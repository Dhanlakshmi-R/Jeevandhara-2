"""User-facing notification inbox.

Read-only: a signed-in user sees the broadcasts an operator resolved to them
(`all`, their role, their location, or them specifically). Delivery is not
fanned out into per-user rows, so `seen` is tracked on the client only.
"""

from __future__ import annotations

from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session

from .. import auth_utils, models, schemas
from ..database import get_db

router = APIRouter(prefix="/notifications", tags=["notifications"])


def _applies(note: models.Notification, user: models.User) -> bool:
    if note.audience == "all":
        return True
    if note.audience == "role":
        return note.audience_value == user.role.value
    if note.audience == "user":
        return note.audience_value == str(user.id)
    if note.audience == "location":
        if not note.audience_value or not user.location:
            return False
        needle = note.audience_value.lower()
        haystack = user.location.lower()
        return needle in haystack or haystack in needle
    return False


@router.get("", response_model=list[schemas.NotificationOut])
def list_my_notifications(
    limit: int = Query(50, ge=1, le=200),
    current_user: models.User = Depends(auth_utils.get_current_user),
    db: Session = Depends(get_db),
):
    rows = (
        db.query(models.Notification)
        .order_by(models.Notification.created_at.desc())
        .limit(200)
        .all()
    )
    result = [n for n in rows if _applies(n, current_user)]
    return result[:limit]
