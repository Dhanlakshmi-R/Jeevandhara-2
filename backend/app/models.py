import enum
from datetime import datetime

from sqlalchemy import Column, Integer, String, DateTime, Enum, ForeignKey, Float
from sqlalchemy.orm import relationship

from .database import Base


class UserRole(str, enum.Enum):
    farmer = "farmer"
    trader = "trader"
    vendor = "vendor"
    admin = "admin"


class User(Base):
    """
    Single users table for both farmers and traders, distinguished by `role`.
    Keeping one table (instead of separate Farmer/Trader tables) keeps auth
    simple now; role-specific fields can be added to a separate profile
    table later (e.g. FarmerProfile) without touching this table's schema.
    """
    __tablename__ = "users"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String, nullable=False)
    email = Column(String, unique=True, index=True, nullable=False)
    hashed_password = Column(String, nullable=False)
    role = Column(Enum(UserRole), nullable=False, default=UserRole.farmer)
    phone = Column(String, nullable=True)
    location = Column(String, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow)

    listings = relationship("Listing", back_populates="farmer")


class Listing(Base):
    """
    Placeholder table for Objective 5 (marketplace & rentals).
    Created now so the schema doesn't need retrofitting later, but not
    wired to any endpoints yet — that happens when Objective 5 is built.
    """
    __tablename__ = "listings"

    id = Column(Integer, primary_key=True, index=True)
    farmer_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    crop_type = Column(String, nullable=True)
    quantity = Column(Float, nullable=True)
    price = Column(Float, nullable=True)
    quality_grade = Column(String, nullable=True)  # filled in later by Objective 4's model
    status = Column(String, default="active")
    created_at = Column(DateTime, default=datetime.utcnow)

    farmer = relationship("User", back_populates="listings")
