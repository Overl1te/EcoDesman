import hashlib
import hmac
from datetime import timedelta

from django.conf import settings
from django.db import IntegrityError, transaction
from django.utils import timezone

from .email_otp import EmailOtpError, generate_email_code, is_email_otp_enabled, send_email_otp
from .greensms import (
    CHANNEL_ORDER,
    GreenSMSError,
    format_dial_number,
    is_phone_verification_enabled,
    send_verification_code,
)
from .models import PhoneVerificationChallenge, User
from .phone_verification import (
    PhoneVerificationError,
    _get_active_challenge,
    _get_challenge,
    _verify_receive_call,
)
from .services import (
    create_passwordless_user,
    get_user_by_identifier,
    identifier_is_email,
    identifier_is_phone,
    normalize_email,
    normalize_phone,
)


AUTH_CHANNELS = (*CHANNEL_ORDER, "email")

CHANNEL_HINTS = {
    "telegram": "Код отправлен в Telegram. Если сообщения нет, выберите другой способ.",
    "call": "Вам поступит короткий звонок. Введите последние 4 цифры входящего номера.",
    "receive": "Позвоните на этот номер со своего телефона. Вызов можно сбросить после соединения.",
    "email": "Код отправлен на почту. Если письма нет, проверьте спам или выберите другой способ.",
}

CHANNEL_LABELS = {
    "telegram": "Код в Telegram",
    "call": "Код в номере",
    "receive": "Обратный звонок",
    "email": "Код на почту",
}


class AuthChallengeError(PhoneVerificationError):
    pass


def load_active_challenge(challenge_id: str) -> PhoneVerificationChallenge:
    return _get_active_challenge(challenge_id)


def request_auth_challenge(
    *,
    identifier: str = "",
    channel: str | None = None,
    extra_phone: str | None = None,
    extra_email: str | None = None,
    existing: PhoneVerificationChallenge | None = None,
    client_ip: str = "",
) -> dict:
    if existing is not None:
        phone = normalize_phone(extra_phone) or existing.phone or None
        email = _clean_email(extra_email) or existing.email or None
        purpose = existing.purpose
        identifier_kind = "email" if email and not extra_phone else "phone"
    else:
        phone, email, user, identifier_kind = _resolve_contacts(
            identifier,
            extra_phone=extra_phone,
            extra_email=extra_email,
        )
        purpose = PhoneVerificationChallenge.Purpose.AUTH
        if user is None and identifier_kind == "username":
            raise AuthChallengeError("Не удалось найти аккаунт с таким логином")
        if not phone and not email:
            if user is not None:
                raise AuthChallengeError("У этого аккаунта нет почты и телефона для входа")
            raise AuthChallengeError("Укажите почту, телефон или логин")

    requested = (channel or "").strip().lower() or None
    if requested and requested not in AUTH_CHANNELS:
        raise AuthChallengeError("Неизвестный способ подтверждения")

    if not requested:
        requested = _default_channel(kind=identifier_kind, phone=phone, email=email)

    if requested == "email":
        if not email:
            raise AuthChallengeError("Укажите электронную почту")
        if not is_email_otp_enabled():
            raise AuthChallengeError("Отправка кода на почту сейчас недоступна", status_code=503)
    else:
        if not phone:
            raise AuthChallengeError("Укажите номер телефона")
        if not is_phone_verification_enabled():
            raise AuthChallengeError("Подтверждение по телефону сейчас недоступно", status_code=503)

    _enforce_rate_limits(
        phone=phone or "",
        email=email or "",
        client_ip=client_ip,
        skip_cooldown=existing is not None,
    )

    debug_code = ""
    greensms_request_id = ""
    receive_number = ""
    code_hash = ""

    if requested == "email":
        debug_code = generate_email_code()
        try:
            send_email_otp(email, debug_code)
        except EmailOtpError as error:
            raise AuthChallengeError(str(error), status_code=503) from error
        code_hash = _hash_code(identity=email, code=debug_code)
    else:
        try:
            result = send_verification_code(
                phone,
                start_channel=requested,
                cascade=existing is None and requested == "telegram",
            )
        except GreenSMSError as error:
            raise AuthChallengeError(str(error), status_code=503) from error
        requested = result.channel
        greensms_request_id = result.request_id
        receive_number = result.dial_number
        debug_code = result.code
        if result.code:
            code_hash = _hash_code(identity=phone, code=result.code)

    now = timezone.now()
    challenge = PhoneVerificationChallenge.objects.create(
        phone=phone or "",
        email=email or "",
        purpose=purpose,
        channel=requested,
        code_hash=code_hash,
        greensms_request_id=greensms_request_id,
        receive_number=receive_number,
        client_ip=client_ip or None,
        expires_at=now + timedelta(seconds=settings.PHONE_VERIFICATION_CODE_TTL_SECONDS),
    )
    return serialize_auth_challenge(challenge, include_debug_code=debug_code)


def verify_auth_challenge(*, challenge_id: str, code: str = "") -> PhoneVerificationChallenge:
    challenge = _get_active_challenge(challenge_id)
    if challenge.channel == PhoneVerificationChallenge.Channel.RECEIVE:
        return _verify_receive_call(challenge)

    cleaned_code = "".join(character for character in (code or "") if character.isdigit())
    if len(cleaned_code) < 4:
        raise AuthChallengeError("Введите код из 4 цифр")

    if challenge.verify_attempts >= settings.PHONE_VERIFICATION_MAX_ATTEMPTS:
        raise AuthChallengeError("Слишком много попыток. Запросите код заново.")

    if challenge.channel == PhoneVerificationChallenge.Channel.CALL:
        cleaned_code = cleaned_code[-4:]

    identity = (
        challenge.email
        if challenge.channel == PhoneVerificationChallenge.Channel.EMAIL
        else challenge.phone
    )
    expected = _hash_code(identity=identity, code=cleaned_code)
    challenge.verify_attempts += 1
    if not hmac.compare_digest(challenge.code_hash, expected):
        challenge.save(update_fields=["verify_attempts", "updated_at"])
        remaining = settings.PHONE_VERIFICATION_MAX_ATTEMPTS - challenge.verify_attempts
        if remaining <= 0:
            raise AuthChallengeError("Слишком много попыток. Запросите код заново.")
        raise AuthChallengeError("Неверный код подтверждения")

    challenge.verified_at = timezone.now()
    challenge.save(update_fields=["verify_attempts", "verified_at", "updated_at"])
    return challenge


def complete_auth_challenge(
    *,
    challenge_id: str,
    code: str = "",
) -> tuple[User, bool]:
    challenge = _get_challenge(challenge_id)
    if challenge.consumed_at is not None:
        raise AuthChallengeError("Этот код уже использован. Запросите новый.")
    if challenge.expires_at <= timezone.now():
        raise AuthChallengeError("Срок действия кода истёк. Запросите новый.")

    if challenge.verified_at is None:
        challenge = verify_auth_challenge(challenge_id=challenge_id, code=code)

    user = _find_user_for_challenge(challenge)
    created = False
    if user is None:
        try:
            with transaction.atomic():
                user = create_passwordless_user(
                    email=challenge.email or None,
                    phone=challenge.phone or None,
                )
                created = True
        except IntegrityError:
            user = _find_user_for_challenge(challenge)
            if user is None:
                raise AuthChallengeError("Не удалось создать аккаунт. Попробуйте ещё раз.")

    if user.is_banned:
        raise AuthChallengeError("Аккаунт заблокирован", status_code=403)

    update_fields: list[str] = []
    if challenge.phone and not user.phone:
        user.phone = challenge.phone
        update_fields.append("phone")
    if challenge.phone and user.phone_verified_at is None:
        user.phone_verified_at = timezone.now()
        update_fields.append("phone_verified_at")
    if challenge.email and not user.email:
        user.email = challenge.email
        update_fields.append("email")
    if update_fields:
        update_fields.append("updated_at")
        try:
            user.save(update_fields=update_fields)
        except IntegrityError:
            user.refresh_from_db()

    challenge.consumed_at = timezone.now()
    challenge.save(update_fields=["consumed_at", "updated_at"])
    return user, created


def serialize_auth_challenge(
    challenge: PhoneVerificationChallenge,
    *,
    include_debug_code: str | None = None,
) -> dict:
    now = timezone.now()
    cooldown = settings.PHONE_VERIFICATION_SEND_COOLDOWN_SECONDS
    elapsed = int((now - challenge.created_at).total_seconds())
    available = _available_channels(phone=challenge.phone, email=challenge.email)
    payload = {
        "challenge_id": str(challenge.id),
        "phone": challenge.phone,
        "email": challenge.email,
        "purpose": challenge.purpose,
        "channel": challenge.channel,
        "detail": CHANNEL_HINTS.get(challenge.channel, "Код подтверждения отправлен."),
        "code_length": 4,
        "needs_code": challenge.channel != PhoneVerificationChallenge.Channel.RECEIVE,
        "receive_number": format_dial_number(challenge.receive_number) if challenge.receive_number else "",
        "expires_in": max(0, int((challenge.expires_at - now).total_seconds())),
        "resend_available_in": max(0, cooldown - elapsed),
        "can_try_next_channel": len(available) > 1,
        "available_channels": available,
        "channel_labels": {key: CHANNEL_LABELS[key] for key in available},
        "verified": challenge.verified_at is not None,
    }
    if (
        (settings.GREENSMS_DEBUG and settings.GREENSMS_DEBUG_RETURN_CODE and challenge.channel != "email")
        or (settings.EMAIL_OTP_DEBUG and challenge.channel == "email")
    ) and include_debug_code:
        payload["debug_code"] = include_debug_code
    return payload


def auth_public_config() -> dict:
    channels = []
    if is_phone_verification_enabled():
        channels.extend(CHANNEL_ORDER)
    if is_email_otp_enabled():
        channels.append("email")
    return {
        "passwordless": True,
        "channels": channels,
    }


def _resolve_contacts(
    identifier: str,
    *,
    extra_phone: str | None,
    extra_email: str | None,
) -> tuple[str | None, str | None, User | None, str]:
    raw = (identifier or "").strip()
    user = get_user_by_identifier(raw) if raw else None
    phone = normalize_phone(extra_phone)
    email = _clean_email(extra_email)

    if identifier_is_phone(raw):
        kind = "phone"
        phone = phone or normalize_phone(raw)
    elif identifier_is_email(raw):
        kind = "email"
        email = email or normalize_email(raw)
    elif raw:
        kind = "username"
    else:
        kind = "unknown"

    if user:
        phone = phone or user.phone
        email = email or user.email

    return phone, email, user, kind


def _default_channel(*, kind: str, phone: str | None, email: str | None) -> str:
    prefer_email = kind in {"email", "username"}
    if prefer_email:
        if email and is_email_otp_enabled():
            return "email"
        if phone and is_phone_verification_enabled():
            return "telegram"
        if email:
            return "email"
        if phone:
            return "telegram"
    else:
        if phone and is_phone_verification_enabled():
            return "telegram"
        if email and is_email_otp_enabled():
            return "email"
        if phone:
            return "telegram"
        if email:
            return "email"
    raise AuthChallengeError("Укажите почту, телефон или логин")


def _available_channels(*, phone: str, email: str) -> list[str]:
    channels: list[str] = []
    if phone and is_phone_verification_enabled():
        channels.extend(CHANNEL_ORDER)
    if email and is_email_otp_enabled():
        channels.append("email")
    return channels


def _clean_email(value: str | None) -> str:
    if not value:
        return ""
    return normalize_email(value)


def _find_user_for_challenge(challenge: PhoneVerificationChallenge) -> User | None:
    if challenge.phone:
        user = get_user_by_identifier(challenge.phone)
        if user:
            return user
    if challenge.email:
        return get_user_by_identifier(challenge.email)
    return None


def _enforce_rate_limits(*, phone: str, email: str, client_ip: str, skip_cooldown: bool = False) -> None:
    now = timezone.now()
    if not skip_cooldown:
        cooldown = now - timedelta(seconds=settings.PHONE_VERIFICATION_SEND_COOLDOWN_SECONDS)
        query = PhoneVerificationChallenge.objects.filter(created_at__gte=cooldown)
        if phone:
            query = query.filter(phone=phone)
        elif email:
            query = query.filter(email=email)
        if query.exists():
            raise AuthChallengeError("Код уже отправлен. Подождите минуту перед повторной отправкой.")

    hour_ago = now - timedelta(hours=1)
    identity_query = PhoneVerificationChallenge.objects.filter(created_at__gte=hour_ago)
    if phone:
        identity_query = identity_query.filter(phone=phone)
    elif email:
        identity_query = identity_query.filter(email=email)
    if identity_query.count() >= settings.PHONE_VERIFICATION_MAX_SENDS_PER_HOUR:
        raise AuthChallengeError("Слишком много запросов. Попробуйте позже.")

    if client_ip:
        recent_ip = PhoneVerificationChallenge.objects.filter(
            client_ip=client_ip,
            created_at__gte=hour_ago,
        ).count()
        if recent_ip >= settings.PHONE_VERIFICATION_MAX_SENDS_PER_IP_HOUR:
            raise AuthChallengeError("Слишком много запросов. Попробуйте позже.")


def _hash_code(*, identity: str, code: str) -> str:
    material = f"{settings.SECRET_KEY}:auth-otp:{identity}:{code}".encode("utf-8")
    return hashlib.sha256(material).hexdigest()
