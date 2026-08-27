import logging

from django.conf import settings

from .http_client import ExternalHttpError, request_json

logger = logging.getLogger(__name__)

TURNSTILE_VERIFY_URL = "https://challenges.cloudflare.com/turnstile/v0/siteverify"


class TurnstileError(Exception):
    def __init__(self, message: str = "Не удалось пройти проверку антибота"):
        super().__init__(message)


def is_turnstile_enabled() -> bool:
    return bool(settings.CLOUDFLARE_TURNSTILE_SITE_KEY and settings.CLOUDFLARE_TURNSTILE_SECRET_KEY)


def verify_turnstile_token(token: str | None, *, remote_ip: str = "") -> None:
    if not is_turnstile_enabled():
        return

    cleaned = (token or "").strip()
    if not cleaned:
        raise TurnstileError("Подтвердите, что вы не робот")

    form_body = {
        "secret": settings.CLOUDFLARE_TURNSTILE_SECRET_KEY,
        "response": cleaned,
    }
    if remote_ip:
        form_body["remoteip"] = remote_ip

    try:
        payload = request_json(TURNSTILE_VERIFY_URL, form_body=form_body, timeout=10)
    except ExternalHttpError:
        logger.exception("Cloudflare Turnstile verification failed")
        raise TurnstileError("Не удалось проверить антибота. Попробуйте ещё раз.") from None

    if payload.get("success") is True:
        return

    logger.warning("Cloudflare Turnstile rejected token: %s", payload.get("error-codes"))
    raise TurnstileError("Проверка антибота не пройдена. Обновите страницу и попробуйте снова.")
