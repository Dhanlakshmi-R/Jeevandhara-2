"""`/weather/places/...` — the offline, all-India location hierarchy.

Every response carries coordinates, so the app never has to geocode a name it
just picked from a list. No weather provider or API key is involved.
"""

from fastapi import APIRouter, HTTPException, Query, status

from .. import places

router = APIRouter(prefix="/weather/places", tags=["weather-places"])


def _lookup(fn, *args):
    """Run a gazetteer lookup, mapping LookupError to 404."""
    try:
        return fn(*args)
    except LookupError as exc:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail=str(exc)
        ) from exc


@router.get("/states")
def states():
    """All 28 states + 8 union territories, each with coordinates."""
    try:
        return {"states": places.gazetteer().list_states()}
    except RuntimeError as exc:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE, detail=str(exc)
        ) from exc


@router.get("/districts")
def districts(state: str = Query(..., min_length=1, max_length=80)):
    return _lookup(places.gazetteer().list_districts, state)


@router.get("/taluks")
def taluks(
    state: str = Query(..., min_length=1, max_length=80),
    district: str = Query(..., min_length=1, max_length=100),
):
    return _lookup(places.gazetteer().list_taluks, state, district)


@router.get("/villages")
def villages(
    state: str = Query(..., min_length=1, max_length=80),
    district: str = Query(..., min_length=1, max_length=100),
    taluk: str = Query(..., min_length=1, max_length=120),
):
    return _lookup(places.gazetteer().list_villages, state, district, taluk)


@router.get("/resolve")
def resolve(
    state: str = Query(..., min_length=1, max_length=80),
    district: str | None = Query(None, max_length=100),
    taluk: str | None = Query(None, max_length=120),
    village: str | None = Query(None, max_length=140),
):
    """Coordinates for whichever level the user chose.

    Every level is valid on its own -- a state, a district or a taluk can be
    the final answer. The response names the level the coordinates came from
    (`level`) and sets `fallback` when a village was asked for but only a
    taluk could be located, so the UI can be honest about precision.
    """
    return _lookup(
        places.gazetteer().resolve, state, district, taluk, village
    )
