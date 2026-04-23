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
    normalize_phone,
    normalize_username,
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
            "phone",
            "avatar_url",
            "role",
            "status_text",
            "bio",
            "city",
            "website_url",
            "telegram_url",
            "vk_url",
            "instagram_url",
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
            "role",
            "status_text",
            "bio",
            "city",
            "website_url",
            "telegram_url",
            "vk_url",
            "instagram_url",
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


class AuthSessionSerializer(serializers.Serializer):
    access = serializers.CharField()
    refresh = serializers.CharField()
    user = CurrentUserSerializer()


class ProfileSettingsSerializer(serializers.ModelSerializer):
    username = serializers.CharField(required=False)
    email = serializers.EmailField(required=False)
    phone = serializers.CharField(required=False, allow_blank=True, allow_null=True)

    class Meta:
        model = User
        fields = (
            "username",
            "email",
            "display_name",
            "phone",
            "avatar_url",
            "status_text",
            "bio",
            "city",
            "website_url",
            "telegram_url",
            "vk_url",
            "instagram_url",
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

    def validate_phone(self, value: str | None) -> str | None:
        normalized = normalize_phone(value)
        if normalized is None:
            return None

        queryset = User.objects.exclude(pk=self.instance.pk).filter(
            phone__iexact=normalized,
        )
        if queryset.exists():
            raise serializers.ValidationError("Этот номер уже привязан к другому аккаунту")
        return normalized

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
    phone = serializers.CharField(required=False, allow_blank=True, allow_null=True, max_length=32)
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

    def validate_phone(self, value: str | None) -> str | None:
        normalized = normalize_phone(value)
        if normalized is None:
            return None

        if User.objects.filter(phone__iexact=normalized).exists():
            raise serializers.ValidationError("Этот номер уже привязан к другому аккаунту")
        return normalized

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
            phone=attrs.get("phone"),
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
            phone=validated_data.get("phone"),
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
