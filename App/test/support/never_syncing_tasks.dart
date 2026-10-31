import 'dart:async';

import 'package:agenda/models/task.dart';
import 'package:agenda/repositories/task_repository.dart';
import 'package:agenda/services/task_database.dart';

/// A signed-in account's tasks on the phone, in memory, whose cloud sync
/// runs until [gate] completes: never, unless a test completes it. Reads and
/// writes answer at once, as the phone's own table does.
class NeverSyncingTasks extends TaskRepository {
  NeverSyncingTasks([List<Task> initial = const []]) : super(TaskDatabase()) {
    rows.addAll(initial);
  }

  /// The tasks on the phone.
  final rows = <Task>[];
  var _next = 500;

  /// Completes the running sync, and every later one.
  final gate = Completer<void>();

  /// Syncs started, and syncs that finished.
  int syncs = 0;
  int finished = 0;

  Task? byId(int id) => rows.where((task) => task.id == id).firstOrNull;

  @override
  String get ownerKey => 'account:1';

  @override
  Future<void> sync() async {
    syncs++;
    await gate.future;
    finished++;
  }

  @override
  Future<List<Task>> getAllTasks() async => [...rows];

  @override
  Future<int> addTask(Task task) async {
    final id = _next++;
    rows.add(task.copyWith(id: id));
    return id;
  }

  @override
  Future<void> addTasks(List<Task> tasks) async {
    for (final task in tasks) {
      await addTask(task);
    }
  }

  @override
  Future<int> updateTask(Task task) async {
    final index = rows.indexWhere((row) => row.id == task.id);
    if (index >= 0) rows[index] = task;
    return index >= 0 ? 1 : 0;
  }

  @override
  Future<int> deleteTask(int id) async {
    rows.removeWhere((task) => task.id == id);
    return 1;
  }

  @override
  Future<int> restoreTask(Task task) async {
    rows
      ..removeWhere((row) => row.id == task.id)
      ..add(task);
    return task.id!;
  }
}
