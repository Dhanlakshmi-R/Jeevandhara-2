"""Admin console operations.

The operational half of the console: weather alerts, notifications, settings,
reports, crop analytics, market review and the permission matrix. It shares the
rules of ``admin.py`` — every route is guarded by :func:`require_admin` (or
:func:`require_superadmin`), nothing credential-shaped is ever returned, and any
action that changes state writes an audit event.

Honesty rules specific to this module:

* Analytics are computed from rows that exist. An empty database yields zeros,
  never sample numbers.
* The market forecast is labelled a *derived estimate* with its basis point
  count, and refuses to answer (``insufficient_data``) when there are too few
  real observations.
* Settings are restricted to a server-side whitelist and coerced to their
  declared type, so the console cannot store a value the app can't read.
"""

from __future__ import annotations

import csv
from datetime import datetime, timedelta
from io import StringIO
from typing import Any

from fastapi import APIRouter, Depends, HTTPException, Query, Request, status
from fastapi.responses import Response
from sqlalchemy import func
from sqlalchemy.orm import Session

from .. import audit, auth_utils, models, schemas
from ..database import get_db

router = APIRouter(prefix="/admin", tags=["admin-ops"])

AdminDep = Depends(auth_utils.require_admin)
SuperadminDep = Depends(auth_utils.require_superadmin)


def _audited(
    db: Session,
    admin: models.User,
    request: Request,
    *,
    event_type: str,
    entity_type: str,
    entity_id: Any = None,
    action: str,
    metadata: dict | None = None,
) -> None:
    audit.record_event(
        db,
        event_type=event_type,
        actor=admin,
        entity_type=entity_type,
        entity_id=entity_id,
        action=action,
        metadata=metadata,
        **audit.request_context(request),
    )


# ============================================================== weather alerts


def _validate_scope(scope_type: str, scope_value: str | None) -> str | None:
    if scope_type in ("state", "district"):
        if not (scope_value and scope_value.strip()):
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail=f"A value is required when scope is '{scope_type}'.",
            )
        return scope_value.strip()
    return None


@router.get("/weather-alerts", response_model=list[schemas.WeatherAlertOut])
def list_weather_alerts(
    active_only: bool = Query(False),
    severity: str | None = Query(None, pattern="^(info|warning|critical)$"),
    limit: int = Query(100, ge=1, le=500),
    admin: models.User = AdminDep,
    db: Session = Depends(get_db),
):
    query = db.query(models.WeatherAlert)
    if active_only:
        query = query.filter(models.WeatherAlert.is_active.is_(True))
    if severity:
        query = query.filter(models.WeatherAlert.severity == severity)
    return (
        query.order_by(models.WeatherAlert.created_at.desc()).limit(limit).all()
    )


@router.post(
    "/weather-alerts",
    response_model=schemas.WeatherAlertOut,
    status_code=status.HTTP_201_CREATED,
)
def create_weather_alert(
    payload: schemas.WeatherAlertCreate,
    request: Request,
    admin: models.User = AdminDep,
    db: Session = Depends(get_db),
):
    scope_value = _validate_scope(payload.scope_type, payload.scope_value)
    alert = models.WeatherAlert(
        title=payload.title.strip(),
        message_en=payload.message_en.strip(),
        message_kn=payload.message_kn,
        severity=payload.severity,
        scope_type=payload.scope_type,
        scope_value=scope_value,
        valid_from=payload.valid_from,
        valid_until=payload.valid_until,
        is_active=payload.is_active,
        created_by_id=admin.id,
    )
    db.add(alert)
    db.commit()
    db.refresh(alert)
    _audited(
        db,
        admin,
        request,
        event_type=audit.EventType.admin_created_weather_alert,
        entity_type="weather_alert",
        entity_id=alert.id,
        action="create",
        metadata={"severity": alert.severity, "scope_type": alert.scope_type},
    )
    return alert


def _get_alert_or_404(db: Session, alert_id: int) -> models.WeatherAlert:
    alert = db.get(models.WeatherAlert, alert_id)
    if alert is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Weather alert not found."
        )
    return alert


@router.put("/weather-alerts/{alert_id}", response_model=schemas.WeatherAlertOut)
def update_weather_alert(
    alert_id: int,
    payload: schemas.WeatherAlertUpdate,
    request: Request,
    admin: models.User = AdminDep,
    db: Session = Depends(get_db),
):
    alert = _get_alert_or_404(db, alert_id)
    data = payload.model_dump(exclude_unset=True)
    if "scope_type" in data or "scope_value" in data:
        scope_type = data.get("scope_type", alert.scope_type)
        scope_value = data.get("scope_value", alert.scope_value)
        alert.scope_value = _validate_scope(scope_type, scope_value)
        alert.scope_type = scope_type
        data.pop("scope_type", None)
        data.pop("scope_value", None)
    for field, value in data.items():
        setattr(alert, field, value)
    alert.updated_at = datetime.utcnow()
    db.commit()
    db.refresh(alert)
    _audited(
        db,
        admin,
        request,
        event_type=audit.EventType.admin_updated_weather_alert,
        entity_type="weather_alert",
        entity_id=alert.id,
        action="update",
        metadata={"fields": sorted(payload.model_dump(exclude_unset=True).keys())},
    )
    return alert


@router.delete("/weather-alerts/{alert_id}", status_code=status.HTTP_200_OK)
def delete_weather_alert(
    alert_id: int,
    request: Request,
    admin: models.User = AdminDep,
    db: Session = Depends(get_db),
):
    alert = _get_alert_or_404(db, alert_id)
    db.delete(alert)
    db.commit()
    _audited(
        db,
        admin,
        request,
        event_type=audit.EventType.admin_deleted_weather_alert,
        entity_type="weather_alert",
        entity_id=alert_id,
        action="delete",
        metadata={"title": alert.title},
    )
    return {"status": "ok", "message": "Weather alert removed."}


# ============================================================= notifications


def _audience_query(db: Session, audience: str, audience_value: str | None):
    if audience == "all":
        return models.User.is_active.is_(True)
    if audience == "role":
        try:
            role = models.UserRole(audience_value)
        except (ValueError, TypeError):
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail="Audience role must be one of: farmer, trader, vendor, admin.",
            )
        return models.User.role == role
    if audience == "location":
        if not (audience_value and audience_value.strip()):
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail="A location is required for a location-targeted notification.",
            )
        like = f"%{audience_value.strip()}%"
        return models.User.location.ilike(like)
    if audience == "user":
        try:
            uid = int(audience_value)
        except (TypeError, ValueError):
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail="A numeric user id is required for a single-user notification.",
            )
        if db.get(models.User, uid) is None:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND, detail="User not found."
            )
        return models.User.id == uid
    raise HTTPException(
        status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
        detail="Audience must be one of: all, role, location, user.",
    )


def _resolve_audience(db: Session, audience: str, audience_value: str | None):
    condition = _audience_query(db, audience, audience_value)
    count = db.query(models.User).filter(condition).count()
    return count


def _audience_summary(audience: str, audience_value: str | None, count: int) -> str:
    if audience == "all":
        return f"All active users ({count})"
    if audience == "role":
        return f"Role {audience_value} ({count})"
    if audience == "location":
        return f"Location contains '{audience_value}' ({count})"
    if audience == "user":
        return f"Single user #{audience_value}"
    return f"{count} recipients"


@router.post(
    "/notifications",
    response_model=schemas.NotificationSendResult,
    status_code=status.HTTP_201_CREATED,
)
def send_notification(
    payload: schemas.NotificationCreate,
    request: Request,
    admin: models.User = AdminDep,
    db: Session = Depends(get_db),
):
    recipient_count = _resolve_audience(db, payload.audience, payload.audience_value)
    note = models.Notification(
        title=payload.title.strip(),
        body_en=payload.body_en.strip(),
        body_kn=payload.body_kn,
        priority=payload.priority,
        audience=payload.audience,
        audience_value=payload.audience_value,
        recipient_count=recipient_count,
        created_by_id=admin.id,
    )
    db.add(note)
    db.commit()
    db.refresh(note)
    _audited(
        db,
        admin,
        request,
        event_type=audit.EventType.admin_sent_notification,
        entity_type="notification",
        entity_id=note.id,
        action="send",
        metadata={
            "audience": payload.audience,
            "recipient_count": recipient_count,
            "priority": payload.priority,
        },
    )
    base = schemas.NotificationOut.model_validate(note)
    return schemas.NotificationSendResult(
        **base.model_dump(),
        audience_summary=_audience_summary(
            payload.audience, payload.audience_value, recipient_count
        ),
    )


@router.get("/notifications", response_model=list[schemas.NotificationOut])
def list_notifications(
    limit: int = Query(50, ge=1, le=200),
    admin: models.User = AdminDep,
    db: Session = Depends(get_db),
):
    return (
        db.query(models.Notification)
        .order_by(models.Notification.created_at.desc())
        .limit(limit)
        .all()
    )


@router.get("/notifications/{notification_id}", response_model=schemas.NotificationOut)
def get_notification(
    notification_id: int,
    admin: models.User = AdminDep,
    db: Session = Depends(get_db),
):
    note = db.get(models.Notification, notification_id)
    if note is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Notification not found."
        )
    return note


# ================================================================== settings

# key -> (type, label, default). Only these keys may be written.
_SETTING_DEFS: dict[str, tuple[str, str, str]] = {
    "support_email": ("str", "Support email", ""),
    "default_language": ("enum:en,kn", "Default language", "en"),
    "maintenance_mode": ("bool", "Maintenance mode", "false"),
    "announcements_enabled": ("bool", "Announcements enabled", "true"),
    "weather_alerts_enabled": ("bool", "Weather alerts enabled", "true"),
    "market_retention_days": ("int", "Market retention (days)", "365"),
    "notification_sender_name": ("str", "Notification sender name", "Jeevandhara"),
}


def _coerce_setting(key: str, value: Any) -> str:
    kind = _SETTING_DEFS[key][0]
    if value is None:
        return ""
    text = str(value).strip()
    if kind == "bool":
        low = text.lower()
        if low in ("true", "1", "yes", "on"):
            return "true"
        if low in ("false", "0", "no", "off", ""):
            return "false"
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail=f"'{key}' must be true or false.",
        )
    if kind == "int":
        try:
            return str(int(text))
        except ValueError:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail=f"'{key}' must be a whole number.",
            )
    if kind.startswith("enum:"):
        allowed = kind.split(":", 1)[1].split(",")
        if text not in allowed:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail=f"'{key}' must be one of: {', '.join(allowed)}.",
            )
        return text
    return text


@router.get("/settings", response_model=schemas.SettingsOut)
def get_settings(
    admin: models.User = AdminDep,
    db: Session = Depends(get_db),
):
    rows = {s.key: s for s in db.query(models.AppSetting).all()}
    items: list[schemas.SettingItem] = []
    for key, (kind, label, default) in _SETTING_DEFS.items():
        row = rows.get(key)
        items.append(
            schemas.SettingItem(
                key=key,
                value=row.value if row is not None else default,
                type=kind,
                label=label,
                default=default,
                updated_at=row.updated_at if row is not None else None,
                updated_by_id=row.updated_by_id if row is not None else None,
            )
        )
    return schemas.SettingsOut(settings=items)


@router.put("/settings", response_model=schemas.SettingsOut)
def update_settings(
    payload: schemas.SettingsUpdate,
    request: Request,
    admin: models.User = AdminDep,
    db: Session = Depends(get_db),
):
    unknown = [k for k in payload.values.keys() if k not in _SETTING_DEFS]
    if unknown:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail=f"Unknown setting key(s): {', '.join(sorted(unknown))}.",
        )
    changed: dict[str, str] = {}
    for key, raw in payload.values.items():
        coerced = _coerce_setting(key, raw)
        row = db.query(models.AppSetting).filter(models.AppSetting.key == key).first()
        if row is None:
            row = models.AppSetting(key=key, value=coerced, updated_by_id=admin.id)
            db.add(row)
        else:
            if row.value == coerced:
                continue
            row.value = coerced
            row.updated_by_id = admin.id
            row.updated_at = datetime.utcnow()
        changed[key] = coerced
    if changed:
        db.commit()
        _audited(
            db,
            admin,
            request,
            event_type=audit.EventType.admin_updated_settings,
            entity_type="app_setting",
            action="update",
            metadata={"changed": sorted(changed.keys())},
        )
    return get_settings(admin=admin, db=db)


# =================================================================== reports


def _period_start(days: int) -> datetime:
    today = datetime.utcnow().date()
    return datetime.combine(today - timedelta(days=days - 1), datetime.min.time())


def _report_summary(db: Session, days: int) -> schemas.ReportSummaryOut:
    since = _period_start(days)
    U = models.User
    return schemas.ReportSummaryOut(
        days=days,
        generated_at=datetime.utcnow(),
        users_total=db.query(U).count(),
        users_new=db.query(U).filter(U.created_at >= since).count(),
        events_total=db.query(models.AuditEvent).count(),
        events_in_period=db.query(models.AuditEvent)
        .filter(models.AuditEvent.created_at >= since)
        .count(),
        crops_total=db.query(models.CropListing).count(),
        crops_active=db.query(models.CropListing)
        .filter(models.CropListing.status == "active")
        .count(),
        marketplace_total=db.query(models.MarketplaceProduct).count(),
        inquiries_total=db.query(models.Inquiry).count(),
        price_alerts_total=db.query(models.WatchlistPriceAlert).count(),
        weather_alerts_active=db.query(models.WeatherAlert)
        .filter(models.WeatherAlert.is_active.is_(True))
        .count(),
        notifications_sent=db.query(models.Notification).count(),
    )


@router.get("/reports/summary", response_model=schemas.ReportSummaryOut)
def report_summary(
    days: int = Query(30, ge=1, le=365),
    admin: models.User = AdminDep,
    db: Session = Depends(get_db),
):
    return _report_summary(db, days)


@router.get("/reports/activity", response_model=list[schemas.EventTypeCount])
def report_activity(
    days: int = Query(30, ge=1, le=365),
    admin: models.User = AdminDep,
    db: Session = Depends(get_db),
):
    since = _period_start(days)
    rows = (
        db.query(models.AuditEvent.event_type, func.count(models.AuditEvent.id))
        .filter(models.AuditEvent.created_at >= since)
        .group_by(models.AuditEvent.event_type)
        .order_by(func.count(models.AuditEvent.id).desc())
        .all()
    )
    return [schemas.EventTypeCount(event_type=t, count=c) for t, c in rows]


@router.get("/reports/crops", response_model=list[schemas.ReportCount])
def report_crops(
    days: int = Query(30, ge=1, le=365),
    limit: int = Query(20, ge=1, le=100),
    admin: models.User = AdminDep,
    db: Session = Depends(get_db),
):
    since = _period_start(days)
    rows = (
        db.query(models.CropListing.name, func.count(models.CropListing.id))
        .filter(models.CropListing.created_at >= since)
        .group_by(models.CropListing.name)
        .order_by(func.count(models.CropListing.id).desc())
        .limit(limit)
        .all()
    )
    return [schemas.ReportCount(key=name, label=name, count=c) for name, c in rows]


@router.get("/reports/export")
def report_export(
    request: Request,
    kind: str = Query("summary", pattern="^(summary|activity|crops)$"),
    days: int = Query(30, ge=1, le=365),
    format: str = Query("json", pattern="^(json|csv)$"),
    admin: models.User = AdminDep,
    db: Session = Depends(get_db),
):
    if kind == "summary":
        data = [_report_summary(db, days).model_dump(mode="json")]
        headers = list(data[0].keys())
    elif kind == "activity":
        data = [r.model_dump(mode="json") for r in report_activity(days=days, admin=admin, db=db)]
        headers = ["event_type", "count"]
    else:
        data = [r.model_dump(mode="json") for r in report_crops(days=days, admin=admin, db=db)]
        headers = ["key", "label", "count"]

    _audited(
        db,
        admin,
        request,
        event_type=audit.EventType.admin_exported_report,
        entity_type="report",
        action="export",
        metadata={"kind": kind, "format": format, "rows": len(data), "days": days},
    )

    if format == "csv":
        buffer = StringIO()
        writer = csv.writer(buffer)
        writer.writerow(headers)
        for row in data:
            writer.writerow([row.get(h) for h in headers])
        return Response(
            content=buffer.getvalue(),
            media_type="text/csv",
            headers={"Content-Disposition": f"attachment; filename=report_{kind}.csv"},
        )
    return {"kind": kind, "days": days, "generated_at": datetime.utcnow().isoformat(), "rows": data}


# ============================================================ crop analytics


@router.get("/analytics/crops", response_model=schemas.CropAnalyticsOut)
def analytics_crops(
    days: int = Query(90, ge=1, le=365),
    limit: int = Query(20, ge=1, le=100),
    admin: models.User = AdminDep,
    db: Session = Depends(get_db),
):
    since = _period_start(days)
    listing_rows = (
        db.query(
            models.CropListing.name,
            func.count(models.CropListing.id),
        func.sum(models.CropListing.quantity),
            func.avg(models.CropListing.expected_price),
        )
        .filter(models.CropListing.created_at >= since)
        .group_by(models.CropListing.name)
        .order_by(func.count(models.CropListing.id).desc())
        .limit(limit)
        .all()
    )
    active_by_name = {
        name: count
        for name, count in db.query(
            models.CropListing.name, func.count(models.CropListing.id)
        )
        .filter(
            models.CropListing.created_at >= since,
            models.CropListing.status == "active",
        )
        .group_by(models.CropListing.name)
        .all()
    }
    crops: list[schemas.CropStat] = []
    for name, total, qty, avg_price in listing_rows:
        market_rows = (
            db.query(models.MarketPrice)
            .filter(models.MarketPrice.commodity == name)
            .count()
        )
        latest = (
            db.query(models.MarketPrice)
            .filter(
                models.MarketPrice.commodity == name,
                models.MarketPrice.modal_price.isnot(None),
            )
            .order_by(models.MarketPrice.trade_date.desc())
            .first()
        )
        crops.append(
            schemas.CropStat(
                commodity=name,
                listings=total,
                active_listings=active_by_name.get(name, 0),
                total_quantity=float(qty or 0),
                avg_expected_price=float(avg_price) if avg_price is not None else None,
                market_rows=market_rows,
                latest_modal_price=latest.modal_price if latest else None,
            )
        )

    status_rows = (
        db.query(models.CropListing.status, func.count(models.CropListing.id))
        .filter(models.CropListing.created_at >= since)
        .group_by(models.CropListing.status)
        .all()
    )
    return schemas.CropAnalyticsOut(
        days=days,
        generated_at=datetime.utcnow(),
        crops=crops,
        listings_by_status=[
            schemas.ReportCount(key=s, label=s, count=c) for s, c in status_rows
        ],
    )


@router.get("/analytics/crops/{commodity}", response_model=schemas.CropDetailOut)
def analytics_crop_detail(
    commodity: str,
    admin: models.User = AdminDep,
    db: Session = Depends(get_db),
):
    name = commodity.strip()
    listings = (
        db.query(models.CropListing).filter(models.CropListing.name == name).all()
    )
    if not listings:
        # A crop with no listings is a valid "no data" answer, not a 404, unless
        # there is also no market history — then there is truly nothing.
        market_count = (
            db.query(models.MarketPrice)
            .filter(models.MarketPrice.commodity == name)
            .count()
        )
        if market_count == 0:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="No listings or market rows for this crop.",
            )

    active = sum(1 for x in listings if x.status == "active")
    sold = sum(1 for x in listings if x.status == "sold")
    total_qty = sum(float(x.quantity or 0) for x in listings)
    prices = [x.expected_price for x in listings if x.expected_price is not None]
    avg_price = sum(prices) / len(prices) if prices else None

    market_rows = (
        db.query(models.MarketPrice).filter(models.MarketPrice.commodity == name)
    )
    market_count = market_rows.count()
    state_rows = (
        db.query(models.MarketPrice.state)
        .filter(
            models.MarketPrice.commodity == name,
            models.MarketPrice.state.isnot(None),
        )
        .distinct()
        .all()
    )
    distinct_markets = (
        db.query(models.MarketPrice.market)
        .filter(models.MarketPrice.commodity == name)
        .distinct()
        .count()
    )
    latest = (
        db.query(models.MarketPrice)
        .filter(
            models.MarketPrice.commodity == name,
            models.MarketPrice.modal_price.isnot(None),
        )
        .order_by(models.MarketPrice.trade_date.desc())
        .first()
    )
    return schemas.CropDetailOut(
        commodity=name,
        listings=len(listings),
        active_listings=active,
        sold_listings=sold,
        total_quantity=total_qty,
        avg_expected_price=avg_price,
        market_rows=market_count,
        distinct_markets=distinct_markets,
        latest_modal_price=latest.modal_price if latest else None,
        latest_trade_date=latest.trade_date if latest else None,
        states=[s for (s,) in state_rows if s],
    )


# =============================================================== market admin


@router.get("/market/prices", response_model=schemas.PagedMarketPrices)
def market_prices(
    commodity: str | None = None,
    market: str | None = None,
    state: str | None = None,
    verified: bool | None = None,
    days: int | None = Query(None, ge=1, le=365),
    limit: int = Query(50, ge=1, le=200),
    offset: int = Query(0, ge=0),
    admin: models.User = AdminDep,
    db: Session = Depends(get_db),
):
    query = db.query(models.MarketPrice)
    if commodity:
        query = query.filter(models.MarketPrice.commodity.ilike(f"%{commodity}%"))
    if market:
        query = query.filter(models.MarketPrice.market.ilike(f"%{market}%"))
    if state:
        query = query.filter(models.MarketPrice.state.ilike(f"%{state}%"))
    if verified is not None:
        query = query.filter(models.MarketPrice.source_verified.is_(verified))
    if days is not None:
        query = query.filter(
            models.MarketPrice.trade_date >= _period_start(days).date()
        )
    total = query.count()
    rows = (
        query.order_by(models.MarketPrice.trade_date.desc(), models.MarketPrice.id.desc())
        .offset(offset)
        .limit(limit)
        .all()
    )
    return schemas.PagedMarketPrices(
        total=total, limit=limit, offset=offset, items=rows
    )


def _set_price_verified(
    db: Session,
    admin: models.User,
    request: Request,
    price_id: int,
    verified: bool,
) -> models.MarketPrice:
    price = db.get(models.MarketPrice, price_id)
    if price is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Market price row not found."
        )
    if price.source_verified != verified:
        price.source_verified = verified
        db.commit()
        db.refresh(price)
        _audited(
            db,
            admin,
            request,
            event_type=audit.EventType.admin_verified_market_price,
            entity_type="market_price",
            entity_id=price.id,
            action="verify" if verified else "unverify",
            metadata={"commodity": price.commodity, "market": price.market},
        )
    return price


@router.post("/market/prices/{price_id}/verify", response_model=schemas.MarketPriceAdminOut)
def verify_market_price(
    price_id: int,
    request: Request,
    admin: models.User = AdminDep,
    db: Session = Depends(get_db),
):
    return _set_price_verified(db, admin, request, price_id, True)


@router.post("/market/prices/{price_id}/unverify", response_model=schemas.MarketPriceAdminOut)
def unverify_market_price(
    price_id: int,
    request: Request,
    admin: models.User = AdminDep,
    db: Session = Depends(get_db),
):
    return _set_price_verified(db, admin, request, price_id, False)


@router.get("/market/sources", response_model=list[schemas.MarketSourceOut])
def market_sources(
    admin: models.User = AdminDep,
    db: Session = Depends(get_db),
):
    rows = (
        db.query(
            models.MarketPrice.source_name,
            func.count(models.MarketPrice.id),
            func.max(models.MarketPrice.fetched_at),
        )
        .group_by(models.MarketPrice.source_name)
        .all()
    )
    out: list[schemas.MarketSourceOut] = []
    for name, rows_count, latest in rows:
        verified = (
            db.query(models.MarketPrice)
            .filter(
                models.MarketPrice.source_name == name,
                models.MarketPrice.source_verified.is_(True),
            )
            .count()
        )
        out.append(
            schemas.MarketSourceOut(
                source_name=name,
                rows=rows_count,
                latest_fetch=latest,
                verified_rows=verified,
            )
        )
    return out


@router.get("/market/forecast", response_model=schemas.MarketForecastOut)
def market_forecast(
    commodity: str = Query(..., min_length=1, max_length=120),
    state: str | None = Query(None, max_length=80),
    horizon: int = Query(7, ge=1, le=30),
    admin: models.User = AdminDep,
    db: Session = Depends(get_db),
):
    """A least-squares projection over stored daily averages.

    This is a *derived estimate*, not a forecast from a source and not advice.
    It returns ``insufficient_data`` (with a reason) whenever there are fewer
    than three real observations, rather than drawing a line through noise.
    """
    query = (
        db.query(models.CropPriceHistory)
        .filter(models.CropPriceHistory.commodity == commodity)
    )
    if state:
        query = query.filter(models.CropPriceHistory.state == state)
    query = query.filter(models.CropPriceHistory.avg_modal_price.isnot(None)).order_by(
        models.CropPriceHistory.date.asc()
    )
    rows = query.limit(120).all()
    series = [(r.date, r.avg_modal_price) for r in rows if r.avg_modal_price is not None]

    method = "least_squares_linear"
    base_out = {
        "commodity": commodity,
        "state": state,
        "generated_at": datetime.utcnow(),
        "basis_points": len(series),
        "horizon_days": horizon,
        "method": method,
    }
    if len(series) < 3:
        return schemas.MarketForecastOut(
            status="insufficient_data",
            reason=(
                "Fewer than 3 daily observations are stored for this crop"
                + (f" in {state}" if state else "")
                + "; a projection would be noise."
            ),
            slope_per_day=None,
            last_value=series[-1][1] if series else None,
            projection=[],
            **base_out,
        )

    n = len(series)
    xs = list(range(n))
    ys = [v for _, v in series]
    mean_x = sum(xs) / n
    mean_y = sum(ys) / n
    denom = sum((x - mean_x) ** 2 for x in xs)
    slope = 0.0 if denom == 0 else sum(
        (x - mean_x) * (y - mean_y) for x, y in zip(xs, ys)
    ) / denom
    intercept = mean_y - slope * mean_x
    last_date = series[-1][0]
    projection = [
        schemas.ForecastPoint(
            date=last_date + timedelta(days=step),
            value=round(intercept + slope * (n - 1 + step), 2),
        )
        for step in range(1, horizon + 1)
    ]
    return schemas.MarketForecastOut(
        status="ok",
        reason=None,
        slope_per_day=round(slope, 2),
        last_value=ys[-1],
        projection=projection,
        **base_out,
    )


# ================================================================ permissions

# Derived from the live guards: what each endpoint actually allows. Not a
# decorative matrix — if a guard changes, this is updated with it.
_CAPABILITIES: list[tuple[str, str, str, list[str]]] = [
    ("view_dashboard", "View dashboard", "See console overview and trends.", ["admin"]),
    ("manage_users", "Manage users", "Suspend or reactivate non-admin accounts.", ["admin"]),
    ("manage_admins", "Manage admins", "Suspend or reactivate admin accounts.", ["superadmin"]),
    ("view_activity", "View activity logs", "Read the audit trail.", ["admin"]),
    ("export_audit", "Export audit log", "Download the full audit trail.", ["superadmin"]),
    ("manage_weather_alerts", "Manage weather alerts", "Publish and edit alerts.", ["admin"]),
    ("send_notifications", "Send notifications", "Broadcast to users.", ["admin"]),
    ("manage_settings", "Manage settings", "Edit application settings.", ["admin"]),
    ("view_reports", "View reports", "View aggregate reports.", ["admin"]),
    ("export_reports", "Export reports", "Download reports.", ["admin"]),
    ("review_market_prices", "Review market prices", "Verify or unverify price rows.", ["admin"]),
    ("view_crop_analytics", "View crop analytics", "See crop analytics.", ["admin"]),
    # Personal-app capabilities, shown so the matrix is complete.
    ("sell_crop", "Sell a crop", "Post a crop for sale.", ["farmer"]),
    ("post_offer", "Post an offer", "Publish a buying offer.", ["trader"]),
    ("browse_marketplace", "Browse marketplace", "Buy inputs.", ["farmer", "trader", "vendor"]),
    ("rent_tools", "Rent tools", "List or hire equipment.", ["farmer"]),
]


@router.get("/permissions", response_model=schemas.PermissionsOut)
def permissions(
    admin: models.User = AdminDep,
    db: Session = Depends(get_db),
):
    return schemas.PermissionsOut(
        roles=["farmer", "trader", "vendor", "admin", "superadmin"],
        capabilities=[
            schemas.PermissionCapability(
                key=key, label=label, description=desc, roles=roles
            )
            for key, label, desc, roles in _CAPABILITIES
        ],
    )



