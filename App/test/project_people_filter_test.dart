// 2026-10-18 (later), voice-commands plan item 8: a shared project's page
// filters by person in one row of chips, «Todas · Para mí · Ana · Paul…»,
// in place of «Para mí» and «Todas». People come from the project's people
// list; a personal project shows nothing.
import 'package:agenda/l10n/generated/app_localizations.dart';
import 'package:agenda/models/task.dart';
import 'package:agenda/models/task_list_info.dart';
import 'package:agenda/providers/regional_provider.dart';
import 'package:agenda/providers/task_lists_provider.dart';
import 'package:agenda/screens/home_screen.dart';
import 'package:agenda/widgets/project_scope_control.dart';
import 'package:agenda/widgets/task_tile.dart';
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
          locale: Locale(language),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
          home: HomeScreen(isRoot: false, listId: id),
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
    'a shared project with 2 or more people shows one row: Todas · Para mí · Ana · Paul, in that order, with no chip for a viewer; Todas is chosen and lists every task',
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
      // All the chips sit on one line.
      final tops = {
        for (final key in ['people-all', 'people-me', 'people-2', 'people-3'])
          tester.getRect(chip(key)).top,
      };
      expect(tops, hasLength(1));
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
    'someone with nothing assigned: the page says No hay coincidencias and to try another filter',
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
      expect(find.text(es.noMatches), findsOneWidget);
      expect(find.text(es.differentFilter), findsOneWidget);
      expect(tester.takeException(), isNull);
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
}

class _Given extends DesignTaskNotifier {
  _Given(this.initial);
  final List<Task> initial;
  @override
  Future<void> loadTasks() async {
    if (!state.hasValue) state = AsyncData(initial);
  }
}
