import json
from datetime import datetime

from pydantic import BaseModel, field_validator


class OpeningHoursEntry(BaseModel):
    days: list[str]
    open: str | None = None
    close: str | None = None


class StoreDetailOut(BaseModel):
    id: int
    store_id: int
    about_url: str | None = None
    address: str | None = None
    postal_code: str | None = None
    city: str | None = None
    phone: str | None = None
    google_maps_url: str | None = None
    latitude: float | None = None
    longitude: float | None = None
    opening_hours: list[OpeningHoursEntry] | None = None
    special_hours: list[OpeningHoursEntry] | None = None
    scraped_at: datetime
    updated_at: datetime

    model_config = {"from_attributes": True}

    @field_validator("opening_hours", "special_hours", mode="before")
    @classmethod
    def parse_json_hours(cls, v):
        if isinstance(v, str):
            return json.loads(v)
        return v


class StoreOut(BaseModel):
    id: int
    company_id: int
    name: str
    chain: str
    external_id: str | None
    store_url: str | None = None
    weekly_deals_url: str | None = None
    detail: StoreDetailOut | None = None

    model_config = {"from_attributes": True}


class CoopStoreLinkOut(BaseModel):
    name: str
    concept: str
    slug: str
    store_url: str
