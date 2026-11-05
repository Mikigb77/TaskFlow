import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import 'package:agenda/models/capture_session.dart';
import 'package:agenda/models/checklist_item.dart';
import 'package:agenda/models/task.dart';
import 'package:agenda/models/meeting.dart';
import 'package:agenda/providers/auth_provider.dart';
import 'package:agenda/providers/calendar_focus_provider.dart';
import 'package:agenda/providers/regional_provider.dart';
import 'package:agenda/providers/task_lists_provider.dart';
import 'package:agenda/providers/task_provider.dart';
import 'package:agenda/screens/voice_task_screen.dart';
import 'package:agenda/services/capture_store.dart';
import 'package:agenda/services/meeting_note.dart';
import 'package:agenda/services/quick_schedule_parser.dart';
import 'package:agenda/services/task_database.dart';

/// Whether [note] offers «Crear tarea»: a note made from a meeting on this
/// phone ([meetingNotes], its ids) with steps still open, its to-dos
/// (MN-22). Other notes with a checklist, such as a recipe, don't: the
/// owner's decision of 2026-11-04 (D1, UX-2722).
bool noteMakesTask(Task note, Set<int> meetingNotes) =>
    note.isNote &&
    note.id != null &&
    meetingNotes.contains(note.id) &&
    note.checklist.any((step) => !step.done());

/// The signed-in account's notes made from a meeting on this phone. Kept,
/// and read before any note's page opens (main_shell.dart), so the page's
/// main button is right from its first frame (UX-2903); read again when a
/// note is added to or removed from the task list, so a meeting's note
/// saved since offers «Crear tarea». The last marks stay while it does.
final meetingNotesProvider = FutureProvider<Set<int>>((ref) async {
  // Changes only when a note comes or goes, not on every task edit.
  ref.watch(
    taskProvider.select(
      (state) => state.value
          ?.where((task) => task.isNote && task.id != null)
          .map((task) => task.id)
          .join(','),
    ),
  );
  try {
    return await MeetingNoteMarks.read(
      ref.watch(meetingNoteMarksDatabaseProvider),
      ref.watch(captureOwnerProvider),
    );
  } catch (_) {
    // Unread: no note offers «Crear tarea».
    return const {};
  }
});

/// The database [meetingNotesProvider] reads; tests replace it.
final meetingNoteMarksDatabaseProvider = Provider((ref) => TaskDatabase());

/// The tasks «Crear tareas» made from [note] on this phone that still exist
/// (done or not): the note then offers «Ver tarea» or «Ver tareas»
/// (UX-2702).
List<Task> noteMadeTasks(WidgetRef ref, Task note) {
  final ids = ref.watch(noteTasksProvider).value?[note.id];
  if (ids == null || ids.isEmpty) return const [];
  final tasks = ref.watch(taskProvider).value ?? const <Task>[];
  return [
    for (final id in ids) ?tasks.firstWhereOrNull((task) => task.id == id),
  ];
}

/// «Ver tareas»: Calendar, on the earliest day of [tasks], with them lit,
/// as after saving them from the pending list.
void showNoteTasks(BuildContext context, List<Task> tasks) {
  final container = ProviderScope.containerOf(context, listen: false);
  final days = [
    for (final task in tasks)
      if (task.displayDate ?? task.deadline case final day?) Task.day(day),
  ]..sort();
  container.read(calendarFocusProvider.notifier).state = CalendarFocus(
    days.firstOrNull,
    {for (final task in tasks) task.id!},
    showCalendar: true,
    undated: tasks.any((task) => task.dueDate == null && task.deadline == null),
  );
  Navigator.of(context).popUntil((route) => route.isFirst);
}

/// Remembers, on this phone only, the tasks each note made with «Crear
/// tareas». Never synced or sent: on another phone the note offers «Crear
/// tareas» again.
class NoteTaskLinks {
  NoteTaskLinks(this.database);
  final TaskDatabase database;

  // Per-account preferences are scoped `<kind>:<owner>`, so deleting the
  // account erases this too.
  static String _scope(String owner) => 'noteTasks:$owner';

  /// Each note's id, with the ids of the tasks it made (one, before notes
  /// made several).
  Future<Map<int, List<int>>> read(String owner) async {
    final rows = await (await database.database).query(
      'app_preferences',
      where: 'scope = ?',
      whereArgs: [_scope(owner)],
    );
    if (rows.isEmpty) return const {};
    final data = jsonDecode(rows.single['data'] as String);
    if (data is! Map) return const {};
    return {
      for (final entry in data.entries)
        if (int.tryParse('${entry.key}') case final note?)
          if (entry.value is int)
            note: [entry.value as int]
          else if (entry.value is List)
            note: [
              for (final id in entry.value as List)
                if (id is int) id,
            ],
    };
  }

  Future<void> link(String owner, int noteId, List<int> taskIds) async {
    final db = await database.database;
    await db.transaction((tx) async {
      final rows = await tx.query(
        'app_preferences',
        where: 'scope = ?',
        whereArgs: [_scope(owner)],
      );
      final data = rows.isEmpty
          ? null
          : jsonDecode(rows.single['data'] as String);
      await tx.insert('app_preferences', {
        'scope': _scope(owner),
        'data': jsonEncode({if (data is Map) ...data, '$noteId': taskIds}),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    });
  }
}

final noteTaskLinksProvider = Provider((ref) => NoteTaskLinks(TaskDatabase()));

/// The signed-in account's note → tasks links on this phone.
final noteTasksProvider = FutureProvider<Map<int, List<int>>>((ref) async {
  try {
    return await ref
        .watch(noteTaskLinksProvider)
        .read(ref.watch(captureOwnerProvider));
  } catch (_) {
    // Unread: the notes offer «Crear tarea».
    return const {};
  }
});

/// «Crear tareas» (MN-22): the capture's review, with one task for each of
/// [note]'s open lines (a meeting's tasks), each with its own steps, all
/// ticked to go in, so the person unticks the steps or removes the tasks
/// they don't want and can change a day before saving. A line's «when» gives
/// its day, read against the meeting's. Nothing is saved until they confirm
/// there. Leaving the review closes it with no question: the note still
/// holds everything, and the capture never waits in `Sin guardar` (source
/// 'note', UX-2706). Once saved, a single new task's page opens over the
/// note, which then offers «Ver tarea» («Ver tareas» for several).
Future<void> createTaskFromNote(BuildContext context, Task note) async {
  final container = ProviderScope.containerOf(context, listen: false);
  final store = container.read(captureStoreProvider);
  final owner = container.read(captureOwnerProvider);
  final projectId =
      note.listId != null && container.read(listCanEditProvider(note.listId))
      ? note.listId
      : null;
  try {
    await container.read(regionalProvider.notifier).ready;
  } catch (_) {
    /* The account's zone then. */
  }
  MeetingNoteTasks? tasks;
  try {
    if (note.id case final id?) {
      tasks = await MeetingNoteMarks.tasks(
        container.read(meetingNoteMarksDatabaseProvider),
        owner,
        id,
      );
    }
  } catch (_) {
    /* Each line becomes a task without steps. */
  }
  final session = await store.create(
    owner,
    _zone(container),
    text: note.title,
    projectId: projectId,
    source: 'note',
  );
  final drafts = [
    for (final line in note.checklist)
      if (!line.done())
        CaptureDraft(
          id: const Uuid().v4(),
          task: noteLineTask(
            line,
            tasks?.tasks[line.id],
            day: tasks?.day,
            projectId: projectId,
          ),
        ),
  ];
  await store.update(
    session.copyWith(
      status: 'ready',
      // The review's «Texto original»: the note, to look back at.
      transcript: note.notes?.trim().isNotEmpty == true
          ? note.notes
          : note.title,
      drafts: drafts,
    ),
  );
  if (!context.mounted) return;
  await showCaptureSheet(
    context,
    captureId: session.id,
    startListening: false,
    useScope: false,
  );
  // Saved: the note remembers its tasks.
  final noteId = note.id;
  if (noteId == null) return;
  try {
    final saved = await store.read(session.id, owner);
    final taskIds = saved?.status == 'saved'
        ? saved!.drafts.map((d) => d.savedTaskId).nonNulls.toList()
        : const <int>[];
    if (taskIds.isEmpty) return;
    await container.read(noteTaskLinksProvider).link(owner, noteId, taskIds);
    container.invalidate(noteTasksProvider);
  } catch (_) {
    /* The note offers «Crear tareas» again. */
  }
}

/// The task one of a meeting note's lines becomes: its [task] as the server
/// wrote it when the line still reads as it did, with its steps ticked to go
/// in, and the day its «when» says, read against the meeting's [day]. The
/// words of a day read whole leave the title; any others stay. A line the
/// person reworded, or one with no [task] (a note from before tasks had
/// steps), keeps its words and has no steps.
Task noteLineTask(
  ChecklistItem line,
  MeetingTask? task, {
  DateTime? day,
  String? projectId,
}) {
  final asSaved = task != null && line.title == meetingTaskLine(task);
  final when = asSaved ? task.when : null;
  final found = when == null
      ? null
      : QuickScheduleParser.parse(when, day ?? DateTime.now());
  // A bare «a las 5» could be morning or afternoon: no day is guessed.
  final dated = found != null && found.ambiguousHour == null;
  final deadline = dated && found.isDeadline;
  final title = !asSaved
      ? line.title
      : dated && found.title.trim().isEmpty
      ? [task.title, ?task.who].join(' · ')
      : line.title;
  return Task(
    title: title,
    priority: 1,
    listId: projectId,
    dueDate: dated && !deadline ? found.date : null,
    hasTime: dated && !deadline && found.hasTime,
    deadline: deadline ? found.date : null,
    deadlineHasTime: deadline && found.hasTime,
    reminderAnchor: deadline ? 'deadline' : 'planned',
    checklist: [
      if (asSaved)
        for (final step in task.steps)
          // Ticked: chosen to go in. Saved as steps still to do.
          ChecklistItem(title: step, completed: true),
    ],
  );
}

/// The capture's zone, as the task form picks it: the one chosen in
/// Ajustes, then the account's, then UTC.
String _zone(ProviderContainer container) {
  final chosen = container.read(regionalProvider).captureTimezone;
  if (CaptureTimezone.valid(chosen)) return chosen!;
  final account = container.read(authProvider).account?.timezone;
  return CaptureTimezone.valid(account) ? account! : 'UTC';
}
