from datetime import date, timedelta

from . import models

DEMO_CROPS = [
    ("Onion", "\U0001F9C5", 5, "quintal", 1500, "Dharwad", 0, "active"),
    ("Tomato", "\U0001F345", 120, "kg", 35, "Dharwad", 0, "active"),
    ("Wheat", "\U0001F33E", 10, "quintal", 2350, "Hubballi", 14, "active"),
    ("Maize", "\U0001F33D", 3, "quintal", 1950, "Dharwad", 7, "sold"),
]


def seed_default_crops(db, user) -> int:
    """Give a farmer a starter set of crop listings if they have none.

    Idempotent: never overwrites or duplicates existing rows. Returns the
    number of rows created.
    """
    if getattr(user, "role", None) != models.UserRole.farmer:
        return 0
    existing = (
        db.query(models.CropListing)
        .filter(models.CropListing.owner_id == user.id)
        .count()
    )
    if existing:
        return 0

    today = date.today()
    written = 0
    for name, emoji, quantity, unit, price, location, days_until, status in DEMO_CROPS:
        crop = models.CropListing(owner_id=user.id, name=name)
        crop.emoji = emoji
        crop.quantity = quantity
        crop.unit = unit
        crop.expected_price = price
        crop.location = location
        crop.harvest_date = today + timedelta(days=days_until)
        crop.status = status
        db.add(crop)
        written += 1
    db.commit()
    return written