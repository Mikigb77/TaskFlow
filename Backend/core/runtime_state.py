"""Small shared state with database row locks; no always-on Redis for staging."""
import hashlib
import time
from datetime import timedelta

from django.core.cache.backends.base import BaseCache, DEFAULT_TIMEOUT
from django.db import transaction
from django.utils import timezone
from rest_framework.throttling import ScopedRateThrottle

from .models import RuntimeState


class PostgresCache(BaseCache):
    def __init__(self, location, params):
        super().__init__(params)

    def _key(self, key, version):
        return hashlib.sha256(self.make_key(key, version=version).encode()).hexdigest()

    def _expiry(self, timeout):
        if timeout is DEFAULT_TIMEOUT:
            timeout = self.default_timeout
        return timezone.now() + timedelta(seconds=timeout if timeout is not None else 31536000)

    def get(self, key, default=None, version=None):
        row = RuntimeState.objects.filter(pk=self._key(key, version), expires_at__gt=timezone.now()).first()
        return row.value if row else default

    def set(self, key, value, timeout=DEFAULT_TIMEOUT, version=None):
        RuntimeState.objects.update_or_create(key=self._key(key, version), defaults={
            "value": value, "expires_at": self._expiry(timeout)})

    def add(self, key, value, timeout=DEFAULT_TIMEOUT, version=None):
        with transaction.atomic():
            row, created = RuntimeState.objects.select_for_update().get_or_create(
                key=self._key(key, version), defaults={"value": value, "expires_at": self._expiry(timeout)})
            if not created and row.expires_at > timezone.now():
                return False
            if not created:
                row.value, row.expires_at = value, self._expiry(timeout)
                row.save(update_fields=["value", "expires_at"])
            return True

    def incr(self, key, delta=1, version=None):
        with transaction.atomic():
            row = RuntimeState.objects.select_for_update().filter(pk=self._key(key, version)).first()
            if row is None or row.expires_at <= timezone.now():
                raise ValueError("Counter has expired")
            row.value += delta
            row.save(update_fields=["value"])
            return row.value

    def delete(self, key, version=None):
        return bool(RuntimeState.objects.filter(pk=self._key(key, version)).delete()[0])

    def clear(self):
        RuntimeState.objects.all().delete()
        return True


class AtomicScopedThrottle(ScopedRateThrottle):
    def allow_request(self, request, view):
        self.scope = getattr(view, self.scope_attr, None)
        if not self.scope:
            return True
        self.rate = self.get_rate()
        self.num_requests, self.duration = self.parse_rate(self.rate)
        raw_key = self.get_cache_key(request, view)
        if raw_key is None:
            return True
        key = "throttle:" + hashlib.sha256(raw_key.encode()).hexdigest()
        self.now = time.time()
        with transaction.atomic():
            row, _ = RuntimeState.objects.select_for_update().get_or_create(key=key, defaults={
                "value": [], "expires_at": timezone.now() + timedelta(seconds=self.duration)})
            self.history = [stamp for stamp in row.value if stamp > self.now - self.duration]
            if len(self.history) >= self.num_requests:
                return False
            self.history.insert(0, self.now)
            row.value = self.history
            row.expires_at = timezone.now() + timedelta(seconds=self.duration)
            row.save(update_fields=["value", "expires_at"])
        return True
