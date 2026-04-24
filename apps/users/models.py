from django.contrib.auth.models import AbstractUser
from django.db import models

from apps.common.models import TimeStampedModel


class User(AbstractUser, TimeStampedModel):
    class Role(models.TextChoices):
        ADMIN = "admin", "Admin"
        SUPPORT = "support", "Support"
        MODERATOR = "moderator", "Moderator"
        USER = "user", "User"

    email = models.EmailField(unique=True)
    display_name = models.CharField(max_length=120, blank=True)
    phone = models.CharField(max_length=32, blank=True, null=True, unique=True)
    avatar_url = models.URLField(blank=True)
    role = models.CharField(max_length=24, choices=Role.choices, default=Role.USER)
    status_text = models.CharField(max_length=120, blank=True)
    bio = models.TextField(blank=True)
    city = models.CharField(max_length=120, blank=True, default="Nizhny Novgorod")
    website_url = models.URLField(blank=True)
    telegram_url = models.URLField(blank=True)
    vk_url = models.URLField(blank=True)
    instagram_url = models.URLField(blank=True)
    warning_count = models.PositiveSmallIntegerField(default=0)
    banned_at = models.DateTimeField(blank=True, null=True)
    terms_accepted_at = models.DateTimeField(blank=True, null=True)
    privacy_policy_accepted_at = models.DateTimeField(blank=True, null=True)
    personal_data_consent_accepted_at = models.DateTimeField(blank=True, null=True)
    public_personal_data_consent_accepted_at = models.DateTimeField(blank=True, null=True)

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
