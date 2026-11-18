"""The single place an audit event is written.

Every caller goes through :func:`record_event`. Raw ``AuditEvent`` inserts are
deliberately kept out of the routers so that one rule is enforced in one place:
**secrets never reach the trail.**

What that means concretely:

* Passwords, password hashes, OTP codes, tokens, API keys and the like are
  removed by :func:`redact` *before* the row is created, based on the key name.
  A caller that passes ``{"password": ...}`` gets ``{"password": "[redacted]"}``
  back, not a leaked credential.
* Deeper values are walked, so a nested ``{"auth": {"token": ...}}`` is caught.
* Full request bodies are never handed to this function; callers pass the few
  facts worth keeping.

Timestamps are stored UTC. Display converts to IST.
"""

from __future__ import annotations

import os
from datetime import datetime, timedelta
from typing import Any

from sqlalchemy.orm import Session

from . import models


class EventType:
    """Canonical event_type values. Never write a raw string at a call site."""

    # Authentication
    login_success = "login_success"
    login_failed = "login_failed"
    logout = "logout"
    token_refresh = "token_refresh"
    password_changed = "password_changed"
    password_reset_requested = "password_reset_requested"
    otp_requested = "otp_requested"
    otp_verified = "otp_verified"
    otp_failed = "otp_failed"
    account_locked = "account_locked"
    session_expired = "session_expired"
    token_reuse_detected = "token_reuse_detected"

    # Profile
    profile_created = "profile_created"
    profile_updated = "profile_updated"
    role_changed = "role_changed"
    place_changed = "place_changed"

    # Crops
    crop_created = "crop_created"
    crop_updated = "crop_updated"
    crop_deleted = "crop_deleted"

    # Listings
    listing_created = "listing_created"
    listing_updated = "listing_updated"
    listing_deleted = "listing_deleted"
    offer_sent = "offer_sent"
    offer_accepted = "offer_accepted"
    offer_rejected = "offer_rejected"
    deal_status_changed = "deal_status_changed"

    # Tools / rental
    tool_created = "tool_created"
    tool_updated = "tool_updated"
    booking_requested = "booking_requested"
    booking_status_changed = "booking_status_changed"

    # Market
    alert_created = "alert_created"
    alert_deleted = "alert_deleted"
    inquiry_created = "inquiry_created"

    # Admin
    admin_viewed_user = "admin_viewed_user"
    admin_suspended_user = "admin_suspended_user"
    admin_unsuspended_user = "admin_unsuspended_user"
    admin_revoked_session = "admin_revoked_session"
    admin_exported_audit = "admin_exported_audit"
    admin_created_weather_alert = "admin_created_weather_alert"
    admin_updated_weather_alert = "admin_updated_weather_alert"
    admin_deleted_weather_alert = "admin_deleted_weather_alert"
    admin_sent_notification = "admin_sent_notification"
    admin_updated_settings = "admin_updated_settings"
    admin_verified_market_price = "admin_verified_market_price"
    admin_exported_report = "admin_exported_report"

    # System
    audit_pruned = "audit_pruned"


# --- redaction ------------------------------------------------------------

_SENSITIVE_KEY_PARTS = (
    "password",
    "passwd",
    "pwd",
    "token",
    "secret",
    "otp",
    "authorization",
    "credential",
    "api_key",
    "apikey",
    "hashed",
    "hash",
    "salt",
    "cookie",
    "session_key",
)
_SENSITIVE_EXACT_KEYS = {"code", "pin", "cvv", "cvc"}

REDACTED = "[redacted]"


def _is_sensitive_key(key: str) -> bool:
    low = key.lower()
    if low in _SENSITIVE_EXACT_KEYS:
        return True
    return any(part in low for part in _SENSITIVE_KEY_PARTS)


def redact(value: Any) -> Any:
    """Return a copy of ``value`` with anything secret-looking removed.

    Recurses into dicts and lists. Non-container values pass through untouched,
    because a free-text value with no sensitive key is just data.
    """
    if isinstance(value, dict):
        return {
            k: (REDACTED if _is_sensitive_key(str(k)) else redact(v))
            for k, v in value.items()
        }
    if isinstance(value, (list, tuple)):
        return [redact(v) for v in value]
    return value


# --- request context ------------------------------------------------------

def device_label(user_agent: str | None) -> str | None:
    """A short human label for a User-Agent, e.g. "Android · Chrome"."""
    if not user_agent:
        return None
    ua = user_agent.lower()
    if "android" in ua:
        platform = "Android"
    elif "iphone" in ua or "ipad" in ua or "ios" in ua:
        platform = "iOS"
    elif "windows" in ua:
        platform = "Windows"
    elif "mac os" in ua or "macintosh" in ua:
        platform = "macOS"
    elif "linux" in ua:
        platform = "Linux"
    else:
        platform = "Unknown"

    if "edg" in ua:
        browser = "Edge"
    elif "chrome" in ua and "chromium" not in ua:
        browser = "Chrome"
    elif "firefox" in ua:
        browser = "Firefox"
    elif "safari" in ua:
        browser = "Safari"
    else:
        browser = None
    return f"{platform} · {browser}" if browser else platform


def request_context(request) -> dict[str, Any]:
    """Extract the bits of an inbound request that belong in the trail.

    Prefers ``X-Forwarded-For`` (first hop) when a proxy set it, otherwise the
    socket peer. Returns empty values when there is no request (system events).
    """
    if request is None:
        return {"ip_address": None, "user_agent": None, "device_label": None}
    ip = None
    try:
        forwarded = request.headers.get("x-forwarded-for")
        if forwarded:
            ip = forwarded.split(",")[0].strip()
        elif request.client is not None:
            ip = request.client.host
    except Exception:  # noqa: BLE001 - context is best-effort, never fatal
        ip = None
    ua = None
    try:
        ua = request.headers.get("user-agent")
    except Exception:  # noqa: BLE001
        ua = None
    return {"ip_address": ip, "user_agent": ua, "device_label": device_label(ua)}


# --- summaries (EN + KN) --------------------------------------------------

_SUMMARIES: dict[str, tuple[str, str]] = {
    EventType.login_success: ("Signed in", "ಸೈನ್ ಇನ್ ಆಗಿದ್ದಾರೆ"),
    EventType.login_failed: ("Failed sign-in attempt", "ಸೈನ್ ಇನ್ ವಿಫಲವಾಗಿದೆ"),
    EventType.logout: ("Signed out", "ಸೈನ್ ಔಟ್ ಆಗಿದ್ದಾರೆ"),
    EventType.token_refresh: ("Session refreshed", "ಅವಧಿ ನವೀಕರಿಸಲಾಗಿದೆ"),
    EventType.token_reuse_detected: (
        "Refresh token reused — session family revoked",
        "ರಿಫ್ರೆಶ್ ಟೋಕನ್ ಮರುಬಳಕೆ — ಅವಧಿ ರದ್ದುಗೊಳಿಸಲಾಗಿದೆ",
    ),
    EventType.password_changed: ("Password changed", "ಪಾಸ್ವರ್ಡ್ ಬದಲಾಗಿದೆ"),
    EventType.otp_requested: ("OTP requested", "OTP ವಿನಂತಿಸಲಾಗಿದೆ"),
    EventType.otp_verified: ("OTP verified", "OTP ಪರಿಶೀಲಿಸಲಾಗಿದೆ"),
    EventType.otp_failed: ("OTP failed", "OTP ವಿಫಲವಾಗಿದೆ"),
    EventType.account_locked: ("Account locked", "ಖಾತೆ ಲಾಕ್ ಆಗಿದೆ"),
    EventType.session_expired: ("Session expired (inactivity)", "ಅವಧಿ ಮುಗಿದಿದೆ (ನಿಷ್ಕ್ರಿಯತೆ)"),
    EventType.profile_created: ("Account created", "ಖಾತೆ ರಚಿಸಲಾಗಿದೆ"),
    EventType.profile_updated: ("Profile updated", "ಪ್ರೊಫೈಲ್ ನವೀಕರಿಸಲಾಗಿದೆ"),
    EventType.role_changed: ("Role changed", "ಪಾತ್ರ ಬದಲಾಗಿದೆ"),
    EventType.place_changed: ("Location changed", "ಸ್ಥಳ ಬದಲಾಗಿದೆ"),
    EventType.crop_created: ("Crop listed", "ಬೆಳೆ ಪಟ್ಟಿ ಮಾಡಲಾಗಿದೆ"),
    EventType.crop_updated: ("Crop updated", "ಬೆಳೆ ನವೀಕರಿಸಲಾಗಿದೆ"),
    EventType.crop_deleted: ("Crop removed", "ಬೆಳೆ ತೆಗೆದುಹಾಕಲಾಗಿದೆ"),
    EventType.listing_created: ("Listing created", "ಜಾಹೀರಾತು ರಚಿಸಲಾಗಿದೆ"),
    EventType.listing_updated: ("Listing updated", "ಜಾಹೀರಾತು ನವೀಕರಿಸಲಾಗಿದೆ"),
    EventType.listing_deleted: ("Listing removed", "ಜಾಹೀರಾತು ತೆಗೆದುಹಾಕಲಾಗಿದೆ"),
    EventType.offer_sent: ("Offer sent", "ಆಫರ್ ಕಳುಹಿಸಲಾಗಿದೆ"),
    EventType.offer_accepted: ("Offer accepted", "ಆಫರ್ ಸ್ವೀಕರಿಸಲಾಗಿದೆ"),
    EventType.offer_rejected: ("Offer rejected", "ಆಫರ್ ತಿರಸ್ಕರಿಸಲಾಗಿದೆ"),
    EventType.deal_status_changed: ("Deal status changed", "ವ್ಯವಹಾರ ಸ್ಥಿತಿ ಬದಲಾಗಿದೆ"),
    EventType.tool_created: ("Tool listed", "ಉಪಕರಣ ಪಟ್ಟಿ ಮಾಡಲಾಗಿದೆ"),
    EventType.tool_updated: ("Tool updated", "ಉಪಕರಣ ನವೀಕರಿಸಲಾಗಿದೆ"),
    EventType.booking_requested: ("Booking requested", "ಬುಕಿಂಗ್ ವಿನಂತಿಸಲಾಗಿದೆ"),
    EventType.booking_status_changed: ("Booking status changed", "ಬುಕಿಂಗ್ ಸ್ಥಿತಿ ಬದಲಾಗಿದೆ"),
    EventType.alert_created: ("Price alert created", "ಬೆಲೆ ಎಚ್ಚರಿಕೆ ರಚಿಸಲಾಗಿದೆ"),
    EventType.alert_deleted: ("Price alert removed", "ಬೆಲೆ ಎಚ್ಚರಿಕೆ ತೆಗೆದುಹಾಕಲಾಗಿದೆ"),
    EventType.inquiry_created: ("Inquiry submitted", "ವಿಚಾರಣೆ ಸಲ್ಲಿಸಲಾಗಿದೆ"),
    EventType.admin_viewed_user: ("Admin viewed a user", "ನಿರ್ವಾಹಕರು ಬಳಕೆದಾರರನ್ನು ನೋಡಿದರು"),
    EventType.admin_suspended_user: ("Admin suspended a user", "ನಿರ್ವಾಹಕರು ಬಳಕೆದಾರರನ್ನು ತಡೆಹಿಡಿದರು"),
    EventType.admin_unsuspended_user: ("Admin reactivated a user", "ನಿರ್ವಾಹಕರು ಬಳಕೆದಾರರನ್ನು ಮರುಸಕ್ರಿಯಗೊಳಿಸಿದರು"),
    EventType.admin_revoked_session: ("Admin revoked a session", "ನಿರ್ವಾಹಕರು ಅವಧಿ ರದ್ದುಗೊಳಿಸಿದರು"),
    EventType.admin_exported_audit: ("Admin exported the audit log", "ನಿರ್ವಾಹಕರು ಲೆಕ್ಕಪರಿಶೋಧನೆ ರಫ್ತು ಮಾಡಿದರು"),
    EventType.admin_created_weather_alert: ("Admin published a weather alert", "ನಿರ್ವಾಹಕರು ಹವಾಮಾನ ಎಚ್ಚರಿಕೆ ಪ್ರಕಟಿಸಿದರು"),
    EventType.admin_updated_weather_alert: ("Admin updated a weather alert", "ನಿರ್ವಾಹಕರು ಹವಾಮಾನ ಎಚ್ಚರಿಕೆ ನವೀಕರಿಸಿದರು"),
    EventType.admin_deleted_weather_alert: ("Admin removed a weather alert", "ನಿರ್ವಾಹಕರು ಹವಾಮಾನ ಎಚ್ಚರಿಕೆ ತೆಗೆದುಹಾಕಿದರು"),
    EventType.admin_sent_notification: ("Admin sent a notification", "ನಿರ್ವಾಹಕರು ಅಧಿಸೂಚನೆ ಕಳುಹಿಸಿದರು"),
    EventType.admin_updated_settings: ("Admin updated settings", "ನಿರ್ವಾಹಕರು ಸೆಟ್ಟಿಂಗ್‌ಗಳನ್ನು ನವೀಕರಿಸಿದರು"),
    EventType.admin_verified_market_price: ("Admin changed a price's verified state", "ನಿರ್ವಾಹಕರು ಬೆಲೆಯ ಪರಿಶೀಲನೆ ಸ್ಥಿತಿ ಬದಲಿಸಿದರು"),
    EventType.admin_exported_report: ("Admin exported a report", "ನಿರ್ವಾಹಕರು ವರದಿ ರಫ್ತು ಮಾಡಿದರು"),
    EventType.audit_pruned: ("Old audit events pruned", "ಹಳೆಯ ಲೆಕ್ಕಪರಿಶೋಧನೆ ದಾಖಲೆಗಳನ್ನು ಅಳಿಸಲಾಗಿದೆ"),
}


def _summary_for(event_type: str, override_en, override_kn) -> tuple[str | None, str | None]:
    en, kn = _SUMMARIES.get(event_type, (None, None))
    return (override_en or en, override_kn or kn)


# --- the one write path ---------------------------------------------------

def record_event(
    db: Session,
    *,
    event_type: str,
    actor: models.User | None = None,
    actor_role: str | None = None,
    entity_type: str | None = None,
    entity_id: Any = None,
    action: str | None = None,
    summary_en: str | None = None,
    summary_kn: str | None = None,
    metadata: dict | None = None,
    ip_address: str | None = None,
    user_agent: str | None = None,
    device_label: str | None = None,
    session_id: int | None = None,
    commit: bool = True,
) -> models.AuditEvent:
    """Create one audit row. The only supported way to write the trail.

    ``metadata`` is redacted here, so a caller cannot leak a secret even by
    mistake. A failed action should still be recorded — call this in the failure
    branch too, with the reason in ``metadata``.
    """
    role = actor_role
    if role is None and actor is not None:
        raw_role = getattr(actor, "role", None)
        role = getattr(raw_role, "value", raw_role)
    safe_metadata = redact(metadata) if metadata is not None else None
    resolved_en, resolved_kn = _summary_for(event_type, summary_en, summary_kn)

    event = models.AuditEvent(
        actor_user_id=getattr(actor, "id", None) if actor is not None else None,
        actor_role=role,
        event_type=event_type,
        entity_type=entity_type,
        entity_id=str(entity_id) if entity_id is not None else None,
        action=action,
        summary_en=resolved_en,
        summary_kn=resolved_kn,
        metadata_json=safe_metadata,
        ip_address=ip_address,
        user_agent=(user_agent[:512] if user_agent else None),
        device_label=device_label,
        session_id=session_id,
    )
    db.add(event)
    if commit:
        db.commit()
        db.refresh(event)
    return event


# --- retention ------------------------------------------------------------

def retention_days() -> int:
    try:
        return int(os.getenv("AUDIT_RETENTION_DAYS", "365"))
    except ValueError:
        return 365


def prune_audit_events(db: Session, *, days: int | None = None, now: datetime | None = None) -> int:
    """Delete events older than the retention window. Idempotent.

    A single system event is written so the prune itself is visible in the
    trail. Returns the number of events removed.
    """
    window = days if days is not None else retention_days()
    cutoff = (now or datetime.utcnow()) - timedelta(days=window)
    deleted = (
        db.query(models.AuditEvent)
        .filter(models.AuditEvent.created_at < cutoff)
        .delete(synchronize_session=False)
    )
    record_event(
        db,
        event_type=EventType.audit_pruned,
        actor=None,
        actor_role="system",
        entity_type="audit_event",
        action="prune",
        metadata={"cutoff": cutoff.isoformat(), "retention_days": window, "deleted": deleted},
    )
    return deleted


def run_audit_retention() -> dict[str, Any]:
    """Scheduler entry point: open a session, prune, close it."""
    from .database import SessionLocal

    db = SessionLocal()
    try:
        deleted = prune_audit_events(db)
        return {"job": "audit_retention", "deleted": deleted}
    finally:
        db.close()


__all__ = [
    "EventType",
    "device_label",
    "prune_audit_events",
    "record_event",
    "redact",
    "request_context",
    "retention_days",
    "run_audit_retention",
]
