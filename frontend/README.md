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
  user and a grid of 6 placeholder tiles, one per ASIP objective. Each
  tile currently just shows a "coming soon" message — replace that
  `onTap` with real navigation as each objective is built.
- `lib/services/api_service.dart` — all HTTP calls to the backend and
  token storage (`shared_preferences`). Add new methods here (e.g.
  `getWeather()`, `getCropPrices()`) as each objective's backend
  endpoint becomes available.
- `lib/models/user.dart` — matches the backend's `UserOut` schema.

## What's next

For each new objective, add: one method in `api_service.dart` calling
the new backend endpoint, and one new screen in `lib/screens/`, then
wire it into the matching tile in `home_screen.dart`.
