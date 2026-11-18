"""Part B5: refresh-token rotation, reuse detection and the device list.

The security property under test: a refresh token is single-use. The first
exchange rotates it; replaying the old one is treated as theft, revokes the
session, and is recorded as `token_reuse_detected`.
"""

from app import audit, models
from app.auth_utils import decode_token

PASSWORD = "hunter2-strong"


def _register(client, email: str, role: str = "farmer"):
    return client.post(
        "/auth/register",
        json={"name": "Test User", "email": email, "password": PASSWORD, "role": role},
    )


def _login(client, email: str):
    return client.post("/auth/login", data={"username": email, "password": PASSWORD})


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


def test_login_returns_a_refresh_token(client, setup):
    _register(client, "refresh1@example.com")
    body = _login(client, "refresh1@example.com").json()
    assert body["refresh_token"]
    payload = decode_token(body["refresh_token"], expected_type="refresh")
    assert payload["sid"] is not None
    assert payload["family"]


def test_refresh_rotates_and_replay_is_detected(client, setup):
    _register(client, "refresh2@example.com")
    first = _login(client, "refresh2@example.com").json()
    old_refresh = first["refresh_token"]

    r = client.post("/auth/refresh", json={"refresh_token": old_refresh})
    assert r.status_code == 200
    rotated = r.json()
    assert rotated["refresh_token"] and rotated["refresh_token"] != old_refresh
    # The new access token actually works.
    me = client.get("/users/me", headers=_auth(rotated["access_token"]))
    assert me.status_code == 200

    # Replaying the already-rotated token is theft: 401 + session revoked.
    replay = client.post("/auth/refresh", json={"refresh_token": old_refresh})
    assert replay.status_code == 401
    assert len(_events(setup, audit.EventType.token_reuse_detected)) == 1

    # The session is now dead, so even the newest token no longer works.
    dead = client.post("/auth/refresh", json={"refresh_token": rotated["refresh_token"]})
    assert dead.status_code == 401

    db = setup.SessionLocal()
    try:
        session = db.query(models.UserSession).first()
        assert session.is_active is False
        assert session.end_reason == "rotation_reuse"
    finally:
        db.close()


def test_refresh_rejects_an_access_token(client, setup):
    _register(client, "refresh3@example.com")
    access = _login(client, "refresh3@example.com").json()["access_token"]
    r = client.post("/auth/refresh", json={"refresh_token": access})
    assert r.status_code == 401


def test_logout_invalidates_the_refresh_token(client, setup):
    _register(client, "refresh4@example.com")
    body = _login(client, "refresh4@example.com").json()
    assert client.post("/auth/logout", headers=_auth(body["access_token"])).status_code == 200
    r = client.post("/auth/refresh", json={"refresh_token": body["refresh_token"]})
    assert r.status_code == 401


def test_sessions_list_marks_current_and_can_revoke(client, setup):
    _register(client, "devices@example.com")
    one = _login(client, "devices@example.com").json()
    two = _login(client, "devices@example.com").json()

    listing = client.get("/auth/sessions", headers=_auth(one["access_token"]))
    assert listing.status_code == 200
    rows = listing.json()
    assert len(rows) == 2
    assert sum(1 for r in rows if r["is_current"]) == 1

    other = next(r for r in rows if not r["is_current"])
    assert client.delete(
        f"/auth/sessions/{other['id']}", headers=_auth(one["access_token"])
    ).status_code == 200

    after = client.get("/auth/sessions", headers=_auth(one["access_token"])).json()
    assert len([r for r in after if r["is_active"]]) == 1
    # The revoked device's refresh token is dead too.
    assert (
        client.post("/auth/refresh", json={"refresh_token": two["refresh_token"]}).status_code
        == 401
    )


def test_logout_all_revokes_every_session(client, setup):
    _register(client, "everywhere@example.com")
    one = _login(client, "everywhere@example.com").json()
    two = _login(client, "everywhere@example.com").json()

    r = client.post("/auth/logout-all", headers=_auth(one["access_token"]))
    assert r.status_code == 200 and r.json()["revoked"] == 2

    for body in (one, two):
        assert (
            client.post(
                "/auth/refresh", json={"refresh_token": body["refresh_token"]}
            ).status_code
            == 401
        )
    assert len(_events(setup, audit.EventType.logout)) == 2
