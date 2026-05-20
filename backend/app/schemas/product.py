from datetime import datetime

from pydantic import BaseModel


class ProductOut(BaseModel):
    id: int
    store_id: int
    name: str
    brand: str | None
    size: str | None
    description: str | None
    image_url: str | None
    price_label: str | None
    is_membership_price: bool
    deal_text: str | None
    comparison_price: str | None
    extra_info: str | None
    scraped_at: datetime

    model_config = {"from_attributes": True}
