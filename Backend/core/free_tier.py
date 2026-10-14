"""Free dictations: a monthly ledger for accounts without Pro.

A dictation counts only once the assistant has answered. Failed, refused and
cancelled dictations are deleted; Pro dictations are never recorded.
"""
import hashlib
from datetime import timedelta

from django.conf import settings
from django.core.cache import cache
from django.db import transaction
from django.db.models import Q
from django.utils import timezone

from .models import FreeDictation, User

# Each AI stage has 45 s and gunicorn stops a request at 120 s, so an older
# pending row comes from a crashed request and no longer holds a slot.
PENDING_TIMEOUT = timedelta(minutes=5)


def month(now):
    # The calendar month in UTC. The app shows the reset as a local date.
    start = now.replace(day=1, hour=0, minute=0, second=0, microsecond=0)
    return start.strftime("%Y-%m"), (start + timedelta(days=32)).replace(day=1)


def free_voice(user):
    now = timezone.now()
    period, resets_at = month(now)
    held = FreeDictation.objects.filter(user=user, period=period).filter(
        Q(counted=True) | Q(created_at__gte=now - PENDING_TIMEOUT)).count()
    limit = settings.FREE_VOICE_CAPTURES_PER_MONTH
    return {"limit": limit, "left": max(0, limit - held),
            "resets_at": resets_at.isoformat().replace("+00:00", "Z")}


def capture_digest(data):
    # The same capture with the same words is a retry; new words are a new dictation.
    digest = hashlib.sha256(data["capture_type"].encode() + b"\n")
    audio = data.get("audio")
    if audio:
        for chunk in audio.chunks():
            digest.update(chunk)
        audio.seek(0)
    else:
        digest.update(data["text"].encode())
    return digest.hexdigest()


def reserve_free_dictation(user, capture_id, digest):
    """Returns (row, outcome): a pending row with "reserved", or None with
    "retry" (already counted, so free), "cancelled", "in_progress" or "used_up"."""
    now = timezone.now()
    period, _ = month(now)
    with transaction.atomic():
        # One decision at a time per account, across all of its devices.
        User.objects.select_for_update().get(pk=user.pk)
        FreeDictation.objects.filter(user=user, counted=False, created_at__lt=now - PENDING_TIMEOUT).delete()
        if capture_id is not None and cache.get(cancelled_key(user, capture_id)):
            return None, "cancelled"
        rows = FreeDictation.objects.filter(user=user, period=period)
        # Without the app's capture ID, a request can't be told apart from new words.
        same = rows.filter(capture_id=capture_id, digest=digest).first() if capture_id is not None else None
        if same is not None:
            return None, "retry" if same.counted else "in_progress"
        if rows.count() >= settings.FREE_VOICE_CAPTURES_PER_MONTH:
            return None, "used_up"
        return FreeDictation.objects.create(user=user, period=period, capture_id=capture_id,
                                            digest=digest, created_at=now), "reserved"


def cancelled_key(user, capture_id):
    return f"free-voice:cancelled:{user.pk}:{capture_id}"


def cancel_free_dictation(user, capture_id):
    """Discards a dictation that is still being understood. The cancel is also
    remembered for a while, because it can arrive before its own request has
    reserved a slot, for example during a slow WAV upload. A new attempt needs a
    new capture ID. Counted dictations stay counted."""
    with transaction.atomic():
        # The same lock as reserve_free_dictation, so the two never interleave.
        User.objects.select_for_update().get(pk=user.pk)
        cache.set(cancelled_key(user, capture_id), True, PENDING_TIMEOUT.total_seconds())
        FreeDictation.objects.filter(user=user, capture_id=capture_id, counted=False).delete()
