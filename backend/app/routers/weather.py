from fastapi import APIRouter, HTTPException, Query, status

from .. import weather_service

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