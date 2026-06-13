import logging
from datetime import datetime, timedelta, timezone

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy import func, or_
from sqlalchemy.orm import Session, joinedload

from app.db.models import Company, Deal, Flyer, Store
from app.db.session import get_db
from app.dependencies import get_company_by_slug
from app.schemas.deal import DealOut

router = APIRouter(prefix="/deals", tags=["deals"])

log = logging.getLogger(__name__)

EMPTY_STORE_REFRESH_COOLDOWN = timedelta(hours=6)


@router.get("/", response_model=list[DealOut])
def list_deals(
    search: str | None = Query(None, description="Search by name or brand"),
    chain: str | None = Query(None, description="Filter by chain, e.g. 'COOP'"),
    category: str | None = Query(None, description="Filter by category"),
    store_ids: list[int] | None = Query(None, alias="store_id", description="Filter by one or more store IDs"),
    limit: int = Query(50, le=200),
    offset: int = Query(0, ge=0),
    db: Session = Depends(get_db),
):
    q = db.query(Deal).options(joinedload(Deal.store))

    if search:
        term = f"%{search}%"
        q = q.filter(or_(Deal.name.ilike(term), Deal.brand.ilike(term)))
    if chain:
        q = q.filter(Deal.chain == chain.upper())
    if category:
        q = q.filter(Deal.category.ilike(f"%{category}%"))
    if store_ids:
        q = q.filter(Deal.store_id.in_(store_ids))

    deals = q.order_by(Deal.scraped_at.desc()).offset(offset).limit(limit).all()
    return [_to_schema(d) for d in deals]


@router.get("/{company_slug}", response_model=list[DealOut])
def list_company_deals(
    company_slug: str,
    search: str | None = Query(None, description="Search by name or brand"),
    chain: str | None = Query(None, description="Filter by chain within the company"),
    category: str | None = Query(None, description="Filter by category"),
    limit: int = Query(50, le=200),
    offset: int = Query(0, ge=0),
    db: Session = Depends(get_db),
):
    company = get_company_by_slug(db, company_slug)
    q = (
        db.query(Deal)
        .join(Store)
        .options(joinedload(Deal.store))
        .filter(Store.company_id == company.id)
    )

    if search:
        term = f"%{search}%"
        q = q.filter(or_(Deal.name.ilike(term), Deal.brand.ilike(term)))
    if chain:
        q = q.filter(Deal.chain == chain.upper())
    if category:
        q = q.filter(Deal.category.ilike(f"%{category}%"))

    deals = q.order_by(Deal.scraped_at.desc()).offset(offset).limit(limit).all()
    return [_to_schema(d) for d in deals]


@router.get("/{company_slug}/{store_id}", response_model=list[DealOut])
def list_store_deals(
    company_slug: str,
    store_id: int,
    search: str | None = Query(None, description="Search by name or brand"),
    category: str | None = Query(None, description="Filter by category"),
    hydrate_if_empty: bool = Query(False, description="Scrape this store if no cached deals exist"),
    limit: int = Query(50, le=200),
    offset: int = Query(0, ge=0),
    db: Session = Depends(get_db),
):
    company = get_company_by_slug(db, company_slug)
    store = db.query(Store).filter(Store.company_id == company.id, Store.id == store_id).first()
    if not store:
        raise HTTPException(status_code=404, detail=f"Store {store_id} not found for {company_slug}")

    if hydrate_if_empty and _store_has_cached_deals(db, store_id) is False and _should_refresh_empty_store(db, store_id):
        _hydrate_store_deals(db, company_slug, company.id, store_id)

    q = db.query(Deal).options(joinedload(Deal.store)).filter(Deal.store_id == store_id)

    if search:
        term = f"%{search}%"
        q = q.filter(or_(Deal.name.ilike(term), Deal.brand.ilike(term)))
    if category:
        q = q.filter(Deal.category.ilike(f"%{category}%"))

    deals = q.order_by(Deal.scraped_at.desc()).offset(offset).limit(limit).all()
    return [_to_schema(d) for d in deals]


@router.get("/by-id/{deal_id}", response_model=DealOut)
def get_deal(deal_id: int, db: Session = Depends(get_db)):
    deal = (
        db.query(Deal)
        .options(joinedload(Deal.store))
        .filter(Deal.id == deal_id)
        .first()
    )
    if not deal:
        raise HTTPException(status_code=404, detail="Deal not found")
    return _to_schema(deal)


def _to_schema(deal: Deal) -> DealOut:
    return DealOut.model_validate(deal)


def _store_has_cached_deals(db: Session, store_id: int) -> bool:
    return db.query(Deal.id).filter(Deal.store_id == store_id).first() is not None


def _should_refresh_empty_store(db: Session, store_id: int) -> bool:
    latest_deal_scrape = db.query(func.max(Deal.scraped_at)).filter(Deal.store_id == store_id).scalar()
    latest_flyer_scrape = db.query(func.max(Flyer.scraped_at)).filter(Flyer.store_id == store_id).scalar()

    timestamps = [timestamp for timestamp in (latest_deal_scrape, latest_flyer_scrape) if timestamp is not None]
    if not timestamps:
        return True

    latest_scrape = max(timestamps)
    return latest_scrape <= datetime.now(timezone.utc) - EMPTY_STORE_REFRESH_COOLDOWN


def _hydrate_store_deals(db: Session, company_slug: str, company_id: int, store_id: int) -> None:
    scraper = _scraper_for_company(company_slug)
    if scraper is None:
        return

    try:
        scraper.scrape_store_deals(db, company_id, store_id)
    except ValueError as exc:
        db.rollback()
        log.warning("Store deal hydration skipped for %s/%s: %s", company_slug, store_id, exc)
    except Exception as exc:
        db.rollback()
        log.exception("Store deal hydration failed for %s/%s: %s", company_slug, store_id, exc)


def _scraper_for_company(company_slug: str):
    from app.scrapers import coop, ica, lidl

    return {
        "coop": coop,
        "ica": ica,
        "lidl": lidl,
    }.get(company_slug.lower())
