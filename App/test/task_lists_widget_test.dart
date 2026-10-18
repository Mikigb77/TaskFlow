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
import 'package:flutter_test/flutter_test.dart';
import 'package:agenda/providers/subscription_provider.dart';
import 'support/capture_fixtures.dart';
import 'support/design_fixtures.dart';
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
    final container = ProviderContainer(overrides: [
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
    await tester.tap(find.text('Save project'));
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
      final container = ProviderContainer(overrides: [
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
      await tester.tap(find.text('Save project'));
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
        final container = ProviderContainer(overrides: [
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
    final container = ProviderContainer(overrides: [
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
      'UX-479: Projects ⋮ reads Miembros for a shared project you edit and a group project you don’t administer, and Compartir for your own project and a group you administer',
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
      ('Equipo', es.shareProject, es.people),
    ]) {
      await openMenu(tester, name);
      expect(inMenu(label), findsOneWidget, reason: name);
      expect(inMenu(notLabel), findsNothing, reason: name);
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
    }
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
    await tester.tap(find.widgetWithText(FilledButton, es.saveList));
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
    await tester.tap(find.widgetWithText(FilledButton, es.saveList));
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
      'UX-329: a new account’s Projects screen has no headline, help line, refresh button or search box: Grupos and Nuevo proyecto are its only buttons',
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
    expect(buttons, hasLength(2), reason: '$buttons');
    expect(inScreen(find.widgetWithText(TextButton, es.groups)), findsOneWidget);
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
    await tester.tap(find.widgetWithText(FilledButton, es.saveList));
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
    await openProjects(tester, [TaskListInfo(id: 'casa', name: 'Casa')]);
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
