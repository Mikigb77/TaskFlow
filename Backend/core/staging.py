from django.conf import settings
from django.utils import timezone
from rest_framework.exceptions import PermissionDenied

from .models import GroupInvitation, ListInvitation


def ensure_registration_allowed(email):
    if settings.DEPLOYMENT_ENVIRONMENT != "staging":
        return
    # Anyone can sign up on staging (owner, 2026-10-18). STAGING_INVITE_ONLY brings back the
    # invited-testers gate below: the allowlist or a live invitation.
    if not getattr(settings, "STAGING_INVITE_ONLY", False):
        return
    email = email.strip().casefold()
    if email in settings.STAGING_ALLOWED_EMAILS:
        return
    pending = {"email": email, "state": "pending", "expires_at__gt": timezone.now()}
    if (GroupInvitation.objects.filter(**pending, group__is_deleted=False).exists()
            or ListInvitation.objects.filter(**pending, task_list__is_deleted=False).exists()):
        return
    raise PermissionDenied("This staging version is for invited testers. Ask a group owner for an invitation.")
