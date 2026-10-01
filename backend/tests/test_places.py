"""Tests for the offline all-India location gazetteer.

These read the real GeoNames-derived SQLite database through the TestClient --
no network and no WEATHER_API_KEY required. The point of the gazetteer is
that every place it lists carries real coordinates, so most assertions here are
about coordinates existing and falling inside India's bounding box rather
than about exact names.
"""

import pytest

from app import places
from app.main import app

# Rough bounding box for India; used to sanity-check coordinates.
LAT = (6.0, 37.5)
LON = (68.0, 98.0)


def in_india(lat, lon) -> bool:
    return LAT[0] <= lat <= LAT[1] and LON[0] <= lon <= LON[1]


# --- states -------------------------------------------------------------


def test_states_lists_all_36_with_coordinates(client):
    resp = client.get("/weather/places/states")
    assert resp.status_code == 200
    states = resp.json()["states"]
    assert len(states) == 36
    for state in states:
        assert state["available"] is True
        assert in_india(state["lat"], state["lon"]), state
    names = {s["name"] for s in states}
    # Every state is browsable now, not just Karnataka.
    assert {"Karnataka", "Kerala", "Puducherry", "Ladakh"} <= names


def test_states_are_sorted_and_unique(client):
    states = client.get("/weather/places/states").json()["states"]
    names = [s["name"] for s in states]
    assert names == sorted(names, key=str.casefold)
    assert len(set(names)) == len(names)


def test_states_report_district_counts(client):
    states = {s["name"]: s for s in client.get("/weather/places/states").json()["states"]}
    assert states["Karnataka"]["districts"] >= 30
    assert states["Kerala"]["districts"] >= 14


# --- districts ----------------------------------------------------------


def test_districts_carry_coordinates(client):
    resp = client.get("/weather/places/districts", params={"state": "Karnataka"})
    assert resp.status_code == 200
    data = resp.json()
    assert len(data) >= 30
    names = [d["name"] for d in data]
    assert "Bagalkot" in names
    for district in data:
        assert in_india(district["lat"], district["lon"]), district


def test_districts_work_for_non_karnataka_states(client):
    """The old dataset was Karnataka-only; every state must now resolve."""
    for state in ("Kerala", "Maharashtra", "Punjab", "Assam", "Goa"):
        resp = client.get("/weather/places/districts", params={"state": state})
        assert resp.status_code == 200, state
        assert len(resp.json()) > 0, state


def test_district_lookup_is_case_and_space_insensitive(client):
    base = client.get("/weather/places/districts", params={"state": "Karnataka"}).json()
    for variant in ("KARNATAKA", "  karnataka  ", "Karnataka"):
        resp = client.get("/weather/places/districts", params={"state": variant})
        assert resp.status_code == 200
        assert resp.json() == base


def test_districts_404_for_unknown_state(client):
    resp = client.get("/weather/places/districts", params={"state": "Atlantis"})
    assert resp.status_code == 404
    assert "Atlantis" in resp.json()["detail"]


# --- taluks -------------------------------------------------------------


def test_taluks_carry_coordinates_and_drop_the_taluk_suffix(client):
    resp = client.get(
        "/weather/places/taluks",
        params={"state": "Karnataka", "district": "Bagalkot"},
    )
    assert resp.status_code == 200
    taluks = resp.json()
    names = [t["name"] for t in taluks]
    assert "Badami" in names
    assert "Mudhol" in names
    # GeoNames calls it "Badami Taluk"; the picker already says "Taluk".
    assert "Badami Taluk" not in names
    for taluk in taluks:
        assert in_india(taluk["lat"], taluk["lon"]), taluk


def test_taluks_404_for_unknown_district(client):
    resp = client.get(
        "/weather/places/taluks",
        params={"state": "Karnataka", "district": "Nowhere"},
    )
    assert resp.status_code == 404
    assert "Nowhere" in resp.json()["detail"]


# --- villages -----------------------------------------------------------


def test_villages_carry_real_coordinates(client):
    resp = client.get(
        "/weather/places/villages",
        params={"state": "Karnataka", "district": "Bagalkot", "taluk": "Badami"},
    )
    assert resp.status_code == 200
    villages = resp.json()
    assert len(villages) > 20
    names = [v["name"] for v in villages]
    assert "Adagal" in names
    assert names == sorted(names, key=str.casefold)
    for village in villages:
        assert in_india(village["lat"], village["lon"]), village


def test_village_coordinates_are_distinct_within_a_taluk(client):
    villages = client.get(
        "/weather/places/villages",
        params={"state": "Karnataka", "district": "Bagalkot", "taluk": "Badami"},
    ).json()
    coords = {(round(v["lat"], 3), round(v["lon"], 3)) for v in villages}
    assert len(coords) > 1, "villages must not all share one centroid"


def test_villages_404_for_unknown_taluk(client):
    resp = client.get(
        "/weather/places/villages",
        params={"state": "Karnataka", "district": "Bagalkot", "taluk": "???"},
    )
    assert resp.status_code == 404
    assert "???" in resp.json()["detail"]


# --- resolve ------------------------------------------------------------


def test_resolve_state_level(client):
    data = client.get("/weather/places/resolve", params={"state": "Kerala"}).json()
    assert data["level"] == "state"
    assert data["matched"] == "Kerala"
    assert data["fallback"] is False
    assert in_india(data["lat"], data["lon"])


def test_resolve_district_level(client):
    data = client.get(
        "/weather/places/resolve",
        params={"state": "Karnataka", "district": "Bagalkot"},
    ).json()
    assert data["level"] == "district"
    assert data["district"] == "Bagalkot"
    assert data["taluk"] is None
    assert in_india(data["lat"], data["lon"])


def test_resolve_taluk_level(client):
    data = client.get(
        "/weather/places/resolve",
        params={"state": "Karnataka", "district": "Bagalkot", "taluk": "Badami"},
    ).json()
    assert data["level"] == "taluk"
    assert data["matched"] == "Badami"
    assert in_india(data["lat"], data["lon"])


def test_resolve_village_level_uses_the_village_coordinates(client):
    listed = client.get(
        "/weather/places/villages",
        params={"state": "Karnataka", "district": "Bagalkot", "taluk": "Badami"},
    ).json()
    target = listed[0]
    data = client.get(
        "/weather/places/resolve",
        params={
            "state": "Karnataka",
            "district": "Bagalkot",
            "taluk": "Badami",
            "village": target["name"],
        },
    ).json()
    assert data["level"] == "village"
    assert data["matched"] == target["name"]
    assert data["fallback"] is False
    # The village's own point, not its taluk's.
    assert data["lat"] == pytest.approx(target["lat"], abs=1e-4)
    assert data["lon"] == pytest.approx(target["lon"], abs=1e-4)
    assert data["village"] == target["name"]


def test_resolve_village_ignores_case_and_padding(client):
    data = client.get(
        "/weather/places/resolve",
        params={
            "state": " kArNaTaKa ",
            "district": "bagalkot",
            "taluk": "BADAMI",
            "village": "  adagal ",
        },
    ).json()
    assert data["level"] == "village"
    assert data["matched"] == "Adagal"


def test_resolve_unknown_village_falls_back_to_taluk_and_says_so(client):
    """The honesty contract: never report district weather as a village's."""
    taluk = client.get(
        "/weather/places/resolve",
        params={"state": "Karnataka", "district": "Bagalkot", "taluk": "Badami"},
    ).json()
    data = client.get(
        "/weather/places/resolve",
        params={
            "state": "Karnataka",
            "district": "Bagalkot",
            "taluk": "Badami",
            "village": "Definitely Not A Real Village",
        },
    ).json()
    assert data["level"] == "taluk"
    assert data["fallback"] is True
    assert data["matched"] == "Badami"
    assert data["village"] is None
    assert data["lat"] == pytest.approx(taluk["lat"])
    assert data["lon"] == pytest.approx(taluk["lon"])


def test_resolve_label_reads_as_a_path(client):
    data = client.get(
        "/weather/places/resolve",
        params={
            "state": "Karnataka",
            "district": "Bagalkot",
            "taluk": "Badami",
            "village": "Adagal",
        },
    ).json()
    assert data["label"] == "Karnataka, Bagalkot, Badami, Adagal"
    assert data["region"] == "Bagalkot"
    assert data["country"] == "India"


def test_resolve_requires_state(client):
    assert client.get("/weather/places/resolve").status_code == 422


def test_resolve_404_for_unknown_state(client):
    resp = client.get("/weather/places/resolve", params={"state": "Atlantis"})
    assert resp.status_code == 404


# --- dataset integrity --------------------------------------------------


def test_gazetteer_built_meta(client):
    assert places.is_available()
    gaz = places.gazetteer()
    # Loaded once and cached; the same object comes back.
    assert places.gazetteer() is gaz


def test_every_state_has_at_least_one_district(client):
    for state in client.get("/weather/places/states").json()["states"]:
        resp = client.get(
            "/weather/places/districts", params={"state": state["name"]}
        )
        assert resp.status_code == 200, state["name"]
        assert len(resp.json()) >= 1, state["name"]


def test_village_cache_does_not_leak_across_taluks(client):
    first = client.get(
        "/weather/places/villages",
        params={"state": "Karnataka", "district": "Bagalkot", "taluk": "Badami"},
    ).json()
    second = client.get(
        "/weather/places/villages",
        params={"state": "Karnataka", "district": "Bagalkot", "taluk": "Mudhol"},
    ).json()
    assert {v["name"] for v in first}.isdisjoint({v["name"] for v in second})


def test_places_require_params(client):
    assert client.get("/weather/places/districts").status_code == 422
    assert client.get("/weather/places/taluks", params={"state": "Karnataka"}).status_code == 422
    assert (
        client.get(
            "/weather/places/villages",
            params={"state": "Karnataka", "district": "Bagalkot"},
        ).status_code
        == 422
    )
