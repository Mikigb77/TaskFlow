import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';
import 'package:agenda/services/capture_store.dart';
import 'package:agenda/services/task_database.dart';

/// Remembers, per account on this phone, the month whose «Has usado tus 10
/// dictados gratis» notice it has seen. A month is known by its free
/// dictations' `resets_at`: the start of the next calendar month, in UTC.
class FreeVoiceNoticeStore {
  FreeVoiceNoticeStore(this.database);
  final TaskDatabase database;

  // Per-account preferences are scoped `<kind>:<owner>`, so deleting the
  // account erases this too.
  static String _scope(String owner) => 'freeVoiceNotice:$owner';

  /// The month whose notice [owner] has seen, if any.
  Future<DateTime?> seen(String owner) async {
    final rows = await (await database.database).query(
      'app_preferences',
      where: 'scope = ?',
      whereArgs: [_scope(owner)],
    );
    if (rows.isEmpty) return null;
    final data = jsonDecode(rows.single['data'] as String);
    return data is Map ? DateTime.tryParse('${data['resets_at']}') : null;
  }

  Future<void> markSeen(String owner, DateTime resetsAt) async =>
      (await database.database).insert('app_preferences', {
        'scope': _scope(owner),
        'data': jsonEncode({'resets_at': resetsAt.toUtc().toIso8601String()}),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
}

final freeVoiceNoticeStoreProvider = Provider(
  (ref) => FreeVoiceNoticeStore(TaskDatabase()),
);

/// The month whose used-up notice the signed-in account has seen. Read from
/// the phone as soon as Nueva tarea shows, so its tap never waits.
final freeVoiceNoticeProvider =
    StateNotifierProvider<FreeVoiceNotice, AsyncValue<DateTime?>>(
      (ref) => FreeVoiceNotice(
        ref.watch(freeVoiceNoticeStoreProvider),
        ref.watch(captureOwnerProvider),
      ),
    );

class FreeVoiceNotice extends StateNotifier<AsyncValue<DateTime?>> {
  FreeVoiceNotice(this._store, this._owner) : super(const AsyncLoading()) {
    _loaded = _load();
  }
  final FreeVoiceNoticeStore _store;
  final String _owner;
  late final Future<void> _loaded;

  Future<void> _load() async {
    DateTime? seen;
    try {
      seen = await _store.seen(_owner);
    } catch (_) {
      // Unread: it shows, once in this run of the app.
    }
    if (mounted && state.isLoading) state = AsyncData(seen);
  }

  /// Whether the notice for the month that ends at [resetsAt] shows now: it
  /// hasn't been seen. It counts as seen from here on, whatever the answer,
  /// so it shows once.
  Future<bool> claim(DateTime resetsAt) async {
    await _loaded;
    final seen = state.valueOrNull;
    if (!mounted || (seen != null && seen.isAtSameMomentAs(resetsAt))) {
      return false;
    }
    state = AsyncData(resetsAt);
    // Not shown again in this run, even if this isn't written.
    unawaited(_store.markSeen(_owner, resetsAt).catchError((_) {}));
    return true;
  }
}
