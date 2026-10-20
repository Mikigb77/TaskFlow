import hashlib
import re
from datetime import timedelta

from django.contrib.auth import authenticate
from django.contrib.auth.password_validation import validate_password
from django.contrib.auth.tokens import default_token_generator
from django.core.cache import cache
from django.core.exceptions import ValidationError as DjangoValidationError
from django.db import IntegrityError, transaction
from django.utils import timezone
from django.utils.http import urlsafe_base64_decode
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
                                 mark_verified, resend_code, send_code, send_new_code, take_over_unconfirmed, unconfirmed,
                                 verification_required)
from .models import EmailVerification, PasswordReset, User, LoginSession
from .password_reset import code_matches as reset_code_matches, request_reset, set_new_password
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
            wait = resend_code(user, email_language(request.data.get("language")))
            if wait:
                # Said rather than a 204, so the app never claims a code went out (D9, 2026-10-18).
                return Response({"code": "resend_limited", "retry_after": wait,
                                 "detail": "Too many codes asked for. Wait before asking for another."},
                                status=429, headers={"Retry-After": str(wait)})
        # Otherwise the same answer whether or not the account exists or is confirmed.
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

    def patch(self, request):
        """Set the first name people see in shared projects; nothing else changes here.

        The app asks a password account for it once, when it first shares or joins a project
        (D8, 2026-10-18). Blank clears it, and the email's first part shows again."""
        fields = set(request.data) if isinstance(request.data, dict) else set()
        if fields != {"first_name"}:
            raise ValidationError({"detail": "Send first_name, and nothing else."})
        name = serializers.CharField(max_length=150, allow_blank=True).run_validation(request.data["first_name"])
        request.user.first_name = " ".join(name.split())
        request.user.save(update_fields=["first_name"])
        return Response(UserSerializer(request.user).data)


RECOVERY_REQUESTED = {"detail": "If that account exists, a recovery email has been sent."}
PASSWORD_UPDATED = {"detail": "Password updated. Sign in with your new password."}


class ResetRequestView(PublicAuthView):
    """Email a 6-digit recovery code (docs/PASSWORD_RECOVERY.md)."""
    throttle_scope = "recovery"

    def post(self, request):
        email = serializers.EmailField().run_validation(request.data.get("email"))
        request_reset(email, email_language(request.data.get("language")) or "en")
        # The same answer whether or not the account exists, and whether or not a code went out.
        return Response(RECOVERY_REQUESTED)


class ResetConfirmView(PublicAuthView):
    """Set a new password with the emailed code (docs/PASSWORD_RECOVERY.md).

    {"email", "code": "123456", "password"}. The long uid:token code of the emails sent before
    6-digit codes still works without the email, for older app builds and reset.html."""

    def post(self, request):
        password = serializers.CharField(max_length=128, trim_whitespace=False).run_validation(request.data.get("password"))
        raw = request.data.get("code")
        if isinstance(raw, int) and not isinstance(raw, bool):
            raw = f"{raw:06d}"  # a code sent as a JSON number loses its leading zeros
        code = serializers.CharField(max_length=300).run_validation(raw)
        if ":" in code:
            return self.confirm_link_code(code, password)
        code = re.sub(r"[\s-]", "", code)
        if not re.fullmatch(r"[0-9]{6}", code):
            return Response(CODE_INVALID, status=400)
        if not request.data.get("email"):
            # Without an address there's no account to check the code against: as for an unknown one.
            return Response(CODE_EXPIRED, status=400)
        email = serializers.EmailField(max_length=254).run_validation(request.data.get("email")).strip().casefold()
        with transaction.atomic():
            user = User.objects.select_for_update().filter(email__iexact=email, is_active=True).first()
            row = PasswordReset.objects.select_for_update().filter(user=user).first() if user else None
            # Unknown, expired and locked after 5 wrong tries look the same.
            if row is None or row.expires_at <= timezone.now() or row.attempts >= MAX_WRONG_ATTEMPTS:
                return Response(CODE_EXPIRED, status=400)
            if not reset_code_matches(row, code):
                row.attempts += 1
                row.save(update_fields=["attempts"])
                # Returned, not raised, so the wrong try is still counted when the block commits.
                return Response(CODE_INVALID, status=400)
            try:
                validate_password(password, user)
            except DjangoValidationError as error:
                # The code stays good, untried: the person picks another password and sends it again.
                raise ValidationError({"password": error.messages})
            set_new_password(user, password)
        # The person proved the mailbox, so a lock from earlier wrong passwords doesn't keep them out.
        cache.delete(login_fail_key(email))
        return Response(PASSWORD_UPDATED)

    def confirm_link_code(self, code, password):
        """The uid:token code, checked by Django's token generator, as before."""
        try:
            uid, token = code.split(":", 1)
            user_id = urlsafe_base64_decode(uid).decode()
            with transaction.atomic():
                user = User.objects.select_for_update().get(pk=user_id, is_active=True)
                if not default_token_generator.check_token(user, token):
                    raise ValueError()
                validate_password(password, user)
                set_new_password(user, password)
        except DjangoValidationError as error:
            raise ValidationError({"password": error.messages})
        except (ValueError, TypeError, OverflowError, UnicodeError, User.DoesNotExist):
            return Response(CODE_EXPIRED, status=400)
        cache.delete(login_fail_key(user.email))
        return Response(PASSWORD_UPDATED)
