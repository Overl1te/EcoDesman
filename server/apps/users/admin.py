from django.contrib import admin
from django.contrib.auth.admin import UserAdmin

from .models import User


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
