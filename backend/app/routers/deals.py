from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy import or_
from sqlalchemy.orm import Session

from app.db.models import Deal, Store
from app.db.session import get_db
from app.schemas.deal import DealOut

router = APIRouter(prefix="/deals", tags=["deals"])


def _to_schema(deal: Deal) -> DealOut:
    d = DealOut.model_validate(deal)
    d.store_name = deal.store.name if deal.store else None
    return d


@router.get("/", response_model=list[DealOut])
def list_deals(
    search: str | None = Query(None),
    chain: str | None = Query(None),
    category: str | None = Query(None),
    limit: int = Query(50, le=200),
    offset: int = Query(0),
    db: Session = Depends(get_db),
):
    q = db.query(Deal).join(Store)

    if search:
        term = f"%{search.lower()}%"
        q = q.filter(or_(Deal.name.ilike(term), Deal.brand.ilike(term)))
    if chain:
        q = q.filter(Deal.chain == chain.upper())
    if category:
        q = q.filter(Deal.category.ilike(f"%{category}%"))

    return [_to_schema(d) for d in q.order_by(Deal.deal_price).offset(offset).limit(limit).all()]


@router.get("/{deal_id}", response_model=DealOut)
def get_deal(deal_id: int, db: Session = Depends(get_db)):
    deal = db.query(Deal).join(Store).filter(Deal.id == deal_id).first()
    if not deal:
        raise HTTPException(status_code=404, detail="Deal not found")
    return _to_schema(deal)
