import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:agenda/models/task_list_info.dart';
import 'package:agenda/providers/task_provider.dart';
import 'package:agenda/services/task_database.dart';
import 'package:agenda/services/task_list_store.dart';

final taskListStoreProvider = Provider<TaskListStore>((ref) =>
    TaskListStore(TaskDatabase(), ref.watch(taskRepositoryProvider).ownerKey));

final taskListsProvider = FutureProvider<List<TaskListInfo>>((ref) {
  ref.watch(taskProvider);
  return ref.watch(taskListStoreProvider).all();
});

// Unknown/revoked lists stay read-only while access metadata is loading.
final listCanEditProvider = Provider.family<bool, String?>((ref, id) =>
    id == null ||
    (ref.watch(taskListsProvider).valueOrNull ?? [])
        .any((list) => list.id == id && list.canEdit));
