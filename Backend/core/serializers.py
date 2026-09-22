from zoneinfo import ZoneInfo, ZoneInfoNotFoundError
from django.contrib.auth.password_validation import validate_password
from django.utils.dateparse import parse_datetime
from rest_framework import serializers
from .models import User, Task, TaskList


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


class TaskListSerializer(serializers.ModelSerializer):
    version = serializers.IntegerField(min_value=0, default=0)

    class Meta:
        model = TaskList
        fields = ["id", "name", "color", "archived", "version", "updated_at"]
        read_only_fields = ["id", "updated_at"]


class ChecklistItemSerializer(serializers.Serializer):
    id = serializers.UUIDField()
    title = serializers.CharField(max_length=160)
    completed = serializers.BooleanField(default=False)
    completed_dates = serializers.ListField(child=serializers.DateField(), max_length=10000, default=list)

    def validate(self, attrs):
        attrs["id"] = str(attrs["id"])
        attrs["completed_dates"] = sorted({value.isoformat() for value in attrs["completed_dates"]})
        return attrs


class TaskSerializer(serializers.ModelSerializer):
    due_date = ZonedDateTimeField(allow_null=True, required=False, default=None)
    scheduled_date = serializers.DateField(allow_null=True, required=False, default=None)
    repeat_until = serializers.DateField(allow_null=True, required=False, default=None)
    completed_dates = serializers.ListField(child=serializers.DateField(), max_length=10000, required=False, default=list)
    priority = serializers.IntegerField(min_value=1, max_value=3, default=1)
    reminder_minutes = serializers.IntegerField(min_value=-1, max_value=10080, allow_null=True, required=False, default=None)
    reminder_time = serializers.IntegerField(min_value=0, max_value=1439, allow_null=True, required=False, default=None)
    version = serializers.IntegerField(min_value=0, required=False, default=0)
    notes = serializers.CharField(max_length=8000, allow_blank=True, default="")
    checklist = ChecklistItemSerializer(many=True, required=False)
    list_id = serializers.PrimaryKeyRelatedField(source="task_list", queryset=TaskList.objects.none(),
                                                allow_null=True, required=False)
    labels = serializers.ListField(child=serializers.CharField(max_length=32), max_length=10, required=False)

    def get_fields(self):
        fields = super().get_fields()
        request = self.context.get("request")
        if request and request.user.is_authenticated:
            fields["list_id"].queryset = TaskList.objects.filter(owner=request.user)
        return fields

    def validate_labels(self, value):
        return list(dict.fromkeys(item.lower() for item in value))

    def validate_checklist(self, value):
        if len(value) > 50:
            raise serializers.ValidationError("Use no more than 50 checklist items.")
        if len({item["id"] for item in value}) != len(value):
            raise serializers.ValidationError("Each checklist item must have a unique ID.")
        return value

    class Meta:
        model = Task
        fields = ["id", "title", "due_date", "scheduled_date", "recurrence", "repeat_until", "completed_dates", "priority", "reminder_minutes", "reminder_time", "notes", "checklist", "list_id", "labels", "is_completed", "is_deleted", "version", "created_at", "updated_at"]
        read_only_fields = ["id", "created_at", "updated_at"]

    def validate(self, attrs):
        due, day = attrs.get("due_date"), attrs.get("scheduled_date")
        repeat = attrs.get("recurrence", getattr(self.instance, "recurrence", "none"))
        if due is not None and day is not None:
            raise serializers.ValidationError("Use a date-only schedule or a timed schedule, not both.")
        if repeat != "none" and due is None and day is None:
            raise serializers.ValidationError({"recurrence": "Choose a start date for a repeating task."})
        if repeat == "none" and (attrs.get("repeat_until") or attrs.get("completed_dates")):
            raise serializers.ValidationError("Repeat settings require a repeating task.")
        if repeat != "none" and attrs.get("is_completed"):
            raise serializers.ValidationError("Complete individual dates of a repeating task.")
        if day and attrs.get("repeat_until") and attrs["repeat_until"] < day:
            raise serializers.ValidationError({"repeat_until": "The end date must be on or after the start date."})
        attrs["completed_dates"] = sorted({value.isoformat() for value in attrs.get("completed_dates", [])})
        return attrs


class DraftRequestSerializer(serializers.Serializer):
    text = serializers.CharField(min_length=3, max_length=4000, required=False)
    timezone = serializers.CharField(max_length=64, validators=[validate_timezone])
    reference_time = ZonedDateTimeField(required=False)
    audio = serializers.FileField(required=False)

    def validate(self, attrs):
        if bool(attrs.get("text")) == bool(attrs.get("audio")):
            raise serializers.ValidationError("Supply either text or one WAV recording.")
        return attrs
