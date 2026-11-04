import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:agenda/models/meeting.dart';
import 'package:agenda/providers/auth_provider.dart';
import 'package:agenda/providers/task_provider.dart';
import 'package:agenda/services/capture_store.dart';
import 'package:agenda/services/meeting_api.dart';
import 'package:agenda/services/meeting_audio.dart';
import 'package:agenda/services/meeting_background.dart';
import 'package:agenda/services/meeting_note.dart';
import 'package:agenda/services/meeting_recorder.dart';
import 'package:agenda/services/meeting_store.dart';
import 'package:agenda/services/meeting_uploader.dart';
import 'package:agenda/services/native_speech.dart';
import 'package:agenda/services/task_database.dart';

/// What the meeting screens show.
class MeetingsState {
  const MeetingsState({
    this.recording,
    this.stopped = const [],
    this.waiting = const [],
    this.ready = const [],
    this.loaded = false,
    this.recordingProblem,
    this.allowanceUsed = false,
  });

  /// The meeting being recorded now: elapsed time and level (MN-7).
  final MeetingRecordingStatus? recording;

  /// Recordings that stopped without Stop (MN-12): «Your recording stopped
  /// at 1:42. Continue, finish or discard?» ([Meeting.recorded]).
  final List<Meeting> stopped;

  /// Stopped meetings waiting for their notes (MN-11), «Waiting for
  /// signal» when [Meeting.waitingForSignal].
  final List<Meeting> waiting;

  /// Notes saved and not yet shown: [Meeting.noteId] opens the note.
  final List<Meeting> ready;

  /// Whether the meetings on this phone have been read once.
  final bool loaded;

  /// Why the server holds back the meeting being recorded now, once it
  /// refused a piece: [MeetingProblem.proRequired] or
  /// [MeetingProblem.allowanceUsed]. Recording goes on.
  final String? recordingProblem;

  /// A meeting on this phone was refused for this month's meeting time
  /// during this calendar month: a new one's notes wait for the next.
  final bool allowanceUsed;

  MeetingsState copyWith({
    MeetingRecordingStatus? recording,
    bool clearRecording = false,
    List<Meeting>? stopped,
    List<Meeting>? waiting,
    List<Meeting>? ready,
    bool? loaded,
    String? recordingProblem,
    bool clearRecordingProblem = false,
    bool? allowanceUsed,
  }) => MeetingsState(
    recording: clearRecording ? null : recording ?? this.recording,
    stopped: stopped ?? this.stopped,
    waiting: waiting ?? this.waiting,
    ready: ready ?? this.ready,
    loaded: loaded ?? this.loaded,
    recordingProblem: clearRecordingProblem
        ? null
        : recordingProblem ?? this.recordingProblem,
    allowanceUsed: allowanceUsed ?? this.allowanceUsed,
  );
}

/// Why a recording can't start.
enum MeetingStartProblem {
  /// Meetings need an account (and Pro, which the server checks).
  signedOut,

  /// The microphone permission was refused; Android still asks again.
  permission,

  /// The microphone permission was refused, and Android no longer asks:
  /// only the phone's Settings can allow it.
  microphoneBlocked,

  /// Under about 100 MB free (MN-6).
  lowSpace,

  /// Another meeting is recording.
  busy,
}

class MeetingStartRefused implements Exception {
  const MeetingStartRefused(this.problem);
  final MeetingStartProblem problem;
  @override
  String toString() => 'Meeting not started: ${problem.name}';
}

/// How «Save notes and sign out» ended ([MeetingController.uploadNow]).
enum MeetingSendResult {
  /// Nothing is left for this account: it can sign out.
  done,

  /// The server couldn't be reached.
  offline,

  /// Still not done after two minutes of retries.
  slow,

  /// What's left can't be sent now: a recording is lost or expired, Pro or
  /// the month's time holds one back, or the login was refused.
  blocked,
}

/// The app's meetings for one account: recording, recovery and uploads
/// while the app runs. With the app closed, WorkManager's task uploads
/// ([runMeetingUploads]); both never send at once (the upload lease).
class MeetingController extends StateNotifier<MeetingsState> {
  MeetingController({
    required this.store,
    required MeetingAudioEngine engine,
    required this.ownerKey,
    this.api,
    this.scheduler = const WorkmanagerMeetingScheduler(),
    DateTime Function()? clock,
    MeetingPieceRules rules = const MeetingPieceRules(),
    Future<int?> Function()? freeBytes,
    this.onNotesSaved,
    this.retryFloor = const Duration(seconds: 2),
  }) : clock = clock ?? DateTime.now,
       super(const MeetingsState()) {
    recorder = MeetingRecorder(
      store: store,
      engine: engine,
      clock: this.clock,
      rules: rules,
      freeBytes: freeBytes,
      onPiece: (_) => _kick(),
      onEnded: recordingEnded,
    );
    uploader = api == null
        ? null
        : MeetingUploader(
            store: store,
            api: api!,
            ownerKey: ownerKey,
            clock: this.clock,
          );
    _status = recorder.status.listen((status) {
      if (mounted) {
        state = state.copyWith(
          recording: status,
          clearRecording: status == null,
        );
      }
    });
    // Recovery that fails (no storage yet) is tried again on the next
    // start; it never surfaces as an unhandled error, also for a
    // controller Riverpod makes again as the account changes.
    ready = _open().catchError((Object _) {});
  }

  final MeetingStore store;
  final String ownerKey;
  final MeetingApi? api;
  final MeetingScheduler scheduler;
  final DateTime Function() clock;

  /// The new notes are in the database: show them.
  final void Function(List<SavedMeetingNote> saved)? onNotesSaved;

  /// The shortest wait between two upload passes.
  final Duration retryFloor;

  late final MeetingRecorder recorder;
  late final MeetingUploader? uploader;
  late final StreamSubscription<MeetingRecordingStatus?> _status;

  /// Done once recovery on start has run.
  late final Future<void> ready;

  Timer? _retry;
  final _ends = <String, MeetingRecorderEnd>{};
  bool _uploading = false;
  bool _again = false;
  Future<void> _upload = Future.value();

  /// On start (MN-12, MN-26): a recording that stopped under the app is
  /// kept as stopped unexpectedly; one left unanswered for 7 days is
  /// finished into a note.
  Future<void> _open() async {
    try {
      await store.recoverInterrupted(ownerKey, active: recorder.meetingId);
      await store.autoFinishStale(ownerKey, clock());
      await store.clean(ownerKey, clock());
    } finally {
      await refresh();
    }
    _kick();
  }

  /// Reads the meetings on this phone again. The stopped recordings it
  /// finds are on show from now: their 7 days count from here (MN-26).
  Future<void> refresh() async {
    await store.markAsked(ownerKey, clock());
    final all = await store.meetings(ownerKey);
    if (!mounted) return;
    final active = recorder.meetingId;
    final held = all
        .where((m) => m.id == active && MeetingProblem.blocksUploads(m.problem))
        .firstOrNull
        ?.problem;
    state = state.copyWith(
      loaded: true,
      recordingProblem: held,
      clearRecordingProblem: held == null,
      allowanceUsed: all.any(_allowanceUsedThisMonth),
      stopped: [
        for (final meeting in all)
          if (meeting.phase == MeetingPhase.interrupted) meeting,
      ],
      waiting: [
        for (final meeting in all)
          if (meeting.phase == MeetingPhase.finishing) meeting,
      ],
      ready: [
        for (final meeting in all)
          if ((meeting.phase == MeetingPhase.saved ||
                  meeting.phase == MeetingPhase.done) &&
              meeting.noteId != null &&
              !meeting.seen)
            meeting,
      ],
    );
  }

  /// [meeting] was refused for the month's meeting time this calendar
  /// month. The refusal set its next try [MeetingUploader.blockedPause]
  /// later.
  bool _allowanceUsedThisMonth(Meeting meeting) {
    if (meeting.problem != MeetingProblem.allowanceUsed) return false;
    final refused =
        (meeting.retryAt?.subtract(MeetingUploader.blockedPause) ??
                meeting.stoppedAt ??
                meeting.startedAt)
            .toLocal();
    final now = clock().toLocal();
    return refused.year == now.year && refused.month == now.month;
  }

  // ---- Recording ----

  /// Why [id]'s recording ended without Stop, once it has; null otherwise.
  MeetingRecorderEnd? endOf(String id) => _ends[id];

  /// The recorder ended [meeting]'s recording by itself, for [end].
  void recordingEnded(Meeting meeting, MeetingRecorderEnd end) {
    _ends[meeting.id] = end;
    unawaited(refresh());
  }

  /// Starts recording a new meeting. Throws [MeetingStartRefused].
  Future<Meeting> start({
    required MeetingNotice notice,
    String? language,
    String? projectId,
  }) async {
    await ready;
    await _canRecord();
    final meeting = await recorder.start(
      ownerKey,
      notice: notice,
      language: language,
      projectId: projectId,
    );
    await refresh();
    return meeting;
  }

  Future<void> _canRecord() async {
    if (api == null || ownerKey == 'local') {
      throw const MeetingStartRefused(MeetingStartProblem.signedOut);
    }
    if (recorder.recording) {
      throw const MeetingStartRefused(MeetingStartProblem.busy);
    }
    if (!await recorder.hasRoom()) {
      throw const MeetingStartRefused(MeetingStartProblem.lowSpace);
    }
    switch (await recorder.engine.permission()) {
      case SpeechPermission.granted:
        return;
      case SpeechPermission.denied:
        throw const MeetingStartRefused(MeetingStartProblem.permission);
      case SpeechPermission.blocked:
        throw const MeetingStartRefused(MeetingStartProblem.microphoneBlocked);
    }
  }

  /// Whether the microphone is allowed now, without asking: back from the
  /// phone's Settings.
  Future<bool> microphoneAllowed() async =>
      await recorder.engine.permission(ask: false) == SpeechPermission.granted;

  /// Stop: the meeting waits for its notes. A recording of a minute or
  /// more judged all silence comes back stopped
  /// ([MeetingPhase.interrupted]), kept, to ask whether to make notes anyway
  /// ([finishMeeting]) or discard it ([discardMeeting]) (UX-2717). Null
  /// when a shorter one heard only silence, and nothing is kept. When it
  /// throws, what was recorded is kept, and Stop works again (UX-2713).
  Future<Meeting?> stop() async {
    final meeting = await recorder.stop();
    try {
      await refresh();
    } catch (_) {
      /* It has stopped: the next refresh shows it. */
    }
    _kick();
    return meeting;
  }

  /// Discard while recording (MN-25).
  Future<void> discardRecording() async {
    await recorder.discard();
    await refresh();
    _kick();
  }

  /// Continue a recording that stopped unexpectedly (MN-12).
  Future<Meeting> continueMeeting(
    String id, {
    required MeetingNotice notice,
  }) async {
    await ready;
    await _canRecord();
    final meeting = await recorder.resume(id, ownerKey, notice: notice);
    await refresh();
    return meeting;
  }

  /// Finish a recording that stopped unexpectedly: its notes are made from
  /// what it has.
  Future<Meeting?> finishMeeting(String id) async {
    final meeting = await store.finish(id, ownerKey, clock());
    await refresh();
    _kick();
    return meeting;
  }

  /// Discard a stopped or waiting meeting: its audio here, and the meeting
  /// on the server (MN-25).
  Future<void> discardMeeting(String id) async {
    if (recorder.meetingId == id) return discardRecording();
    await store.discard(id, ownerKey);
    await refresh();
    _kick();
  }

  /// The screens showed that [id]'s notes are ready.
  Future<void> markSeen(String id) async {
    await store.markSeen(id, ownerKey);
    await MeetingHooks.notesSeen(id);
    await refresh();
  }

  // ---- Signing out (MN-13) ----

  /// What signing out now would leave: when not empty, ask whether to
  /// upload first or discard.
  Future<MeetingBacklog> backlog() => store.backlog(ownerKey);

  /// Upload first: runs uploads now until nothing waits or the server can't
  /// be reached, and says how it ended: [MeetingSendResult.done] when
  /// nothing is left for this account.
  Future<MeetingSendResult> uploadNow() async {
    await ready;
    if (uploader == null) {
      return (await backlog()).isEmpty
          ? MeetingSendResult.done
          : MeetingSendResult.offline;
    }
    await _upload;
    // Asked for now: no waiting out the pauses after earlier failures.
    await store.retryNow(ownerKey);
    final waited = Stopwatch()..start();
    MeetingPass pass;
    while (true) {
      await _upload;
      pass = await uploader!.run();
      await _passed(pass);
      if (pass.idle || pass.offline || pass.stopped) break;
      var due = pass.nextDue!.difference(clock());
      if (due < retryFloor) due = retryFloor;
      if (waited.elapsed + due > const Duration(minutes: 2)) break;
      await Future<void>.delayed(due);
    }
    if ((await backlog()).isEmpty) return MeetingSendResult.done;
    if (pass.offline) return MeetingSendResult.offline;
    final left = [...state.stopped, ...state.waiting];
    final heldBack =
        left.isNotEmpty &&
        left.every(
          (m) =>
              MeetingProblem.blocksUploads(m.problem) ||
              m.problem == MeetingProblem.pieceFailed ||
              m.problem == MeetingProblem.expired,
        );
    if (pass.stopped || heldBack) return MeetingSendResult.blocked;
    return MeetingSendResult.slow;
  }

  /// Discard: every meeting still waiting for this account goes (MN-13).
  Future<void> discardAll() async {
    if (recorder.recording) await recorder.discard();
    await store.discardAll(ownerKey);
    await refresh();
    _kick();
  }

  // ---- Uploads ----

  /// The account has just bought or restored Pro: meetings held back for
  /// Pro are sent at once, not after [MeetingUploader.blockedPause].
  Future<void> proGained() async {
    await ready;
    if (uploader == null) return;
    await store.retryNow(ownerKey, proGained: true);
    await refresh();
    _kick();
  }

  /// Uploads what's due now, and asks WorkManager to go on if the app
  /// closes.
  void _kick() {
    if (uploader == null || !mounted) return;
    unawaited(scheduler.schedule());
    _retry?.cancel();
    if (_uploading) {
      _again = true;
      return;
    }
    _uploading = true;
    _upload = _uploadLoop().whenComplete(() => _uploading = false);
  }

  Future<void> _uploadLoop() async {
    do {
      _again = false;
      try {
        await _passed(await uploader!.run());
      } catch (_) {
        /* Tried again on the next piece or start. */
      }
    } while (_again && mounted);
  }

  Future<void> _passed(MeetingPass pass) async {
    if (pass.saved.isNotEmpty) onNotesSaved?.call(pass.saved);
    await refresh();
    final next = pass.nextDue;
    if (!mounted || next == null || pass.stopped) return;
    var delay = next.difference(clock());
    if (delay < retryFloor) delay = retryFloor;
    _retry?.cancel();
    _retry = Timer(delay, _kick);
  }

  @override
  void dispose() {
    _retry?.cancel();
    unawaited(_status.cancel());
    // A recording the app leaves stays as stopped unexpectedly.
    unawaited(
      recorder.suspend().catchError((Object _) {
        /* Recovery on the next start finds it as stopped unexpectedly. */
      }),
    );
    super.dispose();
  }
}

final meetingStoreProvider = Provider<MeetingStore>(
  (ref) => MeetingStore(TaskDatabase()),
);

/// The microphone; tests give a fake.
final meetingAudioEngineProvider = Provider<MeetingAudioEngine>(
  (ref) => RecordMeetingAudio(),
);

final meetingSchedulerProvider = Provider<MeetingScheduler>(
  (ref) => const WorkmanagerMeetingScheduler(),
);

final meetingClockProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
);

/// Free space where the audio goes (MN-6); tests give their own.
final meetingFreeBytesProvider = Provider<Future<int?> Function()>(
  (ref) => ref.watch(meetingStoreProvider).freeBytes,
);

/// The meeting calls for the signed-in account; null signed out.
final meetingApiProvider = Provider<MeetingApi?>((ref) {
  final id = ref.watch(authProvider.select((s) => s.account?.id));
  return id == null ? null : ApiMeetingApi(ref.read(apiClientProvider), id);
});

final meetingControllerProvider =
    StateNotifierProvider<MeetingController, MeetingsState>(
      (ref) => MeetingController(
        store: ref.watch(meetingStoreProvider),
        engine: ref.watch(meetingAudioEngineProvider),
        api: ref.watch(meetingApiProvider),
        ownerKey: ref.watch(captureOwnerProvider),
        scheduler: ref.watch(meetingSchedulerProvider),
        clock: ref.watch(meetingClockProvider),
        freeBytes: ref.watch(meetingFreeBytesProvider),
        onNotesSaved: (_) =>
            unawaited(ref.read(taskProvider.notifier).showLocal()),
      ),
    );

/// The meeting being recorded now, or null.
final meetingRecordingProvider = Provider<MeetingRecordingStatus?>(
  (ref) => ref.watch(meetingControllerProvider.select((s) => s.recording)),
);

/// Recordings that stopped unexpectedly (MN-12).
final stoppedMeetingsProvider = Provider<List<Meeting>>(
  (ref) => ref.watch(meetingControllerProvider.select((s) => s.stopped)),
);

/// Stopped meetings waiting for their notes (MN-11).
final waitingMeetingsProvider = Provider<List<Meeting>>(
  (ref) => ref.watch(meetingControllerProvider.select((s) => s.waiting)),
);

/// Notes saved and not yet shown.
final meetingResultsProvider = Provider<List<Meeting>>(
  (ref) => ref.watch(meetingControllerProvider.select((s) => s.ready)),
);
