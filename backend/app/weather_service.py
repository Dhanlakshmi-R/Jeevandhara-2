"""Weather provider proxy — the ONLY place that talks to a weather provider.

The Flutter app calls OUR endpoints (`/weather/...`); API keys never leave
the backend. Env vars: WEATHER_API_KEY (optional) and optionally
WEATHER_API_BASE (defaults to WeatherAPI.com v1).

Two providers, one payload shape:
  * WeatherAPI.com when WEATHER_API_KEY is set — the primary. Free tier gives
    current weather + autocomplete + a 3-day forecast; the paid plan unlocks
    a 7-day forecast and severe-weather alerts. We request `days=7` and
    forward whatever the plan returns — we never fake data.
  * Open-Meteo (`app/open_meteo.py`) when the key is absent. Needs no
    signup, so the app works out of the box. No alert feed.

`is_configured()` stays True for both, so the endpoints never 503 on a fresh
checkout. The active provider is reported in the payload's `source` field.
"""

import json
import logging
import os
import threading
import time
import urllib.error
import urllib.parse
import urllib.request

from . import open_meteo

logger = logging.getLogger("jeevandhara.weather")

_API_BASE = os.getenv("WEATHER_API_BASE", "https://api.weatherapi.com/v1")

_WEATHER_CACHE_TTL = 600  # 10 minutes for current + forecast
_SUGGESTION_CACHE_TTL = 1800  # 30 minutes for place autocomplete
_CACHE_MAX = 200


class TtlCache:
    """Small thread-safe TTL cache keyed by the normalized API request."""

    def __init__(self, ttl: float, max_items: int = _CACHE_MAX) -> None:
        self._ttl = ttl
        self._max = max_items
        self._data: dict[str, tuple[float, object]] = {}
        self._lock = threading.Lock()

    def get(self, key: str):
        with self._lock:
            item = self._data.get(key)
            if item is None:
                return None
            expires_at, value = item
            if time.monotonic() > expires_at:
                self._data.pop(key, None)
                return None
            return value

    def set(self, key: str, value: object) -> None:
        with self._lock:
            if len(self._data) >= self._max:
                oldest = min(self._data, key=lambda k: self._data[k][0])
                self._data.pop(oldest, None)
            self._data[key] = (time.monotonic() + self._ttl, value)


_suggestion_cache = TtlCache(_SUGGESTION_CACHE_TTL)
_weather_cache = TtlCache(_WEATHER_CACHE_TTL)


def has_weatherapi_key() -> bool:
    return bool(os.getenv("WEATHER_API_KEY", "").strip())


def provider_name() -> str:
    """Which provider is serving requests right now."""
    return "weatherapi" if has_weatherapi_key() else "open-meteo"


def is_configured() -> bool:
    """Always True: Open-Meteo needs no key, so a fresh checkout still works."""
    return True


def api_get_json(path: str, params: dict[str, str]) -> dict:
    """GET a WeatherAPI endpoint and return parsed JSON. Raises RuntimeError
    on any transport/provider error so the router can map it to a 502."""
    params["key"] = os.getenv("WEATHER_API_KEY", "").strip()
    url = f"{_API_BASE}/{path}?{urllib.parse.urlencode(params)}"
    request = urllib.request.Request(url, headers={"Accept": "application/json"})
    try:
        with urllib.request.urlopen(request, timeout=10) as response:
            body = response.read().decode("utf-8", "replace")
    except urllib.error.HTTPError as exc:
        detail = exc.read().decode("utf-8", "replace")
        raise RuntimeError(
            f"Weather provider returned HTTP {exc.code}: {detail[:300]}"
        ) from exc
    except urllib.error.URLError as exc:
        raise RuntimeError(f"Weather provider request failed: {exc}") from exc

    try:
        payload = json.loads(body)
    except ValueError as exc:
        raise RuntimeError("Weather provider returned an invalid response") from exc
    return payload


def _is_india(country: str) -> bool:
    return country.strip().lower() in {"india", "in", "bharat"}


def fetch_suggestions(query: str, state: str | None, limit: int = 8) -> list[dict]:
    """Search Indian places. `state` (e.g. 'Karnataka') narrows results."""
    cache_key = json.dumps(["search", query.strip().lower(), state], sort_keys=True)
    cached = _suggestion_cache.get(cache_key)
    if cached is not None:
        return cached

    results = (
        _search_weatherapi(query, limit)
        if has_weatherapi_key()
        else open_meteo.search(query, limit)
    )

    if state:
        wanted = state.strip().lower()
        filtered = [r for r in results if r["region"].lower() == wanted]
        if filtered:
            results = filtered

    results = results[:limit]
    _suggestion_cache.set(cache_key, results)
    return results


def _search_weatherapi(query: str, limit: int) -> list[dict]:
    payload = api_get_json(
        "search.json", {"q": query, "limit": str(max(limit, 1))}
    )
    if not isinstance(payload, list):
        raise RuntimeError("Weather provider returned an unexpected payload")

    results = []
    for item in payload:
        if not _is_india(item.get("country", "")):
            continue
        try:
            results.append(
                {
                    "name": str(item.get("name", "")).strip(),
                    "region": str(item.get("region", "")).strip(),
                    "country": str(item.get("country", "")).strip(),
                    "lat": float(item["lat"]),
                    "lon": float(item["lon"]),
                }
            )
        except (KeyError, TypeError, ValueError):
            continue
    return results


def _condition(item: dict) -> dict:
    cond = item.get("condition", {}) or {}
    return {
        "text": cond.get("text", ""),
        "icon": cond.get("icon", ""),
    }


def _with_name(result: dict, name: str) -> dict:
    """Layer the caller's chosen place name onto a provider payload.

    The cache is keyed by coordinates because the forecast depends only on
    those, so the display name is applied per request instead of being baked
    into the cached entry. Without this, the first caller's name (or the
    coordinate fallback) would be shown for everyone else at those
    coordinates.
    """
    label = (name or "").strip()
    if not label:
        return result
    return {**result, "location": {**(result.get("location") or {}), "name": label}}


def fetch_weather(lat: float, lon: float, name: str) -> dict:
    """Current conditions + hourly + daily forecast + alerts for coordinates."""
    cache_key = json.dumps(["weather", round(lat, 4), round(lon, 4)], sort_keys=True)
    cached = _weather_cache.get(cache_key)
    if cached is not None:
        return _with_name(cached, name)

    if not has_weatherapi_key():
        # Cache the unnamed payload; the name is layered on below.
        result = open_meteo.fetch(lat, lon, "")
        _weather_cache.set(cache_key, result)
        return _with_name(result, name)

    current = api_get_json("current.json", {"q": f"{lat},{lon}", "aqi": "no"})
    forecast = api_get_json(
        "forecast.json",
        {"q": f"{lat},{lon}", "days": "7", "aqi": "no", "alerts": "yes"},
    )

    loc = current.get("location", {}) or {}
    cur = current.get("current", {}) or {}
    forecastday = ((forecast.get("forecast", {}) or {}).get("forecastday", [])) or []

    hourly = []
    if forecastday:
        for hour in forecastday[0].get("hour", []) or []:
            hourly.append(
                {
                    "time": hour.get("time", ""),
                    "temp_c": hour.get("temp_c"),
                    "chance_of_rain": hour.get("chance_of_rain", 0),
                    **{"condition": _condition(hour)},
                }
            )

    daily = []
    for day in forecastday:
        day_data = day.get("day", {}) or {}
        daily.append(
            {
                "date": day.get("date", ""),
                "max_temp_c": day_data.get("maxtemp_c"),
                "min_temp_c": day_data.get("mintemp_c"),
                "chance_of_rain": day_data.get("daily_chance_of_rain", 0),
                "uv": day_data.get("uv"),
                "condition": _condition(day_data),
            }
        )

    alerts = []
    alert_node = forecast.get("alerts", {}) or {}
    for alert in alert_node.get("alert", []) or []:
        alerts.append(
            {
                "headline": alert.get("headline", ""),
                "severity": alert.get("severity", ""),
                "instruction": alert.get("instruction", ""),
                "event": alert.get("event", ""),
                "effective": alert.get("effective", ""),
                "expires": alert.get("expires", ""),
            }
        )

    astro = {}
    if forecastday:
        astro = forecastday[0].get("astro", {}) or {}

    result = {
        "location": {
            "name": name or loc.get("name", ""),
            "region": loc.get("region", ""),
            "country": loc.get("country", ""),
            "localtime": loc.get("localtime", ""),
        },
        "current": {
            "temp_c": cur.get("temp_c"),
            "feelslike_c": cur.get("feelslike_c"),
            "condition": _condition(cur),
            "humidity": cur.get("humidity"),
            "wind_kph": cur.get("wind_kph"),
            "wind_degree": cur.get("wind_degree"),
            "wind_dir": cur.get("wind_dir", ""),
            "precip_mm": cur.get("precip_mm", 0),
            "uv": cur.get("uv"),
            "is_day": cur.get("is_day", 1),
            "last_updated": cur.get("last_updated", ""),
        },
        "astro": {"sunrise": astro.get("sunrise", ""), "sunset": astro.get("sunset", "")},
        "hourly": hourly,
        "daily": daily,
        "alerts": alerts,
        "source": "weatherapi",
    }
    _weather_cache.set(cache_key, result)
    return _with_name(result, name)