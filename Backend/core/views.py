from django.conf import settings
from django.core.cache import cache
from django.db import connection
from django.http import JsonResponse
from django.shortcuts import render
from django.utils import timezone
from django.utils.crypto import salted_hmac
from rest_framework.exceptions import Throttled
from rest_framework.parsers import JSONParser, MultiPartParser
from rest_framework.permissions import AllowAny
from rest_framework.response import Response
from rest_framework.views import APIView
from . import ai
from .models import User
from .serializers import DraftRequestSerializer


def health(request):
    with connection.cursor() as cursor:
        cursor.execute("SELECT 1")
    return JsonResponse({"status": "ok", "features": {"notes": True}})


def playground(request):
    test_account = None
    if settings.LOCAL_TEST_ACCOUNT_ENABLED and User.objects.filter(
        email=settings.LOCAL_TEST_ACCOUNT_EMAIL.strip().casefold(),
        is_active=True, is_staff=False, is_superuser=False,
    ).exists():
        test_account = {"email": settings.LOCAL_TEST_ACCOUNT_EMAIL,
                        "password": settings.LOCAL_TEST_ACCOUNT_PASSWORD}
    return render(request, "playground.html", {"test_account": test_account})


def reset_page(request):
    return render(request, "reset.html")


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
    permission_classes = [AllowAny]
    throttle_scope = "ai"
    parser_classes = [JSONParser, MultiPartParser]
    batch = False

    def post(self, request):
        serializer = DraftRequestSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        day = timezone.now().date().isoformat()
        if request.user.is_authenticated:
            budget_key = f"ai:{day}:user:{request.user.pk}"
            consume_budget(budget_key, settings.AI_REQUESTS_PER_DAY)
        else:
            # Never trust caller-provided forwarding headers for the guest budget.
            address = salted_hmac("voice-trial", request.META.get("REMOTE_ADDR", "unknown")).hexdigest()
            budget_key = f"ai:{day}:guest:{address}"
            consume_budget(budget_key, settings.AI_GUEST_REQUESTS_PER_DAY)
        try:
            consume_budget(f"ai:{day}:global", 200)
        except Throttled:
            release_budget(budget_key)
            raise
        data = serializer.validated_data
        data.setdefault("reference_time", timezone.now())
        try:
            return Response(ai.make_drafts(data) if self.batch else ai.make_draft(data))
        except ai.AIUnavailable as error:
            # Failed captures do not use up a trial. The global attempt budget
            # and burst throttle still bound provider traffic and cost.
            release_budget(budget_key)
            return Response({"detail": str(error)}, status=error.status)


class DraftBatchView(DraftView):
    batch = True
