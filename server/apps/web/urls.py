from django.urls import path

from . import views

urlpatterns = [
    path("", views.feed_page, name="web-feed"),
    path("events/", views.events_page, name="web-events"),
    path("map/", views.map_page, name="web-map"),
    path("favorites/", views.favorites_page, name="web-favorites"),
    path("notifications/", views.notifications_page, name="web-notifications"),
    path("notifications/read-all/", views.read_all_notifications, name="web-notifications-read-all"),
    path("profile/", views.profile_page, name="web-profile"),
    path("profile/settings/", views.profile_settings_page, name="web-profile-settings"),
    path("profiles/<int:user_id>/", views.public_profile_page, name="web-public-profile"),
    path("posts/new/", views.post_create_page, name="web-post-create"),
    path("posts/<int:post_id>/", views.post_detail_page, name="web-post-detail"),
    path("posts/<int:post_id>/edit/", views.post_edit_page, name="web-post-edit"),
    path("posts/<int:post_id>/delete/", views.post_delete, name="web-post-delete"),
    path("posts/<int:post_id>/like/", views.toggle_post_like, name="web-post-like"),
    path("posts/<int:post_id>/favorite/", views.toggle_post_favorite, name="web-post-favorite"),
    path("posts/<int:post_id>/comment/", views.create_post_comment, name="web-post-comment"),
    path("login/", views.login_page, name="web-login"),
    path("register/", views.register_page, name="web-register"),
    path("logout/", views.logout_page, name="web-logout"),
]
