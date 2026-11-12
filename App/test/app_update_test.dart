import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:agenda/l10n/generated/app_localizations.dart';
import 'package:agenda/providers/app_update_provider.dart';
import 'package:agenda/services/app_update.dart';
import 'package:agenda/widgets/app_update_dialog.dart';

const _channel = MethodChannel('taskflow/app-update');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final apk = utf8.encode('the newer build');
  final sha = sha256.convert(apk).toString();
  late Directory folder;
  late List<String> asked;
  late List<MethodCall> native;
  late bool metered;
  late int downloads;

  Map<String, dynamic> latest({int code = 5210, String? hash}) => {
    'available': true,
    'version': '1.0.6',
    'version_code': code,
    'sha256': hash ?? sha,
  };

  AppUpdater updater({
    Map<String, dynamic>? answer,
    List<int>? body,
    int installed = 5000,
    http.Client? transport,
  }) {
    final latestAnswer = answer ?? latest();
    return AppUpdater(
      get: (path) async {
        asked.add(path);
        return path == 'app/update/'
            ? latestAnswer
            : {
                'url': 'https://objects.example/apk?sig=1',
                'version': latestAnswer['version'],
                'version_code': latestAnswer['version_code'],
                'sha256': latestAnswer['sha256'],
              };
      },
      installedCode: () async => installed,
      folder: () async => folder,
      transport:
          transport ??
          MockClient((request) async {
            downloads++;
            expect(request.url.host, 'objects.example');
            expect(request.headers.containsKey('Authorization'), isFalse);
            return http.Response.bytes(body ?? apk, 200);
          }),
    );
  }

  setUp(() async {
    folder = await Directory.systemTemp.createTemp('app-update-test');
    asked = [];
    native = [];
    metered = false;
    downloads = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, (call) async {
          native.add(call);
          return call.method == 'metered' ? metered : 'started';
        });
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, null);
    await folder.delete(recursive: true);
  });

  test('a newer build downloads, is checked and installs', () async {
    final updates = updater();
    final found = await updates.latest();
    expect(found?.versionCode, 5210);
    expect(found?.file, isNull);
    final downloaded = await updates.download();
    expect(await downloaded.file!.readAsBytes(), apk);
    expect(downloaded.version, '1.0.6');
    // Already downloaded: found with its file, not downloaded again.
    expect((await updates.latest())?.file?.path, downloaded.file!.path);
    expect(await updates.install(downloaded), AppInstallResult.started);
    expect(native.last.arguments, {'path': downloaded.file!.path});
  });

  test('the same or an older build is no update', () async {
    expect(await updater(installed: 5210).latest(), isNull);
    expect(await updater(answer: {'available': false}).latest(), isNull);
  });

  test('a download that fails its SHA-256 is thrown away', () async {
    final updates = updater(body: utf8.encode('something else'));
    await expectLater(updates.download(), throwsA(isA<AppUpdateFailed>()));
    expect(folder.listSync(), isEmpty);
  });

  test(
    'a newer download replaces the older one, and an installed one goes',
    () async {
      await updater(answer: latest(code: 5100)).download();
      await updater().download();
      expect(folder.listSync().map((entry) => entry.uri.pathSegments.last), [
        'taskflow-staging-5210.apk',
      ]);
      await updater(installed: 5210).clean();
      expect(folder.listSync(), isEmpty);
    },
  );

  test('off mobile data the check downloads; on it, only when asked', () async {
    final now = DateTime(2026, 11, 6, 10);
    var clock = now;
    final controller = AppUpdateController(updater(), clock: () => clock);
    metered = true;
    await controller.check();
    expect(controller.state?.versionCode, 5210);
    expect(controller.state?.file, isNull);
    expect(downloads, 0);

    // Within a minute nothing is asked again; after it, the server is.
    asked.clear();
    clock = now.add(const Duration(seconds: 30));
    await controller.check();
    expect(asked, isEmpty);
    clock = now.add(AppUpdateController.spacing);
    await controller.check();
    expect(asked, ['app/update/']);

    // Update downloads it and installs.
    expect(await controller.install(), AppInstallResult.started);
    expect(downloads, 1);
    expect(controller.state?.file, isNotNull);

    final wifi = AppUpdateController(updater(), clock: () => now);
    metered = false;
    for (final file in folder.listSync()) {
      file.deleteSync();
    }
    await wifi.check();
    expect(wifi.state?.file, isNotNull);
    expect(downloads, 2);
  });

  test('without the staging build there is nothing to check', () async {
    final controller = AppUpdateController(null);
    await controller.check();
    expect(controller.state, isNull);
    expect(await controller.install(), AppInstallResult.failed);
    expect(AppUpdater.supported, isFalse);
  });

  test('a server that fails leaves no update', () async {
    final controller = AppUpdateController(
      AppUpdater(
        get: (_) async => throw const SocketException('offline'),
        installedCode: () async => 1,
        folder: () async => folder,
      ),
    );
    await controller.check();
    expect(controller.state, isNull);
  });

  test('a check that fails is tried again at once', () async {
    var offline = true;
    final controller = AppUpdateController(
      AppUpdater(
        get: (path) async {
          if (offline) throw const SocketException('offline');
          return latest();
        },
        installedCode: () async => 5000,
        folder: () async => folder,
      ),
      clock: () => DateTime(2026, 11, 12, 9),
    );
    metered = true;
    await controller.check();
    expect(controller.state, isNull);
    offline = false;
    await controller.check();
    expect(controller.state?.versionCode, 5210);
  });

  test('a build that fails to download is still offered', () async {
    final controller = AppUpdateController(
      updater(transport: MockClient((request) async => http.Response('', 500))),
    );
    await controller.check();
    expect(controller.state?.versionCode, 5210);
    expect(controller.state?.file, isNull);
  });

  for (final locale in const [Locale('en'), Locale('es'), Locale('ca')]) {
    testWidgets(
      'the dialog asks for the install permission (${locale.languageCode}, 2x text)',
      (tester) async {
        final controller = AppUpdateController(updater());
        await tester.runAsync(controller.check);
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(_channel, (call) async => 'permission');
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [appUpdateProvider.overrideWith((ref) => controller)],
            child: MaterialApp(
              locale: locale,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: const TextScaler.linear(2)),
                child: child!,
              ),
              home: Scaffold(body: AppUpdateDialog(update: controller.state!)),
            ),
          ),
        );
        final l10n = lookupAppLocalizations(locale);
        expect(find.text(l10n.appUpdateBody('1.0.6 (5210)')), findsOneWidget);
        await tester.tap(find.text(l10n.appUpdateInstall));
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pumpAndSettle();
        expect(find.text(l10n.appUpdateAllow), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  test('a download reports how far along it is, from 0 to 1', () async {
    final heard = <double?>[];
    final half = apk.length ~/ 2;
    final updates = updater(
      transport: MockClient.streaming((request, _) async {
        downloads++;
        return http.StreamedResponse(
          Stream.fromIterable([apk.sublist(0, half), apk.sublist(half)]),
          200,
          contentLength: apk.length,
        );
      }),
    );
    final downloaded = await updates.download(onProgress: heard.add);
    expect(downloaded.file, isNotNull);
    expect(heard, [0, half / apk.length, 1]);
  });

  test('without a size the download reports no share', () async {
    final heard = <double?>[];
    final updates = updater(
      transport: MockClient.streaming((request, _) async {
        downloads++;
        return http.StreamedResponse(Stream.value(apk), 200);
      }),
    );
    await updates.download(onProgress: heard.add);
    expect(heard, [null]);
  });

  for (final (locale, half) in const [
    (Locale('en'), '46%'),
    (Locale('es'), '46\u00a0%'),
    (Locale('ca'), '46\u00a0%'),
  ]) {
    testWidgets(
      'Update shows a bar and the share downloaded while the build arrives (${locale.languageCode}, 2x text)',
      (tester) async {
        final chunks = StreamController<List<int>>();
        final controller = AppUpdateController(
          updater(
            transport: MockClient.streaming((request, _) async {
              downloads++;
              return http.StreamedResponse(
                chunks.stream,
                200,
                contentLength: apk.length,
              );
            }),
          ),
        );
        metered = true;
        await tester.runAsync(controller.check);
        expect(controller.state?.file, isNull);
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [appUpdateProvider.overrideWith((ref) => controller)],
            child: MaterialApp(
              locale: locale,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: const TextScaler.linear(2)),
                child: child!,
              ),
              home: Scaffold(body: AppUpdateDialog(update: controller.state!)),
            ),
          ),
        );
        final l10n = lookupAppLocalizations(locale);
        // No bar until Update is tapped.
        expect(find.byType(LinearProgressIndicator), findsNothing);
        await tester.tap(find.text(l10n.appUpdateInstall));
        final rest = apk.length ~/ 2; // 7 of the 15 bytes: 46 %.
        chunks.add(apk.sublist(0, rest));
        // The download runs on real IO: let it reach the first chunk.
        for (var i = 0; i < 50; i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 10)),
          );
          await tester.pump();
          final bars = find.byType(LinearProgressIndicator);
          if (bars.evaluate().isNotEmpty &&
              (tester.widget<LinearProgressIndicator>(bars).value ?? 0) > 0) {
            break;
          }
        }
        final bar = tester.widget<LinearProgressIndicator>(
          find.byType(LinearProgressIndicator),
        );
        expect(bar.value, closeTo(rest / apk.length, 0.001));
        expect(bar.semanticsLabel, l10n.appUpdateDownloading);
        expect(find.text(half), findsOneWidget);
        expect(bar.semanticsValue, half);
        expect(find.text(l10n.appUpdateDownloading), findsOneWidget);
        expect(tester.takeException(), isNull);

        // The rest arrives, Android takes the build and the dialog closes.
        chunks.add(apk.sublist(rest));
        // Not awaited: it completes only once the download has read it.
        unawaited(chunks.close());
        for (
          var i = 0;
          i < 50 && find.byType(AppUpdateDialog).evaluate().isNotEmpty;
          i++
        ) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 10)),
          );
          await tester.pump();
        }
        await tester.pumpAndSettle();
        expect(find.byType(AppUpdateDialog), findsNothing);
        expect(native.map((call) => call.method), contains('install'));
      },
    );
  }
}
