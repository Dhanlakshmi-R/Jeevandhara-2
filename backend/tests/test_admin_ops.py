"""Batch C: the admin console operations API.

Covers the new console modules — weather alerts, notifications, settings,
reports, crop analytics, market review and permissions — plus the honesty rules
that matter: nothing requires a credential to be exposed, analytics are computed
from real rows, the forecast refuses to guess, and settings reject unknown keys.
"""

from datetime import date, datetime, timedelta

from app import audit, models
from app.auth_utils import hash_password

PASSWORD = "hunter2-strong"


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
    return client.post(
        "/auth/login", data={"username": email, "password": PASSWORD}
    ).json()["access_token"]


def _auth(token: str) -> dict:
    return {"Authorization": f"Bearer {token}"}


def _register(client, email: str, role: str = "farmer", location: str | None = None):
    return client.post(
        "/auth/register",
        json={
            "name": "Test User",
            "email": email,
            "password": PASSWORD,
            "role": role,
            "location": location,
        },
    )


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


# ------------------------------------------------------------------- access


def test_new_admin_routes_require_admin(client, setup):
    for path in (
        "/admin/weather-alerts",
        "/admin/notifications",
        "/admin/settings",
        "/admin/reports/summary",
        "/admin/analytics/crops",
        "/admin/market/prices",
        "/admin/permissions",
    ):
        assert client.get(path).status_code == 401, path
    _register(client, "nobody@example.com")
    token = client.post(
        "/auth/login", data={"username": "nobody@example.com", "password": PASSWORD}
    ).json()["access_token"]
    assert client.get("/admin/settings", headers=_auth(token)).status_code == 403


# ------------------------------------------------------------ weather alerts


def test_weather_alert_crud_and_public_feed(client, setup):
    token = _admin_token(client, setup)

    created = client.post(
        "/admin/weather-alerts",
        headers=_auth(token),
        json={
            "title": "Heavy rain",
            "message_en": "Heavy rain expected in the next 24 hours.",
            "severity": "warning",
            "scope_type": "state",
            "scope_value": "Karnataka",
        },
    )
    assert created.status_code == 201
    alert = created.json()
    assert alert["severity"] == "warning"
    assert alert["is_active"] is True
    assert len(_events(setup, audit.EventType.admin_created_weather_alert)) == 1

    # Public feed returns it for matching scope.
    pub = client.get("/weather/alerts?state=Karnataka")
    assert pub.status_code == 200
    assert any(a["id"] == alert["id"] for a in pub.json())
    # And not for a different state.
    other = client.get("/weather/alerts?state=Tamil Nadu").json()
    assert all(a["id"] != alert["id"] for a in other)

    updated = client.put(
        f"/admin/weather-alerts/{alert['id']}",
        headers=_auth(token),
        json={"is_active": False},
    )
    assert updated.status_code == 200
    assert updated.json()["is_active"] is False
    assert len(_events(setup, audit.EventType.admin_updated_weather_alert)) == 1

    # Deactivated alerts drop out of the public feed.
    assert all(
        a["id"] != alert["id"]
        for a in client.get("/weather/alerts?state=Karnataka").json()
    )

    deleted = client.delete(
        f"/admin/weather-alerts/{alert['id']}", headers=_auth(token)
    )
    assert deleted.status_code == 200
    assert len(_events(setup, audit.EventType.admin_deleted_weather_alert)) == 1


def test_weather_alert_scope_requires_value(client, setup):
    token = _admin_token(client, setup)
    r = client.post(
        "/admin/weather-alerts",
        headers=_auth(token),
        json={
            "title": "x",
            "message_en": "y",
            "scope_type": "district",
        },
    )
    assert r.status_code == 422


# ------------------------------------------------------------- notifications


def test_notification_audiences_count_recipients(client, setup):
    token = _admin_token(client, setup)
    _register(client, "f_k@example.com", role="farmer", location="Mandya, Karnataka")
    _register(client, "t_k@example.com", role="trader", location="Mandya, Karnataka")
    _register(client, "f_tn@example.com", role="farmer", location="Salem, Tamil Nadu")

    allres = client.post(
        "/admin/notifications",
        headers=_auth(token),
        json={"title": "Hi all", "body_en": "Body", "audience": "all"},
    )
    assert allres.status_code == 201
    # All active users (3 registered + 1 admin).
    assert allres.json()["recipient_count"] == 4
    assert "All active users" in allres.json()["audience_summary"]

    farmers = client.post(
        "/admin/notifications",
        headers=_auth(token),
        json={
            "title": "Farmers",
            "body_en": "Body",
            "audience": "role",
            "audience_value": "farmer",
        },
    )
    assert farmers.json()["recipient_count"] == 2

    loc = client.post(
        "/admin/notifications",
        headers=_auth(token),
        json={
            "title": "Mandya",
            "body_en": "Body",
            "audience": "location",
            "audience_value": "Mandya",
        },
    )
    assert loc.json()["recipient_count"] == 2

    db = setup.SessionLocal()
    target = (
        db.query(models.User).filter(models.User.email == "f_tn@example.com").first()
    )
    target_id = target.id
    db.close()

    one = client.post(
        "/admin/notifications",
        headers=_auth(token),
        json={
            "title": "One",
            "body_en": "Body",
            "audience": "user",
            "audience_value": str(target_id),
        },
    )
    assert one.json()["recipient_count"] == 1

    assert len(_events(setup, audit.EventType.admin_sent_notification)) == 4

    history = client.get("/admin/notifications", headers=_auth(token)).json()
    assert len(history) == 4
    # No credential-shaped fields ever.
    assert "hashed_password" not in history[0]


def test_notification_bad_audience_rejected(client, setup):
    token = _admin_token(client, setup)
    bad_role = client.post(
        "/admin/notifications",
        headers=_auth(token),
        json={
            "title": "x",
            "body_en": "y",
            "audience": "role",
            "audience_value": "wizard",
        },
    )
    assert bad_role.status_code == 422
    missing_loc = client.post(
        "/admin/notifications",
        headers=_auth(token),
        json={"title": "x", "body_en": "y", "audience": "location"},
    )
    assert missing_loc.status_code == 422


# ------------------------------------------------------------------ settings


def test_settings_defaults_whitelist_and_persistence(client, setup):
    token = _admin_token(client, setup)
    before = client.get("/admin/settings", headers=_auth(token)).json()["settings"]
    keys = {s["key"] for s in before}
    assert "support_email" in keys and "maintenance_mode" in keys
    # Defaults are present even before any write.
    assert next(s for s in before if s["key"] == "default_language")["value"] == "en"

    ok = client.put(
        "/admin/settings",
        headers=_auth(token),
        json={"values": {"maintenance_mode": True, "market_retention_days": 30}},
    )
    assert ok.status_code == 200
    saved = {s["key"]: s["value"] for s in ok.json()["settings"]}
    assert saved["maintenance_mode"] == "true"
    assert saved["market_retention_days"] == "30"
    assert len(_events(setup, audit.EventType.admin_updated_settings)) == 1

    # Rejected: unknown key, bad int, bad enum.
    assert (
        client.put(
            "/admin/settings",
            headers=_auth(token),
            json={"values": {"hack": "x"}},
        ).status_code
        == 422
    )
    assert (
        client.put(
            "/admin/settings",
            headers=_auth(token),
            json={"values": {"market_retention_days": "soon"}},
        ).status_code
        == 422
    )
    assert (
        client.put(
            "/admin/settings",
            headers=_auth(token),
            json={"values": {"default_language": "fr"}},
        ).status_code
        == 422
    )


# ------------------------------------------------------------------- reports


def test_reports_summary_activity_and_export(client, setup):
    token = _admin_token(client, setup)
    _register(client, "rep1@example.com")
    client.post("/auth/login", data={"username": "rep1@example.com", "password": PASSWORD})

    summary = client.get("/admin/reports/summary?days=30", headers=_auth(token))
    assert summary.status_code == 200
    body = summary.json()
    assert body["users_total"] >= 2
    assert body["events_in_period"] >= 1

    activity = client.get("/admin/reports/activity?days=30", headers=_auth(token)).json()
    assert any(row["event_type"] == audit.EventType.login_success for row in activity)

    export = client.get(
        "/admin/reports/export?kind=summary&format=csv&days=30", headers=_auth(token)
    )
    assert export.status_code == 200
    assert export.headers["content-type"].startswith("text/csv")
    assert len(_events(setup, audit.EventType.admin_exported_report)) == 1


# ----------------------------------------------------------- crop analytics


def test_crop_analytics_computed_from_real_rows(client, setup):
    token = _admin_token(client, setup)
    db = setup.SessionLocal()
    try:
        owner = models.User(
            name="Farmer",
            email="owner@example.com",
            hashed_password=hash_password(PASSWORD),
            role=models.UserRole.farmer,
            is_active=True,
            profile_complete=True,
        )
        db.add(owner)
        db.commit()
        db.refresh(owner)
        db.add_all(
            [
                models.CropListing(
                    owner_id=owner.id,
                    name="Onion",
                    quantity=10,
                    expected_price=1500,
                    status="active",
                ),
                models.CropListing(
                    owner_id=owner.id,
                    name="Onion",
                    quantity=5,
                    expected_price=1700,
                    status="sold",
                ),
                models.MarketPrice(
                    commodity="Onion",
                    market="Mandya",
                    state="Karnataka",
                    trade_date=date(2026, 1, 1),
                    modal_price=1600,
                    source_name="test-feed",
                ),
            ]
        )
        db.commit()
    finally:
        db.close()

    r = client.get("/admin/analytics/crops?days=365", headers=_auth(token))
    assert r.status_code == 200
    crops = r.json()["crops"]
    onion = next(c for c in crops if c["commodity"] == "Onion")
    assert onion["listings"] == 2
    assert onion["active_listings"] == 1
    assert onion["total_quantity"] == 15
    assert onion["latest_modal_price"] == 1600

    detail = client.get("/admin/analytics/crops/Onion", headers=_auth(token))
    assert detail.status_code == 200
    d = detail.json()
    assert d["sold_listings"] == 1
    assert d["distinct_markets"] == 1
    assert d["states"] == ["Karnataka"]

    missing = client.get("/admin/analytics/crops/UnicornFruit", headers=_auth(token))
    assert missing.status_code == 404


# -------------------------------------------------------------- market admin


def test_market_price_review_and_sources(client, setup):
    token = _admin_token(client, setup)
    db = setup.SessionLocal()
    try:
        row = models.MarketPrice(
            commodity="Tomato",
            market="Bengaluru",
            state="Karnataka",
            trade_date=date(2026, 2, 1),
            modal_price=800,
            source_name="feed-a",
        )
        db.add(row)
        db.commit()
        db.refresh(row)
        row_id = row.id
    finally:
        db.close()

    listing = client.get("/admin/market/prices?commodity=Tomato", headers=_auth(token))
    assert listing.status_code == 200
    assert listing.json()["total"] == 1

    verified = client.post(
        f"/admin/market/prices/{row_id}/verify", headers=_auth(token)
    )
    assert verified.status_code == 200
    assert verified.json()["source_verified"] is True
    assert len(_events(setup, audit.EventType.admin_verified_market_price)) == 1

    sources = client.get("/admin/market/sources", headers=_auth(token)).json()
    assert any(s["source_name"] == "feed-a" and s["verified_rows"] == 1 for s in sources)


def test_market_forecast_refuses_without_data(client, setup):
    token = _admin_token(client, setup)
    r = client.get(
        "/admin/market/forecast?commodity=Onion", headers=_auth(token)
    )
    assert r.status_code == 200
    body = r.json()
    assert body["status"] == "insufficient_data"
    assert body["projection"] == []
    assert body["reason"]


def test_market_forecast_projects_with_enough_history(client, setup):
    token = _admin_token(client, setup)
    db = setup.SessionLocal()
    try:
        base = date(2026, 1, 1)
        for i in range(10):
            db.add(
                models.CropPriceHistory(
                    state="Karnataka",
                    commodity="Onion",
                    date=base + timedelta(days=i),
                    avg_modal_price=1000 + i * 10,
                    source_name="test",
                )
            )
        db.commit()
    finally:
        db.close()

    r = client.get(
        "/admin/market/forecast?commodity=Onion&state=Karnataka&horizon=5",
        headers=_auth(token),
    )
    body = r.json()
    assert body["status"] == "ok"
    assert body["slope_per_day"] == 10.0
    assert len(body["projection"]) == 5
    # The next day should be 1000 + 9*10 + 10 = 1100.
    assert body["projection"][0]["value"] == 1100.0


# --------------------------------------------------------------- permissions


def test_permissions_matrix_shape(client, setup):
    token = _admin_token(client, setup)
    r = client.get("/admin/permissions", headers=_auth(token))
    assert r.status_code == 200
    body = r.json()
    assert "superadmin" in body["roles"]
    caps = {c["key"]: c for c in body["capabilities"]}
    assert "manage_admins" in caps
    assert caps["manage_admins"]["roles"] == ["superadmin"]
    assert caps["manage_users"]["roles"] == ["admin"]
