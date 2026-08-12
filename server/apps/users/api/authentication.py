from django.conf import settings
from rest_framework_simplejwt.authentication import JWTAuthentication


class CookieJWTAuthentication(JWTAuthentication):
    def authenticate(self, request):
        header = self.get_header(request)
        raw_token = self.get_raw_token(header) if header is not None else None

        if raw_token is None:
            cookie_token = request.COOKIES.get(settings.AUTH_ACCESS_COOKIE_NAME)
            if not cookie_token:
                return None
            raw_token = cookie_token.encode("utf-8")

        validated_token = self.get_validated_token(raw_token)
        return self.get_user(validated_token), validated_token
