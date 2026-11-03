import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:sqflite/sqflite.dart';
import 'package:agenda/models/task.dart';
import 'package:agenda/providers/task_provider.dart';
import 'package:agenda/services/task_database.dart';

/// Remembers, per account on this phone, that the account has had a task or
/// note, so Calendar's first-run instruction never comes back.
class FirstTaskStore {
  final TaskDatabase database;
  FirstTaskStore(this.database);

  Future<bool> hadTask(String owner) async {
    final rows = await (await database.database).query('app_preferences',
        where: 'scope = ?', whereArgs: ['firstTask:$owner']);
    return rows.isNotEmpty &&
        (jsonDecode(rows.single['data'] as String) as Map)['hadTask'] == true;
  }

  Future<void> markHadTask(String owner) async =>
      (await database.database).insert('app_preferences',
          {'scope': 'firstTask:$owner', 'data': jsonEncode({'hadTask': true})},
          conflictAlgorithm: ConflictAlgorithm.replace);
}

final firstTaskStoreProvider = Provider((ref) => FirstTaskStore(TaskDatabase()));

/// Whether the current account has ever had a task or note on this phone.
final hadTaskProvider =
    StateNotifierProvider<HadTaskNotifier, AsyncValue<bool>>((ref) {
  final notifier = HadTaskNotifier(ref.watch(firstTaskStoreProvider),
      ref.watch(taskRepositoryProvider).ownerKey);
  ref.listen<AsyncValue<List<Task>>>(taskProvider, (_, tasks) {
    if ((tasks.value ?? const []).isNotEmpty) notifier.sawTask();
  }, fireImmediately: true);
  return notifier;
});

class HadTaskNotifier extends StateNotifier<AsyncValue<bool>> {
  final FirstTaskStore _store;
  final String _owner;
  bool _seen = false;
  HadTaskNotifier(this._store, this._owner)
      : super(const AsyncValue.loading()) {
    _load();
  }

  Future<void> _load() async {
    bool stored;
    try {
      stored = await _store.hadTask(_owner);
    } catch (_) {
      stored = false;
    }
    if (!mounted || _seen) return;
    state = AsyncValue.data(stored);
  }

  /// The account's list has had something in it: true at once, and stored.
  void sawTask() {
    if (_seen) return;
    _seen = true;
    state = const AsyncValue.data(true);
    unawaited(_store.markHadTask(_owner).catchError((_) {}));
  }
}
