"""initial schema

Revision ID: 20260403_0001
Revises: None
Create Date: 2026-04-03 16:40:00
"""

from alembic import op
import sqlalchemy as sa


revision = "20260403_0001"
down_revision = None
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "companies",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("name", sa.String(length=255), nullable=False),
        sa.Column("slug", sa.String(length=100), nullable=False),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("name"),
        sa.UniqueConstraint("slug"),
    )
    op.create_index(op.f("ix_companies_id"), "companies", ["id"])

    op.create_table(
        "stores",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("company_id", sa.Integer(), nullable=False),
        sa.Column("name", sa.String(length=255), nullable=False),
        sa.Column("chain", sa.String(length=50), nullable=False),
        sa.Column("external_id", sa.String(length=100), nullable=True),
        sa.Column("store_url", sa.String(length=1000), nullable=True),
        sa.Column("weekly_deals_url", sa.String(length=1000), nullable=True),
        sa.ForeignKeyConstraint(["company_id"], ["companies.id"]),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("external_id"),
    )
    op.create_index(op.f("ix_stores_id"), "stores", ["id"])

    op.create_table(
        "store_details",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("store_id", sa.Integer(), nullable=False),
        sa.Column("about_url", sa.String(length=1000), nullable=True),
        sa.Column("address", sa.String(length=500), nullable=True),
        sa.Column("postal_code", sa.String(length=20), nullable=True),
        sa.Column("city", sa.String(length=255), nullable=True),
        sa.Column("phone", sa.String(length=50), nullable=True),
        sa.Column("google_maps_url", sa.String(length=1000), nullable=True),
        sa.Column("latitude", sa.Float(), nullable=True),
        sa.Column("longitude", sa.Float(), nullable=True),
        sa.Column("opening_hours", sa.Text(), nullable=True),
        sa.Column("special_hours", sa.Text(), nullable=True),
        sa.Column("scraped_at", sa.DateTime(), nullable=False, server_default=sa.func.now()),
        sa.Column("updated_at", sa.DateTime(), nullable=False, server_default=sa.func.now()),
        sa.ForeignKeyConstraint(["store_id"], ["stores.id"]),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("store_id"),
    )
    op.create_index(op.f("ix_store_details_id"), "store_details", ["id"])
    op.create_index(op.f("ix_store_details_store_id"), "store_details", ["store_id"])

    op.create_table(
        "deals",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("store_id", sa.Integer(), nullable=False),
        sa.Column("chain", sa.String(length=50), nullable=False),
        sa.Column("external_id", sa.String(length=200), nullable=True),
        sa.Column("name", sa.String(length=500), nullable=False),
        sa.Column("brand", sa.String(length=255), nullable=True),
        sa.Column("size", sa.String(length=100), nullable=True),
        sa.Column("description", sa.Text(), nullable=True),
        sa.Column("category", sa.String(length=255), nullable=True),
        sa.Column("image_url", sa.String(length=1000), nullable=True),
        sa.Column("original_price", sa.Float(), nullable=True),
        sa.Column("deal_price", sa.Float(), nullable=True),
        sa.Column("deal_text", sa.String(length=255), nullable=True),
        sa.Column("price_label", sa.String(length=200), nullable=True),
        sa.Column("is_membership_price", sa.Boolean(), nullable=False, server_default=sa.false()),
        sa.Column("comparison_price", sa.String(length=255), nullable=True),
        sa.Column("extra_info", sa.Text(), nullable=True),
        sa.Column("valid_from", sa.DateTime(), nullable=True),
        sa.Column("valid_to", sa.DateTime(), nullable=True),
        sa.Column("scraped_at", sa.DateTime(), nullable=False),
        sa.Column("source_url", sa.String(length=1000), nullable=True),
        sa.ForeignKeyConstraint(["store_id"], ["stores.id"]),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("external_id"),
    )
    op.create_index(op.f("ix_deals_id"), "deals", ["id"])

    op.create_table(
        "flyers",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("store_id", sa.Integer(), nullable=False),
        sa.Column("url", sa.String(length=1000), nullable=False),
        sa.Column("pdf_path", sa.String(length=1000), nullable=True),
        sa.Column("file_size", sa.BigInteger(), nullable=True),
        sa.Column("week_number", sa.SmallInteger(), nullable=True),
        sa.Column("valid_from", sa.DateTime(), nullable=True),
        sa.Column("valid_to", sa.DateTime(), nullable=True),
        sa.Column("scraped_at", sa.DateTime(), nullable=False, server_default=sa.func.now()),
        sa.ForeignKeyConstraint(["store_id"], ["stores.id"]),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(op.f("ix_flyers_id"), "flyers", ["id"])
    op.create_index(op.f("ix_flyers_store_id"), "flyers", ["store_id"])

    op.create_table(
        "products",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("store_id", sa.Integer(), nullable=False),
        sa.Column("external_id", sa.String(length=200), nullable=True),
        sa.Column("name", sa.String(length=500), nullable=False),
        sa.Column("brand", sa.String(length=255), nullable=True),
        sa.Column("size", sa.String(length=100), nullable=True),
        sa.Column("description", sa.Text(), nullable=True),
        sa.Column("image_url", sa.String(length=1000), nullable=True),
        sa.Column("price_label", sa.String(length=200), nullable=True),
        sa.Column("is_membership_price", sa.Boolean(), nullable=False, server_default=sa.false()),
        sa.Column("deal_text", sa.String(length=255), nullable=True),
        sa.Column("comparison_price", sa.String(length=255), nullable=True),
        sa.Column("extra_info", sa.Text(), nullable=True),
        sa.Column("source_url", sa.String(length=1000), nullable=True),
        sa.Column("scraped_at", sa.DateTime(), nullable=False),
        sa.ForeignKeyConstraint(["store_id"], ["stores.id"]),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("external_id"),
    )
    op.create_index(op.f("ix_products_id"), "products", ["id"])


def downgrade() -> None:
    op.drop_index(op.f("ix_products_id"), table_name="products")
    op.drop_table("products")
    op.drop_index(op.f("ix_flyers_store_id"), table_name="flyers")
    op.drop_index(op.f("ix_flyers_id"), table_name="flyers")
    op.drop_table("flyers")
    op.drop_index(op.f("ix_deals_id"), table_name="deals")
    op.drop_table("deals")
    op.drop_index(op.f("ix_store_details_store_id"), table_name="store_details")
    op.drop_index(op.f("ix_store_details_id"), table_name="store_details")
    op.drop_table("store_details")
    op.drop_index(op.f("ix_stores_id"), table_name="stores")
    op.drop_table("stores")
    op.drop_index(op.f("ix_companies_id"), table_name="companies")
    op.drop_table("companies")
