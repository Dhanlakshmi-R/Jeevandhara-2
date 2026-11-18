"""The admin console API.

Every route here is guarded by :func:`require_admin`, which re-checks the live
database on each request (claim + existence + active + still-admin), so a token
alone is never enough. The highest-risk actions (reading an audit export) demand
a superadmin.

Two rules the console keeps:

* It never returns a credential. `hashed_password` is absent from every schema.
* Reading something is an action too. Looking at a user or exporting the trail
  writes an audit event, so the admins are audited like everyone else.
"""

from __future__ import annotations

import csv
from datetime import datetime, timedelta
from io import StringIO

from fastapi import APIRouter, Depends, HTTPException, Query, Request, status
from fastapi.responses import Response
from sqlalchemy import func, or_
from sqlalchemy.orm import Session

from .. import audit, auth_utils, models, schemas, sessions
from ..database import get_db

router = APIRouter(prefix="/admin", tags=["admin"])

AdminDep = Depends(auth_utils.require_admin)
SuperadminDep = Depends(auth_utils.require_superadmin)


def _day_start(dt: datetime) -> datetime:
    return dt.replace(hour=0, minute=0, second=0, microsecond=0)


def _get_user_or_404(db: Session, user_id: int) -> models.User:
    user = db.query(models.User).filter(models.User.id == user_id).first()
    if user is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found.")
    return user


def _audited(
    db: Session,
    admin: models.User,
    request: Request,
    *,
    event_type: str,
    entity_type: str,
    entity_id,
    action: str,
    metadata: dict | None = None,
    session_id: int | None = None,
) -> None:
    audit.record_event(
        db,
        event_type=event_type,
        actor=admin,
        entity_type=entity_type,
        entity_id=entity_id,
        session_id=session_id,
        action=action,
        metadata=metadata,
        **audit.request_context(request),
    )


# ----------------------------------------------------------------- overview


@router.get("/overview", response_model=schemas.AdminOverviewOut)
def overview(
    admin: models.User = AdminDep,
    db: Session = Depends(get_db),
):
    today = _day_start(datetime.utcnow())
    users = models.User
    return schemas.AdminOverviewOut(
        total_users=db.query(users).count(),
        active_users=db.query(users).filter(users.is_active.is_(True)).count(),
        suspended_users=db.query(users).filter(users.is_active.is_(False)).count(),
        farmers=db.query(users).filter(users.role == models.UserRole.farmer).count(),
        traders=db.query(users).filter(users.role == models.UserRole.trader).count(),
        admins=db.query(users).filter(users.role == models.UserRole.admin).count(),
        active_sessions=db.query(models.UserSession)
        .filter(models.UserSession.is_active.is_(True))
        .count(),
        events_today=db.query(models.AuditEvent)
        .filter(models.AuditEvent.created_at >= today)
        .count(),
        signups_today=db.query(users).filter(users.created_at >= today).count(),
    )


# -------------------------------------------------------------------- users


@router.get("/users", response_model=schemas.AdminUsersPage)
def list_users(
    q: str | None = Query(None, max_length=120),
    role: models.UserRole | None = None,
    status_filter: str | None = Query(None, alias="status", pattern="^(active|suspended)$"),
    limit: int = Query(50, ge=1, le=200),
    offset: int = Query(0, ge=0),
    admin: models.User = AdminDep,
    db: Session = Depends(get_db),
):
    query = db.query(models.User)
    if q:
        like = f"%{q.strip()}%"
        query = query.filter(
            or_(models.User.name.ilike(like), models.User.email.ilike(like))
        )
    if role is not None:
        query = query.filter(models.User.role == role)
    if status_filter == "active":
        query = query.filter(models.User.is_active.is_(True))
    elif status_filter == "suspended":
        query = query.filter(models.User.is_active.is_(False))

    total = query.count()
    rows = (
        query.order_by(models.User.created_at.desc())
        .offset(offset)
        .limit(limit)
        .all()
    )
    return schemas.AdminUsersPage(
        total=total,
        limit=limit,
        offset=offset,
        users=[schemas.AdminUserOut.model_validate(u) for u in rows],
    )


@router.get("/users/{user_id}", response_model=schemas.AdminUserDetail)
def get_user(
    user_id: int,
    request: Request,
    admin: models.User = AdminDep,
    db: Session = Depends(get_db),
):
    user = _get_user_or_404(db, user_id)
    active_sessions = (
        db.query(models.UserSession)
        .filter(
            models.UserSession.user_id == user_id,
            models.UserSession.is_active.is_(True),
        )
        .count()
    )
    event_count = (
        db.query(models.AuditEvent)
        .filter(models.AuditEvent.actor_user_id == user_id)
        .count()
    )
    last_seen = (
        db.query(func.max(models.UserSession.last_seen_at))
        .filter(models.UserSession.user_id == user_id)
        .scalar()
    )

    # Viewing a person is itself an action and is recorded.
    _audited(
        db,
        admin,
        request,
        event_type=audit.EventType.admin_viewed_user,
        entity_type="user",
        entity_id=user.id,
        action="view",
        metadata={"email": user.email},
    )
    detail = schemas.AdminUserDetail.model_validate(user)
    detail.active_session_count = active_sessions
    detail.event_count = event_count
    detail.last_seen_at = last_seen
    return detail


@router.post("/users/{user_id}/suspend", response_model=schemas.AdminUserOut)
def suspend_user(
    user_id: int,
    request: Request,
    admin: models.User = AdminDep,
    db: Session = Depends(get_db),
):
    user = _get_user_or_404(db, user_id)
    if user.id == admin.id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="You cannot suspend your own account.",
        )
    if user.role == models.UserRole.admin and not admin.is_superadmin:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Only a superadmin can suspend an admin.",
        )

    if user.is_active:
        user.is_active = False
        # A suspension must end the person's sessions immediately, not at the
        # next token expiry.
        rows = sessions.sessions_for_user(db, user.id, active_only=True)
        for row in rows:
            sessions.end_session(db, row, "revoked", commit=False)
        db.commit()
        _audited(
            db,
            admin,
            request,
            event_type=audit.EventType.admin_suspended_user,
            entity_type="user",
            entity_id=user.id,
            action="suspend",
            metadata={"email": user.email, "revoked_sessions": len(rows)},
        )
    db.refresh(user)
    return user


@router.post("/users/{user_id}/unsuspend", response_model=schemas.AdminUserOut)
def unsuspend_user(
    user_id: int,
    request: Request,
    admin: models.User = AdminDep,
    db: Session = Depends(get_db),
):
    user = _get_user_or_404(db, user_id)
    if user.role == models.UserRole.admin and not admin.is_superadmin:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Only a superadmin can reactivate an admin.",
        )
    if not user.is_active:
        user.is_active = True
        db.commit()
        _audited(
            db,
            admin,
            request,
            event_type=audit.EventType.admin_unsuspended_user,
            entity_type="user",
            entity_id=user.id,
            action="unsuspend",
            metadata={"email": user.email},
        )
    db.refresh(user)
    return user


# ----------------------------------------------------------------- activity


@router.get("/activity", response_model=schemas.AdminActivityPage)
def activity(
    event_type: str | None = Query(None, max_length=80),
    actor_user_id: int | None = None,
    since: datetime | None = None,
    until: datetime | None = None,
    limit: int = Query(50, ge=1, le=200),
    offset: int = Query(0, ge=0),
    admin: models.User = AdminDep,
    db: Session = Depends(get_db),
):
    query = db.query(models.AuditEvent)
    if event_type:
        query = query.filter(models.AuditEvent.event_type == event_type)
    if actor_user_id is not None:
        query = query.filter(models.AuditEvent.actor_user_id == actor_user_id)
    if since is not None:
        query = query.filter(models.AuditEvent.created_at >= since)
    if until is not None:
        query = query.filter(models.AuditEvent.created_at <= until)

    total = query.count()
    rows = (
        query.order_by(models.AuditEvent.created_at.desc())
        .offset(offset)
        .limit(limit)
        .all()
    )
    return schemas.AdminActivityPage(
        total=total,
        limit=limit,
        offset=offset,
        events=[schemas.AuditEventOut.model_validate(e) for e in rows],
    )


# ----------------------------------------------------------------- sessions


@router.get("/sessions", response_model=list[schemas.AdminSessionOut])
def list_sessions(
    user_id: int | None = None,
    active_only: bool = True,
    limit: int = Query(100, ge=1, le=500),
    admin: models.User = AdminDep,
    db: Session = Depends(get_db),
):
    query = db.query(models.UserSession)
    if user_id is not None:
        query = query.filter(models.UserSession.user_id == user_id)
    if active_only:
        query = query.filter(models.UserSession.is_active.is_(True))
    rows = query.order_by(models.UserSession.last_seen_at.desc()).limit(limit).all()

    out = []
    for row in rows:
        item = schemas.AdminSessionOut.model_validate(row)
        item.user_name = row.user.name if row.user else None
        item.user_email = row.user.email if row.user else None
        out.append(item)
    return out


@router.delete("/sessions/{session_id}", status_code=status.HTTP_200_OK)
def revoke_session(
    session_id: int,
    request: Request,
    admin: models.User = AdminDep,
    db: Session = Depends(get_db),
):
    session = (
        db.query(models.UserSession).filter(models.UserSession.id == session_id).first()
    )
    if session is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Session not found.")
    if session.is_active:
        sessions.end_session(db, session, "revoked", commit=False)
        _audited(
            db,
            admin,
            request,
            event_type=audit.EventType.admin_revoked_session,
            entity_type="user_session",
            entity_id=session.id,
            session_id=session.id,
            action="revoke",
            metadata={"user_id": session.user_id},
        )
        db.commit()
    return {"status": "ok", "message": "Session revoked."}


# -------------------------------------------------------------------- stats


@router.get("/stats/daily", response_model=list[schemas.DailyStat])
def stats_daily(
    days: int = Query(14, ge=1, le=90),
    admin: models.User = AdminDep,
    db: Session = Depends(get_db),
):
    today = datetime.utcnow().date()
    start = today - timedelta(days=days - 1)
    start_dt = datetime.combine(start, datetime.min.time())

    signup_rows = (
        db.query(func.date(models.User.created_at), func.count(models.User.id))
        .filter(models.User.created_at >= start_dt)
        .group_by(func.date(models.User.created_at))
        .all()
    )
    event_rows = (
        db.query(func.date(models.AuditEvent.created_at), func.count(models.AuditEvent.id))
        .filter(models.AuditEvent.created_at >= start_dt)
        .group_by(func.date(models.AuditEvent.created_at))
        .all()
    )
    signups = {str(d): c for d, c in signup_rows}
    events = {str(d): c for d, c in event_rows}

    return [
        schemas.DailyStat(
            date=start + timedelta(days=i),
            signups=signups.get((start + timedelta(days=i)).isoformat(), 0),
            events=events.get((start + timedelta(days=i)).isoformat(), 0),
        )
        for i in range(days)
    ]


# ------------------------------------------------------------------- export
# The one route reserved for the highest tier, because it lifts the whole trail
# out of the system in one go.


@router.get("/export")
def export_audit(
    request: Request,
    format: str = Query("json", pattern="^(json|csv)$"),
    limit: int = Query(5000, ge=1, le=50000),
    admin: models.User = SuperadminDep,
    db: Session = Depends(get_db),
):
    rows = (
        db.query(models.AuditEvent)
        .order_by(models.AuditEvent.created_at.desc())
        .limit(limit)
        .all()
    )
    _audited(
        db,
        admin,
        request,
        event_type=audit.EventType.admin_exported_audit,
        entity_type="audit_event",
        entity_id=None,
        action="export",
        metadata={"format": format, "count": len(rows)},
    )

    if format == "csv":
        buffer = StringIO()
        writer = csv.writer(buffer)
        writer.writerow(
            [
                "id",
                "created_at",
                "event_type",
                "actor_user_id",
                "actor_role",
                "entity_type",
                "entity_id",
                "action",
                "summary_en",
                "summary_kn",
                "ip_address",
                "device_label",
                "session_id",
                "metadata",
            ]
        )
        for e in rows:
            writer.writerow(
                [
                    e.id,
                    e.created_at.isoformat() if e.created_at else "",
                    e.event_type,
                    e.actor_user_id,
                    e.actor_role,
                    e.entity_type,
                    e.entity_id,
                    e.action,
                    e.summary_en,
                    e.summary_kn,
                    e.ip_address,
                    e.device_label,
                    e.session_id,
                    e.metadata_json,
                ]
            )
        return Response(
            content=buffer.getvalue(),
            media_type="text/csv",
            headers={"Content-Disposition": "attachment; filename=audit_export.csv"},
        )

    return {
        "exported_at": datetime.utcnow().isoformat(),
        "count": len(rows),
        "events": [schemas.AuditEventOut.model_validate(e) for e in rows],
    }
