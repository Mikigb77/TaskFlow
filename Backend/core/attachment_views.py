import hashlib
import logging
import unicodedata
import uuid
from datetime import timedelta

from django.conf import settings
from django.core.files.uploadhandler import FileUploadHandler, StopUpload
from django.db import IntegrityError, transaction
from django.db.models import F, Q, Sum
from django.db.models.functions import Coalesce
from django.http import FileResponse
from django.utils import timezone
from rest_framework import mixins, serializers, viewsets
from rest_framework.decorators import action
from rest_framework.exceptions import NotFound, ValidationError
from rest_framework.parsers import JSONParser, MultiPartParser
from rest_framework.response import Response

from .models import Attachment, AttachmentUsage, Task, User
from .free_tier import month
from .list_access import visible_tasks, lock_task
from .billing import BillingUnavailable, has_pro

logger = logging.getLogger(__name__)


class BoundedUploadHandler(FileUploadHandler):
    """Reject oversized files while parsing, before temporary storage can grow."""
    def new_file(self, *args, **kwargs):
        super().new_file(*args, **kwargs)
        self.received = 0

    def receive_data_chunk(self, raw_data, start):
        self.received += len(raw_data)
        if self.received > settings.ATTACHMENT_MAX_BYTES:
            raise StopUpload(connection_reset=True)
        return raw_data

    def file_complete(self, file_size):
        return None


class AttachmentSerializer(serializers.ModelSerializer):
    task_id = serializers.UUIDField(read_only=True)
    is_deleted = serializers.SerializerMethodField()

    def get_is_deleted(self, value):
        return value.is_deleted or value.task.is_deleted

    class Meta:
        model = Attachment
        fields = ["id", "task_id", "name", "size", "sha256", "is_deleted", "created_at", "updated_at"]
        read_only_fields = fields


class AttachmentUploadSerializer(serializers.Serializer):
    task_id = serializers.UUIDField()
    name = serializers.CharField(max_length=180)
    file = serializers.FileField(allow_empty_file=False)

    def validate_name(self, value):
        value = unicodedata.normalize("NFC", value).strip()
        if not value or value in (".", "..") or any(c in value for c in ("/", "\\")) or any(unicodedata.category(c).startswith("C") for c in value):
            raise serializers.ValidationError("Use a filename without paths or control characters.")
        return value

    def validate_file(self, value):
        if value.size > settings.ATTACHMENT_MAX_BYTES:
            raise serializers.ValidationError("Attachments can be at most 6 MiB each.")
        return value


def _remove_blob(file):
    try:
        file.storage.delete(file.name)
    except OSError:
        # The tombstone still revokes download access. Retrying DELETE attempts
        # cleanup again; storage names stay in the row until physical removal.
        logger.warning("Attachment storage cleanup will need a retry.")


def delete_task_attachments(task):
    """Called inside the task transaction, including offline tombstone uploads."""
    rows = list(task.attachments.filter(is_deleted=False))
    if not rows:
        return
    task.attachments.filter(pk__in=[row.pk for row in rows]).update(is_deleted=True, updated_at=timezone.now())
    for row in rows:
        transaction.on_commit(lambda file=row.file: _remove_blob(file))


def quota_files(user_id):
    # A list's owner controls its files, even when the uploader has left.
    # This also avoids charging a former member for files they cannot remove.
    return Attachment.objects.filter(
        Q(task__task_list__owner_id=user_id) | Q(task__task_list__isnull=True, owner_id=user_id),
        is_deleted=False, task__is_deleted=False)


def quota_owner_id(task):
    return task.task_list.owner_id if task.task_list_id else task.owner_id


def uploaded(user_id, now=None):
    """(bytes ever uploaded, bytes uploaded this UTC month, when the month resets).
    Removed and cleaned-up files still count: AttachmentUsage is never lowered."""
    period, resets_at = month(now or timezone.now())
    rows = AttachmentUsage.objects.filter(user_id=user_id)
    total = rows.aggregate(total=Sum("bytes"))["total"] or 0
    this_month = rows.filter(period=period).values_list("bytes", flat=True).first() or 0
    return total, this_month, resets_at


def storage_usage(user):
    # Both allowances and never a billing call; the app knows whether the account has Pro.
    total, this_month, resets_at = uploaded(user.pk)
    return {"used_bytes": total, "limit_bytes": settings.FREE_ATTACHMENT_BYTES,
            "month_used_bytes": this_month, "month_limit_bytes": settings.PRO_ATTACHMENT_BYTES_PER_MONTH,
            "resets_at": resets_at.isoformat().replace("+00:00", "Z")}


def files_allowed(file_count):
    return file_count <= 1000  # A technical bound for every tier.


class StorageFull(Exception):
    """Raised inside the upload transaction and answered outside it."""
    def __init__(self, limit):
        super().__init__(limit)
        self.limit = limit  # "lifetime" without Pro, "month" with it, "files" at the file bound


def check_upload(owner_id, size):
    """Raises StorageFull when the quota owner can't upload `size` more bytes. Within the
    free allowance nobody is over Pro's either, so billing is asked only above it. When Pro
    ends, files stay readable and removable; only uploads over the free allowance are refused."""
    if not files_allowed(quota_files(owner_id).count() + 1):
        raise StorageFull("files")
    total, this_month, _ = uploaded(owner_id)
    if total + size <= settings.FREE_ATTACHMENT_BYTES:
        return
    pro = has_pro(User.objects.get(pk=owner_id))
    if pro is None:
        raise BillingUnavailable()  # 503: the app retries later.
    if not pro:
        raise StorageFull("lifetime")
    if this_month + size > settings.PRO_ATTACHMENT_BYTES_PER_MONTH:
        raise StorageFull("month")


def charge_upload(owner_id, size):
    """Adds an upload to its owner's usage, inside the upload's transaction and lock."""
    period, _ = month(timezone.now())
    usage, _ = AttachmentUsage.objects.get_or_create(user_id=owner_id, period=period)
    AttachmentUsage.objects.filter(pk=usage.pk).update(bytes=F("bytes") + size)


def check_list_transfer(task, destination):
    # A move uploads nothing, so it charges nobody's allowance: its bytes were counted
    # when they were uploaded. Only the file bound applies.
    if task is None or (destination.pk if destination else None) == task.task_list_id:
        return
    owner_id = destination.owner_id if destination else task.owner_id
    list(User.objects.select_for_update().filter(pk__in={owner_id, task.owner_id}).order_by('pk'))
    moving = task.attachments.filter(is_deleted=False).count()
    if not files_allowed(moving + quota_files(owner_id).exclude(task=task).count()):
        raise ValidationError({'list_id': 'This destination already holds as many files as it can. Remove a backed-up file before moving the task.'})


def sweep(now=None):
    """Delete the files of tasks completed over ATTACHMENT_RETENTION_DAYS ago, for every account,
    from storage. A file added after its task was completed gets the same days from when it was
    added. Completions from before the server kept times count from the task's last change.
    Usage stays counted. Run daily by maintain_staging; returns how many files went."""
    cutoff = (now or timezone.now()) - timedelta(days=settings.ATTACHMENT_RETENTION_DAYS)
    expired = Attachment.objects.annotate(done_at=Coalesce("task__completed_at", "task__updated_at")).filter(
        is_deleted=False, task__is_completed=True, done_at__lte=cutoff, created_at__lte=cutoff)
    removed = 0
    while ids := list(expired.values_list("pk", flat=True)[:200]):
        with transaction.atomic():
            # Checked again under the lock: a task reopened meanwhile keeps its files.
            rows = list(expired.filter(pk__in=ids).select_for_update(of=("self",)))
            Attachment.objects.filter(pk__in=[row.pk for row in rows]).update(is_deleted=True, updated_at=timezone.now())
            for row in rows:
                transaction.on_commit(lambda file=row.file: _remove_blob(file))
        if not rows:
            break  # Reopened meanwhile; nothing else matched.
        removed += len(rows)
    return removed


class AttachmentViewSet(mixins.ListModelMixin, mixins.RetrieveModelMixin, viewsets.GenericViewSet):
    serializer_class = AttachmentSerializer
    parser_classes = [MultiPartParser, JSONParser]
    throttle_scope = "attachments"
    lookup_value_regex = "[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}"

    def get_queryset(self):
        rows = Attachment.objects.filter(task__in=visible_tasks(self.request.user)).select_related("task")
        if self.action != "list" or self.request.query_params.get("include_deleted") != "true":
            rows = rows.filter(is_deleted=False, task__is_deleted=False)
        task_id = self.request.query_params.get("task_id")
        if task_id is not None:
            try:
                rows = rows.filter(task_id=uuid.UUID(task_id))
            except ValueError:
                raise ValidationError({"task_id": "Use a valid task identifier."})
        return rows

    def update(self, request, pk=None):
        # One immutable object per client UUID. A dropped response can be retried
        # safely without an extra object or a new task conflict/version.
        serializer = AttachmentUploadSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        data = serializer.validated_data
        upload = data["file"]
        digest = hashlib.sha256()
        for chunk in upload.chunks():
            digest.update(chunk)
        checksum = digest.hexdigest()
        upload.seek(0)
        stored = None
        try:
            with transaction.atomic():
                # Serialize quota checks and uploads across this account.
                task, _ = lock_task(data["task_id"], request.user)
                if task is None or task.is_deleted:
                    raise NotFound()
                quota_owner = quota_owner_id(task)
                list(User.objects.select_for_update().filter(pk__in={quota_owner, request.user.pk}).order_by('pk'))
                existing = Attachment.objects.select_for_update().filter(pk=pk).first()
                if existing is not None:
                    if existing.owner_id != request.user.pk:
                        raise NotFound()
                    if existing.is_deleted:
                        return Response({"detail": "This attachment was removed. Choose it again to upload a new copy."}, status=409)
                    if (existing.task_id, existing.name, existing.sha256, existing.size) != (task.pk, data["name"], checksum, upload.size):
                        return Response({"detail": "This attachment identifier already contains different data."}, status=409)
                    if not existing.file.storage.exists(existing.file.name):
                        # A retained local file can repair missing storage, but
                        # only with the exact original bytes/name/task identity.
                        existing.file.save("upload.blob", upload, save=False)
                        stored = existing.file
                        existing.save(update_fields=["file", "updated_at"])
                    return Response(self.get_serializer(existing).data)
                if Attachment.objects.filter(task=task, is_deleted=False).count() >= 20:
                    raise ValidationError({"file": "Use at most 20 backed-up attachments per task."})
                check_upload(quota_owner, upload.size)
                item = Attachment(id=pk, owner=request.user, task=task, name=data["name"], size=upload.size, sha256=checksum)
                item.file.save("upload.blob", upload, save=False)
                stored = item.file
                item.save(force_insert=True)
                charge_upload(quota_owner, upload.size)
            return Response(self.get_serializer(item).data, status=201)
        except StorageFull as full:
            # Numbers only for the user's own allowance: a member can't change the owner's.
            detail = {"lifetime": "The account or project owner has used all the file uploads included without Pro.",
                      "month": "The account or project owner has used this month's file uploads. More are available next month.",
                      "files": "The account or project owner holds as many files as it can. Remove a backed-up file first."}
            body = {"code": "storage_full", "shared": quota_owner != request.user.pk, "limit": full.limit,
                    "detail": detail[full.limit]}
            if not body["shared"]:
                body["storage"] = storage_usage(request.user)
            return Response(body, status=400)
        except IntegrityError:
            if stored is not None:
                _remove_blob(stored)
            # A UUID concurrently claimed by another account never grants access.
            raise NotFound()
        except Exception:
            if stored is not None:
                _remove_blob(stored)
            raise

    @action(detail=True, methods=["get"])
    def content(self, request, pk=None):
        item = self.get_object()
        try:
            file = item.file.open("rb")
        except OSError:
            return Response({"detail": "This file is temporarily unavailable. Please retry later."}, status=503)
        response = FileResponse(file, as_attachment=True, filename=item.name, content_type="application/octet-stream")
        response["Cache-Control"] = "private, no-store"
        response["X-Content-Type-Options"] = "nosniff"
        response["ETag"] = f'"{item.sha256}"'
        return response

    def destroy(self, request, pk=None):
        with transaction.atomic():
            item = Attachment.objects.filter(pk=pk).first()
            if item is None:
                raise NotFound()
            lock_task(item.task_id, request.user)
            item = Attachment.objects.select_for_update().get(pk=pk)
            if not item.is_deleted:
                item.is_deleted = True
                item.save(update_fields=["is_deleted", "updated_at"])
            transaction.on_commit(lambda: _remove_blob(item.file))
        return Response(status=204)
