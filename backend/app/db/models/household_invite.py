import uuid
from datetime import datetime, timezone

from sqlalchemy import ForeignKey, String, Uuid
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base


class HouseholdInvite(Base):
    __tablename__ = "household_invites"

    id: Mapped[uuid.UUID] = mapped_column(Uuid, primary_key=True, default=uuid.uuid4)
    household_id: Mapped[uuid.UUID] = mapped_column(Uuid, ForeignKey("households.id"), index=True)
    code: Mapped[str] = mapped_column(String(32), unique=True, index=True)
    created_by_user_id: Mapped[int] = mapped_column(ForeignKey("users.id"), index=True)
    expires_at: Mapped[datetime]
    revoked_at: Mapped[datetime | None]
    max_uses: Mapped[int | None]
    uses_count: Mapped[int] = mapped_column(default=0)
    created_at: Mapped[datetime] = mapped_column(default=lambda: datetime.now(timezone.utc))

    household: Mapped["Household"] = relationship(back_populates="invites")
    created_by: Mapped["User"] = relationship(back_populates="created_household_invites")
