"""After a staging deploy, sign in end to end through the public URL.

Backend/scripts/deploy-staging-ci.sh runs it as the taskflow-api-staging-check
Cloud Run job, once the new revision serves. It gives its own check account a
new random password, signs in over HTTPS the way the app does, reads the
account, renews the session and signs out. Then it sends Google sign-in a fake
token, which a working API refuses as invalid: that proves the API knows its
Google client and can reach Google's certificates. Last, the check account's
password becomes unusable again, so nobody can sign in to it between deploys.

It prints which checks passed or failed, never a password or a token.
"""
import json
import secrets
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen

from django.conf import settings
from django.core.management.base import BaseCommand, CommandError

from core.models import LoginSession, User

# Resend's simulated recipient: nothing is ever delivered to a real inbox.
CHECK_EMAIL = "delivered+tf-deploy-check@resend.dev"


def call(base, method, path, data=None, token=None):
    """One request to the deployed API: (status, JSON body or {})."""
    headers = {"Content-Type": "application/json", "Accept": "application/json"}
    if token:
        headers["Authorization"] = f"Bearer {token}"
    request = Request(base + path, method=method, headers=headers,
                      data=None if data is None else json.dumps(data).encode())
    try:
        with urlopen(request, timeout=90) as response:
            status, raw = response.status, response.read()
    except HTTPError as error:
        status, raw = error.code, error.read()
    except URLError as error:
        raise CommandError(f"{method} {path}: the API could not be reached ({error.reason}).") from None
    try:
        body = json.loads(raw) if raw else {}
    except ValueError:
        body = {}
    return status, body if isinstance(body, dict) else {}


class Command(BaseCommand):
    help = "Sign in to the deployed staging API end to end with the deploy check account."

    def add_arguments(self, parser):
        parser.add_argument("--url", required=True, help="The API's public URL, e.g. https://….run.app")

    def handle(self, *args, url, **options):
        if settings.DEPLOYMENT_ENVIRONMENT != "staging":
            raise CommandError("The deploy check only runs against staging.")
        if not url.startswith("https://"):
            raise CommandError("The deploy check needs the API's HTTPS URL.")
        base = url.rstrip("/") + "/api/"
        password = secrets.token_urlsafe(32)
        user, _ = User.objects.get_or_create(email=CHECK_EMAIL, defaults={
            "first_name": "Deploy check", "timezone": settings.DEFAULT_TIME_ZONE})
        if user.is_staff or user.is_superuser:
            raise CommandError("The deploy check account must not be staff.")
        user.set_password(password)
        user.is_active = True
        user.email_verified = True  # the normal sign-in needs a confirmed address
        user.save(update_fields=["password", "is_active", "email_verified"])
        try:
            self.run_checks(base, password)
        finally:
            user.set_unusable_password()
            user.save(update_fields=["password"])
            LoginSession.objects.filter(user=user, revoked=False).update(revoked=True)
        self.stdout.write(self.style.SUCCESS("Deploy check passed: sign-in works end to end."))

    def expect(self, label, status, wanted, ok=True):
        if status != wanted or not ok:
            raise CommandError(f"{label}: expected HTTP {wanted}, received {status}.")
        self.stdout.write(f"ok  {label}")

    def run_checks(self, base, password):
        status, body = call(base, "GET", "health/")
        self.expect("Health, with the database", status, 200, body.get("status") == "ok")

        status, body = call(base, "POST", "auth/login/", {"email": CHECK_EMAIL, "password": password})
        self.expect("Sign in with email and password", status, 200, bool(body.get("access") and body.get("refresh")))
        access, refresh = body["access"], body["refresh"]

        status, body = call(base, "GET", "auth/me/", token=access)
        self.expect("Read the signed-in account", status, 200, body.get("email") == CHECK_EMAIL)

        status, body = call(base, "POST", "auth/refresh/", {"refresh": refresh})
        self.expect("Renew the session", status, 200, bool(body.get("access")))
        access = body["access"]

        status, _ = call(base, "POST", "auth/logout/", {}, token=access)
        self.expect("Sign out", status, 204)

        status, body = call(base, "POST", "auth/google/", {"id_token": "deploy-check", "timezone": "UTC"})
        # 503 google_not_configured: no Google client ID. 503 alone: Google's certificates are out of reach.
        self.expect("Google sign-in refuses a fake token", status, 401,
                    body.get("code") == "google_invalid_token")
