"""Marketplace router: community-farmed input listings.

Reads are public (a logged-out farmer still needs to find seed at a good
price). Writes are owned: the person who lists a product is the only one who
can edit or retire it. `rating` stays null until real reviews exist - a
product card never invents stars.
"""

from __future__ import annotations

from datetime import datetime

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session

from .. import auth_utils, models, schemas
from ..database import get_db

router = APIRouter(prefix="/marketplace", tags=["marketplace"])


def _product_out(p: models.MarketplaceProduct) -> schemas.ProductOut:
    return schemas.ProductOut(
        id=p.id,
        poster=p.poster.name if p.poster else None,
        poster_id=p.poster_id,
        name=p.name,
        emoji=p.emoji or "\U0001F6D2",
        category=p.category or "Seeds",
        price=p.price,
        unit=p.unit or "pack",
        rating=None,  # no reviews exist yet; never invent stars
        in_stock=p.in_stock,
        description=p.description,
        created_at=p.created_at,
    )


@router.get("")
def list_products(
    category: str | None = Query(None, max_length=40),
    q: str | None = Query(None, max_length=120),
    in_stock: bool | None = Query(None),
    limit: int = Query(50, ge=1, le=200),
    db: Session = Depends(get_db),
):
    """Active marketplace rows, newest first. Empty is honest: none listed."""
    query = (
        db.query(models.MarketplaceProduct)
        .filter(models.MarketplaceProduct.status == "active")
        .order_by(models.MarketplaceProduct.created_at.desc())
    )
    if category and category != "All":
        query = query.filter(models.MarketplaceProduct.category == category)
    if in_stock is not None:
        query = query.filter(models.MarketplaceProduct.in_stock == in_stock)
    if q:
        needle = f"%{q.strip().lower()}%"
        query = query.filter(
            (models.MarketplaceProduct.name.ilike(needle))
            | (models.MarketplaceProduct.description.ilike(needle))
        )
    rows = query.limit(limit).all()
    return {"items": [_product_out(p) for p in rows]}


@router.get("/{product_id}", response_model=schemas.ProductOut)
def product_detail(product_id: int, db: Session = Depends(get_db)):
    return _product_out(_get_product_or_404(db, product_id))


@router.post("", response_model=schemas.ProductOut, status_code=201)
def create_product(
    payload: schemas.ProductCreate,
    current_user: models.User = Depends(auth_utils.get_current_user),
    db: Session = Depends(get_db),
):
    if payload.category not in schemas.MARKETPLACE_CATEGORIES:
        raise HTTPException(
            status_code=422,
            detail=f"Category must be one of: {', '.join(schemas.MARKETPLACE_CATEGORIES)}",
        )
    product = models.MarketplaceProduct(
        poster_id=current_user.id,
        name=payload.name.strip(),
        emoji=payload.emoji or "\U0001F6D2",
        category=payload.category,
        price=payload.price,
        unit=payload.unit or "pack",
        in_stock=payload.in_stock,
        description=payload.description,
    )
    db.add(product)
    db.commit()
    db.refresh(product)
    return _product_out(product)


@router.patch("/{product_id}", response_model=schemas.ProductOut)
def update_product(
    product_id: int,
    payload: schemas.ProductUpdate,
    current_user: models.User = Depends(auth_utils.get_current_user),
    db: Session = Depends(get_db),
):
    product = _get_product_or_404(db, product_id)
    if product.poster_id != current_user.id:
        raise HTTPException(status_code=403, detail="You can only edit your own products")
    for field, value in payload.model_dump(exclude_unset=True).items():
        if value is None:
            continue
        if field == "category" and value not in schemas.MARKETPLACE_CATEGORIES:
            raise HTTPException(
                status_code=422,
                detail=f"Category must be one of: {', '.join(schemas.MARKETPLACE_CATEGORIES)}",
            )
        setattr(product, field, value)
    product.updated_at = datetime.utcnow()
    db.commit()
    db.refresh(product)
    return _product_out(product)


@router.delete("/{product_id}", status_code=204)
def retire_product(
    product_id: int,
    current_user: models.User = Depends(auth_utils.get_current_user),
    db: Session = Depends(get_db),
):
    product = _get_product_or_404(db, product_id)
    if product.poster_id != current_user.id:
        raise HTTPException(status_code=403, detail="You can only remove your own products")
    product.status = "hidden"
    product.updated_at = datetime.utcnow()
    db.commit()


def _get_product_or_404(db: Session, product_id: int) -> models.MarketplaceProduct:
    product = (
        db.query(models.MarketplaceProduct)
        .filter(models.MarketplaceProduct.id == product_id)
        .first()
    )
    if product is None or product.status != "active":
        raise HTTPException(status_code=404, detail="Product not found")
    return product