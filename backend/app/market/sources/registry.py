"""Source registry and failover.

The one rule this module enforces: **a price without provenance is not a
price**. Every row returned from here carries which source produced it, that
source's attribution string, its confidence, whether it was verified, when it
was actually fetched, and whether it is stale. Callers cannot opt out.

Failover walks ``price_chain`` in order and returns the first source that is
enabled and answers. If every source fails, the error lists each reason rather
than collapsing to "no data" - "no API key" and "upstream 500" lead to very
different user-facing messages.
"""

from __future__ import annotations

import logging
from datetime import datetime, timedelta, timezone
from typing import Any, Iterable

from .base import (
    ARRIVAL_CHAIN,
    CACHE_TTL,
    PRICE_CHAIN,
    SOURCES,
    CircuitBreaker,
    MarketSource,
    SourceUnavailable,
    SourceStatus,
    utcnow,
)
from .data_gov import DataGovSource
from .enam import EnamSource
from .mandi_api import MandiApiSource

logger = logging.getLogger("jeevandhara.market")


class NoSourceAvailable(RuntimeError):
    """Every candidate source failed. Carries per-source reasons."""

    def __init__(self, attempts: list[dict[str, str]], kind: str) -> None:
        detail = "; ".join(f"{a['source']}: {a['reason']}" for a in attempts)
        super().__init__(f"no market source available ({detail})")
        self.attempts = attempts
        self.kind = kind


#: Single shared instances. The TTL cache and circuit breaker state live on the
#: instance, so creating a new object per request would defeat both.
_INSTANCES: dict[str, MarketSource] = {}


def get_source(name: str) -> MarketSource:
    source = _INSTANCES.get(name)
    if source is None:
        source = _build(name)
        _INSTANCES[name] = source
    return source


def _build(name: str) -> MarketSource:
    if name == "data_gov_in":
        return DataGovSource()
    if name == "enam":
        return EnamSource()
    if name == "mandi_api":
        return MandiApiSource()
    raise KeyError(f"unknown market source: {name}")


def available_sources(kind: str = "price") -> list[str]:
    """Names from the configured chain that are currently enabled."""
    chain = ARRIVAL_CHAIN if kind == "arrival" else PRICE_CHAIN
    return [name for name in chain if get_source(name).enabled]


def fetch_prices(
    *,
    commodity: str | None = None,
    state: str | None = None,
    district: str | None = None,
    market: str | None = None,
    date: str | None = None,
    limit: int = 500,
) -> tuple[list[dict[str, Any]], dict[str, Any]]:
    """Price lookup with failover. Returns ``(rows, meta)``.

    ``meta`` always contains ``source``, ``attribution``, ``confidence``,
    ``verified``, ``stale``, ``fetched_at`` and ``attempts`` so the API layer can
    pass provenance straight through to the client.
    """
    return _fetch_with_failover(
        PRICE_CHAIN,
        kind="price",
        commodity=commodity,
        state=state,
        district=district,
        market=market,
        date=date,
        limit=limit,
    )


def fetch_arrivals(
    *,
    commodity: str | None = None,
    state: str | None = None,
    district: str | None = None,
    market: str | None = None,
    date: str | None = None,
    limit: int = 500,
) -> tuple[list[dict[str, Any]], dict[str, Any]]:
    """Arrival-quantity lookup with failover."""
    return _fetch_with_failover(
        ARRIVAL_CHAIN,
        kind="arrival",
        commodity=commodity,
        state=state,
        district=district,
        market=market,
        date=date,
        limit=limit,
    )


def _fetch_with_failover(
    chain: Iterable[str],
    *,
    kind: str,
    **params: Any,
) -> tuple[list[dict[str, Any]], dict[str, Any]]:
    attempts: list[dict[str, str]] = []

    for name in chain:
        source = get_source(name)
        if not source.enabled:
            attempts.append({"source": name, "reason": "disabled or not configured"})
            continue

        # An arrival request must never be answered by a price-only source.
        if kind == "arrival" and not source.provides_arrivals:
            attempts.append({"source": name, "reason": "does not publish arrival quantities"})
            continue

        try:
            rows, meta = source.fetch(**params)
        except SourceUnavailable as exc:
            attempts.append({"source": name, "reason": exc.reason})
            logger.info("market source %s skipped: %s", name, exc.reason)
            continue

        enriched = [dict(row, _provenance=meta) for row in rows]
        return enriched, dict(meta, attempts=attempts, fallback_used=bool(attempts))

    raise NoSourceAvailable(attempts, kind=kind)


# --------------------------------------------------------------- freshness

#: A price older than this many days is never presented as actionable. Mandi
#: rates move daily and a farmer deciding whether to sell today cannot use a
#: number from last week, however confidently we fetched it.
MAX_ACTIONABLE_LAG_DAYS = 1

#: Beyond this, the data is shown for context only.
STALE_AFTER_DAYS = 1
VERY_STALE_AFTER_DAYS = 3


def annotate_freshness(
    rows: list[dict[str, Any]], meta: dict[str, Any], *, now: datetime | None = None
) -> list[dict[str, Any]]:
    """Attach a ``freshness`` verdict to each row.

    Three verdicts, deliberately distinct:

    * ``fresh``    - recent enough to act on.
    * ``stale``    - real data, too old to act on confidently.
    * ``unverified`` - from a feed we have never actually parsed.

    Age is taken from the **data's own observation date**, not from when we
    happened to call the API. Those are different things, and using the wrong
    one is how a 7-day-old rate ends up labelled "fresh" because the fetch was
    fast. A row can also be fresher than its siblings when a feed returns a
    multi-day window, so this is computed per row.

    An unverified feed is never ``fresh``, however new the data.
    """
    reference = now or utcnow()
    observed = _parse_iso(meta.get("fetched_at"))

    for row in rows:
        # The row's own market date, and nothing else. We deliberately do NOT
        # fall back to fetched_at here: a feed can be fetched instantly and
        # still be carrying last week's rates, and conflating the two is how a
        # 7-day-old price gets labelled fresh. No date means no currency claim.
        row_date = _parse_iso(row.get("date"))
        lag_days = (
            max((reference - row_date).total_seconds(), 0.0) / 86400.0
            if row_date
            else None
        )

        if not meta.get("verified"):
            verdict = "unverified"
        elif meta.get("stale") or lag_days is None or lag_days > STALE_AFTER_DAYS:
            verdict = "stale"
        else:
            verdict = "fresh"

        # How this row may be used, so the API layer cannot accidentally let a
        # week-old rate inform sell advice.
        actionable = verdict == "fresh" and lag_days is not None and lag_days <= MAX_ACTIONABLE_LAG_DAYS

        provenance = dict(row.get("_provenance", meta))
        provenance.update(
            freshness=verdict,
            actionable=actionable,
            observed_at=row_date.isoformat() if row_date else None,
            lag_days=round(lag_days, 1) if lag_days is not None else None,
            fetch_age_seconds=(
                int((reference - observed).total_seconds()) if observed else None
            ),
        )
        row["_provenance"] = provenance
    return rows


def _parse_iso(value: Any) -> datetime | None:
    """Parse an ISO date or datetime into an aware UTC datetime, or None.

    A bare ``YYYY-MM-DD`` is anchored to midnight UTC, which is what feeds mean
    by a market date.
    """
    if not value:
        return None
    text = str(value).strip()
    try:
        parsed = datetime.fromisoformat(text.replace("Z", "+00:00"))
    except ValueError:
        try:
            parsed = datetime.strptime(text, "%Y-%m-%d")
        except ValueError:
            return None
    if parsed.tzinfo is None:
        parsed = parsed.replace(tzinfo=timezone.utc)
    return parsed


# ----------------------------------------------------------------- status

def source_status() -> list[dict[str, Any]]:
    """Per-source health for ``/market/status``, in chain order."""
    seen: list[dict[str, Any]] = []
    for name in list(PRICE_CHAIN) + [n for n in ARRIVAL_CHAIN if n not in PRICE_CHAIN]:
        if name not in SOURCES:
            continue
        source = get_source(name)
        missing = getattr(source, "missing_key", None)
        seen.append(
            dict(
                source.status().as_dict(),
                kind=source.kind,
                verification_note=(SOURCES[name].get("verification_note") or "").strip(),
                disabled_reason=(
                    f"{missing} not set"
                    if missing
                    else "disabled in data_sources.yaml"
                    if not SOURCES[name].get("enabled")
                    else "disabled when APP_ENV=production"
                    if SOURCES[name].get("dev_only")
                    else None
                ),
            )
        )
    return seen


def market_status() -> dict[str, Any]:
    """Aggregate health: which feeds are live, and what can we promise?"""
    statuses = source_status()
    price_ok = [s for s in statuses if s["kind"] == "price" and s["enabled"] and s["verified"]]
    arrival_ok = [
        s for s in statuses if s["kind"] == "arrival" and s["enabled"] and s["verified"]
    ]

    return {
        # Only mark the module live if an enabled AND verified feed exists.
        "live": bool(price_ok),
        "prices": "live" if price_ok else ("stale" if any(s["enabled"] for s in statuses) else "unavailable"),
        "arrivals": "live" if arrival_ok else "unavailable",
        "demand_capable": bool(arrival_ok),
        "checked_at": utcnow().isoformat(),
        "sources": statuses,
        "notes": [
            "Prices and arrivals are served by different feeds; a live price does "
            "not imply a live arrival feed.",
        ],
    }


def reset_for_tests() -> None:
    """Drop cached instances so a test can change config or env cleanly."""
    _INSTANCES.clear()


__all__ = [
    "CircuitBreaker",
    "DataGovSource",
    "EnamSource",
    "MandiApiSource",
    "MarketSource",
    "NoSourceAvailable",
    "SourceStatus",
    "SourceUnavailable",
    "annotate_freshness",
    "available_sources",
    "fetch_arrivals",
    "fetch_prices",
    "get_source",
    "market_status",
    "reset_for_tests",
    "source_status",
]