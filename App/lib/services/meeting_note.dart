import 'dart:convert';

import 'package:sqflite/sqflite.dart';
import 'package:agenda/services/task_database.dart';
import 'package:agenda/l10n/meeting_copy.dart';
import 'package:agenda/models/checklist_item.dart';
import 'package:agenda/models/meeting.dart';
import 'package:agenda/models/task.dart';
import 'package:agenda/services/notification_service.dart';

/// The words a meeting's note uses around the server's text, in the
/// meeting's language. Every one is optional: one left null is left out.
class MeetingNoteLabels {
  const MeetingNoteLabels({
    this.decisions,
    this.openQuestions,
    this.chapters,
    this.startMissing,
    this.untitled,
    this.chapterRange,
    this.meetingLine,
    this.steps,
  });

  /// The heading over each task's steps.
  final String? steps;

  /// The heading over the decisions.
  final String? decisions;

  /// The heading over the open questions.
  final String? openQuestions;

  /// The heading over the chapter lines.
  final String? chapters;

  /// The line that opens a note whose start expired on the server (MN-28).
  final String? startMissing;

  /// The title of a meeting the server gave none (no speech).
  final String? untitled;

  /// A chapter's minutes, as its line starts: «Minutos 0–30».
  final String Function(int startMinute, int endMinute)? chapterRange;

  /// The line that opens the note: when the meeting was and how long, as
  /// «Reunión del martes 3 nov, 10:15 · 52 min» (UX-2710).
  final String Function(DateTime startedAt, Duration length)? meetingLine;

  /// No words of the app's own: the note holds only the server's text.
  static const none = MeetingNoteLabels();
}

/// What the meeting core asks of the screens, in the app and in the
/// background worker alike: the note's words in the meeting's language,
/// and the "notes ready" notification. Tests replace them.
abstract final class MeetingHooks {
  /// The note's labels for a meeting in [language] (BCP-47, may be null).
  static MeetingNoteLabels Function(String? language) labels =
      meetingNoteLabels;

  /// Called once a meeting's notes are saved as note [noteId], in either
  /// isolate: the "notes ready" notification (MN-11).
  static Future<void> Function(SavedMeetingNote saved) notesReady =
      TaskReminders.showMeetingNotesReady;

  /// Meeting [meetingId]'s notes were shown in the app: its "notes ready"
  /// notification goes (UX-2811).
  static Future<void> Function(String meetingId) notesSeen =
      TaskReminders.clearMeetingNotesReady;

  /// Note [noteId]'s page opened: the "notes ready" that opens it goes
  /// (UX-2811).
  static Future<void> Function(int noteId) noteOpened =
      TaskReminders.clearMeetingNoteReady;
}

/// A meeting whose notes were just saved as a note.
class SavedMeetingNote {
  const SavedMeetingNote({
    required this.meetingId,
    required this.ownerKey,
    required this.noteId,
    required this.title,
    this.language,
  });
  final String meetingId;
  final String ownerKey;
  final int noteId;
  final String title;
  final String? language;
}

/// A task as a checklist line of its note: its words, then who and when if
/// they were said (`Send the pilot quote · Miki · Friday`).
String meetingTaskLine(MeetingTask task) =>
    [task.title, ?task.who, ?task.when].join(' · ');

/// The meeting's notes as an ordinary note (MN-21): the title the server
/// wrote, a body of the meeting's date and length (from [startedAt], local,
/// and [length]), the summary, decisions, open questions and one line per
/// chapter with its notes, and one checklist line per task, so one tap can
/// turn them into tasks (MN-22). Each task's steps are in the body, under
/// its line's words, and [MeetingNoteTasks] keeps them for «Crear tareas».
Task meetingNote(
  MeetingResult result, {
  required MeetingNoteLabels labels,
  String? projectId,
  DateTime? startedAt,
  Duration length = Duration.zero,
}) {
  final sections = <String>[];
  if (startedAt != null && labels.meetingLine != null) {
    sections.add(labels.meetingLine!(startedAt, length));
  }
  if (result.startMissing && labels.startMissing != null) {
    sections.add(labels.startMissing!);
  }
  if (result.summary.isNotEmpty) sections.add(result.summary);
  String list(String? heading, List<String> lines) =>
      [?heading, for (final line in lines) '• $line'].join('\n');
  final steps = [
    for (final task in result.tasks)
      if (task.steps.isNotEmpty) list(task.title, task.steps),
  ];
  if (steps.isNotEmpty) {
    sections.add([?labels.steps, ...steps].join('\n\n'));
  }
  if (result.decisions.isNotEmpty) {
    sections.add(list(labels.decisions, result.decisions));
  }
  if (result.openQuestions.isNotEmpty) {
    sections.add(list(labels.openQuestions, result.openQuestions));
  }
  final chapters = [
    for (final chapter in result.chapters)
      [
        [
          ?labels.chapterRange?.call(chapter.startMinute, chapter.endMinute),
          if (chapter.title.trim().isNotEmpty) chapter.title.trim(),
        ].join(' · '),
        if (chapter.notes.isNotEmpty) chapter.notes,
      ].join('\n'),
  ];
  if (chapters.isNotEmpty) {
    sections.add([?labels.chapters, ...chapters].join('\n\n'));
  }
  final title = result.title.isNotEmpty
      ? result.title
      : labels.untitled ??
            (result.summary.isNotEmpty
                ? result.summary.split(RegExp(r'(?<=[.!?])\s')).first
                : '');
  final body = sections.join('\n\n');
  return Task(
    kind: 'note',
    title: title.length > 200 ? title.substring(0, 200) : title,
    priority: 1,
    listId: projectId,
    notes: body.isEmpty ? null : body,
    checklist: [
      for (final task in result.tasks)
        ChecklistItem(title: meetingTaskLine(task)),
    ],
  );
}

/// What «Crear tareas» needs of a meeting's note and the note doesn't hold:
/// each line's task as the server wrote it, by its checklist item's id, with
/// its steps, and the day the meeting was, to read its «when» against.
class MeetingNoteTasks {
  const MeetingNoteTasks({required this.tasks, this.day});

  /// The meeting's [note] (made by [meetingNote] from [result]) and its
  /// tasks, line by line; [startedAt] is local.
  factory MeetingNoteTasks.of(
    Task note,
    MeetingResult result, {
    DateTime? startedAt,
  }) => MeetingNoteTasks(
    tasks: {
      for (final (i, item) in note.checklist.indexed)
        if (i < result.tasks.length) item.id: result.tasks[i],
    },
    day: startedAt == null ? null : Task.day(startedAt),
  );

  final Map<String, MeetingTask> tasks;
  final DateTime? day;

  Map<String, Object?> toJson() => {
    if (day != null) 'day': Task.dateKey(day!),
    'tasks': {for (final e in tasks.entries) e.key: e.value.toJson()},
  };

  static MeetingNoteTasks? fromJson(Object? json) {
    if (json is! Map || json['tasks'] is! Map) return null;
    final day = DateTime.tryParse('${json['day']}');
    return MeetingNoteTasks(
      tasks: {
        for (final entry in (json['tasks'] as Map).entries)
          '${entry.key}': ?MeetingTask.fromJson(entry.value),
      },
      day: day == null ? null : Task.day(day),
    );
  }
}

/// Marks, on this phone only, the notes made from a meeting, so only they
/// offer «Crear tarea» (D1). Never synced or sent: on another phone a
/// meeting's note doesn't offer it.
class MeetingNoteMarks {
  // Per-account preferences are scoped `<kind>:<owner>`, so deleting the
  // account erases this too.
  static String _scope(String owner) => 'meetingNotes:$owner';

  static Set<int> _ids(List<Map<String, Object?>> rows) {
    if (rows.isEmpty) return const {};
    final data = jsonDecode(rows.single['data'] as String);
    if (data is! List) return const {};
    return {
      for (final id in data)
        if (id is int) id,
    };
  }

  // Each note's tasks, for «Crear tareas»: `{noteId: MeetingNoteTasks}`.
  static String _tasksScope(String owner) => 'meetingTasks:$owner';

  /// Marks note [noteId] of [owner] as a meeting's, inside [tx], the
  /// transaction that saves it, with its [tasks] when known.
  static Future<void> add(
    DatabaseExecutor tx,
    String owner,
    int noteId, {
    MeetingNoteTasks? tasks,
  }) async {
    if (tasks != null && tasks.tasks.isNotEmpty) {
      final rows = await tx.query(
        'app_preferences',
        where: 'scope = ?',
        whereArgs: [_tasksScope(owner)],
      );
      final data = rows.isEmpty
          ? null
          : jsonDecode(rows.single['data'] as String);
      await tx.insert('app_preferences', {
        'scope': _tasksScope(owner),
        'data': jsonEncode({
          if (data is Map) ...data,
          '$noteId': tasks.toJson(),
        }),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    final ids = _ids(
      await tx.query(
        'app_preferences',
        where: 'scope = ?',
        whereArgs: [_scope(owner)],
      ),
    );
    await tx.insert('app_preferences', {
      'scope': _scope(owner),
      'data': jsonEncode([...ids, noteId]),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// The ids of [owner]'s notes made from a meeting on this phone.
  static Future<Set<int>> read(TaskDatabase database, String owner) async =>
      _ids(
        await (await database.database).query(
          'app_preferences',
          where: 'scope = ?',
          whereArgs: [_scope(owner)],
        ),
      );

  /// Note [noteId]'s tasks, or null when this phone has none for it, such
  /// as a note saved before tasks had steps.
  static Future<MeetingNoteTasks?> tasks(
    TaskDatabase database,
    String owner,
    int noteId,
  ) async {
    final rows = await (await database.database).query(
      'app_preferences',
      where: 'scope = ?',
      whereArgs: [_tasksScope(owner)],
    );
    if (rows.isEmpty) return null;
    final data = jsonDecode(rows.single['data'] as String);
    return data is Map ? MeetingNoteTasks.fromJson(data['$noteId']) : null;
  }
}
