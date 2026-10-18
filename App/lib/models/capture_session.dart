import 'package:agenda/models/capture_command.dart';
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

  /// The project the task goes to once the confirming tap creates it, by
  /// name: a `project` command of the same dictation, or `Crear «X»`.
  final String? newProject;

  /// The project as said, which doesn't exist: the card offers to create it
  /// or to pick another, and the task waits for that tap.
  final String? projectSuggestion;

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
    this.newProject,
    this.projectSuggestion,
  });

  /// A project made in the same dictation has nobody to assign yet, so a
  /// person named for it leaves nothing to decide: the card only says so.
  /// A project that doesn't exist always waits for a choice.
  static bool _reviewed(TaskDraft draft) {
    if (draft.projectSuggestion != null) return false;
    if (draft.newProject != null) {
      return draft.assignmentIssues.every(
        (issue) => issue == 'member_not_available',
      );
    }
    return draft.assignmentIssues.isEmpty;
  }

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
    assignmentReviewed: _reviewed(draft),
    confirmed: draft.questions.isEmpty && draft.clarifications.isEmpty,
    newProject: draft.newProject,
    projectSuggestion: draft.projectSuggestion,
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
    String? newProject,
    bool clearNewProject = false,
    bool clearProjectSuggestion = false,
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
    newProject: clearNewProject ? null : newProject ?? this.newProject,
    projectSuggestion: clearProjectSuggestion ? null : projectSuggestion,
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
    if (newProject != null) 'newProject': newProject,
    if (projectSuggestion != null) 'projectSuggestion': projectSuggestion,
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
    newProject: json['newProject'] as String?,
    projectSuggestion: json['projectSuggestion'] as String?,
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

  /// The dictation's commands (create a project, find, change or delete a
  /// task), in the order they were said, with their cards' choices.
  final List<CaptureCommand> commands;
  final String? projectId;

  /// Where the first words came from: `speech` (the recognizer or recorded
  /// audio), `typed` (the keyboard) or `shared` (a share, sent to the server
  /// as typed). Null until words arrive.
  final String? source;

  /// The later day capture was opened for (Calendar's selected day, the
  /// timeline's day): a task understood with no date and no deadline gets it.
  final DateTime? day;

  /// The speech language chosen in Voz (e.g. `ca-ES`) for spoken captures,
  /// so online transcription hears that language. Null for typed captures.
  final String? language;

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
    this.commands = const [],
    this.source,
    this.day,
    this.language,
  });

  bool get terminal => status == 'saved' || status == 'discarded';
  List<CaptureDraft> get remaining => drafts.where((d) => d.pending).toList();
  List<CaptureDraft> get ready => drafts.where((d) => d.ready).toList();

  /// The words were understood: tasks, notes or commands to show. A result
  /// that is only commands has no drafts.
  bool get hasResult => drafts.isNotEmpty || commands.isNotEmpty;

  CaptureSession copyWith({
    String? text,
    String? transcript,
    String? audioPath,
    String? audioFormat,
    String? status,
    String? error,
    String? kind,
    List<CaptureDraft>? drafts,
    List<CaptureCommand>? commands,
    String? source,
    String? language,
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
    commands: commands ?? this.commands,
    source: source ?? this.source,
    day: day,
    language: language ?? this.language,
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
    if (commands.isNotEmpty)
      'commands': commands.map((c) => c.toJson()).toList(),
    'source': source,
    'day': day == null ? null : Task.dateKey(day!),
    if (language != null) 'language': language,
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
    commands: [
      for (final item in json['commands'] as List? ?? [])
        if (item is Map)
          ?CaptureCommand.fromJson(Map<String, dynamic>.from(item)),
    ],
    source: json['source'],
    day: json['day'] == null ? null : DateTime.parse(json['day']),
    language: json['language'],
  );
}
