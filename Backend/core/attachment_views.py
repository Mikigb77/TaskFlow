import hashlib
import logging
import unicodedata
import uuid

from django.conf import settings
from django.core.files.uploadhandler import FileUploadHandler, StopUpload
from django.db import IntegrityError, transaction
from django.db.models import Sum, Q
from django.http import FileResponse
from django.utils import timezone
from rest_framework import mixins, serializers, viewsets
from rest_framework.decorators import action
from rest_framework.exceptions import NotFound, ValidationError
from rest_framework.parsers import JSONParser, MultiPartParser
from rest_framework.response import Response

from .models import Attachment, Task, User
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


def storage_usage(user):
    used = quota_files(user.pk).aggregate(total=Sum("size"))["total"] or 0
    return {"used_bytes": used, "limit_bytes": settings.FREE_ATTACHMENT_BYTES}


def storage_allows(owner_id, total_bytes, file_count):
    # The cap follows the quota owner. When Pro ends, files stay readable and
    # removable; only additions above the free cap are refused.
    if file_count > 1000:
        return False  # A technical bound for every tier.
    if total_bytes <= settings.FREE_ATTACHMENT_BYTES:
        return True
    pro = has_pro(User.objects.get(pk=owner_id))  # Billing is asked only above the free cap.
    if pro is None:
        raise BillingUnavailable()  # 503: the app retries later.
    return pro


class StorageFull(Exception):
    """Raised inside the upload transaction and answered outside it."""


def check_list_transfer(task, destination):
    if task is None or (destination.pk if destination else None) == task.task_list_id:
        return
    owner_id = destination.owner_id if destination else task.owner_id
    list(User.objects.select_for_update().filter(pk__in={owner_id, task.owner_id}).order_by('pk'))
    moving = task.attachments.filter(is_deleted=False)
    existing = quota_files(owner_id).exclude(task=task)
    size = (moving.aggregate(total=Sum('size'))['total'] or 0) + (existing.aggregate(total=Sum('size'))['total'] or 0)
    if not storage_allows(owner_id, size, moving.count() + existing.count()):
        raise ValidationError({'list_id': 'This destination does not have enough file storage. Remove a backed-up file before moving the task.'})


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
                quota_owner = task.task_list.owner_id if task.task_list_id else task.owner_id
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
                rows = quota_files(quota_owner)
                used = rows.aggregate(total=Sum("size"))["total"] or 0
                if not storage_allows(quota_owner, used + upload.size, rows.count() + 1):
                    raise StorageFull()
                if Attachment.objects.filter(task=task, is_deleted=False).count() >= 20:
                    raise ValidationError({"file": "Use at most 20 backed-up attachments per task."})
                item = Attachment(id=pk, owner=request.user, task=task, name=data["name"], size=upload.size, sha256=checksum)
                item.file.save("upload.blob", upload, save=False)
                stored = item.file
                item.save(force_insert=True)
            return Response(self.get_serializer(item).data, status=201)
        except StorageFull:
            # Numbers only for the user's own storage: a member can't free the owner's space.
            body = {"code": "storage_full", "shared": quota_owner != request.user.pk,
                    "detail": "The account or list owner's file storage is full. Remove a backed-up file before uploading another."}
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
