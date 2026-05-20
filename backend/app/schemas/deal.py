from datetime import datetime

from pydantic import BaseModel


class DealOut(BaseModel):
    id: int
    chain: str
    store_id: int
    external_id: str | None = None
    name: str
    brand: str | None = None
    size: str | None = None
    description: str | None = None
    category: str | None = None
    image_url: str | None = None
    original_price: float | None = None
    deal_price: float | None = None
    deal_text: str | None = None
    price_label: str | None = None
    is_membership_price: bool = False
    comparison_price: str | None = None
    extra_info: str | None = None
    valid_from: datetime | None = None
    valid_to: datetime | None = None
    scraped_at: datetime
    source_url: str | None = None

    model_config = {"from_attributes": True}
