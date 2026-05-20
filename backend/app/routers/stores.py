from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session, joinedload

from app.db.models import Flyer, Store
from app.db.session import get_db
from app.dependencies import get_company_by_slug
from app.schemas.flyer import FlyerOut
from app.schemas.store import StoreOut

router = APIRouter(prefix="/stores", tags=["stores"])


@router.get("/", response_model=list[StoreOut])
def list_stores(
    chain: str | None = Query(None, description="Filter by chain, e.g. 'STORA COOP'"),
    db: Session = Depends(get_db),
):
    q = db.query(Store).options(joinedload(Store.detail))
    if chain:
        q = q.filter(Store.chain == chain.upper())
    return q.order_by(Store.chain, Store.name).all()


@router.get("/flyers", response_model=list[FlyerOut])
def list_flyers_by_store_ids(
    store_ids: list[int] = Query(alias="store_id", description="One or more store IDs"),
    limit: int = Query(50, le=200),
    offset: int = Query(0, ge=0),
    db: Session = Depends(get_db),
):
    flyers = (
        db.query(Flyer)
        .filter(Flyer.store_id.in_(store_ids))
        .order_by(Flyer.scraped_at.desc())
        .offset(offset)
        .limit(limit)
        .all()
    )
    return flyers


@router.get("/{company_slug}", response_model=list[StoreOut])
def list_company_stores(
    company_slug: str,
    chain: str | None = Query(None, description="Filter by chain within the company"),
    db: Session = Depends(get_db),
):
    company = get_company_by_slug(db, company_slug)
    q = db.query(Store).options(joinedload(Store.detail)).filter(Store.company_id == company.id)
    if chain:
        q = q.filter(Store.chain == chain.upper())
    return q.order_by(Store.chain, Store.name).all()


@router.get("/{company_slug}/{store_id}/flyers", response_model=list[FlyerOut])
def list_store_flyers(
    company_slug: str,
    store_id: int,
    limit: int = Query(10, le=50),
    offset: int = Query(0, ge=0),
    db: Session = Depends(get_db),
):
    company = get_company_by_slug(db, company_slug)
    store = db.query(Store).filter(Store.company_id == company.id, Store.id == store_id).first()
    if not store:
        raise HTTPException(status_code=404, detail=f"Store {store_id} not found for {company_slug}")

    flyers = (
        db.query(Flyer)
        .filter(Flyer.store_id == store_id)
        .order_by(Flyer.scraped_at.desc())
        .offset(offset)
        .limit(limit)
        .all()
    )
    return flyers
