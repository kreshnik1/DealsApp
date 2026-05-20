from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy import func
from sqlalchemy.orm import Session

from app.db.models import Company, Store
from app.db.session import get_db
from app.schemas.store import CoopStoreLinkOut
from app.scrapers import coop, willys

router = APIRouter(prefix="/scrape", tags=["scrape"])


def _get_company_by_name(db: Session, company_name: str) -> Company:
    """Look up a company by its slug (case-insensitive). Raises 404 if missing."""
    company = (
        db.query(Company)
        .filter(func.lower(Company.slug) == company_name.lower())
        .first()
    )
    if company is None:
        raise HTTPException(
            status_code=404,
            detail=f"Company '{company_name}' not found",
        )
    return company


@router.get("/coop/stores")
def scrape_coop_store_links(
    save: bool = Query(True, description="Save Coop company and stores into the database"),
    db: Session = Depends(get_db),
):
    if save:
        created = coop.save_store_links(db)
        total = (
            db.query(func.count(Store.id))
            .join(Company, Store.company_id == Company.id)
            .filter(Company.slug == "coop")
            .scalar()
        )
        return {"company": "Coop", "stores_created": created, "total_stores": total}

    stores = coop.discover_store_links()
    return [CoopStoreLinkOut.model_validate(store, from_attributes=True) for store in stores]


@router.post("/coop/stores/save")
def save_coop_stores(db: Session = Depends(get_db)):
    created = coop.save_store_links(db)
    total = (
        db.query(func.count(Store.id))
        .join(Company, Store.company_id == Company.id)
        .filter(Company.slug == "coop")
        .scalar()
    )
    return {"company": "Coop", "stores_created": created, "total_stores": total}


@router.post("/coop/products/first-store")
def scrape_first_coop_store_products(db: Session = Depends(get_db)):
    return coop.scrape_first_store_products(db)


@router.get("/{company_name}/deals")
def scrape_company_products(company_name: str, db: Session = Depends(get_db)):
    company = _get_company_by_name(db, company_name)
    return coop.scrape_company_store_products(db, company.id)


@router.get("/{company_name}/{store_id}/deals")
def scrape_store_products(company_name: str, store_id: int, db: Session = Depends(get_db)):
    company = _get_company_by_name(db, company_name)
    return coop.scrape_store_products(db, company.id, store_id)


@router.get("/willys")
def scrape_willys(
    lat: float = Query(..., description="Latitude"),
    lon: float = Query(..., description="Longitude"),
    db: Session = Depends(get_db),
):
    count = willys.scrape(db, lat=lat, lon=lon)
    return {"chain": "Willys", "deals_saved": count}
