import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:agenda/providers/task_provider.dart';
import 'package:agenda/services/reminder_preferences.dart';
import 'package:agenda/services/task_database.dart';

final reminderPreferenceStoreProvider =
    Provider((ref) => ReminderPreferenceStore(TaskDatabase()));
final reminderPreferencesProvider = FutureProvider<ReminderPreferences>((ref) =>
    ref
        .watch(reminderPreferenceStoreProvider)
        .read(ref.watch(taskRepositoryProvider).ownerKey));
