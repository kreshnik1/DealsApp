from datetime import datetime

from pydantic import BaseModel


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
    opening_hours: str | None = None
    special_hours: str | None = None
    scraped_at: datetime
    updated_at: datetime

    model_config = {"from_attributes": True}


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
