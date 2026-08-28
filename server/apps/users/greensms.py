import logging
from dataclasses import dataclass

from django.conf import settings

from .http_client import ExternalHttpError, request_json

logger = logging.getLogger(__name__)

GREENSMS_API_BASE = "https://api3.greensms.ru"
CHANNEL_ORDER = ("telegram", "call", "receive")


class GreenSMSError(Exception):
    def __init__(self, message: str = "Не удалось отправить код подтверждения"):
        super().__init__(message)


@dataclass(frozen=True)
class GreenSMSSendResult:
    channel: str
    request_id: str
    code: str = ""
    dial_number: str = ""


def is_greensms_configured() -> bool:
    return bool(settings.GREENSMS_TOKEN or (settings.GREENSMS_USER and settings.GREENSMS_PASSWORD))


def is_phone_verification_enabled() -> bool:
    return bool(settings.GREENSMS_DEBUG) or is_greensms_configured()


def to_greensms_number(phone: str) -> str:
    digits = "".join(character for character in phone if character.isdigit())
    if digits.startswith("8") and len(digits) == 11:
        digits = f"7{digits[1:]}"
    return digits


def send_verification_code(
    phone: str,
    *,
    start_channel: str = "telegram",
    cascade: bool = True,
) -> GreenSMSSendResult:
    if start_channel not in CHANNEL_ORDER:
        start_channel = "telegram"

    channels = CHANNEL_ORDER[CHANNEL_ORDER.index(start_channel) :]
    if not cascade:
        channels = (start_channel,)

    last_error = "Не удалось отправить код подтверждения"
    for channel in channels:
        try:
            if channel == "telegram":
                return _send_telegram(phone)
            if channel == "call":
                return _send_flashcall(phone)
            return _send_receive_call(phone)
        except GreenSMSError as error:
            last_error = str(error)
            logger.warning("GreenSMS channel %s failed for %s: %s", channel, phone, error)

    raise GreenSMSError(last_error)


def next_channel(current: str) -> str | None:
    if current not in CHANNEL_ORDER:
        return "telegram"
    index = CHANNEL_ORDER.index(current) + 1
    if index >= len(CHANNEL_ORDER):
        return None
    return CHANNEL_ORDER[index]


def is_receive_call_confirmed(request_id: str) -> bool:
    if settings.GREENSMS_DEBUG and str(request_id).startswith("debug-"):
        return True

    payload = _request(
        "/call/status",
        {"id": request_id, "extended": "true"},
        debug_prefix="status",
        method="GET",
    )
    status_text = str(payload.get("status") or payload.get("status_text") or "").lower()
    status_code = int(payload.get("status_code") or payload.get("statusCode") or -1)
    if status_text in {"answered", "completed", "confirmed"}:
        return True
    # GreenSMS: 3+ значит входящий звонок от абонента принят.
    return 3 <= status_code < 100


def format_dial_number(number: str) -> str:
    digits = "".join(character for character in number if character.isdigit())
    if digits.startswith("8") and len(digits) == 11:
        digits = f"7{digits[1:]}"
    if digits.startswith("7") and len(digits) == 11:
        return f"+7 ({digits[1:4]}) {digits[4:7]}-{digits[7:9]}-{digits[9:11]}"
    return number


def _generate_code() -> str:
    import secrets

    return f"{secrets.randbelow(10000):04d}"


def _send_telegram(phone: str) -> GreenSMSSendResult:
    code = _generate_code()
    payload = _request("/telegram/send", {"to": to_greensms_number(phone), "txt": code}, debug_prefix="tg")
    return GreenSMSSendResult(channel="telegram", request_id=_request_id(payload, "tg"), code=code)


def _send_flashcall(phone: str) -> GreenSMSSendResult:
    payload = _request("/call/send", {"to": to_greensms_number(phone)}, debug_prefix="call")
    raw_code = "".join(character for character in str(payload.get("code") or "") if character.isdigit())
    if settings.GREENSMS_DEBUG and not raw_code:
        raw_code = _generate_code()
    if len(raw_code) < 4:
        raise GreenSMSError("Не удалось позвонить с кодом в номере")
    return GreenSMSSendResult(
        channel="call",
        request_id=_request_id(payload, "call"),
        code=raw_code[-4:],
    )


def _send_receive_call(phone: str) -> GreenSMSSendResult:
    payload = _request("/call/receive", {"to": to_greensms_number(phone)}, debug_prefix="receive")
    number = "".join(character for character in str(payload.get("number") or "") if character.isdigit())
    if settings.GREENSMS_DEBUG and not number:
        number = "78005553535"
    if not number:
        raise GreenSMSError("Не удалось получить номер для обратного звонка")
    return GreenSMSSendResult(
        channel="receive",
        request_id=_request_id(payload, "receive"),
        dial_number=number,
    )


def _request(path: str, params: dict[str, str], *, debug_prefix: str, method: str = "POST") -> dict:
    if settings.GREENSMS_DEBUG:
        logger.info("GreenSMS debug skip %s to %s", path, params.get("to") or params.get("id"))
        return {"request_id": f"debug-{debug_prefix}"}

    if not is_greensms_configured():
        raise GreenSMSError("Сервис подтверждения телефона не настроен")

    headers = {}
    query = dict(params)
    if settings.GREENSMS_TOKEN:
        headers["Authorization"] = f"Bearer {settings.GREENSMS_TOKEN}"
    else:
        query["user"] = settings.GREENSMS_USER
        query["pass"] = settings.GREENSMS_PASSWORD

    try:
        payload = request_json(
            f"{GREENSMS_API_BASE}{path}",
            method=method,
            query=query,
            headers=headers,
            timeout=20,
        )
    except ExternalHttpError as error:
        logger.warning("GreenSMS HTTP error %s: %s", path, error)
        raise GreenSMSError(_user_facing_channel_error(path, str(error))) from error

    if payload.get("error"):
        raise GreenSMSError(_user_facing_channel_error(path, _extract_payload_error(payload)))

    return payload


def _request_id(payload: dict, prefix: str) -> str:
    value = str(payload.get("request_id") or payload.get("requestId") or "")
    if value:
        return value
    if settings.GREENSMS_DEBUG:
        return f"debug-{prefix}"
    raise GreenSMSError("Сервис подтверждения вернул пустой ответ")


def _extract_payload_error(payload: dict) -> str:
    for key in ("error_message", "message", "error"):
        value = payload.get(key)
        if isinstance(value, str) and value.strip():
            return value.strip()
    return "Ошибка GreenSMS"


def _user_facing_channel_error(path: str, raw_message: str) -> str:
    if "telegram" in path:
        return raw_message or "Не удалось отправить код в Telegram"
    if "receive" in path:
        return raw_message or "Не удалось подготовить обратный звонок"
    if "call" in path:
        return raw_message or "Не удалось позвонить с кодом в номере"
    return raw_message or "Не удалось отправить подтверждение"
