import uuid
from datetime import date as date_type
from datetime import datetime, timezone

from sqlalchemy import (
    Boolean,
    Date,
    DateTime,
    Float,
    ForeignKey,
    Integer,
    String,
    Text,
    UniqueConstraint,
)
from sqlalchemy.orm import Mapped, mapped_column, relationship

from .database import Base


def _uuid() -> str:
    return str(uuid.uuid4())


def _now() -> datetime:
    return datetime.now(timezone.utc)


class User(Base):
    __tablename__ = "users"

    id: Mapped[str] = mapped_column(String, primary_key=True, default=_uuid)
    phone: Mapped[str] = mapped_column(String, unique=True, index=True)
    name: Mapped[str | None] = mapped_column(String, nullable=True)
    role: Mapped[str] = mapped_column(String)  # customer | shopkeeper | admin | super_admin
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_now)


class OtpCode(Base):
    __tablename__ = "otp_codes"

    id: Mapped[str] = mapped_column(String, primary_key=True, default=_uuid)
    phone: Mapped[str] = mapped_column(String, index=True)
    code: Mapped[str] = mapped_column(String)
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    consumed: Mapped[bool] = mapped_column(Boolean, default=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_now)


class Region(Base):
    __tablename__ = "regions"

    id: Mapped[str] = mapped_column(String, primary_key=True, default=_uuid)
    name: Mapped[str] = mapped_column(String, unique=True)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)


class Category(Base):
    __tablename__ = "categories"

    id: Mapped[str] = mapped_column(String, primary_key=True, default=_uuid)
    name: Mapped[str] = mapped_column(String)
    type: Mapped[str] = mapped_column(String)  # "shop" | "product"
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)


class ServiceOption(Base):
    __tablename__ = "services"

    id: Mapped[str] = mapped_column(String, primary_key=True, default=_uuid)
    name: Mapped[str] = mapped_column(String)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)


class ProductIcon(Base):
    """
    The built-in icon library (PRD-style: no photo uploads -- shops/
    products pick a bundled Material icon by id instead). Only `id`
    (e.g. "milk_01") is meaningful for rendering on the client, resolved
    via the Flutter app's IconRegistry; this table just carries the
    human-readable label + category grouping so an admin can browse/
    manage which icons are offered.
    """

    __tablename__ = "icons"

    id: Mapped[str] = mapped_column(String, primary_key=True)
    label: Mapped[str] = mapped_column(String)
    category_id: Mapped[str | None] = mapped_column(String, ForeignKey("categories.id"), nullable=True)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)


def _shop_code() -> str:
    # Short, human-typeable code a customer can enter in the "Dynamic /
    # On-the-Fly" white-label flow (see routers/shops.py get_shop_by_code)
    # instead of installing a shop-specific APK. Deliberately NOT the
    # shop's uuid (too long to type/read aloud) -- 8 chars of the uuid's
    # hex, uppercased, is unique enough in practice and re-checked for
    # collisions at creation time regardless (see shops.py).
    return uuid.uuid4().hex[:8].upper()


class Shop(Base):
    __tablename__ = "shops"

    id: Mapped[str] = mapped_column(String, primary_key=True, default=_uuid)
    owner_user_id: Mapped[str] = mapped_column(String, ForeignKey("users.id"))
    name: Mapped[str] = mapped_column(String)
    owner_name: Mapped[str] = mapped_column(String)
    phone: Mapped[str] = mapped_column(String)
    alt_phone: Mapped[str | None] = mapped_column(String, nullable=True)
    description: Mapped[str | None] = mapped_column(Text, nullable=True)
    category_id: Mapped[str | None] = mapped_column(String, ForeignKey("categories.id"), nullable=True)
    region_id: Mapped[str] = mapped_column(String, ForeignKey("regions.id"))
    latitude: Mapped[float | None] = mapped_column(Float, nullable=True)
    longitude: Mapped[float | None] = mapped_column(Float, nullable=True)
    formatted_address: Mapped[str | None] = mapped_column(String, nullable=True)
    status: Mapped[str] = mapped_column(String, default="pending")  # pending|approved|rejected
    is_available: Mapped[bool] = mapped_column(Boolean, default=True)
    home_delivery: Mapped[bool] = mapped_column(Boolean, default=False)
    delivery_radius_km: Mapped[float | None] = mapped_column(Float, nullable=True)
    delivery_fee: Mapped[float | None] = mapped_column(Float, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_now)

    # --- White-label branding (Multi-Tenant / White-Labeled ecosystem) ---
    # Everything a client app needs to skin itself for this one shop --
    # see GET /shops/{shop_id}/branding and the Flutter ShopThemeController
    # that consumes it. No file uploads (matches the rest of this app's
    # "no photo uploads" pattern -- icons are picked from a bundled
    # registry) -- logo/banner are just URLs the shopkeeper pastes in
    # (e.g. an image already hosted somewhere), and colors are hex strings
    # the client parses into a Color.
    logo_url: Mapped[str | None] = mapped_column(String, nullable=True)
    banner_url: Mapped[str | None] = mapped_column(String, nullable=True)
    primary_color: Mapped[str | None] = mapped_column(String, nullable=True)  # "#RRGGBB"
    secondary_color: Mapped[str | None] = mapped_column(String, nullable=True)  # "#RRGGBB"

    # Short code a customer types into the "Dynamic / On-the-Fly" build of
    # the customer app (or that's embedded in a shareable deep link) to
    # lock that install to this one shop's catalog + theme, without
    # needing a shop-specific APK build. Unique across all shops.
    shop_code: Mapped[str] = mapped_column(String, unique=True, index=True, default=_shop_code)

    products: Mapped[list["Product"]] = relationship(back_populates="shop", cascade="all, delete-orphan")


class ShopService(Base):
    __tablename__ = "shop_services"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    shop_id: Mapped[str] = mapped_column(String, ForeignKey("shops.id"))
    service_id: Mapped[str] = mapped_column(String, ForeignKey("services.id"))

    __table_args__ = (UniqueConstraint("shop_id", "service_id"),)


class Product(Base):
    __tablename__ = "products"

    id: Mapped[str] = mapped_column(String, primary_key=True, default=_uuid)
    shop_id: Mapped[str] = mapped_column(String, ForeignKey("shops.id"))
    name: Mapped[str] = mapped_column(String)
    category_id: Mapped[str | None] = mapped_column(String, ForeignKey("categories.id"), nullable=True)
    price: Mapped[float] = mapped_column(Float)
    unit: Mapped[str] = mapped_column(String)
    icon_id: Mapped[str | None] = mapped_column(String, nullable=True)
    is_available: Mapped[bool] = mapped_column(Boolean, default=True)
    description: Mapped[str | None] = mapped_column(Text, nullable=True)

    shop: Mapped["Shop"] = relationship(back_populates="products")


class CartItem(Base):
    __tablename__ = "cart_items"

    id: Mapped[str] = mapped_column(String, primary_key=True, default=_uuid)
    customer_id: Mapped[str] = mapped_column(String, ForeignKey("users.id"))
    shop_id: Mapped[str] = mapped_column(String, ForeignKey("shops.id"))
    shop_name: Mapped[str] = mapped_column(String)
    product_id: Mapped[str] = mapped_column(String, ForeignKey("products.id"))
    product_name: Mapped[str] = mapped_column(String)
    unit: Mapped[str] = mapped_column(String)
    unit_price: Mapped[float] = mapped_column(Float)
    quantity: Mapped[int] = mapped_column(Integer)
    added_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_now)

    __table_args__ = (UniqueConstraint("customer_id", "product_id"),)


class Order(Base):
    __tablename__ = "orders"

    id: Mapped[str] = mapped_column(String, primary_key=True, default=_uuid)
    customer_id: Mapped[str] = mapped_column(String, ForeignKey("users.id"))
    customer_name: Mapped[str] = mapped_column(String)
    customer_phone: Mapped[str] = mapped_column(String)
    shop_id: Mapped[str] = mapped_column(String, ForeignKey("shops.id"))
    shop_name: Mapped[str] = mapped_column(String)
    shop_phone: Mapped[str] = mapped_column(String)
    status: Mapped[str] = mapped_column(String, default="placed")
    delivery_boy_phone: Mapped[str | None] = mapped_column(String, nullable=True)
    total_amount: Mapped[float] = mapped_column(Float)
    notes: Mapped[str | None] = mapped_column(Text, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_now)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_now, onupdate=_now)

    items: Mapped[list["OrderItem"]] = relationship(back_populates="order", cascade="all, delete-orphan")


class OrderItem(Base):
    __tablename__ = "order_items"

    id: Mapped[str] = mapped_column(String, primary_key=True, default=_uuid)
    order_id: Mapped[str] = mapped_column(String, ForeignKey("orders.id"))
    product_id: Mapped[str | None] = mapped_column(String, nullable=True)
    product_name: Mapped[str] = mapped_column(String)
    unit: Mapped[str] = mapped_column(String)
    unit_price: Mapped[float] = mapped_column(Float)
    quantity: Mapped[int] = mapped_column(Integer)

    order: Mapped["Order"] = relationship(back_populates="items")


class CallLog(Base):
    __tablename__ = "call_logs"

    id: Mapped[str] = mapped_column(String, primary_key=True, default=_uuid)
    shop_id: Mapped[str] = mapped_column(String, ForeignKey("shops.id"))
    # Optional free-text context (e.g. a name if the customer volunteered
    # one) -- customers aren't required to be logged in to call a shop,
    # so most entries will just be a bare timestamp.
    caller_label: Mapped[str | None] = mapped_column(String, nullable=True)
    called_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_now)


class SaleItem(Base):
    """
    One line from a shopkeeper's "today's sales" entry -- flat, no parent
    "sale" grouping, mirroring the mobile app's `sale_items` table
    exactly so date-range/series/top-product queries behave identically.
    """

    __tablename__ = "sale_items"

    id: Mapped[str] = mapped_column(String, primary_key=True, default=_uuid)
    shop_id: Mapped[str] = mapped_column(String, ForeignKey("shops.id"))
    product_id: Mapped[str | None] = mapped_column(String, nullable=True)
    product_name: Mapped[str] = mapped_column(String)
    quantity: Mapped[float] = mapped_column(Float)
    unit_price: Mapped[float] = mapped_column(Float)
    sale_date: Mapped[date_type] = mapped_column(Date)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_now)


class SyncQueueEntry(Base):
    """
    Optional bookkeeping table: mobile clients can POST an entry here
    when they make an offline write that later needs reconciling (mirrors
    the on-device `sync_queue` table in the Flutter app). Not required
    for the API to function -- everything else in this backend commits
    directly -- but gives you a server-side audit trail / retry point if
    a client's offline write needs manual review.
    """

    __tablename__ = "sync_queue"

    id: Mapped[str] = mapped_column(String, primary_key=True, default=_uuid)
    device_user_id: Mapped[str | None] = mapped_column(String, nullable=True)
    entity_type: Mapped[str] = mapped_column(String)
    entity_id: Mapped[str] = mapped_column(String)
    action: Mapped[str] = mapped_column(String)
    payload: Mapped[str | None] = mapped_column(Text, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_now)
