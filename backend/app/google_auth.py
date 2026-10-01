"""Server-side verification of Google Sign-In ID tokens.

The Flutter app captures an ID token from google_sign_in and sends it here.
We verify signature, issuer and audience using google-auth's own transport
(no extra dependency beyond google-auth itself), then trust the profile
claims if email_verified is true.
"""
import os

from fastapi import HTTPException, status
from google.auth.transport import requests as google_requests
from google.oauth2 import id_token

_VALID_ISSUERS = {"accounts.google.com", "https://accounts.google.com"}


def _configured_client_ids() -> list[str]:
    ids: list[str] = []
    for env_key in (
        "GOOGLE_CLIENT_ID",
        "GOOGLE_ANDROID_CLIENT_ID",
        "GOOGLE_IOS_CLIENT_ID",
        "GOOGLE_ALLOWED_CLIENT_IDS",
    ):
        raw = os.getenv(env_key, "").strip()
        for candidate in raw.split(","):
            candidate = candidate.strip()
            if candidate and candidate not in ids:
                ids.append(candidate)
    return ids


def verify_google_id_token(token: str) -> dict:
    audiences = _configured_client_ids()
    if not audiences:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Google Sign-In is not configured on the server (missing GOOGLE_CLIENT_ID).",
        )

    info: dict = {}
    for audience in audiences:
        try:
            info = id_token.verify_oauth2_token(
                token, google_requests.Request(), audience=audience
            )
            break
        except ValueError:
            continue
    if not info:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid Google ID token or audience mismatch.",
        )

    if info.get("iss") not in _VALID_ISSUERS:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid Google token issuer."
        )
    if not info.get("email_verified"):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED, detail="Google email is not verified."
        )
    return info


def google_verifier() -> callable:
    """FastAPI dependency returning the verify function, so tests can override it."""
    return verify_google_id_token