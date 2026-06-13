"""add shopping lists and inventory tables

Revision ID: 20260612_0003
Revises: 20260520_0002
Create Date: 2026-06-12 19:00:00
"""

from alembic import op
import sqlalchemy as sa


revision = "20260612_0003"
down_revision = "20260520_0002"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "shopping_lists",
        sa.Column("id", sa.Integer(), nullable=False, autoincrement=True),
        sa.Column("user_id", sa.Integer(), nullable=False),
        sa.Column("name", sa.String(length=255), nullable=False, server_default="Min inköpslista"),
        sa.Column("is_archived", sa.Boolean(), nullable=False, server_default=sa.false()),
        sa.Column("created_at", sa.DateTime(), nullable=False, server_default=sa.func.now()),
        sa.Column("updated_at", sa.DateTime(), nullable=False, server_default=sa.func.now()),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], name="fk_shopping_lists_user_id", ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(op.f("ix_shopping_lists_id"), "shopping_lists", ["id"])
    op.create_index(op.f("ix_shopping_lists_user_id"), "shopping_lists", ["user_id"])

    op.create_table(
        "shopping_list_items",
        sa.Column("id", sa.Integer(), nullable=False, autoincrement=True),
        sa.Column("shopping_list_id", sa.Integer(), nullable=False),
        sa.Column("deal_id", sa.Integer(), nullable=True),
        sa.Column("store_id", sa.Integer(), nullable=True),
        sa.Column("source", sa.String(length=20), nullable=False, server_default="manual"),
        sa.Column("name", sa.String(length=500), nullable=False),
        sa.Column("brand", sa.String(length=255), nullable=True),
        sa.Column("size", sa.String(length=100), nullable=True),
        sa.Column("image_url", sa.String(length=1000), nullable=True),
        sa.Column("chain", sa.String(length=50), nullable=True),
        sa.Column("quantity", sa.Float(), nullable=False, server_default="1"),
        sa.Column("unit", sa.String(length=20), nullable=True),
        sa.Column("note", sa.Text(), nullable=True),
        sa.Column("deal_price", sa.Float(), nullable=True),
        sa.Column("original_price", sa.Float(), nullable=True),
        sa.Column("deal_text", sa.String(length=255), nullable=True),
        sa.Column("is_membership_price", sa.Boolean(), nullable=False, server_default=sa.false()),
        sa.Column("deal_valid_to", sa.DateTime(), nullable=True),
        sa.Column("is_checked", sa.Boolean(), nullable=False, server_default=sa.false()),
        sa.Column("position", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("purchased_at", sa.DateTime(), nullable=True),
        sa.Column("created_at", sa.DateTime(), nullable=False, server_default=sa.func.now()),
        sa.Column("updated_at", sa.DateTime(), nullable=False, server_default=sa.func.now()),
        sa.ForeignKeyConstraint(
            ["shopping_list_id"], ["shopping_lists.id"],
            name="fk_shopping_list_items_list_id", ondelete="CASCADE",
        ),
        sa.ForeignKeyConstraint(
            ["deal_id"], ["deals.id"],
            name="fk_shopping_list_items_deal_id", ondelete="SET NULL",
        ),
        sa.ForeignKeyConstraint(
            ["store_id"], ["stores.id"],
            name="fk_shopping_list_items_store_id", ondelete="SET NULL",
        ),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(op.f("ix_shopping_list_items_id"), "shopping_list_items", ["id"])
    op.create_index(op.f("ix_shopping_list_items_shopping_list_id"), "shopping_list_items", ["shopping_list_id"])
    op.create_index(op.f("ix_shopping_list_items_deal_id"), "shopping_list_items", ["deal_id"])

    op.create_table(
        "inventory_items",
        sa.Column("id", sa.Integer(), nullable=False, autoincrement=True),
        sa.Column("user_id", sa.Integer(), nullable=False),
        sa.Column("shopping_list_item_id", sa.Integer(), nullable=True),
        sa.Column("deal_id", sa.Integer(), nullable=True),
        sa.Column("store_id", sa.Integer(), nullable=True),
        sa.Column("name", sa.String(length=500), nullable=False),
        sa.Column("brand", sa.String(length=255), nullable=True),
        sa.Column("size", sa.String(length=100), nullable=True),
        sa.Column("image_url", sa.String(length=1000), nullable=True),
        sa.Column("chain", sa.String(length=50), nullable=True),
        sa.Column("quantity", sa.Float(), nullable=False, server_default="1"),
        sa.Column("quantity_remaining", sa.Float(), nullable=False, server_default="1"),
        sa.Column("unit", sa.String(length=20), nullable=True),
        sa.Column("purchase_price", sa.Float(), nullable=True),
        sa.Column("total_price", sa.Float(), nullable=True),
        sa.Column("currency", sa.String(length=3), nullable=False, server_default="SEK"),
        sa.Column("was_deal", sa.Boolean(), nullable=False, server_default=sa.false()),
        sa.Column("deal_text", sa.String(length=255), nullable=True),
        sa.Column("purchased_at", sa.DateTime(), nullable=False, server_default=sa.func.now()),
        sa.Column("status", sa.String(length=20), nullable=False, server_default="in_stock"),
        sa.Column("expiry_date", sa.Date(), nullable=True),
        sa.Column("consumed_at", sa.DateTime(), nullable=True),
        sa.Column("note", sa.Text(), nullable=True),
        sa.Column("created_at", sa.DateTime(), nullable=False, server_default=sa.func.now()),
        sa.Column("updated_at", sa.DateTime(), nullable=False, server_default=sa.func.now()),
        sa.ForeignKeyConstraint(
            ["user_id"], ["users.id"],
            name="fk_inventory_items_user_id", ondelete="CASCADE",
        ),
        sa.ForeignKeyConstraint(
            ["shopping_list_item_id"], ["shopping_list_items.id"],
            name="fk_inventory_items_list_item_id", ondelete="SET NULL",
        ),
        sa.ForeignKeyConstraint(
            ["deal_id"], ["deals.id"],
            name="fk_inventory_items_deal_id", ondelete="SET NULL",
        ),
        sa.ForeignKeyConstraint(
            ["store_id"], ["stores.id"],
            name="fk_inventory_items_store_id", ondelete="SET NULL",
        ),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(op.f("ix_inventory_items_id"), "inventory_items", ["id"])
    op.create_index(op.f("ix_inventory_items_user_id"), "inventory_items", ["user_id"])
    op.create_index(op.f("ix_inventory_items_status"), "inventory_items", ["status"])
    op.create_index(op.f("ix_inventory_items_purchased_at"), "inventory_items", ["purchased_at"])
    op.create_index(op.f("ix_inventory_items_expiry_date"), "inventory_items", ["expiry_date"])


def downgrade() -> None:
    op.drop_table("inventory_items")
    op.drop_table("shopping_list_items")
    op.drop_table("shopping_lists")
