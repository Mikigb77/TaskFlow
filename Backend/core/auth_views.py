import hashlib
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
from rest_framework_simplejwt.exceptions import TokenError
from rest_framework_simplejwt.serializers import TokenRefreshSerializer
from rest_framework_simplejwt.tokens import RefreshToken
from rest_framework_simplejwt.utils import get_md5_hash_password

from .models import User, LoginSession
from .serializers import RegistrationSerializer, UserSerializer
from .staging import ensure_registration_allowed


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
        serializer = RegistrationSerializer(data=request.data)
        try:
            serializer.is_valid(raise_exception=True)
            ensure_registration_allowed(serializer.validated_data["email"])
            with transaction.atomic():
                user = serializer.save()
                return Response(issue_session(user), status=201)
        except DjangoValidationError as error:
            raise ValidationError({"password": error.messages})
        except IntegrityError:
            raise ValidationError({"email": ["An account with this email already exists."]})


class LoginView(PublicAuthView):
    def post(self, request):
        email = serializers.EmailField(max_length=254).run_validation(request.data.get("email"))
        password = serializers.CharField(max_length=128, trim_whitespace=False).run_validation(request.data.get("password"))
        email = email.strip().casefold()
        key = "login-fail:" + hashlib.sha256(email.encode()).hexdigest()
        if cache.get(key, 0) >= 5:
            raise Throttled(wait=900, detail="Too many failed attempts. Try again in 15 minutes.")
        user = authenticate(request, email=email, password=password)
        if user is None:
            if not cache.add(key, 1, 900):
                cache.incr(key)
            raise AuthenticationFailed("Email or password is incorrect.")
        cache.delete(key)
        user.last_login = timezone.now()
        user.save(update_fields=["last_login"])
        return Response(issue_session(user))


class RefreshView(PublicAuthView):
    def post(self, request):
        raw = serializers.CharField(max_length=4096).run_validation(request.data.get("refresh"))
        try:
            initial = RefreshToken(raw)
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
                LoginSession.objects.filter(user=user).update(revoked=True)
        except DjangoValidationError as error:
            raise ValidationError({"password": error.messages})
        except (ValueError, TypeError, OverflowError, UnicodeError, User.DoesNotExist):
            raise ValidationError({"code": "This recovery code is invalid or expired."})
        return Response({"detail": "Password updated. Sign in with your new password."})
