"""Contract tests for the /listings router (traders + tool rentals).

These are the user-generated modules: every row is written by a real
authenticated user, there is no feed to watch over, and an empty list **is**
the honest answer. The tests pin down the rules that keep it honest:

1. Public reads (browse traders, browse tools) need no login - a farmer
   without an account must still be able to find a buyer.
2. Writes are owned. Only the user who published a card/tool can edit or
   hide it; anyone else gets 403, not a silent copy.
3. Crop names go through the same canonicaliser as market prices, so
   "pyaz" typed by hand matches "Onion".
4. Nothing is invented on the response either: rating is null until real
   reviews exist, never a star count.
"""

from __future__ import annotations


def _register(client, email: str = "farmer@example.com", role: str = "farmer") -> str:
    response = client.post(
        "/auth/register",
        json={
            "name": "Ramakrishna",
            "email": email,
            "password": "correct horse battery",
            "role": role,
        },
    )
    assert response.status_code == 201, response.text

    login = client.post(
        "/auth/login",
        data={"username": email, "password": "correct horse battery"},
    )
    assert login.status_code == 200, login.text
    return login.json()["access_token"]


def _auth(token: str) -> dict[str, str]:
    return {"Authorization": f"Bearer {token}"}


# ------------------------------------------------------------------ tools


def test_tools_start_honestly_empty(client):
    response = client.get("/tools")
    assert response.status_code == 200
    assert response.json() == {"items": []}


def test_creating_a_tool_requires_login(client):
    response = client.post(
        "/tools",
        json={"name": "Tractor", "price_per_day": 1500},
    )
    assert response.status_code == 401


def test_owner_can_publish_a_tool_and_everyone_can_read_it(client):
    token = _register(client, "farmer@example.com")

    created = client.post(
        "/tools",
        json={
            "name": "Power tiller",
            "emoji": "\U0001F92F",
            "category": "Tillage",
            "description": "Kubota 2.8 HP",
            "price_per_day": 800,
            "location": "Dharwad",
            "available": True,
        },
        headers=_auth(token),
    )
    assert created.status_code == 201, created.text
    body = created.json()
    assert body["owner"] == "Ramakrishna"
    assert body["owner_id"] > 0

    listed = client.get("/tools")
    assert listed.status_code == 200
    items = listed.json()["items"]
    assert len(items) == 1
    assert items[0]["name"] == "Power tiller"
    assert items[0]["price_per_day"] == 800

    detail = client.get(f"/tools/{body['id']}")
    assert detail.status_code == 200
    assert detail.json()["category"] == "Tillage"


def test_tool_cannot_be_edited_by_someone_else(client):
    owner = _register(client, "farmer@example.com")
    intruder = _register(client, "other@example.com")

    created = client.post(
        "/tools",
        json={"name": "Sprayer", "price_per_day": 150},
        headers=_auth(owner),
    ).json()

    response = client.patch(
        f"/tools/{created['id']}",
        json={"available": False},
        headers=_auth(intruder),
    )
    assert response.status_code == 403

    destroyed = client.delete(f"/tools/{created['id']}", headers=_auth(intruder))
    assert destroyed.status_code == 403


def test_owner_can_toggle_and_hide_their_tool(client):
    token = _register(client, "farmer@example.com")
    created = client.post(
        "/tools",
        json={"name": "Seed drill", "price_per_day": 300},
        headers=_auth(token),
    ).json()

    toggled = client.patch(
        f"/tools/{created['id']}",
        json={"available": False},
        headers=_auth(token),
    )
    assert toggled.status_code == 200
    assert toggled.json()["available"] is False

    listed = client.get("/tools")
    assert listed.json()["items"][0]["available"] is False

    hid = client.delete(f"/tools/{created['id']}", headers=_auth(token))
    assert hid.status_code == 204
    assert client.get("/tools").json()["items"] == []


# ----------------------------------------------------------------- traders


def test_traders_start_honestly_empty(client):
    response = client.get("/traders")
    assert response.status_code == 200
    assert response.json() == {"items": []}


def test_publishing_a_trader_card_requires_login(client):
    response = client.post("/traders/me", json={"crops": ["Onion"]})
    assert response.status_code == 401


def test_trader_card_is_public_and_normalises_crops(client):
    token = _register(client, "trader@example.com", role="trader")

    posted = client.post(
        "/traders/me",
        json={
            "company": "Karnataka Agro Exports",
            "crops": ["pyaz", "Tomato"],
            "offered_price_per_quintal": 4400,
            "note": "Paying cash at mandi gate",
            "emoji": "\U0001F3EA",
            "available": True,
        },
        headers=_auth(token),
    )
    assert posted.status_code == 201, posted.text
    card = posted.json()
    # The caller spelled "pyaz"; the card must commit to the canonical name
    # so a filter by "Onion" meets it.
    assert card["crops"] == ["Onion", "Tomato"]
    assert card["name"] == "Ramakrishna"
    assert card["rating"] is None, "no reviews exist; a card never invents stars"

    listed = client.get("/traders")
    assert len(listed.json()["items"]) == 1

    by_crop = client.get("/traders", params={"crop": "Onion"})
    assert len(by_crop.json()["items"]) == 1

    not_that_crop = client.get("/traders", params={"crop": "Bajra"})
    assert not_that_crop.json()["items"] == []

    by_q = client.get("/traders", params={"q": "agro"})
    assert len(by_q.json()["items"]) == 1


def test_trader_can_only_see_and_edit_their_own_card(client):
    token = _register(client, "trader@example.com", role="trader")

    assert client.get("/traders/me", headers=_auth(token)).json() == []
    client.post(
        "/traders/me", json={"crops": ["Onion"]}, headers=_auth(token)
    )

    mine = client.get("/traders/me", headers=_auth(token))
    assert len(mine.json()) == 1
    assert mine.json()[0]["crops"] == ["Onion"]

    updated = client.patch(
        "/traders/me",
        json={
            "crops": ["Onion", "Tomato"],
            "offered_price_per_quintal": 4600,
            "available": False,
        },
        headers=_auth(token),
    )
    assert updated.status_code == 200
    assert updated.json()["available"] is False

    took_down = client.delete("/traders/me", headers=_auth(token))
    assert took_down.status_code == 204
    assert client.get("/traders").json()["items"] == []


def test_traders_public_read_needs_no_login(client):
    token = _register(client, "trader@example.com", role="trader")
    client.post(
        "/traders/me",
        json={"crops": ["Rice"], "offered_price_per_quintal": 3200},
        headers=_auth(token),
    )

    assert len(client.get("/traders").json()["items"]) == 1