import 'dart:async';
import 'dart:math' as math;
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

/// A newer staging build than the one installed.
class AppUpdate {
  const AppUpdate({
    required this.version,
    required this.versionCode,
    required this.sha256,
    this.file,
  });
  final String version;
  final int versionCode;
  final String sha256;

  /// The downloaded APK, its SHA-256 checked; null until it is downloaded.
  final File? file;
}

/// How an install ended without replacing the app. On success Android
/// replaces the app and closes it, so Dart never hears.
enum AppInstallResult {
  /// Android opened the setting that lets TaskFlow Staging install updates.
  permission,

  /// Android took the update; it may still ask to confirm.
  started,
  cancelled,
  failed,
}

class AppUpdateFailed implements Exception {
  const AppUpdateFailed(this.reason);
  final String reason;
  @override
  String toString() => 'AppUpdateFailed: $reason';
}

/// The private staging app's own updater. GitHub Actions publishes every
/// staging build as the newest release of the app repository; the staging
/// API tells a signed-in phone about it (`app/update/`, Backend
/// core/app_updates.py) and gives it a short-lived download link. The
/// production app has none of this: Google Play updates it.
class AppUpdater {
  AppUpdater({
    required this.get,
    required this.installedCode,
    required this.folder,
    http.Client? transport,
    MethodChannel? channel,
  }) : _http = transport ?? http.Client(),
       _channel = channel ?? const MethodChannel('taskflow/app-update') {
    _channel.setMethodCallHandler((call) async {
      if (call.method != 'installResult') return;
      _results.add(_result(call.arguments));
    });
  }

  /// Only the private staging release build updates itself.
  static bool get supported =>
      const String.fromEnvironment('APP_ENV') == 'staging' &&
      kReleaseMode &&
      Platform.isAndroid;

  /// An authenticated GET of the API at [path], answering its JSON.
  final Future<dynamic> Function(String path) get;

  /// The installed build's versionCode.
  final Future<int> Function() installedCode;

  /// Where downloads go; only updates are kept there.
  final Future<Directory> Function() folder;
  final http.Client _http;
  final MethodChannel _channel;
  final _results = StreamController<AppInstallResult>.broadcast();

  /// How installs that Android took ended, when it didn't replace the app.
  Stream<AppInstallResult> get installResults => _results.stream;

  static AppInstallResult _result(Object? value) =>
      AppInstallResult.values.asNameMap()[value] ?? AppInstallResult.failed;

  File _apk(Directory folder, int code) =>
      File('${folder.path}/taskflow-staging-$code.apk');

  /// The newest build, when it is newer than this one; with its file when it
  /// is downloaded already.
  Future<AppUpdate?> latest() async {
    final data = await get('app/update/');
    if (data is! Map || data['available'] != true) return null;
    final code = data['version_code'];
    final sha = data['sha256'];
    if (code is! int || sha is! String || code <= await installedCode()) {
      return null;
    }
    final file = _apk(await folder(), code);
    return AppUpdate(
      version: '${data['version'] ?? ''}',
      versionCode: code,
      sha256: sha,
      file: await file.exists() && await _digest(file) == sha ? file : null,
    );
  }

  /// Downloads the newest build and checks its SHA-256. It may be newer than
  /// the one [latest] found, if one was published meanwhile. [onProgress]
  /// hears the share downloaded, from 0 to 1, as it arrives; null when the
  /// server doesn't say how big the build is.
  Future<AppUpdate> download({void Function(double? done)? onProgress}) async {
    final link = await get('app/update/download/');
    if (link is! Map) throw const AppUpdateFailed('link');
    final url = Uri.tryParse('${link['url']}');
    final code = link['version_code'];
    final sha = link['sha256'];
    if (url == null ||
        url.scheme != 'https' ||
        code is! int ||
        sha is! String) {
      throw const AppUpdateFailed('link');
    }
    if (code <= await installedCode()) throw const AppUpdateFailed('older');
    final dir = await folder();
    await dir.create(recursive: true);
    final target = _apk(dir, code);
    final part = File('${target.path}.part');
    try {
      final response = await _http
          .send(http.Request('GET', url))
          .timeout(const Duration(seconds: 30));
      if (response.statusCode != 200) {
        throw AppUpdateFailed('http ${response.statusCode}');
      }
      final total = response.contentLength;
      final known = total != null && total > 0;
      var received = 0;
      onProgress?.call(known ? 0 : null);
      await response.stream
          .timeout(const Duration(seconds: 60))
          .map((chunk) {
            received += chunk.length;
            if (known) onProgress?.call(math.min(1, received / total));
            return chunk;
          })
          .pipe(part.openWrite());
      if (await _digest(part) != sha) throw const AppUpdateFailed('sha256');
      await part.rename(target.path);
    } on TimeoutException {
      throw const AppUpdateFailed('timeout');
    } on IOException catch (error) {
      throw AppUpdateFailed('$error');
    } finally {
      if (await part.exists()) await part.delete();
    }
    // Only the newest download is kept.
    await for (final entry in dir.list()) {
      if (entry is File && entry.path != target.path) {
        await entry.delete().catchError((_) => entry);
      }
    }
    return AppUpdate(
      version: '${link['version'] ?? ''}',
      versionCode: code,
      sha256: sha,
      file: target,
    );
  }

  /// Whether the phone is on a metered network, such as mobile data. Builds
  /// download by themselves only off it; on it, when the person says so.
  Future<bool> metered() async {
    try {
      return await _channel.invokeMethod<bool>('metered') ?? true;
    } on PlatformException {
      return true;
    }
  }

  /// Hands the downloaded build to Android's installer.
  Future<AppInstallResult> install(AppUpdate update) async {
    final file = update.file;
    if (file == null) return AppInstallResult.failed;
    try {
      return _result(
        await _channel.invokeMethod<String>('install', {'path': file.path}),
      );
    } on PlatformException {
      return AppInstallResult.failed;
    }
  }

  /// Removes downloads that the installed build has caught up with.
  Future<void> clean() async {
    final dir = await folder();
    if (!await dir.exists()) return;
    final installed = await installedCode();
    await for (final entry in dir.list()) {
      final code = RegExp(r'taskflow-staging-(\d+)\.apk$')
          .firstMatch(entry.path)
          ?.group(1);
      if (entry is File && (code == null || int.parse(code) <= installed)) {
        await entry.delete().catchError((_) => entry);
      }
    }
  }

  static Future<String> _digest(File file) async =>
      (await sha256.bind(file.openRead()).first).toString();

  void close() {
    _channel.setMethodCallHandler(null);
    _results.close();
    _http.close();
  }
}
