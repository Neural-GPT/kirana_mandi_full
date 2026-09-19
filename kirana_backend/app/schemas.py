from datetime import date, datetime

from pydantic import BaseModel, ConfigDict, Field


class OrmBase(BaseModel):
    model_config = ConfigDict(from_attributes=True)


# --- Auth ---
class SendOtpRequest(BaseModel):
    phone: str = Field(min_length=10, max_length=10)


class SendOtpResponse(BaseModel):
    sent: bool
    # Only populated when textbee isn't configured, so local/dev testing
    # doesn't require a real SMS gateway. Never populated once textbee
    # credentials are set -- see routers/auth.py.
    debug_otp: str | None = None


class VerifyOtpRequest(BaseModel):
    phone: str = Field(min_length=10, max_length=10)
    otp: str
    role: str  # "customer" | "shopkeeper" | "admin"
    name: str | None = None


class AdminLoginRequest(BaseModel):
    admin_id: str
    password: str


class UserOut(OrmBase):
    id: str
    phone: str
    name: str | None
    role: str
    created_at: datetime


class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    user: UserOut


# --- Catalog ---
class RegionOut(OrmBase):
    id: str
    name: str
    is_active: bool


class RegionCreate(BaseModel):
    name: str


class CategoryOut(OrmBase):
    id: str
    name: str
    type: str
    is_active: bool


class CategoryCreate(BaseModel):
    name: str
    type: str  # "shop" | "product"


class CategoryActiveUpdate(BaseModel):
    is_active: bool


class ServiceOut(OrmBase):
    id: str
    name: str
    is_active: bool


class ServiceCreate(BaseModel):
    name: str


class IconOut(OrmBase):
    id: str
    label: str
    category_id: str | None
    is_active: bool


class IconCreate(BaseModel):
    id: str
    label: str
    category_id: str | None = None


# --- Shops ---
class ShopCreate(BaseModel):
    name: str
    owner_name: str
    phone: str
    alt_phone: str | None = None
    description: str | None = None
    category_id: str | None = None
    region_id: str
    latitude: float | None = None
    longitude: float | None = None
    formatted_address: str | None = None
    home_delivery: bool = False
    delivery_radius_km: float | None = None
    delivery_fee: float | None = None
    service_ids: list[str] = []
    # --- White-label branding (all optional -- a shop that hasn't set
    # these up yet just renders with the app's default theme) ---
    logo_url: str | None = None
    banner_url: str | None = None
    primary_color: str | None = None
    secondary_color: str | None = None


class ShopUpdate(ShopCreate):
    is_available: bool | None = None


class ShopOut(OrmBase):
    id: str
    owner_user_id: str
    name: str
    owner_name: str
    phone: str
    alt_phone: str | None
    description: str | None
    category_id: str | None
    region_id: str
    latitude: float | None
    longitude: float | None
    formatted_address: str | None
    status: str
    is_available: bool
    home_delivery: bool
    delivery_radius_km: float | None
    delivery_fee: float | None
    created_at: datetime
    service_ids: list[str] = []
    logo_url: str | None = None
    banner_url: str | None = None
    primary_color: str | None = None
    secondary_color: str | None = None
    shop_code: str


class ShopServiceIdsUpdate(BaseModel):
    service_ids: list[str]


class ShopAvailabilityUpdate(BaseModel):
    is_available: bool


class ShopStatusUpdate(BaseModel):
    status: str  # approved | rejected


# --- White-labeling ---
class ShopBrandingOut(BaseModel):
    """
    Everything a client app needs to skin itself for one shop -- served
    publicly (no auth) so a freshly-installed white-label build, which
    has no logged-in user yet, can still render the right logo/colors on
    its very first screen. Deliberately a narrower shape than ShopOut
    (no owner/contact internals) since this is public.
    """

    shop_id: str
    shop_name: str
    logo_url: str | None
    banner_url: str | None
    primary_color: str | None
    secondary_color: str | None
    region_id: str
    contact_number: str
    status: str  # pending | approved | rejected -- client should refuse to load a non-approved shop
    shop_code: str


class ShopCodeLookupOut(BaseModel):
    shop_id: str


# --- White-label APK generation ---
class GenerateApkResponse(BaseModel):
    triggered: bool
    message: str
    # Where a human can watch the build progress (GitHub's own Actions
    # UI) -- the dispatch API itself doesn't hand back a run id to link
    # to directly.
    actions_url: str | None = None


class ApkStatusOut(BaseModel):
    status: str  # "not_built_yet" | "ready"
    download_url: str | None = None
    built_at: datetime | None = None
    application_id: str | None = None


# --- Products ---
class ProductCreate(BaseModel):
    name: str
    category_id: str | None = None
    price: float
    unit: str
    icon_id: str | None = None
    description: str | None = None
    is_available: bool = True


class ProductOut(OrmBase):
    id: str
    shop_id: str
    name: str
    category_id: str | None
    price: float
    unit: str
    icon_id: str | None
    is_available: bool
    description: str | None


class ProductSearchResultOut(BaseModel):
    """
    A product plus its parent shop, since a customer searching for a
    product needs to know which shop sells it (mirrors the mobile app's
    ProductSearchResult, which pairs the two for the same reason).
    """

    product: ProductOut
    shop: ShopOut


# --- Cart ---
class CartItemUpsert(BaseModel):
    shop_id: str
    shop_name: str
    product_id: str
    product_name: str
    unit: str
    unit_price: float
    quantity: int = 1


class CartQuantityUpdate(BaseModel):
    quantity: int


class CartItemOut(OrmBase):
    id: str
    shop_id: str
    shop_name: str
    product_id: str
    product_name: str
    unit: str
    unit_price: float
    quantity: int
    added_at: datetime


# --- Orders ---
class OrderItemOut(OrmBase):
    id: str
    product_id: str | None
    product_name: str
    unit: str
    unit_price: float
    quantity: int


class OrderOut(OrmBase):
    id: str
    customer_id: str
    customer_name: str
    customer_phone: str
    shop_id: str
    shop_name: str
    shop_phone: str
    status: str
    delivery_boy_phone: str | None
    total_amount: float
    notes: str | None
    created_at: datetime
    updated_at: datetime
    items: list[OrderItemOut] = []


class CheckoutRequest(BaseModel):
    # Empty = checkout the customer's whole cart, grouped by shop.
    # Non-empty = checkout only these shop ids (e.g. "Place Order" on
    # one shop group while leaving other shops' items in the cart).
    shop_ids: list[str] = []


class OrderStatusUpdate(BaseModel):
    status: str
    delivery_boy_phone: str | None = None


# --- Sales / analytics ---
class SaleEntryIn(BaseModel):
    product_id: str | None = None
    product_name: str
    quantity: float
    unit_price: float


class RecordSalesRequest(BaseModel):
    sale_date: date
    entries: list[SaleEntryIn]


class SaleItemOut(OrmBase):
    id: str
    shop_id: str
    product_id: str | None
    product_name: str
    quantity: float
    unit_price: float
    sale_date: date
    created_at: datetime


class RevenuePointOut(BaseModel):
    bucket_label: str
    revenue: float


class TopProductOut(BaseModel):
    product_name: str
    quantity: float


# --- Calls ---
class CallLogCreate(BaseModel):
    shop_id: str
    caller_label: str | None = None


class CallLogOut(OrmBase):
    id: str
    shop_id: str
    caller_label: str | None
    called_at: datetime


# --- Admin ---
class AdminCreate(BaseModel):
    phone: str
    name: str
    role: str = "admin"  # "admin" | "super_admin"


# --- Sync queue (optional offline-write audit trail) ---
class SyncQueueEntryCreate(BaseModel):
    entity_type: str
    entity_id: str
    action: str
    payload: str | None = None
