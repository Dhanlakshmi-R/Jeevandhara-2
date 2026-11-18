from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from . import models
from .database import engine, migrate_schema
from .routers import (
    admin,
    admin_ops,
    ai,
    auth,
    google,
    listings,
    market,
    marketplace,
    mycrops,
    notifications,
    otp,
    places,
    sensors,
    users,
    weather,
)

# Creates tables if they don't exist yet, then applies the inline SQLite
# migration (adds new columns to existing tables without losing data).
# Switch to real Alembic migrations if/when the project moves to Postgres
# or the schema starts changing between deployed environments.
models.Base.metadata.create_all(bind=engine)
migrate_schema()

app = FastAPI(title="Jeevandhara 2 API")

# Wide open for local development so the Flutter app (emulator/device)
# can call the API freely. Tighten `allow_origins` before deploying.
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(auth.router)
app.include_router(admin.router)
app.include_router(admin_ops.router)
app.include_router(google.router)
app.include_router(otp.router)
app.include_router(users.router)
app.include_router(weather.router)
app.include_router(places.router)
app.include_router(ai.router)
app.include_router(market.router)
app.include_router(listings.router)
app.include_router(mycrops.router)
app.include_router(notifications.router)
app.include_router(marketplace.router)
app.include_router(sensors.router)


@app.on_event("startup")
def _start_market_scheduler() -> None:
    """Warm the market tables in the background.

    A request never waits on an upstream: reads hit the database or the source
    TTL cache, and this only keeps both topped up. Disabled with
    MARKET_SCHEDULER=off, which is what the test suite sets.
    """
    from .market import scheduler

    scheduler.start()


@app.on_event("shutdown")
def _stop_market_scheduler() -> None:
    from .market import scheduler

    scheduler.stop()


@app.get("/")
def health_check():
    return {"status": "ok", "service": "jeevandhara2-api"}
