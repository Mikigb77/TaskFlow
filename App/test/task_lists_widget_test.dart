import 'package:agenda/main.dart';
import 'package:agenda/l10n/generated/app_localizations.dart';
import 'package:agenda/models/task_list_info.dart';
import 'package:agenda/providers/auth_provider.dart';
import 'package:agenda/providers/task_lists_provider.dart';
import 'package:agenda/providers/task_provider.dart';
import 'package:agenda/providers/theme_provider.dart';
import 'package:agenda/screens/task_lists_screen.dart';
import 'package:agenda/screens/list_sharing_screen.dart';
import 'package:agenda/theme/app_theme.dart';
import 'package:agenda/services/capture_store.dart';
import 'package:agenda/services/task_database.dart';
import 'package:agenda/services/task_list_store.dart';
import 'package:agenda/widgets/task_editor.dart';
import 'package:agenda/models/task.dart';
import 'package:agenda/providers/groups_provider.dart';
import 'package:agenda/widgets/task_assignment_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/design_fixtures.dart';

void main() {
  testWidgets(
      'create rename archive and restore a list; capture directly into it with labels',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = _Lists();
    final container = ProviderContainer(overrides: [
      authProvider.overrideWith(
          (ref) => SignedInFixtureAuth(ref.read(apiClientProvider))),
      pendingCapturesProvider.overrideWith((ref) async => []),
      apiClientProvider.overrideWith((ref) => OfflineApiClient()),
      taskRepositoryProvider.overrideWithValue(MemoryTasks()),
      taskProvider.overrideWith((ref) => DesignTaskNotifier()),
      themeStoreProvider.overrideWithValue(MemoryThemeStore()),
      taskListStoreProvider.overrideWithValue(store),
    ]);
    addTearDown(container.dispose);
    await tester.pumpWidget(
        UncontrolledProviderScope(container: container, child: const MyApp()));
    await tester.pumpAndSettle();
    tester.state<NavigatorState>(find.byType(Navigator)).pushNamed('/lists');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('new-list')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('list-name')), 'Shopping');
    await tester.tap(find.text('Save project'));
    await tester.pumpAndSettle();
    final id = store.lists.single.id;
    await tester.tap(find.byTooltip('Manage Shopping'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit project'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('list-name')), 'Weekend');
    await tester.tap(find.text('Save project'));
    await tester.pumpAndSettle();
    expect(store.lists.single.id, id);
    await tester.tap(find.text('Weekend'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('New task'));
    await tester.pumpAndSettle();
    expect(
        tester.widget<TaskEditor>(find.byType(TaskEditor)).initialListId, id);
    await tester.enterText(
        find.byKey(const ValueKey('task-title')), 'Buy coffee');
    await tester.tap(find.byKey(const ValueKey('task-more-details')));
    await tester.pumpAndSettle();
    final labels = find.byKey(const ValueKey('task-labels'));
    await tester.scrollUntilVisible(labels, 250,
        scrollable: find
            .descendant(
                of: find.byType(TaskEditor), matching: find.byType(Scrollable))
            .first);
    await tester.enterText(labels, 'Errands, errands, home');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Create Task'));
    await tester.pumpAndSettle();
    final task = container
        .read(taskProvider)
        .requireValue
        .singleWhere((task) => task.title == 'Buy coffee');
    expect(task.listId, id);
    expect(task.labels, ['errands', 'home']);
    expect(task.dueDate, isNull);
    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Manage Weekend'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Archive project'));
    await tester.pumpAndSettle();
    expect(store.lists.single.archived, isTrue);
    expect(
        container
            .read(taskProvider)
            .requireValue
            .any((task) => task.listId == id),
        isTrue);
    await tester.tap(find.byTooltip('Manage Weekend'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Restore project'));
    await tester.pumpAndSettle();
    expect(store.lists.single.archived, isFalse);
    for (final mode in [ThemeMode.light, ThemeMode.dark]) {
      await container.read(themeModeProvider.notifier).setMode(mode);
      tester.view.physicalSize = const Size(320, 568);
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets(
      'switching to Spanish preserves an open list name and stored color',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 568));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    for (final dark in [false, true]) {
      final store = _Lists();
      final container = ProviderContainer(overrides: [
        apiClientProvider.overrideWith((ref) => OfflineApiClient()),
        taskProvider.overrideWith((ref) => DesignTaskNotifier()),
        taskListStoreProvider.overrideWithValue(store),
        invitationsProvider.overrideWith((ref) async => []),
        themeStoreProvider.overrideWithValue(MemoryThemeStore()),
      ]);
      Widget app(String language) => UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
              locale: Locale(language),
              theme: dark ? AppTheme.dark : AppTheme.light,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(textScaler: const TextScaler.linear(2)),
                  child: child!),
              home: const TaskListsScreen()));
      await tester.pumpWidget(app('en'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('new-list')));
      await tester.pumpAndSettle();
      final name = find.byKey(const ValueKey('list-name'));
      await tester.enterText(name, 'My untranslated shopping list');
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      final blue = find.widgetWithText(ChoiceChip, 'Blue');
      await tester.ensureVisible(blue);
      await tester.pumpAndSettle();
      await tester.tap(blue);
      await tester.pumpAndSettle();
      await tester.pumpWidget(app('es'));
      await tester.pumpAndSettle();
      expect(find.text('My untranslated shopping list'), findsOneWidget);
      expect(
          tester
              .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Azul'))
              .selected,
          isTrue);
      await tester.tap(find.text('Guardar proyecto'));
      await tester.pumpAndSettle();
      expect(store.lists.single.name, 'My untranslated shopping list');
      expect(store.lists.single.color, 'blue');
      final id = store.lists.single.id;
      final menu = find.byTooltip('Gestionar My untranslated shopping list');
      await tester.scrollUntilVisible(menu, 180,
          scrollable: find.byType(Scrollable).first);
      await tester.pumpAndSettle();
      await tester.tap(menu);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Archivar proyecto'));
      await tester.pumpAndSettle();
      expect(store.lists.single.id, id);
      expect(store.lists.single.archived, isTrue);
      expect(store.lists.single.color, 'blue');
      final notice = tester.getRect(find.byType(SnackBar));
      expect(notice.top, greaterThanOrEqualTo(0));
      expect(notice.bottom, lessThanOrEqualTo(568));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      container.dispose();
    }
  });
  testWidgets(
      'UX-303: Projects search ignores accents (es/ca, 2x text, 320 dp, both themes)',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 568));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    for (final language in ['es', 'ca']) {
      for (final dark in [false, true]) {
        final l10n = lookupAppLocalizations(Locale(language));
        final store = _Lists()
          ..lists = [
            TaskListInfo(id: 'school', name: 'Col·legi'),
            TaskListInfo(id: 'doctor', name: 'Médico'),
            TaskListInfo(id: 'food', name: 'Compras'),
          ];
        final container = ProviderContainer(overrides: [
          apiClientProvider.overrideWith((ref) => OfflineApiClient()),
          taskProvider.overrideWith((ref) => DesignTaskNotifier()),
          taskListStoreProvider.overrideWithValue(store),
          invitationsProvider.overrideWith((ref) async => []),
          themeStoreProvider.overrideWithValue(MemoryThemeStore()),
        ]);
        await tester.pumpWidget(UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
                locale: Locale(language),
                theme: dark ? AppTheme.dark : AppTheme.light,
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                builder: (context, child) => MediaQuery(
                    data: MediaQuery.of(context)
                        .copyWith(textScaler: const TextScaler.linear(2)),
                    child: child!),
                home: const TaskListsScreen())));
        await tester.pumpAndSettle();
        final list = find.byType(Scrollable).first;
        final search = find.widgetWithText(TextField, l10n.projectsFind);
        Future<void> searchFor(String query) async {
          await tester.drag(list, const Offset(0, 3000));
          await tester.pumpAndSettle();
          await tester.scrollUntilVisible(search, 200, scrollable: list);
          await tester.enterText(search, query);
          await tester.pumpAndSettle();
        }

        final reason = '$language dark=$dark';
        await searchFor('collegi');
        await tester.scrollUntilVisible(
            find.widgetWithText(ListTile, 'Col·legi'), 180,
            scrollable: list);
        expect(find.widgetWithText(ListTile, 'Col·legi'), findsOneWidget,
            reason: reason);
        expect(find.widgetWithText(ListTile, 'Médico'), findsNothing);
        expect(find.widgetWithText(ListTile, 'Compras'), findsNothing);

        await searchFor('medico');
        await tester.scrollUntilVisible(
            find.widgetWithText(ListTile, 'Médico'), 180,
            scrollable: list);
        expect(find.widgetWithText(ListTile, 'Médico'), findsOneWidget,
            reason: reason);
        expect(find.widgetWithText(ListTile, 'Col·legi'), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        container.dispose();
      }
    }
  });

  testWidgets(
      'UX-308: with no projects the picker offers Nuevo proyecto, and saving a name puts the task in it',
      (tester) async {
    final es = lookupAppLocalizations(const Locale('es'));
    final store = _Lists();
    var task = Task(id: 1, title: 'Comprar pan', priority: 1);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        authProvider.overrideWith(
            (ref) => SignedInFixtureAuth(ref.read(apiClientProvider))),
        apiClientProvider.overrideWith((ref) => OfflineApiClient()),
        taskRepositoryProvider.overrideWithValue(MemoryTasks()),
        taskProvider.overrideWith((ref) => DesignTaskNotifier()),
        taskListStoreProvider.overrideWithValue(store),
        groupsProvider.overrideWith((ref) async => []),
      ],
      child: MaterialApp(
        locale: const Locale('es'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, change) => TaskAssignmentPicker(
              task: task,
              onChanged: (value) => change(() => task = value),
            ),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ActionChip, es.noList));
    await tester.pumpAndSettle();
    final sheet = find.byType(BottomSheet);
    expect(find.descendant(of: sheet, matching: find.text(es.list)),
        findsOneWidget);
    final create = find.descendant(
        of: sheet, matching: find.widgetWithText(ListTile, es.newList));
    expect(create, findsOneWidget);
    await tester.tap(create);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('list-name')), 'Compras');
    await tester.tap(find.text(es.saveList));
    await tester.pumpAndSettle();
    expect(store.lists.single.name, 'Compras');
    expect(task.listId, store.lists.single.id);
    expect(find.widgetWithText(ActionChip, 'Compras'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _Lists extends TaskListStore {
  _Lists() : super(TaskDatabase(), 'local');
  List<TaskListInfo> lists = [];
  @override
  Future<List<TaskListInfo>> all() async => lists;
  @override
  Future<void> create(TaskListInfo list) async {
    lists = [...lists, list];
  }

  @override
  Future<void> update(TaskListInfo list) async {
    lists =
        lists.map((current) => current.id == list.id ? list : current).toList();
  }
}
