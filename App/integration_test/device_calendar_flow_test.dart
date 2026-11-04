// Real Android READ_CALENDAR permission dialogs, Calendar Provider and SQLite.
// Seed only the synthetic calendars/events documented in DEVICE_CALENDAR_VALIDATION.md.
// The host denies/allows the printed OS dialogs, then toggles READ_CALENDAR
// AppOps at the printed markers. No provider or permission channel is mocked.
import 'dart:convert';
import 'package:agenda/providers/no_retry.dart';
import 'package:agenda/main.dart';
import 'package:agenda/models/task.dart';
import 'package:agenda/providers/auth_provider.dart';
import 'package:agenda/providers/device_calendar_provider.dart';
import 'package:agenda/providers/regional_provider.dart';
import 'package:agenda/providers/task_provider.dart';
import 'package:agenda/providers/task_lists_provider.dart';
import 'package:agenda/providers/theme_provider.dart';
import 'package:agenda/repositories/task_repository.dart';
import 'package:agenda/services/capture_store.dart';
import 'package:agenda/services/device_calendars.dart';
import 'package:agenda/services/notification_service.dart';
import 'package:agenda/services/task_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:table_calendar/table_calendar.dart';
import '../test/support/design_fixtures.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
      'Android calendar permission, recurrence, deduplication and revocation',
      (tester) async {
    await TaskReminders.initialize();
    final originalOwner = await TaskReminders.engine.activeOwner();
    final database = TaskDatabase();
    final sql = await database.database;
    final owner =
        'calendar-integration-${DateTime.now().microsecondsSinceEpoch}';
    final repository = _CalendarRepository(database, owner);
    final day = DateTime(2026, 9, 22);
    await database.insertTasks([
      Task(
          title: 'A task stays independent',
          priority: 1,
          dueDate: day,
          hasTime: false,
          reminderMinutes: -1),
    ], ownerKey: owner);
    final before = jsonEncode(
        await sql.query('tasks', where: 'owner_key = ?', whereArgs: [owner]));
    final store = CalendarPreferenceStore(owner, database);
    final container = ProviderContainer(retry: noRetry, overrides: [
      authProvider.overrideWith((ref) => SignedInFixtureAuth(ref.read(apiClientProvider))),
      apiClientProvider.overrideWith((ref) {
        final api = OfflineApiClient();
        ref.onDispose(api.close);
        return api;
      }),
      taskRepositoryProvider.overrideWithValue(repository),
      calendarPreferenceStoreProvider.overrideWithValue(store),
      themeStoreProvider.overrideWithValue(MemoryThemeStore()),
      regionalStoreProvider.overrideWithValue(MemoryRegionalStore()),
      taskListsProvider.overrideWith((ref) async => []),
      pendingCapturesProvider.overrideWith((ref) async => []),
    ]);
    addTearDown(() async {
      container.dispose();
      await sql.delete('tasks', where: 'owner_key = ?', whereArgs: [owner]);
      await sql.delete('app_preferences',
          where: 'scope = ?', whereArgs: ['calendars:$owner']);
      await TaskReminders.activate(originalOwner ?? 'local');
    });
    final controller = container.read(deviceCalendarProvider.notifier);
    final bridge = container.read(deviceCalendarsProvider);
    await controller.ready;
    expect(await bridge.status(), CalendarAccess.denied,
        reason:
            'Start with calendar access unrequested; preserve other app data.');
    await expectLater(
        bridge.events({'1'}, day),
        throwsA(isA<PlatformException>()
            .having((e) => e.code, 'code', 'calendar_permission')));
    await container.read(regionalProvider.notifier).ready;
    await container.read(taskProvider.notifier).loadTasks();
    await tester.pumpWidget(
        UncontrolledProviderScope(container: container, child: const MyApp()));
    await tester.pumpAndSettle();
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    navigator.pushNamed('/deviceCalendars');
    await tester.pumpAndSettle();
    final connect = find.byKey(const ValueKey('calendar-connect'));
    await tester.tap(connect);
    debugPrint('CALENDAR_HOST_DENY_DIALOG');
    await tester.pump();
    await _until(
        tester,
        () async =>
            connect.evaluate().isNotEmpty &&
            tester.widget<FilledButton>(connect).onPressed != null);
    expect(await bridge.status(), CalendarAccess.denied);
    expect(container.read(deviceCalendarProvider).preferences.enabled, isFalse);
    expect((await controller.events(day)).items, isEmpty);
    await tester.tap(connect);
    debugPrint('CALENDAR_HOST_ALLOW_DIALOG');
    await _until(
        tester,
        () async =>
            container.read(deviceCalendarProvider).preferences.enabled &&
            container.read(deviceCalendarProvider).calendars.length >= 2);
    await tester.pumpAndSettle();
    final calendars = container
        .read(deviceCalendarProvider)
        .calendars
        .where((c) => c.account == 'taskflow-calendar-fixture')
        .toList();
    expect(calendars, hasLength(2));
    for (final calendar in calendars) {
      final finder = find.byKey(ValueKey('device-calendar-${calendar.id}'));
      await tester.scrollUntilVisible(finder, 150,
          scrollable: find.byType(Scrollable).last);
      await tester.pumpAndSettle();
      await tester.tap(finder);
      await tester.pumpAndSettle();
    }
    expect((await CalendarPreferenceStore(owner, database).read()).selected,
        calendars.map((c) => c.selectionKey).toSet());
    expect(
        (await CalendarPreferenceStore('$owner-other', database).read())
            .selected,
        isEmpty);
    final selectedIds = calendars.map((c) => c.id).toSet();
    final raw = await bridge.events(selectedIds, day);
    expect(
        raw.items.where((e) => e.title == 'Fixture-appointment'), hasLength(2));
    final result = await controller.events(day);
    expect(result.truncated, isFalse);
    expect(result.items, hasLength(4));
    expect(result.items.singleWhere((e) => e.title == 'Fixture-all-day').allDay,
        isTrue);
    expect(
        result.items
            .singleWhere((e) => e.title == 'Fixture-appointment')
            .sources,
        hasLength(2));
    expect(result.items.any((e) => e.title == 'Fixture-overnight'), isTrue);
    final nextWeek = await controller.events(DateTime(2026, 9, 29));
    expect(nextWeek.items.map((e) => e.title), ['Fixture-weekly']);
    expect(
        (await controller.events(DateTime(2026, 9, 23)))
            .items
            .any((e) => e.title == 'Fixture-all-day'),
        isFalse);
    navigator.pop();
    await tester.pumpAndSettle();
    tester
        .widget<TableCalendar<Task>>(find.byType(TableCalendar<Task>))
        .onDaySelected!(day, day);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
        find.byKey(const ValueKey('calendar-events-line')), 160,
        scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    await binding.convertFlutterSurfaceToImage();
    for (final theme in [ThemeMode.light, ThemeMode.dark]) {
      await container.read(themeModeProvider.notifier).setMode(theme);
      await tester.pumpAndSettle();
      await binding.takeScreenshot('device-calendars-${theme.name}');
    }
    await tester.tap(find.byKey(const ValueKey('calendar-events-line')));
    await tester.pumpAndSettle();
    final sheet = find.byType(BottomSheet);
    expect(find.descendant(of: sheet, matching: find.byType(Checkbox)),
        findsNothing);
    await tester.scrollUntilVisible(find.text('Fixture-appointment'), 120,
        scrollable: find
            .descendant(of: sheet, matching: find.byType(Scrollable))
            .first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Fixture-appointment'));
    await tester.pumpAndSettle();
    expect(find.text('Open in calendar app'), findsOneWidget);
    debugPrint('CALENDAR_HOST_REVOKE_APP_OP');
    await _until(
        tester, () async => await bridge.status() != CalendarAccess.granted);
    await controller.refresh();
    await tester.pumpAndSettle();
    expect(find.text('Fixture-appointment'), findsNothing);
    expect(find.text('Open in calendar app'), findsNothing);
    expect(
        find.text(
            'This event is no longer available in the selected calendars.'),
        findsWidgets);
    await expectLater(
        bridge.events(selectedIds, day),
        throwsA(isA<PlatformException>()
            .having((e) => e.code, 'code', 'calendar_permission')));
    debugPrint('CALENDAR_HOST_RESTORE_APP_OP');
    await _until(
        tester, () async => await bridge.status() == CalendarAccess.granted);
    await controller.refresh();
    await tester.pumpAndSettle();
    expect(find.text('Open in calendar app'), findsOneWidget);
    expect((await controller.events(day)).items, hasLength(4));
    expect(
        jsonEncode(await sql
            .query('tasks', where: 'owner_key = ?', whereArgs: [owner])),
        before);
    expect(tester.takeException(), isNull);
    debugPrint(
        'CALENDAR_NATIVE_VALIDATED: denied/granted/revoked/restored, 5 provider instances -> 4 events, weekly expansion, isolated SQLite');
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  }, timeout: const Timeout(Duration(minutes: 10)));
}

Future<void> _until(
    WidgetTester tester, Future<bool> Function() condition) async {
  final watch = Stopwatch()..start();
  while (!await condition()) {
    if (watch.elapsed > const Duration(minutes: 3)) {
      fail('Calendar native operation timed out.');
    }
    await tester.pump(const Duration(milliseconds: 150));
  }
}

class _CalendarRepository extends TaskRepository {
  _CalendarRepository(this.database, this.owner) : super(database);
  final TaskDatabase database;
  final String owner;
  @override
  String get ownerKey => owner;
  @override
  Future<List<Task>> getAllTasks() => database.getTasks(ownerKey: owner);
}
