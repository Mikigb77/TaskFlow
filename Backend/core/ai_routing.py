"""One bounded budget per AI stage, on Vertex AI.

Every stage runs on Vertex with Application Default Credentials (core.ai.client);
there is no API key and no other provider. A stage gets 45 s in all, and one
retry after a transient failure when enough of that budget is left. No retry
follows a quota (429), auth, permission, invalid-input or model-validation error.

No user content or credentials enter the logs. Billing entitlements and
application quotas are enforced by the API before reaching here.
"""
import logging
import time

import httpx
from google.genai import errors

logger = logging.getLogger(__name__)
TRANSIENT = {500, 502, 503, 504}
BUDGET_SECONDS = 45
# Google refuses a request deadline under 10 s with a 400.
MIN_ATTEMPT_MS = 10_000
try:
    # Newer Google SDKs prefer httpx2 when available; its errors have different
    # classes from httpx even though the API is compatible.
    import httpx2
    TRANSPORT_ERRORS = (httpx.TransportError, httpx2.TransportError)
except ImportError:
    TRANSPORT_ERRORS = (httpx.TransportError,)


def _code(error):
    return error.code if isinstance(error, errors.APIError) else 504


def route(stage, call):
    """Run call(timeout_ms) within the stage's budget, retrying once if transient."""
    deadline = time.monotonic() + BUDGET_SECONDS

    def remaining():
        milliseconds = int((deadline - time.monotonic()) * 1000)
        if milliseconds < MIN_ATTEMPT_MS:
            raise errors.ServerError(504, {"error": {"message": "AI stage timed out"}})
        return milliseconds

    for attempt in range(2):
        started = time.monotonic()
        try:
            result = call(remaining())
        except (errors.APIError, *TRANSPORT_ERRORS) as error:
            code = _code(error)
            if code not in TRANSIENT:
                raise
            logger.warning("AI stage=%s provider=vertex status=%s attempt=%d", stage, code, attempt + 1)
            if attempt or (deadline - time.monotonic()) * 1000 < MIN_ATTEMPT_MS + 500:
                raise
            time.sleep(.5)
            continue
        logger.info("AI stage=%s provider=vertex attempt=%d elapsed_ms=%d",
                    stage, attempt + 1, round((time.monotonic() - started) * 1000))
        return result
