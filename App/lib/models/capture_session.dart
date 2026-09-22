import 'package:agenda/models/task.dart';
import 'package:agenda/models/task_draft.dart';
import 'package:uuid/uuid.dart';

class CaptureDraft {
  final String id;
  final Task task;
  final List<String> questions;
  final bool confirmed;
  final int? savedTaskId;
  final bool removed;

  const CaptureDraft(
      {required this.id,
      required this.task,
      this.questions = const [],
      this.confirmed = true,
      this.savedTaskId,
      this.removed = false});

  factory CaptureDraft.fromAI(TaskDraft draft) => CaptureDraft(
      id: const Uuid().v4(),
      task: Task(
          title: draft.title,
          kind: draft.kind,
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
          notes: draft.notes),
      questions: draft.questions,
      confirmed: draft.questions.isEmpty);

  bool get pending => savedTaskId == null && !removed;
  bool get ready => pending && confirmed;

  CaptureDraft copyWith(
          {Task? task, bool? confirmed, int? savedTaskId, bool? removed}) =>
      CaptureDraft(
          id: id,
          task: task ?? this.task,
          questions: questions,
          confirmed: confirmed ?? this.confirmed,
          savedTaskId: savedTaskId ?? this.savedTaskId,
          removed: removed ?? this.removed);

  Map<String, dynamic> toJson() => {
        'id': id,
        'task': task.toMap(),
        'questions': questions,
        'confirmed': confirmed,
        'savedTaskId': savedTaskId,
        'removed': removed
      };

  factory CaptureDraft.fromJson(Map<String, dynamic> json) => CaptureDraft(
      id: json['id'],
      task: Task.fromMap(Map<String, dynamic>.from(json['task'])),
      questions: List<String>.from(json['questions'] ?? []),
      confirmed: json['confirmed'] == true,
      savedTaskId: json['savedTaskId'],
      removed: json['removed'] == true);
}

class CaptureSession {
  final String id;
  final String ownerKey;
  final DateTime capturedAt;
  final String timezone;
  final String kind;
  final String text;
  final String transcript;
  final String? audioPath;
  final String status;
  final String? error;
  final List<CaptureDraft> drafts;

  const CaptureSession(
      {required this.id,
      required this.ownerKey,
      required this.capturedAt,
      required this.timezone,
      this.kind = 'task',
      this.text = '',
      this.transcript = '',
      this.audioPath,
      this.status = 'editing',
      this.error,
      this.drafts = const []});

  bool get terminal => status == 'saved' || status == 'discarded';
  List<CaptureDraft> get remaining => drafts.where((d) => d.pending).toList();
  List<CaptureDraft> get ready => drafts.where((d) => d.ready).toList();

  CaptureSession copyWith(
          {String? text,
          String? transcript,
          String? audioPath,
          String? status,
          String? error,
          String? kind,
          List<CaptureDraft>? drafts}) =>
      CaptureSession(
          id: id,
          ownerKey: ownerKey,
          capturedAt: capturedAt,
          timezone: timezone,
          kind: kind ?? this.kind,
          text: text ?? this.text,
          transcript: transcript ?? this.transcript,
          audioPath: audioPath ?? this.audioPath,
          status: status ?? this.status,
          error: error,
          drafts: drafts ?? this.drafts);

  Map<String, dynamic> toJson() => {
        'id': id,
        'ownerKey': ownerKey,
        'capturedAt': capturedAt.toUtc().toIso8601String(),
        'timezone': timezone,
        'kind': kind,
        'text': text,
        'transcript': transcript,
        'audioPath': audioPath,
        'status': status,
        'error': error,
        'drafts': drafts.map((d) => d.toJson()).toList()
      };

  factory CaptureSession.fromJson(Map<String, dynamic> json) => CaptureSession(
      id: json['id'],
      ownerKey: json['ownerKey'],
      capturedAt: DateTime.parse(json['capturedAt']),
      timezone: json['timezone'],
      kind: json['kind'] ?? 'task',
      text: json['text'] ?? '',
      transcript: json['transcript'] ?? '',
      audioPath: json['audioPath'],
      status: json['status'],
      error: json['error'],
      drafts: (json['drafts'] as List? ?? [])
          .map((d) => CaptureDraft.fromJson(Map<String, dynamic>.from(d)))
          .toList());
}
