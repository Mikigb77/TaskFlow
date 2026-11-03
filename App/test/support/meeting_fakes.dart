import 'dart:async';
import 'dart:io';
import 'package:agenda/models/meeting.dart';
import 'package:agenda/services/api_client.dart';
import 'package:agenda/services/meeting_api.dart';
import 'package:agenda/services/meeting_background.dart';
import 'package:agenda/services/meeting_recorder.dart';

/// A clock the test moves.
class FakeClock {
  FakeClock([DateTime? start]) : now = start ?? DateTime.utc(2026, 11, 3, 10);
  DateTime now;
  DateTime call() => now;
  void advance(Duration by) => now = now.add(by);
}

/// A timer the test fires itself.
class FakeTimer implements Timer {
  FakeTimer(this.after, this.then);
  final Duration after;
  final void Function() then;
  bool _active = true;

  /// Runs it now, as the real one would once [after] passed; nothing once
  /// cancelled or fired.
  void fire() {
    if (!_active) return;
    _active = false;
    then();
  }

  @override
  void cancel() => _active = false;

  @override
  bool get isActive => _active;

  @override
  int get tick => _active ? 0 : 1;
}

/// A microphone that writes a little audio to each file it's given, and
/// hears what the test says.
class FakeMeetingAudio implements MeetingAudioEngine {
  FakeMeetingAudio({
    this.permitted = true,
    this.supported = MeetingAudioFormat.opus,
  });
  bool permitted;
  MeetingAudioFormat supported;
  final files = <String>[];
  final notices = <MeetingNotice>[];
  bool running = false;
  int stops = 0;
  var _levels = StreamController<double>.broadcast();

  @override
  Future<bool> hasPermission() async => permitted;

  @override
  Future<MeetingAudioFormat> format() async => supported;

  void _write(String path) {
    files.add(path);
    File(path)
      ..createSync(recursive: true)
      ..writeAsBytesSync(List.filled(4096, 7));
  }

  @override
  Future<void> start(
    String path,
    MeetingAudioFormat format,
    MeetingNotice notice,
  ) async {
    notices.add(notice);
    running = true;
    _write(path);
  }

  @override
  Future<void> next(String path) async {
    if (!running) throw StateError('Not recording.');
    _write(path);
  }

  @override
  Future<void> stop() async {
    running = false;
    stops++;
  }

  @override
  Stream<double> get levels => _levels.stream;

  void hear(double db) => _levels.add(db);

  void fail() => _levels.addError(StateError('The microphone went away.'));

  /// A new process: nothing listens to the old levels.
  void reset() {
    _levels = StreamController<double>.broadcast();
    running = false;
  }
}

/// One call the fake server received.
class MeetingCall {
  MeetingCall(this.kind, this.meetingId, {this.index, this.lastIndex});
  final String kind;
  final String meetingId;
  final int? index;
  final int? lastIndex;
  @override
  String toString() => '$kind $meetingId ${index ?? lastIndex ?? ''}';
}

typedef PieceHandler = Future<MeetingPieceAnswer> Function(MeetingPiece piece);

/// The server of Backend/docs/MEETINGS.md, as the test programs it.
class FakeMeetingApi implements MeetingApi {
  final calls = <MeetingCall>[];
  final received = <String, Set<int>>{};

  /// Answers to pieces; by default, saved.
  PieceHandler? onPiece;

  /// Answers to `finish`; by default, ready once every piece is in.
  Future<MeetingAnswer> Function(String id, int lastIndex)? onFinish;
  Future<void> Function(String id)? onDelete;

  int inFlight = 0;
  int maxInFlight = 0;

  MeetingResult result = const MeetingResult(
    title: 'Pilot pricing with Acme',
    summary: 'We agreed the pilot. Pricing comes next.',
    todos: [
      MeetingTodo(text: 'Send the pilot quote', who: 'Miki', when: 'Friday'),
      MeetingTodo(text: 'Book the room'),
    ],
    decisions: ['Start the pilot in December'],
    openQuestions: ['Who signs for Acme?'],
    chapters: [
      MeetingChapter(
        startMinute: 0,
        endMinute: 30,
        title: 'Introductions and scope',
        notes: 'Scope is the warehouse.',
      ),
    ],
    language: 'en',
  );

  @override
  Future<MeetingPieceAnswer> uploadPiece(
    MeetingPiece piece, {
    required MeetingAudioFormat format,
    String? language,
  }) async {
    calls.add(MeetingCall('piece', piece.meetingId, index: piece.index));
    inFlight++;
    if (inFlight > maxInFlight) maxInFlight = inFlight;
    try {
      final answer = onPiece == null
          ? const MeetingPieceAnswer(saved: true, status: 'recording')
          : await onPiece!(piece);
      if (answer.saved) {
        (received[piece.meetingId] ??= {}).add(piece.index);
      }
      return answer;
    } finally {
      inFlight--;
    }
  }

  @override
  Future<MeetingAnswer> finish(String meetingId, int lastIndex) async {
    calls.add(MeetingCall('finish', meetingId, lastIndex: lastIndex));
    if (onFinish != null) return onFinish!(meetingId, lastIndex);
    final have = received[meetingId] ?? {};
    final missing = [
      for (var i = 0; i <= lastIndex; i++)
        if (!have.contains(i)) i,
    ];
    return missing.isEmpty
        ? MeetingAnswer(status: 'ready', result: result)
        : MeetingAnswer(status: 'waiting', missing: missing);
  }

  @override
  Future<MeetingAnswer?> status(String meetingId) async {
    calls.add(MeetingCall('get', meetingId));
    return null;
  }

  @override
  Future<void> delete(String meetingId) async {
    calls.add(MeetingCall('delete', meetingId));
    if (onDelete != null) await onDelete!(meetingId);
  }

  List<String> kinds() => [for (final call in calls) call.kind];
}

ApiException offline() => ApiException(0, ApiClient.offlineMessage);

class FakeMeetingScheduler implements MeetingScheduler {
  int scheduled = 0;
  @override
  Future<void> schedule() async => scheduled++;
}
