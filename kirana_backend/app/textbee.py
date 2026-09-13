import logging

import httpx

from .config import get_settings

logger = logging.getLogger("kirana.textbee")


def send_sms(phone: str, message: str) -> bool:
    """
    Sends an SMS via textbee.dev's gateway API. Returns True if textbee
    accepted the request, False otherwise (never raises -- callers treat
    OTP delivery failure as "couldn't send," not a 500).

    textbee routes through a specific registered Android device, so the
    device id is part of the URL path, not just a header/body field:
    https://textbee.dev/docs
    """
    settings = get_settings()
    if not settings.textbee_configured:
        return False

    url = (
        f"https://api.textbee.dev/api/v1/gateway/devices/"
        f"{settings.textbee_device_id}/send-sms"
    )
    try:
        response = httpx.post(
            url,
            json={"recipients": [phone], "message": message},
            headers={"x-api-key": settings.textbee_api_key},
            timeout=10,
        )
        response.raise_for_status()
        return True
    except httpx.HTTPError:
        logger.exception("Failed to send OTP SMS via textbee")
        return False
