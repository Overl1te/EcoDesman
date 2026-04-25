from urllib.parse import parse_qsl, urlencode, urlsplit, urlunsplit

from django.contrib.auth.password_validation import validate_password
from rest_framework import serializers
from rest_framework.exceptions import PermissionDenied
from rest_framework_simplejwt.exceptions import InvalidToken, TokenError
from rest_framework_simplejwt.serializers import TokenRefreshSerializer
from rest_framework_simplejwt.settings import api_settings
from rest_framework_simplejwt.tokens import RefreshToken

from ..models import User
from ..selectors import get_profile_stats
from ..services import (
    create_user_account,
    is_reserved_public_username,
    normalize_email,
    normalize_username,
)
from ..validation import (
    PROFILE_BIO_MAX_LENGTH,
    clean_avatar_position,
    clean_avatar_scale,
    clean_plain_text,
    normalize_social_url,
)


class UserStatsSerializer(serializers.Serializer):
    posts_count = serializers.IntegerField()
    likes_given_count = serializers.IntegerField()
    likes_received_count = serializers.IntegerField()
    comments_count = serializers.IntegerField()
    views_received_count = serializers.IntegerField()


def build_versioned_media_url(url: str, updated_at) -> str:
    if not url or updated_at is None:
        return url

    parts = urlsplit(url)
    query = dict(parse_qsl(parts.query, keep_blank_values=True))
    query["v"] = str(int(updated_at.timestamp()))
    return urlunsplit(
        (parts.scheme, parts.netloc, parts.path, urlencode(query), parts.fragment)
    )


class UserSummarySerializer(serializers.ModelSerializer):
    name = serializers.CharField(source="display_name")
    avatar_url = serializers.SerializerMethodField()
    is_banned = serializers.BooleanField(read_only=True)

    class Meta:
        model = User
        fields = (
            "id",
            "name",
            "username",
            "role",
            "status_text",
            "avatar_url",
            "avatar_position_x",
            "avatar_position_y",
            "avatar_scale",
            "warning_count",
            "is_banned",
        )

    def get_avatar_url(self, obj: User) -> str:
        return build_versioned_media_url(obj.avatar_url, obj.updated_at)


class CurrentUserSerializer(serializers.ModelSerializer):
    name = serializers.CharField(source="display_name")
    avatar_url = serializers.SerializerMethodField()
    stats = serializers.SerializerMethodField()
    is_banned = serializers.BooleanField(read_only=True)
    can_access_admin = serializers.BooleanField(source="is_admin_role", read_only=True)
    can_access_support = serializers.BooleanField(read_only=True)

    class Meta:
        model = User
        fields = (
            "id",
            "name",
            "username",
            "email",
            "avatar_url",
            "avatar_position_x",
            "avatar_position_y",
            "avatar_scale",
            "role",
            "status_text",
            "bio",
            "city",
            "telegram_url",
            "vk_url",
            "instagram_url",
            "max_url",
            "warning_count",
            "is_banned",
            "can_access_admin",
            "can_access_support",
            "stats",
        )

    def get_stats(self, obj: User) -> dict[str, int]:
        request = self.context.get("request")
        return get_profile_stats(obj, viewer=getattr(request, "user", None))

    def get_avatar_url(self, obj: User) -> str:
        return build_versioned_media_url(obj.avatar_url, obj.updated_at)


class PublicProfileSerializer(serializers.ModelSerializer):
    name = serializers.CharField(source="display_name")
    avatar_url = serializers.SerializerMethodField()
    stats = serializers.SerializerMethodField()
    is_banned = serializers.BooleanField(read_only=True)
    can_access_admin = serializers.BooleanField(source="is_admin_role", read_only=True)
    can_access_support = serializers.BooleanField(read_only=True)

    class Meta:
        model = User
        fields = (
            "id",
            "name",
            "username",
            "avatar_url",
            "avatar_position_x",
            "avatar_position_y",
            "avatar_scale",
            "role",
            "status_text",
            "bio",
            "city",
            "telegram_url",
            "vk_url",
            "instagram_url",
            "max_url",
            "warning_count",
            "is_banned",
            "can_access_admin",
            "can_access_support",
            "stats",
        )

    def get_stats(self, obj: User) -> dict[str, int]:
        request = self.context.get("request")
        return get_profile_stats(obj, viewer=getattr(request, "user", None))

    def get_avatar_url(self, obj: User) -> str:
        return build_versioned_media_url(obj.avatar_url, obj.updated_at)


class LoginSerializer(serializers.Serializer):
    identifier = serializers.CharField()
    password = serializers.CharField(write_only=True, trim_whitespace=False)


class SocialLoginSerializer(serializers.Serializer):
    access_token = serializers.CharField(required=False, trim_whitespace=True)
    code = serializers.CharField(required=False, trim_whitespace=True)
    telegram_auth = serializers.DictField(required=False)
    redirect_uri = serializers.URLField(required=False)
    email = serializers.EmailField(required=False, allow_blank=True)
    accept_terms = serializers.BooleanField(required=False, default=False)
    accept_privacy_policy = serializers.BooleanField(required=False, default=False)
    accept_personal_data = serializers.BooleanField(required=False, default=False)
    accept_public_personal_data_distribution = serializers.BooleanField(required=False, default=False)

    def validate(self, attrs: dict) -> dict:
        if not attrs.get("access_token") and not attrs.get("code") and not attrs.get("telegram_auth"):
            raise serializers.ValidationError(
                {"access_token": ["access_token, code or telegram_auth is required"]},
            )
        if attrs.get("code") and not attrs.get("redirect_uri"):
            raise serializers.ValidationError(
                {"redirect_uri": ["redirect_uri is required when code is used"]},
            )
        return attrs


class AuthSessionSerializer(serializers.Serializer):
    access = serializers.CharField()
    refresh = serializers.CharField()
    user = CurrentUserSerializer()


class ProfileSettingsSerializer(serializers.ModelSerializer):
    username = serializers.CharField(required=False)
    email = serializers.EmailField(required=False)

    class Meta:
        model = User
        fields = (
            "username",
            "email",
            "display_name",
            "avatar_url",
            "avatar_position_x",
            "avatar_position_y",
            "avatar_scale",
            "status_text",
            "bio",
            "city",
            "telegram_url",
            "vk_url",
            "instagram_url",
            "max_url",
        )

    def validate_username(self, value: str) -> str:
        normalized = normalize_username(value)
        if not normalized:
            raise serializers.ValidationError("Введите username")

        User.username_validator(normalized)
        if is_reserved_public_username(normalized):
            raise serializers.ValidationError("Этот username зарезервирован")
        queryset = User.objects.exclude(pk=self.instance.pk).filter(
            username__iexact=normalized,
        )
        if queryset.exists():
            raise serializers.ValidationError("Этот username уже занят")
        return normalized

    def validate_email(self, value: str) -> str:
        normalized = normalize_email(value)
        queryset = User.objects.exclude(pk=self.instance.pk).filter(
            email__iexact=normalized,
        )
        if queryset.exists():
            raise serializers.ValidationError("Аккаунт с таким email уже существует")
        return normalized

    def validate_display_name(self, value: str) -> str:
        return clean_plain_text(value, max_length=120, field_label="Имя")

    def validate_status_text(self, value: str) -> str:
        return clean_plain_text(value, max_length=120, field_label="Статус")

    def validate_bio(self, value: str) -> str:
        return clean_plain_text(
            value,
            max_length=PROFILE_BIO_MAX_LENGTH,
            field_label="Описание",
            allow_newlines=True,
        )

    def validate_city(self, value: str) -> str:
        return clean_plain_text(value, max_length=120, field_label="Город")

    def validate_telegram_url(self, value: str) -> str:
        return normalize_social_url(value, "telegram_url")

    def validate_vk_url(self, value: str) -> str:
        return normalize_social_url(value, "vk_url")

    def validate_instagram_url(self, value: str) -> str:
        return normalize_social_url(value, "instagram_url")

    def validate_max_url(self, value: str) -> str:
        return normalize_social_url(value, "max_url")

    def validate_avatar_position_x(self, value: int) -> int:
        return clean_avatar_position(value)

    def validate_avatar_position_y(self, value: int) -> int:
        return clean_avatar_position(value)

    def validate_avatar_scale(self, value) -> float:
        return clean_avatar_scale(value)

    def update(self, instance: User, validated_data: dict) -> User:
        for field, value in validated_data.items():
            setattr(instance, field, value)

        if not instance.display_name:
            instance.display_name = instance.username

        instance.save()
        return instance


class RegisterSerializer(serializers.Serializer):
    username = serializers.CharField(min_length=3, max_length=150)
    email = serializers.EmailField()
    display_name = serializers.CharField(required=False, allow_blank=True, max_length=120)
    password = serializers.CharField(write_only=True, trim_whitespace=False, min_length=8)
    password_confirmation = serializers.CharField(write_only=True, trim_whitespace=False)
    accept_terms = serializers.BooleanField()
    accept_privacy_policy = serializers.BooleanField()
    accept_personal_data = serializers.BooleanField()
    accept_public_personal_data_distribution = serializers.BooleanField(required=False, default=False)

    def validate_username(self, value: str) -> str:
        normalized = normalize_username(value)
        if not normalized:
            raise serializers.ValidationError("Введите username")

        User.username_validator(normalized)
        if is_reserved_public_username(normalized):
            raise serializers.ValidationError("Этот username зарезервирован")
        if User.objects.filter(username__iexact=normalized).exists():
            raise serializers.ValidationError("Этот username уже занят")
        return normalized

    def validate_email(self, value: str) -> str:
        normalized = normalize_email(value)
        if User.objects.filter(email__iexact=normalized).exists():
            raise serializers.ValidationError("Аккаунт с таким email уже существует")
        return normalized

    def validate_display_name(self, value: str) -> str:
        return clean_plain_text(value, max_length=120, field_label="Имя")

    def validate(self, attrs: dict) -> dict:
        if attrs["password"] != attrs["password_confirmation"]:
            raise serializers.ValidationError(
                {"password_confirmation": ["Пароли не совпадают"]},
            )

        required_acceptances = {
            "accept_terms": "Нужно принять пользовательское соглашение",
            "accept_privacy_policy": "Нужно подтвердить ознакомление с политикой обработки персональных данных",
            "accept_personal_data": "Нужно дать согласие на обработку персональных данных",
        }
        for field_name, message in required_acceptances.items():
            if not attrs.get(field_name):
                raise serializers.ValidationError({field_name: [message]})

        temp_user = User(
            username=attrs["username"],
            email=attrs["email"],
            display_name=attrs.get("display_name", "").strip(),
        )
        validate_password(attrs["password"], user=temp_user)
        return attrs

    def create(self, validated_data: dict) -> User:
        return create_user_account(
            username=validated_data["username"],
            email=validated_data["email"],
            password=validated_data["password"],
            display_name=validated_data.get("display_name", ""),
            accept_terms=validated_data["accept_terms"],
            accept_privacy_policy=validated_data["accept_privacy_policy"],
            accept_personal_data=validated_data["accept_personal_data"],
            accept_public_personal_data_distribution=validated_data.get(
                "accept_public_personal_data_distribution",
                False,
            ),
        )


class LogoutSerializer(serializers.Serializer):
    refresh = serializers.CharField(trim_whitespace=True)


class PasswordResetRequestSerializer(serializers.Serializer):
    identifier = serializers.CharField(trim_whitespace=True)

    def validate_identifier(self, value: str) -> str:
        normalized = value.strip()
        if not normalized:
            raise serializers.ValidationError("Введите почту, телефон или логин")
        return normalized


class ChangePasswordSerializer(serializers.Serializer):
    current_password = serializers.CharField(write_only=True, trim_whitespace=False)
    new_password = serializers.CharField(write_only=True, trim_whitespace=False, min_length=8)
    new_password_confirmation = serializers.CharField(write_only=True, trim_whitespace=False)

    def validate(self, attrs: dict) -> dict:
        request = self.context["request"]
        user = request.user

        if not user.check_password(attrs["current_password"]):
            raise serializers.ValidationError(
                {"current_password": ["Неверный текущий пароль"]},
            )

        if attrs["new_password"] != attrs["new_password_confirmation"]:
            raise serializers.ValidationError(
                {"new_password_confirmation": ["Пароли не совпадают"]},
            )

        if attrs["current_password"] == attrs["new_password"]:
            raise serializers.ValidationError(
                {"new_password": ["Новый пароль должен отличаться от текущего"]},
            )

        validate_password(attrs["new_password"], user=user)
        return attrs


class SafeTokenRefreshSerializer(TokenRefreshSerializer):
    def validate(self, attrs: dict) -> dict:
        try:
            refresh = RefreshToken(attrs["refresh"])
        except TokenError as error:
            raise InvalidToken(str(error)) from error

        user_id = refresh.payload.get(api_settings.USER_ID_CLAIM)
        if user_id is None:
            raise serializers.ValidationError({"detail": "Некорректный refresh token"})

        user = User.objects.filter(**{api_settings.USER_ID_FIELD: user_id}).first()
        if user is None or not user.is_active:
            raise PermissionDenied("Аккаунт недоступен")

        return super().validate(attrs)


class UserRoleSerializer(serializers.Serializer):
    role = serializers.ChoiceField(choices=User.Role.choices)
