from datetime import date, datetime, timezone

from sqlalchemy import Boolean, Date, Float, ForeignKey, String, Text
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base

STATUS_IN_STOCK = "in_stock"
STATUS_CONSUMED = "consumed"
STATUS_DISCARDED = "discarded"
INVENTORY_STATUSES = (STATUS_IN_STOCK, STATUS_CONSUMED, STATUS_DISCARDED)


class InventoryItem(Base):
    __tablename__ = "inventory_items"

    id: Mapped[int] = mapped_column(primary_key=True, index=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)

    # Provenance (soft links; snapshots below survive source deletion)
    shopping_list_item_id: Mapped[int | None] = mapped_column(
        ForeignKey("shopping_list_items.id", ondelete="SET NULL")
    )
    deal_id: Mapped[int | None] = mapped_column(ForeignKey("deals.id", ondelete="SET NULL"))
    store_id: Mapped[int | None] = mapped_column(ForeignKey("stores.id", ondelete="SET NULL"))

    name: Mapped[str] = mapped_column(String(500))
    brand: Mapped[str | None] = mapped_column(String(255))
    size: Mapped[str | None] = mapped_column(String(100))
    image_url: Mapped[str | None] = mapped_column(String(1000))
    chain: Mapped[str | None] = mapped_column(String(50))

    quantity: Mapped[float] = mapped_column(Float, default=1)
    quantity_remaining: Mapped[float] = mapped_column(Float, default=1)
    unit: Mapped[str | None] = mapped_column(String(20))

    # Purchase facts
    purchase_price: Mapped[float | None] = mapped_column(Float)  # per unit, as paid
    total_price: Mapped[float | None] = mapped_column(Float)
    currency: Mapped[str] = mapped_column(String(3), default="SEK")
    was_deal: Mapped[bool] = mapped_column(Boolean, default=False)
    deal_text: Mapped[str | None] = mapped_column(String(255))
    purchased_at: Mapped[datetime] = mapped_column(
        default=lambda: datetime.now(timezone.utc), index=True
    )

    # Lifecycle
    status: Mapped[str] = mapped_column(String(20), default=STATUS_IN_STOCK, index=True)
    expiry_date: Mapped[date | None] = mapped_column(Date, index=True)
    consumed_at: Mapped[datetime | None] = mapped_column()
    note: Mapped[str | None] = mapped_column(Text)

    created_at: Mapped[datetime] = mapped_column(default=lambda: datetime.now(timezone.utc))
    updated_at: Mapped[datetime] = mapped_column(
        default=lambda: datetime.now(timezone.utc),
        onupdate=lambda: datetime.now(timezone.utc),
    )

    user: Mapped["User"] = relationship()
    deal: Mapped["Deal | None"] = relationship()
    store: Mapped["Store | None"] = relationship()
