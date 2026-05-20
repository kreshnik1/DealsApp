import logging

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.config import settings
from app.db.models import Company, Deal, Flyer, Product, Role, Store, StoreDetail, User  # noqa: F401
from app.routers import auth, deals, scrape, stores

logging.basicConfig(level=logging.INFO, format="%(levelname)-5s %(name)s — %(message)s")

app = FastAPI(title="DealsApp", version="1.0.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.allowed_origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(auth.router)
app.include_router(deals.router)
app.include_router(stores.router)
app.include_router(scrape.router)


@app.get("/health")
def health_check():
    return {"status": "ok"}
