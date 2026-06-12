from datetime import datetime, timezone

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy import case, func
from sqlalchemy.orm import Session, joinedload

from app.auth import get_current_user
from app.db.models import Deal, InventoryItem, ShoppingList, ShoppingListItem
from app.db.models.user import User
from app.db.session import get_db
from app.schemas.inventory import InventoryItemOut
from app.schemas.shopping import (
    CheckoutRequest,
    PurchaseItemRequest,
    ShoppingListCreate,
    ShoppingListDetailOut,
    ShoppingListItemCreate,
    ShoppingListItemOut,
    ShoppingListItemUpdate,
    ShoppingListOut,
    ShoppingListUpdate,
)

router = APIRouter(prefix="/shopping-lists", tags=["shopping-lists"])


def _get_owned_list(db: Session, user: User, list_id: int, with_items: bool = False) -> ShoppingList:
    q = db.query(ShoppingList).filter(ShoppingList.id == list_id, ShoppingList.user_id == user.id)
    if with_items:
        q = q.options(joinedload(ShoppingList.items))
    shopping_list = q.first()
    if shopping_list is None:
        raise HTTPException(status_code=404, detail=f"Shopping list {list_id} not found")
    return shopping_list


def _get_owned_item(db: Session, user: User, list_id: int, item_id: int) -> ShoppingListItem:
    _get_owned_list(db, user, list_id)
    item = db.query(ShoppingListItem).filter(
        ShoppingListItem.id == item_id,
        ShoppingListItem.shopping_list_id == list_id,
    ).first()
    if item is None:
        raise HTTPException(status_code=404, detail=f"Item {item_id} not found in list {list_id}")
    return item


def _list_to_schema(shopping_list: ShoppingList, counts: tuple[int, int] | None = None) -> ShoppingListOut:
    out = ShoppingListOut.model_validate(shopping_list)
    if counts is not None:
        out.item_count, out.checked_count = counts
    else:
        out.item_count = len(shopping_list.items)
        out.checked_count = sum(1 for i in shopping_list.items if i.is_checked)
    return out


@router.get("/", response_model=list[ShoppingListOut])
def list_shopping_lists(
    include_archived: bool = Query(False),
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    q = db.query(ShoppingList).filter(ShoppingList.user_id == user.id)
    if not include_archived:
        q = q.filter(ShoppingList.is_archived.is_(False))
    lists = q.order_by(ShoppingList.created_at).all()

    counts = {
        lid: (total, checked)
        for lid, total, checked in db.query(
            ShoppingListItem.shopping_list_id,
            func.count(ShoppingListItem.id),
            func.sum(case((ShoppingListItem.is_checked.is_(True), 1), else_=0)),
        ).filter(
            ShoppingListItem.shopping_list_id.in_([sl.id for sl in lists])
        ).group_by(ShoppingListItem.shopping_list_id).all()
    } if lists else {}

    result = []
    for sl in lists:
        total, checked = counts.get(sl.id, (0, 0))
        result.append(_list_to_schema(sl, (total, int(checked or 0))))
    return result


@router.post("/", response_model=ShoppingListDetailOut, status_code=201)
def create_shopping_list(
    payload: ShoppingListCreate,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    shopping_list = ShoppingList(user_id=user.id, name=payload.name)
    db.add(shopping_list)
    db.commit()
    db.refresh(shopping_list)
    return ShoppingListDetailOut.model_validate(shopping_list)


@router.get("/{list_id}", response_model=ShoppingListDetailOut)
def get_shopping_list(
    list_id: int,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    shopping_list = _get_owned_list(db, user, list_id, with_items=True)
    out = ShoppingListDetailOut.model_validate(shopping_list)
    out.item_count = len(shopping_list.items)
    out.checked_count = sum(1 for i in shopping_list.items if i.is_checked)
    return out


@router.patch("/{list_id}", response_model=ShoppingListOut)
def update_shopping_list(
    list_id: int,
    payload: ShoppingListUpdate,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    shopping_list = _get_owned_list(db, user, list_id, with_items=True)
    if payload.name is not None:
        shopping_list.name = payload.name
    if payload.is_archived is not None:
        shopping_list.is_archived = payload.is_archived
    db.commit()
    db.refresh(shopping_list)
    return _list_to_schema(shopping_list)


@router.delete("/{list_id}", status_code=204)
def delete_shopping_list(
    list_id: int,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    shopping_list = _get_owned_list(db, user, list_id)
    db.delete(shopping_list)
    db.commit()


# ---------------------------------------------------------------------------
# Items
# ---------------------------------------------------------------------------

@router.post("/{list_id}/items", response_model=ShoppingListItemOut, status_code=201)
def add_item(
    list_id: int,
    payload: ShoppingListItemCreate,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    _get_owned_list(db, user, list_id)

    next_position = (
        db.query(func.coalesce(func.max(ShoppingListItem.position), -1))
        .filter(ShoppingListItem.shopping_list_id == list_id)
        .scalar()
    ) + 1

    item = ShoppingListItem(
        shopping_list_id=list_id,
        quantity=payload.quantity,
        unit=payload.unit,
        note=payload.note,
        position=next_position,
    )

    if payload.deal_id is not None:
        deal = db.query(Deal).filter(Deal.id == payload.deal_id).first()
        if deal is None:
            raise HTTPException(status_code=404, detail=f"Deal {payload.deal_id} not found")
        # Snapshot the deal: deal rows rotate weekly, the list item must
        # keep showing what the user added.
        item.source = "deal"
        item.deal_id = deal.id
        item.store_id = deal.store_id
        item.name = payload.name or deal.name
        item.brand = payload.brand or deal.brand
        item.size = payload.size or deal.size
        item.image_url = deal.image_url
        item.chain = deal.chain
        item.deal_price = deal.deal_price
        item.original_price = deal.original_price
        item.deal_text = deal.deal_text
        item.is_membership_price = bool(deal.is_membership_price)
        item.deal_valid_to = deal.valid_to
    else:
        item.source = "manual"
        item.name = payload.name.strip()
        item.brand = payload.brand
        item.size = payload.size

    db.add(item)
    db.commit()
    db.refresh(item)
    return ShoppingListItemOut.model_validate(item)


@router.patch("/{list_id}/items/{item_id}", response_model=ShoppingListItemOut)
def update_item(
    list_id: int,
    item_id: int,
    payload: ShoppingListItemUpdate,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    item = _get_owned_item(db, user, list_id, item_id)
    for field in ("quantity", "unit", "note", "position"):
        value = getattr(payload, field)
        if value is not None:
            setattr(item, field, value)
    if payload.is_checked is not None:
        item.is_checked = payload.is_checked
    db.commit()
    db.refresh(item)
    return ShoppingListItemOut.model_validate(item)


@router.delete("/{list_id}/items/{item_id}", status_code=204)
def delete_item(
    list_id: int,
    item_id: int,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    item = _get_owned_item(db, user, list_id, item_id)
    db.delete(item)
    db.commit()


# ---------------------------------------------------------------------------
# Purchase: list item -> inventory
# ---------------------------------------------------------------------------

def _purchase_item(
    db: Session,
    user: User,
    item: ShoppingListItem,
    quantity: float | None = None,
    purchase_price: float | None = None,
    total_price: float | None = None,
    expiry_date=None,
    purchased_at: datetime | None = None,
) -> InventoryItem:
    qty = quantity if quantity is not None else item.quantity
    price = purchase_price if purchase_price is not None else item.deal_price
    total = total_price
    if total is None and price is not None:
        total = round(price * qty, 2)
    when = purchased_at or datetime.now(timezone.utc)

    inventory_item = InventoryItem(
        user_id=user.id,
        shopping_list_item_id=item.id,
        deal_id=item.deal_id,
        store_id=item.store_id,
        name=item.name,
        brand=item.brand,
        size=item.size,
        image_url=item.image_url,
        chain=item.chain,
        quantity=qty,
        quantity_remaining=qty,
        unit=item.unit,
        purchase_price=price,
        total_price=total,
        was_deal=item.source == "deal",
        deal_text=item.deal_text,
        purchased_at=when,
        expiry_date=expiry_date,
        note=item.note,
    )
    db.add(inventory_item)

    item.purchased_at = when
    item.is_checked = True
    return inventory_item


@router.post("/{list_id}/items/{item_id}/purchase", response_model=InventoryItemOut, status_code=201)
def purchase_item(
    list_id: int,
    item_id: int,
    payload: PurchaseItemRequest | None = None,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    item = _get_owned_item(db, user, list_id, item_id)
    if item.purchased_at is not None:
        raise HTTPException(status_code=409, detail="Item already purchased")

    payload = payload or PurchaseItemRequest()
    inventory_item = _purchase_item(
        db, user, item,
        quantity=payload.quantity,
        purchase_price=payload.purchase_price,
        total_price=payload.total_price,
        expiry_date=payload.expiry_date,
        purchased_at=payload.purchased_at,
    )
    db.commit()
    db.refresh(inventory_item)
    return InventoryItemOut.model_validate(inventory_item)


@router.post("/{list_id}/checkout", response_model=list[InventoryItemOut])
def checkout(
    list_id: int,
    payload: CheckoutRequest | None = None,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    """Convert all (checked) unpurchased items of the list into inventory."""
    _get_owned_list(db, user, list_id)
    payload = payload or CheckoutRequest()

    q = db.query(ShoppingListItem).filter(
        ShoppingListItem.shopping_list_id == list_id,
        ShoppingListItem.purchased_at.is_(None),
    )
    if payload.only_checked:
        q = q.filter(ShoppingListItem.is_checked.is_(True))
    items = q.order_by(ShoppingListItem.position).all()

    if not items:
        raise HTTPException(status_code=404, detail="No items to purchase")

    when = payload.purchased_at or datetime.now(timezone.utc)
    inventory_items = [_purchase_item(db, user, item, purchased_at=when) for item in items]
    db.commit()
    for inv in inventory_items:
        db.refresh(inv)
    return [InventoryItemOut.model_validate(inv) for inv in inventory_items]
