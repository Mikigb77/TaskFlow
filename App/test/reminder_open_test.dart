// Round 1 of 2026-10-13-app, P23 (UX-223): tapping a reminder whose task is
// gone never pushes a second app shell; it says the task may have been
// deleted, where the user already is.
import 'dart:io';

import 'package:agenda/l10n/generated/app_localizations.dart';
import 'package:agenda/main.dart';
import 'package:agenda/providers/regional_provider.dart';
import 'package:agenda/screens/calendar_screen.dart';
import 'package:agenda/screens/main_shell.dart';
import 'package:agenda/services/notification_service.dart';
import 'package:agenda/services/task_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'support/design_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  const timeoutChannel = MethodChannel('taskflow/accessibility');
  final platform =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late Directory directory;
  setUpAll(() => databaseFactory = databaseFactoryFfi);

  setUp(() async {
    platform.setMockMethodCallHandler(timeoutChannel, (_) async => null);
    // The reminder engine reads its alerts from a database in a temporary
    // folder, never the phone's.
    directory = await Directory.systemTemp.createTemp('taskflow-reminder-');
    await databaseFactory.setDatabasesPath(directory.path);
  });

  tearDown(() async {
    platform.setMockMethodCallHandler(timeoutChannel, null);
    TaskReminders.openRequest.value = null;
    await TaskDatabase().close();
    await directory.delete(recursive: true);
  });

  for (final language in ['es', 'en', 'ca']) {
    testWidgets(
      'UX-223: a reminder whose task is gone keeps the one app shell and shows Es posible que esta tarea se haya eliminado ($language)',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final container = designContainer(
          regionalStore: MemoryRegionalStore(
            RegionalPreferences(language: language),
          ),
        );
        addTearDown(container.dispose);
        await tester.pumpWidget(
          UncontrolledProviderScope(container: container, child: const MyApp()),
        );
        await tester.pumpAndSettle();
        final l = lookupAppLocalizations(Locale(language));
        expect(find.byType(CalendarScreen), findsOneWidget);
        expect(find.byType(MainShell, skipOffstage: false), findsOneWidget);
        final navigator = tester.state<NavigatorState>(
          find.byType(Navigator).first,
        );
        expect(navigator.canPop(), isFalse);

        // Open the database first, in real time, so the lookup is quick.
        await tester.runAsync(() => TaskDatabase().database);
        // The user taps a notification for an alert this phone no longer has.
        await tester.runAsync(() async {
          TaskReminders.openRequest.value = const ReminderReference(
            424242,
            'stale-token',
          );
          await Future<void>.delayed(const Duration(milliseconds: 50));
        });
        final message = find.text(l.taskRemoved);
        for (var i = 0; i < 50 && message.evaluate().isEmpty; i++) {
          await tester.pump();
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 20)),
          );
        }
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        expect(message, findsOneWidget);
        if (language == 'es') {
          expect(l.taskRemoved, 'Es posible que esta tarea se haya eliminado.');
        }
        // Still the one shell, on Calendario, with nothing pushed.
        expect(find.byType(MainShell, skipOffstage: false), findsOneWidget);
        expect(find.byType(CalendarScreen), findsOneWidget);
        expect(
          tester.state<NavigatorState>(find.byType(Navigator).first).canPop(),
          isFalse,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
}
