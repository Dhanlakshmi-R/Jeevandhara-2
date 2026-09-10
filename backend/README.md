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
