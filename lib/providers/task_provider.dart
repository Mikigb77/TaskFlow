import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:agenda/models/task.dart';
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
        unawaited(TaskReminders.sync(local));
        await _repository.sync();
        if (!mounted) return;
        final synced = await _repository.getAllTasks();
        if (!mounted) return;
        state = AsyncValue.data(synced);
        unawaited(TaskReminders.sync(synced));
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

  Future<void> deleteTask(int id) async {
    await _repository.deleteTask(id);
    if (!mounted) return;
    unawaited(loadTasks());
  }
}
