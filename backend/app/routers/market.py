"""Market router.

Public reads (prices, history, commodities, mandis, demand, status) are open
because a price is public information and a logged-out farmer should still see
it. Anything that writes a row owned by a person - inquiries and alerts - is
authenticated and scoped to the caller, so one user cannot read or delete
another's.

Every failure path returns the per-source reasons rather than a bare 503: the
UI needs "data.gov.in has no API key" and "eNAM returned HTTP 500" to look
different, because the honest empty state says something different for each.
"""

from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException, Query, Request, status
from sqlalchemy.orm import Session

from .. import audit, auth_utils, models, schemas
from ..database import get_db
from ..market import service
from ..market.normalizer import canonical_commodity, normalize_state
from ..market.service import MarketDataUnavailable, SellAdviceUnavailable
from ..market.sources.registry import NoSourceAvailable

router = APIRouter(prefix="/market", tags=["market"])


# ------------------------------------------------------------------ errors

def _unavailable(exc: MarketDataUnavailable) -> HTTPException:
    """503 with the reasons, because 'no data' and 'no source' differ."""
    return HTTPException(
        status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
        detail=exc.as_dict(),
    )


# ------------------------------------------------------------------ prices

@router.get("/prices")
def prices(
    commodity: str = Query(..., min_length=1, max_length=80, description="Crop name in any spelling, e.g. Onion / Pyaz"),
    state: str | None = Query(None, max_length=60),
    district: str | None = Query(None, max_length=60),
    market: str | None = Query(None, max_length=120),
    date: str | None = Query(None, max_length=32, description="YYYY-MM-DD, or omit for the newest"),
    limit: int = Query(200, ge=1, le=1000),
    db: Session = Depends(get_db),
):
    """Latest quotations for one crop, each row carrying its own provenance.

    Freshness in every row's `_provenance` is derived from that row's market
    date, not from when we fetched it - so a fast fetch of last week's rates
    still reads as stale.
    """
    try:
        return service.get_prices(
            db,
            commodity=commodity,
            state=state,
            district=district,
            market=market,
            date=date,
            limit=limit,
        )
    except MarketDataUnavailable as exc:
        raise _unavailable(exc) from exc


@router.get("/prices/history")
def price_history(
    commodity: str = Query(..., min_length=1, max_length=80),
    state: str = Query(..., min_length=1, max_length=60),
    days: int = Query(90, ge=7, le=365),
    db: Session = Depends(get_db),
):
    """Daily average modal price series for the sparkline and 7-day momentum."""
    try:
        return service.get_history(db, commodity=commodity, state=state, days=days)
    except NoSourceAvailable as exc:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail={"message": str(exc), "attempts": exc.attempts},
        ) from exc


# -------------------------------------------------------------- reference

@router.get("/commodities")
def commodities(db: Session = Depends(get_db)):
    """Crops we can answer for, with the aliases that resolve to each."""
    return {"items": service.list_commodities(db)}


@router.get("/mandis")
def mandis(
    state: str | None = Query(None, max_length=60),
    db: Session = Depends(get_db),
):
    """Mandis we can quote, with district and whether we hold rows for them."""
    return {"items": service.list_mandis(db, state=state)}


@router.get("/districts")
def districts(
    state: str | None = Query(None, max_length=60),
    db: Session = Depends(get_db),
):
    return {"items": service.list_districts(db, state=state)}


# ----------------------------------------------------------------- demand

@router.get("/demand")
def demand(
    commodity: str = Query(..., min_length=1, max_length=80),
    mandi: str | None = Query(None, max_length=120),
    district: str | None = Query(None, max_length=60),
    state: str | None = Query(None, max_length=60),
    force: bool = Query(False, description="Recompute instead of reusing the stored reading"),
    db: Session = Depends(get_db),
):
    """Demand index for one crop in one place, with its full breakdown.

    Always labelled derived. Components that could not be computed come back
    under `omitted` with a reason; they are never given a stand-in value.
    """
    try:
        return service.get_demand(
            db, commodity=commodity, mandi=mandi, district=district, state=state, force=force
        )
    except MarketDataUnavailable as exc:
        raise _unavailable(exc) from exc


@router.get("/demand/top")
def demand_top(
    commodity: str = Query(..., min_length=1, max_length=80),
    state: str | None = Query(None, max_length=60),
    district: str | None = Query(None, max_length=60),
    limit: int = Query(10, ge=1, le=50),
    db: Session = Depends(get_db),
):
    """Best mandis for a crop. Mandis we could not score are listed separately."""
    try:
        return service.get_demand_top(
            db, commodity=commodity, state=state, district=district, limit=limit
        )
    except MarketDataUnavailable as exc:
        raise _unavailable(exc) from exc


# ------------------------------------------------------------- sell advice

@router.get("/sell-advice")
def sell_advice(
    commodity: str = Query(..., min_length=1, max_length=80),
    quantity_quintals: float = Query(..., gt=0, le=100_000),
    district: str | None = Query(None, max_length=60),
    state: str | None = Query(None, max_length=60),
    db: Session = Depends(get_db),
):
    """Best mandi to sell at today, or a stated reason why we cannot say.

    Refuses rather than guessing when no actionable price exists: a farmer may
    act on this, so a stale recommendation is worse than none.
    """
    try:
        return service.sell_advice(
            db,
            commodity=commodity,
            quantity_quintals=quantity_quintals,
            district=district,
            state=state,
        )
    except SellAdviceUnavailable as exc:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail={"reason": exc.reason, **exc.details},
        ) from exc
    except MarketDataUnavailable as exc:
        raise _unavailable(exc) from exc


# ----------------------------------------------------------------- status

@router.get("/status")
def status_endpoint():
    """Per-source health: which feeds are live, verified, and what that means."""
    return service.market_status()


# -------------------------------------------------- first-party endpoints

@router.post("/inquiry", response_model=schemas.InquiryOut, status_code=status.HTTP_201_CREATED)
def create_inquiry(
    body: schemas.InquiryCreate,
    request: Request,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(auth_utils.get_current_user),
):
    """Record what a farmer's buyers are offering.

    Tier C, owned by the caller. This is the one demand input we own rather
    than scrape, so it is the one that keeps working when every public feed is
    down.
    """
    crop = canonical_commodity(body.crop_name)
    row = models.Inquiry(
        user_id=current_user.id,
        crop_name=crop,
        quantity_quintals=body.quantity_quintals,
        expected_price=body.expected_price,
        district=body.district,
        state=normalize_state(body.state) if body.state else None,
        mandi=body.mandi,
        notes=body.notes,
    )
    db.add(row)
    db.commit()
    db.refresh(row)
    audit.record_event(
        db,
        event_type=audit.EventType.inquiry_created,
        actor=current_user,
        entity_type="inquiry",
        entity_id=row.id,
        action="create",
        metadata={"crop": row.crop_name, "state": row.state, "district": row.district},
        **audit.request_context(request),
    )
    return row


@router.get("/inquiries", response_model=list[schemas.InquiryOut])
def list_inquiries(
    db: Session = Depends(get_db),
    current_user: models.User = Depends(auth_utils.get_current_user),
):
    """Only the caller's own inquiries. Ownership is not optional."""
    rows = (
        db.query(models.Inquiry)
        .filter(models.Inquiry.user_id == current_user.id)
        .order_by(models.Inquiry.created_at.desc())
        .all()
    )
    return rows


@router.delete("/inquiries/{inquiry_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_inquiry(
    inquiry_id: int,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(auth_utils.get_current_user),
):
    row = (
        db.query(models.Inquiry)
        .filter(models.Inquiry.id == inquiry_id, models.Inquiry.user_id == current_user.id)
        .first()
    )
    if row is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="inquiry not found")
    db.delete(row)
    db.commit()


@router.post("/alerts", response_model=schemas.PriceAlertOut, status_code=status.HTTP_201_CREATED)
def create_alert(
    body: schemas.PriceAlertCreate,
    request: Request,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(auth_utils.get_current_user),
):
    row = models.WatchlistPriceAlert(
        user_id=current_user.id,
        commodity=canonical_commodity(body.commodity),
        market=body.market,
        district=body.district,
        direction=body.direction,
        threshold=body.threshold,
    )
    db.add(row)
    db.commit()
    db.refresh(row)
    audit.record_event(
        db,
        event_type=audit.EventType.alert_created,
        actor=current_user,
        entity_type="price_alert",
        entity_id=row.id,
        action="create",
        metadata={"commodity": row.commodity, "direction": row.direction},
        **audit.request_context(request),
    )
    return row


@router.get("/alerts", response_model=list[schemas.PriceAlertOut])
def list_alerts(
    db: Session = Depends(get_db),
    current_user: models.User = Depends(auth_utils.get_current_user),
):
    rows = (
        db.query(models.WatchlistPriceAlert)
        .filter(models.WatchlistPriceAlert.user_id == current_user.id)
        .order_by(models.WatchlistPriceAlert.created_at.desc())
        .all()
    )
    return rows


@router.delete("/alerts/{alert_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_alert(
    alert_id: int,
    request: Request,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(auth_utils.get_current_user),
):
    row = (
        db.query(models.WatchlistPriceAlert)
        .filter(
            models.WatchlistPriceAlert.id == alert_id,
            models.WatchlistPriceAlert.user_id == current_user.id,
        )
        .first()
    )
    if row is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="alert not found")
    db.delete(row)
    db.commit()
    audit.record_event(
        db,
        event_type=audit.EventType.alert_deleted,
        actor=current_user,
        entity_type="price_alert",
        entity_id=alert_id,
        action="delete",
        metadata={"commodity": row.commodity},
        **audit.request_context(request),
    )
