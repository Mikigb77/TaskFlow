from zoneinfo import ZoneInfo, ZoneInfoNotFoundError
from django.contrib.auth.password_validation import validate_password
from django.utils.dateparse import parse_datetime
from rest_framework import serializers
from .models import User, Task


def validate_timezone(value):
    try:
        ZoneInfo(value)
    except (ZoneInfoNotFoundError, ValueError):
        raise serializers.ValidationError("Choose a valid IANA time zone, such as Europe/Madrid.")
    return value


class UserSerializer(serializers.ModelSerializer):
    class Meta:
        model = User
        fields = ["id", "email", "first_name", "timezone"]


class RegistrationSerializer(serializers.ModelSerializer):
    password = serializers.CharField(write_only=True, max_length=128, trim_whitespace=False)
    timezone = serializers.CharField(max_length=64, validators=[validate_timezone], required=False)

    class Meta:
        model = User
        fields = ["email", "password", "first_name", "timezone"]

    def validate_email(self, value):
        value = value.strip().casefold()
        if User.objects.filter(email__iexact=value).exists():
            raise serializers.ValidationError("An account with this email already exists.")
        return value

    def validate(self, attrs):
        validate_password(attrs["password"], User(email=attrs["email"], first_name=attrs.get("first_name", "")))
        return attrs

    def create(self, validated_data):
        return User.objects.create_user(**validated_data)


class ZonedDateTimeField(serializers.DateTimeField):
    def to_internal_value(self, value):
        if not isinstance(value, str):
            raise serializers.ValidationError("Use an ISO 8601 date with a time-zone offset.")
        try:
            parsed = parse_datetime(value)
        except ValueError:
            parsed = None
        if parsed is None or parsed.utcoffset() is None:
            raise serializers.ValidationError("Include a time-zone offset or Z.")
        return super().to_internal_value(value)


class TaskSerializer(serializers.ModelSerializer):
    due_date = ZonedDateTimeField()
    priority = serializers.IntegerField(min_value=1, max_value=3, default=1)
    version = serializers.IntegerField(min_value=0, required=False, default=0)
    notes = serializers.CharField(max_length=8000, allow_blank=True, default="")

    class Meta:
        model = Task
        fields = ["id", "title", "due_date", "priority", "notes", "is_completed", "is_deleted", "version", "created_at", "updated_at"]
        read_only_fields = ["id", "created_at", "updated_at"]


class DraftRequestSerializer(serializers.Serializer):
    text = serializers.CharField(min_length=3, max_length=4000, required=False)
    timezone = serializers.CharField(max_length=64, validators=[validate_timezone])
    reference_time = ZonedDateTimeField(required=False)
    audio = serializers.FileField(required=False)

    def validate(self, attrs):
        if bool(attrs.get("text")) == bool(attrs.get("audio")):
            raise serializers.ValidationError("Supply either text or one WAV recording.")
        return attrs
