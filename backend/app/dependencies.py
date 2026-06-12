from fastapi import HTTPException
from sqlalchemy import func
from sqlalchemy.orm import Session

from app.db.models import Company

# Companies whose deals/flyers are identical in every store. They are scraped
# once onto an anchor store; store-scoped endpoints serve them company-wide.
NATIONAL_DEAL_COMPANY_SLUGS = {"lidl"}


def get_company_by_slug(db: Session, slug: str) -> Company:
    company = (
        db.query(Company)
        .filter(func.lower(Company.slug) == slug.lower())
        .first()
    )
    if company is None:
        raise HTTPException(status_code=404, detail=f"Company '{slug}' not found")
    return company


def get_or_create_company(db: Session, name: str, slug: str) -> Company:
    company = db.query(Company).filter_by(slug=slug).first()
    if company is None:
        company = Company(name=name, slug=slug)
        db.add(company)
        db.flush()
    return company
