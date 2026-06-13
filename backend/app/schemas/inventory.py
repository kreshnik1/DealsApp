from datetime import date, datetime

from pydantic import BaseModel, Field, model_validator


class InventoryItemOut(BaseModel):
    id: int
    shopping_list_item_id: int | None = None
    deal_id: int | None = None
    store_id: int | None = None
    name: str
    brand: str | None = None
    size: str | None = None
    image_url: str | None = None
    chain: str | None = None
    quantity: float
    quantity_remaining: float
    unit: str | None = None
    purchase_price: float | None = None
    total_price: float | None = None
    currency: str
    was_deal: bool
    deal_text: str | None = None
    purchased_at: datetime
    status: str
    expiry_date: date | None = None
    consumed_at: datetime | None = None
    note: str | None = None
    created_at: datetime
    updated_at: datetime

    model_config = {"from_attributes": True}


class InventoryItemCreate(BaseModel):
    """Add directly to inventory: from a deal (deal_id) or free-form (name)."""

    deal_id: int | None = None
    name: str | None = Field(None, max_length=500)
    brand: str | None = Field(None, max_length=255)
    size: str | None = Field(None, max_length=100)
    quantity: float = Field(1, gt=0)
    unit: str | None = Field(None, max_length=20)
    purchase_price: float | None = Field(None, ge=0)
    total_price: float | None = Field(None, ge=0)
    purchased_at: datetime | None = None
    expiry_date: date | None = None
    note: str | None = None

    @model_validator(mode="after")
    def require_deal_or_name(self):
        if self.deal_id is None and not (self.name and self.name.strip()):
            raise ValueError("Provide either deal_id or name")
        return self


class InventoryItemUpdate(BaseModel):
    quantity_remaining: float | None = Field(None, ge=0)
    status: str | None = Field(None, pattern="^(in_stock|consumed|discarded)$")
    expiry_date: date | None = None
    note: str | None = None
    purchase_price: float | None = Field(None, ge=0)
    total_price: float | None = Field(None, ge=0)


class ConsumeRequest(BaseModel):
    amount: float | None = Field(None, gt=0, description="Amount consumed; omit to consume everything")
    discard: bool = False


class InventoryStatsOut(BaseModel):
    in_stock: int
    consumed: int
    discarded: int
    expiring_within_7_days: int
    spent_last_30_days: float
    currency: str = "SEK"
