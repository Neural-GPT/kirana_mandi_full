from fastapi import APIRouter, Depends, HTTPException, Request, status
from fastapi.responses import Response
from sqlalchemy.orm import Session

from .. import models, schemas
from ..config import get_settings
from ..database import get_db
from ..deps import get_current_user, require_shop_owner
from ..github_deploy import fetch_apk_bytes, get_apk_status, trigger_apk_build

router = APIRouter(tags=["deploy"])


def _get_owned_shop(shop_id: str, user: models.User, db: Session) -> models.Shop:
    shop = db.get(models.Shop, shop_id)
    if shop is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Shop not found.")
    require_shop_owner(shop.owner_user_id, user)
    return shop


@router.post("/shops/{shop_id}/generate-apk", response_model=schemas.GenerateApkResponse)
def generate_apk(
    shop_id: str,
    db: Session = Depends(get_db),
    user: models.User = Depends(get_current_user),
):
    """
    "Generate My App" -- kicks off a CI build (see
    .github/workflows/build_apk.yml) that produces a release APK unique
    to this shop: its own Android application id (so it installs
    alongside other shops' apps rather than overwriting them), its own
    launcher name, and its own launcher icon from the shop's logo. The
    build runs asynchronously -- poll GET .../apk-status for the result.
    """
    shop = _get_owned_shop(shop_id, user, db)
    settings = get_settings()
    if not settings.github_deploy_configured:
        raise HTTPException(
            status.HTTP_503_SERVICE_UNAVAILABLE,
            "APK generation isn't configured on this server yet "
            "(GITHUB_TOKEN / GITHUB_REPO).",
        )

    ok = trigger_apk_build(
        shop_id=shop.id,
        app_name=shop.name,
        primary_color=shop.primary_color,
        secondary_color=shop.secondary_color,
        logo_url=shop.logo_url,
    )
    if not ok:
        raise HTTPException(
            status.HTTP_502_BAD_GATEWAY,
            "Could not start the build. Please try again shortly.",
        )
    return schemas.GenerateApkResponse(
        triggered=True,
        message="Build started -- this usually takes a few minutes.",
        actions_url=f"https://github.com/{settings.github_repo}/actions",
    )


@router.get("/shops/{shop_id}/apk-status", response_model=schemas.ApkStatusOut)
def apk_status(
    shop_id: str,
    request: Request,
    db: Session = Depends(get_db),
    user: models.User = Depends(get_current_user),
):
    shop = _get_owned_shop(shop_id, user, db)
    result = get_apk_status(shop.id)
    if result["status"] == "ready":
        # Point at OUR OWN public download route, not GitHub's
        # browser_download_url -- that only works for someone logged
        # into GitHub with access to this repo, which a customer (or
        # the shopkeeper, in a different browser) doesn't have when the
        # repo is private. See fetch_apk_bytes()'s docstring.
        result["download_url"] = str(request.base_url).rstrip("/") + f"/shops/{shop.id}/download"
    return schemas.ApkStatusOut(**result)


@router.get("/shops/{shop_id}/download")
def download_apk(shop_id: str, db: Session = Depends(get_db)):
    """
    Public, unauthenticated on purpose: this is the link the shopkeeper
    shares with customers to install the app, so it can't require a
    Kirana Mandi login (a brand-new customer has no account yet) or
    GitHub access (the repo can stay private). It proxies the actual
    bytes from GitHub using this server's own token -- see
    fetch_apk_bytes().
    """
    shop = db.get(models.Shop, shop_id)
    if shop is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Shop not found.")
    content = fetch_apk_bytes(shop.id)
    if content is None:
        raise HTTPException(
            status.HTTP_404_NOT_FOUND,
            "No build is available for this shop yet.",
        )
    safe_name = "".join(c for c in shop.name if c.isalnum() or c in " -_").strip() or "app"
    return Response(
        content=content,
        media_type="application/vnd.android.package-archive",
        headers={"Content-Disposition": f'attachment; filename="{safe_name}.apk"'},
    )