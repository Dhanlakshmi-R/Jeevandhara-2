"""Open-Meteo fallback provider — serves real weather with NO API key.

`weather_service` uses WeatherAPI.com whenever `WEATHER_API_KEY` is set (it
gives severe-weather alerts and a richer current block). When the key is
absent we fall back to this module so the app still works out of the box
rather than showing a 503.

Both providers are normalized into the SAME payload shape, so the Flutter
client never needs to know which one answered.

Env vars: none required. `OPEN_METEO_BASE` exists only so tests can point at a
local stub server.
"""

import json
import logging
import os
import urllib.error
import urllib.parse
import urllib.request

logger = logging.getLogger("jeevandhara.weather.openmeteo")

_GEOCODE_BASE = os.getenv(
    "OPEN_METEO_GEOCODE_BASE", "https://geocoding-api.open-meteo.com/v1"
)
_FORECAST_BASE = os.getenv("OPEN_METEO_BASE", "https://api.open-meteo.com/v1")

# WMO 4677 weather codes as used by Open-Meteo -> human text.
# The Flutter client picks a Material icon by matching substrings in this
# text ('rain', 'snow', 'thunder', 'fog', 'cloud', 'sun'/'clear'), so the
# wording below is part of the contract.
_WMO_TEXT = {
    0: "Clear sky",
    1: "Mainly clear",
    2: "Partly cloudy",
    3: "Overcast",
    45: "Fog",
    48: "Depositing rime fog",
    51: "Light drizzle",
    53: "Moderate drizzle",
    55: "Dense drizzle",
    56: "Light freezing drizzle",
    57: "Dense freezing drizzle",
    61: "Slight rain",
    63: "Moderate rain",
    65: "Heavy rain",
    66: "Light freezing rain",
    67: "Heavy freezing rain",
    71: "Slight snow fall",
    73: "Moderate snow fall",
    75: "Heavy snow fall",
    77: "Snow grains",
    80: "Slight rain showers",
    81: "Moderate rain showers",
    82: "Violent rain showers",
    85: "Slight snow showers",
    86: "Heavy snow showers",
    95: "Thunderstorm",
    96: "Thunderstorm with slight hail",
    99: "Thunderstorm with heavy hail",
}

_COMPASS = (
    "N", "NNE", "NE", "ENE", "E", "ESE", "SE", "SSE",
    "S", "SSW", "SW", "WSW", "W", "WNW", "NW", "NNW",
)

_CURRENT_FIELDS = (
    "temperature_2m,relative_humidity_2m,apparent_temperature,precipitation,"
    "weather_code,wind_speed_10m,wind_direction_10m,is_day"
)
_HOURLY_FIELDS = "temperature_2m,precipitation_probability,weather_code"
_DAILY_FIELDS = (
    "weather_code,temperature_2m_max,temperature_2m_min,precipitation_sum,"
    "precipitation_probability_max,uv_index_max,sunrise,sunset"
)


def _get_json(base: str, path: str, params: dict[str, str]) -> dict:
    """GET and parse JSON. Raises RuntimeError so the router can return 502."""
    url = f"{base}/{path}?{urllib.parse.urlencode(params)}"
    request = urllib.request.Request(url, headers={"Accept": "application/json"})
    try:
        with urllib.request.urlopen(request, timeout=10) as response:
            body = response.read().decode("utf-8", "replace")
    except urllib.error.HTTPError as exc:
        detail = exc.read().decode("utf-8", "replace")
        raise RuntimeError(
            f"Open-Meteo returned HTTP {exc.code}: {detail[:300]}"
        ) from exc
    except urllib.error.URLError as exc:
        raise RuntimeError(f"Open-Meteo request failed: {exc}") from exc

    try:
        payload = json.loads(body)
    except ValueError as exc:
        raise RuntimeError("Open-Meteo returned an invalid response") from exc
    if not isinstance(payload, dict):
        raise RuntimeError("Open-Meteo returned an unexpected payload")
    return payload


def _condition(code) -> dict:
    """No icon URL: the app falls back to a Material icon from the text."""
    try:
        text = _WMO_TEXT[int(code)]
    except (TypeError, ValueError, KeyError):
        text = "Unknown"
    return {"text": text, "icon": ""}


def _compass(degrees) -> str:
    if degrees is None:
        return ""
    try:
        index = int((float(degrees) % 360) / 22.5 + 0.5) % 16
    except (TypeError, ValueError):
        return ""
    return _COMPASS[index]


def _at(values, index, key=None):
    """Read list[index], tolerating nulls and short arrays."""
    if not isinstance(values, list) or index >= len(values):
        return None
    value = values[index]
    if key is None:
        return value
    return value.get(key) if isinstance(value, dict) else None


def search(query: str, limit: int = 8) -> list[dict]:
    """Indian place suggestions, already shaped like WeatherAPI results."""
    payload = _get_json(
        _GEOCODE_BASE,
        "search",
        {
            "name": query,
            # Over-fetch: most global hits are filtered out by the India check.
            "count": str(min(max(limit * 5, 20), 100)),
            "language": "en",
            "format": "json",
        },
    )

    results = []
    for item in payload.get("results") or []:
        if not isinstance(item, dict):
            continue
        # Open-Meteo gives ISO country codes rather than names.
        if str(item.get("country_code", "")).upper() != "IN":
            continue
        try:
            results.append(
                {
                    "name": str(item.get("name", "")).strip(),
                    "region": str(item.get("admin1", "") or "").strip(),
                    "country": "India",
                    "lat": float(item["latitude"]),
                    "lon": float(item["longitude"]),
                }
            )
        except (KeyError, TypeError, ValueError):
            continue
    return results[:limit]


def fetch(lat: float, lon: float, name: str = "") -> dict:
    """Current + hourly + daily, normalized to the WeatherAPI payload shape."""
    payload = _get_json(
        _FORECAST_BASE,
        "forecast",
        {
            "latitude": f"{lat}",
            "longitude": f"{lon}",
            "current": _CURRENT_FIELDS,
            "hourly": _HOURLY_FIELDS,
            "daily": _DAILY_FIELDS,
            "timezone": "auto",
            "forecast_days": "7",
        },
    )

    current = payload.get("current") or {}
    hourly = payload.get("hourly") or {}
    daily = payload.get("daily") or {}

    current_time = str(current.get("time", ""))

    # Start the 24-hour strip at the current hour. Open-Meteo returns whole
    # days of hourly data, so the first entry is usually midnight. Compare
    # only the "YYYY-MM-DDTHH" prefix: current.time carries minutes (14:15),
    # and a full-string compare would skip the 14:00 bucket we are standing in.
    times = hourly.get("time") if isinstance(hourly.get("time"), list) else []
    current_hour = current_time[:13]
    start = 0
    for index, stamp in enumerate(times):
        if isinstance(stamp, str) and stamp[:13] >= current_hour:
            start = index
            break

    hourly_out = []
    for offset in range(24):
        index = start + offset
        if index >= len(times):
            break
        hourly_out.append(
            {
                "time": times[index],
                "temp_c": _at(hourly.get("temperature_2m"), index),
                "chance_of_rain": _at(
                    hourly.get("precipitation_probability"), index
                ) or 0,
                "condition": _condition(_at(hourly.get("weather_code"), index)),
            }
        )

    daily_times = daily.get("time") if isinstance(daily.get("time"), list) else []
    daily_out = []
    for index, date in enumerate(daily_times):
        daily_out.append(
            {
                "date": date,
                "max_temp_c": _at(daily.get("temperature_2m_max"), index),
                "min_temp_c": _at(daily.get("temperature_2m_min"), index),
                "chance_of_rain": _at(
                    daily.get("precipitation_probability_max"), index
                ) or 0,
                "uv": _at(daily.get("uv_index_max"), index),
                "condition": _condition(_at(daily.get("weather_code"), index)),
            }
        )

    # Open-Meteo exposes UV only as a daily maximum, so today's max stands in
    # for the current reading. Real provider data either way — never invented.
    today_uv = daily_out[0]["uv"] if daily_out else None

    return {
        "location": {
            # Never fall back to the timezone name: India's zone is "Asia/Kolkata",
            # so every unnamed location in the country would be labelled Kolkata.
            # Coordinates are unambiguous and honest about the precision.
            "name": name or f"{lat:.3f}, {lon:.3f}",
            "region": "",
            "country": "India",
            "localtime": current_time,
        },
        "current": {
            "temp_c": current.get("temperature_2m"),
            "feelslike_c": current.get("apparent_temperature"),
            "condition": _condition(current.get("weather_code")),
            "humidity": current.get("relative_humidity_2m"),
            "wind_kph": current.get("wind_speed_10m"),
            "wind_degree": current.get("wind_direction_10m"),
            "wind_dir": _compass(current.get("wind_direction_10m")),
            "precip_mm": current.get("precipitation", 0),
            "uv": today_uv,
            "is_day": current.get("is_day", 1),
            "last_updated": current_time,
        },
        "astro": {
            "sunrise": str(_at(daily.get("sunrise"), 0) or ""),
            "sunset": str(_at(daily.get("sunset"), 0) or ""),
        },
        "hourly": hourly_out,
        "daily": daily_out,
        # Open-Meteo has no severe-weather alert feed.
        "alerts": [],
        "source": "open-meteo",
    }
