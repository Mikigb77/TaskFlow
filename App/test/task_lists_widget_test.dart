import 'dart:async';

import 'package:agenda/providers/no_retry.dart';
import 'package:agenda/main.dart';
import 'package:agenda/l10n/generated/app_localizations.dart';
import 'package:agenda/models/task_list_info.dart';
import 'package:agenda/providers/auth_provider.dart';
import 'package:agenda/providers/task_lists_provider.dart';
import 'package:agenda/providers/task_provider.dart';
import 'package:agenda/providers/theme_provider.dart';
import 'package:agenda/screens/task_lists_screen.dart';
import 'package:agenda/theme/app_theme.dart';
import 'package:agenda/services/capture_store.dart';
import 'package:agenda/services/task_database.dart';
import 'package:agenda/services/task_list_store.dart';
import 'package:agenda/widgets/task_editor.dart';
import 'package:agenda/models/task.dart';
import 'package:agenda/providers/groups_provider.dart';
import 'package:agenda/providers/invitations_provider.dart';
import 'package:agenda/widgets/task_assignment_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:agenda/providers/subscription_provider.dart';
import 'support/capture_fixtures.dart';
import 'support/design_fixtures.dart';
import 'support/hanging_sync.dart';
import 'support/no_counter.dart';
import 'support/search_clear.dart';
import 'package:agenda/services/api_client.dart';
import 'package:agenda/widgets/app_components.dart';
import 'package:agenda/widgets/task_list_picker.dart';
import 'package:agenda/screens/list_sharing_screen.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:agenda/models/task_group.dart';
import 'package:agenda/screens/home_screen.dart';
import 'package:agenda/screens/groups_screen.dart';

void main() {
  testWidgets(
      'create rename archive and restore a list; add a task directly into it with labels',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = _Lists();
    final captures = MemoryCaptures();
    final container = ProviderContainer(retry: noRetry, overrides: [
      // Without Pro, tasks are added with the form (2026-10-18 later).
      hasProProvider.overrideWithValue(false),
      billingLoadingProvider.overrideWithValue(false),
      captureStoreProvider.overrideWithValue(captures),
      authProvider.overrideWith(
          (ref) => SignedInFixtureAuth(ref.read(apiClientProvider))),
      pendingCapturesProvider.overrideWith((ref) async => []),
      apiClientProvider.overrideWith((ref) => OfflineApiClient()),
      taskRepositoryProvider.overrideWithValue(MemoryTasks()),
      taskProvider.overrideWith((ref) => DesignTaskNotifier()),
      themeStoreProvider.overrideWithValue(MemoryThemeStore()),
      taskListStoreProvider.overrideWithValue(store),
    ]);
    captures.tasks = container;
    addTearDown(container.dispose);
    await tester.pumpWidget(
        UncontrolledProviderScope(container: container, child: const MyApp()));
    await tester.pumpAndSettle();
    tester.state<NavigatorState>(find.byType(Navigator)).pushNamed('/lists');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('new-list')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('list-name')), 'Shopping');
    await tester.tap(find.text('Create project'));
    await tester.pumpAndSettle();
    final id = store.lists.single.id;
    // Saving opens the new project's page; back to Projects.
    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await tester.pumpAndSettle();
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
    // Added from the project's page, it goes to the project.
    await tester.tap(find.text('New task').hitTestable());
    await tester.pumpAndSettle();
    expect(
        tester.widget<TaskEditor>(find.byType(TaskEditor)).task.listId, id);
    await tester.enterText(
        find.byKey(const ValueKey('task-title')), 'Buy coffee');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('task-save')));
    await tester.pumpAndSettle();
    final added = container
        .read(taskProvider)
        .requireValue
        .singleWhere((task) => task.title == 'Buy coffee');
    expect(added.listId, id);
    // Labels are set in the form, which edits the saved task.
    tester
        .state<NavigatorState>(find.byType(Navigator))
        .push(MaterialPageRoute<void>(builder: (_) => TaskEditor(task: added)));
    await tester.pumpAndSettle();
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
    await tester.tap(find.widgetWithText(ElevatedButton, 'Save changes'));
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
      final container = ProviderContainer(retry: noRetry, overrides: [
        apiClientProvider.overrideWith((ref) => OfflineApiClient()),
        taskProvider.overrideWith((ref) => DesignTaskNotifier()),
        taskListStoreProvider.overrideWithValue(store),
        pendingInvitationsProvider.overrideWith((ref) async => []),
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
      await tester.tap(find.text('Create project'));
      await tester.pumpAndSettle();
      expect(store.lists.single.color, 'teal');
      // Saving opens the new project's page; back to Projects.
      tester.state<NavigatorState>(find.byType(Navigator)).pop();
      await tester.pumpAndSettle();
      // The colour is chosen in Edit project.
      final edit = find.byTooltip('Manage My untranslated shopping list');
      await tester.scrollUntilVisible(edit, 180,
          scrollable: find.byType(Scrollable).first);
      await tester.pumpAndSettle();
      await tester.tap(edit);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit project'));
      await tester.pumpAndSettle();
      final blue = find.widgetWithText(ChoiceChip, 'Blue');
      await tester.ensureVisible(blue);
      await tester.pumpAndSettle();
      await tester.tap(blue);
      await tester.pumpAndSettle();
      await tester.pumpWidget(app('es'));
      await tester.pumpAndSettle();
      expect(find.text('My untranslated shopping list'), findsWidgets);
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
            // The search box shows from 8 projects.
            for (final name in ['Casa', 'Trabajo', 'Gimnasio', 'Viajes', 'Lectura'])
              TaskListInfo(id: name, name: name),
          ];
        final container = ProviderContainer(retry: noRetry, overrides: [
          apiClientProvider.overrideWith((ref) => OfflineApiClient()),
          taskProvider.overrideWith((ref) => DesignTaskNotifier()),
          taskListStoreProvider.overrideWithValue(store),
          pendingInvitationsProvider.overrideWith((ref) async => []),
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
      retry: noRetry,
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
    await tester.tap(find.text(es.createList));
    await tester.pumpAndSettle();
    expect(store.lists.single.name, 'Compras');
    expect(task.listId, store.lists.single.id);
    expect(find.widgetWithText(ActionChip, 'Compras'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  // ---- P13 / P15: Projects' ⋮ menu ----

  final es = lookupAppLocalizations(const Locale('es'));
  final platform =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const timeoutChannel = MethodChannel('taskflow/accessibility');

  /// Projects in Spanish, signed in, with [lists] stored on the phone.
  Future<(_Lists, _CountingTasks, _DeleteApi)> openProjects(
      WidgetTester tester, List<TaskListInfo> lists,
      {List<Task>? tasks,
      List<TaskGroupInfo> groups = const [],
      List<Override> overrides = const []}) async {
    // Messages stay 10 s, long enough to reach Deshacer.
    platform.setMockMethodCallHandler(timeoutChannel, (_) async => 10000);
    addTearDown(() => platform.setMockMethodCallHandler(timeoutChannel, null));
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final store = _Lists()..lists = lists;
    final counting = _CountingTasks(tasks);
    final api = _DeleteApi();
    final container = ProviderContainer(retry: noRetry, overrides: [
      ...overrides,
      apiClientProvider.overrideWithValue(api),
      authProvider.overrideWith((ref) => SignedInFixtureAuth(api)),
      taskRepositoryProvider.overrideWithValue(MemoryTasks()),
      taskProvider.overrideWith((ref) => counting),
      taskListStoreProvider.overrideWithValue(store),
      pendingInvitationsProvider.overrideWith((ref) async => []),
      groupsProvider.overrideWith((ref) async => groups),
      themeStoreProvider.overrideWithValue(MemoryThemeStore()),
    ]);
    addTearDown(container.dispose);
    addTearDown(api.close);
    await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
            locale: const Locale('es'),
            theme: AppTheme.light,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const TaskListsScreen())));
    await tester.pumpAndSettle();
    return (store, counting, api);
  }

  Future<void> openMenu(WidgetTester tester, String name) async {
    final menu = find.byTooltip(es.manageItem(name));
    await tester.scrollUntilVisible(menu, 180,
        scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    await tester.tap(menu);
    await tester.pumpAndSettle();
  }

  testWidgets(
      'UX-305: the ⋮ item reads Compartir, even before the project’s first sync',
      (tester) async {
    await openProjects(tester, [
      TaskListInfo(id: 'casa', name: 'Casa', version: 0),
    ]);
    await openMenu(tester, 'Casa');
    expect(find.text(es.shareProject), findsOneWidget);
    expect(find.textContaining('gestionar personas'), findsNothing);
    await tester.tap(find.text(es.shareProject));
    await tester.pumpAndSettle();
    // Not synced yet: sharing says what to do.
    expect(find.byType(ListSharingScreen), findsOneWidget);
    expect(find.text(es.connectToShare), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'UX-301: archiving a project says «Casa» archivado: ya no aparece en el calendario ni te avisará. with Deshacer; Deshacer restores it and reloads the tasks so reminders are rescheduled',
      (tester) async {
    expect(es.projectArchivedNoReminders('Casa'),
        '«Casa» archivado: ya no aparece en el calendario ni te avisará.');
    final (store, tasks, _) = await openProjects(tester, [
      TaskListInfo(id: 'casa', name: 'Casa', version: 2),
    ]);
    await openMenu(tester, 'Casa');
    await tester.tap(find.text(es.archiveList));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(store.lists.single.archived, isTrue);
    final message = find.text(es.projectArchivedNoReminders('Casa'));
    expect(message, findsOneWidget);
    final undo = find.descendant(
        of: find.byType(SnackBar), matching: find.text(es.undo));
    expect(undo, findsOneWidget);
    final loadsBefore = tasks.loads;
    await tester.tap(undo);
    await tester.pumpAndSettle();
    expect(store.lists.single.archived, isFalse);
    expect(store.lists.single.name, 'Casa');
    expect(tasks.loads, greaterThan(loadsBefore),
        reason: 'loading the tasks again reschedules their reminders');
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'UX-317: an owner’s personal project has Eliminar proyecto in red in its ⋮; deleting it asks in red and says Proyecto eliminado',
      (tester) async {
    expect(es.deleteList, 'Eliminar proyecto');
    final (_, _, api) = await openProjects(tester, [
      TaskListInfo(id: 'casa', name: 'Casa', version: 2),
    ]);
    await openMenu(tester, 'Casa');
    final item = find.text(es.deleteList);
    expect(item, findsOneWidget);
    expect(find.text(es.deleteListForEveryone), findsNothing);
    final error = Theme.of(tester.element(item)).colorScheme.error;
    expect(tester.widget<Text>(item).style?.color, error);
    await tester.tap(item);
    await tester.pumpAndSettle();
    final confirm = find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(FilledButton, es.deleteList));
    expect(
        tester.widget<FilledButton>(confirm).style!.backgroundColor!.resolve({}),
        error);
    await tester.tap(confirm);
    await tester.pumpAndSettle();
    expect(api.calls.single, ('DELETE', 'lists/casa/'));
    expect(find.text(es.projectDeleted), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'UX-317: a shared project’s delete item says para todos; a project you don’t own has none',
      (tester) async {
    await openProjects(tester, [
      TaskListInfo(id: 'casa', name: 'Casa', version: 2, shared: true),
      TaskListInfo(
          id: 'obra', name: 'Obra', version: 2, shared: true, role: 'editor'),
    ]);
    await openMenu(tester, 'Casa');
    expect(find.text(es.deleteListForEveryone), findsOneWidget);
    expect(find.text(es.deleteList), findsNothing);
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
    await openMenu(tester, 'Obra');
    expect(find.text(es.deleteListForEveryone), findsNothing);
    expect(find.text(es.deleteList), findsNothing);
    expect(tester.takeException(), isNull);
  });

  // ---- P73 (UX-477, UX-479): delete and Share say what's true ----

  testWidgets(
      'UX-477: deleting the unshared Compras from Projects ⋮ asks ¿Eliminar «Compras» con todas sus tareas, notas y archivos? with no para todas; a shared project still warns everyone',
      (tester) async {
    expect(es.deleteListPrivateHelp('Compras'),
        '¿Eliminar «Compras» con todas sus tareas, notas y archivos? No se puede deshacer.');
    final (_, _, api) = await openProjects(tester, [
      TaskListInfo(id: 'compras', name: 'Compras', version: 2),
      TaskListInfo(id: 'casa', name: 'Casa', version: 2, shared: true),
    ]);
    await openMenu(tester, 'Compras');
    await tester.tap(find.text(es.deleteList));
    await tester.pumpAndSettle();
    final dialog = find.byType(AlertDialog);
    expect(
        find.descendant(
            of: dialog,
            matching: find.text(
                '¿Eliminar «Compras» con todas sus tareas, notas y archivos? No se puede deshacer.')),
        findsOneWidget);
    expect(find.textContaining('para todas'), findsNothing);
    await tester.tap(
        find.descendant(of: dialog, matching: find.text(es.cancel)));
    await tester.pumpAndSettle();
    expect(api.calls, isEmpty);

    await openMenu(tester, 'Casa');
    await tester.tap(find.text(es.deleteListForEveryone));
    await tester.pumpAndSettle();
    expect(
        find.descendant(
            of: find.byType(AlertDialog), matching: find.text(es.deleteListHelp)),
        findsOneWidget);
    expect(find.text(es.deleteListPrivateHelp('Casa')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'UX-479 / UX-1642: Projects ⋮ reads Compartir only for your own unshared project, and Miembros for a shared project, a group project you don’t administer and one you do',
      (tester) async {
    expect(es.people, 'Miembros');
    expect(es.shareProject, 'Compartir');
    await openProjects(tester, [
      TaskListInfo(
          id: 'obra', name: 'Obra', version: 2, shared: true, role: 'editor'),
      TaskListInfo(
          id: 'familia',
          name: 'Familia',
          version: 2,
          shared: true,
          role: 'editor',
          groupId: 'g-familia',
          groupName: 'Hogar'),
      TaskListInfo(id: 'casa', name: 'Casa', version: 2),
      TaskListInfo(
          id: 'equipo',
          name: 'Equipo',
          version: 2,
          shared: true,
          role: 'admin',
          groupId: 'g-trabajo',
          groupName: 'Trabajo'),
    ]);
    Finder inMenu(String text) => find.descendant(
        of: find.byType(PopupMenuItem<String>), matching: find.text(text));
    for (final (name, label, notLabel) in [
      ('Obra', es.people, es.shareProject),
      ('Familia', es.people, es.shareProject),
      ('Casa', es.shareProject, es.people),
      ('Equipo', es.people, es.shareProject),
    ]) {
      await openMenu(tester, name);
      expect(inMenu(label), findsOneWidget, reason: name);
      expect(inMenu(notLabel), findsNothing, reason: name);
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
    }
    expect(tester.takeException(), isNull);
  });

  // ---- Run 2026-10-19-app, round 2 · P212 (UX-1642): the ⋮ names the page
  // it opens ----

  testWidgets(
      'UX-1642: at 360×800 Proyectos ⋮ reads Miembros for a shared project you own and opens Miembros; Compartir for your unshared personal project; Miembros for a reader’s shared project',
      (tester) async {
    await openProjects(tester, [
      TaskListInfo(
          id: 'casa',
          name: 'Casa',
          version: 2,
          shared: true,
          ownerId: 1,
          people: const [
            ProjectMember(id: 1, name: 'María', role: 'owner'),
            ProjectMember(id: 2, name: 'Ana', role: 'editor'),
          ]),
      TaskListInfo(id: 'huerto', name: 'Huerto', version: 2),
      TaskListInfo(
          id: 'obra', name: 'Obra', version: 2, shared: true, role: 'viewer'),
    ], overrides: [
      listSharingProvider.overrideWith((ref, id) async => {
            'list': {'name': 'Casa', 'role': 'owner', 'version': 2},
            'members': [
              {'user_id': 2, 'user__email': 'ana@example.invalid', 'role': 'editor'}
            ],
            'invitations': [],
          }),
    ]);
    tester.view.physicalSize = const Size(360, 800);
    await tester.pumpAndSettle();
    Finder inMenu(String text) => find.descendant(
        of: find.byType(PopupMenuItem<String>), matching: find.text(text));
    for (final (name, label, notLabel) in [
      ('Huerto', es.shareProject, es.people),
      ('Obra', es.people, es.shareProject),
    ]) {
      await openMenu(tester, name);
      expect(inMenu(label), findsOneWidget, reason: name);
      expect(inMenu(notLabel), findsNothing, reason: name);
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
    }

    await openMenu(tester, 'Casa');
    expect(inMenu(es.shareProject), findsNothing);
    await tester.tap(inMenu(es.people));
    await tester.pumpAndSettle();
    final page = find.byType(ListSharingScreen);
    expect(page, findsOneWidget);
    expect(
        find.descendant(
            of: find.descendant(of: page, matching: find.byType(AppBar)),
            matching: find.text(es.people)),
        findsOneWidget,
        reason: 'the page it opens is called what the menu said');
    expect(tester.takeException(), isNull);
  });


  // ---- Round 1 (b9) · P26: Projects with less noise ----

  Finder pageFor(String id) =>
      find.byWidgetPredicate((w) => w is HomeScreen && w.listId == id);

  bool isCurrent(WidgetTester tester, Finder finder) =>
      ModalRoute.of(tester.element(finder))!.isCurrent;

  testWidgets(
      'UX-327: saving a new project from Projects lands on its page',
      (tester) async {
    final (store, _, _) = await openProjects(tester, []);
    await tester.tap(find.byKey(const ValueKey('new-list')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('list-name')), 'Huerto');
    await tester.tap(find.widgetWithText(FilledButton, es.createList));
    await tester.pumpAndSettle();
    final id = store.lists.single.id;
    expect(pageFor(id), findsOneWidget);
    expect(isCurrent(tester, pageFor(id)), isTrue);
    expect(
        find.descendant(of: find.byType(AppBar), matching: find.text('Huerto')),
        findsOneWidget);
    // Its empty state says what to do next.
    expect(find.text(es.listEmpty), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'UX-327: saving a new project from a group page lands on its page, not on Projects filtered to the group',
      (tester) async {
    const group = TaskGroupInfo(
        id: 'master', name: 'Máster', ownerId: 1, version: 1, role: 'owner');
    final (store, _, _) = await openProjects(tester, [], groups: [
      group
    ], overrides: [
      groupDetailsProvider('master').overrideWith((ref) async => {
            'group': {
              'id': 'master',
              'name': 'Máster',
              'owner_id': 1,
              'version': 1,
              'role': 'owner',
              'project_count': 0,
              'people': [
                {'user_id': 1, 'name': 'Yo', 'role': 'owner'},
              ],
            },
            'invitations': [],
          }),
    ]);
    tester.state<NavigatorState>(find.byType(Navigator)).push(
        MaterialPageRoute<void>(
            builder: (_) => const GroupScreen(groupId: 'master')));
    await tester.pumpAndSettle();
    final add = find.widgetWithText(TextButton, es.newList);
    await tester.scrollUntilVisible(add, 120,
        scrollable: find.byType(Scrollable).last);
    await tester.tap(add);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('list-name')), 'Tesis');
    await tester.tap(find.widgetWithText(FilledButton, es.createList));
    await tester.pumpAndSettle();
    final saved = store.lists.single;
    expect(saved.groupId, 'master');
    expect(pageFor(saved.id), findsOneWidget);
    expect(isCurrent(tester, pageFor(saved.id)), isTrue);
    expect(
        find.descendant(of: find.byType(AppBar), matching: find.text('Tesis')),
        findsOneWidget);
    // Back goes to the group page.
    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await tester.pumpAndSettle();
    expect(isCurrent(tester, find.byType(GroupScreen)), isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'UX-329: a new account’s Projects screen has no headline, help line, refresh button or search box: Nuevo proyecto is its only button, and Grupos waits until something is shared (P286)',
      (tester) async {
    await openProjects(tester, []);
    final screen = find.byType(TaskListsScreen);
    Finder inScreen(Finder finder) =>
        find.descendant(of: screen, matching: finder);
    expect(inScreen(find.text(es.lists)), findsOneWidget,
        reason: 'only the app bar title');
    expect(
        find.descendant(of: find.byType(AppBar), matching: find.text(es.lists)),
        findsOneWidget);
    expect(inScreen(find.byType(TextField)), findsNothing);
    expect(inScreen(find.byIcon(Icons.refresh)), findsNothing);
    expect(inScreen(find.byIcon(Icons.refresh_rounded)), findsNothing);
    expect(inScreen(find.textContaining('Actualizar')), findsNothing);
    expect(inScreen(find.textContaining('Crea proyectos personales')),
        findsNothing);
    // The empty state says it once.
    expect(inScreen(find.text(es.listsEmptyTitle)), findsOneWidget);
    expect(inScreen(find.text(es.listsEmptyHelp)), findsOneWidget);
    final buttons = tester
        .widgetList(inScreen(find.byWidgetPredicate(
            (w) => w is ButtonStyleButton || w is IconButton)))
        .toList();
    expect(buttons, hasLength(1), reason: '$buttons');
    expect(inScreen(find.widgetWithText(TextButton, es.groups)), findsNothing);
    expect(find.byKey(const ValueKey('new-list')), findsOneWidget);
    expect(inScreen(find.byType(LinearProgressIndicator)), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'UX-329: the search box shows from 8 projects, not with 7',
      (tester) async {
    await openProjects(tester, [
      for (var i = 1; i <= 7; i++) TaskListInfo(id: 'p$i', name: 'Proyecto $i'),
    ]);
    expect(find.widgetWithText(TextField, es.projectsFind), findsNothing);
    await tester.pumpWidget(const SizedBox());
    await openProjects(tester, [
      for (var i = 1; i <= 8; i++) TaskListInfo(id: 'p$i', name: 'Proyecto $i'),
    ]);
    expect(find.widgetWithText(TextField, es.projectsFind), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'UX-430: with 8 projects, typing zzz in the Proyectos search shows No se han encontrado proyectos',
      (tester) async {
    expect(es.projectsNoneFound, 'No se han encontrado proyectos');
    await openProjects(tester, [
      for (final name in [
        'Casa',
        'Trabajo',
        'Compras',
        'Gimnasio',
        'Viajes',
        'Lectura',
        'Jardín',
        'Coche',
      ])
        TaskListInfo(id: name, name: name),
    ]);
    final search = find.widgetWithText(TextField, es.projectsFind);
    await tester.enterText(search, 'zzz');
    await tester.pumpAndSettle();
    expect(find.text(es.projectsNoneFound), findsOneWidget);
    expect(find.text('Casa'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'UX-332: the create dialog has no colour chips and new projects are teal; Editar proyecto still has the five colours',
      (tester) async {
    final (store, _, _) = await openProjects(tester, [
      TaskListInfo(id: 'casa', name: 'Casa', color: 'blue', version: 2),
    ]);
    await tester.tap(find.byKey(const ValueKey('new-list')));
    await tester.pumpAndSettle();
    final dialog = find.byType(AlertDialog);
    expect(find.descendant(of: dialog, matching: find.byType(ChoiceChip)),
        findsNothing);
    await tester.tap(find.widgetWithText(TextButton, es.cancel));
    await tester.pumpAndSettle();

    await openMenu(tester, 'Casa');
    await tester.tap(find.text(es.editList));
    await tester.pumpAndSettle();
    expect(find.descendant(of: dialog, matching: find.byType(ChoiceChip)),
        findsNWidgets(5));
    await tester.tap(find.widgetWithText(TextButton, es.cancel));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('new-list')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('list-name')), 'Huerto');
    await tester.tap(find.widgetWithText(FilledButton, es.createList));
    await tester.pumpAndSettle();
    expect(store.lists.singleWhere((l) => l.name == 'Huerto').color, 'teal');
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'UX-334: a pinned row is announced Fijado with a pin icon, not ★; a directly shared row reads Compartido · Editor; counts exclude completed items',
      (tester) async {
    expect(es.projectPinned, 'Fijado');
    expect(es.projectSharedRole(es.roleEditor), 'Compartido · Editor');
    final handle = tester.ensureSemantics();
    await openProjects(tester, [
      TaskListInfo(id: 'casa', name: 'Casa', version: 2, pinned: true),
      TaskListInfo(
          id: 'obra', name: 'Obra', version: 2, shared: true, role: 'editor'),
    ], tasks: [
      Task(id: 1, title: 'Barrer', priority: 1, listId: 'casa'),
      Task(id: 2, title: 'Fregar', priority: 1, listId: 'casa'),
      Task(
          id: 3,
          title: 'Tender',
          priority: 1,
          listId: 'casa',
          isCompleted: true),
    ]);
    final casa = find.widgetWithText(ListTile, 'Casa');
    expect(find.textContaining('★'), findsNothing);
    expect(
        find.descendant(
            of: casa, matching: find.byIcon(Icons.push_pin_outlined)),
        findsOneWidget);
    expect(tester.getSemantics(casa).label, contains(es.projectPinned));
    expect(find.descendant(of: casa, matching: find.text(es.listItemCount(2))),
        findsOneWidget,
        reason: 'two open tasks; the completed one is not counted');
    final obra = find.widgetWithText(ListTile, 'Obra');
    expect(
        find.descendant(
            of: obra, matching: find.text('Compartido · Editor')),
        findsOneWidget);
    expect(find.textContaining(es.projectsShared), findsNothing);
    handle.dispose();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'UX-329: at 320 dp and 2× text in Spanish, Proyectos and Grupos each stay on one line, unbroken, with no overflow',
      (tester) async {
    // In a group, so Grupos shows (P286).
    await openProjects(tester, [TaskListInfo(id: 'casa', name: 'Casa')],
        groups: const [
          TaskGroupInfo(
              id: 'master', name: 'Máster', ownerId: 1, version: 1, role: 'owner'),
        ]);
    tester.view.physicalSize = const Size(320, 568);
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull, reason: 'no overflow');
    for (final word in [es.lists, es.groups]) {
      final text = find.text(word).first;
      final paragraph = tester.renderObject<RenderParagraph>(text);
      final line = paragraph.getFullHeightForCaret(const TextPosition(offset: 0));
      expect(paragraph.size.height, lessThan(line * 1.5),
          reason: '$word fits on one line');
      final rect = tester.getRect(text);
      expect(rect.left, greaterThanOrEqualTo(0), reason: word);
      expect(rect.right, lessThanOrEqualTo(320), reason: word);
    }
  });
  testWidgets(
      'UX-338: choosing a group under ¿Dónde va este proyecto? says Todos en Máster lo verán.',
      (tester) async {
    expect(es.projectGroupSees('Máster'), 'Todos en Máster lo verán.');
    await openProjects(tester, [], groups: const [
      TaskGroupInfo(
          id: 'master', name: 'Máster', ownerId: 1, version: 1, role: 'owner'),
    ]);
    await tester.tap(find.byKey(const ValueKey('new-list')));
    await tester.pumpAndSettle();
    expect(find.text('Todos en Máster lo verán.'), findsNothing);
    await tester.tap(find.text(es.projectsPersonal));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Máster').last);
    await tester.pumpAndSettle();
    expect(
        find.descendant(
            of: find.byType(AlertDialog),
            matching: find.text('Todos en Máster lo verán.')),
        findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  // ---- Run 2026-10-19-app, round 1 · P183 (UX-1510) and P184 (UX-1516,
  // UX-1522) ----

  /// Projects in Spanish with [lists], [tasks] (the samples by default) and
  /// [api]; invitations come from [invitations].
  Future<_Lists> openProjectsWith(
    WidgetTester tester,
    List<TaskListInfo> lists, {
    TaskNotifier Function()? tasks,
    ApiClient? api,
    Future<List<PendingInvitation>> Function()? invitations,
  }) async {
    platform.setMockMethodCallHandler(timeoutChannel, (_) async => 10000);
    addTearDown(() => platform.setMockMethodCallHandler(timeoutChannel, null));
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final store = _Lists()..lists = lists;
    final client = api ?? _DeleteApi();
    final container = ProviderContainer(retry: noRetry, overrides: [
      apiClientProvider.overrideWithValue(client),
      authProvider.overrideWith((ref) => SignedInFixtureAuth(client)),
      taskRepositoryProvider.overrideWithValue(MemoryTasks()),
      taskProvider.overrideWith((ref) => tasks?.call() ?? DesignTaskNotifier()),
      taskListStoreProvider.overrideWithValue(store),
      pendingInvitationsProvider
          .overrideWith((ref) => invitations?.call() ?? Future.value([])),
      groupsProvider.overrideWith((ref) async => []),
      themeStoreProvider.overrideWithValue(MemoryThemeStore()),
    ]);
    addTearDown(container.dispose);
    addTearDown(client.close);
    await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
            locale: const Locale('es'),
            theme: AppTheme.light,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const TaskListsScreen())));
    await tester.pumpAndSettle();
    return store;
  }

  testWidgets(
      'UX-1510: with a sync that never completes, deleting Casa shows a spinner on its row while the DELETE runs, then Proyecto eliminado and the row goes once the server answers',
      (tester) async {
    final tasks = HangingSyncTasks();
    final api = _HeldDeleteApi();
    await openProjectsWith(tester, [
      TaskListInfo(id: 'casa', name: 'Casa', version: 2),
      TaskListInfo(id: 'obra', name: 'Obra', version: 2),
    ], tasks: () => tasks, api: api);
    await openMenu(tester, 'Casa');
    await tester.tap(find.text(es.deleteList));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(FilledButton, es.deleteList)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(api.deletes, ['lists/casa/']);
    final casa = find.widgetWithText(ListTile, 'Casa');
    expect(casa, findsOneWidget, reason: 'still there while the DELETE runs');
    expect(
        find.descendant(
            of: casa, matching: find.byType(CircularProgressIndicator)),
        findsOneWidget,
        reason: 'its row shows a spinner');
    expect(find.byTooltip(es.manageItem('Casa')), findsNothing);
    expect(
        find.descendant(
            of: find.widgetWithText(ListTile, 'Obra'),
            matching: find.byType(CircularProgressIndicator)),
        findsNothing);
    expect(find.text(es.projectDeleted), findsNothing);

    // The server answers; the sync it starts never completes.
    api.answer.complete({});
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text(es.projectDeleted), findsOneWidget);
    expect(find.widgetWithText(ListTile, 'Casa'), findsNothing);
    expect(find.widgetWithText(ListTile, 'Obra'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(tasks.syncs, greaterThan(0), reason: 'the sync runs behind');
    expect(tester.takeException(), isNull);
  });

  testWidgets('UX-1522: Grupos comes after the last project', (tester) async {
    // Obra is shared, so Grupos shows (P286).
    await openProjectsWith(tester, [
      TaskListInfo(id: 'casa', name: 'Casa', version: 2),
      TaskListInfo(id: 'obra', name: 'Obra', version: 2, shared: true),
      TaskListInfo(id: 'viaje', name: 'Viaje', version: 2),
    ]);
    final groups = find.widgetWithText(TextButton, es.groups);
    await tester.scrollUntilVisible(groups, 120,
        scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    for (final name in ['Casa', 'Obra', 'Viaje']) {
      expect(tester.getRect(groups).top,
          greaterThan(tester.getRect(find.widgetWithText(ListTile, name)).bottom),
          reason: 'Grupos below $name');
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'UX-1522: the create dialog’s button reads Crear proyecto; the edit dialog’s Guardar proyecto',
      (tester) async {
    final en = lookupAppLocalizations(const Locale('en'));
    final ca = lookupAppLocalizations(const Locale('ca'));
    expect([en.createList, es.createList, ca.createList],
        ['Create project', 'Crear proyecto', 'Crea el projecte']);
    expect(es.saveList, 'Guardar proyecto');
    await openProjectsWith(
        tester, [TaskListInfo(id: 'casa', name: 'Casa', version: 2)]);
    await tester.tap(find.byKey(const ValueKey('new-list')));
    await tester.pumpAndSettle();
    final dialog = find.byType(AlertDialog);
    expect(
        find.descendant(
            of: dialog,
            matching: find.widgetWithText(FilledButton, es.createList)),
        findsOneWidget);
    expect(find.descendant(of: dialog, matching: find.text(es.saveList)),
        findsNothing);
    await tester.tap(find.widgetWithText(TextButton, es.cancel));
    await tester.pumpAndSettle();
    await openMenu(tester, 'Casa');
    await tester.tap(find.text(es.editList));
    await tester.pumpAndSettle();
    expect(
        find.descendant(
            of: dialog, matching: find.widgetWithText(FilledButton, es.saveList)),
        findsOneWidget);
    expect(find.descendant(of: dialog, matching: find.text(es.createList)),
        findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'UX-1522: offline, with invitations failing to load, neither Proyectos nor Grupos shows Reintentar invitaciones',
      (tester) async {
    // Shared, so Grupos shows (P286).
    await openProjectsWith(tester,
        [TaskListInfo(id: 'casa', name: 'Casa', version: 2, shared: true)],
        invitations: () async => throw ApiException(0, 'offline'));
    expect(find.textContaining('Reintentar invitaciones'), findsNothing);
    expect(find.textContaining('invitaciones'), findsNothing);
    expect(find.widgetWithText(ListTile, 'Casa'), findsOneWidget);
    final groups = find.widgetWithText(TextButton, es.groups);
    await tester.scrollUntilVisible(groups, 120,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(groups);
    await tester.pumpAndSettle();
    expect(find.byType(GroupsScreen), findsOneWidget);
    expect(find.textContaining('Reintentar invitaciones'), findsNothing);
    expect(find.textContaining('invitaciones'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'UX-1522: an owner’s shared row with 5 open items reads Compartido · 5 tareas y notas; a member’s row keeps their role',
      (tester) async {
    expect(es.projectSharedRole(es.listItemCount(5)),
        'Compartido · 5 tareas y notas');
    await openProjectsWith(tester, [
      TaskListInfo(id: 'casa', name: 'Casa', version: 2, shared: true),
      TaskListInfo(
          id: 'obra', name: 'Obra', version: 2, shared: true, role: 'editor'),
    ], tasks: () => _CountingTasks([
          for (var i = 1; i <= 5; i++)
            Task(id: i, title: 'Tarea $i', priority: 1, listId: 'casa'),
          Task(
              id: 6,
              title: 'Hecha',
              priority: 1,
              listId: 'casa',
              isCompleted: true),
          Task(id: 7, title: 'Pared', priority: 1, listId: 'obra'),
        ]));
    final casa = find.widgetWithText(ListTile, 'Casa');
    expect(
        find.descendant(
            of: casa, matching: find.text('Compartido · 5 tareas y notas')),
        findsOneWidget);
    expect(find.descendant(of: casa, matching: find.textContaining('Propietario')),
        findsNothing);
    expect(
        find.descendant(
            of: find.widgetWithText(ListTile, 'Obra'),
            matching: find.text('Compartido · Editor')),
        findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('UX-1522: Proyectos’ empty state shows a folder', (tester) async {
    await openProjectsWith(tester, []);
    final empty = find.byType(EmptyState);
    expect(empty, findsOneWidget);
    expect(find.descendant(of: empty, matching: find.byIcon(Icons.folder_outlined)),
        findsOneWidget);
    expect(
        find.descendant(
            of: empty, matching: find.byIcon(Icons.event_available_outlined)),
        findsNothing);
    expect(tester.takeException(), isNull);
  });

  /// The project chip of a task in no project, in Spanish, with [store]'s
  /// projects.
  Future<Task Function()> openPicker(WidgetTester tester, _Lists store) async {
    var task = Task(id: 1, title: 'Comprar billetes', priority: 1);
    await tester.pumpWidget(ProviderScope(
      retry: noRetry,
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
    return () => task;
  }

  testWidgets(
      'UX-1516: with 2 editable projects the project sheet lists Nuevo proyecto last; creating Viaje there moves the task into it',
      (tester) async {
    final store = _Lists()
      ..lists = [
        TaskListInfo(id: 'casa', name: 'Casa', version: 2),
        TaskListInfo(id: 'obra', name: 'Obra', version: 2),
      ];
    final task = await openPicker(tester, store);
    await tester.tap(find.widgetWithText(ActionChip, es.noList));
    await tester.pumpAndSettle();
    final sheet = find.byType(BottomSheet);
    final rows = tester
        .widgetList<ListTile>(
            find.descendant(of: sheet, matching: find.byType(ListTile)))
        .map((tile) => (tile.title as Text).data)
        .toList();
    expect(rows.last, es.newList, reason: '$rows');
    expect(rows, containsAllInOrder(['Casa', 'Obra', es.newList]));
    expect(rows.where((row) => row == es.newList), hasLength(1));
    await tester.tap(
        find.descendant(of: sheet, matching: find.widgetWithText(ListTile, es.newList)));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('list-name')), 'Viaje');
    await tester.tap(find.widgetWithText(FilledButton, es.createList));
    await tester.pumpAndSettle();
    final viaje = store.lists.singleWhere((list) => list.name == 'Viaje');
    expect(task().listId, viaje.id);
    expect(find.widgetWithText(ActionChip, 'Viaje'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'UX-1516: with a dictated new project, the project sheet keeps Nuevo proyecto hidden',
      (tester) async {
    final store = _Lists()
      ..lists = [
        TaskListInfo(id: 'casa', name: 'Casa', version: 2),
        TaskListInfo(id: 'obra', name: 'Obra', version: 2),
      ];
    await tester.pumpWidget(ProviderScope(
      retry: noRetry,
      overrides: [
        apiClientProvider.overrideWith((ref) => OfflineApiClient()),
        taskRepositoryProvider.overrideWithValue(MemoryTasks()),
        taskProvider.overrideWith((ref) => DesignTaskNotifier()),
        taskListStoreProvider.overrideWithValue(store),
      ],
      child: MaterialApp(
        locale: const Locale('es'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Scaffold(
          body: Consumer(
            builder: (context, ref, _) {
              ref.watch(taskListsProvider);
              return TextButton(
                onPressed: () =>
                    chooseTaskList(context, ref, newName: 'Excursión'),
                child: const Text('Proyecto'),
              );
            },
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Proyecto'));
    await tester.pumpAndSettle();
    final sheet = find.byType(BottomSheet);
    expect(
        find.descendant(
            of: sheet, matching: find.text(es.commandNewProject('Excursión'))),
        findsOneWidget);
    expect(find.descendant(of: sheet, matching: find.text('Casa')),
        findsOneWidget);
    expect(find.descendant(of: sheet, matching: find.text(es.newList)),
        findsNothing);
    expect(tester.takeException(), isNull);
  });

  group('P285 · project name dialogs show no character counter', () {
    /// A Spanish page whose button runs [open] with the app's providers.
    Future<void> pumpOpener(WidgetTester tester,
        Future<void> Function(BuildContext context, WidgetRef ref) open) async {
      final store = _Lists()
        ..lists = [TaskListInfo(id: 'casa', name: 'Casa', version: 2)];
      await tester.pumpWidget(ProviderScope(
        retry: noRetry,
        overrides: [
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
            body: Consumer(
              builder: (context, ref, _) {
                ref.watch(taskListsProvider);
                ref.watch(groupsProvider);
                return TextButton(
                  onPressed: () => open(context, ref),
                  child: const Text('Abrir'),
                );
              },
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Abrir'));
      await tester.pumpAndSettle();
    }

    testWidgets(
        'UX-2505: the new project dialog shows no 0/80 counter and still stops at 80',
        (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpOpener(tester, (context, ref) => editTaskList(context, ref));
      expect(find.text(es.newList), findsWidgets);
      await expectNoCounter(tester, 80);
      expect(tester.takeException(), isNull);
      semantics.dispose();
    });

    testWidgets(
        'UX-2505: editing a project’s name shows no counter and still stops at 80',
        (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpOpener(
          tester,
          (context, ref) => editTaskList(context, ref,
              list: TaskListInfo(id: 'casa', name: 'Casa', version: 2)));
      expect(find.text(es.editList), findsOneWidget);
      // «Casa» would have read «4/80».
      await expectNoCounter(tester, 80);
      expect(tester.takeException(), isNull);
      semantics.dispose();
    });

    testWidgets(
        'UX-2505: correcting a dictated project’s name shows no counter and still stops at 80',
        (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpOpener(
          tester,
          (context, ref) => chooseTaskList(context, ref,
              newName: 'Excursión', onRename: (_) {}));
      await tester.tap(find.text(es.commandNewProject('Excursión')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('new-project-name')), findsOneWidget);
      await expectNoCounter(tester, 80);
      expect(tester.takeException(), isNull);
      semantics.dispose();
    });
  });

  group('P286 · a project’s page manages it; Grupos once it matters', () {
    const me = ProjectMember(id: 1, name: 'Yo', role: 'owner');
    const ana = ProjectMember(id: 2, name: 'Ana', role: 'editor');

    /// The texts of the ⋮ menu that's open, top to bottom.
    List<String> menuTexts(WidgetTester tester) => tester
        .widgetList<PopupMenuItem<String>>(find.byType(PopupMenuItem<String>))
        .map((item) => (item.child! as Text).data!)
        .toList();

    /// What Proyectos ⋮ offers for [name], then that project's page open.
    Future<List<String>> projectsMenuThenPage(
        WidgetTester tester, String name) async {
      await openMenu(tester, name);
      final offered = menuTexts(tester);
      // Closes the menu without choosing.
      await tester.tapAt(const Offset(8, 420));
      await tester.pumpAndSettle();
      expect(find.byType(PopupMenuItem<String>), findsNothing);
      await tester.tap(find.widgetWithText(ListTile, name));
      await tester.pumpAndSettle();
      return offered;
    }

    Finder pageOf(String id) => find.byWidgetPredicate(
        (w) => w is HomeScreen && w.listId == id,
        skipOffstage: false);

    Finder inAppBar(Finder finder) => find.descendant(
        of: find.descendant(of: pageOf('casa'), matching: find.byType(AppBar)),
        matching: finder);

    testWidgets(
        'UX-2503: «Casa»’s page (owner) has a ⋮ after ✓, «Gestionar Casa», listing what Proyectos ⋮ offers for Casa, in its order (its own Compartir button and pinning aside)',
        (tester) async {
      await openProjects(
          tester, [TaskListInfo(id: 'casa', name: 'Casa', version: 2)]);
      final offered = await projectsMenuThenPage(tester, 'Casa');
      expect(offered, [
        es.pinProject,
        es.editList,
        es.archiveList,
        es.shareProject,
        es.deleteList,
      ]);
      expect(pageOf('casa'), findsOneWidget);
      final done = inAppBar(find.byTooltip(es.completedTasks));
      final manage = inAppBar(find.byTooltip(es.manageItem('Casa')));
      expect(done, findsOneWidget);
      expect(manage, findsOneWidget);
      expect(tester.getCenter(manage).dx, greaterThan(tester.getCenter(done).dx),
          reason: '⋮ comes after ✓');
      expect(tester.getSize(manage).width, greaterThanOrEqualTo(48));
      await tester.tap(manage);
      await tester.pumpAndSettle();
      // The same items, in the same order; «Compartir» is the page's own
      // button under the app bar, so ⋮ doesn't repeat it, and pinning only
      // reorders Proyectos, so the page doesn't offer it (P303, UX-2628).
      expect(menuTexts(tester), [
        for (final item in offered)
          if (item != es.shareProject && item != es.pinProject) item
      ]);
      expect(find.widgetWithText(TextButton, es.shareProject), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    for (final (role, expected) in [
      ('owner', [
        es.pinProject,
        es.projectNotifications,
        es.editList,
        es.archiveList,
        es.deleteListForEveryone,
      ]),
      ('editor', [es.pinProject, es.projectNotifications]),
      ('viewer', [es.pinProject, es.projectNotifications]),
    ]) {
      testWidgets(
          'UX-2503: a shared project’s page ($role) lists in its ⋮ what Proyectos ⋮ offers that role, in its order (Miembros is the page’s own button; pinning stays on Proyectos)',
          (tester) async {
        await openProjects(tester, [
          TaskListInfo(
              id: 'casa',
              name: 'Casa',
              version: 2,
              shared: true,
              role: role,
              ownerId: role == 'owner' ? 1 : 2,
              people: const [me, ana]),
        ]);
        final offered = await projectsMenuThenPage(tester, 'Casa');
        // On Proyectos, Miembros comes before the owner's delete.
        final members = role == 'owner' ? 4 : 2;
        expect(offered, [
          ...expected.take(members),
          es.people,
          ...expected.skip(members),
        ]);
        await tester.tap(inAppBar(find.byTooltip(es.manageItem('Casa'))));
        await tester.pumpAndSettle();
        // Pinning only reorders Proyectos: the page doesn't offer it
        // (P303, UX-2628).
        expect(menuTexts(tester),
            [for (final item in expected) if (item != es.pinProject) item]);
        expect(menuTexts(tester), [
          for (final item in offered)
            if (item != es.people && item != es.pinProject) item
        ]);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets(
        'UX-2503: renaming «Casa» to «Casaa» from its page takes 3 taps (⋮, Editar proyecto, Guardar proyecto) plus typing, and the page says Casaa',
        (tester) async {
      final (store, _, _) = await openProjects(
          tester, [TaskListInfo(id: 'casa', name: 'Casa', version: 2)]);
      await tester.tap(find.widgetWithText(ListTile, 'Casa'));
      await tester.pumpAndSettle();
      var taps = 0;
      Future<void> tap(Finder finder) async {
        expect(finder, findsOneWidget);
        await tester.tap(finder);
        await tester.pumpAndSettle();
        taps++;
      }

      await tap(inAppBar(find.byTooltip(es.manageItem('Casa'))));
      await tap(find.text(es.editList));
      await tester.enterText(find.byKey(const ValueKey('list-name')), 'Casaa');
      await tap(find.widgetWithText(FilledButton, es.saveList));
      expect(taps, 3);
      expect(find.byType(AlertDialog), findsNothing);
      expect(store.lists.single.name, 'Casaa');
      expect(pageOf('casa'), findsOneWidget);
      expect(
          ModalRoute.of(tester.element(pageOf('casa')))!.isCurrent, isTrue,
          reason: 'still on the project’s page');
      expect(inAppBar(find.text('Casaa')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'UX-2503: Eliminar proyecto from «Casa»’s page closes it and shows Proyecto eliminado on Proyectos, without Casa',
        (tester) async {
      final (_, _, api) = await openProjects(tester, [
        TaskListInfo(id: 'casa', name: 'Casa', version: 2),
        TaskListInfo(id: 'obra', name: 'Obra', version: 2),
      ]);
      await tester.tap(find.widgetWithText(ListTile, 'Casa'));
      await tester.pumpAndSettle();
      await tester.tap(inAppBar(find.byTooltip(es.manageItem('Casa'))));
      await tester.pumpAndSettle();
      await tester.tap(find.text(es.deleteList));
      await tester.pumpAndSettle();
      // It still asks first.
      await tester.tap(find.descendant(
          of: find.byType(AlertDialog),
          matching: find.widgetWithText(FilledButton, es.deleteList)));
      await tester.pumpAndSettle();
      expect(api.calls, contains(('DELETE', 'lists/casa/')));
      expect(pageOf('casa'), findsNothing, reason: 'the page is closed');
      final projects = find.byType(TaskListsScreen);
      expect(ModalRoute.of(tester.element(projects))!.isCurrent, isTrue);
      expect(find.text(es.projectDeleted).hitTestable(), findsOneWidget);
      expect(find.widgetWithText(ListTile, 'Casa'), findsNothing);
      expect(find.widgetWithText(ListTile, 'Obra'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'UX-2516: a new account’s Proyectos, opened from another screen, has no Grupos: its only buttons are Atrás and Nuevo proyecto',
        (tester) async {
      await openProjects(tester, []);
      tester.state<NavigatorState>(find.byType(Navigator)).push(
          MaterialPageRoute<void>(builder: (_) => const TaskListsScreen()));
      await tester.pumpAndSettle();
      final top = find.byType(TaskListsScreen);
      expect(top, findsOneWidget, reason: 'the one below is offstage');
      expect(find.text(es.groups), findsNothing);
      expect(find.byIcon(Icons.groups_outlined), findsNothing);
      // Each button once: BackButton wraps an IconButton, which wraps a
      // button of its own.
      final buttons = find.descendant(
          of: top,
          matching: find.byWidgetPredicate((w) =>
              w.runtimeType == IconButton ||
              w is FilledButton ||
              w is TextButton ||
              w is OutlinedButton ||
              w is ElevatedButton));
      expect(buttons, findsNWidgets(2), reason: '${tester.widgetList(buttons)}');
      final back = MaterialLocalizations.of(tester.element(top))
          .backButtonTooltip;
      expect(find.descendant(of: top, matching: find.byTooltip(back)),
          findsOneWidget);
      expect(
          find.descendant(
              of: top, matching: find.byKey(const ValueKey('new-list'))),
          findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'UX-2516: projects of one’s own, none shared and no group, still show no Grupos',
        (tester) async {
      await openProjects(tester, [
        TaskListInfo(id: 'casa', name: 'Casa', version: 2),
        TaskListInfo(id: 'obra', name: 'Obra', version: 2),
      ]);
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -600));
      await tester.pumpAndSettle();
      expect(find.text(es.groups), findsNothing);
      expect(tester.takeException(), isNull);
    });

    Future<void> expectGroupsShown(WidgetTester tester) async {
      final groups = find.widgetWithText(TextButton, es.groups);
      await tester.scrollUntilVisible(groups, 200,
          scrollable: find.byType(Scrollable).first);
      await tester.pumpAndSettle();
      expect(groups, findsOneWidget);
      await tester.tap(groups);
      await tester.pumpAndSettle();
      expect(find.byType(GroupsScreen), findsOneWidget);
    }

    testWidgets('UX-2516: with a shared project, Grupos shows and opens Grupos',
        (tester) async {
      await openProjects(tester, [
        TaskListInfo(
            id: 'casa',
            name: 'Casa',
            version: 2,
            shared: true,
            ownerId: 1,
            people: const [me, ana]),
      ]);
      await expectGroupsShown(tester);
      expect(tester.takeException(), isNull);
    });

    testWidgets('UX-2516: in a group, Grupos shows and opens Grupos',
        (tester) async {
      await openProjects(tester, [],
          groups: const [
            TaskGroupInfo(
                id: 'master',
                name: 'Máster',
                ownerId: 1,
                version: 1,
                role: 'owner'),
          ]);
      await expectGroupsShown(tester);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'UX-2516: with a pending group invitation (its card on Proyectos), Grupos shows',
        (tester) async {
      await openProjectsWith(tester, [],
          invitations: () async => const [
                PendingInvitation(
                    kind: 'group',
                    id: 'inv-1',
                    name: 'Máster',
                    targetId: 'master',
                    role: 'member'),
              ]);
      expect(find.textContaining('Máster'), findsWidgets,
          reason: 'the invitation’s card shows');
      final groups = find.widgetWithText(TextButton, es.groups);
      await tester.scrollUntilVisible(groups, 200,
          scrollable: find.byType(Scrollable).first);
      expect(groups, findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  // ---- P288 (UX-2509): every search clears in one tap ----

  group('P288 · Proyectos search clears in one tap', () {
    // The search box shows from 8 projects.
    const names = [
      'Casa', 'Trabajo', 'Gimnasio', 'Viajes', 'Lectura', 'Dentista',
      'Compras', 'Huerto',
    ];

    Future<void> show(WidgetTester tester, String language) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final store = _Lists()
        ..lists = [for (final name in names) TaskListInfo(id: name, name: name)];
      final container = ProviderContainer(retry: noRetry, overrides: [
        apiClientProvider.overrideWith((ref) => OfflineApiClient()),
        taskProvider.overrideWith((ref) => DesignTaskNotifier()),
        taskListStoreProvider.overrideWithValue(store),
        pendingInvitationsProvider.overrideWith((ref) async => []),
        themeStoreProvider.overrideWithValue(MemoryThemeStore()),
      ]);
      addTearDown(container.dispose);
      await tester.pumpWidget(UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
              locale: Locale(language),
              theme: AppTheme.light,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: const TaskListsScreen())));
      await tester.pumpAndSettle();
    }

    Finder row(String name) => find.widgetWithText(ListTile, name);

    for (final language in ['es', 'en', 'ca']) {
      testWidgets(
          'UX-2509: ($language, 1×, 360×800) Proyectos: an empty search has no ✕; typing «dent» shows a 48 dp ✕ read as «Borrar búsqueda»; one tap clears it and every project comes back',
          (tester) async {
        final l = lookupAppLocalizations(Locale(language));
        final semantics = tester.ensureSemantics();
        await show(tester, language);
        final field = searchField();
        expect(field, findsOneWidget);
        expectNoClear(field, l);
        expect(row('Casa'), findsOneWidget);

        await tester.enterText(field, 'dent');
        await tester.pumpAndSettle();
        expect(row('Dentista'), findsOneWidget);
        expect(row('Casa'), findsNothing);
        expect(row('Trabajo'), findsNothing);
        expectClear(tester, field, l);

        await tapClear(tester, field, l);
        expect(searchText(tester, field), isEmpty);
        expect(row('Casa'), findsOneWidget);
        expect(row('Trabajo'), findsOneWidget);
        expectNoClear(field, l);
        // Every project is listed again, the last one at the end.
        await tester.scrollUntilVisible(row('Huerto'), 200,
            scrollable: find.byType(Scrollable).first);
        expect(row('Huerto'), findsOneWidget);
        expect(tester.takeException(), isNull);
        semantics.dispose();
      });
    }

    testWidgets(
        'UX-2509: (es, 1×, 360×800) Proyectos with no match: the ✕ is in view and brings the projects back',
        (tester) async {
      final es = lookupAppLocalizations(const Locale('es'));
      final semantics = tester.ensureSemantics();
      await show(tester, 'es');
      final field = searchField();
      await tester.enterText(field, 'zanahorias');
      await tester.pumpAndSettle();
      expect(find.text(es.projectsNoneFound), findsOneWidget);
      expect(row('Casa'), findsNothing);
      expectClear(tester, field, es);

      await tapClear(tester, field, es);
      expect(find.text(es.projectsNoneFound), findsNothing);
      expect(row('Casa'), findsOneWidget);
      expectNoClear(field, es);
      expect(tester.takeException(), isNull);
      semantics.dispose();
    });
  });

  // ---- Run 2026-10-28-app, round 2 · P303 (UX-2628) ----

  group('P303 · pinning stays on Proyectos', () {
    const me = ProjectMember(id: 1, name: 'Yo', role: 'owner');
    const ana = ProjectMember(id: 2, name: 'Ana', role: 'editor');

    /// The texts of the ⋮ menu that's open, top to bottom.
    List<String> menuTexts(WidgetTester tester) => tester
        .widgetList<PopupMenuItem<String>>(find.byType(PopupMenuItem<String>))
        .map((item) => (item.child! as Text).data!)
        .toList();

    Finder pageOf(String id) => find.byWidgetPredicate(
        (w) => w is HomeScreen && w.listId == id,
        skipOffstage: false);

    Finder inAppBarOf(String id, Finder finder) => find.descendant(
        of: find.descendant(of: pageOf(id), matching: find.byType(AppBar)),
        matching: finder);

    Future<void> closeMenu(WidgetTester tester) async {
      await tester.tapAt(const Offset(8, 420));
      await tester.pumpAndSettle();
      expect(find.byType(PopupMenuItem<String>), findsNothing);
    }

    /// Projects in Spanish, signed in, with [lists] in a store that pins
    /// and orders them as the phone's database does.
    Future<_PinningLists> openPinning(
        WidgetTester tester, List<TaskListInfo> lists) async {
      platform.setMockMethodCallHandler(timeoutChannel, (_) async => 10000);
      addTearDown(
          () => platform.setMockMethodCallHandler(timeoutChannel, null));
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final store = _PinningLists()..lists = lists;
      final api = _DeleteApi();
      final container = ProviderContainer(retry: noRetry, overrides: [
        apiClientProvider.overrideWithValue(api),
        authProvider.overrideWith((ref) => SignedInFixtureAuth(api)),
        taskRepositoryProvider.overrideWithValue(MemoryTasks()),
        taskProvider.overrideWith((ref) => _CountingTasks()),
        taskListStoreProvider.overrideWithValue(store),
        pendingInvitationsProvider.overrideWith((ref) async => []),
        groupsProvider.overrideWith((ref) async => []),
        themeStoreProvider.overrideWithValue(MemoryThemeStore()),
      ]);
      addTearDown(container.dispose);
      addTearDown(api.close);
      await tester.pumpWidget(UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
              locale: const Locale('es'),
              theme: AppTheme.light,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: const TaskListsScreen())));
      await tester.pumpAndSettle();
      return store;
    }

    for (final pinned in [false, true]) {
      for (final (label, shared, role) in [
        ('owner, personal', false, 'owner'),
        ('owner, shared', true, 'owner'),
        ('editor', true, 'editor'),
        ('viewer', true, 'viewer'),
      ]) {
        testWidgets(
            'UX-2628: «Casa»’s page ($label${pinned ? ', pinned' : ''}) lists neither Fijar nor Desfijar proyecto in its ⋮; Proyectos’ ⋮ for Casa still lists ${pinned ? 'Desfijar' : 'Fijar'} proyecto',
            (tester) async {
          await openPinning(tester, [
            TaskListInfo(
                id: 'casa',
                name: 'Casa',
                version: 2,
                pinned: pinned,
                shared: shared,
                role: role,
                ownerId: role == 'owner' ? 1 : 2,
                people: shared ? const [me, ana] : const []),
          ]);
          await openMenu(tester, 'Casa');
          expect(menuTexts(tester),
              contains(pinned ? es.unpinProject : es.pinProject));
          await closeMenu(tester);
          await tester.tap(find.widgetWithText(ListTile, 'Casa'));
          await tester.pumpAndSettle();
          expect(pageOf('casa'), findsOneWidget);
          final manage =
              inAppBarOf('casa', find.byTooltip(es.manageItem('Casa')));
          expect(manage, findsOneWidget);
          await tester.tap(manage);
          await tester.pumpAndSettle();
          final items = menuTexts(tester);
          expect(items, isNotEmpty);
          expect(items, isNot(contains(es.pinProject)));
          expect(items, isNot(contains(es.unpinProject)));
          expect(find.text(es.pinProject), findsNothing);
          expect(find.text(es.unpinProject), findsNothing);
          expect(tester.takeException(), isNull);
        });
      }
    }

    testWidgets(
        'UX-2628: on Proyectos, Fijar proyecto in «Obra»’s ⋮ moves its row to the top, marked Fijado, and its ⋮ then offers Desfijar proyecto; Obra’s page still offers neither',
        (tester) async {
      final store = await openPinning(tester, [
        TaskListInfo(id: 'casa', name: 'Casa', version: 2),
        TaskListInfo(id: 'obra', name: 'Obra', version: 2),
      ]);
      Finder row(String name) => find.widgetWithText(ListTile, name);
      expect(tester.getTopLeft(row('Casa')).dy,
          lessThan(tester.getTopLeft(row('Obra')).dy));
      expect(
          find.descendant(
              of: row('Obra'), matching: find.byIcon(Icons.push_pin_outlined)),
          findsNothing);

      await openMenu(tester, 'Obra');
      await tester.tap(find.text(es.pinProject));
      await tester.pumpAndSettle();

      expect(store.lists.singleWhere((l) => l.id == 'obra').pinned, isTrue);
      // Obra now leads the list, with the pin that reads Fijado.
      expect(tester.getTopLeft(row('Obra')).dy,
          lessThan(tester.getTopLeft(row('Casa')).dy));
      final handle = tester.ensureSemantics();
      expect(
          find.descendant(
              of: row('Obra'), matching: find.byIcon(Icons.push_pin_outlined)),
          findsOneWidget);
      expect(tester.getSemantics(row('Obra')).label,
          contains(es.projectPinned));
      handle.dispose();
      await openMenu(tester, 'Obra');
      expect(menuTexts(tester).first, es.unpinProject);
      await closeMenu(tester);

      // Its own page doesn't offer pinning, pinned or not.
      await tester.tap(row('Obra'));
      await tester.pumpAndSettle();
      await tester
          .tap(inAppBarOf('obra', find.byTooltip(es.manageItem('Obra'))));
      await tester.pumpAndSettle();
      expect(menuTexts(tester), isNotEmpty);
      expect(find.text(es.pinProject), findsNothing);
      expect(find.text(es.unpinProject), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });
}

/// P303: the phone's projects, pinned and ordered as its database does:
/// archived last, pinned first, then by name.
class _PinningLists extends _Lists {
  @override
  Future<List<TaskListInfo>> all() async => [...lists]..sort((a, b) {
      if (a.archived != b.archived) return a.archived ? 1 : -1;
      if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });

  @override
  Future<void> preferences(String id,
      {bool? pinned, String? notifications}) async {
    lists = [
      for (final list in lists)
        list.id == id && pinned != null ? list.copyWith(pinned: pinned) : list,
    ];
  }
}

/// Projects' server: a DELETE waits for [answer]; anything else goes
/// nowhere.
class _HeldDeleteApi extends OfflineApiClient {
  final deletes = <String>[];
  final answer = Completer<dynamic>();
  @override
  Future<dynamic> request(String method, String path,
      {Map<String, dynamic>? data,
      String? audioPath,
      bool authenticated = true,
      int? accountId}) {
    if (method == 'DELETE') {
      deletes.add(path);
      return answer.future;
    }
    return Future.value({});
  }
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

/// Counts how often the tasks are loaded again; in the app, each load
/// reschedules the reminders.
class _CountingTasks extends DesignTaskNotifier {
  _CountingTasks([this.given]);

  /// The tasks on the phone; the design samples when null.
  final List<Task>? given;
  int loads = 0;
  @override
  Future<void> loadTasks() {
    loads++;
    if (given != null && !state.hasValue) {
      state = AsyncData(given!);
      return Future.value();
    }
    return super.loadTasks();
  }
}

/// Records the server calls Projects makes.
class _DeleteApi extends OfflineApiClient {
  final calls = <(String, String)>[];
  @override
  Future<dynamic> request(String method, String path,
      {Map<String, dynamic>? data,
      String? audioPath,
      bool authenticated = true,
      int? accountId}) async {
    calls.add((method, path));
    return {};
  }
}
