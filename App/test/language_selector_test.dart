import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:agenda/services/task_database.dart';
import 'package:agenda/services/app_language.dart';
import 'dart:convert';
import 'dart:async';
import 'package:agenda/l10n/generated/app_localizations.dart';
import 'package:agenda/main.dart';
import 'package:agenda/providers/regional_provider.dart';
import 'package:agenda/providers/theme_provider.dart';
import 'package:agenda/screens/settings_screen.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/design_fixtures.dart';

void main() {
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('flutter_timezone'),
      (_) async => 'Europe/Madrid',
    );
  });

  testWidgets(
    'Settings switches the whole app, persists selection and follows later phone changes',
    (tester) async {
      tester.platformDispatcher.localesTestValue = [const Locale('fr', 'FR')];
      addTearDown(tester.platformDispatcher.clearLocalesTestValue);
      final store = MemoryRegionalStore(const RegionalPreferences());
      final container = designContainer(regionalStore: store);
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(container: container, child: const MyApp()),
      );
      await tester.pumpAndSettle();
      expect(find.text('Today’s agenda'), findsOneWidget);
      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      navigator.pushNamed('/settings');
      await tester.pumpAndSettle();
      final selector = find.byKey(const ValueKey('settings-language'));
      await tester.scrollUntilVisible(selector, 180,
          scrollable: find
              .descendant(
                  of: find.byType(SettingsScreen),
                  matching: find.byType(Scrollable))
              .first);
      await tester.pumpAndSettle();
      await tester.tap(selector);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('language-system')), findsOneWidget);
      expect(find.byKey(const ValueKey('language-es')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('language-ca')));
      await tester.pumpAndSettle();
      expect(store.value.language, 'ca');
      expect(find.byType(BottomSheet), findsNothing);
      expect(find.text('Idioma'), findsOneWidget);
      tester.platformDispatcher.localesTestValue = [const Locale('es', 'MX')];
      await tester.pumpAndSettle();
      expect(find.text('Català'), findsOneWidget);
      navigator.pop();
      await tester.pumpAndSettle();
      expect(find.text('L’agenda d’avui'), findsOneWidget);
      expect(container.read(regionalProvider).language, 'ca');

      navigator.pushNamed('/settings');
      await tester.pumpAndSettle();
      await tester.tap(selector);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('language-system')));
      await tester.pumpAndSettle();
      expect(store.value.language, 'system');
      expect(find.text('Recordatorios'), findsOneWidget);
      tester.platformDispatcher.localesTestValue = [const Locale('ja', 'JP')];
      await tester.pumpAndSettle();
      expect(find.text('Reminders'), findsOneWidget);
      expect(find.text('Same as phone · English'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  for (final theme in [ThemeMode.light, ThemeMode.dark]) {
    testWidgets(
      'Catalan language choices stay usable at 2x text on a small phone, $theme',
      (tester) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final store = MemoryRegionalStore(
          const RegionalPreferences(language: 'ca'),
        );
        final container = designContainer(regionalStore: store);
        addTearDown(container.dispose);
        await container.read(themeModeProvider.notifier).setMode(theme);
        await tester.pumpWidget(
          UncontrolledProviderScope(container: container, child: const MyApp()),
        );
        await tester.pumpAndSettle();
        tester
            .state<NavigatorState>(find.byType(Navigator))
            .pushNamed('/settings');
        await tester.pumpAndSettle();
        final selector = find.byKey(const ValueKey('settings-language'));
        await tester.scrollUntilVisible(selector, 160,
            scrollable: find
                .descendant(
                    of: find.byType(SettingsScreen),
                    matching: find.byType(Scrollable))
                .first);
        await tester.pumpAndSettle();
        await tester.tap(selector);
        await tester.pumpAndSettle();
        final english = find.byKey(const ValueKey('language-en'));
        await tester.scrollUntilVisible(
          english,
          100,
          scrollable: find
              .descendant(
                of: find.byType(BottomSheet),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        await tester.pumpAndSettle();
        await tester.tap(english);
        await tester.pumpAndSettle();
        expect(store.value.language, 'en');
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'failed persistence rolls back the language and keeps the selector open',
    (tester) async {
      final store = _FailingStore();
      final container = designContainer(regionalStore: store);
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(container: container, child: const MyApp()),
      );
      await tester.pumpAndSettle();
      tester
          .state<NavigatorState>(find.byType(Navigator))
          .pushNamed('/settings');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('settings-language')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('language-ca')));
      await tester.pumpAndSettle();
      expect(container.read(regionalProvider).language, 'en');
      expect(find.byType(BottomSheet), findsOneWidget);
      expect(
        find.text('Could not save this preference. Please try again.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'UX-482: in Catalan at 2x text on 320×568 the Idioma sheet opens with no overflow, and every row (Com el telèfon, Español, Català, English) scrolls into view and can be chosen',
    (tester) async {
      final ca = lookupAppLocalizations(const Locale('ca'));
      expect(ca.languageAutomatic, 'Com el telèfon');
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final store = MemoryRegionalStore(
        const RegionalPreferences(language: 'ca'),
      );
      final container = designContainer(regionalStore: store);
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(container: container, child: const MyApp()),
      );
      await tester.pumpAndSettle();
      tester
          .state<NavigatorState>(find.byType(Navigator))
          .pushNamed('/settings');
      await tester.pumpAndSettle();
      final selector = find.byKey(const ValueKey('settings-language'));
      // The first sheet opens in Catalan, before any choice.
      var catalan = true;
      for (final code in ['system', 'es', 'en', 'ca']) {
        await tester.scrollUntilVisible(
          selector,
          160,
          scrollable: find
              .descendant(
                of: find.byType(SettingsScreen),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        await tester.pumpAndSettle();
        await tester.tap(selector);
        await tester.pumpAndSettle();
        final sheet = find.byType(BottomSheet);
        expect(sheet, findsOneWidget);
        expect(tester.takeException(), isNull, reason: 'opening for $code');
        if (catalan) {
          expect(
            find.descendant(
              of: sheet,
              matching: find.text(ca.languageAutomatic),
            ),
            findsOneWidget,
          );
          catalan = false;
        }
        final row = find.descendant(
          of: sheet,
          matching: find.byKey(ValueKey('language-$code')),
        );
        await tester.scrollUntilVisible(
          row,
          100,
          scrollable: find
              .descendant(of: sheet, matching: find.byType(Scrollable))
              .first,
        );
        await tester.pumpAndSettle();
        expect(row.hitTestable(), findsOneWidget, reason: code);
        await tester.tap(row);
        await tester.pumpAndSettle();
        expect(store.value.language, code);
        expect(find.byType(BottomSheet), findsNothing, reason: code);
        expect(tester.takeException(), isNull, reason: code);
      }
    },
  );

  // ---- P186 (UX-1621): Idioma's choice becomes the per-app language ----

  Future<List<List<Object?>>> recordLanguageBridge(WidgetTester tester) async {
    final calls = <List<Object?>>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('taskflow/app-language'),
      (call) async {
        expect(call.method, 'apply');
        calls.add(
          List<Object?>.from(
            (call.arguments as Map)['languages'] as List<Object?>,
          ),
        );
        return <String>['es-ES'];
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('taskflow/app-language'),
        null,
      ),
    );
    return calls;
  }

  Future<void> chooseLanguage(WidgetTester tester, String code) async {
    final selector = find.byKey(const ValueKey('settings-language'));
    await tester.scrollUntilVisible(
      selector,
      180,
      scrollable: find
          .descendant(
            of: find.byType(SettingsScreen),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pumpAndSettle();
    await tester.tap(selector);
    await tester.pumpAndSettle();
    final row = find.byKey(ValueKey('language-$code'));
    await tester.scrollUntilVisible(
      row,
      100,
      scrollable: find
          .descendant(
            of: find.byType(BottomSheet),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pumpAndSettle();
    await tester.tap(row);
    await tester.pumpAndSettle();
  }

  testWidgets(
    'UX-1621: on Android, choosing Català in Idioma applies «ca» as the per-app language, and Como el teléfono applies an empty list',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      try {
        tester.platformDispatcher.localesTestValue = [const Locale('es', 'ES')];
        addTearDown(tester.platformDispatcher.clearLocalesTestValue);
        final calls = await recordLanguageBridge(tester);
        final store = MemoryRegionalStore(const RegionalPreferences());
        final container = designContainer(regionalStore: store);
        addTearDown(container.dispose);
        await tester.pumpWidget(
          UncontrolledProviderScope(container: container, child: const MyApp()),
        );
        await tester.pumpAndSettle();
        // At start, the stored choice (Como el teléfono) is applied.
        expect(calls, [<Object?>[]]);
        calls.clear();
        tester
            .state<NavigatorState>(find.byType(Navigator))
            .pushNamed('/settings');
        await tester.pumpAndSettle();

        await chooseLanguage(tester, 'ca');
        expect(store.value.language, 'ca');
        expect(calls, [
          ['ca'],
        ]);
        calls.clear();

        await chooseLanguage(tester, 'system');
        expect(store.value.language, 'system');
        expect(calls, [<Object?>[]]);
        expect(tester.takeException(), isNull);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    },
  );

  testWidgets(
    'UX-1621: off Android, choosing a language never calls the per-app-language bridge',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      try {
        final calls = await recordLanguageBridge(tester);
        final store = MemoryRegionalStore(const RegionalPreferences());
        final container = designContainer(regionalStore: store);
        addTearDown(container.dispose);
        await tester.pumpWidget(
          UncontrolledProviderScope(container: container, child: const MyApp()),
        );
        await tester.pumpAndSettle();
        tester
            .state<NavigatorState>(find.byType(Navigator))
            .pushNamed('/settings');
        await tester.pumpAndSettle();
        await chooseLanguage(tester, 'ca');
        expect(store.value.language, 'ca');
        await chooseLanguage(tester, 'system');
        expect(store.value.language, 'system');
        expect(calls, isEmpty);
        expect(tester.takeException(), isNull);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    },
  );

  // ---- Run 2026-10-19-app · P215 (UX-1649): «Como el teléfono» reads the phone ----

  group('P215', () {
    setUp(() => AppLanguageBridge.phoneLocales = null);
    tearDown(() => AppLanguageBridge.phoneLocales = null);

    /// The per-app-language channel answers [phone] once [answer] completes.
    Completer<void> gateLanguageBridge(
      WidgetTester tester,
      List<String>? phone,
    ) {
      final answer = Completer<void>();
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        AppLanguageBridge.channel,
        (call) async {
          await answer.future;
          return phone;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          AppLanguageBridge.channel,
          null,
        ),
      );
      return answer;
    }

    Future<ProviderContainer> pumpApp(
      WidgetTester tester, {
      required List<Locale> flutterLocales,
      required String language,
    }) async {
      tester.platformDispatcher.localesTestValue = flutterLocales;
      addTearDown(tester.platformDispatcher.clearLocalesTestValue);
      final container = designContainer(
        regionalStore: MemoryRegionalStore(
          // weekStart null: «Primer día de la semana: Como el teléfono».
          RegionalPreferences(language: language),
        ),
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(container: container, child: const MyApp()),
      );
      return container;
    }

    int weekStart(WidgetTester tester) => MaterialLocalizations.of(
      tester.element(find.byType(Navigator).first),
    ).firstDayOfWeekIndex;

    /// An in-memory task database with the app's tables, for [body].
    Future<T?> withDatabase<T>(
      WidgetTester tester,
      Future<T> Function(TaskDatabase database, Database sql) body,
    ) => tester.runAsync(() async {
      sqfliteFfiInit();
      final sql = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
      await sql.execute(
        'CREATE TABLE tasks(id INTEGER PRIMARY KEY AUTOINCREMENT, title TEXT, dueDate TEXT, priority INTEGER, isCompleted INTEGER, notes TEXT, filePaths TEXT, imagePaths TEXT)',
      );
      await TaskDatabase.upgrade(sql, 3, TaskDatabase.schemaVersion);
      try {
        return await body(TaskDatabase.forTesting(sql), sql);
      } finally {
        await sql.close();
      }
    });

    testWidgets(
      'UX-1649: Spanish phone, Idioma English, week start Como el teléfono: Monday once Android answers, with no other rebuild',
      (tester) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.android;
        try {
          final answer = gateLanguageBridge(tester, ['es-ES']);
          // Under the per-app language Flutter reports the app's locale.
          await pumpApp(
            tester,
            flutterLocales: [const Locale('en', 'ES')],
            language: 'en',
          );
          await tester.pump();
          expect(find.text('Today’s agenda'), findsOneWidget);
          // Before Android answers, Flutter's en-ES gives Material en: Sunday.
          expect(weekStart(tester), 0);
          answer.complete();
          await tester.pumpAndSettle();
          expect(AppLanguageBridge.phoneLocales, [const Locale('es', 'ES')]);
          expect(weekStart(tester), 1);
          // The app's language stays English.
          expect(find.text('Today’s agenda'), findsOneWidget);
          expect(tester.takeException(), isNull);
        } finally {
          debugDefaultTargetPlatformOverride = null;
        }
      },
    );

    testWidgets(
      'UX-1649: with the phone’s languages saved as es-ES and Android not yet answered, the first frame already starts the week on Monday',
      (tester) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.android;
        try {
          gateLanguageBridge(tester, ['es-ES']);
          // What main() does before runApp: read the saved row and seed the
          // bridge with it.
          await withDatabase(tester, (database, sql) async {
            await sql.insert('app_preferences', {
              'scope': 'phone-locales',
              'data': jsonEncode(['es-ES']),
            });
            AppLanguageBridge.phoneLocales ??=
                await AppLanguageBridge.readSavedPhoneLocales(database);
          });
          expect(AppLanguageBridge.phoneLocales, [const Locale('es', 'ES')]);
          await pumpApp(
            tester,
            flutterLocales: [const Locale('en', 'ES')],
            language: 'en',
          );
          await tester.pump();
          // Android hasn't answered: the saved row decides the first frame.
          expect(weekStart(tester), 1);
          expect(tester.takeException(), isNull);
        } finally {
          debugDefaultTargetPlatformOverride = null;
        }
      },
    );

    testWidgets(
      'UX-1649: US English phone, Idioma Español, week start Como el teléfono: Sunday, the phone’s, not Spanish Monday',
      (tester) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.android;
        try {
          final answer = gateLanguageBridge(tester, ['en-US']);
          await pumpApp(
            tester,
            flutterLocales: [const Locale('es', 'US')],
            language: 'es',
          );
          answer.complete();
          await tester.pumpAndSettle();
          expect(find.text('Agenda de hoy'), findsOneWidget);
          expect(weekStart(tester), 0);
          expect(tester.takeException(), isNull);
        } finally {
          debugDefaultTargetPlatformOverride = null;
        }
      },
    );

    testWidgets(
      'UX-1649: below Android 13 the channel answers null: Flutter’s locales decide, as before',
      (tester) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.android;
        try {
          final answer = gateLanguageBridge(tester, null);
          await pumpApp(
            tester,
            flutterLocales: [const Locale('en', 'US')],
            language: 'es',
          );
          answer.complete();
          await tester.pumpAndSettle();
          expect(AppLanguageBridge.phoneLocales, isNull);
          // Flutter's en-US: Sunday, as before P215.
          expect(weekStart(tester), 0);
          expect(tester.takeException(), isNull);
        } finally {
          debugDefaultTargetPlatformOverride = null;
        }
      },
    );

    for (final (name, answer, saved) in [
      ('Android 13+ answers es-ES, en-US', <String>['es-ES', 'en-US'], true),
      ('below Android 13 the channel answers null', null, false),
      ('the channel answers an empty list', <String>[], false),
    ]) {
      testWidgets(
        'UX-1649: apply keeps the phone’s languages on the phone only when Android reports them: $name',
        (tester) async {
          debugDefaultTargetPlatformOverride = TargetPlatform.android;
          try {
            tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
              AppLanguageBridge.channel,
              (_) async => answer,
            );
            addTearDown(
              () => tester.binding.defaultBinaryMessenger
                  .setMockMethodCallHandler(AppLanguageBridge.channel, null),
            );
            final result = await withDatabase(tester, (database, sql) async {
              await AppLanguageBridge.apply('en', database: database);
              final rows = await sql.query(
                'app_preferences',
                where: 'scope = ?',
                whereArgs: ['phone-locales'],
              );
              return (
                rows,
                await AppLanguageBridge.readSavedPhoneLocales(database),
              );
            });
            final (rows, read) = result!;
            if (saved) {
              expect(rows.single['data'], jsonEncode(['es-ES', 'en-US']));
              expect(read, [
                const Locale('es', 'ES'),
                const Locale('en', 'US'),
              ]);
              expect(AppLanguageBridge.phoneLocales, read);
              expect(AppLanguageBridge.phoneOr([const Locale('fr')]), read);
            } else {
              expect(rows, isEmpty);
              expect(read, isNull);
              expect(AppLanguageBridge.phoneLocales, isNull);
              final flutter = [const Locale('fr', 'FR')];
              expect(AppLanguageBridge.phoneOr(flutter), flutter);
            }
          } finally {
            debugDefaultTargetPlatformOverride = null;
          }
        },
      );
    }

    testWidgets(
      'UX-1649: off Android, apply calls nothing and phoneOr returns Flutter’s locales',
      (tester) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
        try {
          var calls = 0;
          tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            AppLanguageBridge.channel,
            (_) async {
              calls++;
              return ['es-ES'];
            },
          );
          addTearDown(
            () => tester.binding.defaultBinaryMessenger
                .setMockMethodCallHandler(AppLanguageBridge.channel, null),
          );
          await AppLanguageBridge.apply('en');
          expect(calls, 0);
          expect(AppLanguageBridge.phoneLocales, isNull);
          final flutter = [const Locale('en', 'GB')];
          expect(AppLanguageBridge.phoneOr(flutter), flutter);
        } finally {
          debugDefaultTargetPlatformOverride = null;
        }
      },
    );
  });

  // ---- UX loop 2026-10-28-app, round 1 · P295 (UX-2609): the language
  // sheet closes at once ----
  group('P295 · the language sheet closes at once', () {
    testWidgets(
      'UX-2609: on Android, with the per-app-language bridge never answering after start, choosing Català closes the sheet at once and the app shows in Catalan',
      (tester) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.android;
        try {
          final never = Completer<List<String>>();
          var calls = 0;
          tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            AppLanguageBridge.channel,
            (_) async {
              calls++;
              // The start's apply answers; the choice's never does.
              if (calls == 1) return <String>['es-ES'];
              return never.future;
            },
          );
          addTearDown(
            () => tester.binding.defaultBinaryMessenger
                .setMockMethodCallHandler(AppLanguageBridge.channel, null),
          );
          final store = MemoryRegionalStore(
            const RegionalPreferences(language: 'es'),
          );
          final container = designContainer(regionalStore: store);
          addTearDown(container.dispose);
          await tester.pumpWidget(
            UncontrolledProviderScope(
              container: container,
              child: const MyApp(),
            ),
          );
          await tester.pumpAndSettle();
          tester
              .state<NavigatorState>(find.byType(Navigator))
              .pushNamed('/settings');
          await tester.pumpAndSettle();
          final selector = find.byKey(const ValueKey('settings-language'));
          await tester.scrollUntilVisible(
            selector,
            180,
            scrollable: find
                .descendant(
                  of: find.byType(SettingsScreen),
                  matching: find.byType(Scrollable),
                )
                .first,
          );
          await tester.pumpAndSettle();
          await tester.tap(selector);
          await tester.pumpAndSettle();
          expect(find.byType(BottomSheet), findsOneWidget);
          await tester.tap(find.byKey(const ValueKey('language-ca')));
          // The sheet's closing starts with the save, not after the bridge.
          await tester.pumpAndSettle(const Duration(milliseconds: 100));
          expect(find.byType(BottomSheet), findsNothing);
          expect(store.value.language, 'ca');
          expect(calls, 2, reason: 'the bridge was asked, and never answers');
          expect(never.isCompleted, isFalse);
          final ca = lookupAppLocalizations(const Locale('ca'));
          expect(find.text(ca.language), findsWidgets);
          expect(find.text('Català'), findsOneWidget);
          expect(
            Localizations.localeOf(
              tester.element(find.byType(SettingsScreen)),
            ).languageCode,
            'ca',
          );
          expect(tester.takeException(), isNull);
        } finally {
          debugDefaultTargetPlatformOverride = null;
        }
      },
    );
  });

}

class _FailingStore extends MemoryRegionalStore {
  @override
  Future<void> write(RegionalPreferences value) async =>
      throw StateError('Disk full');
}
