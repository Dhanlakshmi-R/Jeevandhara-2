# Jeevandhara 2

Chat-first agriculture platform for Indian farmers and traders. The app opens
into an assistant rather than a dashboard, and every feature is reachable as a
"tool" the assistant can open.

Currently built: **authentication** (email, Google, phone OTP), **real weather**
for all of India, **an AI assistant** with tool routing and citations, and the
**foundation of real-time market intelligence** (multi-source price feeds with
mandatory provenance). Market demand scoring, sell advice and the market UI are
in progress.

## Structure

```
Jeevandhara-2/
├── backend/     FastAPI + SQLAlchemy + JWT  (see backend/README.md)
└── frontend/    Flutter app                (see frontend/README.md)
```

## Quick start

Two terminals. Backend first — the Flutter app needs it to do anything useful.

### 1. Backend

```bash
git clone https://github.com/Dhanlakshmi-R/Jeevandhara-2.git
cd Jeevandhara-2/backend

python -m venv venv
.\venv\Scripts\activate            # Windows
# source venv/bin/activate         # macOS / Linux

pip install -r requirements.txt
copy .env.example .env             # Windows; `cp` on macOS/Linux

uvicorn app.main:app --reload --port 8000
```

Open **http://localhost:8000/docs** for interactive API docs. `.env` works
as-is: SQLite, no external services, no API keys required.

> Generate a real `JWT_SECRET_KEY` before deploying:
> `python -c "import secrets; print(secrets.token_hex(32))"`

### 2. Frontend

```bash
cd Jeevandhara-2/frontend
flutter pub get
flutter run
```

The API base URL lives in `lib/services/api_service.dart` and defaults to
`http://10.0.2.2:8000`, which is how an Android emulator reaches the host
machine's `localhost`. See [frontend/README.md](frontend/README.md) for iOS
simulator and physical-device URLs.

## Verify the install

```bash
# backend — 236 tests
cd backend
.\venv\Scripts\python.exe -m pytest tests -q

# frontend — 75 tests
cd frontend
flutter test
```

Run pytest **from inside `backend/`**. From the repository root it fails with
`ModuleNotFoundError: No module named 'app'`.

## What's working

| Area | State | Notes |
|------|-------|-------|
| Auth | Done | Email + password, Google ID-token, phone OTP (console in dev, MSG91/Twilio in prod) |
| Places | Done | Offline gazetteer: 36 states/UTs, 763 districts, 6,891 sub-districts, 554,135 villages |
| Weather | Done | Open-Meteo by default, WeatherAPI with a key; current + hourly + daily + alerts |
| AI assistant | Done | Server-Sent Events stream, tool routing, citations, thinking indicator, EN/KN |
| App shell | Done | Role-aware navigation (farmer/trader), command palette (`Ctrl+K`), responsive sidebar/bottom-nav |
| Design system | Done | Central tokens, palette, typography, motion, reusable UI primitives |
| Market sources | Done | 4-source registry with failover, TTL cache, circuit breaker, provenance on every row |
| Market demand | In progress | Models written; scoring, routes and UI pending |
| Sell advice | Not started | Depends on a usable demand feed |

## Architecture notes

Three decisions run through the whole codebase and are worth knowing before
changing anything.

**1. The app never talks to a data provider directly.** Weather, places and
market prices are all proxied through the backend. No API key ships inside the
app, and provider failover, caching and rate limits live in one place.

**2. Provenance is mandatory, not optional.** Any number that reaches a farmer
carries the source that produced it, that source's confidence, whether it was
verified against a live response, and when it was actually fetched. A request
that fails everywhere returns each source's failure reason instead of a
generic "no data", because "you have no API key" and "the government server is
down" need different responses.

**3. Freshness comes from the data, not the fetch.** A price is dated by its own
market date. A feed can answer instantly and still be carrying last week's
rates, and treating those as equivalent is how a week-old number ends up
labelled live. Undated rows are treated as stale by default.

## Market data sources

Configured in [`backend/app/market/data_sources.yaml`](backend/app/market/data_sources.yaml)
so provenance can be reviewed without reading code. Current state:

| Source | Role | Status |
|--------|------|--------|
| data.gov.in (OGD) | Primary prices | Written to published docs; **unverified** — unreachable from the dev network and no API key. Disabled until both are true |
| eNAM / Agmarknet | Arrivals, demand | Endpoint contract recovered from their JavaScript, but **every data endpoint returns HTTP 500**. Client ships rate-limited to 1 request / 30 min |
| Agmarknet 2.0 | Arrivals | React SPA; its JSON API has not been located. Disabled |
| `mandi-api.onrender.com` | Dev fallback | **Verified live.** Community-contributed, unofficial, ~7 days behind. Disabled automatically when `APP_ENV=production` |

Two consequences are deliberate rather than bugs:

- **eNAM publishes arrival quantities but no traded quantity or trade count.**
  Their own renderer hardcodes `0`. So `off_take_ratio` and `buyer_competition`
  are excluded from the demand index rather than faked; the remaining weights
  are renormalised and the shortfall is reported to the user.
- **No official source is currently serving prices**, so the Karnataka + onion
  vertical slice runs on the dev fallback, labelled `low` confidence and
  `stale`. Enabling a guessed endpoint or imitating a missing field would
  produce confident, wrong numbers — the exact failure this design prevents.

## Pushing to GitHub

The repository is already connected. Review before pushing:

```bash
git status
git log --oneline -10
git push origin main
```

Current state: 7 commits ahead of `origin/main`, tagged `pre-market-backend` as
the rollback point before market work began. Nothing has been pushed.

`.gitignore` already covers `venv/`, `.env`, `*.db`, `__pycache__/`, Flutter
build output and IDE directories, and `.gitattributes` normalises line endings.
Never commit `.env` or a real API key.

## Roadmap

1. Demand index with per-component availability reporting
2. `/market` endpoints: prices, history, demand, sell advice, source status
3. Provenance model and banner in the Flutter app
4. Replace market sample data with live/stale-aware UI
5. Market AI tools, so the assistant can answer price and demand questions
   from real data instead of canned text