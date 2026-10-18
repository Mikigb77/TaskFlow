import hashlib
import io
import json
import logging
import re
import time
from contextlib import contextmanager
from datetime import timedelta
from unittest.mock import patch

from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.primitives.asymmetric import rsa
from django.conf import settings
from django.core import mail
from django.core.cache import cache
from django.core.management import call_command
from django.db import connection
from django.db.migrations.executor import MigrationExecutor
from django.db.models import F
from django.test import TestCase, TransactionTestCase, override_settings
from django.utils import timezone
from google.auth import crypt, jwt
from rest_framework.test import APIClient

from .auth_views import ResendVerificationView, VerifyEmailView
from .email_delivery import deliver_email, reserve_email
from .email_verification import SCRUBBED_SUBJECT, verification_required
from .models import EmailDelivery, EmailVerification, GoogleIdentity, LoginSession, User
from .serializers import UserSerializer

EMAIL = "new@example.invalid"
PASSWORD = "Verification-test-passphrase!2026"
OTHER_PASSWORD = "Another-test-passphrase!2026"
REGISTER, LOGIN = "/api/auth/register/", "/api/auth/login/"
VERIFY, RESEND = "/api/auth/verify-email/", "/api/auth/verify-email/resend/"
ENGLISH = ("Your code to confirm your email for TaskFlow is {code}. It expires in 30 minutes. "
           "If you didn't create a TaskFlow account, ignore this message.")
SPANISH = ("Tu código para confirmar tu correo en TaskFlow es {code}. Caduca en 30 minutos. "
           "Si no has creado una cuenta de TaskFlow, ignora este mensaje.")
CATALAN = ("El teu codi per confirmar el teu correu a TaskFlow és {code}. Caduca d’aquí a 30 minuts. "
           "Si no has creat cap compte de TaskFlow, ignora aquest missatge.")
AUDIENCE = "synthetic-web-client.apps.googleusercontent.com"


def code_in(message):
    return re.search(r"[0-9]{6}", message.subject).group()


def codes(*values):
    """Fix the codes the server picks, in order."""
    return patch("core.email_verification.secrets.randbelow", side_effect=list(values))


@contextmanager
def captured_logs():
    lines = []

    class Collect(logging.Handler):
        def emit(self, record):
            lines.append(logging.Formatter().format(record))

    handler, root = Collect(logging.DEBUG), logging.getLogger()
    level = root.level
    root.addHandler(handler)
    root.setLevel(logging.DEBUG)
    try:
        yield lines
    finally:
        root.removeHandler(handler)
        root.setLevel(level)


class VerificationTestCase(TestCase):
    def setUp(self):
        cache.clear()
        self.client = APIClient()

    def register(self, email=EMAIL, password=PASSWORD, **extra):
        return self.client.post(REGISTER, {"email": email, "password": password, **extra}, format="json")

    def login(self, email=EMAIL, password=PASSWORD, **extra):
        return self.client.post(LOGIN, {"email": email, "password": password, **extra}, format="json")

    def verify(self, code, email=EMAIL, password=PASSWORD):
        # The app sends the password the person just typed; None leaves it out.
        data = {"email": email, "code": code}
        if password is not None:
            data["password"] = password
        return self.client.post(VERIFY, data, format="json")

    def resend(self, email=EMAIL, **extra):
        return self.client.post(RESEND, {"email": email, **extra}, format="json")

    def age_last_code(self, seconds=61):
        # As if the latest code went out a minute ago: past the one-a-minute limit.
        EmailVerification.objects.update(sent_at=F("sent_at") - timedelta(seconds=seconds))


@override_settings(EMAIL_VERIFICATION_REQUIRED=True)
class EmailVerificationTests(VerificationTestCase):
    def test_register_sends_a_code_and_gives_no_tokens(self):
        response = self.register(" New@Example.INVALID ")
        self.assertEqual(response.status_code, 201, response.data)
        self.assertEqual(response.data, {"verification_required": True, "email": EMAIL})
        user = User.objects.get()
        self.assertEqual(user.email, EMAIL)
        self.assertFalse(user.email_verified)
        self.assertFalse(LoginSession.objects.exists())
        [message] = mail.outbox
        self.assertEqual(message.to, [EMAIL])
        self.assertEqual(message.from_email, settings.DEFAULT_FROM_EMAIL)
        if getattr(settings, "EMAIL_SUPPORT_ADDRESS", ""):
            self.assertEqual(message.reply_to, [settings.EMAIL_SUPPORT_ADDRESS])
        self.assertRegex(message.subject, r"^Your TaskFlow code: [0-9]{6}$")
        self.assertIn(ENGLISH.format(code=code_in(message)), message.body)
        row = EmailVerification.objects.get(user=user)
        self.assertAlmostEqual(row.expires_at, timezone.now() + timedelta(minutes=30), delta=timedelta(seconds=30))

    def test_login_while_unverified_is_refused_and_sends_a_fresh_code(self):
        with codes(111111, 222222):
            self.register()
            wrong = self.login(password="Not-the-passphrase!2026")
            self.assertEqual(wrong.status_code, 401)
            self.assertEqual(wrong.data, {"detail": "Email or password is incorrect."})
            # Within a minute of the last code: refused, without a second email.
            self.assertEqual(self.login().status_code, 403)
            self.assertEqual(len(mail.outbox), 1)
            self.age_last_code()
            response = self.login()
        self.assertEqual(response.status_code, 403)
        self.assertEqual(set(response.data), {"code", "detail", "email"})
        self.assertEqual((response.data["code"], response.data["email"]), ("email_unverified", EMAIL))
        self.assertFalse(LoginSession.objects.exists())
        self.assertEqual([code_in(message) for message in mail.outbox], ["111111", "222222"])
        # The fresh code replaces the first one.
        self.assertEqual(self.verify("111111").data["code"], "code_invalid")
        self.assertEqual(self.verify("222222").status_code, 200)

    def test_verifying_gives_the_same_session_as_signing_in(self):
        self.register()
        code = code_in(mail.outbox[0])
        response = self.verify(f"{code[:3]} {code[3:]}")  # spaces typed from the email are fine
        self.assertEqual(response.status_code, 200, response.data)
        self.assertEqual(set(response.data), {"access", "refresh", "user"})
        user = User.objects.get()
        self.assertTrue(user.email_verified)
        self.assertEqual(response.data["user"], UserSerializer(user).data)
        self.assertFalse(EmailVerification.objects.exists())
        self.client.credentials(HTTP_AUTHORIZATION="Bearer " + response.data["access"])
        self.assertEqual(self.client.get("/api/auth/me/").data["email"], EMAIL)
        self.client.credentials()
        signed_in = self.login()
        self.assertEqual(signed_in.status_code, 200)
        self.assertEqual(set(signed_in.data), set(response.data))
        # The code is used up, and a confirmed address is sent nothing more.
        self.assertEqual(self.verify(code).data["code"], "code_expired")
        self.assertEqual(self.resend().status_code, 204)
        self.assertEqual(len(mail.outbox), 1)

    def test_a_code_sent_as_a_number_keeps_its_leading_zeros(self):
        with codes(4321):
            self.register()
        self.assertEqual(code_in(mail.outbox[0]), "004321")
        self.assertEqual(self.verify(4321).status_code, 200)

    def test_a_wrong_code_is_invalid_and_five_wrong_tries_lock_it(self):
        self.register()
        code = code_in(mail.outbox[0])
        wrong = f"{(int(code) + 1) % 10 ** 6:06d}"
        for _ in range(5):
            response = self.verify(wrong)
            self.assertEqual(response.status_code, 400)
            self.assertEqual(set(response.data), {"code", "detail"})
            self.assertEqual(response.data["code"], "code_invalid")
        locked = self.verify(code)
        self.assertEqual(locked.status_code, 400)
        self.assertEqual(locked.data["code"], "code_expired")
        self.assertFalse(User.objects.get().email_verified)
        self.assertFalse(LoginSession.objects.exists())

    def test_expired_unknown_and_confirmed_all_look_expired(self):
        self.register()
        code = code_in(mail.outbox[0])
        EmailVerification.objects.update(expires_at=timezone.now() - timedelta(seconds=1))
        User.objects.create_user("confirmed@example.invalid", PASSWORD, email_verified=True)
        responses = [self.verify(code), self.verify(code, "unknown@example.invalid"),
                     self.verify(code, "confirmed@example.invalid")]
        for response in responses:
            self.assertEqual(response.status_code, 400)
            self.assertEqual(response.data, responses[0].data)
        self.assertEqual(set(responses[0].data), {"code", "detail"})
        self.assertEqual(responses[0].data["code"], "code_expired")
        self.assertFalse(User.objects.get(email=EMAIL).email_verified)

    def test_resend_answers_the_same_for_anyone_and_replaces_the_code(self):
        unknown = self.resend("unknown@example.invalid")
        self.assertEqual(unknown.status_code, 204)
        self.assertFalse(mail.outbox)
        self.assertFalse(User.objects.exists())
        with codes(111111, 222222):
            self.register()
            self.assertEqual(self.resend().status_code, 204)  # within a minute: nothing
            self.assertEqual(len(mail.outbox), 1)
            self.age_last_code()
            self.assertEqual(self.resend().status_code, 204)
        self.assertEqual([code_in(message) for message in mail.outbox], ["111111", "222222"])
        self.assertEqual(self.verify("111111").data["code"], "code_invalid")
        self.assertEqual(self.verify("222222").status_code, 200)

    def test_resend_sends_one_code_a_minute_and_five_an_hour(self):
        self.register()
        self.resend()
        self.assertEqual(len(mail.outbox), 1)
        for sent in (2, 3, 4, 5):
            self.age_last_code()
            self.resend()
            self.assertEqual(len(mail.outbox), sent)
        self.age_last_code()
        self.resend()  # a sixth code in the same hour
        self.assertEqual(len(mail.outbox), 5)
        EmailVerification.objects.update(hour_started_at=F("hour_started_at") - timedelta(hours=1))
        self.resend()
        self.assertEqual(len(mail.outbox), 6)

    def test_the_outbox_limits_apply_too(self):
        for _ in range(8):  # this address's emails for today are used up
            reserve_email(EMAIL)
        response = self.register()
        self.assertEqual(response.status_code, 429)
        self.assertFalse(User.objects.exists())
        self.register("other@example.invalid")
        for _ in range(7):
            reserve_email("other@example.invalid")
        self.age_last_code()
        self.assertEqual(self.resend("other@example.invalid").status_code, 204)
        self.assertEqual(self.login("other@example.invalid").status_code, 403)
        self.assertEqual(len(mail.outbox), 1)

    def test_registering_again_replaces_an_unconfirmed_sign_up(self):
        with codes(111111, 222222):
            self.register(first_name="Typo", timezone="Europe/Madrid", language="es")
            original = User.objects.get()
            self.age_last_code()
            response = self.register(EMAIL.upper(), OTHER_PASSWORD, first_name="Rightful",
                                     timezone="America/New_York")
        self.assertEqual(response.status_code, 201, response.data)
        self.assertEqual(response.data, {"verification_required": True, "email": EMAIL})
        # The new sign-up's email follows its own request, not the replaced one's.
        self.assertEqual(mail.outbox[1].subject, "Your TaskFlow code: 222222")
        user = User.objects.get()
        self.assertEqual(user.pk, original.pk)
        self.assertTrue(user.check_password(OTHER_PASSWORD))
        self.assertFalse(user.check_password(PASSWORD))
        self.assertEqual((user.first_name, user.timezone), ("Rightful", "America/New_York"))
        self.assertFalse(user.email_verified)
        self.assertEqual(self.verify("111111", password=OTHER_PASSWORD).data["code"], "code_invalid")
        self.assertEqual(self.verify("222222", password=OTHER_PASSWORD).status_code, 200)
        # Once confirmed, the address is taken.
        taken = self.register()
        self.assertEqual(taken.status_code, 400)
        self.assertEqual(taken.data, {"email": ["An account with this email already exists."]})
        self.assertTrue(User.objects.get().check_password(OTHER_PASSWORD))

    def test_a_sign_up_replaced_before_its_code_is_entered_is_not_confirmed(self):
        # Someone signs up, then the same address is signed up again with another password.
        with codes(111111, 222222):
            self.register()
            self.age_last_code()
            self.register(password=OTHER_PASSWORD)
        # The first person enters a code from their mailbox, with the password they chose.
        for code in ("222222", "111111"):
            replaced = self.verify(code)
            self.assertEqual(replaced.status_code, 400)
            self.assertEqual(set(replaced.data), {"code", "detail"})
            self.assertEqual(replaced.data["code"], "signup_replaced")
        self.assertFalse(User.objects.get().email_verified)
        self.assertFalse(LoginSession.objects.exists())
        self.assertEqual(EmailVerification.objects.get().attempts, 0)  # no code try spent
        # The newer sign-up confirms with its own password.
        self.assertEqual(self.verify("222222", password=OTHER_PASSWORD).status_code, 200)

    def test_a_missing_password_answers_signup_replaced(self):
        self.register()
        code = code_in(mail.outbox[0])
        for password in (None, ""):
            response = self.verify(code, password=password)
            self.assertEqual(response.status_code, 400)
            self.assertEqual(response.data["code"], "signup_replaced")
        self.assertEqual(EmailVerification.objects.get().attempts, 0)
        self.assertFalse(User.objects.get().email_verified)
        # A missing password guesses nothing, so it doesn't count toward sign-in's lock.
        for _ in range(4):
            self.verify(code, password=None)
        self.assertEqual(self.verify(code).status_code, 200)

    def test_wrong_passwords_here_count_toward_the_sign_in_lock(self):
        self.register()
        code = code_in(mail.outbox[0])
        for _ in range(3):
            self.assertEqual(self.login(password="Not-the-passphrase!2026").status_code, 401)
        for _ in range(2):
            self.assertEqual(self.verify(code, password="Not-the-passphrase!2026").data["code"], "signup_replaced")
        # Five wrong passwords across sign-in and verification: both wait, even with the right one.
        self.assertEqual(self.verify(code).status_code, 429)
        self.assertEqual(self.login().status_code, 429)
        self.assertEqual(EmailVerification.objects.get().attempts, 0)
        self.assertFalse(User.objects.get().email_verified)

    def test_registering_again_within_a_minute(self):
        self.register()
        code = code_in(mail.outbox[0])
        # The same person tapping again keeps the code already sent.
        again = self.register()
        self.assertEqual(again.status_code, 201)
        self.assertEqual(again.data, {"verification_required": True, "email": EMAIL})
        self.assertEqual(len(mail.outbox), 1)
        # Another password has to wait, and changes nothing meanwhile.
        self.assertEqual(self.register(password=OTHER_PASSWORD).status_code, 429)
        self.assertTrue(User.objects.get().check_password(PASSWORD))
        self.assertEqual(self.verify(code).status_code, 200)

    def test_a_password_reset_confirms_the_address(self):
        self.register()
        self.assertEqual(self.client.post("/api/auth/password-reset/", {"email": EMAIL}, format="json").status_code, 200)
        recovery = re.search(r"recovery code in the app:\n(\S+)", mail.outbox[1].body).group(1)
        response = self.client.post("/api/auth/password-reset/confirm/",
                                    {"code": recovery, "password": OTHER_PASSWORD}, format="json")
        self.assertEqual(response.status_code, 200, response.data)
        self.assertTrue(User.objects.get().email_verified)
        self.assertFalse(EmailVerification.objects.exists())
        self.assertEqual(self.login(password=OTHER_PASSWORD).status_code, 200)

    def test_the_email_language_follows_the_request_with_english_as_fallback(self):
        cases = [("es", "Tu código de TaskFlow: {code}", SPANISH),
                 ("ca", "El teu codi de TaskFlow: {code}", CATALAN),
                 ("en", "Your TaskFlow code: {code}", ENGLISH),
                 ("es-ES", "Tu código de TaskFlow: {code}", SPANISH),
                 ("fr", "Your TaskFlow code: {code}", ENGLISH),
                 (None, "Your TaskFlow code: {code}", ENGLISH)]
        for index, (language, subject, body) in enumerate(cases):
            with self.subTest(language=language):
                extra = {} if language is None else {"language": language}
                self.assertEqual(self.register(f"person{index}@example.invalid", **extra).status_code, 201)
                message = mail.outbox[-1]
                code = code_in(message)
                self.assertEqual(message.subject, subject.format(code=code))
                self.assertIn(body.format(code=code), message.body)

    def test_later_codes_keep_the_sign_up_language(self):
        self.register(language="ca")
        self.age_last_code()
        self.resend()
        self.age_last_code()
        self.login()
        self.age_last_code()
        self.resend(language="es")
        subjects = [message.subject.rsplit(":", 1)[0] for message in mail.outbox]
        self.assertEqual(subjects, ["El teu codi de TaskFlow"] * 3 + ["Tu código de TaskFlow"])

    def test_the_code_is_never_stored_or_logged_in_plain_text(self):
        code = "482913"
        with captured_logs() as lines, codes(int(code)):
            logging.getLogger("core").debug("capture check")
            self.register()
            row = EmailVerification.objects.get()
            self.assertRegex(row.code_digest, r"^[0-9a-f]{64}$")
            for unsalted in (code, f"{row.user_id}:{code}"):
                self.assertNotEqual(row.code_digest, hashlib.sha256(unsalted.encode()).hexdigest())
            self.assertIn(code, mail.outbox[0].subject)  # the person did get it
            delivery = EmailDelivery.objects.get()
            self.assertEqual((delivery.state, delivery.subject, delivery.body), ("sent", SCRUBBED_SUBJECT, ""))
            self.assertEqual(self.verify("000000").data["code"], "code_invalid")
            self.assertEqual(self.verify(code).status_code, 200)
        self.assertIn("capture check", lines)
        self.assertEqual([line for line in lines if code in line or PASSWORD in line], [])

    def test_an_unsent_email_for_a_replaced_code_never_goes_out(self):
        with patch("django.core.mail.EmailMultiAlternatives.send", side_effect=OSError("mail server down")):
            self.register()
        unsent = EmailDelivery.objects.get()
        self.assertEqual(unsent.state, "pending")  # kept for a retry
        self.age_last_code()
        self.resend()
        unsent.refresh_from_db()
        self.assertEqual((unsent.state, unsent.subject, unsent.body), ("cancelled", SCRUBBED_SUBJECT, ""))
        EmailDelivery.objects.filter(pk=unsent.pk).update(next_attempt_at=timezone.now())
        self.assertEqual(deliver_email(unsent.pk), "cancelled")
        self.assertEqual(len(mail.outbox), 1)  # only the new code

    @override_settings(EMAIL_VERIFICATION_REQUIRED=False)
    def test_without_verification_register_and_login_answer_as_before(self):
        response = self.register(timezone="Europe/Madrid")
        self.assertEqual(response.status_code, 201)
        self.assertEqual(set(response.data), {"access", "refresh", "user"})
        self.assertEqual(response.data["user"]["email"], EMAIL)
        # Usable at once, so it stays usable if verification is turned on later.
        self.assertTrue(User.objects.get(email=EMAIL).email_verified)
        self.assertFalse(mail.outbox)
        self.assertFalse(EmailVerification.objects.exists())
        User.objects.create_user("unconfirmed@example.invalid", PASSWORD)
        self.assertEqual(self.login("unconfirmed@example.invalid").status_code, 200)
        duplicate = self.register("unconfirmed@example.invalid", OTHER_PASSWORD)
        self.assertEqual(duplicate.status_code, 400)
        self.assertEqual(duplicate.data, {"email": ["An account with this email already exists."]})
        self.assertTrue(User.objects.get(email="unconfirmed@example.invalid").check_password(PASSWORD))

    @override_settings()
    def test_verification_is_required_unless_turned_off(self):
        del settings.EMAIL_VERIFICATION_REQUIRED
        self.assertTrue(verification_required())

    def test_verification_endpoints_use_the_auth_rate_limit(self):
        self.assertEqual(VerifyEmailView.throttle_scope, "auth")
        self.assertEqual(ResendVerificationView.throttle_scope, "auth")

    def test_new_accounts_start_unconfirmed_and_admins_confirmed(self):
        self.assertFalse(User.objects.create_user("plain@example.invalid", PASSWORD).email_verified)
        self.assertTrue(User.objects.create_superuser("admin@example.invalid", PASSWORD).email_verified)

    @override_settings(LOCAL_TEST_ACCOUNT_ENABLED=True, LOCAL_TEST_ACCOUNT_EMAIL="seed@taskflow.local",
                       LOCAL_TEST_ACCOUNT_PASSWORD=PASSWORD)
    def test_the_local_test_account_is_confirmed(self):
        call_command("seed_test_user", stdout=io.StringIO())
        self.assertTrue(User.objects.get().email_verified)
        self.assertEqual(self.login("seed@taskflow.local").status_code, 200)

    @override_settings(LOCAL_TEST_ACCOUNT_ENABLED=True, LOCAL_TEST_ACCOUNT_EMAIL="seed@taskflow.local",
                       LOCAL_TEST_ACCOUNT_PASSWORD=PASSWORD)
    def test_seeding_confirms_a_test_account_signed_up_in_the_app(self):
        self.register("seed@taskflow.local")
        output = io.StringIO()
        call_command("seed_test_user", stdout=output)
        self.assertIn("Confirmed", output.getvalue())
        self.assertTrue(User.objects.get().email_verified)
        self.assertFalse(EmailVerification.objects.exists())
        self.assertEqual(self.login("seed@taskflow.local").status_code, 200)


@override_settings(EMAIL_VERIFICATION_REQUIRED=True, GOOGLE_OAUTH_CLIENT_IDS=[AUDIENCE])
class GoogleVerificationTests(VerificationTestCase):
    @classmethod
    def setUpClass(cls):
        super().setUpClass()
        key = rsa.generate_private_key(public_exponent=65537, key_size=2048)
        cls.signer = crypt.RSASigner.from_string(key.private_bytes(
            serialization.Encoding.PEM, serialization.PrivateFormat.PKCS8, serialization.NoEncryption()),
            key_id="fixture")
        cls.certificates = json.dumps({"fixture": key.public_key().public_bytes(
            serialization.Encoding.PEM, serialization.PublicFormat.SubjectPublicKeyInfo).decode()}).encode()

    def setUp(self):
        super().setUp()
        # Only Google's certificate download is replaced: the real verifier checks each token.
        certificates = type("CertResponse", (), {"status": 200, "data": self.certificates})()
        self.enterContext(patch("core.google_auth.Request")).return_value.return_value = certificates

    def token(self, email=EMAIL, **claims):
        now = int(time.time())
        return jwt.encode(self.signer, {
            "iss": "https://accounts.google.com", "aud": AUDIENCE, "iat": now - 1, "exp": now + 300,
            "sub": "google-subject-1", "email": email, "email_verified": True, **claims}).decode()

    def google(self, email=EMAIL, **claims):
        return self.client.post("/api/auth/google/", {"id_token": self.token(email, **claims),
                                                      "timezone": "Europe/Madrid"}, format="json")

    def test_a_google_account_counts_as_verified(self):
        response = self.google()
        self.assertEqual(response.status_code, 200, response.data)
        self.assertTrue(User.objects.get().email_verified)
        self.assertFalse(mail.outbox)

    def test_google_claims_an_unconfirmed_sign_up_of_its_address(self):
        self.register(first_name="Somebody else")
        placeholder = User.objects.get()
        response = self.google()
        self.assertEqual(response.status_code, 200, response.data)
        user = User.objects.get()
        self.assertEqual(user.pk, placeholder.pk)
        self.assertTrue(user.email_verified)
        # Whoever typed this address can't sign in with their password.
        self.assertFalse(user.has_usable_password())
        self.assertEqual((user.first_name, user.timezone), ("", "Europe/Madrid"))
        self.assertEqual(GoogleIdentity.objects.get().user_id, user.pk)
        self.assertFalse(EmailVerification.objects.exists())
        self.assertEqual(self.login().status_code, 401)

    def test_google_names_the_sign_up_it_claims_with_its_own_name(self):
        self.register(first_name="Somebody else")
        response = self.google(given_name="Ana")
        self.assertEqual(response.status_code, 200, response.data)
        self.assertEqual(User.objects.get().first_name, "Ana")

    def test_google_never_claims_a_confirmed_account(self):
        User.objects.create_user(EMAIL, PASSWORD, email_verified=True)
        response = self.google()
        self.assertEqual(response.status_code, 409)
        self.assertEqual(response.data["code"], "google_link_required")
        self.assertTrue(User.objects.get().check_password(PASSWORD))
        self.assertFalse(GoogleIdentity.objects.exists())

    def test_linking_google_confirms_the_address(self):
        user = User.objects.create_user(EMAIL, PASSWORD)
        self.client.force_authenticate(user)
        response = self.client.post("/api/auth/google/link/", {"id_token": self.token(), "password": PASSWORD},
                                    format="json")
        self.assertEqual(response.status_code, 200, response.data)
        user.refresh_from_db()
        self.assertTrue(user.email_verified)


class ExistingAccountsMigrationTests(TransactionTestCase):
    def test_accounts_made_before_verification_count_as_confirmed(self):
        before = [("core", "0019_groupinvitation_invited_by")]
        after = [("core", "0020_email_verification")]
        executor = MigrationExecutor(connection)
        latest = executor.loader.graph.leaf_nodes()
        self.addCleanup(lambda: MigrationExecutor(connection).migrate(latest))
        executor.migrate(before)
        try:
            OldUser = executor.loader.project_state(before).apps.get_model("core", "User")
            ids = [OldUser.objects.create(email=f"existing-{i}@example.invalid").pk for i in range(2)]
        finally:
            executor = MigrationExecutor(connection)
            executor.migrate(after)
        MigratedUser = executor.loader.project_state(after).apps.get_model("core", "User")
        self.assertEqual(MigratedUser.objects.filter(pk__in=ids, email_verified=True).count(), 2)
