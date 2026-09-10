from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from . import models
from .database import engine
from .routers import auth, users

# Creates tables if they don't exist yet. Fine for early development;
# switch to Alembic migrations once the schema starts changing often
# after multiple people are working against a shared Postgres DB.
models.Base.metadata.create_all(bind=engine)

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
app.include_router(users.router)


@app.get("/")
def health_check():
    return {"status": "ok", "service": "jeevandhara2-api"}
