"""add roles and users tables with admin seed

Revision ID: 20260520_0002
Revises: 20260403_0001
Create Date: 2026-05-20 21:00:00
"""

from alembic import op
import sqlalchemy as sa
from passlib.context import CryptContext


revision = "20260520_0002"
down_revision = "20260403_0001"
branch_labels = None
depends_on = None

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")


def upgrade() -> None:
    op.create_table(
        "roles",
        sa.Column("id", sa.Uuid(), nullable=False, server_default=sa.text("gen_random_uuid()")),
        sa.Column("name", sa.String(length=50), nullable=False),
        sa.Column("description", sa.String(length=255), nullable=True),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("name"),
    )

    op.execute("INSERT INTO roles (name, description) VALUES ('user', 'Regular user')")
    op.execute("INSERT INTO roles (name, description) VALUES ('admin', 'Administrator')")

    op.create_table(
        "users",
        sa.Column("id", sa.Integer(), nullable=False, autoincrement=True),
        sa.Column("username", sa.String(length=50), nullable=False),
        sa.Column("email", sa.String(length=255), nullable=False),
        sa.Column("hashed_password", sa.String(length=255), nullable=False),
        sa.Column("full_name", sa.String(length=255), nullable=True),
        sa.Column("role_id", sa.Uuid(), nullable=False),
        sa.Column("is_active", sa.Boolean(), nullable=False, server_default=sa.true()),
        sa.Column("created_at", sa.DateTime(), nullable=False, server_default=sa.func.now()),
        sa.ForeignKeyConstraint(["role_id"], ["roles.id"], name="fk_users_role_id"),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(op.f("ix_users_id"), "users", ["id"])
    op.create_index(op.f("ix_users_username"), "users", ["username"], unique=True)
    op.create_index(op.f("ix_users_email"), "users", ["email"], unique=True)
    op.create_index(op.f("ix_users_role_id"), "users", ["role_id"])

    hashed = pwd_context.hash("admin")
    op.execute(
        sa.text(
            "INSERT INTO users (username, email, hashed_password, full_name, role_id) "
            "VALUES ('admin', 'admin@dealsapp.com', :hashed, 'Administrator', "
            "(SELECT id FROM roles WHERE name = 'admin'))"
        ).bindparams(hashed=hashed)
    )


def downgrade() -> None:
    op.drop_index(op.f("ix_users_role_id"), table_name="users")
    op.drop_index(op.f("ix_users_email"), table_name="users")
    op.drop_index(op.f("ix_users_username"), table_name="users")
    op.drop_index(op.f("ix_users_id"), table_name="users")
    op.drop_table("users")
    op.drop_table("roles")
