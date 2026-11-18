"""My Crops router: a farmer's "what I have to sell" postings.

Rules:
1. Writes are owned. Only the logged-in farmer can create rows, and only the
   owner can edit/retire them (403 otherwise).
2. Nothing is fabricated. `expected_price` is the farmer's own expectation, a
   claim, never a mandi quote. A list with no rows is honest.
3. Crop names are sneaked through the market normalizer so "pyaz" posted
   stays canonical and chat/prices can talk about the same crop.
"""

from __future__ import annotations

from datetime import datetime

from fastapi import APIRouter, Depends, HTTPException, Request
from sqlalchemy.orm import Session

from .. import audit, auth_utils, models, schemas
from ..database import get_db
from ..market.normalizer import canonical_commodity

router = APIRouter(prefix="/my-crops", tags=["my-crops"])


def _crop_out(crop: models.CropListing) -> schemas.CropOut:
    return schemas.CropOut(
        id=crop.id,
        name=crop.name,
        emoji=crop.emoji or "\U0001F33E",
        quantity=crop.quantity,
        unit=crop.unit,
        expected_price=crop.expected_price,
        location=crop.location,
        description=crop.description,
        harvest_date=crop.harvest_date,
        status=crop.status,
        created_at=crop.created_at,
    )


@router.get("", response_model=list[schemas.CropOut])
def my_crops(
    current_user: models.User = Depends(auth_utils.get_current_user),
    db: Session = Depends(get_db),
):
    """The caller's listings, newest first. `[]` means none posted yet."""
    rows = (
        db.query(models.CropListing)
        .filter(models.CropListing.owner_id == current_user.id)
        .order_by(models.CropListing.created_at.desc())
        .all()
    )
    return [_crop_out(r) for r in rows]


@router.post("", response_model=schemas.CropOut, status_code=201)
def create_crop(
    payload: schemas.CropCreate,
    request: Request,
    current_user: models.User = Depends(auth_utils.get_current_user),
    db: Session = Depends(get_db),
):
    canonical = canonical_commodity(payload.name)
    name = canonical or payload.name.strip()
    crop = models.CropListing(
        owner_id=current_user.id,
        name=name,
        emoji=payload.emoji or "\U0001F33E",
        quantity=payload.quantity,
        unit=payload.unit or "kg",
        expected_price=payload.expected_price,
        location=payload.location or current_user.location,
        description=payload.description,
        harvest_date=payload.harvest_date,
    )
    db.add(crop)
    db.commit()
    db.refresh(crop)
    audit.record_event(
        db,
        event_type=audit.EventType.crop_created,
        actor=current_user,
        entity_type="crop_listing",
        entity_id=crop.id,
        action="create",
        metadata={"name": crop.name, "quantity": crop.quantity, "unit": crop.unit},
        **audit.request_context(request),
    )
    return _crop_out(crop)


@router.patch("/{crop_id}", response_model=schemas.CropOut)
def update_crop(
    crop_id: int,
    payload: schemas.CropUpdate,
    request: Request,
    current_user: models.User = Depends(auth_utils.get_current_user),
    db: Session = Depends(get_db),
):
    crop = _get_owned_crop(db, crop_id, current_user)
    for field, value in payload.model_dump(exclude_unset=True).items():
        if value is None:
            continue
        if field == "name":
            canonical = canonical_commodity(value)
            value = canonical or value.strip()
        setattr(crop, field, value)
    crop.updated_at = datetime.utcnow()
    db.commit()
    db.refresh(crop)
    audit.record_event(
        db,
        event_type=audit.EventType.crop_updated,
        actor=current_user,
        entity_type="crop_listing",
        entity_id=crop.id,
        action="update",
        metadata={"name": crop.name, "status": crop.status},
        **audit.request_context(request),
    )
    return _crop_out(crop)


@router.delete("/{crop_id}", status_code=204)
def retire_crop(
    crop_id: int,
    request: Request,
    current_user: models.User = Depends(auth_utils.get_current_user),
    db: Session = Depends(get_db),
):
    """Take the listing down (soft delete) without losing history."""
    crop = _get_owned_crop(db, crop_id, current_user)
    crop.status = "hidden"
    crop.updated_at = datetime.utcnow()
    db.commit()
    audit.record_event(
        db,
        event_type=audit.EventType.crop_deleted,
        actor=current_user,
        entity_type="crop_listing",
        entity_id=crop.id,
        action="delete",
        metadata={"name": crop.name},
        **audit.request_context(request),
    )


def _get_owned_crop(
    db: Session, crop_id: int, user: models.User
) -> models.CropListing:
    crop = db.query(models.CropListing).filter(models.CropListing.id == crop_id).first()
    if crop is None or crop.status == "hidden":
        raise HTTPException(status_code=404, detail="Crop listing not found")
    if crop.owner_id != user.id:
        raise HTTPException(status_code=403, detail="You can only edit your own listings")
    return crop