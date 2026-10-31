from .settings import *  # noqa: F403

DATABASES = {"default": {"ENGINE": "django.db.backends.sqlite3", "NAME": ":memory:"}}
CACHES = {"default": {"BACKEND": "django.core.cache.backends.locmem.LocMemCache"}}
EMAIL_BACKEND = "django.core.mail.backends.locmem.EmailBackend"
# Tests must not inherit a developer's paid routing choice. Dedicated routing
# tests explicitly override this mode and mock both network adapters.
AI_ROUTE = "ai_studio"
# No test may reach RevenueCat. Without a key only complimentary grants are Pro;
# billing tests set a fixture key and mock the provider.
REVENUECAT_API_KEY = ""
# Existing tests register and sign in at once, as before email verification. The
# verification tests turn it on with override_settings.
EMAIL_VERIFICATION_REQUIRED = False
# Keep real Argon2 hashing and auth validation in security tests.
