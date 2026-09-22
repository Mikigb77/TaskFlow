import hashlib
import logging
import unicodedata
import uuid

from django.conf import settings
from django.core.files.uploadhandler import FileUploadHandler, StopUpload
from django.db import IntegrityError, transaction
from django.db.models import Sum
from django.http import FileResponse
from django.utils import timezone
from rest_framework import mixins, serializers, viewsets
from rest_framework.decorators import action
from rest_framework.exceptions import NotFound, ValidationError
from rest_framework.parsers import JSONParser, MultiPartParser
from rest_framework.response import Response

from .models import Attachment, Task, User

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


class AttachmentViewSet(mixins.ListModelMixin, mixins.RetrieveModelMixin, viewsets.GenericViewSet):
    serializer_class = AttachmentSerializer
    parser_classes = [MultiPartParser, JSONParser]
    throttle_scope = "attachments"
    lookup_value_regex = "[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}"

    def get_queryset(self):
        rows = Attachment.objects.filter(owner=self.request.user).select_related("task")
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
                User.objects.select_for_update().get(pk=request.user.pk)
                task = Task.objects.select_for_update().filter(pk=data["task_id"], owner=request.user, is_deleted=False).first()
                if task is None:
                    raise NotFound()
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
                rows = Attachment.objects.filter(owner=request.user, is_deleted=False, task__is_deleted=False)
                used = rows.aggregate(total=Sum("size"))["total"] or 0
                if used + upload.size > settings.ATTACHMENT_ACCOUNT_BYTES or rows.count() >= 1000:
                    raise ValidationError({"file": "Your account attachment storage is full. Remove a backed-up file before uploading another."})
                if rows.filter(task=task).count() >= 20:
                    raise ValidationError({"file": "Use at most 20 backed-up attachments per task."})
                item = Attachment(id=pk, owner=request.user, task=task, name=data["name"], size=upload.size, sha256=checksum)
                item.file.save("upload.blob", upload, save=False)
                stored = item.file
                item.save(force_insert=True)
            return Response(self.get_serializer(item).data, status=201)
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
            User.objects.select_for_update().get(pk=request.user.pk)
            item = Attachment.objects.select_for_update().filter(pk=pk, owner=request.user).first()
            if item is None:
                raise NotFound()
            if not item.is_deleted:
                item.is_deleted = True
                item.save(update_fields=["is_deleted", "updated_at"])
            transaction.on_commit(lambda: _remove_blob(item.file))
        return Response(status=204)
