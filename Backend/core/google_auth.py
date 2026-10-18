"""Verify Google identity before issuing TaskFlow's own revocable sessions."""
import hashlib
from functools import partial

from django.conf import settings
from django.core.cache import cache
from django.db import IntegrityError, transaction
from django.utils import timezone
from google.auth import exceptions as google_errors
from google.auth.transport.requests import Request
from google.oauth2 import id_token
from rest_framework import serializers
from rest_framework.exceptions import APIException, AuthenticationFailed, Throttled
from rest_framework.response import Response
from rest_framework.views import APIView

from .auth_views import PublicAuthView, issue_session
from .email_verification import mark_verified, take_over_unconfirmed, unconfirmed, verification_required
from .models import GoogleIdentity, User
from .serializers import UserSerializer, validate_timezone


class GoogleUnavailable(APIException):
    status_code = 503
    default_detail = "Google sign-in is temporarily unavailable."


class GoogleRequestSerializer(serializers.Serializer):
    id_token = serializers.CharField(max_length=12000, trim_whitespace=False)
    timezone = serializers.CharField(max_length=64, default="UTC", validators=[validate_timezone])
    password = serializers.CharField(max_length=128, required=False, trim_whitespace=False, write_only=True)


def verify_google_identity(token):
    subject, email, _ = verify_google_profile(token)
    return subject, email


def google_first_name(claims):
    """The name Google shares with basic sign-in, for people to recognise each other in shared
    projects. Only the given name, like the one name a password sign-up asks for."""
    for claim in ("given_name", "name"):
        value = claims.get(claim)
        if isinstance(value, str) and value.split():
            return " ".join(value.split())[:User._meta.get_field("first_name").max_length]
    return ""


def verify_google_profile(token):
    """Like verify_google_identity, plus the first name Google shares ("" when it shares none)."""
    audiences = settings.GOOGLE_OAUTH_CLIENT_IDS
    if not audiences:
        raise GoogleUnavailable({"detail": "Google sign-in is not configured.", "code": "google_not_configured"})
    try:
        # Never accept a caller-provided audience or decode without verification.
        claims = id_token.verify_oauth2_token(
            token, partial(Request(), timeout=5), audience=audiences)
    except google_errors.TransportError:
        raise GoogleUnavailable() from None
    except (ValueError, google_errors.GoogleAuthError):
        raise AuthenticationFailed({"detail": "Google identity could not be verified.", "code": "google_invalid_token"}) from None
    subject = claims.get("sub")
    if (claims.get("email_verified") is not True or not isinstance(subject, str)
            or not subject or len(subject) > 255):
        raise AuthenticationFailed({"detail": "Use a verified Google account.", "code": "google_invalid_token"})
    try:
        email = serializers.EmailField(max_length=254).run_validation(claims.get("email"))
    except serializers.ValidationError:
        raise AuthenticationFailed({"detail": "Google identity could not be verified.", "code": "google_invalid_token"}) from None
    return subject, email.strip().casefold(), google_first_name(claims)


def name_if_missing(user, first_name):
    """Give a nameless account Google's name. A name the person already has always stays."""
    if first_name and not user.first_name.strip():
        user.first_name = first_name
        return ["first_name"]
    return []


def conflict(code="google_link_required"):
    return Response({"code": code, "detail": "Sign in to your existing TaskFlow account to link Google."}, status=409)


class GoogleLoginView(PublicAuthView):
    def post(self, request):
        serializer = GoogleRequestSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        subject, email, first_name = verify_google_profile(serializer.validated_data["id_token"])
        try:
            with transaction.atomic():
                identity = GoogleIdentity.objects.select_related("user").filter(subject=subject).first()
                if identity:
                    user = User.objects.select_for_update().get(pk=identity.user_id)
                else:
                    from .staging import ensure_registration_allowed
                    existing = User.objects.select_for_update().filter(email__iexact=email).first()
                    if existing is None:
                        ensure_registration_allowed(email)
                        # verify_google_identity accepts only an address Google has verified.
                        user = User.objects.create_user(
                            email, timezone=serializer.validated_data["timezone"], email_verified=True,
                            first_name=first_name)
                    elif verification_required() and unconfirmed(existing):
                        # A password sign-up nobody confirmed: nobody could sign in to it, and
                        # Google has proven this person owns the address, so it becomes theirs.
                        ensure_registration_allowed(email)
                        user = existing
                        take_over_unconfirmed(user, first_name=first_name,
                                              time_zone=serializer.validated_data["timezone"])
                    else:
                        # Matching email alone is not authorization to merge accounts.
                        return conflict()
                    GoogleIdentity.objects.create(user=user, subject=subject)
                if not user.is_active:
                    raise AuthenticationFailed("This account is unavailable.")
                if user.email.casefold() == email:
                    mark_verified(user)  # Google says it has verified this address
                user.last_login = timezone.now()
                # Accounts from before names were taken from Google get one at their next sign-in.
                user.save(update_fields=["last_login", *name_if_missing(user, first_name)])
                return Response(issue_session(user))
        except IntegrityError:
            # A racing signup rolls back both identity and user. A normal retry
            # can use the winner; never reassign an identity to resolve a race.
            return conflict("google_account_changed")


class GoogleLinkView(APIView):
    throttle_scope = "auth"

    def post(self, request):
        serializer = GoogleRequestSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        key = "login-fail:" + hashlib.sha256(request.user.email.encode()).hexdigest()
        if cache.get(key, 0) >= 5:
            raise Throttled(wait=900)
        password = serializer.validated_data.get("password", "")
        if not request.user.has_usable_password() or not request.user.check_password(password):
            if not cache.add(key, 1, 900):
                cache.incr(key)
            return Response({"code": "google_password_required", "detail": "Confirm your current TaskFlow password."}, status=400)
        subject, email, first_name = verify_google_profile(serializer.validated_data["id_token"])
        if email != request.user.email.casefold():
            return Response({"code": "google_email_mismatch", "detail": "Choose the Google account with your TaskFlow email."}, status=409)
        try:
            with transaction.atomic():
                user = User.objects.select_for_update().get(pk=request.user.pk)
                # Recheck after the lock in case password/account state changed.
                if not user.is_active or not user.check_password(password):
                    raise AuthenticationFailed("Please sign in again.")
                existing = GoogleIdentity.objects.filter(user=user).first()
                if existing and existing.subject != subject:
                    return conflict("google_already_linked")
                identity, _ = GoogleIdentity.objects.get_or_create(subject=subject, defaults={"user": user})
                if identity.user_id != user.pk:
                    return conflict("google_already_linked")
                # The Google address is this account's (checked above), and Google verified it.
                mark_verified(user)
                if named := name_if_missing(user, first_name):
                    user.save(update_fields=named)
                cache.delete(key)
                return Response(UserSerializer(user).data)
        except IntegrityError:
            return conflict("google_already_linked")
