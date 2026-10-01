import enum
import secrets
from datetime import datetime

from sqlalchemy import Boolean, Column, Integer, String, DateTime, Enum, ForeignKey, Float
from sqlalchemy.orm import relationship

from .database import Base


class UserRole(str, enum.Enum):
    farmer = "farmer"
    trader = "trader"
    vendor = "vendor"
    admin = "admin"


class AuthProvider(str, enum.Enum):
    password = "password"
    google = "google"
    phone = "phone"


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
    phone_verified = Column(Boolean, nullable=False, default=False)
    # How this user signed up: password | google | phone. Existing rows
    # (created before this column existed) default to "password".
    auth_provider = Column(Enum(AuthProvider), nullable=False, default=AuthProvider.password)
    # Stable ID of the Google account (sub claim), used to find/re-link users.
    provider_user_id = Column(String, nullable=True, index=True)
    profile_image = Column(String, nullable=True)  # Google picture URL or uploaded avatar
    # False for users created via Google/OTP before they finish onboarding.
    profile_complete = Column(Boolean, nullable=False, default=True)
    location = Column(String, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow)

    listings = relationship("Listing", back_populates="farmer")


class OtpRequest(Base):
    """
    One row per OTP delivery attempt for a phone number. Only the bcrypt hash
    of the code is ever stored — never the plaintext code — so a DB leak does
    not expose usable OTPs. Expiry, attempt count and resend count are tracked
    per row to enforce the OTP lifecycle server-side.
    """
    __tablename__ = "otp_requests"

    id = Column(Integer, primary_key=True, index=True)
    phone = Column(String, nullable=False, index=True)  # normalized E.164 without '+'
    code_hash = Column(String, nullable=False)
    attempt_count = Column(Integer, nullable=False, default=0)
    resend_count = Column(Integer, nullable=False, default=0)
    last_sent_at = Column(DateTime, nullable=False, default=datetime.utcnow)
    expires_at = Column(DateTime, nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow)


def generate_verification_code() -> str:
    """Cryptographically random 6-digit code."""
    return f"{secrets.randbelow(1000000):06d}"


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
