"""Session lifecycle helpers.

A session is opened on login and closed on logout, force-revoke or inactivity.
Closing an app without logging out does *not* close a session; the inactivity
sweep marks stale sessions and records ``session_expired`` instead.
"""

from __future__ import annotations

import os
from datetime import datetime, timedelta

from sqlalchemy.orm import Session

from . import audit, models


def inactivity_minutes() -> int:
    try:
        return int(os.getenv("SESSION_INACTIVITY_MINUTES", "43200"))  # 30 days
    except ValueError:
        return 43200


def start_session(
    db: Session,
    user: models.User,
    request=None,
    *,
    commit: bool = True,
) -> models.UserSession:
    """Open a session for ``user``. Captures IP/UA/device from the request."""
    ctx = audit.request_context(request)
    session = models.UserSession(
        user_id=user.id,
        started_at=datetime.utcnow(),
        last_seen_at=datetime.utcnow(),
        ip_address=ctx["ip_address"],
        user_agent=ctx["user_agent"],
        device_label=ctx["device_label"],
        is_active=True,
    )
    db.add(session)
    if commit:
        db.commit()
        db.refresh(session)
    return session


def touch_session(db: Session, session: models.UserSession, *, commit: bool = True) -> None:
    session.last_seen_at = datetime.utcnow()
    if commit:
        db.commit()


def end_session(
    db: Session,
    session: models.UserSession,
    reason: str,
    *,
    commit: bool = True,
) -> None:
    """Close a session with the given end_reason."""
    session.is_active = False
    session.ended_at = datetime.utcnow()
    session.end_reason = reason
    session.refresh_token_hash = None
    if commit:
        db.commit()


def revoke_session(db: Session, session: models.UserSession, *, reason: str = "revoked") -> None:
    end_session(db, session, reason)


def sessions_for_user(
    db: Session,
    user_id: int,
    *,
    active_only: bool = False,
) -> list[models.UserSession]:
    query = db.query(models.UserSession).filter(models.UserSession.user_id == user_id)
    if active_only:
        query = query.filter(models.UserSession.is_active.is_(True))
    return query.order_by(models.UserSession.last_seen_at.desc()).all()


def expire_stale_sessions(db: Session, *, minutes: int | None = None, now: datetime | None = None) -> int:
    """Mark sessions inactive after the inactivity window and record the event.

    This is what distinguishes "closed the app" from "logged out": the session
    is not a logout, it expired.
    """
    window = minutes if minutes is not None else inactivity_minutes()
    cutoff = (now or datetime.utcnow()) - timedelta(minutes=window)
    stale = (
        db.query(models.UserSession)
        .filter(
            models.UserSession.is_active.is_(True),
            models.UserSession.last_seen_at < cutoff,
        )
        .all()
    )
    for session in stale:
        end_session(db, session, "expired", commit=False)
        audit.record_event(
            db,
            event_type=audit.EventType.session_expired,
            actor_role="system",
            entity_type="user_session",
            entity_id=session.id,
            session_id=session.id,
            action="expire",
            actor=None,
            metadata={"user_id": session.user_id, "last_seen_at": session.last_seen_at.isoformat()},
            commit=False,
        )
    if stale:
        db.commit()
    return len(stale)


__all__ = [
    "end_session",
    "expire_stale_sessions",
    "inactivity_minutes",
    "revoke_session",
    "sessions_for_user",
    "start_session",
    "touch_session",
]
