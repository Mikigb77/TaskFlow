import 'package:agenda/models/meeting.dart';
import 'package:agenda/services/api_client.dart';

/// The server's answer to a piece: 200 `{"saved": true, "status": …}`.
class MeetingPieceAnswer {
  const MeetingPieceAnswer({required this.saved, required this.status});
  final bool saved;

  /// `recording`, `waiting` or `ready`.
  final String status;
}

/// The server's answer to `finish` or `GET`.
class MeetingAnswer {
  const MeetingAnswer({
    required this.status,
    this.result,
    this.missing = const [],
    this.received = const [],
  });

  /// `recording`, `waiting` or `ready`.
  final String status;
  final MeetingResult? result;

  /// The pieces the server still lacks (`waiting`).
  final List<int> missing;

  /// The pieces it has (`recording`).
  final List<int> received;

  bool get ready => status == 'ready' && result != null;

  static List<int> _numbers(Object? value) => value is List
      ? [
          for (final item in value)
            if (item is num) item.toInt(),
        ]
      : const [];

  factory MeetingAnswer.fromJson(Object? body) {
    if (body is! Map) {
      throw ApiException(502, 'The server returned an invalid response.');
    }
    final result = body['result'];
    return MeetingAnswer(
      status: body['status'] is String ? body['status'] as String : 'waiting',
      result: result is Map
          ? MeetingResult.fromJson(Map<String, dynamic>.from(result))
          : null,
      missing: _numbers(body['missing']),
      received: _numbers(body['received']),
    );
  }
}

/// The four calls of Backend/docs/MEETINGS.md. Every one is safe to
/// repeat. Failures are [ApiException]s: status 0 when the server can't be
/// reached, else the server's status and body.
abstract class MeetingApi {
  Future<MeetingPieceAnswer> uploadPiece(
    MeetingPiece piece, {
    required MeetingAudioFormat format,
    String? language,
  });

  Future<MeetingAnswer> finish(String meetingId, int lastIndex);

  /// Null when the server has no such meeting (404).
  Future<MeetingAnswer?> status(String meetingId);

  Future<void> delete(String meetingId);
}

/// [MeetingApi] through the app's [ApiClient], with its login and refresh,
/// for account [accountId] only: a call made after the account changed is
/// refused (MN-13).
class ApiMeetingApi implements MeetingApi {
  ApiMeetingApi(this.api, this.accountId);
  final ApiClient api;
  final int accountId;

  static String _seconds(Duration value) =>
      (value.inMilliseconds / 1000).toStringAsFixed(3);

  @override
  Future<MeetingPieceAnswer> uploadPiece(
    MeetingPiece piece, {
    required MeetingAudioFormat format,
    String? language,
  }) async {
    final body = await api.uploadMeetingPiece(
      meetingId: piece.meetingId,
      index: piece.index,
      filePath: piece.path,
      contentType: format.mimeType,
      filename: 'piece-${piece.index}.${format.extension}',
      fields: {
        'offset_seconds': _seconds(piece.offset),
        'duration_seconds': _seconds(piece.duration),
        if (language != null && language.isNotEmpty) 'language': language,
      },
      accountId: accountId,
    );
    return MeetingPieceAnswer(
      saved: body['saved'] == true,
      status: body['status'] is String ? body['status'] as String : 'recording',
    );
  }

  @override
  Future<MeetingAnswer> finish(String meetingId, int lastIndex) async =>
      MeetingAnswer.fromJson(
        await api.request(
          'POST',
          'meetings/$meetingId/finish/',
          data: {'last_index': lastIndex},
          accountId: accountId,
        ),
      );

  @override
  Future<MeetingAnswer?> status(String meetingId) async {
    try {
      return MeetingAnswer.fromJson(
        await api.request(
          'GET',
          'meetings/$meetingId/',
          accountId: accountId,
        ),
      );
    } on ApiException catch (error) {
      if (error.status == 404) return null;
      rethrow;
    }
  }

  @override
  Future<void> delete(String meetingId) async {
    await api.request(
      'DELETE',
      'meetings/$meetingId/',
      accountId: accountId,
    );
  }
}
