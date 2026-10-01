"""Tests for the weather proxy endpoints.

These never touch the network: we monkeypatch `app.weather_service.api_get_json`
with canned provider payloads and assert on the assembled responses,
India/state filtering, caching and error mapping.
"""

import pytest

import app.weather_service as weather_service
from app.main import app

SEARCH_PAYLOAD = [
    {
        "id": 1,
        "name": "Bengaluru",
        "region": "Karnataka",
        "country": "India",
        "lat": 12.9766,
        "lon": 77.5993,
    },
    {
        "id": 2,
        "name": "Mysuru",
        "region": "Karnataka",
        "country": "India",
        "lat": 12.2958,
        "lon": 76.6394,
    },
    {
        "id": 3,
        "name": "Bengaluru (test)",
        "region": "Karnataka",
        "country": "Pakistan",
        "lat": 30.0,
        "lon": 70.0,
    },
    {
        "id": 4,
        "name": "Chennai",
        "region": "Tamil Nadu",
        "country": "India",
        "lat": 13.0827,
        "lon": 80.2707,
    },
]

CURRENT_PAYLOAD = {
    "location": {
        "name": "Tumakuru",
        "region": "Karnataka",
        "country": "India",
        "localtime": "2026-09-24 15:00",
    },
    "current": {
        "temp_c": 34.0,
        "feelslike_c": 36.2,
        "condition": {"text": "Partly cloudy", "icon": "//cdn/116.png"},
        "humidity": 55,
        "wind_kph": 12.6,
        "wind_degree": 240,
        "wind_dir": "WSW",
        "precip_mm": 0.0,
        "uv": 7.0,
        "is_day": 1,
        "last_updated": "2026-09-24 14:45",
    },
}

FORECAST_PAYLOAD = {
    "location": CURRENT_PAYLOAD["location"],
    "current": CURRENT_PAYLOAD["current"],
    "forecast": {
        "forecastday": [
            {
                "date": "2026-09-24",
                "day": {
                    "maxtemp_c": 35.0,
                    "mintemp_c": 23.0,
                    "daily_chance_of_rain": 20,
                    "uv": 8.0,
                    "condition": {"text": "Partly cloudy", "icon": "//cdn/116.png"},
                },
                "astro": {"sunrise": "06:10 AM", "sunset": "06:25 PM"},
                "hour": [
                    {
                        "time": "2026-09-24 12:00",
                        "temp_c": 34.0,
                        "chance_of_rain": 10,
                        "condition": {"text": "Partly cloudy", "icon": "//cdn/116.png"},
                    }
                ],
            },
            {
                "date": "2026-09-25",
                "day": {
                    "maxtemp_c": 29.0,
                    "mintemp_c": 22.0,
                    "daily_chance_of_rain": 85,
                    "uv": 4.0,
                    "condition": {"text": "Heavy rain", "icon": "//cdn/308.png"},
                },
                "astro": {},
                "hour": [],
            },
        ]
    },
    "alerts": {
        "alert": [
            {
                "headline": "Heavy Rain Expected",
                "severity": "Moderate",
                "instruction": "Avoid low-lying areas.",
                "event": "Heavy Rain",
                "effective": "2026-09-25 00:00",
                "expires": "2026-09-26 00:00",
            }
        ]
    },
}


@pytest.fixture(autouse=True)
def _clear_caches():
    weather_service._suggestion_cache._data.clear()
    weather_service._weather_cache._data.clear()
    yield
    weather_service._suggestion_cache._data.clear()
    weather_service._weather_cache._data.clear()


@pytest.fixture()
def api_ready(monkeypatch):
    monkeypatch.setenv("WEATHER_API_KEY", "test-key")
    monkeypatch.setattr("app.weather_service.is_configured", lambda: True)


def _patch_provider(monkeypatch, responses):
    """Replace the provider transport; returns a call counter."""
    calls = {"n": 0}

    def fake_get_json(path, params):
        calls["n"] += 1
        payload = responses.get(path)
        if isinstance(payload, Exception):
            raise payload
        return payload

    monkeypatch.setattr("app.weather_service.api_get_json", fake_get_json)
    return calls


def test_suggestions_never_503s_when_no_key_is_set(client, monkeypatch):
    # No key used to mean a 503. Open-Meteo now serves the request instead, so
    # a fresh checkout gets real weather with no configuration. The provider
    # stub stops the fallback from touching the network.
    monkeypatch.delenv("WEATHER_API_KEY", raising=False)
    monkeypatch.setattr(
        "app.weather_service.open_meteo.search", lambda q, limit=8: []
    )
    resp = client.get("/weather/suggestions", params={"q": "beng"})
    assert resp.status_code == 200
    assert resp.json() == []


def test_suggestions_requires_query(client, api_ready):
    resp = client.get("/weather/suggestions")
    assert resp.status_code == 422


def test_suggestions_filters_to_india_only(client, api_ready, monkeypatch):
    _patch_provider(monkeypatch, {"search.json": SEARCH_PAYLOAD})
    resp = client.get("/weather/suggestions", params={"q": "beng"})
    assert resp.status_code == 200
    data = resp.json()
    names = [item["name"] for item in data]
    assert "Bengaluru" in names
    assert "Bengaluru (test)" not in names  # Pakistan dropped
    assert all(item["country"] == "India" for item in data)
    assert data[0]["lat"] == 12.9766


def test_suggestions_state_filter(client, api_ready, monkeypatch):
    _patch_provider(monkeypatch, {"search.json": SEARCH_PAYLOAD})
    resp = client.get(
        "/weather/suggestions", params={"q": "beng", "state": "Karnataka"}
    )
    assert resp.status_code == 200
    data = resp.json()
    assert {item["name"] for item in data} == {"Bengaluru", "Mysuru"}


def test_suggestions_state_filter_falls_back_when_no_match(
    client, api_ready, monkeypatch
):
    _patch_provider(monkeypatch, {"search.json": SEARCH_PAYLOAD})
    resp = client.get("/weather/suggestions", params={"q": "beng", "state": "Goa"})
    assert resp.status_code == 200
    # No Goa matches: fall back to all-India results so the UI isn't empty.
    assert {item["name"] for item in resp.json()} == {"Bengaluru", "Mysuru", "Chennai"}


def test_weather_never_503s_when_no_key_is_set(client, monkeypatch):
    # Same reason as the suggestions variant: Open-Meteo covers the no-key case.
    monkeypatch.delenv("WEATHER_API_KEY", raising=False)
    monkeypatch.setattr(
        "app.weather_service.open_meteo.fetch",
        lambda lat, lon, name="": {"source": "open-meteo"},
    )
    resp = client.get("/weather", params={"lat": 12.97, "lon": 77.59})
    assert resp.status_code == 200
    assert resp.json()["source"] == "open-meteo"


def test_weather_validates_coordinates(client, api_ready):
    resp = client.get("/weather", params={"lat": 200, "lon": 77.59})
    assert resp.status_code == 422
    resp = client.get("/weather", params={"lat": 12.97, "lon": 500})
    assert resp.status_code == 422
    resp = client.get("/weather")
    assert resp.status_code == 422


def test_weather_fetches_and_assembles(client, api_ready, monkeypatch):
    calls = _patch_provider(
        monkeypatch,
        {"current.json": CURRENT_PAYLOAD, "forecast.json": FORECAST_PAYLOAD},
    )
    resp = client.get("/weather", params={"lat": 12.97, "lon": 77.59, "name": "Tumakuru"})
    assert resp.status_code == 200
    data = resp.json()

    assert data["location"]["name"] == "Tumakuru"
    assert data["current"]["temp_c"] == 34.0
    assert data["current"]["feelslike_c"] == 36.2
    assert data["current"]["humidity"] == 55
    assert data["current"]["wind_dir"] == "WSW"
    assert data["current"]["uv"] == 7.0
    assert data["astro"]["sunrise"] == "06:10 AM"

    assert len(data["hourly"]) == 1
    assert data["hourly"][0]["temp_c"] == 34.0

    assert len(data["daily"]) == 2
    assert data["daily"][1]["chance_of_rain"] == 85
    assert data["daily"][1]["condition"]["text"] == "Heavy rain"

    assert len(data["alerts"]) == 1
    assert data["alerts"][0]["headline"] == "Heavy Rain Expected"

    # 2 provider calls expected (current + forecast).
    assert calls["n"] == 2


def test_weather_is_cached(client, api_ready, monkeypatch):
    calls = _patch_provider(
        monkeypatch,
        {"current.json": CURRENT_PAYLOAD, "forecast.json": FORECAST_PAYLOAD},
    )
    params = {"lat": 13.0, "lon": 80.2, "name": "Chennai"}
    assert client.get("/weather", params=params).status_code == 200
    assert client.get("/weather", params=params).status_code == 200
    # Second hit served from cache: only one fetch for current + forecast.
    assert calls["n"] == 2


def test_weather_maps_provider_errors_to_502(client, api_ready, monkeypatch):
    _patch_provider(
        monkeypatch,
        {
            "current.json": RuntimeError("Weather provider request failed: boom"),
            "forecast.json": CURRENT_PAYLOAD,
        },
    )
    resp = client.get("/weather", params={"lat": 12.97, "lon": 77.59})
    assert resp.status_code == 502
    assert "boom" in resp.json()["detail"]