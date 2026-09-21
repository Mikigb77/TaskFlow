import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:agenda/models/task.dart';
import 'package:agenda/providers/auth_provider.dart';
import 'package:agenda/providers/task_provider.dart';
import 'package:agenda/providers/theme_provider.dart';
import 'package:agenda/repositories/task_repository.dart';
import 'package:agenda/services/task_database.dart';
import 'package:agenda/services/api_client.dart';

// Isolated UI fixtures: no real accounts, persistence, reminders or AI calls.
class MemoryThemeStore extends ThemePreferenceStore {
  MemoryThemeStore([this.value = 'light']);
  String? value;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String mode) async {
    value = mode;
  }
}

class OfflineApiClient extends ApiClient {
  @override
  Future<void> restore() async {}
}

class MemoryTasks extends TaskRepository {
  MemoryTasks() : super(TaskDatabase());
}

class DesignTaskNotifier extends TaskNotifier {
  DesignTaskNotifier() : super(MemoryTasks());
  static List<Task> samples() {
    final now = DateTime.now();
    DateTime time(int h, int m) => DateTime(now.year, now.month, now.day, h, m);
    return [
      Task(
          id: 1,
          title: 'A little morning movement',
          dueDate: time(8, 30),
          priority: 1,
          isCompleted: true),
      Task(
          id: 2,
          title: 'Review the new designs',
          dueDate: time(10, 0),
          priority: 2,
          notes: 'Bring your ideas for the next release.'),
      Task(
          id: 3,
          title: 'Doctor appointment',
          dueDate: time(14, 30),
          priority: 3,
          notes: 'Remember the blood test results.'),
      Task(
          id: 4,
          title: 'Pick up a few groceries',
          dueDate: time(18, 0),
          priority: 1),
    ];
  }

  @override
  Future<void> loadTasks() async {
    if (!state.hasValue) state = AsyncData(samples());
  }

  @override
  Future<void> addTask(Task task) async {
    state = AsyncData([...state.requireValue, task.copyWith(id: 5)]);
  }

  @override
  Future<void> updateTask(Task task) async {
    state = AsyncData(state.requireValue
        .map((item) => item.id == task.id ? task : item)
        .toList());
  }

  @override
  Future<void> deleteTask(int id) async {
    state =
        AsyncData(state.requireValue.where((item) => item.id != id).toList());
  }
}

ProviderContainer designContainer({MemoryThemeStore? store}) =>
    ProviderContainer(overrides: [
      apiClientProvider.overrideWith((ref) {
        final api = OfflineApiClient();
        ref.onDispose(api.close);
        return api;
      }),
      taskRepositoryProvider.overrideWithValue(MemoryTasks()),
      taskProvider.overrideWith((ref) => DesignTaskNotifier()),
      themeStoreProvider.overrideWithValue(store ?? MemoryThemeStore()),
    ]);

Future<void> setAppearance(ProviderContainer container, ThemeMode mode) =>
    container.read(themeModeProvider.notifier).setMode(mode);
