from django.contrib import admin
from django.contrib.auth.admin import UserAdmin

from .models import PhoneVerificationChallenge, User


@admin.register(User)
class EcoNizhnyUserAdmin(UserAdmin):
    fieldsets = UserAdmin.fieldsets + (
        (
            "ЭкоВыхухоль",
            {
                "fields": (
                    "display_name",
                    "phone",
                    "avatar_url",
                    "role",
                    "warning_count",
                    "banned_at",
                    "status_text",
                    "bio",
                    "city",
                )
            },
        ),
    )
    list_display = (
        "id",
        "email",
        "username",
        "display_name",
        "role",
        "warning_count",
        "banned_at",
        "phone",
        "is_staff",
    )
    search_fields = ("email", "username", "display_name", "phone", "city")


@admin.register(PhoneVerificationChallenge)
class PhoneVerificationChallengeAdmin(admin.ModelAdmin):
    list_display = (
        "id",
        "phone",
        "purpose",
        "channel",
        "verified_at",
        "consumed_at",
        "expires_at",
        "created_at",
    )
    list_filter = ("purpose", "channel")
    search_fields = ("phone", "greensms_request_id")
    readonly_fields = (
        "id",
        "phone",
        "purpose",
        "channel",
        "code_hash",
        "greensms_request_id",
        "receive_number",
        "client_ip",
        "verify_attempts",
        "verified_at",
        "consumed_at",
        "expires_at",
        "created_at",
        "updated_at",
    )
