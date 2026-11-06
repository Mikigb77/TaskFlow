// P318: «Crear tarea» from a note, in memory: a task list that saving adds
// to, editing changes, and Deshacer or Eliminar take from, and the phone's
// note → task links.
import 'dart:convert';

import 'package:agenda/models/task.dart';
import 'package:agenda/providers/task_provider.dart';
import 'package:agenda/services/meeting_note.dart';
import 'package:agenda/services/task_database.dart';
import 'package:agenda/widgets/note_task.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:sqflite/sqflite.dart';

import 'design_fixtures.dart';

/// A task list in memory: added tasks get new ids, deleted ones go.
class NoteTaskList extends TaskNotifier {
  NoteTaskList(List<Task> items) : items = [...items], super(MemoryTasks());
  final List<Task> items;
  int _next = 500;

  @override
  Future<void> loadTasks() async => state = AsyncValue.data([...items]);
  @override
  Future<void> showLocal() => loadTasks();
  @override
  Future<int> addTask(Task task) async {
    final id = _next++;
    items.add(task.copyWith(id: id));
    await loadTasks();
    return id;
  }

  @override
  Future<void> addTasks(List<Task> tasks) async {
    for (final task in tasks) {
      items.add(task.copyWith(id: _next++));
    }
    await loadTasks();
  }

  @override
  Future<void> updateTask(Task task) async {
    final at = items.indexWhere((item) => item.id == task.id);
    if (at >= 0) items[at] = task;
    await loadTasks();
  }

  @override
  Future<void> deleteTask(int id, {bool sync = true}) async {
    items.removeWhere((task) => task.id == id);
    await loadTasks();
  }

  @override
  Future<void> restoreTask(Task task) async {
    items.add(task);
    await loadTasks();
  }
}

/// The phone's note → task links, in memory.
class MemoryNoteTaskLinks extends NoteTaskLinks {
  /// [links]: each note's one task, for the whole note; [lines]: notes
  /// whose lines made tasks, each line's task by its id (UX-3101).
  MemoryNoteTaskLinks([
    Map<int, int>? links,
    Map<int, Map<String, int>>? lines,
  ]) : links = {
         for (final entry in {...?links}.entries)
           entry.key: {NoteTaskLinks.wholeNote: entry.value},
         for (final entry in {...?lines}.entries) entry.key: {...entry.value},
       },
       super(TaskDatabase());
  final Map<int, Map<String, int>> links;
  @override
  Future<Map<int, Map<String, int>>> read(String owner) async => {
    for (final entry in links.entries) entry.key: {...entry.value},
  };
  @override
  Future<void> link(String owner, int noteId, Map<String, int> lineTasks) async =>
      links[noteId] = {...?links[noteId], ...lineTasks};
}

/// The overrides for [NoteTaskList] and [MemoryNoteTaskLinks]. Every note
/// in the task list counts as made from a meeting on this phone, unless
/// [meetingNotes] names them (D1); they are read once [meetingNotesReady]
/// completes, if given (UX-2903).
List<Override> noteTaskOverrides(
  MemoryNoteTaskLinks links, {
  Set<int>? meetingNotes,
  Future<void>? meetingNotesReady,
}) => [
  noteTaskLinksProvider.overrideWithValue(links),
  meetingNotesOverride(meetingNotes, meetingNotesReady),
];

/// [meetingNotesProvider] in memory: [ids], or every note in the task list,
/// once [ready] completes, if given.
Override meetingNotesOverride([Set<int>? ids, Future<void>? ready]) =>
    meetingNotesProvider.overrideWith((ref) async {
      final tasks = ref.watch(taskProvider).value ?? const <Task>[];
      if (ready != null) await ready;
      return ids ??
          {
            for (final task in tasks)
              if (task.isNote && task.id != null) task.id!,
          };
    });

/// This phone's meeting-note marks (D1) in memory, for the real
/// [meetingNotesProvider] to read: [ids], and how many times it read them.
class MemoryMeetingNoteMarks implements TaskDatabase {
  MemoryMeetingNoteMarks([Set<int>? ids, Map<int, MeetingNoteTasks>? tasks])
    : ids = {...?ids},
      tasks = {...?tasks};
  final Set<int> ids;

  /// Each note's tasks, for «Crear tareas».
  final Map<int, MeetingNoteTasks> tasks;
  int reads = 0;

  @override
  Future<Database> get database async => _MarksTable(this);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// The one table [MeetingNoteMarks.read] queries.
class _MarksTable implements Database {
  _MarksTable(this.marks);
  final MemoryMeetingNoteMarks marks;

  @override
  Future<List<Map<String, Object?>>> query(
    String table, {
    bool? distinct,
    List<String>? columns,
    String? where,
    List<Object?>? whereArgs,
    String? groupBy,
    String? having,
    String? orderBy,
    int? limit,
    int? offset,
  }) async {
    final scope = whereArgs?.firstOrNull;
    if (table == 'app_preferences' &&
        scope is String &&
        scope.startsWith('meetingTasks:')) {
      return [
        if (marks.tasks.isNotEmpty)
          {
            'scope': scope,
            'data': jsonEncode({
              for (final entry in marks.tasks.entries)
                '${entry.key}': entry.value.toJson(),
            }),
          },
      ];
    }
    if (table != 'app_preferences' ||
        scope is! String ||
        !scope.startsWith('meetingNotes:')) {
      return const [];
    }
    marks.reads++;
    return [
      {
        'scope': scope,
        'data': jsonEncode([...marks.ids]),
      },
    ];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// The real [meetingNotesProvider], reading [marks].
Override meetingNoteMarksOverride(MemoryMeetingNoteMarks marks) =>
    meetingNoteMarksDatabaseProvider.overrideWithValue(marks);
