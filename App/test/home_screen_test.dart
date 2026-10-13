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
