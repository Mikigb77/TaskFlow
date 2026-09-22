import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:agenda/models/task.dart';
import 'package:agenda/models/task_schedule_change.dart';
import 'package:agenda/providers/auth_provider.dart';
import 'package:agenda/repositories/task_repository.dart';
import 'package:agenda/repositories/cloud_task_repository.dart';
import 'package:agenda/services/task_database.dart';
import 'package:agenda/services/notification_service.dart';

final taskRepositoryProvider = Provider<TaskRepository>((ref) {
  final account = ref.watch(authProvider.select((value) => value.account));
  if (account == null) return TaskRepository(TaskDatabase());
  return CloudTaskRepository(
      TaskDatabase(), ref.read(apiClientProvider), account.id);
});

final taskProvider =
    StateNotifierProvider<TaskNotifier, AsyncValue<List<Task>>>((ref) {
  return TaskNotifier(ref.watch(taskRepositoryProvider));
});

class TaskNotifier extends StateNotifier<AsyncValue<List<Task>>> {
  final TaskRepository _repository;
  Future<void>? _loading;
  bool _loadAgain = false;
  TaskNotifier(this._repository) : super(const AsyncValue.loading()) {
    loadTasks();
  }

  Future<void> loadTasks() {
    _loadAgain = true;
    return _loading ??= _loadLoop().whenComplete(() => _loading = null);
  }

  Future<void> _loadLoop() async {
    do {
      _loadAgain = false;
      try {
        final local = await _repository.getAllTasks();
        if (!mounted) return;
        state = AsyncValue.data(local);
        unawaited(TaskReminders.sync(local, ownerKey: _repository.ownerKey));
        await _repository.sync();
        if (!mounted) return;
        final synced = await _repository.getAllTasks();
        if (!mounted) return;
        state = AsyncValue.data(synced);
        unawaited(TaskReminders.sync(synced, ownerKey: _repository.ownerKey));
      } catch (error, stack) {
        if (!mounted) return;
        if (!state.hasValue) state = AsyncValue.error(error, stack);
        _repository.syncError =
            'Sync could not complete. Your local tasks are safe.';
      }
    } while (_loadAgain && mounted);
  }

  Future<void> addTask(Task task) async {
    await _repository.addTask(task);
    if (!mounted) return;
    unawaited(loadTasks());
  }

  Future<void> updateTask(Task task) async {
    await _repository.updateTask(task);
    if (!mounted) return;
    unawaited(loadTasks());
  }

  Future<void> addTasks(List<Task> tasks) async {
    await _repository.addTasks(tasks);
    if (mounted) unawaited(loadTasks());
  }

  Future<void> _mutating = Future.value();
  Future<void> moveToList(int taskId, String? listId) => _mutate(() async {
        final task = (await _repository.getAllTasks())
            .where((task) => task.id == taskId)
            .firstOrNull;
        if (task == null) throw StateError('This task no longer exists.');
        await _repository.updateTask(task.copyWith(listId: listId));
        if (mounted) await loadTasks();
      });

  Future<T> _mutate<T>(Future<T> Function() action) {
    final operation = _mutating.then((_) => action());
    _mutating =
        operation.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return operation;
  }

  Future<TaskScheduleChange> rescheduleTask(
          int id, DateTime? date, bool hasTime) =>
      _mutate(() async {
        final task = (await _repository.getAllTasks())
            .where((t) => t.id == id)
            .firstOrNull;
        if (task == null) throw StateError('Task no longer exists.');
        final after = TaskScheduleChange.apply(task, date, hasTime);
        await _repository.updateTask(after);
        if (mounted) await loadTasks();
        return TaskScheduleChange(task, after);
      });

  Future<bool> undoSchedule(TaskScheduleChange change) => _mutate(() async {
        final task = (await _repository.getAllTasks())
            .where((t) => t.id == change.after.id)
            .firstOrNull;
        if (task == null || !change.canUndo(task)) return false;
        await _repository.updateTask(change.restore(task));
        if (mounted) await loadTasks();
        return true;
      });

  Future<void> setCompleted(Task occurrence, bool completed) {
    return _mutate(() async {
      final tasks = await _repository.getAllTasks();
      final task = tasks.where((t) => t.id == occurrence.id).firstOrNull;
      if (task == null) throw StateError('Task no longer exists.');
      if (task.isRecurring) {
        final date = occurrence.displayDate;
        if (date == null || task.occurrenceOn(date) == null) return;
        final dates = {...task.completedDates};
        if (completed) {
          dates.add(Task.dateKey(date));
        } else {
          dates.remove(Task.dateKey(date));
        }
        await _repository
            .updateTask(task.copyWith(completedDates: dates.toList()..sort()));
      } else {
        await _repository.updateTask(task.copyWith(isCompleted: completed));
      }
      if (mounted) await loadTasks();
    });
  }

  Future<void> setChecklistCompleted(
          Task occurrence, String itemId, bool completed) =>
      _mutate(() async {
        final task = (await _repository.getAllTasks())
            .where((t) => t.id == occurrence.id)
            .firstOrNull;
        if (task == null) throw StateError('Task no longer exists.');
        final date = task.isRecurring ? occurrence.displayDate : null;
        if (task.isRecurring &&
            (date == null || task.occurrenceOn(date) == null)) {
          throw StateError('This occurrence has changed. Open it again.');
        }
        if (!task.checklist.any((item) => item.id == itemId)) {
          throw StateError('This step was removed.');
        }
        await _repository.updateTask(task.copyWith(
            checklist: task.checklist
                .map((item) => item.id == itemId
                    ? item.setDone(completed,
                        occurrence: date == null ? null : Task.dateKey(date))
                    : item)
                .toList()));
        if (mounted) await loadTasks();
      });

  Future<void> deleteTask(int id) async {
    await _repository.deleteTask(id);
    if (!mounted) return;
    unawaited(loadTasks());
  }
}
