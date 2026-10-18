"""Email verification for password sign-ups: a 6-digit code by email, valid for 30 minutes.

Only a salted digest of a code is stored, and a code is never logged. The email goes through
the same outbox as invitations and password resets. See docs/EMAIL_VERIFICATION.md.
"""
import math
import secrets
from datetime import timedelta

from django.conf import settings
from django.db import transaction
from django.db.models import Case, F, Value, When
from django.utils import timezone
from django.utils.crypto import constant_time_compare, salted_hmac
from rest_framework.exceptions import Throttled

from .email_delivery import deliver_email, reserve_email
from .models import EmailDelivery, EmailVerification, LoginSession, User

CODE_LIFETIME = timedelta(minutes=30)
MAX_WRONG_ATTEMPTS = 5
RESEND_INTERVAL = timedelta(seconds=60)
CODES_PER_HOUR = 5
# The outbox clears a sent email's body but keeps its subject, which holds the code.
SCRUBBED_SUBJECT = "TaskFlow email code"

EMAILS = {
    "en": ("Your TaskFlow code: {code}",
           "Your code to confirm your email for TaskFlow is {code}. It expires in {minutes} minutes. "
           "If you didn't create a TaskFlow account, ignore this message."),
    "es": ("Tu código de TaskFlow: {code}",
           "Tu código para confirmar tu correo en TaskFlow es {code}. Caduca en {minutes} minutos. "
           "Si no has creado una cuenta de TaskFlow, ignora este mensaje."),
    "ca": ("El teu codi de TaskFlow: {code}",
           "El teu codi per confirmar el teu correu a TaskFlow és {code}. Caduca d’aquí a {minutes} minuts. "
           "Si no has creat cap compte de TaskFlow, ignora aquest missatge."),
}


def verification_required():
    return bool(getattr(settings, "EMAIL_VERIFICATION_REQUIRED", True))


def email_language(value):
    """"en", "es" or "ca" from what the app sends ("es", "ca-ES"…); None when missing or unknown."""
    if isinstance(value, str):
        primary = value.strip().replace("_", "-").split("-")[0].lower()
        if primary in EMAILS:
            return primary
    return None


def unconfirmed(user):
    """A sign-up nobody has proven the address of. Nobody can sign in to it, so it can be replaced."""
    return user.is_active and not user.email_verified


def code_digest(user_id, code):
    return salted_hmac("email-verification", f"{user_id}:{code}", algorithm="sha256").hexdigest()


def code_matches(row, code):
    return constant_time_compare(row.code_digest, code_digest(row.user_id, code))


def has_live_code(user):
    return EmailVerification.objects.filter(
        user=user, expires_at__gt=timezone.now(), attempts__lt=MAX_WRONG_ATTEMPTS).exists()


def _scrub_delivery(delivery_id, *, cancel):
    """Take the code out of an outbox row; with cancel, an unsent one is also cancelled."""
    if delivery_id is None:
        return
    changes = {"subject": SCRUBBED_SUBJECT}
    if cancel:
        changes.update(body="", state=Case(When(state="pending", then=Value("cancelled")), default=F("state")))
    EmailDelivery.objects.filter(pk=delivery_id).update(**changes)


def _wait_seconds(row, now):
    """How long until this address may get another code; 0 if it may now."""
    wait = (row.sent_at + RESEND_INTERVAL - now).total_seconds()
    if now - row.hour_started_at < timedelta(hours=1) and row.sent_this_hour >= CODES_PER_HOUR:
        wait = max(wait, (row.hour_started_at + timedelta(hours=1) - now).total_seconds())
    return max(0, math.ceil(wait))


def issue_code(user, language=None):
    """Queue a new code for an unconfirmed account, replacing its last one.

    Call inside a transaction that holds the user's row lock, and give the result to send_code
    once it commits. Raises Throttled beyond one code a minute or five an hour per address, or
    beyond the outbox's own limits; nothing is written then. Without a language, the email uses
    the sign-up's language, else English."""
    now = timezone.now()
    row = EmailVerification.objects.select_for_update().filter(user=user).first()
    wait = _wait_seconds(row, now) if row else 0
    if wait:
        raise Throttled(wait=wait, detail="A code was sent recently. Wait a little before asking for another.")
    reserve_email(user.email)
    code = f"{secrets.randbelow(10 ** 6):06d}"
    language = language or (row.language if row else "en")
    subject, body = EMAILS[language]
    minutes = int(CODE_LIFETIME.total_seconds() // 60)
    delivery = EmailDelivery.objects.create(
        recipient=user.email, subject=subject.format(code=code),
        body=body.format(code=code, minutes=minutes), expires_at=now + CODE_LIFETIME)
    if row is None:
        row = EmailVerification(user=user, hour_started_at=now, sent_this_hour=0)
    else:
        # The previous code stops working, so an unsent email for it must not go out.
        _scrub_delivery(row.delivery_id, cancel=True)
        if now - row.hour_started_at >= timedelta(hours=1):
            row.hour_started_at, row.sent_this_hour = now, 0
    row.code_digest = code_digest(user.pk, code)
    row.expires_at = now + CODE_LIFETIME
    row.attempts = 0
    row.sent_at = now
    row.sent_this_hour += 1
    row.language = language
    row.delivery_id = delivery.pk
    row.save()
    return delivery


def send_code(delivery):
    """Deliver a code email queued by issue_code, after its transaction has committed."""
    if delivery is not None and deliver_email(delivery.pk) == "sent":
        _scrub_delivery(delivery.pk, cancel=False)


def send_new_code(user, language=None):
    """Email a fresh code to an unconfirmed account, or quietly nothing when the limits say no."""
    with transaction.atomic():
        locked = User.objects.select_for_update().filter(pk=user.pk, is_active=True, email_verified=False).first()
        try:
            delivery = issue_code(locked, language) if locked else None
        except Throttled:
            delivery = None
    send_code(delivery)


def resend_code(user, language=None):
    """Email a fresh code for «Reenviar código»: 0 once one is on its way, else the seconds to wait.

    Unlike send_new_code, the wait is told, so the app never says a code was sent when it wasn't.
    It gives nothing away: registering the same address already answers 429 while a recent
    code for an unconfirmed sign-up stands."""
    with transaction.atomic():
        locked = User.objects.select_for_update().filter(pk=user.pk, is_active=True, email_verified=False).first()
        if locked is None:
            return 0
        try:
            delivery = issue_code(locked, language)
        except Throttled as error:
            return max(1, math.ceil(error.wait or 3600))
    send_code(delivery)
    return 0


def mark_verified(user):
    """The address is proven: the account counts as confirmed and its code stops working.

    Call inside the transaction that holds the user's row lock."""
    if user.email_verified:
        return
    row = EmailVerification.objects.filter(user=user).first()
    if row is not None:
        _scrub_delivery(row.delivery_id, cancel=True)
        row.delete()
    user.email_verified = True
    user.save(update_fields=["email_verified"])


def take_over_unconfirmed(user, *, password=None, first_name="", time_zone=None):
    """Turn an unconfirmed sign-up into a fresh one for the person signing up now.

    Nobody could sign in to it, so nothing is lost. Without a password (Google), it has no
    usable one. Call inside the transaction that holds the user's row lock."""
    if password is None:
        user.set_unusable_password()
    else:
        user.set_password(password)
    user.first_name = first_name
    user.timezone = time_zone or User._meta.get_field("timezone").get_default()
    user.date_joined = timezone.now()
    user.save(update_fields=["password", "first_name", "timezone", "date_joined"])
    LoginSession.objects.filter(user=user).update(revoked=True)
