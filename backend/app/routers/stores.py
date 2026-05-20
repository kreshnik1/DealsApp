from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy import func
from sqlalchemy.orm import Session

from app.db.models import Company, Store
from app.db.session import get_db
from app.schemas.store import StoreOut

router = APIRouter(prefix="/stores", tags=["stores"])


def _get_company_by_name(db: Session, company_name: str) -> Company:
    """Look up a company by slug (case-insensitive). Raises 404 if missing."""
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


@router.get("/", response_model=list[StoreOut])
def list_stores(
    chain: str | None = Query(None, description="Optional Store.chain filter, e.g. 'STORA COOP'"),
    db: Session = Depends(get_db),
):
    q = db.query(Store)
    if chain:
        q = q.filter(Store.chain == chain.upper())
    return q.order_by(Store.chain, Store.name).all()


@router.get("/{company_name}", response_model=list[StoreOut])
def list_company_stores(
    company_name: str,
    chain: str | None = Query(None, description="Optional Store.chain filter within the company"),
    db: Session = Depends(get_db),
):
    company = _get_company_by_name(db, company_name)
    q = db.query(Store).filter(Store.company_id == company.id)
    if chain:
        q = q.filter(Store.chain == chain.upper())
    return q.order_by(Store.chain, Store.name).all()
