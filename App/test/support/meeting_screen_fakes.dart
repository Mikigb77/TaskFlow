// The meeting core as the screens see it, scripted by the test: no
// database, microphone, server or WorkManager.
import 'dart:async';

import 'package:agenda/models/meeting.dart';
import 'package:agenda/services/meeting_controller.dart';
import 'package:agenda/services/meeting_recorder.dart';
import 'package:agenda/services/meeting_store.dart';
import 'package:agenda/services/task_database.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'meeting_fakes.dart';

/// Recovery on start finds nothing; the controller below keeps the rest.
class _QuietStore extends MeetingStore {
  _QuietStore() : super(TaskDatabase());
  @override
  Future<List<Meeting>> recoverInterrupted(
    String ownerKey, {
    String? active,
  }) async => const [];
  @override
  Future<List<Meeting>> autoFinishStale(String ownerKey, DateTime now) async =>
      const [];
  @override
  Future<void> clean(String ownerKey, DateTime now) async {}
  @override
  Future<void> markAsked(String ownerKey, DateTime now) async {}
}

const meetingOwner = 'https://api.example.invalid/users/1';

/// A meeting as the store would give it.
Meeting fakeMeeting(
  String id, {
  MeetingPhase phase = MeetingPhase.finishing,
  Duration recorded = const Duration(minutes: 42, seconds: 10),
  String? problem,
  int? noteId,
  String? title,
}) => Meeting(
  id: id,
  ownerKey: meetingOwner,
  phase: phase,
  startedAt: DateTime.utc(2026, 11, 3, 9),
  format: MeetingAudioFormat.opus,
  recorded: recorded,
  nextIndex: 9,
  problem: problem,
  noteId: noteId,
  title: title,
);

/// What the screens asked of the meeting core.
class MeetingCalls {
  final started = <MeetingNotice>[];
  final languages = <String?>[];
  final projects = <String?>[];
  final continued = <String>[];
  final finished = <String>[];
  final discarded = <String>[];
  final seen = <String>[];
  int stops = 0;
  int discardedRecordings = 0;
  int uploads = 0;
  int discardedAll = 0;

  /// What was asked, in order: `discardAll`, `upload`, and what the test
  /// adds (such as `signOut`).
  final order = <String>[];
}

/// [MeetingController] whose state the test sets, and whose actions it
/// records and answers.
class ScriptedMeetings extends MeetingController {
  ScriptedMeetings({
    this.initial = const MeetingsState(loaded: true),
    this.refuse,
    this.silent = false,
    this.uploaded = true,
    this.loading,
    super.freeBytes,
  }) : super(
         store: _QuietStore(),
         engine: FakeMeetingAudio(),
         ownerKey: meetingOwner,
         scheduler: FakeMeetingScheduler(),
       );

  /// What recovery on start finds.
  final MeetingsState initial;
  final calls = MeetingCalls();

  /// Start answers this refusal.
  MeetingStartProblem? refuse;

  /// Stop heard only silence.
  bool silent;

  /// Upload first reaches the server.
  bool uploaded;

  /// The first read of the meetings waits for this, as right after launch.
  final Completer<void>? loading;

  /// Discarding the recording waits for this, once the recording is gone.
  Completer<void>? discardGate;

  /// Moves the screens on, as the core would.
  void emit(MeetingsState next) => state = next;

  MeetingRecordingStatus recordingStatus(
    String id, {
    Duration elapsed = const Duration(minutes: 12, seconds: 3),
    double level = 0.6,
  }) => MeetingRecordingStatus(meetingId: id, elapsed: elapsed, level: level);

  @override
  Future<void> refresh() async {
    await loading?.future;
    if (mounted && !state.loaded) state = initial;
  }

  @override
  Future<Meeting> start({
    required MeetingNotice notice,
    String? language,
    String? projectId,
  }) async {
    if (refuse != null) throw MeetingStartRefused(refuse!);
    calls.started.add(notice);
    calls.languages.add(language);
    calls.projects.add(projectId);
    const id = 'meeting-1';
    state = state.copyWith(recording: recordingStatus(id));
    return fakeMeeting(id, phase: MeetingPhase.recording);
  }

  @override
  Future<Meeting> continueMeeting(
    String id, {
    required MeetingNotice notice,
  }) async {
    if (refuse != null) throw MeetingStartRefused(refuse!);
    calls.continued.add(id);
    state = state.copyWith(
      recording: recordingStatus(id),
      stopped: [
        for (final meeting in state.stopped)
          if (meeting.id != id) meeting,
      ],
    );
    return fakeMeeting(id, phase: MeetingPhase.recording);
  }

  @override
  Future<Meeting?> stop() async {
    calls.stops++;
    final id = state.recording?.meetingId;
    state = state.copyWith(clearRecording: true);
    if (silent || id == null) return null;
    final meeting = fakeMeeting(id);
    state = state.copyWith(waiting: [...state.waiting, meeting]);
    return meeting;
  }

  @override
  Future<void> discardRecording() async {
    calls.discardedRecordings++;
    state = state.copyWith(clearRecording: true);
    await discardGate?.future;
  }

  @override
  Future<Meeting?> finishMeeting(String id) async {
    calls.finished.add(id);
    final meeting = state.stopped.where((m) => m.id == id).firstOrNull;
    if (meeting == null) return null;
    final finishing = fakeMeeting(id, recorded: meeting.recorded);
    state = state.copyWith(
      stopped: [
        for (final m in state.stopped)
          if (m.id != id) m,
      ],
      waiting: [...state.waiting, finishing],
    );
    return finishing;
  }

  @override
  Future<void> discardMeeting(String id) async {
    calls.discarded.add(id);
    state = state.copyWith(
      stopped: [
        for (final m in state.stopped)
          if (m.id != id) m,
      ],
      waiting: [
        for (final m in state.waiting)
          if (m.id != id) m,
      ],
    );
  }

  @override
  Future<void> markSeen(String id) async {
    calls.seen.add(id);
    state = state.copyWith(
      ready: [
        for (final m in state.ready)
          if (m.id != id) m,
      ],
    );
  }

  @override
  Future<MeetingBacklog> backlog() async => MeetingBacklog(
    meetings:
        (state.recording == null ? 0 : 1) +
        state.stopped.length +
        state.waiting.length,
  );

  @override
  Future<bool> uploadNow() async {
    calls.uploads++;
    calls.order.add('upload');
    if (!uploaded) return false;
    state = state.copyWith(stopped: const [], waiting: const []);
    return true;
  }

  @override
  Future<void> discardAll() async {
    calls.discardedAll++;
    calls.order.add('discardAll');
    state = state.copyWith(
      clearRecording: true,
      stopped: const [],
      waiting: const [],
    );
  }

  /// The notes of [id] are saved as note [noteId], and wait to be shown.
  void notesSaved(String id, int noteId, {String title = 'Pilot pricing'}) {
    state = state.copyWith(
      waiting: [
        for (final m in state.waiting)
          if (m.id != id) m,
      ],
      ready: [
        ...state.ready,
        fakeMeeting(
          id,
          phase: MeetingPhase.saved,
          noteId: noteId,
          title: title,
        ),
      ],
    );
  }
}

/// The override that puts [meetings] behind the screens.
Override meetingsOverride(ScriptedMeetings meetings) =>
    meetingControllerProvider.overrideWith((ref) => meetings);

/// Lets the scripted futures finish.
Future<void> settleMeetings() => Future<void>.delayed(Duration.zero);
