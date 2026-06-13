from datetime import date, datetime, timedelta, timezone

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy import func, or_
from sqlalchemy.orm import Session

from app.auth import get_current_user
from app.db.models import Deal, InventoryItem
from app.db.models.inventory import STATUS_CONSUMED, STATUS_DISCARDED, STATUS_IN_STOCK
from app.db.models.user import User
from app.db.session import get_db
from app.schemas.inventory import (
    ConsumeRequest,
    InventoryItemCreate,
    InventoryItemOut,
    InventoryItemUpdate,
    InventoryStatsOut,
)

router = APIRouter(prefix="/inventory", tags=["inventory"])


def _get_owned_item(db: Session, user: User, item_id: int) -> InventoryItem:
    item = db.query(InventoryItem).filter(
        InventoryItem.id == item_id, InventoryItem.user_id == user.id
    ).first()
    if item is None:
        raise HTTPException(status_code=404, detail=f"Inventory item {item_id} not found")
    return item


@router.get("/", response_model=list[InventoryItemOut])
def list_inventory(
    status: str | None = Query(None, pattern="^(in_stock|consumed|discarded)$"),
    search: str | None = Query(None, description="Search by name or brand"),
    chain: str | None = Query(None),
    expiring_within_days: int | None = Query(None, ge=0, description="Only items expiring within N days"),
    limit: int = Query(50, le=200),
    offset: int = Query(0, ge=0),
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    q = db.query(InventoryItem).filter(InventoryItem.user_id == user.id)

    if status:
        q = q.filter(InventoryItem.status == status)
    if search:
        term = f"%{search}%"
        q = q.filter(or_(InventoryItem.name.ilike(term), InventoryItem.brand.ilike(term)))
    if chain:
        q = q.filter(InventoryItem.chain == chain.upper())
    if expiring_within_days is not None:
        cutoff = date.today() + timedelta(days=expiring_within_days)
        q = q.filter(InventoryItem.expiry_date.isnot(None), InventoryItem.expiry_date <= cutoff)

    items = q.order_by(InventoryItem.purchased_at.desc()).offset(offset).limit(limit).all()
    return [InventoryItemOut.model_validate(i) for i in items]


@router.get("/stats", response_model=InventoryStatsOut)
def inventory_stats(
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    status_counts = dict(
        db.query(InventoryItem.status, func.count(InventoryItem.id))
        .filter(InventoryItem.user_id == user.id)
        .group_by(InventoryItem.status)
        .all()
    )

    expiring = (
        db.query(func.count(InventoryItem.id))
        .filter(
            InventoryItem.user_id == user.id,
            InventoryItem.status == STATUS_IN_STOCK,
            InventoryItem.expiry_date.isnot(None),
            InventoryItem.expiry_date <= date.today() + timedelta(days=7),
        )
        .scalar()
    )

    spent = (
        db.query(func.coalesce(func.sum(InventoryItem.total_price), 0.0))
        .filter(
            InventoryItem.user_id == user.id,
            InventoryItem.purchased_at >= datetime.now(timezone.utc) - timedelta(days=30),
        )
        .scalar()
    )

    return InventoryStatsOut(
        in_stock=status_counts.get(STATUS_IN_STOCK, 0),
        consumed=status_counts.get(STATUS_CONSUMED, 0),
        discarded=status_counts.get(STATUS_DISCARDED, 0),
        expiring_within_7_days=expiring or 0,
        spent_last_30_days=round(float(spent or 0), 2),
    )


@router.get("/{item_id}", response_model=InventoryItemOut)
def get_inventory_item(
    item_id: int,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    return InventoryItemOut.model_validate(_get_owned_item(db, user, item_id))


@router.post("/", response_model=InventoryItemOut, status_code=201)
def add_inventory_item(
    payload: InventoryItemCreate,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    """Add directly to inventory, e.g. buying a deal on the spot without a list."""
    item = InventoryItem(
        user_id=user.id,
        quantity=payload.quantity,
        quantity_remaining=payload.quantity,
        unit=payload.unit,
        purchase_price=payload.purchase_price,
        total_price=payload.total_price,
        purchased_at=payload.purchased_at or datetime.now(timezone.utc),
        expiry_date=payload.expiry_date,
        note=payload.note,
    )

    if payload.deal_id is not None:
        deal = db.query(Deal).filter(Deal.id == payload.deal_id).first()
        if deal is None:
            raise HTTPException(status_code=404, detail=f"Deal {payload.deal_id} not found")
        item.deal_id = deal.id
        item.store_id = deal.store_id
        item.name = payload.name or deal.name
        item.brand = payload.brand or deal.brand
        item.size = payload.size or deal.size
        item.image_url = deal.image_url
        item.chain = deal.chain
        item.was_deal = True
        item.deal_text = deal.deal_text
        if item.purchase_price is None:
            item.purchase_price = deal.deal_price
    else:
        item.name = payload.name.strip()
        item.brand = payload.brand
        item.size = payload.size

    if item.total_price is None and item.purchase_price is not None:
        item.total_price = round(item.purchase_price * item.quantity, 2)

    db.add(item)
    db.commit()
    db.refresh(item)
    return InventoryItemOut.model_validate(item)


@router.patch("/{item_id}", response_model=InventoryItemOut)
def update_inventory_item(
    item_id: int,
    payload: InventoryItemUpdate,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    item = _get_owned_item(db, user, item_id)

    for field in ("expiry_date", "note", "purchase_price", "total_price"):
        value = getattr(payload, field)
        if value is not None:
            setattr(item, field, value)

    if payload.quantity_remaining is not None:
        item.quantity_remaining = payload.quantity_remaining
        if item.quantity_remaining <= 0 and item.status == STATUS_IN_STOCK:
            item.status = STATUS_CONSUMED
            item.consumed_at = datetime.now(timezone.utc)

    if payload.status is not None:
        item.status = payload.status
        if payload.status in (STATUS_CONSUMED, STATUS_DISCARDED) and item.consumed_at is None:
            item.consumed_at = datetime.now(timezone.utc)
        elif payload.status == STATUS_IN_STOCK:
            item.consumed_at = None

    db.commit()
    db.refresh(item)
    return InventoryItemOut.model_validate(item)


@router.post("/{item_id}/consume", response_model=InventoryItemOut)
def consume_inventory_item(
    item_id: int,
    payload: ConsumeRequest | None = None,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    """Consume some or all of an item; fully consumed items leave 'in_stock'."""
    item = _get_owned_item(db, user, item_id)
    if item.status != STATUS_IN_STOCK:
        raise HTTPException(status_code=409, detail=f"Item is already {item.status}")

    payload = payload or ConsumeRequest()
    amount = payload.amount if payload.amount is not None else item.quantity_remaining
    item.quantity_remaining = max(0.0, round(item.quantity_remaining - amount, 3))

    if item.quantity_remaining <= 0:
        item.status = STATUS_DISCARDED if payload.discard else STATUS_CONSUMED
        item.consumed_at = datetime.now(timezone.utc)

    db.commit()
    db.refresh(item)
    return InventoryItemOut.model_validate(item)


@router.delete("/{item_id}", status_code=204)
def delete_inventory_item(
    item_id: int,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    item = _get_owned_item(db, user, item_id)
    db.delete(item)
    db.commit()
