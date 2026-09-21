from django.conf import settings
from django.core.cache import cache
from django.db import connection
from django.http import JsonResponse
from django.shortcuts import render
from django.utils import timezone
from rest_framework.exceptions import Throttled
from rest_framework.parsers import JSONParser, MultiPartParser
from rest_framework.response import Response
from rest_framework.views import APIView
from . import ai
from .models import User
from .serializers import DraftRequestSerializer


def health(request):
    with connection.cursor() as cursor:
        cursor.execute("SELECT 1")
    return JsonResponse({"status": "ok"})


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
        raise Throttled(detail="Daily AI limit reached. You can still create tasks manually.", wait=3600)


class DraftView(APIView):
    throttle_scope = "ai"
    parser_classes = [JSONParser, MultiPartParser]

    def post(self, request):
        serializer = DraftRequestSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        day = timezone.now().date().isoformat()
        consume_budget(f"ai:{day}:user:{request.user.pk}", settings.AI_REQUESTS_PER_DAY)
        consume_budget(f"ai:{day}:global", 200)
        data = serializer.validated_data
        data.setdefault("reference_time", timezone.now())
        try:
            return Response(ai.make_draft(data))
        except ai.AIUnavailable as error:
            return Response({"detail": str(error)}, status=error.status)
