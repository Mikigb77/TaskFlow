import 'package:agenda/providers/no_retry.dart';
import 'package:agenda/providers/subscription_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:agenda/models/task.dart';
import 'package:agenda/models/task_list_info.dart';
import 'package:agenda/models/task_schedule_change.dart';
import 'package:agenda/providers/auth_provider.dart';
import 'package:agenda/providers/first_task_provider.dart';
import 'package:agenda/providers/task_provider.dart';
import 'package:agenda/providers/theme_provider.dart';
import 'package:agenda/providers/task_lists_provider.dart';
import 'package:agenda/repositories/task_repository.dart';
import 'package:agenda/services/task_database.dart';
import 'package:agenda/services/api_client.dart';
import 'package:agenda/services/capture_store.dart';
import 'package:agenda/models/capture_session.dart';
import 'package:agenda/providers/regional_provider.dart';
import 'package:agenda/widgets/attachment_panel.dart';
import 'package:agenda/services/invitation_links.dart';

class MemoryRegionalStore extends RegionalPreferenceStore {
  MemoryRegionalStore([
    this.value = const RegionalPreferences(
      language: 'en',
      clock: ClockFormat.twentyFour,
      weekStart: 1,
      // On-device speech, chosen: the capture tests written for that path.
      // Online is the app's default since 2026-11-05 (regional and Voz
      // tests).
      speechOnline: false,
    ),
  ]);
  RegionalPreferences value;
  @override
  Future<RegionalPreferences> read() async => value;
  @override
  Future<void> write(RegionalPreferences value) async {
    this.value = value;
  }
}

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

/// Remembers which accounts have had a task, without sqflite.
class MemoryFirstTaskStore extends FirstTaskStore {
  MemoryFirstTaskStore([Iterable<String> owners = const []])
    : owners = {...owners},
      super(TaskDatabase());
  final Set<String> owners;
  @override
  Future<bool> hadTask(String owner) async => owners.contains(owner);
  @override
  Future<void> markHadTask(String owner) async {
    owners.add(owner);
  }
}

class OfflineApiClient extends ApiClient {
  @override
  Future<void> restore() async {}
}

// Screens past the login gate use a synthetic session, never a real credential.
class SignedInFixtureAuth extends AuthNotifier {
  SignedInFixtureAuth(super.api);
  @override
  Future<void> restore() async {
    state = AuthState(
      account: Account.fromJson({
        'id': 1,
        'email': 'design@example.invalid',
        'timezone': 'Europe/Madrid',
      }),
    );
  }
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
        isCompleted: true,
      ),
      Task(
        id: 2,
        title: 'Review the new designs',
        dueDate: time(10, 0),
        priority: 2,
        notes: 'Bring your ideas for the next release.',
      ),
      Task(
        id: 3,
        title: 'Doctor appointment',
        dueDate: time(14, 30),
        priority: 3,
        notes: 'Remember the blood test results.',
      ),
      Task(
        id: 4,
        title: 'Pick up a few groceries',
        dueDate: time(18, 0),
        priority: 1,
      ),
    ];
  }

  @override
  Future<void> loadTasks() async {
    if (!state.hasValue) state = AsyncData(samples());
  }

  @override
  Future<int> addTask(Task task) async {
    state = AsyncData([...state.requireValue, task.copyWith(id: 5)]);
    return 5;
  }

  @override
  Future<void> updateTask(Task task) async {
    state = AsyncData(
      state.requireValue
          .map((item) => item.id == task.id ? task : item)
          .toList(),
    );
  }

  @override
  Future<void> setCompleted(Task task, bool completed, {DateTime? at}) =>
      updateTask(task.copyWith(isCompleted: completed));

  @override
  Future<TaskScheduleChange> rescheduleTask(
    int id,
    DateTime? date,
    bool hasTime,
  ) async {
    final before = state.requireValue.firstWhere((task) => task.id == id);
    final after = TaskScheduleChange.apply(before, date, hasTime);
    await updateTask(after);
    return TaskScheduleChange(before, after);
  }

  @override
  Future<bool> undoSchedule(TaskScheduleChange change) async {
    final current = state.requireValue.firstWhere(
      (task) => task.id == change.after.id,
    );
    if (!change.canUndo(current)) return false;
    await updateTask(change.restore(current));
    return true;
  }

  @override
  Future<void> addTasks(List<Task> tasks) async {
    var id = state.requireValue.fold<int>(
      0,
      (max, task) => task.id! > max ? task.id! : max,
    );
    state = AsyncData([
      ...state.requireValue,
      ...tasks.map((task) => task.copyWith(id: ++id)),
    ]);
  }

  @override
  Future<void> deleteTask(int id, {bool sync = true}) async {
    state = AsyncData(
      state.requireValue.where((item) => item.id != id).toList(),
    );
  }

  @override
  Future<void> restoreTask(Task task) async {
    state = AsyncData([...state.requireValue, task]);
  }

  /// One at a time, through [restoreTask], so a stand-in's own wins.
  @override
  Future<bool> restoreTasks(List<Task> tasks) async {
    var whole = true;
    for (final task in tasks) {
      try {
        await restoreTask(task);
      } catch (_) {
        whole = false;
      }
    }
    return whole;
  }
}

ProviderContainer designContainer({
  MemoryThemeStore? store,
  RegionalPreferenceStore? regionalStore,
  TaskNotifier Function()? tasks,
  List<TaskListInfo>? projects,
  // Loads the projects instead of [projects], e.g. to keep a reload pending.
  Future<List<TaskListInfo>> Function()? loadProjects,
  // Extra stand-ins a test needs, e.g. reminder storage or the phone's side.
  List<Override> overrides = const [],
  // Without Pro, `Añadir tarea` opens typing, understood on the phone.
  bool pro = true,
  // A stand-in server; by default every request goes nowhere.
  ApiClient? api,
  // What was said or typed but not saved yet; none by default.
  List<CaptureSession> pendingCaptures = const [],
  // Whether this account has had a task before; a test's own
  // firstTaskStoreProvider in [overrides] wins over this.
  bool hadTask = false,
}) => ProviderContainer(
  retry: noRetry,
  overrides: [
    if (!overrides.any((o) => o.origin == firstTaskStoreProvider))
      firstTaskStoreProvider.overrideWithValue(
        MemoryFirstTaskStore([if (hadTask) MemoryTasks().ownerKey]),
      ),
    ...overrides,
    invitationLinkProvider.overrideWith(
      (ref) => InvitationLinks(listen: false),
    ),
    hasProProvider.overrideWithValue(pro),
    billingLoadingProvider.overrideWithValue(false),
    authProvider.overrideWith(
      (ref) => SignedInFixtureAuth(ref.read(apiClientProvider)),
    ),
    attachmentEntriesProvider.overrideWith((ref, taskId) async => []),
    regionalStoreProvider.overrideWithValue(
      regionalStore ?? MemoryRegionalStore(),
    ),
    pendingCapturesProvider.overrideWith((ref) async => pendingCaptures),
    taskListsProvider.overrideWith(
      loadProjects != null
          ? (ref) => loadProjects()
          : (ref) async => projects ?? [],
    ),
    apiClientProvider.overrideWith((ref) {
      final client = api ?? OfflineApiClient();
      ref.onDispose(client.close);
      return client;
    }),
    taskRepositoryProvider.overrideWithValue(MemoryTasks()),
    taskProvider.overrideWith((ref) => tasks?.call() ?? DesignTaskNotifier()),
    themeStoreProvider.overrideWithValue(store ?? MemoryThemeStore()),
  ],
);

Future<void> setAppearance(ProviderContainer container, ThemeMode mode) =>
    container.read(themeModeProvider.notifier).setMode(mode);
