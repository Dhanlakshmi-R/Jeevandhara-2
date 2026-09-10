from fastapi import APIRouter, Depends

from .. import models, schemas, auth_utils

router = APIRouter(prefix="/users", tags=["users"])


@router.get("/me", response_model=schemas.UserOut)
def read_current_user(current_user: models.User = Depends(auth_utils.get_current_user)):
    """Protected route — proves the JWT flow works end-to-end from the app."""
    return current_user
