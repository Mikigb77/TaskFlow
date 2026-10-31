import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:agenda/providers/calendar_focus_provider.dart';

/// The address waiting for its emailed code, kept across a restart: Android
/// may close TaskFlow while the person reads the email. Only the address and
/// when its code went are stored, never the password.
final pendingVerificationProvider = Provider<PendingVerification>(
  (ref) => PendingVerification(now: ref.watch(calendarClockProvider)),
);

/// The first read of the waiting address, started with the app: signed out,
/// it opens once this is done, so a waiting address opens straight on its
/// screen.
final pendingVerificationLoadProvider =
    FutureProvider<({String email, DateTime sentAt})?>(
      (ref) => ref.watch(pendingVerificationProvider).load(),
    );

class PendingVerification {
  PendingVerification({FlutterSecureStorage? storage, DateTime Function()? now})
    : _storage = storage ?? const FlutterSecureStorage(),
      _now = now ?? DateTime.now;

  final FlutterSecureStorage _storage;
  final DateTime Function() _now;
  Future<void> _writes = Future.value();
  Future<({String email, DateTime sentAt})?>? _loaded;
  bool _resumed = false;
  static const _key = 'taskflow.pending-verification';

  /// How long a code works.
  static const life = Duration(minutes: 30);

  /// A code just went to [email].
  Future<void> remember(String email) {
    _loaded = null;
    return _write(
      () => _storage.write(
        key: _key,
        value: jsonEncode({
          'email': email,
          'saved': _now().toUtc().toIso8601String(),
        }),
      ),
    );
  }

  /// The address is confirmed, or no longer waits.
  Future<void> forget() {
    _loaded = null;
    return _write(() => _storage.delete(key: _key));
  }

  /// The address still waiting for a code that works, and when that code
  /// went; an older one is dropped. Read once, until the entry changes.
  Future<({String email, DateTime sentAt})?> load() => _loaded ??= _read();

  /// [load], once per start of the app.
  Future<({String email, DateTime sentAt})?> resume() async {
    if (_resumed) return null;
    _resumed = true;
    return load();
  }

  Future<({String email, DateTime sentAt})?> _read() async {
    try {
      await _writes;
      final raw = await _storage.read(key: _key);
      if (raw == null) return null;
      final value = jsonDecode(raw) as Map;
      final email = value['email'] as String;
      final sentAt = DateTime.parse(value['saved'] as String);
      final age = _now().difference(sentAt);
      if (email.isNotEmpty && !age.isNegative && age < life) {
        return (email: email, sentAt: sentAt);
      }
    } catch (_) {
      /* Unsupported storage or an unreadable entry: nothing waits. */
    }
    // Storage now holds nothing waiting, as the memoised answer says.
    unawaited(_write(() => _storage.delete(key: _key)));
    return null;
  }

  Future<void> _write(Future<void> Function() change) =>
      _writes = _writes.then((_) => change()).catchError((Object _) {});
}
