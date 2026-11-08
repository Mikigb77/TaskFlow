import os
import json
from datetime import timedelta
from pathlib import Path

import dj_database_url

BASE_DIR = Path(__file__).resolve().parent.parent
if os.getenv("TASKFLOW_CONFIG_FILE"):
    # Cloud Run mounts this Secret Manager version; it is never in the image.
    for key, value in json.loads(Path(os.environ["TASKFLOW_CONFIG_FILE"]).read_text()).items():
        os.environ.setdefault(key, str(value))
if os.getenv("MIGRATION_DATABASE_DIRECT") == "1":
    os.environ["DATABASE_URL"] = os.environ["DATABASE_URL_UNPOOLED"]
SECRET_KEY = os.environ["DJANGO_SECRET_KEY"]
DEBUG = os.getenv("DJANGO_DEBUG", "0") == "1"
ALLOWED_HOSTS = os.getenv("DJANGO_ALLOWED_HOSTS", "localhost,127.0.0.1,10.0.2.2").split(",")
ROOT_URLCONF = "config.urls"
WSGI_APPLICATION = "config.wsgi.application"
INSTALLED_APPS = [
    "django.contrib.auth", "django.contrib.contenttypes", "django.contrib.sessions",
    "django.contrib.messages", "django.contrib.staticfiles", "rest_framework",
    "rest_framework_simplejwt.token_blacklist", "core",
]
MIDDLEWARE = [
    "django.middleware.security.SecurityMiddleware", "django.contrib.sessions.middleware.SessionMiddleware",
    "django.middleware.common.CommonMiddleware", "django.middleware.csrf.CsrfViewMiddleware",
    "django.contrib.auth.middleware.AuthenticationMiddleware", "django.middleware.clickjacking.XFrameOptionsMiddleware",
]
TEMPLATES = [{"BACKEND": "django.template.backends.django.DjangoTemplates",
              "DIRS": [BASE_DIR / "templates"], "APP_DIRS": True, "OPTIONS": {}}]
DATABASES = {"default": dj_database_url.config(default="sqlite:///db.sqlite3", conn_max_age=0, conn_health_checks=True)}
if DATABASES["default"]["ENGINE"].endswith("postgresql"):
    DATABASES["default"]["DISABLE_SERVER_SIDE_CURSORS"] = True
    DATABASES["default"].setdefault("OPTIONS", {})["connect_timeout"] = 15
AUTH_USER_MODEL = "core.User"
PASSWORD_HASHERS = ["django.contrib.auth.hashers.Argon2PasswordHasher", "django.contrib.auth.hashers.PBKDF2PasswordHasher"]
AUTH_PASSWORD_VALIDATORS = [
    {"NAME": "django.contrib.auth.password_validation.UserAttributeSimilarityValidator"},
    {"NAME": "django.contrib.auth.password_validation.MinimumLengthValidator", "OPTIONS": {"min_length": 12}},
    {"NAME": "django.contrib.auth.password_validation.CommonPasswordValidator"},
    {"NAME": "django.contrib.auth.password_validation.NumericPasswordValidator"},
]
CACHES = {"default": {"BACKEND": "django_redis.cache.RedisCache",
                       "LOCATION": os.getenv("REDIS_URL", "redis://cache:6379/0"),
                       "OPTIONS": {"CLIENT_CLASS": "django_redis.client.DefaultClient"}}}
if os.getenv("STATE_BACKEND") == "postgres":
    CACHES = {"default": {"BACKEND": "core.runtime_state.PostgresCache"}}
REST_FRAMEWORK = {
    "NUM_PROXIES": int(os.getenv("TRUSTED_PROXY_COUNT", "0")),
    "DEFAULT_AUTHENTICATION_CLASSES": ["core.authentication.SessionJWTAuthentication"],
    "DEFAULT_PERMISSION_CLASSES": ["rest_framework.permissions.IsAuthenticated"],
    "DEFAULT_RENDERER_CLASSES": ["rest_framework.renderers.JSONRenderer"],
    "DEFAULT_THROTTLE_CLASSES": ["core.runtime_state.AtomicScopedThrottle"] if os.getenv("STATE_BACKEND") == "postgres" else ["rest_framework.throttling.ScopedRateThrottle"],
    "DEFAULT_THROTTLE_RATES": {"auth": "10/min", "recovery": "5/hour", "tasks": "120/min", "ai": "6/min", "attachments": "60/min", "billing": "10/min", "invitations": "10/hour", "meetings": "60/min"},
    "DEFAULT_PAGINATION_CLASS": "rest_framework.pagination.PageNumberPagination",
    "PAGE_SIZE": 100,
}
SIMPLE_JWT = {
    "ACCESS_TOKEN_LIFETIME": timedelta(minutes=10), "REFRESH_TOKEN_LIFETIME": timedelta(days=7),
    "ROTATE_REFRESH_TOKENS": True, "BLACKLIST_AFTER_ROTATION": True,
    "CHECK_REVOKE_TOKEN": True, "UPDATE_LAST_LOGIN": True,
}
PASSWORD_RESET_TIMEOUT = 1800
EMAIL_BACKEND = os.getenv("EMAIL_BACKEND", "django.core.mail.backends.smtp.EmailBackend")
EMAIL_HOST = os.getenv("EMAIL_HOST", "mailpit")
EMAIL_PORT = int(os.getenv("EMAIL_PORT", "1025"))
EMAIL_HOST_USER = os.getenv("EMAIL_HOST_USER", "")
EMAIL_HOST_PASSWORD = os.getenv("EMAIL_HOST_PASSWORD", "")
EMAIL_USE_TLS = os.getenv("EMAIL_USE_TLS", "0") == "1"
EMAIL_TIMEOUT = 8
DEFAULT_FROM_EMAIL = os.getenv("DEFAULT_FROM_EMAIL", "TaskFlow <noreply@taskflow.local>")
RESEND_API_KEY = os.getenv("RESEND_API_KEY", "")
EMAIL_RETRY_QUEUE = os.getenv("EMAIL_RETRY_QUEUE", "")
EMAIL_RETRY_JOB = os.getenv("EMAIL_RETRY_JOB", "")
EMAIL_RETRY_IDENTITY = os.getenv("EMAIL_RETRY_IDENTITY", "")
INVITATION_BASE_URL = os.getenv("INVITATION_BASE_URL", "http://localhost:3000/invite/")
PASSWORD_RESET_BASE_URL = os.getenv("PASSWORD_RESET_BASE_URL", "http://localhost:8088/reset-password/")
USE_TZ = True
TIME_ZONE = "UTC"
DEFAULT_TIME_ZONE = os.getenv("DEFAULT_TIME_ZONE", "UTC")
GOOGLE_OAUTH_CLIENT_IDS = [value.strip() for value in os.getenv("GOOGLE_OAUTH_CLIENT_IDS", "").split(",") if value.strip()]
LANGUAGE_CODE = "en-us"
STATIC_URL = "static/"
DEFAULT_AUTO_FIELD = "django.db.models.BigAutoField"
SECURE_CONTENT_TYPE_NOSNIFF = True
X_FRAME_OPTIONS = "DENY"
SESSION_COOKIE_HTTPONLY = True
SESSION_COOKIE_SAMESITE = "Lax"
SECURE_REFERRER_POLICY = "same-origin"
SECURE_SSL_REDIRECT = os.getenv("REQUIRE_HTTPS", "0") == "1"
SESSION_COOKIE_SECURE = SECURE_SSL_REDIRECT
CSRF_COOKIE_SECURE = SECURE_SSL_REDIRECT
if os.getenv("CLOUD_RUN_PROXY", "0") == "1":
    SECURE_PROXY_SSL_HEADER = ("HTTP_X_FORWARDED_PROTO", "https")
SECURE_HSTS_SECONDS = 3600 if SECURE_SSL_REDIRECT else 0
DATA_UPLOAD_MAX_MEMORY_SIZE = 7 * 1024 * 1024
FILE_UPLOAD_MAX_MEMORY_SIZE = 6 * 1024 * 1024
DATA_UPLOAD_MAX_NUMBER_FILES = 1
FILE_UPLOAD_HANDLERS = ["core.attachment_views.BoundedUploadHandler", "django.core.files.uploadhandler.MemoryFileUploadHandler", "django.core.files.uploadhandler.TemporaryFileUploadHandler"]
MEDIA_ROOT = BASE_DIR / "private_media"
ATTACHMENT_MAX_BYTES = 6 * 1024 * 1024
# What an account or project owner may upload, in MiB like the per-file limit
# (core.models.AttachmentUsage). Without Pro: this much in the account's whole
# history, so removed and cleaned-up files still count. With Pro: this much each
# UTC calendar month. The 1,000-file bound applies to everyone.
FREE_ATTACHMENT_BYTES = int(os.getenv("FREE_ATTACHMENT_MB", "200")) * 1024 * 1024
PRO_ATTACHMENT_BYTES_PER_MONTH = int(os.getenv("PRO_ATTACHMENT_MB_PER_MONTH", "500")) * 1024 * 1024
# A completed task's files are deleted from storage this many days after it was
# completed, for every account (maintain_staging; core.attachment_views.sweep).
ATTACHMENT_RETENTION_DAYS = int(os.getenv("ATTACHMENT_RETENTION_DAYS", "15"))
if os.getenv("AWS_ENDPOINT_URL_S3"):
    from botocore.config import Config as S3Config
    STORAGES = {
        "default": {"BACKEND": "storages.backends.s3.S3Storage", "OPTIONS": {
            "access_key": os.environ["AWS_ACCESS_KEY_ID"],
            "secret_key": os.environ["AWS_SECRET_ACCESS_KEY"],
            "bucket_name": os.getenv("ATTACHMENT_BUCKET", "docs4taskflow"),
            "endpoint_url": os.environ["AWS_ENDPOINT_URL_S3"],
            "region_name": os.getenv("AWS_REGION", "eu-central-1"),
            "addressing_style": "path", "signature_version": "s3v4",
            "default_acl": None, "file_overwrite": False,
            "querystring_auth": True,
            "client_config": S3Config(connect_timeout=10, read_timeout=30,
                retries={"max_attempts": 2, "mode": "standard"},
                signature_version="s3v4", s3={"addressing_style": "path"}),
        }},
        "staticfiles": {"BACKEND": "django.contrib.staticfiles.storage.StaticFilesStorage"},
    }
# Every AI call runs on Vertex AI with Application Default Credentials: no API key exists.
AI_VERTEX_PROJECT = os.getenv("AI_VERTEX_PROJECT", "")
AI_VERTEX_LOCATION = os.getenv("AI_VERTEX_LOCATION", "global")
AI_VERTEX_TEXT_MODEL = os.getenv("AI_VERTEX_TEXT_MODEL", "gemini-3.1-flash-lite")
AI_VERTEX_AUDIO_MODEL = os.getenv("AI_VERTEX_AUDIO_MODEL", "gemini-3.1-flash-lite")
# Meeting notes (docs/MEETINGS.md). The pieces' fallback
# model is gemini-3.5-transcribe; changing the setting is enough.
AI_MEETING_AUDIO_MODEL = os.getenv("AI_MEETING_AUDIO_MODEL", "gemini-3.5-flash-lite")
AI_MEETING_TEXT_MODEL = os.getenv("AI_MEETING_TEXT_MODEL", "gemini-3.5-flash-lite")
# Pieces of about 5 minutes per UTC calendar month for each Pro account: 240 is about 20 hours.
AI_MEETING_PIECES_PER_MONTH = int(os.getenv("AI_MEETING_PIECES_PER_MONTH", "240"))
MEETING_PIECE_MAX_BYTES = 8 * 1024 * 1024
LOGGING = {
    "version": 1, "disable_existing_loggers": False,
    "handlers": {"ai_console": {"class": "logging.StreamHandler"}},
    "loggers": {"core.ai_routing": {"handlers": ["ai_console"], "level": "INFO", "propagate": False}},
}
AI_REQUESTS_PER_DAY = int(os.getenv("AI_REQUESTS_PER_DAY", "50"))
AI_GLOBAL_REQUESTS_PER_DAY = int(os.getenv("AI_GLOBAL_REQUESTS_PER_DAY", "200"))
# AI dictations per UTC calendar month for accounts without Pro.
FREE_VOICE_CAPTURES_PER_MONTH = int(os.getenv("FREE_VOICE_CAPTURES_PER_MONTH", "10"))
DEPLOYMENT_ENVIRONMENT = os.getenv("DEPLOYMENT_ENVIRONMENT", "production")
# The staging app's own updater reads the newest release of this repository
# (core/app_updates.py). Off without a token, as in production, where Google
# Play updates the app.
APP_UPDATE_REPOSITORY = os.getenv("APP_UPDATE_REPOSITORY", "Mikigb77/TaskFlow")
APP_UPDATE_GITHUB_TOKEN = os.getenv("APP_UPDATE_GITHUB_TOKEN", "")
STAGING_ALLOWED_EMAILS = {email.strip().casefold() for email in os.getenv("STAGING_ALLOWED_EMAILS", "").split(",") if email.strip()}
COMPLIMENTARY_PRO_EMAILS = {email.strip().casefold() for email in os.getenv("COMPLIMENTARY_PRO_EMAILS", "").split(",") if email.strip()}
# Existing password accounts need an explicit server-approved, opaque identity.
# New email matches qualify only after Google has verified their ownership.
COMPLIMENTARY_PRO_BILLING_IDS = {value.strip() for value in os.getenv("COMPLIMENTARY_PRO_BILLING_IDS", "").split(",") if value.strip()}
REVENUECAT_API_KEY = os.getenv("REVENUECAT_API_KEY", "")
REVENUECAT_ALLOW_SANDBOX = os.getenv("REVENUECAT_ALLOW_SANDBOX", "0") == "1"
LOCAL_TEST_ACCOUNT_ENABLED = os.getenv("LOCAL_TEST_ACCOUNT_ENABLED", "0") == "1"
LOCAL_TEST_ACCOUNT_EMAIL = os.getenv("LOCAL_TEST_ACCOUNT_EMAIL", "")
LOCAL_TEST_ACCOUNT_PASSWORD = os.getenv("LOCAL_TEST_ACCOUNT_PASSWORD", "")
