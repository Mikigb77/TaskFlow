import hashlib
import re
from datetime import timedelta
from urllib.parse import urlencode

from django.conf import settings
from django.contrib.auth import authenticate
from django.contrib.auth.password_validation import validate_password
from django.contrib.auth.tokens import default_token_generator
from django.core.cache import cache
from django.core.exceptions import ValidationError as DjangoValidationError
from django.db import IntegrityError, transaction
from django.utils import timezone
from django.utils.encoding import force_bytes
from django.utils.http import urlsafe_base64_encode, urlsafe_base64_decode
from rest_framework import serializers
from rest_framework.exceptions import AuthenticationFailed, Throttled, ValidationError
from rest_framework.permissions import AllowAny
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework_simplejwt.exceptions import AuthenticationFailed as TokenAuthenticationFailed, TokenError
from rest_framework_simplejwt.serializers import TokenRefreshSerializer
from rest_framework_simplejwt.tokens import RefreshToken
from rest_framework_simplejwt.utils import get_md5_hash_password

from .email_verification import (MAX_WRONG_ATTEMPTS, code_matches, email_language, has_live_code, issue_code,
                                 mark_verified, send_code, send_new_code, take_over_unconfirmed, unconfirmed,
                                 verification_required)
from .models import EmailVerification, User, LoginSession
from .serializers import EMAIL_EXISTS, RegistrationSerializer, UserSerializer
from .staging import ensure_registration_allowed

CODE_INVALID = {"code": "code_invalid", "detail": "That code isn't right. Check the email and try again."}
CODE_EXPIRED = {"code": "code_expired", "detail": "That code has expired. Ask for a new one."}
SIGNUP_REPLACED = {"code": "signup_replaced",
                   "detail": "This email was signed up again with another password. Sign up again to get a new code."}


def login_fail_key(email):
    # Sign-in's lock: after five wrong passwords, 15 minutes' wait. Email verification shares it.
    return "login-fail:" + hashlib.sha256(email.strip().casefold().encode()).hexdigest()


def issue_session(user):
    session = LoginSession.objects.create(user=user, expires_at=timezone.now() + timedelta(days=7))
    refresh = RefreshToken.for_user(user)
    refresh["sid"] = str(session.id)
    return {"access": str(refresh.access_token), "refresh": str(refresh), "user": UserSerializer(user).data}


class PublicAuthView(APIView):
    permission_classes = [AllowAny]
    authentication_classes = []
    throttle_scope = "auth"

    def get_authenticate_header(self, request):
        return "Bearer"


class RegisterView(PublicAuthView):
    def post(self, request):
        required = verification_required()
        serializer = RegistrationSerializer(data=request.data, context={"replace_unconfirmed": required})
        try:
            serializer.is_valid(raise_exception=True)
            data = serializer.validated_data
            ensure_registration_allowed(data["email"])
            if not required:
                with transaction.atomic():
                    # Usable at once, so it stays confirmed if verification is turned on later.
                    user = serializer.save(email_verified=True)
                    return Response(issue_session(user), status=201)
            with transaction.atomic():
                # A new sign-up's email follows its own request, else English.
                delivery = register_unconfirmed(data, email_language(request.data.get("language")) or "en")
            send_code(delivery)
            return Response({"verification_required": True, "email": data["email"]}, status=201)
        except DjangoValidationError as error:
            raise ValidationError({"password": error.messages})
        except IntegrityError:
            raise ValidationError({"email": [EMAIL_EXISTS]})


def register_unconfirmed(data, language):
    """Create an unconfirmed account, or replace one nobody confirmed, and queue its code."""
    user = User.objects.select_for_update().filter(email__iexact=data["email"]).first()
    if user is None:
        user = User.objects.create_user(**data, email_verified=False)
        return issue_code(user, language)
    if not unconfirmed(user):
        raise ValidationError({"email": [EMAIL_EXISTS]})
    try:
        delivery = issue_code(user, language)
    except Throttled:
        # A second tap with the same password keeps the code already on its way.
        if has_live_code(user) and user.check_password(data["password"]):
            return None
        raise
    take_over_unconfirmed(user, password=data["password"], first_name=data.get("first_name", ""),
                          time_zone=data.get("timezone"))
    return delivery


class VerifyEmailView(PublicAuthView):
    def post(self, request):
        email = serializers.EmailField(max_length=254).run_validation(request.data.get("email")).strip().casefold()
        raw = request.data.get("code")
        if isinstance(raw, int) and not isinstance(raw, bool):
            raw = f"{raw:06d}"  # a code sent as a JSON number loses its leading zeros
        code = re.sub(r"[\s-]", "", serializers.CharField(max_length=32).run_validation(raw))
        password = request.data.get("password")
        password = password if isinstance(password, str) else ""
        key = login_fail_key(email)
        if password and cache.get(key, 0) >= 5:
            # Sign-in's lock applies here too, so this can't be used to guess the password instead.
            raise Throttled(wait=900, detail="Too many failed attempts. Try again in 15 minutes.")
        with transaction.atomic():
            user = User.objects.select_for_update().filter(
                email__iexact=email, is_active=True, email_verified=False).first()
            if user is None:
                # Unknown and already confirmed look the same as an expired code.
                return Response(CODE_EXPIRED, status=400)
            # The password first: if this address was signed up again with another password, the
            # person entering the code isn't the one who chose the password now in place. That
            # spends no code try, and confirms nothing.
            if user.has_usable_password():
                if not password:
                    return Response(SIGNUP_REPLACED, status=400)
                if len(password) > 128 or not user.check_password(password):
                    if not cache.add(key, 1, 900):
                        cache.incr(key)
                    return Response(SIGNUP_REPLACED, status=400)
                cache.delete(key)
            if not re.fullmatch(r"[0-9]{6}", code):
                return Response(CODE_INVALID, status=400)
            row = EmailVerification.objects.select_for_update().filter(user=user).first()
            # Expired and locked after 5 wrong tries look the same.
            if row is None or row.expires_at <= timezone.now() or row.attempts >= MAX_WRONG_ATTEMPTS:
                return Response(CODE_EXPIRED, status=400)
            if not code_matches(row, code):
                row.attempts += 1
                row.save(update_fields=["attempts"])
                # Returned, not raised, so the wrong try is still counted when the block commits.
                return Response(CODE_INVALID, status=400)
            mark_verified(user)
            user.last_login = timezone.now()
            user.save(update_fields=["last_login"])
            return Response(issue_session(user))


class ResendVerificationView(PublicAuthView):
    def post(self, request):
        email = serializers.EmailField(max_length=254).run_validation(request.data.get("email")).strip().casefold()
        user = User.objects.filter(email__iexact=email, is_active=True, email_verified=False).first()
        if user is not None:
            send_new_code(user, email_language(request.data.get("language")))
        # The same answer whether or not the account exists, is confirmed or was sent a code.
        return Response(status=204)


class LoginView(PublicAuthView):
    def post(self, request):
        email = serializers.EmailField(max_length=254).run_validation(request.data.get("email"))
        password = serializers.CharField(max_length=128, trim_whitespace=False).run_validation(request.data.get("password"))
        email = email.strip().casefold()
        key = login_fail_key(email)
        if cache.get(key, 0) >= 5:
            raise Throttled(wait=900, detail="Too many failed attempts. Try again in 15 minutes.")
        user = authenticate(request, email=email, password=password)
        if user is None:
            if not cache.add(key, 1, 900):
                cache.incr(key)
            raise AuthenticationFailed("Email or password is incorrect.")
        cache.delete(key)
        if verification_required() and not user.email_verified:
            # The right password, but the address isn't confirmed: no session, and a fresh code
            # when the limits allow one. A wrong password never gets this far.
            send_new_code(user, email_language(request.data.get("language")))
            return Response({"code": "email_unverified", "email": user.email,
                             "detail": "Confirm your email to sign in. Enter the 6-digit code we emailed you."},
                            status=403)
        user.last_login = timezone.now()
        user.save(update_fields=["last_login"])
        return Response(issue_session(user))


class RefreshView(PublicAuthView):
    def post(self, request):
        raw = serializers.CharField(max_length=4096).run_validation(request.data.get("refresh"))
        try:
            initial = RefreshToken(raw)
        except TokenError:
            raise AuthenticationFailed("Your session has ended. Please sign in again.")
        if not User.objects.filter(pk=initial.get("user_id")).exists():
            # A token we signed, for an account that's been deleted: the same answer as the
            # API's other endpoints give, so the person's other phones erase their copy.
            raise TokenAuthenticationFailed("This account no longer exists.", code="user_not_found")
        try:
            with transaction.atomic():
                session = LoginSession.objects.select_for_update().select_related("user").get(
                    id=initial.get("sid"), user_id=initial.get("user_id"), revoked=False,
                    expires_at__gt=timezone.now(), user__is_active=True)
                if initial.get("hash_password") != get_md5_hash_password(session.user.password):
                    raise AuthenticationFailed("Please sign in again.")
                # Check again under the session lock: only one refresh can rotate this token.
                serializer = TokenRefreshSerializer(data={"refresh": raw})
                serializer.is_valid(raise_exception=True)
                session.expires_at = timezone.now() + timedelta(days=7)
                session.save(update_fields=["expires_at"])
                return Response(serializer.validated_data)
        except (TokenError, LoginSession.DoesNotExist, ValueError, DjangoValidationError):
            raise AuthenticationFailed("Your session has ended. Please sign in again.")


class LogoutView(APIView):
    def post(self, request):
        LoginSession.objects.filter(id=request.auth["sid"], user=request.user).update(revoked=True)
        return Response(status=204)


class MeView(APIView):
    def get(self, request):
        return Response(UserSerializer(request.user).data)


class ResetRequestView(PublicAuthView):
    throttle_scope = "recovery"

    def post(self, request):
        email = serializers.EmailField().run_validation(request.data.get("email"))
        user = User.objects.filter(email__iexact=email.strip(), is_active=True).first()
        if user:
            uid = urlsafe_base64_encode(force_bytes(user.pk))
            token = default_token_generator.make_token(user)
            link = settings.PASSWORD_RESET_BASE_URL + "#" + urlencode({"uid": uid, "token": token})
            from .models import EmailDelivery
            from .email_delivery import reserve_email, deliver_email
            from rest_framework.exceptions import Throttled
            try:
                reserve_email(user.email)
            except Throttled:
                # Never reveal whether a mailbox has an account or is quota-limited.
                return Response({"detail": "If that account exists, a recovery email has been sent."})
            message = EmailDelivery.objects.create(
                recipient=user.email, subject="Reset your TaskFlow password",
                body=f"Use this link within 30 minutes:\n{link}\n\nOr paste this recovery code in the app:\n{uid}:{token}\n\nIf you did not request this, ignore this email.",
                expires_at=timezone.now() + timedelta(minutes=30))
            deliver_email(message.pk)
        return Response({"detail": "If that account exists, a recovery email has been sent."})


class ResetConfirmView(PublicAuthView):
    def post(self, request):
        code = serializers.CharField(max_length=300).run_validation(request.data.get("code"))
        password = serializers.CharField(max_length=128, trim_whitespace=False).run_validation(request.data.get("password"))
        try:
            uid, token = code.split(":", 1)
            user_id = urlsafe_base64_decode(uid).decode()
            with transaction.atomic():
                user = User.objects.select_for_update().get(pk=user_id, is_active=True)
                if not default_token_generator.check_token(user, token):
                    raise ValueError()
                validate_password(password, user)
                user.set_password(password)
                user.save(update_fields=["password"])
                # The recovery email proved the address, which confirms an unconfirmed sign-up.
                mark_verified(user)
                LoginSession.objects.filter(user=user).update(revoked=True)
        except DjangoValidationError as error:
            raise ValidationError({"password": error.messages})
        except (ValueError, TypeError, OverflowError, UnicodeError, User.DoesNotExist):
            raise ValidationError({"code": "This recovery code is invalid or expired."})
        return Response({"detail": "Password updated. Sign in with your new password."})
