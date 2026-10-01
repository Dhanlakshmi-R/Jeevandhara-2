from datetime import datetime, timedelta

from app.sms import get_sms_provider


def _send(client, phone="9876543210"):
    return client.post("/auth/otp/send", json={"phone": phone})


def test_sms_provider_not_configured(client, setup):
    setup.fake_sms  # ensure override exists; we replace it below
    from app.main import app

    app.dependency_overrides[get_sms_provider] = lambda: None
    try:
        r = _send(client)
        assert r.status_code == 503
    finally:
        app.dependency_overrides[get_sms_provider] = lambda: setup.fake_sms


def test_send_otp_invalid_phone(client):
    assert _send(client, phone="12345").status_code == 400
    assert _send(client, phone="888#%%%").status_code == 400


def test_otp_full_flow_new_user(client, setup):
    r = _send(client)
    assert r.status_code == 200
    body = r.json()
    assert body["message"] == "OTP sent"
    assert body["phone"] == "919876543210"
    assert body["resend_after_seconds"] > 0

    code = setup.fake_sms.sent[-1][1]
    assert len(code) == 6 and code.isdigit()

    # Wrong code first.
    wrong = client.post("/auth/otp/verify", json={"phone": "9876543210", "otp": "000000"})
    assert wrong.status_code == 400

    # Correct code → new user, profile incomplete.
    ok = client.post("/auth/otp/verify", json={"phone": "9876543210", "otp": code})
    assert ok.status_code == 200
    data = ok.json()
    assert data["profile_complete"] is False
    assert data["user"]["phone"] == "919876543210"
    assert data["user"]["phone_verified"] is True
    assert data["user"]["auth_provider"] == "phone"

    # A code can only be used once.
    reuse = client.post("/auth/otp/verify", json={"phone": "9876543210", "otp": code})
    assert reuse.status_code == 400


def test_otp_verify_wrong_attempts_capped(client, setup):
    _send(client)
    for _ in range(5):
        r = client.post("/auth/otp/verify", json={"phone": "9876543210", "otp": "000000"})
        assert r.status_code == 400
    r = client.post("/auth/otp/verify", json={"phone": "9876543210", "otp": "000000"})
    assert r.status_code == 429


def test_otp_send_cooldown(client):
    assert _send(client).status_code == 200
    r = _send(client)
    assert r.status_code == 429


def test_otp_expired(client, setup):
    _send(client)
    with setup.SessionLocal() as db:
        from app import models

        row = db.query(models.OtpRequest).first()
        row.expires_at = datetime.utcnow() - timedelta(seconds=1)
        db.commit()

    r = client.post("/auth/otp/verify", json={"phone": "9876543210", "otp": "123456"})
    assert r.status_code == 400
    assert "expired" in r.json()["detail"].lower()


def test_otp_login_links_existing_user_with_phone(client, setup):
    # Register via email/password with a 10-digit local phone number.
    client.post(
        "/auth/register",
        json={
            "name": "Sita",
            "email": "sita@example.com",
            "password": "password123",
            "phone": "9876543210",
            "location": "Pune, Maharashtra",
        },
    )
    _send(client)
    code = setup.fake_sms.sent[-1][1]
    r = client.post("/auth/otp/verify", json={"phone": "9876543210", "otp": code})
    assert r.status_code == 200
    data = r.json()
    assert data["user"]["email"] == "sita@example.com"
    assert data["profile_complete"] is True  # existing account, profile already done
    assert data["user"]["phone"] == "919876543210"


def test_complete_profile_updates_user(client, setup):
    _send(client)
    code = setup.fake_sms.sent[-1][1]
    login = client.post("/auth/otp/verify", json={"phone": "9876543210", "otp": code}).json()
    token = login["access_token"]

    r = client.post(
        "/auth/complete-profile",
        json={
            "name": "Ramesh Patil",
            "role": "trader",
            "location": "Nagpur, Maharashtra",
        },
        headers={"Authorization": f"Bearer {token}"},
    )
    assert r.status_code == 200
    data = r.json()
    assert data["profile_complete"] is True
    assert data["user"]["name"] == "Ramesh Patil"
    assert data["user"]["role"] == "trader"
    assert data["user"]["location"] == "Nagpur, Maharashtra"

    me = client.get("/users/me", headers={"Authorization": f"Bearer {token}"})
    assert me.json()["role"] == "trader"


def test_complete_profile_requires_auth(client):
    r = client.post("/auth/complete-profile", json={"name": "No One", "role": "farmer"})
    assert r.status_code == 401