from fastapi import APIRouter, Depends, HTTPException, Request, status
from fastapi.security import OAuth2PasswordRequestForm
from sqlalchemy.orm import Session

from .. import audit, auth_utils, crop_seeding, models, schemas, sessions
from ..database import get_db

router = APIRouter(prefix="/auth", tags=["auth"])


@router.post("/register", response_model=schemas.UserOut, status_code=status.HTTP_201_CREATED)
def register(
    user_in: schemas.UserCreate,
    request: Request,
    db: Session = Depends(get_db),
):
    # Admin is never self-service. The first admin is minted by
    # `backend/scripts/create_admin.py`; later ones by a superadmin.
    if user_in.role == models.UserRole.admin:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Admin accounts cannot be created here.",
        )
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

    # Give new farmers a starter set of crop listings so My Crops is not empty.
    crop_seeding.seed_default_crops(db, user)

    audit.record_event(
        db,
        event_type=audit.EventType.profile_created,
        actor=user,
        entity_type="user",
        entity_id=user.id,
        action="register",
        metadata={"role": user.role.value},
        **audit.request_context(request),
    )
    return user


@router.post("/login", response_model=schemas.AuthResult)
def login(
    request: Request,
    form_data: OAuth2PasswordRequestForm = Depends(),
    db: Session = Depends(get_db),
):
    """
    Uses OAuth2PasswordRequestForm so this also works directly from the
    FastAPI docs UI (/docs) — it expects form fields 'username' and
    'password'. The Flutter app sends `username=<email>&password=<pw>`.
    """
    user = db.query(models.User).filter(models.User.email == form_data.username).first()
    if not user or not auth_utils.verify_password(form_data.password, user.hashed_password):
        # Failures are recorded too — a login that did not happen is exactly
        # what a security trail needs to see.
        audit.record_event(
            db,
            event_type=audit.EventType.login_failed,
            actor=None,
            actor_role=None,
            entity_type="user",
            action="login",
            metadata={"email": form_data.username},
            **audit.request_context(request),
        )
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect email or password",
        )

    if not user.is_active:
        audit.record_event(
            db,
            event_type=audit.EventType.login_failed,
            actor=user,
            entity_type="user",
            entity_id=user.id,
            action="login",
            metadata={"reason": "suspended", "email": user.email},
            **audit.request_context(request),
        )
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="This account is suspended.",
        )

    return auth_utils.issue_auth_result(user, db, request)


@router.post("/logout", status_code=status.HTTP_200_OK)
def logout(
    request: Request,
    token: str = Depends(auth_utils.oauth2_scheme),
    db: Session = Depends(get_db),
):
    """Close the current session and record a logout event.

    A token that no longer verifies still gets a best-effort local sign-out on
    the client; server-side we only act when we can identify the session.
    """
    session = None
    try:
        payload = auth_utils.decode_token(token)
    except HTTPException:
        raise

    sid = payload.get("sid")
    user = db.query(models.User).filter(models.User.id == int(payload["sub"])).first()
    if sid is not None:
        session = (
            db.query(models.UserSession)
            .filter(models.UserSession.id == int(sid), models.UserSession.is_active.is_(True))
            .first()
        )
    if session is not None:
        sessions.end_session(db, session, "logout", commit=False)
    audit.record_event(
        db,
        event_type=audit.EventType.logout,
        actor=user,
        entity_type="user_session" if session is not None else "user",
        entity_id=session.id if session is not None else (user.id if user else None),
        session_id=session.id if session is not None else None,
        action="logout",
        **audit.request_context(request),
    )
    db.commit()
    return {"status": "ok", "message": "Signed out."}


@router.post("/refresh", response_model=schemas.AuthResult)
def refresh(
    body: schemas.RefreshRequest,
    request: Request,
    db: Session = Depends(get_db),
):
    """Exchange a refresh token for a new access + refresh token (rotation).

    The presented token must match the hash stored on its session. If it does
    not — a replayed/older token — the whole session is revoked and a
    `token_reuse_detected` event is written, which is the whole point of rotating.
    """
    payload = auth_utils.decode_token(body.refresh_token, expected_type="refresh")
    sid = payload.get("sid")
    if sid is None:
        raise auth_utils._credentials_exception()

    session = (
        db.query(models.UserSession).filter(models.UserSession.id == int(sid)).first()
    )
    if session is None or not session.is_active:
        raise auth_utils._credentials_exception()

    user = db.query(models.User).filter(models.User.id == session.user_id).first()
    if user is None or not user.is_active:
        sessions.end_session(db, session, "revoked", commit=False)
        audit.record_event(
            db,
            event_type=audit.EventType.logout,
            actor=user,
            entity_type="user_session",
            entity_id=session.id,
            session_id=session.id,
            action="revoke",
            metadata={"reason": "account_inactive"},
            **audit.request_context(request),
        )
        db.commit()
        raise auth_utils._credentials_exception()

    if not auth_utils.verify_token_hash(body.refresh_token, session.refresh_token_hash):
        # Reuse (or an older token in the family). Kill the session and say so.
        sessions.end_session(db, session, "rotation_reuse", commit=False)
        audit.record_event(
            db,
            event_type=audit.EventType.token_reuse_detected,
            actor=user,
            entity_type="user_session",
            entity_id=session.id,
            session_id=session.id,
            action="refresh",
            **audit.request_context(request),
        )
        db.commit()
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Refresh token has already been used. Please sign in again.",
        )

    new_refresh = auth_utils.create_refresh_token(session)
    session.refresh_token_hash = auth_utils.hash_token(new_refresh)
    sessions.touch_session(db, session, commit=False)
    access_token = auth_utils.create_access_token(
        data={"sub": str(user.id), "role": user.role.value, "sid": session.id}
    )
    audit.record_event(
        db,
        event_type=audit.EventType.token_refresh,
        actor=user,
        entity_type="user_session",
        entity_id=session.id,
        session_id=session.id,
        action="refresh",
        **audit.request_context(request),
    )
    db.commit()
    return {
        "access_token": access_token,
        "refresh_token": new_refresh,
        "token_type": "bearer",
        "profile_complete": user.profile_complete,
        "user": user,
    }


@router.get("/sessions", response_model=list[schemas.SessionOut])
def list_sessions(
    token: str = Depends(auth_utils.oauth2_scheme),
    db: Session = Depends(get_db),
    current_user: models.User = Depends(auth_utils.get_current_user),
):
    """The signed-in device list for the current user."""
    try:
        current_sid = auth_utils.decode_token(token).get("sid")
    except HTTPException:
        current_sid = None
    rows = sessions.sessions_for_user(db, current_user.id)
    out = []
    for row in rows:
        item = schemas.SessionOut.model_validate(row)
        item.is_current = row.id == current_sid
        out.append(item)
    return out


@router.delete("/sessions/{session_id}", status_code=status.HTTP_200_OK)
def revoke_own_session(
    session_id: int,
    request: Request,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(auth_utils.get_current_user),
):
    """Sign out one of *your own* devices. 404 for anyone else's session."""
    session = (
        db.query(models.UserSession)
        .filter(
            models.UserSession.id == session_id,
            models.UserSession.user_id == current_user.id,
        )
        .first()
    )
    if session is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Session not found.")
    if session.is_active:
        sessions.end_session(db, session, "revoked", commit=False)
        audit.record_event(
            db,
            event_type=audit.EventType.logout,
            actor=current_user,
            entity_type="user_session",
            entity_id=session.id,
            session_id=session.id,
            action="revoke_session",
            metadata={"reason": "user_revoked"},
            **audit.request_context(request),
        )
        db.commit()
    return {"status": "ok", "message": "Session signed out."}


@router.post("/logout-all", status_code=status.HTTP_200_OK)
def logout_all(
    request: Request,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(auth_utils.get_current_user),
):
    """Sign out of every device at once."""
    rows = sessions.sessions_for_user(db, current_user.id, active_only=True)
    ctx = audit.request_context(request)
    for row in rows:
        sessions.end_session(db, row, "logout", commit=False)
        audit.record_event(
            db,
            event_type=audit.EventType.logout,
            actor=current_user,
            entity_type="user_session",
            entity_id=row.id,
            session_id=row.id,
            action="logout_all",
            **ctx,
        )
    db.commit()
    return {"status": "ok", "revoked": len(rows)}


@router.post("/complete-profile", response_model=schemas.AuthResult)
def complete_profile(
    body: schemas.ProfileCompleteRequest,
    request: Request,
    token: str = Depends(auth_utils.oauth2_scheme),
    db: Session = Depends(get_db),
    current_user: models.User = Depends(auth_utils.get_current_user),
):
    """
    Called after a successful Google/OTP sign-in when `profile_complete` is
    False, to collect name/role/location before entering the app. Also usable
    later to update profile data for any signed-in user.
    """
    if body.role == models.UserRole.admin:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Admin accounts cannot be created here.",
        )
    previous_role = current_user.role
    previous_location = current_user.location
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

    crop_seeding.seed_default_crops(db, current_user)

    audit.record_event(
        db,
        event_type=audit.EventType.profile_updated,
        actor=current_user,
        entity_type="user",
        entity_id=current_user.id,
        action="complete_profile",
        metadata={"role": current_user.role.value},
        **audit.request_context(request),
    )
    if previous_role != current_user.role:
        audit.record_event(
            db,
            event_type=audit.EventType.role_changed,
            actor=current_user,
            entity_type="user",
            entity_id=current_user.id,
            action="role_change",
            metadata={
                "from": getattr(previous_role, "value", previous_role),
                "to": current_user.role.value,
            },
            **audit.request_context(request),
        )
    if body.location and body.location != previous_location:
        audit.record_event(
            db,
            event_type=audit.EventType.place_changed,
            actor=current_user,
            entity_type="user",
            entity_id=current_user.id,
            action="place_change",
            metadata={"to": body.location},
            **audit.request_context(request),
        )
    try:
        existing_sid = auth_utils.decode_token(token).get("sid")
    except HTTPException:
        existing_sid = None
    return auth_utils.issue_auth_result(
        current_user, session_id=existing_sid, start_session=False
    )
