from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy import func
from sqlalchemy.orm import Session, joinedload

from app.db.models import Flyer, Store, StoreDetail
from app.db.session import get_db
from app.dependencies import NATIONAL_DEAL_COMPANY_SLUGS, get_company_by_slug
from app.schemas.flyer import FlyerOut
from app.schemas.store import StoreOut

router = APIRouter(prefix="/stores", tags=["stores"])


@router.get("/nearby", response_model=list[StoreOut])
def list_nearby_stores(
    latitude: float = Query(..., ge=-90, le=90),
    longitude: float = Query(..., ge=-180, le=180),
    limit: int = Query(20, ge=1, le=50),
    db: Session = Depends(get_db),
):
    origin_lat = func.radians(latitude)
    origin_lon = func.radians(longitude)
    store_lat = func.radians(StoreDetail.latitude)
    store_lon = func.radians(StoreDetail.longitude)

    # Keep the calculation in SQL so the API can order by distance without
    # introducing extra geo dependencies such as PostGIS.
    distance_km = (
        6371.0
        * 2
        * func.asin(
            func.sqrt(
                func.pow(func.sin((store_lat - origin_lat) / 2), 2)
                + func.cos(origin_lat)
                * func.cos(store_lat)
                * func.pow(func.sin((store_lon - origin_lon) / 2), 2)
            )
        )
    ).label("distance_km")

    rows = (
        db.query(Store, distance_km)
        .join(StoreDetail, Store.detail)
        .options(joinedload(Store.detail))
        .filter(StoreDetail.latitude.is_not(None), StoreDetail.longitude.is_not(None))
        .order_by(distance_km.asc(), Store.chain.asc(), Store.name.asc())
        .limit(limit)
        .all()
    )

    stores: list[Store] = []
    for store, distance in rows:
        setattr(store, "distance_km", float(distance) if distance is not None else None)
        stores.append(store)

    return stores


@router.get("/", response_model=list[StoreOut])
def list_stores(
    chain: str | None = Query(None, description="Filter by chain, e.g. 'STORA COOP'"),
    city: str | None = Query(None, description="Filter by city, e.g. 'Stockholm'"),
    db: Session = Depends(get_db),
):
    q = db.query(Store).options(joinedload(Store.detail))
    if chain:
        q = q.filter(Store.chain == chain.upper())
    if city:
        q = q.filter(Store.detail.has(func.lower(StoreDetail.city) == city.strip().lower()))
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
    city: str | None = Query(None, description="Filter by city within the company, e.g. 'Stockholm'"),
    limit: int | None = Query(None, ge=1, le=200, description="Limit the number of stores returned"),
    db: Session = Depends(get_db),
):
    company = get_company_by_slug(db, company_slug)
    q = db.query(Store).options(joinedload(Store.detail)).filter(Store.company_id == company.id)
    if chain:
        q = q.filter(Store.chain == chain.upper())
    if city:
        q = q.filter(Store.detail.has(func.lower(StoreDetail.city) == city.strip().lower()))
    q = q.order_by(Store.chain, Store.name)
    if limit is not None:
        q = q.limit(limit)
    return q.all()


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

    q = db.query(Flyer)
    if company.slug in NATIONAL_DEAL_COMPANY_SLUGS:
        q = q.join(Store).filter(Store.company_id == company.id)
    else:
        q = q.filter(Flyer.store_id == store_id)

    flyers = (
        q.order_by(Flyer.scraped_at.desc())
        .offset(offset)
        .limit(limit)
        .all()
    )
    return flyers
