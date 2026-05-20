from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session, joinedload

from app.db.models import Store
from app.db.session import get_db
from app.dependencies import get_company_by_slug
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
