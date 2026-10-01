"""Tests for the Open-Meteo fallback provider.

No network: `app.open_meteo._get_json` is monkeypatched with canned payloads.
These cover India filtering, the WMO code -> text mapping (the Flutter client
derives its Material icon from that text), the 24-hour strip that must start
at the current hour rather than midnight, and the shape parity with the
WeatherAPI provider so the app needs no client-side branching.
"""

import pytest

import app.open_meteo as open_meteo
import app.weather_service as weather_service
from app.main import app

GEOCODE_PAYLOAD = {
    "results": [
        {
            "id": 1,
            "name": "Bengaluru",
            "latitude": 12.97194,
            "longitude": 77.59369,
            "country_code": "IN",
            "admin1": "Karnataka",
        },
        {
            "id": 2,
            "name": "Bengaluru",
            "latitude": 33.5,
            "longitude": 69.2,
            "country_code": "AF",
            "admin1": "Kabul",
        },
        {
            "id": 3,
            "name": "Mysuru",
            "latitude": 12.2958,
            "longitude": 76.6394,
            "country_code": "IN",
            "admin1": "Karnataka",
        },
    ]
}

FORECAST_PAYLOAD = {
    "timezone": "Asia/Kolkata",
    "current": {
        "time": "2026-09-30T14:15",
        "temperature_2m": 25.7,
        "relative_humidity_2m": 69,
        "apparent_temperature": 26.1,
        "precipitation": 0.4,
        "weather_code": 3,
        "wind_speed_10m": 3.3,
        "wind_direction_10m": 225,
        "is_day": 1,
    },
    "hourly": {
        "time": [
            "2026-09-30T00:00",
            "2026-09-30T01:00",
            "2026-09-30T14:00",
            "2026-09-30T15:00",
            "2026-10-01T00:00",
        ],
        "temperature_2m": [21.0, 20.5, 26.9, 27.4, 24.0],
        "precipitation_probability": [10, 10, 60, 55, 20],
        "weather_code": [0, 0, 61, 61, 3],
    },
    "daily": {
        "time": ["2026-09-30", "2026-10-01"],
        "weather_code": [80, 3],
        "temperature_2m_max": [28.1, 27.4],
        "temperature_2m_min": [19.5, 19.0],
        "precipitation_sum": [6.2, 1.1],
        "precipitation_probability_max": [96, 40],
        "uv_index_max": [7.95, 6.1],
        "sunrise": ["2026-09-30T06:08", "2026-10-01T06:09"],
        "sunset": ["2026-09-30T18:10", "2026-10-01T18:09"],
    },
}


@pytest.fixture
def stub(monkeypatch):
    """Serve canned payloads and record the requested URLs."""
    calls = []

    def fake_get_json(base, path, params):
        calls.append((path, params))
        if path == "search":
            return GEOCODE_PAYLOAD
        return FORECAST_PAYLOAD

    monkeypatch.setattr(open_meteo, "_get_json", fake_get_json)
    weather_service._suggestion_cache._data.clear()
    weather_service._weather_cache._data.clear()
    return calls


# --- provider selection -------------------------------------------------


def test_is_configured_without_any_key(monkeypatch):
    monkeypatch.delenv("WEATHER_API_KEY", raising=False)
    assert weather_service.is_configured() is True
    assert weather_service.provider_name() == "open-meteo"


def test_provider_switches_to_weatherapi_when_key_present(monkeypatch):
    monkeypatch.setenv("WEATHER_API_KEY", "abc123")
    assert weather_service.provider_name() == "weatherapi"


# --- search -------------------------------------------------------------


def test_search_filters_out_non_india(stub):
    results = open_meteo.search("bengaluru")
    assert [r["name"] for r in results] == ["Bengaluru", "Mysuru"]
    # The Afghanistan result (country_code "AF") is dropped entirely.
    assert all(r["lat"] in (12.97194, 12.2958) for r in results)
    assert all(r["country"] == "India" for r in results)


def test_search_overfetches_because_most_hits_are_filtered(stub):
    open_meteo.search("bengaluru", limit=8)
    _, params = stub[0]
    assert int(params["count"]) >= 20


def test_search_handles_no_results(monkeypatch):
    # Open-Meteo omits the "results" key entirely when nothing matches.
    monkeypatch.setattr(open_meteo, "_get_json", lambda base, path, params: {})
    assert open_meteo.search("zzzzzzzz") == []


def test_state_filter_applies_to_fallback_results(stub):
    results = weather_service.fetch_suggestions("bengaluru", "Karnataka")
    assert {r["region"] for r in results} == {"Karnataka"}
    assert len(results) == 2


def test_state_filter_falls_back_to_all_india(stub):
    results = weather_service.fetch_suggestions("bengaluru", "Kerala")
    assert len(results) == 2


# --- weather fetch ------------------------------------------------------


def test_fetch_normalizes_to_weatherapi_shape(stub):
    data = open_meteo.fetch(12.97194, 77.59369, "Bengaluru")

    assert data["source"] == "open-meteo"
    assert data["location"]["name"] == "Bengaluru"
    assert data["current"]["temp_c"] == 25.7
    assert data["current"]["feelslike_c"] == 26.1
    assert data["current"]["humidity"] == 69
    assert data["current"]["precip_mm"] == 0.4
    assert data["current"]["is_day"] == 1
    # No icon URL from this provider; the app falls back to a Material icon.
    assert data["current"]["condition"] == {"text": "Overcast", "icon": ""}


def test_unnamed_location_is_not_labelled_with_the_timezone(stub):
    # Regression: the provider's timezone for all of India is "Asia/Kolkata",
    # so using it as the place name labelled every unnamed location "Kolkata".
    data = open_meteo.fetch(10.3184, 77.1858)

    assert data["location"]["name"] == "10.318, 77.186"
    assert "Kolkata" not in data["location"]["name"]


def test_cached_coordinates_still_report_the_callers_place_name(stub):
    # The cache is keyed by coordinates, so a nameless first request must not
    # pin the coordinate fallback as the label for later requests.
    first = weather_service.fetch_weather(10.3184, 77.1858, "")
    second = weather_service.fetch_weather(10.3184, 77.1858, "Alampatti")

    assert first["location"]["name"] == "10.318, 77.186"
    assert second["location"]["name"] == "Alampatti"
    # Same underlying payload, so no provider call was needed for the rename.
    assert second["current"]["temp_c"] == first["current"]["temp_c"]


def test_wind_degrees_become_a_compass_point(stub):
    data = open_meteo.fetch(12.97, 77.59)
    assert data["current"]["wind_degree"] == 225
    assert data["current"]["wind_dir"] == "SW"


def test_hourly_starts_at_current_hour_not_midnight(stub):
    data = open_meteo.fetch(12.97, 77.59)
    assert [h["time"] for h in data["hourly"]] == [
        "2026-09-30T14:00",
        "2026-09-30T15:00",
        "2026-10-01T00:00",
    ]
    assert data["hourly"][0]["chance_of_rain"] == 60
    assert data["hourly"][0]["temp_c"] == 26.9


def test_astro_and_daily_and_empty_alerts(stub):
    data = open_meteo.fetch(12.97, 77.59)
    assert data["astro"]["sunrise"] == "2026-09-30T06:08"
    assert data["astro"]["sunset"] == "2026-09-30T18:10"
    assert len(data["daily"]) == 2
    assert data["daily"][0]["chance_of_rain"] == 96
    assert data["daily"][0]["max_temp_c"] == 28.1
    assert data["alerts"] == []


def test_current_uv_uses_todays_daily_maximum(stub):
    data = open_meteo.fetch(12.97, 77.59)
    assert data["current"]["uv"] == 7.95


@pytest.mark.parametrize(
    "code,expected",
    [
        (0, "Clear sky"),
        (2, "Partly cloudy"),
        (3, "Overcast"),
        (45, "Fog"),
        (53, "Moderate drizzle"),
        (63, "Moderate rain"),
        (75, "Heavy snow fall"),
        (82, "Violent rain showers"),
        (95, "Thunderstorm"),
        (99, "Thunderstorm with heavy hail"),
    ],
)
def test_wmo_codes_map_to_text_the_flutter_icon_matcher_understands(code, expected):
    assert open_meteo._condition(code)["text"] == expected


def test_unknown_wmo_code_does_not_crash():
    assert open_meteo._condition(1234) == {"text": "Unknown", "icon": ""}
    assert open_meteo._condition(None) == {"text": "Unknown", "icon": ""}


@pytest.mark.parametrize(
    "degrees,expected",
    [(0, "N"), (45, "NE"), (90, "E"), (180, "S"), (225, "SW"), (350, "N"), (None, "")],
)
def test_compass_points(degrees, expected):
    assert open_meteo._compass(degrees) == expected


def test_short_or_null_arrays_are_tolerated(monkeypatch):
    monkeypatch.setattr(
        open_meteo,
        "_get_json",
        lambda base, path, params: {
            "current": {"time": "2026-09-30T14:15"},
            "hourly": {"time": ["2026-09-30T00:00"]},
            "daily": {"time": []},
        },
    )
    data = open_meteo.fetch(12.97, 77.59)
    assert data["current"]["temp_c"] is None
    assert data["current"]["wind_dir"] == ""
    assert data["daily"] == []
    assert data["hourly"][0]["temp_c"] is None


# --- endpoint integration ------------------------------------------------


def test_suggestions_endpoint_serves_fallback(client, stub, monkeypatch):
    monkeypatch.delenv("WEATHER_API_KEY", raising=False)
    response = client.get("/weather/suggestions", params={"q": "bengaluru"})
    assert response.status_code == 200
    assert [r["name"] for r in response.json()] == ["Bengaluru", "Mysuru"]


def test_weather_endpoint_serves_fallback(client, stub, monkeypatch):
    monkeypatch.delenv("WEATHER_API_KEY", raising=False)
    response = client.get(
        "/weather", params={"lat": 12.97194, "lon": 77.59369, "name": "Bengaluru"}
    )
    assert response.status_code == 200
    assert response.json()["source"] == "open-meteo"
