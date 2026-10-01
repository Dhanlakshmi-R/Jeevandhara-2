# Jeevandhara 2 — Frontend (Flutter)

## Setup

Requires the Flutter SDK installed (`flutter --version` to check).

```bash
cd frontend
flutter pub get
```

## Before running: point it at your backend

Open `lib/services/api_service.dart` and check `baseUrl`:

- **Android emulator** (default, already set): `http://10.0.2.2:8000`
- **iOS simulator**: `http://localhost:8000`
- **Physical device**: your computer's LAN IP, e.g. `http://192.168.1.5:8000`
  (device and computer must be on the same Wi-Fi network)

## Run

Make sure the backend (see `../backend/README.md`) is running first, then:

```bash
flutter run
```

## What's in this scaffold

- `lib/main.dart` — checks for a saved login token on startup and routes
  to Login or Home accordingly.
- `lib/screens/login_screen.dart`, `register_screen.dart` — auth screens.
- `lib/screens/home_screen.dart` — the app shell: shows the logged-in
  user and a grid of placeholder tiles, one per ASIP objective. Each
  tile currently just shows a "coming soon" message — replace that
  `onTap` with real navigation as each objective is built.
- `lib/services/api_service.dart` — all HTTP calls to the backend and
  token storage (`shared_preferences`). Add new methods here (e.g.
  `getWeather()`, `getCropPrices()`) as each objective's backend
  endpoint becomes available.
- `lib/models/user.dart` — matches the backend's `UserOut` schema.

## Weather module

The weather tab is live: real conditions, forecast and rule-based
farming advice, all proxied through the backend so no API key ships in
the app.

| File | Role |
|------|------|
| `lib/services/weather_service.dart` | HTTP client for `/weather` + `/weather/places/*`, plus pure parsers |
| `lib/services/place_search.dart` | Debounced, race-safe suggestion controller |
| `lib/services/weather_recommendations.dart` | Rule-based farmer guidance from real values |
| `lib/services/weather_place_store.dart` | Persists the last chosen place (SharedPreferences) |
| `lib/screens/weather_screen.dart` | Dashboard: hero card, metrics, hourly + daily forecast, alerts |
| `lib/screens/place_search_screen.dart` | Searchable location picker |
| `lib/screens/find_place_screen.dart` | Picker shell: **Search by name** / **Browse district** |

### Picking a location

Two paths, both popping a `WeatherSuggestion` that the dashboard then
uses to fetch weather for those exact coordinates:

- **Search by name** — free-text autocomplete against the provider's
  Indian gazetteer. Suggestions appear after one character, are
  debounced (300 ms) so typing never floods the API, and are rendered as
  `Bengaluru, Karnataka, India`. The state dropdown narrows results;
  arrow keys move the highlight, Enter selects, Escape closes the list.
  Covers all states and union territories.
- **Browse district** — the offline GeoNames cascade
  (State → District → Taluk → Village) from the backend's bundled
  gazetteer, covering all of India: 36 states/UTs, 763 districts,
  6,891 sub-districts and 554,135 settlements.

  **You can stop at any level.** Picking just a state, or a district, or a
  taluk is a complete answer — the button reads `Show weather for Bagalkot`
  and uses that level's own coordinates, so you never have to drill down to
  a village to get weather.

  Every level is resolved through `/weather/places/resolve`, so no name is
  ever sent to a geocoding provider. If the gazetteer has no record for a
  chosen village, the picker **does not silently substitute the taluk**: it
  shows a card naming the coarser point and its level, and only fetches it
  if you tap *Use it anyway*. *Pick another* returns to the cascade with
  your village still selected. The resulting `WeatherSuggestion.name` is the
  place that was actually matched, so taluk weather is never displayed under
  a village's name.

  State, district, taluk and village lists all arrive with coordinates, so
  per-level load failures surface inline with a *Retry* button instead of an
  empty dropdown.

The gazetteer is a build artifact of
[`../backend/scripts/build_india_places.py`](../backend/scripts/build_india_places.py);
regenerate it with that script after cloning. Two coverage caveats come from
the source data: settlements that belong to no sub-district are not browsable,
and district names follow GeoNames rather than today's official list.

### Configuration

The app needs no key of its own. The backend picks a provider at startup:
**Open-Meteo** (no key required) by default, or **WeatherAPI.com** when
`WEATHER_API_KEY` is set in `backend/.env` — see
[`../backend/README.md`](../backend/README.md). Weather works out of the box;
a key only adds severe-weather alerts.

If the backend itself is not running, the app says so explicitly
("Cannot reach the server") rather than showing a generic retry.

### Tests

```bash
flutter test test/place_search_test.dart          # search + recommendations
flutter test test/find_place_screen_test.dart     # picker (both paths)
flutter test test/weather_screen_test.dart        # dashboard
flutter test test/weather_parse_test.dart         # response parsing
```


## What's next

For each new objective, add: one method in `api_service.dart` calling
the new backend endpoint, and one new screen in `lib/screens/`, then
wire it into the matching tile in `home_screen.dart`.
