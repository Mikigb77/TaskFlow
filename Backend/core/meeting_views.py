"""The meeting endpoints of docs/MEETINGS.md. The flow itself is in core/meetings.py."""
import io
import math

from django.conf import settings
from django.core.files.uploadedfile import InMemoryUploadedFile
from django.core.files.uploadhandler import FileUploadHandler, StopUpload
from rest_framework import serializers
from rest_framework.parsers import JSONParser, MultiPartParser
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from . import ai, meetings
from .billing import BillingUnavailable, has_pro

# Room for the form's other fields and the multipart boundaries around the audio.
FORM_OVERHEAD_BYTES = 64 * 1024


class MeetingAudioUploadHandler(FileUploadHandler):
    """Keep the piece in memory, never in a temporary file (MN-15), and stop past the size limit."""

    def new_file(self, *args, **kwargs):
        super().new_file(*args, **kwargs)
        self.buffer = io.BytesIO()

    def receive_data_chunk(self, raw_data, start):
        if self.buffer.tell() + len(raw_data) > settings.MEETING_PIECE_MAX_BYTES:
            raise StopUpload(connection_reset=True)
        self.buffer.write(raw_data)
        return None

    def file_complete(self, file_size):
        self.buffer.seek(0)
        return InMemoryUploadedFile(file=self.buffer, field_name=self.field_name, name=self.file_name,
                                    content_type=self.content_type, size=file_size, charset=self.charset,
                                    content_type_extra=self.content_type_extra)


def _finite(value):
    if not math.isfinite(value):
        raise serializers.ValidationError("Use a finite number.")
    return value


class PieceSerializer(serializers.Serializer):
    audio = serializers.FileField(allow_empty_file=False)
    offset_seconds = serializers.FloatField(min_value=0, max_value=10_000_000)
    duration_seconds = serializers.FloatField(min_value=0, max_value=600)
    language = serializers.CharField(required=False, allow_blank=True, max_length=64)

    def validate_audio(self, value):
        if value.size > settings.MEETING_PIECE_MAX_BYTES:
            raise serializers.ValidationError("A piece can be at most 8 MB.")
        if (value.content_type or "").split(";")[0].strip().lower() not in meetings.AUDIO_TYPES:
            raise serializers.ValidationError("Send Ogg, Opus, AAC, MP4, M4A, WAV or WebM audio.")
        return value

    def validate_offset_seconds(self, value):
        return _finite(value)

    def validate_duration_seconds(self, value):
        return _finite(value)

    def validate_language(self, value):
        return meetings.language_hint(value)


class FinishSerializer(serializers.Serializer):
    last_index = serializers.IntegerField(min_value=0, max_value=meetings.MAX_INDEX)


def _pro_refusal(user):
    """Every meeting endpoint but DELETE needs Pro. None when the person has it."""
    pro = has_pro(user)
    if pro is None:
        raise BillingUnavailable()  # Never tell a paying customer that this needs Pro.
    if not pro:
        return Response({"code": "pro_required"}, status=402)
    return None


class MeetingView(APIView):
    permission_classes = [IsAuthenticated]
    throttle_scope = "meetings"
    parser_classes = [JSONParser]

    def get(self, request, meeting_id):
        refusal = _pro_refusal(request.user)
        if refusal:
            return refusal
        try:
            return Response(meetings.meeting_status(request.user, meeting_id))
        except ai.AIUnavailable as error:
            return Response({"detail": str(error)}, status=error.status)

    def delete(self, request, meeting_id):
        # Login and ownership only: a discard or an acknowledgement deletes at once, also after Pro
        # lapsed or while RevenueCat is down (MN-24, MN-25).
        meetings.discard(request.user, meeting_id)
        return Response(status=204)


class MeetingFinishView(APIView):
    permission_classes = [IsAuthenticated]
    throttle_scope = "meetings"
    parser_classes = [JSONParser]

    def post(self, request, meeting_id):
        refusal = _pro_refusal(request.user)
        if refusal:
            return refusal
        serializer = FinishSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        try:
            status, body = meetings.finish(request.user, meeting_id, serializer.validated_data["last_index"])
        except ai.AIUnavailable as error:
            return Response({"detail": str(error)}, status=error.status)
        return Response(body, status=status)


class MeetingPieceView(APIView):
    permission_classes = [IsAuthenticated]
    throttle_scope = "meetings"
    parser_classes = [MultiPartParser]

    def put(self, request, meeting_id, index):
        # Before the body is read: the piece stays in memory, and an oversized one is refused unread.
        request._request.upload_handlers = [MeetingAudioUploadHandler(request._request)]
        try:
            length = int(request.META.get("CONTENT_LENGTH") or 0)
        except ValueError:
            length = 0
        if length > settings.MEETING_PIECE_MAX_BYTES + FORM_OVERHEAD_BYTES:
            return Response({"audio": ["A piece can be at most 8 MB."]}, status=400)
        refusal = _pro_refusal(request.user)
        if refusal:
            return refusal
        if index > meetings.MAX_INDEX:
            return Response({"index": [f"Use a piece number up to {meetings.MAX_INDEX}."]}, status=400)
        serializer = PieceSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        data = serializer.validated_data
        audio = data.pop("audio")
        mime_type = audio.content_type.split(";")[0].strip().lower()
        try:
            meeting = meetings.receive_piece(
                request.user, meeting_id, index, audio.read(), mime_type,
                data["offset_seconds"], data["duration_seconds"], data.get("language", ""))
        except meetings.MeetingFinished:
            return Response({"code": "meeting_finished"}, status=409)
        except meetings.AllowanceUsed:
            return Response({"code": "meeting_allowance_used"}, status=402)
        except ai.AIUnavailable as error:
            return Response({"detail": str(error)}, status=error.status)
        finally:
            audio.close()
        return Response({"meeting_id": str(meeting_id), "index": index, "saved": True,
                         "status": meetings.status_of(meeting)})
