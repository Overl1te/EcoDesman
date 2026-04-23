from django.urls import path

from .views import (
    AdminMapCategoryDetailView,
    AdminMapCategoryListView,
    AdminMapPointDetailView,
    AdminMapPointListCreateView,
    AdminOverviewView,
    AdminPostListView,
    AdminUserMapMarkerDetailView,
    AdminUserMapMarkerListView,
    AdminUserListView,
)

urlpatterns = [
    path("admin/overview", AdminOverviewView.as_view(), name="admin-overview"),
    path("admin/posts", AdminPostListView.as_view(), name="admin-post-list"),
    path("admin/users", AdminUserListView.as_view(), name="admin-user-list"),
    path(
        "admin/map/categories",
        AdminMapCategoryListView.as_view(),
        name="admin-map-category-list",
    ),
    path(
        "admin/map/categories/<int:category_id>",
        AdminMapCategoryDetailView.as_view(),
        name="admin-map-category-detail",
    ),
    path(
        "admin/map/points",
        AdminMapPointListCreateView.as_view(),
        name="admin-map-point-list",
    ),
    path(
        "admin/map/points/<int:point_id>",
        AdminMapPointDetailView.as_view(),
        name="admin-map-point-detail",
    ),
    path(
        "admin/map/user-markers",
        AdminUserMapMarkerListView.as_view(),
        name="admin-user-map-marker-list",
    ),
    path(
        "admin/map/user-markers/<int:marker_id>",
        AdminUserMapMarkerDetailView.as_view(),
        name="admin-user-map-marker-detail",
    ),
]
