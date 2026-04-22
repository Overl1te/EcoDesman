from django.contrib import admin

from .models import (
    MapPoint,
    MapPointCategory,
    MapPointImage,
    MapPointReview,
    UserMapMarker,
    UserMapMarkerComment,
    UserMapMarkerMedia,
)


class MapPointImageInline(admin.TabularInline):
    model = MapPointImage
    extra = 0


class MapPointReviewInline(admin.TabularInline):
    model = MapPointReview
    extra = 0


class UserMapMarkerMediaInline(admin.TabularInline):
    model = UserMapMarkerMedia
    extra = 0


class UserMapMarkerCommentInline(admin.TabularInline):
    model = UserMapMarkerComment
    extra = 0


@admin.register(MapPointCategory)
class MapPointCategoryAdmin(admin.ModelAdmin):
    list_display = ("title", "slug", "sort_order")
    search_fields = ("title", "slug")
    ordering = ("sort_order", "title")


@admin.register(MapPoint)
class MapPointAdmin(admin.ModelAdmin):
    list_display = (
        "title",
        "slug",
        "latitude",
        "longitude",
        "is_active",
        "sort_order",
    )
    list_filter = ("is_active", "categories")
    search_fields = ("title", "slug", "short_description", "address")
    filter_horizontal = ("categories",)
    inlines = [MapPointImageInline, MapPointReviewInline]
    ordering = ("sort_order", "title")


@admin.register(UserMapMarker)
class UserMapMarkerAdmin(admin.ModelAdmin):
    list_display = (
        "title",
        "author",
        "latitude",
        "longitude",
        "is_public",
        "is_active",
        "created_at",
    )
    list_filter = ("is_public", "is_active", "created_at")
    search_fields = ("title", "description", "author__username", "author__email")
    inlines = [UserMapMarkerMediaInline, UserMapMarkerCommentInline]
    ordering = ("-created_at", "-id")
