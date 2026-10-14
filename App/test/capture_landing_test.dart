// P36 (U4) and P37 (U5): saying or typing something opens the result in the
// same capture sheet, and after `Añadir…` the screen underneath shows the
// task: Calendar on its day, Tareas with its filter cleared, and the pending
// list back on Calendar.
import 'dart:async';
import 'dart:io';

import 'package:agenda/l10n/generated/app_localizations.dart';
import 'package:agenda/l10n/region.dart';
import 'package:agenda/main.dart';
import 'package:agenda/models/capture_session.dart';
import 'package:agenda/models/task.dart';
import 'package:agenda/providers/auth_provider.dart';
import 'package:agenda/providers/regional_provider.dart';
import 'package:agenda/providers/subscription_provider.dart';
import 'package:agenda/providers/task_lists_provider.dart';
import 'package:agenda/providers/task_provider.dart';
import 'package:agenda/providers/theme_provider.dart';
import 'package:agenda/screens/calendar_screen.dart';
import 'package:agenda/screens/captures_screen.dart';
import 'package:agenda/screens/home_screen.dart';
import 'package:agenda/screens/voice_task_screen.dart';
import 'package:agenda/services/api_client.dart';
import 'package:agenda/services/capture_store.dart';
import 'package:agenda/services/invitation_links.dart';
import 'package:agenda/services/native_speech.dart';
import 'package:agenda/services/task_database.dart';
import 'package:agenda/widgets/attachment_panel.dart';
import 'package:agenda/widgets/task_actions.dart';
import 'package:agenda/widgets/task_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

import 'support/capture_fixtures.dart' show SilentRecorder;
import 'support/design_fixtures.dart';

final es = lookupAppLocalizations(const Locale('es'));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final platform =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const timeoutChannel = MethodChannel('taskflow/accessibility');
  const timezone = MethodChannel('flutter_timezone');
  setUp(() {
    // Messages stay for 10 s, the phone's accessibility timeout.
    platform.setMockMethodCallHandler(timeoutChannel, (_) async => 10000);
    platform.setMockMethodCallHandler(timezone, (_) async => 'Europe/Madrid');
  });
  tearDown(() {
    platform.setMockMethodCallHandler(timeoutChannel, null);
    platform.setMockMethodCallHandler(timezone, null);
  });

  final now = DateTime.now();
  DateTime inDays(int days, [int hour = 0]) =>
      DateTime(now.year, now.month, now.day + days, hour);

  /// The first Friday at least two days away, so it's never Hoy or Mañana.
  DateTime friday() {
    var day = inDays(2);
    while (day.weekday != DateTime.friday) {
      day = DateTime(day.year, day.month, day.day + 1);
    }
    return day;
  }

  Map<String, dynamic> found(
    String title, {
    DateTime? at,
    DateTime? on,
    int priority = 1,
  }) => {
    'title': title,
    'due_date': at?.toIso8601String(),
    'scheduled_date': on == null ? null : DateFormat('yyyy-MM-dd').format(on),
    'priority': priority,
    'notes': '',
    'questions': [],
  };

  Finder row(String title) => find.widgetWithText(TaskTile, title);
  Color lit(WidgetTester tester) => Theme.of(
    tester.element(find.byType(NavigationBar)),
  ).colorScheme.primaryContainer;

  testWidgets(
    'U4: after Listo the same sheet says Entendiendo… over the words, then shows the result; no page is pushed and review_tasks_screen.dart is gone',
    (tester) async {
      final app = await _App.open(tester, []);
      app.api.found = [found('Comprar pan')];
      final gate = app.api.gate = Completer<void>();
      await app.say(tester, 'Comprar pan', submit: false);
      final words = find.byKey(const ValueKey('capture-words'));
      final route = ModalRoute.of(tester.element(words));
      await tester.tap(find.widgetWithText(FilledButton, es.done));
      await tester.pump();
      await tester.pump();
      expect(find.text(es.captureUnderstanding), findsOneWidget);
      expect(es.captureUnderstanding, 'Entendiendo…');
      expect(find.text('Comprar pan'), findsOneWidget);
      gate.complete();
      await tester.pumpAndSettle();
      final result = find.byType(CaptureResult);
      expect(result, findsOneWidget);
      expect(identical(ModalRoute.of(tester.element(result)), route), isTrue);
      expect(find.byType(BottomSheet), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(BottomSheet),
          matching: find.byType(CaptureResult),
        ),
        findsOneWidget,
      );
      expect(
        File('lib/screens/review_tasks_screen.dart').existsSync(),
        isFalse,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'U5: from Calendar, a result dated Friday → Añadir al calendario closes the sheet, selects Friday, shows and highlights the row, says Añadida al vie, … with Deshacer; Deshacer removes it and reopens the sheet on the result',
    (tester) async {
      final day = friday();
      final app = await _App.open(tester, [
        Task(
          id: 1,
          title: 'Regar las plantas',
          priority: 1,
          dueDate: inDays(0, 9),
        ),
      ]);
      expect(find.text(es.todayAgenda), findsOneWidget);
      app.api.found = [
        found(
          'Llevar el coche al taller',
          at: DateTime(day.year, day.month, day.day, 17),
        ),
      ];
      await app.say(tester, 'Llevar el coche al taller el viernes a las 17');
      expect(find.text(es.captureAddToCalendar), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('save-drafts')));
      await tester.pumpAndSettle();

      expect(find.byType(BottomSheet), findsNothing);
      expect(find.byType(CaptureResult), findsNothing);
      // Friday is selected.
      expect(find.text(DateFormat.MMMMEEEEd('es').format(day)), findsOneWidget);
      expect(find.text(es.todayAgenda), findsNothing);
      final saved = row('Llevar el coche al taller');
      expect(saved.hitTestable(), findsOneWidget);
      expect(tester.widget<TaskTile>(saved).color, lit(tester));
      final calendar = tester.element(find.byType(CalendarScreen));
      final message = es.taskAddedOn(calendar.weekdayDate(day));
      expect(
        message,
        startsWith('Añadida al ${DateFormat.E('es').format(day)}'),
      );
      expect(find.text(message), findsOneWidget);
      expect(
        tester.getRect(saved).bottom,
        lessThanOrEqualTo(tester.getRect(find.byType(SnackBar)).top),
      );
      expect(find.text(es.undo), findsOneWidget);

      await tester.tap(find.text(es.undo));
      await tester.pumpAndSettle();
      expect(app.tasks.titles(), isNot(contains('Llevar el coche al taller')));
      expect(app.store.undos, 1);
      expect(find.byType(CaptureResult), findsOneWidget);
      expect(
        tester
            .widget<TextFormField>(find.byKey(const ValueKey('task-title')))
            .controller!
            .text,
        'Llevar el coche al taller',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'U5: a batch on two days lands on the earlier day with 2 tareas añadidas',
    (tester) async {
      final early = inDays(3);
      final late = inDays(5);
      final app = await _App.open(tester, []);
      app.api.found = [
        found('Pagar la luz', on: late),
        found('Llamar al fontanero', on: early),
      ];
      await app.say(tester, 'Pagar la luz y llamar al fontanero');
      expect(find.text(es.captureAddTasks(2)), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('save-drafts')));
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsNothing);
      expect(es.captureTasksAdded(2), '2 tareas añadidas');
      expect(find.text(es.captureTasksAdded(2)), findsOneWidget);
      expect(find.text(es.undo), findsOneWidget);
      expect(
        find.text(DateFormat.MMMMEEEEd('es').format(early)),
        findsOneWidget,
      );
      final saved = row('Llamar al fontanero');
      expect(saved.hitTestable(), findsOneWidget);
      expect(tester.widget<TaskTile>(saved).color, lit(tester));
      // The later one is on its own day.
      expect(row('Pagar la luz'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'U5: on Tareas filtered to Prioridad alta, saving a normal-priority task selects Todas and highlights the new row',
    (tester) async {
      final app = await _App.open(tester, [
        Task(id: 1, title: 'Renovar el pasaporte', priority: 3),
        Task(id: 2, title: 'Ordenar el trastero', priority: 1),
      ]);
      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text(es.tasks),
        ),
      );
      await tester.pumpAndSettle();
      ChoiceChip chip(String label) =>
          tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, label));
      await tester.tap(find.widgetWithText(ChoiceChip, es.highPriority));
      await tester.pumpAndSettle();
      expect(chip(es.highPriority).selected, isTrue);
      expect(row('Ordenar el trastero'), findsNothing);

      app.api.found = [found('Comprar bombillas')];
      await app.say(tester, 'Comprar bombillas');
      // The page under the sheet has its own Añadir tarea.
      expect(
        find.descendant(
          of: find.byType(CaptureResult),
          matching: find.text(es.captureAddTask),
        ),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('save-drafts')));
      await tester.pumpAndSettle();

      expect(find.byType(BottomSheet), findsNothing);
      expect(find.byType(HomeScreen).hitTestable(), findsWidgets);
      expect(chip(es.allTasks).selected, isTrue);
      expect(chip(es.highPriority).selected, isFalse);
      final saved = row('Comprar bombillas');
      // In view on the page, clear of the message under it.
      expect(saved.hitTestable(), findsOneWidget);
      expect(
        tester.getRect(saved).bottom,
        lessThanOrEqualTo(tester.getRect(find.byType(SnackBar)).top),
      );
      expect(tester.widget<TaskTile>(saved).color, lit(tester));
      expect(find.text(es.taskSavedInbox), findsOneWidget);
      expect(find.text(es.undo), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'U5: saving a resumed capture from the pending list lands on Calendar with the row highlighted',
    (tester) async {
      final day = inDays(3);
      final app = await _App.open(tester, []);
      app.store.current = CaptureSession(
        id: 'pending',
        ownerKey: app.container.read(captureOwnerProvider),
        timezone: 'Europe/Madrid',
        capturedAt: DateTime.now().toUtc(),
        status: 'ready',
        source: 'speech',
        transcript: 'Revisar la caldera',
        drafts: [
          CaptureDraft(
            id: 'boiler',
            task: Task(title: 'Revisar la caldera', priority: 1, dueDate: day),
          ),
        ],
      );
      app.container.invalidate(pendingCapturesProvider);
      // From another tab, as the pending list can be opened from anywhere.
      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text(es.tasks),
        ),
      );
      await tester.pumpAndSettle();
      unawaited(
        Navigator.of(
          tester.element(find.byType(HomeScreen)),
        ).pushNamed('/captures'),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Revisar la caldera'));
      await tester.pumpAndSettle();
      expect(find.byType(CaptureResult), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('save-drafts')));
      await tester.pumpAndSettle();

      expect(find.byType(CapturesScreen), findsNothing);
      expect(find.byType(BottomSheet), findsNothing);
      expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        0,
      );
      expect(find.text(DateFormat.MMMMEEEEd('es').format(day)), findsOneWidget);
      final saved = row('Revisar la caldera');
      expect(saved.hitTestable(), findsOneWidget);
      expect(tester.widget<TaskTile>(saved).color, lit(tester));
      expect(tester.takeException(), isNull);
    },
  );

  // ---- P59 (U5, second attempt): Tareas scrolls the new task into view ----

  /// Tareas with [tasks], filtered to `Prioridad alta`.
  Future<void> tareasHighPriority(WidgetTester tester) async {
    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text(es.tasks),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, es.highPriority));
    await tester.pumpAndSettle();
  }

  /// Fourteen tasks, two of them high priority, as a list in real use.
  List<Task> many() => [
    for (var id = 1; id <= 14; id++)
      Task(id: id, title: 'Tarea número $id', priority: id <= 2 ? 3 : 1),
  ];

  /// The part of Tareas the list shows: under the app bar, above the
  /// Dictar / Escribir actions.
  Rect listArea(WidgetTester tester) {
    final page = find.byType(HomeScreen);
    final bar = tester.getRect(
      find.descendant(of: page, matching: find.byType(AppBar)),
    );
    final actions = tester.getRect(find.byType(TaskActions));
    return Rect.fromLTRB(0, bar.bottom, bar.width, actions.top);
  }

  (double, double) offsets(WidgetTester tester) {
    final nested = tester.state<NestedScrollViewState>(
      find.byType(NestedScrollView),
    );
    return (
      nested.outerController.position.pixels,
      nested.innerController.position.pixels,
    );
  }

  testWidgets(
    'U5: at 2× text on 360×740, saving a normal task on Tareas filtered to Prioridad alta brings the new row’s top into the list area, highlighted',
    (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final app = await _App.open(tester, many(), size: const Size(360, 740));
      // At 2× text the filter chips start below the fold: bring
      // `Prioridad alta` into view before tapping it, so the list really is
      // filtered.
      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text(es.tasks),
        ),
      );
      await tester.pumpAndSettle();
      final high = find.widgetWithText(ChoiceChip, es.highPriority);
      await tester.ensureVisible(high);
      await tester.pumpAndSettle();
      await tester.tap(high);
      await tester.pumpAndSettle();
      expect(tester.widget<ChoiceChip>(high).selected, isTrue);
      expect(row('Tarea número 9'), findsNothing);
      app.api.found = [found('Comprar bombillas')];
      await app.say(tester, 'Comprar bombillas');
      await tester.tap(find.byKey(const ValueKey('save-drafts')));
      await tester.pumpAndSettle();

      final saved = row('Comprar bombillas');
      expect(saved, findsOneWidget);
      final area = listArea(tester);
      final top = tester.getRect(saved).top;
      expect(
        top,
        greaterThanOrEqualTo(area.top - 0.5),
        reason: 'row $top, list $area',
      );
      expect(top, lessThan(area.bottom), reason: 'row $top, list $area');
      // Its top can be touched, not hidden under the actions or the message.
      final point = Offset(tester.getRect(saved).center.dx, top + 4);
      final hits = tester.hitTestOnBinding(point);
      expect(
        hits.path.any((entry) => entry.target == tester.renderObject(saved)),
        isTrue,
        reason: 'the new row’s top is hit-testable at $point',
      );
      expect(tester.widget<TaskTile>(saved).color, lit(tester));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'U5: with animations off, the new row on Tareas is reached in one jump, before its highlight fades',
    (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      final app = await _App.open(tester, many());
      await tareasHighPriority(tester);
      app.api.found = [found('Comprar bombillas')];
      await app.say(tester, 'Comprar bombillas');
      final before = offsets(tester);
      await tester.tap(find.byKey(const ValueKey('save-drafts')));
      // Frame by frame, well inside the 1.5 s highlight.
      final seen = <(double, double)>[before];
      final changedAt = <int>[];
      for (var frame = 0; frame < 60; frame++) {
        await tester.pump(const Duration(milliseconds: 16));
        if (find.byType(NestedScrollView).evaluate().isEmpty) continue;
        final now = offsets(tester);
        if (now != seen.last) {
          seen.add(now);
          changedAt.add(frame);
        }
      }
      final saved = row('Comprar bombillas');
      expect(saved.hitTestable(), findsOneWidget);
      // Still lit: the move ended before the highlight timer.
      expect(tester.widget<TaskTile>(saved).color, lit(tester));
      final settled = offsets(tester);
      await tester.pumpAndSettle();
      expect(offsets(tester), settled);
      expect(changedAt, isNotEmpty, reason: 'the list had to move');
      // Jumps, one per frame at most: a 300 ms animation would take about
      // 19 frames of 16 ms from its first step to its last.
      expect(
        changedAt.last - changedAt.first,
        lessThan(changedAt.length + 2),
        reason: 'offsets $seen changed at frames $changedAt',
      );
      expect(
        changedAt.length,
        lessThanOrEqualTo(8),
        reason: 'offsets $seen changed at frames $changedAt',
      );
      expect(settled, isNot(before), reason: 'the list had to move');
      // As with animations on: clear of the `Añadida…` message under it.
      expect(
        tester.getRect(saved).bottom,
        lessThanOrEqualTo(tester.getRect(find.byType(SnackBar)).top),
        reason:
            'row ${tester.getRect(saved)}, message '
            '${tester.getRect(find.byType(SnackBar))}, list area '
            '${listArea(tester)}',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'U5: on Tareas with two tasks, where the new row already shows, saving moves neither scroll offset and highlights it',
    (tester) async {
      final app = await _App.open(tester, [
        Task(id: 1, title: 'Renovar el pasaporte', priority: 3),
        Task(id: 2, title: 'Ordenar el trastero', priority: 1),
      ], size: const Size(390, 1400));
      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text(es.tasks),
        ),
      );
      await tester.pumpAndSettle();
      app.api.found = [found('Comprar bombillas')];
      await app.say(tester, 'Comprar bombillas');
      final before = offsets(tester);
      await tester.tap(find.byKey(const ValueKey('save-drafts')));
      await tester.pumpAndSettle();
      final saved = row('Comprar bombillas');
      expect(saved.hitTestable(), findsOneWidget);
      expect(tester.widget<TaskTile>(saved).color, lit(tester));
      expect(offsets(tester), before);
      expect(before, (0.0, 0.0));
      expect(tester.takeException(), isNull);
    },
  );
}

/// The app in Spanish with a 24-hour clock, on Calendar, with capture
/// answered by [api] and kept in [store].
class _App {
  _App(this.container, this.store, this.api, this.tasks);
  final ProviderContainer container;
  final _Captures store;
  final _Api api;
  final _Tasks tasks;

  static Future<_App> open(
    WidgetTester tester,
    List<Task> initial, {
    Size size = const Size(390, 844),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final store = _Captures();
    final api = _Api();
    final tasks = _Tasks(initial);
    final container = ProviderContainer(
      overrides: [
        invitationLinkProvider.overrideWith(
          (ref) => InvitationLinks(listen: false),
        ),
        hasProProvider.overrideWithValue(true),
        authProvider.overrideWith((ref) => SignedInFixtureAuth(api)),
        attachmentEntriesProvider.overrideWith((ref, taskId) async => []),
        regionalStoreProvider.overrideWithValue(
          MemoryRegionalStore(
            const RegionalPreferences(
              language: 'es',
              clock: ClockFormat.twentyFour,
              weekStart: 1,
            ),
          ),
        ),
        taskListsProvider.overrideWith((ref) async => []),
        apiClientProvider.overrideWithValue(api),
        taskRepositoryProvider.overrideWithValue(MemoryTasks()),
        taskProvider.overrideWith((ref) => tasks),
        themeStoreProvider.overrideWithValue(MemoryThemeStore()),
        captureStoreProvider.overrideWithValue(store),
        nativeSpeechProvider.overrideWithValue(_Speech()),
        captureRecorderFactoryProvider.overrideWithValue(SilentRecorder.new),
      ],
    );
    store.tasks = tasks;
    addTearDown(() {
      container.dispose();
      api.close();
    });
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const MyApp()),
    );
    await tester.pumpAndSettle();
    return _App(container, store, api, tasks);
  }

  /// `Dictar una tarea` on the screen in front, `Escribir`, the words, and
  /// `Listo` unless [submit] is false.
  Future<void> say(
    WidgetTester tester,
    String words, {
    bool submit = true,
  }) async {
    await tester.tap(find.text(es.addTask).hitTestable());
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip(es.captureTypeInstead));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('capture-words')), words);
    await tester.pumpAndSettle();
    if (!submit) return;
    await tester.tap(find.widgetWithText(FilledButton, es.done));
    await tester.pumpAndSettle();
  }
}

/// The assistant: returns [found] for every capture, after [gate] if set.
class _Api extends OfflineApiClient {
  List<Map<String, dynamic>> found = [];
  Completer<void>? gate;
  @override
  Future<dynamic> request(
    String method,
    String path, {
    Map<String, dynamic>? data,
    String? audioPath,
    bool authenticated = true,
    int? accountId,
    bool retry = true,
  }) async {
    if (!path.startsWith('ai/')) {
      throw ApiException(0, 'Offline. Retry when connected.');
    }
    await gate?.future;
    return {'transcript': data?['text'] ?? '', 'tasks': found};
  }
}

/// Tasks in memory, numbered as they are added.
class _Tasks extends DesignTaskNotifier {
  _Tasks(this.initial);
  final List<Task> initial;
  int _next = 100;
  @override
  Future<void> loadTasks() async {
    if (!state.hasValue) state = AsyncData(initial);
  }

  List<String> titles() => state.requireValue.map((t) => t.title).toList();

  int add(Task task) {
    final id = _next++;
    state = AsyncData([...state.requireValue, task.copyWith(id: id)]);
    return id;
  }
}

/// A capture store in memory: saving adds the tasks with the ids it reports,
/// as the real store's transaction does, and Undo takes them out again.
class _Captures extends CaptureStore {
  _Captures() : super(TaskDatabase());
  CaptureSession? current;
  _Tasks? tasks;
  int undos = 0;

  @override
  Future<CaptureSession> create(
    String ownerKey,
    String timezone, {
    String text = '',
    DateTime? now,
    bool audio = false,
    String kind = 'task',
    String? projectId,
    String? source,
    DateTime? day,
    String? id,
  }) async => current = CaptureSession(
    id: 'capture-${DateTime.now().microsecondsSinceEpoch}',
    ownerKey: ownerKey,
    timezone: timezone,
    capturedAt: (now ?? DateTime.now()).toUtc(),
    text: text,
    kind: kind,
    projectId: projectId,
    source: source,
    day: day,
  );
  @override
  Future<void> update(CaptureSession value) async => current = value;
  @override
  Future<CaptureSession?> read(String id, String ownerKey) async =>
      current?.id == id ? current : null;
  @override
  Future<List<CaptureSession>> pending(String ownerKey) async => [
    if (current != null && !current!.terminal && current!.remaining.isNotEmpty)
      current!,
  ];
  @override
  Future<void> cleanFinished(String ownerKey) async {}
  @override
  Future<void> discard(String id, String ownerKey) async {
    if (current?.id == id) current = current!.copyWith(status: 'discarded');
  }

  @override
  Future<CaptureSession> saveReady(
    String id,
    String ownerKey,
    Set<String> draftIds,
  ) async {
    final drafts = [
      for (final draft in current!.drafts)
        draftIds.contains(draft.id)
            ? draft.copyWith(savedTaskId: tasks!.add(draft.task))
            : draft,
    ];
    return current = current!.copyWith(
      status: drafts.any((d) => d.pending) ? 'ready' : 'saved',
      drafts: drafts,
    );
  }

  @override
  Future<CaptureSession?> undoSave(
    CaptureSession before,
    Map<String, int> savedIds,
  ) async {
    undos++;
    for (final id in savedIds.values) {
      await tasks!.deleteTask(id);
    }
    return current = before;
  }
}

/// The phone's recognizer, listening until it is stopped.
class _Speech extends NativeSpeech {
  final _events = StreamController<SpeechEvent>.broadcast(sync: true);
  int? _run;
  @override
  Future<SpeechCapability> capability({String? language}) async =>
      const SpeechCapability(
        onDevice: true,
        language: 'es-ES',
        languageInstalled: true,
      );
  @override
  Stream<SpeechEvent> get events => _events.stream;
  @override
  Future<SpeechPermission> permission() async => SpeechPermission.granted;
  @override
  Future<void> start(
    int id,
    String language, {
    List<String> hints = const [],
  }) async => _run = id;
  @override
  Future<void> stop(int id) async {
    if (_run != null) _events.add(SpeechEvent(_run!, 'ended'));
  }

  @override
  Future<void> cancel(int id) async {}
}
