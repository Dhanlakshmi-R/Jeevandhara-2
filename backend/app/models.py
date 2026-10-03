import enum
import secrets
from datetime import date, datetime

from sqlalchemy import (
    Boolean,
    Column,
    Date,
    DateTime,
    Enum,
    Float,
    ForeignKey,
    Integer,
    String,
    UniqueConstraint,
)
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
    inquiries = relationship("Inquiry", back_populates="farmer")
    price_alerts = relationship("WatchlistPriceAlert", back_populates="user")


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


# =============================================================================
# Market intelligence
#
# Design rules for everything below, and the reason each field exists:
#
# 1. NO price is stored without provenance. Every row that carries a number also
#    carries `source_name`, `source_url` and `fetched_at`. A price whose origin
#    is unknown cannot be shown to a farmer with a straight face, and cannot be
#    defended when they ask where it came from.
#
# 2. Staleness is stored, not inferred. `fetched_at` plus `trade_date` lets the
#    API recompute freshness as time passes instead of freezing a verdict at
#    write time that goes quietly wrong a week later.
#
# 3. Derived values are labelled. `mandi_demand.score` is an index, not a
#    measurement; `is_derived` and `confidence` say so on every read.
# =============================================================================


class MarketPrice(Base):
    """One observation of a commodity's price at one market on one day.

    Uniqueness is (commodity, market, trade_date, variety): the same market can
    legitimately quote the same crop at different grades and varieties on the
    same day, and those are different prices for different lots.
    """

    __tablename__ = "market_prices"
    __table_args__ = (
        UniqueConstraint(
            "commodity", "market", "trade_date", "variety", name="uq_market_price_grain"
        ),
    )

    id = Column(Integer, primary_key=True, index=True)
    commodity = Column(String, nullable=False, index=True)
    variety = Column(String, nullable=True)
    grade = Column(String, nullable=True)

    state = Column(String, nullable=True, index=True)
    district = Column(String, nullable=True, index=True)
    market = Column(String, nullable=False, index=True)

    trade_date = Column(Date, nullable=False, index=True)

    # INR per quintal, normalised at write time by the normalizer. NULL is
    # meaningful: "the source did not report this bound", not zero.
    min_price = Column(Float, nullable=True)
    modal_price = Column(Float, nullable=True, index=True)
    max_price = Column(Float, nullable=True)

    arrival_quantity_quintals = Column(Float, nullable=True)
    arrival_unit = Column(String, nullable=True)

    # --- provenance, mandatory ---
    source_name = Column(String, nullable=False)
    source_url = Column(String, nullable=True)
    source_confidence = Column(String, nullable=True)  # high | medium | low
    source_verified = Column(Boolean, nullable=False, default=False)
    fetched_at = Column(DateTime, nullable=False, default=datetime.utcnow)

    # Upstream's own identifier, so a later sync can reconcile instead of
    # duplicating. Nullable: only some feeds publish one.
    upstream_id = Column(String, nullable=True)

    created_at = Column(DateTime, nullable=False, default=datetime.utcnow)

    __table_args_index__ = ("commodity", "market", "trade_date")


class CropPriceHistory(Base):
    """Daily aggregate price series per state+commodity.

    Feeds like mandi-api publish a pre-aggregated series; recomputing it from
    `market_prices` would be slow and would change as backfill happens. Storing
    the upstream series keeps the 7-day momentum and sparkline features cheap.
    """

    __tablename__ = "crop_price_history"
    __table_args__ = (
        UniqueConstraint("state", "commodity", "date", name="uq_price_history_grain"),
    )

    id = Column(Integer, primary_key=True, index=True)
    state = Column(String, nullable=False, index=True)
    commodity = Column(String, nullable=False, index=True)
    date = Column(Date, nullable=False, index=True)

    avg_min_price = Column(Float, nullable=True)
    avg_modal_price = Column(Float, nullable=True)
    avg_max_price = Column(Float, nullable=True)

    # How many market-days backed this average. Below ~3 the average is
    # misleading, so the API treats it as low confidence.
    data_points = Column(Integer, nullable=True)

    source_name = Column(String, nullable=False)
    fetched_at = Column(DateTime, nullable=False, default=datetime.utcnow)


class MandiDemand(Base):
    """A computed demand index for one mandi+commodity.

    Not a measurement. `score` is a weighted blend of whatever components could
    actually be computed, which is why `component_count` and
    `weights_used` are stored: with only two of six components available the
    score is far weaker than with all six, and a caller must be able to see that.
    """

    __tablename__ = "mandi_demand"
    __table_args__ = (
        UniqueConstraint("mandi", "commodity", "computed_for", name="uq_demand_grain"),
    )

    id = Column(Integer, primary_key=True, index=True)
    mandi = Column(String, nullable=False, index=True)
    district = Column(String, nullable=True, index=True)
    state = Column(String, nullable=True, index=True)
    commodity = Column(String, nullable=False, index=True)

    # 0-100. Higher means demand looks stronger.
    score = Column(Float, nullable=True)
    # human-readable band: strong | moderate | weak | insufficient_data
    band = Column(String, nullable=False, default="insufficient_data")

    # How many weighted components were actually computable, and what their
    # weights summed to before renormalisation. Anything less than 2 means the
    # score is not trustworthy and the API refuses to present it as advice.
    component_count = Column(Integer, nullable=False, default=0)
    weights_used = Column(Float, nullable=False, default=0.0)

    sample_size = Column(Integer, nullable=True)
    confidence = Column(String, nullable=False, default="low")

    # Provenance of the *inputs*, which is not necessarily the source that
    # published the price the user is looking at.
    source_name = Column(String, nullable=True)
    fetched_at = Column(DateTime, nullable=True)

    # The date this reading is about (latest input date), not when we computed.
    computed_for = Column(Date, nullable=False, index=True)
    created_at = Column(DateTime, nullable=False, default=datetime.utcnow)

    components = relationship(
        "MandiDemandComponent", back_populates="demand", cascade="all, delete-orphan"
    )


class MandiDemandComponent(Base):
    """One contributor to a demand reading, kept even when it contributes nothing.

    A component row with `available=False` and a reason is the audit trail for
    why the score excludes it. Without that, a 0.60-weight index silently
    presents as if it were a full one.
    """

    __tablename__ = "mandi_demand_components"
    __table_args__ = (
        UniqueConstraint("demand_id", "component", name="uq_demand_component"),
    )

    id = Column(Integer, primary_key=True, index=True)
    demand_id = Column(
        Integer, ForeignKey("mandi_demand.id", ondelete="CASCADE"), nullable=False, index=True
    )

    # price_momentum | off_take_ratio | money_turnover | stock_depletion
    # | buyer_competition | msp_premium | first_party
    component = Column(String, nullable=False, index=True)

    # The weight from the brief.
    weight = Column(Float, nullable=False)
    # The weight after renormalising across available components only.
    effective_weight = Column(Float, nullable=True)

    available = Column(Boolean, nullable=False, default=False)
    unavailable_reason = Column(String, nullable=True)

    raw_value = Column(Float, nullable=True)
    normalised_value = Column(Float, nullable=True)  # z-score
    contribution = Column(Float, nullable=True)

    sample_size = Column(Integer, nullable=True)
    explanation_en = Column(String, nullable=True)
    explanation_kn = Column(String, nullable=True)

    source_name = Column(String, nullable=True)

    demand = relationship("MandiDemand", back_populates="components")


class SourceSyncLog(Base):
    """One row per sync attempt, success or failure.

    This is how a "prices haven't updated in three days" bug gets diagnosed
    without guessing: the log says which source was tried, whether it failed,
    and with what error.
    """

    __tablename__ = "source_sync_log"

    id = Column(Integer, primary_key=True, index=True)
    source_name = Column(String, nullable=False, index=True)
    job = Column(String, nullable=False, index=True)

    ok = Column(Boolean, nullable=False, default=False)
    # Set when ok is False. Never a secret, never a full request URL with keys.
    error = Column(String, nullable=True)

    rows_fetched = Column(Integer, nullable=True)
    rows_written = Column(Integer, nullable=True)

    started_at = Column(DateTime, nullable=False, default=datetime.utcnow)
    finished_at = Column(DateTime, nullable=True)
    duration_ms = Column(Integer, nullable=True)


class Inquiry(Base):
    """A first-party signal: a farmer telling us what buyers are offering.

    This is the only demand input we own rather than scrape, which makes it the
    most trustworthy available while public sources are unavailable. It is also
    the only place the honest "not enough data" answer improves over time.
    """

    __tablename__ = "inquiries"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)

    crop_name = Column(String, nullable=False, index=True)
    quantity_quintals = Column(Float, nullable=True)
    # What buyers are offering, per the submitter. Not verified.
    expected_price = Column(Float, nullable=True)

    district = Column(String, nullable=True, index=True)
    state = Column(String, nullable=True, index=True)
    mandi = Column(String, nullable=True, index=True)

    # stored | agreed | pending | closed — the farmer's own lifecycle.
    status = Column(String, nullable=False, default="pending", index=True)
    notes = Column(String, nullable=True)

    created_at = Column(DateTime, nullable=False, default=datetime.utcnow, index=True)

    farmer = relationship("User", back_populates="inquiries")


class WatchlistPriceAlert(Base):
    """A user-triggered threshold on one commodity+mandi.

    `direction` is 'above' or 'below'; `threshold` is INR per quintal.
    Delivery is not implemented in this milestone - the table records intent so
    the notification work has something to build on.
    """

    __tablename__ = "watchlist_price_alerts"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)

    commodity = Column(String, nullable=False, index=True)
    market = Column(String, nullable=True, index=True)
    district = Column(String, nullable=True)

    direction = Column(String, nullable=False)  # above | below
    threshold = Column(Float, nullable=False)

    is_active = Column(Boolean, nullable=False, default=True)
    # Last time this alert actually fired, so we do not re-notify every sync.
    last_triggered_at = Column(DateTime, nullable=True)
    created_at = Column(DateTime, nullable=False, default=datetime.utcnow)

    user = relationship("User", back_populates="price_alerts")
