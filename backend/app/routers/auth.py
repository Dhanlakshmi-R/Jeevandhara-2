from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.security import OAuth2PasswordRequestForm
from sqlalchemy.orm import Session

from .. import models, schemas, auth_utils
from ..database import get_db

router = APIRouter(prefix="/auth", tags=["auth"])


@router.post("/register", response_model=schemas.UserOut, status_code=status.HTTP_201_CREATED)
def register(user_in: schemas.UserCreate, db: Session = Depends(get_db)):
    existing = db.query(models.User).filter(models.User.email == user_in.email).first()
    if existing:
        raise HTTPException(status_code=400, detail="Email already registered")

    user = models.User(
        name=user_in.name,
        email=user_in.email,
        hashed_password=auth_utils.hash_password(user_in.password),
        role=user_in.role,
        phone=user_in.phone,
        location=user_in.location,
    )
    db.add(user)
    db.commit()
    db.refresh(user)
    return user


@router.post("/login", response_model=schemas.Token)
def login(form_data: OAuth2PasswordRequestForm = Depends(), db: Session = Depends(get_db)):
    """
    Uses OAuth2PasswordRequestForm so this also works directly from the
    FastAPI docs UI (/docs) — it expects form fields 'username' and
    'password'. The Flutter app sends `username=<email>&password=<pw>`.
    """
    user = db.query(models.User).filter(models.User.email == form_data.username).first()
    if not user or not auth_utils.verify_password(form_data.password, user.hashed_password):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect email or password",
        )

    access_token = auth_utils.create_access_token(data={"sub": str(user.id)})
    return {"access_token": access_token, "token_type": "bearer"}


@router.post("/complete-profile", response_model=schemas.AuthResult)
def complete_profile(
    body: schemas.ProfileCompleteRequest,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(auth_utils.get_current_user),
):
    """
    Called after a successful Google/OTP sign-in when `profile_complete` is
    False, to collect name/role/location before entering the app. Also usable
    later to update profile data for any signed-in user.
    """
    if body.phone:
        current_user.phone = body.phone
    current_user.name = body.name
    current_user.role = body.role
    if body.location:
        current_user.location = body.location
    if body.profile_image:
        current_user.profile_image = body.profile_image
    current_user.profile_complete = True
    db.commit()
    db.refresh(current_user)
    return auth_utils.issue_auth_result(current_user)
