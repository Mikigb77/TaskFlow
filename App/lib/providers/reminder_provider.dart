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

/// The accounts that asked for reminders on this phone, were refused by it
/// and went by «Permitir avisos» to its notifications page. Each request
/// settles once the person is back in the app: reminders on if the phone now
/// allows them, nothing more if it still refuses. Forgotten either way.
final reminderRequestsProvider =
    Provider<Map<String, Future<void>>>((ref) => {});
