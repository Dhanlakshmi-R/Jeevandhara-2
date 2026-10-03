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

`10.0.2.2` is how the Android emulator reaches the host machine's `localhost`.
Using `localhost` from an emulator points at the emulator itself, which is the
most common reason a fresh setup shows "Cannot reach the server".

## Run

Make sure the backend (see `../backend/README.md`) is running first, then:

```bash
flutter run
```

## Tests

```bash
cd frontend
flutter test
```

75 tests pass. For a single file:

```bash
flutter test test/weather_screen_test.dart
```

## What's in this app

- `lib/main.dart` — routes to splash → login or shell based on a saved token.
- `lib/app/` — the destination registry and responsive shell. One registry
  drives the sidebar, bottom nav, command palette and deep links.
- `lib/chat/` — the assistant screen: SSE streaming, tool-result cards,
  citation chips, thinking indicator, composer.
- `lib/design/` — design tokens, palette, typography, motion.
- `lib/widgets/ui/` — shared primitives (buttons, cards, inputs, modals,
  loading/empty/error states).
- `lib/theme/` — `app_theme.dart`, `colors.dart` (`context.colors`), and
  `locale.dart` which holds every English and Kannada string.
- `lib/services/api_service.dart` — HTTP calls and token storage.

### App shell

One shell, role-aware rather than duplicated. `AppDestination` in
`lib/app/destinations.dart` is the single source of truth for what exists and
who can see it; farmer-only screens are unreachable for traders because they are
absent from that role's list, not merely greyed out.

`Ctrl+K` / `⌘K` opens the command palette. Layout is responsive: sidebar on
desktop, bottom navigation on mobile.

### Assistant

`lib/ai/` streams replies from `POST /ai/chat` over Server-Sent Events and can
invoke tools, each mapped to a destination. `tool_registry.dart` is intentionally
static — the palette and composer suggestions must render instantly and work
offline. Availability comes from `GET /ai/capabilities` instead.

The UI is fully built in English and Kannada. **Tool *answers* are not yet
grounded in market data**: the backend's price reply is still canned text, which
is why it does not claim to be live.

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
flutter test test/app_shell_test.dart             # navigation + roles
flutter test test/ai_context_test.dart            # assistant context
```

## Market prices screen

`lib/screens/market_prices_screen.dart` currently renders
`MarketPrice.sampleData()`. **It is not connected to any source** — the
backend market layer exists but is not yet exposed over HTTP.

The replacement needs a provenance model rather than just new fields, because
the backend distinguishes `live`, `stale`, `unverified` and `unavailable`
sources, and a screen that collapses those into one list of numbers is exactly
the failure the backend was designed to prevent. Planned:

- `DataOrigin` + `DataSourceStatus` in `lib/services/data_source_status.dart`
- a shared provenance banner in `lib/widgets/ui/`
- polling every 5 minutes while the market is open, pull-to-refresh, skeletons
- demand-ring taps opening the component breakdown for that mandi

`lib/ai/prompt/tool_registry.dart` already maps `AiTool.prices` to this screen,
so the assistant can already navigate to it. It cannot yet answer a price
question with real data.

## Known issues

`ListTile background color or ink splashes may be invisible.` — a Material
assertion raised on the Marketplace and Profile screens where a `ListTile` sits
inside a `DecoratedBox`. Cosmetic, but noisy in debug logs.

## What's next

For each new objective, add: one method in `api_service.dart` calling the new
backend endpoint, one screen in `lib/screens/`, and an entry in
`AppDestinations`. Every user-visible string goes in `lib/theme/locale.dart` in
both English and Kannada.
