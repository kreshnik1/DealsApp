"""add auth identities and household tables

Revision ID: 20260613_0003
Revises: 20260612_0003
Create Date: 2026-06-13 12:00:00
"""

from alembic import op
import sqlalchemy as sa


revision = "20260613_0003"
down_revision = "20260612_0003"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column("users", sa.Column("last_login_at", sa.DateTime(), nullable=True))
    op.alter_column("users", "username", existing_type=sa.String(length=50), nullable=True)
    op.alter_column("users", "email", existing_type=sa.String(length=255), nullable=True)
    op.alter_column("users", "hashed_password", existing_type=sa.String(length=255), nullable=True)

    op.create_table(
        "auth_identities",
        sa.Column("id", sa.Uuid(), nullable=False, server_default=sa.text("gen_random_uuid()")),
        sa.Column("user_id", sa.Integer(), nullable=False),
        sa.Column("provider", sa.String(length=50), nullable=False),
        sa.Column("provider_user_id", sa.String(length=255), nullable=False),
        sa.Column("email", sa.String(length=255), nullable=True),
        sa.Column("email_verified", sa.Boolean(), nullable=False, server_default=sa.false()),
        sa.Column("created_at", sa.DateTime(), nullable=False, server_default=sa.func.now()),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], name="fk_auth_identities_user_id"),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("provider", "provider_user_id", name="uq_auth_identities_provider_user"),
    )
    op.create_index(op.f("ix_auth_identities_user_id"), "auth_identities", ["user_id"])
    op.create_index(op.f("ix_auth_identities_provider"), "auth_identities", ["provider"])

    op.create_table(
        "households",
        sa.Column("id", sa.Uuid(), nullable=False, server_default=sa.text("gen_random_uuid()")),
        sa.Column("name", sa.String(length=120), nullable=False),
        sa.Column("created_by_user_id", sa.Integer(), nullable=False),
        sa.Column("created_at", sa.DateTime(), nullable=False, server_default=sa.func.now()),
        sa.ForeignKeyConstraint(["created_by_user_id"], ["users.id"], name="fk_households_created_by_user_id"),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(op.f("ix_households_created_by_user_id"), "households", ["created_by_user_id"])

    op.create_table(
        "household_members",
        sa.Column("id", sa.Uuid(), nullable=False, server_default=sa.text("gen_random_uuid()")),
        sa.Column("household_id", sa.Uuid(), nullable=False),
        sa.Column("user_id", sa.Integer(), nullable=False),
        sa.Column("role", sa.String(length=20), nullable=False),
        sa.Column("joined_at", sa.DateTime(), nullable=False, server_default=sa.func.now()),
        sa.CheckConstraint("role IN ('owner', 'admin', 'member')", name="ck_household_members_role"),
        sa.ForeignKeyConstraint(["household_id"], ["households.id"], name="fk_household_members_household_id"),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], name="fk_household_members_user_id"),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("household_id", "user_id", name="uq_household_members_household_user"),
    )
    op.create_index(op.f("ix_household_members_household_id"), "household_members", ["household_id"])
    op.create_index(op.f("ix_household_members_user_id"), "household_members", ["user_id"])

    op.create_table(
        "household_invites",
        sa.Column("id", sa.Uuid(), nullable=False, server_default=sa.text("gen_random_uuid()")),
        sa.Column("household_id", sa.Uuid(), nullable=False),
        sa.Column("code", sa.String(length=32), nullable=False),
        sa.Column("created_by_user_id", sa.Integer(), nullable=False),
        sa.Column("expires_at", sa.DateTime(), nullable=False),
        sa.Column("revoked_at", sa.DateTime(), nullable=True),
        sa.Column("max_uses", sa.Integer(), nullable=True),
        sa.Column("uses_count", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("created_at", sa.DateTime(), nullable=False, server_default=sa.func.now()),
        sa.ForeignKeyConstraint(["created_by_user_id"], ["users.id"], name="fk_household_invites_created_by_user_id"),
        sa.ForeignKeyConstraint(["household_id"], ["households.id"], name="fk_household_invites_household_id"),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("code"),
    )
    op.create_index(op.f("ix_household_invites_household_id"), "household_invites", ["household_id"])
    op.create_index(op.f("ix_household_invites_code"), "household_invites", ["code"], unique=True)
    op.create_index(op.f("ix_household_invites_created_by_user_id"), "household_invites", ["created_by_user_id"])


def downgrade() -> None:
    op.drop_index(op.f("ix_household_invites_created_by_user_id"), table_name="household_invites")
    op.drop_index(op.f("ix_household_invites_code"), table_name="household_invites")
    op.drop_index(op.f("ix_household_invites_household_id"), table_name="household_invites")
    op.drop_table("household_invites")

    op.drop_index(op.f("ix_household_members_user_id"), table_name="household_members")
    op.drop_index(op.f("ix_household_members_household_id"), table_name="household_members")
    op.drop_table("household_members")

    op.drop_index(op.f("ix_households_created_by_user_id"), table_name="households")
    op.drop_table("households")

    op.drop_index(op.f("ix_auth_identities_provider"), table_name="auth_identities")
    op.drop_index(op.f("ix_auth_identities_user_id"), table_name="auth_identities")
    op.drop_table("auth_identities")

    op.alter_column("users", "hashed_password", existing_type=sa.String(length=255), nullable=False)
    op.alter_column("users", "email", existing_type=sa.String(length=255), nullable=False)
    op.alter_column("users", "username", existing_type=sa.String(length=50), nullable=False)
    op.drop_column("users", "last_login_at")
