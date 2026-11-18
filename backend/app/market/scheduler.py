"""Background market sync.

Refresh semantics live here so no screen has to invent its own:

======================  ==========  =====================================
Job                     Interval    What it does
======================  ==========  =====================================
prices sync             15 min      fetch -> persist -> log
arrivals sync           30 min      same, arrival chain only
demand recompute        60 min      recompute stored readings for held crops
nightly full sync       1 day 03:00 wide backfill across Karnataka
======================  ==========  =====================================

A sync never blocks a request. The scheduler runs on its own threads, and reads
go straight to the database or to the source TTL cache, so a slow upstream only
affects the job - which then records its failure in ``source_sync_log`` instead
of surfacing in a user's page load.
"""

from __future__ import annotations

import logging
import threading
import time
from typing import Any

from .. import audit, sessions
from ..database import SessionLocal
from . import service
from .sources import registry
from .sources.base import utcnow
from .sources.registry import NoSourceAvailable

logger = logging.getLogger("jeevandhara.market.scheduler")

#: Only these states are wide-synced. The vertical slice is Karnataka-first, so
#: a nightly job does not spend its budget on states nobody is looking at yet.
SYNC_STATES: tuple[str, ...] = ("Karnataka",)

#: Every crop in the alias table is a crop a screen can offer as a chip, so
#: the sync stocks all of them rather than only the ones already on screen.
#: The cap only guards against a runaway table.
_TOP_CROPS_LIMIT = 60

_scheduler = None
_lock = threading.Lock()


# ------------------------------------------------------------------- jobs

def sync_prices(state: str = SYNC_STATES[0]) -> dict[str, Any]:
    """Fetch and persist the newest prices for the crops we hold.

    Deliberately narrow: it refreshes what is already on screen instead of
    pulling a whole state we have no reader for.
    """
    return _run("prices", state=state, mode="prices")


def sync_arrivals(state: str = SYNC_STATES[0]) -> dict[str, Any]:
    """Refresh arrival quantities, which feed the arrival-trend component."""
    return _run("arrivals", state=state, mode="arrivals")


def recompute_demand() -> dict[str, Any]:
    """Recompute stored demand readings for the crops and places we hold.

    Reads what is in storage rather than fetching anything, so this job cannot
    be the reason a source gets hammered.
    """
    summary = {"job": "demand", "ok": True, "computed": 0, "skipped": 0, "errors": []}
    db = SessionLocal()
    try:
        crops = service.list_commodities(db)
        for crop in crops:
            if not crop["has_data"]:
                continue
            for place in _places_for(db, crop["commodity"]):
                try:
                    service.get_demand(
                        db,
                        commodity=crop["commodity"],
                        mandi=place.get("market"),
                        district=place.get("district"),
                        state=place.get("state"),
                        force=True,
                    )
                    summary["computed"] += 1
                except service.MarketDataUnavailable:
                    summary["skipped"] += 1
                except Exception as exc:  # noqa: BLE001 - one bad crop must not stop the rest
                    summary["errors"].append(f"{crop['commodity']}: {exc}"[:200])
                    logger.warning("demand recompute failed for %s: %s", crop["commodity"], exc)
    finally:
        db.close()
    return summary


def prune_audit() -> dict[str, Any]:
    """Delete audit events past the retention window (default 365 days)."""
    return audit.run_audit_retention()


def expire_sessions() -> dict[str, Any]:
    """Mark sessions inactive after the inactivity window and record it.

    This is the line between "logged out" and "closed the app": only the former
    is a logout, the latter shows up here as ``session_expired``.
    """
    db = SessionLocal()
    try:
        expired = sessions.expire_stale_sessions(db)
        return {"job": "session_expiry", "expired": expired}
    finally:
        db.close()


def nightly_sync() -> dict[str, Any]:
    """Wide backfill: every district in the sync states, then demand."""
    out = {"job": "nightly", "started_at": utcnow().isoformat(), "states": []}
    for state in SYNC_STATES:
        out["states"].append(_run("nightly-prices", state=state, mode="prices"))
    out["demand"] = recompute_demand()
    out["finished_at"] = utcnow().isoformat()
    return out


# ---------------------------------------------------------------- internals

def _run(job: str, *, state: str, mode: str) -> dict[str, Any]:
    """One fetch/persist/log cycle, isolated so a failure only costs a row.

    Crops are paced: the source's own call floor is what protects the upstream,
    and without a sleep that floor would reject every crop after the first -
    which is exactly how the sync used to end up holding two crops.
    """
    db = SessionLocal()
    summary: dict[str, Any] = {
        "job": job,
        "state": state,
        "ok": False,
        "rows": 0,
        "crops": 0,
        "failed": [],
        "empty": [],
        "reason": None,
    }
    crops = _crop_list(db)
    pace = registry.bulk_sync_pace()
    registry.begin_bulk_sync()
    try:
        for i, commodity in enumerate(crops):
            try:
                if mode == "arrivals":
                    rows, meta = registry.fetch_arrivals(commodity=commodity, state=state)
                    summary["rows"] += len(rows)
                    summary["crops"] += 1
                else:
                    result = service.get_prices(
                        db, commodity=commodity, state=state, limit=200
                    )
                    if (result.get("meta") or {}).get("from_storage"):
                        # Nothing upstream answered: this is storage being
                        # served to a reader, not a sync that fetched anything.
                        summary["failed"].append(commodity)
                    else:
                        summary["crops"] += 1
                        summary["rows"] += len(result["rows"])
                        if (result.get("meta") or {}).get("empty"):
                            # Answered, and the honest answer was "we do not
                            # carry this crop" - recorded so a thin harvest
                            # never gets filed as a source failure.
                            summary["empty"].append(commodity)
            except NoSourceAvailable as exc:
                summary["failed"].append(commodity)
                summary["reason"] = "; ".join(
                    f"{a['source']}: {a['reason']}" for a in exc.attempts
                )
            except Exception as exc:  # noqa: BLE001 - keep the loop alive
                summary["failed"].append(commodity)
                summary["reason"] = str(exc)[:300]
                logger.warning("sync %s/%s failed: %s", commodity, job, exc)
            if pace and i < len(crops) - 1:
                time.sleep(pace)
        summary["ok"] = summary["reason"] is None
    finally:
        registry.end_bulk_sync()
        db.close()

    logger.info(
        "market sync %s state=%s crops=%s/%s rows=%s empty=%s ok=%s %s",
        job,
        state,
        summary["crops"],
        len(crops),
        summary["rows"],
        len(summary["empty"]),
        summary["ok"],
        summary["reason"] or "",
    )
    return summary


def _crop_list(db) -> list[str]:
    """Crops worth syncing: everything already held, then the whole alias table.

    Storage first, because that is what a screen is actually showing. The alias
    table follows so a crop nobody has searched for yet is stocked before
    someone taps its chip - previously only the held crops plus three
    references were polled, which is why Tomato and Potato never arrived.
    """
    from .. import models

    from .normalizer import COMMODITY_ALIASES

    held = [
        row.commodity
        for row in db.query(models.MarketPrice.commodity).distinct().all()
        if row.commodity
    ]
    out: list[str] = []
    for name in held + list(COMMODITY_ALIASES):
        if name not in out:
            out.append(name)
    return out[:_TOP_CROPS_LIMIT]


def _places_for(db, commodity: str) -> list[dict[str, Any]]:
    from .. import models

    rows = (
        db.query(models.MarketPrice.market, models.MarketPrice.district, models.MarketPrice.state)
        .filter(models.MarketPrice.commodity == commodity)
        .distinct()
        .all()
    )
    return [
        {"market": market, "district": district, "state": state}
        for market, district, state in rows
    ]


# ---------------------------------------------------------------- lifecycle

def start() -> bool:
    """Start the scheduler if configured to run. Returns whether it started.

    ``MARKET_SCHEDULER=off`` (or any value other than ``on``) leaves it off, so
    tests and one-off scripts never start background threads that outlive the
    process.
    """
    import os

    if os.getenv("MARKET_SCHEDULER", "on").strip().lower() != "on":
        logger.info("market scheduler disabled by MARKET_SCHEDULER")
        return False

    with _lock:
        global _scheduler
        if _scheduler is not None:
            return False

        try:
            from apscheduler.schedulers.background import BackgroundScheduler
        except ImportError:
            logger.warning("APScheduler not installed; market sync will not run")
            return False

        scheduler = BackgroundScheduler(timezone="Asia/Kolkata")
        scheduler.add_job(
            sync_prices, "interval", minutes=15, id="prices", max_instances=1, coalesce=True
        )
        scheduler.add_job(
            sync_arrivals, "interval", minutes=30, id="arrivals", max_instances=1, coalesce=True
        )
        scheduler.add_job(
            recompute_demand, "interval", minutes=60, id="demand", max_instances=1, coalesce=True
        )
        scheduler.add_job(
            nightly_sync,
            "cron",
            hour=3,
            minute=0,
            id="nightly",
            max_instances=1,
            coalesce=True,
        )
        scheduler.add_job(
            prune_audit,
            "cron",
            hour=4,
            minute=15,
            id="audit_retention",
            max_instances=1,
            coalesce=True,
        )
        scheduler.add_job(
            expire_sessions,
            "interval",
            minutes=30,
            id="session_expiry",
            max_instances=1,
            coalesce=True,
        )
        scheduler.start()
        _scheduler = scheduler
        logger.info(
            "scheduler started: prices/15m arrivals/30m demand/60m nightly/03:00 "
            "audit_retention/04:15 session_expiry/30m (IST)"
        )
        return True


def stop() -> None:
    with _lock:
        global _scheduler
        if _scheduler is None:
            return
        try:
            _scheduler.shutdown(wait=False)
        except Exception:  # noqa: BLE001 - shutting down must never raise
            pass
        _scheduler = None


def is_running() -> bool:
    return _scheduler is not None and _scheduler.running


__all__ = ["is_running", "nightly_sync", "recompute_demand", "start", "stop", "sync_arrivals", "sync_prices"]
