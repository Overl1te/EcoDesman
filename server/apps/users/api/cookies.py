from django.conf import settings
from django.http import HttpRequest
from rest_framework.response import Response
from rest_framework_simplejwt.settings import api_settings


def _resolve_cookie_secure(request: HttpRequest | None) -> bool:
    if settings.AUTH_COOKIE_SECURE is not None:
        return settings.AUTH_COOKIE_SECURE
    return bool(request and request.is_secure())


def _cookie_kwargs(max_age: int, *, secure: bool) -> dict[str, object]:
    kwargs: dict[str, object] = {
        "httponly": True,
        "max_age": max_age,
        "path": settings.AUTH_COOKIE_PATH,
        "samesite": settings.AUTH_COOKIE_SAMESITE,
        "secure": secure,
    }
    if settings.AUTH_COOKIE_DOMAIN:
        kwargs["domain"] = settings.AUTH_COOKIE_DOMAIN
    return kwargs


def set_auth_cookies(
    response: Response,
    *,
    access_token: str,
    refresh_token: str,
    request: HttpRequest | None = None,
) -> None:
    secure = _resolve_cookie_secure(request)
    response.set_cookie(
        settings.AUTH_ACCESS_COOKIE_NAME,
        access_token,
        **_cookie_kwargs(int(api_settings.ACCESS_TOKEN_LIFETIME.total_seconds()), secure=secure),
    )
    response.set_cookie(
        settings.AUTH_REFRESH_COOKIE_NAME,
        refresh_token,
        **_cookie_kwargs(int(api_settings.REFRESH_TOKEN_LIFETIME.total_seconds()), secure=secure),
    )


def clear_auth_cookies(response: Response) -> None:
    delete_kwargs = {
        "path": settings.AUTH_COOKIE_PATH,
        "samesite": settings.AUTH_COOKIE_SAMESITE,
    }
    if settings.AUTH_COOKIE_DOMAIN:
        delete_kwargs["domain"] = settings.AUTH_COOKIE_DOMAIN

    response.delete_cookie(settings.AUTH_ACCESS_COOKIE_NAME, **delete_kwargs)
    response.delete_cookie(settings.AUTH_REFRESH_COOKIE_NAME, **delete_kwargs)
