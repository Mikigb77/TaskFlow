"""Transactional mail with a durable outbox and no email content in logs."""
import logging
import hashlib
import re
from datetime import timedelta
from urllib.parse import urlencode

import httpx
from django.conf import settings
from django.core.mail import EmailMultiAlternatives
from django.core.cache import cache
from django.db import transaction
from django.utils import timezone
from django.utils.html import escape

from .invitation_email import invitation_html, invitation_message
from .models import EmailDelivery
from rest_framework.exceptions import Throttled

logger = logging.getLogger(__name__)


def schedule_retry(row):
    """Wake a job only for actual email work; idle staging can scale to zero."""
    if not settings.EMAIL_RETRY_QUEUE:
        return
    try:
        import google.auth
        from google.auth.transport.requests import AuthorizedSession
        credentials, _ = google.auth.default(scopes=["https://www.googleapis.com/auth/cloud-platform"])
        with AuthorizedSession(credentials) as client:
            response = client.post(
                f"https://cloudtasks.googleapis.com/v2/{settings.EMAIL_RETRY_QUEUE}/tasks",
                timeout=8,
                json={"task": {
                    "name": f"{settings.EMAIL_RETRY_QUEUE}/tasks/mail-{row.pk}-{row.attempts}",
                    "scheduleTime": (row.next_attempt_at + timedelta(seconds=15)).isoformat(),
                    "httpRequest": {
                        "httpMethod": "POST", "url": settings.EMAIL_RETRY_JOB,
                        "headers": {"Content-Type": "application/json"}, "body": "e30=",
                        "oauthToken": {"serviceAccountEmail": settings.EMAIL_RETRY_IDENTITY,
                                       "scope": "https://www.googleapis.com/auth/cloud-platform"},
                    },
                }},
            )
            if response.status_code != 409:
                response.raise_for_status()
    except Exception:
        logger.warning("Email retry scheduling deferred: id=%s", row.pk)


def email_html(body):
    # An invitation gets its designed layout, rebuilt from its own text (invitation_email).
    designed = invitation_html(body)
    if designed is not None:
        return designed
    # Only application-generated HTTPS links become anchors. Escape all names/content.
    paragraphs = []
    for paragraph in body.split("\n\n"):
        lines = []
        for line in paragraph.splitlines():
            safe = escape(line)
            if re.fullmatch(r"https://[^\s]+", line):
                safe = f'<a href="{safe}" style="color:#166b5c">Open in TaskFlow</a>'
            lines.append(str(safe))
        paragraphs.append("<p>" + "<br>".join(lines) + "</p>")
    return '<div style="font:16px/1.7 system-ui,sans-serif;max-width:560px;color:#193d36"><h1 style="font-size:24px">TaskFlow</h1>' + "".join(paragraphs) + "</div>"


def reserve_email(recipient):
    now = timezone.now()
    recipient_key = hashlib.sha256(recipient.encode()).hexdigest()
    for key, limit, ttl in (
        (f"mail:day:{now:%Y-%m-%d}", 80, 86400),
        (f"mail:month:{now:%Y-%m}", 2700, 32 * 86400),
        (f"mail:recipient:{now:%Y-%m-%d}:{recipient_key}", 8, 86400),
    ):
        count = 1 if cache.add(key, 1, ttl) else cache.incr(key)
        if count > limit:
            cache.decr(key)
            raise Throttled(detail="Email sending is temporarily limited. Try again later.", wait=3600)


def queue_invitation(invitation, code, *, kind, sender, language=None):
    """Queue the invitation email, in "en", "es" or "ca" (English by default)."""
    reserve_email(invitation.email)
    name = invitation.group.name if kind == "group" else invitation.task_list.name
    link = settings.INVITATION_BASE_URL + "#" + urlencode({
        "kind": kind, "id": str(invitation.pk), "code": code,
        "environment": settings.DEPLOYMENT_ENVIRONMENT})
    subject, body = invitation_message(kind=kind, sender=sender, name=name, link=link, email=invitation.email,
                                       code=code, language=language)
    return EmailDelivery.objects.create(recipient=invitation.email, subject=subject,
        body=body, expires_at=invitation.expires_at,
        **{f"{kind}_invitation": invitation})


def deliver_email(delivery_id):
    with transaction.atomic():
        row = EmailDelivery.objects.select_for_update().filter(pk=delivery_id).first()
        if row is None:
            return "cancelled"
        if row.state != "pending":
            return row.state
        if row.expires_at <= timezone.now():
            row.state, row.body = "expired", ""
            row.save(update_fields=["state", "body"])
            return "expired"
        if row.next_attempt_at > timezone.now():
            return "pending"
        if row.attempts >= 6:
            row.state, row.body = "failed", ""
            row.save(update_fields=["state", "body"])
            return "failed"
        for invitation in (row.group_invitation, row.list_invitation):
            if invitation and invitation.state != "pending":
                row.state, row.body = "cancelled", ""
                row.save(update_fields=["state", "body"])
                return "cancelled"
        row.attempts += 1
        # A short lease prevents two request/job workers sending at once.
        row.next_attempt_at = timezone.now() + timedelta(minutes=5)
        row.save(update_fields=["attempts", "next_attempt_at"])
    # Schedule before the network send: a killed worker cannot strand the outbox.
    schedule_retry(row)
    try:
        if settings.EMAIL_BACKEND == "core.email_delivery.ResendBackend":
            if not settings.RESEND_API_KEY:
                raise RuntimeError("Email provider is not configured")
            with httpx.Client(timeout=8, follow_redirects=False) as client:
                response = client.post("https://api.resend.com/emails", headers={
                    "Authorization": f"Bearer {settings.RESEND_API_KEY}",
                    "Idempotency-Key": f"taskflow/{row.pk}"}, json={
                    "from": settings.DEFAULT_FROM_EMAIL, "to": [row.recipient],
                    "subject": row.subject, "text": row.body,
                    "html": email_html(row.body)})
                response.raise_for_status()
        else:
            message = EmailMultiAlternatives(row.subject, row.body, settings.DEFAULT_FROM_EMAIL, [row.recipient])
            message.send(fail_silently=False)
    except Exception:
        # Do not expose credentials, recipients, invitation codes or provider response bodies.
        logger.warning("Email delivery deferred: id=%s", row.pk)
        return "pending"
    EmailDelivery.objects.filter(pk=row.pk).update(state="sent", body="")
    return "sent"


class ResendBackend:
    """Marker used by the outbox; all production delivery goes through it."""
