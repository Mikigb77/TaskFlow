// P318: «Crear tarea» from a note, in memory: a task list that saving adds
// to, editing changes, and Deshacer or Eliminar take from, and the phone's
// note → task links.
import 'package:agenda/models/task.dart';
import 'package:agenda/providers/task_provider.dart';
import 'package:agenda/services/task_database.dart';
import 'package:agenda/widgets/note_task.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';

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
  MemoryNoteTaskLinks([Map<int, int>? links])
    : links = {...?links},
      super(TaskDatabase());
  final Map<int, int> links;
  @override
  Future<Map<int, int>> read(String owner) async => {...links};
  @override
  Future<void> link(String owner, int noteId, int taskId) async =>
      links[noteId] = taskId;
}

/// The overrides for [NoteTaskList] and [MemoryNoteTaskLinks].
List<Override> noteTaskOverrides(MemoryNoteTaskLinks links) => [
  noteTaskLinksProvider.overrideWithValue(links),
];
