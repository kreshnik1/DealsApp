from datetime import datetime, timezone

from sqlalchemy import BigInteger, ForeignKey, String
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base


class Flyer(Base):
    __tablename__ = "flyers"

    id: Mapped[int] = mapped_column(primary_key=True, index=True)
    store_id: Mapped[int] = mapped_column(ForeignKey("stores.id"), index=True)

    url: Mapped[str] = mapped_column(String(1000))
    pdf_path: Mapped[str | None] = mapped_column(String(1000))
    file_size: Mapped[int | None] = mapped_column(BigInteger)
    valid_from: Mapped[datetime | None] = mapped_column()
    valid_to: Mapped[datetime | None] = mapped_column()
    scraped_at: Mapped[datetime] = mapped_column(default=lambda: datetime.now(timezone.utc))

    store: Mapped["Store"] = relationship(back_populates="flyers")
