from .base import *  # noqa: F403

DEBUG = False
SECURE_SSL_REDIRECT = False
SECURE_HSTS_SECONDS = 0
SECURE_HSTS_INCLUDE_SUBDOMAINS = False
SECURE_HSTS_PRELOAD = False
SESSION_COOKIE_SECURE = env_bool(
    "SESSION_COOKIE_SECURE",
    default=env_str("PUBLIC_SCHEME", "http").lower() == "https",
)
CSRF_COOKIE_SECURE = env_bool(
    "CSRF_COOKIE_SECURE",
    default=env_str("PUBLIC_SCHEME", "http").lower() == "https",
)
