from django.conf import settings
from django.db import transaction
from django.shortcuts import get_object_or_404
from django.utils import timezone
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
    identifier_is_phone,
    issue_warning,
    unban_user,
    update_user_role,
)
from ..oauth import (
    SocialAuthError,
    exchange_code_for_token,
    fetch_social_profile,
    fetch_telegram_profile,
    list_social_providers,
    login_or_create_social_user,
)
from ..greensms import is_phone_verification_enabled
from ..phone_verification import (
    PhoneVerificationError,
    consume_verified_challenge,
    has_active_phone_challenge,
    phone_verification_public_config,
    request_phone_challenge,
    resend_phone_challenge,
    serialize_challenge,
    verify_phone_code,
)
from ..request_utils import get_client_ip
from ..turnstile import TurnstileError, is_turnstile_enabled, verify_turnstile_token
from .cookies import clear_auth_cookies, set_auth_cookies
from .serializers import (
    ChangePasswordSerializer,
    CurrentUserSerializer,
    LoginSerializer,
    LogoutSerializer,
    PasswordResetRequestSerializer,
    PhoneChallengeRequestSerializer,
    PhoneChallengeResendSerializer,
    PhoneChallengeVerifySerializer,
    ProfileSettingsSerializer,
    PublicProfileSerializer,
    RegisterSerializer,
    SafeTokenRefreshSerializer,
    SocialLoginSerializer,
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


def _turnstile_error_response(error: TurnstileError) -> Response:
    return Response({"detail": str(error), "turnstile_token": [str(error)]}, status=status.HTTP_400_BAD_REQUEST)


def _phone_error_response(error: PhoneVerificationError) -> Response:
    return Response({"detail": str(error)}, status=error.status_code)


def require_turnstile(request, *, allow_active_challenge: bool = False) -> None:
    if allow_active_challenge:
        challenge_id = (
            request.data.get("phone_challenge_id") or request.data.get("challenge_id") or ""
        )
        if has_active_phone_challenge(str(challenge_id).strip()):
            return
    verify_turnstile_token(
        request.data.get("turnstile_token"),
        remote_ip=get_client_ip(request),
    )


class AuthProtectionView(APIView):
    permission_classes = [AllowAny]

    def get(self, request):
        site_key = settings.CLOUDFLARE_TURNSTILE_SITE_KEY if is_turnstile_enabled() else ""
        return Response(
            {
                "turnstile": {
                    "enabled": is_turnstile_enabled(),
                    "site_key": site_key,
                },
                "phone_verification": phone_verification_public_config(),
            }
        )


class LoginView(APIView):
    permission_classes = [AllowAny]

    def post(self, request):
        serializer = LoginSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        try:
            require_turnstile(request, allow_active_challenge=True)
        except TurnstileError as error:
            return _turnstile_error_response(error)

        identifier = serializer.validated_data["identifier"]
        user = authenticate_user(
            identifier=identifier,
            password=serializer.validated_data["password"],
        )
        if user is None:
            existing_user = get_user_by_identifier(identifier)
            if existing_user and not existing_user.is_active:
                return Response(
                    {"detail": "Аккаунт заблокирован"},
                    status=status.HTTP_403_FORBIDDEN,
                )
            return Response(
                {"detail": "Неверный логин или пароль"},
                status=status.HTTP_401_UNAUTHORIZED,
            )

        if is_phone_verification_enabled() and identifier_is_phone(identifier):
            challenge_id = (serializer.validated_data.get("phone_challenge_id") or "").strip()
            try:
                if not challenge_id:
                    payload = request_phone_challenge(
                        phone=user.phone or identifier,
                        purpose="login",
                        client_ip=get_client_ip(request),
                    )
                    return Response(
                        {**payload, "code": "phone_confirmation_required"},
                        status=status.HTTP_400_BAD_REQUEST,
                    )
                consume_verified_challenge(
                    challenge_id=challenge_id,
                    phone=user.phone or identifier,
                    purpose="login",
                    code=serializer.validated_data.get("phone_code"),
                )
            except PhoneVerificationError as error:
                return _phone_error_response(error)

            if user.phone_verified_at is None:
                user.phone_verified_at = timezone.now()
                user.save(update_fields=["phone_verified_at"])

        return build_auth_response(user=user, request=request)


class RegisterView(APIView):
    permission_classes = [AllowAny]

    def post(self, request):
        serializer = RegisterSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        try:
            require_turnstile(request, allow_active_challenge=True)
        except TurnstileError as error:
            return _turnstile_error_response(error)

        try:
            with transaction.atomic():
                if is_phone_verification_enabled():
                    consume_verified_challenge(
                        challenge_id=serializer.validated_data.get("phone_challenge_id"),
                        phone=serializer.validated_data.get("phone"),
                        purpose="register",
                        code=serializer.validated_data.get("phone_code"),
                    )
                    serializer.context["phone_verified"] = True
                user = serializer.save()
        except PhoneVerificationError as error:
            return _phone_error_response(error)

        return build_auth_response(
            user=user,
            request=request,
            status_code=status.HTTP_201_CREATED,
        )


class SocialProviderListView(APIView):
    permission_classes = [AllowAny]

    def get(self, request):
        try:
            providers = list_social_providers(
                redirect_uri=request.query_params.get("redirect_uri", ""),
                state=request.query_params.get("state", ""),
            )
        except SocialAuthError as error:
            return Response({"detail": str(error)}, status=status.HTTP_400_BAD_REQUEST)
        return Response({"providers": providers})


class SocialLoginView(APIView):
    permission_classes = [AllowAny]

    def post(self, request, provider: str):
        serializer = SocialLoginSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        data = serializer.validated_data

        try:
            if provider == "telegram":
                profile = fetch_telegram_profile(data.get("telegram_auth") or {})
            else:
                access_token = data.get("access_token")
                email_hint = data.get("email", "")
                if not access_token:
                    if not data.get("code"):
                        return Response(
                            {"detail": "access_token or code is required"},
                            status=status.HTTP_400_BAD_REQUEST,
                        )
                    token_payload = exchange_code_for_token(
                        provider,
                        code=data["code"],
                        redirect_uri=data["redirect_uri"],
                    )
                    access_token = token_payload.get("access_token")
                    email_hint = token_payload.get("email") or email_hint
                if not access_token:
                    return Response(
                        {"detail": "Social provider did not return access token"},
                        status=status.HTTP_400_BAD_REQUEST,
                    )

                profile = fetch_social_profile(
                    provider,
                    access_token=access_token,
                    email_hint=email_hint,
                )
            user, created = login_or_create_social_user(
                profile,
                accept_terms=data.get("accept_terms", False),
                accept_privacy_policy=data.get("accept_privacy_policy", False),
                accept_personal_data=data.get("accept_personal_data", False),
                accept_public_personal_data_distribution=data.get(
                    "accept_public_personal_data_distribution",
                    False,
                ),
            )
        except SocialAuthError as error:
            return Response({"detail": str(error)}, status=status.HTTP_400_BAD_REQUEST)

        response = build_auth_response(user=user, request=request)
        response.data["is_new_user"] = created
        response.data["provider"] = provider
        return response


class PhoneChallengeSendView(APIView):
    permission_classes = [AllowAny]

    def post(self, request):
        serializer = PhoneChallengeRequestSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        try:
            require_turnstile(request)
            payload = request_phone_challenge(
                phone=serializer.validated_data["phone"],
                purpose=serializer.validated_data.get("purpose") or "register",
                client_ip=get_client_ip(request),
            )
        except TurnstileError as error:
            return _turnstile_error_response(error)
        except PhoneVerificationError as error:
            return _phone_error_response(error)
        return Response(payload, status=status.HTTP_201_CREATED)


class PhoneChallengeVerifyView(APIView):
    permission_classes = [AllowAny]

    def post(self, request):
        serializer = PhoneChallengeVerifySerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        try:
            challenge = verify_phone_code(
                challenge_id=serializer.validated_data["challenge_id"],
                code=serializer.validated_data.get("code") or "",
            )
        except PhoneVerificationError as error:
            return _phone_error_response(error)
        return Response(serialize_challenge(challenge))


class PhoneChallengeResendView(APIView):
    permission_classes = [AllowAny]

    def post(self, request):
        serializer = PhoneChallengeResendSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        try:
            require_turnstile(request, allow_active_challenge=True)
            payload = resend_phone_challenge(
                challenge_id=serializer.validated_data["challenge_id"],
                client_ip=get_client_ip(request),
            )
        except TurnstileError as error:
            return _turnstile_error_response(error)
        except PhoneVerificationError as error:
            return _phone_error_response(error)
        return Response(payload)


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
        try:
            require_turnstile(request)
        except TurnstileError as error:
            return _turnstile_error_response(error)
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
