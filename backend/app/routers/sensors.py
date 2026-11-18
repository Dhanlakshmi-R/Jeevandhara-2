from datetime import datetime

from fastapi import APIRouter, Depends, HTTPException, Query, status
from pydantic import BaseModel, Field
from sqlalchemy.orm import Session

from ..database import get_db
from .. import models

router = APIRouter(prefix="/sensors", tags=["sensors"])


class SoilMoistureIn(BaseModel):
    device_id: str = Field(..., min_length=1, max_length=80)
    moisture_pct: float = Field(..., ge=0, le=100)
    temperature_c: float | None = None
    humidity_pct: float | None = Field(None, ge=0, le=100)
    recorded_at: datetime | None = None


@router.post("/soil-moisture", status_code=status.HTTP_201_CREATED)
def ingest_reading(req: SoilMoistureIn, db: Session = Depends(get_db)):
    row = models.SoilMoistureReading(
        device_id=req.device_id,
        moisture_pct=req.moisture_pct,
        temperature_c=req.temperature_c,
        humidity_pct=req.humidity_pct,
        recorded_at=req.recorded_at or datetime.utcnow(),
    )
    db.add(row)
    db.commit()
    db.refresh(row)
    return {"id": row.id, "recorded_at": row.recorded_at}


@router.get("/soil-moisture/latest")
def latest_reading(device_id: str | None = Query(None), db: Session = Depends(get_db)):
    q = db.query(models.SoilMoistureReading)
    if device_id:
        q = q.filter(models.SoilMoistureReading.device_id == device_id)
    row = q.order_by(models.SoilMoistureReading.recorded_at.desc()).first()
    if row is None:
        raise HTTPException(status_code=404, detail="No soil-moisture readings yet")
    return {
        "device_id": row.device_id,
        "moisture_pct": row.moisture_pct,
        "temperature_c": row.temperature_c,
        "humidity_pct": row.humidity_pct,
        "recorded_at": row.recorded_at,
    }


@router.get("/soil-moisture/history")
def history(device_id: str | None = Query(None), limit: int = Query(50, ge=1, le=500), db: Session = Depends(get_db)):
    q = db.query(models.SoilMoistureReading)
    if device_id:
        q = q.filter(models.SoilMoistureReading.device_id == device_id)
    rows = q.order_by(models.SoilMoistureReading.recorded_at.desc()).limit(limit).all()
    return [
        {
            "device_id": r.device_id,
            "moisture_pct": r.moisture_pct,
            "temperature_c": r.temperature_c,
            "humidity_pct": r.humidity_pct,
            "recorded_at": r.recorded_at,
        }
        for r in rows
    ]