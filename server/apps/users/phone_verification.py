import hashlib
import hmac
from datetime import timedelta
from uuid import UUID

from django.conf import settings
from django.utils import timezone

from .greensms import (
    CHANNEL_ORDER,
    GreenSMSError,
    format_dial_number,
    is_phone_verification_enabled,
    is_receive_call_confirmed,
    next_channel,
    send_verification_code,
)
from .models import PhoneVerificationChallenge, User
from .services import normalize_phone, phone_identity_values


class PhoneVerificationError(Exception):
    def __init__(self, message: str, *, status_code: int = 400):
        super().__init__(message)
        self.status_code = status_code


CHANNEL_HINTS = {
    "telegram": "Код отправлен в Telegram. Если сообщения нет, попробуйте другой способ.",
    "call": "Вам поступит короткий звонок. Введите последние 4 цифры входящего номера — это и есть код.",
    "receive": "Позвоните на этот номер со своего телефона. Вызов бесплатный, его можно сбросить после соединения.",
}


def phone_verification_public_config() -> dict:
    return {
        "enabled": is_phone_verification_enabled(),
        "channels": list(CHANNEL_ORDER),
    }


def request_phone_challenge(
    *,
    phone: str | None,
    purpose: str,
    client_ip: str = "",
    start_channel: str | None = None,
    existing: PhoneVerificationChallenge | None = None,
) -> dict:
    if not is_phone_verification_enabled():
        raise PhoneVerificationError("Подтверждение телефона сейчас отключено")

    normalized = _require_phone(phone)
    purpose = _clean_purpose(purpose)
    _ensure_phone_available(normalized, purpose=purpose)
    _enforce_rate_limits(phone=normalized, client_ip=client_ip, skip_cooldown=existing is not None)

    if existing is not None:
        start_channel = next_channel(existing.channel)
        if start_channel is None:
            raise PhoneVerificationError(
                "Все способы доставки уже использованы. Подождите и запросите код снова.",
            )

    try:
        result = send_verification_code(normalized, start_channel=start_channel or "telegram")
    except GreenSMSError as error:
        raise PhoneVerificationError(str(error), status_code=503) from error

    now = timezone.now()
    challenge = PhoneVerificationChallenge.objects.create(
        phone=normalized,
        purpose=purpose,
        channel=result.channel,
        code_hash=_hash_code(normalized, result.code) if result.code else "",
        greensms_request_id=result.request_id,
        receive_number=result.dial_number,
        client_ip=client_ip or None,
        expires_at=now + timedelta(seconds=settings.PHONE_VERIFICATION_CODE_TTL_SECONDS),
    )
    return serialize_challenge(challenge, include_debug_code=result.code)


def resend_phone_challenge(
    *,
    challenge_id: str,
    client_ip: str = "",
) -> dict:
    challenge = _get_active_challenge(challenge_id)
    return request_phone_challenge(
        phone=challenge.phone,
        purpose=challenge.purpose,
        client_ip=client_ip,
        existing=challenge,
    )


def verify_phone_code(*, challenge_id: str, code: str = "") -> PhoneVerificationChallenge:
    challenge = _get_active_challenge(challenge_id)
    if challenge.channel == PhoneVerificationChallenge.Channel.RECEIVE:
        return _verify_receive_call(challenge)

    cleaned_code = "".join(character for character in (code or "") if character.isdigit())
    if len(cleaned_code) < 4:
        raise PhoneVerificationError("Введите код из 4 цифр")

    if challenge.verify_attempts >= settings.PHONE_VERIFICATION_MAX_ATTEMPTS:
        raise PhoneVerificationError("Слишком много попыток. Запросите код заново.")

    expected = _hash_code(
        challenge.phone,
        cleaned_code[-4:] if challenge.channel == PhoneVerificationChallenge.Channel.CALL else cleaned_code,
    )
    challenge.verify_attempts += 1
    if not hmac.compare_digest(challenge.code_hash, expected):
        challenge.save(update_fields=["verify_attempts", "updated_at"])
        remaining = settings.PHONE_VERIFICATION_MAX_ATTEMPTS - challenge.verify_attempts
        if remaining <= 0:
            raise PhoneVerificationError("Слишком много попыток. Запросите код заново.")
        raise PhoneVerificationError("Неверный код подтверждения")

    challenge.verified_at = timezone.now()
    challenge.save(update_fields=["verify_attempts", "verified_at", "updated_at"])
    return challenge


def consume_verified_challenge(
    *,
    challenge_id: str | None,
    phone: str | None,
    purpose: str,
    code: str | None = None,
) -> PhoneVerificationChallenge:
    if not is_phone_verification_enabled():
        raise PhoneVerificationError("Подтверждение телефона сейчас отключено")

    if not challenge_id:
        raise PhoneVerificationError("Сначала подтвердите телефон")

    normalized = _require_phone(phone)
    purpose = _clean_purpose(purpose)
    challenge = _get_challenge(challenge_id)
    if challenge.phone != normalized or challenge.purpose != purpose:
        raise PhoneVerificationError("Подтверждение телефона не совпадает с данными регистрации")
    if challenge.consumed_at is not None:
        raise PhoneVerificationError("Этот код уже использован. Запросите новый.")
    if challenge.expires_at <= timezone.now():
        raise PhoneVerificationError("Срок действия кода истёк. Запросите новый.")

    if challenge.verified_at is None:
        if challenge.channel == PhoneVerificationChallenge.Channel.RECEIVE:
            challenge = verify_phone_code(challenge_id=str(challenge.id))
        elif not code:
            raise PhoneVerificationError("Введите код подтверждения телефона")
        else:
            challenge = verify_phone_code(challenge_id=str(challenge.id), code=code)

    challenge.consumed_at = timezone.now()
    challenge.save(update_fields=["consumed_at", "updated_at"])
    return challenge


def serialize_challenge(
    challenge: PhoneVerificationChallenge,
    *,
    include_debug_code: str | None = None,
) -> dict:
    now = timezone.now()
    cooldown = settings.PHONE_VERIFICATION_SEND_COOLDOWN_SECONDS
    elapsed = int((now - challenge.created_at).total_seconds())
    payload = {
        "challenge_id": str(challenge.id),
        "phone": challenge.phone,
        "purpose": challenge.purpose,
        "channel": challenge.channel,
        "detail": CHANNEL_HINTS.get(challenge.channel, "Код подтверждения отправлен."),
        "code_length": 4,
        "needs_code": challenge.channel != PhoneVerificationChallenge.Channel.RECEIVE,
        "receive_number": format_dial_number(challenge.receive_number) if challenge.receive_number else "",
        "expires_in": max(0, int((challenge.expires_at - now).total_seconds())),
        "resend_available_in": max(0, cooldown - elapsed),
        "can_try_next_channel": next_channel(challenge.channel) is not None,
        "verified": challenge.verified_at is not None,
    }
    if settings.GREENSMS_DEBUG and settings.GREENSMS_DEBUG_RETURN_CODE and include_debug_code:
        payload["debug_code"] = include_debug_code
    return payload


def _require_phone(phone: str | None) -> str:
    normalized = normalize_phone(phone)
    if not normalized:
        raise PhoneVerificationError("Укажите номер телефона")
    return normalized


def _clean_purpose(purpose: str) -> str:
    allowed = {choice.value for choice in PhoneVerificationChallenge.Purpose}
    cleaned = (purpose or PhoneVerificationChallenge.Purpose.REGISTER).strip()
    if cleaned not in allowed:
        raise PhoneVerificationError("Некорректная цель подтверждения")
    return cleaned


def _ensure_phone_available(phone: str, *, purpose: str) -> None:
    exists = User.objects.filter(phone__in=phone_identity_values(phone)).exists()
    if purpose == PhoneVerificationChallenge.Purpose.REGISTER:
        if exists:
            raise PhoneVerificationError("Аккаунт с таким телефоном уже существует")
        return
    if purpose == PhoneVerificationChallenge.Purpose.LOGIN and not exists:
        raise PhoneVerificationError("Аккаунт с таким телефоном не найден")


def _enforce_rate_limits(*, phone: str, client_ip: str, skip_cooldown: bool = False) -> None:
    now = timezone.now()
    if not skip_cooldown:
        cooldown = now - timedelta(seconds=settings.PHONE_VERIFICATION_SEND_COOLDOWN_SECONDS)
        if PhoneVerificationChallenge.objects.filter(phone=phone, created_at__gte=cooldown).exists():
            raise PhoneVerificationError("Код уже отправлен. Подождите минуту перед повторной отправкой.")

    hour_ago = now - timedelta(hours=1)
    recent_phone = PhoneVerificationChallenge.objects.filter(phone=phone, created_at__gte=hour_ago).count()
    if recent_phone >= settings.PHONE_VERIFICATION_MAX_SENDS_PER_HOUR:
        raise PhoneVerificationError("Слишком много запросов на этот номер. Попробуйте позже.")

    if client_ip:
        recent_ip = PhoneVerificationChallenge.objects.filter(
            client_ip=client_ip,
            created_at__gte=hour_ago,
        ).count()
        if recent_ip >= settings.PHONE_VERIFICATION_MAX_SENDS_PER_IP_HOUR:
            raise PhoneVerificationError("Слишком много запросов. Попробуйте позже.")


def _verify_receive_call(challenge: PhoneVerificationChallenge) -> PhoneVerificationChallenge:
    if not challenge.greensms_request_id:
        raise PhoneVerificationError("Не удалось проверить обратный звонок. Запросите номер заново.")
    try:
        confirmed = is_receive_call_confirmed(challenge.greensms_request_id)
    except GreenSMSError as error:
        raise PhoneVerificationError(str(error), status_code=503) from error
    if not confirmed:
        raise PhoneVerificationError("Звонок ещё не поступил. Позвоните на указанный номер.")

    challenge.verified_at = timezone.now()
    challenge.save(update_fields=["verified_at", "updated_at"])
    return challenge


def has_active_phone_challenge(challenge_id: str | None) -> bool:
    if not (challenge_id or "").strip():
        return False
    try:
        _get_active_challenge(challenge_id)
    except PhoneVerificationError:
        return False
    return True


def _get_active_challenge(challenge_id: str) -> PhoneVerificationChallenge:
    challenge = _get_challenge(challenge_id)
    if challenge.consumed_at is not None:
        raise PhoneVerificationError("Этот код уже использован. Запросите новый.")
    if challenge.expires_at <= timezone.now():
        raise PhoneVerificationError("Срок действия кода истёк. Запросите новый.")
    return challenge


def _get_challenge(challenge_id: str) -> PhoneVerificationChallenge:
    try:
        uuid_value = UUID(str(challenge_id))
    except (TypeError, ValueError) as error:
        raise PhoneVerificationError("Некорректный идентификатор подтверждения") from error

    challenge = PhoneVerificationChallenge.objects.filter(id=uuid_value).first()
    if challenge is None:
        raise PhoneVerificationError("Запросите код подтверждения заново")
    return challenge


def _hash_code(phone: str, code: str) -> str:
    material = f"{settings.SECRET_KEY}:phone-otp:{phone}:{code}".encode("utf-8")
    return hashlib.sha256(material).hexdigest()
