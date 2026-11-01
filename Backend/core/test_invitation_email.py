"""The designed invitation email (voice-commands plan, item 4): text, HTML, language and account deletion."""
import re
from datetime import timedelta
from unittest.mock import patch

from django.core import mail
from django.core.cache import cache
from django.test import SimpleTestCase, TestCase, override_settings
from django.utils import timezone
from rest_framework.test import APIClient

from .email_delivery import deliver_email, email_html, queue_invitation
from .invitation_email import (invitation_html, invitation_language, invitation_message, preferred_language,
                               unsigned_invitation)
from .models import EmailDelivery, GroupInvitation, ListInvitation, ListMembership, TaskGroup, TaskList, User

LINK = "https://taskflow.example.invalid/invite/#kind=list&id=1e0c6f3c-2f7e-4a43-9a43-5a2c2a8d8d11&code=Abc_123-xyz"
CODE = "Abc_123-xyz"
# The kind of footer the outbox appends to every email it sends (deliver_email).
FOOTER = ("This is an automated TaskFlow email. This sending address is not monitored. "
          "For help, contact support@example.invalid. Replies are directed to TaskFlow Support.")
PASSWORD = "Invitation-fixture-2026!"


def message(language="en", kind="list", sender="Lena", name="Huerto", email="otto@example.invalid", **options):
    return invitation_message(kind=kind, sender=sender, name=name, link=LINK, email=email, code=CODE,
                              language=language, **options)


class InvitationTextTests(TestCase):
    def test_each_language_says_who_invited_to_what_with_one_link_and_the_code(self):
        expected = {
            ("en", "list"): ("You’re invited to a project in TaskFlow",
                             "Lena invited you to join the project “Huerto” in TaskFlow.", "Review the invitation:"),
            ("en", "group"): ("You’re invited to a group in TaskFlow",
                              "Lena invited you to join the group “Huerto” in TaskFlow.", "Review the invitation:"),
            ("es", "list"): ("Te han invitado a un proyecto en TaskFlow",
                             "Lena te invita a unirte al proyecto «Huerto» en TaskFlow.", "Revisar la invitación:"),
            ("es", "group"): ("Te han invitado a un grupo en TaskFlow",
                              "Lena te invita a unirte al grupo «Huerto» en TaskFlow.", "Revisar la invitación:"),
            ("ca", "list"): ("T’han convidat a un projecte a TaskFlow",
                             "Lena et convida a unir-te al projecte «Huerto» a TaskFlow.", "Revisa la invitació:"),
            ("ca", "group"): ("T’han convidat a un grup a TaskFlow",
                              "Lena et convida a unir-te al grup «Huerto» a TaskFlow.", "Revisa la invitació:"),
        }
        for (language, kind), (subject, headline, button) in expected.items():
            with self.subTest(language=language, kind=kind):
                title, body = message(language, kind)
                self.assertEqual(title, subject)
                paragraphs = body.split("\n\n")
                self.assertEqual(paragraphs[0].splitlines()[0], headline)
                self.assertEqual(paragraphs[1], f"{button}\n{LINK}")
                self.assertEqual(body.count(LINK), 1)
                self.assertEqual(paragraphs[-2].splitlines()[-1], CODE)
                self.assertIn("otto@example.invalid", paragraphs[-2])
                self.assertIn("7", paragraphs[-1])
                self.assertNotIn("Lena", title)  # The outbox keeps subjects after sending.

    def test_someone_without_an_account_hears_about_google_play_and_the_website(self):
        _, body = message("es")
        self.assertIn("¿Aún no usas TaskFlow? La app llegará pronto a Google Play. Mientras tanto, puedes ver lo que "
                      "hace en https://taskflow.garbar.tech/es/", body)  # In the email's language (UX-2617).
        self.assertIn("Cuando tengas la app, crea tu cuenta con otto@example.invalid", body)
        self.assertNotIn("staging", body)
        User.objects.create_user("otto@example.invalid", PASSWORD, email_verified=True)
        _, body = message("es", email="OTTO@example.invalid")
        self.assertNotIn("Google Play", body)
        self.assertIn("O abre TaskFlow con la sesión iniciada como OTTO@example.invalid", body)

    def test_an_unconfirmed_sign_up_still_counts_as_new(self):
        User.objects.create_user("otto@example.invalid", PASSWORD, email_verified=False)
        self.assertIn("Google Play", message()[1])

    @override_settings(DEPLOYMENT_ENVIRONMENT="staging")
    def test_staging_keeps_the_tester_line_for_new_people(self):
        for language, line in (("en", "If you’re a staging tester"), ("es", "Si pruebas la versión de staging"),
                               ("ca", "Si proves la versió de staging")):
            self.assertIn(line, message(language)[1])
        User.objects.create_user("otto@example.invalid", PASSWORD, email_verified=True)
        self.assertNotIn("staging tester", message()[1])

    def test_names_stay_on_one_line(self):
        _, body = message(sender="Lena\n\nhttps://evil.invalid/", name="Huerto\nReview the invitation:")
        self.assertTrue(body.startswith("Lena https://evil.invalid/ invited you to join the project "
                                        "“Huerto Review the invitation:” in TaskFlow.\n"))
        self.assertEqual(len(body.split("\n\n")), 5)


class InvitationHtmlTests(TestCase):
    def html(self, body):
        markup = email_html(body)
        self.assertTrue(markup.startswith("<!DOCTYPE html>"), markup[:80])
        return markup

    def test_the_design_has_one_button_the_code_and_the_outbox_footer(self):
        _, body = message()
        markup = self.html(body + "\n\n" + FOOTER)
        self.assertEqual(markup.count("<a "), 2)  # The button and the website.
        self.assertIn(f'href="{LINK.replace("&", "&amp;")}"', markup)
        self.assertIn(">Review the invitation</a>", markup)
        self.assertIn(CODE, markup)
        self.assertIn("<strong>Lena</strong> invited you to join the project “<strong>Huerto</strong>” in TaskFlow.",
                      markup)
        self.assertIn("<strong>otto@example.invalid</strong>", markup)
        self.assertIn('href="https://taskflow.garbar.tech/"', markup)
        self.assertIn(FOOTER, markup)
        self.assertLess(markup.index(">Review the invitation</a>"), markup.index(f">{CODE}</p>"))
        self.assertLess(markup.index(f">{CODE}</p>"), markup.index(FOOTER))
        # Mobile and dark mode: a fluid table, the colour-scheme meta and dark colours.
        self.assertIn('<meta name="viewport"', markup)
        self.assertIn('<meta name="color-scheme" content="light dark">', markup)
        self.assertIn("@media (prefers-color-scheme:dark)", markup)
        self.assertIn("max-width:560px", markup)
        self.assertNotIn("<img", markup)
        self.assertEqual(invitation_html(body), email_html(body))  # Without a footer too.

    def test_each_language_and_kind_has_its_own_html(self):
        for language, words in (("en", "Invitation"), ("es", "Invitación"), ("ca", "Invitació")):
            for kind in ("list", "group"):
                with self.subTest(language=language, kind=kind):
                    subject, body = message(language, kind)
                    markup = self.html(body)
                    self.assertIn(f'<html lang="{language}">', markup)
                    self.assertIn(f"<title>{subject}</title>", markup)
                    self.assertIn(words, markup)
                    self.assertIn(CODE, markup)

    @override_settings(DEPLOYMENT_ENVIRONMENT="staging")
    def test_members_and_staging_variants(self):
        markup = self.html(message("ca")[1])
        self.assertIn("Si proves la versió de staging", markup)
        self.assertIn("<strong>Encara no fas servir TaskFlow?</strong>", markup)
        User.objects.create_user("otto@example.invalid", PASSWORD, email_verified=True)
        markup = self.html(message("ca")[1])
        self.assertNotIn("Google Play", markup)
        self.assertIn("O obre TaskFlow amb la sessió iniciada com a <strong>otto@example.invalid</strong>", markup)

    def test_names_and_codes_are_escaped(self):
        sender, name = '<script>alert("x")</script>', 'Física & "Química" <b>'
        _, body = message("es", "group", sender=sender, name=name)
        markup = self.html(body + "\n\n<img src=x onerror=alert(1)>")
        for raw in ("<script>", "<b>", "<img"):
            self.assertNotIn(raw, markup)
        self.assertIn("&lt;script&gt;alert(&quot;x&quot;)&lt;/script&gt;", markup)
        self.assertIn("Física &amp; &quot;Química&quot; &lt;b&gt;", markup)
        self.assertIn("&lt;img src=x onerror=alert(1)&gt;", markup)

    def test_only_https_links_become_buttons(self):
        local = LINK.replace("https://taskflow.example.invalid", "http://localhost:8088")
        _, body = invitation_message(kind="list", sender="Lena", name="Huerto", link=local,
                                     email="otto@example.invalid", code=CODE)
        markup = self.html(body)
        self.assertNotIn('href="http://localhost', markup)
        self.assertIn(local.replace("&", "&amp;"), markup)

    def test_other_emails_keep_the_plain_layout(self):
        reset = "Use this link within 30 minutes:\nhttps://example.invalid/reset/#uid=1\n\nIf you did not request this, ignore this email."
        markup = email_html(reset)
        self.assertTrue(markup.startswith("<div "))
        self.assertIn(">Open in TaskFlow</a>", markup)
        legacy = ("Lena invited you to join Huerto in TaskFlow.\n\nReview your invitation:\n" + LINK)
        self.assertTrue(email_html(legacy).startswith("<div "))
        _, body = message()
        self.assertTrue(email_html(body.replace("Review the invitation:", "Review it:")).startswith("<div "))

    @override_settings(EMAIL_BACKEND="core.email_delivery.ResendBackend", RESEND_API_KEY="fixture-only",
                       INVITATION_BASE_URL="https://taskflow.example.invalid/invite/", EMAIL_RETRY_QUEUE="")
    @patch("core.email_delivery.httpx.Client")
    def test_the_outbox_sends_the_text_and_its_design(self, provider):
        cache.clear()
        owner = User.objects.create_user("lena@example.invalid", PASSWORD, first_name="Lena")
        group = TaskGroup.objects.create(owner=owner, name="Coro")
        invitation = GroupInvitation.objects.create(group=group, invited_by=owner, email="otto@example.invalid",
                                                    role="editor", code_digest="fixture",
                                                    expires_at=timezone.now() + timedelta(days=7))
        row = queue_invitation(invitation, CODE, kind="group", sender="Lena", language="ca")
        self.assertEqual(deliver_email(row.pk), "sent")
        payload = provider.return_value.__enter__.return_value.post.call_args.kwargs["json"]
        self.assertEqual(payload["subject"], "T’han convidat a un grup a TaskFlow")
        self.assertTrue(payload["text"].startswith("Lena et convida a unir-te al grup «Coro» a TaskFlow."))
        self.assertTrue(payload["html"].startswith("<!DOCTYPE html>"))
        self.assertIn(CODE, payload["html"])
        row.refresh_from_db()
        self.assertEqual(row.body, "")  # The code is gone from the outbox once sent, as before.


class InvitationLanguageTests(SimpleTestCase):
    def test_the_request_language_then_accept_language_then_english(self):
        self.assertEqual(invitation_language("ca-ES", "es-ES,es;q=0.9"), "ca")
        self.assertEqual(invitation_language(None, "es-ES,es;q=0.9,en;q=0.8"), "es")
        self.assertEqual(invitation_language("fr", "fr-FR,ca;q=0.5,es;q=0.4"), "ca")
        self.assertEqual(invitation_language("", "de-DE"), "en")
        self.assertEqual(invitation_language(None, None), "en")
        self.assertEqual(preferred_language("en;q=0.2, es;q=0.8"), "es")
        self.assertEqual(preferred_language("ca;q=0, es;q=bad, en"), "en")


class UnsignedInvitationTests(TestCase):
    def test_the_sender_becomes_someone_in_the_emails_language(self):
        for language, someone in (("en", "Someone invited you to join"), ("es", "Alguien te invita a unirte"),
                                  ("ca", "Algú et convida a unir-te")):
            for sender in ("lena@example.invalid", "Lena  Ruiz"):
                with self.subTest(language=language, sender=sender):
                    body = invitation_message(kind="list", sender=sender, name="Huerto", link=LINK,
                                              email="otto@example.invalid", code=CODE, language=language)[1]
                    unsigned = unsigned_invitation(body, ("lena@example.invalid", "Lena  Ruiz"))
                    self.assertTrue(unsigned.startswith(someone), unsigned)
                    self.assertNotIn("Lena", unsigned)
                    self.assertNotIn("lena@", unsigned)
                    self.assertIn("<strong>" + someone.split()[0] + "</strong>", invitation_html(unsigned))

    def test_older_emails_and_other_senders(self):
        legacy = "lena@example.invalid invited you to join Huerto in TaskFlow.\n\nReview your invitation:\n" + LINK
        self.assertTrue(unsigned_invitation(legacy, ("lena@example.invalid", "Lena")).startswith("Someone invited"))
        body = invitation_message(kind="list", sender="Marta", name="Huerto", link=LINK,
                                  email="otto@example.invalid", code=CODE)[1]
        self.assertIsNone(unsigned_invitation(body, ("lena@example.invalid", "Lena")))


@override_settings(INVITATION_BASE_URL="https://taskflow.example.invalid/invite/")
class InvitationEndpointTests(TestCase):
    def setUp(self):
        cache.clear()
        self.owner = User.objects.create_user("lena@example.invalid", PASSWORD, first_name="Lena")
        self.client = APIClient()
        self.client.force_authenticate(self.owner)
        self.garden = TaskList.objects.create(owner=self.owner, name="Huerto")
        self.choir = TaskGroup.objects.create(owner=self.owner, name="Coro")

    def invite(self, path, **extra):
        language = extra.pop("language", None)
        body = {"email": "otto@example.invalid", "role": "editor", **({"language": language} if language else {})}
        response = self.client.post(path, body, format="json", **extra)
        self.assertEqual(response.status_code, 201, response.data)
        return EmailDelivery.objects.filter(recipient="otto@example.invalid").latest("created_at")

    def test_the_language_comes_from_the_request_then_its_accept_language(self):
        project, group = f"/api/lists/{self.garden.pk}/invite/", f"/api/groups/{self.choir.pk}/invite/"
        cases = ((project, {"language": "ca"}, "T’han convidat a un projecte a TaskFlow"),
                 (project, {"HTTP_ACCEPT_LANGUAGE": "es-ES,es;q=0.9"}, "Te han invitado a un proyecto en TaskFlow"),
                 (project, {"language": "fr", "HTTP_ACCEPT_LANGUAGE": "fr,en;q=0.5"}, "You’re invited to a project in TaskFlow"),
                 (group, {"language": "es-ES"}, "Te han invitado a un grupo en TaskFlow"),
                 (group, {}, "You’re invited to a group in TaskFlow"))
        for path, extra, subject in cases:
            with self.subTest(path=path, extra=extra):
                row = self.invite(path, **dict(extra))
                self.assertEqual(row.subject, subject)
        self.assertTrue(mail.outbox)
        self.assertTrue(mail.outbox[-1].body.startswith("Lena invited you to join the group “Coro” in TaskFlow."))
        self.assertTrue(mail.outbox[0].body.startswith("lena@example.invalid et convida a unir-te al projecte «Huerto»"))

    def test_account_deletion_unsigns_unsent_spanish_and_catalan_invitations(self):
        ListMembership.objects.create(task_list=self.garden, user=User.objects.create_user(
            "ed@example.invalid", PASSWORD, first_name="Ed"), role="editor")
        self.garden.shared = True
        self.garden.save()
        with patch("core.group_views.deliver_email", return_value="pending"), \
                patch("core.email_delivery.deliver_email", return_value="pending"):
            self.invite(f"/api/groups/{self.choir.pk}/invite/", language="es")
            self.invite(f"/api/lists/{self.garden.pk}/invite/", language="ca")
        # The group has nobody else, so it goes with its invitation; the project stays, with Ed.
        with self.captureOnCommitCallbacks(execute=True):
            plan = self.client.get("/api/auth/delete-account/").data["plan"]
            response = self.client.post("/api/auth/delete-account/", {"password": PASSWORD, "plan": plan}, format="json")
        self.assertEqual(response.status_code, 204)
        row = EmailDelivery.objects.get(list_invitation__isnull=False)
        self.assertTrue(row.body.startswith("Algú et convida a unir-te al projecte «Huerto» a TaskFlow."), row.body)
        self.assertNotIn("lena@", row.body)
        self.assertTrue(ListInvitation.objects.filter(pk=row.list_invitation_id).exists())
        self.assertIn("<strong>Algú</strong>", email_html(row.body))
        self.assertFalse(re.search("lena", email_html(row.body), re.IGNORECASE))
