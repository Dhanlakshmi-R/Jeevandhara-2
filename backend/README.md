# Jeevandhara 2 — Backend (FastAPI)

## Setup

```bash
cd backend
python3 -m venv venv
source venv/bin/activate        # Windows: venv\Scripts\activate
pip install -r requirements.txt
cp .env.example .env            # then edit .env if needed
```

By default `.env` points at a local SQLite file (`jeevandhara.db`) so you
can run everything with zero extra setup. Switch `DATABASE_URL` to a
Postgres URL later without changing any code.

## Run

```bash
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

Then open **http://localhost:8000/docs** — FastAPI's interactive docs.
You can register a user, log in, and call `/users/me` directly from
that page to confirm everything works before touching the app.

## Endpoints in this scaffold

| Method | Path            | Auth required | Purpose                          |
|--------|-----------------|----------------|-----------------------------------|
| GET    | `/`             | No             | Health check                     |
| POST   | `/auth/register`| No             | Create a farmer or trader account|
| POST   | `/auth/login`   | No             | Get a JWT access token           |
| GET    | `/users/me`     | Yes (Bearer)   | Confirm token + fetch profile    |

## What's next

Each future objective gets its own router file in `app/routers/` (e.g.
`weather.py`, `marketplace.py`, `crop_quality.py`), included in
`main.py` the same way `auth` and `users` are. The `Listing` model in
`app/models.py` is a placeholder for Objective 5 — extend it rather
than creating a new table when you build that feature.

## Weather module

Real weather data is proxied from the backend — the app never talks to a
provider directly, and no API key ships in the client. Endpoints live in
`app/routers/weather.py`.

### Two providers, one payload shape

| Provider | When | Key needed |
|----------|------|------------|
| **WeatherAPI.com** (`app/weather_service.py`) | `WEATHER_API_KEY` is set | Yes — free at <https://www.weatherapi.com/signup.aspx> |
| **Open-Meteo** (`app/open_meteo.py`) | no key set (**default**) | No |

Open-Meteo is the default so a fresh checkout returns real weather with zero
setup. Set a key whenever you want the richer provider: WeatherAPI also serves
**severe-weather alerts**, which Open-Meteo has no feed for. Both are
normalized into an identical response, so the Flutter client never branches on
provider — it just reads `source` (`"weatherapi"` or `"open-meteo"`).

### Adding the key (optional)

1. Sign up at <https://www.weatherapi.com/signup.aspx>; the dashboard shows
   your key immediately.
2. Put it in `backend/.env`:
   ```
   WEATHER_API_KEY=your_key_here
   ```
3. Restart the server. `.env` is gitignored — never paste the key into a
   Dart or Python source file, or commit it.

Verify with either provider:

```bash
curl "http://localhost:8000/weather/suggestions?q=bengaluru"
```

The WeatherAPI free tier gives current conditions + autocomplete + a 3-day
forecast; paid plans unlock 7-day forecasts, UV index and alerts. The backend
requests `days=7&alerts=yes` and forwards whatever the plan returns rather
than fabricating anything.

### Endpoints

| Method | Path                          | Notes                                         |
|--------|-------------------------------|-----------------------------------------------|
| GET    | `/weather/suggestions?q=&state=` | India-only place autocomplete; `state` narrows to a region (falls back to all-India) |
| GET    | `/weather?lat=&lon=&name=`    | Current + hourly + daily + alerts payload     |
| GET    | `/weather/places/states`      | All 36 states + UTs, each with coordinates and a district count |
| GET    | `/weather/places/districts?state=` | Districts for a state, with coordinates |
| GET    | `/weather/places/taluks?state=&district=` | Sub-districts, with coordinates |
| GET    | `/weather/places/villages?state=&district=&taluk=` | Settlements, with coordinates |
| GET    | `/weather/places/resolve?state=&district=&taluk=&village=` | Coordinates for whichever level was chosen, plus `level` / `matched` / `fallback` |

### Location gazetteer

`/weather/places/*` is served from a bundled **GeoNames** extract of India
(`app/data/india_places.db`, ~16 MB) and needs **no** provider at all — it works
offline. It covers all of India: 36 states/UTs, 763 districts, 6,891 sub-districts
and 554,135 settlements that sit under a sub-district.

Rebuild it from scratch with:

```bash
python scripts/build_india_places.py
```

The script downloads `https://download.geonames.org/export/dump/IN.zip`
(GeoNames, CC BY 4.0) and is the only step that needs network access. The
generated `.db` is a build artifact — regenerate it rather than editing it.

Every level can be the final answer, not just a village. `resolve` returns the
coordinates for the deepest level that was supplied, plus:

- `level` — which admin level the coordinates actually belong to
- `matched` — the real name of the place those coordinates describe
- `fallback` — `true` when a village was requested but only a coarser level
  could be located

`fallback` exists so the app can stay honest: taluk coordinates are offered
explicitly instead of being passed off as the village's own weather.

Two coverage caveats, both inherent to the source: 2,784 GeoNames settlements
that belong to no sub-district are not browsable, and 1,074 settlements under
districts that have no sub-districts are not exposed either. The data is
GeoNames, not an official census, so district names may not match today's
administrative list exactly.

Responses are cached in-process (suggestions 30 min, weather 10 min). The
weather cache is keyed by coordinates only, so `?name=` is layered on per
request rather than being pinned by whoever fetched those coordinates first.
Provider failures map to **502**; invalid parameters to **422**; an unknown
place name to **404**.

Two differences worth knowing when reading the payload, both from Open-Meteo
having a leaner feed: `alerts` is always empty, and `current.uv` carries the
day's UV *maximum* (WeatherAPI reports a live reading).

Run the suite with `pytest` — `tests/test_weather.py` covers the WeatherAPI
path, `tests/test_weather_open_meteo.py` the fallback.
