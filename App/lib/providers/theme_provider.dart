import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ThemePreferenceStore {
  static const _storage = FlutterSecureStorage();
  Future<String?> read() => _storage.read(key: 'appearance');
  Future<void> write(String mode) =>
      _storage.write(key: 'appearance', value: mode);
}

final themeStoreProvider = Provider((ref) => ThemePreferenceStore());
final themeModeProvider = StateNotifierProvider<ThemeController, ThemeMode>(
    (ref) => ThemeController(ref.read(themeStoreProvider)));

class ThemeController extends StateNotifier<ThemeMode> {
  ThemeController(this._store) : super(ThemeMode.system) {
    ready = _restore();
  }
  final ThemePreferenceStore _store;
  late final Future<void> ready;
  bool _chosen = false;
  Future<void> _writes = Future.value();
  Future<void> _restore() async {
    try {
      final saved = await _store.read();
      if (!mounted || _chosen) return;
      state = ThemeMode.values.firstWhere((mode) => mode.name == saved,
          orElse: () => ThemeMode.system);
    } catch (_) {/* Use device appearance when preferences are unavailable. */}
  }

  Future<void> setMode(ThemeMode mode) {
    _chosen = true;
    state = mode;
    // Keep rapid toggles in order so the last choice survives a restart.
    return _writes =
        _writes.catchError((Object _) {}).then((_) => _store.write(mode.name));
  }
}
