from django.conf import settings
from django.contrib import admin
from django.urls import include, path, re_path
from django.views.generic import RedirectView
from django.views.static import serve

urlpatterns = [
    path("", RedirectView.as_view(url="/api/v1/health/", permanent=False)),
    path("admin/", RedirectView.as_view(pattern_name="admin:index", permanent=False)),
    path("django-admin/", admin.site.urls),
    path("api/v1/", include("api.v1.urls")),
]

if getattr(settings, "SERVE_MEDIA_FILES", False):
    media_prefix = settings.MEDIA_URL.lstrip("/")
    urlpatterns += [
        re_path(
            rf"^{media_prefix}(?P<path>.*)$",
            serve,
            {"document_root": settings.MEDIA_ROOT},
        ),
    ]
