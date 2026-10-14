import 'dart:async';

import 'package:agenda/l10n/generated/app_localizations.dart';
import 'package:agenda/models/task.dart';
import 'package:agenda/models/task_list_info.dart';
import 'package:agenda/screens/home_screen.dart';
import 'package:agenda/theme/app_theme.dart';
import 'package:agenda/widgets/app_components.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/design_fixtures.dart';
import 'package:agenda/l10n/region.dart';
import 'package:agenda/widgets/task_tile.dart';
import 'package:agenda/models/capture_session.dart';
import 'package:agenda/providers/project_scope_provider.dart';
import 'package:agenda/providers/task_lists_provider.dart';
import 'package:agenda/screens/captures_screen.dart';
import 'package:agenda/widgets/task_actions.dart';

final _project = TaskListInfo(id: 'school', name: 'Col·legi');

Widget _app(ProviderContainer container, Widget home, String language) =>
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: AppTheme.light,
        locale: Locale(language),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: home,
      ),
    );

void main() {
  setUpAll(() async {
    await (FontLoader(
      'Manrope',
    )..addFont(rootBundle.load('assets/fonts/Manrope.ttf'))).load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });
  for (final language in ['es', 'en']) {
    for (final (name, screen) in [
      ('Tareas', const HomeScreen()),
      ('a project page', const HomeScreen(listId: 'school', isRoot: false)),
    ]) {
      testWidgets(
        'UX-428: an empty list on $name shows the Tareas tab’s check_box_outlined icon ($language)',
        (tester) async {
          final l10n = lookupAppLocalizations(Locale(language));
          final container = designContainer(
            tasks: _NoTasks.new,
            projects: [_project],
          );
          addTearDown(container.dispose);
          await tester.pumpWidget(_app(container, screen, language));
          await tester.pumpAndSettle();
          final empty = find.byType(EmptyState);
          expect(empty, findsOneWidget);
          expect(
            find.descendant(of: empty, matching: find.text(l10n.freshStart)),
            findsOneWidget,
          );
          expect(
            find.descendant(
              of: empty,
              matching: find.byIcon(Icons.check_box_outlined),
            ),
            findsOneWidget,
          );
          expect(find.byIcon(Icons.checklist_rounded), findsNothing);
          expect(tester.takeException(), isNull);
        },
      );
    }

    testWidgets(
      'UX-428: a project page’s Notas button shows the Notas tab’s description_outlined icon ($language)',
      (tester) async {
        final l10n = lookupAppLocalizations(Locale(language));
        final container = designContainer(projects: [_project]);
        addTearDown(container.dispose);
        await tester.pumpWidget(
          _app(
            container,
            const HomeScreen(listId: 'school', isRoot: false),
            language,
          ),
        );
        await tester.pumpAndSettle();
        final button = find.ancestor(
          of: find.text(l10n.notes),
          matching: find.byWidgetPredicate((widget) => widget is TextButton),
        );
        expect(button, findsOneWidget);
        expect(
          find.descendant(
            of: button,
            matching: find.byIcon(Icons.description_outlined),
          ),
          findsOneWidget,
        );
        expect(find.byIcon(Icons.notes_rounded), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final language in ['es', 'ca']) {
    testWidgets(
      'UX-201: Tareas with the Hoy filter lists yesterday’s open task with its date ($language)',
      (tester) async {
        final l10n = lookupAppLocalizations(Locale(language));
        // Tall enough that every row of the filtered list is built.
        tester.view.physicalSize = const Size(400, 1600);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final now = DateTime.now();
        final yesterday = DateTime(now.year, now.month, now.day - 1, 10);
        final container = designContainer(
          tasks: () => _GivenTasks([
            Task(id: 1, title: 'Comprar pan', priority: 1, dueDate: yesterday),
            Task(
              id: 2,
              title: 'Llamar a mamá',
              priority: 1,
              dueDate: DateTime(now.year, now.month, now.day, 18),
            ),
            Task(
              id: 3,
              title: 'Ir al dentista',
              priority: 1,
              dueDate: DateTime(now.year, now.month, now.day + 1, 9),
            ),
            Task(
              id: 4,
              title: 'Pagar la luz',
              priority: 1,
              dueDate: DateTime(now.year, now.month, now.day - 2, 9),
              isCompleted: true,
            ),
            Task(
              id: 5,
              title: 'Tomar la pastilla',
              priority: 1,
              dueDate: DateTime(now.year, now.month, now.day - 5, 8),
              recurrence: 'daily',
              completedDates: [Task.dateKey(now)],
            ),
          ]),
        );
        addTearDown(container.dispose);
        await tester.pumpWidget(_app(container, const HomeScreen(), language));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(ChoiceChip, l10n.today));
        await tester.pumpAndSettle();
        final context = tester.element(find.byType(HomeScreen));
        final overdue = find.widgetWithText(TaskTile, 'Comprar pan');
        expect(overdue, findsOneWidget);
        expect(
          find.descendant(
            of: overdue,
            matching: find.textContaining(context.dayLabel(yesterday)),
          ),
          findsOneWidget,
        );
        expect(find.widgetWithText(TaskTile, 'Llamar a mamá'), findsOneWidget);
        expect(find.widgetWithText(TaskTile, 'Ir al dentista'), findsNothing);
        expect(find.widgetWithText(TaskTile, 'Pagar la luz'), findsNothing);
        // A repeating task done today but missed yesterday: one overdue row,
        // shown with yesterday's date.
        final habit = find.widgetWithText(TaskTile, 'Tomar la pastilla');
        expect(habit, findsOneWidget);
        expect(
          find.descendant(
            of: habit,
            matching: find.textContaining(
              context.dayLabel(DateTime(now.year, now.month, now.day - 1)),
            ),
          ),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final language in ['es', 'ca', 'en']) {
    testWidgets(
      'UX-308: the Tasks tab shows a Proyectos text button, not a bare folder icon ($language)',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final l10n = lookupAppLocalizations(Locale(language));
        final container = designContainer(projects: [_project]);
        addTearDown(container.dispose);
        await tester.pumpWidget(_app(container, const HomeScreen(), language));
        await tester.pumpAndSettle();
        final projects = find.widgetWithText(TextButton, l10n.lists);
        expect(projects, findsOneWidget);
        expect(projects.hitTestable(), findsOneWidget);
        expect(
          find.widgetWithIcon(IconButton, Icons.folder_outlined),
          findsNothing,
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'UX-308: at 2x text on a 320 dp phone the Proyectos button fits beside the heading ($language)',
      (tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.view.reset);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final l10n = lookupAppLocalizations(Locale(language));
        final container = designContainer(projects: [_project]);
        addTearDown(container.dispose);
        await tester.pumpWidget(_app(container, const HomeScreen(), language));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'no overflow');
        final projects = find.widgetWithText(TextButton, l10n.lists);
        expect(projects.hitTestable(), findsOneWidget);
        final rect = tester.getRect(projects);
        expect(rect.left, greaterThanOrEqualTo(0));
        expect(rect.right, lessThanOrEqualTo(320));
        expect(
          find.byTooltip(l10n.completedTasks).hitTestable(),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'UX-308: at 2x text on 320x640 the Tareas heading never overflows, and Proyectos and Tareas completadas open their screens ($language)',
      (tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.view.reset);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final l10n = lookupAppLocalizations(Locale(language));
        final container = designContainer(projects: [_project]);
        addTearDown(container.dispose);
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              theme: AppTheme.light,
              locale: Locale(language),
              supportedLocales: AppLocalizations.supportedLocales,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              home: const HomeScreen(),
              onGenerateRoute: (settings) => MaterialPageRoute<void>(
                settings: settings,
                builder: (_) => Scaffold(body: Text('route ${settings.name}')),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'no overflow');
        final heading = find.text(l10n.yourTasks);
        expect(heading, findsOneWidget);
        final projects = find.widgetWithText(TextButton, l10n.lists);
        final completed = find.byTooltip(l10n.completedTasks);
        for (final control in [projects, completed]) {
          expect(control.hitTestable(), findsOneWidget);
          final rect = tester.getRect(control);
          expect(rect.left, greaterThanOrEqualTo(0));
          expect(rect.right, lessThanOrEqualTo(320));
        }
        await tester.tap(projects);
        await tester.pumpAndSettle();
        expect(find.text('route /lists'), findsOneWidget);
        tester.state<NavigatorState>(find.byType(Navigator)).pop();
        await tester.pumpAndSettle();
        await tester.tap(completed);
        await tester.pumpAndSettle();
        expect(find.text('route /completedTasks'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'UX-308: at 390x844 with 1x text in Spanish Proyectos and Tareas completadas sit on one line',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final l10n = lookupAppLocalizations(const Locale('es'));
      final container = designContainer(projects: [_project]);
      addTearDown(container.dispose);
      await tester.pumpWidget(_app(container, const HomeScreen(), 'es'));
      await tester.pumpAndSettle();
      final projects = tester.getRect(
        find.widgetWithText(TextButton, l10n.lists),
      );
      final completed = tester.getRect(find.byTooltip(l10n.completedTasks));
      expect((projects.center.dy - completed.center.dy).abs(), lessThan(4));
      expect(projects.right, lessThanOrEqualTo(completed.left + 0.5));
      expect(tester.takeException(), isNull);
    },
  );

  // ---- Round 1 (b9) · P24 and P43: project pages and Tareas ----

  final es = lookupAppLocalizations(const Locale('es'));
  const me = ProjectMember(id: 1, name: 'Yo', role: 'owner');
  const ana = ProjectMember(id: 2, name: 'Ana', role: 'editor');

  /// [home] in [language] at 390×844 with [tasks], [projects] and [pending]
  /// captures.
  Future<ProviderContainer> open(
    WidgetTester tester,
    Widget home, {
    List<Task> tasks = const [],
    List<TaskListInfo> projects = const [],
    List<CaptureSession> pending = const [],
    String language = 'es',
  }) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final container = designContainer(
      tasks: () => _GivenTasks(tasks),
      projects: projects,
      pendingCaptures: pending,
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light,
          locale: Locale(language),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: home,
          onGenerateRoute: (settings) => MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => settings.name == '/captures'
                ? const CapturesScreen()
                : Scaffold(body: Text('route ${settings.name}')),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  testWidgets(
    'UX-314: a viewer’s project page shows Este proyecto es de solo lectura and no Añadir tarea; an editor’s page keeps it',
    (tester) async {
      expect(es.readOnlyList, 'Este proyecto es de solo lectura');
      await open(
        tester,
        const HomeScreen(listId: 'obra', isRoot: false),
        projects: [
          TaskListInfo(
            id: 'obra',
            name: 'Obra',
            version: 2,
            shared: true,
            role: 'viewer',
            ownerId: 2,
            people: const [ana, me],
          ),
        ],
      );
      expect(find.text(es.readOnlyList), findsOneWidget);
      expect(find.text(es.listEditingAccessHelp), findsOneWidget);
      expect(find.byType(TaskActions), findsNothing);
      expect(find.text(es.addTask), findsNothing);
      expect(
        find.byType(FilledButton),
        findsNothing,
        reason: 'no create button',
      );
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox());
      await open(
        tester,
        const HomeScreen(listId: 'obra', isRoot: false),
        projects: [
          TaskListInfo(
            id: 'obra',
            name: 'Obra',
            version: 2,
            shared: true,
            role: 'editor',
            ownerId: 2,
            people: const [ana, me],
          ),
        ],
      );
      expect(find.text(es.readOnlyList), findsNothing);
      expect(find.text(es.addTask), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'UX-315: a shared project’s page lists tasks assigned to others by default; Para mí there hides them without changing Calendar’s scope',
    (tester) async {
      final casa = TaskListInfo(
        id: 'casa',
        name: 'Casa',
        version: 2,
        shared: true,
        ownerId: 1,
        people: const [me, ana],
      );
      final container = await open(
        tester,
        const HomeScreen(listId: 'casa', isRoot: false),
        projects: [casa],
        tasks: [
          Task(
            id: 1,
            title: 'Pintar la valla',
            priority: 1,
            listId: 'casa',
            assignment: 'member',
            assigneeId: 2,
          ),
          Task(
            id: 2,
            title: 'Comprar pintura',
            priority: 1,
            listId: 'casa',
            assignment: 'member',
            assigneeId: 1,
          ),
        ],
      );
      // Calendar's scope is Para mí (the default), and the page still shows
      // Ana's task.
      expect(container.read(projectScopeProvider).team, isFalse);
      expect(find.widgetWithText(TaskTile, 'Pintar la valla'), findsOneWidget);
      expect(find.widgetWithText(TaskTile, 'Comprar pintura'), findsOneWidget);
      expect(
        tester
            .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, es.forTeam))
            .selected,
        isTrue,
      );

      // Calendar on Todas; Para mí chosen on the page applies to the page.
      container.read(projectScopeProvider.notifier).state = const ProjectScope(
        team: true,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ChoiceChip, es.forMe));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(TaskTile, 'Pintar la valla'), findsNothing);
      expect(find.widgetWithText(TaskTile, 'Comprar pintura'), findsOneWidget);
      final global = container.read(projectScopeProvider);
      expect(global.team, isTrue, reason: 'Calendar keeps Todas');
      expect(global.projectId, isNull, reason: 'Calendar keeps its project');
      expect(tester.takeException(), isNull);
    },
  );

  for (final language in ['es', 'ca']) {
    testWidgets(
      'UX-219: Tareas filtered to Prioridad alta with no match says No hay tareas que coincidan, not Un nuevo comienzo ($language)',
      (tester) async {
        final l = lookupAppLocalizations(Locale(language));
        await open(
          tester,
          const HomeScreen(),
          language: language,
          tasks: [Task(id: 1, title: 'Comprar pan', priority: 1)],
        );
        await tester.tap(find.widgetWithText(ChoiceChip, l.highPriority));
        await tester.pumpAndSettle();
        final empty = find.byType(EmptyState);
        expect(
          find.descendant(of: empty, matching: find.text(l.noMatches)),
          findsOneWidget,
        );
        expect(
          find.descendant(of: empty, matching: find.text(l.differentFilter)),
          findsOneWidget,
        );
        expect(find.text(l.freshStart), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'UX-219: Tareas with no tasks and no filter still says Un nuevo comienzo',
    (tester) async {
      await open(tester, const HomeScreen());
      expect(find.text(es.freshStart), findsOneWidget);
      expect(find.text(es.noMatches), findsNothing);
    },
  );

  for (final (name, screen, title) in [
    ('a project page', const HomeScreen(listId: 'casa', isRoot: false), 'Casa'),
    ('Sin fecha', const HomeScreen(initialFilter: 3, isRoot: false), null),
  ]) {
    testWidgets(
      'UX-333: $name has no uppercase eyebrow and no headline repeating the app bar title',
      (tester) async {
        await open(
          tester,
          screen,
          projects: [TaskListInfo(id: 'casa', name: 'Casa')],
        );
        final heading = title ?? es.inbox;
        expect(find.byType(SectionLabel), findsNothing);
        expect(find.text(heading), findsOneWidget, reason: 'only once');
        expect(
          find.descendant(
            of: find.byType(AppBar),
            matching: find.text(heading),
          ),
          findsOneWidget,
          reason: 'in the app bar',
        );
        expect(find.text(es.yourTasks), findsNothing);
        // Its buttons stay.
        expect(find.byTooltip(es.completedTasks), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'UX-333: an archived project’s page says Proyecto archivado as a plain subtitle, not an uppercase eyebrow',
    (tester) async {
      await open(
        tester,
        const HomeScreen(listId: 'casa', isRoot: false),
        projects: [TaskListInfo(id: 'casa', name: 'Casa', archived: true)],
      );
      expect(find.text(es.archivedList), findsOneWidget);
      expect(find.text(es.archivedList.toUpperCase()), findsNothing);
      expect(find.byType(SectionLabel), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'U11: Tareas’ chips are Todas las tareas, Sin fecha, Hoy and Prioridad alta, with no Bandeja personal; an undated task’s tile reads Sin fecha',
    (tester) async {
      expect(es.inbox, 'Sin fecha');
      expect(es.noDate, 'Sin fecha');
      await open(
        tester,
        const HomeScreen(),
        tasks: [Task(id: 1, title: 'Algún día', priority: 1)],
      );
      final chips = tester
          .widgetList<ChoiceChip>(
            find.descendant(
              of: find.byType(HomeScreen),
              matching: find.byType(ChoiceChip),
            ),
          )
          .map((chip) => (chip.label as Text).data)
          .toList();
      expect(chips, [es.allTasks, es.inbox, es.today, es.highPriority]);
      expect(find.text('Bandeja personal'), findsNothing);
      expect(find.text(es.noList), findsNothing);
      final tile = find.widgetWithText(TaskTile, 'Algún día');
      expect(tile, findsOneWidget);
      expect(
        find.descendant(of: tile, matching: find.text('Sin fecha')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: tile, matching: find.textContaining('Bandeja')),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'U11: one unsaved capture shows Sin guardar · 1, and the list it opens is titled Sin guardar',
    (tester) async {
      expect(es.pendingCaptureCount(1), 'Sin guardar · 1');
      expect(es.unfinishedCaptures, 'Sin guardar');
      await open(
        tester,
        const HomeScreen(),
        pending: [
          CaptureSession(
            id: 'c1',
            ownerKey: 'local',
            capturedAt: DateTime(2026, 10, 14, 9),
            timezone: 'Europe/Madrid',
            text: 'Llamar al médico mañana',
          ),
        ],
      );
      final link = find.text(es.pendingCaptureCount(1));
      expect(link, findsOneWidget);
      await tester.tap(link);
      await tester.pumpAndSettle();
      expect(find.byType(CapturesScreen), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.text(es.unfinishedCaptures),
        ),
        findsOneWidget,
      );
      expect(find.textContaining('Captura'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  // ---- Round 2 (b9) · P114: read-only only when it is, and said once ----

  TaskListInfo viewerProject() => TaskListInfo(
    id: 'p1',
    name: 'Obra',
    version: 2,
    shared: true,
    role: 'viewer',
    ownerId: 2,
    people: const [ana, me],
  );

  /// A project page for 'p1' at [size] and [scale] text in [language].
  Future<ProviderContainer> openProject(
    WidgetTester tester, {
    required List<TaskListInfo> projects,
    List<Task> tasks = const [],
    String language = 'es',
    Size size = const Size(360, 740),
    double scale = 1,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    if (scale != 1) {
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    }
    final container = designContainer(
      tasks: () => _GivenTasks(tasks),
      projects: projects,
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      _app(container, const HomeScreen(listId: 'p1', isRoot: false), language),
    );
    await tester.pumpAndSettle();
    return container;
  }

  test('UX-625: readOnlyListEmpty reads as the plan says in each language', () {
    expect(es.readOnlyListEmpty, 'Este proyecto aún no tiene tareas.');
    expect(
      lookupAppLocalizations(const Locale('en')).readOnlyListEmpty,
      'No tasks in this project yet.',
    );
    expect(
      lookupAppLocalizations(const Locale('ca')).readOnlyListEmpty,
      'Aquest projecte encara no té tasques.',
    );
  });

  testWidgets(
    'UX-625: an empty view-only project page at 360x740 says Este proyecto aún no tiene tareas. with the read-only line, and never Añade una tarea or Añadir tarea',
    (tester) async {
      await openProject(tester, projects: [viewerProject()]);
      final empty = find.byType(EmptyState);
      expect(
        find.descendant(of: empty, matching: find.text(es.readOnlyListEmpty)),
        findsOneWidget,
      );
      expect(find.text(es.freshStart), findsOneWidget);
      expect(find.text(es.readOnlyList), findsOneWidget);
      expect(find.text(es.listEmpty), findsNothing);
      expect(find.text(es.addTask), findsNothing);
      expect(find.byType(TaskActions), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  for (final language in ['en', 'ca']) {
    testWidgets(
      'UX-625: the empty view-only project page says the no-tasks sentence, not listEmpty ($language)',
      (tester) async {
        final l = lookupAppLocalizations(Locale(language));
        await openProject(
          tester,
          projects: [viewerProject()],
          language: language,
        );
        expect(find.text(l.readOnlyListEmpty), findsOneWidget);
        expect(find.text(l.readOnlyList), findsOneWidget);
        expect(find.text(l.listEmpty), findsNothing);
        expect(find.text(l.addTask), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'UX-625: an editable empty project page still says Añade una tarea a este proyecto… with Añadir tarea and no read-only line',
    (tester) async {
      await openProject(
        tester,
        projects: [TaskListInfo(id: 'p1', name: 'Obra')],
      );
      expect(find.text(es.listEmpty), findsOneWidget);
      expect(find.text(es.addTask), findsOneWidget);
      expect(find.text(es.readOnlyList), findsNothing);
      expect(find.text(es.readOnlyListEmpty), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'UX-626: a new project not yet in the lists never shows Este proyecto es de solo lectura; once it loads as editable the page shows Añadir tarea',
    (tester) async {
      // As right after createProject: the lists are reloading, with the
      // previous value still lacking the new project.
      tester.view.physicalSize = const Size(360, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final casa = TaskListInfo(id: 'other', name: 'Casa');
      final obra = TaskListInfo(id: 'p1', name: 'Obra');
      final reload = Completer<List<TaskListInfo>>();
      var loads = 0;
      final container = designContainer(
        tasks: () => _GivenTasks(const []),
        loadProjects: () => ++loads == 1 ? Future.value([casa]) : reload.future,
      );
      addTearDown(container.dispose);
      await container.read(taskListsProvider.future);
      container.invalidate(taskListsProvider);
      await tester.pumpWidget(
        _app(container, const HomeScreen(listId: 'p1', isRoot: false), 'es'),
      );
      // Every frame of the reload, not only the settled one.
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 16));
        expect(container.read(taskListsProvider).isLoading, isTrue);
        expect(find.text(es.readOnlyList), findsNothing);
        expect(find.text(es.readOnlyListEmpty), findsNothing);
        expect(find.text(es.listEditingAccessHelp), findsNothing);
      }

      reload.complete([casa, obra]);
      await tester.pumpAndSettle();
      expect(find.text(es.addTask), findsOneWidget);
      expect(find.text(es.readOnlyList), findsNothing);
      expect(find.text(es.readOnlyListEmpty), findsNothing);
      expect(
        find.descendant(of: find.byType(AppBar), matching: find.text('Obra')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'UX-629: Para mí on a shared project whose only task is someone else’s says No hay tareas que coincidan and Prueba otra palabra o filtro., not Un nuevo comienzo',
    (tester) async {
      await openProject(
        tester,
        projects: [
          TaskListInfo(
            id: 'p1',
            name: 'Obra',
            version: 2,
            shared: true,
            role: 'editor',
            ownerId: 2,
            people: const [ana, me],
          ),
        ],
        tasks: [
          Task(
            id: 1,
            title: 'Pintar la valla',
            priority: 1,
            listId: 'p1',
            assignment: 'member',
            assigneeId: 2,
          ),
        ],
      );
      expect(find.widgetWithText(TaskTile, 'Pintar la valla'), findsOneWidget);
      await tester.tap(find.widgetWithText(ChoiceChip, es.forMe));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(TaskTile, 'Pintar la valla'), findsNothing);
      final empty = find.byType(EmptyState);
      expect(
        find.descendant(of: empty, matching: find.text(es.noMatches)),
        findsOneWidget,
      );
      expect(
        find.descendant(of: empty, matching: find.text(es.differentFilter)),
        findsOneWidget,
      );
      expect(find.text(es.freshStart), findsNothing);
      expect(find.text(es.listEmpty), findsNothing);
      // Todas again shows the task.
      await tester.tap(find.widgetWithText(ChoiceChip, es.forTeam));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(TaskTile, 'Pintar la valla'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'UX-625: at 2x text on 320x568 in Catalan the empty view-only project page shows its sentence and the read-only line without overflow',
    (tester) async {
      final ca = lookupAppLocalizations(const Locale('ca'));
      await openProject(
        tester,
        projects: [viewerProject()],
        language: 'ca',
        size: const Size(320, 568),
        scale: 2,
      );
      expect(tester.takeException(), isNull, reason: 'no overflow');
      final page = tester.getRect(find.byType(NestedScrollView));
      final message = find.text(ca.readOnlyListEmpty, skipOffstage: false);
      expect(message, findsOneWidget);
      // The scope chips sit above the empty state. Scrolling the page in
      // small steps, the sentence's first line and its last line each come
      // into the visible page between the app bar and the read-only bar.
      var firstLineSeen = false;
      var lastLineSeen = false;
      for (var step = 0; step < 30; step++) {
        final rect = tester.getRect(message);
        expect(rect.left, greaterThanOrEqualTo(0));
        expect(rect.right, lessThanOrEqualTo(320));
        if (rect.top >= page.top && rect.top < page.bottom) {
          firstLineSeen = true;
        }
        if (rect.bottom <= page.bottom && rect.bottom > page.top) {
          lastLineSeen = true;
        }
        await tester.dragFrom(Offset(8, page.bottom - 8), const Offset(0, -40));
        await tester.pumpAndSettle();
      }
      expect(firstLineSeen, isTrue, reason: 'its first line can be read');
      expect(lastLineSeen, isTrue, reason: 'its last line can be read');
      final line = find.text(ca.readOnlyList);
      expect(line, findsOneWidget);
      final lineRect = tester.getRect(line);
      expect(lineRect.left, greaterThanOrEqualTo(0));
      expect(lineRect.right, lessThanOrEqualTo(320));
      expect(lineRect.bottom, lessThanOrEqualTo(568));
      expect(find.text(ca.listEmpty), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  // ---- Round 3 (b9) · P116: a project that's gone shows read-only again ----

  testWidgets(
    'UX-630: a project page whose lists settled without p1 shows Este proyecto es de solo lectura and Este proyecto aún no tiene tareas., never Añadir tarea',
    (tester) async {
      final container = await openProject(
        tester,
        projects: [TaskListInfo(id: 'other', name: 'Casa')],
      );
      final lists = container.read(taskListsProvider);
      expect(lists.isLoading, isFalse);
      expect(lists.hasValue, isTrue);
      expect(find.text(es.readOnlyList), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(EmptyState),
          matching: find.text(es.readOnlyListEmpty),
        ),
        findsOneWidget,
      );
      expect(find.text(es.addTask), findsNothing);
      expect(find.byType(TaskActions), findsNothing);
      expect(find.text(es.listEmpty), findsNothing);
      // The fallback title, since the project's name is gone too.
      expect(
        find.descendant(of: find.byType(AppBar), matching: find.text(es.list)),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'UX-630: a project page open while p1 is editable shows Añadir tarea; after the lists reload without p1 it shows Este proyecto es de solo lectura and no Añadir tarea',
    (tester) async {
      tester.view.physicalSize = const Size(360, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final casa = TaskListInfo(id: 'other', name: 'Casa');
      final obra = TaskListInfo(id: 'p1', name: 'Obra');
      var current = [casa, obra];
      final container = designContainer(
        tasks: () => _GivenTasks(const []),
        loadProjects: () async => current,
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        _app(container, const HomeScreen(listId: 'p1', isRoot: false), 'es'),
      );
      await tester.pumpAndSettle();
      expect(find.text(es.addTask), findsOneWidget);
      expect(find.byType(TaskActions), findsOneWidget);
      expect(find.text(es.readOnlyList), findsNothing);

      // The user is removed from the project on another device.
      current = [casa];
      container.invalidate(taskListsProvider);
      await tester.pumpAndSettle();
      expect(container.read(taskListsProvider).isLoading, isFalse);
      expect(find.text(es.readOnlyList), findsOneWidget);
      expect(find.text(es.readOnlyListEmpty), findsOneWidget);
      expect(find.text(es.addTask), findsNothing);
      expect(find.byType(TaskActions), findsNothing);
      expect(find.text(es.listEmpty), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'UX-630: at 2x text on 320x568 in Catalan the settled-without-p1 page shows Aquest projecte és de només lectura and Aquest projecte encara no té tasques. without overflow, and no Afegeix una tasca',
    (tester) async {
      final ca = lookupAppLocalizations(const Locale('ca'));
      expect(ca.readOnlyList, 'Aquest projecte és de només lectura');
      await openProject(
        tester,
        projects: [TaskListInfo(id: 'other', name: 'Casa')],
        language: 'ca',
        size: const Size(320, 568),
        scale: 2,
      );
      expect(tester.takeException(), isNull, reason: 'no overflow');
      expect(
        find.text(ca.readOnlyListEmpty, skipOffstage: false),
        findsOneWidget,
      );
      final line = find.text(ca.readOnlyList);
      expect(line, findsOneWidget);
      final lineRect = tester.getRect(line);
      expect(lineRect.left, greaterThanOrEqualTo(0));
      expect(lineRect.right, lessThanOrEqualTo(320));
      expect(lineRect.bottom, lessThanOrEqualTo(568));
      expect(find.text(ca.addTask, skipOffstage: false), findsNothing);
      expect(find.byType(TaskActions, skipOffstage: false), findsNothing);
      expect(find.text(ca.listEmpty, skipOffstage: false), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}

class _NoTasks extends DesignTaskNotifier {
  @override
  Future<void> loadTasks() async {
    state = const AsyncData(<Task>[]);
  }
}

class _GivenTasks extends DesignTaskNotifier {
  _GivenTasks(this.initial);
  final List<Task> initial;
  @override
  Future<void> loadTasks() async {
    if (!state.hasValue) state = AsyncData(initial);
  }
}
