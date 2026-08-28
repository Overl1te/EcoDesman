import logging
import secrets

from django.conf import settings
from django.core.mail import send_mail

logger = logging.getLogger(__name__)


class EmailOtpError(Exception):
    def __init__(self, message: str = "Не удалось отправить код на почту"):
        super().__init__(message)


def is_email_otp_enabled() -> bool:
    if settings.EMAIL_OTP_DEBUG:
        return True
    return bool(settings.EMAIL_HOST)


def generate_email_code() -> str:
    return f"{secrets.randbelow(10000):04d}"


def send_email_otp(email: str, code: str) -> None:
    if settings.EMAIL_OTP_DEBUG:
        logger.info("Email OTP debug for %s: %s", email, code)
        return

    from_email = settings.DEFAULT_FROM_EMAIL or settings.EMAIL_HOST_USER
    if not from_email:
        raise EmailOtpError("Отправка писем не настроена")

    try:
        sent = send_mail(
            subject="Код входа в ЭкоВыхухоль",
            message=f"Ваш код: {code}\nОн действует несколько минут. Если это были не вы, просто игнорируйте письмо.",
            from_email=from_email,
            recipient_list=[email],
            fail_silently=False,
        )
    except Exception as error:
        logger.warning("Failed to send login email to %s: %s", email, error)
        raise EmailOtpError("Не удалось отправить код на почту") from error

    if not sent:
        raise EmailOtpError("Не удалось отправить код на почту")
