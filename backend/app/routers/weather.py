from datetime import datetime

import asyncio
import json
from datetime import datetime

from fastapi import APIRouter, Depends, HTTPException, Query, status
from fastapi.responses import StreamingResponse
from sqlalchemy import or_
from sqlalchemy.orm import Session

from .. import models, weather_service
from ..database import get_db

router = APIRouter(prefix="/weather", tags=["weather"])


def _require_configured() -> None:
    if not weather_service.is_configured():
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Weather service is not configured",
        )


@router.get("/suggestions")
def suggestions(
    q: str = Query(..., min_length=1, max_length=100, description="Place/city search term"),
    state: str | None = Query(None, max_length=60, description="Indian state/UT to filter by"),
):
    """Indian place suggestions used by the app's location search."""
    _require_configured()
    try:
        return weather_service.fetch_suggestions(q, state)
    except RuntimeError as exc:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY, detail=str(exc)
        ) from exc


@router.get("")
def weather(
    lat: float = Query(..., ge=-90, le=90),
    lon: float = Query(..., ge=-180, le=180),
    name: str = Query("", max_length=120),
):
    """Current conditions + hourly + daily forecast + alerts for coordinates."""
    _require_configured()
    try:
        return weather_service.fetch_weather(lat, lon, name)
    except RuntimeError as exc:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY, detail=str(exc)
        ) from exc


@router.get("/alerts")
def alerts(
    state: str | None = Query(None, max_length=80),
    district: str | None = Query(None, max_length=80),
    db: Session = Depends(get_db),
):
    """Operator-published weather advisories for a place, if any.

    Separate from the forecast provider's alerts: these are the app's own
    advisories and are shown regardless of whether a weather provider is
    configured. Only currently-active rows (and, where set, within their valid
    window) are returned.
    """
    now = datetime.utcnow()
    query = db.query(models.WeatherAlert).filter(
        models.WeatherAlert.is_active.is_(True),
        or_(
            models.WeatherAlert.valid_from.is_(None),
            models.WeatherAlert.valid_from <= now,
        ),
        or_(
            models.WeatherAlert.valid_until.is_(None),
            models.WeatherAlert.valid_until >= now,
        ),
    )
    scope_clauses = [models.WeatherAlert.scope_type == "all"]
    if state:
        scope_clauses.append(
            (models.WeatherAlert.scope_type == "state")
            & (models.WeatherAlert.scope_value.ilike(state))
        )
    if district:
        scope_clauses.append(
            (models.WeatherAlert.scope_type == "district")
            & (models.WeatherAlert.scope_value.ilike(district))
        )
    query = query.filter(or_(*scope_clauses))
    rows = query.order_by(models.WeatherAlert.created_at.desc()).limit(50).all()
    return [
        {
            "id": a.id,
            "title": a.title,
            "message_en": a.message_en,
            "message_kn": a.message_kn,
            "severity": a.severity,
            "scope_type": a.scope_type,
            "scope_value": a.scope_value,
            "valid_from": a.valid_from,
            "valid_until": a.valid_until,
            "created_at": a.created_at,
        }
        for a in rows
    ]@router.get("/stream")
async def stream(
    lat: float = Query(..., ge=-90, le=90),
    lon: float = Query(..., ge=-180, le=180),
    name: str = Query("", max_length=120),
):
    async def generator():
        while True:
            try:
                reading = await asyncio.to_thread(
                    weather_service.fetch_weather, lat, lon, name
                )
                yield "data: " + json.dumps(reading) + "\n\n"
            except Exception as exc:
                payload = {"error": str(exc)}
                yield "event: error\ndata: " + json.dumps(payload) + "\n\n"
            for _ in range(12):
                await asyncio.sleep(5)
                yield ": heartbeat\n\n"

    return StreamingResponse(
        generator(),
        media_type="text/event-stream",
        headers={
            "Cache-Control": "no-cache",
            "Connection": "keep-alive",
            "X-Accel-Buffering": "no",
        },
    )
