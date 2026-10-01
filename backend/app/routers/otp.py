import os
from datetime import datetime, timedelta

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from .. import models, schemas, auth_utils, sms
from ..database import get_db
from ..models import generate_verification_code
from ..phone import normalize_phone
from ..rate_limit import get_rate_limiter, RateLimiter

router = APIRouter(prefix="/auth", tags=["auth"])

OTP_EXPIRY_SECONDS = int(os.getenv("OTP_EXPIRY_SECONDS", "300"))
OTP_RESEND_COOLDOWN_SECONDS = int(os.getenv("OTP_RESEND_COOLDOWN_SECONDS", "30"))
OTP_MAX_ATTEMPTS = int(os.getenv("OTP_MAX_ATTEMPTS", "5"))
OTP_MAX_RESENDS = int(os.getenv("OTP_MAX_RESENDS", "5"))


def _placeholder_email(normalized_phone: str) -> str:
    """Deterministic placeholder email for phone-only users (email column is NOT NULL + unique)."""
    return f"phone.{normalized_phone}@jeevandhara.in"


@router.post("/otp/send", status_code=status.HTTP_200_OK)
def send_otp(
    body: schemas.OtpSendRequest,
    db: Session = Depends(get_db),
    provider: sms.SmsProvider | None = Depends(sms.get_sms_provider),
    limiter: RateLimiter = Depends(get_rate_limiter),
):
    phone = normalize_phone(body.phone)
    if not phone:
        raise HTTPException(status_code=400, detail="Enter a valid Indian mobile number.")

    retry_after = limiter.check(f"otp:{phone}")
    if retry_after:
        raise HTTPException(
            status_code=429,
            detail=f"Too many requests. Try again in {retry_after} seconds.",
            headers={"Retry-After": str(retry_after)},
        )

    if provider is None:
        raise HTTPException(
            status_code=503,
            detail="SMS provider is not configured. Please contact support or try Google login.",
        )

    previous = (
        db.query(models.OtpRequest)
        .filter(models.OtpRequest.phone == phone)
        .order_by(models.OtpRequest.created_at.desc())
        .first()
    )
    resend_count = 0
    if previous:
        seconds_since = (datetime.utcnow() - previous.last_sent_at).total_seconds()
        if seconds_since < OTP_RESEND_COOLDOWN_SECONDS:
            wait = int(OTP_RESEND_COOLDOWN_SECONDS - seconds_since) + 1
            raise HTTPException(
                status_code=429,
                detail=f"Please wait {wait} seconds before requesting another code.",
                headers={"Retry-After": str(wait)},
            )
        resend_count = previous.resend_count + 1
        if resend_count > OTP_MAX_RESENDS:
            raise HTTPException(
                status_code=429,
                detail="Too many codes requested for this number. Try again later.",
                headers={"Retry-After": "1800"},
            )

    code = generate_verification_code()
    row = models.OtpRequest(
        phone=phone,
        code_hash=auth_utils.hash_otp(code),
        resend_count=resend_count,
        last_sent_at=datetime.utcnow(),
        expires_at=datetime.utcnow() + timedelta(seconds=OTP_EXPIRY_SECONDS),
    )
    try:
        provider.send_verification(phone, code)
    except Exception as exc:  # delivery failed — never commit the OTP
        raise HTTPException(status_code=502, detail="Could not send the SMS right now.") from exc

    # Replace any previous codes for this number so only one active OTP exists.
    db.query(models.OtpRequest).filter(models.OtpRequest.phone == phone).delete()
    db.add(row)
    db.commit()

    return {
        "message": "OTP sent",
        "phone": phone,
        "resend_after_seconds": OTP_RESEND_COOLDOWN_SECONDS,
    }


@router.post("/otp/verify", response_model=schemas.AuthResult)
def verify_otp(body: schemas.OtpVerifyRequest, db: Session = Depends(get_db)):
    phone = normalize_phone(body.phone)
    if not phone:
        raise HTTPException(status_code=400, detail="Enter a valid Indian mobile number.")

    row = (
        db.query(models.OtpRequest)
        .filter(models.OtpRequest.phone == phone)
        .order_by(models.OtpRequest.created_at.desc())
        .first()
    )
    if row is None:
        raise HTTPException(status_code=400, detail="No code was requested for this number.")
    if row.expires_at < datetime.utcnow():
        raise HTTPException(status_code=400, detail="Code expired. Request a new one.")
    if row.attempt_count >= OTP_MAX_ATTEMPTS:
        raise HTTPException(status_code=429, detail="Too many incorrect attempts. Request a new code.")

    if not auth_utils.verify_otp(body.otp.strip(), row.code_hash):
        row.attempt_count += 1
        db.commit()
        raise HTTPException(status_code=400, detail="Incorrect code. Please try again.")

    db.delete(row)

    user = (
        db.query(models.User)
        .filter(
            (models.User.phone == phone)
            | (models.User.phone == phone[2:])
            | (models.User.phone == "+" + phone)
        )
        .first()
    )
    if not user:
        user = models.User(
            name="Farmer",
            email=_placeholder_email(phone),
            hashed_password=auth_utils.unusable_password_hash(),
            role=models.UserRole.farmer,
            phone=phone,
            phone_verified=True,
            auth_provider=models.AuthProvider.phone,
            profile_complete=False,
        )
        db.add(user)
        db.commit()
        db.refresh(user)
    else:
        user.phone = phone
        user.phone_verified = True
        db.commit()
        db.refresh(user)

    return auth_utils.issue_auth_result(user)