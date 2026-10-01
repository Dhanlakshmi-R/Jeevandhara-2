from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from .. import models, schemas, auth_utils, google_auth
from ..database import get_db
from ..google_auth import google_verifier

router = APIRouter(prefix="/auth", tags=["auth"])


@router.post("/google", response_model=schemas.AuthResult)
def google_login(
    body: schemas.GoogleAuthRequest,
    db: Session = Depends(get_db),
    verify=Depends(google_verifier),
):
    info = verify(body.id_token)
    sub = str(info["sub"])
    email = (info.get("email") or "").lower()
    name = (info.get("name") or "").strip() or "Farmer"
    picture = info.get("picture")

    user = db.query(models.User).filter(models.User.provider_user_id == sub).first()
    if user is None and email:
        # Link to an existing password-registered account with the same email.
        user = db.query(models.User).filter(models.User.email == email).first()

    if user is None:
        user = models.User(
            name=name,
            email=email or f"google.{sub[:20]}@jeevandhara.in",
            hashed_password=auth_utils.unusable_password_hash(),
            role=models.UserRole.farmer,
            auth_provider=models.AuthProvider.google,
            provider_user_id=sub,
            profile_image=picture,
            profile_complete=False,
        )
        db.add(user)
        db.commit()
        db.refresh(user)
    else:
        if user.auth_provider is None or user.auth_provider == models.AuthProvider.password:
            user.auth_provider = models.AuthProvider.google
            user.provider_user_id = sub
        if picture and not user.profile_image:
            user.profile_image = picture
        db.commit()
        db.refresh(user)

    return auth_utils.issue_auth_result(user)