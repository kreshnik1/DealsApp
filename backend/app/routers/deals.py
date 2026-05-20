from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy import or_
from sqlalchemy.orm import Session, joinedload

from app.db.models import Company, Deal, Store
from app.db.session import get_db
from app.dependencies import get_company_by_slug
from app.schemas.deal import DealOut

router = APIRouter(prefix="/deals", tags=["deals"])


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
    limit: int = Query(50, le=200),
    offset: int = Query(0, ge=0),
    db: Session = Depends(get_db),
):
    company = get_company_by_slug(db, company_slug)
    store = db.query(Store).filter(Store.company_id == company.id, Store.id == store_id).first()
    if not store:
        raise HTTPException(status_code=404, detail=f"Store {store_id} not found for {company_slug}")

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
