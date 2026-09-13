import random
from datetime import datetime, timedelta, timezone

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from .. import models, schemas
from ..config import get_settings
from ..constants import ADMIN_ROLES, ROLE_CUSTOMER, ROLE_SHOPKEEPER, ROLE_SUPER_ADMIN
from ..database import get_db
from ..deps import get_current_user
from ..security import create_access_token
from ..textbee import send_sms

router = APIRouter(prefix="/auth", tags=["auth"])

# Synthetic phone used only to key the single env-configured admin's row
# -- mirrors the Flutter app's EnvConfig-based admin login. This admin
# never goes through OTP, so it never needs a real phone number.
_ENV_ADMIN_PHONE = "env-admin"


@router.post("/otp/send", response_model=schemas.SendOtpResponse)
def send_otp(body: schemas.SendOtpRequest, db: Session = Depends(get_db)):
    settings = get_settings()
    code = f"{random.randint(1000, 9999)}"
    expires_at = datetime.now(timezone.utc) + timedelta(minutes=settings.otp_validity_minutes)

    db.add(models.OtpCode(phone=body.phone, code=code, expires_at=expires_at))
    db.commit()

    sent = send_sms(body.phone, f"Your Kirana Mandi OTP is {code}. Valid for {settings.otp_validity_minutes} minutes.")

    # Only ever hand the code back in the response when textbee isn't
    # configured -- otherwise a real SMS should have gone out and
    # leaking the code in the API response would defeat the point of
    # having one.
    return schemas.SendOtpResponse(sent=sent, debug_otp=None if sent else code)


@router.post("/otp/verify", response_model=schemas.TokenResponse)
def verify_otp(body: schemas.VerifyOtpRequest, db: Session = Depends(get_db)):
    now = datetime.now(timezone.utc)
    otp_row = (
        db.query(models.OtpCode)
        .filter(
            models.OtpCode.phone == body.phone,
            models.OtpCode.code == body.otp,
            models.OtpCode.consumed.is_(False),
            models.OtpCode.expires_at >= now,
        )
        .order_by(models.OtpCode.created_at.desc())
        .first()
    )
    if otp_row is None:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "Incorrect or expired OTP. Please try again.")

    otp_row.consumed = True

    user = db.query(models.User).filter(models.User.phone == body.phone).first()

    if body.role in ADMIN_ROLES:
        # Admin accounts are never self-service: the phone must already
        # be registered as an admin (via POST /admin/admins by an
        # existing super_admin) before it can log in through this door.
        if user is None or user.role not in ADMIN_ROLES:
            raise HTTPException(
                status.HTTP_403_FORBIDDEN,
                "This phone number is not registered as an admin.",
            )
        db.commit()
        token = create_access_token(user_id=user.id, role=user.role)
        return schemas.TokenResponse(access_token=token, user=user)

    if user is None:
        if body.role not in (ROLE_CUSTOMER, ROLE_SHOPKEEPER):
            raise HTTPException(status.HTTP_400_BAD_REQUEST, "Invalid role.")
        user = models.User(
            phone=body.phone,
            name=(body.name or "").strip() or None,
            role=body.role,
        )
        db.add(user)
    else:
        # Let a returning customer/shopkeeper correct their stored name.
        trimmed = (body.name or "").strip()
        if trimmed and trimmed != user.name:
            user.name = trimmed

    db.commit()
    db.refresh(user)

    token = create_access_token(user_id=user.id, role=user.role)
    return schemas.TokenResponse(access_token=token, user=user)


@router.post("/admin/login", response_model=schemas.TokenResponse)
def admin_login(body: schemas.AdminLoginRequest, db: Session = Depends(get_db)):
    settings = get_settings()
    if not settings.admin_login_configured:
        raise HTTPException(
            status.HTTP_503_SERVICE_UNAVAILABLE,
            "Admin login isn't configured on this server yet "
            "(ADMIN_ID / ADMIN_PASSWORD environment variables are unset).",
        )
    if body.admin_id != settings.admin_id or body.password != settings.admin_password:
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Incorrect id or password.")

    user = db.query(models.User).filter(models.User.phone == _ENV_ADMIN_PHONE).first()
    if user is None:
        user = models.User(phone=_ENV_ADMIN_PHONE, name="Admin", role=ROLE_SUPER_ADMIN)
        db.add(user)
        db.commit()
        db.refresh(user)

    token = create_access_token(user_id=user.id, role=user.role)
    return schemas.TokenResponse(access_token=token, user=user)


@router.get("/me", response_model=schemas.UserOut)
def me(user: models.User = Depends(get_current_user)):
    return user
