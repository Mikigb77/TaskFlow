import json
import time
from unittest.mock import patch

from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.primitives.asymmetric import rsa
from django.core.cache import cache
from django.test import TestCase, override_settings
from google.auth import crypt, exceptions, jwt
from rest_framework.test import APIClient

from .models import GoogleIdentity, LoginSession, Task, User

AUDIENCE = "synthetic-web-client.apps.googleusercontent.com"
PASSWORD = "Synthetic-test-password!2026"


@override_settings(GOOGLE_OAUTH_CLIENT_IDS=[AUDIENCE])
class GoogleAuthTests(TestCase):
    @classmethod
    def setUpClass(cls):
        super().setUpClass()
        key = rsa.generate_private_key(public_exponent=65537, key_size=2048)
        private = key.private_bytes(serialization.Encoding.PEM,
                                    serialization.PrivateFormat.PKCS8,
                                    serialization.NoEncryption())
        cls.signer = crypt.RSASigner.from_string(private, key_id="fixture")
        cls.public = key.public_key().public_bytes(serialization.Encoding.PEM,
                                                   serialization.PublicFormat.SubjectPublicKeyInfo).decode()

    def setUp(self):
        cache.clear()
        self.client = APIClient()
        # Only certificate transport is mocked. Google's real JWT signature,
        # audience, issuer and expiry validation all execute in these tests.
        class CertResponse:
            status = 200
            data = json.dumps({"fixture": self.public}).encode()
        self.transport = self.enterContext(patch("core.google_auth.Request"))
        self.transport.return_value.return_value = CertResponse()

    def token(self, **changes):
        claims = {"iss": "https://accounts.google.com", "aud": AUDIENCE,
                  "iat": int(time.time()) - 1, "exp": int(time.time()) + 300,
                  "sub": "google-subject-1", "email": "person@example.invalid",
                  "email_verified": True}
        claims.update(changes)
        return jwt.encode(self.signer, claims).decode()

    def login(self, **changes):
        return self.client.post("/api/auth/google/", {
            "id_token": self.token(**changes), "timezone": "Europe/Madrid"}, format="json")

    def test_verified_signup_reuses_identity_and_issues_normal_revocable_session(self):
        first = self.login()
        self.assertEqual(first.status_code, 200, first.data)
        user = User.objects.get()
        self.assertFalse(user.has_usable_password())
        self.assertEqual(user.timezone, "Europe/Madrid")
        self.assertTrue(first.data["user"]["google_linked"])
        second = self.login(email="renamed@example.invalid")
        self.assertEqual(second.data["user"]["id"], user.pk)
        self.assertEqual(second.data["user"]["billing_id"], str(user.billing_id))
        self.assertEqual(User.objects.count(), 1)
        self.transport.return_value.assert_called_with(
            "https://www.googleapis.com/oauth2/v1/certs", method="GET", timeout=5)
        self.client.credentials(HTTP_AUTHORIZATION="Bearer " + first.data["access"])
        self.assertEqual(self.client.get("/api/auth/me/").status_code, 200)
        self.assertEqual(self.client.post("/api/auth/logout/", {}, format="json").status_code, 204)
        self.assertEqual(self.client.get("/api/auth/me/").status_code, 401)

    @override_settings(COMPLIMENTARY_PRO_EMAILS={"owner@example.invalid"}, COMPLIMENTARY_PRO_BILLING_IDS=set())
    def test_verified_owner_gets_complimentary_pro_in_login_response(self):
        response = self.login(email="owner@example.invalid")
        self.assertEqual(response.status_code, 200)
        self.assertTrue(response.data["user"]["complimentary_pro"])

    def test_rejects_wrong_audience_issuer_expiry_and_unverified_email(self):
        for change in [{"aud": "another-app"}, {"iss": "https://evil.invalid"},
                       {"exp": int(time.time()) - 60}, {"email_verified": False},
                       {"email_verified": "true"}, {"sub": ""}]:
            with self.subTest(change=change):
                self.assertEqual(self.login(**change).status_code, 401)
        self.assertFalse(User.objects.exists())
        self.assertFalse(LoginSession.objects.exists())

    def test_rejects_forged_signature(self):
        token = self.token()
        header, payload, signature = token.split('.')
        signature = ('A' if signature[0] != 'A' else 'B') + signature[1:]
        result = self.client.post('/api/auth/google/', {'id_token': '.'.join([header, payload, signature])}, format='json')
        self.assertEqual(result.status_code, 401)
        self.assertFalse(User.objects.exists())

    @override_settings(GOOGLE_OAUTH_CLIENT_IDS=[])
    def test_missing_server_configuration_fails_closed(self):
        self.assertEqual(self.login().status_code, 503)
        self.transport.assert_not_called()
        self.assertFalse(User.objects.exists())

    def test_certificate_network_error_is_retryable_and_does_not_create_account(self):
        self.transport.return_value.side_effect = exceptions.TransportError('synthetic timeout')
        self.assertEqual(self.login().status_code, 503)
        self.assertFalse(User.objects.exists())

    def test_existing_email_is_never_automatically_linked(self):
        user = User.objects.create_user('PERSON@example.invalid', PASSWORD)
        result = self.login()
        self.assertEqual(result.status_code, 409)
        self.assertEqual(result.data['code'], 'google_link_required')
        self.assertFalse(GoogleIdentity.objects.exists())
        self.assertFalse(LoginSession.objects.exists())
        self.assertTrue(User.objects.get(pk=user.pk).check_password(PASSWORD))

    def test_explicit_link_preserves_tasks_and_billing_identity(self):
        user = User.objects.create_user('person@example.invalid', PASSWORD)
        task = Task.objects.create(owner=user, title='Keep my task')
        original_billing_id = user.billing_id
        self.client.force_authenticate(user)
        result = self.client.post('/api/auth/google/link/', {
            'id_token': self.token(), 'password': PASSWORD}, format='json')
        self.assertEqual(result.status_code, 200, result.data)
        self.assertTrue(result.data['google_linked'])
        self.client.force_authenticate(None)
        login = self.login()
        self.assertEqual(login.data['user']['id'], user.pk)
        self.assertEqual(login.data['user']['billing_id'], str(original_billing_id))
        self.assertEqual(Task.objects.get(pk=task.pk).owner_id, user.pk)

    def test_link_requires_session_current_password_and_matching_email(self):
        user = User.objects.create_user('person@example.invalid', PASSWORD)
        data = {'id_token': self.token(), 'password': PASSWORD}
        self.assertEqual(self.client.post('/api/auth/google/link/', data, format='json').status_code, 401)
        self.client.force_authenticate(user)
        result = self.client.post('/api/auth/google/link/', {**data, 'password': 'wrong'}, format='json')
        self.assertEqual(result.status_code, 400)
        self.transport.assert_not_called()
        result = self.client.post('/api/auth/google/link/', {**data, 'id_token': self.token(email='other@example.invalid')}, format='json')
        self.assertEqual(result.status_code, 409)
        self.assertFalse(GoogleIdentity.objects.exists())

    def test_identity_cannot_be_transferred_to_another_user(self):
        original = User.objects.create_user('old@example.invalid', PASSWORD)
        GoogleIdentity.objects.create(user=original, subject='google-subject-1')
        another = User.objects.create_user('person@example.invalid', PASSWORD)
        self.client.force_authenticate(another)
        result = self.client.post('/api/auth/google/link/', {'id_token': self.token(), 'password': PASSWORD}, format='json')
        self.assertEqual(result.status_code, 409)
        self.assertEqual(GoogleIdentity.objects.get().user_id, original.pk)

    def test_disabled_user_cannot_sign_in(self):
        user = User.objects.create_user('person@example.invalid', is_active=False)
        GoogleIdentity.objects.create(user=user, subject='google-subject-1')
        self.assertEqual(self.login().status_code, 401)
        self.assertFalse(LoginSession.objects.exists())

    def test_bad_timezone_does_not_create_account_or_contact_google(self):
        result = self.client.post('/api/auth/google/', {'id_token': self.token(), 'timezone': 'Not/AZone'}, format='json')
        self.assertEqual(result.status_code, 400)
        self.transport.assert_not_called()
