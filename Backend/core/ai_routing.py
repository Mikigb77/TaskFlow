"""Explicit AI Studio / Vertex routing, with one bounded paid attempt per stage.

No user content or credentials enter the circuit-breaker keys or logs. Billing
entitlements and application quotas are enforced by the API before reaching here.
"""
import hashlib
import logging
import time

import httpx
from django.conf import settings
from django.core.cache import cache
from django.core.exceptions import ImproperlyConfigured
from google.genai import errors

logger = logging.getLogger(__name__)
TRANSIENT = {429, 500, 502, 503, 504}
try:
    # Newer Google SDKs prefer httpx2 when available; its errors have different
    # classes from httpx even though the API is compatible.
    import httpx2
    TRANSPORT_ERRORS = (httpx.TransportError, httpx2.TransportError)
except ImportError:
    TRANSPORT_ERRORS = (httpx.TransportError,)


def _code(error):
    return error.code if isinstance(error, errors.APIError) else 504


def _cooldown_key(stage):
    model = settings.AI_AUDIO_MODEL if stage == "audio" else settings.AI_TEXT_MODEL
    digest = hashlib.sha256(f"{stage}:{model}".encode()).hexdigest()[:24]
    return f"taskflow:ai:cooldown:{digest}"


def _cooling_down(key):
    try:
        return bool(cache.get(key))
    except Exception:
        # A failed cache cannot prevent the bounded provider attempts.
        return False


def _cool_down(key, error):
    seconds = 60 if _code(error) == 429 else 30
    response = getattr(error, "response", None)
    retry_after = getattr(response, "headers", {}).get("retry-after", "")
    if str(retry_after).isdigit():
        seconds = max(seconds, min(300, int(retry_after)))
    try:
        cache.set(key, True, timeout=seconds)
    except Exception:
        pass


def route(stage, free, vertex):
    """Bound inference timeouts and retries to one 45s budget per stage.

    auto: up to two short free calls, then one paid call with remaining time.
    Quota errors skip the second free call. A short shared cooldown avoids sending
    every user through the same overloaded free endpoint. No paid fallback follows
    auth, permission, invalid-input or model-validation errors.
    """
    mode = settings.AI_ROUTE
    if mode not in {"ai_studio", "auto", "vertex"}:
        raise ImproperlyConfigured("AI_ROUTE must be ai_studio, auto or vertex.")
    deadline = time.monotonic() + 45

    def remaining():
        milliseconds = int((deadline - time.monotonic()) * 1000)
        if milliseconds <= 0:
            raise errors.ServerError(504, {"error": {"message": "AI stage timed out"}})
        return milliseconds

    def call_vertex(fallback):
        started = time.monotonic()
        result = vertex(remaining())
        logger.info("AI stage=%s provider=vertex fallback=%s elapsed_ms=%d",
                    stage, fallback, round((time.monotonic() - started) * 1000))
        return result

    if mode == "vertex":
        return call_vertex(False)
    key = _cooldown_key(stage)
    if mode == "auto" and _cooling_down(key):
        return call_vertex(True)
    for attempt in range(2):
        timeout = remaining()
        if mode == "auto":
            timeout = min(timeout, settings.AI_FREE_ATTEMPT_SECONDS * 1000)
        started = time.monotonic()
        try:
            result = free(timeout)
            logger.info("AI stage=%s provider=ai_studio fallback=False elapsed_ms=%d",
                        stage, round((time.monotonic() - started) * 1000))
            return result
        except (errors.APIError, *TRANSPORT_ERRORS) as error:
            code = _code(error)
            if code not in TRANSIENT:
                raise
            logger.warning("AI stage=%s provider=ai_studio status=%s attempt=%d", stage, code, attempt + 1)
            if mode == "auto" and (code == 429 or attempt == 1):
                _cool_down(key, error)
                return call_vertex(True)
            if attempt or code == 429 or deadline - time.monotonic() <= 1:
                raise
            time.sleep(.5)
