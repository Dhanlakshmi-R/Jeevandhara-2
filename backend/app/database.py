import os
from dotenv import load_dotenv
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker, declarative_base

load_dotenv()

DATABASE_URL = os.getenv("DATABASE_URL", "sqlite:///./jeevandhara.db")

# SQLite needs this extra arg for multi-threaded FastAPI; Postgres ignores it.
connect_args = {"check_same_thread": False} if DATABASE_URL.startswith("sqlite") else {}

engine = create_engine(DATABASE_URL, connect_args=connect_args)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

Base = declarative_base()


def get_db():
    """FastAPI dependency: yields a DB session per request and always closes it."""
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


def migrate_schema():
    """
    Minimal inline migration to keep `Base.metadata.create_all` working with
    the existing SQLite file: it ALTERs the `users` table to add any new
    columns that don't exist yet, preserving existing rows. Safe to run on
    every startup (each ALTER only runs if the column is missing).

    This is intentionally scoped to SQLite. If the project moves to Postgres,
    switch to real Alembic migrations instead of this helper.
    """
    if not DATABASE_URL.startswith("sqlite"):
        return
    from sqlalchemy import inspect, text

    inspector = inspect(engine)
    if "users" not in inspector.get_table_names():
        return

    existing = {col["name"] for col in inspector.get_columns("users")}
    # column name -> full ALTER statement (SQLite supports ADD COLUMN only).
    additions = {
        "phone_verified": "ALTER TABLE users ADD COLUMN phone_verified BOOLEAN DEFAULT 0",
        "auth_provider": "ALTER TABLE users ADD COLUMN auth_provider VARCHAR DEFAULT 'password'",
        "provider_user_id": "ALTER TABLE users ADD COLUMN provider_user_id VARCHAR",
        "profile_image": "ALTER TABLE users ADD COLUMN profile_image VARCHAR",
        "profile_complete": "ALTER TABLE users ADD COLUMN profile_complete BOOLEAN DEFAULT 1",
    }
    with engine.begin() as conn:
        for name, ddl in additions.items():
            if name not in existing:
                conn.execute(text(ddl))
