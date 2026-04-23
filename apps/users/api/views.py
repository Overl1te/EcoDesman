from django.conf import settings
from django.shortcuts import get_object_or_404
from rest_framework import status
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework_simplejwt.exceptions import InvalidToken, TokenError
from rest_framework_simplejwt.tokens import RefreshToken

from ..models import User
from ..selectors import search_users
from ..services import (
    authenticate_user,
    ban_user,
    blacklist_refresh_token,
    blacklist_user_refresh_tokens,
    can_administrate,
    get_user_by_identifier,
    issue_warning,
    unban_user,
    update_user_role,
)
from .cookies import clear_auth_cookies, set_auth_cookies
from .serializers import (
    ChangePasswordSerializer,
    CurrentUserSerializer,
    LoginSerializer,
    LogoutSerializer,
    PasswordResetRequestSerializer,
    ProfileSettingsSerializer,
    PublicProfileSerializer,
    RegisterSerializer,
    SafeTokenRefreshSerializer,
    UserRoleSerializer,
    UserSummarySerializer,
)


def build_auth_payload(*, user: User, request) -> dict:
    refresh = RefreshToken.for_user(user)
    return {
        "access": str(refresh.access_token),
        "refresh": str(refresh),
        "user": CurrentUserSerializer(user, context={"request": request}).data,
    }


def build_auth_response(*, user: User, request, status_code: int = status.HTTP_200_OK) -> Response:
    payload = build_auth_payload(user=user, request=request)
    response = Response(payload, status=status_code)
    set_auth_cookies(
        response,
        access_token=payload["access"],
        refresh_token=payload["refresh"],
        request=request,
    )
    return response


class LoginView(APIView):
    permission_classes = [AllowAny]

    def post(self, request):
        serializer = LoginSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        user = authenticate_user(
            identifier=serializer.validated_data["identifier"],
            password=serializer.validated_data["password"],
        )
        if user is None:
            existing_user = get_user_by_identifier(serializer.validated_data["identifier"])
            if existing_user and not existing_user.is_active:
                return Response(
                    {"detail": "Аккаунт заблокирован"},
                    status=status.HTTP_403_FORBIDDEN,
                )
            return Response(
                {"detail": "Неверный логин или пароль"},
                status=status.HTTP_401_UNAUTHORIZED,
            )

        return build_auth_response(user=user, request=request)


class RegisterView(APIView):
    permission_classes = [AllowAny]

    def post(self, request):
        serializer = RegisterSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        user = serializer.save()
        return build_auth_response(
            user=user,
            request=request,
            status_code=status.HTTP_201_CREATED,
        )

class RefreshView(APIView):
    permission_classes = [AllowAny]
    authentication_classes = []

    def post(self, request):
        refresh_token = request.data.get("refresh") or request.COOKIES.get(
            settings.AUTH_REFRESH_COOKIE_NAME,
        )
        if not refresh_token:
            return Response(
                {"detail": "Refresh token is required"},
                status=status.HTTP_400_BAD_REQUEST,
            )

        serializer = SafeTokenRefreshSerializer(data={"refresh": refresh_token})
        serializer.is_valid(raise_exception=True)

        token_payload = serializer.validated_data
        response = Response(token_payload)
        set_auth_cookies(
            response,
            access_token=token_payload["access"],
            refresh_token=token_payload.get("refresh", refresh_token),
            request=request,
        )
        return response


class LogoutView(APIView):
    permission_classes = [AllowAny]
    authentication_classes = []

    def post(self, request):
        refresh_token = request.data.get("refresh") or request.COOKIES.get(
            settings.AUTH_REFRESH_COOKIE_NAME,
        )
        try:
            if refresh_token:
                blacklist_refresh_token(refresh_token)
        except TokenError as error:
            raise InvalidToken(str(error)) from error
        response = Response(status=status.HTTP_204_NO_CONTENT)
        clear_auth_cookies(response)
        return response


class PasswordResetRequestView(APIView):
    permission_classes = [AllowAny]

    def post(self, request):
        serializer = PasswordResetRequestSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        return Response(
            {
                "detail": (
                    "Запрос принят. Когда подключим письмо или SMS, "
                    "инструкция по восстановлению будет приходить сюда."
                ),
            },
            status=status.HTTP_200_OK,
        )


class ChangePasswordView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        serializer = ChangePasswordSerializer(
            data=request.data,
            context={"request": request},
        )
        serializer.is_valid(raise_exception=True)

        request.user.set_password(serializer.validated_data["new_password"])
        request.user.save(update_fields=["password"])
        blacklist_user_refresh_tokens(request.user)
        request.user.refresh_from_db()

        return build_auth_response(user=request.user, request=request)


class MeView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        return Response(CurrentUserSerializer(request.user, context={"request": request}).data)

    def patch(self, request):
        serializer = ProfileSettingsSerializer(
            request.user,
            data=request.data,
            partial=True,
        )
        serializer.is_valid(raise_exception=True)
        serializer.save()
        return Response(CurrentUserSerializer(request.user, context={"request": request}).data)


class UserListView(APIView):
    permission_classes = [AllowAny]

    def get(self, request):
        queryset = search_users(request.query_params.get("search"))[:20]
        serializer = UserSummarySerializer(queryset, many=True)
        return Response(serializer.data)


class PublicProfileView(APIView):
    permission_classes = [AllowAny]

    def get(self, request, user_id: int):
        user = get_object_or_404(User, id=user_id)
        return Response(PublicProfileSerializer(user, context={"request": request}).data)


class PublicProfileByUsernameView(APIView):
    permission_classes = [AllowAny]

    def get(self, request, username: str):
        user = get_object_or_404(User, username__iexact=username)
        return Response(PublicProfileSerializer(user, context={"request": request}).data)


class UserWarningView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request, user_id: int):
        if not can_administrate(request.user):
            return Response(status=status.HTTP_403_FORBIDDEN)

        user = get_object_or_404(User, id=user_id)
        issue_warning(user)
        return Response(PublicProfileSerializer(user, context={"request": request}).data)


class UserBanView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request, user_id: int):
        if not can_administrate(request.user):
            return Response(status=status.HTTP_403_FORBIDDEN)

        user = get_object_or_404(User, id=user_id)
        ban_user(user)
        return Response(PublicProfileSerializer(user, context={"request": request}).data)


class UserUnbanView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request, user_id: int):
        if not can_administrate(request.user):
            return Response(status=status.HTTP_403_FORBIDDEN)

        user = get_object_or_404(User, id=user_id)
        unban_user(user)
        return Response(PublicProfileSerializer(user, context={"request": request}).data)


class UserRoleView(APIView):
    permission_classes = [IsAuthenticated]

    def patch(self, request, user_id: int):
        if not can_administrate(request.user):
            return Response(status=status.HTTP_403_FORBIDDEN)

        user = get_object_or_404(User, id=user_id)
        serializer = UserRoleSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        update_user_role(user, serializer.validated_data["role"])
        return Response(PublicProfileSerializer(user, context={"request": request}).data)
