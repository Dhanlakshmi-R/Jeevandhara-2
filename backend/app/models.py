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
    JSON,
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
    # Account status. A suspended account (is_active=False) must be rejected on
    # login and on every protected request, not merely hidden in the UI.
    is_active = Column(Boolean, nullable=False, default=True)
    # Highest admin tier. Only a superadmin may suspend other admins or read
    # audit exports. Never settable from the public register screen.
    is_superadmin = Column(Boolean, nullable=False, default=False)
    created_at = Column(DateTime, default=datetime.utcnow)

    listings = relationship("Listing", back_populates="farmer")
    crop_listings = relationship(
        "CropListing",
        back_populates="owner",
        foreign_keys="CropListing.owner_id",
    )
    marketplace_products = relationship(
        "MarketplaceProduct",
        back_populates="poster",
        foreign_keys="MarketplaceProduct.poster_id",
    )
    trader_offers = relationship(
        "TraderOffer",
        back_populates="owner",
        foreign_keys="TraderOffer.owner_id",
    )
    tool_listings = relationship(
        "ToolListing",
        back_populates="owner",
        foreign_keys="ToolListing.owner_id",
    )
    inquiries = relationship("Inquiry", back_populates="farmer")
    price_alerts = relationship("WatchlistPriceAlert", back_populates="user")
    sessions = relationship(
        "UserSession",
        back_populates="user",
        foreign_keys="UserSession.user_id",
    )


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


class TraderOffer(Base):
    """A trader's public "I am buying" card.

    User-generated content, not scraped: nothing on this card can come from a
    feed, because "who is buying in my village and at what price" is something
    only the trader knows. An empty table is therefore the truth until someone
    publishes an offer - it is never seeded with invented buyers.
    """

    __tablename__ = "trader_offers"

    id = Column(Integer, primary_key=True, index=True)
    owner_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)

    company = Column(String, nullable=True)
    # Comma-separated canonical crop names ("Onion, Tomato, Chilli"). A single
    # string keeps this a list without pulling in a JSON column or a join table
    # for what is, ultimately, a tag list on a business card.
    crops = Column(String, nullable=True)
    # What the trader says they are offering per quintal. Not verified - it is
    # the trader's own claim, and the card says so.
    offered_price_per_quintal = Column(Float, nullable=True)
    note = Column(String, nullable=True)
    emoji = Column(String, nullable=False, default="\U0001F3EA")
    available = Column(Boolean, nullable=False, default=True)
    # active | hidden - a trader can take their card down without deleting it.
    status = Column(String, nullable=False, default="active")
    created_at = Column(DateTime, nullable=False, default=datetime.utcnow)
    updated_at = Column(DateTime, nullable=False, default=datetime.utcnow)

    owner = relationship("User", back_populates="trader_offers")


class ToolListing(Base):
    """A rentable tool posted by a farmer, ready to lend or hire out.

    Like TraderOffer this is user-generated: the only source of a rental
    listing is the person who owns the tool. Pricing and availability are the
    owner's own claim, labelled as such.
    """

    __tablename__ = "tool_listings"

    id = Column(Integer, primary_key=True, index=True)
    owner_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)

    name = Column(String, nullable=False)
    emoji = Column(String, nullable=False, default="\U0001FA9C")
    category = Column(String, nullable=False, default="Other")
    description = Column(String, nullable=True)
    price_per_day = Column(Float, nullable=False)
    location = Column(String, nullable=True)
    available = Column(Boolean, nullable=False, default=True)
    status = Column(String, nullable=False, default="active")
    created_at = Column(DateTime, nullable=False, default=datetime.utcnow)
    updated_at = Column(DateTime, nullable=False, default=datetime.utcnow)

    owner = relationship("User", back_populates="tool_listings")


class CropListing(Base):
    """A farmer's "I have this to sell" posting.

    User-generated: the number that matters (what is for sale, where, at what
    expected price) is the farmer's own claim, labelled as such. `status`
    runs `active -> sold`, or `hidden` when the farmer takes it down; an
    empty table is honest until someone posts.
    """

    __tablename__ = "crop_listings"

    id = Column(Integer, primary_key=True, index=True)
    owner_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)

    # Canonical crop name when it matches the market normalizer, else the
    # farmer's own spelling.
    name = Column(String, nullable=False, index=True)
    emoji = Column(String, nullable=False, default="\U0001F33E")
    quantity = Column(Float, nullable=False)
    unit = Column(String, nullable=False, default="kg")
    # INR per unit, the farmer's own expectation, not a market quote.
    expected_price = Column(Float, nullable=True)
    location = Column(String, nullable=True)
    description = Column(String, nullable=True)
    harvest_date = Column(Date, nullable=True)

    status = Column(String, nullable=False, default="active")  # active | sold | hidden
    created_at = Column(DateTime, nullable=False, default=datetime.utcnow)
    updated_at = Column(DateTime, nullable=False, default=datetime.utcnow)

    owner = relationship("User", back_populates="crop_listings")


class MarketplaceProduct(Base):
    """A farming input listed for sale on the community marketplace.

    Same ownership rules as the other user-generated modules: a product only
    exists because someone listed it. `rating` is always NULL until real
    reviews exist - a rating column full of invented stars is exactly the
    fabrication this codebase refuses.
    """

    __tablename__ = "marketplace_products"

    id = Column(Integer, primary_key=True, index=True)
    # Nullable so a future admin/vendor row can post without a normal user.
    poster_id = Column(Integer, ForeignKey("users.id"), nullable=True, index=True)

    name = Column(String, nullable=False)
    emoji = Column(String, nullable=False, default="\U0001F6D2")
    # Seeds | Fertilizers | Pesticides | Tools | Eco-friendly
    category = Column(String, nullable=False, default="Seeds", index=True)
    price = Column(Float, nullable=False)
    unit = Column(String, nullable=False, default="pack")
    # INR per unit. Null until reviews exist.
    rating = Column(Float, nullable=True)
    in_stock = Column(Boolean, nullable=False, default=True)
    description = Column(String, nullable=True)

    status = Column(String, nullable=False, default="active")  # active | hidden
    created_at = Column(DateTime, nullable=False, default=datetime.utcnow)
    updated_at = Column(DateTime, nullable=False, default=datetime.utcnow)

    poster = relationship("User", back_populates="marketplace_products")


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


# =============================================================================
# Accountability: sessions and the audit trail
#
# Two rules drive everything below, and both are privacy rules as much as
# security ones:
#
# 1. We record WHAT a person did and WHEN, never the secret they used to do it.
#    No password, hash, OTP, token or raw request body is ever written here;
#    `app/audit.py` redacts before insert so a careless caller cannot leak one.
#
# 2. Timestamps are UTC. Display converts to IST; storage does not, because a
#    trail that means different things in different timezones is not a trail.
# =============================================================================


class UserSession(Base):
    """One signed-in session (one device / one login).

    A row is opened on login and closed on explicit logout, force-revoke or
    inactivity. An app that is merely closed leaves the row active until the
    inactivity window marks it stale and records `session_expired` - closing an
    app is not a logout and must not be recorded as one.
    """

    __tablename__ = "user_sessions"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)

    started_at = Column(DateTime, nullable=False, default=datetime.utcnow)
    last_seen_at = Column(DateTime, nullable=False, default=datetime.utcnow)
    ended_at = Column(DateTime, nullable=True)
    # logout | revoked | expired | rotation_reuse
    end_reason = Column(String, nullable=True)

    ip_address = Column(String, nullable=True)
    user_agent = Column(String, nullable=True)
    device_label = Column(String, nullable=True)
    is_active = Column(Boolean, nullable=False, default=True)

    # Phase 2 (Part B): the current refresh-token hash for this session, rotated
    # on every refresh. Null until refresh tokens are issued.
    refresh_token_hash = Column(String, nullable=True, index=True)
    refresh_token_family = Column(String, nullable=True, index=True)

    user = relationship("User", back_populates="sessions")


class AuditEvent(Base):
    """An append-only record of one thing that happened.

    `metadata` is JSON and is redacted by `app/audit.py` before it is written.
    The Python attribute is `metadata_json` because `metadata` is reserved on a
    declarative class; the physical column is still named `metadata`.
    """

    __tablename__ = "audit_events"

    id = Column(Integer, primary_key=True, index=True)

    # Null for system-generated events (retention prunes, scheduled jobs).
    actor_user_id = Column(Integer, ForeignKey("users.id"), nullable=True, index=True)
    actor_role = Column(String, nullable=True)

    event_type = Column(String, nullable=False, index=True)
    entity_type = Column(String, nullable=True, index=True)
    entity_id = Column(String, nullable=True, index=True)
    action = Column(String, nullable=True)

    summary_en = Column(String, nullable=True)
    summary_kn = Column(String, nullable=True)
    metadata_json = Column("metadata", JSON, nullable=True)

    ip_address = Column(String, nullable=True)
    user_agent = Column(String, nullable=True)
    device_label = Column(String, nullable=True)
    session_id = Column(Integer, nullable=True, index=True)

    created_at = Column(DateTime, nullable=False, default=datetime.utcnow, index=True)

    actor = relationship("User", foreign_keys=[actor_user_id])


# =============================================================================
# Admin console operations
#
# Everything below backs the administrator console (weather alerts,
# notifications, settings, reports, crop analytics, market review). Same rule as
# the rest of the schema: nothing here is seeded or invented. A weather alert or
# a broadcast only exists because an operator published it; an analytics number
# is computed from rows that were actually written.
# =============================================================================


class WeatherAlert(Base):
    """An operator-published weather warning for a region.

    This is deliberately separate from the third-party forecast feed: a feed's
    alert is a provider's claim, whereas a row here is the operator's own
    advisory, shown to farmers in the affected scope while it is active.
    """

    __tablename__ = "weather_alerts"

    id = Column(Integer, primary_key=True, index=True)
    title = Column(String, nullable=False)
    message_en = Column(String, nullable=False)
    message_kn = Column(String, nullable=True)
    # info | warning | critical — drives colour and urgency in the app.
    severity = Column(String, nullable=False, default="info", index=True)

    # all | state | district. A value is required for state/district.
    scope_type = Column(String, nullable=False, default="all", index=True)
    scope_value = Column(String, nullable=True, index=True)

    valid_from = Column(DateTime, nullable=True)
    valid_until = Column(DateTime, nullable=True)
    is_active = Column(Boolean, nullable=False, default=True, index=True)

    created_by_id = Column(Integer, ForeignKey("users.id"), nullable=True, index=True)
    created_at = Column(DateTime, nullable=False, default=datetime.utcnow)
    updated_at = Column(DateTime, nullable=False, default=datetime.utcnow)

    created_by = relationship("User", foreign_keys=[created_by_id])


class Notification(Base):
    """One broadcast an operator sent, and to whom.

    Delivery is not fanned out into per-user rows yet; what is stored is the
    message plus the audience it was resolved against and how many accounts that
    audience contained at send time. That keeps the history truthful ("sent to 42
    farmers") without inventing a delivery receipt we cannot produce.
    """

    __tablename__ = "notifications"

    id = Column(Integer, primary_key=True, index=True)
    title = Column(String, nullable=False)
    body_en = Column(String, nullable=False)
    body_kn = Column(String, nullable=True)
    # info | warning | critical
    priority = Column(String, nullable=False, default="info", index=True)

    # all | role | location | user
    audience = Column(String, nullable=False, default="all", index=True)
    # role name, location string, or user id (as text) depending on audience.
    audience_value = Column(String, nullable=True)

    recipient_count = Column(Integer, nullable=False, default=0)

    created_by_id = Column(Integer, ForeignKey("users.id"), nullable=True, index=True)
    created_at = Column(DateTime, nullable=False, default=datetime.utcnow, index=True)

    created_by = relationship("User", foreign_keys=[created_by_id])


class SoilMoistureReading(Base):
    """One reading from a soil-moisture (and optional temp/humidity) sensor.

    Device-agnostic: any board (ESP32, Arduino, etc.) that can POST JSON
    can feed this table. `device_id` identifies the physical unit; readings
    are never invented — an empty table means no sensor has reported yet.
    """

    __tablename__ = "soil_moisture_readings"

    id = Column(Integer, primary_key=True, index=True)
    device_id = Column(String, nullable=False, index=True)
    moisture_pct = Column(Float, nullable=False)
    temperature_c = Column(Float, nullable=True)
    humidity_pct = Column(Float, nullable=True)
    recorded_at = Column(DateTime, nullable=False, default=datetime.utcnow, index=True)
    created_at = Column(DateTime, nullable=False, default=datetime.utcnow)


class AppSetting(Base):
    """A single operator-editable configuration value.

    Only keys on the server-side whitelist may be written, and each is coerced
    to its declared type on read, so an operator cannot store an arbitrary blob
    or a value the app cannot interpret.
    """

    __tablename__ = "app_settings"

    id = Column(Integer, primary_key=True, index=True)
    key = Column(String, unique=True, index=True, nullable=False)
    value = Column(String, nullable=True)
    updated_by_id = Column(Integer, ForeignKey("users.id"), nullable=True)
    updated_at = Column(DateTime, nullable=False, default=datetime.utcnow)

    updated_by = relationship("User", foreign_keys=[updated_by_id])
