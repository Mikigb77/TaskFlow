from zoneinfo import ZoneInfo, ZoneInfoNotFoundError
from django.contrib.auth.password_validation import validate_password
from django.utils.dateparse import parse_datetime
from rest_framework import serializers
from .models import User, Task, TaskList, TaskGroup, ProjectPreference
from .billing import complimentary_pro


def validate_timezone(value):
    try:
        ZoneInfo(value)
    except (ZoneInfoNotFoundError, ValueError):
        raise serializers.ValidationError("Choose a valid IANA time zone, such as Europe/Madrid.")
    return value


class UserSerializer(serializers.ModelSerializer):
    google_linked = serializers.SerializerMethodField()
    complimentary_pro = serializers.SerializerMethodField()

    def get_complimentary_pro(self, user):
        return complimentary_pro(user)

    def get_google_linked(self, user):
        return hasattr(user, "google_identity")

    class Meta:
        model = User
        fields = ["id", "email", "first_name", "timezone", "billing_id", "google_linked", "complimentary_pro"]
        read_only_fields = ["billing_id"]


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
    role = serializers.SerializerMethodField()
    group_id = serializers.PrimaryKeyRelatedField(source="group", queryset=TaskGroup.objects.none(), allow_null=True, required=False)
    group_name = serializers.CharField(source="group.name", read_only=True, default=None)
    group_archived = serializers.BooleanField(source="group.archived", read_only=True, default=False)
    people = serializers.SerializerMethodField()
    pinned = serializers.SerializerMethodField()
    notifications = serializers.SerializerMethodField()

    def get_fields(self):
        fields = super().get_fields()
        request = self.context.get("request")
        if request and request.user.is_authenticated:
            from .list_access import visible_groups
            fields["group_id"].queryset = visible_groups(request.user)
        return fields

    def get_people(self, value):
        from .list_access import project_people
        if value.group_id:
            cache = self.context.setdefault("group_people", {})
            if value.group_id not in cache:
                cache[value.group_id] = project_people(value)
            return cache[value.group_id]
        return project_people(value)

    def _preference(self, value):
        key = "project_preferences"
        if key not in self.context:
            self.context[key] = {row.task_list_id: row for row in ProjectPreference.objects.filter(user=self.context["request"].user)}
        return self.context[key].get(value.pk)

    def get_pinned(self, value):
        return getattr(self._preference(value), "pinned", False)

    def get_notifications(self, value):
        return getattr(self._preference(value), "notifications", "assigned")

    def get_role(self, value):
        from .list_access import list_role
        return list_role(value, self.context["request"].user)

    class Meta:
        model = TaskList
        fields = ["id", "name", "color", "archived", "version", "updated_at", "shared", "role", "group_id", "group_name", "group_archived", "owner_id", "people", "pinned", "notifications"]
        read_only_fields = ["id", "updated_at", "shared", "role", "owner_id"]


class OccurrenceExceptionSerializer(serializers.Serializer):
    original_date = serializers.DateField()
    skipped = serializers.BooleanField(default=False)
    due_date = ZonedDateTimeField(allow_null=True, required=False, default=None)
    scheduled_date = serializers.DateField(allow_null=True, required=False, default=None)

    def validate(self, attrs):
        due, day = attrs["due_date"], attrs["scheduled_date"]
        if attrs["skipped"]:
            if due is not None or day is not None:
                raise serializers.ValidationError("A skipped occurrence cannot also be rescheduled.")
        elif (due is None) == (day is None):
            raise serializers.ValidationError("Choose a date-only or timed schedule for this occurrence.")
        return {"original_date": attrs["original_date"].isoformat(), "skipped": attrs["skipped"],
                "due_date": due.isoformat().replace("+00:00", "Z") if due else None,
                "scheduled_date": day.isoformat() if day else None}


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
    kind = serializers.ChoiceField(choices=["task", "note"], required=False)
    due_date = ZonedDateTimeField(allow_null=True, required=False, default=None)
    scheduled_date = serializers.DateField(allow_null=True, required=False, default=None)
    deadline_at = ZonedDateTimeField(allow_null=True, required=False)
    deadline_date = serializers.DateField(allow_null=True, required=False)
    duration_minutes = serializers.IntegerField(min_value=1, max_value=1440, allow_null=True, required=False)
    reminder_anchor = serializers.ChoiceField(choices=["planned", "deadline"], required=False)
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
    repeat_interval = serializers.IntegerField(min_value=1, max_value=99, required=False)
    repeat_weekdays = serializers.ListField(child=serializers.IntegerField(min_value=1, max_value=7), max_length=7, required=False)
    exceptions = OccurrenceExceptionSerializer(many=True, required=False)
    assignment = serializers.ChoiceField(choices=["personal", "member", "group", "unassigned"], required=False)
    assignee_id = serializers.IntegerField(min_value=1, allow_null=True, required=False)
    assignee_name = serializers.SerializerMethodField()
    created_by = serializers.IntegerField(source="owner_id", read_only=True)

    def get_assignee_name(self, task):
        from .list_access import display_name
        return display_name(task.assignee) if task.assignee_id else None

    def validate_assignment_context(self, attrs, kind):
        from .list_access import project_people
        project = attrs.get("task_list", getattr(self.instance, "task_list", None))
        shared = bool(project and (project.shared or project.group_id))
        assignment = attrs.get("assignment", getattr(self.instance, "assignment", "group" if shared else "personal"))
        assignee_id = attrs.get("assignee_id", getattr(self.instance, "assignee_id", None))
        if kind == "note":
            if assignment not in ("personal", "group") or assignee_id is not None:
                raise serializers.ValidationError({"assignment": "Notes do not have a responsible person."})
            attrs.update(assignment="personal", assignee_id=None)
            return
        if not shared:
            if assignment != "personal" or assignee_id is not None:
                raise serializers.ValidationError({"assignment": "Choose a shared project before assigning a task."})
        elif assignment == "personal":
            # Older clients and personal-to-shared moves have no assignment field.
            assignment = "group"
        if assignment == "member":
            eligible = {person["user_id"] for person in project_people(project) if person["role"] != "viewer"}
            if assignee_id not in eligible:
                raise serializers.ValidationError({"assignee_id": "Choose a current project member who can edit tasks."})
        elif assignee_id is not None:
            raise serializers.ValidationError({"assignee_id": "Only a member assignment can have a responsible person."})
        attrs.update(assignment=assignment, assignee_id=assignee_id)

    def validate_repeat_weekdays(self, value):
        return sorted(set(value))

    def validate_exceptions(self, value):
        if len(value) > 500:
            raise serializers.ValidationError("Use no more than 500 occurrence changes per series.")
        if len({item["original_date"] for item in value}) != len(value):
            raise serializers.ValidationError("Change each original occurrence at most once.")
        return sorted(value, key=lambda item: item["original_date"])

    def get_fields(self):
        fields = super().get_fields()
        request = self.context.get("request")
        if request and request.user.is_authenticated:
            from .list_access import visible_lists
            fields["list_id"].queryset = visible_lists(request.user)
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
        fields = ["id", "kind", "title", "due_date", "scheduled_date", "deadline_at", "deadline_date", "duration_minutes", "reminder_anchor", "recurrence", "repeat_until", "repeat_interval", "repeat_weekdays", "exceptions", "completed_dates", "priority", "reminder_minutes", "reminder_time", "notes", "checklist", "list_id", "labels", "is_completed", "is_deleted", "version", "created_at", "updated_at", "assignment", "assignee_id", "assignee_name", "created_by"]
        read_only_fields = ["id", "created_at", "updated_at"]

    def validate(self, attrs):
        due, day = attrs.get("due_date"), attrs.get("scheduled_date")
        kind = attrs.get("kind", getattr(self.instance, "kind", "task"))
        self.validate_assignment_context(attrs, kind)
        if self.instance and kind != self.instance.kind:
            raise serializers.ValidationError({"kind": "Keep the original type. Create a separate task or note instead."})
        if kind == "note":
            effective = lambda key, default=None: attrs.get(key, getattr(self.instance, key, default))
            if (any(effective(key) is not None for key in ("due_date", "scheduled_date", "deadline_at", "deadline_date", "duration_minutes", "reminder_time", "repeat_until"))
                    or effective("priority", 1) != 1 or effective("is_completed", False)
                    or effective("recurrence", "none") != "none" or effective("repeat_interval", 1) != 1
                    or effective("reminder_anchor", "planned") != "planned" or effective("reminder_minutes") not in (None, -1)
                    or any(effective(key, []) for key in ("completed_dates", "repeat_weekdays", "exceptions"))
                    or any(item.get("completed_dates") for item in effective("checklist", []))):
                raise serializers.ValidationError({"kind": "Notes hold information and checklists, without task schedules, priority, reminders or completion."})
        deadline_at = attrs.get("deadline_at", getattr(self.instance, "deadline_at", None))
        deadline_date = attrs.get("deadline_date", getattr(self.instance, "deadline_date", None))
        if deadline_at is not None and deadline_date is not None:
            raise serializers.ValidationError("Use a date-only or a timed deadline, not both.")
        if attrs.get("reminder_anchor", getattr(self.instance, "reminder_anchor", "planned")) == "deadline" and deadline_at is None and deadline_date is None:
            raise serializers.ValidationError({"reminder_anchor": "Set a deadline or use the planned start for reminders."})
        repeat = attrs.get("recurrence", getattr(self.instance, "recurrence", "none"))
        weekdays = attrs.get("repeat_weekdays", getattr(self.instance, "repeat_weekdays", []))
        if repeat == "none":
            if attrs.get("repeat_interval", 1) != 1 or attrs.get("repeat_weekdays") or attrs.get("exceptions"):
                raise serializers.ValidationError("Recurrence rules require a repeating task.")
            attrs.update(repeat_interval=1, repeat_weekdays=[], exceptions=[])
        elif repeat != "weekly" and weekdays:
            if "repeat_weekdays" in attrs:
                raise serializers.ValidationError({"repeat_weekdays": "Selected weekdays require weekly repetition."})
            attrs["repeat_weekdays"] = []
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
    project_id = serializers.UUIDField(allow_null=True, required=False)
    capture_type = serializers.ChoiceField(choices=["task", "note"], required=False, default="task")
    text = serializers.CharField(min_length=3, max_length=4000, required=False)
    timezone = serializers.CharField(max_length=64, validators=[validate_timezone])
    reference_time = ZonedDateTimeField(required=False)
    audio = serializers.FileField(required=False)

    def validate(self, attrs):
        if bool(attrs.get("text")) == bool(attrs.get("audio")):
            raise serializers.ValidationError("Supply either text or one WAV recording.")
        return attrs
