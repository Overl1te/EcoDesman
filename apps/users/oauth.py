from __future__ import annotations

import json
from dataclasses import dataclass
from urllib.error import HTTPError, URLError
from urllib.parse import urlencode
from urllib.request import Request, urlopen

from django.conf import settings
from django.db import transaction
from django.utils import timezone

from .models import User, UserSocialAccount
from .services import is_reserved_public_username, normalize_email, normalize_username


class SocialAuthError(Exception):
    pass


@dataclass(frozen=True)
class SocialProfile:
    provider: str
    provider_user_id: str
    email: str
    display_name: str
    avatar_url: str = ""


def get_provider_config(provider: str) -> dict:
    config = settings.SOCIAL_AUTH_PROVIDERS.get(provider)
    if not config:
        raise SocialAuthError("Unknown social auth provider")
    return config


def list_social_providers(*, redirect_uri: str = "", state: str = "") -> list[dict]:
    providers = []
    for provider, config in settings.SOCIAL_AUTH_PROVIDERS.items():
        item = {
            "id": provider,
            "label": config["label"],
            "enabled": bool(config.get("client_id")),
            "scope": config.get("scope", ""),
        }
        if redirect_uri and config.get("client_id"):
            item["authorization_url"] = build_authorization_url(
                provider,
                redirect_uri=redirect_uri,
                state=state,
            )
        providers.append(item)
    return providers


def build_authorization_url(provider: str, *, redirect_uri: str, state: str = "") -> str:
    config = get_provider_config(provider)
    client_id = config.get("client_id")
    if not client_id:
        raise SocialAuthError("Social auth provider is not configured")

    params = {
        "client_id": client_id,
        "redirect_uri": redirect_uri,
        "response_type": "code",
        "scope": config.get("scope", ""),
    }
    if state:
        params["state"] = state
    if provider == "yandex":
        params["force_confirm"] = "yes"
    if provider == "vk":
        params["v"] = config.get("api_version", "5.199")
    return f"{config['auth_url']}?{urlencode(params)}"


def fetch_json(
    url: str,
    *,
    method: str = "GET",
    data: dict | None = None,
    headers: dict | None = None,
) -> dict:
    body = None
    request_headers = {"Accept": "application/json", **(headers or {})}
    if data is not None:
        body = urlencode(data).encode("utf-8")
        request_headers.setdefault("Content-Type", "application/x-www-form-urlencoded")

    request = Request(url, data=body, headers=request_headers, method=method)
    try:
        with urlopen(request, timeout=10) as response:
            payload = response.read().decode("utf-8")
    except HTTPError as error:
        detail = error.read().decode("utf-8", errors="replace")
        raise SocialAuthError(f"Social provider returned HTTP {error.code}: {detail}") from error
    except URLError as error:
        raise SocialAuthError("Social provider is unavailable") from error

    try:
        return json.loads(payload)
    except json.JSONDecodeError as error:
        raise SocialAuthError("Social provider returned invalid JSON") from error


def exchange_code_for_token(provider: str, *, code: str, redirect_uri: str) -> dict:
    config = get_provider_config(provider)
    if not config.get("client_id") or not config.get("client_secret"):
        raise SocialAuthError("Social auth provider is not configured")
    if not redirect_uri:
        raise SocialAuthError("redirect_uri is required for code exchange")

    payload = {
        "grant_type": "authorization_code",
        "code": code,
        "redirect_uri": redirect_uri,
        "client_id": config["client_id"],
        "client_secret": config["client_secret"],
    }
    return fetch_json(config["token_url"], method="POST", data=payload)


def fetch_social_profile(provider: str, *, access_token: str, email_hint: str = "") -> SocialProfile:
    config = get_provider_config(provider)
    if provider == "google":
        payload = fetch_json(
            config["userinfo_url"],
            headers={"Authorization": f"Bearer {access_token}"},
        )
        provider_user_id = str(payload.get("sub") or "")
        email = payload.get("email") or email_hint
        name = payload.get("name") or payload.get("email") or ""
        avatar_url = payload.get("picture") or ""
    elif provider == "yandex":
        payload = fetch_json(
            config["userinfo_url"],
            headers={"Authorization": f"OAuth {access_token}"},
        )
        provider_user_id = str(payload.get("id") or "")
        email = payload.get("default_email") or email_hint
        name = payload.get("real_name") or payload.get("display_name") or payload.get("login") or ""
        avatar_id = payload.get("default_avatar_id")
        avatar_url = f"https://avatars.yandex.net/get-yapic/{avatar_id}/islands-200" if avatar_id else ""
    elif provider == "vk":
        params = urlencode(
            {
                "access_token": access_token,
                "fields": "photo_200",
                "v": config.get("api_version", "5.199"),
            }
        )
        payload = fetch_json(f"{config['userinfo_url']}?{params}")
        if payload.get("error"):
            raise SocialAuthError(payload["error"].get("error_msg") or "VK profile request failed")
        user_data = (payload.get("response") or [{}])[0]
        provider_user_id = str(user_data.get("id") or "")
        email = email_hint
        name = " ".join(
            part for part in (user_data.get("first_name"), user_data.get("last_name")) if part
        )
        avatar_url = user_data.get("photo_200") or ""
    else:
        raise SocialAuthError("Unknown social auth provider")

    if not provider_user_id:
        raise SocialAuthError("Social provider did not return user id")

    return SocialProfile(
        provider=provider,
        provider_user_id=provider_user_id,
        email=normalize_email(email) if email else "",
        display_name=name.strip(),
        avatar_url=avatar_url,
    )


def _build_unique_username(profile: SocialProfile) -> str:
    email_prefix = profile.email.split("@", 1)[0] if profile.email else ""
    raw_base = email_prefix or profile.display_name or f"{profile.provider}_{profile.provider_user_id}"
    base = "".join(
        character.lower()
        for character in raw_base.replace(" ", "_")
        if character.isalnum() or character in {"_", ".", "+", "-"}
    ).strip("._+-")
    username = normalize_username(base)[:140] or f"{profile.provider}_{profile.provider_user_id}"[:140]
    if is_reserved_public_username(username):
        username = f"{username}_{profile.provider}"

    candidate = username
    suffix = 2
    while User.objects.filter(username__iexact=candidate).exists():
        candidate = f"{username[:135]}_{suffix}"
        suffix += 1
    return candidate


@transaction.atomic
def login_or_create_social_user(
    profile: SocialProfile,
    *,
    accept_terms: bool = False,
    accept_privacy_policy: bool = False,
    accept_personal_data: bool = False,
    accept_public_personal_data_distribution: bool = False,
) -> tuple[User, bool]:
    social_account = (
        UserSocialAccount.objects.select_related("user")
        .filter(provider=profile.provider, provider_user_id=profile.provider_user_id)
        .first()
    )
    if social_account:
        _sync_social_account(social_account, profile)
        return social_account.user, False

    if not profile.email:
        raise SocialAuthError("Social provider did not return email")

    user = User.objects.filter(email__iexact=profile.email).first()
    created = False
    if user is None:
        if not (accept_terms and accept_privacy_policy and accept_personal_data):
            raise SocialAuthError("Legal acceptances are required for new social account")

        accepted_at = timezone.now()
        user = User(
            username=_build_unique_username(profile),
            email=profile.email,
            display_name=profile.display_name or profile.email.split("@", 1)[0],
            avatar_url=profile.avatar_url,
            terms_accepted_at=accepted_at,
            privacy_policy_accepted_at=accepted_at,
            personal_data_consent_accepted_at=accepted_at,
            public_personal_data_consent_accepted_at=(
                accepted_at if accept_public_personal_data_distribution else None
            ),
        )
        user.set_unusable_password()
        user.save()
        created = True
    else:
        update_fields = []
        if not user.display_name and profile.display_name:
            user.display_name = profile.display_name
            update_fields.append("display_name")
        if not user.avatar_url and profile.avatar_url:
            user.avatar_url = profile.avatar_url
            update_fields.append("avatar_url")
        if update_fields:
            user.save(update_fields=update_fields)

    UserSocialAccount.objects.create(
        user=user,
        provider=profile.provider,
        provider_user_id=profile.provider_user_id,
        email=profile.email,
        display_name=profile.display_name,
        avatar_url=profile.avatar_url,
    )
    return user, created


def _sync_social_account(social_account: UserSocialAccount, profile: SocialProfile) -> None:
    update_fields = []
    for field_name in ("email", "display_name", "avatar_url"):
        next_value = getattr(profile, field_name)
        if next_value and getattr(social_account, field_name) != next_value:
            setattr(social_account, field_name, next_value)
            update_fields.append(field_name)
    if update_fields:
        social_account.save(update_fields=update_fields)
