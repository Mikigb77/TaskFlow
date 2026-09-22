import 'dart:convert';
import 'package:agenda/main.dart';
import 'package:agenda/models/task.dart';
import 'package:agenda/providers/auth_provider.dart';
import 'package:agenda/providers/regional_provider.dart';
import 'package:agenda/providers/task_provider.dart';
import 'package:agenda/providers/task_lists_provider.dart';
import 'package:agenda/providers/theme_provider.dart';
import 'package:agenda/repositories/task_repository.dart';
import 'package:agenda/screens/calendar_screen.dart';
import 'package:agenda/screens/regional_settings_screen.dart';
import 'package:agenda/services/capture_store.dart';
import 'package:agenda/services/notification_service.dart';
import 'package:agenda/services/task_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:table_calendar/table_calendar.dart';
import '../test/support/design_fixtures.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
      'Android regional controls persist without changing saved schedules',
      (tester) async {
    await TaskReminders.initialize();
    final originalOwner = await TaskReminders.engine.activeOwner();
    final database = TaskDatabase();
    final sql = await database.database;
    final priorPreferences = await sql
        .query('app_preferences', where: 'scope = ?', whereArgs: ['regional']);
    final owner = 'region-integration-${DateTime.now().microsecondsSinceEpoch}';
    final repository = _RegionalRepository(database, owner);
    final today = DateTime.now();
    await database.insertTasks([
      Task(
          title: 'Prepare the presentation',
          priority: 2,
          dueDate: DateTime(today.year, today.month, today.day, 18, 45),
          reminderMinutes: -1),
      Task(
          title: 'Pick up the parcel',
          priority: 1,
          dueDate: Task.day(today),
          hasTime: false,
          reminderMinutes: -1),
    ], ownerKey: owner);
    final captures = CaptureStore(database);
    final pending =
        await captures.create(owner, 'Europe/Madrid', text: 'Friday at five');
    final before = jsonEncode(
        await sql.query('tasks', where: 'owner_key = ?', whereArgs: [owner]));
    final store = RegionalPreferenceStore(database);
    await store.write(const RegionalPreferences(
        language: 'en', clock: ClockFormat.twentyFour, weekStart: 1));
    final container = ProviderContainer(overrides: [
      apiClientProvider.overrideWith((ref) {
        final api = OfflineApiClient();
        ref.onDispose(api.close);
        return api;
      }),
      taskRepositoryProvider.overrideWithValue(repository),
      themeStoreProvider.overrideWithValue(MemoryThemeStore()),
      regionalStoreProvider.overrideWithValue(store),
      taskListsProvider.overrideWith((ref) async => []),
      pendingCapturesProvider.overrideWith((ref) async => []),
    ]);
    addTearDown(() async {
      container.dispose();
      await sql.delete('tasks', where: 'owner_key = ?', whereArgs: [owner]);
      await sql.delete('captures', where: 'owner_key = ?', whereArgs: [owner]);
      await sql.delete('app_preferences',
          where: 'scope = ?', whereArgs: ['regional']);
      if (priorPreferences.isNotEmpty) {
        await sql.insert('app_preferences', priorPreferences.single);
      }
      await TaskReminders.activate(originalOwner ?? 'local');
    });
    await container.read(regionalProvider.notifier).ready;
    await container.read(taskProvider.notifier).loadTasks();
    await tester.pumpWidget(
        UncontrolledProviderScope(container: container, child: const MyApp()));
    await tester.pumpAndSettle();
    expect(find.text('Your calendar'), findsOneWidget);
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    navigator.pushNamed('/region');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('regional-language')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Español').last);
    await tester.pumpAndSettle();
    expect(find.text('Idioma y región'), findsOneWidget);
    await _choose(tester, 'regional-clock', 'Reloj de 12 horas');
    await _choose(tester, 'regional-week', 'Domingo');
    await binding.convertFlutterSurfaceToImage();
    for (final theme in [ThemeMode.light, ThemeMode.dark]) {
      await container.read(themeModeProvider.notifier).setMode(theme);
      await tester.pumpAndSettle();
      await binding.takeScreenshot('regional-settings-${theme.name}');
    }
    final restored = RegionalController(RegionalPreferenceStore(database));
    await restored.ready;
    expect(restored.state.language, 'es');
    expect(restored.state.clock, ClockFormat.twelve);
    expect(restored.state.weekStart, 0);
    restored.dispose();
    navigator.pop();
    await tester.pumpAndSettle();
    expect(find.text('Tu calendario'), findsOneWidget);
    expect(
        tester
            .widget<TableCalendar<Task>>(find.byType(TableCalendar<Task>))
            .startingDayOfWeek,
        StartingDayOfWeek.sunday);
    final calendarContext = tester.element(find.byType(CalendarScreen));
    expect(MaterialLocalizations.of(calendarContext).timeOfDayFormat(),
        TimeOfDayFormat.h_colon_mm_space_a);
    await binding.takeScreenshot('regional-calendar-dark');
    expect(
        jsonEncode(await sql
            .query('tasks', where: 'owner_key = ?', whereArgs: [owner])),
        before);
    expect((await captures.read(pending.id, owner))!.timezone, 'Europe/Madrid');
    final device = await CaptureTimezone.resolve(const RegionalPreferences());
    expect(device.fallback, isFalse);
    expect(CaptureTimezone.valid(device.identifier), isTrue);
    debugPrint('Android device timezone verified: ${device.identifier}');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

Future<void> _choose(WidgetTester tester, String key, String value) async {
  final finder = find.byKey(ValueKey(key));
  await tester.scrollUntilVisible(finder, 120,
      scrollable: find
          .descendant(
              of: find.byType(RegionalSettingsScreen),
              matching: find.byType(Scrollable))
          .first);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
  await tester.tap(find.text(value).last);
  await tester.pumpAndSettle();
}

class _RegionalRepository extends TaskRepository {
  _RegionalRepository(this.database, this.owner) : super(database);
  final TaskDatabase database;
  final String owner;
  @override
  String get ownerKey => owner;
  @override
  Future<List<Task>> getAllTasks() => database.getTasks(ownerKey: owner);
}
