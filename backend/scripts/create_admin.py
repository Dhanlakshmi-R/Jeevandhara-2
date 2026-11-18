"""Create the FIRST admin account, end to end. One-off CLI.

Why a script and not a screen
-----------------------------
Admin is never self-service. `/auth/register` refuses the admin role outright,
so the only way the very first admin can exist is out of band, on the server,
by someone with shell access. After that, a superadmin creates further admins
from the console.

Credentials come from the environment (ADMIN_EMAIL / ADMIN_PASSWORD /
ADMIN_NAME) when present, otherwise from an interactive prompt. The password is
read with getpass and is never echoed, printed or logged.

Usage
-----
    python scripts/create_admin.py
    ADMIN_EMAIL=me@example.com ADMIN_PASSWORD='...' python scripts/create_admin.py --superadmin

Safe to re-run: if the email already exists the account is promoted to admin,
and it is only marked superadmin when --superadmin is passed or it is the first
admin ever created.
"""

from __future__ import annotations

import argparse
import getpass
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from app import audit, models  # noqa: E402
from app.auth_utils import hash_password  # noqa: E402
from app.database import SessionLocal, engine, migrate_schema  # noqa: E402

MIN_PASSWORD_LENGTH = 8


def _resolve_email() -> str:
    email = (os.getenv("ADMIN_EMAIL") or "").strip()
    if not email:
        email = input("Admin email: ").strip()
    return email.lower()


def _resolve_name(email: str) -> str:
    name = (os.getenv("ADMIN_NAME") or "").strip()
    if not name:
        name = input("Admin name [Administrator]: ").strip() or "Administrator"
    return name


def _resolve_password() -> str:
    password = os.getenv("ADMIN_PASSWORD") or ""
    if password:
        return password
    password = getpass.getpass("Admin password: ")
    confirm = getpass.getpass("Confirm password: ")
    if password != confirm:
        raise SystemExit("Passwords do not match.")
    return password


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Create the first Jeevandhara admin.")
    parser.add_argument(
        "--superadmin",
        action="store_true",
        help="Mark the account as superadmin (highest tier).",
    )
    parser.add_argument(
        "--force",
        action="store_true",
        help="Allow creating/resetting even when an admin already exists.",
    )
    args = parser.parse_args(argv)

    if os.getenv("APP_ENV", "development").strip().lower() == "production":
        # Allowed in production on purpose - this is how you bootstrap. But the
        # operator should know they are touching a live database.
        print("NOTE: APP_ENV=production. This will write to the live database.")

    # Safe on a fresh database: creates tables and applies the inline SQLite
    # migration, exactly as the app's startup does.
    models.Base.metadata.create_all(bind=engine)
    migrate_schema()

    db = SessionLocal()
    try:
        admin_count = (
            db.query(models.User).filter(models.User.role == models.UserRole.admin).count()
        )
        any_superadmin = (
            db.query(models.User)
            .filter(models.User.role == models.UserRole.admin, models.User.is_superadmin.is_(True))
            .count()
        )
        if admin_count and not args.force:
            print(
                f"An admin already exists ({admin_count}). Use the console, or pass "
                "--force to bootstrap another one.",
                file=sys.stderr,
            )
            return 2

        email = _resolve_email()
        if not email or "@" not in email:
            print("A valid email is required.", file=sys.stderr)
            return 2
        password = _resolve_password()
        if len(password) < MIN_PASSWORD_LENGTH:
            print(
                f"Password must be at least {MIN_PASSWORD_LENGTH} characters.",
                file=sys.stderr,
            )
            return 2
        name = _resolve_name(email)

        # The first admin is always a superadmin; later ones only on request.
        make_super = args.superadmin or any_superadmin == 0

        user = db.query(models.User).filter(models.User.email == email).first()
        created = user is None
        if created:
            user = models.User(
                name=name,
                email=email,
                hashed_password=hash_password(password),
                role=models.UserRole.admin,
                is_superadmin=make_super,
                is_active=True,
                profile_complete=True,
            )
            db.add(user)
            db.flush()
        else:
            user.name = name
            user.role = models.UserRole.admin
            user.is_active = True
            user.is_superadmin = make_super
            # Only reset the credential when a password was actually supplied.
            if os.getenv("ADMIN_PASSWORD") or not created:
                user.hashed_password = hash_password(password)
        db.commit()
        db.refresh(user)

        audit.record_event(
            db,
            event_type=audit.EventType.profile_created,
            actor=None,
            actor_role="system",
            entity_type="user",
            entity_id=user.id,
            action="bootstrap_admin",
            metadata={"email": user.email, "is_superadmin": user.is_superadmin},
        )

        print(f"{'Created' if created else 'Promoted'} admin: {user.email}")
        print(f"Superadmin: {user.is_superadmin}")
        print("No password was printed or logged.")
        return 0
    finally:
        db.close()


if __name__ == "__main__":
    raise SystemExit(main())
