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

146 tests pass. For a single file:

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
flutter test test/market_parse_test.dart          # market provenance parsing
flutter test test/market_prices_screen_test.dart  # prices + honesty states
flutter test test/app_shell_test.dart             # navigation + roles
flutter test test/ai_context_test.dart            # assistant context
```

## Market prices screen

`lib/screens/market_prices_screen.dart` now reads the backend over HTTP
(`/market/prices`, `/market/status`, `/market/commodities`, `/market/mandis`)
through `lib/services/market_service.dart`, and every row carries its
provenance:

- `lib/design/provenance.dart` — `Provenance` (source, tier, freshness,
  observed date, lag, actionable), `DataTier` (A/B/C/D, unknown renders `?`
  rather than pretending to be A), `Freshness`, `SourceStatus`, `MarketStatus`,
  and `MarketUnavailableException` carrying the 503 `attempts` block.
- `lib/widgets/ui/provenance_chip.dart` — tier letter + feed name per row, and
  a freshness badge whose age comes from the row's own market date.
- `lib/widgets/ui/data_source_status.dart` — `DataSourceStatusBanner` (which
  feeds are off and why, verbatim), `SourceListPanel`, and `FreshnessBanner`
  (built only when the window is not all fresh).

Failure paths stay honest: a 503 renders its per-source reasons with a retry,
and an empty store renders "nothing is shown here until a source reports one"
instead of a padded list. Pull-to-refresh re-reads status and prices together.
`MarketPrice.sampleData()` is gone, as are the sample lists in `trader`,
`crop`, `product`, `tool` and `app_notification`.

## My Crops and Marketplace

Both screens are wired to their routers:

- `lib/services/crops_service.dart` reads `/my-crops` and posts, patches and
  retires rows with the caller's bearer token. `CropListing` keeps the
  server's typed fields (quantity, price, status, harvest date), renders
  "No asking price" when `expected_price` is absent, and hides rows the farmer
  took down.
- `lib/services/marketplace_service.dart` reads `/marketplace` and creates or
  retires products. `MarketplaceProduct.rating` stays null until reviews exist,
  so a card says "No reviews" rather than drawing unearned stars. The remove
  control only appears for the row's owner (`poster_id`).
- The dashboard's "Recent Crop Listings" card reads the same `/my-crops` rows
  and its "View all" link opens the My Crops destination through
  `AppShellScope`, an inherited widget exposed by `AppShell`.
- Both My Crops and Marketplace rows now have an owner-only Edit action that
  reuses the create form in edit mode and PATCHes the existing row.

Checkout has no order endpoint behind it, so the cart says so explicitly:
nothing is sent to a seller and the cart is kept.

`tool_rental_screen.dart` and `find_traders_screen.dart` are wired the same
way. The notifications screen now reads `/notifications` (audience-filtered
broadcasts) and the shell badge reflects the unread count; marking read is
local because delivery is not fanned out into per-user rows.

## Trader side

- `lib/services/listings_service.dart` now attaches the bearer token to
  `/traders/me` reads (a 401 becomes "Sign in to manage your trading card")
  and accepts both the bare array `/traders/me` returns and an `{items}`
  envelope. `saveTraderOffer` sends company, crops, price, note, emoji and
  availability; `deleteTraderOffer` takes the card down.
- `TraderOverviewPage` reads `/traders/me` and renders exactly the row the
  server stores — the trader's own buying card. The old invented KPIs
  (`₹4,82,500`, 24 deals, a 4.6 rating), the hardcoded deals list and the
  "Offer posted to nearby farmers!" snackbar are gone. A failed read shows a
  retry; no card shows an honest invitation to post one.
- `TraderPostOfferPage` prefills from the existing card and publishes through
  `POST /traders/me`, validating that at least one crop is listed and that a
  price is positive when supplied.
- `lib/services/trader_offer_store.dart` carries the saved card from the form
  to the dashboard, which the shell keeps alive in an `IndexedStack`. The
  server stays the source of truth: every dashboard visit re-reads the card.
- `TraderDealsPage` shows "No deals yet" because the backend stores buying
  cards, not orders — there is no deal history to read.


Every user-visible string on these widgets lives in `lib/theme/locale.dart`
with an English and a Kannada entry; models that format labels take an
optional reader (`priceLabelOf(context.str)`) and fall back to English when
called with no reader.

Still to come: polling while the market is open, and demand rings opening the
component breakdown for a mandi.

`lib/ai/prompt/tool_registry.dart` maps `AiTool.prices` to this screen, and
`backend/app/ai_chat.py` answers price questions from stored rows with the
same provenance rules.

## Known issues

`ListTile background color or ink splashes may be invisible.` — a Material
assertion raised on the Marketplace and Profile screens where a `ListTile` sits
inside a `DecoratedBox`. Cosmetic, but noisy in debug logs.

## What's next

For each new objective, add: one method in `api_service.dart` calling the new
backend endpoint, one screen in `lib/screens/`, and an entry in
`AppDestinations`. Every user-visible string goes in `lib/theme/locale.dart` in
both English and Kannada.
