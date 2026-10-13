from django.conf import settings
from django.core.cache import cache
from django.db import connection
from django.http import JsonResponse
from django.shortcuts import render
from django.utils import timezone
from rest_framework.exceptions import Throttled
from rest_framework.parsers import JSONParser, MultiPartParser
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView
from . import ai
from .models import User
from .serializers import DraftRequestSerializer
from .capture_context import capture_context
from .billing import require_pro


def health(request):
    with connection.cursor() as cursor:
        cursor.execute("SELECT 1")
    return JsonResponse({"status": "ok", "features": {"notes": True, "groups": True, "assignments": True, "notifications": True}})


def live(request):
    # Startup/liveness probes must not wake an idle Neon database.
    return JsonResponse({"status": "ok", "environment": settings.DEPLOYMENT_ENVIRONMENT})


def playground(request):
    if settings.DEPLOYMENT_ENVIRONMENT != "development":
        from django.http import Http404
        raise Http404()
    test_account = None
    if settings.LOCAL_TEST_ACCOUNT_ENABLED and User.objects.filter(
        email=settings.LOCAL_TEST_ACCOUNT_EMAIL.strip().casefold(),
        is_active=True, is_staff=False, is_superuser=False,
    ).exists():
        test_account = {"email": settings.LOCAL_TEST_ACCOUNT_EMAIL,
                        "password": settings.LOCAL_TEST_ACCOUNT_PASSWORD}
    return render(request, "playground.html", {"test_account": test_account})


def reset_page(request):
    response = render(request, "reset.html")
    response["Referrer-Policy"] = "no-referrer"
    response["Cache-Control"] = "no-store"
    return response


def invitation_page(request, download=False):
    import secrets
    nonce = secrets.token_urlsafe(24)
    response = render(request, "invitation.html", {
        "nonce": nonce, "download": download,
        "app_scheme": "taskflow-staging" if settings.DEPLOYMENT_ENVIRONMENT == "staging" else "taskflow",
    })
    response["Referrer-Policy"] = "no-referrer"
    response["Cache-Control"] = "no-store"
    response["Content-Security-Policy"] = (
        f"default-src 'none'; script-src 'nonce-{nonce}'; style-src 'nonce-{nonce}'; "
        "base-uri 'none'; form-action 'none'; frame-ancestors 'none'")
    return response


def consume_budget(key, limit):
    if cache.add(key, 1, 86400):
        count = 1
    else:
        count = cache.incr(key)
    if count > limit:
        cache.decr(key)
        raise Throttled(detail="Daily AI limit reached. You can still create tasks manually.", wait=3600)


def release_budget(key):
    try:
        cache.decr(key)
    except ValueError:
        pass  # The reservation expired while the provider was running.


class DraftView(APIView):
    permission_classes = [IsAuthenticated]
    throttle_scope = "ai"
    parser_classes = [JSONParser, MultiPartParser]
    batch = False

    def post(self, request):
        serializer = DraftRequestSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        data = serializer.validated_data
        data["collaboration_context"] = capture_context(request.user, data.get("project_id"))
        require_pro(request.user)
        day = timezone.now().date().isoformat()
        budget_key = f"ai:{day}:user:{request.user.pk}"
        consume_budget(budget_key, settings.AI_REQUESTS_PER_DAY)
        try:
            consume_budget(f"ai:{day}:global", 200)
        except Throttled:
            release_budget(budget_key)
            raise
        data.setdefault("reference_time", timezone.now())
        try:
            return Response(ai.make_drafts(data) if self.batch else ai.make_draft(data))
        except ai.AIUnavailable as error:
            # Failed captures do not use up the account allowance. The global attempt budget
            # and burst throttle still bound provider traffic and cost.
            release_budget(budget_key)
            return Response({"detail": str(error)}, status=error.status)


class DraftBatchView(DraftView):
    batch = True
