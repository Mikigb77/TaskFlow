import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

import 'package:agenda/providers/auth_provider.dart';
import 'package:agenda/services/app_update.dart';

/// The staging app's updater; null in every other build, which Google Play
/// updates (production) or the developer installs (debug).
final appUpdaterProvider = Provider<AppUpdater?>((ref) {
  if (!AppUpdater.supported) return null;
  final api = ref.read(apiClientProvider);
  final updater = AppUpdater(
    get: (path) => api.request('GET', path),
    installedCode: () async =>
        int.tryParse((await PackageInfo.fromPlatform()).buildNumber) ?? 0,
    folder: () async =>
        Directory('${(await getTemporaryDirectory()).path}/app-updates'),
  );
  ref.onDispose(updater.close);
  return updater;
});

/// A newer staging build, or null.
final appUpdateProvider =
    StateNotifierProvider<AppUpdateController, AppUpdate?>(
      (ref) => AppUpdateController(ref.read(appUpdaterProvider)),
    );

class AppUpdateController extends StateNotifier<AppUpdate?> {
  AppUpdateController(this._updater, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now,
      super(null);

  /// How often the app looks for a newer build: when it opens, and when it
  /// comes back to the front after this long.
  static const interval = Duration(hours: 1);

  final AppUpdater? _updater;
  final DateTime Function() _clock;
  DateTime? _checked;
  Future<void>? _checking;

  /// Looks for a newer build, at most once an [interval]. Off mobile data it
  /// downloads it too, so it installs at once.
  Future<void> check() => _checking ??= _check().whenComplete(() {
    _checking = null;
  });

  Future<void> _check() async {
    final updater = _updater;
    final now = _clock();
    if (updater == null ||
        (_checked != null && now.difference(_checked!) < interval)) {
      return;
    }
    _checked = now;
    try {
      await updater.clean();
      var update = await updater.latest();
      if (update != null && update.file == null && !await updater.metered()) {
        update = await updater.download();
      }
      if (mounted) state = update;
    } catch (_) {
      // No server, no network or no release: the next check tries again.
    }
  }

  /// Downloads the update if it isn't yet, then hands it to Android.
  /// [onProgress] hears the download's progress (AppUpdater.download).
  Future<AppInstallResult> install({
    void Function(double? done)? onProgress,
  }) async {
    final updater = _updater;
    var update = state;
    if (updater == null || update == null) return AppInstallResult.failed;
    await _checking;
    if (update.file == null) {
      try {
        update = await updater.download(onProgress: onProgress);
      } catch (_) {
        return AppInstallResult.failed;
      }
      if (mounted) state = update;
    }
    return updater.install(update);
  }
}
