// Run 2026-10-19-app, round 1 · P178: task rows on Calendar, Tareas and
// project pages: a named Cambiar fecha action, a view-only row as one button,
// no empty values, readable when lit, «Atrasada» in lists, no repeated
// project, a labelled assignee.
import 'dart:async';
import 'dart:math' as math;

import 'package:agenda/l10n/generated/app_localizations.dart';
import 'package:agenda/l10n/region.dart';
import 'package:agenda/main.dart';
import 'package:agenda/models/task.dart';
import 'package:agenda/models/task_list_info.dart';
import 'package:agenda/providers/regional_provider.dart';
import 'package:agenda/screens/calendar_screen.dart';
import 'package:agenda/screens/home_screen.dart';
import 'package:agenda/screens/task_detail_screen.dart';
import 'package:agenda/theme/app_theme.dart';
import 'package:agenda/widgets/task_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/design_fixtures.dart';
import 'ux_previews/support/fixtures.dart' as fx;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const timeoutChannel = MethodChannel('taskflow/accessibility');
  final platform =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  setUp(
    () => platform.setMockMethodCallHandler(timeoutChannel, (_) async => null),
  );
  tearDown(() => platform.setMockMethodCallHandler(timeoutChannel, null));
  setUpAll(() async {
    await (FontLoader(
      'Manrope',
    )..addFont(rootBundle.load('assets/fonts/Manrope.ttf'))).load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });

  final es = lookupAppLocalizations(const Locale('es'));
  final now = DateTime.now();
  DateTime on(int offset, [int hour = 0, int minute = 0]) =>
      DateTime(now.year, now.month, now.day + offset, hour, minute);

  /// Ana's «Coro», which this account (1) can only view.
  final choirToView = TaskListInfo(
    id: 'coro',
    name: 'Coro',
    color: 'rose',
    version: 1,
    role: 'viewer',
    shared: true,
    ownerId: fx.ana,
    people: const [
      ProjectMember(id: fx.ana, name: 'Ana', role: 'owner'),
      ProjectMember(id: fx.me, name: 'María', role: 'viewer'),
    ],
  );

  ProviderContainer containerFor(
    List<Task> tasks,
    List<TaskListInfo> projects, {
    String language = 'es',
  }) {
    final container = designContainer(
      tasks: () => _GivenTasks(tasks),
      projects: projects,
      hadTask: true,
      regionalStore: MemoryRegionalStore(
        RegionalPreferences(
          language: language,
          clock: ClockFormat.twentyFour,
          weekStart: 1,
        ),
      ),
    );
    addTearDown(container.dispose);
    return container;
  }

  void sized(WidgetTester tester, Size size, double scale) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    if (scale != 1) {
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    }
  }

  /// [home] alone, in a MaterialApp.
  Future<ProviderContainer> page(
    WidgetTester tester,
    Widget home, {
    required List<Task> tasks,
    List<TaskListInfo> projects = const [],
    Size size = const Size(390, 1400),
    double scale = 1,
    ThemeData? theme,
  }) async {
    sized(tester, size, scale);
    final container = containerFor(tasks, projects);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: theme ?? AppTheme.light,
          locale: const Locale('es'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
            child: child!,
          ),
          home: home,
        ),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  /// The whole app, on Calendar.
  Future<ProviderContainer> app(
    WidgetTester tester, {
    required List<Task> tasks,
    List<TaskListInfo> projects = const [],
    Size size = const Size(390, 1400),
    double scale = 1,
  }) async {
    sized(tester, size, scale);
    final container = containerFor(tasks, projects);
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const MyApp()),
    );
    await tester.pumpAndSettle();
    return container;
  }

  Finder row(String title) => find.widgetWithText(TaskTile, title);
  Finder inRow(String title, Finder finder) =>
      find.descendant(of: row(title), matching: finder);

  /// The semantics node that carries the row's tap.
  SemanticsNode rowNode(WidgetTester tester, String title) {
    var node = tester.getSemantics(row(title));
    // The row's own container node, or the first one above that taps.
    while (!node.getSemanticsData().hasAction(SemanticsAction.tap) &&
        node.parent != null) {
      node = node.parent!;
    }
    return node;
  }

  testWidgets(
    'UX-1416: an editable row’s TalkBack actions include «Cambiar fecha», and invoking it opens the move sheet',
    (tester) async {
      final semantics = tester.ensureSemantics();
      await page(
        tester,
        const HomeScreen(),
        tasks: [
          Task(id: 1, title: 'Comprar pan', priority: 1, dueDate: on(0, 18)),
        ],
      );
      expect(es.reschedule, 'Cambiar fecha');
      final node = rowNode(tester, 'Comprar pan');
      final data = node.getSemanticsData();
      final actions = [
        for (final id in data.customSemanticsActionIds ?? const <int>[])
          CustomSemanticsAction.getAction(id)!.label,
      ];
      expect(actions, contains(es.reschedule));
      final id = data.customSemanticsActionIds!.firstWhere(
        (id) => CustomSemanticsAction.getAction(id)!.label == es.reschedule,
      );
      tester.renderObject(row('Comprar pan')).owner!.semanticsOwner!.performAction(
        node.id,
        SemanticsAction.customAction,
        id,
      );
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsOneWidget, reason: 'move sheet');
      semantics.dispose();
    },
  );

  testWidgets(
    'UX-1416: a view-only row has no circle; TalkBack hears it as one button that starts «Comer con Ana, … 13:30», with no «Completar», and a tap opens the task',
    (tester) async {
      final semantics = tester.ensureSemantics();
      await page(
        tester,
        const HomeScreen(listId: 'coro', isRoot: false),
        projects: [choirToView],
        tasks: [
          Task(
            id: 76,
            title: 'Comer con Ana',
            dueDate: on(0, 13, 30),
            priority: 1,
            listId: 'coro',
            assignment: 'group',
          ),
        ],
      );
      expect(inRow('Comer con Ana', find.byType(Checkbox)), findsNothing);
      final node = rowNode(tester, 'Comer con Ana');
      final data = node.getSemanticsData();
      expect(data.flagsCollection.isButton, isTrue);
      expect(data.label, startsWith('Comer con Ana, '));
      expect(data.label, contains('13:30'));
      expect(data.label, isNot(contains(es.completeNamedTask('Comer con Ana'))));
      expect(data.label, isNot(contains(es.complete)));
      // One node: nothing inside it is read on its own.
      var children = 0;
      node.visitChildren((_) {
        children++;
        return true;
      });
      expect(children, 0, reason: 'read as one button');
      expect(
        find.descendant(
          of: row('Comer con Ana'),
          matching: find.byWidgetPredicate(
            (widget) => widget is Semantics && widget.properties.checked != null,
          ),
        ),
        findsNothing,
      );
      await tester.tap(row('Comer con Ana'));
      await tester.pumpAndSettle();
      expect(find.byType(TaskDetailScreen), findsOneWidget);
      semantics.dispose();
    },
  );

  // ---- Run 2026-10-19-app, round 2 · P206 (UX-1637): view-only rows line
  // up with the others ----

  for (final scale in [1.0, 2.0]) {
    testWidgets(
      'UX-1637: at ${scale}x on 360×800 on Calendar (calendar/agenda.added), the view-only «Comer con Ana» starts at the same x as the other rows’ titles, within 1 dp, and is still one button with no circle',
      (tester) async {
        final semantics = tester.ensureSemantics();
        await app(
          tester,
          size: const Size(360, 800),
          scale: scale,
          projects: [choirToView],
          tasks: [
            Task(
              id: 1,
              title: 'Llamar al médico para pedir cita',
              dueDate: on(0, 10),
              priority: 1,
            ),
            Task(
              id: 76,
              title: 'Comer con Ana',
              dueDate: on(0, 13, 30),
              priority: 1,
              listId: 'coro',
              assignment: 'group',
            ),
            Task(
              id: 2,
              title: 'Recoger a los niños del colegio',
              dueDate: on(0, 17),
              priority: 1,
            ),
          ],
        );
        double titleStart(String title) {
          final text = find.descendant(
            of: row(title),
            matching: find.text(title),
          );
          expect(text, findsOneWidget, reason: title);
          return tester.getRect(text).left;
        }

        final starts = <String, double>{};
        for (final title in [
          'Llamar al médico para pedir cita',
          'Comer con Ana',
          'Recoger a los niños del colegio',
        ]) {
          await tester.ensureVisible(row(title));
          await tester.pumpAndSettle();
          starts[title] = titleStart(title);
        }
        final viewOnly = starts['Comer con Ana']!;
        for (final MapEntry(:key, :value) in starts.entries) {
          expect(
            (value - viewOnly).abs(),
            lessThanOrEqualTo(1),
            reason: '$key starts at $value, «Comer con Ana» at $viewOnly',
          );
        }
        // Still no circle, and one button: «Comer con Ana, … 13:30».
        expect(inRow('Comer con Ana', find.byType(Checkbox)), findsNothing);
        final node = rowNode(tester, 'Comer con Ana');
        final data = node.getSemanticsData();
        expect(data.flagsCollection.isButton, isTrue);
        expect(data.label, startsWith('Comer con Ana, '));
        expect(data.label, contains('13:30'));
        var children = 0;
        node.visitChildren((_) {
          children++;
          return true;
        });
        expect(children, 0, reason: 'read as one button');
        expect(
          inRow(
            'Llamar al médico para pedir cita',
            find.byType(Checkbox),
          ),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
        semantics.dispose();
      },
    );
  }

  // ---- Run 2026-10-19-app, round 3 · P208 (UX-1637 re-check): on a
  // view-only project's page (tasks/project.viewer) the rows line up too ----

  testWidgets(
    'UX-1637: at 1x on 360×800 on a view-only project’s page (tasks/project.viewer) every row’s title starts at 80 dp, the same x as an editable row’s title on Tareas, with no icon in the circle’s place',
    (tester) async {
      final tasks = [
        Task(
          id: 76,
          title: 'Comer con Ana',
          dueDate: on(0, 13, 30),
          priority: 1,
          listId: 'coro',
          assignment: 'group',
        ),
        Task(
          id: 77,
          title: 'Ensayo general',
          dueDate: on(1, 19),
          priority: 2,
          listId: 'coro',
          assignment: 'group',
        ),
      ];
      final mine = Task(
        id: 1,
        title: 'Comprar pan',
        dueDate: on(0, 18),
        priority: 1,
      );
      await page(
        tester,
        const HomeScreen(),
        size: const Size(360, 800),
        projects: [choirToView],
        tasks: [mine],
      );
      final editable = tester
          .getRect(inRow('Comprar pan', find.text('Comprar pan')))
          .left;
      expect(inRow('Comprar pan', find.byType(Checkbox)), findsOneWidget);
      expect(editable, closeTo(80, 1), reason: 'an editable title at 80 dp');

      await tester.pumpWidget(const SizedBox());
      await page(
        tester,
        const HomeScreen(listId: 'coro', isRoot: false),
        size: const Size(360, 800),
        projects: [choirToView],
        tasks: tasks,
      );
      for (final title in ['Comer con Ana', 'Ensayo general']) {
        await tester.ensureVisible(row(title));
        await tester.pumpAndSettle();
        final start = tester.getRect(inRow(title, find.text(title))).left;
        expect(
          (start - editable).abs(),
          lessThanOrEqualTo(1),
          reason: '«$title» starts at $start, an editable title at $editable',
        );
        expect(inRow(title, find.byType(Checkbox)), findsNothing);
        // Nothing drawn in the circle's place, left of the title.
        final titleRect = tester.getRect(inRow(title, find.text(title)));
        final icons = find.descendant(of: row(title), matching: find.byType(Icon));
        for (final icon in icons.evaluate()) {
          final rect = tester.getRect(find.byWidget(icon.widget).first);
          expect(
            rect.right <= titleRect.left && rect.top < titleRect.bottom &&
                rect.bottom > titleRect.top,
            isFalse,
            reason: 'an icon in the circle’s place of «$title»',
          );
        }
      }
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'UX-1418: at 2× on Calendar a date-only row has no «Sin hora» line',
    (tester) async {
      await app(
        tester,
        size: const Size(360, 1600),
        scale: 2,
        tasks: [
          Task(
            id: 7,
            title: 'Pagar la factura de la luz',
            dueDate: on(0),
            hasTime: false,
            priority: 1,
          ),
          Task(id: 8, title: 'Comer con Ana', dueDate: on(0, 13, 30), priority: 1),
        ],
      );
      final calendar = find.byType(CalendarScreen);
      final dateOnly = find.descendant(
        of: calendar,
        matching: row('Pagar la factura de la luz'),
      );
      expect(dateOnly, findsOneWidget);
      expect(
        find.descendant(of: dateOnly, matching: find.textContaining(es.anyTime)),
        findsNothing,
      );
      expect(
        find.descendant(
          of: dateOnly,
          matching: find.byIcon(Icons.schedule_rounded),
        ),
        findsNothing,
      );
      // A timed row keeps its time.
      expect(
        find.descendant(
          of: find.descendant(of: calendar, matching: row('Comer con Ana')),
          matching: find.text('13:30'),
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'UX-1418: at 2× on Tareas a date-only row reads its date alone, with no «· Sin hora»',
    (tester) async {
      final date = on(3);
      await page(
        tester,
        const HomeScreen(),
        size: const Size(360, 1600),
        scale: 2,
        tasks: [
          Task(
            id: 7,
            title: 'Pagar la factura de la luz',
            dueDate: date,
            hasTime: false,
            priority: 1,
          ),
        ],
      );
      final context = tester.element(find.byType(HomeScreen));
      expect(
        inRow('Pagar la factura de la luz', find.text(context.dayLabel(date))),
        findsOneWidget,
      );
      expect(
        inRow('Pagar la factura de la luz', find.textContaining(es.anyTime)),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'UX-1418 / UX-1512: on the Sin fecha page no row shows «Sin fecha»; on the Tareas root an undated row still does',
    (tester) async {
      final tasks = [
        Task(id: 6, title: 'Comprar pilas para el mando', priority: 1),
        Task(id: 9, title: 'Ordenar el trastero', priority: 2),
      ];
      await page(
        tester,
        const HomeScreen(initialFilter: 3, isRoot: false),
        tasks: tasks,
      );
      for (final task in tasks) {
        expect(row(task.title), findsOneWidget);
        expect(inRow(task.title, find.text(es.noDate)), findsNothing);
        expect(inRow(task.title, find.textContaining(es.noDate)), findsNothing);
      }
      await tester.pumpWidget(const SizedBox());
      await page(tester, const HomeScreen(), tasks: tasks);
      expect(
        inRow('Comprar pilas para el mando', find.text(es.noDate)),
        findsOneWidget,
      );
    },
  );

  test(
    'UX-1418: the Calendar count reads «2 pendientes» with nothing done, and «2 pendientes · 1 completada» with one',
    () {
      expect(es.agendaCounts(2, 0), '2 pendientes');
      expect(es.agendaCounts(2, 1), '2 pendientes · 1 completada');
      expect(es.agendaCounts(2, 0), isNot(contains('0')));
      for (final language in ['en', 'ca']) {
        final l = lookupAppLocalizations(Locale(language));
        expect(l.agendaCounts(2, 0), isNot(contains('0')), reason: language);
        expect(l.agendaCounts(2, 1), contains('·'), reason: language);
      }
    },
  );

  testWidgets(
    'UX-1418: Calendar with 2 open and 0 done says «2 pendientes»',
    (tester) async {
      await app(
        tester,
        tasks: [
          Task(id: 1, title: 'Comer con Ana', dueDate: on(0, 13, 30), priority: 1),
          Task(id: 2, title: 'Clase de yoga', dueDate: on(0, 19, 30), priority: 1),
        ],
      );
      final calendar = find.byType(CalendarScreen);
      expect(
        find.descendant(of: calendar, matching: find.text(es.agendaCounts(2, 0))),
        findsOneWidget,
      );
      expect(
        find.descendant(of: calendar, matching: find.textContaining('0 completadas')),
        findsNothing,
      );
    },
  );

  testWidgets('UX-1418: the priority label’s font size is 12', (tester) async {
    await page(
      tester,
      const HomeScreen(),
      tasks: [
        Task(id: 4, title: 'Recoger a los niños', dueDate: on(0, 17), priority: 3),
      ],
    );
    final context = tester.element(find.byType(HomeScreen));
    final label = tester.widget<Text>(
      inRow(
        'Recoger a los niños',
        find.text(es.priorityValue(context.priorityName(3))),
      ),
    );
    expect(label.style?.fontSize, 12);
  });

  double contrast(Color a, Color b) {
    final l1 = a.computeLuminance(), l2 = b.computeLuminance();
    return (math.max(l1, l2) + 0.05) / (math.min(l1, l2) + 0.05);
  }

  for (final (name, theme) in [
    ('light', AppTheme.light),
    ('dark', AppTheme.dark),
  ]) {
    testWidgets(
      'UX-1419: a lit row’s secondary text keeps 4.5:1 on its tint ($name)',
      (tester) async {
        final task = Task(
          id: 7,
          title: 'Pagar la factura de la luz',
          dueDate: on(0, 9),
          priority: 1,
          recurrence: 'weekly',
          notes: 'Con la tarjeta',
        );
        await page(
          tester,
          Builder(
            builder: (context) => Scaffold(
              body: Padding(
                padding: const EdgeInsets.all(16),
                child: TaskTile(
                  task: task,
                  color: Theme.of(context).colorScheme.primaryContainer,
                ),
              ),
            ),
          ),
          theme: theme,
          tasks: [task],
        );
        final tint = theme.colorScheme.primaryContainer;
        final secondary = tester
            .widgetList<Text>(
              find.descendant(
                of: find.byType(TaskTile),
                matching: find.byType(Text),
              ),
            )
            .where((text) => text.data != task.title);
        expect(secondary, isNotEmpty);
        for (final text in secondary) {
          final color = text.style?.color ?? theme.colorScheme.onSurface;
          expect(
            contrast(color, tint),
            greaterThanOrEqualTo(4.5),
            reason: '«${text.data}» on the lit row',
          );
        }
      },
    );
  }

  testWidgets(
    'UX-1420: on the Tareas root an open task dated two days ago reads «… · Atrasada»',
    (tester) async {
      final date = on(-2);
      await page(
        tester,
        const HomeScreen(),
        tasks: [
          Task(
            id: 26,
            title: 'Renovar el DNI',
            dueDate: date,
            hasTime: false,
            priority: 1,
          ),
          Task(
            id: 27,
            title: 'Devolver el libro',
            dueDate: on(1),
            hasTime: false,
            priority: 1,
          ),
        ],
      );
      final context = tester.element(find.byType(HomeScreen));
      expect(es.overdueDate('sáb, 17 de oct'), 'sáb, 17 de oct · Atrasada');
      final line = es.overdueDate(context.dayLabel(date));
      expect(line, endsWith('· Atrasada'));
      expect(inRow('Renovar el DNI', find.text(line)), findsOneWidget);
      expect(
        inRow('Devolver el libro', find.textContaining('Atrasada')),
        findsNothing,
      );
      final en = lookupAppLocalizations(const Locale('en'));
      final ca = lookupAppLocalizations(const Locale('ca'));
      expect(en.overdueDate('Sat, 17 Oct'), 'Sat, 17 Oct · Overdue');
      expect(ca.overdueDate('ds., 17 d’oct.'), 'ds., 17 d’oct. · Endarrerida');
    },
  );

  testWidgets(
    'UX-1420: on a project page an overdue open row reads «· Atrasada» too',
    (tester) async {
      final date = on(-2);
      await page(
        tester,
        const HomeScreen(listId: 'casa', isRoot: false),
        projects: [fx.casa],
        tasks: [
          Task(
            id: 26,
            title: 'Pagar la comunidad',
            dueDate: date,
            hasTime: false,
            priority: 1,
            listId: 'casa',
          ),
        ],
      );
      final context = tester.element(find.byType(HomeScreen));
      expect(
        inRow(
          'Pagar la comunidad',
          find.text(es.overdueDate(context.dayLabel(date))),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'UX-1512: on «Matemáticas» no row shows a «Matemáticas» label; on the Tareas root rows still show their project',
    (tester) async {
      final tasks = [...fx.sharedProjectTasks()];
      await page(
        tester,
        const HomeScreen(listId: 'matematicas', isRoot: false),
        projects: fx.allProjects,
        tasks: tasks,
      );
      final rows = find.byType(TaskTile);
      expect(rows, findsWidgets);
      expect(
        find.descendant(of: rows, matching: find.text('Matemáticas')),
        findsNothing,
      );
      await tester.pumpWidget(const SizedBox());
      await page(
        tester,
        const HomeScreen(),
        projects: fx.allProjects,
        tasks: tasks,
      );
      expect(
        inRow('Preparar el examen del tema 5', find.text('Matemáticas')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'UX-1512: a row given to Ana shows the person icon before her name, and TalkBack reads «Responsable: Ana»; «Todos» gets the group icon',
    (tester) async {
      final semantics = tester.ensureSemantics();
      await page(
        tester,
        const HomeScreen(listId: 'matematicas', isRoot: false),
        projects: fx.allProjects,
        tasks: fx.sharedProjectTasks(),
      );
      expect(es.assigneeLabel('Ana'), 'Responsable: Ana');
      const ana = 'Corregir los ejercicios del tema 4';
      expect(inRow(ana, find.text('Ana')), findsOneWidget);
      expect(inRow(ana, find.byIcon(Icons.person_outline)), findsOneWidget);
      expect(
        inRow(ana, find.bySemanticsLabel(RegExp('Responsable: Ana'))),
        findsOneWidget,
      );
      const everyone = 'Preparar el examen del tema 5';
      expect(inRow(everyone, find.byIcon(Icons.groups_outlined)), findsOneWidget);
      // «Necesita responsable» stays as it is.
      const nobody = 'Fotocopias de geometría';
      expect(
        inRow(nobody, find.bySemanticsLabel(RegExp('^Responsable: '))),
        findsNothing,
      );
      semantics.dispose();
    },
  );

  testWidgets(
    'UX-1512: the detail of Ana’s task (tasks/detail.created-by) reads «Responsable: Ana» on the person chip and «Proyecto: Matemáticas» on the project chip',
    (tester) async {
      final semantics = tester.ensureSemantics();
      await app(
        tester,
        tasks: [...fx.normalDay(), ...fx.sharedProjectTasks()],
        projects: fx.allProjects,
      );
      unawaited(
        Navigator.of(
          tester.element(find.byType(CalendarScreen)),
        ).pushNamed('/taskDetails', arguments: 31),
      );
      await tester.pumpAndSettle();
      final detail = find.byType(TaskDetailScreen);
      expect(detail, findsOneWidget);
      expect(es.projectLabel('Matemáticas'), 'Proyecto: Matemáticas');
      expect(
        find.descendant(
          of: detail,
          matching: find.bySemanticsLabel(RegExp('Responsable: Ana')),
        ),
        findsWidgets,
      );
      expect(
        find.descendant(
          of: detail,
          matching: find.bySemanticsLabel(RegExp('Proyecto: Matemáticas')),
        ),
        findsWidgets,
      );
      final en = lookupAppLocalizations(const Locale('en'));
      final ca = lookupAppLocalizations(const Locale('ca'));
      expect(en.assigneeLabel('Ana'), 'Assignee: Ana');
      expect(ca.assigneeLabel('Ana'), 'Responsable: Ana');
      expect(en.projectLabel('Casa'), 'Project: Casa');
      expect(ca.projectLabel('Casa'), 'Projecte: Casa');
      semantics.dispose();
    },
  );

  testWidgets(
    'UX-1512: at 2× on 360 dp a row on its own project page is at least 40 dp shorter than the same row naming its project',
    (tester) async {
      sized(tester, const Size(360, 1600), 2);
      final task = Task(
        id: 70,
        title: 'Reservar el autobús',
        dueDate: on(2, 10),
        priority: 3,
        listId: 'excursion',
        assignment: 'member',
        assigneeId: fx.jordi,
        assigneeName: 'Jordi',
      );
      final container = containerFor([task], fx.allProjects);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.light,
            locale: const Locale('es'),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            home: Scaffold(
              body: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                children: [
                  TaskTile(
                    key: const ValueKey('here'),
                    task: task,
                    showDate: true,
                    project: 'excursion',
                  ),
                  TaskTile(
                    key: const ValueKey('named'),
                    task: task,
                    showDate: true,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final here = tester.getSize(find.byKey(const ValueKey('here'))).height;
      final named = tester.getSize(find.byKey(const ValueKey('named'))).height;
      expect(named - here, greaterThanOrEqualTo(40), reason: '$named vs $here');
    },
  );

  // ---- Run 2026-10-21-changes, batch e, round 2 · P240 (UX-1725): a row
  // with a deadline doesn't say «Sin fecha» ----

  /// «Pagar la factura del gas», with only a deadline, [offset] days away.
  Task gasBill(int offset, {int id = 41, String? listId}) => Task(
    id: id,
    title: 'Pagar la factura del gas',
    priority: 2,
    deadline: on(offset),
    reminderAnchor: 'deadline',
    listId: listId,
  );

  /// Every label TalkBack can read in [node] and below it.
  String spoken(SemanticsNode node) {
    final parts = <String>[node.getSemanticsData().label];
    node.visitChildren((child) {
      parts.add(spoken(child));
      return true;
    });
    return parts.where((part) => part.isNotEmpty).join(', ');
  }

  /// The deadline line [l] writes for a deadline on [date].
  String dueLine(WidgetTester tester, AppLocalizations l, DateTime date) =>
      l.deadlineLabel(
        tester.element(find.byType(TaskTile).first).weekdayDate(date),
      );

  for (final scale in [1.0, 2.0]) {
    testWidgets(
      'UX-1725: es ${scale}x on 360×800, Calendar on the day of a task with only a deadline: its row reads «Vence <day>», whole, and no «Sin fecha»',
      (tester) async {
        await app(
          tester,
          size: const Size(360, 800),
          scale: scale,
          tasks: [gasBill(0)],
        );
        final calendar = find.byType(CalendarScreen);
        final gas = find.descendant(
          of: calendar,
          matching: row('Pagar la factura del gas'),
        );
        expect(gas, findsOneWidget);
        final due = dueLine(tester, es, on(0));
        expect(due, startsWith('Vence '));
        final line = find.descendant(of: gas, matching: find.text(due));
        expect(line, findsOneWidget, reason: 'the row reads «$due»');
        expect(
          find.descendant(of: gas, matching: find.textContaining(es.noDate)),
          findsNothing,
          reason: 'no «Sin fecha» in the row',
        );
        // «Vence …» shows whole: inside the row and the screen, not cut off.
        final rect = tester.getRect(line);
        final rowRect = tester.getRect(gas);
        expect(rect.left, greaterThanOrEqualTo(rowRect.left - 0.5));
        expect(rect.right, lessThanOrEqualTo(rowRect.right + 0.5));
        expect(rect.right, lessThanOrEqualTo(360.5));
        final paragraph = tester.renderObject<RenderParagraph>(
          find.descendant(of: line, matching: find.byType(RichText)).first,
        );
        expect(paragraph.didExceedMaxLines, isFalse);
        expect(paragraph.size.width, lessThanOrEqualTo(rowRect.width));
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'UX-1725: TalkBack reads a deadline-only row with «Vence …» and no «Sin fecha», on Calendar and as a view-only row',
    (tester) async {
      final semantics = tester.ensureSemantics();
      await app(tester, size: const Size(360, 800), tasks: [gasBill(0)]);
      final due = dueLine(tester, es, on(0));
      final heard = spoken(rowNode(tester, 'Pagar la factura del gas'));
      expect(heard, contains(due));
      expect(heard, isNot(contains(es.noDate)));

      // A row that can't be changed is one button; its label is the details.
      await tester.pumpWidget(const SizedBox());
      await page(
        tester,
        const HomeScreen(listId: 'coro', isRoot: false),
        projects: [choirToView],
        tasks: [gasBill(2, id: 42, listId: 'coro')],
      );
      final node = rowNode(tester, 'Pagar la factura del gas');
      final label = node.getSemanticsData().label;
      expect(label, startsWith('Pagar la factura del gas, '));
      expect(label, contains(dueLine(tester, es, on(2))));
      expect(label, isNot(contains(es.noDate)));
      semantics.dispose();
    },
  );

  testWidgets(
    'UX-1725: on the Tareas root a task with only a deadline reads «Vence …» and no «Sin fecha»; a task with neither still reads «Sin fecha»',
    (tester) async {
      await page(
        tester,
        const HomeScreen(),
        size: const Size(360, 1600),
        tasks: [
          gasBill(3),
          Task(id: 6, title: 'Comprar pilas para el mando', priority: 1),
        ],
      );
      expect(row('Pagar la factura del gas'), findsOneWidget);
      expect(
        inRow(
          'Pagar la factura del gas',
          find.text(dueLine(tester, es, on(3))),
        ),
        findsOneWidget,
      );
      expect(
        inRow('Pagar la factura del gas', find.textContaining(es.noDate)),
        findsNothing,
      );
      expect(
        inRow('Comprar pilas para el mando', find.text(es.noDate)),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  for (final language in ['en', 'ca']) {
    testWidgets(
      'UX-1725: $language, on the Tareas root a deadline-only row reads its deadline line and not its «no date» word',
      (tester) async {
        final l = lookupAppLocalizations(Locale(language));
        sized(tester, const Size(360, 1600), 1);
        final container = containerFor(
          [
            gasBill(3),
            Task(id: 6, title: 'Comprar pilas para el mando', priority: 1),
          ],
          const [],
          language: language,
        );
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              theme: AppTheme.light,
              locale: Locale(language),
              supportedLocales: AppLocalizations.supportedLocales,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              home: const HomeScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final due = dueLine(tester, l, on(3));
        expect(
          due,
          startsWith(language == 'en' ? 'Due ' : 'Termini: '),
          reason: 'the catalog’s deadline line',
        );
        expect(
          inRow('Pagar la factura del gas', find.text(due)),
          findsOneWidget,
        );
        expect(
          inRow('Pagar la factura del gas', find.textContaining(l.noDate)),
          findsNothing,
          reason: 'no «${l.noDate}»',
        );
        // A task with neither a day nor a deadline still says so.
        expect(
          inRow('Comprar pilas para el mando', find.text(l.noDate)),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );
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
