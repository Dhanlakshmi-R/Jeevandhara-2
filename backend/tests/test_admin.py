"""Admin role, sessions and the audit trail.

Phase 1 covers the role, the trail and logout. The `/admin/*` route matrix is
added in Phase 2 and lives in the same file.
"""

import json
from datetime import datetime, timedelta

import pytest

from app import audit, models, sessions
from app.auth_utils import decode_token, hash_password

PASSWORD = "hunter2-strong"


# ------------------------------------------------------------------ helpers


def _register(client, email: str, role: str = "farmer", password: str = PASSWORD):
    return client.post(
        "/auth/register",
        json={"name": "Test User", "email": email, "password": password, "role": role},
    )


def _login(client, email: str, password: str = PASSWORD):
    return client.post("/auth/login", data={"username": email, "password": password})


def _make_admin(db, email: str, *, superadmin: bool = False, active: bool = True) -> models.User:
    user = models.User(
        name="Admin User",
        email=email,
        hashed_password=hash_password(PASSWORD),
        role=models.UserRole.admin,
        is_superadmin=superadmin,
        is_active=active,
        profile_complete=True,
    )
    db.add(user)
    db.commit()
    db.refresh(user)
    return user


def _auth(token: str) -> dict:
    return {"Authorization": f"Bearer {token}"}


def _events(setup, event_type: str) -> list[models.AuditEvent]:
    db = setup.SessionLocal()
    try:
        return (
            db.query(models.AuditEvent)
            .filter(models.AuditEvent.event_type == event_type)
            .all()
        )
    finally:
        db.close()


# ------------------------------------------------------------- A1: the role


def test_register_refuses_admin_role(client, setup):
    r = _register(client, "sneaky@example.com", role="admin")
    assert r.status_code == 403

    db = setup.SessionLocal()
    try:
        assert db.query(models.User).filter(models.User.email == "sneaky@example.com").first() is None
    finally:
        db.close()
    assert len(_events(setup, audit.EventType.profile_created)) == 0


def test_login_token_carries_role_and_session(client, setup):
    assert _register(client, "farmer1@example.com").status_code == 201
    r = _login(client, "farmer1@example.com")
    assert r.status_code == 200
    payload = decode_token(r.json()["access_token"])
    assert payload["role"] == "farmer"
    assert payload["sid"] is not None

    db = setup.SessionLocal()
    try:
        row = db.query(models.UserSession).filter(models.UserSession.id == payload["sid"]).first()
        assert row is not None and row.is_active is True
        assert row.end_reason is None
    finally:
        db.close()


def test_admin_token_carries_admin_role(client, setup):
    db = setup.SessionLocal()
    _make_admin(db, "boss@example.com")
    db.close()
    r = _login(client, "boss@example.com")
    assert r.status_code == 200
    assert decode_token(r.json()["access_token"])["role"] == "admin"


def test_suspended_user_cannot_login(client, setup):
    assert _register(client, "suspended@example.com").status_code == 201
    db = setup.SessionLocal()
    user = db.query(models.User).filter(models.User.email == "suspended@example.com").first()
    user.is_active = False
    db.commit()
    db.close()

    r = _login(client, "suspended@example.com")
    assert r.status_code == 403
    # The refused login is still in the trail.
    failed = _events(setup, audit.EventType.login_failed)
    assert any(e.metadata_json and e.metadata_json.get("reason") == "suspended" for e in failed)


# ------------------------------------------------------- A2: the audit trail


def test_register_and_login_emit_events(client, setup):
    _register(client, "trail@example.com")
    _login(client, "trail@example.com")
    assert len(_events(setup, audit.EventType.profile_created)) == 1
    assert len(_events(setup, audit.EventType.login_success)) == 1


def test_failed_login_is_recorded(client, setup):
    _register(client, "badpw@example.com")
    r = _login(client, "badpw@example.com", password="wrong-password")
    assert r.status_code == 401
    failed = _events(setup, audit.EventType.login_failed)
    assert len(failed) == 1
    assert failed[0].metadata_json["email"] == "badpw@example.com"


def test_login_event_metadata_contains_no_secrets(client, setup):
    _register(client, "secret@example.com")
    _login(client, "secret@example.com")

    event = _events(setup, audit.EventType.login_success)[0]
    metadata = event.metadata_json or {}
    lowered = {k.lower() for k in metadata}
    assert not any("password" in k for k in lowered)
    assert not any("token" in k for k in lowered)
    assert not any("otp" in k for k in lowered)
    # The actual password never appears anywhere in the serialised event.
    assert PASSWORD not in json.dumps(metadata)


def test_redact_helper_removes_secret_keys_and_recurses():
    cleaned = audit.redact(
        {
            "password": "p",
            "token": "t",
            "otp_code": "123456",
            "nested": {"authorization": "Bearer x", "keep": 1},
            "safe": "ok",
        }
    )
    assert cleaned["password"] == audit.REDACTED
    assert cleaned["token"] == audit.REDACTED
    assert cleaned["otp_code"] == audit.REDACTED
    assert cleaned["nested"]["authorization"] == audit.REDACTED
    assert cleaned["nested"]["keep"] == 1
    assert cleaned["safe"] == "ok"


def test_crop_creation_is_audited(client, setup):
    _register(client, "cropfarmer@example.com")
    token = _login(client, "cropfarmer@example.com").json()["access_token"]
    r = client.post(
        "/my-crops",
        json={"name": "Onion", "quantity": 5, "unit": "quintal"},
        headers=_auth(token),
    )
    assert r.status_code == 201
    events = _events(setup, audit.EventType.crop_created)
    assert len(events) == 1
    assert events[0].entity_type == "crop_listing"
    assert events[0].summary_en and events[0].summary_kn


# ------------------------------------------------------------- A2: logout


def test_logout_closes_session_and_records_event(client, setup):
    _register(client, "bye@example.com")
    token = _login(client, "bye@example.com").json()["access_token"]
    sid = decode_token(token)["sid"]

    r = client.post("/auth/logout", headers=_auth(token))
    assert r.status_code == 200

    db = setup.SessionLocal()
    try:
        row = db.query(models.UserSession).filter(models.UserSession.id == sid).first()
        assert row.is_active is False
        assert row.end_reason == "logout"
        assert row.ended_at is not None
    finally:
        db.close()
    assert len(_events(setup, audit.EventType.logout)) == 1


def test_closing_app_is_not_a_logout_it_expires(client, setup):
    _register(client, "idle@example.com")
    _login(client, "idle@example.com")

    db = setup.SessionLocal()
    try:
        row = db.query(models.UserSession).first()
        row.last_seen_at = datetime.utcnow() - timedelta(days=60)
        db.commit()
        expired = sessions.expire_stale_sessions(db, minutes=30 * 24 * 60)
    finally:
        db.close()

    assert expired == 1
    # No logout event was written; an expiry event was.
    assert len(_events(setup, audit.EventType.logout)) == 0
    assert len(_events(setup, audit.EventType.session_expired)) == 1


# ------------------------------------------------------------- retention


def test_prune_removes_only_old_events(client, setup):
    db = setup.SessionLocal()
    try:
        db.add(
            models.AuditEvent(
                event_type=audit.EventType.login_success,
                created_at=datetime.utcnow() - timedelta(days=400),
            )
        )
        db.add(models.AuditEvent(event_type=audit.EventType.login_success))
        db.commit()

        removed = audit.prune_audit_events(db, days=365)
        assert removed == 1

        remaining = db.query(models.AuditEvent).all()
        assert all(e.created_at > datetime.utcnow() - timedelta(days=365) for e in remaining)
        prune_events = [e for e in remaining if e.event_type == audit.EventType.audit_pruned]
        assert len(prune_events) == 1
        assert prune_events[0].metadata_json["deleted"] == 1
    finally:
        db.close()
