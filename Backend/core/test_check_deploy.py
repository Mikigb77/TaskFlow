"""The post-deploy sign-in check (check_deploy), run against the test client instead of HTTPS."""
import json
from io import StringIO
from unittest.mock import patch

from django.core.cache import cache
from django.core.management import call_command
from django.core.management.base import CommandError
from django.test import TestCase, override_settings
from rest_framework.test import APIClient

from core.management.commands.check_deploy import CHECK_EMAIL
from core.models import LoginSession, User

URL = "https://taskflow-api-staging.example.invalid"


def through_test_client(base, method, path, data=None, token=None):
    assert base == URL + "/api/"
    client = APIClient()
    extra = {"HTTP_AUTHORIZATION": f"Bearer {token}"} if token else {}
    response = client.generic(method, "/api/" + path, json.dumps(data) if data is not None else "",
                              content_type="application/json", **extra)
    try:
        body = response.json() if response.content else {}
    except ValueError:
        body = {}
    return response.status_code, body if isinstance(body, dict) else {}


@override_settings(DEPLOYMENT_ENVIRONMENT="staging", GOOGLE_OAUTH_CLIENT_IDS=["web-client.example.invalid"])
class DeployCheckTests(TestCase):
    def setUp(self):
        self.enterContext(patch("core.management.commands.check_deploy.call", side_effect=through_test_client))
        # Google refuses the fake token, as it would after fetching its certificates.
        self.verify = self.enterContext(patch("core.google_auth.id_token.verify_oauth2_token",
                                              side_effect=ValueError("Wrong number of segments")))

    def run_check(self):
        cache.clear()  # the sign-in rate limit, shared by the tests
        out = StringIO()
        call_command("check_deploy", url=URL, stdout=out)
        return out.getvalue()

    def test_signs_in_end_to_end_and_locks_the_account_again(self):
        output = self.run_check()
        self.assertIn("Deploy check passed", output)
        for label in ("Sign in with email and password", "Read the signed-in account", "Renew the session",
                      "Sign out", "Google sign-in refuses a fake token"):
            self.assertIn(f"ok  {label}", output)
        user = User.objects.get(email=CHECK_EMAIL)
        self.assertFalse(user.has_usable_password())
        self.assertTrue(user.email_verified)
        self.assertFalse(user.is_staff)
        self.assertFalse(LoginSession.objects.filter(user=user, revoked=False).exists())
        # It never prints a token.
        self.assertNotIn("eyJ", output)

    def test_runs_again_with_the_same_account(self):
        self.run_check()
        self.run_check()
        self.assertEqual(User.objects.filter(email=CHECK_EMAIL).count(), 1)

    @override_settings(GOOGLE_OAUTH_CLIENT_IDS=[])
    def test_fails_when_google_sign_in_lost_its_client(self):
        with self.assertRaisesMessage(CommandError, "Google sign-in refuses a fake token: expected HTTP 401, received 503"):
            self.run_check()
        self.assertFalse(User.objects.get(email=CHECK_EMAIL).has_usable_password())

    def test_fails_when_sign_in_fails(self):
        with patch("core.auth_views.authenticate", return_value=None):
            with self.assertRaisesMessage(CommandError, "Sign in with email and password: expected HTTP 200, received 401"):
                self.run_check()
        self.assertFalse(User.objects.get(email=CHECK_EMAIL).has_usable_password())

    @override_settings(DEPLOYMENT_ENVIRONMENT="production")
    def test_only_runs_on_staging(self):
        with self.assertRaisesMessage(CommandError, "only runs against staging"):
            self.run_check()
        self.assertFalse(User.objects.filter(email=CHECK_EMAIL).exists())
