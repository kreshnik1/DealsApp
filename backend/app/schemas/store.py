from pydantic import BaseModel


class StoreOut(BaseModel):
    id: int
    company_id: int
    name: str
    chain: str
    external_id: str | None
    store_url: str | None = None
    weekly_deals_url: str | None = None

    model_config = {"from_attributes": True}


class CoopStoreLinkOut(BaseModel):
    name: str
    concept: str
    slug: str
    store_url: str
    weekly_deals_url: str
