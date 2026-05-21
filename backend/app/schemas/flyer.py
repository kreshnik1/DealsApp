from datetime import datetime

from pydantic import BaseModel


class FlyerOut(BaseModel):
    id: int
    store_id: int
    url: str
    pdf_path: str | None = None
    file_size: int | None = None
    week_number: int | None = None
    valid_from: datetime | None = None
    valid_to: datetime | None = None
    scraped_at: datetime

    model_config = {"from_attributes": True}
