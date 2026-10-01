def test_register_login_me(client):
    r = client.post(
        "/auth/register",
        json={
            "name": "Ram Kumar",
            "email": "ram@example.com",
            "password": "supersecret",
            "role": "farmer",
            "phone": "9876543210",
        },
    )
    assert r.status_code == 201
    assert r.json()["email"] == "ram@example.com"
    assert r.json()["profile_complete"] is True
    assert r.json()["auth_provider"] == "password"
    assert "hashed_password" not in r.json()

    r = client.post(
        "/auth/login",
        data={"username": "ram@example.com", "password": "supersecret"},
    )
    assert r.status_code == 200
    token = r.json()["access_token"]

    r = client.get("/users/me", headers={"Authorization": f"Bearer {token}"})
    assert r.status_code == 200
    assert r.json()["role"] == "farmer"
    assert r.json()["phone"] == "9876543210"


def test_login_wrong_password(client):
    client.post(
        "/auth/register",
        json={"name": "Ram", "email": "ram2@example.com", "password": "correct-horse"},
    )
    r = client.post(
        "/auth/login",
        data={"username": "ram2@example.com", "password": "wrong"},
    )
    assert r.status_code == 401


def test_register_duplicate_email(client):
    payload = {
        "name": "Ram",
        "email": "dup@example.com",
        "password": "password123",
    }
    assert client.post("/auth/register", json=payload).status_code == 201
    assert client.post("/auth/register", json=payload).status_code == 400


def test_users_me_requires_auth(client):
    assert client.get("/users/me").status_code == 401