from django.contrib.auth.password_validation import validate_password
from django.db.models import Q
from django.utils import timezone
from rest_framework_simplejwt.token_blacklist.models import BlacklistedToken, OutstandingToken
from rest_framework_simplejwt.tokens import RefreshToken

from .models import User

PUBLIC_ROUTE_RESERVED_USERNAMES = frozenset(
    {
        "_next",
        "admin",
        "api",
        "auth",
        "download",
        "events",
        "favorites",
        "favicon.ico",
        "fonts",
        "help",
        "login",
        "logout",
        "map",
        "notifications",
        "posts",
        "profile",
        "profiles",
        "register",
        "robots.txt",
        "settings",
        "sitemap.xml",
        "support",
    }
)


def normalize_username(username: str) -> str:
    return username.strip().lower()


def normalize_email(email: str) -> str:
    return email.strip().lower()


def _digits_only(value: str) -> str:
    return "".join(character for character in value if character.isdigit())


def ru_local_phone_digits(phone: str) -> str:
    """Return up to 10 Russian national digits, stripping +7 / 8 prefixes."""
    raw_value = phone.strip()
    digits = _digits_only(raw_value)
    if not digits or digits in {"7", "8"}:
        return ""

    original_length = len(digits)
    had_plus = "+" in raw_value

    while len(digits) > 10 and digits[0] in "78":
        digits = digits[1:]

    if had_plus and original_length <= 10 and digits.startswith("7"):
        digits = digits[1:]
        if digits == "7":
            digits = ""

    return digits[:10]


def phone_identity_values(phone: str | None) -> list[str]:
    if phone is None:
        return []

    local = ru_local_phone_digits(phone)
    if len(local) == 10:
        return [f"+7{local}", f"8{local}", f"7{local}", local]

    normalized = normalize_phone(phone)
    return [normalized] if normalized else []


def normalize_phone(phone: str | None) -> str | None:
    if phone is None:
        return None

    raw_value = phone.strip()
    if not raw_value:
        return None

    local = ru_local_phone_digits(raw_value)
    if len(local) == 10:
        return f"+7{local}"

    digits = _digits_only(raw_value)
    if not digits:
        return None

    if raw_value.startswith("+"):
        return f"+{digits}"

    return digits


def is_reserved_public_username(username: str) -> bool:
    return normalize_username(username) in PUBLIC_ROUTE_RESERVED_USERNAMES


def identifier_is_phone(identifier: str) -> bool:
    normalized = identifier.strip()
    if not normalized or "@" in normalized:
        return False
    if any(character.isalpha() for character in normalized):
        return False
    return len(ru_local_phone_digits(normalized)) == 10


def get_user_by_identifier(identifier: str) -> User | None:
    normalized = identifier.strip()
    if not normalized:
        return None

    identifier_query = Q(email__iexact=normalized) | Q(username__iexact=normalized)
    if identifier_is_phone(normalized):
        phone_values = phone_identity_values(normalized)
        if phone_values:
            identifier_query |= Q(phone__in=phone_values)

    return (
        User.objects.filter(identifier_query)
        .order_by("id")
        .first()
    )


def authenticate_user(identifier: str, password: str) -> User | None:
    user = get_user_by_identifier(identifier)
    if not user or not user.is_active:
        return None

    if not user.check_password(password):
        return None

    return user


def create_user_account(
    *,
    username: str,
    email: str,
    password: str,
    display_name: str = "",
    phone: str | None = None,
    phone_verified: bool = False,
    accept_terms: bool,
    accept_privacy_policy: bool,
    accept_personal_data: bool,
    accept_public_personal_data_distribution: bool = False,
) -> User:
    normalized_username = normalize_username(username)
    normalized_email = normalize_email(email)
    normalized_phone = normalize_phone(phone)

    temp_user = User(
        username=normalized_username,
        email=normalized_email,
        display_name=display_name.strip(),
        phone=normalized_phone,
    )
    validate_password(password, user=temp_user)

    accepted_at = timezone.now()

    user = User.objects.create_user(
        username=normalized_username,
        email=normalized_email,
        password=password,
        display_name=display_name.strip(),
        phone=normalized_phone,
        phone_verified_at=accepted_at if phone_verified and normalized_phone else None,
        terms_accepted_at=accepted_at if accept_terms else None,
        privacy_policy_accepted_at=accepted_at if accept_privacy_policy else None,
        personal_data_consent_accepted_at=accepted_at if accept_personal_data else None,
        public_personal_data_consent_accepted_at=(
            accepted_at if accept_public_personal_data_distribution else None
        ),
    )
    if not user.display_name:
        user.display_name = user.username
        user.save(update_fields=["display_name"])
    return user


def can_manage_posts(user) -> bool:
    return bool(user and user.is_authenticated and user.is_post_manager)


def can_administrate(user) -> bool:
    return bool(user and user.is_authenticated and user.is_admin_role)


def can_access_support(user) -> bool:
    return bool(user and user.is_authenticated and user.can_access_support)


def blacklist_refresh_token(refresh_token: str) -> None:
    token = RefreshToken(refresh_token)
    token.blacklist()


def blacklist_user_refresh_tokens(user: User) -> None:
    for outstanding_token in OutstandingToken.objects.filter(user=user):
        BlacklistedToken.objects.get_or_create(token=outstanding_token)


def issue_warning(target: User) -> User:
    target.warning_count += 1
    if target.warning_count >= 5:
        target.is_active = False
        target.banned_at = timezone.now()
        blacklist_user_refresh_tokens(target)
    target.save(update_fields=["warning_count", "is_active", "banned_at"])
    return target


def ban_user(target: User) -> User:
    target.is_active = False
    target.banned_at = timezone.now()
    blacklist_user_refresh_tokens(target)
    target.save(update_fields=["is_active", "banned_at"])
    return target


def unban_user(target: User) -> User:
    target.is_active = True
    target.banned_at = None
    target.warning_count = 0
    target.save(update_fields=["is_active", "banned_at", "warning_count"])
    return target


def update_user_role(target: User, role: str) -> User:
    target.role = role
    target.save(update_fields=["role"])
    return target
