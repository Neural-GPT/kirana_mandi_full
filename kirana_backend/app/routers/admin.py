from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from .. import models, schemas
from ..constants import ADMIN_ROLES, ROLE_ADMIN, ROLE_SUPER_ADMIN, SHOP_STATUS_APPROVED, SHOP_STATUS_PENDING
from ..database import get_db
from ..deps import require_roles

router = APIRouter(prefix="/admin", tags=["admin"])


@router.get("/stats")
def platform_stats(
    db: Session = Depends(get_db),
    _admin: models.User = Depends(require_roles(*ADMIN_ROLES)),
) -> dict:
    return {
        "totalShops": db.query(models.Shop).count(),
        "pendingShops": db.query(models.Shop).filter(models.Shop.status == SHOP_STATUS_PENDING).count(),
        "approvedShops": db.query(models.Shop).filter(models.Shop.status == SHOP_STATUS_APPROVED).count(),
        "totalProducts": db.query(models.Product).count(),
        "totalRegions": db.query(models.Region).filter(models.Region.is_active.is_(True)).count(),
        "totalCustomers": db.query(models.User)
        .filter(models.User.role == "customer")
        .count(),
    }


@router.get("/users", response_model=list[schemas.UserOut])
def list_users_by_role(
    role: str,
    db: Session = Depends(get_db),
    _admin: models.User = Depends(require_roles(*ADMIN_ROLES)),
):
    return (
        db.query(models.User)
        .filter(models.User.role == role)
        .order_by(models.User.created_at.desc())
        .all()
    )


@router.get("/admins", response_model=list[schemas.UserOut])
def list_admins(
    db: Session = Depends(get_db),
    _super_admin: models.User = Depends(require_roles(ROLE_SUPER_ADMIN)),
):
    return (
        db.query(models.User)
        .filter(models.User.role.in_([ROLE_ADMIN, ROLE_SUPER_ADMIN]))
        .order_by(models.User.created_at.desc())
        .all()
    )


@router.post("/admins", response_model=schemas.UserOut)
def add_admin(
    body: schemas.AdminCreate,
    db: Session = Depends(get_db),
    _super_admin: models.User = Depends(require_roles(ROLE_SUPER_ADMIN)),
):
    """
    Registers a phone number as an admin (or super_admin). That phone can
    then log in through the normal OTP flow (POST /auth/otp/send +
    /auth/otp/verify with role="admin") -- see auth.py's verify_otp,
    which only allows role="admin" for phone numbers already present
    with an admin role here. Only a super_admin may add admins. A phone
    already registered under a different role (shopkeeper/customer/an
    existing admin) is rejected rather than silently reassigned.
    """
    if body.role not in (ROLE_ADMIN, ROLE_SUPER_ADMIN):
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "Role must be admin or super_admin.")

    existing = db.query(models.User).filter(models.User.phone == body.phone).first()
    if existing is not None:
        if existing.role in (ROLE_ADMIN, ROLE_SUPER_ADMIN):
            raise HTTPException(status.HTTP_409_CONFLICT, "This phone number is already an admin.")
        raise HTTPException(
            status.HTTP_409_CONFLICT,
            f"This phone number is already registered as a {existing.role}.",
        )

    admin = models.User(phone=body.phone, name=body.name, role=body.role)
    db.add(admin)
    db.commit()
    db.refresh(admin)
    return admin


@router.delete("/admins/{user_id}", status_code=status.HTTP_204_NO_CONTENT)
def remove_admin(
    user_id: str,
    db: Session = Depends(get_db),
    super_admin: models.User = Depends(require_roles(ROLE_SUPER_ADMIN)),
):
    target = db.get(models.User, user_id)
    if target is None:
        return
    if target.role == ROLE_SUPER_ADMIN:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "Can't remove a super admin.")
    if target.id == super_admin.id:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "Can't remove yourself.")
    db.delete(target)
    db.commit()
