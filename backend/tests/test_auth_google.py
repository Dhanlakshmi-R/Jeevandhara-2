from fastapi import HTTPException

from app.google_auth import google_verifier
from app.main import app


def _google_login(client, token="abc"):
    return client.post("/auth/google", json={"id_token": token})


def test_google_login_new_user(client):
    r = _google_login(client)
    assert r.status_code == 200
    data = r.json()
    assert data["profile_complete"] is False
    assert data["user"]["email"] == "gita@example.com"
    assert data["user"]["auth_provider"] == "google"
    assert data["user"]["provider_user_id"] == "google-sub-001"

    token = data["access_token"]
    me = client.get("/users/me", headers={"Authorization": f"Bearer {token}"})
    assert me.status_code == 200
    assert me.json()["auth_provider"] == "google"


def test_google_login_same_sub_returns_same_user(client):
    first = _google_login(client).json()
    second = _google_login(client).json()
    assert first["user"]["id"] == second["user"]["id"]
    assert first["user"]["profile_complete"] is False


def test_google_login_links_existing_password_account(client):
    client.post(
        "/auth/register",
        json={
            "name": "Gita Sharma",
            "email": "gita@example.com",
            "password": "same-password",
        },
    )
    r = _google_login(client)
    assert r.status_code == 200
    data = r.json()
    # Existing account keeps its completed profile; Google gets linked.
    assert data["user"]["profile_complete"] is True
    assert data["user"]["auth_provider"] == "google"


def test_google_login_invalid_token(client):
    original = app.dependency_overrides[google_verifier]

    def reject():
        def _reject(token):
            raise HTTPException(
                status_code=401, detail="Invalid Google ID token or audience mismatch."
            )

        return _reject

    app.dependency_overrides[google_verifier] = reject
    try:
        r = _google_login(client, token="not-a-real-token")
        assert r.status_code == 401
    finally:
        app.dependency_overrides[google_verifier] = original