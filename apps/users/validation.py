from __future__ import annotations

import re
from urllib.parse import urlsplit, urlunsplit

from django.core.exceptions import ValidationError

PROFILE_BIO_MAX_LENGTH = 500
AVATAR_MAX_BYTES = 2 * 1024 * 1024
IMAGE_UPLOAD_MAX_BYTES = 5 * 1024 * 1024
MEDIA_UPLOAD_MAX_BYTES = 20 * 1024 * 1024

_CONTROL_CHAR_RE = re.compile(r"[\x00-\x08\x0b\x0c\x0e-\x1f\x7f]")

SOCIAL_LINK_RULES = {
    "telegram_url": {
        "label": "Telegram",
        "hosts": {"t.me", "telegram.me"},
    },
    "vk_url": {
        "label": "VK",
        "hosts": {"vk.com"},
    },
    "instagram_url": {
        "label": "Instagram",
        "hosts": {"instagram.com", "www.instagram.com"},
    },
    "max_url": {
        "label": "MAX",
        "hosts": {"max.ru", "web.max.ru"},
    },
}


def clean_plain_text(
    value: str | None,
    *,
    max_length: int,
    field_label: str,
    allow_newlines: bool = False,
) -> str:
    if value is None:
        return ""

    cleaned = value.strip()
    if _CONTROL_CHAR_RE.search(cleaned):
        raise ValidationError(f"{field_label}: уберите служебные символы")
    if not allow_newlines and ("\n" in cleaned or "\r" in cleaned):
        raise ValidationError(f"{field_label}: переносы строк здесь не нужны")
    if "<" in cleaned or ">" in cleaned:
        raise ValidationError(f"{field_label}: HTML-теги недопустимы")
    if len(cleaned) > max_length:
        raise ValidationError(f"{field_label}: максимум {max_length} символов")
    return cleaned


def normalize_social_url(value: str | None, field_name: str) -> str:
    raw_value = (value or "").strip()
    if not raw_value:
        return ""

    if field_name not in SOCIAL_LINK_RULES:
        raise ValidationError("Неизвестная социальная сеть")

    if "://" not in raw_value:
        raw_value = f"https://{raw_value}"

    parts = urlsplit(raw_value)
    host = parts.hostname.lower() if parts.hostname else ""
    rule = SOCIAL_LINK_RULES[field_name]

    if parts.scheme != "https" or parts.username or parts.password:
        raise ValidationError(f"{rule['label']}: укажите безопасную ссылку https")
    if host not in rule["hosts"]:
        allowed_hosts = ", ".join(sorted(rule["hosts"]))
        raise ValidationError(f"{rule['label']}: ссылка должна вести на {allowed_hosts}")
    if not parts.path or parts.path == "/":
        raise ValidationError(f"{rule['label']}: укажите ссылку на профиль")

    normalized_path = "/" + parts.path.lstrip("/")
    return urlunsplit(("https", host, normalized_path, parts.query, ""))


def clean_avatar_position(value: int | str | None, *, default: int = 50) -> int:
    if value in {None, ""}:
        return default
    try:
        parsed = int(value)
    except (TypeError, ValueError) as error:
        raise ValidationError("Позиция аватара должна быть числом") from error
    if parsed < 0 or parsed > 100:
        raise ValidationError("Позиция аватара должна быть от 0 до 100")
    return parsed


def clean_avatar_scale(value, *, default: float = 1.0) -> float:
    if value in {None, ""}:
        return default
    try:
        parsed = float(value)
    except (TypeError, ValueError) as error:
        raise ValidationError("Масштаб аватара должен быть числом") from error
    if parsed < 1 or parsed > 3:
        raise ValidationError("Масштаб аватара должен быть от 1 до 3")
    return round(parsed, 2)


def validate_upload_size(upload, *, max_bytes: int, label: str = "Файл") -> None:
    size = getattr(upload, "size", 0) or 0
    if size > max_bytes:
        max_mb = max_bytes // (1024 * 1024)
        raise ValidationError(f"{label}: максимум {max_mb} МБ")
