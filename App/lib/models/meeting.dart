/// A conversation recorded on this phone and turned into notes by the
/// server (App/docs/MEETING_NOTES.md, Backend/docs/MEETINGS.md).
library;

/// Where a meeting is on this phone.
enum MeetingPhase {
  /// The recorder is writing it now, or was until the app stopped.
  recording,

  /// The recorder stopped without Stop: the app was killed, or the phone
  /// shut down (MN-12). It waits for Continue, Finish or Discard.
  interrupted,

  /// Stop was pressed: pieces upload, then `finish` is repeated until the
  /// notes come back (MN-10, MN-11).
  finishing,

  /// The notes are saved as a note here; the server still has to hear
  /// that it can delete the meeting (MN-24).
  saved,

  /// The server deleted it after the note was saved. Kept only to say the
  /// notes are ready, until that has been seen.
  done,

  /// Discarded: local audio is gone, the server still has to hear it.
  discarding;

  static MeetingPhase parse(Object? value) => MeetingPhase.values.firstWhere(
    (phase) => phase.name == value,
    orElse: () => MeetingPhase.interrupted,
  );
}

/// Why a meeting's uploads are held back, as the screens may say it.
abstract final class MeetingProblem {
  /// The last call could not reach the server: «Waiting for signal».
  static const offline = 'offline';

  /// The account no longer has TaskFlow Pro (402 `pro_required`).
  static const proRequired = 'pro_required';

  /// This month's meeting allowance is used (402 `meeting_allowance_used`).
  static const allowanceUsed = 'meeting_allowance_used';

  /// The server answered with an error; it's tried again later.
  static const server = 'server';

  /// The server no longer has the pieces this phone already sent and
  /// deleted, so no notes can be made from them.
  static const expired = 'expired';

  /// A piece can't be sent: its audio is gone from the phone, or the server
  /// refuses it for good (corrupt, too large). The server can't make notes
  /// without it, so the meeting can only be discarded; its other pieces
  /// stay here and wait.
  static const pieceFailed = 'piece_failed';

  static bool blocksUploads(String? problem) =>
      problem == proRequired || problem == allowanceUsed;
}

/// How a meeting's pieces are encoded. Ogg Opus survives a sudden stop;
/// AAC is written as ADTS frames, which do too. Never M4A (MN-3).
enum MeetingAudioFormat {
  opus('ogg', 'audio/ogg'),
  aac('aac', 'audio/aac');

  const MeetingAudioFormat(this.extension, this.mimeType);
  final String extension;
  final String mimeType;

  static MeetingAudioFormat parse(Object? value) =>
      MeetingAudioFormat.values.firstWhere(
        (format) => format.name == value,
        orElse: () => MeetingAudioFormat.opus,
      );
}

class Meeting {
  const Meeting({
    required this.id,
    required this.ownerKey,
    required this.phase,
    required this.startedAt,
    required this.format,
    this.stoppedAt,
    this.heartbeatAt,
    this.recorded = Duration.zero,
    this.nextIndex = 0,
    this.lastIndex,
    this.language,
    this.projectId,
    this.problem,
    this.attempts = 0,
    this.retryAt,
    this.waits = 0,
    this.askedAt,
    this.noteId,
    this.title,
    this.seen = false,
    this.waitingPieces = 0,
  });

  /// Made on the phone; the server keeps the same id.
  final String id;
  final String ownerKey;
  final MeetingPhase phase;
  final DateTime startedAt;

  /// How its pieces are encoded, chosen when it started.
  final MeetingAudioFormat format;

  /// When Stop was pressed, or when the recording was last known to run.
  final DateTime? stoppedAt;
  final DateTime? heartbeatAt;

  /// How much audio the meeting has: the next piece starts here.
  final Duration recorded;

  /// The number the next kept piece gets (MN-5).
  final int nextIndex;

  /// The last piece's number, once Stop or Finish set it.
  final int? lastIndex;
  final String? language;
  final String? projectId;

  /// Why uploads are held back ([MeetingProblem]); null when they aren't.
  final String? problem;

  /// Failed calls since the last answer; the pause before the next grows
  /// with them.
  final int attempts;
  final DateTime? retryAt;

  /// How many times `finish` answered `waiting` with every piece sent.
  final int waits;

  /// When the screens first had this stopped recording to ask about
  /// (MN-12); the 7 days without an answer count from then (MN-26).
  final DateTime? askedAt;

  /// The note the notes were saved as.
  final int? noteId;

  /// The saved note's title.
  final String? title;

  /// Whether the screens have shown that the notes are ready.
  final bool seen;

  /// Pieces still on the phone waiting for the server's confirmation.
  final int waitingPieces;

  /// «Waiting for signal» (MN-11).
  bool get waitingForSignal => problem == MeetingProblem.offline;

  /// No piece was kept: everything recorded was silence.
  bool get empty => nextIndex == 0;

  /// Kept no piece with sound, but holds its silent pieces on the phone
  /// ([MeetingPiece.held]): a quiet recording, as Stop keeps one to ask
  /// about (UX-2717). An empty meeting's pieces still there are held ones.
  bool get quiet => empty && waitingPieces > 0;
}

/// One numbered piece of about 5 minutes (MN-4, MN-5).
class MeetingPiece {
  const MeetingPiece({
    required this.meetingId,
    required this.ownerKey,
    required this.index,
    required this.offset,
    required this.duration,
    required this.path,
    required this.state,
    this.hasSound = true,
    this.attempts = 0,
    this.retryAt,
  });

  final String meetingId;
  final String ownerKey;
  final int index;
  final Duration offset;
  final Duration duration;
  final String path;

  /// `recording` while the recorder writes it, `pending` until the server
  /// confirms it, `saved` after (its file is then deleted); `failed` when
  /// it can never be sent ([MeetingProblem.pieceFailed]); `held` for a
  /// silent piece kept on the phone, never sent, while its meeting has no
  /// piece with sound yet (UX-2717).
  final String state;
  final bool hasSound;
  final int attempts;
  final DateTime? retryAt;

  static const recording = 'recording';
  static const pending = 'pending';
  static const saved = 'saved';
  static const failed = 'failed';
  static const held = 'held';
}

/// One task said in the meeting, with the steps that belong to it.
class MeetingTask {
  const MeetingTask({
    required this.title,
    this.who,
    this.when,
    this.steps = const [],
  });
  final String title;
  final String? who;

  /// The words as said; «Crear tareas» reads the day from them against the
  /// meeting's date.
  final String? when;

  /// The parts of this same task that were said; unrelated ones are tasks
  /// of their own.
  final List<String> steps;

  Map<String, Object?> toJson() => {
    'title': title,
    'who': who,
    'when': when,
    'steps': steps,
  };

  /// Null when [json] holds no title.
  static MeetingTask? fromJson(Object? json) {
    if (json is! Map) return null;
    final title = MeetingResult._text(json['title'] ?? json['text']);
    if (title.isEmpty) return null;
    return MeetingTask(
      title: title,
      who: MeetingResult._optional(json['who']),
      when: MeetingResult._optional(json['when']),
      steps: MeetingResult._lines(json['steps']),
    );
  }
}

class MeetingChapter {
  const MeetingChapter({
    required this.startMinute,
    required this.endMinute,
    required this.title,
    this.notes = '',
  });
  final int startMinute;
  final int endMinute;
  final String title;
  final String notes;
}

/// The server's final notes (Backend/docs/MEETINGS.md, «The result»).
class MeetingResult {
  const MeetingResult({
    this.title = '',
    this.summary = '',
    this.tasks = const [],
    this.decisions = const [],
    this.openQuestions = const [],
    this.chapters = const [],
    this.startMissing = false,
    this.language,
  });

  final String title;
  final String summary;
  final List<MeetingTask> tasks;
  final List<String> decisions;
  final List<String> openQuestions;
  final List<MeetingChapter> chapters;

  /// The start of the recording expired on the server (MN-28).
  final bool startMissing;

  /// BCP-47 primary tag of the language mostly spoken.
  final String? language;

  static String _text(Object? value) => value is String ? value.trim() : '';
  static String? _optional(Object? value) {
    final text = _text(value);
    return text.isEmpty ? null : text;
  }

  static List<String> _lines(Object? value) => value is List
      ? value.map(_text).where((line) => line.isNotEmpty).toList()
      : const [];

  static int _minute(Object? value) => value is num ? value.toInt() : 0;

  /// Reads the result leniently: a field missing or of the wrong type is
  /// left empty rather than losing the rest of the notes.
  factory MeetingResult.fromJson(Map<String, dynamic> json) => MeetingResult(
    title: _text(json['title']),
    summary: _text(json['summary']),
    // `tasks`, each with its steps; a server from before them sends only
    // `todos`, one line each.
    tasks: [
      if ((json['tasks'] is List ? json['tasks'] : json['todos'])
          case final List items)
        for (final item in items) ?MeetingTask.fromJson(item),
    ],
    decisions: _lines(json['decisions']),
    openQuestions: _lines(json['open_questions']),
    chapters: [
      if (json['chapters'] is List)
        for (final item in json['chapters'] as List)
          if (item is Map)
            MeetingChapter(
              startMinute: _minute(item['start_minute']),
              endMinute: _minute(item['end_minute']),
              title: _text(item['title']),
              notes: _text(item['notes']),
            ),
    ],
    startMissing: json['start_missing'] == true,
    language: _optional(json['language']),
  );
}
