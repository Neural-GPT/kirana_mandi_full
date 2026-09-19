"""
Thin client for the two GitHub REST endpoints "Generate My App" needs:
dispatching the build workflow, and reading back the release it
publishes. Mirrors textbee.py's shape (never raises out of its public
functions -- callers get a clean bool/None instead of an HTTP client
exception bubbling into a 500).
"""
import logging
from datetime import datetime

import httpx

from .config import get_settings

logger = logging.getLogger("kirana.github_deploy")

_API_BASE = "https://api.github.com"


def _headers(token: str) -> dict[str, str]:
    return {
        "Authorization": f"Bearer {token}",
        "Accept": "application/vnd.github+json",
        "X-GitHub-Api-Version": "2022-11-28",
    }


def _derive_application_id(shop_id: str) -> str:
    # Must match the derivation in
    # .github/actions/build-shop-apk/action.yml EXACTLY -- both sides
    # compute this independently rather than one passing it to the
    # other, so it has to be the same deterministic function in both
    # places. Any change here needs the same change there.
    short = shop_id.replace("-", "")[:8].lower()
    return f"com.kiranamandi.shop.s{short}"


def trigger_apk_build(
    shop_id: str,
    app_name: str,
    primary_color: str | None,
    secondary_color: str | None,
    logo_url: str | None,
) -> bool:
    """Fires the build_apk.yml workflow_dispatch event. Returns True if
    GitHub accepted the request (202/204) -- the build itself runs
    asynchronously; poll get_apk_status() for the result."""
    settings = get_settings()
    if not settings.github_deploy_configured:
        return False

    url = (
        f"{_API_BASE}/repos/{settings.github_repo}/actions/workflows/"
        f"{settings.github_workflow_file}/dispatches"
    )
    body = {
        "ref": settings.github_workflow_ref,
        "inputs": {
            "shop_id": shop_id,
            "app_name": app_name,
            "primary_color": (primary_color or "2E7D32").lstrip("#"),
            "secondary_color": (secondary_color or "").lstrip("#"),
            "logo_url": logo_url or "",
        },
    }
    try:
        resp = httpx.post(url, headers=_headers(settings.github_token), json=body, timeout=15)
        if resp.status_code == 204:
            return True
        logger.warning("GitHub workflow dispatch failed: %s %s", resp.status_code, resp.text)
        return False
    except httpx.HTTPError:
        logger.exception("GitHub workflow dispatch request failed")
        return False


def get_apk_status(shop_id: str) -> dict:
    """
    Looks up the per-shop GitHub Release (tag `shop-{shop_id}`) the
    workflow publishes/overwrites on every successful build. Returns a
    dict matching schemas.ApkStatusOut's fields; never raises.
    """
    settings = get_settings()
    result = {
        "status": "not_built_yet",
        "download_url": None,
        "built_at": None,
        "application_id": _derive_application_id(shop_id),
    }
    if not settings.github_deploy_configured:
        return result

    tag = f"shop-{shop_id}"
    url = f"{_API_BASE}/repos/{settings.github_repo}/releases/tags/{tag}"
    try:
        resp = httpx.get(url, headers=_headers(settings.github_token), timeout=15)
        if resp.status_code == 404:
            return result
        resp.raise_for_status()
        release = resp.json()
        apk_asset = next(
            (a for a in release.get("assets", []) if a.get("name", "").endswith(".apk")),
            None,
        )
        if apk_asset is None:
            return result  # release exists but the build/upload hasn't finished yet
        result["status"] = "ready"
        result["download_url"] = apk_asset.get("browser_download_url")
        published_at = release.get("published_at")
        if published_at:
            result["built_at"] = datetime.fromisoformat(published_at.replace("Z", "+00:00"))
        return result
    except httpx.HTTPError:
        logger.exception("GitHub release lookup failed")
        return result
