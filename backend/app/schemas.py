from datetime import date, datetime

from pydantic import BaseModel, ConfigDict, EmailStr, Field
from .models import UserRole


class UserCreate(BaseModel):
    name: str
    email: EmailStr
    password: str
    role: UserRole = UserRole.farmer
    phone: str | None = None
    location: str | None = None


class UserOut(BaseModel):
    id: int
    name: str
    email: EmailStr
    role: UserRole
    phone: str | None = None
    phone_verified: bool = False
    auth_provider: str = "password"
    provider_user_id: str | None = None
    profile_image: str | None = None
    profile_complete: bool = True
    location: str | None = None

    class Config:
        from_attributes = True


class LoginRequest(BaseModel):
    email: EmailStr
    password: str


class Token(BaseModel):
    access_token: str
    token_type: str = "bearer"


class AuthResult(Token):
    """Returned by every login path (password, Google, OTP) after a successful sign-in.

    `profile_complete=False` tells the app to show the onboarding/profile-completion
    screen before entering the app (new Google/OTP users). `refresh_token` is
    null when the caller reused an existing session (profile completion), in
    which case the app keeps the refresh token it already holds.
    """
    refresh_token: str | None = None
    profile_complete: bool
    user: UserOut


class RefreshRequest(BaseModel):
    refresh_token: str


class SessionOut(BaseModel):
    """One signed-in session, shown on the "where you are signed in" screen."""

    id: int
    started_at: datetime
    last_seen_at: datetime
    ended_at: datetime | None = None
    end_reason: str | None = None
    ip_address: str | None = None
    user_agent: str | None = None
    device_label: str | None = None
    is_active: bool
    is_current: bool = False

    class Config:
        from_attributes = True


class GoogleAuthRequest(BaseModel):
    id_token: str


class OtpSendRequest(BaseModel):
    phone: str = Field(..., description="Indian mobile number, e.g. 9876543210, +919876543210 or 919876543210")


class OtpVerifyRequest(BaseModel):
    phone: str
    otp: str = Field(..., min_length=4, max_length=8)


class ProfileCompleteRequest(BaseModel):
    name: str = Field(..., min_length=2, max_length=100)
    role: UserRole = UserRole.farmer
    phone: str | None = None
    location: str | None = None
    profile_image: str | None = None


# ---------------------------------------------------------------- market


class InquiryCreate(BaseModel):
    """A farmer reporting what buyers are offering in their area.

    Tier C: created by a real person in this app, owned by them, and the only
    first-party demand input the index has while public trade feeds are down.
    """

    crop_name: str = Field(..., min_length=2, max_length=80)
    quantity_quintals: float | None = Field(None, gt=0, le=100_000)
    expected_price: float | None = Field(None, gt=0, le=10_000_000)
    district: str | None = Field(None, max_length=80)
    state: str | None = Field(None, max_length=80)
    mandi: str | None = Field(None, max_length=120)
    notes: str | None = Field(None, max_length=500)


class InquiryOut(BaseModel):
    id: int
    crop_name: str
    quantity_quintals: float | None = None
    expected_price: float | None = None
    district: str | None = None
    state: str | None = None
    mandi: str | None = None
    status: str
    notes: str | None = None
    created_at: datetime

    class Config:
        from_attributes = True


class PriceAlertCreate(BaseModel):
    commodity: str = Field(..., min_length=2, max_length=80)
    market: str | None = Field(None, max_length=120)
    district: str | None = Field(None, max_length=80)
    direction: str = Field(..., pattern="^(above|below)$")
    threshold: float = Field(..., gt=0, le=10_000_000)


class PriceAlertOut(BaseModel):
    id: int
    commodity: str
    market: str | None = None
    district: str | None = None
    direction: str
    threshold: float
    is_active: bool
    last_triggered_at: datetime | None = None
    created_at: datetime

    class Config:
        from_attributes = True


# ------------------------------------------------------------ listings


class TraderOfferCreate(BaseModel):
    """A trader's own "I am buying" card.

    Everything here is the trader's claim: price, crops and availability are
    not verified by us and the card carries that label. `crops` uses canonical
    spellings so the same names filter against market prices.
    """

    company: str | None = Field(None, max_length=120)
    crops: list[str] = Field(default_factory=list, max_length=24)
    offered_price_per_quintal: float | None = Field(None, gt=0, le=10_000_000)
    note: str | None = Field(None, max_length=500)
    emoji: str | None = Field(None, max_length=8)
    available: bool = True


class TraderOfferOut(BaseModel):
    id: int
    name: str
    company: str | None = None
    location: str | None = None
    crops: list[str] = []
    offered_price_per_quintal: float | None = None
    note: str | None = None
    emoji: str = "\U0001F3EA"
    available: bool = True
    # Real ratings need reviews, which do not exist yet; null means "no
    # rating yet", which the app renders as "New", never as a score.
    rating: float | None = None
    created_at: datetime

    class Config:
        from_attributes = True


class ToolCreate(BaseModel):
    name: str = Field(..., min_length=1, max_length=120)
    emoji: str | None = Field(None, max_length=8)
    category: str = Field("Other", max_length=60)
    description: str | None = Field(None, max_length=500)
    price_per_day: float = Field(..., gt=0, le=10_000_000)
    location: str | None = Field(None, max_length=160)
    available: bool = True


class ToolUpdate(BaseModel):
    name: str | None = Field(None, min_length=1, max_length=120)
    emoji: str | None = Field(None, max_length=8)
    category: str | None = Field(None, max_length=60)
    description: str | None = Field(None, max_length=500)
    price_per_day: float | None = Field(None, gt=0, le=10_000_000)
    location: str | None = Field(None, max_length=160)
    available: bool | None = None


class ToolOut(BaseModel):
    id: int
    owner: str
    owner_id: int
    name: str
    emoji: str = "\U0001FA9C"
    category: str = "Other"
    description: str | None = None
    price_per_day: float
    location: str | None = None
    available: bool = True
    created_at: datetime

    class Config:
        from_attributes = True


# ------------------------------------------------------------ my crops


class CropCreate(BaseModel):
    """A farmer posting "I have this to sell".

    `expected_price` is the farmer's own expectation - a claim, not a mandi
    quote - so it can be absent and the card still posts.
    """

    name: str = Field(..., min_length=2, max_length=80)
    emoji: str | None = Field(None, max_length=8)
    quantity: float = Field(..., gt=0, le=1_000_000)
    unit: str = Field("kg", max_length=20)
    expected_price: float | None = Field(None, gt=0, le=10_000_000)
    location: str | None = Field(None, max_length=160)
    description: str | None = Field(None, max_length=600)
    harvest_date: date | None = None


class CropUpdate(BaseModel):
    """Editable fields on a listing the farmer owns. `status` runs the card's
    lifecycle (active -> sold, or hidden to take it down)."""

    name: str | None = Field(None, min_length=2, max_length=80)
    emoji: str | None = Field(None, max_length=8)
    quantity: float | None = Field(None, gt=0, le=1_000_000)
    unit: str | None = Field(None, max_length=20)
    expected_price: float | None = Field(None, gt=0, le=10_000_000)
    location: str | None = Field(None, max_length=160)
    description: str | None = Field(None, max_length=600)
    harvest_date: date | None = None
    status: str | None = Field(None, pattern="^(active|sold|hidden)$")


class CropOut(BaseModel):
    id: int
    name: str
    emoji: str = "\U0001F33E"
    quantity: float
    unit: str = "kg"
    expected_price: float | None = None
    location: str | None = None
    description: str | None = None
    harvest_date: date | None = None
    status: str = "active"
    created_at: datetime

    class Config:
        from_attributes = True


# ------------------------------------------------------------ marketplace


MARKETPLACE_CATEGORIES = ("Seeds", "Fertilizers", "Pesticides", "Tools", "Eco-friendly")


class ProductCreate(BaseModel):
    """A farming input someone is offering for sale."""

    name: str = Field(..., min_length=2, max_length=120)
    emoji: str | None = Field(None, max_length=8)
    category: str = Field("Seeds", max_length=40)
    price: float = Field(..., gt=0, le=10_000_000)
    unit: str = Field("pack", max_length=20)
    in_stock: bool = True
    description: str | None = Field(None, max_length=600)


class ProductUpdate(BaseModel):
    name: str | None = Field(None, min_length=2, max_length=120)
    emoji: str | None = Field(None, max_length=8)
    category: str | None = Field(None, max_length=40)
    price: float | None = Field(None, gt=0, le=10_000_000)
    unit: str | None = Field(None, max_length=20)
    in_stock: bool | None = None
    description: str | None = Field(None, max_length=600)
    status: str | None = Field(None, pattern="^(active|hidden)$")


class ProductOut(BaseModel):
    id: int
    poster: str | None = None
    poster_id: int | None = None
    name: str
    emoji: str = "\U0001F6D2"
    category: str = "Seeds"
    price: float
    unit: str = "pack"
    # Real ratings need reviews, which do not exist yet -> always None.
    rating: float | None = None
    in_stock: bool = True
    description: str | None = None
    created_at: datetime

    class Config:
        from_attributes = True


# ------------------------------------------------------------ admin console
#
# These models back the /admin routes. `hashed_password` is deliberately absent
# from every one of them: the console shows who a user is and what they did, and
# never re-exposes a credential to the screen.


class AdminUserOut(BaseModel):
    id: int
    name: str
    email: EmailStr
    role: UserRole
    phone: str | None = None
    auth_provider: str = "password"
    location: str | None = None
    profile_complete: bool = True
    is_active: bool = True
    is_superadmin: bool = False
    created_at: datetime | None = None

    class Config:
        from_attributes = True


class AdminUserDetail(AdminUserOut):
    active_session_count: int = 0
    event_count: int = 0
    last_seen_at: datetime | None = None


class AdminUsersPage(BaseModel):
    total: int
    limit: int
    offset: int
    users: list[AdminUserOut]


class AdminOverviewOut(BaseModel):
    total_users: int
    active_users: int
    suspended_users: int
    farmers: int
    traders: int
    admins: int
    active_sessions: int
    events_today: int
    signups_today: int


class AuditEventOut(BaseModel):
    """One row of the trail. `metadata` is emitted under its real column name
    while the ORM attribute is `metadata_json` (`metadata` is reserved)."""

    model_config = ConfigDict(from_attributes=True, populate_by_name=True)

    id: int
    event_type: str
    actor_user_id: int | None = None
    actor_role: str | None = None
    entity_type: str | None = None
    entity_id: str | None = None
    action: str | None = None
    summary_en: str | None = None
    summary_kn: str | None = None
    metadata_json: dict | None = Field(default=None, serialization_alias="metadata")
    ip_address: str | None = None
    device_label: str | None = None
    session_id: int | None = None
    created_at: datetime


class AdminActivityPage(BaseModel):
    total: int
    limit: int
    offset: int
    events: list[AuditEventOut]


class AdminSessionOut(SessionOut):
    user_id: int
    user_name: str | None = None
    user_email: str | None = None


class DailyStat(BaseModel):
    date: date
    signups: int
    events: int


# =============================================================================
# Admin console — weather alerts, notifications, settings, reports, analytics,
# market review, permissions
# =============================================================================


class WeatherAlertBase(BaseModel):
    title: str = Field(..., min_length=1, max_length=160)
    message_en: str = Field(..., min_length=1, max_length=2000)
    message_kn: str | None = Field(None, max_length=2000)
    severity: str = Field("info", pattern="^(info|warning|critical)$")
    scope_type: str = Field("all", pattern="^(all|state|district)$")
    scope_value: str | None = Field(None, max_length=120)
    valid_from: datetime | None = None
    valid_until: datetime | None = None
    is_active: bool = True


class WeatherAlertCreate(WeatherAlertBase):
    pass


class WeatherAlertUpdate(BaseModel):
    title: str | None = Field(None, min_length=1, max_length=160)
    message_en: str | None = Field(None, min_length=1, max_length=2000)
    message_kn: str | None = Field(None, max_length=2000)
    severity: str | None = Field(None, pattern="^(info|warning|critical)$")
    scope_type: str | None = Field(None, pattern="^(all|state|district)$")
    scope_value: str | None = Field(None, max_length=120)
    valid_from: datetime | None = None
    valid_until: datetime | None = None
    is_active: bool | None = None


class WeatherAlertOut(WeatherAlertBase):
    model_config = ConfigDict(from_attributes=True)

    id: int
    created_by_id: int | None = None
    created_at: datetime
    updated_at: datetime


class NotificationCreate(BaseModel):
    title: str = Field(..., min_length=1, max_length=160)
    body_en: str = Field(..., min_length=1, max_length=4000)
    body_kn: str | None = Field(None, max_length=4000)
    priority: str = Field("info", pattern="^(info|warning|critical)$")
    audience: str = Field("all", pattern="^(all|role|location|user)$")
    audience_value: str | None = Field(None, max_length=160)


class NotificationOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    title: str
    body_en: str
    body_kn: str | None = None
    priority: str
    audience: str
    audience_value: str | None = None
    recipient_count: int
    created_by_id: int | None = None
    created_at: datetime


class NotificationSendResult(NotificationOut):
    """A sent notification plus the audience it was resolved against."""

    audience_summary: str


class SettingItem(BaseModel):
    key: str
    value: str | None = None
    type: str
    label: str
    default: str | None = None
    updated_at: datetime | None = None
    updated_by_id: int | None = None


class SettingsOut(BaseModel):
    settings: list[SettingItem]


class SettingsUpdate(BaseModel):
    """Map of key -> value. Unknown keys are rejected by the server."""

    values: dict[str, str | bool | int | None]


class PermissionCapability(BaseModel):
    key: str
    label: str
    description: str
    roles: list[str]


class PermissionsOut(BaseModel):
    roles: list[str]
    capabilities: list[PermissionCapability]


class ReportCount(BaseModel):
    key: str
    label: str
    count: int


class ReportSummaryOut(BaseModel):
    days: int
    generated_at: datetime
    users_total: int
    users_new: int
    events_total: int
    events_in_period: int
    crops_total: int
    crops_active: int
    marketplace_total: int
    inquiries_total: int
    price_alerts_total: int
    weather_alerts_active: int
    notifications_sent: int


class EventTypeCount(BaseModel):
    event_type: str
    count: int


class CropStat(BaseModel):
    commodity: str
    listings: int
    active_listings: int
    total_quantity: float
    avg_expected_price: float | None = None
    market_rows: int = 0
    latest_modal_price: float | None = None


class CropAnalyticsOut(BaseModel):
    days: int
    generated_at: datetime
    crops: list[CropStat]
    listings_by_status: list[ReportCount]


class CropDetailOut(BaseModel):
    commodity: str
    listings: int
    active_listings: int
    sold_listings: int
    total_quantity: float
    avg_expected_price: float | None = None
    market_rows: int
    distinct_markets: int
    latest_modal_price: float | None = None
    latest_trade_date: date | None = None
    states: list[str]


class MarketPriceAdminOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    commodity: str
    variety: str | None = None
    grade: str | None = None
    state: str | None = None
    district: str | None = None
    market: str
    trade_date: date
    min_price: float | None = None
    modal_price: float | None = None
    max_price: float | None = None
    arrival_quantity_quintals: float | None = None
    source_name: str
    source_confidence: str | None = None
    source_verified: bool
    fetched_at: datetime


class MarketSourceOut(BaseModel):
    source_name: str
    rows: int
    latest_fetch: datetime | None = None
    verified_rows: int


class ForecastPoint(BaseModel):
    date: date
    value: float


class MarketForecastOut(BaseModel):
    """A *derived* projection, clearly labelled as an estimate, never advice."""

    commodity: str
    state: str | None = None
    generated_at: datetime
    basis_points: int
    horizon_days: int
    method: str
    status: str  # ok | insufficient_data
    reason: str | None = None
    slope_per_day: float | None = None
    last_value: float | None = None
    projection: list[ForecastPoint]


class PagedMarketPrices(BaseModel):
    total: int
    limit: int
    offset: int
    items: list[MarketPriceAdminOut]
