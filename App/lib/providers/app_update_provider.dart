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

  /// How often the app looks for a newer build while it stays open. It also
  /// looks each time it opens and each time it comes back to the front.
  static const interval = Duration(minutes: 15);

  /// The least time between two checks, so flicking between apps, or
  /// Android's installer coming and going, doesn't ask the server each time.
  static const spacing = Duration(minutes: 1);

  final AppUpdater? _updater;
  final DateTime Function() _clock;
  DateTime? _checked;
  Future<void>? _checking;

  /// Looks for a newer build, at most once a [spacing]. Off mobile data it
  /// downloads it too, so it installs at once.
  Future<void> check() => _checking ??= _check().whenComplete(() {
    _checking = null;
  });

  Future<void> _check() async {
    final updater = _updater;
    final now = _clock();
    if (updater == null ||
        (_checked != null && now.difference(_checked!) < spacing)) {
      return;
    }
    AppUpdate? update;
    var answered = false;
    try {
      await updater.clean();
      update = await updater.latest();
      // Only a check the server answered counts: one that failed, say with
      // no network yet as the app opens, is tried again at the next chance.
      _checked = now;
      answered = true;
      if (update != null && update.file == null && !await updater.metered()) {
        update = await updater.download();
      }
    } catch (_) {
      // No server, no network or no release: the next check tries again. A
      // build that was found but didn't download is still offered; Update
      // downloads it.
    }
    if (mounted && answered) state = update;
  }

  /// Downloads the update if it isn't yet, then hands it to Android.
  /// [onProgress] hears the download's progress (AppUpdater.download).
  Future<AppInstallResult> install({
    void Function(double? done)? onProgress,
  }) async {
    final updater = _updater;
    if (updater == null || state == null) return AppInstallResult.failed;
    // A check under way may be downloading this build already.
    await _checking;
    var update = state;
    if (update == null) return AppInstallResult.failed;
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
