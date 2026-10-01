from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from . import models
from .database import engine, migrate_schema
from .routers import ai, auth, google, otp, places, users, weather

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
app.include_router(google.router)
app.include_router(otp.router)
app.include_router(users.router)
app.include_router(weather.router)
app.include_router(places.router)
app.include_router(ai.router)


@app.get("/")
def health_check():
    return {"status": "ok", "service": "jeevandhara2-api"}
