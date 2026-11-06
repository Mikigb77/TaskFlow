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
/// phone ([meetingNotes], its ids) with lines (its tasks) still open that
/// made no task yet ([made], by line id, from [NoteTaskLinks]) (MN-22).
/// Other notes with a checklist, such as a recipe, don't: the owner's
/// decision of 2026-11-04 (D1, UX-2722).
bool noteMakesTask(
  Task note,
  Set<int> meetingNotes, [
  Map<String, int> made = const {},
]) =>
    note.isNote &&
    note.id != null &&
    meetingNotes.contains(note.id) &&
    noteLinesToMake(note, made).isNotEmpty;

/// [note]'s open lines that made no task yet ([made], by line id): the ones
/// «Crear tareas» turns into tasks (UX-3102). A note that made one task
/// from all its lines, before lines were tasks, has none left.
List<ChecklistItem> noteLinesToMake(Task note, Map<String, int> made) =>
    made.containsKey(NoteTaskLinks.wholeNote)
    ? const []
    : [
        for (final line in note.checklist)
          if (!line.done() && !made.containsKey(line.id)) line,
      ];

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

/// The tasks «Crear tareas» made from [note] on this phone that still
/// exist (done or not), by the line that made each ([NoteTaskLinks.wholeNote]
/// for a note's one task from before lines were tasks): the note then shows
/// each line's task, and offers «Ver tarea» or «Ver tareas» (UX-2702,
/// UX-3101).
Map<String, Task> noteMadeTasks(WidgetRef ref, Task note) {
  final links = ref.watch(noteTasksProvider).value?[note.id];
  if (links == null || links.isEmpty) return const {};
  final tasks = ref.watch(taskProvider).value ?? const <Task>[];
  return {
    for (final entry in links.entries)
      entry.key: ?tasks.firstWhereOrNull((task) => task.id == entry.value),
  };
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

  /// The line key of a note's one task, made from all its lines before
  /// lines were tasks.
  static const wholeNote = '';

  /// Each note's id, with the task each of its lines made, by line id
  /// ([wholeNote] for a note's one task from before).
  Future<Map<int, Map<String, int>>> read(String owner) async {
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
            note: {wholeNote: entry.value as int}
          else if (entry.value is Map)
            note: {
              for (final line in (entry.value as Map).entries)
                if (line.value is int) '${line.key}': line.value as int,
            },
    };
  }

  /// Adds the tasks [lineTasks] (by line id) made from note [noteId] to
  /// those it made before.
  Future<void> link(
    String owner,
    int noteId,
    Map<String, int> lineTasks,
  ) async {
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
        'data': jsonEncode({
          if (data is Map) ...data,
          '$noteId': {
            if (data is Map && data['$noteId'] is Map)
              ...data['$noteId'] as Map,
            ...lineTasks,
          },
        }),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    });
  }
}

final noteTaskLinksProvider = Provider((ref) => NoteTaskLinks(TaskDatabase()));

/// The signed-in account's note → tasks links on this phone.
final noteTasksProvider = FutureProvider<Map<int, Map<String, int>>>((
  ref,
) async {
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
Future<void> createTaskFromNote(
  BuildContext context,
  Task note, {
  // The lines to make into tasks: by default every open line.
  List<ChecklistItem>? lines,
}) async {
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
  // Each card's line, so the note knows which line made which task.
  final lineOf = <String, String>{};
  final drafts = <CaptureDraft>[];
  for (final line in lines ?? noteLinesToMake(note, const {})) {
    final id = const Uuid().v4();
    lineOf[id] = line.id;
    drafts.add(
      CaptureDraft(
        id: id,
        task: noteLineTask(
          line,
          tasks?.tasks[line.id],
          day: tasks?.day,
          projectId: projectId,
        ),
      ),
    );
  }
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
    final made = saved?.status == 'saved'
        ? {
            for (final draft in saved!.drafts)
              if ((lineOf[draft.id], draft.savedTaskId) case (
                final line?,
                final task?,
              ))
                line: task,
          }
        : const <String, int>{};
    if (made.isEmpty) return;
    await container.read(noteTaskLinksProvider).link(owner, noteId, made);
    container.invalidate(noteTasksProvider);
  } catch (_) {
    /* The note offers «Crear tareas» again. */
  }
}

/// The task one of a meeting note's lines becomes: the line's words, with
/// the day they say read against the meeting's [day] and left out of the
/// title, and its [task]'s steps (as the server wrote them, kept by the
/// line's id even when the person reworded it), ticked to go in (UX-3106).
/// A day already gone by [today] is not set: the words stay in the title,
/// so a task made a week later isn't saved overdue (UX-3105). A bare hour
/// («a las 5») stays in the title; its day still applies (UX-3104).
Task noteLineTask(
  ChecklistItem line,
  MeetingTask? task, {
  DateTime? day,
  DateTime? today,
  String? projectId,
}) {
  final now = Task.day(today ?? DateTime.now());
  final found = QuickScheduleParser.parse(
    line.title,
    day ?? now,
    keepAmbiguousHour: true,
  );
  final dated = found != null && !Task.day(found.date).isBefore(now);
  final deadline = dated && found.isDeadline;
  // The words left once the day's are out, without a dangling « · ».
  final rest = !dated
      ? ''
      : found.title
            .replaceAll(RegExp(r'(\s*·\s*)+$'), '')
            .replaceAll(RegExp(r'^(\s*·\s*)+'), '')
            .replaceAll(RegExp(r'\s*·\s*(·\s*)+'), ' · ')
            .trim();
  return Task(
    title: rest.isEmpty ? line.title : rest,
    priority: 1,
    listId: projectId,
    dueDate: dated && !deadline ? found.date : null,
    hasTime: dated && !deadline && found.hasTime,
    deadline: deadline ? found.date : null,
    deadlineHasTime: deadline && found.hasTime,
    reminderAnchor: deadline ? 'deadline' : 'planned',
    checklist: [
      for (final step in task?.steps ?? const <String>[])
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
