// Run 2026-10-19-app · P218 (UX-1653): «Como el teléfono» follows a
// phone-language change while the app runs.
import 'dart:io';

import 'package:agenda/l10n/generated/app_localizations.dart';
import 'package:agenda/main.dart';
import 'package:agenda/providers/regional_provider.dart';
import 'package:agenda/services/app_language.dart';
import 'package:agenda/services/reminder_copy.dart';
import 'package:agenda/services/task_database.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'support/design_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late Directory directory;
  setUpAll(() => databaseFactory = databaseFactoryFfi);

  setUp(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('flutter_timezone'),
      (_) async => 'Europe/Madrid',
    );
    AppLanguageBridge.phoneLocales = null;
    // The bridge saves the phone's languages in the app's database: a
    // temporary folder here, never the phone's.
    directory = await Directory.systemTemp.createTemp('taskflow-language-');
    await databaseFactory.setDatabasesPath(directory.path);
  });

  tearDown(() async {
    AppLanguageBridge.phoneLocales = null;
    await TaskDatabase().close();
    await directory.delete(recursive: true);
  });

  /// The per-app-language channel: records each call's `languages` and
  /// answers with whatever [phone] holds at the time.
  List<List<Object?>> fakeBridge(
    WidgetTester tester,
    List<String> Function() phone,
  ) {
    final calls = <List<Object?>>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      AppLanguageBridge.channel,
      (call) async {
        expect(call.method, 'apply');
        calls.add(
          List<Object?>.from(
            (call.arguments as Map)['languages'] as List<Object?>,
          ),
        );
        return phone();
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(AppLanguageBridge.channel, null),
    );
    return calls;
  }

  /// Pumps until the bridge's database write, which runs in real time, is done.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 5; i++) {
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 40)),
      );
    }
    await tester.pumpAndSettle();
  }

  Future<void> pumpApp(WidgetTester tester, String language) async {
    final container = designContainer(
      regionalStore: MemoryRegionalStore(
        RegionalPreferences(language: language),
      ),
    );
    addTearDown(container.dispose);
    // Open the database in real time first, so the bridge's write is quick,
    // and restore Idioma before the first frame, as main() does.
    await tester.runAsync(() async {
      await TaskDatabase().database;
      await container.read(regionalProvider.notifier).ready;
    });
    expect(container.read(regionalProvider).language, language);
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const MyApp()),
    );
    await settle(tester);
  }

  String appLanguage(WidgetTester tester) => Localizations.localeOf(
        tester.element(find.byType(Navigator).first),
      ).languageCode;

  testWidgets(
    'UX-1653: Idioma «Como el teléfono», the phone switches from Spanish to Catalan while the app runs: the app turns Catalan without a restart',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      try {
        var phone = ['es-ES'];
        final calls = fakeBridge(tester, () => phone);
        tester.platformDispatcher.localesTestValue = [const Locale('es', 'ES')];
        addTearDown(tester.platformDispatcher.clearLocalesTestValue);
        await pumpApp(tester, 'system');
        final es = lookupAppLocalizations(const Locale('es'));
        final ca = lookupAppLocalizations(const Locale('ca'));
        expect(appLanguage(tester), 'es');
        expect(find.text(es.todayAgenda), findsOneWidget);
        // At start, «Como el teléfono» is applied once.
        expect(calls, [<Object?>[]]);
        calls.clear();

        // The phone's language changes in Android settings; the activity
        // stays alive, so only didChangeLocales arrives.
        phone = ['ca-ES'];
        tester.platformDispatcher.localesTestValue = [const Locale('ca', 'ES')];
        await settle(tester);

        expect(appLanguage(tester), 'ca');
        expect(find.text(ca.todayAgenda), findsOneWidget);
        expect(find.text(es.todayAgenda), findsNothing);
        expect(tester.takeException(), isNull);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    },
  );

  testWidgets(
    'UX-1653: the locale change asks the bridge exactly once more, with languages [], and the fresh ca-ES is kept and saved',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      try {
        var phone = ['es-ES'];
        final calls = fakeBridge(tester, () => phone);
        tester.platformDispatcher.localesTestValue = [const Locale('es', 'ES')];
        addTearDown(tester.platformDispatcher.clearLocalesTestValue);
        await pumpApp(tester, 'system');
        expect(AppLanguageBridge.phoneLocales, [const Locale('es', 'ES')]);
        calls.clear();

        phone = ['ca-ES'];
        tester.platformDispatcher.localesTestValue = [const Locale('ca', 'ES')];
        await settle(tester);

        expect(calls, [<Object?>[]]);
        expect(AppLanguageBridge.phoneLocales, [const Locale('ca', 'ES')]);
        final saved = await tester.runAsync(
          () => AppLanguageBridge.readSavedPhoneLocales(TaskDatabase()),
        );
        expect(saved, [const Locale('ca', 'ES')]);
        expect(tester.takeException(), isNull);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    },
  );

  testWidgets(
    'UX-1653: right after the locale change, the reminders’ strings (no deviceLocales) are Catalan',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      try {
        var phone = ['es-ES'];
        fakeBridge(tester, () => phone);
        tester.platformDispatcher.localesTestValue = [const Locale('es', 'ES')];
        addTearDown(tester.platformDispatcher.clearLocalesTestValue);
        await pumpApp(tester, 'system');
        final before = await tester.runAsync(
          () => readReminderStrings(TaskDatabase()),
        );
        expect(before!.localeName, 'es');

        phone = ['ca-ES'];
        tester.platformDispatcher.localesTestValue = [const Locale('ca', 'ES')];
        await settle(tester);

        final after = await tester.runAsync(
          () => readReminderStrings(TaskDatabase()),
        );
        final ca = lookupAppLocalizations(const Locale('ca'));
        expect(after!.localeName, 'ca');
        expect(after.notificationToday, ca.notificationToday);
        expect(tester.takeException(), isNull);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    },
  );

  testWidgets(
    'UX-1653: Idioma English, the phone’s region changes: one more apply with [en], the app stays English and settles (no loop)',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      try {
        var phone = ['es-ES'];
        final calls = fakeBridge(tester, () => phone);
        // Under a per-app language Flutter reports the app's language.
        tester.platformDispatcher.localesTestValue = [const Locale('en', 'ES')];
        addTearDown(tester.platformDispatcher.clearLocalesTestValue);
        await pumpApp(tester, 'en');
        final en = lookupAppLocalizations(const Locale('en'));
        expect(find.text(en.todayAgenda), findsOneWidget);
        expect(calls, [
          ['en'],
        ]);
        calls.clear();

        phone = ['en-US'];
        tester.platformDispatcher.localesTestValue = [const Locale('en', 'US')];
        await settle(tester);

        expect(calls, [
          ['en'],
        ]);
        expect(AppLanguageBridge.phoneLocales, [const Locale('en', 'US')]);
        expect(appLanguage(tester), 'en');
        expect(find.text(en.todayAgenda), findsOneWidget);
        // The US phone's week starts on Sunday.
        expect(
          MaterialLocalizations.of(
            tester.element(find.byType(Navigator).first),
          ).firstDayOfWeekIndex,
          0,
        );
        expect(tester.takeException(), isNull);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    },
  );

  testWidgets(
    'UX-1653: off Android, a phone-language change makes no bridge call and the app and reminders still follow it',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      try {
        final calls = fakeBridge(tester, () => ['es-ES']);
        tester.platformDispatcher.localesTestValue = [const Locale('es', 'ES')];
        addTearDown(tester.platformDispatcher.clearLocalesTestValue);
        await pumpApp(tester, 'system');
        expect(appLanguage(tester), 'es');

        tester.platformDispatcher.localesTestValue = [const Locale('ca', 'ES')];
        await settle(tester);

        expect(calls, isEmpty);
        expect(AppLanguageBridge.phoneLocales, isNull);
        expect(appLanguage(tester), 'ca');
        final ca = lookupAppLocalizations(const Locale('ca'));
        expect(find.text(ca.todayAgenda), findsOneWidget);
        // The bridge returns at once off Android, so the reminder refresh
        // still runs; with no bridge answer and no saved row, the reminders'
        // strings are the phone's live language.
        final strings = await tester.runAsync(
          () => readReminderStrings(TaskDatabase()),
        );
        expect(strings!.localeName,
            const RegionalPreferences()
                .localeFor(PlatformDispatcher.instance.locales)
                .languageCode);
        expect(tester.takeException(), isNull);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    },
  );
}
