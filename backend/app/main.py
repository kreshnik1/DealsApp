from fastapi import FastAPI

from app.db.models import Company, Deal, Product, Store  # noqa: F401 — ensure models are registered
from app.routers import deals, scrape, stores

app = FastAPI(title="DealsApp")

app.include_router(deals.router)
app.include_router(stores.router)
app.include_router(scrape.router)
