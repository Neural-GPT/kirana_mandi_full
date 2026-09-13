from collections import defaultdict
from datetime import date, datetime, timezone

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.orm import Session

from .. import models, schemas
from ..constants import ADMIN_ROLES
from ..database import get_db
from ..deps import get_current_user

router = APIRouter(tags=["sales & calls"])


def _assert_owns_shop(shop_id: str, user: models.User, db: Session) -> models.Shop:
    shop = db.get(models.Shop, shop_id)
    if shop is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Shop not found.")
    if user.role not in ADMIN_ROLES and shop.owner_user_id != user.id:
        raise HTTPException(status.HTTP_403_FORBIDDEN, "You don't own this shop.")
    return shop


# --- Sales (flat sale_items, matching the mobile app's schema) ---
@router.post("/shops/{shop_id}/sales", response_model=list[schemas.SaleItemOut])
def record_daily_sales(
    shop_id: str,
    body: schemas.RecordSalesRequest,
    db: Session = Depends(get_db),
    user: models.User = Depends(get_current_user),
):
    _assert_owns_shop(shop_id, user, db)
    if not body.entries:
        return []

    created: list[models.SaleItem] = []
    for entry in body.entries:
        row = models.SaleItem(
            shop_id=shop_id,
            product_id=entry.product_id,
            product_name=entry.product_name,
            quantity=entry.quantity,
            unit_price=entry.unit_price,
            sale_date=body.sale_date,
        )
        db.add(row)
        created.append(row)
    db.commit()
    for row in created:
        db.refresh(row)
    return created


@router.get("/shops/{shop_id}/sales", response_model=list[schemas.SaleItemOut])
def sale_items_for_date(
    shop_id: str,
    sale_date: date = Query(...),
    db: Session = Depends(get_db),
    user: models.User = Depends(get_current_user),
):
    _assert_owns_shop(shop_id, user, db)
    return (
        db.query(models.SaleItem)
        .filter(models.SaleItem.shop_id == shop_id, models.SaleItem.sale_date == sale_date)
        .order_by(models.SaleItem.created_at.desc())
        .all()
    )


def _sale_items_in_range(shop_id: str, start: date, end: date, db: Session) -> list[models.SaleItem]:
    return (
        db.query(models.SaleItem)
        .filter(
            models.SaleItem.shop_id == shop_id,
            models.SaleItem.sale_date >= start,
            models.SaleItem.sale_date <= end,
        )
        .all()
    )


@router.get("/shops/{shop_id}/sales/revenue")
def revenue_for_range(
    shop_id: str,
    start: date = Query(...),
    end: date = Query(...),
    db: Session = Depends(get_db),
    user: models.User = Depends(get_current_user),
) -> dict:
    _assert_owns_shop(shop_id, user, db)
    items = _sale_items_in_range(shop_id, start, end, db)
    total = sum(i.quantity * i.unit_price for i in items)
    return {"revenue": total}


@router.get("/shops/{shop_id}/sales/series", response_model=list[schemas.RevenuePointOut])
def revenue_series(
    shop_id: str,
    start: date = Query(...),
    end: date = Query(...),
    group_by: str = Query("day", pattern="^(day|week|month)$"),
    db: Session = Depends(get_db),
    user: models.User = Depends(get_current_user),
):
    """
    Revenue bucketed by day/ISO-week/month, computed in Python rather
    than with a dialect-specific date-grouping SQL expression -- this
    backend needs to run unmodified against both SQLite (local dev) and
    Postgres (production), whose date functions aren't compatible.
    """
    _assert_owns_shop(shop_id, user, db)
    items = _sale_items_in_range(shop_id, start, end, db)

    buckets: dict[str, float] = defaultdict(float)
    for item in items:
        d = item.sale_date
        if group_by == "day":
            key = d.isoformat()
        elif group_by == "week":
            iso = d.isocalendar()
            key = f"{iso[0]}-W{iso[1]:02d}"
        else:  # month
            key = f"{d.year}-{d.month:02d}"
        buckets[key] += item.quantity * item.unit_price

    return [
        schemas.RevenuePointOut(bucket_label=k, revenue=v)
        for k, v in sorted(buckets.items())
    ]


@router.get("/shops/{shop_id}/sales/top-products", response_model=list[schemas.TopProductOut])
def top_products(
    shop_id: str,
    start: date = Query(...),
    end: date = Query(...),
    limit: int = Query(5, ge=1, le=50),
    db: Session = Depends(get_db),
    user: models.User = Depends(get_current_user),
):
    _assert_owns_shop(shop_id, user, db)
    items = _sale_items_in_range(shop_id, start, end, db)

    quantities: dict[str, float] = defaultdict(float)
    for item in items:
        quantities[item.product_name] += item.quantity

    ranked = sorted(quantities.items(), key=lambda kv: kv[1], reverse=True)[:limit]
    return [schemas.TopProductOut(product_name=name, quantity=qty) for name, qty in ranked]


# --- Call logs ---
@router.post("/calls", response_model=schemas.CallLogOut)
def log_call(body: schemas.CallLogCreate, db: Session = Depends(get_db)):
    # Deliberately unauthenticated on the write side -- this fires the
    # moment a customer taps "Call Shop", and customers aren't required
    # to be logged in to see a shop's phone number in the first place.
    shop = db.get(models.Shop, body.shop_id)
    if shop is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Shop not found.")
    call = models.CallLog(shop_id=body.shop_id, caller_label=body.caller_label)
    db.add(call)
    db.commit()
    db.refresh(call)
    return call


@router.get("/shops/{shop_id}/calls", response_model=list[schemas.CallLogOut])
def list_calls(
    shop_id: str,
    limit: int = Query(100, ge=1, le=500),
    db: Session = Depends(get_db),
    user: models.User = Depends(get_current_user),
):
    _assert_owns_shop(shop_id, user, db)
    return (
        db.query(models.CallLog)
        .filter(models.CallLog.shop_id == shop_id)
        .order_by(models.CallLog.called_at.desc())
        .limit(limit)
        .all()
    )


@router.get("/shops/{shop_id}/calls/count")
def call_count_since(
    shop_id: str,
    since: datetime = Query(...),
    db: Session = Depends(get_db),
    user: models.User = Depends(get_current_user),
) -> dict:
    _assert_owns_shop(shop_id, user, db)
    since_aware = since if since.tzinfo else since.replace(tzinfo=timezone.utc)
    count = (
        db.query(models.CallLog)
        .filter(models.CallLog.shop_id == shop_id, models.CallLog.called_at >= since_aware)
        .count()
    )
    return {"count": count}


# --- Optional offline-write audit trail ---
@router.post("/sync-queue", status_code=status.HTTP_204_NO_CONTENT)
def push_sync_queue_entry(
    body: schemas.SyncQueueEntryCreate,
    db: Session = Depends(get_db),
    user: models.User = Depends(get_current_user),
):
    """
    Optional endpoint for a client that made an offline write (using the
    on-device sync_queue table) to report it once back online, for
    server-side audit/reconciliation. Not required for normal operation
    -- every other endpoint in this API commits directly.
    """
    db.add(
        models.SyncQueueEntry(
            device_user_id=user.id,
            entity_type=body.entity_type,
            entity_id=body.entity_id,
            action=body.action,
            payload=body.payload,
        )
    )
    db.commit()
