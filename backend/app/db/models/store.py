from sqlalchemy import ForeignKey, String
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base


class Store(Base):
    __tablename__ = "stores"

    id: Mapped[int] = mapped_column(primary_key=True, index=True)
    company_id: Mapped[int] = mapped_column(ForeignKey("companies.id"), index=True)
    name: Mapped[str] = mapped_column(String(255))
    chain: Mapped[str] = mapped_column(String(50), index=True)
    external_id: Mapped[str | None] = mapped_column(String(100), unique=True)
    store_url: Mapped[str | None] = mapped_column(String(1000))
    weekly_deals_url: Mapped[str | None] = mapped_column(String(1000))

    company: Mapped["Company"] = relationship(back_populates="stores")
    deals: Mapped[list["Deal"]] = relationship(back_populates="store")
    products: Mapped[list["Product"]] = relationship(back_populates="store")
    flyers: Mapped[list["Flyer"]] = relationship(back_populates="store")
    detail: Mapped["StoreDetail | None"] = relationship(back_populates="store", uselist=False)
