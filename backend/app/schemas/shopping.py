from datetime import date, datetime

from pydantic import BaseModel, Field, model_validator


class ShoppingListItemOut(BaseModel):
    id: int
    shopping_list_id: int
    deal_id: int | None = None
    store_id: int | None = None
    source: str
    name: str
    brand: str | None = None
    size: str | None = None
    image_url: str | None = None
    chain: str | None = None
    quantity: float
    unit: str | None = None
    note: str | None = None
    deal_price: float | None = None
    original_price: float | None = None
    deal_text: str | None = None
    is_membership_price: bool = False
    deal_valid_to: datetime | None = None
    is_checked: bool
    position: int
    purchased_at: datetime | None = None
    created_at: datetime
    updated_at: datetime

    model_config = {"from_attributes": True}


class ShoppingListOut(BaseModel):
    id: int
    name: str
    is_archived: bool
    created_at: datetime
    updated_at: datetime
    item_count: int = 0
    checked_count: int = 0

    model_config = {"from_attributes": True}


class ShoppingListDetailOut(ShoppingListOut):
    items: list[ShoppingListItemOut] = []


class ShoppingListCreate(BaseModel):
    name: str = Field("Min inköpslista", max_length=255)


class ShoppingListUpdate(BaseModel):
    name: str | None = Field(None, max_length=255)
    is_archived: bool | None = None


class ShoppingListItemCreate(BaseModel):
    """Add either a deal (deal_id) or a free-form product (name)."""

    deal_id: int | None = None
    name: str | None = Field(None, max_length=500)
    brand: str | None = Field(None, max_length=255)
    size: str | None = Field(None, max_length=100)
    quantity: float = Field(1, gt=0)
    unit: str | None = Field(None, max_length=20)
    note: str | None = None

    @model_validator(mode="after")
    def require_deal_or_name(self):
        if self.deal_id is None and not (self.name and self.name.strip()):
            raise ValueError("Provide either deal_id or name")
        return self


class ShoppingListItemUpdate(BaseModel):
    quantity: float | None = Field(None, gt=0)
    unit: str | None = Field(None, max_length=20)
    note: str | None = None
    is_checked: bool | None = None
    position: int | None = Field(None, ge=0)


class PurchaseItemRequest(BaseModel):
    """Optional overrides when converting a list item into inventory."""

    quantity: float | None = Field(None, gt=0)
    purchase_price: float | None = Field(None, ge=0)
    total_price: float | None = Field(None, ge=0)
    expiry_date: date | None = None
    purchased_at: datetime | None = None


class CheckoutRequest(BaseModel):
    only_checked: bool = True
    purchased_at: datetime | None = None
