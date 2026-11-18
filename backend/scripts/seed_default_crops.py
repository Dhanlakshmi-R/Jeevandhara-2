"""Seed starter crop listings for every existing farmer account."""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from app import models, crop_seeding  # noqa: E402
from app.database import SessionLocal  # noqa: E402

db = SessionLocal()
try:
    users = db.query(models.User).filter(models.User.role == models.UserRole.farmer).all()
    total = 0
    for user in users:
        total += crop_seeding.seed_default_crops(db, user)
    print(f"Seeded {total} starter crop listings across {len(users)} farmers.")
finally:
    db.close()