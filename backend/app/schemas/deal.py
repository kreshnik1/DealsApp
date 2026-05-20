from datetime import datetime

from pydantic import BaseModel


class DealOut(BaseModel):
    id: int
    chain: str
    store_id: int
    store_name: str | None = None
    name: str
    brand: str | None
    description: str | None
    category: str | None
    image_url: str | None
    original_price: float | None
    deal_price: float | None
    price_label: str | None
    comparison_price: str | None
    valid_from: datetime | None
    valid_to: datetime | None
    scraped_at: datetime

    model_config = {"from_attributes": True}
