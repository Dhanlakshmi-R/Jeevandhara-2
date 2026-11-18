"""Seed demo trader + tool listings from the REAL endpoints. Dev only.

Why this exists
---------------
Traders and tools are user-generated: the only way a card exists is a real
user creating it, so a fresh database is *honestly* empty and both screens
say "no data". That is correct in production, but during development it makes
the wiring hard to see. This script creates demo rows through the same models
and tables the API reads - they are not mocked, and never shipped as real.

THE RULES
---------
1. REFUSES TO RUN when APP_ENV == production. A copy-pasted command in the
   wrong place must fail loudly, not seed pretend buyers into a live system.
2. Rows are idempotent: re-running updates instead of duplicating.
3. The banner prints every run and the demo rows are normal rows - the script
   is the only thing that labels them demo, so grep the git history, not rows.

Usage
-----
    python scripts/seed_demo_listings.py
"""

from __future__ import annotations

import os
import sys
from datetime import date, datetime, timedelta

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from app import models  # noqa: E402
from app.auth_utils import hash_password  # noqa: E402
from app.database import SessionLocal  # noqa: E402

DEMO_EMAILS = ("demo.farmer@jeevandhara.test",)
TRAILER = "demo.trader@jeevandhara.test"
VENDOR = "demo.vendor@jeevandhara.test"

DEMO_TOOLS = [
    # name, emoji, category, description, price/day, location
    ("Power tiller", "\U0001F92F", "Tillage", "Kubota 2.8 HP, ~3 acres/day, fuel included", 800, "Dharwad"),
    ("Diesel pump", "\U0001F4A6", "Irrigation", "5 HP, pipes for 2 acres, runs on diesel", 500, "Dharwad"),
    ("Seed drill", "\U0001F331", "Sowing", "8-row, calibrated for maize and jowar", 350, "Hubballi"),
    ("Pesticide sprayer", "\U0001F41C", "Spraying", "Manual knapsack, 16 litre tank", 150, "Dharwad"),
]

# name, emoji, quantity, unit, expected price/unit, location, days-until-harvest, status
DEMO_CROPS = [
    ("Onion", "\U0001F9C5", 5, "quintal", 1500, "Dharwad", 0, "active"),
    ("Tomato", "\U0001F345", 120, "kg", 35, "Dharwad", 0, "active"),
    ("Wheat", "\U0001F33E", 10, "quintal", 2350, "Hubballi", 14, "active"),
    ("Maize", "\U0001F33D", 3, "quintal", 1950, "Dharwad", 7, "sold"),
]

# name, emoji, category, price, unit, in_stock, description
DEMO_PRODUCTS = [
    ("Hybrid Tomato Seeds", "\U0001F331", "Seeds", 180, "pack", True, "100g pack, 90% germination, BL-2040"),
    ("Potassium Sulphate", "\u2697\uFE0F", "Fertilizers", 640, "25kg bag", True, "SOP 50%, granulated, for onion and chilli"),
    ("Neem Oil Spray", "\U0001FABD", "Pesticides", 320, "1L bottle", True, "Cold-pressed neem oil, 2% EC"),
    ("Zip-It Knapsack Sprayer", "\U0001F41C", "Tools", 1899, "unit", True, "16 litre, brass nozzle, shoulder straps"),
    ("Jeevamrutha Concentrate", "\U0001F7E2", "Eco-friendly", 150, "1L bottle", True, "Cow-dung based natural fertiliser mix"),
    ("Synthetic Pesticide (Methomyl 40%)", "\u26A0\uFE0F", "Pesticides", 550, "500g pack", False, "Out of stock — restock expected next week"),
]

DEMO_CARD = {
    "email": TRAILER,
    "name": "Demo Trader",
    "company": "Shivamogga Traders",
    "crops": ["Onion", "Tomato", "Rice"],
    "offered_price_per_quintal": 4400,
    "note": "Paying cash at mandi gate. Weighing on site, no cut.",
    "emoji": "\U0001F3EA",
}


def _banner() -> None:
    print("=" * 64)
    print("  DEMO DATA SEED - DEVELOPMENT ONLY")
    print("  Creates trader/tool rows through the real API tables.")
    print("  These rows are NOT real businesses. Never deploy this.")
    print("=" * 64)


def _ensure_user(db, email: str, name: str, role: str) -> models.User:
    user = db.query(models.User).filter(models.User.email == email).first()
    if user is None:
        user = models.User(
            name=name,
            email=email,
            hashed_password=hash_password("demo-demo-demo"),
            role=models.UserRole[role],
            phone_verified=False,
            profile_complete=True,
            location="Dharwad",
        )
        db.add(user)
        db.flush()
    return user


def _sync_tools(db, owner: models.User) -> int:
    written = 0
    for name, emoji, category, description, price, location in DEMO_TOOLS:
        tool = (
            db.query(models.ToolListing)
            .filter(models.ToolListing.owner_id == owner.id, models.ToolListing.name == name)
            .first()
        )
        if tool is None:
            tool = models.ToolListing(owner_id=owner.id, name=name)
            db.add(tool)
        tool.emoji = emoji
        tool.category = category
        tool.description = description
        tool.price_per_day = price
        tool.location = location
        tool.available = True
        tool.status = "active"
        tool.updated_at = datetime.utcnow()
        written += 1
    return written


def _sync_card(db, trader: models.User) -> None:
    card = (
        db.query(models.TraderOffer).filter(models.TraderOffer.owner_id == trader.id).first()
    )
    if card is None:
        card = models.TraderOffer(owner_id=trader.id)
        db.add(card)
    card.company = DEMO_CARD["company"]
    card.crops = ",".join(DEMO_CARD["crops"])
    card.offered_price_per_quintal = DEMO_CARD["offered_price_per_quintal"]
    card.note = DEMO_CARD["note"]
    card.emoji = DEMO_CARD["emoji"]
    card.available = True
    card.status = "active"
    card.updated_at = datetime.utcnow()


def _sync_crops(db, farmer: models.User) -> int:
    written = 0
    today = date.today()
    for name, emoji, quantity, unit, price, location, days_until, status in DEMO_CROPS:
        crop = (
            db.query(models.CropListing)
            .filter(
                models.CropListing.owner_id == farmer.id,
                models.CropListing.name == name,
            )
            .first()
        )
        if crop is None:
            crop = models.CropListing(owner_id=farmer.id, name=name)
            db.add(crop)
        crop.emoji = emoji
        crop.quantity = quantity
        crop.unit = unit
        crop.expected_price = price
        crop.location = location
        crop.harvest_date = today + timedelta(days=days_until)
        crop.status = status
        crop.updated_at = datetime.utcnow()
        written += 1
    return written


def _sync_products(db, vendor: models.User) -> int:
    written = 0
    for name, emoji, category, price, unit, in_stock, description in DEMO_PRODUCTS:
        product = (
            db.query(models.MarketplaceProduct)
            .filter(
                models.MarketplaceProduct.poster_id == vendor.id,
                models.MarketplaceProduct.name == name,
            )
            .first()
        )
        if product is None:
            product = models.MarketplaceProduct(poster_id=vendor.id, name=name)
            db.add(product)
        product.emoji = emoji
        product.category = category
        product.price = price
        product.unit = unit
        product.in_stock = in_stock
        product.description = description
        product.status = "active"
        product.updated_at = datetime.utcnow()
        written += 1
    return written


def main() -> int:
    if os.getenv("APP_ENV", "development").strip().lower() == "production":
        print("REFUSED: APP_ENV=production. Demo data would look like real buyers.", file=sys.stderr)
        return 2

    _banner()
    db = SessionLocal()
    try:
        farmer = _ensure_user(db, "demo.farmer@jeevandhara.test", "Demo Farmer", "farmer")
        trader = _ensure_user(db, TRAILER, DEMO_CARD["name"], "trader")
        vendor = _ensure_user(db, VENDOR, "Demo Vendor", "vendor")
        tools = _sync_tools(db, farmer)
        crops = _sync_crops(db, farmer)
        products = _sync_products(db, vendor)
        _sync_card(db, trader)
        db.commit()
        print(f"Demo farmer tools:            {tools} tools upserted")
        print(f"Demo farmer crops:            {crops} crop listings upserted")
        print(f"Demo vendor products:         {products} marketplace products upserted")
        print("Demo trader card:             Shivamogga Traders (Onion, Tomato, Rice @ 4400/q)")
        print("Tip: browse GET /tools, /traders, /marketplace, or the app screens.")
    finally:
        db.close()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())