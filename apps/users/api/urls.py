from django.urls import path

from .views import (
    ChangePasswordView,
    LoginView,
    LogoutView,
    MeView,
    PasswordResetRequestView,
    PublicProfileView,
    PublicProfileByUsernameView,
    RefreshView,
    RegisterView,
    UserBanView,
    UserListView,
    UserRoleView,
    UserUnbanView,
    UserWarningView,
)

urlpatterns = [
    path("auth/register", RegisterView.as_view(), name="auth-register"),
    path("auth/login", LoginView.as_view(), name="auth-login"),
    path("auth/refresh", RefreshView.as_view(), name="token_refresh"),
    path("auth/logout", LogoutView.as_view(), name="auth-logout"),
    path(
        "auth/password-reset/request",
        PasswordResetRequestView.as_view(),
        name="auth-password-reset-request",
    ),
    path("auth/change-password", ChangePasswordView.as_view(), name="auth-change-password"),
    path("auth/me", MeView.as_view(), name="auth-me"),
    path("users", UserListView.as_view(), name="user-list"),
    path("users/<int:user_id>/warn", UserWarningView.as_view(), name="user-warn"),
    path("users/<int:user_id>/ban", UserBanView.as_view(), name="user-ban"),
    path("users/<int:user_id>/unban", UserUnbanView.as_view(), name="user-unban"),
    path("users/<int:user_id>/role", UserRoleView.as_view(), name="user-role"),
    path(
        "profiles/by-username/<str:username>",
        PublicProfileByUsernameView.as_view(),
        name="public-profile-by-username",
    ),
    path("profiles/<int:user_id>", PublicProfileView.as_view(), name="public-profile"),
]
