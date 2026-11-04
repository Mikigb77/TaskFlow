import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import 'package:agenda/models/capture_session.dart';
import 'package:agenda/models/checklist_item.dart';
import 'package:agenda/models/task.dart';
import 'package:agenda/providers/auth_provider.dart';
import 'package:agenda/providers/regional_provider.dart';
import 'package:agenda/providers/task_lists_provider.dart';
import 'package:agenda/providers/task_provider.dart';
import 'package:agenda/screens/voice_task_screen.dart';
import 'package:agenda/services/capture_store.dart';
import 'package:agenda/services/meeting_note.dart';
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

/// The task «Crear tarea» made from [note] on this phone, while it exists
/// (done or not): the note then offers «Ver tarea» (UX-2702).
Task? noteMadeTask(WidgetRef ref, Task note) {
  final id = ref.watch(noteTasksProvider).value?[note.id];
  if (id == null) return null;
  return ref
      .watch(taskProvider)
      .value
      ?.firstWhereOrNull((task) => task.id == id);
}

/// Remembers, on this phone only, the task each note made with «Crear
/// tarea». Never synced or sent: on another phone the note offers «Crear
/// tarea» again.
class NoteTaskLinks {
  NoteTaskLinks(this.database);
  final TaskDatabase database;

  // Per-account preferences are scoped `<kind>:<owner>`, so deleting the
  // account erases this too.
  static String _scope(String owner) => 'noteTasks:$owner';

  /// Each note's id, with the id of the task it made.
  Future<Map<int, int>> read(String owner) async {
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
          if (entry.value is int) note: entry.value as int,
    };
  }

  Future<void> link(String owner, int noteId, int taskId) async {
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
        'data': jsonEncode({if (data is Map) ...data, '$noteId': taskId}),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    });
  }
}

final noteTaskLinksProvider = Provider((ref) => NoteTaskLinks(TaskDatabase()));

/// The signed-in account's note → task links on this phone.
final noteTasksProvider = FutureProvider<Map<int, int>>((ref) async {
  try {
    return await ref
        .watch(noteTaskLinksProvider)
        .read(ref.watch(captureOwnerProvider));
  } catch (_) {
    // Unread: the notes offer «Crear tarea».
    return const {};
  }
});

/// «Crear tarea» (MN-22): the capture's review, with one task titled like
/// [note] and its open steps as the checklist, all ticked to go in, so the
/// person unticks the ones they don't want and can set a day before
/// saving. Nothing is saved until they confirm there. Leaving the review
/// closes it with no question: the note still holds everything, and the
/// capture never waits in `Sin guardar` (source 'note', UX-2706). Once
/// saved, the new task's page opens over the note, which then offers «Ver
/// tarea».
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
  final session = await store.create(
    owner,
    _zone(container),
    text: note.title,
    projectId: projectId,
    source: 'note',
  );
  final drafts = [
    CaptureDraft(
      id: const Uuid().v4(),
      task: Task(
        title: note.title,
        priority: 1,
        listId: projectId,
        checklist: [
          for (final step in note.checklist)
            // Ticked: chosen to go in. Saved as steps still to do.
            if (!step.done()) ChecklistItem(title: step.title, completed: true),
        ],
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
  // Saved: the note remembers its task.
  final noteId = note.id;
  if (noteId == null) return;
  try {
    final saved = await store.read(session.id, owner);
    final taskId = saved?.status == 'saved'
        ? saved!.drafts.map((d) => d.savedTaskId).nonNulls.firstOrNull
        : null;
    if (taskId == null) return;
    await container.read(noteTaskLinksProvider).link(owner, noteId, taskId);
    container.invalidate(noteTasksProvider);
  } catch (_) {
    /* The note offers «Crear tarea» again. */
  }
}

/// The capture's zone, as the task form picks it: the one chosen in
/// Ajustes, then the account's, then UTC.
String _zone(ProviderContainer container) {
  final chosen = container.read(regionalProvider).captureTimezone;
  if (CaptureTimezone.valid(chosen)) return chosen!;
  final account = container.read(authProvider).account?.timezone;
  return CaptureTimezone.valid(account) ? account! : 'UTC';
}
