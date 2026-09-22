import os
from datetime import timedelta
from pathlib import Path

import dj_database_url

BASE_DIR = Path(__file__).resolve().parent.parent
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
DATABASES = {"default": dj_database_url.config(default="sqlite:///db.sqlite3", conn_max_age=60)}
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
REST_FRAMEWORK = {
    "NUM_PROXIES": 0,
    "DEFAULT_AUTHENTICATION_CLASSES": ["core.authentication.SessionJWTAuthentication"],
    "DEFAULT_PERMISSION_CLASSES": ["rest_framework.permissions.IsAuthenticated"],
    "DEFAULT_RENDERER_CLASSES": ["rest_framework.renderers.JSONRenderer"],
    "DEFAULT_THROTTLE_CLASSES": ["rest_framework.throttling.ScopedRateThrottle"],
    "DEFAULT_THROTTLE_RATES": {"auth": "10/min", "recovery": "5/hour", "tasks": "120/min", "ai": "6/min", "attachments": "60/min"},
    "DEFAULT_PAGINATION_CLASS": "rest_framework.pagination.PageNumberPagination",
    "PAGE_SIZE": 100,
}
SIMPLE_JWT = {
    "ACCESS_TOKEN_LIFETIME": timedelta(minutes=10), "REFRESH_TOKEN_LIFETIME": timedelta(days=7),
    "ROTATE_REFRESH_TOKENS": True, "BLACKLIST_AFTER_ROTATION": True,
    "CHECK_REVOKE_TOKEN": True, "UPDATE_LAST_LOGIN": True,
}
PASSWORD_RESET_TIMEOUT = 1800
EMAIL_BACKEND = "django.core.mail.backends.smtp.EmailBackend"
EMAIL_HOST = os.getenv("EMAIL_HOST", "mailpit")
EMAIL_PORT = int(os.getenv("EMAIL_PORT", "1025"))
DEFAULT_FROM_EMAIL = "TaskFlow <noreply@taskflow.local>"
PASSWORD_RESET_BASE_URL = os.getenv("PASSWORD_RESET_BASE_URL", "http://localhost:8088/reset-password/")
USE_TZ = True
TIME_ZONE = "UTC"
DEFAULT_TIME_ZONE = os.getenv("DEFAULT_TIME_ZONE", "UTC")
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
DATA_UPLOAD_MAX_MEMORY_SIZE = 7 * 1024 * 1024
FILE_UPLOAD_MAX_MEMORY_SIZE = 6 * 1024 * 1024
DATA_UPLOAD_MAX_NUMBER_FILES = 1
FILE_UPLOAD_HANDLERS = ["core.attachment_views.BoundedUploadHandler", "django.core.files.uploadhandler.MemoryFileUploadHandler", "django.core.files.uploadhandler.TemporaryFileUploadHandler"]
MEDIA_ROOT = BASE_DIR / "private_media"
ATTACHMENT_MAX_BYTES = 6 * 1024 * 1024
ATTACHMENT_ACCOUNT_BYTES = 64 * 1024 * 1024
GEMINI_API_KEY = os.getenv("GEMINI_API_KEY", "")
AI_TEXT_MODEL = os.getenv("AI_TEXT_MODEL", "gemma-4-31b-it")
AI_AUDIO_MODEL = os.getenv("AI_AUDIO_MODEL", "gemini-3.5-transcribe")
AI_REQUESTS_PER_DAY = int(os.getenv("AI_REQUESTS_PER_DAY", "50"))
AI_GUEST_REQUESTS_PER_DAY = int(os.getenv("AI_GUEST_REQUESTS_PER_DAY", "5"))
LOCAL_TEST_ACCOUNT_ENABLED = os.getenv("LOCAL_TEST_ACCOUNT_ENABLED", "0") == "1"
LOCAL_TEST_ACCOUNT_EMAIL = os.getenv("LOCAL_TEST_ACCOUNT_EMAIL", "")
LOCAL_TEST_ACCOUNT_PASSWORD = os.getenv("LOCAL_TEST_ACCOUNT_PASSWORD", "")
