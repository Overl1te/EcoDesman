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


def normalize_phone(phone: str | None) -> str | None:
    if phone is None:
        return None

    raw_value = phone.strip()
    if not raw_value:
        return None

    has_plus = raw_value.startswith("+")
    digits = "".join(character for character in raw_value if character.isdigit())
    if not digits:
        return None

    if has_plus:
        return f"+{digits}"

    if len(digits) == 11 and digits.startswith("8"):
        return f"+7{digits[1:]}"

    if len(digits) == 11 and digits.startswith("7"):
        return f"+{digits}"

    return digits


def is_reserved_public_username(username: str) -> bool:
    return normalize_username(username) in PUBLIC_ROUTE_RESERVED_USERNAMES


def get_user_by_identifier(identifier: str) -> User | None:
    normalized = identifier.strip()
    if not normalized:
        return None

    normalized_phone = normalize_phone(normalized)
    identifier_query = Q(email__iexact=normalized) | Q(username__iexact=normalized)
    if normalized_phone:
        identifier_query |= Q(phone__iexact=normalized_phone)

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
