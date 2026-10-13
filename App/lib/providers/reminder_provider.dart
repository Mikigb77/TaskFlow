import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:agenda/providers/task_provider.dart';
import 'package:agenda/services/notification_service.dart';
import 'package:agenda/services/reminder_preferences.dart';
import 'package:agenda/services/task_database.dart';

final reminderPreferenceStoreProvider =
    Provider((ref) => ReminderPreferenceStore(TaskDatabase()));
final reminderPreferencesProvider = FutureProvider<ReminderPreferences>((ref) =>
    ref
        .watch(reminderPreferenceStoreProvider)
        .read(ref.watch(taskRepositoryProvider).ownerKey));
final reminderAccessProvider = Provider((ref) => const ReminderAccess());

/// Per account, the open dated tasks there were when its tasks first loaded
/// in this run of the app. Kept in memory only, never saved.
final _launchDatedTasksProvider = Provider<Map<String, Set<int>>>((ref) => {});

/// Whether the account has open dated tasks, and whether one of them was
/// saved since the app started, so the reminder question can refer to "it".
/// A task that only arrives through sync also counts as saved.
final datedTasksProvider = Provider<DatedTasks>((ref) {
  final tasks = ref.watch(taskProvider).valueOrNull;
  if (tasks == null) return const DatedTasks.none();
  final owner = ref.watch(taskRepositoryProvider).ownerKey;
  final dated = tasks.where(
    (task) =>
        !task.isNote &&
        !task.isCompleted &&
        (task.dueDate != null || task.deadline != null),
  );
  final ids = {for (final task in dated) ?task.id};
  final atLaunch = ref
      .read(_launchDatedTasksProvider)
      .putIfAbsent(owner, () => ids);
  return DatedTasks(
    any: dated.isNotEmpty,
    savedThisSession: ids.any((id) => !atLaunch.contains(id)),
  );
});

class DatedTasks {
  const DatedTasks({required this.any, required this.savedThisSession});
  const DatedTasks.none() : any = false, savedThisSession = false;
  final bool any;
  final bool savedThisSession;
}
