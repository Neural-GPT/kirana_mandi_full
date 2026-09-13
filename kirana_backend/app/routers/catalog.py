from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import func
from sqlalchemy.orm import Session

from .. import models, schemas
from ..constants import ADMIN_ROLES
from ..database import get_db
from ..deps import get_current_user, require_roles

router = APIRouter(tags=["catalog"])


# --- Regions ---
@router.get("/regions", response_model=list[schemas.RegionOut])
def list_regions(active_only: bool = True, db: Session = Depends(get_db)):
    q = db.query(models.Region)
    if active_only:
        q = q.filter(models.Region.is_active.is_(True))
    return q.order_by(models.Region.name).all()


@router.post("/regions", response_model=schemas.RegionOut)
def find_or_create_region(
    body: schemas.RegionCreate,
    db: Session = Depends(get_db),
    _user: models.User = Depends(get_current_user),
):
    """
    Any logged-in user (shopkeeper or admin) can call this. If a region
    with this name already exists (case-insensitive), it's reused rather
    than duplicated -- this is what lets a shopkeeper add their own area
    during shop setup while still deduplicating against admin-created
    ones. New regions immediately show up for every other shopkeeper and
    for customers browsing by area.
    """
    name = body.name.strip()
    existing = (
        db.query(models.Region)
        .filter(func.lower(models.Region.name) == name.lower())
        .first()
    )
    if existing:
        return existing

    region = models.Region(name=name)
    db.add(region)
    db.commit()
    db.refresh(region)
    return region


@router.patch("/regions/{region_id}/active", response_model=schemas.RegionOut)
def set_region_active(
    region_id: str,
    body: schemas.CategoryActiveUpdate,
    db: Session = Depends(get_db),
    _admin: models.User = Depends(require_roles(*ADMIN_ROLES)),
):
    region = db.get(models.Region, region_id)
    if region is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Region not found.")
    region.is_active = body.is_active
    db.commit()
    db.refresh(region)
    return region


@router.get("/regions/{region_id}", response_model=schemas.RegionOut)
def get_region(region_id: str, db: Session = Depends(get_db)):
    region = db.get(models.Region, region_id)
    if region is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Region not found.")
    return region


@router.put("/regions/{region_id}", response_model=schemas.RegionOut)
def rename_region(
    region_id: str,
    body: schemas.RegionCreate,
    db: Session = Depends(get_db),
    _admin: models.User = Depends(require_roles(*ADMIN_ROLES)),
):
    region = db.get(models.Region, region_id)
    if region is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Region not found.")
    region.name = body.name.strip()
    db.commit()
    db.refresh(region)
    return region


# --- Categories (admin-managed; everyone can read) ---
@router.get("/categories", response_model=list[schemas.CategoryOut])
def list_categories(
    type: str | None = None, active_only: bool = True, db: Session = Depends(get_db)
):
    q = db.query(models.Category)
    if type:
        q = q.filter(models.Category.type == type)
    if active_only:
        q = q.filter(models.Category.is_active.is_(True))
    return q.order_by(models.Category.name).all()


@router.post("/categories", response_model=schemas.CategoryOut)
def create_category(
    body: schemas.CategoryCreate,
    db: Session = Depends(get_db),
    _admin: models.User = Depends(require_roles(*ADMIN_ROLES)),
):
    if body.type not in ("shop", "product"):
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "type must be 'shop' or 'product'.")
    category = models.Category(name=body.name, type=body.type)
    db.add(category)
    db.commit()
    db.refresh(category)
    return category


@router.patch("/categories/{category_id}", response_model=schemas.CategoryOut)
def update_category(
    category_id: str,
    body: schemas.CategoryCreate,
    db: Session = Depends(get_db),
    _admin: models.User = Depends(require_roles(*ADMIN_ROLES)),
):
    category = db.get(models.Category, category_id)
    if category is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Category not found.")
    category.name = body.name
    category.type = body.type
    db.commit()
    db.refresh(category)
    return category


@router.patch("/categories/{category_id}/active", response_model=schemas.CategoryOut)
def set_category_active(
    category_id: str,
    body: schemas.CategoryActiveUpdate,
    db: Session = Depends(get_db),
    _admin: models.User = Depends(require_roles(*ADMIN_ROLES)),
):
    category = db.get(models.Category, category_id)
    if category is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Category not found.")
    category.is_active = body.is_active
    db.commit()
    db.refresh(category)
    return category


# --- Services (admin-managed; everyone can read) ---
@router.get("/services", response_model=list[schemas.ServiceOut])
def list_services(active_only: bool = True, db: Session = Depends(get_db)):
    q = db.query(models.ServiceOption)
    if active_only:
        q = q.filter(models.ServiceOption.is_active.is_(True))
    return q.order_by(models.ServiceOption.name).all()


@router.post("/services", response_model=schemas.ServiceOut)
def create_service(
    body: schemas.ServiceCreate,
    db: Session = Depends(get_db),
    _admin: models.User = Depends(require_roles(*ADMIN_ROLES)),
):
    service = models.ServiceOption(name=body.name)
    db.add(service)
    db.commit()
    db.refresh(service)
    return service


@router.put("/services/{service_id}", response_model=schemas.ServiceOut)
def rename_service(
    service_id: str,
    body: schemas.ServiceCreate,
    db: Session = Depends(get_db),
    _admin: models.User = Depends(require_roles(*ADMIN_ROLES)),
):
    service = db.get(models.ServiceOption, service_id)
    if service is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Service not found.")
    service.name = body.name
    db.commit()
    db.refresh(service)
    return service


@router.patch("/services/{service_id}/active", response_model=schemas.ServiceOut)
def set_service_active(
    service_id: str,
    body: schemas.CategoryActiveUpdate,
    db: Session = Depends(get_db),
    _admin: models.User = Depends(require_roles(*ADMIN_ROLES)),
):
    service = db.get(models.ServiceOption, service_id)
    if service is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Service not found.")
    service.is_active = body.is_active
    db.commit()
    db.refresh(service)
    return service


# --- Icons (admin-managed; everyone can read) ---
@router.get("/icons", response_model=list[schemas.IconOut])
def list_icons(
    category_id: str | None = None, active_only: bool = True, db: Session = Depends(get_db)
):
    q = db.query(models.ProductIcon)
    if category_id:
        q = q.filter(models.ProductIcon.category_id == category_id)
    if active_only:
        q = q.filter(models.ProductIcon.is_active.is_(True))
    return q.order_by(models.ProductIcon.label).all()


@router.post("/icons", response_model=schemas.IconOut)
def create_icon(
    body: schemas.IconCreate,
    db: Session = Depends(get_db),
    _admin: models.User = Depends(require_roles(*ADMIN_ROLES)),
):
    if db.get(models.ProductIcon, body.id) is not None:
        raise HTTPException(status.HTTP_409_CONFLICT, "An icon with this id already exists.")
    icon = models.ProductIcon(id=body.id, label=body.label, category_id=body.category_id)
    db.add(icon)
    db.commit()
    db.refresh(icon)
    return icon


@router.patch("/icons/{icon_id}/active", response_model=schemas.IconOut)
def set_icon_active(
    icon_id: str,
    body: schemas.CategoryActiveUpdate,
    db: Session = Depends(get_db),
    _admin: models.User = Depends(require_roles(*ADMIN_ROLES)),
):
    icon = db.get(models.ProductIcon, icon_id)
    if icon is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Icon not found.")
    icon.is_active = body.is_active
    db.commit()
    db.refresh(icon)
    return icon
