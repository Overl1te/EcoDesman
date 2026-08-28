import uuid
from decimal import Decimal

from django.contrib.auth.models import AbstractUser
from django.db import models

from apps.common.models import TimeStampedModel


class User(AbstractUser, TimeStampedModel):
    class Role(models.TextChoices):
        ADMIN = "admin", "Admin"
        SUPPORT = "support", "Support"
        MODERATOR = "moderator", "Moderator"
        USER = "user", "User"

    email = models.EmailField(unique=True, blank=True, null=True)
    display_name = models.CharField(max_length=120, blank=True)
    phone = models.CharField(max_length=32, blank=True, null=True, unique=True)
    avatar_url = models.URLField(blank=True)
    avatar_position_x = models.PositiveSmallIntegerField(default=50)
    avatar_position_y = models.PositiveSmallIntegerField(default=50)
    avatar_scale = models.DecimalField(max_digits=3, decimal_places=2, default=Decimal("1.00"))
    role = models.CharField(max_length=24, choices=Role.choices, default=Role.USER)
    status_text = models.CharField(max_length=120, blank=True)
    bio = models.TextField(blank=True, max_length=500)
    city = models.CharField(max_length=120, blank=True, default="Nizhny Novgorod")
    website_url = models.URLField(blank=True)
    telegram_url = models.URLField(blank=True)
    vk_url = models.URLField(blank=True)
    instagram_url = models.URLField(blank=True)
    max_url = models.URLField(blank=True)
    warning_count = models.PositiveSmallIntegerField(default=0)
    banned_at = models.DateTimeField(blank=True, null=True)
    terms_accepted_at = models.DateTimeField(blank=True, null=True)
    privacy_policy_accepted_at = models.DateTimeField(blank=True, null=True)
    personal_data_consent_accepted_at = models.DateTimeField(blank=True, null=True)
    public_personal_data_consent_accepted_at = models.DateTimeField(blank=True, null=True)
    phone_verified_at = models.DateTimeField(blank=True, null=True)

    @property
    def is_admin_role(self) -> bool:
        return self.role == self.Role.ADMIN or self.is_superuser

    @property
    def is_post_manager(self) -> bool:
        return self.is_admin_role or self.role in {self.Role.SUPPORT, self.Role.MODERATOR}

    @property
    def can_access_support(self) -> bool:
        return self.is_admin_role or self.role == self.Role.SUPPORT

    @property
    def is_banned(self) -> bool:
        return bool(self.banned_at or not self.is_active)

    def __str__(self) -> str:
        return self.display_name or self.username


class UserSocialAccount(TimeStampedModel):
    class Provider(models.TextChoices):
        VK = "vk", "VK"
        GOOGLE = "google", "Google"
        YANDEX = "yandex", "Yandex"
        TELEGRAM = "telegram", "Telegram"

    user = models.ForeignKey(
        User,
        on_delete=models.CASCADE,
        related_name="social_accounts",
    )
    provider = models.CharField(max_length=24, choices=Provider.choices)
    provider_user_id = models.CharField(max_length=190)
    email = models.EmailField(blank=True)
    display_name = models.CharField(max_length=190, blank=True)
    avatar_url = models.URLField(blank=True)

    class Meta:
        constraints = [
            models.UniqueConstraint(
                fields=("provider", "provider_user_id"),
                name="unique_social_provider_user",
            ),
        ]

    def __str__(self) -> str:
        return f"{self.provider}:{self.provider_user_id}"


class PhoneVerificationChallenge(TimeStampedModel):
    class Purpose(models.TextChoices):
        AUTH = "auth", "Auth"
        REGISTER = "register", "Register"
        LOGIN = "login", "Login"
        PASSWORD_RESET = "password_reset", "Password reset"

    class Channel(models.TextChoices):
        TELEGRAM = "telegram", "Telegram"
        CALL = "call", "Код в номере"
        RECEIVE = "receive", "Обратный звонок"
        EMAIL = "email", "Код на почту"

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    phone = models.CharField(max_length=32, blank=True, db_index=True)
    email = models.EmailField(blank=True, db_index=True)
    purpose = models.CharField(max_length=32, choices=Purpose.choices)
    channel = models.CharField(max_length=16, choices=Channel.choices)
    code_hash = models.CharField(max_length=64, blank=True)
    greensms_request_id = models.CharField(max_length=64, blank=True)
    receive_number = models.CharField(max_length=32, blank=True)
    client_ip = models.GenericIPAddressField(blank=True, null=True)
    verify_attempts = models.PositiveSmallIntegerField(default=0)
    verified_at = models.DateTimeField(blank=True, null=True)
    consumed_at = models.DateTimeField(blank=True, null=True)
    expires_at = models.DateTimeField()

    class Meta:
        indexes = [
            models.Index(fields=("phone", "purpose", "created_at")),
            models.Index(fields=("email", "purpose", "created_at")),
            models.Index(fields=("client_ip", "created_at")),
        ]

    def __str__(self) -> str:
        identity = self.email or self.phone or str(self.id)
        return f"{identity}:{self.purpose}:{self.channel}"
