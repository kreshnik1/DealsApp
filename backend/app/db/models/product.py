from datetime import datetime, timezone

from sqlalchemy import Boolean, ForeignKey, String, Text
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base


class Product(Base):
    __tablename__ = "products"

    id: Mapped[int] = mapped_column(primary_key=True, index=True)
    store_id: Mapped[int] = mapped_column(ForeignKey("stores.id"), index=True)
    external_id: Mapped[str | None] = mapped_column(String(200), unique=True)
    name: Mapped[str] = mapped_column(String(500))
    brand: Mapped[str | None] = mapped_column(String(255))
    size: Mapped[str | None] = mapped_column(String(100))
    description: Mapped[str | None] = mapped_column(Text)
    image_url: Mapped[str | None] = mapped_column(String(1000))
    price_label: Mapped[str | None] = mapped_column(String(200))
    is_membership_price: Mapped[bool] = mapped_column(Boolean, default=False)
    deal_text: Mapped[str | None] = mapped_column(String(255))
    comparison_price: Mapped[str | None] = mapped_column(String(255))
    extra_info: Mapped[str | None] = mapped_column(Text)
    source_url: Mapped[str | None] = mapped_column(String(1000))
    scraped_at: Mapped[datetime] = mapped_column(default=lambda: datetime.now(timezone.utc))

    store: Mapped["Store"] = relationship(back_populates="products")
