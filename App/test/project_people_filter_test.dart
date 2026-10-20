// 2026-10-18 (later), voice-commands plan item 8: a shared project's page
// filters by person in one row of chips, «Todas · Para mí · Ana · Paul…»,
// in place of «Para mí» and «Todas». People come from the project's people
// list; a personal project shows nothing.
//
// 2026-10-18-commands, P131 (UX-1101): the chips wrap onto two rows, and
// Tareas completadas moved into the app bar to pay for the second row.
// Before the change, the first task row's top on a shared project page with
// two tasks and «Ana» and «Paul» as other editors, ES, Manrope (AppTheme.light):
//   2× text on 320×640: 420.0 dp
//   1.3× text on 393×851: 393.0 dp
// After it: 418.0 dp (two chip rows) and 329.0 dp (one row) — no lower.
//
// 2026-10-18-commands, P145 (UX-1214): the chosen chip shows ✓ again, and
// every chip in the people row and the «Todas»/«Para mí» pair has 4 dp side
// padding (Material's is 8) to pay for it. Manrope, 2× text on 320 dp, the
// selected «Todas» + 8 + «Para mí», against the 272 dp the page leaves:
//   ES «Todas» + «Para mí»: 147.1 + 8 + 125.9 = 281.0 dp with Material's
//     padding; 139.1 + 8 + 117.9 = 265.0 dp with 4 dp — fits.
//   CA «Totes» + «Per a mi»: 141.9 + 8 + 132.8 = 282.7 dp with Material's
//     padding; 133.9 + 8 + 124.8 = 266.7 dp with 4 dp — fits.
import 'package:agenda/l10n/generated/app_localizations.dart';
import 'package:agenda/models/task.dart';
import 'package:agenda/models/task_list_info.dart';
import 'package:agenda/providers/regional_provider.dart';
import 'package:agenda/providers/task_lists_provider.dart';
import 'package:agenda/screens/calendar_screen.dart';
import 'package:agenda/screens/completed_tasks_screen.dart';
import 'package:agenda/screens/home_screen.dart';
import 'package:agenda/theme/app_theme.dart';
import 'package:agenda/widgets/project_scope_control.dart';
import 'package:agenda/widgets/task_tile.dart';
import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/capture_fixtures.dart' show captureSheetOverrides;
import 'support/design_fixtures.dart';

final es = lookupAppLocalizations(const Locale('es'));
final ca = lookupAppLocalizations(const Locale('ca'));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final platform =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const timeoutChannel = MethodChannel('taskflow/accessibility');
  setUp(
    () => platform.setMockMethodCallHandler(timeoutChannel, (_) async => null),
  );
  tearDown(() => platform.setMockMethodCallHandler(timeoutChannel, null));

  // The signed-in fixture account is 1: Miki, who owns the project.
  const miki = ProjectMember(id: 1, name: 'Miki', role: 'owner');
  const ana = ProjectMember(id: 2, name: 'Ana', role: 'editor');
  const paul = ProjectMember(id: 3, name: 'Paul', role: 'editor');
  const vera = ProjectMember(id: 4, name: 'Vera', role: 'viewer');

  TaskListInfo familia({
    List<ProjectMember> people = const [miki, ana, paul, vera],
  }) => TaskListInfo(
    id: 'familia',
    name: 'Familia',
    version: 1,
    shared: true,
    role: 'owner',
    ownerId: 1,
    people: people,
  );

  List<Task> tasks() => [
    Task(
      id: 1,
      title: 'Comprar pan',
      priority: 1,
      listId: 'familia',
      assignment: 'group',
    ),
    Task(
      id: 2,
      title: 'Recoger a los niños',
      priority: 1,
      listId: 'familia',
      assignment: 'member',
      assigneeId: 2,
      assigneeName: 'Ana',
    ),
    Task(
      id: 3,
      title: 'Pagar la luz',
      priority: 1,
      listId: 'familia',
      assignment: 'member',
      assigneeId: 3,
      assigneeName: 'Paul',
    ),
    Task(
      id: 4,
      title: 'Llamar al fontanero',
      priority: 1,
      listId: 'familia',
      assignment: 'member',
      assigneeId: 1,
      assigneeName: 'Miki',
    ),
  ];

  /// The page of project [id], with [projects] (read from [load] when
  /// given, to change them later) and [tasks].
  Future<ProviderContainer> openProject(
    WidgetTester tester, {
    List<TaskListInfo>? projects,
    Future<List<TaskListInfo>> Function()? load,
    String id = 'familia',
    List<Task>? given,
    String language = 'es',
    Size size = const Size(390, 844),
    double textScale = 1,
    // The app's own theme (Manrope), where a test measures.
    ThemeData? theme,
    // Another screen instead of the project's page.
    Widget? home,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final container = designContainer(
      regionalStore: MemoryRegionalStore(
        RegionalPreferences(language: language),
      ),
      projects: projects ?? [familia()],
      loadProjects: load,
      tasks: () => _Given(given ?? tasks()),
      overrides: captureSheetOverrides(),
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: theme,
          routes: {'/completedTasks': (_) => const CompletedTasksScreen()},
          locale: Locale(language),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
          home: home ?? HomeScreen(isRoot: false, listId: id),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  Finder row() => find.byKey(const ValueKey('people-filter'));
  Finder chip(String key) => find.byKey(ValueKey(key));
  bool chosen(WidgetTester tester, String key) =>
      tester.widget<ChoiceChip>(chip(key)).selected;

  /// The task titles the page lists, top to bottom.
  List<String> listed(WidgetTester tester) {
    final tiles = tester.widgetList<TaskTile>(find.byType(TaskTile)).toList();
    return [for (final tile in tiles) tile.task.title];
  }

  Future<void> choose(WidgetTester tester, String key) async {
    await tester.ensureVisible(chip(key));
    await tester.pumpAndSettle();
    await tester.tap(chip(key));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'a shared project with 2 or more people shows Todas · Para mí · Ana · Paul, in that order, with no chip for a viewer; Todas is chosen and lists every task',
    (tester) async {
      await openProject(tester);
      expect(row(), findsOneWidget);
      final labels = [
        for (final widget in tester.widgetList<ChoiceChip>(
          find.descendant(of: row(), matching: find.byType(ChoiceChip)),
        ))
          widget.key,
      ];
      expect(labels, const [
        ValueKey('people-all'),
        ValueKey('people-me'),
        ValueKey('people-2'),
        ValueKey('people-3'),
      ]);
      expect(
        find.descendant(of: row(), matching: find.text(es.forTeam)),
        findsOneWidget,
      );
      expect(
        find.descendant(of: row(), matching: find.text(es.forMe)),
        findsOneWidget,
      );
      expect(
        find.descendant(of: row(), matching: find.text('Ana')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: row(), matching: find.text('Paul')),
        findsOneWidget,
      );
      expect(find.text('Vera'), findsNothing, reason: 'a viewer has no tasks');
      expect(find.text('Miki'), findsNothing, reason: 'that is Para mí');
      // The row replaces the two chips: Para mí and Todas show once.
      expect(find.widgetWithText(ChoiceChip, es.forMe), findsOneWidget);
      expect(find.widgetWithText(ChoiceChip, es.forTeam), findsOneWidget);
      expect(chosen(tester, 'people-all'), isTrue);
      expect(listed(tester), hasLength(4));
      // Every chip shows on the screen, without a drag.
      for (final key in ['people-all', 'people-me', 'people-2', 'people-3']) {
        expect(chip(key).hitTestable(), findsOneWidget);
        expect(tester.getRect(chip(key)).right, lessThanOrEqualTo(390.5));
      }
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Ana shows only the tasks assigned to Ana; Paul only his; Para mí the account’s and everyone’s; Todas every task again',
    (tester) async {
      await openProject(tester);
      await choose(tester, 'people-2');
      expect(chosen(tester, 'people-2'), isTrue);
      expect(chosen(tester, 'people-all'), isFalse);
      expect(listed(tester), ['Recoger a los niños']);

      await choose(tester, 'people-3');
      expect(chosen(tester, 'people-3'), isTrue);
      expect(chosen(tester, 'people-2'), isFalse);
      expect(listed(tester), ['Pagar la luz']);

      await choose(tester, 'people-me');
      expect(chosen(tester, 'people-me'), isTrue);
      expect(chosen(tester, 'people-3'), isFalse);
      expect(
        listed(tester),
        unorderedEquals(['Comprar pan', 'Llamar al fontanero']),
      );

      await choose(tester, 'people-all');
      expect(chosen(tester, 'people-all'), isTrue);
      expect(listed(tester), hasLength(4));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'someone with nothing assigned: the page says they have nothing open here and to tap Todas',
    (tester) async {
      await openProject(
        tester,
        projects: [
          familia(
            people: const [
              miki,
              ana,
              ProjectMember(id: 5, name: 'Marta', role: 'editor'),
            ],
          ),
        ],
      );
      await choose(tester, 'people-5');
      expect(listed(tester), isEmpty);
      expect(find.text(es.personNothingOpen('Marta')), findsOneWidget);
      expect(find.text(es.personNothingOpenHelp), findsOneWidget);
      expect(find.text(es.noMatches), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  // ---- Run 2026-10-18-commands, b3 · P142 (UX-1109): an empty person's
  // view says why, not «No hay tareas que coincidan» ----

  for (final (language, l, nothing, help) in [
    (
      'es',
      es,
      'Marta no tiene tareas pendientes aquí',
      'Toca Todas para ver todas las tareas.',
    ),
    (
      'ca',
      ca,
      'Marta no té tasques pendents aquí',
      'Toca Totes per veure totes les tasques.',
    ),
  ]) {
    testWidgets(
      'UX-1109: on a shared project’s page, tapping Marta, who has nothing open, says «$nothing» and «$help» ($language); with «pan» searched it says no task matches',
      (tester) async {
        expect(l.personNothingOpen('Marta'), nothing);
        expect(l.personNothingOpenHelp, help);
        await openProject(
          tester,
          language: language,
          projects: [
            familia(
              people: const [
                miki,
                ana,
                ProjectMember(id: 5, name: 'Marta', role: 'editor'),
              ],
            ),
          ],
        );
        await choose(tester, 'people-5');
        expect(chosen(tester, 'people-5'), isTrue);
        expect(listed(tester), isEmpty);
        expect(find.text(nothing), findsOneWidget);
        expect(find.text(help), findsOneWidget);
        expect(find.text(l.noMatches), findsNothing);
        expect(find.text(l.differentFilter), findsNothing);

        final search = find.widgetWithText(TextField, l.findTask);
        expect(search, findsOneWidget);
        await tester.enterText(search, 'pan');
        await tester.pumpAndSettle();
        expect(listed(tester), isEmpty);
        expect(find.text(l.noMatches), findsOneWidget);
        expect(find.text(l.differentFilter), findsOneWidget);
        expect(find.text(nothing), findsNothing);
        expect(find.text(help), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  test(
    'UX-1109: the empty person view reads “{name} has nothing open here” / “Tap All to see every task.” in English, and the search lines are unchanged in Spanish',
    () {
      final en = lookupAppLocalizations(const Locale('en'));
      expect(en.personNothingOpen('Marta'), 'Marta has nothing open here');
      expect(en.personNothingOpenHelp, 'Tap All to see every task.');
      expect(es.noMatches, 'No hay tareas que coincidan');
      expect(es.differentFilter, 'Prueba otra palabra o filtro.');
    },
  );

  testWidgets(
    'a personal project shows no chips at all; a shared project with only the account keeps today’s Para mí and Todas, and no people row',
    (tester) async {
      await openProject(
        tester,
        id: 'casa',
        projects: [TaskListInfo(id: 'casa', name: 'Casa', version: 1)],
        given: [Task(id: 9, title: 'Regar', priority: 1, listId: 'casa')],
      );
      expect(row(), findsNothing);
      expect(find.byType(ChoiceChip), findsNothing);
      expect(find.text(es.forMe), findsNothing);
      await tester.pumpWidget(const SizedBox());

      await openProject(
        tester,
        projects: [
          familia(people: const [miki]),
        ],
      );
      expect(row(), findsNothing);
      expect(find.widgetWithText(ChoiceChip, es.forMe), findsOneWidget);
      expect(find.widgetWithText(ChoiceChip, es.forTeam), findsOneWidget);
      expect(find.byType(ChoiceChip), findsNWidgets(2));
      expect(chip('people-2'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'when the chosen person leaves the project, their chip goes and the page lists every task',
    (tester) async {
      var projects = [familia()];
      final container = await openProject(tester, load: () async => projects);
      await choose(tester, 'people-2');
      expect(listed(tester), ['Recoger a los niños']);
      projects = [
        familia(people: const [miki, paul]),
      ];
      container.invalidate(taskListsProvider);
      await tester.pumpAndSettle();
      expect(chip('people-2'), findsNothing);
      expect(chosen(tester, 'people-all'), isTrue);
      expect(listed(tester), hasLength(4));
      expect(tester.takeException(), isNull);
    },
  );

  test(
    'the chips read Todas · Para mí in Spanish and Totes · Per a mi in Catalan',
    () {
      expect(es.forTeam, 'Todas');
      expect(es.forMe, 'Para mí');
      expect(ca.forTeam, 'Totes');
      expect(ca.forMe, 'Per a mi');
    },
  );

  test(
    'projectPeopleToFilter: the others who can be given tasks, only in a project shared with 2 or more people',
    () {
      expect(projectPeopleToFilter(null, 1), isEmpty);
      expect(
        projectPeopleToFilter(TaskListInfo(id: 'casa', name: 'Casa'), 1),
        isEmpty,
      );
      expect(projectPeopleToFilter(familia(people: const [miki]), 1), isEmpty);
      expect(projectPeopleToFilter(familia(), 1).map((p) => p.name), [
        'Ana',
        'Paul',
      ]);
      expect(
        projectPeopleToFilter(familia(people: const [miki, vera]), 1),
        isEmpty,
        reason: 'a viewer is never assigned',
      );
    },
  );

  for (final language in ['es', 'ca']) {
    testWidgets(
      'at 2× text on 320 dp ($language), the people stay in one row that scrolls sideways, a long name is cut with …, and nothing overflows',
      (tester) async {
        final l = lookupAppLocalizations(Locale(language));
        await openProject(
          tester,
          language: language,
          size: const Size(320, 640),
          textScale: 2,
          projects: [
            familia(
              people: const [
                miki,
                ana,
                paul,
                ProjectMember(
                  id: 6,
                  name: 'Maria Antònia Ferrer i Puigdollers',
                  role: 'editor',
                ),
              ],
            ),
          ],
        );
        expect(row(), findsOneWidget);
        final keys = [
          'people-all',
          'people-me',
          'people-2',
          'people-3',
          'people-6',
        ];
        final first = tester.getRect(chip(keys.first));
        final rowRect = tester.getRect(row());
        expect(rowRect.left, greaterThanOrEqualTo(0));
        expect(rowRect.right, lessThanOrEqualTo(320.5));
        // One chip high: no second line.
        expect(rowRect.height, lessThanOrEqualTo(first.height + 0.5));
        expect(
          find.descendant(of: row(), matching: find.text(l.forTeam)),
          findsOneWidget,
        );
        // The last chip is reached by scrolling the row, not the page.
        await tester.drag(row(), const Offset(-2000, 0));
        await tester.pumpAndSettle();
        final last = tester.getRect(chip('people-6'));
        expect(last.right, lessThanOrEqualTo(320.5));
        expect(last.left, greaterThanOrEqualTo(-0.5));
        final name = find.descendant(
          of: chip('people-6'),
          matching: find.byType(RichText),
        );
        expect(
          tester.renderObject<RenderParagraph>(name).didExceedMaxLines,
          isTrue,
          reason: 'cut with …',
        );
        await tester.tap(chip('people-6'));
        await tester.pumpAndSettle();
        expect(chosen(tester, 'people-6'), isTrue);
        expect(tester.takeException(), isNull, reason: 'no overflow');
      },
    );
  }

  // ---- Run 2026-10-18-commands, P131: UX-1101, UX-1108, UX-1110 ----

  /// The first two ChoiceChips on screen, by their text, top to bottom.
  List<String> firstTwoChips(WidgetTester tester) {
    final chips = find.byType(ChoiceChip);
    return [
      for (var i = 0; i < 2; i++)
        tester
            .widgetList<Text>(
              find.descendant(of: chips.at(i), matching: find.byType(Text)),
            )
            .map((text) => text.data ?? '')
            .join(),
    ];
  }

  for (final language in ['es', 'ca']) {
    final l = lookupAppLocalizations(Locale(language));
    testWidgets(
      'UX-1108: Todas first, then Para mí, on Calendar, on the Tareas root, on a shared project whose others are viewers, and on one with two other editors ($language)',
      (tester) async {
        await openProject(
          tester,
          language: language,
          home: const CalendarScreen(),
        );
        expect(firstTwoChips(tester), [l.forTeam, l.forMe]);
        await tester.pumpWidget(const SizedBox());

        await openProject(tester, language: language, home: const HomeScreen());
        expect(firstTwoChips(tester), [l.forTeam, l.forMe]);
        await tester.pumpWidget(const SizedBox());

        await openProject(
          tester,
          language: language,
          projects: [
            familia(people: const [miki, vera]),
          ],
        );
        expect(row(), findsNothing);
        expect(firstTwoChips(tester), [l.forTeam, l.forMe]);
        await tester.pumpWidget(const SizedBox());

        await openProject(tester, language: language);
        expect(firstTwoChips(tester), [l.forTeam, l.forMe]);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'UX-1108: the chips read Todas and Para mí in Spanish, Totes and Per a mi in Catalan',
    (tester) async {
      expect([es.forTeam, es.forMe], ['Todas', 'Para mí']);
      expect([ca.forTeam, ca.forMe], ['Totes', 'Per a mi']);
    },
  );

  testWidgets(
    'UX-1110: Ana’s chip is named «Tareas de Ana»-style for TalkBack and reports selected once tapped; the people row’s Todas is «Todas las tareas»; the visible text doesn’t change',
    (tester) async {
      final semantics = tester.ensureSemantics();
      await openProject(tester);
      SemanticsFinder named(String label) => find.semantics.byPredicate(
        (node) => node.label == label || node.label.startsWith('$label\n'),
      );
      SemanticsData chipData(String key) =>
          tester.getSemantics(chip(key)).getSemanticsData();
      expect(chipData('people-2').label, es.commandFindPerson('Ana'));
      expect(chipData('people-all').label, es.allTasks);
      expect(es.allTasks, 'Todas las tareas');
      expect(named(es.commandFindPerson('Ana')), findsOne);
      expect(named(es.commandFindPerson('Paul')), findsOne);
      expect(
        chipData('people-2').flagsCollection.isSelected,
        isNot(Tristate.isTrue),
      );
      expect(
        chipData('people-all').flagsCollection.isSelected,
        Tristate.isTrue,
      );
      // What shows stays the same.
      expect(
        find.descendant(of: chip('people-2'), matching: find.text('Ana')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: chip('people-all'),
          matching: find.text(es.forTeam),
        ),
        findsOneWidget,
      );
      await choose(tester, 'people-2');
      expect(chipData('people-2').flagsCollection.isSelected, Tristate.isTrue);
      expect(chipData('people-2').label, es.commandFindPerson('Ana'));
      expect(
        chipData('people-all').flagsCollection.isSelected,
        isNot(Tristate.isTrue),
      );
      expect(tester.takeException(), isNull);
      semantics.dispose();
    },
  );

  testWidgets(
    'UX-1101: on a project page Tareas completadas is an app-bar action that opens Tareas completadas, and no header row holds only that button',
    (tester) async {
      await openProject(tester);
      final completed = find.byTooltip(es.completedTasks);
      expect(completed, findsOneWidget);
      expect(
        find.ancestor(of: completed, matching: find.byType(AppBar)),
        findsOneWidget,
      );
      expect(es.completedTasks, 'Tareas completadas');
      await tester.tap(completed);
      await tester.pumpAndSettle();
      expect(find.byType(CompletedTasksScreen), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(CompletedTasksScreen),
          matching: find.text(es.completedTasks),
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'UX-1101: an archived project still says it is archived, outside the app bar, with ✓ in the app bar',
    (tester) async {
      await openProject(
        tester,
        projects: [
          TaskListInfo(
            id: 'familia',
            name: 'Familia',
            version: 1,
            shared: true,
            role: 'owner',
            ownerId: 1,
            archived: true,
            people: const [miki, ana, paul],
          ),
        ],
      );
      expect(find.text(es.archivedListAddHelp), findsOneWidget);
      expect(
        es.archivedListAddHelp,
        'Proyecto archivado. Restáuralo para añadir tareas.',
      );
      expect(
        find.ancestor(
          of: find.text(es.archivedListAddHelp),
          matching: find.byType(AppBar),
        ),
        findsNothing,
      );
      expect(
        find.ancestor(
          of: find.byTooltip(es.completedTasks),
          matching: find.byType(AppBar),
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'UX-1101: on the root Tareas page «Completadas» is still beside «Proyectos», not in the app bar',
    (tester) async {
      await openProject(tester, home: const HomeScreen());
      final completed = find.widgetWithText(TextButton, es.completedButton);
      expect(completed, findsOneWidget);
      expect(
        find.ancestor(of: completed, matching: find.byType(AppBar)),
        findsNothing,
      );
      final projects = find.widgetWithText(TextButton, es.lists);
      expect(projects, findsOneWidget);
      final button = tester.getRect(completed);
      final link = tester.getRect(projects);
      expect(button.center.dy, closeTo(link.center.dy, 4));
      expect(button.left, greaterThanOrEqualTo(link.right - 1));
      expect(tester.takeException(), isNull);
    },
  );

  // ---- Run 2026-10-18-commands, round 2, P145: UX-1214 ----

  /// Every ChoiceChip in the «Todas»/«Para mí» pair on Calendar.
  List<ChoiceChip> pairChips(WidgetTester tester) => tester
      .widgetList<ChoiceChip>(
        find.descendant(
          of: find.byType(ProjectScopeControl),
          matching: find.byType(ChoiceChip),
        ),
      )
      .toList();

  const sharedPadding = EdgeInsets.symmetric(horizontal: 4, vertical: 8);

  testWidgets(
    'UX-1214: every chip in the people row and the Todas/Para mí pair on Calendar keeps Material’s ✓; tapping Ana widens her chip by the ✓ that leaves Todas',
    (tester) async {
      await openProject(
        tester,
        projects: [
          familia(people: const [miki, ana, paul]),
        ],
      );
      const keys = ['people-all', 'people-me', 'people-2', 'people-3'];
      for (final key in keys) {
        expect(
          tester.widget<ChoiceChip>(chip(key)).showCheckmark,
          anyOf(isNull, isTrue),
          reason: key,
        );
      }
      final allBefore = tester.getSize(chip('people-all')).width;
      final anaBefore = tester.getSize(chip('people-2')).width;
      expect(chosen(tester, 'people-all'), isTrue);
      await tester.tap(chip('people-2'));
      await tester.pumpAndSettle();
      expect(chosen(tester, 'people-2'), isTrue);
      expect(chosen(tester, 'people-all'), isFalse);
      final allAfter = tester.getSize(chip('people-all')).width;
      final anaAfter = tester.getSize(chip('people-2')).width;
      // Material paints the ✓ inside the chosen chip; it isn't an Icon.
      final mark = allBefore - allAfter;
      expect(mark, greaterThan(8), reason: 'Todas lost its ✓');
      expect(anaAfter - anaBefore, closeTo(mark, 0.5), reason: 'Ana got it');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());

      await openProject(tester, home: const CalendarScreen());
      final pair = pairChips(tester);
      expect(pair, hasLength(2));
      for (final chip in pair) {
        expect(chip.showCheckmark, anyOf(isNull, isTrue));
      }
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'UX-1214: the people row’s chips and the pair’s chips on Calendar all have padding EdgeInsets.symmetric(horizontal: 4, vertical: 8)',
    (tester) async {
      await openProject(
        tester,
        projects: [
          familia(people: const [miki, ana, paul]),
        ],
      );
      for (final key in ['people-all', 'people-me', 'people-2', 'people-3']) {
        expect(
          tester.widget<ChoiceChip>(chip(key)).padding,
          sharedPadding,
          reason: key,
        );
      }
      await tester.pumpWidget(const SizedBox());
      await openProject(tester, home: const CalendarScreen());
      final pair = pairChips(tester);
      expect(pair, hasLength(2));
      for (final chip in pair) {
        expect(chip.padding, sharedPadding);
      }
      expect(tester.takeException(), isNull);
    },
  );

  // Manrope from here on, as on the phone: the tests above measure with
  // the test font.
  group('UX-1101 with Manrope', () {
    setUpAll(() async {
      await (FontLoader(
        'Manrope',
      )..addFont(rootBundle.load('assets/fonts/Manrope.ttf'))).load();
      await (FontLoader(
        'MaterialIcons',
      )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    });

    List<Task> twoTasks() => [
      Task(
        id: 1,
        title: 'Comprar pan',
        priority: 1,
        listId: 'familia',
        assignment: 'group',
      ),
      Task(
        id: 2,
        title: 'Recoger a los niños',
        priority: 1,
        listId: 'familia',
        assignment: 'member',
        assigneeId: 2,
        assigneeName: 'Ana',
      ),
    ];

    for (final language in ['es', 'ca']) {
      for (final (size, scale, people) in [
        (
          const Size(393, 851),
          1.3,
          const [
            miki,
            ProjectMember(id: 2, name: 'Ana García', role: 'editor'),
            paul,
          ],
        ),
        (const Size(320, 640), 2.0, const [miki, ana, paul]),
      ]) {
        testWidgets(
          'UX-1101: at $scale× on ${size.width.toInt()}×${size.height.toInt()} ($language), with ${people[1].name} and Paul, every person chip is hit-testable and wholly on screen, with no drag',
          (tester) async {
            await openProject(
              tester,
              language: language,
              size: size,
              textScale: scale,
              theme: AppTheme.light,
              projects: [familia(people: people)],
              given: twoTasks(),
            );
            expect(row(), findsOneWidget);
            for (final key in [
              'people-all',
              'people-me',
              'people-2',
              'people-3',
            ]) {
              expect(chip(key).hitTestable(), findsOneWidget, reason: key);
              final rect = tester.getRect(chip(key));
              expect(rect.left, greaterThanOrEqualTo(-0.5), reason: key);
              expect(
                rect.right,
                lessThanOrEqualTo(size.width + 0.5),
                reason: key,
              );
              expect(rect.top, greaterThanOrEqualTo(-0.5), reason: key);
              expect(
                rect.bottom,
                lessThanOrEqualTo(size.height + 0.5),
                reason: key,
              );
            }
            expect(tester.takeException(), isNull);
          },
        );

        testWidgets(
          'UX-1214: at $scale× on ${size.width.toInt()}×${size.height.toInt()} ($language), with ${people[1].name} and Paul, Todas chosen and again Paul chosen (✓ on each): every person chip is hit-testable and wholly on screen, with no drag',
          (tester) async {
            await openProject(
              tester,
              language: language,
              size: size,
              textScale: scale,
              theme: AppTheme.light,
              projects: [familia(people: people)],
              given: twoTasks(),
            );
            expect(row(), findsOneWidget);
            final scrollable = tester.state<ScrollableState>(
              find.descendant(of: row(), matching: find.byType(Scrollable)),
            );
            void allOnScreen(String state) {
              expect(scrollable.position.pixels, 0, reason: state);
              for (final key in [
                'people-all',
                'people-me',
                'people-2',
                'people-3',
              ]) {
                final why = '$key, $state';
                final shown = tester.widget<ChoiceChip>(chip(key));
                expect(shown.showCheckmark, anyOf(isNull, isTrue), reason: why);
                expect(chip(key).hitTestable(), findsOneWidget, reason: why);
                final rect = tester.getRect(chip(key));
                expect(rect.left, greaterThanOrEqualTo(-0.5), reason: why);
                expect(
                  rect.right,
                  lessThanOrEqualTo(size.width + 0.5),
                  reason: why,
                );
                expect(rect.top, greaterThanOrEqualTo(-0.5), reason: why);
                expect(
                  rect.bottom,
                  lessThanOrEqualTo(size.height + 0.5),
                  reason: why,
                );
              }
            }

            expect(chosen(tester, 'people-all'), isTrue);
            allOnScreen('Todas chosen');
            // No ensureVisible, no drag: Paul's chip is tapped where it is.
            await tester.tap(chip('people-3'));
            await tester.pumpAndSettle();
            expect(chosen(tester, 'people-3'), isTrue);
            allOnScreen('Paul chosen');
            expect(tester.takeException(), isNull);
          },
        );
      }
    }

    // The tops P131's implementer measured before the change, recorded at
    // the top of this file: 2× on 320×640, 420.0 dp; 1.3× on 393×851,
    // 393.0 dp.
    for (final (size, scale, before) in [
      (const Size(320, 640), 2.0, 420.0),
      (const Size(393, 851), 1.3, 393.0),
    ]) {
      testWidgets(
        'UX-1101: ES, Manrope, a shared project page with two tasks and Ana and Paul: at $scale× on ${size.width.toInt()}×${size.height.toInt()} the first task row’s top is no lower than before the change ($before dp)',
        (tester) async {
          await openProject(
            tester,
            size: size,
            textScale: scale,
            theme: AppTheme.light,
            projects: [
              familia(people: const [miki, ana, paul]),
            ],
            given: twoTasks(),
          );
          final first = find.byType(TaskTile).first;
          expect(first, findsOneWidget);
          final top = tester.getRect(first).top;
          expect(top, lessThanOrEqualTo(before + 0.5));
          expect(tester.takeException(), isNull);
        },
      );
    }

    testWidgets(
      'UX-1101: ES at 2× on 320×640 with 8 other editors, the people row scrolls sideways and the last chip it shows is cut at the screen’s right edge',
      (tester) async {
        final others = [
          for (final (id, name) in [
            (2, 'Ana'),
            (3, 'Paul'),
            (5, 'Marta'),
            (6, 'Jordi'),
            (7, 'Lucía'),
            (8, 'Pere'),
            (9, 'Núria'),
            (10, 'Carlos'),
          ])
            ProjectMember(id: id, name: name, role: 'editor'),
        ];
        await openProject(
          tester,
          size: const Size(320, 640),
          textScale: 2,
          theme: AppTheme.light,
          projects: [
            familia(people: [miki, ...others]),
          ],
          given: twoTasks(),
        );
        expect(row(), findsOneWidget);
        final scrollable = tester.state<ScrollableState>(
          find.descendant(of: row(), matching: find.byType(Scrollable)),
        );
        expect(scrollable.position.axis, Axis.horizontal);
        expect(scrollable.position.maxScrollExtent, greaterThan(0));
        final rects = [
          for (final key in [
            'people-all',
            'people-me',
            for (final person in others) 'people-${person.id}',
          ])
            tester.getRect(chip(key)),
        ];
        // One row.
        expect(rects.map((rect) => rect.top.round()).toSet(), hasLength(1));
        final cut = rects.where((rect) => rect.left < 320 && rect.right > 320);
        expect(cut, hasLength(1), reason: 'the next chip shows, cut');
        expect(tester.takeException(), isNull);
      },
    );
  });
}

class _Given extends DesignTaskNotifier {
  _Given(this.initial);
  final List<Task> initial;
  @override
  Future<void> loadTasks() async {
    if (!state.hasValue) state = AsyncData(initial);
  }
}
