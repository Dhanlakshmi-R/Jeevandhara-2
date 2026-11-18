import hashlib
import hmac
import os
import secrets
from datetime import datetime, timedelta

import bcrypt as _bcrypt
from fastapi import Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer
from jose import JWTError, jwt
from sqlalchemy.orm import Session

from . import models
from .database import get_db

SECRET_KEY = os.getenv("JWT_SECRET_KEY", "dev-only-secret-change-me")
ALGORITHM = os.getenv("JWT_ALGORITHM", "HS256")
ACCESS_TOKEN_EXPIRE_MINUTES = int(os.getenv("ACCESS_TOKEN_EXPIRE_MINUTES", "60"))
# Refresh tokens live far longer than access tokens; the session, not the
# token's lifetime, is what logout/revocation actually kills.
REFRESH_TOKEN_EXPIRE_MINUTES = int(
    os.getenv("REFRESH_TOKEN_EXPIRE_MINUTES", str(60 * 24 * 30))
)

oauth2_scheme = OAuth2PasswordBearer(tokenUrl="auth/login")

# bcrypt only considers the first 72 bytes of a password. Truncate to stay
# within that limit (and to remain compatible with passlib-generated hashes).
_BCRYPT_MAX = 72


def _to_bytes(value: str) -> bytes:
    return value.encode("utf-8")[:_BCRYPT_MAX]


def hash_password(password: str) -> str:
    return _bcrypt.hashpw(_to_bytes(password), _bcrypt.gensalt()).decode("utf-8")


def verify_password(plain_password: str, hashed_password: str) -> bool:
    try:
        return _bcrypt.checkpw(_to_bytes(plain_password), hashed_password.encode("utf-8"))
    except (ValueError, TypeError):
        return False


def unusable_password_hash() -> str:
    """Hash of a random token so Google/OTP users can never log in with a password."""
    return hash_password(secrets.token_urlsafe(32))


def hash_otp(code: str) -> str:
    """Hash an OTP before persisting it. Only the hash is ever stored."""
    return pwd_context.hash(code)


def verify_otp(code: str, code_hash: str) -> bool:
    return pwd_context.verify(code, code_hash)


def create_access_token(data: dict, expires_minutes: int | None = None) -> str:
    to_encode = data.copy()
    expire = datetime.utcnow() + timedelta(
        minutes=expires_minutes if expires_minutes is not None else ACCESS_TOKEN_EXPIRE_MINUTES
    )
    # `type` lets a refresh token be rejected where an access token is expected,
    # even though both are signed with the same key.
    to_encode.update({"exp": expire, "type": "access"})
    return jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)


def _credentials_exception() -> HTTPException:
    return HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Could not validate credentials",
        headers={"WWW-Authenticate": "Bearer"},
    )


def decode_token(token: str, *, expected_type: str | None = "access") -> dict:
    """Decode and validate a JWT. Raises 401 on any failure."""
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
    except JWTError:
        raise _credentials_exception()
    if expected_type is not None and payload.get("type") != expected_type:
        raise _credentials_exception()
    if payload.get("sub") is None:
        raise _credentials_exception()
    return payload


def create_refresh_token(session: models.UserSession) -> str:
    """Mint a refresh token bound to one session.

    The token carries the session id (`sid`) and a `family` id; only a SHA-256
    hash is stored, so the plaintext token exists only in the client's hands.
    `type="refresh"` stops it being accepted where an access token is expected.
    """
    expire = datetime.utcnow() + timedelta(minutes=REFRESH_TOKEN_EXPIRE_MINUTES)
    to_encode = {
        "sub": str(session.user_id),
        "sid": session.id,
        "family": session.refresh_token_family,
        "jti": secrets.token_urlsafe(16),
        "exp": expire,
        "type": "refresh",
    }
    return jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)


def hash_token(token: str) -> str:
    """SHA-256 of a token.

    Refresh tokens are long and opaque, so a plain hash is sufficient and can be
    compared in constant time. bcrypt (used for passwords) would silently
    truncate at 72 bytes, making the tail of a 200-char token unauthenticated.
    """
    return hashlib.sha256(token.encode("utf-8")).hexdigest()


def verify_token_hash(token: str, token_hash: str | None) -> bool:
    if not token_hash:
        return False
    return hmac.compare_digest(hash_token(token), token_hash)


def issue_auth_result(
    user: models.User,
    db: Session | None = None,
    request=None,
    *,
    session_id: int | None = None,
    start_session: bool = True,
) -> dict:
    """Build a consistent AuthResult dict (token + user) for every login path.

    When ``db`` is supplied and ``start_session`` is true, a session row is
    opened and a ``login_success`` event is recorded, and the token carries the
    role and session id so admin routes can re-verify them and logout can close
    the right session. Callers that are *not* a fresh login (profile completion)
    pass ``start_session=False`` and the existing ``session_id`` so no extra row
    or login event is created.
    """
    from . import audit, sessions

    session = sessions.start_session(db, user, request) if (db is not None and start_session) else None
    sid = session.id if session is not None else session_id
    access_token = create_access_token(
        data={
            "sub": str(user.id),
            "role": user.role.value,
            "sid": sid,
        }
    )
    # Only a fresh login gets a refresh token. Profile completion reuses the
    # session it already has, so it must not mint (and thus rotate) one here.
    refresh_token = None
    if session is not None:
        if not session.refresh_token_family:
            session.refresh_token_family = secrets.token_urlsafe(16)
        refresh_token = create_refresh_token(session)
        session.refresh_token_hash = hash_token(refresh_token)
        db.commit()
    if db is not None and start_session:
        ctx = audit.request_context(request)
        audit.record_event(
            db,
            event_type=audit.EventType.login_success,
            actor=user,
            entity_type="user",
            entity_id=user.id,
            session_id=session.id if session is not None else None,
            metadata={"auth_provider": getattr(user.auth_provider, "value", user.auth_provider)},
            **ctx,
        )
    return {
        "access_token": access_token,
        "refresh_token": refresh_token,
        "token_type": "bearer",
        "profile_complete": user.profile_complete,
        "user": user,
    }


def get_current_user(
    token: str = Depends(oauth2_scheme), db: Session = Depends(get_db)
) -> models.User:
    """
    Dependency to protect routes. Add `current_user: models.User = Depends(get_current_user)`
    as a parameter on any endpoint that should require a logged-in user.

    The user is re-read from the database on every request, so a suspended or
    deleted account is rejected even when the token still verifies.
    """
    payload = decode_token(token)
    user = db.query(models.User).filter(models.User.id == int(payload["sub"])).first()
    if user is None:
        raise _credentials_exception()
    if not user.is_active:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="This account is suspended.",
        )
    return user


def require_admin(
    token: str = Depends(oauth2_scheme), db: Session = Depends(get_db)
) -> models.User:
    """Guard for every /admin route.

    Three checks, none trust the token alone:
    1. the token is valid and typed `access`,
    2. it carries an `admin` role claim,
    3. the user still exists, is active, and is still an admin right now.
    """
    payload = decode_token(token)
    if payload.get("role") != models.UserRole.admin.value:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Admin privileges required.",
        )
    user = db.query(models.User).filter(models.User.id == int(payload["sub"])).first()
    if user is None or not user.is_active or user.role != models.UserRole.admin:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Admin privileges required.",
        )
    return user


def require_superadmin(admin: models.User = Depends(require_admin)) -> models.User:
    """Stricter guard for the highest tier: suspending admins, audit exports."""
    if not admin.is_superadmin:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Superadmin privileges required.",
        )
    return admin
