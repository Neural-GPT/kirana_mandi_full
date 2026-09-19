from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session, joinedload

from .. import models, schemas
from ..constants import ADMIN_ROLES, ROLE_SHOPKEEPER, SHOP_STATUS_PENDING
from ..database import get_db
from ..deps import get_current_user, require_roles, verify_tenant_scope

router = APIRouter(tags=["shops"])


def _service_ids_for(shop_id: str, db: Session) -> list[str]:
    rows = db.query(models.ShopService.service_id).filter(
        models.ShopService.shop_id == shop_id
    ).all()
    return [r[0] for r in rows]


def _shop_to_out(shop: models.Shop, db: Session) -> schemas.ShopOut:
    out = schemas.ShopOut.model_validate(shop)
    return out.model_copy(update={"service_ids": _service_ids_for(shop.id, db)})


def _unique_shop_code(db: Session) -> str:
    # models._shop_code() is a random 8-char code; collisions are
    # astronomically unlikely but cheap to guard against outright rather
    # than trust probability, since this becomes a public, unguessable-ish
    # identifier customers type in by hand (see the "Dynamic / On-the-Fly"
    # white-label flow).
    for _ in range(10):
        code = models._shop_code()
        exists = db.query(models.Shop.id).filter(models.Shop.shop_code == code).first()
        if exists is None:
            return code
    raise HTTPException(status.HTTP_500_INTERNAL_SERVER_ERROR, "Could not generate a unique shop code.")


def _apply_shop_fields(shop: models.Shop, body: schemas.ShopCreate, db: Session) -> None:
    shop.name = body.name
    shop.owner_name = body.owner_name
    shop.phone = body.phone
    shop.alt_phone = body.alt_phone
    shop.description = body.description
    shop.category_id = body.category_id
    shop.region_id = body.region_id
    shop.latitude = body.latitude
    shop.longitude = body.longitude
    shop.formatted_address = body.formatted_address
    shop.home_delivery = body.home_delivery
    shop.delivery_radius_km = body.delivery_radius_km
    shop.delivery_fee = body.delivery_fee
    shop.logo_url = body.logo_url
    shop.banner_url = body.banner_url
    shop.primary_color = body.primary_color
    shop.secondary_color = body.secondary_color


def _apply_shop_services(shop: models.Shop, body: schemas.ShopCreate, db: Session) -> None:
    db.query(models.ShopService).filter(models.ShopService.shop_id == shop.id).delete()
    for service_id in body.service_ids:
        db.add(models.ShopService(shop_id=shop.id, service_id=service_id))


@router.post("/shops", response_model=schemas.ShopOut)
def create_shop(
    body: schemas.ShopCreate,
    db: Session = Depends(get_db),
    user: models.User = Depends(require_roles(ROLE_SHOPKEEPER)),
):
    existing = db.query(models.Shop).filter(models.Shop.owner_user_id == user.id).first()
    if existing is not None:
        raise HTTPException(status.HTTP_409_CONFLICT, "You already have a shop.")

    shop = models.Shop(owner_user_id=user.id, status=SHOP_STATUS_PENDING, shop_code=_unique_shop_code(db))
    _apply_shop_fields(shop, body, db)  # set columns BEFORE flush -- flush
    # executes the INSERT right away, and several columns (name, phone,
    # region_id, ...) are NOT NULL, so they must already be set on the
    # object beforehand.
    db.add(shop)
    db.flush()  # assigns shop.id (a Python-side column default) so
    # _apply_shop_services can create ShopService rows that reference it
    _apply_shop_services(shop, body, db)
    db.commit()
    db.refresh(shop)
    return _shop_to_out(shop, db)


@router.get("/shops/mine", response_model=schemas.ShopOut | None)
def get_my_shop(
    db: Session = Depends(get_db),
    user: models.User = Depends(require_roles(ROLE_SHOPKEEPER)),
):
    shop = db.query(models.Shop).filter(models.Shop.owner_user_id == user.id).first()
    return _shop_to_out(shop, db) if shop else None


@router.get("/shops/search", response_model=list[schemas.ShopOut])
def search_shops_by_name(q: str, db: Session = Depends(get_db)):
    shops = (
        db.query(models.Shop)
        .filter(
            models.Shop.status == "approved",
            models.Shop.is_available.is_(True),
            models.Shop.name.ilike(f"%{q}%"),
        )
        .order_by(models.Shop.name)
        .all()
    )
    return [_shop_to_out(s, db) for s in shops]


@router.get("/shops/{shop_id}", response_model=schemas.ShopOut)
def get_shop(
    shop_id: str,
    db: Session = Depends(get_db),
    _scope: None = Depends(verify_tenant_scope),
):
    shop = db.get(models.Shop, shop_id)
    if shop is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Shop not found.")
    return _shop_to_out(shop, db)


@router.get("/shops/{shop_id}/branding", response_model=schemas.ShopBrandingOut)
def get_shop_branding(shop_id: str, db: Session = Depends(get_db)):
    """
    Config endpoint for white-labeling. Public (no auth, no tenant-scope
    check) by design -- a freshly-installed white-label build's very
    first request, before any user is logged in, needs this to paint its
    splash/login screens with the right shop's logo and colors.
    """
    shop = db.get(models.Shop, shop_id)
    if shop is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Shop not found.")
    return schemas.ShopBrandingOut(
        shop_id=shop.id,
        shop_name=shop.name,
        logo_url=shop.logo_url,
        banner_url=shop.banner_url,
        primary_color=shop.primary_color,
        secondary_color=shop.secondary_color,
        region_id=shop.region_id,
        contact_number=shop.phone,
        status=shop.status,
        shop_code=shop.shop_code,
    )


@router.get("/shops/by-code/{shop_code}", response_model=schemas.ShopCodeLookupOut)
def get_shop_by_code(shop_code: str, db: Session = Depends(get_db)):
    """
    Resolves a shopkeeper-shareable Shop Code (or the code embedded in a
    deep link) to a shop_id -- the "Dynamic / On-the-Fly UI" white-label
    flow: the generic customer app calls this once, then locks itself to
    the returned shop_id (see ShopThemeController.lockToShop in the
    Flutter app) and fetches /shops/{shop_id}/branding + catalog from
    there on.
    """
    shop = (
        db.query(models.Shop)
        .filter(models.Shop.shop_code == shop_code.strip().upper())
        .first()
    )
    if shop is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "No shop found for that code.")
    return schemas.ShopCodeLookupOut(shop_id=shop.id)


@router.patch("/shops/{shop_id}/availability", response_model=schemas.ShopOut)
def set_shop_availability(
    shop_id: str,
    body: schemas.ShopAvailabilityUpdate,
    db: Session = Depends(get_db),
    user: models.User = Depends(get_current_user),
):
    shop = db.get(models.Shop, shop_id)
    if shop is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Shop not found.")
    if user.role not in ADMIN_ROLES and shop.owner_user_id != user.id:
        raise HTTPException(status.HTTP_403_FORBIDDEN, "You don't own this shop.")
    shop.is_available = body.is_available
    db.commit()
    db.refresh(shop)
    return _shop_to_out(shop, db)


@router.put("/shops/{shop_id}/services", response_model=schemas.ShopOut)
def set_shop_services(
    shop_id: str,
    body: schemas.ShopServiceIdsUpdate,
    db: Session = Depends(get_db),
    user: models.User = Depends(get_current_user),
):
    """
    Updates only the shop's service links, independent of the rest of the
    shop record -- mirrors the mobile app's ServiceRepository.setShopServices,
    which is called separately from shop create/update.
    """
    shop = db.get(models.Shop, shop_id)
    if shop is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Shop not found.")
    if user.role not in ADMIN_ROLES and shop.owner_user_id != user.id:
        raise HTTPException(status.HTTP_403_FORBIDDEN, "You don't own this shop.")

    db.query(models.ShopService).filter(models.ShopService.shop_id == shop_id).delete()
    for service_id in body.service_ids:
        db.add(models.ShopService(shop_id=shop_id, service_id=service_id))
    db.commit()
    db.refresh(shop)
    return _shop_to_out(shop, db)


@router.get("/regions/{region_id}/shops", response_model=list[schemas.ShopOut])
def list_shops_in_region(region_id: str, db: Session = Depends(get_db)):
    # Only approved + currently-available shops are shown to customers.
    shops = (
        db.query(models.Shop)
        .filter(
            models.Shop.region_id == region_id,
            models.Shop.status == "approved",
            models.Shop.is_available.is_(True),
        )
        .order_by(models.Shop.name)
        .all()
    )
    return [_shop_to_out(s, db) for s in shops]


@router.put("/shops/{shop_id}", response_model=schemas.ShopOut)
def update_shop(
    shop_id: str,
    body: schemas.ShopUpdate,
    db: Session = Depends(get_db),
    user: models.User = Depends(get_current_user),
):
    shop = db.get(models.Shop, shop_id)
    if shop is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Shop not found.")
    if user.role not in ADMIN_ROLES and shop.owner_user_id != user.id:
        raise HTTPException(status.HTTP_403_FORBIDDEN, "You don't own this shop.")

    _apply_shop_fields(shop, body, db)
    _apply_shop_services(shop, body, db)
    if body.is_available is not None:
        shop.is_available = body.is_available

    db.commit()
    db.refresh(shop)
    return _shop_to_out(shop, db)


@router.get("/admin/shops", response_model=list[schemas.ShopOut])
def list_all_shops_for_admin(
    status_filter: str | None = None,
    db: Session = Depends(get_db),
    _admin: models.User = Depends(require_roles(*ADMIN_ROLES)),
):
    q = db.query(models.Shop)
    if status_filter:
        q = q.filter(models.Shop.status == status_filter)
    shops = q.order_by(models.Shop.created_at.desc()).all()
    return [_shop_to_out(s, db) for s in shops]


@router.patch("/admin/shops/{shop_id}/status", response_model=schemas.ShopOut)
def set_shop_status(
    shop_id: str,
    body: schemas.ShopStatusUpdate,
    db: Session = Depends(get_db),
    _admin: models.User = Depends(require_roles(*ADMIN_ROLES)),
):
    shop = db.get(models.Shop, shop_id)
    if shop is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Shop not found.")
    shop.status = body.status
    db.commit()
    db.refresh(shop)
    return _shop_to_out(shop, db)


# --- Products (nested under a shop) ---
@router.get("/shops/{shop_id}/products", response_model=list[schemas.ProductOut])
def list_products(
    shop_id: str,
    db: Session = Depends(get_db),
    _scope: None = Depends(verify_tenant_scope),
):
    return (
        db.query(models.Product)
        .filter(models.Product.shop_id == shop_id)
        .order_by(models.Product.name)
        .all()
    )


@router.post("/shops/{shop_id}/products", response_model=schemas.ProductOut)
def create_product(
    shop_id: str,
    body: schemas.ProductCreate,
    db: Session = Depends(get_db),
    user: models.User = Depends(get_current_user),
):
    shop = db.get(models.Shop, shop_id)
    if shop is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Shop not found.")
    if user.role not in ADMIN_ROLES and shop.owner_user_id != user.id:
        raise HTTPException(status.HTTP_403_FORBIDDEN, "You don't own this shop.")

    product = models.Product(shop_id=shop_id, **body.model_dump())
    db.add(product)
    db.commit()
    db.refresh(product)
    return product


@router.put("/products/{product_id}", response_model=schemas.ProductOut)
def update_product(
    product_id: str,
    body: schemas.ProductCreate,
    db: Session = Depends(get_db),
    user: models.User = Depends(get_current_user),
):
    product = db.get(models.Product, product_id)
    if product is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Product not found.")
    shop = db.get(models.Shop, product.shop_id)
    if user.role not in ADMIN_ROLES and shop.owner_user_id != user.id:
        raise HTTPException(status.HTTP_403_FORBIDDEN, "You don't own this shop.")

    for field, value in body.model_dump().items():
        setattr(product, field, value)
    db.commit()
    db.refresh(product)
    return product


@router.delete("/products/{product_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_product(
    product_id: str,
    db: Session = Depends(get_db),
    user: models.User = Depends(get_current_user),
):
    product = db.get(models.Product, product_id)
    if product is None:
        return
    shop = db.get(models.Shop, product.shop_id)
    if user.role not in ADMIN_ROLES and shop.owner_user_id != user.id:
        raise HTTPException(status.HTTP_403_FORBIDDEN, "You don't own this shop.")
    db.delete(product)
    db.commit()


@router.get("/products/search", response_model=list[schemas.ProductSearchResultOut])
def search_products(q: str, region_id: str | None = None, db: Session = Depends(get_db)):
    query = (
        db.query(models.Product)
        .join(models.Shop, models.Product.shop_id == models.Shop.id)
        .options(joinedload(models.Product.shop))
        .filter(
            models.Shop.status == "approved",
            models.Shop.is_available.is_(True),
            models.Product.is_available.is_(True),
            models.Product.name.ilike(f"%{q}%"),
        )
    )
    if region_id:
        query = query.filter(models.Shop.region_id == region_id)
    products = query.order_by(models.Product.name).limit(50).all()
    return [
        schemas.ProductSearchResultOut(
            product=schemas.ProductOut.model_validate(p),
            shop=_shop_to_out(p.shop, db),
        )
        for p in products
    ]


@router.get("/products/{product_id}", response_model=schemas.ProductOut)
def get_product(product_id: str, db: Session = Depends(get_db)):
    product = db.get(models.Product, product_id)
    if product is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Product not found.")
    return product


@router.get("/admin/products", response_model=list[schemas.ProductSearchResultOut])
def all_products_for_admin(
    limit: int = 200,
    db: Session = Depends(get_db),
    _admin: models.User = Depends(require_roles(*ADMIN_ROLES)),
):
    products = (
        db.query(models.Product)
        .join(models.Shop, models.Product.shop_id == models.Shop.id)
        .options(joinedload(models.Product.shop))
        .order_by(models.Shop.created_at.desc())
        .limit(limit)
        .all()
    )
    return [
        schemas.ProductSearchResultOut(
            product=schemas.ProductOut.model_validate(p),
            shop=_shop_to_out(p.shop, db),
        )
        for p in products
    ]
