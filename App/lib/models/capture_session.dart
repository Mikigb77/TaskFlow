import 'package:agenda/models/task.dart';
import 'package:agenda/models/task_draft.dart';
import 'package:uuid/uuid.dart';
import 'package:agenda/models/capture_clarification.dart';

class CaptureDraft {
  final String id;
  final Task task;
  final List<String> questions;
  final bool confirmed;
  final int? savedTaskId;
  final bool removed;
  final List<String> assignmentIssues;
  final Map<String, String?> assignmentHints;
  final bool assignmentReviewed;
  final List<CaptureClarification> clarifications;
  final List<String> resolvedQuestions;

  /// Built on the phone from typed words whose date was applied: the task as
  /// it would be without that date, for `Keep as typed`.
  final Task? asTyped;

  const CaptureDraft({
    required this.id,
    required this.task,
    this.questions = const [],
    this.assignmentIssues = const [],
    this.assignmentHints = const {},
    this.assignmentReviewed = true,
    this.confirmed = true,
    this.savedTaskId,
    this.removed = false,
    this.clarifications = const [],
    this.resolvedQuestions = const [],
    this.asTyped,
  });

  factory CaptureDraft.fromAI(TaskDraft draft) => CaptureDraft(
    id: const Uuid().v4(),
    task: Task(
      title: draft.title,
      kind: draft.kind,
      listId: draft.listId,
      assignment: draft.assignment,
      assigneeId: draft.assigneeId,
      assigneeName: draft.assigneeName,
      dueDate: draft.dueDate,
      hasTime: draft.hasTime,
      deadline: draft.deadline,
      deadlineHasTime: draft.deadlineHasTime,
      durationMinutes: draft.durationMinutes,
      reminderAnchor: draft.dueDate == null && draft.deadline != null
          ? 'deadline'
          : 'planned',
      recurrence: draft.recurrence,
      repeatInterval: draft.repeatInterval,
      repeatWeekdays: draft.repeatWeekdays,
      repeatUntil: draft.repeatUntil,
      priority: draft.priority,
      checklist: draft.checklist,
      notes: draft.notes,
    ),
    questions: draft.questions,
    clarifications: draft.clarifications,
    assignmentIssues: draft.assignmentIssues,
    assignmentHints: draft.assignmentHints,
    assignmentReviewed: draft.assignmentIssues.isEmpty,
    confirmed: draft.questions.isEmpty && draft.clarifications.isEmpty,
  );

  bool get pending => savedTaskId == null && !removed;
  bool get ready =>
      pending &&
      confirmed &&
      assignmentReviewed &&
      task.title.trim().isNotEmpty;

  List<CaptureClarification> get reviewQuestions => [
    ...clarifications,
    for (final question in questions)
      if (!clarifications.any((c) => c.question == question))
        CaptureClarification(question: question),
  ];

  CaptureDraft copyWith({
    Task? task,
    bool? confirmed,
    int? savedTaskId,
    bool? removed,
    bool? assignmentReviewed,
    List<String>? resolvedQuestions,
    bool clearSavedTaskId = false,
    bool clearAsTyped = false,
  }) => CaptureDraft(
    id: id,
    task: task ?? this.task,
    questions: questions,
    assignmentIssues: assignmentIssues,
    assignmentHints: assignmentHints,
    assignmentReviewed: assignmentReviewed ?? this.assignmentReviewed,
    confirmed: confirmed ?? this.confirmed,
    savedTaskId: clearSavedTaskId ? null : savedTaskId ?? this.savedTaskId,
    clarifications: clarifications,
    resolvedQuestions: resolvedQuestions ?? this.resolvedQuestions,
    removed: removed ?? this.removed,
    asTyped: clearAsTyped ? null : asTyped,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'task': task.toMap(),
    'questions': questions,
    'assignmentIssues': assignmentIssues,
    'assignmentHints': assignmentHints,
    'assignmentReviewed': assignmentReviewed,
    'confirmed': confirmed,
    'clarifications': clarifications.map((c) => c.toJson()).toList(),
    'resolvedQuestions': resolvedQuestions,
    'savedTaskId': savedTaskId,
    'removed': removed,
    if (asTyped != null) 'asTyped': asTyped!.toMap(),
  };

  factory CaptureDraft.fromJson(Map<String, dynamic> json) => CaptureDraft(
    id: json['id'],
    task: Task.fromMap(Map<String, dynamic>.from(json['task'])),
    questions: List<String>.from(json['questions'] ?? []),
    assignmentIssues: List<String>.from(json['assignmentIssues'] ?? []),
    assignmentHints: Map<String, String?>.from(json['assignmentHints'] ?? {}),
    assignmentReviewed: json['assignmentReviewed'] != false,
    confirmed: json['confirmed'] == true,
    clarifications: (json['clarifications'] as List? ?? [])
        .map((c) => CaptureClarification.fromJson(Map<String, dynamic>.from(c)))
        .toList(),
    resolvedQuestions: List<String>.from(json['resolvedQuestions'] ?? []),
    savedTaskId: json['savedTaskId'],
    removed: json['removed'] == true,
    asTyped: json['asTyped'] == null
        ? null
        : Task.fromMap(Map<String, dynamic>.from(json['asTyped'])),
  );
}

class CaptureSession {
  // Matches the Android AudioRecorder configuration used by VoiceTaskScreen.
  // A blank unfinished header cannot identify its format without this journal.
  static const androidPcmWav = 'android-pcm16-mono-16000';
  final String id;
  final String ownerKey;
  final DateTime capturedAt;
  final String timezone;
  final String kind;
  final String text;
  final String transcript;
  final String? audioPath;
  final String? audioFormat;
  final String status;
  final String? error;
  final List<CaptureDraft> drafts;
  final String? projectId;

  /// Where the first words came from: `speech` (the recognizer or recorded
  /// audio) or `typed` (the keyboard or a share). Null until words arrive.
  final String? source;

  /// The later day capture was opened for (Calendar's selected day, the
  /// timeline's day): a task understood with no date and no deadline gets it.
  final DateTime? day;

  const CaptureSession({
    required this.id,
    required this.ownerKey,
    required this.capturedAt,
    required this.timezone,
    this.projectId,
    this.kind = 'task',
    this.text = '',
    this.transcript = '',
    this.audioPath,
    this.audioFormat,
    this.status = 'editing',
    this.error,
    this.drafts = const [],
    this.source,
    this.day,
  });

  bool get terminal => status == 'saved' || status == 'discarded';
  List<CaptureDraft> get remaining => drafts.where((d) => d.pending).toList();
  List<CaptureDraft> get ready => drafts.where((d) => d.ready).toList();

  CaptureSession copyWith({
    String? text,
    String? transcript,
    String? audioPath,
    String? audioFormat,
    String? status,
    String? error,
    String? kind,
    List<CaptureDraft>? drafts,
    String? source,
  }) => CaptureSession(
    id: id,
    ownerKey: ownerKey,
    capturedAt: capturedAt,
    timezone: timezone,
    projectId: projectId,
    kind: kind ?? this.kind,
    text: text ?? this.text,
    transcript: transcript ?? this.transcript,
    audioPath: audioPath ?? this.audioPath,
    audioFormat: audioFormat ?? this.audioFormat,
    status: status ?? this.status,
    error: error,
    drafts: drafts ?? this.drafts,
    source: source ?? this.source,
    day: day,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'ownerKey': ownerKey,
    'capturedAt': capturedAt.toUtc().toIso8601String(),
    'timezone': timezone,
    'projectId': projectId,
    'kind': kind,
    'text': text,
    'transcript': transcript,
    'audioPath': audioPath,
    'audioFormat': audioFormat,
    'status': status,
    'error': error,
    'drafts': drafts.map((d) => d.toJson()).toList(),
    'source': source,
    'day': day == null ? null : Task.dateKey(day!),
  };

  factory CaptureSession.fromJson(Map<String, dynamic> json) => CaptureSession(
    id: json['id'],
    ownerKey: json['ownerKey'],
    capturedAt: DateTime.parse(json['capturedAt']),
    timezone: json['timezone'],
    projectId: json['projectId'],
    kind: json['kind'] ?? 'task',
    text: json['text'] ?? '',
    transcript: json['transcript'] ?? '',
    audioPath: json['audioPath'],
    audioFormat: json['audioFormat'],
    status: json['status'],
    error: json['error'],
    drafts: (json['drafts'] as List? ?? [])
        .map((d) => CaptureDraft.fromJson(Map<String, dynamic>.from(d)))
        .toList(),
    source: json['source'],
    day: json['day'] == null ? null : DateTime.parse(json['day']),
  );
}
