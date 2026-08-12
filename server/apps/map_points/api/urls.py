from django.urls import path

from .views import (
    MapOverviewView,
    MapPointDetailView,
    MapPointReviewCreateView,
    MapPointReviewDetailView,
    MapPointReviewReportView,
    UserMapMarkerCommentCreateView,
    UserMapMarkerCommentDetailView,
    UserMapMarkerCommentReportView,
    UserMapMarkerDetailView,
    UserMapMarkerListCreateView,
    UserMapMarkerReportView,
)

urlpatterns = [
    path("map/overview", MapOverviewView.as_view(), name="map-overview"),
    path("map/points/<int:point_id>", MapPointDetailView.as_view(), name="map-point-detail"),
    path(
        "map/points/<int:point_id>/reviews",
        MapPointReviewCreateView.as_view(),
        name="map-point-review-create",
    ),
    path(
        "map/points/<int:point_id>/reviews/<int:review_id>",
        MapPointReviewDetailView.as_view(),
        name="map-point-review-detail",
    ),
    path(
        "map/points/<int:point_id>/reviews/<int:review_id>/report",
        MapPointReviewReportView.as_view(),
        name="map-point-review-report",
    ),
    path(
        "map/user-markers",
        UserMapMarkerListCreateView.as_view(),
        name="user-map-marker-list",
    ),
    path(
        "map/user-markers/<int:marker_id>",
        UserMapMarkerDetailView.as_view(),
        name="user-map-marker-detail",
    ),
    path(
        "map/user-markers/<int:marker_id>/report",
        UserMapMarkerReportView.as_view(),
        name="user-map-marker-report",
    ),
    path(
        "map/user-markers/<int:marker_id>/comments",
        UserMapMarkerCommentCreateView.as_view(),
        name="user-map-marker-comment-create",
    ),
    path(
        "map/user-markers/<int:marker_id>/comments/<int:comment_id>",
        UserMapMarkerCommentDetailView.as_view(),
        name="user-map-marker-comment-detail",
    ),
    path(
        "map/user-markers/<int:marker_id>/comments/<int:comment_id>/report",
        UserMapMarkerCommentReportView.as_view(),
        name="user-map-marker-comment-report",
    ),
]
