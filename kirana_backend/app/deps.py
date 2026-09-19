from fastapi import Depends, Header, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy.orm import Session

from .database import get_db
from .models import User
from .security import decode_access_token

_bearer = HTTPBearer(auto_error=False)


def get_current_user(
    credentials: HTTPAuthorizationCredentials | None = Depends(_bearer),
    db: Session = Depends(get_db),
) -> User:
    if credentials is None:
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Missing bearer token")
    try:
        payload = decode_access_token(credentials.credentials)
    except ValueError as exc:
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, str(exc)) from exc

    user = db.get(User, payload.get("sub"))
    if user is None:
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "User no longer exists")
    return user


def require_roles(*roles: str):
    """Dependency factory: `Depends(require_roles("admin", "super_admin"))`."""

    def _check(user: User = Depends(get_current_user)) -> User:
        if user.role not in roles:
            raise HTTPException(
                status.HTTP_403_FORBIDDEN,
                f"This action requires one of: {', '.join(roles)}",
            )
        return user

    return _check


def require_shop_owner(shop_owner_user_id: str, user: User) -> None:
    if user.role in ("admin", "super_admin"):
        return
    if user.id != shop_owner_user_id:
        raise HTTPException(status.HTTP_403_FORBIDDEN, "You don't own this shop")


def verify_tenant_scope(
    shop_id: str,
    x_shop_id: str | None = Header(default=None, alias="X-Shop-ID"),
) -> None:
    """
    Multi-tenant isolation guard for customer-facing, shop-scoped routes
    (e.g. `GET /shops/{shop_id}/products`).

    A white-labeled/dynamic-mode client app is *locked* to one shop_id
    (see the Flutter ShopThemeController) and sends it on every request
    as `X-Shop-ID` so a bug elsewhere in the client can never leak
    another tenant's data into that build -- if the header is present it
    MUST match the shop_id in the URL, or the request is rejected before
    it touches the database.

    The header is optional (older/non-white-label clients, and every
    other role, simply don't send it) so this is additive, not a breaking
    change to the API: every route's normal `shop_id` path/ownership
    checks still apply on top of this.
    """
    if x_shop_id is not None and x_shop_id != shop_id:
        raise HTTPException(
            status.HTTP_403_FORBIDDEN,
            "This app is locked to a different shop.",
        )
