import os
from types import SimpleNamespace

os.environ["DATABASE_URL"] = "sqlite://"
os.environ["JWT_SECRET_KEY"] = "test-secret"
os.environ["APP_ENV"] = "development"
os.environ["OTP_SMS_PROVIDER"] = "console"
os.environ["GOOGLE_CLIENT_ID"] = "test-client-id.apps.googleusercontent.com"

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from app.database import Base, get_db
from app.google_auth import google_verifier
from app.main import app
from app.rate_limit import RateLimiter, get_rate_limiter
from app.sms import get_sms_provider


class FakeSmsProvider:
    """Captures codes so tests can assert flow, without sending anything."""

    def __init__(self):
        self.sent = []  # list of (phone, code)

    def send_verification(self, phone: str, code: str) -> None:
        self.sent.append((phone, code))


@pytest.fixture()
def setup():
    engine = create_engine(
        "sqlite://", connect_args={"check_same_thread": False}, poolclass=StaticPool
    )
    SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
    Base.metadata.create_all(bind=engine)

    fake_sms = FakeSmsProvider()
    limiter = RateLimiter(min_interval=0.0, window=1_000_000, max_calls=1_000_000)

    def override_get_db():
        db = SessionLocal()
        try:
            yield db
        finally:
            db.close()

    def fake_google_verify() -> callable:
        return lambda token: {
            "sub": "google-sub-001",
            "email": "gita@example.com",
            "email_verified": True,
            "name": "Gita Sharma",
            "picture": "https://example.com/gita.png",
        }

    app.dependency_overrides[get_db] = override_get_db
    app.dependency_overrides[get_sms_provider] = lambda: fake_sms
    app.dependency_overrides[get_rate_limiter] = lambda: limiter
    app.dependency_overrides[google_verifier] = fake_google_verify

    yield SimpleNamespace(
        engine=engine, SessionLocal=SessionLocal, fake_sms=fake_sms
    )

    app.dependency_overrides.clear()


@pytest.fixture()
def client(setup):
    with TestClient(app) as c:
        yield c