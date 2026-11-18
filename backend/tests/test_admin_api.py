"""Part A3: the /admin console API and its access matrix.

Every route must be reachable only with a live admin (re-checked server-side),
the highest-risk route only with a superadmin, and nothing may ever return a
password hash.
"""

from app import audit, models
from app.auth_utils import hash_password

PASSWORD = "hunter2-strong"


def _register(client, email: str, role: str = "farmer"):
    return client.post(
        "/auth/register",
        json={"name": "Test User", "email": email, "password": PASSWORD, "role": role},
    )


def _login(client, email: str):
    return client.post("/auth/login", data={"username": email, "password": PASSWORD})


def _make_admin(db, email: str, *, superadmin: bool = False) -> models.User:
    user = models.User(
        name="Admin User",
        email=email,
        hashed_password=hash_password(PASSWORD),
        role=models.UserRole.admin,
        is_superadmin=superadmin,
        is_active=True,
        profile_complete=True,
    )
    db.add(user)
    db.commit()
    db.refresh(user)
    return user


def _admin_token(client, setup, email="boss@example.com", superadmin=False) -> str:
    db = setup.SessionLocal()
    try:
        _make_admin(db, email, superadmin=superadmin)
    finally:
        db.close()
    return _login(client, email).json()["access_token"]


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


# --------------------------------------------------------------- access guard


def test_admin_routes_require_an_admin(client, setup):
    assert client.get("/admin/overview").status_code == 401
    _register(client, "plain@example.com")
    token = _login(client, "plain@example.com").json()["access_token"]
    assert client.get("/admin/overview", headers=_auth(token)).status_code == 403


def test_admin_can_read_overview(client, setup):
    token = _admin_token(client, setup)
    _register(client, "afarmer@example.com", role="farmer")
    r = client.get("/admin/overview", headers=_auth(token))
    assert r.status_code == 200
    body = r.json()
    assert body["total_users"] >= 2
    assert body["farmers"] >= 1
    assert body["admins"] >= 1


# -------------------------------------------------------------------- users


def test_admin_users_list_and_filters(client, setup):
    token = _admin_token(client, setup)
    _register(client, "f1@example.com", role="farmer")
    _register(client, "t1@example.com", role="trader")

    all_users = client.get("/admin/users", headers=_auth(token)).json()
    assert all_users["total"] >= 3

    farmers = client.get("/admin/users?role=farmer", headers=_auth(token)).json()
    assert all(u["role"] == "farmer" for u in farmers["users"])
    assert len(farmers["users"]) >= 1

    search = client.get("/admin/users?q=t1@example.com", headers=_auth(token)).json()
    assert search["total"] == 1
    assert search["users"][0]["email"] == "t1@example.com"
    # Never leaks a credential.
    assert "hashed_password" not in search["users"][0]


def test_admin_viewing_a_user_is_recorded(client, setup):
    token = _admin_token(client, setup)
    _register(client, "looked@example.com")

    db = setup.SessionLocal()
    target = db.query(models.User).filter(models.User.email == "looked@example.com").first()
    db.close()

    r = client.get(f"/admin/users/{target.id}", headers=_auth(token))
    assert r.status_code == 200
    assert r.json()["email"] == "looked@example.com"
    assert len(_events(setup, audit.EventType.admin_viewed_user)) == 1


def test_suspend_revokes_sessions_and_blocks_access(client, setup):
    token = _admin_token(client, setup)
    _register(client, "bad@example.com")
    victim = _login(client, "bad@example.com").json()

    db = setup.SessionLocal()
    target = db.query(models.User).filter(models.User.email == "bad@example.com").first()
    sid = target.id
    db.close()

    r = client.post(f"/admin/users/{sid}/suspend", headers=_auth(token))
    assert r.status_code == 200
    assert r.json()["is_active"] is False

    # Existing token is rejected now, and a fresh login is refused.
    assert client.get("/users/me", headers=_auth(victim["access_token"])).status_code == 403
    assert _login(client, "bad@example.com").status_code == 403

    assert len(_events(setup, audit.EventType.admin_suspended_user)) == 1
    db = setup.SessionLocal()
    try:
        row = db.query(models.UserSession).filter(
            models.UserSession.user_id == sid
        ).first()
        assert row.is_active is False
        assert row.end_reason == "revoked"
    finally:
        db.close()

    # Reactivation lets them back in.
    assert client.post(f"/admin/users/{sid}/unsuspend", headers=_auth(token)).status_code == 200
    assert _login(client, "bad@example.com").status_code == 200
    assert len(_events(setup, audit.EventType.admin_unsuspended_user)) == 1


def test_admin_cannot_suspend_self(client, setup):
    token = _admin_token(client, setup)
    db = setup.SessionLocal()
    me = db.query(models.User).filter(models.User.email == "boss@example.com").first()
    me_id = me.id
    db.close()
    r = client.post(f"/admin/users/{me_id}/suspend", headers=_auth(token))
    assert r.status_code == 400


def test_only_superadmin_can_touch_another_admin(client, setup):
    boss_token = _admin_token(client, setup, "boss@example.com", superadmin=False)
    db = setup.SessionLocal()
    other = _make_admin(db, "otheradmin@example.com", superadmin=False)
    other_id = other.id
    db.close()

    assert (
        client.post(f"/admin/users/{other_id}/suspend", headers=_auth(boss_token)).status_code
        == 403
    )

    super_token = _admin_token(client, setup, "root@example.com", superadmin=True)
    assert (
        client.post(f"/admin/users/{other_id}/suspend", headers=_auth(super_token)).status_code
        == 200
    )


# ----------------------------------------------------------------- activity


def test_admin_activity_list_exposes_metadata(client, setup):
    token = _admin_token(client, setup)
    _register(client, "active@example.com")
    _login(client, "active@example.com")

    r = client.get(
        f"/admin/activity?event_type={audit.EventType.login_success}",
        headers=_auth(token),
    )
    assert r.status_code == 200
    body = r.json()
    assert body["total"] >= 1
    assert "metadata" in body["events"][0]


# ----------------------------------------------------------------- sessions


def test_admin_session_list_and_revoke(client, setup):
    token = _admin_token(client, setup)
    _register(client, "sitter@example.com")
    _login(client, "sitter@example.com")

    r = client.get("/admin/sessions", headers=_auth(token))
    assert r.status_code == 200
    rows = r.json()
    assert len(rows) >= 1
    target = next(s for s in rows if s["user_email"] == "sitter@example.com")

    assert client.delete(
        f"/admin/sessions/{target['id']}", headers=_auth(token)
    ).status_code == 200
    assert len(_events(setup, audit.EventType.admin_revoked_session)) == 1


# -------------------------------------------------------------------- stats


def test_admin_daily_stats_shape(client, setup):
    token = _admin_token(client, setup)
    r = client.get("/admin/stats/daily?days=7", headers=_auth(token))
    assert r.status_code == 200
    rows = r.json()
    assert len(rows) == 7
    assert {"date", "signups", "events"} == set(rows[0].keys())


# ------------------------------------------------------------------- export


def test_export_is_superadmin_only(client, setup):
    boss_token = _admin_token(client, setup, "boss@example.com", superadmin=False)
    assert client.get("/admin/export", headers=_auth(boss_token)).status_code == 403

    super_token = _admin_token(client, setup, "root@example.com", superadmin=True)
    r = client.get("/admin/export", headers=_auth(super_token))
    assert r.status_code == 200
    assert "events" in r.json()
    assert len(_events(setup, audit.EventType.admin_exported_audit)) == 1

    csv_resp = client.get("/admin/export?format=csv", headers=_auth(super_token))
    assert csv_resp.status_code == 200
    assert csv_resp.headers["content-type"].startswith("text/csv")
