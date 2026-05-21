from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy import func
from sqlalchemy.orm import Session

from app.auth import get_admin_user, get_current_user
from app.db.models import Company, Store
from app.db.models.user import User
from app.db.session import get_db
from app.dependencies import get_company_by_slug
from app.schemas.store import CoopStoreLinkOut
from app.scrapers import coop, ica, lidl, willys

router = APIRouter(prefix="/scrape", tags=["scrape"])

SCRAPER_REGISTRY = {
    "coop": coop,
    "ica": ica,
    "lidl": lidl,
}


@router.get("/coop/stores")
def scrape_coop_store_links(
    save: bool = Query(True, description="Persist Coop stores into the database"),
    db: Session = Depends(get_db),
    _admin: User = Depends(get_admin_user),
):
    if not save:
        stores = coop.discover_store_links()
        return [CoopStoreLinkOut.model_validate(s, from_attributes=True) for s in stores]

    created = coop.save_store_links(db)
    total = (
        db.query(func.count(Store.id))
        .join(Company)
        .filter(Company.slug == "coop")
        .scalar()
    )
    return {"company": "Coop", "stores_created": created, "total_stores": total}


@router.get("/ica/stores")
def scrape_ica_store_links(
    save: bool = Query(True, description="Persist ICA stores into the database"),
    db: Session = Depends(get_db),
    _admin: User = Depends(get_admin_user),
):
    if not save:
        stores = ica.discover_store_links()
        return [{"name": s.name, "chain": s.chain, "store_id": s.store_id, "store_url": s.store_url} for s in stores]

    created = ica.save_store_links(db)
    total = (
        db.query(func.count(Store.id))
        .join(Company)
        .filter(Company.slug == "ica")
        .scalar()
    )
    return {"company": "ICA", "stores_created": created, "total_stores": total}


@router.get("/lidl/stores")
def scrape_lidl_store_links(
    save: bool = Query(True, description="Persist Lidl stores into the database"),
    db: Session = Depends(get_db),
    _admin: User = Depends(get_admin_user),
):
    if not save:
        stores = lidl.discover_store_links()
        return [{"name": s["name"], "chain": s["chain"], "store_url": s["store_url"]} for s in stores]

    created = lidl.save_store_links(db)
    total = (
        db.query(func.count(Store.id))
        .join(Company)
        .filter(Company.slug == "lidl")
        .scalar()
    )
    return {"company": "Lidl", "stores_created": created, "total_stores": total}


@router.get("/{company_slug}/store-info")
def scrape_store_info(
    company_slug: str,
    limit: int | None = Query(None, description="Max number of stores to scrape, or all if omitted"),
    mode: str = Query("new", description="'new' = only stores without details, 'update' = re-scrape all and update changed"),
    db: Session = Depends(get_db),
    _admin: User = Depends(get_admin_user),
):
    company = get_company_by_slug(db, company_slug)
    scraper = SCRAPER_REGISTRY.get(company_slug.lower())
    if scraper is None:
        raise HTTPException(status_code=400, detail=f"No scraper available for '{company_slug}'")
    try:
        return scraper.scrape_store_info(db, company.id, mode=mode, limit=limit)
    except ValueError as e:
        raise HTTPException(status_code=404, detail=str(e))


@router.post("/coop/deals/first-store")
def scrape_first_coop_store_deals(
    db: Session = Depends(get_db),
    _admin: User = Depends(get_admin_user),
):
    try:
        return coop.scrape_first_store_deals(db)
    except ValueError as e:
        raise HTTPException(status_code=404, detail=str(e))


@router.get("/{company_slug}/{store_id}/store-info")
def scrape_single_store_info(
    company_slug: str,
    store_id: int,
    mode: str = Query("new", description="'new' = only if no details exist, 'update' = re-scrape and update if changed"),
    db: Session = Depends(get_db),
    _user: User = Depends(get_current_user),
):
    company = get_company_by_slug(db, company_slug)
    scraper = SCRAPER_REGISTRY.get(company_slug.lower())
    if scraper is None:
        raise HTTPException(status_code=400, detail=f"No scraper available for '{company_slug}'")
    try:
        return scraper.scrape_store_info(db, company.id, store_id, mode)
    except ValueError as e:
        raise HTTPException(status_code=404, detail=str(e))


@router.get("/{company_slug}/deals")
def scrape_company_deals(
    company_slug: str,
    db: Session = Depends(get_db),
    _admin: User = Depends(get_admin_user),
):
    company = get_company_by_slug(db, company_slug)
    scraper = SCRAPER_REGISTRY.get(company_slug.lower())
    if scraper is None:
        raise HTTPException(status_code=400, detail=f"No scraper available for '{company_slug}'")
    try:
        return scraper.scrape_company_store_deals(db, company.id)
    except ValueError as e:
        raise HTTPException(status_code=404, detail=str(e))


@router.get("/{company_slug}/{store_id}/deals")
def scrape_store_deals(
    company_slug: str,
    store_id: int,
    db: Session = Depends(get_db),
    _user: User = Depends(get_current_user),
):
    company = get_company_by_slug(db, company_slug)
    scraper = SCRAPER_REGISTRY.get(company_slug.lower())
    if scraper is None:
        raise HTTPException(status_code=400, detail=f"No scraper available for '{company_slug}'")
    try:
        return scraper.scrape_store_deals(db, company.id, store_id)
    except ValueError as e:
        raise HTTPException(status_code=404, detail=str(e))


@router.get("/willys")
def scrape_willys(
    lat: float = Query(..., description="Latitude"),
    lon: float = Query(..., description="Longitude"),
    db: Session = Depends(get_db),
    _user: User = Depends(get_current_user),
):
    count = willys.scrape(db, lat=lat, lon=lon)
    return {"chain": "Willys", "deals_saved": count}
