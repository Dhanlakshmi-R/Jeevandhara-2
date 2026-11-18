"""Contract tests for the /market router.

Two things are being pinned down here, and only the second one matters most:

1. The happy path returns rows with provenance and freshness attached.
2. **When a source is down, the response says which source and why** - a 503
   carrying per-source reasons, never a 200 with an empty list that the UI
   would render as "no prices today".

The ownership tests exist because inquiries and alerts are the only rows in
this router that belong to a person. If they can be listed or deleted by
anyone, the "one dependency so it cannot be forgotten" rule is already broken.

No network: upstream responses are injected at the registry boundary.
"""

from __future__ import annotations

from datetime import date, timedelta
from unittest.mock import patch

import pytest

from app.market.sources.base import utcnow
from app.market.sources.registry import NoSourceAvailable

# ------------------------------------------------------------------ helpers

def _register(client, email: str = "farmer@example.com") -> str:
    registered = client.post(
        "/auth/register",
        json={
            "name": "Ramakrishna",
            "email": email,
            "password": "correct horse battery",
            "role": "farmer",
        },
    )
    assert registered.status_code == 201, registered.text

    login = client.post(
        "/auth/login",
        data={"username": email, "password": "correct horse battery"},
    )
    assert login.status_code == 200, login.text
    return login.json()["access_token"]


def _auth(token: str) -> dict[str, str]:
    return {"Authorization": f"Bearer {token}"}


def _today() -> str:
    return date.today().isoformat()


def _rows(*, trade_date: str | None = None, stale: bool = False) -> list[dict]:
    """One real-looking observation with the provenance block attached.

    `stale=True` back-dates the market date so the freshness rule can be
    tested against the data's own date rather than the fetch time.
    """
    day = trade_date or (date.today() - timedelta(days=7) if stale else date.today())
    return [
        {
            "commodity": "Onion",
            "variety": None,
            "grade": None,
            "state": "Karnataka",
            "district": "Kolar",
            "market": "Bangarpet",
            "date": day if isinstance(day, str) else day.isoformat(),
            "min_price": 3000.0,
            "modal_price": 4400.0,
            "max_price": 5200.0,
            "unit": None,
            "arrival_quantity": None,
            "upstream_id": None,
            "source": "mandi_api",
            "_provenance": {
                "source": "mandi_api",
                "attribution": "Community mandi feed",
                "confidence": "low",
                "verified": True,
                "fetched_at": utcnow().isoformat(),
                "stale": stale,
            },
        }
    ]


def _meta(**overrides) -> dict:
    meta = {
        "source": "mandi_api",
        "attribution": "Community mandi feed",
        "confidence": "low",
        "verified": True,
        "fetched_at": utcnow().isoformat(),
        "stale": False,
    }
    meta.update(overrides)
    return meta


def _patch_prices(rows=None, meta=None):
    """Patch the registry boundary with an injected upstream response."""
    return patch(
        "app.market.service.registry.fetch_prices",
        return_value=(rows if rows is not None else _rows(), meta or _meta()),
    )


# ------------------------------------------------------------------ status

def test_status_is_public_and_reports_source_health(client):
    response = client.get("/market/status")
    assert response.status_code == 200

    body = response.json()
    assert set(body) >= {"live", "prices", "arrivals", "demand_capable", "sources", "checked_at"}
    assert isinstance(body["sources"], list)
    assert body["sources"], "status must enumerate the configured sources"

    for source in body["sources"]:
        # Every source has to be able to explain itself, including the ones
        # that are off - that is the whole point of the endpoint.
        assert set(source) >= {"name", "enabled", "verified", "confidence", "attribution"}
        if not source["enabled"]:
            assert source.get("disabled_reason"), f"{source['name']} is off with no reason"


def test_status_never_calls_a_source_a_live_price_feed_without_verification(client):
    body = client.get("/market/status").json()
    if not body["live"]:
        assert body["prices"] in {"stale", "unavailable"}


# ------------------------------------------------------------------ prices

def test_prices_returns_rows_with_provenance_and_freshness(client):
    with _patch_prices():
        response = client.get("/market/prices", params={"commodity": "Onion", "state": "Karnataka"})

    assert response.status_code == 200
    body = response.json()
    assert body["commodity"] == "Onion"
    assert body["rows"], "expected at least one row"

    row = body["rows"][0]
    provenance = row["_provenance"]
    for key in ("source", "attribution", "confidence", "verified", "fetched_at", "stale"):
        assert key in provenance, f"{key} missing from provenance"
    for key in ("freshness", "actionable", "observed_at", "lag_days"):
        assert key in provenance, f"{key} missing from freshness annotation"

    assert body["meta"]["source"] == "mandi_api"


def test_prices_labels_a_week_old_rate_as_stale(client):
    with _patch_prices(rows=_rows(stale=True)):
        response = client.get("/market/prices", params={"commodity": "Onion"})

    row = response.json()["rows"][0]
    # Age comes from the market date, never from how fast we fetched it.
    assert row["_provenance"]["freshness"] == "stale"
    assert row["_provenance"]["actionable"] is False
    assert row["_provenance"]["lag_days"] >= 6


def test_prices_freshness_uses_the_market_date_not_the_fetch_time(client):
    with _patch_prices(rows=_rows(trade_date=_today(), stale=True)):
        response = client.get("/market/prices", params={"commodity": "Onion"})

    provenance = response.json()["rows"][0]["_provenance"]
    # A fast fetch of a stale-labelled source still resolves to `fresh` when
    # the observation itself is from today: freshness is about the data.
    assert provenance["freshness"] == "fresh"
    assert provenance["actionable"] is True


def test_prices_503s_with_per_source_reasons_when_every_source_fails(client):
    attempts = [
        {"source": "data_gov_in", "reason": "DATA_GOV_API_KEY not set"},
        {"source": "enam", "reason": "HTTP 500: empty body"},
        {"source": "mandi_api", "reason": "HTTP 500: upstream down"},
    ]
    with patch(
        "app.market.service.registry.fetch_prices",
        side_effect=NoSourceAvailable(attempts, kind="price"),
    ):
        response = client.get("/market/prices", params={"commodity": "Onion"})

    assert response.status_code == 503
    detail = response.json()["detail"]
    assert detail["kind"] == "price"
    reasons = {a["source"]: a["reason"] for a in detail["attempts"]}
    assert reasons["data_gov_in"] == "DATA_GOV_API_KEY not set"
    assert "500" in reasons["enam"]


def test_rate_limited_chain_serves_stored_rows_with_their_provenance(client, setup):
    """Three rate-limited feeds must not become an error page.

    We hold real observations; the honest response is those rows, marked stale
    and still carrying the attempts, not a 503 the UI renders as "nothing
    today".
    """
    with _patch_prices():
        first = client.get("/market/prices", params={"commodity": "Onion"})
    assert first.status_code == 200, first.text

    attempts = [
        {"source": "data_gov_in", "reason": "disabled or not configured"},
        {"source": "enam", "reason": "minimum interval not elapsed"},
        {"source": "mandi_api", "reason": "minimum interval not elapsed"},
    ]
    with patch(
        "app.market.service.registry.fetch_prices",
        side_effect=NoSourceAvailable(attempts, kind="price"),
    ):
        response = client.get("/market/prices", params={"commodity": "Onion"})

    assert response.status_code == 200
    body = response.json()
    assert body["rows"], "stored observations must be served"
    assert body["meta"]["from_storage"] is True
    assert body["meta"]["stale"] is True
    assert body["meta"]["attempts"] == attempts, "why the live pull failed stays"

    provenance = body["rows"][0]["_provenance"]
    assert provenance["source"] == "mandi_api"
    assert provenance["tier"] in {"A", "B", "C", "D"}
    assert provenance["freshness"] == "stale"
    assert provenance["actionable"] is False, "a stored copy is never actionable"
    assert "stored" in provenance["note"].lower()


def test_storage_fallback_never_reports_a_crop_nobody_quoted(client):
    """Fallback answers for held crops only; unknown crops still 503."""
    attempts = [{"source": "mandi_api", "reason": "minimum interval not elapsed"}]
    with patch(
        "app.market.service.registry.fetch_prices",
        side_effect=NoSourceAvailable(attempts, kind="price"),
    ):
        response = client.get("/market/prices", params={"commodity": "Turmeric"})

    assert response.status_code == 503
    assert response.json()["detail"]["attempts"] == attempts


def test_a_crop_no_source_quotes_is_empty_not_an_outage(client):
    """The chain's honest "nobody has this crop" must reach the screen.

    It used to be folded into the same NoSourceAvailable as an outage, so the
    app said "market data unavailable" about a crop that was simply unquoted.
    """
    with _patch_prices(
        rows=[],
        meta=_meta(empty=True, note="No market source reports rows for this crop right now."),
    ):
        response = client.get("/market/prices", params={"commodity": "Bajra"})

    assert response.status_code == 200
    body = response.json()
    assert body["rows"] == []
    assert body["meta"]["empty"] is True
    assert "no market source" in body["meta"]["note"].lower()


def test_prices_requires_a_commodity(client):
    assert client.get("/market/prices").status_code == 422


def test_prices_normalises_the_crop_name(client):
    with _patch_prices() as mocked:
        client.get("/market/prices", params={"commodity": "pyaz"})

    _, kwargs = mocked.call_args
    assert kwargs["commodity"] == "Onion", "Pyaz must resolve to the canonical crop"


def test_prices_are_persisted_with_provenance(client, setup):
    from app import models

    with _patch_prices():
        client.get("/market/prices", params={"commodity": "Onion", "state": "Karnataka"})

    db = setup.SessionLocal()
    try:
        rows = db.query(models.MarketPrice).all()
        assert rows, "observations should be stored"
        for row in rows:
            assert row.source_name, "a stored price must carry its source"
            assert row.trade_date, "a stored price must carry a market date"
    finally:
        db.close()


# ----------------------------------------------------------------- history

def test_price_history_returns_a_series(client):
    series = [
        {
            "date": (date.today() - timedelta(days=offset)).isoformat(),
            "modal_price": 4000.0 + offset * 50,
            "min_price": 3800.0,
            "max_price": 4300.0,
            "data_points": 12,
            "commodity": "Onion",
            "state": "Karnataka",
        }
        for offset in range(10)
    ]
    with patch(
        "app.market.service._history_upstream", return_value=(series, _meta())
    ):
        response = client.get(
            "/market/prices/history", params={"commodity": "Onion", "state": "Karnataka"}
        )

    assert response.status_code == 200
    body = response.json()
    assert len(body["rows"]) == 10
    assert body["meta"]["source"] == "mandi_api"
    # Oldest first: a sparkline and a momentum calc both read left to right.
    dates = [row["date"] for row in body["rows"]]
    assert dates == sorted(dates)


def test_price_history_degrades_to_stored_observations(client):
    """No upstream history must still answer from our own copy, labelled."""
    with patch("app.market.service._history_upstream", return_value=([], _meta(source=None, stale=True))):
        response = client.get(
            "/market/prices/history", params={"commodity": "Onion", "state": "Karnataka"}
        )

    assert response.status_code == 200
    assert response.json()["rows"] == []
    assert response.json()["meta"]["stale"] is True


# ------------------------------------------------------------- reference

def test_commodities_lists_aliases_for_the_search_box(client):
    body = client.get("/market/commodities").json()
    items = {row["commodity"]: row for row in body["items"]}

    assert "Onion" in items
    # Aliases are stored in normalised (lower-cased, transliterated) form, so
    # the assertion is on the match working rather than on display casing.
    aliases = [alias.lower() for alias in items["Onion"]["aliases"]]
    assert "pyaz" in aliases
    assert "onions" in aliases
    assert isinstance(items["Onion"]["has_data"], bool)


def test_mandis_lists_places_we_have_rows_for(client, setup):
    """The picker reads storage only - no network on a screen that must be fast."""
    db = setup.SessionLocal()
    try:
        _seed_price(db, market="Bangarpet", district="Kolar")
    finally:
        db.close()

    body = client.get("/market/mandis", params={"state": "Karnataka"}).json()
    assert {row["market"] for row in body["items"]} == {"Bangarpet"}
    entry = body["items"][0]
    assert entry["has_data"] is True
    assert entry["last_observed"]


def test_mandis_is_empty_rather_than_invented(client):
    body = client.get("/market/mandis").json()
    assert body["items"] == [], "no rows means no mandis, not a hardcoded list"


# ----------------------------------------------------------------- demand

def _seed_price(db, **overrides):
    from app import models

    row = models.MarketPrice(
        commodity=overrides.get("commodity", "Onion"),
        market=overrides.get("market", "Bangarpet"),
        district=overrides.get("district", "Kolar"),
        state=overrides.get("state", "Karnataka"),
        trade_date=overrides.get("trade_date", date.today()),
        min_price=overrides.get("min_price", 3000.0),
        modal_price=overrides.get("modal_price", 4400.0),
        max_price=overrides.get("max_price", 5200.0),
        source_name="mandi_api",
        source_confidence="low",
        source_verified=True,
        fetched_at=utcnow().replace(tzinfo=None),
    )
    db.add(row)
    db.commit()
    return row


def test_demand_503s_when_nothing_is_stored(client):
    response = client.get("/market/demand", params={"commodity": "Onion"})
    assert response.status_code == 503
    assert response.json()["detail"]["attempts"][0]["source"] == "database"


def test_demand_is_labelled_derived_and_exposes_its_breakdown(client, setup):
    db = setup.SessionLocal()
    try:
        _seed_price(db)
        _seed_price(db, market="Bengaluru", district="Bengaluru", modal_price=4700.0)
    finally:
        db.close()

    response = client.get("/market/demand", params={"commodity": "Onion", "force": True})
    assert response.status_code == 200

    body = response.json()
    assert body["is_derived"] is True
    assert set(body) >= {"score", "band", "components", "coverage", "confidence", "omitted"}
    assert len(body["components"]) == 9, "every component is reported, used or not"

    available = [c for c in body["components"] if c["available"]]
    omitted = [c for c in body["components"] if not c["available"]]
    assert available and omitted, "a real reading has both, and says which"

    for component in omitted:
        assert component["unavailable_reason"], "an omitted component must say why"
        assert component["effective_weight"] is None, "an omitted component must carry no weight"

    assert body["omitted"], "the API must surface what was left out"
    for entry in body["omitted"]:
        assert entry["reason"]


def test_demand_never_scores_from_a_single_component(client, setup):
    db = setup.SessionLocal()
    try:
        # One mandi, one date: only market_activity and price_dispersion can
        # compute, and without history momentum is unavailable - so the reading
        # is thin but should still refuse if only one resolves.
        _seed_price(db)
    finally:
        db.close()

    body = client.get("/market/demand", params={"commodity": "Onion", "force": True}).json()
    if body["score"] is not None:
        assert body["component_count"] >= 2
        assert body["band"] != "insufficient_data"


def test_demand_top_ranks_and_lists_unscorable_mandis_separately(client, setup):
    db = setup.SessionLocal()
    try:
        _seed_price(db, market="Bangarpet", modal_price=5000.0)
        _seed_price(db, market="Bengaluru", modal_price=4700.0)
        _seed_price(db, market="Hubballi", district="Dharwad", modal_price=4300.0)
    finally:
        db.close()

    response = client.get("/market/demand/top", params={"commodity": "Onion"})
    assert response.status_code == 200

    body = response.json()
    assert body["is_derived"] is True
    assert set(body) >= {"ranked", "insufficient_data", "explanation"}
    assert "insufficient_data" in body["explanation"]

    scores = [row["score"] for row in body["ranked"] if row["score"] is not None]
    assert scores == sorted(scores, reverse=True), "ranking must be ordered"


# ------------------------------------------------------------- sell advice

def test_sell_advice_names_a_mandi_with_live_prices(client, setup):
    db = setup.SessionLocal()
    try:
        _seed_price(db, market="Bangarpet", modal_price=5000.0)
        _seed_price(db, market="Bengaluru", modal_price=4700.0)
    finally:
        db.close()

    response = client.get(
        "/market/sell-advice",
        params={"commodity": "Onion", "quantity_quintals": 20, "state": "Karnataka"},
    )
    assert response.status_code == 200

    body = response.json()
    assert body["is_derived"] is True
    assert body["best_mandi"]["market"] == "Bangarpet"
    assert body["best_mandi"]["modal_price"] == 5000.0
    assert body["expected_value"]["at_best_modal"] == 100_000.0
    assert body["caveats_en"], "advice must state what it did not model"
    assert any("Travel cost" in line for line in body["caveats_en"])


def test_sell_advice_refuses_when_the_price_is_too_old(client, setup):
    db = setup.SessionLocal()
    try:
        _seed_price(db, trade_date=date.today() - timedelta(days=9))
    finally:
        db.close()

    response = client.get(
        "/market/sell-advice", params={"commodity": "Onion", "quantity_quintals": 5}
    )
    assert response.status_code == 409
    detail = response.json()["detail"]
    assert "older than" in detail["reason"]
    assert "newest_observation" in detail


def test_sell_advice_409s_when_we_have_no_price_at_all(client):
    response = client.get(
        "/market/sell-advice", params={"commodity": "Onion", "quantity_quintals": 5}
    )
    assert response.status_code == 409
    assert "no price observations" in response.json()["detail"]["reason"]


# ------------------------------------------------ first-party: inquiries

def test_inquiry_requires_auth(client):
    response = client.post(
        "/market/inquiry", json={"crop_name": "Onion", "expected_price": 4000}
    )
    assert response.status_code == 401


def test_inquiry_roundtrip(client):
    token = _register(client)

    created = client.post(
        "/market/inquiry",
        json={"crop_name": "pyaz", "quantity_quintals": 20, "district": "Kolar"},
        headers=_auth(token),
    )
    assert created.status_code == 201, created.text
    body = created.json()
    assert body["crop_name"] == "Onion", "stored under the canonical crop name"
    assert body["status"] == "pending"

    listed = client.get("/market/inquiries", headers=_auth(token))
    assert listed.status_code == 200
    assert [row["id"] for row in listed.json()] == [body["id"]]

    deleted = client.delete(f"/market/inquiries/{body['id']}", headers=_auth(token))
    assert deleted.status_code == 204
    assert client.get("/market/inquiries", headers=_auth(token)).json() == []


def test_inquiries_are_owner_scoped(client):
    owner = _register(client, "owner@example.com")
    stranger = _register(client, "stranger@example.com")

    created = client.post(
        "/market/inquiry",
        json={"crop_name": "Tomato", "quantity_quintals": 10},
        headers=_auth(owner),
    ).json()

    # A stranger must not even see that it exists - 404, not 403, so the id
    # cannot be probed for.
    assert client.get("/market/inquiries", headers=_auth(stranger)).json() == []
    assert (
        client.delete(f"/market/inquiries/{created['id']}", headers=_auth(stranger)).status_code
        == 404
    )


# ------------------------------------------------- first-party: alerts

def test_alert_crud_roundtrip(client):
    token = _register(client)

    created = client.post(
        "/market/alerts",
        json={"commodity": "Onion", "direction": "above", "threshold": 5000},
        headers=_auth(token),
    )
    assert created.status_code == 201, created.text
    alert = created.json()
    assert alert["direction"] == "above"
    assert alert["threshold"] == 5000

    assert [row["id"] for row in client.get("/market/alerts", headers=_auth(token)).json()] == [
        alert["id"]
    ]

    assert (
        client.delete(f"/market/alerts/{alert['id']}", headers=_auth(token)).status_code == 204
    )
    assert client.get("/market/alerts", headers=_auth(token)).json() == []


def test_alerts_are_owner_scoped(client):
    owner = _register(client, "owner2@example.com")
    stranger = _register(client, "stranger2@example.com")

    alert = client.post(
        "/market/alerts",
        json={"commodity": "Tomato", "direction": "below", "threshold": 2000},
        headers=_auth(owner),
    ).json()

    assert client.get("/market/alerts", headers=_auth(stranger)).json() == []
    assert (
        client.delete(f"/market/alerts/{alert['id']}", headers=_auth(stranger)).status_code == 404
    )


def test_alert_direction_is_validated(client):
    token = _register(client)
    response = client.post(
        "/market/alerts",
        json={"commodity": "Onion", "direction": "sideways", "threshold": 10},
        headers=_auth(token),
    )
    assert response.status_code == 422
