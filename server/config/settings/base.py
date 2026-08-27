import os
from datetime import timedelta
from pathlib import Path
from urllib.parse import urlsplit

from django.core.exceptions import ImproperlyConfigured


def env_bool(name: str, default: bool = False) -> bool:
    raw_value = os.getenv(name, str(default))
    return raw_value.strip().lower() in {"1", "true", "yes", "on"}


def env_list(name: str, default: str = "") -> list[str]:
    raw_value = os.getenv(name, default)
    return [item.strip() for item in raw_value.split(",") if item.strip()]


def _append_unique(items: list[str], candidate: str) -> None:
    if candidate and candidate not in items:
        items.append(candidate)


def _encode_idna(value: str) -> str:
    try:
        return value.encode("idna").decode("ascii")
    except UnicodeError:
        return value


def host_variants(value: str) -> list[str]:
    raw_value = value.strip()
    if not raw_value or raw_value == "*":
        return [raw_value] if raw_value else []

    variants = [raw_value]
    prefix = "." if raw_value.startswith(".") else ""
    host_with_port = raw_value[len(prefix) :]
    host = host_with_port
    port = ""

    if host_with_port.count(":") == 1:
        maybe_host, maybe_port = host_with_port.rsplit(":", 1)
        if maybe_port.isdigit():
            host = maybe_host
            port = f":{maybe_port}"

    encoded_host = _encode_idna(host)
    if encoded_host != host:
        variants.append(f"{prefix}{encoded_host}{port}")

    return variants


def origin_variants(value: str) -> list[str]:
    raw_value = value.strip()
    if not raw_value:
        return []

    variants = [raw_value]
    parsed = urlsplit(raw_value)
    hostname = parsed.hostname

    if not hostname:
        return variants

    encoded_host = _encode_idna(hostname)
    if encoded_host == hostname:
        return variants

    netloc = encoded_host
    if parsed.port is not None:
        netloc = f"{netloc}:{parsed.port}"
    if parsed.username:
        credentials = parsed.username
        if parsed.password:
            credentials = f"{credentials}:{parsed.password}"
        netloc = f"{credentials}@{netloc}"

    variants.append(parsed._replace(netloc=netloc).geturl())
    return variants


def env_list_with_extras(
    name: str,
    default: str = "",
    extras: tuple[str, ...] = (),
) -> list[str]:
    values: list[str] = []
    for item in [*env_list(name, default), *extras]:
        if item and item not in values:
            values.append(item)
    return values


def env_host_list_with_extras(
    name: str,
    default: str = "",
    extras: tuple[str, ...] = (),
) -> list[str]:
    values: list[str] = []
    for item in [*env_list(name, default), *extras]:
        for variant in host_variants(item):
            _append_unique(values, variant)
    return values


def env_origin_list(name: str, default: str = "") -> list[str]:
    values: list[str] = []
    for item in env_list(name, default):
        for variant in origin_variants(item):
            _append_unique(values, variant)
    return values


def env_str(name: str, default: str = "") -> str:
    return os.getenv(name, default).strip()


BASE_DIR = Path(__file__).resolve().parent.parent.parent


def build_storage_settings() -> tuple[dict, str, bool]:
    use_s3_media = env_bool("DJANGO_USE_S3_MEDIA", default=False)
    storages = {
        "default": {
            "BACKEND": "django.core.files.storage.FileSystemStorage",
        },
        "staticfiles": {
            "BACKEND": "whitenoise.storage.CompressedManifestStaticFilesStorage",
        },
    }
    media_url = "media/"
    serve_media_files = env_bool("DJANGO_SERVE_MEDIA", default=DEBUG) and not use_s3_media

    if not use_s3_media:
        return storages, media_url, serve_media_files

    bucket_name = env_str("AWS_STORAGE_BUCKET_NAME")
    endpoint_url = env_str("AWS_S3_ENDPOINT_URL").rstrip("/")
    access_key = env_str("AWS_S3_ACCESS_KEY_ID") or env_str("AWS_ACCESS_KEY_ID")
    secret_key = env_str("AWS_S3_SECRET_ACCESS_KEY") or env_str("AWS_SECRET_ACCESS_KEY")
    custom_domain = (
        env_str("AWS_S3_CUSTOM_DOMAIN")
        .removeprefix("https://")
        .removeprefix("http://")
        .rstrip("/")
    )
    location = env_str("AWS_LOCATION")
    region_name = env_str("AWS_S3_REGION_NAME")
    addressing_style = env_str("AWS_S3_ADDRESSING_STYLE", "virtual")
    signature_version = env_str("AWS_S3_SIGNATURE_VERSION", "s3v4")
    verify = env_str("AWS_S3_VERIFY")
    default_acl = env_str("AWS_DEFAULT_ACL")
    object_acl = env_str("AWS_S3_OBJECT_ACL")

    if not bucket_name:
        raise ImproperlyConfigured(
            "AWS_STORAGE_BUCKET_NAME must be set when DJANGO_USE_S3_MEDIA=true",
        )

    if not endpoint_url:
        raise ImproperlyConfigured(
            "AWS_S3_ENDPOINT_URL must be set when DJANGO_USE_S3_MEDIA=true",
        )

    options: dict[str, object] = {
        "bucket_name": bucket_name,
        "endpoint_url": endpoint_url,
        "querystring_auth": env_bool("AWS_QUERYSTRING_AUTH", default=False),
        "file_overwrite": env_bool("AWS_S3_FILE_OVERWRITE", default=False),
        "addressing_style": addressing_style,
        "signature_version": signature_version,
    }

    if access_key:
        options["access_key"] = access_key
    if secret_key:
        options["secret_key"] = secret_key
    if region_name:
        options["region_name"] = region_name
    if verify:
        options["verify"] = verify
    if custom_domain:
        options["custom_domain"] = custom_domain
    if location:
        options["location"] = location
    if default_acl:
        options["default_acl"] = default_acl
    if object_acl:
        options["object_parameters"] = {"ACL": object_acl}

    storages["default"] = {
        "BACKEND": "storages.backends.s3.S3Storage",
        "OPTIONS": options,
    }

    if custom_domain:
        media_url = f"https://{custom_domain.strip('/')}/"
        return storages, media_url, serve_media_files

    parsed_endpoint = urlsplit(endpoint_url)
    if addressing_style == "path":
        media_url = f"{parsed_endpoint.scheme}://{parsed_endpoint.netloc}/{bucket_name}/"
    else:
        media_url = f"{parsed_endpoint.scheme}://{bucket_name}.{parsed_endpoint.netloc}/"

    return storages, media_url, serve_media_files


def build_database_settings() -> dict:
    if os.getenv("POSTGRES_DB"):
        return {
            "default": {
                "ENGINE": "django.db.backends.postgresql",
                "NAME": os.getenv("POSTGRES_DB", "econizhny"),
                "USER": os.getenv("POSTGRES_USER", "econizhny"),
                "PASSWORD": os.getenv("POSTGRES_PASSWORD", "econizhny"),
                "HOST": os.getenv("POSTGRES_HOST", "db"),
                "PORT": os.getenv("POSTGRES_PORT", "5432"),
            }
        }

    return {
        "default": {
            "ENGINE": "django.db.backends.sqlite3",
            "NAME": BASE_DIR / os.getenv("DJANGO_SQLITE_NAME", "db.sqlite3"),
        }
    }

SECRET_KEY = os.getenv(
    "DJANGO_SECRET_KEY",
    "econizhny-dev-secret-key-change-me",
)
DEBUG = env_bool("DJANGO_DEBUG", default=False)
ALLOWED_HOSTS = env_host_list_with_extras(
    "DJANGO_ALLOWED_HOSTS",
    "127.0.0.1,localhost",
    extras=("127.0.0.1", "localhost", "0.0.0.0"),
)
CSRF_TRUSTED_ORIGINS = env_origin_list("DJANGO_CSRF_TRUSTED_ORIGINS")
CORS_ALLOWED_ORIGINS = env_origin_list("DJANGO_CORS_ALLOWED_ORIGINS")
CORS_ALLOW_CREDENTIALS = True
USE_X_FORWARDED_HOST = True
SECURE_PROXY_SSL_HEADER = ("HTTP_X_FORWARDED_PROTO", "https")

INSTALLED_APPS = [
    "django.contrib.admin",
    "django.contrib.auth",
    "django.contrib.contenttypes",
    "django.contrib.sessions",
    "django.contrib.messages",
    "django.contrib.staticfiles",
    "corsheaders",
    "rest_framework",
    "rest_framework_simplejwt",
    "rest_framework_simplejwt.token_blacklist",
    "apps.admin_panel.apps.AdminPanelConfig",
    "apps.common.apps.CommonConfig",
    "apps.map_points.apps.MapPointsConfig",
    "apps.notifications.apps.NotificationsConfig",
    "apps.users.apps.UsersConfig",
    "apps.posts.apps.PostsConfig",
    "apps.support.apps.SupportConfig",
]

MIDDLEWARE = [
    "django.middleware.security.SecurityMiddleware",
    "corsheaders.middleware.CorsMiddleware",
    "whitenoise.middleware.WhiteNoiseMiddleware",
    "django.contrib.sessions.middleware.SessionMiddleware",
    "django.middleware.common.CommonMiddleware",
    "django.middleware.csrf.CsrfViewMiddleware",
    "django.contrib.auth.middleware.AuthenticationMiddleware",
    "django.contrib.messages.middleware.MessageMiddleware",
    "django.middleware.clickjacking.XFrameOptionsMiddleware",
]

ROOT_URLCONF = "config.urls"

TEMPLATES = [
    {
        "BACKEND": "django.template.backends.django.DjangoTemplates",
        "DIRS": [],
        "APP_DIRS": True,
        "OPTIONS": {
            "context_processors": [
                "django.template.context_processors.request",
                "django.contrib.auth.context_processors.auth",
                "django.contrib.messages.context_processors.messages",
            ],
        },
    },
]

WSGI_APPLICATION = "config.wsgi.application"
ASGI_APPLICATION = "config.asgi.application"

DATABASES = build_database_settings()

AUTH_PASSWORD_VALIDATORS = [
    {
        "NAME": "django.contrib.auth.password_validation.UserAttributeSimilarityValidator",
    },
    {
        "NAME": "django.contrib.auth.password_validation.MinimumLengthValidator",
    },
    {
        "NAME": "django.contrib.auth.password_validation.CommonPasswordValidator",
    },
    {
        "NAME": "django.contrib.auth.password_validation.NumericPasswordValidator",
    },
]

LANGUAGE_CODE = "ru-ru"
TIME_ZONE = "Europe/Moscow"
USE_I18N = True
USE_TZ = True

STATIC_URL = "static/"
STATIC_ROOT = BASE_DIR / "staticfiles"
MEDIA_ROOT = BASE_DIR / "media"
RUNTIME_LOGS_DIR = BASE_DIR / "runtime_logs"
BACKUPS_DIR = BASE_DIR / "backups"
STORAGES, MEDIA_URL, SERVE_MEDIA_FILES = build_storage_settings()

for required_dir in (MEDIA_ROOT, STATIC_ROOT, RUNTIME_LOGS_DIR, BACKUPS_DIR):
    required_dir.mkdir(parents=True, exist_ok=True)

DEFAULT_AUTO_FIELD = "django.db.models.BigAutoField"
AUTH_USER_MODEL = "users.User"
APP_LOG_LEVEL = env_str("APP_LOG_LEVEL", "INFO").upper()

REST_FRAMEWORK = {
    "DEFAULT_AUTHENTICATION_CLASSES": (
        "apps.users.api.authentication.CookieJWTAuthentication",
        "rest_framework_simplejwt.authentication.JWTAuthentication",
    ),
    "DEFAULT_PERMISSION_CLASSES": (
        "rest_framework.permissions.AllowAny",
    ),
    "DEFAULT_PAGINATION_CLASS": "apps.posts.api.pagination.PostPagination",
    "PAGE_SIZE": 10,
    "DEFAULT_RENDERER_CLASSES": (
        "rest_framework.renderers.JSONRenderer",
        "rest_framework.renderers.BrowsableAPIRenderer",
    ),
}

SIMPLE_JWT = {
    "ACCESS_TOKEN_LIFETIME": timedelta(minutes=30),
    "REFRESH_TOKEN_LIFETIME": timedelta(days=7),
    "ROTATE_REFRESH_TOKENS": True,
    "BLACKLIST_AFTER_ROTATION": True,
    "UPDATE_LAST_LOGIN": True,
}

AUTH_ACCESS_COOKIE_NAME = env_str("AUTH_ACCESS_COOKIE_NAME", "eco_desman_access")
AUTH_REFRESH_COOKIE_NAME = env_str("AUTH_REFRESH_COOKIE_NAME", "eco_desman_refresh")
AUTH_COOKIE_DOMAIN = env_str("AUTH_COOKIE_DOMAIN")
_auth_cookie_secure_raw = os.getenv("AUTH_COOKIE_SECURE")
AUTH_COOKIE_SECURE = (
    _auth_cookie_secure_raw.strip().lower() in {"1", "true", "yes", "on"}
    if _auth_cookie_secure_raw is not None
    else None
)
AUTH_COOKIE_SAMESITE = env_str("AUTH_COOKIE_SAMESITE", "Lax")
AUTH_COOKIE_PATH = env_str("AUTH_COOKIE_PATH", "/")

CLOUDFLARE_TURNSTILE_SITE_KEY = env_str("CLOUDFLARE_TURNSTILE_SITE_KEY")
CLOUDFLARE_TURNSTILE_SECRET_KEY = env_str("CLOUDFLARE_TURNSTILE_SECRET_KEY")
GREENSMS_TOKEN = env_str("GREENSMS_TOKEN")
GREENSMS_USER = env_str("GREENSMS_USER")
GREENSMS_PASSWORD = env_str("GREENSMS_PASSWORD") or env_str("GREENSMS_PASS")
GREENSMS_DEBUG = env_bool("GREENSMS_DEBUG", default=False)
GREENSMS_DEBUG_RETURN_CODE = env_bool("GREENSMS_DEBUG_RETURN_CODE", default=False)
PHONE_VERIFICATION_CODE_TTL_SECONDS = int(env_str("PHONE_VERIFICATION_CODE_TTL_SECONDS", "600") or "600")
PHONE_VERIFICATION_SEND_COOLDOWN_SECONDS = int(
    env_str("PHONE_VERIFICATION_SEND_COOLDOWN_SECONDS", "60") or "60",
)
PHONE_VERIFICATION_MAX_SENDS_PER_HOUR = int(env_str("PHONE_VERIFICATION_MAX_SENDS_PER_HOUR", "5") or "5")
PHONE_VERIFICATION_MAX_SENDS_PER_IP_HOUR = int(
    env_str("PHONE_VERIFICATION_MAX_SENDS_PER_IP_HOUR", "10") or "10",
)
PHONE_VERIFICATION_MAX_ATTEMPTS = int(env_str("PHONE_VERIFICATION_MAX_ATTEMPTS", "5") or "5")

SOCIAL_AUTH_PROVIDERS = {
    "google": {
        "label": "Google",
        "client_id": env_str("GOOGLE_OAUTH_CLIENT_ID"),
        "client_secret": env_str("GOOGLE_OAUTH_CLIENT_SECRET"),
        "auth_url": "https://accounts.google.com/o/oauth2/v2/auth",
        "token_url": "https://oauth2.googleapis.com/token",
        "userinfo_url": "https://www.googleapis.com/oauth2/v3/userinfo",
        "scope": "openid email profile",
    },
    "yandex": {
        "label": "Яндекс",
        "client_id": env_str("YANDEX_OAUTH_CLIENT_ID"),
        "client_secret": env_str("YANDEX_OAUTH_CLIENT_SECRET"),
        "auth_url": "https://oauth.yandex.ru/authorize",
        "token_url": "https://oauth.yandex.ru/token",
        "userinfo_url": "https://login.yandex.ru/info",
        "scope": "login:email login:info",
    },
    "vk": {
        "label": "VK",
        "client_id": env_str("VK_OAUTH_CLIENT_ID"),
        "client_secret": env_str("VK_OAUTH_CLIENT_SECRET"),
        "auth_url": "https://oauth.vk.com/authorize",
        "token_url": "https://oauth.vk.com/access_token",
        "userinfo_url": "https://api.vk.com/method/users.get",
        "scope": "email",
        "api_version": "5.199",
    },
    "telegram": {
        "label": "Telegram",
        "bot_token": env_str("TELEGRAM_BOT_TOKEN"),
        "bot_username": env_str("TELEGRAM_BOT_USERNAME"),
    },
}

LOGGING = {
    "version": 1,
    "disable_existing_loggers": False,
    "formatters": {
        "verbose": {
            "format": "%(asctime)s [%(levelname)s] %(name)s: %(message)s",
        },
        "simple": {
            "format": "[%(levelname)s] %(message)s",
        },
    },
    "handlers": {
        "console": {
            "class": "logging.StreamHandler",
            "formatter": "simple",
            "level": APP_LOG_LEVEL,
        },
        "app_file": {
            "class": "logging.handlers.WatchedFileHandler",
            "filename": str(RUNTIME_LOGS_DIR / "django.log"),
            "formatter": "verbose",
            "level": APP_LOG_LEVEL,
        },
        "error_file": {
            "class": "logging.handlers.WatchedFileHandler",
            "filename": str(RUNTIME_LOGS_DIR / "django.error.log"),
            "formatter": "verbose",
            "level": "ERROR",
        },
    },
    "root": {
        "handlers": ["console", "app_file", "error_file"],
        "level": APP_LOG_LEVEL,
    },
    "loggers": {
        "django": {
            "handlers": ["console", "app_file", "error_file"],
            "level": APP_LOG_LEVEL,
            "propagate": False,
        },
        "apps": {
            "handlers": ["console", "app_file", "error_file"],
            "level": APP_LOG_LEVEL,
            "propagate": False,
        },
    },
}
