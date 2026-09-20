from django.utils import timezone
from rest_framework.exceptions import AuthenticationFailed
from rest_framework_simplejwt.authentication import JWTAuthentication
from .models import LoginSession


class SessionJWTAuthentication(JWTAuthentication):
    def get_user(self, validated_token):
        user = super().get_user(validated_token)
        if not LoginSession.objects.filter(id=validated_token.get("sid"), user=user,
                                           revoked=False, expires_at__gt=timezone.now()).exists():
            raise AuthenticationFailed("Your session has ended. Please sign in again.")
        return user
