"""Password recovery: a 6-digit code by email, valid for 30 minutes (docs/PASSWORD_RECOVERY.md).

Built like sign-up's email verification (core/email_verification.py): only a salted digest of
a code is stored, a code is never logged, five wrong tries lock it, and an address gets at most
one code a minute and five an hour, on top of the outbox's own limits. The email goes through
the same outbox as every other email.
"""
import secrets
from datetime import timedelta

from django.db import transaction
from django.utils import timezone
from django.utils.crypto import constant_time_compare, salted_hmac
from rest_framework.exceptions import Throttled

from .email_delivery import deliver_email, reserve_email
from .email_verification import CODE_LIFETIME, _scrub_delivery, _wait_seconds, mark_verified
from .models import EmailDelivery, LoginSession, PasswordReset, User

# The outbox clears a sent email's body but keeps its subject, which holds the code.
SCRUBBED_SUBJECT = "TaskFlow recovery code"

# The app calls the field «Código de recuperación», "Recovery code", «Codi de recuperació».
EMAILS = {
    "en": ("Your TaskFlow recovery code: {code}",
           "Your TaskFlow recovery code is {code}. Type it in the app to choose a new password. "
           "It expires in {minutes} minutes. If you didn't ask for it, ignore this message and "
           "your password stays as it is."),
    "es": ("Tu código de recuperación de TaskFlow: {code}",
           "Tu código de recuperación de TaskFlow es {code}. Escríbelo en la aplicación para elegir "
           "una contraseña nueva. Caduca en {minutes} minutos. Si no lo has pedido, ignora este "
           "mensaje y tu contraseña seguirá igual."),
    "ca": ("El teu codi de recuperació de TaskFlow: {code}",
           "El teu codi de recuperació de TaskFlow és {code}. Escriu-lo a l’aplicació per triar una "
           "contrasenya nova. Caduca d’aquí a {minutes} minuts. Si no l’has demanat, ignora aquest "
           "missatge i la contrasenya no canviarà."),
}


def code_digest(user_id, code):
    # Its own salt: a sign-up code can never pass for a recovery code, or the other way round.
    return salted_hmac("password-reset", f"{user_id}:{code}", algorithm="sha256").hexdigest()


def code_matches(row, code):
    return constant_time_compare(row.code_digest, code_digest(row.user_id, code))


def _scrub(delivery_id, *, cancel):
    _scrub_delivery(delivery_id, cancel=cancel, subject=SCRUBBED_SUBJECT)


def issue_reset_code(user, language="en"):
    """Queue a new code for an account, replacing its last one.

    Call inside a transaction that holds the user's row lock, and deliver the result once it
    commits. Raises Throttled beyond one code a minute or five an hour per address, or beyond
    the outbox's own limits; nothing is written then."""
    now = timezone.now()
    row = PasswordReset.objects.select_for_update().filter(user=user).first()
    wait = _wait_seconds(row, now) if row else 0
    if wait:
        raise Throttled(wait=wait, detail="A code was sent recently. Wait a little before asking for another.")
    reserve_email(user.email)
    code = f"{secrets.randbelow(10 ** 6):06d}"
    subject, body = EMAILS[language]
    minutes = int(CODE_LIFETIME.total_seconds() // 60)
    delivery = EmailDelivery.objects.create(
        recipient=user.email, subject=subject.format(code=code),
        body=body.format(code=code, minutes=minutes), expires_at=now + CODE_LIFETIME)
    if row is None:
        row = PasswordReset(user=user, hour_started_at=now, sent_this_hour=0)
    else:
        # The previous code stops working, so an unsent email for it must not go out.
        _scrub(row.delivery_id, cancel=True)
        if now - row.hour_started_at >= timedelta(hours=1):
            row.hour_started_at, row.sent_this_hour = now, 0
    row.code_digest = code_digest(user.pk, code)
    row.expires_at = now + CODE_LIFETIME
    row.attempts = 0
    row.sent_at = now
    row.sent_this_hour += 1
    row.delivery_id = delivery.pk
    row.save()
    return delivery


def request_reset(email, language="en"):
    """Email a code to the active account with this address, or quietly nothing.

    Nothing is sent for an unknown address, nor past a limit, and the caller answers the same
    either way: the answer never says whether an account exists."""
    with transaction.atomic():
        user = User.objects.select_for_update().filter(email__iexact=email.strip(), is_active=True).first()
        try:
            delivery = issue_reset_code(user, language) if user else None
        except Throttled:
            delivery = None
    if delivery is not None and deliver_email(delivery.pk) == "sent":
        _scrub(delivery.pk, cancel=False)


def set_new_password(user, password):
    """The mailbox is proven: the password changes, and every way back in with the old one ends.

    Call with a validated password, inside the transaction that holds the user's row lock."""
    user.set_password(password)
    user.save(update_fields=["password"])
    # The recovery email proved the address, which confirms an unconfirmed sign-up.
    mark_verified(user)
    LoginSession.objects.filter(user=user).update(revoked=True)
    # Single use, whichever code was used: a live 6-digit code goes too, with its unsent email.
    row = PasswordReset.objects.filter(user=user).first()
    if row is not None:
        _scrub(row.delivery_id, cancel=True)
        row.delete()
