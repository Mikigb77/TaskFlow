"""Password recovery with a 6-digit code (docs/PASSWORD_RECOVERY.md, UX-1602)."""
import hashlib
import io
import logging
import re
from contextlib import contextmanager
from datetime import timedelta
from unittest.mock import patch

from django.conf import settings
from django.contrib.auth.tokens import default_token_generator
from django.core import mail
from django.core.cache import cache
from django.core.management import call_command
from django.db.models import F
from django.test import TestCase
from django.utils import timezone
from django.utils.encoding import force_bytes
from django.utils.http import urlsafe_base64_encode
from rest_framework.test import APIClient

from .auth_views import ResetConfirmView, ResetRequestView
from .email_delivery import reserve_email
from .email_verification import issue_code
from .models import EmailDelivery, EmailVerification, LoginSession, PasswordReset, User

EMAIL = "recover@example.invalid"
PASSWORD = "Recovery-test-passphrase!2026"
NEW_PASSWORD = "Chosen-again-passphrase!2026"
REQUEST, CONFIRM = "/api/auth/password-reset/", "/api/auth/password-reset/confirm/"
SENT = {"detail": "If that account exists, a recovery email has been sent."}
UPDATED = {"detail": "Password updated. Sign in with your new password."}
EMAILS = {
    "en": ("Your TaskFlow recovery code: {code}",
           "Your TaskFlow recovery code is {code}. Type it in the app to choose a new password. It expires in 30 "
           "minutes. If you didn't ask for it, ignore this message and your password stays as it is."),
    "es": ("Tu código de recuperación de TaskFlow: {code}",
           "Tu código de recuperación de TaskFlow es {code}. Escríbelo en la aplicación para elegir una contraseña "
           "nueva. Caduca en 30 minutos. Si no lo has pedido, ignora este mensaje y tu contraseña seguirá igual."),
    "ca": ("El teu codi de recuperació de TaskFlow: {code}",
           "El teu codi de recuperació de TaskFlow és {code}. Escriu-lo a l’aplicació per triar una contrasenya "
           "nova. Caduca d’aquí a 30 minuts. Si no l’has demanat, ignora aquest missatge i la contrasenya no canviarà."),
}


def code_in(message):
    return re.search(r"[0-9]{6}", message.subject).group()


def codes(*values):
    """Fix the codes the server picks, in order."""
    return patch("core.password_reset.secrets.randbelow", side_effect=list(values))


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


class PasswordRecoveryTests(TestCase):
    def setUp(self):
        cache.clear()
        self.client = APIClient()
        self.user = User.objects.create_user(EMAIL, PASSWORD, email_verified=True)

    def ask(self, email=EMAIL, **extra):
        return self.client.post(REQUEST, {"email": email, **extra}, format="json")

    def confirm(self, code, email=EMAIL, password=NEW_PASSWORD):
        data = {"code": code, "password": password}
        if email is not None:
            data["email"] = email
        return self.client.post(CONFIRM, data, format="json")

    def login(self, password):
        return self.client.post("/api/auth/login/", {"email": EMAIL, "password": password}, format="json")

    def age_last_code(self, seconds=61):
        # As if the latest code went out a minute ago: past the one-a-minute limit.
        PasswordReset.objects.update(sent_at=F("sent_at") - timedelta(seconds=seconds))

    def test_the_request_answers_the_same_whether_or_not_the_account_exists(self):
        User.objects.create_user("gone@example.invalid", PASSWORD, is_active=False)
        answers = [self.ask(email) for email in (EMAIL, "unknown@example.invalid", "gone@example.invalid")]
        for response in answers:
            self.assertEqual((response.status_code, response.data), (200, SENT))
        [message] = mail.outbox  # Only the active account is sent a code.
        self.assertEqual(message.to, [EMAIL])
        self.assertEqual(PasswordReset.objects.get().user, self.user)

    @patch.object(ResetRequestView, "throttle_classes", [])  # more requests than the endpoint's 5 an hour per client
    def test_a_six_digit_code_in_the_requests_language_with_english_otherwise(self):
        cases = [("es", "es"), ("ca", "ca"), ("en", "en"), ("ca-ES", "ca"), ("es_ES", "es"), ("fr", "en"), (None, "en")]
        for index, (language, expected) in enumerate(cases):
            with self.subTest(language=language):
                email = f"person{index}@example.invalid"
                User.objects.create_user(email, PASSWORD)
                extra = {} if language is None else {"language": language}
                self.assertEqual(self.ask(email, **extra).status_code, 200)
                message = mail.outbox[-1]
                code = code_in(message)
                subject, body = EMAILS[expected]
                self.assertEqual(message.subject, subject.format(code=code))
                self.assertIn(body.format(code=code), message.body)
                self.assertEqual(message.from_email, settings.DEFAULT_FROM_EMAIL)
                if getattr(settings, "EMAIL_SUPPORT_ADDRESS", ""):
                    self.assertEqual(message.reply_to, [settings.EMAIL_SUPPORT_ADDRESS])
        row = PasswordReset.objects.get(user__email="person0@example.invalid")
        self.assertAlmostEqual(row.expires_at, timezone.now() + timedelta(minutes=30), delta=timedelta(seconds=30))

    def test_the_new_email_holds_neither_a_link_nor_the_long_code(self):
        self.ask()
        body = mail.outbox[0].body
        self.assertNotIn(settings.PASSWORD_RESET_BASE_URL, body)
        self.assertNotIn(urlsafe_base64_encode(force_bytes(self.user.pk)) + ":", body)

    def test_the_code_sets_the_password_ends_every_session_and_confirms_the_address(self):
        User.objects.filter(pk=self.user.pk).update(email_verified=False)
        tokens = self.login(PASSWORD).data
        self.ask(" Recover@Example.INVALID ")
        code = code_in(mail.outbox[0])
        # Typed from the email with a space or a hyphen, and the address in any case.
        response = self.confirm(f"{code[:3]} - {code[3:]}", email="RECOVER@example.invalid")
        self.assertEqual((response.status_code, response.data), (200, UPDATED))
        user = User.objects.get(pk=self.user.pk)
        self.assertTrue(user.check_password(NEW_PASSWORD))
        self.assertTrue(user.email_verified)
        self.assertFalse(PasswordReset.objects.exists())
        self.assertFalse(LoginSession.objects.filter(user=user, revoked=False).exists())
        self.client.credentials(HTTP_AUTHORIZATION="Bearer " + tokens["access"])
        self.assertEqual(self.client.get("/api/auth/me/").status_code, 401)
        self.client.credentials()
        self.assertEqual(self.client.post("/api/auth/refresh/", {"refresh": tokens["refresh"]}, format="json").status_code, 401)
        self.assertEqual(self.login(PASSWORD).status_code, 401)
        self.assertEqual(self.login(NEW_PASSWORD).status_code, 200)
        # Single use.
        again = self.confirm(code, password="Yet-another-passphrase!2026")
        self.assertEqual((again.status_code, again.data["code"]), (400, "code_expired"))

    def test_a_code_sent_as_a_number_keeps_its_leading_zeros(self):
        with codes(4321):
            self.ask()
        self.assertEqual(code_in(mail.outbox[0]), "004321")
        self.assertEqual(self.confirm(4321).status_code, 200)

    def test_a_wrong_code_is_invalid_and_five_wrong_tries_lock_it(self):
        self.ask()
        code = code_in(mail.outbox[0])
        wrong = f"{(int(code) + 1) % 10 ** 6:06d}"
        for _ in range(5):
            response = self.confirm(wrong)
            self.assertEqual(response.status_code, 400)
            self.assertEqual(set(response.data), {"code", "detail"})
            self.assertEqual(response.data["code"], "code_invalid")
        locked = self.confirm(code)
        self.assertEqual((locked.status_code, locked.data["code"]), (400, "code_expired"))
        self.assertTrue(User.objects.get(pk=self.user.pk).check_password(PASSWORD))

    def test_something_that_isnt_six_digits_is_invalid_and_spends_no_try(self):
        self.ask()
        for typed in ("12345", "1234567", "12345a", "abcdef"):
            with self.subTest(typed=typed):
                self.assertEqual(self.confirm(typed).data["code"], "code_invalid")
        self.assertEqual(PasswordReset.objects.get().attempts, 0)
        self.assertEqual(self.confirm(code_in(mail.outbox[0])).status_code, 200)

    def test_expired_unknown_and_never_asked_all_look_expired(self):
        self.ask()
        code = code_in(mail.outbox[0])
        PasswordReset.objects.update(expires_at=timezone.now() - timedelta(seconds=1))
        User.objects.create_user("never-asked@example.invalid", PASSWORD)
        responses = [self.confirm(code), self.confirm(code, "unknown@example.invalid"),
                     self.confirm(code, "never-asked@example.invalid"), self.confirm(code, email=None)]
        for response in responses:
            self.assertEqual(response.status_code, 400)
            self.assertEqual(response.data, responses[0].data)
        self.assertEqual(set(responses[0].data), {"code", "detail"})
        self.assertEqual(responses[0].data["code"], "code_expired")
        self.assertTrue(User.objects.get(pk=self.user.pk).check_password(PASSWORD))

    def test_a_weak_password_keeps_the_code_untried(self):
        self.ask()
        code = code_in(mail.outbox[0])
        weak = self.confirm(code, password="short")
        self.assertEqual(weak.status_code, 400)
        self.assertIn("password", weak.data)
        self.assertEqual(PasswordReset.objects.get().attempts, 0)
        self.assertTrue(User.objects.get(pk=self.user.pk).check_password(PASSWORD))
        self.assertEqual(self.confirm(code).status_code, 200)

    @patch.object(ResetRequestView, "throttle_classes", [])
    def test_one_code_a_minute_and_five_an_hour_and_a_new_one_replaces_the_last(self):
        with codes(111111, 222222, 333333, 444444, 555555, 666666):
            self.assertEqual(self.ask().data, SENT)
            within_a_minute = self.ask()  # nothing is sent, the first code still works, and the answer is the same
            self.assertEqual((within_a_minute.status_code, within_a_minute.data), (200, SENT))
            self.assertEqual(len(mail.outbox), 1)
            for sent in (2, 3, 4, 5):
                self.age_last_code()
                self.ask()
                self.assertEqual(len(mail.outbox), sent)
            self.age_last_code()
            self.assertEqual(self.ask().data, SENT)  # a sixth code in the same hour: nothing is sent
            self.assertEqual(len(mail.outbox), 5)
            PasswordReset.objects.update(hour_started_at=F("hour_started_at") - timedelta(hours=1))
            self.ask()
        self.assertEqual([code_in(message) for message in mail.outbox],
                         ["111111", "222222", "333333", "444444", "555555", "666666"])
        self.assertEqual(self.confirm("555555").data["code"], "code_invalid")  # replaced
        self.assertEqual(self.confirm("666666").status_code, 200)

    def test_the_outbox_limits_apply_too(self):
        for _ in range(8):  # this address's emails for today are used up
            reserve_email(EMAIL)
        response = self.ask()
        self.assertEqual((response.status_code, response.data), (200, SENT))
        self.assertFalse(mail.outbox)
        self.assertFalse(PasswordReset.objects.exists())

    def test_an_unsent_email_for_a_replaced_code_never_goes_out(self):
        with patch("django.core.mail.EmailMultiAlternatives.send", side_effect=OSError("mail server down")):
            self.ask()
        unsent = EmailDelivery.objects.get()
        self.assertEqual(unsent.state, "pending")  # kept for a retry
        self.age_last_code()
        self.ask()
        unsent.refresh_from_db()
        self.assertEqual((unsent.state, unsent.subject, unsent.body), ("cancelled", "TaskFlow recovery code", ""))
        self.assertEqual(len(mail.outbox), 1)  # only the new code

    def test_the_code_is_never_stored_or_logged_in_plain_text(self):
        code = "482913"
        with captured_logs() as lines, codes(int(code)):
            logging.getLogger("core").debug("capture check")
            self.ask()
            row = PasswordReset.objects.get()
            self.assertRegex(row.code_digest, r"^[0-9a-f]{64}$")
            for unsalted in (code, f"{row.user_id}:{code}"):
                self.assertNotEqual(row.code_digest, hashlib.sha256(unsalted.encode()).hexdigest())
            self.assertIn(code, mail.outbox[0].subject)  # the person did get it
            delivery = EmailDelivery.objects.get()
            self.assertEqual((delivery.state, delivery.subject, delivery.body), ("sent", "TaskFlow recovery code", ""))
            self.assertEqual(self.confirm("000000").data["code"], "code_invalid")
            self.assertEqual(self.confirm(code).status_code, 200)
        self.assertIn("capture check", lines)
        self.assertEqual([line for line in lines if code in line or NEW_PASSWORD in line], [])

    def test_a_sign_up_code_is_no_recovery_code(self):
        unconfirmed = User.objects.create_user("unconfirmed@example.invalid", PASSWORD)
        with patch("core.email_verification.secrets.randbelow", return_value=246810):
            issue_code(unconfirmed, "en")  # its sign-up code
        self.assertTrue(EmailVerification.objects.filter(user=unconfirmed).exists())
        response = self.confirm("246810", "unconfirmed@example.invalid")
        self.assertEqual((response.status_code, response.data["code"]), (400, "code_expired"))
        self.assertTrue(User.objects.get(pk=unconfirmed.pk).check_password(PASSWORD))

    def test_a_reset_lifts_the_sign_in_lock(self):
        for _ in range(5):
            self.assertEqual(self.login("Not-the-passphrase!2026").status_code, 401)
        self.assertEqual(self.login(PASSWORD).status_code, 429)
        self.ask()
        self.assertEqual(self.confirm(code_in(mail.outbox[0])).status_code, 200)
        self.assertEqual(self.login(NEW_PASSWORD).status_code, 200)

    def test_the_old_long_code_still_works_without_the_email(self):
        # Emails sent before 6-digit codes, typed into older app builds or reset.html.
        self.ask()
        live = code_in(mail.outbox[0])
        old = urlsafe_base64_encode(force_bytes(self.user.pk)) + ":" + default_token_generator.make_token(self.user)
        response = self.client.post(CONFIRM, {"code": old, "password": NEW_PASSWORD}, format="json")
        self.assertEqual((response.status_code, response.data), (200, UPDATED))
        self.assertTrue(User.objects.get(pk=self.user.pk).check_password(NEW_PASSWORD))
        # Single use either way: the old code again, and the live 6-digit code, both stop working.
        again = self.client.post(CONFIRM, {"code": old, "password": "Yet-another-passphrase!2026"}, format="json")
        self.assertEqual((again.status_code, again.data["code"]), (400, "code_expired"))
        self.assertEqual(self.confirm(live).data["code"], "code_expired")
        self.assertFalse(PasswordReset.objects.exists())

    def test_maintenance_removes_codes_that_expired_over_an_hour_ago(self):
        self.ask()
        other = User.objects.create_user("other@example.invalid", PASSWORD)
        self.ask("other@example.invalid")
        PasswordReset.objects.filter(user=self.user).update(expires_at=timezone.now() - timedelta(hours=1, seconds=1))
        call_command("maintain_staging", stdout=io.StringIO())
        self.assertEqual(list(PasswordReset.objects.values_list("user_id", flat=True)), [other.pk])

    def test_the_endpoints_keep_their_rate_limits(self):
        self.assertEqual(ResetRequestView.throttle_scope, "recovery")
        self.assertEqual(ResetConfirmView.throttle_scope, "auth")
