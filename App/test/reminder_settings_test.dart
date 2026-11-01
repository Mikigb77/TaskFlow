import 'package:agenda/l10n/generated/app_localizations.dart';
import 'package:agenda/providers/reminder_provider.dart';
import 'package:agenda/providers/task_provider.dart';
import 'package:agenda/repositories/task_repository.dart';
import 'package:agenda/screens/notification_settings_screen.dart';
import 'package:agenda/services/reminder_preferences.dart';
import 'package:agenda/services/task_database.dart';
import 'package:agenda/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:agenda/l10n/region.dart';
import 'package:agenda/main.dart';
import 'package:agenda/models/task.dart';
import 'package:agenda/providers/regional_provider.dart';
import 'package:agenda/services/reminder_engine.dart';
import 'package:agenda/widgets/reminder_control.dart';
import 'package:agenda/widgets/task_editor.dart';
import 'package:agenda/services/notification_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:io';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:agenda/models/task_list_info.dart';
import 'package:agenda/providers/calendar_focus_provider.dart';
import 'support/design_fixtures.dart';
import 'support/phone_alerts.dart';
import 'support/reminder_fixtures.dart';

void main() {
  for (final lang in ['en', 'es']) {
    testWidgets(
      '$lang notification defaults and diagnostics fit large text in both themes',
      (tester) async {
        final database = TaskDatabase();
        final store = _Preferences(database);
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        for (final theme in [AppTheme.light, AppTheme.dark]) {
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                reminderPreferenceStoreProvider.overrideWithValue(store),
                taskRepositoryProvider.overrideWithValue(
                  TaskRepository(database),
                ),
              ],
              child: MaterialApp(
                locale: Locale(lang),
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                theme: theme,
                builder: (_, child) => MediaQuery(
                  data: const MediaQueryData(
                    size: Size(320, 568),
                    textScaler: TextScaler.linear(2),
                  ),
                  child: child!,
                ),
                home: const NotificationSettingsScreen(),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final timed = find.text(
            lang == 'es' ? 'Tareas con hora' : 'Timed tasks',
          );
          await tester.scrollUntilVisible(timed, 160);
          await tester.pumpAndSettle();
          await tester.tap(timed);
          await tester.pumpAndSettle();
          final thirty = find
              .text(lang == 'es' ? '30 minutos antes' : '30 minutes before')
              .last;
          // At 2× on a small phone the list scrolls.
          await tester.ensureVisible(thirty);
          await tester.pumpAndSettle();
          await tester.tap(thirty);
          await tester.pumpAndSettle();
          expect((await store.read('local')).leadMinutes, 30);
          // Check-ins, upcoming alerts and explanations start folded away.
          expect(find.text('Original task title'), findsNothing);
          final details = find.text(lang == 'es' ? 'Detalles' : 'Details');
          await tester.scrollUntilVisible(details, 160);
          await tester.pumpAndSettle();
          await tester.tap(details);
          await tester.pumpAndSettle();
          await tester.scrollUntilVisible(
            find.text('Original task title'),
            180,
          );
          await tester.pumpAndSettle();
          expect(
            find.textContaining(lang == 'es' ? ' · bloqueado' : ' · blocked'),
            findsOneWidget,
          );
          expect(
            find.textContaining(
              lang == 'es'
                  ? 'Las notificaciones están desactivadas'
                  : 'Notifications are disabled',
            ),
            findsOneWidget,
          );
          expect(store.alerts.single['status'], 'blocked');
          expect(
            store.alerts.single['error'],
            'Notifications are disabled in system settings.',
          );
          await tester.scrollUntilVisible(
            find.text(lang == 'es' ? 'Reintentar' : 'Try again'),
            -180,
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
        }
      },
    );
  }

  group('P8 / P32: turning reminders on', () {
    const timeoutChannel = MethodChannel('taskflow/accessibility');
    final platform =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    setUp(
      () =>
          platform.setMockMethodCallHandler(timeoutChannel, (_) async => null),
    );
    tearDown(() => platform.setMockMethodCallHandler(timeoutChannel, null));
    final es = lookupAppLocalizations(const Locale('es'));
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    final timed = Task(
      id: 1,
      title: 'Médico',
      priority: 1,
      dueDate: DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 10),
    );

    Widget app(
      MemoryReminderStore store,
      FakeReminderAccess access,
      Widget home, {
      String language = 'es',
    }) => ProviderScope(
      overrides: [
        ...reminderOverrides(store, access),
        taskRepositoryProvider.overrideWithValue(MemoryTasks()),
      ],
      child: MaterialApp(
        locale: Locale(language),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: AppTheme.light,
        home: home,
      ),
    );

    Future<ValueNotifier<Task>> pumpChip(
      WidgetTester tester,
      MemoryReminderStore store,
      FakeReminderAccess access,
    ) async {
      final task = ValueNotifier(timed);
      addTearDown(task.dispose);
      await tester.pumpWidget(
        app(
          store,
          access,
          Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(24),
              child: ValueListenableBuilder<Task>(
                valueListenable: task,
                builder: (context, value, _) => ReminderChip(
                  task: value,
                  onChanged: (changed) => task.value = changed,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return task;
    }

    Finder chipText(String text) => find.descendant(
      of: find.byType(ReminderChip),
      matching: find.text(text),
    );
    String lead(WidgetTester tester, int minutes) =>
        tester.element(find.byType(ReminderChip)).reminderLead(minutes);

    for (final (name, settings, allowed) in [
      ('the switch is off', const ReminderPreferences(), true),
      (
        'the switch is on but the permission is denied',
        const ReminderPreferences(enabled: true),
        false,
      ),
    ]) {
      testWidgets(
        'UX-209: when $name the chip reads Sin recordatorio · Activar; granting it reads normally',
        (tester) async {
          final store = MemoryReminderStore(settings);
          final access = FakeReminderAccess(allowed: allowed);
          await pumpChip(tester, store, access);
          expect(chipText(es.noReminderTurnOn), findsOneWidget);
          expect(
            find.descendant(
              of: find.byType(ReminderChip),
              matching: find.byIcon(Icons.notifications_off_outlined),
            ),
            findsOneWidget,
          );
          await tester.tap(find.byType(ReminderChip));
          await tester.pumpAndSettle();
          expect(access.permissionRequests, 1);
          expect(store.value.enabled, isTrue);
          expect(chipText(es.noReminderTurnOn), findsNothing);
          expect(chipText(es.reminderValue(lead(tester, 10))), findsOneWidget);
          expect(
            find.descendant(
              of: find.byType(ReminderChip),
              matching: find.byIcon(Icons.notifications_outlined),
            ),
            findsOneWidget,
          );
          expect(find.text(es.remindersOnConfirmation), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );
    }

    testWidgets(
      'UX-209: a refused permission leaves reminders off and offers the phone’s settings',
      (tester) async {
        final store = MemoryReminderStore();
        final access = FakeReminderAccess(grant: false);
        await pumpChip(tester, store, access);
        await tester.tap(find.byType(ReminderChip));
        await tester.pumpAndSettle();
        expect(store.value.enabled, isFalse);
        expect(chipText(es.noReminderTurnOn), findsOneWidget);
        expect(find.text(es.notificationPermissionOff), findsOneWidget);
        expect(
          find.widgetWithText(SnackBarAction, es.allowNotifications),
          findsOneWidget,
        );
        expect(find.text(es.remindersOnConfirmation), findsNothing);
      },
    );

    testWidgets(
      'UX-405: without exact alarms the action asks once for Alarmas y recordatorios',
      (tester) async {
        final store = MemoryReminderStore();
        final access = FakeReminderAccess(exact: false);
        await pumpChip(tester, store, access);
        await tester.tap(find.byType(ReminderChip));
        await tester.pumpAndSettle();
        final sheet = find.byType(BottomSheet);
        expect(
          find.descendant(of: sheet, matching: find.text(es.exactAlarmsNeeded)),
          findsOneWidget,
        );
        await tester.tap(
          find.descendant(
            of: sheet,
            matching: find.widgetWithText(FilledButton, es.allowPreciseAlarms),
          ),
        );
        await tester.pumpAndSettle();
        expect(access.exactRequests, 1);
        expect(store.value.enabled, isTrue);
        expect(find.byType(BottomSheet), findsNothing);
        expect(find.text(es.remindersOnConfirmation), findsOneWidget);
      },
    );

    testWidgets(
      'UX-435 / UX-436: the sheet’s button names «Alarmas y recordatorios»; closing it without allowing asks again instead of saying Listo',
      (tester) async {
        expect(es.allowPreciseAlarms, 'Permitir «Alarmas y recordatorios»');
        final store = MemoryReminderStore();
        final access = FakeReminderAccess(exact: false);
        await pumpChip(tester, store, access);
        await tester.tap(find.byType(ReminderChip));
        await tester.pumpAndSettle();
        final sheet = find.byType(BottomSheet);
        expect(
          find.descendant(
            of: sheet,
            matching: find.widgetWithText(FilledButton, es.allowPreciseAlarms),
          ),
          findsOneWidget,
        );
        expect(find.text('Permitir alarmas exactas'), findsNothing);
        // Closed without allowing: tap above the sheet.
        await tester.tapAt(const Offset(20, 20));
        await tester.pumpAndSettle();
        expect(find.byType(BottomSheet), findsNothing);
        expect(access.exactRequests, 0);
        final snack = find.byType(SnackBar);
        expect(snack, findsOneWidget);
        expect(
          find.descendant(of: snack, matching: find.text(es.exactAlarmsNeeded)),
          findsOneWidget,
        );
        expect(
          es.exactAlarmsNeeded,
          'Para que el aviso llegue a su hora, permite «Alarmas y recordatorios».',
        );
        expect(
          find.descendant(of: snack, matching: find.byType(SnackBarAction)),
          findsNothing,
        );
        expect(find.text(es.remindersOnConfirmation), findsNothing);
        expect(find.text('Listo. Recordatorios activados.'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'UX-436: with exact alarms on, the chip turns reminders on and says Listo. Recordatorios activados.',
      (tester) async {
        final store = MemoryReminderStore();
        final access = FakeReminderAccess(exact: true);
        await pumpChip(tester, store, access);
        await tester.tap(find.byType(ReminderChip));
        await tester.pumpAndSettle();
        expect(find.byType(BottomSheet), findsNothing);
        expect(store.value.enabled, isTrue);
        expect(es.remindersOnConfirmation, 'Listo. Recordatorios activados.');
        expect(
          find.descendant(
            of: find.byType(SnackBar),
            matching: find.text(es.remindersOnConfirmation),
          ),
          findsOneWidget,
        );
        expect(
          find.text('Listo. Te avisaremos antes de cada tarea con hora.'),
          findsNothing,
        );
      },
    );

    testWidgets(
      'UX-435: Notificaciones with exact alarms off offers Permitir «Alarmas y recordatorios»',
      (tester) async {
        final store = MemoryReminderStore(
          const ReminderPreferences(enabled: true, asked: true),
        );
        final access = FakeReminderAccess(allowed: true, exact: false);
        await tester.pumpWidget(
          app(store, access, const NotificationSettingsScreen()),
        );
        await tester.pumpAndSettle();
        final button = find.text('Permitir «Alarmas y recordatorios»');
        expect(button, findsOneWidget);
        expect(find.text(es.allowPreciseAlarms), findsOneWidget);
        await tester.tap(button);
        await tester.pumpAndSettle();
        expect(access.exactRequests, 1);
        expect(tester.takeException(), isNull);
      },
    );

    test('UX-435 / UX-436 / UX-438: the new copy in English and Catalan', () {
      final en = lookupAppLocalizations(const Locale('en'));
      final ca = lookupAppLocalizations(const Locale('ca'));
      expect(en.allowPreciseAlarms, 'Allow “Alarms & reminders”');
      expect(en.remindersOnConfirmation, 'Done. Reminders are on.');
      expect(ca.allowPreciseAlarms, 'Permet «Alarmes i recordatoris»');
      expect(ca.remindersOnConfirmation, 'Fet. Recordatoris activats.');
    });

    testWidgets(
      'UX-210: chip → 1 hora antes applies, closes the list and the chip reads it',
      (tester) async {
        final store = MemoryReminderStore(
          const ReminderPreferences(enabled: true, asked: true),
        );
        final access = FakeReminderAccess(allowed: true);
        final task = await pumpChip(tester, store, access);
        expect(find.byType(PopupMenuButton<int>), findsNothing);
        expect(chipText(es.reminderValue(lead(tester, 10))), findsOneWidget);
        await tester.tap(find.byType(ReminderChip));
        await tester.pumpAndSettle();
        final sheet = find.byType(BottomSheet);
        expect(sheet, findsOneWidget);
        final hour = lead(tester, 60);
        await tester.tap(find.descendant(of: sheet, matching: find.text(hour)));
        await tester.pumpAndSettle();
        expect(find.byType(BottomSheet), findsNothing);
        expect(task.value.reminderMinutes, 60);
        expect(chipText(es.reminderValue(hour)), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'UX-210: in the task form, tapping Recordatorio opens the list',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final container = designContainer(
          regionalStore: MemoryRegionalStore(
            const RegionalPreferences(language: 'es'),
          ),
          overrides: reminderOverrides(
            MemoryReminderStore(
              const ReminderPreferences(enabled: true, asked: true),
            ),
            FakeReminderAccess(allowed: true),
          ),
        );
        addTearDown(container.dispose);
        await tester.pumpWidget(
          UncontrolledProviderScope(container: container, child: const MyApp()),
        );
        await tester.pumpAndSettle();
        // The form edits a saved task; this one is date-only.
        final now = DateTime.now();
        tester
            .state<NavigatorState>(find.byType(Navigator))
            .push(
              MaterialPageRoute<void>(
                builder: (_) => TaskEditor(
                  task: Task(
                    id: 1,
                    title: 'Comprar pan',
                    priority: 1,
                    dueDate: DateTime(now.year, now.month, now.day),
                    hasTime: false,
                  ),
                ),
              ),
            );
        await tester.pumpAndSettle();
        final more = find.byKey(const ValueKey('task-more-details'));
        await tester.ensureVisible(more);
        await tester.pumpAndSettle();
        await tester.tap(more);
        await tester.pumpAndSettle();
        final row = find.widgetWithText(ListTile, es.reminder);
        await tester.ensureVisible(row);
        await tester.pumpAndSettle();
        await tester.tap(row);
        await tester.pumpAndSettle();
        final sheet = find.byType(BottomSheet);
        expect(sheet, findsOneWidget);
        // A date-only task: the default, off, or a time of its own.
        expect(
          find.descendant(of: sheet, matching: find.text(es.chooseAlertTime)),
          findsOneWidget,
        );
        await tester.tap(
          find.descendant(of: sheet, matching: find.text(es.off)),
        );
        await tester.pumpAndSettle();
        expect(find.byType(BottomSheet), findsNothing);
        expect(
          find.descendant(of: row, matching: find.text(es.off)),
          findsOneWidget,
        );
      },
    );

    for (final language in ['es', 'ca']) {
      testWidgets(
        'UX-405: with everything allowed Notificaciones shows the switch and defaults, with the rest folded under Detalles ($language)',
        (tester) async {
          final l = lookupAppLocalizations(Locale(language));
          final store = MemoryReminderStore(
            const ReminderPreferences(enabled: true, asked: true),
          );
          final access = FakeReminderAccess(allowed: true, exact: true);
          await tester.pumpWidget(
            app(
              store,
              access,
              const NotificationSettingsScreen(),
              language: language,
            ),
          );
          await tester.pumpAndSettle();
          expect(
            find.widgetWithText(SwitchListTile, l.enableReminders),
            findsOneWidget,
          );
          expect(
            tester.widget<SwitchListTile>(find.byType(SwitchListTile)).subtitle,
            isNull,
          );
          expect(find.text(l.timedTasks), findsOneWidget);
          expect(find.text(l.dateOnlyTasks), findsOneWidget);
          expect(find.text(l.details), findsOneWidget);
          // Section labels show in capitals.
          for (final folded in [
            l.dailyCheckIns.toUpperCase(),
            l.morningCheckIn,
            l.eveningCheckIn,
            l.upcomingAlerts.toUpperCase(),
            l.dailyCheckInsHelp,
            l.scheduledAlertHelp,
            l.noUpcomingAlerts,
          ]) {
            expect(find.text(folded), findsNothing, reason: folded);
          }
          for (final problem in [
            l.tryAgain,
            l.allowNotifications,
            l.allowPreciseAlarms,
            l.notificationPermissionOff,
          ]) {
            expect(find.text(problem), findsNothing, reason: problem);
          }
          await tester.tap(find.text(l.details));
          await tester.pumpAndSettle();
          final alerts = find.text(l.noUpcomingAlerts);
          await tester.scrollUntilVisible(alerts, 160);
          await tester.pumpAndSettle();
          expect(alerts, findsOneWidget);
          expect(find.text(l.upcomingAlerts.toUpperCase()), findsOneWidget);
          expect(find.text(l.dailyCheckIns.toUpperCase()), findsOneWidget);
          expect(find.text(l.morningCheckIn), findsOneWidget);
          expect(find.text(l.eveningCheckIn), findsOneWidget);
          // Spanish ‘Mañana’ read as ‘tomorrow’: the check-ins say when.
          if (language == 'es') {
            expect(find.text('Por la mañana'), findsOneWidget);
            expect(find.text('Por la tarde'), findsOneWidget);
          } else {
            expect(find.text('Al matí'), findsOneWidget);
            expect(find.text('Al vespre'), findsOneWidget);
          }
          expect(tester.takeException(), isNull);
        },
      );
    }

    for (final (problem, access) in [
      ('the permission is off', FakeReminderAccess(allowed: false)),
      ('exact alarms are off', FakeReminderAccess(allowed: true, exact: false)),
    ]) {
      testWidgets(
        'UX-405: when $problem Notificaciones shows the status line and its fixes',
        (tester) async {
          final store = MemoryReminderStore(
            const ReminderPreferences(enabled: true, asked: true),
          );
          await tester.pumpWidget(
            app(store, access, const NotificationSettingsScreen()),
          );
          await tester.pumpAndSettle();
          expect(
            find.text(
              access.allowed
                  ? es.exactAlarmsNeeded
                  : es.notificationPermissionOff,
            ),
            findsOneWidget,
          );
          // UX-1606: one button, the one that fixes it.
          expect(
            find.widgetWithText(
              FilledButton,
              access.allowed ? es.allowPreciseAlarms : es.allowNotifications,
            ),
            findsOneWidget,
          );
          expect(find.byType(OutlinedButton), findsNothing);
          expect(find.text(es.tryAgain), findsNothing);
          expect(tester.takeException(), isNull);
        },
      );
    }

    testWidgets(
      'UX-405 / UX-401: the switch turns reminders on through the shared action, with 9:00 for tasks without a time',
      (tester) async {
        final store = MemoryReminderStore();
        final access = FakeReminderAccess();
        await tester.pumpWidget(
          app(store, access, const NotificationSettingsScreen()),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byType(SwitchListTile));
        await tester.pumpAndSettle();
        expect(access.permissionRequests, 1);
        expect(store.value.enabled, isTrue);
        expect(store.value.dateOnlyTime, 540);
        expect(find.text(es.remindersOnConfirmation), findsOneWidget);
        expect(
          tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
          isTrue,
        );
      },
    );

    testWidgets(
      'UX-401: a time already chosen for tasks without a time survives turning reminders on',
      (tester) async {
        final store = MemoryReminderStore(
          const ReminderPreferences(dateOnlyTime: 480),
        );
        final access = FakeReminderAccess();
        await tester.pumpWidget(
          app(store, access, const NotificationSettingsScreen()),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byType(SwitchListTile));
        await tester.pumpAndSettle();
        expect(store.value.enabled, isTrue);
        expect(store.value.dateOnlyTime, 480);
      },
    );

    testWidgets(
      'UX-401: after consent a fresh account’s task for tomorrow without a time is reminded at 9:00',
      (tester) async {
        final store = MemoryReminderStore();
        final access = FakeReminderAccess();
        await pumpChip(tester, store, access);
        await tester.tap(find.byType(ReminderChip));
        await tester.pumpAndSettle();
        final now = DateTime(2026, 10, 13, 12);
        final planned = ReminderEngine.plan(
          'local',
          [
            Task(
              id: 3,
              title: 'Comprar pan',
              priority: 1,
              dueDate: DateTime(2026, 10, 14),
              hasTime: false,
            ),
          ],
          store.value,
          now,
        );
        expect(planned, hasLength(1));
        expect(planned.single.when, DateTime(2026, 10, 14, 9));
      },
    );
  });

  // ---- Run 2026-10-19-app, round 1 · P177: when a reminder won't come ----
  group('P177', () {
    const timeoutChannel = MethodChannel('taskflow/accessibility');
    final platform =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    setUp(
      () =>
          platform.setMockMethodCallHandler(timeoutChannel, (_) async => null),
    );
    tearDown(() => platform.setMockMethodCallHandler(timeoutChannel, null));
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    final at10 = DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 10);
    final dateOnly = DateTime(tomorrow.year, tomorrow.month, tomorrow.day);
    const on = ReminderPreferences(enabled: true, asked: true);

    // María (account 1) owns «Matemáticas»; Ana (2) is in it.
    TaskListInfo project({
      String notifications = 'all',
      bool archived = false,
    }) => TaskListInfo(
      id: 'matematicas',
      name: 'Matemáticas',
      version: 3,
      role: 'owner',
      shared: true,
      ownerId: 1,
      notifications: notifications,
      archived: archived,
      people: const [
        ProjectMember(id: 1, name: 'María', role: 'owner'),
        ProjectMember(id: 2, name: 'Ana', role: 'editor'),
      ],
    );
    final anas = Task(
      id: 31,
      title: 'Corregir los ejercicios del tema 4',
      dueDate: at10,
      priority: 2,
      listId: 'matematicas',
      assignment: 'member',
      assigneeId: 2,
      assigneeName: 'Ana',
    );
    final mine = Task(
      id: 32,
      title: 'Preparar el examen',
      dueDate: at10,
      priority: 1,
      listId: 'matematicas',
      assignment: 'member',
      assigneeId: 1,
      assigneeName: 'María',
    );

    ProviderContainer container({
      List<TaskListInfo> projects = const [],
      ReminderPreferences preferences = on,
      String language = 'es',
    }) {
      final made = designContainer(
        projects: projects,
        regionalStore: MemoryRegionalStore(
          RegionalPreferences(
            language: language,
            clock: ClockFormat.twentyFour,
            weekStart: 1,
          ),
        ),
        overrides: reminderOverrides(
          MemoryReminderStore(preferences),
          FakeReminderAccess(allowed: true),
        ),
      );
      addTearDown(made.dispose);
      return made;
    }

    Future<ValueNotifier<Task>> pumpChip(
      WidgetTester tester,
      Task task, {
      List<TaskListInfo> projects = const [],
      ReminderPreferences preferences = on,
      String language = 'es',
    }) async {
      final value = ValueNotifier(task);
      addTearDown(value.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container(
            projects: projects,
            preferences: preferences,
            language: language,
          ),
          child: MaterialApp(
            locale: Locale(language),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: AppTheme.light,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(alwaysUse24HourFormat: true),
              child: child!,
            ),
            home: Scaffold(
              body: Padding(
                padding: const EdgeInsets.all(24),
                child: ValueListenableBuilder<Task>(
                  valueListenable: value,
                  builder: (context, task, _) => ReminderChip(
                    task: task,
                    onChanged: (changed) => value.value = changed,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return value;
    }

    String chipLabel(WidgetTester tester) {
      final texts = tester.widgetList<Text>(
        find.descendant(
          of: find.byType(ReminderChip),
          matching: find.byType(Text),
        ),
      );
      return texts.map((text) => text.data ?? '').join();
    }

    test('UX-1505: the three readings in EN, ES and CA', () {
      final en = lookupAppLocalizations(const Locale('en'));
      final es = lookupAppLocalizations(const Locale('es'));
      final ca = lookupAppLocalizations(const Locale('ca'));
      expect(en.noReminderProjectMuted, 'No reminder: project muted');
      expect(
        es.noReminderProjectMuted,
        'Sin recordatorio: proyecto silenciado',
      );
      expect(
        ca.noReminderProjectMuted,
        'Sense recordatori: projecte silenciat',
      );
      expect(en.noReminderProjectArchived, 'No reminder: project archived');
      expect(
        es.noReminderProjectArchived,
        'Sin recordatorio: proyecto archivado',
      );
      expect(
        ca.noReminderProjectArchived,
        'Sense recordatori: projecte arxivat',
      );
    });

    for (final language in ['es', 'en', 'ca']) {
      testWidgets(
        'UX-1505, UX-1634: Ana’s task viewed by María, following the default, reads «Recordatorio para Ana» ($language)',
        (tester) async {
          final l = lookupAppLocalizations(Locale(language));
          await pumpChip(
            tester,
            anas,
            projects: [project()],
            language: language,
          );
          expect(chipLabel(tester), l.reminderForPersonOnly('Ana'));
          expect(
            chipLabel(tester),
            isNot(l.reminderValue(l.minutesBefore(10))),
          );
          expect(tester.takeException(), isNull);
        },
      );
    }

    testWidgets(
      'UX-1505: a task in a muted project reads «Sin recordatorio: proyecto silenciado», and a tap opens that project’s «Novedades del proyecto»',
      (tester) async {
        final es = lookupAppLocalizations(const Locale('es'));
        await pumpChip(
          tester,
          mine,
          projects: [project(notifications: 'muted')],
        );
        expect(chipLabel(tester), es.noReminderProjectMuted);
        await tester.tap(find.byType(ReminderChip));
        await tester.pumpAndSettle();
        final sheet = find.byType(BottomSheet);
        expect(sheet, findsOneWidget);
        expect(
          find.descendant(
            of: sheet,
            matching: find.text(es.projectNotifications),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(of: sheet, matching: find.text('Matemáticas')),
          findsOneWidget,
        );
        expect(
          find.descendant(of: sheet, matching: find.text(es.updatesMuted)),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'UX-1505: a task in an archived project reads «Sin recordatorio: proyecto archivado», and a tap does nothing',
      (tester) async {
        final es = lookupAppLocalizations(const Locale('es'));
        final task = await pumpChip(
          tester,
          mine,
          projects: [project(archived: true)],
        );
        expect(chipLabel(tester), es.noReminderProjectArchived);
        await tester.tap(find.byType(ReminderChip), warnIfMissed: false);
        await tester.pumpAndSettle();
        expect(find.byType(BottomSheet), findsNothing);
        expect(task.value.reminderMinutes, mine.reminderMinutes);
        expect(tester.takeException(), isNull);
      },
    );

    for (final (name, task) in [
      ('a task of this account in an active, unmuted project', mine),
      (
        'a personal task',
        Task(id: 9, title: 'Médico', priority: 1, dueDate: at10),
      ),
    ]) {
      testWidgets('UX-1505: $name reads as before', (tester) async {
        final es = lookupAppLocalizations(const Locale('es'));
        await pumpChip(tester, task, projects: [project()]);
        expect(chipLabel(tester), es.reminderValue(es.minutesBefore(10)));
        expect(
          find.descendant(
            of: find.byType(ReminderChip),
            matching: find.byIcon(Icons.notifications_outlined),
          ),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      });
    }

    /// The edit form for [task], with its Recordatorio row in view.
    Future<Finder> pumpForm(
      WidgetTester tester,
      Task task, {
      List<TaskListInfo> projects = const [],
    }) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container(projects: projects),
          child: const MyApp(),
        ),
      );
      await tester.pumpAndSettle();
      unawaited(
        tester
            .state<NavigatorState>(find.byType(Navigator).first)
            .push(
              MaterialPageRoute<void>(builder: (_) => TaskEditor(task: task)),
            ),
      );
      await tester.pumpAndSettle();
      final more = find.byKey(const ValueKey('task-more-details'));
      if (more.evaluate().isNotEmpty) {
        await tester.ensureVisible(more);
        await tester.pumpAndSettle();
        await tester.tap(more);
        await tester.pumpAndSettle();
      }
      // P270 (UX-2206): a line that names itself is the row's only text.
      final row = find.descendant(
        of: find.byType(ReminderControl),
        matching: find.byType(ListTile),
      );
      await tester.ensureVisible(row);
      await tester.pumpAndSettle();
      return row;
    }

    for (final (name, task, projects, reading) in [
      (
        'Ana’s task viewed by María',
        anas,
        [project()],
        // Ana's phone uses her own default, which this phone doesn't know.
        (AppLocalizations l) => l.reminderForPersonOnly('Ana'),
      ),
      (
        'a task in a muted project',
        mine,
        [project(notifications: 'muted')],
        (AppLocalizations l) => l.noReminderProjectMuted,
      ),
      (
        'a task in an archived project',
        mine,
        [project(archived: true)],
        (AppLocalizations l) => l.noReminderProjectArchived,
      ),
    ]) {
      testWidgets(
        'UX-1505: the edit form’s Recordatorio row says the same for $name',
        (tester) async {
          final es = lookupAppLocalizations(const Locale('es'));
          final row = await pumpForm(tester, task, projects: projects);
          final tile = tester.widget<ListTile>(row);
          expect((tile.title! as Text).data, reading(es));
          expect(tile.subtitle, isNull);
          expect(tester.takeException(), isNull);
        },
      );
    }

    // ---- Run 2026-10-19-app, round 2 · P203 (UX-1634): someone else's
    // reminder names a time only when the task sets its own ----

    test('UX-1634: «Recordatorio para {name}» reads as the plan wrote it', () {
      expect(
        lookupAppLocalizations(const Locale('en')).reminderForPersonOnly('Ana'),
        'Reminder for Ana',
      );
      expect(
        lookupAppLocalizations(const Locale('es')).reminderForPersonOnly('Ana'),
        'Recordatorio para Ana',
      );
      expect(
        lookupAppLocalizations(const Locale('ca')).reminderForPersonOnly('Ana'),
        'Recordatori per a Ana',
      );
    });

    // P259 (UX-2024): the values on the task are this account's own, never
    // Ana's, so none is said after her name.
    for (final (language, followsDefault) in [
      ('es', 'Recordatorio para Ana'),
      ('en', 'Reminder for Ana'),
      ('ca', 'Recordatori per a Ana'),
    ]) {
      testWidgets(
        'UX-1634, UX-2024: Ana’s timed task viewed by María reads «$followsDefault» with no reminder of its own, and with 30 minutes set ($language)',
        (tester) async {
          final l = lookupAppLocalizations(Locale(language));
          await pumpChip(
            tester,
            anas,
            projects: [project()],
            language: language,
          );
          expect(chipLabel(tester), followsDefault);
          expect(chipLabel(tester), l.reminderForPersonOnly('Ana'));
          expect(chipLabel(tester), isNot(contains(l.minutesBefore(10))));
          await pumpChip(
            tester,
            anas.copyWith(reminderMinutes: 30),
            projects: [project()],
            language: language,
          );
          expect(chipLabel(tester), followsDefault);
          expect(chipLabel(tester), isNot(contains(l.minutesBefore(30))));
          expect(tester.takeException(), isNull);
        },
      );
    }

    final anasDateOnly = Task(
      id: 33,
      title: 'Traer el material de geometría',
      dueDate: dateOnly,
      hasTime: false,
      priority: 1,
      listId: 'matematicas',
      assignment: 'member',
      assigneeId: 2,
      assigneeName: 'Ana',
    );

    testWidgets(
      'UX-1634, UX-2024: Ana’s date-only task reads «Recordatorio para Ana» with no time of its own, with 8:00 set, and with «Desactivado»',
      (tester) async {
        final es = lookupAppLocalizations(const Locale('es'));
        await pumpChip(tester, anasDateOnly, projects: [project()]);
        expect(chipLabel(tester), 'Recordatorio para Ana');
        expect(chipLabel(tester), isNot(contains('9:00')));
        await pumpChip(
          tester,
          anasDateOnly.copyWith(reminderTime: 8 * 60),
          projects: [project()],
        );
        expect(chipLabel(tester), 'Recordatorio para Ana');
        // Off is this account's own too: Ana's phone keeps hers.
        await pumpChip(
          tester,
          anasDateOnly.copyWith(reminderMinutes: -1),
          projects: [project()],
        );
        expect(chipLabel(tester), es.reminderForPersonOnly('Ana'));
        expect(tester.takeException(), isNull);
      },
    );

    for (final (name, task, reading) in [
      (
        'Ana’s timed task with no reminder of its own',
        anas,
        'Recordatorio para Ana',
      ),
      (
        'Ana’s timed task with 30 minutes set',
        anas.copyWith(reminderMinutes: 30),
        'Recordatorio para Ana',
      ),
      (
        'Ana’s date-only task with no time of its own',
        anasDateOnly,
        'Recordatorio para Ana',
      ),
      (
        'Ana’s date-only task with 8:00 set',
        anasDateOnly.copyWith(reminderTime: 8 * 60),
        'Recordatorio para Ana',
      ),
    ]) {
      testWidgets(
        'UX-1634: the edit form’s Recordatorio row reads «$reading» for $name, with no «predeterminado»',
        (tester) async {
          final es = lookupAppLocalizations(const Locale('es'));
          final row = await pumpForm(tester, task, projects: [project()]);
          final tile = tester.widget<ListTile>(row);
          final subtitle = (tile.title! as Text).data!;
          expect(subtitle, reading);
          expect(tile.subtitle, isNull);
          expect(subtitle, isNot(contains(es.defaultChoice)));
          expect(subtitle.toLowerCase(), isNot(contains('predeterminado')));
          expect(tester.takeException(), isNull);
        },
      );
    }

    testWidgets(
      'UX-1634: a task of this account still reads «Recordatorio: 10 minutos antes» with a 10-minute default',
      (tester) async {
        await pumpChip(tester, mine, projects: [project()]);
        expect(chipLabel(tester), 'Recordatorio: 10 minutos antes');
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'UX-1413: the chooser for a timed task with a 10-minute default lists 6 rows, the first «10 minutos antes · predeterminado» and selected, no other «10 minutos antes», no «Usar valor predeterminado»',
      (tester) async {
        final es = lookupAppLocalizations(const Locale('es'));
        await pumpChip(
          tester,
          Task(id: 9, title: 'Médico', priority: 1, dueDate: at10),
        );
        await tester.tap(find.byType(ReminderChip));
        await tester.pumpAndSettle();
        final sheet = find.byType(BottomSheet);
        // The single reminder's rows; a task with a day also has the two
        // plans under them (reminder_plan_sheet_test.dart).
        final rows = tester
            .widgetList<ListTile>(
              find.descendant(of: sheet, matching: find.byType(ListTile)),
            )
            .where(
              (row) =>
                  row.key != const ValueKey('reminder-plan-until-day') &&
                  row.key != const ValueKey('reminder-plan-your-way'),
            )
            .toList();
        expect(rows, hasLength(6));
        final first = rows.first;
        expect(
          (first.title! as Text).data,
          '${es.minutesBefore(10)} · ${es.defaultChoice}',
        );
        expect(first.selected, isTrue);
        expect(
          rows.skip(1).where((row) => row.selected),
          isEmpty,
          reason: 'only the default is selected',
        );
        expect(
          find.descendant(of: sheet, matching: find.text(es.minutesBefore(10))),
          findsNothing,
        );
        expect(
          find.descendant(
            of: sheet,
            matching: find.text('Usar valor predeterminado'),
          ),
          findsNothing,
        );
        expect(
          find.descendant(
            of: sheet,
            matching: find.textContaining('Usar valor'),
          ),
          findsNothing,
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'UX-1413: the chooser for a date-only task with reminders on lists «9:00 · predeterminado»; with no default time set it has no default row',
      (tester) async {
        final es = lookupAppLocalizations(const Locale('es'));
        final task = Task(
          id: 9,
          title: 'Comprar pan',
          priority: 1,
          dueDate: dateOnly,
          hasTime: false,
        );
        await pumpChip(
          tester,
          task,
          preferences: const ReminderPreferences(
            enabled: true,
            asked: true,
            dateOnlyTime: 540,
          ),
        );
        await tester.tap(find.byType(ReminderChip));
        await tester.pumpAndSettle();
        var sheet = find.byType(BottomSheet);
        var titles = tester
            .widgetList<ListTile>(
              find.descendant(of: sheet, matching: find.byType(ListTile)),
            )
            .map((row) => (row.title! as Text).data)
            .toList();
        expect(titles.first, '9:00 · ${es.defaultChoice}');
        expect(titles, contains(es.chooseAlertTime));

        await tester.pumpWidget(const SizedBox());
        await pumpChip(
          tester,
          task,
          preferences: const ReminderPreferences(enabled: true, asked: true),
        );
        await tester.tap(find.byType(ReminderChip));
        await tester.pumpAndSettle();
        sheet = find.byType(BottomSheet);
        titles = tester
            .widgetList<ListTile>(
              find.descendant(of: sheet, matching: find.byType(ListTile)),
            )
            .map((row) => (row.title! as Text).data)
            .toList();
        expect(
          titles.where((title) => title!.contains(es.defaultChoice)),
          isEmpty,
        );
        expect(titles, isNot(contains('Usar valor predeterminado')));
        expect(titles, contains(es.chooseAlertTime));
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'UX-1413: «Elegir hora del aviso» opens a time picker in input mode',
      (tester) async {
        final es = lookupAppLocalizations(const Locale('es'));
        await pumpChip(
          tester,
          Task(
            id: 9,
            title: 'Comprar pan',
            priority: 1,
            dueDate: dateOnly,
            hasTime: false,
          ),
          preferences: const ReminderPreferences(
            enabled: true,
            asked: true,
            dateOnlyTime: 540,
          ),
        );
        await tester.tap(find.byType(ReminderChip));
        await tester.pumpAndSettle();
        await tester.tap(find.text(es.chooseAlertTime));
        await tester.pumpAndSettle();
        final picker = find.byType(TimePickerDialog);
        expect(picker, findsOneWidget);
        expect(
          tester.widget<TimePickerDialog>(picker).initialEntryMode,
          TimePickerEntryMode.input,
        );
        // Typing fields, not the dial.
        expect(
          find.descendant(of: picker, matching: find.byType(TextField)),
          findsWidgets,
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'UX-1413: the form’s Recordatorio row shows the › chevron when it can be tapped',
      (tester) async {
        final row = await pumpForm(
          tester,
          Task(id: 9, title: 'Médico', priority: 1, dueDate: at10),
        );
        expect(
          find.descendant(
            of: row,
            matching: find.byIcon(Icons.chevron_right_rounded),
          ),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );
  });

  // ---- Run 2026-10-19-app, round 1 · P187: reminders set up and stay true ----
  group('P187', () {
    const timeoutChannel = MethodChannel('taskflow/accessibility');
    final platform =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    setUp(
      () =>
          platform.setMockMethodCallHandler(timeoutChannel, (_) async => null),
    );
    tearDown(() => platform.setMockMethodCallHandler(timeoutChannel, null));
    setUpAll(() async {
      await (FontLoader(
        'Manrope',
      )..addFont(rootBundle.load('assets/fonts/Manrope.ttf'))).load();
    });
    final es = lookupAppLocalizations(const Locale('es'));
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    final timed = Task(
      id: 1,
      title: 'Médico',
      priority: 1,
      dueDate: DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 10),
    );

    Widget app(
      MemoryReminderStore store,
      FakeReminderAccess access,
      Widget home, {
      String language = 'es',
    }) => ProviderScope(
      overrides: [
        ...reminderOverrides(store, access),
        taskRepositoryProvider.overrideWithValue(MemoryTasks()),
      ],
      child: MaterialApp(
        locale: Locale(language),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: AppTheme.light,
        home: home,
      ),
    );

    /// 2× text on a 360×800 phone, as the preview suite renders it.
    void largeText(WidgetTester tester) {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    }

    Future<void> pumpChip(
      WidgetTester tester,
      MemoryReminderStore store,
      FakeReminderAccess access,
    ) async {
      final task = ValueNotifier(timed);
      addTearDown(task.dispose);
      await tester.pumpWidget(
        app(
          store,
          access,
          Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(24),
              child: ValueListenableBuilder<Task>(
                valueListenable: task,
                builder: (context, value, _) => ReminderChip(
                  task: value,
                  onChanged: (changed) => task.value = changed,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    bool switchOn(WidgetTester tester) =>
        tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value;

    test('UX-1606 / UX-1622: the new reminder copy in EN, ES and CA', () {
      final en = lookupAppLocalizations(const Locale('en'));
      final ca = lookupAppLocalizations(const Locale('ca'));
      expect(
        en.notificationPermissionOff,
        'Your phone isn’t letting TaskFlow notify you.',
      );
      expect(
        es.notificationPermissionOff,
        'El teléfono no deja que TaskFlow te avise.',
      );
      expect(
        ca.notificationPermissionOff,
        'El telèfon no deixa que TaskFlow t’avisi.',
      );
      expect(en.allowNotifications, 'Allow notifications');
      expect(es.allowNotifications, 'Permitir avisos');
      expect(ca.allowNotifications, 'Permet els avisos');
      expect(en.tryAgain, 'Try again');
      expect(es.tryAgain, 'Reintentar');
      expect(ca.tryAgain, 'Torna-ho a provar');
      expect(en.remindersOnLate, 'On · may arrive late');
      expect(es.remindersOnLate, 'Activados · pueden llegar tarde');
      expect(ca.remindersOnLate, 'Activats · poden arribar tard');
      expect(
        en.exactAlarmsNextScreen,
        'On the next screen, turn on the switch, then come back.',
      );
      expect(
        es.exactAlarmsNextScreen,
        'En la siguiente pantalla, activa el interruptor y vuelve.',
      );
      expect(
        ca.exactAlarmsNextScreen,
        'A la pantalla següent, activa l’interruptor i torna.',
      );
    });

    test(
      'UX-1606 / UX-1616: retryScheduling, openSystemSettings and taskDefaults are gone from the three catalogs',
      () {
        for (final language in ['en', 'es', 'ca']) {
          final arb = File('lib/l10n/app_$language.arb').readAsStringSync();
          for (final key in [
            'retryScheduling',
            'openSystemSettings',
            'taskDefaults',
          ]) {
            expect(arb, isNot(contains('"$key"')), reason: '$language $key');
          }
        }
      },
    );

    for (final grant in [true, false]) {
      testWidgets(
        grant
            ? 'UX-1605: allowing during the flow, Recordatorios shows the switch on and no blocked line on every frame'
            : 'UX-1605 / UX-2601: refusing during the flow, the switch goes back off, alone, and the message offers «Permitir avisos»',
        (tester) async {
          final store = MemoryReminderStore();
          final access = _GatedAccess(grant: grant);
          await tester.pumpWidget(
            app(store, access, const NotificationSettingsScreen()),
          );
          await tester.pumpAndSettle();
          expect(switchOn(tester), isFalse);
          // UX-2601: with the switch off, the switch is the one way in.
          expect(find.text(es.notificationPermissionOff), findsNothing);

          await tester.tap(find.byType(SwitchListTile));
          await tester.pump();
          expect(access.permissionRequests, 1);
          // Android's dialog is up: the screen already shows the switch on,
          // and not the problem the flow is fixing.
          expect(switchOn(tester), isTrue);
          expect(find.text(es.notificationPermissionOff), findsNothing);
          expect(find.text(es.allowNotifications), findsNothing);

          // Back from Android while the flow still runs.
          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.inactive,
          );
          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.resumed,
          );
          access.answer.complete();
          if (grant) {
            for (var frame = 0; frame < 120; frame++) {
              await tester.pump(const Duration(milliseconds: 16));
              expect(switchOn(tester), isTrue, reason: 'frame $frame');
              expect(
                find.text(es.notificationPermissionOff),
                findsNothing,
                reason: 'frame $frame',
              );
            }
            await tester.pumpAndSettle();
            expect(switchOn(tester), isTrue);
            expect(find.text(es.notificationPermissionOff), findsNothing);
            expect(store.value.enabled, isTrue);
          } else {
            await tester.pumpAndSettle();
            expect(switchOn(tester), isFalse);
            // UX-2601: the switch alone; the message says why and offers
            // the phone's page.
            expect(
              find.descendant(
                of: find.byType(ListTile),
                matching: find.text(es.notificationPermissionOff),
              ),
              findsNothing,
            );
            expect(
              find.widgetWithText(FilledButton, es.allowNotifications),
              findsNothing,
            );
            expect(
              find.widgetWithText(SnackBarAction, es.allowNotifications),
              findsOneWidget,
            );
            expect(store.value.enabled, isFalse);
          }
          expect(tester.takeException(), isNull);
        },
      );
    }

    testWidgets(
      'UX-1605: back from Android while the flow is still busy, Recordatorios re-reads the permission at once',
      (tester) async {
        final store = MemoryReminderStore(
          const ReminderPreferences(enabled: true, asked: true),
        );
        final access = _HangingSaveAccess(allowed: false);
        await tester.pumpWidget(
          app(store, access, const NotificationSettingsScreen()),
        );
        await tester.pumpAndSettle();
        expect(find.text(es.notificationPermissionOff), findsOneWidget);
        // A refresh that hangs keeps the screen busy.
        access.hang = true;
        await tester.drag(find.byType(ListView), const Offset(0, 300));
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
        expect(find.byType(LinearProgressIndicator), findsOneWidget);
        // The person allowed notifications in the phone's settings.
        access.allowed = true;
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.inactive,
        );
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pump();
        await tester.pump();
        expect(find.text(es.notificationPermissionOff), findsNothing);
        access.release.complete();
        await tester.pumpAndSettle();
        expect(find.text(es.notificationPermissionOff), findsNothing);
      },
    );

    testWidgets(
      'UX-1605: while Recordatorios is busy, the problem block’s button is disabled',
      (tester) async {
        final store = MemoryReminderStore(
          const ReminderPreferences(enabled: true, asked: true),
        );
        final access = _HangingSaveAccess(allowed: false);
        await tester.pumpWidget(
          app(store, access, const NotificationSettingsScreen()),
        );
        await tester.pumpAndSettle();
        final button = find.widgetWithText(FilledButton, es.allowNotifications);
        expect(tester.widget<FilledButton>(button).onPressed, isNotNull);
        access.hang = true;
        await tester.drag(find.byType(ListView), const Offset(0, 300));
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
        expect(find.byType(LinearProgressIndicator), findsOneWidget);
        expect(tester.widget<FilledButton>(button).onPressed, isNull);
        access.release.complete();
        await tester.pumpAndSettle();
      },
    );

    testWidgets(
      'UX-1605: «Listo. Recordatorios activados.» shows even when the reminder refresh never completes',
      (tester) async {
        final store = MemoryReminderStore();
        final access = _NeverReconciles();
        await pumpChip(tester, store, access);
        await tester.tap(find.byType(ReminderChip));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        expect(access.reconciles, 1);
        expect(
          find.descendant(
            of: find.byType(SnackBar),
            matching: find.text(es.remindersOnConfirmation),
          ),
          findsOneWidget,
        );
        expect(store.value.enabled, isTrue);
      },
    );

    for (final language in ['es', 'ca']) {
      testWidgets(
        'UX-1606: blocked, $language at 2× on 360×800: one plain line and one FilledButton Permitir avisos; no Abrir ajustes del sistema, no Actualizar y reintentar',
        (tester) async {
          largeText(tester);
          final l = lookupAppLocalizations(Locale(language));
          final store = MemoryReminderStore(
            const ReminderPreferences(enabled: true, asked: true),
          );
          final access = FakeReminderAccess(allowed: false);
          await tester.pumpWidget(
            app(
              store,
              access,
              const NotificationSettingsScreen(),
              language: language,
            ),
          );
          await tester.pumpAndSettle();
          final line = find.text(l.notificationPermissionOff);
          expect(line, findsOneWidget);
          expect(find.byType(FilledButton), findsOneWidget);
          expect(
            find.widgetWithText(FilledButton, l.allowNotifications),
            findsOneWidget,
          );
          expect(find.byType(OutlinedButton), findsNothing);
          expect(find.text(l.tryAgain), findsNothing);
          expect(find.text(l.allowPreciseAlarms), findsNothing);
          for (final old in [
            'Abrir ajustes del sistema',
            'Actualizar y reintentar',
            'Permiso del sistema desactivado',
            'Obre la configuració del sistema',
            'Actualitza i torna a programar',
            'El permís del sistema està desactivat',
          ]) {
            expect(find.text(old), findsNothing, reason: old);
          }
          // Line and button sit on the first screen, whole.
          final view = tester.view.physicalSize / tester.view.devicePixelRatio;
          for (final shown in [
            line,
            find.widgetWithText(FilledButton, l.allowNotifications),
          ]) {
            final rect = tester.getRect(shown);
            expect(rect.bottom, lessThanOrEqualTo(view.height));
            expect(rect.right, lessThanOrEqualTo(view.width));
          }
          expect(tester.takeException(), isNull);
        },
      );
    }

    testWidgets(
      'UX-1606: exact alarms off: the exactAlarmsNeeded line and one FilledButton Permitir «Alarmas y recordatorios», nothing else in the block',
      (tester) async {
        final store = MemoryReminderStore(
          const ReminderPreferences(enabled: true, asked: true),
        );
        final access = FakeReminderAccess(allowed: true, exact: false);
        await tester.pumpWidget(
          app(store, access, const NotificationSettingsScreen()),
        );
        await tester.pumpAndSettle();
        expect(find.text(es.exactAlarmsNeeded), findsOneWidget);
        expect(find.byType(FilledButton), findsOneWidget);
        expect(
          find.widgetWithText(FilledButton, es.allowPreciseAlarms),
          findsOneWidget,
        );
        expect(find.byType(OutlinedButton), findsNothing);
        expect(find.byType(TextButton), findsNothing);
        expect(find.text(es.allowNotifications), findsNothing);
        expect(find.text(es.notificationPermissionOff), findsNothing);
        expect(find.text(es.tryAgain), findsNothing);
        expect(find.text('Abrir ajustes del sistema'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );

    for (final failed in [true, false]) {
      testWidgets(
        failed
            ? 'UX-1606: with a scheduler error, Reintentar shows'
            : 'UX-1606: without a scheduler error, Reintentar doesn’t show',
        (tester) async {
          final store = MemoryReminderStore(
            const ReminderPreferences(enabled: true, asked: true),
          );
          if (failed) {
            store.info = [
              {'key': 'error', 'value': 'refresh_failed'},
            ];
          }
          final access = FakeReminderAccess(allowed: true, exact: true);
          await tester.pumpWidget(
            app(store, access, const NotificationSettingsScreen()),
          );
          await tester.pumpAndSettle();
          expect(
            find.widgetWithText(OutlinedButton, es.tryAgain),
            failed ? findsOneWidget : findsNothing,
          );
          expect(find.text('Actualizar y reintentar'), findsNothing);
          expect(tester.takeException(), isNull);
        },
      );
    }

    testWidgets(
      'UX-1606: tapping Permitir avisos on Recordatorios opens TaskFlow’s notification settings',
      (tester) async {
        final store = MemoryReminderStore(
          const ReminderPreferences(enabled: true, asked: true),
        );
        final access = FakeReminderAccess(allowed: false);
        await tester.pumpWidget(
          app(store, access, const NotificationSettingsScreen()),
        );
        await tester.pumpAndSettle();
        await tester.tap(
          find.widgetWithText(FilledButton, es.allowNotifications),
        );
        await tester.pumpAndSettle();
        expect(access.notificationSettingsOpened, 1);
        expect(access.permissionRequests, 0);
      },
    );

    group('UX-1606: the notification-settings opener', () {
      const appSettings = MethodChannel('taskflow/app-settings');
      const permissions = MethodChannel(
        'flutter.baseflow.com/permissions/methods',
      );
      final opened = <String>[];
      tearDown(() {
        platform.setMockMethodCallHandler(appSettings, null);
        platform.setMockMethodCallHandler(permissions, null);
        opened.clear();
      });

      test(
        'opens TaskFlow’s notifications page, not App info (openAppSettings)',
        () async {
          TestWidgetsFlutterBinding.ensureInitialized();
          platform.setMockMethodCallHandler(appSettings, (call) async {
            opened.add('app-settings/${call.method}');
            return null;
          });
          platform.setMockMethodCallHandler(permissions, (call) async {
            opened.add('permissions/${call.method}');
            return true;
          });
          await const ReminderAccess().openNotificationSettings();
          expect(opened, ['app-settings/openNotificationSettings']);
        },
      );

      test('falls back to App info when the page can’t open', () async {
        TestWidgetsFlutterBinding.ensureInitialized();
        platform.setMockMethodCallHandler(appSettings, (call) async {
          opened.add('app-settings/${call.method}');
          throw PlatformException(code: 'unavailable');
        });
        platform.setMockMethodCallHandler(permissions, (call) async {
          opened.add('permissions/${call.method}');
          return true;
        });
        await const ReminderAccess().openNotificationSettings();
        expect(opened, [
          'app-settings/openNotificationSettings',
          'permissions/openAppSettings',
        ]);
      });
    });

    testWidgets(
      'UX-1606: after No permitir, the message reads El teléfono no deja que TaskFlow te avise. and Permitir avisos opens the notifications page',
      (tester) async {
        final store = MemoryReminderStore();
        final access = FakeReminderAccess(grant: false);
        await pumpChip(tester, store, access);
        await tester.tap(find.byType(ReminderChip));
        await tester.pumpAndSettle();
        final snack = find.byType(SnackBar);
        expect(
          find.descendant(
            of: snack,
            matching: find.text(es.notificationPermissionOff),
          ),
          findsOneWidget,
        );
        final action = find.widgetWithText(
          SnackBarAction,
          es.allowNotifications,
        );
        expect(action, findsOneWidget);
        expect(find.text('Abrir ajustes del sistema'), findsNothing);
        await tester.tap(action);
        await tester.pumpAndSettle();
        expect(access.notificationSettingsOpened, 1);
      },
    );

    test(
      'UX-1607: a reminder notification carries the reminder category; the silent Completada line doesn’t',
      () {
        final reminder = PlannedReminder(
          identity: 'task/1',
          taskId: 1,
          when: DateTime(2026, 10, 21, 9),
          title: 'Médico',
          body: '10:00',
          languageCode: 'es',
        );
        expect(
          reminderNotificationDetails(reminder).android!.category,
          AndroidNotificationCategory.reminder,
        );
        expect(
          reminderNotificationDetails(reminder, silent: true).android!.category,
          AndroidNotificationCategory.reminder,
        );
        final checkIn = PlannedReminder(
          identity: 'daily/morning',
          when: DateTime(2026, 10, 21, 9),
          title: 'Por la mañana',
          body: '',
          languageCode: 'es',
          daily: true,
        );
        expect(
          reminderNotificationDetails(checkIn).android!.category,
          AndroidNotificationCategory.reminder,
        );
        expect(
          undoNotificationDetails(
            'es',
            const Duration(seconds: 10),
          ).android!.category,
          isNull,
        );
      },
    );

    testWidgets(
      'UX-1616: the Tareas sin hora picker and both daily check-in pickers open in typing mode',
      (tester) async {
        tester.view.physicalSize = const Size(393, 852);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final store = MemoryReminderStore(
          const ReminderPreferences(
            enabled: true,
            asked: true,
            dateOnlyTime: 540,
            morning: 480,
            evening: 1200,
          ),
        );
        final access = FakeReminderAccess(allowed: true, exact: true);
        await tester.pumpWidget(
          app(store, access, const NotificationSettingsScreen()),
        );
        await tester.pumpAndSettle();
        Future<void> expectTyping(String row) async {
          final tile = find.widgetWithText(ListTile, row);
          await tester.scrollUntilVisible(tile, 120);
          await tester.pumpAndSettle();
          await tester.tap(find.text(row));
          await tester.pumpAndSettle();
          final dialog = find.byType(TimePickerDialog);
          expect(dialog, findsOneWidget, reason: row);
          expect(
            tester.widget<TimePickerDialog>(dialog).initialEntryMode,
            TimePickerEntryMode.input,
            reason: row,
          );
          // Typing fields, not the dial.
          expect(
            find.descendant(of: dialog, matching: find.byType(TextField)),
            findsWidgets,
            reason: row,
          );
          await tester.tap(
            find.descendant(
              of: dialog,
              matching: find.text(
                MaterialLocalizations.of(
                  tester.element(dialog),
                ).cancelButtonLabel,
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(dialog, findsNothing);
        }

        await expectTyping(es.dateOnlyTasks);
        await tester.tap(find.text(es.details));
        await tester.pumpAndSettle();
        await expectTyping(es.morningCheckIn);
        await expectTyping(es.eveningCheckIn);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'UX-1616: at 2× on 360×800 Recordatorios shows 10 minutos antes whole, in a row like Tareas sin hora, with no OPCIONES PREDETERMINADAS',
      (tester) async {
        largeText(tester);
        final store = MemoryReminderStore(
          const ReminderPreferences(
            enabled: true,
            asked: true,
            leadMinutes: 10,
            dateOnlyTime: 540,
          ),
        );
        final access = FakeReminderAccess(allowed: true, exact: true);
        await tester.pumpWidget(
          app(store, access, const NotificationSettingsScreen()),
        );
        await tester.pumpAndSettle();
        final value = tester
            .element(find.byType(NotificationSettingsScreen))
            .reminderLead(10);
        expect(value, '10 minutos antes');
        final shown = find.text(value);
        await tester.scrollUntilVisible(shown, 120);
        await tester.pumpAndSettle();
        expect(shown, findsOneWidget);
        final paragraph = tester.renderObject<RenderParagraph>(shown);
        expect(paragraph.didExceedMaxLines, isFalse);
        final rect = tester.getRect(shown);
        expect(rect.left, greaterThanOrEqualTo(0));
        expect(rect.right, lessThanOrEqualTo(360));
        // The words fit the box they were laid out in: nothing clipped.
        expect(
          paragraph.getMaxIntrinsicWidth(double.infinity),
          lessThanOrEqualTo(paragraph.size.width + 0.5),
          reason: 'one line holds it, or it wraps whole',
        );
        expect(find.byType(DropdownButtonFormField<int>), findsNothing);
        expect(
          find.descendant(
            of: find.widgetWithText(ListTile, es.timedTasks),
            matching: find.text(value),
          ),
          findsOneWidget,
        );
        expect(find.text('OPCIONES PREDETERMINADAS'), findsNothing);
        expect(find.text('Opciones predeterminadas'), findsNothing);
        // The row opens the one-tap list of leads, without a default row.
        await tester.tap(find.text(es.timedTasks));
        await tester.pumpAndSettle();
        final sheet = find.byType(BottomSheet);
        expect(sheet, findsOneWidget);
        expect(
          find.descendant(of: sheet, matching: find.byType(ListTile)),
          findsNWidgets(6),
        );
        expect(tester.takeException(), isNull);
      },
    );

    for (final leave in ['Ahora no', 'Back']) {
      testWidgets(
        'UX-1622: the Alarmas y recordatorios sheet says what to do next and offers Ahora no; leaving by $leave ends the flow as Back does',
        (tester) async {
          final store = MemoryReminderStore();
          final access = FakeReminderAccess(exact: false);
          await pumpChip(tester, store, access);
          await tester.tap(find.byType(ReminderChip));
          await tester.pumpAndSettle();
          final sheet = find.byType(BottomSheet);
          expect(sheet, findsOneWidget);
          expect(
            find.descendant(
              of: sheet,
              matching: find.text(es.exactAlarmsNextScreen),
            ),
            findsOneWidget,
          );
          final notNow = find.descendant(
            of: sheet,
            matching: find.widgetWithText(TextButton, es.reminderAskNotNow),
          );
          expect(notNow, findsOneWidget);
          expect(es.reminderAskNotNow, 'Ahora no');
          // Under the button.
          expect(
            tester.getTopLeft(notNow).dy,
            greaterThan(
              tester
                  .getBottomLeft(
                    find.descendant(
                      of: sheet,
                      matching: find.widgetWithText(
                        FilledButton,
                        es.allowPreciseAlarms,
                      ),
                    ),
                  )
                  .dy,
            ),
          );
          if (leave == 'Ahora no') {
            await tester.tap(notNow);
          } else {
            await tester.binding.handlePopRoute();
          }
          await tester.pumpAndSettle();
          expect(find.byType(BottomSheet), findsNothing);
          expect(access.exactRequests, 0);
          expect(store.value.enabled, isTrue);
          final snack = find.byType(SnackBar);
          expect(
            find.descendant(
              of: snack,
              matching: find.text(es.exactAlarmsNeeded),
            ),
            findsOneWidget,
          );
          expect(find.text(es.remindersOnConfirmation), findsNothing);
          expect(tester.takeException(), isNull);
        },
      );
    }

    testWidgets(
      'UX-1622: the second line shows only on the Alarmas y recordatorios sheet, not on Recordatorios',
      (tester) async {
        final store = MemoryReminderStore(
          const ReminderPreferences(enabled: true, asked: true),
        );
        final access = FakeReminderAccess(allowed: true, exact: false);
        await tester.pumpWidget(
          app(store, access, const NotificationSettingsScreen()),
        );
        await tester.pumpAndSettle();
        expect(find.text(es.exactAlarmsNeeded), findsOneWidget);
        expect(find.text(es.exactAlarmsNextScreen), findsNothing);
      },
    );

    // ---- Run 2026-10-19-app · P216 (UX-1650): Detalles waits for the alerts ----

    Future<void> openDetails(WidgetTester tester) async {
      final details = find.byKey(const ValueKey('reminder-details'));
      await tester.scrollUntilVisible(details, 200);
      await tester.pumpAndSettle();
      await tester.tap(details);
      await tester.pumpAndSettle();
    }

    final upcoming = <String, Object?>{
      'identity': 'local/task/1/once',
      'title': 'Médico',
      'fire_at': DateTime(
        tomorrow.year,
        tomorrow.month,
        tomorrow.day,
        9,
        45,
      ).toUtc().toIso8601String(),
      'status': 'scheduled',
      'daily': 0,
      'error': null,
    };

    for (final fails in [false, true]) {
      testWidgets(
        fails
            ? 'UX-1650: Recordatorios, a turn-on whose alerts fail to set: after it ends, Reintentar shows with no app resume'
            : 'UX-1650: Recordatorios, turning on waits for the alerts: the confirmation shows first, the switch stays on with the bar, then Detalles lists the alert',
        (tester) async {
          final store = MemoryReminderStore();
          final access = _SlowReconcile(
            store,
            delay: const Duration(seconds: 2),
            alerts: [upcoming],
            fails: fails,
          );
          await tester.pumpWidget(
            app(store, access, const NotificationSettingsScreen()),
          );
          await tester.pumpAndSettle();
          expect(switchOn(tester), isFalse);
          // UX-2601: off, the switch is alone.
          expect(find.text(es.notificationPermissionOff), findsNothing);
          access.reconciles = 0;

          await tester.tap(find.byType(SwitchListTile));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));
          // The confirmation doesn't wait for the alerts.
          expect(access.pending, isTrue);
          expect(
            find.descendant(
              of: find.byType(SnackBar),
              matching: find.text(es.remindersOnConfirmation),
            ),
            findsOneWidget,
          );
          // Until the alerts are set: switch on, bar showing, no problem line.
          for (var step = 0; step < 16; step++) {
            expect(access.pending, isTrue, reason: 'step $step');
            expect(switchOn(tester), isTrue, reason: 'step $step');
            expect(
              find.byType(LinearProgressIndicator),
              findsOneWidget,
              reason: 'step $step',
            );
            expect(
              find.text(es.notificationPermissionOff),
              findsNothing,
              reason: 'step $step',
            );
            await tester.pump(const Duration(milliseconds: 100));
          }
          await tester.pump(const Duration(seconds: 1));
          expect(access.pending, isFalse);
          await tester.pumpAndSettle();
          expect(find.byType(LinearProgressIndicator), findsNothing);
          expect(switchOn(tester), isTrue);
          expect(find.text(es.notificationPermissionOff), findsNothing);
          // One run of setting the alerts per turn-on; the screen's own load
          // only reads the outcome.
          expect(access.reconciles, 1);
          if (fails) {
            expect(
              find.widgetWithText(OutlinedButton, es.tryAgain),
              findsOneWidget,
            );
          } else {
            expect(
              find.widgetWithText(OutlinedButton, es.tryAgain),
              findsNothing,
            );
            await openDetails(tester);
            expect(find.text('Médico'), findsOneWidget);
            expect(find.text(es.noUpcomingAlerts), findsNothing);
          }
          expect(tester.takeException(), isNull);
        },
      );
    }

    testWidgets(
      'UX-1650 / UX-2601: a refusal at Android’s dialog still turns the switch off at once, alone, with the message',
      (tester) async {
        final store = MemoryReminderStore();
        final access = _SlowReconcile(
          store,
          delay: const Duration(seconds: 2),
          alerts: [upcoming],
          grant: false,
        );
        await tester.pumpWidget(
          app(store, access, const NotificationSettingsScreen()),
        );
        await tester.pumpAndSettle();
        access.reconciles = 0;
        await tester.tap(find.byType(SwitchListTile));
        await tester.pump();
        await tester.pump();
        await tester.pump();
        expect(switchOn(tester), isFalse);
        // UX-2601: no line of the screen's own while the switch is off; the
        // message says it.
        expect(
          find.descendant(
            of: find.byType(ListTile),
            matching: find.text(es.notificationPermissionOff),
          ),
          findsNothing,
        );
        expect(access.reconciles, 0);
        await tester.pumpAndSettle();
        expect(switchOn(tester), isFalse);
        expect(store.value.enabled, isFalse);
        expect(tester.takeException(), isNull);
      },
    );
  });

  // ---- Run 2026-10-19-app, round 1 · P190 (UX-1601): an alert time that
  // has already passed says so, on the chip and in the form ----
  group('P190', () {
    const timeoutChannel = MethodChannel('taskflow/accessibility');
    final platform =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    setUp(
      () =>
          platform.setMockMethodCallHandler(timeoutChannel, (_) async => null),
    );
    tearDown(() => platform.setMockMethodCallHandler(timeoutChannel, null));
    // Monday 19 October 2026.
    final today = DateTime(2026, 10, 19);
    final tomorrow = DateTime(2026, 10, 20);
    final at11 = DateTime(2026, 10, 19, 11);
    final at8 = DateTime(2026, 10, 19, 8);
    // On and allowed, with the 9:00 default that turning them on writes.
    const on = ReminderPreferences(
      enabled: true,
      asked: true,
      dateOnlyTime: 540,
    );
    Task dateOnly(
      DateTime day, {
      int id = 1,
      String? listId,
      String assignment = 'personal',
      int? assigneeId,
      String? assigneeName,
    }) => Task(
      id: id,
      title: 'Llamar a Marta',
      priority: 1,
      dueDate: day,
      hasTime: false,
      listId: listId,
      assignment: assignment,
      assigneeId: assigneeId,
      assigneeName: assigneeName,
    );

    // María (account 1) owns «Matemáticas»; Ana (2) is in it.
    TaskListInfo project({
      String notifications = 'all',
      bool archived = false,
    }) => TaskListInfo(
      id: 'matematicas',
      name: 'Matemáticas',
      version: 3,
      role: 'owner',
      shared: true,
      ownerId: 1,
      notifications: notifications,
      archived: archived,
      people: const [
        ProjectMember(id: 1, name: 'María', role: 'owner'),
        ProjectMember(id: 2, name: 'Ana', role: 'editor'),
      ],
    );

    /// The app at [now], holding [tasks], in [language].
    Future<ProviderContainer> openApp(
      WidgetTester tester, {
      required DateTime now,
      required List<Task> tasks,
      List<TaskListInfo> projects = const [],
      ReminderPreferences preferences = on,
      bool allowed = true,
      String language = 'es',
      Size size = const Size(390, 844),
      double textScale = 1,
    }) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = textScale;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final container = designContainer(
        projects: projects,
        tasks: () => _P190Tasks(tasks),
        regionalStore: MemoryRegionalStore(
          RegionalPreferences(
            language: language,
            clock: ClockFormat.twentyFour,
            weekStart: 1,
          ),
        ),
        overrides: [
          ...reminderOverrides(
            MemoryReminderStore(preferences),
            FakeReminderAccess(allowed: allowed),
          ),
          calendarClockProvider.overrideWithValue(() => now),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(container: container, child: const MyApp()),
      );
      await tester.pumpAndSettle();
      return container;
    }

    /// The detail of task [id], with its reminder chip in view.
    Future<void> openDetail(WidgetTester tester, int id) async {
      tester
          .state<NavigatorState>(find.byType(Navigator).first)
          .pushNamed('/taskDetails', arguments: id);
      await tester.pumpAndSettle();
      final chip = find.byType(ReminderChip);
      expect(chip, findsOneWidget);
      await tester.ensureVisible(chip);
      await tester.pumpAndSettle();
    }

    String chipLabel(WidgetTester tester) => tester
        .widgetList<Text>(
          find.descendant(
            of: find.byType(ReminderChip),
            matching: find.byType(Text),
          ),
        )
        .map((text) => text.data ?? '')
        .join();

    Finder chipIcon(IconData icon) => find.descendant(
      of: find.byType(ReminderChip),
      matching: find.byIcon(icon),
    );

    String nine(WidgetTester tester) => tester
        .element(find.byType(ReminderChip))
        .clockTime(DateTime(2000, 1, 1, 9));

    test('UX-1601: the passed reading in EN, ES and CA', () {
      expect(
        lookupAppLocalizations(const Locale('en')).noReminderTimePassed,
        'No reminder: the alert time has passed',
      );
      expect(
        lookupAppLocalizations(const Locale('es')).noReminderTimePassed,
        'Sin recordatorio: ya ha pasado la hora del aviso',
      );
      expect(
        lookupAppLocalizations(const Locale('ca')).noReminderTimePassed,
        'Sense recordatori: l’hora de l’avís ja ha passat',
      );
    });

    for (final language in ['es', 'en', 'ca']) {
      testWidgets(
        'UX-1601: reminders on and allowed, at 11:00 the detail of a date-only task for today reads the passed reading, with the crossed-out bell ($language)',
        (tester) async {
          final l = lookupAppLocalizations(Locale(language));
          await openApp(
            tester,
            now: at11,
            tasks: [dateOnly(today)],
            language: language,
          );
          await openDetail(tester, 1);
          expect(chipLabel(tester), l.noReminderTimePassed);
          expect(chipLabel(tester), isNot(contains('9:00')));
          expect(chipIcon(Icons.notifications_off_outlined), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );
    }

    testWidgets(
      'UX-1601: at 11:00 a date-only task for tomorrow reads «Recordatorio: 9:00»',
      (tester) async {
        final es = lookupAppLocalizations(const Locale('es'));
        await openApp(tester, now: at11, tasks: [dateOnly(tomorrow)]);
        await openDetail(tester, 1);
        expect(chipLabel(tester), es.reminderValue(nine(tester)));
        expect(chipIcon(Icons.notifications_outlined), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'UX-1601: at 08:00 today’s date-only task reads «Recordatorio: 9:00»',
      (tester) async {
        final es = lookupAppLocalizations(const Locale('es'));
        await openApp(tester, now: at8, tasks: [dateOnly(today)]);
        await openDetail(tester, 1);
        expect(chipLabel(tester), es.reminderValue(nine(tester)));
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'UX-1601: at 11:00 the edit form’s Recordatorio row for today’s date-only task says the same',
      (tester) async {
        final es = lookupAppLocalizations(const Locale('es'));
        await openApp(tester, now: at11, tasks: [dateOnly(today)]);
        unawaited(
          tester
              .state<NavigatorState>(find.byType(Navigator).first)
              .push(
                MaterialPageRoute<void>(
                  builder: (_) => TaskEditor(task: dateOnly(today)),
                ),
              ),
        );
        await tester.pumpAndSettle();
        final more = find.byKey(const ValueKey('task-more-details'));
        if (more.evaluate().isNotEmpty) {
          await tester.ensureVisible(more);
          await tester.pumpAndSettle();
          await tester.tap(more);
          await tester.pumpAndSettle();
        }
        final row = find.descendant(
          of: find.byType(ReminderControl),
          matching: find.byType(ListTile),
        );
        await tester.ensureVisible(row);
        await tester.pumpAndSettle();
        // P270 (UX-2206): the passed line names itself, alone in the row.
        expect(
          (tester.widget<ListTile>(row).title! as Text).data,
          es.noReminderTimePassed,
        );
        expect(tester.widget<ListTile>(row).subtitle, isNull);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'UX-1601: tapping the passed chip opens the chooser; «Elegir hora del aviso» at 18:00 makes it read «Recordatorio: 18:00»',
      (tester) async {
        final es = lookupAppLocalizations(const Locale('es'));
        final container = await openApp(
          tester,
          now: at11,
          tasks: [dateOnly(today)],
        );
        await openDetail(tester, 1);
        expect(chipLabel(tester), es.noReminderTimePassed);
        await tester.tap(find.byType(ReminderChip));
        await tester.pumpAndSettle();
        final sheet = find.byType(BottomSheet);
        expect(sheet, findsOneWidget);
        final choose = find.descendant(
          of: sheet,
          matching: find.text(es.chooseAlertTime),
        );
        expect(choose, findsOneWidget);
        await tester.tap(choose);
        await tester.pumpAndSettle();
        final dialog = find.byType(TimePickerDialog);
        expect(dialog, findsOneWidget);
        final boxes = find.descendant(
          of: dialog,
          matching: find.byType(TextField),
        );
        await tester.enterText(boxes.at(0), '18');
        await tester.enterText(boxes.at(1), '00');
        await tester.pumpAndSettle();
        await tester.tap(
          find.text(
            MaterialLocalizations.of(tester.element(dialog)).okButtonLabel,
          ),
        );
        await tester.pumpAndSettle();
        expect(dialog, findsNothing);
        expect(
          container
              .read(taskProvider)
              .requireValue
              .singleWhere((task) => task.id == 1)
              .reminderTime,
          18 * 60,
        );
        final six = tester
            .element(find.byType(ReminderChip))
            .clockTime(DateTime(2000, 1, 1, 18));
        expect(six, '18:00');
        expect(chipLabel(tester), es.reminderValue(six));
        expect(chipIcon(Icons.notifications_outlined), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    for (final (name, preferences, allowed) in [
      ('reminders are off', const ReminderPreferences(dateOnlyTime: 540), true),
      ('notifications are blocked', on, false),
    ]) {
      testWidgets(
        'UX-1601, UX-209: when $name the passed task still reads «Sin recordatorio · Activar»',
        (tester) async {
          final es = lookupAppLocalizations(const Locale('es'));
          await openApp(
            tester,
            now: at11,
            tasks: [dateOnly(today)],
            preferences: preferences,
            allowed: allowed,
          );
          await openDetail(tester, 1);
          expect(chipLabel(tester), es.noReminderTurnOn);
          expect(tester.takeException(), isNull);
        },
      );
    }

    for (final (name, task, projects, reading) in [
      (
        'Ana’s task viewed by María',
        dateOnly(
          today,
          listId: 'matematicas',
          assignment: 'member',
          assigneeId: 2,
          assigneeName: 'Ana',
        ),
        [project()],
        (AppLocalizations l) => l.reminderForPersonOnly('Ana'),
      ),
      (
        'a task in a muted project',
        dateOnly(
          today,
          listId: 'matematicas',
          assignment: 'member',
          assigneeId: 1,
          assigneeName: 'María',
        ),
        [project(notifications: 'muted')],
        (AppLocalizations l) => l.noReminderProjectMuted,
      ),
      (
        'a task in an archived project',
        dateOnly(
          today,
          listId: 'matematicas',
          assignment: 'member',
          assigneeId: 1,
          assigneeName: 'María',
        ),
        [project(archived: true)],
        (AppLocalizations l) => l.noReminderProjectArchived,
      ),
    ]) {
      testWidgets(
        'UX-1601, UX-1505: at 11:00, $name keeps its own reading over the passed one',
        (tester) async {
          final es = lookupAppLocalizations(const Locale('es'));
          await openApp(tester, now: at11, tasks: [task], projects: projects);
          final value = ValueNotifier(task);
          addTearDown(value.dispose);
          // The chip alone, as the detail draws it: an archived project's
          // detail may not open for editing.
          tester
              .state<NavigatorState>(find.byType(Navigator).first)
              .push(
                MaterialPageRoute<void>(
                  builder: (_) => Scaffold(
                    body: Padding(
                      padding: const EdgeInsets.all(24),
                      child: ValueListenableBuilder<Task>(
                        valueListenable: value,
                        builder: (context, task, _) => ReminderChip(
                          task: task,
                          onChanged: (changed) => value.value = changed,
                        ),
                      ),
                    ),
                  ),
                ),
              );
          await tester.pumpAndSettle();
          expect(chipLabel(tester), reading(es));
          expect(chipLabel(tester), isNot(es.noReminderTimePassed));
          expect(tester.takeException(), isNull);
        },
      );
    }

    for (final language in ['es', 'ca']) {
      testWidgets(
        'UX-1601: ${language.toUpperCase()}, 2× on 360×800, the passed reading on the detail is whole, inside the screen, with no overflow',
        (tester) async {
          await (FontLoader(
            'Manrope',
          )..addFont(rootBundle.load('assets/fonts/Manrope.ttf'))).load();
          final l = lookupAppLocalizations(Locale(language));
          await openApp(
            tester,
            now: at11,
            tasks: [dateOnly(today)],
            language: language,
            size: const Size(360, 800),
            textScale: 2,
          );
          await openDetail(tester, 1);
          final text = find.descendant(
            of: find.byType(ReminderChip),
            matching: find.text(l.noReminderTimePassed),
          );
          expect(text, findsOneWidget);
          final paragraph = tester.renderObject<RenderParagraph>(text);
          expect(paragraph.didExceedMaxLines, isFalse);
          final rect = tester.getRect(find.byType(ReminderChip));
          expect(rect.left, greaterThanOrEqualTo(0));
          expect(rect.right, lessThanOrEqualTo(360));
          final textRect = tester.getRect(text);
          expect(textRect.right, lessThanOrEqualTo(rect.right));
          expect(tester.takeException(), isNull);
        },
      );
    }
  });

  group('P270 · a reminder that has rung', () {
    const timeoutChannel = MethodChannel('taskflow/accessibility');
    final platform =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    setUp(
      () =>
          platform.setMockMethodCallHandler(timeoutChannel, (_) async => null),
    );
    tearDown(() => platform.setMockMethodCallHandler(timeoutChannel, null));
    const on = ReminderPreferences(
      enabled: true,
      asked: true,
      dateOnlyTime: 540,
    );
    // Monday 19 October 2026.
    DateTime at(int hour, int minute) => DateTime(2026, 10, 19, hour, minute);

    /// «Pagar la luz», today at 09:50 with «10 minutos antes».
    Task bill(int id) => Task(
      id: id,
      title: 'Pagar la luz',
      priority: 1,
      dueDate: at(9, 50),
      hasTime: true,
      reminderMinutes: 10,
    );

    /// A date-only task for today, with the 9:00 default (D1).
    Task call(int id) => Task(
      id: id,
      title: 'Llamar a Marta',
      priority: 1,
      dueDate: DateTime(2026, 10, 19),
      hasTime: false,
    );

    // What the real engine keeps on the phone for each case.
    late int billId;
    late List<Map<String, Object?>> ringing; // rang at 09:40, not planned again
    late List<Map<String, Object?>> rang; // planned again at 09:41
    late List<Map<String, Object?>> snoozed; // «Posponer 10 min» at 09:42
    late int callId;
    late List<Map<String, Object?>> savedLate; // saved at 10:00 (D1)
    setUpAll(() async {
      final phone = await PhoneAlerts.open(at(9, 30));
      billId = await phone.add(bill(0));
      ringing = await phone.of(billId);
      phone.now = at(9, 41);
      await phone.refresh();
      rang = await phone.of(billId);
      phone.now = at(9, 42);
      await phone.snooze(billId);
      snoozed = await phone.of(billId);
      await phone.close();
      final later = await PhoneAlerts.open(at(10, 0));
      callId = await later.add(call(0));
      savedLate = await later.of(callId);
      await later.close();
    });

    /// The app at [now], with [kept] as the phone's alerts.
    Future<void> open(
      WidgetTester tester, {
      required DateTime now,
      required List<Task> tasks,
      List<Map<String, Object?>> kept = const [],
      String language = 'es',
    }) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final container = designContainer(
        tasks: () => _P190Tasks(tasks),
        regionalStore: MemoryRegionalStore(
          RegionalPreferences(
            language: language,
            clock: ClockFormat.twentyFour,
            weekStart: 1,
          ),
        ),
        overrides: [
          ...reminderOverrides(
            MemoryReminderStore(on),
            FakeReminderAccess(allowed: true)..kept = [...kept],
          ),
          calendarClockProvider.overrideWithValue(() => now),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(container: container, child: const MyApp()),
      );
      await tester.pumpAndSettle();
    }

    NavigatorState navigator(WidgetTester tester) =>
        tester.state<NavigatorState>(find.byType(Navigator).first);

    /// Task [id]'s page, its reminder chip in view.
    Future<void> openDetail(WidgetTester tester, int id) async {
      navigator(tester).pushNamed('/taskDetails', arguments: id);
      await tester.pumpAndSettle();
      final chip = find.byType(ReminderChip);
      expect(chip, findsOneWidget);
      await tester.ensureVisible(chip);
      await tester.pumpAndSettle();
    }

    /// [task]'s edit form, «Más detalles» open, its reminder row in view.
    Future<Finder> openForm(WidgetTester tester, Task task) async {
      unawaited(
        navigator(
          tester,
        ).push(MaterialPageRoute<void>(builder: (_) => TaskEditor(task: task))),
      );
      await tester.pumpAndSettle();
      final more = find.byKey(const ValueKey('task-more-details'));
      if (more.evaluate().isNotEmpty) {
        await tester.ensureVisible(more);
        await tester.pumpAndSettle();
        await tester.tap(more);
        await tester.pumpAndSettle();
      }
      final row = find.descendant(
        of: find.byType(ReminderControl),
        matching: find.byType(ListTile),
      );
      expect(row, findsOneWidget);
      await tester.ensureVisible(row);
      await tester.pumpAndSettle();
      return row;
    }

    String chipLabel(WidgetTester tester) => tester
        .widgetList<Text>(
          find.descendant(
            of: find.byType(ReminderChip),
            matching: find.byType(Text),
          ),
        )
        .map((text) => text.data ?? '')
        .join();

    Finder chipIcon(IconData icon) => find.descendant(
      of: find.byType(ReminderChip),
      matching: find.byIcon(icon),
    );

    String clock(WidgetTester tester, int hour, int minute) =>
        tester.element(find.byType(ReminderChip)).clockTime(at(hour, minute));

    test('the engine kept the alert that rang, and its snooze', () {
      expect(ringing.map((row) => row['status']), contains('scheduled'));
      expect(rang.map((row) => row['status']), contains('elapsed'));
      expect(snoozed.any((row) => row['snooze_at'] != null), isTrue);
    });

    test('UX-2401: the sent and snoozed lines in EN, ES and CA', () {
      final en = lookupAppLocalizations(const Locale('en'));
      final es = lookupAppLocalizations(const Locale('es'));
      final ca = lookupAppLocalizations(const Locale('ca'));
      expect(
        en.reminderSent('today', '', '09:40'),
        'Reminder sent: today, 09:40',
      );
      expect(
        es.reminderSent('today', '', '09:40'),
        'Recordatorio enviado: hoy, 09:40',
      );
      expect(
        ca.reminderSent('today', '', '09:40'),
        'Recordatori enviat: avui, 09:40',
      );
      expect(
        en.reminderSnoozed('today', '', '09:52'),
        'Reminder snoozed: today, 09:52',
      );
      expect(
        es.reminderSnoozed('today', '', '09:52'),
        'Recordatorio pospuesto: hoy, 09:52',
      );
      expect(
        ca.reminderSnoozed('today', '', '09:52'),
        'Recordatori ajornat: avui, 09:52',
      );
    });

    test('UX-2411: the deadline reading in EN, ES and CA', () {
      final en = lookupAppLocalizations(const Locale('en'));
      final es = lookupAppLocalizations(const Locale('es'));
      final ca = lookupAppLocalizations(const Locale('ca'));
      expect(
        en.reminderValue(en.reminderBeforeDeadline('1 hour before')),
        'Reminder: 1 hour before · deadline',
      );
      expect(
        es.reminderValue(es.reminderBeforeDeadline('1 hora antes')),
        'Recordatorio: 1 hora antes · fecha límite',
      );
      expect(
        ca.reminderValue(ca.reminderBeforeDeadline('1 hora abans')),
        'Recordatori: 1 hora abans · termini',
      );
    });

    for (final language in ['es', 'en', 'ca']) {
      testWidgets(
        'UX-2401: opened at 09:41, a reminder that rang at 09:40 reads «Recordatorio enviado: hoy, 09:40» with the usual bell ($language)',
        (tester) async {
          final l = lookupAppLocalizations(Locale(language));
          await open(
            tester,
            now: at(9, 41),
            tasks: [bill(billId)],
            kept: rang,
            language: language,
          );
          await openDetail(tester, billId);
          final time = clock(tester, 9, 40);
          expect(time, '09:40');
          expect(chipLabel(tester), l.reminderSent('today', '', time));
          expect(chipLabel(tester), isNot(l.noReminderTimePassed));
          expect(chipIcon(Icons.notifications_outlined), findsOneWidget);
          expect(chipIcon(Icons.notifications_off_outlined), findsNothing);
          expect(tester.takeException(), isNull);
        },
      );
    }

    testWidgets(
      'UX-2401: opened from its notice before the phone plans again, the reminder that rang still reads «Recordatorio enviado: hoy, 09:40»',
      (tester) async {
        final es = lookupAppLocalizations(const Locale('es'));
        await open(
          tester,
          now: at(9, 41),
          tasks: [bill(billId)],
          kept: ringing,
        );
        await openDetail(tester, billId);
        expect(
          chipLabel(tester),
          es.reminderSent('today', '', clock(tester, 9, 40)),
        );
        expect(chipIcon(Icons.notifications_outlined), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'UX-2401: a tap on «Recordatorio enviado» opens the reminder choices',
      (tester) async {
        final es = lookupAppLocalizations(const Locale('es'));
        await open(tester, now: at(9, 41), tasks: [bill(billId)], kept: rang);
        await openDetail(tester, billId);
        final lead = tester.element(find.byType(ReminderChip)).reminderLead(10);
        await tester.tap(find.byType(ReminderChip));
        await tester.pumpAndSettle();
        final sheet = find.byType(BottomSheet);
        expect(sheet, findsOneWidget);
        expect(
          find.descendant(of: sheet, matching: find.text(es.reminder)),
          findsWidgets,
        );
        expect(
          find.descendant(of: sheet, matching: find.textContaining(lead)),
          findsWidgets,
        );
        expect(tester.takeException(), isNull);
      },
    );

    for (final language in ['es', 'en', 'ca']) {
      testWidgets(
        'UX-2401: after «Posponer 10 min» at 09:42 it reads «Recordatorio pospuesto: hoy, 09:52» ($language)',
        (tester) async {
          final l = lookupAppLocalizations(Locale(language));
          await open(
            tester,
            now: at(9, 43),
            tasks: [bill(billId)],
            kept: snoozed,
            language: language,
          );
          await openDetail(tester, billId);
          final time = clock(tester, 9, 52);
          expect(time, '09:52');
          expect(chipLabel(tester), l.reminderSnoozed('today', '', time));
          expect(chipIcon(Icons.notifications_outlined), findsOneWidget);
          expect(chipIcon(Icons.notifications_off_outlined), findsNothing);
          expect(tester.takeException(), isNull);
        },
      );
    }

    testWidgets(
      'UX-2401 (D1): a date-only task for today saved at 10:00 with the 9:00 default still reads «Sin recordatorio: ya ha pasado la hora del aviso»',
      (tester) async {
        final es = lookupAppLocalizations(const Locale('es'));
        await open(
          tester,
          now: at(10, 0),
          tasks: [call(callId)],
          kept: savedLate,
        );
        await openDetail(tester, callId);
        expect(chipLabel(tester), es.noReminderTimePassed);
        expect(chipIcon(Icons.notifications_off_outlined), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'UX-2401: the form’s row of a reminder that rang reads «Recordatorio enviado: hoy, 09:40» alone, with the usual bell',
      (tester) async {
        final es = lookupAppLocalizations(const Locale('es'));
        await open(tester, now: at(9, 41), tasks: [bill(billId)], kept: rang);
        final row = await openForm(tester, bill(billId));
        final tile = tester.widget<ListTile>(row);
        final time = tester.element(row).clockTime(at(9, 40));
        expect((tile.title! as Text).data, es.reminderSent('today', '', time));
        expect(tile.subtitle, isNull);
        expect(
          find.descendant(
            of: row,
            matching: find.byIcon(Icons.notifications_outlined),
          ),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );

    /// «Entregar el informe» tomorrow at 10:00, due the day after at 12:00,
    /// with «1 hora antes» from [anchor].
    Task report(String anchor) => Task(
      id: 5,
      title: 'Entregar el informe',
      priority: 1,
      dueDate: DateTime(2026, 10, 20, 10),
      hasTime: true,
      deadline: DateTime(2026, 10, 21, 12),
      deadlineHasTime: true,
      reminderAnchor: anchor,
      reminderMinutes: 60,
    );

    testWidgets(
      'UX-2411: a task with a deadline whose reminder counts from its day reads «Recordatorio: 1 hora antes», with no «Planificado para ·»',
      (tester) async {
        final es = lookupAppLocalizations(const Locale('es'));
        await open(tester, now: at(9, 0), tasks: [report('planned')]);
        await openDetail(tester, 5);
        final lead = tester.element(find.byType(ReminderChip)).reminderLead(60);
        expect(chipLabel(tester), es.reminderValue(lead));
        expect(chipLabel(tester), isNot(contains(es.plannedFor)));
        expect(chipLabel(tester), isNot(contains(es.deadline)));
        expect(tester.takeException(), isNull);
      },
    );

    for (final language in ['es', 'en', 'ca']) {
      testWidgets(
        'UX-2411: counting from the deadline it reads «Recordatorio: 1 hora antes · fecha límite» ($language)',
        (tester) async {
          final l = lookupAppLocalizations(Locale(language));
          await open(
            tester,
            now: at(9, 0),
            tasks: [report('deadline')],
            language: language,
          );
          await openDetail(tester, 5);
          final lead = tester
              .element(find.byType(ReminderChip))
              .reminderLead(60);
          expect(
            chipLabel(tester),
            l.reminderValue(l.reminderBeforeDeadline(lead)),
          );
          expect(chipLabel(tester), isNot(contains(l.plannedFor)));
          expect(tester.takeException(), isNull);
        },
      );
    }

    testWidgets(
      'UX-2206: a single reminder’s form row still shows «Recordatorio» over «10 minutos antes»',
      (tester) async {
        final es = lookupAppLocalizations(const Locale('es'));
        final tomorrow = bill(
          1,
        ).copyWith(dueDate: DateTime(2026, 10, 20, 9, 50));
        await open(tester, now: at(9, 0), tasks: [tomorrow]);
        final row = await openForm(tester, tomorrow);
        final tile = tester.widget<ListTile>(row);
        expect((tile.title! as Text).data, es.reminder);
        expect(
          (tile.subtitle! as Text).data,
          tester.element(row).reminderLead(10),
        );
        expect(tester.takeException(), isNull);
      },
    );
  });

  group('P272 · Recordatorios has one way in while they’re off', () {
    const timeoutChannel = MethodChannel('taskflow/accessibility');
    final platform =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    setUp(
      () =>
          platform.setMockMethodCallHandler(timeoutChannel, (_) async => null),
    );
    tearDown(() => platform.setMockMethodCallHandler(timeoutChannel, null));
    final es = lookupAppLocalizations(const Locale('es'));

    /// Ajustes › Recordatorios in Spanish at 1× on a 360×800 phone.
    Future<void> openReminders(
      WidgetTester tester,
      MemoryReminderStore store,
      FakeReminderAccess access,
    ) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...reminderOverrides(store, access),
            taskRepositoryProvider.overrideWithValue(MemoryTasks()),
          ],
          child: MaterialApp(
            locale: const Locale('es'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: AppTheme.light,
            home: const NotificationSettingsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    bool switchOn(WidgetTester tester) =>
        tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value;

    /// The screen's own line about the phone blocking, not the message's.
    Finder blockedLine() => find.descendant(
      of: find.byType(ListView),
      matching: find.text(es.notificationPermissionOff),
    );

    Finder allowButton() =>
        find.widgetWithText(FilledButton, es.allowNotifications);

    void leaveApp(WidgetTester tester) {
      for (final state in [
        AppLifecycleState.inactive,
        AppLifecycleState.hidden,
        AppLifecycleState.paused,
      ]) {
        tester.binding.handleAppLifecycleStateChanged(state);
      }
    }

    void returnToApp(WidgetTester tester) {
      for (final state in [
        AppLifecycleState.hidden,
        AppLifecycleState.inactive,
        AppLifecycleState.resumed,
      ]) {
        tester.binding.handleAppLifecycleStateChanged(state);
      }
    }

    testWidgets(
      'UX-2601: ES 1× on 360×800, the switch off and notifications blocked: the switch alone, and turning it on asks Android',
      (tester) async {
        final store = MemoryReminderStore();
        final access = FakeReminderAccess(allowed: false);
        await openReminders(tester, store, access);
        final toggle = find.widgetWithText(SwitchListTile, es.enableReminders);
        expect(toggle, findsOneWidget);
        expect(switchOn(tester), isFalse);
        // Inside the viewport.
        final box = tester.getRect(toggle);
        expect(box.top, greaterThanOrEqualTo(0));
        expect(box.bottom, lessThanOrEqualTo(800));
        expect(blockedLine(), findsNothing);
        expect(find.text(es.notificationPermissionOff), findsNothing);
        expect(allowButton(), findsNothing);
        expect(find.text(es.allowNotifications), findsNothing);
        expect(find.byIcon(Icons.notifications_off_outlined), findsNothing);

        await tester.tap(toggle);
        await tester.pumpAndSettle();
        expect(access.permissionRequests, 1);
        expect(access.notificationSettingsOpened, 0);
        expect(store.value.enabled, isTrue);
        expect(switchOn(tester), isTrue);
        expect(find.text(es.remindersOnConfirmation), findsOneWidget);
        expect(blockedLine(), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'UX-2601: the switch refused by Android, then its «Permitir avisos» and allowing in Android: back on Recordatorios the switch is on, with Listo. Recordatorios activados.',
      (tester) async {
        final store = MemoryReminderStore();
        final access = FakeReminderAccess(allowed: false, grant: false);
        await openReminders(tester, store, access);
        await tester.tap(find.byType(SwitchListTile));
        await tester.pumpAndSettle();
        expect(access.permissionRequests, 1);
        expect(switchOn(tester), isFalse);
        expect(blockedLine(), findsNothing);
        expect(allowButton(), findsNothing);
        await tester.tap(
          find.widgetWithText(SnackBarAction, es.allowNotifications),
        );
        await tester.pump();
        expect(access.notificationSettingsOpened, 1);
        leaveApp(tester);
        await tester.pump();

        access.allowed = true;
        returnToApp(tester);
        await tester.pumpAndSettle();
        expect(store.value.enabled, isTrue);
        expect(store.value.dateOnlyTime, 540);
        expect(store.value.asked, isTrue);
        expect(switchOn(tester), isTrue);
        expect(find.text(es.remindersOnConfirmation), findsOneWidget);
        expect(blockedLine(), findsNothing);
        expect(allowButton(), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'UX-2601 / UX-1606: the switch on and notifications blocked still show the line and «Permitir avisos», which opens the notifications page',
      (tester) async {
        final store = MemoryReminderStore(
          const ReminderPreferences(enabled: true, asked: true),
        );
        final access = FakeReminderAccess(allowed: false);
        await openReminders(tester, store, access);
        expect(switchOn(tester), isTrue);
        expect(blockedLine(), findsOneWidget);
        expect(allowButton(), findsOneWidget);
        await tester.tap(allowButton());
        await tester.pumpAndSettle();
        expect(access.notificationSettingsOpened, 1);
        expect(access.permissionRequests, 0);
        expect(tester.takeException(), isNull);
      },
    );
  });
}

class _Preferences extends ReminderPreferenceStore {
  _Preferences(super.database);
  ReminderPreferences value = const ReminderPreferences();
  final alerts = <Map<String, Object?>>[
    {
      'identity': 'local/task/1/once',
      'title': 'Original task title',
      'fire_at': '2030-09-23T12:00:00Z',
      'status': 'blocked',
      'daily': 0,
      'error': 'Notifications are disabled in system settings.',
    },
  ];
  @override
  Future<ReminderPreferences> read(String owner) async => value;
  @override
  Future<void> write(String owner, ReminderPreferences settings) async {
    value = settings;
  }

  @override
  Future<List<Map<String, Object?>>> upcomingAlerts(String owner) async =>
      alerts;
  @override
  Future<List<Map<String, Object?>>> schedulingInfo() async => [
    {'key': 'error', 'value': 'background_failed'},
    {'key': 'window', 'value': '{"owner":"local","deferred":2}'},
  ];
}

/// P187: Android's permission dialog stays up until [answer] completes.
class _GatedAccess extends FakeReminderAccess {
  _GatedAccess({super.grant});
  final answer = Completer<void>();
  @override
  Future<bool> requestPermission() async {
    permissionRequests++;
    await answer.future;
    if (grant) allowed = true;
    return grant;
  }
}

/// P187: once [hang] is set, setting the alerts again waits for [release],
/// which keeps Recordatorios busy.
class _HangingSaveAccess extends FakeReminderAccess {
  _HangingSaveAccess({super.allowed});
  bool hang = false;
  final release = Completer<void>();
  @override
  Future<void> reconcile(String owner) async {
    if (hang) await release.future;
  }
}

/// P187: setting the alerts never finishes.
class _NeverReconciles extends FakeReminderAccess {
  int reconciles = 0;
  @override
  Future<void> reconcile(String owner) {
    reconciles++;
    return Completer<void>().future;
  }
}

/// P216: setting the alerts takes [delay]; then the store lists [alerts], or,
/// when [fails], the error is recorded (as TaskReminders.recordError writes
/// it to reminder_meta) and the call throws.
class _SlowReconcile extends FakeReminderAccess {
  _SlowReconcile(
    this.store, {
    required this.delay,
    required this.alerts,
    this.fails = false,
    super.grant,
  });
  final MemoryReminderStore store;
  final Duration delay;
  final List<Map<String, Object?>> alerts;
  final bool fails;
  int reconciles = 0;
  bool pending = false;
  @override
  Future<void> reconcile(String owner) async {
    reconciles++;
    if (!store.value.enabled) return;
    pending = true;
    await Future<void>.delayed(delay);
    pending = false;
    if (fails) {
      store.info = [
        {'key': 'error', 'value': 'refresh_failed'},
      ];
      throw StateError('scheduling failed');
    }
    store.alerts = alerts;
  }
}

/// P190: the tasks a test gives, kept in memory.
class _P190Tasks extends DesignTaskNotifier {
  _P190Tasks(this.initial);
  final List<Task> initial;
  @override
  Future<void> loadTasks() async {
    if (!state.hasValue) state = AsyncData([...initial]);
  }
}
