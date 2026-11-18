"""Market service: fetch -> normalise -> persist -> serve.

The boundary between "the internet said something" and "the app shows
something". Everything above this module (routers, AI tools, Flutter) reads
shapes produced here, and every shape carries its provenance block unchanged:
source, attribution, confidence, verified, fetched_at, stale, freshness,
actionable, observed_at, lag_days.

Three rules this module exists to keep:

1. **Nothing is invented.** A failed fetch is an exception listing every
   source's reason, never an empty list that reads as "no data today".
2. **Nothing is persisted without provenance.** ``MarketPrice.source_name`` is
   non-nullable for the same reason a citation is mandatory in an article.
3. **Nothing is served without freshness.** Every read path runs
   ``annotate_freshness`` so a 7-day-old rate cannot be dressed as today's.
"""

from __future__ import annotations

import logging
from datetime import date as date_cls, datetime, timedelta
from typing import Any

from sqlalchemy import func, select
from sqlalchemy.orm import Session

from .. import models
from .demand import COMPONENT_ORDER, DemandInputs, compute_demand
from .normalizer import COMMODITY_ALIASES, canonical_commodity, normalize_state
from .sources import registry
from .sources.base import utcnow
from .sources.registry import NoSourceAvailable

logger = logging.getLogger("jeevandhara.market")

#: How far back the sparkline and the 7-day momentum read.
HISTORY_DAYS = 90

#: Demand rows are recomputed on read when the stored one is older than this.
#: An hourly background job keeps the table warm; this is the safety net for a
#: process that has been up less than an hour.
DEMAND_MAX_AGE_MINUTES = 60

#: A sell decision needs today's price. Nothing older is offered as advice.
ADVICE_MAX_LAG_DAYS = registry.MAX_ACTIONABLE_LAG_DAYS


# ------------------------------------------------------------------ errors

class MarketDataUnavailable(RuntimeError):
    """Every configured source failed. `attempts` says which, and why."""

    def __init__(self, attempts: list[dict[str, str]], kind: str) -> None:
        detail = "; ".join(f"{a['source']}: {a['reason']}" for a in attempts)
        super().__init__(f"market data unavailable ({detail})")
        self.attempts = attempts
        self.kind = kind

    def as_dict(self) -> dict[str, Any]:
        return {"message": str(self), "attempts": self.attempts, "kind": self.kind}


class SellAdviceUnavailable(RuntimeError):
    """Advice could not be formed from live data, so none is given."""

    def __init__(self, reason: str, **details: Any) -> None:
        super().__init__(reason)
        self.reason = reason
        self.details = details


# ------------------------------------------------------------------ prices

def get_prices(
    db: Session,
    *,
    commodity: str,
    state: str | None = None,
    district: str | None = None,
    market: str | None = None,
    date: str | None = None,
    limit: int = 200,
    persist: bool = True,
) -> dict[str, Any]:
    """Latest price rows for a crop, with provenance and freshness attached.

    Raises ``MarketDataUnavailable`` rather than returning an empty payload,
    because "the source is down" and "nobody quoted this crop today" must not
    look the same on screen.
    """
    canonical = canonical_commodity(commodity)
    clean_state = normalize_state(state) if state else None

    try:
        rows, meta = registry.fetch_prices(
            commodity=canonical,
            state=clean_state,
            district=district,
            market=market,
            date=date,
            limit=limit,
        )
    except NoSourceAvailable as exc:
        # Every feed is off, rate-limited or broken. Before telling a farmer
        # there is nothing, ask the database: we hold real observations with
        # their own provenance, and "the source will not answer" is a different
        # message from "this crop has never been quoted".
        rows, meta = _stored_prices(
            db,
            canonical,
            state=clean_state,
            district=district,
            market=market,
            limit=limit,
            attempts=exc.attempts,
        )
        if not rows:
            raise MarketDataUnavailable(exc.attempts, exc.kind) from exc
        rows = registry.annotate_freshness(rows, meta)
        return {
            "commodity": canonical,
            "state": clean_state,
            "district": district,
            "market": market,
            "rows": rows,
            "meta": meta,
        }

    rows = registry.annotate_freshness(rows, meta)
    if persist:
        _persist_prices(db, rows, meta)
    return {
        "commodity": canonical,
        "state": clean_state,
        "district": district,
        "market": market,
        "rows": rows,
        "meta": meta,
    }


#: Served when the upstream chains are unusable and storage is not.
STORAGE_FALLBACK_NOTE = (
    "No market source is answering right now, so these are our stored "
    "observations rather than a fresh pull."
)


def _stored_prices(
    db: Session,
    commodity: str,
    *,
    state: str | None = None,
    district: str | None = None,
    market: str | None = None,
    limit: int = 200,
    attempts: list[dict[str, str]] | None = None,
) -> tuple[list[dict[str, Any]], dict[str, Any]]:
    """Stored observations, shaped exactly like a live response.

    Newest row per market and variety, each carrying the provenance it was
    written with. The meta block states plainly that this is storage, is
    always ``stale`` (we could not refresh it), and keeps the per-source
    attempts so a caller can still say why the live pull failed.
    """
    query = db.query(models.MarketPrice).filter(
        models.MarketPrice.commodity == commodity
    )
    if state:
        query = query.filter(models.MarketPrice.state == state)
    if district:
        query = query.filter(models.MarketPrice.district == district)
    if market:
        query = query.filter(models.MarketPrice.market == market)
    query = query.order_by(
        models.MarketPrice.trade_date.desc(), models.MarketPrice.id.desc()
    )

    latest: dict[tuple[str, str | None], models.MarketPrice] = {}
    for row in query.all():
        key = (row.market, row.variety)
        if key not in latest:
            latest[key] = row
        if len(latest) >= limit:
            break

    rows: list[dict[str, Any]] = []
    for row in latest.values():
        rows.append(
            {
                "commodity": row.commodity,
                "variety": row.variety,
                "grade": row.grade,
                "state": row.state,
                "district": row.district,
                "market": row.market,
                "date": row.trade_date.isoformat(),
                "min_price": row.min_price,
                "modal_price": row.modal_price,
                "max_price": row.max_price,
                "unit": "quintal",
                "arrival_quantity": row.arrival_quantity_quintals,
                "_provenance": {
                    "source": row.source_name,
                    "attribution": _attribution_for(row.source_name),
                    "confidence": row.source_confidence or "unknown",
                    "verified": bool(row.source_verified),
                    "fetched_at": (
                        row.fetched_at.isoformat() if row.fetched_at else None
                    ),
                    "stale": True,
                    "note": STORAGE_FALLBACK_NOTE,
                },
            }
        )

    if not rows:
        return [], {}

    sources = [str(r["_provenance"]["source"]) for r in rows]
    dominant = max(set(sources), key=sources.count)
    meta = {
        "source": dominant,
        "attribution": _attribution_for(dominant),
        "confidence": _confidence_for(dominant),
        "verified": all(bool(r["_provenance"]["verified"]) for r in rows),
        "tier": _tier_for(dominant),
        "fetched_at": max(
            (r["_provenance"]["fetched_at"] for r in rows if r["_provenance"]["fetched_at"]),
            default=None,
        ),
        "stale": True,
        "note": STORAGE_FALLBACK_NOTE,
        "attempts": attempts or [],
        "fallback_used": True,
        "from_storage": True,
    }
    return rows, meta


def _source_config(name: str) -> dict[str, Any]:
    return registry.SOURCES.get(str(name or ""), {})


def _attribution_for(name: str) -> str:
    return str(_source_config(name).get("attribution") or name)


def _confidence_for(name: str) -> str:
    return str(_source_config(name).get("confidence") or "unknown")


def _tier_for(name: str) -> str:
    declared = str(_source_config(name).get("tier") or "C").upper()
    return declared if declared in registry.VALID_TIERS else "C"


def _persist_prices(db: Session, rows: list[dict[str, Any]], meta: dict[str, Any]) -> int:
    """Upsert observations. Returns how many rows were new.

    Idempotent by the (commodity, market, trade_date, variety) unique key so a
    background sync and an on-demand read can both write without duplicating.
    """
    written = 0
    for row in rows:
        trade_date = _to_date(row.get("date"))
        if trade_date is None or not row.get("market"):
            # No market date means no usable observation: we refuse to store a
            # price we cannot date, because undated rows are exactly the ones
            # that later get presented as current.
            continue

        existing = (
            db.query(models.MarketPrice)
            .filter(
                models.MarketPrice.commodity == row.get("commodity"),
                models.MarketPrice.market == row["market"],
                models.MarketPrice.trade_date == trade_date,
                models.MarketPrice.variety == (row.get("variety") or None),
            )
            .first()
        )
        provenance = row.get("_provenance") or {}
        payload = dict(
            grade=row.get("grade"),
            state=row.get("state"),
            district=row.get("district"),
            min_price=row.get("min_price"),
            modal_price=row.get("modal_price"),
            max_price=row.get("max_price"),
            arrival_quantity_quintals=row.get("arrival_quantity"),
            arrival_unit=row.get("unit"),
            source_name=provenance.get("source") or row.get("source") or "unknown",
            source_url=provenance.get("url"),
            source_confidence=provenance.get("confidence"),
            source_verified=bool(provenance.get("verified")),
            fetched_at=_to_datetime(provenance.get("fetched_at")) or utcnow().replace(tzinfo=None),
            upstream_id=row.get("upstream_id"),
        )

        if existing:
            for key, value in payload.items():
                setattr(existing, key, value)
        else:
            db.add(
                models.MarketPrice(
                    commodity=row["commodity"],
                    variety=row.get("variety") or None,
                    trade_date=trade_date,
                    market=row["market"],
                    **payload,
                )
            )
            written += 1

    _log_sync(db, meta, job="prices", rows_written=written, rows_fetched=len(rows))
    db.commit()
    return written


def get_history(
    db: Session,
    *,
    commodity: str,
    state: str,
    days: int = HISTORY_DAYS,
    persist: bool = True,
) -> dict[str, Any]:
    """Daily average price series for one state+commodity.

    Reads the stored series first, then the upstream one, so a screen works
    offline-from-cache as long as any real observation exists. Falls back to
    aggregating our own stored rows when the upstream history endpoint is not
    available - still real data, just our own copy of it.
    """
    canonical = canonical_commodity(commodity)
    clean_state = normalize_state(state)

    rows, meta = _history_upstream(canonical, clean_state, days)
    if rows and persist:
        _persist_history(db, rows, canonical, clean_state, meta)

    if not rows:
        rows = _history_from_db(db, canonical, clean_state, days)

    return {
        "commodity": canonical,
        "state": clean_state,
        "days": days,
        "rows": sorted(rows, key=lambda r: r.get("date") or ""),
        "meta": meta,
    }


def _history_upstream(
    commodity: str, state: str, days: int
) -> tuple[list[dict[str, Any]], dict[str, Any]]:
    """Ask the configured price sources for a series, without failing the read.

    History is a nice-to-have next to the price table: a screen with no
    sparkline is a worse experience, a screen with a 500 is a broken one. So
    this path degrades to "no history" and records why.
    """
    attempts: list[dict[str, str]] = []
    for name in registry.available_sources("price"):
        source = registry.get_source(name)
        history = getattr(source, "history", None)
        if history is None:
            attempts.append({"source": name, "reason": "no history endpoint"})
            continue
        try:
            rows = history(state, commodity, days)
        except Exception as exc:  # noqa: BLE001 - any failure just skips this feed
            attempts.append({"source": name, "reason": str(exc)[:200]})
            logger.info("market history %s failed: %s", name, exc)
            continue
        if not rows:
            attempts.append({"source": name, "reason": "no rows returned"})
            continue
        meta = dict(
            source=name,
            attribution=source.attribution,
            confidence=source.confidence,
            verified=source.verified,
            fetched_at=utcnow().isoformat(),
            stale=False,
            attempts=attempts,
        )
        return rows, meta

    return [], dict(
        source=None,
        attribution=None,
        confidence="low",
        verified=False,
        fetched_at=utcnow().isoformat(),
        stale=True,
        attempts=attempts,
        note="no upstream history available; served from stored observations",
    )


def _persist_history(
    db: Session,
    rows: list[dict[str, Any]],
    commodity: str,
    state: str,
    meta: dict[str, Any],
) -> None:
    source_name = meta.get("source") or "unknown"
    for row in rows:
        day = _to_date(row.get("date"))
        if day is None:
            continue
        existing = (
            db.query(models.CropPriceHistory)
            .filter(
                models.CropPriceHistory.state == state,
                models.CropPriceHistory.commodity == commodity,
                models.CropPriceHistory.date == day,
            )
            .first()
        )
        payload = dict(
            avg_min_price=row.get("min_price"),
            avg_modal_price=row.get("modal_price"),
            avg_max_price=row.get("max_price"),
            data_points=int(row["data_points"]) if row.get("data_points") else None,
            source_name=source_name,
            fetched_at=utcnow().replace(tzinfo=None),
        )
        if existing:
            for key, value in payload.items():
                setattr(existing, key, value)
        else:
            db.add(
                models.CropPriceHistory(
                    state=state, commodity=commodity, date=day, **payload
                )
            )
    db.commit()


def _history_from_db(
    db: Session, commodity: str, state: str, days: int
) -> list[dict[str, Any]]:
    """Aggregate our own stored observations into a series.

    Only used when no upstream history exists. The result is our copy of real
    observations, so it is still Tier A data - it just has fewer days behind it,
    which ``data_points`` reports honestly.
    """
    since = date_cls.today() - timedelta(days=days)
    grouped = (
        db.query(
            models.MarketPrice.trade_date,
            func.avg(models.MarketPrice.min_price),
            func.avg(models.MarketPrice.modal_price),
            func.avg(models.MarketPrice.max_price),
            func.count(models.MarketPrice.id),
        )
        .filter(
            models.MarketPrice.commodity == commodity,
            models.MarketPrice.state == state,
            models.MarketPrice.trade_date >= since,
        )
        .group_by(models.MarketPrice.trade_date)
        .order_by(models.MarketPrice.trade_date)
        .all()
    )
    return [
        {
            "date": day.isoformat(),
            "min_price": round(low, 2) if low is not None else None,
            "modal_price": round(modal, 2) if modal is not None else None,
            "max_price": round(high, 2) if high is not None else None,
            "data_points": count,
            "commodity": commodity,
            "state": state,
        }
        for day, low, modal, high, count in grouped
        if modal is not None
    ]


# -------------------------------------------------------------- reference

def list_commodities(db: Session) -> list[dict[str, Any]]:
    """Commodities we can answer for, with every alias that resolves to them.

    Union of the alias table (what we know how to match) and what has actually
    been observed in storage (what we have data for). A crop present in one and
    not the other is still listed, with ``has_data`` saying which.
    """
    observed = {
        row.commodity
        for row in db.query(models.MarketPrice.commodity)
        .distinct()
        .all()
        if row.commodity
    }

    out: list[dict[str, Any]] = []
    for canonical, aliases in sorted(COMMODITY_ALIASES.items()):
        out.append(
            {
                "commodity": canonical,
                "aliases": sorted(aliases),
                "has_data": canonical in observed,
            }
        )

    # Anything stored that the alias table does not know about yet - never hide
    # real observations because a lookup table has not caught up.
    for name in sorted(observed - set(COMMODITY_ALIASES)):
        out.append({"commodity": name, "aliases": [], "has_data": True})

    out.sort(key=lambda item: (not item["has_data"], item["commodity"]))
    return out


def list_mandis(db: Session, *, state: str | None = None) -> list[dict[str, Any]]:
    """Mandis we actually hold observations for, with district and recency.

    Reads storage only. An earlier version also merged the upstream mandi list
    so empty places showed up in the picker, but that put a live network call
    on the critical path of a screen whose job is to be fast - and a picker
    entry with no prices behind it is a dead end anyway. Places are discovered
    by having data.
    """
    clean_state = normalize_state(state) if state else None

    rows = (
        db.query(
            models.MarketPrice.market,
            models.MarketPrice.district,
            models.MarketPrice.state,
            func.max(models.MarketPrice.trade_date),
            func.count(models.MarketPrice.id),
        )
        .group_by(
            models.MarketPrice.market,
            models.MarketPrice.district,
            models.MarketPrice.state,
        )
        .all()
    )

    out = []
    for market, district, row_state, last_date, count in rows:
        if clean_state and normalize_state(row_state or "") != clean_state:
            continue
        out.append(
            {
                "market": market,
                "district": district,
                "state": row_state,
                "last_observed": last_date.isoformat() if last_date else None,
                "observations": count,
                "has_data": True,
            }
        )

    out.sort(key=lambda row: (row["market"]))
    return out


def list_districts(db: Session, *, state: str | None = None) -> list[str]:
    clean_state = normalize_state(state) if state else None
    query = db.query(models.MarketPrice.district).distinct()
    if clean_state:
        query = query.filter(models.MarketPrice.state == clean_state)
    return sorted({row.district for row in query.all() if row.district})


# ----------------------------------------------------------------- demand

def get_demand(
    db: Session,
    *,
    commodity: str,
    mandi: str | None = None,
    district: str | None = None,
    state: str | None = None,
    force: bool = False,
) -> dict[str, Any]:
    """Compute (or reuse) a demand reading for one crop in one place.

    Stored readings are reused while they are young, because recomputing on
    every read would put a source fetch on the critical path of a screen that
    has a perfectly good answer in the database.
    """
    canonical = canonical_commodity(commodity)
    clean_state = normalize_state(state) if state else None

    if not force:
        cached = _fresh_demand(db, canonical, mandi=mandi, district=district, state=clean_state)
        if cached is not None:
            return cached

    prices = _price_rows(db, canonical, mandi=mandi, district=district, state=clean_state)
    if not prices:
        raise MarketDataUnavailable(
            [
                {
                    "source": "database",
                    "reason": (
                        f"no stored price observations for '{canonical}'"
                        + (f" in {mandi or district or clean_state}" if (mandi or district or clean_state) else "")
                    ),
                }
            ],
            kind="price",
        )

    inputs = _demand_inputs(db, canonical, prices, mandi=mandi, district=district, state=clean_state)
    result = compute_demand(inputs)

    reading = _store_demand(db, canonical, result, inputs, mandi=mandi, district=district, state=clean_state)
    return reading


def _demand_inputs(
    db: Session,
    commodity: str,
    prices: list[dict[str, Any]],
    *,
    mandi: str | None,
    district: str | None,
    state: str | None,
) -> DemandInputs:
    """Build the component inputs from what we actually hold.

    Only inputs we genuinely possess are passed. Anything missing stays missing
    so the component is omitted with a reason instead of being fed a default.
    """
    history = _history_from_db(db, commodity, state or _state_of(prices), HISTORY_DAYS)
    arrivals = _arrival_rows(db, commodity, mandi=mandi, district=district, state=state)
    inquiries = _inquiry_rows(db, commodity, mandi=mandi, district=district, state=state)

    sources = sorted(
        {p["_provenance"].get("source") for p in prices if p.get("_provenance")}
    )

    inputs = DemandInputs(
        price_rows=prices,
        price_history=history,
        arrivals=arrivals,
        inquiries=inquiries,
        sources=[s for s in sources if s],
    )

    # Traded quantity and trade counts are not published by any reachable feed.
    # They are deliberately left as None so those components report
    # `no_traded_quantity` / `no_trade_count` rather than computing from a 0.
    # MSP stays None for the same reason: no resource id has been confirmed.
    return inputs


def _arrival_rows(
    db: Session,
    commodity: str,
    *,
    mandi: str | None,
    district: str | None,
    state: str | None,
) -> list[dict[str, Any]]:
    query = db.query(models.MarketPrice).filter(models.MarketPrice.commodity == commodity)
    query = _scope(query, mandi=mandi, district=district, state=state)
    rows = query.order_by(models.MarketPrice.trade_date).all()

    by_date: dict[date_cls, list[float]] = {}
    for row in rows:
        if row.arrival_quantity_quintals is None:
            continue
        by_date.setdefault(row.trade_date, []).append(row.arrival_quantity_quintals)

    return [
        {"date": day.isoformat(), "quantity": sum(values)}
        for day, values in sorted(by_date.items())
    ]


def _inquiry_rows(
    db: Session,
    commodity: str,
    *,
    mandi: str | None,
    district: str | None,
    state: str | None,
) -> list[dict[str, Any]]:
    query = db.query(models.Inquiry).filter(models.Inquiry.crop_name == commodity)
    if mandi:
        query = query.filter(models.Inquiry.mandi == mandi)
    if district:
        query = query.filter(models.Inquiry.district == district)
    if state:
        query = query.filter(models.Inquiry.state == state)
    return [{"id": row.id, "created_at": row.created_at.isoformat()} for row in query.all()]


def _price_rows(
    db: Session,
    commodity: str,
    *,
    mandi: str | None,
    district: str | None,
    state: str | None,
) -> list[dict[str, Any]]:
    """Stored observations, shaped the way the demand components expect."""
    query = db.query(models.MarketPrice).filter(models.MarketPrice.commodity == commodity)
    query = _scope(query, mandi=mandi, district=district, state=state)

    latest: dict[str, models.MarketPrice] = {}
    for row in query.all():
        current = latest.get(row.market)
        if current is None or row.trade_date > current.trade_date:
            latest[row.market] = row

    out = []
    for row in latest.values():
        if row.modal_price is None:
            continue
        out.append(
            {
                "market": row.market,
                "district": row.district,
                "state": row.state,
                "date": row.trade_date.isoformat(),
                "min_price": row.min_price,
                "modal_price": row.modal_price,
                "max_price": row.max_price,
                "arrival_quantity": row.arrival_quantity_quintals,
                "_provenance": {
                    "source": row.source_name,
                    "confidence": row.source_confidence,
                    "verified": row.source_verified,
                    "fetched_at": row.fetched_at.isoformat() if row.fetched_at else None,
                },
            }
        )
    return out


def _scope(
    query,
    *,
    mandi: str | None = None,
    district: str | None = None,
    state: str | None = None,
):
    if mandi:
        query = query.filter(models.MarketPrice.market == mandi)
    if district:
        query = query.filter(models.MarketPrice.district == district)
    if state:
        query = query.filter(models.MarketPrice.state == normalize_state(state))
    return query


def _state_of(prices: list[dict[str, Any]]) -> str | None:
    for row in prices:
        if row.get("state"):
            return row["state"]
    return None


def _fresh_demand(
    db: Session,
    commodity: str,
    *,
    mandi: str | None,
    district: str | None,
    state: str | None,
) -> dict[str, Any] | None:
    query = db.query(models.MandiDemand).filter(models.MandiDemand.commodity == commodity)
    if mandi:
        query = query.filter(models.MandiDemand.mandi == mandi)
    if district:
        query = query.filter(models.MandiDemand.district == district)
    if state:
        query = query.filter(models.MandiDemand.state == normalize_state(state))

    stored = query.order_by(models.MandiDemand.created_at.desc()).first()
    if stored is None:
        return None

    age = utcnow().replace(tzinfo=None) - stored.created_at
    if age > timedelta(minutes=DEMAND_MAX_AGE_MINUTES):
        return None
    return _reading(stored)


def _store_demand(
    db: Session,
    commodity: str,
    result,
    inputs: DemandInputs,
    *,
    mandi: str | None,
    district: str | None,
    state: str | None,
) -> dict[str, Any]:
    place = mandi or district or state or "Karnataka"
    computed_for = _latest_date(inputs) or date_cls.today()

    row = (
        db.query(models.MandiDemand)
        .filter(
            models.MandiDemand.commodity == commodity,
            models.MandiDemand.mandi == place,
            models.MandiDemand.computed_for == computed_for,
        )
        .first()
    )
    now = utcnow().replace(tzinfo=None)

    payload = dict(
        district=district,
        state=state,
        score=result.score,
        band=result.band,
        component_count=result.component_count,
        weights_used=result.weights_used,
        sample_size=result.sample_size,
        confidence=result.confidence,
        source_name=", ".join(result.sources) if result.sources else None,
        fetched_at=now,
        computed_for=computed_for,
        created_at=now,
    )

    if row is None:
        row = models.MandiDemand(mandi=place, commodity=commodity, **payload)
        db.add(row)
    else:
        for key, value in payload.items():
            setattr(row, key, value)
        row.components.clear()

    db.flush()

    for component in result.components:
        db.add(
            models.MandiDemandComponent(
                demand_id=row.id,
                component=component.name,
                weight=component.weight,
                effective_weight=component.effective_weight,
                available=component.available,
                unavailable_reason=component.reason,
                raw_value=component.raw_value,
                normalised_value=component.normalised_value,
                contribution=component.contribution,
                sample_size=component.sample_size,
                explanation_en=component.explanation_en,
                explanation_kn=component.explanation_kn,
                source_name=component.source_name,
            )
        )

    db.commit()
    db.refresh(row)
    return _reading(row)


def _reading(row: models.MandiDemand) -> dict[str, Any]:
    """A stored demand row as the API shape, breakdown included."""
    components = sorted(
        row.components, key=lambda c: COMPONENT_ORDER.index(c.component)
        if c.component in COMPONENT_ORDER
        else len(COMPONENT_ORDER)
    )
    live = [c for c in components if c.available]
    drivers = sorted(
        (c for c in live if c.contribution), key=lambda c: c.contribution, reverse=True
    )[:2]

    payload = {
        "mandi": row.mandi,
        "district": row.district,
        "state": row.state,
        "commodity": row.commodity,
        "score": row.score,
        "band": row.band,
        "is_derived": True,
        "component_count": row.component_count,
        "components_total": len(components),
        "weights_used": round(row.weights_used, 4),
        "coverage": (
            round(row.weights_used, 4) if not row.components else None
        ),
        "confidence": row.confidence,
        "sample_size": row.sample_size,
        "computed_for": row.computed_for.isoformat(),
        "computed_at": row.created_at.isoformat(),
        "source": row.source_name,
        "components": [_component(c) for c in components],
        "drivers_en": [f"{c.component}: {c.explanation_en}" for c in drivers],
        "drivers_kn": [f"{c.component}: {c.explanation_kn}" for c in drivers],
        "explanations_en": [
            c.explanation_en for c in live if c.explanation_en
        ],
        "explanations_kn": [
            c.explanation_kn for c in live if c.explanation_kn
        ],
        "omitted": [
            {"component": c.component, "reason": c.unavailable_reason}
            for c in components
            if not c.available
        ],
    }

    nominal = sum(c.weight for c in components) or 1.0
    payload["coverage"] = round(row.weights_used / nominal, 4)
    return payload


def _component(row: models.MandiDemandComponent) -> dict[str, Any]:
    return {
        "component": row.component,
        "weight": row.weight,
        "effective_weight": row.effective_weight,
        "available": row.available,
        "unavailable_reason": row.unavailable_reason,
        "raw_value": row.raw_value,
        "normalised_value": row.normalised_value,
        "contribution": row.contribution,
        "sample_size": row.sample_size,
        "explanation_en": row.explanation_en,
        "explanation_kn": row.explanation_kn,
        "source": row.source_name,
    }


def _latest_date(inputs: DemandInputs) -> date_cls | None:
    """The market date this reading is actually about."""
    candidates: list[date_cls] = []
    for row in list(inputs.price_rows) + list(inputs.price_history):
        parsed = _to_date(row.get("date"))
        if parsed:
            candidates.append(parsed)
    return max(candidates) if candidates else None


def get_demand_top(
    db: Session,
    *,
    commodity: str,
    state: str | None = None,
    district: str | None = None,
    limit: int = 10,
) -> dict[str, Any]:
    """Best mandis for a crop, ranked by score among those that have one.

    Mandis whose reading is ``insufficient_data`` are returned separately: a
    list that silently drops them would imply they scored badly, when the truth
    is that we do not know.
    """
    canonical = canonical_commodity(commodity)
    clean_state = normalize_state(state) if state else None

    places = _candidate_places(db, canonical, district=district, state=clean_state)
    ranked: list[dict[str, Any]] = []
    unknown: list[dict[str, Any]] = []

    for place in places:
        try:
            reading = get_demand(
                db,
                commodity=canonical,
                mandi=place["market"],
                district=place["district"],
                state=clean_state,
            )
        except MarketDataUnavailable:
            continue
        if reading["score"] is None:
            unknown.append(
                {
                    "mandi": place["market"],
                    "district": place["district"],
                    "band": reading["band"],
                    "reason": "insufficient_data",
                }
            )
            continue
        ranked.append(reading)

    ranked.sort(key=lambda r: r["score"], reverse=True)
    return {
        "commodity": canonical,
        "state": clean_state,
        "district": district,
        "is_derived": True,
        "ranked": ranked[:limit],
        "insufficient_data": unknown[:limit],
        "ranked_count": len(ranked),
        "unknown_count": len(unknown),
        "explanation": (
            "Ranked by the derived demand index. Mandis listed under "
            "insufficient_data have too few inputs to score and are not ranked "
            "- absence from the ranking does not mean low demand."
        ),
    }


def _candidate_places(
    db: Session, commodity: str, *, district: str | None, state: str | None
) -> list[dict[str, Any]]:
    query = db.query(
        models.MarketPrice.market, models.MarketPrice.district
    ).filter(models.MarketPrice.commodity == commodity)
    query = _scope(query, district=district, state=state)
    seen: dict[str, dict[str, Any]] = {}
    for market, dist in query.all():
        if market not in seen:
            seen[market] = {"market": market, "district": dist}
    return list(seen.values())


# ------------------------------------------------------------ sell advice

def sell_advice(
    db: Session,
    *,
    commodity: str,
    quantity_quintals: float,
    district: str | None = None,
    state: str | None = None,
) -> dict[str, Any]:
    """Where to sell, from live prices only.

    Deliberately narrow: it ranks mandis we hold today's price for, and refuses
    when we hold none. It does not model transport cost or distance, because
    nothing in the dataset describes them and a made-up travel cost would look
    exactly like a real one on screen.
    """
    canonical = canonical_commodity(commodity)
    clean_state = normalize_state(state) if state else None

    prices = _price_rows(db, canonical, mandi=None, district=district, state=clean_state)
    if not prices:
        raise SellAdviceUnavailable(
            "no price observations are available for this crop right now, so no "
            "recommendation can be made",
            commodity=canonical,
            district=district,
            state=clean_state,
        )

    dated = [row for row in prices if row.get("date")]
    if not dated:
        raise SellAdviceUnavailable(
            "price observations for this crop carry no market date, so their "
            "age cannot be checked and advice would not be trustworthy",
            commodity=canonical,
        )

    today = date_cls.today()
    actionable = [
        row for row in dated if (today - _to_date(row["date"])).days <= ADVICE_MAX_LAG_DAYS
    ]
    if not actionable:
        newest = max(_to_date(row["date"]) for row in dated)
        raise SellAdviceUnavailable(
            f"the newest price for this crop is from {newest.isoformat()}, which "
            f"is older than {ADVICE_MAX_LAG_DAYS} day(s); a sell decision needs a "
            "current rate",
            commodity=canonical,
            newest_observation=newest.isoformat(),
            oldest_observed_days=(today - newest).days,
        )

    priced = [row for row in actionable if row.get("modal_price")]
    if not priced:
        raise SellAdviceUnavailable(
            "no mandi is quoting a modal price for this crop today",
            commodity=canonical,
        )

    best = max(priced, key=lambda row: row["modal_price"])
    worst = min(priced, key=lambda row: row["modal_price"])
    spread = best["modal_price"] - worst["modal_price"]

    reading = None
    try:
        reading = get_demand(
            db, commodity=canonical, mandi=best["market"], district=district, state=clean_state
        )
    except MarketDataUnavailable:
        # Advice still stands on price alone; the demand reading is extra, not
        # load-bearing, so its absence must not block the answer.
        pass

    return {
        "commodity": canonical,
        "quantity_quintals": quantity_quintals,
        "district": district,
        "state": clean_state,
        "best_mandi": {
            "market": best["market"],
            "district": best["district"],
            "modal_price": best["modal_price"],
            "min_price": best.get("min_price"),
            "max_price": best.get("max_price"),
            "observed_on": best["date"],
            "source": (best.get("_provenance") or {}).get("source"),
        },
        "price_range": {
            "low": worst["modal_price"],
            "high": best["modal_price"],
            "spread": round(spread, 2),
            "spread_pct": (
                round(spread / worst["modal_price"] * 100.0, 1)
                if worst["modal_price"]
                else None
            ),
            "quoted_in": len(priced),
        },
        "expected_value": {
            "quintals": quantity_quintals,
            "at_best_modal": round(best["modal_price"] * quantity_quintals, 2),
            "currency": "INR",
        },
        "demand": reading,
        "is_derived": True,
        "confidence": reading["confidence"] if reading else "low",
        "caveats_en": [
            f"Prices from {len(priced)} mandi(s) observed within the last "
            f"{ADVICE_MAX_LAG_DAYS} day(s).",
            "Travel cost and distance are not modelled - no dataset describes "
            "them, so they are left out rather than estimated.",
        ],
        "caveats_kn": [
            f"ಕಳೆದ {ADVICE_MAX_LAG_DAYS} ದಿನದಲ್ಲಿ ವರದಿಯಾದ {len(priced)} ಮಂಡಿಗಳ "
            "ಬೆಲೆಗಳು ಮಾತ್ರ.",
            "ಪ್ರಯಾಣ ವೆಚ್ಚ ಮತ್ತು ದೂರವನ್ನು ಲೆಕ್ಕಹಾಕಲಾಗಿಲ್ಲ - ಯಾವುದೇ ದತ್ತಾಂಶ ಅವುಗಳನ್ನು "
            "ವಿವರಿಸುವುದಿಲ್ಲ, ಆದ್ದರಿಂದ ಅಂದಾಜು ಮಾಡದೆ ಬಿಟ್ಟಿದ್ದೇವೆ.",
        ],
        "meta": {
            "tier": "D",
            "source": (best.get("_provenance") or {}).get("source"),
            "fetched_at": (best.get("_provenance") or {}).get("fetched_at"),
            "stale": (best.get("_provenance") or {}).get("stale"),
            "confidence": (best.get("_provenance") or {}).get("confidence"),
        },
    }


# ------------------------------------------------------------------ status

def market_status() -> dict[str, Any]:
    """`/market/status`: what the feeds are doing, and what we can promise."""
    return registry.market_status()


# ------------------------------------------------------------------- utils

def _to_date(value: Any) -> date_cls | None:
    if value is None:
        return None
    if isinstance(value, date_cls) and not isinstance(value, datetime):
        return value
    if isinstance(value, datetime):
        return value.date()
    text = str(value).strip()
    if not text:
        return None
    for fmt in ("%Y-%m-%d", "%d-%m-%Y", "%d/%m/%Y", "%Y/%m/%d", "%d-%b-%Y", "%d %b %Y"):
        try:
            return datetime.strptime(text[:11].strip(), fmt).date()
        except ValueError:
            continue
    try:
        return datetime.fromisoformat(text.replace("Z", "+00:00")).date()
    except ValueError:
        return None


def _to_datetime(value: Any) -> datetime | None:
    if value is None:
        return None
    if isinstance(value, datetime):
        return value.replace(tzinfo=None) if value.tzinfo else value
    try:
        parsed = datetime.fromisoformat(str(value).replace("Z", "+00:00"))
    except ValueError:
        return None
    return parsed.replace(tzinfo=None)


def _log_sync(
    db: Session,
    meta: dict[str, Any],
    *,
    job: str,
    rows_fetched: int,
    rows_written: int,
    error: str | None = None,
) -> None:
    """Record the attempt, success or not, so a stale screen can be diagnosed."""
    attempts = meta.get("attempts") or []
    failures = [a for a in attempts if a.get("reason")]
    db.add(
        models.SourceSyncLog(
            source_name=meta.get("source") or "none",
            job=job,
            ok=not error,
            error=error or ("; ".join(f"{a['source']}: {a['reason']}" for a in failures)[:500] or None),
            rows_fetched=rows_fetched,
            rows_written=rows_written,
            started_at=utcnow().replace(tzinfo=None),
            finished_at=utcnow().replace(tzinfo=None),
        )
    )


__all__ = [
    "ADVICE_MAX_LAG_DAYS",
    "DEMAND_MAX_AGE_MINUTES",
    "HISTORY_DAYS",
    "MarketDataUnavailable",
    "SellAdviceUnavailable",
    "get_demand",
    "get_demand_top",
    "get_history",
    "get_prices",
    "list_commodities",
    "list_districts",
    "list_mandis",
    "market_status",
    "sell_advice",
]
