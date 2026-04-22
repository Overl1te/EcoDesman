from django.urls import include, path
from apps.common.api.views import ImageUploadView, MediaUploadView

urlpatterns = [
    path("health/", include("apps.common.api.urls")),
    path("uploads/images", ImageUploadView.as_view(), name="image-upload"),
    path("uploads/media", MediaUploadView.as_view(), name="media-upload"),
    path("", include("apps.admin_panel.api.urls")),
    path("", include("apps.users.api.urls")),
    path("", include("apps.map_points.api.urls")),
    path("", include("apps.notifications.api.urls")),
    path("", include("apps.posts.api.urls")),
    path("", include("apps.support.api.urls")),
]
