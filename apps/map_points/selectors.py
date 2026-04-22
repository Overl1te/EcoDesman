from django.db import models
from django.db.models import Prefetch

from .category_style import sort_categories
from .models import (
    MapPoint,
    MapPointCategory,
    MapPointImage,
    MapPointReview,
    MapPointReviewImage,
    UserMapMarker,
    UserMapMarkerComment,
    UserMapMarkerMedia,
)


def list_active_map_points():
    return (
        MapPoint.objects.filter(is_active=True)
        .prefetch_related("categories")
        .prefetch_related(
            Prefetch("images", queryset=MapPointImage.objects.order_by("position", "id")),
            Prefetch(
                "reviews",
                queryset=MapPointReview.objects.select_related("author")
                .prefetch_related(
                    Prefetch(
                        "images",
                        queryset=MapPointReviewImage.objects.order_by("position", "id"),
                    )
                )
                .order_by("-created_at", "-id"),
            ),
        )
    )


def get_map_point(point_id: int):
    return list_active_map_points().filter(id=point_id)


def list_map_categories():
    return sort_categories(MapPointCategory.objects.all())


def list_visible_user_map_markers(viewer=None):
    queryset = (
        UserMapMarker.objects.filter(is_active=True)
        .select_related("author")
        .prefetch_related(
            Prefetch(
                "media",
                queryset=UserMapMarkerMedia.objects.order_by("position", "id"),
            ),
            Prefetch(
                "comments",
                queryset=UserMapMarkerComment.objects.select_related("author").order_by(
                    "created_at",
                    "id",
                ),
            ),
        )
    )

    if viewer and viewer.is_authenticated:
        return queryset.filter(models.Q(is_public=True) | models.Q(author=viewer))

    return queryset.filter(is_public=True)


def get_visible_user_map_marker(marker_id: int, viewer=None):
    return list_visible_user_map_markers(viewer=viewer).filter(id=marker_id)
