import 'dart:convert';
import 'package:agenda/providers/no_retry.dart';
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
import 'package:agenda/widgets/language_selector.dart';
import 'package:agenda/screens/data_transfer_screen.dart';
import 'package:agenda/services/archive_files.dart';
import 'package:agenda/services/archive_store.dart';
import 'package:agenda/services/reminder_preferences.dart';
import 'package:agenda/services/capture_store.dart';
import 'package:agenda/services/notification_service.dart';
import 'package:agenda/services/task_database.dart';
import 'package:agenda/services/task_list_store.dart';
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
    final container = ProviderContainer(retry: noRetry, overrides: [
      authProvider.overrideWith((ref) => SignedInFixtureAuth(ref.read(apiClientProvider))),
      apiClientProvider.overrideWith((ref) {
        final api = OfflineApiClient();
        ref.onDispose(api.close);
        return api;
      }),
      taskRepositoryProvider.overrideWithValue(repository),
      themeStoreProvider.overrideWithValue(MemoryThemeStore()),
      regionalStoreProvider.overrideWithValue(store),
      taskListStoreProvider.overrideWithValue(TaskListStore(database, owner)),
      pendingCapturesProvider.overrideWith((ref) async => []),
      archiveFilesProvider.overrideWithValue(_RegionalArchiveFiles()),
    ]);
    addTearDown(() async {
      container.dispose();
      await sql.delete('tasks', where: 'owner_key = ?', whereArgs: [owner]);
      await sql.delete('captures', where: 'owner_key = ?', whereArgs: [owner]);
      await sql
          .delete('task_lists', where: 'owner_key = ?', whereArgs: [owner]);
      await sql.delete('archive_imports',
          where: 'owner_key = ?', whereArgs: [owner]);
      await sql.delete('app_preferences',
          where: 'scope = ?', whereArgs: ['reminders:$owner']);
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
    expect(find.text('Today’s agenda'), findsOneWidget);
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    navigator.pushNamed('/region');
    await tester.pumpAndSettle();
    // The language picker lives in Settings; its sheet works the same here.
    showLanguageSelector(tester.element(find.byType(RegionalSettingsScreen)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Español').last);
    await tester.pumpAndSettle();
    expect(find.text('Hora y región'), findsOneWidget);
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
    expect(find.text('Agenda de hoy'), findsOneWidget);
    expect(
        tester
            .widget<TableCalendar<Task>>(find.byType(TableCalendar<Task>))
            .startingDayOfWeek,
        StartingDayOfWeek.sunday);
    final calendarContext = tester.element(find.byType(CalendarScreen));
    expect(MaterialLocalizations.of(calendarContext).timeOfDayFormat(),
        TimeOfDayFormat.h_colon_mm_space_a);
    await binding.takeScreenshot('regional-calendar-dark');

    // Exercise translated list controls against real Android SQLite. Display
    // labels must never become persisted color keys or rewrite task schedules.
    navigator.pushNamed('/lists');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('new-list')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('list-name')),
        'Regional fixture · keep my words');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    final blue = find.widgetWithText(ChoiceChip, 'Azul');
    await tester.ensureVisible(blue);
    await tester.pumpAndSettle();
    await tester.tap(blue);
    await tester.pumpAndSettle();
    await binding.takeScreenshot('regional-list-editor-spanish');
    await tester.tap(find.text('Guardar lista'));
    await tester.pumpAndSettle();
    final savedList = (await TaskListStore(database, owner).all()).single;
    expect(savedList.name, 'Regional fixture · keep my words');
    expect(savedList.color, 'blue');
    final menu = find.byTooltip('Gestionar ${savedList.name}');
    await tester.scrollUntilVisible(menu, 120,
        scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    await tester.tap(menu);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Archivar lista'));
    await tester.pumpAndSettle();
    final archived = (await TaskListStore(database, owner).all()).single;
    expect(archived.id, savedList.id);
    expect(archived.color, 'blue');
    expect(archived.archived, isTrue);
    await binding.takeScreenshot('regional-list-archived-spanish');
    navigator.pop();
    await tester.pumpAndSettle();

    // Guest account UI only: no credentials, recovery emails or network calls.
    navigator.pushNamed('/account');
    await tester.pumpAndSettle();
    expect(find.text('Tu cuenta'), findsOneWidget);
    for (final theme in [ThemeMode.light, ThemeMode.dark]) {
      await container.read(themeModeProvider.notifier).setMode(theme);
      await tester.pumpAndSettle();
      await binding.takeScreenshot('regional-account-${theme.name}-spanish');
    }
    navigator.pop();
    await tester.pumpAndSettle();
    tester
        .state<ScaffoldMessengerState>(find.byType(ScaffoldMessenger))
        .hideCurrentSnackBar();

    // The translated reminder choices still store minutes, not display labels.
    navigator.pushNamed('/notifications');
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
        find.byType(DropdownButtonFormField<int>), 160,
        scrollable: find.byType(Scrollable).last);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<int>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('30 minutos antes').last);
    await tester.pumpAndSettle();
    expect(
        (await ReminderPreferenceStore(database).read(owner)).leadMinutes, 30);
    await binding.takeScreenshot('regional-reminder-settings-spanish');
    navigator.pop();
    await tester.pumpAndSettle();

    // The picker returns synthetic bytes; parsing, receipt checks, selection and
    // the import transaction use the production screen and real Android SQLite.
    navigator.pushNamed('/dataTransfer');
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
        find.text('Elegir archivo para importar'), 180,
        scrollable: find.byType(Scrollable).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Elegir archivo para importar'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
        find.text('Vista previa de importación'), 180,
        scrollable: find.byType(Scrollable).last);
    await tester.pumpAndSettle();
    await binding.takeScreenshot('regional-import-preview-spanish');
    final invalid =
        find.widgetWithText(CheckboxListTile, 'Invalid priority fixture');
    await tester.scrollUntilVisible(invalid, 180,
        scrollable: find.byType(Scrollable).last);
    await tester.pumpAndSettle();
    expect(tester.widget<CheckboxListTile>(invalid).onChanged, isNull);
    expect(find.textContaining('prioridad: valor no válido (1–3)'),
        findsOneWidget);
    await tester.scrollUntilVisible(
        find.byKey(const ValueKey('confirm-import')), 120,
        scrollable: find.byType(Scrollable).last);
    await tester.pumpAndSettle();
    await binding.takeScreenshot('regional-import-warning-spanish');
    await container
        .read(regionalProvider.notifier)
        .set(container.read(regionalProvider).withLanguage('en'));
    await tester.pumpAndSettle();
    expect(find.text('Import 1 selected item and lists'), findsOneWidget);
    await container
        .read(regionalProvider.notifier)
        .set(container.read(regionalProvider).withLanguage('es'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('confirm-import')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('confirm-import')));
    await tester.pumpAndSettle();
    final imported = (await database.getTasks(ownerKey: owner))
        .where((task) => task.title == _RegionalArchiveFiles.title)
        .single;
    expect(imported.dueDate, DateTime(2030, 10, 2));
    expect(imported.hasTime, isFalse);
    expect(imported.notes, 'Original note · keep these words');
    expect(
        (await ArchiveStore(database, owner).imported(_RegionalArchiveFiles.id))
            .length,
        1);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
        find.text('Elegir archivo para importar'), -200,
        scrollable: find.byType(Scrollable).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Elegir archivo para importar'));
    await tester.pumpAndSettle();
    final retained =
        find.widgetWithText(CheckboxListTile, _RegionalArchiveFiles.title);
    await tester.scrollUntilVisible(retained, 180,
        scrollable: find.byType(Scrollable).last);
    await tester.pumpAndSettle();
    expect(tester.widget<CheckboxListTile>(retained).onChanged, isNull);
    expect((await database.getTasks(ownerKey: owner)).length, 3);
    navigator.pop();
    await tester.pumpAndSettle();
    await sql.delete('tasks',
        where: 'id = ? AND owner_key = ?', whereArgs: [imported.id, owner]);
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

class _RegionalArchiveFiles extends ArchiveFiles {
  static const id = 'da83e122-42f6-47dd-bf46-ec77512cf6d8';
  static const title = 'Archive fixture · original words';
  @override
  Future<ArchiveFile?> choose() async => ArchiveFile(
      'regional-fixture.json',
      jsonEncode({
        'format': 'taskflow',
        'version': 2,
        'export_id': id,
        'lists': [],
        'tasks': [
          {
            'id': 'c1a79663-87c7-42d8-8f1a-b6c148f5b8e1',
            ...Task(
                    title: title,
                    priority: 1,
                    notes: 'Original note · keep these words',
                    dueDate: DateTime(2030, 10, 2),
                    hasTime: false,
                    reminderMinutes: -1)
                .toApi(),
            'attachments': ['fixture.pdf'],
          },
          {
            'id': 'c1a79663-87c7-42d8-8f1a-b6c148f5b8e2',
            ...Task(title: 'Invalid priority fixture', priority: 8).toApi(),
          },
        ],
      }));
}
