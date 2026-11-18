"""Listings router: trader offers and tool rentals.

These are the user-generated modules of the app. Unlike prices or weather
there is **no feed to pull from** - "who buys in my village" and "whose
tiller is free this week" are things only people in the area know. So every
row here is written by a real, authenticated user and the honest empty state
("nobody has posted yet") is a real state, never papered over.

Design rules from the market module carry over:

1. Reads are public, writes are owned. Anyone can browse traders and tools
   (a logged-out farmer still needs to find a buyer). Only the owner of a
   row can edit or remove it.
2. Nothing is fabricated. Pricing, crops and availability are the poster's
   own claims and the card is labelled as such; there is no rating column
   with invented stars (reviews do not exist yet, so `rating` is null and
   the app renders "New").
3. Crop names are canonicalised through the same normalizer the market
   module uses, so "pyaz" typed in search matches "Onion" and filters
   align with market prices.
"""

from __future__ import annotations

from datetime import datetime

from fastapi import APIRouter, Depends, HTTPException, Query, Request, status
from sqlalchemy.orm import Session

from .. import audit, auth_utils, models, schemas
from ..database import get_db
from ..market.normalizer import canonical_commodity

router = APIRouter(tags=["listings"])

#: Crop names that only some cards carry; used to build the chip filters.
def _crop_list(raw: str | None) -> list[str]:
    return [c for c in (raw or "").split(",") if c.strip()]


def _join_crops(crops: list[str]) -> str:
    return ",".join(dict.fromkeys(c for c in crops if c.strip()))


def _offer_out(offer: models.TraderOffer) -> schemas.TraderOfferOut:
    """Flatten an offer + its owner into the card response."""
    owner = offer.owner
    return schemas.TraderOfferOut(
        id=offer.id,
        name=owner.name,
        company=offer.company,
        location=owner.location,
        crops=_crop_list(offer.crops),
        offered_price_per_quintal=offer.offered_price_per_quintal,
        note=offer.note,
        emoji=offer.emoji or "\U0001F3EA",
        available=offer.available,
        rating=None,  # no reviews exist yet; a card never invents stars
        created_at=offer.created_at,
    )


# ------------------------------------------------------------------ traders


@router.get("/traders")
def list_traders(
    crop: str | None = Query(None, max_length=80, description="Crop name in any spelling"),
    q: str | None = Query(None, max_length=120),
    available: bool | None = Query(None),
    limit: int = Query(50, ge=1, le=200),
    db: Session = Depends(get_db),
):
    """Traders' public cards, newest first.

    `q` searches name, company, location and crops; `crop` matches the
    trading crop list. An empty result is honest: it means nobody in reachable
    data has published a card yet.
    """
    query = (
        db.query(models.TraderOffer)
        .filter(models.TraderOffer.status == "active")
        .join(models.User)
        .order_by(models.TraderOffer.created_at.desc())
    )
    if available is not None:
        query = query.filter(models.TraderOffer.available == available)
    if crop:
        canonical = canonical_commodity(crop)
        if canonical:
            query = query.filter(models.TraderOffer.crops.like(f"%{canonical}%"))
    if q:
        needle = f"%{q.strip().lower()}%"
        query = query.filter(
            (models.User.name.ilike(needle))
            | (models.TraderOffer.company.ilike(needle))
            | (models.TraderOffer.crops.ilike(needle))
            | (models.User.location.ilike(needle))
        )
    offers = query.limit(limit).all()
    return {"items": [_offer_out(o) for o in offers]}


@router.get("/traders/me", response_model=list[schemas.TraderOfferOut])
def my_offer(
    current_user: models.User = Depends(auth_utils.get_current_user),
    db: Session = Depends(get_db),
):
    """The caller's own card - a page can put it at the top or show a blank."""
    offer = db.query(models.TraderOffer).filter(models.TraderOffer.owner_id == current_user.id).first()
    return [_offer_out(offer)] if offer else []


@router.post("/traders/me", response_model=schemas.TraderOfferOut, status_code=201)
def upsert_offer(
    payload: schemas.TraderOfferCreate,
    request: Request,
    current_user: models.User = Depends(auth_utils.get_current_user),
    db: Session = Depends(get_db),
):
    """Publish or replace the caller's card in one call.

    Upsert rather than create-or-403: re-posting after an edit should not
    require remembering a nested id.
    """
    crops = [canonical_commodity(c) for c in payload.crops]
    crops = [c for c in crops if c] or [c for c in payload.crops if c.strip()]
    offer = db.query(models.TraderOffer).filter(models.TraderOffer.owner_id == current_user.id).first()
    if offer is None:
        offer = models.TraderOffer(owner_id=current_user.id)
        db.add(offer)
    offer.company = payload.company
    offer.crops = _join_crops(crops)
    offer.offered_price_per_quintal = payload.offered_price_per_quintal
    offer.note = payload.note
    offer.emoji = payload.emoji or "\U0001F3EA"
    offer.available = payload.available
    offer.status = "active"
    offer.updated_at = datetime.utcnow()
    db.commit()
    db.refresh(offer)
    audit.record_event(
        db,
        event_type=audit.EventType.listing_created,
        actor=current_user,
        entity_type="trader_offer",
        entity_id=offer.id,
        action="upsert",
        metadata={"company": offer.company, "crops": _crop_list(offer.crops)},
        **audit.request_context(request),
    )
    return _offer_out(offer)


@router.patch("/traders/me", response_model=schemas.TraderOfferOut)
def update_offer(
    payload: schemas.TraderOfferCreate,
    request: Request,
    current_user: models.User = Depends(auth_utils.get_current_user),
    db: Session = Depends(get_db),
):
    """Toggle availability / refresh fields without re-sending the card."""
    offer = db.query(models.TraderOffer).filter(models.TraderOffer.owner_id == current_user.id).first()
    if offer is None:
        raise HTTPException(status_code=404, detail="You have not published a card yet")
    return upsert_offer(payload, request, current_user, db)


@router.delete("/traders/me", status_code=204)
def retire_offer(
    request: Request,
    current_user: models.User = Depends(auth_utils.get_current_user),
    db: Session = Depends(get_db),
):
    """Take the card down (soft delete: status=hidden) without removing history."""
    offer = db.query(models.TraderOffer).filter(models.TraderOffer.owner_id == current_user.id).first()
    if offer is None:
        raise HTTPException(status_code=404, detail="You have not published a card yet")
    offer.status = "hidden"
    offer.available = False
    db.commit()
    audit.record_event(
        db,
        event_type=audit.EventType.listing_deleted,
        actor=current_user,
        entity_type="trader_offer",
        entity_id=offer.id,
        action="retire",
        metadata={"company": offer.company},
        **audit.request_context(request),
    )


# ------------------------------------------------------------------ tools


@router.get("/tools")
def list_tools(
    category: str | None = Query(None, max_length=60),
    q: str | None = Query(None, max_length=120),
    available: bool | None = Query(None),
    limit: int = Query(50, ge=1, le=200),
    db: Session = Depends(get_db),
):
    """Rentable tools, newest first. Empty is honest: none listed yet."""
    query = (
        db.query(models.ToolListing)
        .filter(models.ToolListing.status == "active")
        .order_by(models.ToolListing.created_at.desc())
    )
    if available is not None:
        query = query.filter(models.ToolListing.available == available)
    if category and category != "All":
        query = query.filter(models.ToolListing.category.ilike(f"%{category}%"))
    if q:
        needle = f"%{q.strip().lower()}%"
        query = query.filter(
            (models.ToolListing.name.ilike(needle))
            | (models.ToolListing.description.ilike(needle))
            | (models.ToolListing.location.ilike(needle))
        )
    rows = query.limit(limit).all()
    return {"items": [_tool_out(t) for t in rows]}


@router.get("/tools/{tool_id}", response_model=schemas.ToolOut)
def tool_detail(tool_id: int, db: Session = Depends(get_db)):
    tool = _get_tool_or_404(db, tool_id)
    return _tool_out(tool)


@router.post("/tools", response_model=schemas.ToolOut, status_code=201)
def create_tool(
    payload: schemas.ToolCreate,
    request: Request,
    current_user: models.User = Depends(auth_utils.get_current_user),
    db: Session = Depends(get_db),
):
    tool = models.ToolListing(
        owner_id=current_user.id,
        name=payload.name.strip(),
        emoji=payload.emoji or "\U0001FA9C",
        category=payload.category.strip() or "Other",
        description=payload.description,
        price_per_day=payload.price_per_day,
        location=payload.location,
        available=payload.available,
    )
    db.add(tool)
    db.commit()
    db.refresh(tool)
    audit.record_event(
        db,
        event_type=audit.EventType.tool_created,
        actor=current_user,
        entity_type="tool_listing",
        entity_id=tool.id,
        action="create",
        metadata={"name": tool.name, "category": tool.category},
        **audit.request_context(request),
    )
    return _tool_out(tool)


@router.patch("/tools/{tool_id}", response_model=schemas.ToolOut)
def update_tool(
    tool_id: int,
    payload: schemas.ToolUpdate,
    request: Request,
    current_user: models.User = Depends(auth_utils.get_current_user),
    db: Session = Depends(get_db),
):
    """Edit or toggle availability. Only the owner may touch their tool."""
    tool = _get_tool_or_404(db, tool_id)
    if tool.owner_id != current_user.id:
        raise HTTPException(status_code=403, detail="You can only edit your own listing")
    for field, value in payload.model_dump(exclude_unset=True).items():
        if field == "name" and value is not None:
            value = value.strip()
        setattr(tool, field, value)
    tool.updated_at = datetime.utcnow()
    db.commit()
    db.refresh(tool)
    audit.record_event(
        db,
        event_type=audit.EventType.tool_updated,
        actor=current_user,
        entity_type="tool_listing",
        entity_id=tool.id,
        action="update",
        metadata={"name": tool.name, "available": tool.available},
        **audit.request_context(request),
    )
    return _tool_out(tool)


@router.delete("/tools/{tool_id}", status_code=204)
def retire_tool(
    tool_id: int,
    request: Request,
    current_user: models.User = Depends(auth_utils.get_current_user),
    db: Session = Depends(get_db),
):
    tool = _get_tool_or_404(db, tool_id)
    if tool.owner_id != current_user.id:
        raise HTTPException(status_code=403, detail="You can only remove your own listing")
    tool.status = "hidden"
    tool.available = False
    db.commit()
    audit.record_event(
        db,
        event_type=audit.EventType.listing_deleted,
        actor=current_user,
        entity_type="tool_listing",
        entity_id=tool.id,
        action="retire",
        metadata={"name": tool.name},
        **audit.request_context(request),
    )


def _get_tool_or_404(db: Session, tool_id: int) -> models.ToolListing:
    tool = db.query(models.ToolListing).filter(models.ToolListing.id == tool_id).first()
    if tool is None or tool.status != "active":
        raise HTTPException(status_code=404, detail="Tool not found")
    return tool


def _tool_out(tool: models.ToolListing) -> schemas.ToolOut:
    return schemas.ToolOut(
        id=tool.id,
        owner=tool.owner.name if tool.owner else "Unknown",
        owner_id=tool.owner_id,
        name=tool.name,
        emoji=tool.emoji or "\U0001FA9C",
        category=tool.category or "Other",
        description=tool.description,
        price_per_day=tool.price_per_day,
        location=tool.location,
        available=tool.available,
        created_at=tool.created_at,
    )