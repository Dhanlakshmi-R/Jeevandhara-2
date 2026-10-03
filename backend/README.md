# Jeevandhara 2 — Backend (FastAPI)

## Setup

```bash
cd backend
python -m venv venv
.\venv\Scripts\activate             # Windows
# source venv/bin/activate          # macOS / Linux
pip install -r requirements.txt
copy .env.example .env              # Windows; `cp` on macOS/Linux
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

## Tests

```bash
cd backend                          # must be run from here
.\venv\Scripts\python.exe -m pytest tests -q
```

236 tests pass. Run pytest from **inside** `backend/` — from the repo root it
fails with `ModuleNotFoundError: No module named 'app'`. The 52 warnings are
pre-existing `datetime.utcnow()` deprecations in the OTP code.

## Endpoints

| Method | Path                | Auth | Purpose                              |
|--------|---------------------|------|--------------------------------------|
| GET    | `/`                 | No   | Health check                         |
| POST   | `/auth/register`    | No   | Email + password signup              |
| POST   | `/auth/login`       | No   | JWT access token                     |
| POST   | `/auth/complete-profile` | No | Finish an incomplete signup      |
| POST   | `/auth/google`      | No   | Google ID-token sign-in             |
| POST   | `/auth/otp/send`    | No   | Request an OTP                       |
| POST   | `/auth/otp/verify`  | No   | Verify OTP, get a token              |
| GET    | `/users/me`         | Yes  | Current profile                      |
| GET    | `/weather`          | No   | Current + forecast + alerts          |
| GET    | `/weather/suggestions` | No | Place autocomplete                  |
| GET    | `/weather/places/*` | No   | Offline India gazetteer cascade     |
| POST   | `/ai/chat`          | No   | Streaming assistant reply (SSE)      |
| GET    | `/ai/capabilities`  | No   | Which assistant tools are available |

Market endpoints (`/market/*`) are not yet mounted. The source layer they will
use is built and tested — see below.

## What's next

Each future objective gets its own router file in `app/routers/` (e.g.
`market.py`), included in `main.py` the same way `auth` and `users` are. The
`Listing` model in `app/models.py` is a placeholder for Objective 5 — extend it
rather than creating a new table when you build that feature.

## AI assistant

`app/ai_chat.py` answers without any LLM key. It is rule-based and
deterministic: `POST /ai/chat` classifies the message, and if weather tools are
configured it calls the real provider and grounds the reply in actual numbers,
with a citation for each.

Without a key configured, `compose_reply` routes to a capability explanation
instead of inventing an answer. Setting `LLM_API_KEY` switches to model-backed
generation; the routing, tools and citations are identical either way.

The client streams over SSE, so `thinking` events can arrive before the reply.

**Known gap:** `_price_reply()` is still canned. It explains how prices work
rather than answering with real data, because no market route exists yet. It
must be replaced before prices can be claimed as live.

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

## Market data module

`app/market/` fetches wholesale mandi prices. The rule the whole module is
built around: **a price without provenance is not a price.** Every row carries
the source that produced it, that source's confidence, whether it was verified
against a live response, and when the data was actually observed.

### Sources

Configured entirely in `app/market/data_sources.yaml` — endpoints, field
mappings, attribution, confidence, verification state and cache TTLs. Adding or
retiring a source should not require touching Python.

| Source | Role | Status |
|--------|------|--------|
| `data_gov_in` | Primary prices | Written to published OGD docs, **unverified** — `api.data.gov.in` refuses TCP from the dev network and `DATA_GOV_API_KEY` is unset. Disabled until both are resolved |
| `enam` | Arrivals, demand | Paths and POST parameters recovered from the dashboard's own JavaScript, but **every data endpoint returns HTTP 500**. Rate-limited to one request per 30 minutes |
| `agmarknet` | Arrivals | React SPA; the JSON API inside its JS bundle has not been located. Disabled |
| `mandi_api` | Dev fallback | **Verified live.** Community-contributed, unofficial, roughly 7 days behind. Excluded automatically when `APP_ENV=production` |

Failover walks the chain in order (`price_chain`, `arrival_chain` in the YAML).
If every candidate fails, the error lists each source's reason — "no API key"
and "government server is down" need different user-facing messages.

### Layout

| File | Role |
|------|------|
| `market/data_sources.yaml` | The source registry. Provenance lives here, not in code |
| `market/sources/base.py` | TTL cache, circuit breaker, HTTP helper, `SourceStatus`, number parsing |
| `market/sources/data_gov.py` | OGD client. Key-gated |
| `market/sources/enam.py` | eNAM / Agmarknet client |
| `market/sources/mandi_api.py` | Dev-only fallback, verified against a live payload |
| `market/sources/registry.py` | Failover, freshness annotation, aggregate status |
| `market/normalizer.py` | Commodity / unit / mandi-name normalisation |

### Freshness

Three verdicts, computed per row from the row's own market date:

- `fresh` — recent enough to act on
- `stale` — real data, too old to act on
- `unverified` — from a feed never successfully parsed

Age deliberately does **not** come from `fetched_at`. A feed can respond
instantly and still carry last week's rates; conflating the two is how a
7-day-old price gets labelled live. Undated rows are stale by default.

### Normalisation

Upstream spellings are inconsistent in ways that would silently break lookups,
so they collapse to canonical values before anything else runs:

- Commodities: `Onion`, `onions`, `Pyaz`, `ಈರುಳ್ಳಿ` → `Onion`;
  `Arecanut(Betelnut/Supari)` → `Arecanut`; `Arhar/Tur/Red gram` → `Tur/Arhar`
- Units: everything converted to quintals; `quintal (100 kg)` stays a quintal
- Mandis: `Bangarpet APMC` → `Bangarpet`, `APMC Hubballi` → `Hubballi`

An unknown commodity is returned cleaned but otherwise untouched. Inventing a
match would return a different crop's price.

### Two things not currently knowable

**eNAM publishes no traded quantity or trade count.** Their dashboard renderer
hardcodes `0` in the trades column. `trade_count` is recorded as `0` because
that is literally what the feed says; `traded_quantity` is `None` because the
field does not exist. The consequence is that `off_take_ratio` and
`buyer_competition` cannot be computed and are excluded from the demand index
rather than imputed.

**`mandi_api` ignores its query filters.** It requires at least one of
`state`/`commodity`, returns ~200 rows regardless of `limit`, and its
`/v1/commodities` endpoint is a *sample* — it lists 4 commodities for Karnataka
while `/v1/prices` happily returns onions. Filtering therefore happens locally,
and the vocabulary endpoint is never used to restrict what the app shows.

### Tests

```bash
.\venv\Scripts\python.exe -m pytest tests/test_market_sources.py -q
```

130 tests, no network access. Upstream payloads are injected, which makes them
the regression net for the field mappings — especially the ones that could not
be confirmed live. The freshness tests are the ones worth reading first: they
fail if a stale rate is ever labelled fresh.
