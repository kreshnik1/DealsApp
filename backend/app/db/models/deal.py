from datetime import datetime, timezone

from sqlalchemy import Float, ForeignKey, String, Text
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base


class Deal(Base):
    __tablename__ = "deals"

    id: Mapped[int] = mapped_column(primary_key=True, index=True)
    store_id: Mapped[int] = mapped_column(ForeignKey("stores.id"), index=True)
    chain: Mapped[str] = mapped_column(String(50), index=True)
    external_id: Mapped[str | None] = mapped_column(String(200))

    name: Mapped[str] = mapped_column(String(500))
    brand: Mapped[str | None] = mapped_column(String(255))
    description: Mapped[str | None] = mapped_column(Text)
    category: Mapped[str | None] = mapped_column(String(255))
    image_url: Mapped[str | None] = mapped_column(String(1000))

    original_price: Mapped[float | None] = mapped_column(Float)
    deal_price: Mapped[float | None] = mapped_column(Float)
    price_label: Mapped[str | None] = mapped_column(String(200))
    comparison_price: Mapped[str | None] = mapped_column(String(100))

    valid_from: Mapped[datetime | None] = mapped_column()
    valid_to: Mapped[datetime | None] = mapped_column()
    scraped_at: Mapped[datetime] = mapped_column(default=lambda: datetime.now(timezone.utc))
    source_url: Mapped[str | None] = mapped_column(String(1000))

    store: Mapped["Store"] = relationship(back_populates="deals")
