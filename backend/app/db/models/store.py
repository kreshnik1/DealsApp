from sqlalchemy import ForeignKey, Integer, String
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base


class Store(Base):
    __tablename__ = "stores"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    company_id: Mapped[int] = mapped_column(Integer, ForeignKey("companies.id"), nullable=False)
    name: Mapped[str] = mapped_column(String(255), nullable=False)
    chain: Mapped[str] = mapped_column(String(50), nullable=False)
    external_id: Mapped[str | None] = mapped_column(String(100), unique=True)
    store_url: Mapped[str | None] = mapped_column(String(1000))
    weekly_deals_url: Mapped[str | None] = mapped_column(String(1000))

    company: Mapped["Company"] = relationship("Company", back_populates="stores")
    deals: Mapped[list["Deal"]] = relationship("Deal", back_populates="store")
    products: Mapped[list["Product"]] = relationship("Product", back_populates="store")
