"""Server-authoritative RevenueCat access, bound to our opaque account identity."""
import hashlib
import http.client
import json
from urllib.parse import quote

from django.conf import settings
from django.core.cache import cache
from django.utils import timezone
from django.utils.dateparse import parse_datetime
from rest_framework.exceptions import APIException
from rest_framework.response import Response
from rest_framework.views import APIView


class BillingUnavailable(APIException):
    status_code = 503
    default_detail = "We could not verify TaskFlow Pro. Please try again."
    default_code = "billing_unavailable"

    def __init__(self):
        # A stable code lets the app say "try again", never "used up" or "full".
        super().__init__({"code": self.default_code, "detail": self.default_detail})


def _customer(billing_id):
    key = settings.REVENUECAT_API_KEY
    if not key:
        raise BillingUnavailable()
    # A fixed HTTPS destination, no redirects, and a bounded response. Never
    # accept an endpoint, app-user ID or entitlement claim from the phone.
    connection = http.client.HTTPSConnection("api.revenuecat.com", timeout=6)
    try:
        connection.request("GET", f"/v1/subscribers/{quote(str(billing_id), safe='')}",
                           headers={"Authorization": f"Bearer {key}", "Accept": "application/json"})
        response = connection.getresponse()
        payload = response.read(1024 * 1024 + 1)
        if response.status not in (200, 201) or len(payload) > 1024 * 1024:
            raise BillingUnavailable()
        return json.loads(payload)["subscriber"]
    except (OSError, http.client.HTTPException, ValueError, KeyError, TypeError) as error:
        raise BillingUnavailable() from error
    finally:
        connection.close()


def delete_customer(billing_id):
    """Delete this account's RevenueCat customer, once the account itself is gone.

    Best effort: Google Play keeps its own purchase records, and a failure here never undoes or
    blocks a deletion. True when RevenueCat confirms it, or never had that customer; None when
    billing isn't configured here."""
    key = settings.REVENUECAT_API_KEY
    if not key:
        return None
    connection = http.client.HTTPSConnection("api.revenuecat.com", timeout=6)
    try:
        connection.request("DELETE", f"/v1/subscribers/{quote(str(billing_id), safe='')}",
                           headers={"Authorization": f"Bearer {key}", "Accept": "application/json"})
        response = connection.getresponse()
        response.read(64 * 1024)
        return response.status in (200, 201, 204, 404)
    except (OSError, http.client.HTTPException):
        return False
    finally:
        connection.close()


def _date(value):
    if value is None:
        return None
    parsed = parse_datetime(value)
    if parsed is None or timezone.is_naive(parsed):
        raise ValueError("Invalid provider date")
    return parsed


def _access(subscriber, *, sandbox_allowed, now):
    inactive = {"active": False, "expires_at": None, "sandbox": False}
    entitlement = subscriber.get("entitlements", {}).get("taskflow_pro")
    if entitlement is None:
        return inactive
    product = entitlement["product_identifier"]
    purchase = subscriber.get("subscriptions", {}).get(product)
    lifetime = False
    if purchase is None:
        purchases = subscriber.get("non_subscriptions", {}).get(product, [])
        if not purchases:
            return inactive
        purchase = max(purchases, key=lambda p: p.get("purchase_date", ""))
        lifetime = True
    sandbox = purchase.get("is_sandbox")
    if type(sandbox) is not bool or (sandbox and not sandbox_allowed):
        return inactive
    if purchase.get("refunded_at") is not None:
        return inactive
    expires = _date(entitlement["expires_date"])
    grace = _date(entitlement.get("grace_period_expires_date"))
    until = max((value for value in (expires, grace) if value is not None), default=None)
    active = until > now if until is not None else lifetime and expires is None
    return {"active": active, "expires_at": until.isoformat() if until else None, "sandbox": sandbox}


def complimentary_pro(user):
    return bool(user.is_active and user.email.strip().casefold() in settings.COMPLIMENTARY_PRO_EMAILS
                and (str(user.billing_id) in settings.COMPLIMENTARY_PRO_BILLING_IDS
                     or hasattr(user, "google_identity")))


def subscription_access(user, *, refresh=False):
    # Check grants before the store or its cache. They are never supplied by
    # the client, do not expire, and do not require a purchase or a test receipt.
    if complimentary_pro(user):
        return {"active": True, "expires_at": None, "sandbox": False, "complimentary": True}
    sandbox_allowed = settings.DEPLOYMENT_ENVIRONMENT in ("development", "staging") and settings.REVENUECAT_ALLOW_SANDBOX
    if settings.REVENUECAT_API_KEY.startswith("test_") and not sandbox_allowed:
        raise BillingUnavailable()
    config = f"{settings.REVENUECAT_API_KEY}:taskflow_pro:{sandbox_allowed}"
    fingerprint = hashlib.sha256(config.encode()).hexdigest()[:16]
    key = f"billing:{fingerprint}:{user.billing_id}"
    now = timezone.now()
    cached = None if refresh else cache.get(key)
    if cached is not None:
        expires = _date(cached["expires_at"])
        if not cached["active"] or expires is None or expires > now:
            return cached
    try:
        result = _access(_customer(user.billing_id), sandbox_allowed=sandbox_allowed, now=now)
    except (ValueError, KeyError, TypeError, AttributeError) as error:
        raise BillingUnavailable() from error
    # Refresh after purchases via POST /billing/access/. Refund/revocation lag
    # is at most 30 seconds; outages never extend a cached grant beyond expiry.
    ttl = 30 if result["active"] else 5
    if result["expires_at"] and result["active"]:
        ttl = min(ttl, max(0, int((_date(result["expires_at"]) - now).total_seconds())))
    if ttl > 0:
        cache.set(key, result, ttl)
    return result


def has_pro(user):
    """True or False, or None when the store cannot be reached right now."""
    if not settings.REVENUECAT_API_KEY:
        # Billing is not configured, so only complimentary grants can be Pro.
        return complimentary_pro(user)
    try:
        return subscription_access(user)["active"]
    except BillingUnavailable:
        return None


class BillingAccessView(APIView):
    throttle_scope = "billing"

    def get(self, request):
        return Response({"entitlement": "taskflow_pro", **subscription_access(request.user)})

    def post(self, request):
        return Response({"entitlement": "taskflow_pro", **subscription_access(request.user, refresh=True)})
