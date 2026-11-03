import 'dart:async';
import 'dart:collection';
import 'package:agenda/models/meeting.dart';
import 'package:agenda/services/meeting_store.dart';

/// The words of the recording's ongoing notification (MN-1). The screens'
/// package gives them, in the app's language.
class MeetingNotice {
  const MeetingNotice({
    required this.title,
    this.text,
    this.channelName,
    this.stopLabel,
    this.discardLabel,
  });
  final String title;
  final String? text;

  /// The name Android's notification settings give the recording's
  /// channel. The recorder's own is English only ("Audio Capture").
  final String? channelName;

  /// The notification's **Stop** and **Discard** (MN-1, MN-25); no button
  /// when null.
  final String? stopLabel;
  final String? discardLabel;
}

/// The microphone, as the meeting recorder needs it. The app's is
/// `RecordMeetingAudio` (the `record` package, in a foreground service);
/// tests give a fake.
abstract class MeetingAudioEngine {
  Future<bool> hasPermission();

  /// Ogg Opus when this phone can write it, else AAC in ADTS frames.
  Future<MeetingAudioFormat> format();

  /// Starts writing [path] in [format], mono 16 kHz at about 24 kbps,
  /// showing [notice] while it records.
  Future<void> start(
    String path,
    MeetingAudioFormat format,
    MeetingNotice notice,
  );

  /// Goes on in a new file [path], losing as little as possible between
  /// the two: the previous file is complete once this returns.
  Future<void> next(String path);

  Future<void> stop();

  /// The input level, in dBFS (0 is the loudest, about −160 silence), a few
  /// times a second while recording.
  Stream<double> get levels;
}

/// When a recording is cut into pieces (MN-4).
class MeetingPieceRules {
  const MeetingPieceRules({
    this.target = const Duration(minutes: 5),
    this.cap = const Duration(minutes: 6),
    this.pause = const Duration(milliseconds: 700),
    this.soundDb = -42,
    this.soundSamples = 3,
    this.heartbeat = const Duration(seconds: 5),
    this.floorWindow = const Duration(seconds: 10),
    this.minFreeBytes = 100 * 1024 * 1024,
    this.lowFreeBytes = 300 * 1024 * 1024,
  });

  /// A piece is cut at the first pause after this long…
  final Duration target;

  /// …and at this long whatever is said, by a timer too, so a piece never
  /// passes the server's 600-second limit while no level comes.
  final Duration cap;

  /// How long the level stays low to count as a pause between words.
  final Duration pause;

  /// A level above this is sound, not silence; a piece with fewer than
  /// [soundSamples] such levels is silence, and is left out.
  final double soundDb;
  final int soundSamples;

  /// How often the recording saves how far it got, for recovery.
  final Duration heartbeat;

  /// The room's quiet is the lowest level heard over this long.
  final Duration floorWindow;

  /// Below this much free space the recording stops safely (MN-6).
  final int minFreeBytes;

  /// Below this much, recording warns that space is low and goes on: at
  /// about 1 MB every 5 minutes, a few hours before [minFreeBytes].
  final int lowFreeBytes;
}

/// What the recording screen shows (MN-7).
class MeetingRecordingStatus {
  const MeetingRecordingStatus({
    required this.meetingId,
    required this.elapsed,
    required this.level,
  });
  final String meetingId;

  /// Audio recorded so far in this meeting, with earlier sessions.
  final Duration elapsed;

  /// The input level from 0 (silence) to 1 (loud).
  final double level;

  static double levelOf(double db) => ((db + 60) / 60).clamp(0.0, 1.0);
}

/// Why a recording ended without Stop.
enum MeetingRecorderEnd {
  /// The phone is almost out of space (MN-6): the meeting was finished.
  lowSpace,

  /// The microphone failed: the meeting waits as stopped unexpectedly.
  failed,

  /// Out of space with nothing but silence recorded: nothing was kept.
  empty,
}

class _Session {
  _Session(this.meeting, this.index, this.offset, this.started);
  final Meeting meeting;
  int index;
  Duration offset;
  DateTime started;
  DateTime? lastBeat;
  int loud = 0;
  DateTime? quietSince;
  final window = ListQueue<(DateTime, double)>();
}

/// Records one meeting at a time into numbered pieces in [store]
/// (MN-1 to MN-5): each piece is cut at a pause after about 5 minutes
/// ([MeetingPieceRules]), with its offset and duration; a piece of only
/// silence is left out and its number used by the next. Every few seconds
/// it saves how far it got, so a recording that stops under it can be
/// recovered ([MeetingStore.recoverInterrupted]).
class MeetingRecorder {
  MeetingRecorder({
    required this.store,
    required this.engine,
    DateTime Function()? clock,
    this.rules = const MeetingPieceRules(),
    this.freeBytes,
    this.onPiece,
    this.onEnded,
    this.timer = Timer.new,
  }) : clock = clock ?? DateTime.now;

  final MeetingStore store;
  final MeetingAudioEngine engine;
  final DateTime Function() clock;
  final MeetingPieceRules rules;

  /// Free space on the phone, when it can be known.
  final Future<int?> Function()? freeBytes;

  /// A piece is ready to upload.
  final void Function(Meeting meeting)? onPiece;

  /// The recording ended without Stop ([MeetingRecorderEnd]).
  final void Function(Meeting meeting, MeetingRecorderEnd end)? onEnded;

  /// Makes the timer that cuts a piece at [MeetingPieceRules.cap]; tests
  /// give one they fire.
  final Timer Function(Duration after, void Function() then) timer;

  _Session? _session;
  Timer? _capTimer;
  StreamSubscription<double>? _levels;
  Future<void> _chain = Future.value();
  bool _closing = false;

  /// The one closing of the current session under way: Stop, Discard and
  /// an end the recorder began itself never close it twice.
  Future<_Session?>? _closingSession;

  /// An end the recorder began itself ([_end]), with its meeting.
  Future<Meeting>? _ending;

  final _status = StreamController<MeetingRecordingStatus?>.broadcast();

  /// The recording's elapsed time and level; null once it ends.
  Stream<MeetingRecordingStatus?> get status => _status.stream;
  MeetingRecordingStatus? current;

  bool get recording => _session != null;

  /// Done once every level heard so far has been handled.
  Future<void> settle() => _chain;
  String? get meetingId => _session?.meeting.id;

  /// Whether the phone has room to record (MN-6); true when unknown.
  Future<bool> hasRoom() async {
    final free = await freeBytes?.call();
    return free == null || free >= rules.minFreeBytes;
  }

  /// Whether space is low enough to warn about as recording starts (MN-6);
  /// false when unknown.
  Future<bool> roomIsLow() async {
    final free = await freeBytes?.call();
    return free != null && free < rules.lowFreeBytes;
  }

  /// Starts a new meeting for [ownerKey].
  Future<Meeting> start(
    String ownerKey, {
    required MeetingNotice notice,
    String? language,
    String? projectId,
  }) async {
    await _ending;
    if (_session != null) throw StateError('A meeting is already recording.');
    final meeting = await store.create(
      ownerKey,
      format: await engine.format(),
      now: clock(),
      language: language,
      projectId: projectId,
    );
    try {
      await _begin(meeting, notice);
    } catch (_) {
      await store.discard(meeting.id, ownerKey);
      rethrow;
    }
    return meeting;
  }

  /// Continue (MN-12): records on into interrupted meeting [id], its new
  /// pieces numbered after the last and starting where it stopped.
  Future<Meeting> resume(
    String id,
    String ownerKey, {
    required MeetingNotice notice,
  }) async {
    await _ending;
    if (_session != null) throw StateError('A meeting is already recording.');
    final meeting = await store.resume(id, ownerKey, clock());
    try {
      await _begin(meeting, notice);
    } catch (_) {
      await store.recoverInterrupted(ownerKey);
      rethrow;
    }
    return meeting;
  }

  Future<void> _begin(Meeting meeting, MeetingNotice notice) async {
    final path = await store.piecePath(
      meeting.id,
      meeting.recorded,
      meeting.format,
    );
    await store.openPiece(
      meeting,
      index: meeting.nextIndex,
      offset: meeting.recorded,
      path: path,
      now: clock(),
    );
    final session = _Session(
      meeting,
      meeting.nextIndex,
      meeting.recorded,
      clock(),
    );
    try {
      await engine.start(path, meeting.format, notice);
    } catch (_) {
      _session = null;
      rethrow;
    }
    session.started = clock();
    session.lastBeat = session.started;
    _closing = false;
    _session = session;
    _armCap(session);
    _publish(session, -160);
    _levels = engine.levels.listen(
      (db) => _chain = _chain.then((_) => _onLevel(db)),
      onError: (Object _) =>
          _chain = _chain.then((_) => _end(MeetingRecorderEnd.failed)),
    );
  }

  void _publish(_Session session, double db) {
    current = MeetingRecordingStatus(
      meetingId: session.meeting.id,
      elapsed: session.offset + clock().difference(session.started),
      level: MeetingRecordingStatus.levelOf(db),
    );
    if (!_status.isClosed) _status.add(current);
  }

  bool _quiet(_Session session, double db) {
    var floor = db;
    for (final (_, level) in session.window) {
      if (level < floor) floor = level;
    }
    final threshold = (floor + 10).clamp(-55.0, -30.0);
    return db < threshold;
  }

  Future<void> _onLevel(double db) async {
    final session = _session;
    if (session == null || _closing) return;
    final now = clock();
    try {
      session.window.add((now, db));
      while (session.window.isNotEmpty &&
          now.difference(session.window.first.$1) > rules.floorWindow) {
        session.window.removeFirst();
      }
      if (db > rules.soundDb) session.loud++;
      if (_quiet(session, db)) {
        session.quietSince ??= now;
      } else {
        session.quietSince = null;
      }
      _publish(session, db);
      final length = now.difference(session.started);
      if (now.difference(session.lastBeat ?? session.started) >=
          rules.heartbeat) {
        session.lastBeat = now;
        await store.heartbeat(
          session.meeting,
          index: session.index,
          pieceDuration: length,
          hasSound: session.loud >= rules.soundSamples,
          now: now,
        );
      }
      final paused =
          session.quietSince != null &&
          now.difference(session.quietSince!) >= rules.pause;
      if ((length >= rules.target && paused) || length >= rules.cap) {
        await _cut(session);
      }
    } catch (_) {
      await _end(MeetingRecorderEnd.failed);
    }
  }

  /// Cuts the piece at [MeetingPieceRules.cap] even when no level comes
  /// to do it, so no piece passes the server's 600 seconds.
  void _armCap(_Session session) {
    _capTimer?.cancel();
    final started = session.started;
    final left = rules.cap - clock().difference(started);
    _capTimer = timer(left.isNegative ? Duration.zero : left, () {
      _chain = _chain.then((_) async {
        // A pause or an earlier cut may have ended this piece meanwhile.
        if (!identical(_session, session) ||
            _closing ||
            session.started != started) {
          return;
        }
        try {
          await _cut(session);
        } catch (_) {
          await _end(MeetingRecorderEnd.failed);
        }
      });
    });
  }

  /// Ends the current piece and goes on in the next.
  Future<void> _cut(_Session session) async {
    if (!await hasRoom()) {
      await _end(MeetingRecorderEnd.lowSpace);
      return;
    }
    final now = clock();
    final duration = now.difference(session.started);
    final hasSound = session.loud >= rules.soundSamples;
    final offset = session.offset + duration;
    final path = await store.piecePath(
      session.meeting.id,
      offset,
      session.meeting.format,
    );
    await engine.next(path);
    final started = clock();
    await store.closePiece(
      session.meeting,
      index: session.index,
      duration: duration,
      hasSound: hasSound,
      now: now,
      nextPath: path,
    );
    session
      ..index = hasSound ? session.index + 1 : session.index
      ..offset = offset
      ..started = started
      ..lastBeat = started
      ..loud = 0
      ..quietSince = null;
    _armCap(session);
    if (hasSound) onPiece?.call(session.meeting);
  }

  /// Stops listening and stops the microphone. The session goes to the
  /// first caller only; one that comes while it closes waits for it and
  /// gets null.
  Future<_Session?> _close() {
    final closing = _closingSession;
    if (closing != null) return closing.then((_) => null);
    final session = _session;
    if (session == null) return Future.value(null);
    final done = _closingSession = _shut(session);
    return done.whenComplete(() {
      if (identical(_closingSession, done)) _closingSession = null;
    });
  }

  Future<_Session?> _shut(_Session session) async {
    _closing = true;
    _capTimer?.cancel();
    _capTimer = null;
    await _levels?.cancel();
    _levels = null;
    await _chain;
    _session = null;
    current = null;
    if (!_status.isClosed) _status.add(null);
    try {
      await engine.stop();
    } catch (_) {
      /* What was written stays: the file survives a sudden stop. */
    }
    return session;
  }

  Future<void> _closePiece(_Session session) async {
    final now = clock();
    await store.closePiece(
      session.meeting,
      index: session.index,
      duration: now.difference(session.started),
      hasSound: session.loud >= rules.soundSamples,
      now: now,
    );
  }

  /// Stop (MN-1): the last piece is kept and the meeting waits for its
  /// notes. Null when nothing but silence was recorded: the meeting is
  /// discarded then.
  Future<Meeting?> stop() async {
    // Stop pressed while the recorder was ending by itself (the microphone
    // failed, or space ran out): what it kept is finished all the same.
    final ended = await _ending;
    if (ended != null) return store.finish(ended.id, ended.ownerKey, clock());
    final session = await _close();
    if (session == null) return null;
    final meeting = session.meeting;
    await _closePiece(session);
    return store.finish(meeting.id, meeting.ownerKey, clock());
  }

  /// Discard (MN-25): stops and deletes everything recorded.
  Future<void> discard() async {
    final ended = await _ending;
    if (ended != null) return store.discard(ended.id, ended.ownerKey);
    final session = await _close();
    if (session == null) return;
    await store.discard(session.meeting.id, session.meeting.ownerKey);
  }

  /// Stops recording, keeping the meeting as stopped unexpectedly: when the
  /// app is closing under it.
  Future<void> suspend() async {
    if (await _ending != null) return;
    final session = await _close();
    if (session == null) return;
    await _closePiece(session);
    await store.recoverInterrupted(session.meeting.ownerKey);
  }

  Future<void> _end(MeetingRecorderEnd end) async {
    final session = _session;
    if (session == null || _closing) return;
    _closing = true;
    // Not awaited from inside the level chain: [_close] waits for it.
    final ending = _ending = Future(() async {
      var reason = end;
      final closed = await _close();
      final meeting = closed?.meeting ?? session.meeting;
      if (closed == null) return meeting;
      try {
        await _closePiece(closed);
      } catch (_) {
        /* Recovery keeps it as far as the last heartbeat. */
      }
      try {
        if (end == MeetingRecorderEnd.lowSpace) {
          final kept = await store.finish(
            meeting.id,
            meeting.ownerKey,
            clock(),
          );
          // Only silence: discarded, and no notes will follow.
          if (kept == null) reason = MeetingRecorderEnd.empty;
        } else {
          await store.recoverInterrupted(meeting.ownerKey);
        }
      } catch (_) {
        /* Found as stopped unexpectedly on the next start. */
      }
      onPiece?.call(meeting);
      onEnded?.call(meeting, reason);
      return meeting;
    });
    unawaited(
      ending.whenComplete(() {
        if (identical(_ending, ending)) _ending = null;
      }),
    );
  }

  Future<void> dispose() async {
    await suspend();
    await _status.close();
  }
}
