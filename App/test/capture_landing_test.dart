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
import 'package:agenda/models/task_list_info.dart';
import 'package:agenda/providers/auth_provider.dart';
import 'package:agenda/providers/calendar_focus_provider.dart';
import 'package:agenda/providers/regional_provider.dart';
import 'package:agenda/providers/subscription_provider.dart';
import 'package:agenda/providers/task_lists_provider.dart';
import 'package:agenda/providers/task_provider.dart';
import 'package:agenda/providers/theme_provider.dart';
import 'package:agenda/repositories/task_repository.dart';
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
import 'package:flutter/rendering.dart';
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
    'U5 / P297: a batch on two days lands on the earlier day, named with its task',
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
      // The message names the day Calendar lands on with its task (P297),
      // and the later day, out of sight, after it (P102).
      final calendar = tester.element(find.byType(CalendarScreen));
      expect(
        find.text(
          '${es.taskAddedOn(calendar.weekdayDate(early))} · '
          '${es.captureAlsoOn(calendar.weekdayDate(late))}',
        ),
        findsOneWidget,
      );
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
    'U5: on Tareas filtered to Prioridad alta, saving a normal-priority task clears the filter and highlights the new row',
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
      FilterChip chip(String label) =>
          tester.widget<FilterChip>(find.widgetWithText(FilterChip, label));
      // The chips scroll sideways when they don't fit.
      final high = find.widgetWithText(FilterChip, es.highPriority);
      await tester.ensureVisible(high);
      await tester.pumpAndSettle();
      await tester.tap(high);
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
      // No filter chosen: every task shows.
      expect(chip(es.inbox).selected, isFalse);
      expect(chip(es.today).selected, isFalse);
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
    await tester.tap(find.widgetWithText(FilterChip, es.highPriority));
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
      final high = find.widgetWithText(FilterChip, es.highPriority);
      await tester.ensureVisible(high);
      await tester.pumpAndSettle();
      await tester.tap(high);
      await tester.pumpAndSettle();
      expect(tester.widget<FilterChip>(high).selected, isTrue);
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

  // ---- P72 (UX-475): Calendar's no-date landing clears the save message ----

  /// Saves `Comprar pilas` with no date from Calendar at 390×844 and checks
  /// the lit `Bandeja` row sits fully above the save message, under the app
  /// bar.
  Future<void> noDateLanding(WidgetTester tester) async {
    final app = await _App.open(tester, [
      Task(
        id: 1,
        title: 'Regar las plantas',
        priority: 1,
        dueDate: inDays(0, 9),
      ),
      Task(id: 2, title: 'Llamar a mamá', priority: 1, dueDate: inDays(0, 18)),
    ]);
    expect(find.text(es.todayAgenda), findsOneWidget);
    expect(find.byKey(const ValueKey('calendar-inbox')), findsNothing);
    app.api.found = [found('Comprar pilas')];
    await app.say(tester, 'Comprar pilas');
    await tester.tap(find.byKey(const ValueKey('save-drafts')));
    // Frame by frame for 1.2 s, as on a phone: past the message's entrance
    // and the scroll, inside the 1.5 s highlight and the message's 10 s.
    for (var frame = 0; frame < 48; frame++) {
      await tester.pump(const Duration(milliseconds: 25));
    }

    expect(find.byType(BottomSheet), findsNothing);
    expect(find.text(es.taskSavedInbox), findsOneWidget);
    final inbox = find.byKey(const ValueKey('calendar-inbox'));
    expect(inbox, findsOneWidget);
    expect(find.text(es.inboxCount(1)), findsOneWidget);
    final rowRect = tester.getRect(inbox);
    final message = tester.getRect(find.byType(SnackBar));
    final bar = tester.getRect(
      find.descendant(
        of: find.byType(CalendarScreen),
        matching: find.byType(AppBar),
      ),
    );
    expect(
      rowRect.bottom,
      lessThanOrEqualTo(message.top),
      reason: 'row $rowRect, message $message',
    );
    expect(
      rowRect.top,
      greaterThanOrEqualTo(bar.bottom - 0.5),
      reason: 'row $rowRect, app bar $bar',
    );
    // The whole row can be touched, not covered by the message.
    for (final point in [rowRect.topCenter, rowRect.bottomCenter]) {
      final at = point + Offset(0, point == rowRect.topCenter ? 2 : -2);
      final hits = tester.hitTestOnBinding(at);
      expect(
        hits.path.any((entry) => entry.target == tester.renderObject(inbox)),
        isTrue,
        reason: 'the Bandeja row is hit-testable at $at',
      );
    }
    // Lit as the landing.
    final lit = tester.widget<DecoratedBox>(
      find
          .descendant(
            of: find.ancestor(of: inbox, matching: find.byType(Align)).first,
            matching: find.byType(DecoratedBox),
          )
          .first,
    );
    expect(
      (lit.decoration as BoxDecoration).color,
      Theme.of(tester.element(inbox)).colorScheme.primaryContainer,
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  }

  testWidgets(
    'UX-475: at 390×844, a task saved without a date from Calendar lights the Bandeja row fully above the save message',
    (tester) async {
      await noDateLanding(tester);
    },
  );

  testWidgets(
    'UX-475: with animations off, the no-date row on Calendar still lands fully above the save message',
    (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      await noDateLanding(tester);
    },
  );

  // ---- 2026-10-14-speed · P101 (UX-601): saving never waits on the cloud ----

  /// Friday at 17:00, said and saved with `Añadir al calendario` from
  /// Calendar on a signed-in account whose cloud is [cloud].
  Future<_App> saveFridayResult(WidgetTester tester, _SlowCloud cloud) async {
    final day = friday();
    final app = await _App.open(tester, [], cloud: cloud);
    app.api.found = [
      found(
        'Llevar el coche al taller',
        at: DateTime(day.year, day.month, day.day, 17),
      ),
    ];
    await app.speak(tester, 'Llevar el coche al taller el viernes a las 5');
    expect(find.byType(CaptureResult), findsOneWidget);
    expect(find.text(es.captureAddToCalendar), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('save-drafts')));
    await tester.pumpAndSettle();
    return app;
  }

  List<String> listed(_App app) => [
    for (final task in app.container.read(taskProvider).valueOrNull ?? [])
      task.title,
  ];

  testWidgets(
    'UX-601: with a cloud sync that never completes, Añadir al calendario closes the sheet at once, selects Friday, lights its row and says Añadida al vie, … with Deshacer',
    (tester) async {
      final cloud = _SlowCloud();
      final app = await saveFridayResult(tester, cloud);
      expect(cloud.syncs, greaterThan(0), reason: 'a sync is under way');
      expect(cloud.finished, 0, reason: 'and it never finished');
      expect(find.byType(BottomSheet), findsNothing);
      expect(find.byType(CaptureResult), findsNothing);
      expect(find.text(es.saving), findsNothing);
      final day = friday();
      expect(find.text(DateFormat.MMMMEEEEd('es').format(day)), findsOneWidget);
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
      expect(find.text(es.undo), findsOneWidget);
      expect(listed(app), contains('Llevar el coche al taller'));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'UX-601: with the same never-ending sync, Deshacer brings the result back in the sheet and the task leaves Calendar',
    (tester) async {
      final cloud = _SlowCloud();
      final app = await saveFridayResult(tester, cloud);
      await tester.tap(find.text(es.undo));
      await tester.pumpAndSettle();
      expect(cloud.finished, 0);
      expect(find.byType(CaptureResult), findsOneWidget);
      expect(
        tester
            .widget<TextFormField>(find.byKey(const ValueKey('task-title')))
            .controller!
            .text,
        'Llevar el coche al taller',
      );
      expect(find.text(es.saving), findsNothing);
      expect(listed(app), isNot(contains('Llevar el coche al taller')));
      expect(cloud.titles, isNot(contains('Llevar el coche al taller')));
      expect(row('Llevar el coche al taller'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'UX-601: with a sync already running when the save happens, the saved task is in the task list from the save on and never leaves it, before and after that sync completes',
    (tester) async {
      final cloud = _SlowCloud();
      final day = friday();
      final app = await _App.open(tester, [], cloud: cloud);
      final gate = cloud.gate;
      expect(cloud.syncs, 1, reason: 'the first load is syncing');
      final seen = <List<String>>[];
      app.container.listen(
        taskProvider,
        (_, next) =>
            seen.add([for (final t in next.valueOrNull ?? []) t.title]),
      );
      app.api.found = [
        found(
          'Llevar el coche al taller',
          at: DateTime(day.year, day.month, day.day, 17),
        ),
      ];
      await app.speak(tester, 'Llevar el coche al taller el viernes a las 5');
      await tester.tap(find.byKey(const ValueKey('save-drafts')));
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsNothing);
      final from = seen.indexWhere(
        (titles) => titles.contains('Llevar el coche al taller'),
      );
      expect(from, isNot(-1), reason: 'shown before the sync completed');
      expect(cloud.finished, 0);

      // The running sync completes; the loop reads the list again.
      gate.complete();
      await tester.pumpAndSettle();
      expect(cloud.finished, greaterThan(0));
      expect(seen.length, greaterThan(from + 1), reason: 'read again');
      for (final titles in seen.skip(from)) {
        expect(titles, contains('Llevar el coche al taller'), reason: '$seen');
      }
      expect(listed(app), contains('Llevar el coche al taller'));
      expect(row('Llevar el coche al taller').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'UX-601: a task-list read that began before the save and answers after it never puts back a list without the saved task',
    (tester) async {
      final cloud = _SlowCloud()..gate.complete();
      final day = friday();
      final app = await _App.open(tester, [], cloud: cloud);
      app.api.found = [
        found(
          'Llevar el coche al taller',
          at: DateTime(day.year, day.month, day.day, 17),
        ),
      ];
      await app.speak(tester, 'Llevar el coche al taller el viernes a las 5');
      // A reload starts now: its read is taken before the save and held.
      final held = cloud.holdNextRead();
      unawaited(app.container.read(taskProvider.notifier).loadTasks());
      await tester.pump();
      final seen = <List<String>>[];
      app.container.listen(
        taskProvider,
        (_, next) =>
            seen.add([for (final t in next.valueOrNull ?? []) t.title]),
      );
      await tester.tap(find.byKey(const ValueKey('save-drafts')));
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsNothing);
      expect(listed(app), contains('Llevar el coche al taller'));

      // The old read answers late, without the task.
      held.complete();
      await tester.pumpAndSettle();
      final from = seen.indexWhere(
        (titles) => titles.contains('Llevar el coche al taller'),
      );
      expect(from, isNot(-1));
      for (final titles in seen.skip(from)) {
        expect(titles, contains('Llevar el coche al taller'), reason: '$seen');
      }
      expect(listed(app), contains('Llevar el coche al taller'));
      expect(row('Llevar el coche al taller').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  // ---- 2026-10-14-speed · P102 (U5): a batch shows every place ----

  /// The Bandeja (no-date) row's fill, lit or not.
  Color? inboxFill(WidgetTester tester) {
    final inbox = find.byKey(const ValueKey('calendar-inbox'));
    if (inbox.evaluate().isEmpty) return null;
    final box = tester.widget<DecoratedBox>(
      find
          .descendant(
            of: find.ancestor(of: inbox, matching: find.byType(Align)).first,
            matching: find.byType(DecoratedBox),
          )
          .first,
    );
    return (box.decoration as BoxDecoration).color;
  }

  /// The colour the Bandeja row is lighting up to (or fading to).
  Color? inboxTarget(WidgetTester tester) {
    final inbox = find.byKey(const ValueKey('calendar-inbox'));
    if (inbox.evaluate().isEmpty) return null;
    return (tester
                .widget<TweenAnimationBuilder<Color?>>(
                  find
                      .ancestor(
                        of: inbox,
                        matching: find.byType(TweenAnimationBuilder<Color?>),
                      )
                      .first,
                )
                .tween
            as ColorTween)
        .end;
  }

  /// The colour [title]'s row is lighting up to (or fading to).
  Color? rowTarget(WidgetTester tester, String title) {
    final tile = row(title);
    if (tile.evaluate().isEmpty) return null;
    final builder = find.ancestor(
      of: tile,
      matching: find.byType(TweenAnimationBuilder<Color?>),
    );
    if (builder.evaluate().isEmpty) return tester.widget<TaskTile>(tile).color;
    return (tester.widget<TweenAnimationBuilder<Color?>>(builder.first).tween
            as ColorTween)
        .end;
  }

  testWidgets(
    'U5: one save with a Saturday task and an undated one lands on Saturday with the Saturday row and the no-date row lit in the same frame; both fade, with no exception',
    (tester) async {
      final saturday = DateTime(
        friday().year,
        friday().month,
        friday().day + 1,
      );
      final app = await _App.open(tester, [
        // An older task with no date: the no-date row already shows.
        Task(id: 1, title: 'Ordenar el trastero', priority: 1),
      ]);
      app.api.found = [
        found(
          'Recoger el coche',
          at: DateTime(saturday.year, saturday.month, saturday.day, 10),
        ),
        found('Pagar la luz'),
      ];
      await app.say(
        tester,
        'Recoger el coche el sábado por la mañana y pagar la luz',
      );
      expect(find.text(es.captureAddTasks(2)), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('save-drafts')));
      final frames = <(bool, bool)>[];
      for (var frame = 0; frame < 60; frame++) {
        await tester.pump(const Duration(milliseconds: 16));
        // Lit: each row is lighting up to the highlight colour.
        final carLit = rowTarget(tester, 'Recoger el coche') == lit(tester);
        final inboxLit = inboxTarget(tester) == lit(tester);
        frames.add((carLit, inboxLit));
      }
      final first = frames.indexWhere((f) => f.$1 || f.$2);
      expect(first, isNot(-1), reason: 'something lit: $frames');
      expect(frames[first], (true, true), reason: 'same frame: $frames');
      expect(tester.takeException(), isNull);
      expect(
        find.text(DateFormat.MMMMEEEEd('es').format(saturday)),
        findsOneWidget,
      );
      // The undated task names no other day.
      expect(find.text(es.captureTasksAdded(2)), findsOneWidget);
      expect(find.byKey(const ValueKey('calendar-inbox')), findsOneWidget);
      // Both light fully, then both fade.
      await tester.pump(const Duration(milliseconds: 700));
      expect(
        tester.widget<TaskTile>(row('Recoger el coche')).color,
        lit(tester),
      );
      expect(inboxFill(tester), lit(tester));
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      expect(rowTarget(tester, 'Recoger el coche'), isNot(lit(tester)));
      expect(inboxTarget(tester), isNot(lit(tester)));
      expect(
        tester.widget<TaskTile>(row('Recoger el coche')).color,
        isNot(lit(tester)),
      );
      expect(inboxFill(tester), isNot(lit(tester)));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'U5 / P297: a Friday and a Saturday task in one save say Añadida al vie, … · también el sáb, …; Friday, Saturday and the next Monday say Añadida al vie, … · también en otros 2 días',
    (tester) async {
      final fri = friday();
      final sat = DateTime(fri.year, fri.month, fri.day + 1);
      final mon = DateTime(fri.year, fri.month, fri.day + 3);
      final app = await _App.open(tester, []);
      app.api.found = [
        found('Médico', at: DateTime(fri.year, fri.month, fri.day, 17)),
        found('Recoger el coche', on: sat),
      ];
      await app.say(tester, 'Médico el viernes y recoger el coche el sábado');
      await tester.tap(find.byKey(const ValueKey('save-drafts')));
      await tester.pumpAndSettle();
      final calendar = tester.element(find.byType(CalendarScreen));
      // The landing day is named with its task (P297).
      final two =
          '${es.taskAddedOn(calendar.weekdayDate(fri))} · ${es.captureAlsoOn(calendar.weekdayDate(sat))}';
      expect(two, startsWith('Añadida al vie'));
      expect(two, contains(' · también el '));
      expect(two, endsWith(calendar.weekdayDate(sat)));
      expect(calendar.weekdayDate(sat), startsWith('sáb'));
      expect(find.text(two), findsOneWidget);
      // Lands on the earliest day.
      expect(find.text(DateFormat.MMMMEEEEd('es').format(fri)), findsOneWidget);

      await tester.pump(const Duration(seconds: 11));
      await tester.pumpAndSettle();
      app.api.found = [
        found('Médico', at: DateTime(fri.year, fri.month, fri.day, 17)),
        found('Recoger el coche', on: sat),
        found('Llamar al banco', on: mon),
      ];
      await app.say(tester, 'Tres cosas en tres días');
      await tester.tap(find.byKey(const ValueKey('save-drafts')));
      await tester.pumpAndSettle();
      final three =
          '${es.taskAddedOn(calendar.weekdayDate(fri))} · ${es.captureAlsoOnDays(2)}';
      expect(three, endsWith(' · también en otros 2 días'));
      expect(find.text(three), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  // ---- 2026-10-15-changes · P119 (UX-701): the first-run example lands
  // both tasks on one day ----

  testWidgets(
    'UX-701: a new account says the first-run example; two tasks for tomorrow land on tomorrow, both lit, with 2 tareas añadidas al … and no también',
    (tester) async {
      final tomorrow = inDays(1);
      final app = await _App.open(tester, []);
      // A new account on Calendar, today shown, told what to say.
      expect(find.text(es.todayAgenda), findsOneWidget);
      expect(find.text(es.calendarTrySaying), findsOneWidget);
      app.api.found = [
        found('Llamar al dentista', on: tomorrow),
        found('Comprar pan', on: tomorrow),
      ];
      await app.speak(tester, 'Mañana, llamar al dentista y comprar pan');
      expect(find.text(es.captureAddTasks(2)), findsOneWidget);
      expect(es.captureAddTasks(2), 'Añadir 2 tareas');
      await tester.tap(find.byKey(const ValueKey('save-drafts')));
      await tester.pumpAndSettle();

      expect(find.byType(BottomSheet), findsNothing);
      // Tomorrow is selected.
      expect(
        find.text(DateFormat.MMMMEEEEd('es').format(tomorrow)),
        findsOneWidget,
      );
      expect(find.text(es.todayAgenda), findsNothing);
      for (final title in ['Llamar al dentista', 'Comprar pan']) {
        final saved = row(title);
        expect(saved.hitTestable(), findsOneWidget, reason: title);
        expect(
          tester.widget<TaskTile>(saved).color,
          lit(tester),
          reason: title,
        );
      }
      // UX-2203: one day for both, so the message names it.
      final calendar = tester.element(find.byType(CalendarScreen));
      expect(
        find.text(es.captureTasksAddedOn(2, calendar.weekdayDate(tomorrow))),
        findsOneWidget,
      );
      expect(find.textContaining('también'), findsNothing);
      expect(
        find.descendant(
          of: find.byType(SnackBar),
          matching: find.text(es.undo),
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  // ---- UX loop 2026-10-19-app, round 1 · P169 (UX-1309, UX-1405): lit rows
  // clear the message, and today after a while away ----

  group('P169: Calendar after a save and on return', () {
    setUpAll(() async {
      await (FontLoader(
        'Manrope',
      )..addFont(rootBundle.load('assets/fonts/Manrope.ttf'))).load();
      await (FontLoader(
        'MaterialIcons',
      )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    });

    DateTime at(int days, int hour, [int minute = 0]) =>
        DateTime(now.year, now.month, now.day + days, hour, minute);

    /// Today as the preview suite's `normalDay()` has it, with its own
    /// «Recoger a los niños del colegio» at 17:00.
    List<Task> normalDay() => [
      Task(
        id: 1,
        title: 'Paseo por el parque',
        dueDate: at(0, 8, 30),
        priority: 1,
        isCompleted: true,
      ),
      Task(
        id: 2,
        title: 'Llamar al médico para pedir cita',
        dueDate: at(0, 10),
        priority: 2,
        notes: 'Preguntar por los resultados de los análisis.',
      ),
      Task(id: 3, title: 'Comer con Ana', dueDate: at(0, 13, 30), priority: 1),
      Task(
        id: 4,
        title: 'Recoger a los niños del colegio',
        dueDate: at(0, 17),
        priority: 3,
        reminderMinutes: 30,
      ),
      Task(
        id: 5,
        title: 'Clase de yoga',
        dueDate: at(0, 19, 30),
        priority: 1,
        recurrence: 'weekly',
      ),
      Task(id: 6, title: 'Comprar pilas para el mando', priority: 1),
    ];

    /// The preview suite's three-task answer: two for today, one for Friday.
    List<Map<String, dynamic>> threeTasks() {
      final fri = friday();
      return [
        found('Comprar pan y leche', on: inDays(0)),
        found(
          'Llamar al médico',
          at: DateTime(fri.year, fri.month, fri.day, 10),
        ),
        found('Recoger a los niños del colegio', at: at(0, 17)),
      ];
    }

    /// The lit row of the saved task [title].
    Finder litRow(String title) => find.byWidgetPredicate(
      (widget) => widget is LandedTaskTile && widget.task.title == title,
    );

    bool isLit(WidgetTester tester, String title) =>
        tester.widget<LandedTaskTile>(litRow(title)).lit;

    Finder agenda() => find
        .descendant(
          of: find.descendant(
            of: find.byType(CalendarScreen),
            matching: find.byType(CustomScrollView),
          ),
          matching: find.byType(Scrollable),
        )
        .first;

    /// The agenda's visible area, under the app bar and the week.
    Rect agendaArea(WidgetTester tester) => tester.getRect(agenda());

    /// [title]'s lit row is entirely in the agenda, above the save message.
    void expectClear(WidgetTester tester, String title) {
      final row = litRow(title);
      // Rows far out of view aren't built.
      expect(row, findsOneWidget, reason: '$title is on screen');
      final rect = tester.getRect(row);
      final message = tester.getRect(find.byType(SnackBar));
      final area = agendaArea(tester);
      expect(
        rect.top,
        greaterThanOrEqualTo(area.top - 0.5),
        reason: '$title $rect, agenda $area',
      );
      expect(
        rect.bottom,
        lessThanOrEqualTo(message.top),
        reason: '$title $rect, message $message',
      );
      expect(isLit(tester, title), isTrue, reason: '$title is lit');
    }

    /// Saves the three tasks from Calendar on today, and waits as a phone
    /// would: past the message's entrance and the scroll, inside the 1.5 s
    /// highlight.
    Future<_App> saveThree(
      WidgetTester tester, {
      required List<Task> day,
      double textScale = 1,
      Size size = const Size(360, 800),
      DateTime Function()? clock,
    }) async {
      final app = await _App.open(
        tester,
        day,
        size: size,
        textScale: textScale,
        clock: clock,
      );
      expect(find.text(es.todayAgenda), findsOneWidget);
      app.api.found = threeTasks();
      await app.say(tester, 'Comprar pan y leche, llamar al médico el viernes '
          'a las diez y recoger a los niños a las cinco');
      expect(find.text(es.captureAddTasks(3)), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('save-drafts')));
      for (var frame = 0; frame < 48; frame++) {
        await tester.pump(const Duration(milliseconds: 25));
      }
      expect(find.byType(BottomSheet), findsNothing);
      expect(find.text(es.todayAgenda), findsOneWidget);
      return app;
    }

    void stillAnimations(WidgetTester tester) {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    }

    /// Today without its own 17:00 «Recoger a los niños del colegio»: a day
    /// doesn't hold the same task twice at the same time (P197).
    List<Task> dayWithoutPickUp() =>
        normalDay().where((task) => task.id != 4).toList();

    // P197 (UX-1309, round 2): acceptance 1 replaces round 1's 1x pair on
    // 360x800, whose fixture held the same 17:00 task twice.
    for (final still in [false, true]) {
      final how = still ? ', animations off' : '';
      testWidgets(
        'UX-1309: ES 1x on 393x852$how, after saving the three-task fixture from Calendar on today (no 17:00 Recoger of its own), Comprar pan y leche and the new Recoger a los niños del colegio are both entirely above the save message',
        (tester) async {
          if (still) stillAnimations(tester);
          await saveThree(
            tester,
            day: dayWithoutPickUp(),
            size: const Size(393, 852),
          );
          expect(
            litRow('Recoger a los niños del colegio'),
            findsOneWidget,
            reason: 'one row with that title',
          );
          expectClear(tester, 'Comprar pan y leche');
          expectClear(tester, 'Recoger a los niños del colegio');
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        },
      );
    }

    for (final still in [false, true]) {
      final how = still ? ', animations off' : '';
      for (final (name, day) in [
        ('normalDay', normalDay),
        ('normalDay minus id 4', dayWithoutPickUp),
      ]) {
        testWidgets(
          'UX-1309: ES 2x on 360x800$how ($name), after the same save, Comprar pan y leche is entirely above the save message, with no «Sin hora» line (UX-1418)',
          (tester) async {
            if (still) stillAnimations(tester);
            await saveThree(tester, day: day(), textScale: 2);
            // The whole row, to its last line, is above the message.
            expectClear(tester, 'Comprar pan y leche');
            expect(
              find.descendant(
                of: litRow('Comprar pan y leche'),
                matching: find.textContaining(es.anyTime),
              ),
              findsNothing,
              reason: 'a date-only row on Calendar has no time line',
            );
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
          },
        );
      }
    }

    testWidgets(
      'UX-1309 (b): when the lit block fits (a day with nothing else, 1x, 360x800), both lit rows are revealed above the save message',
      (tester) async {
        await saveThree(tester, day: const []);
        expectClear(tester, 'Comprar pan y leche');
        expectClear(tester, 'Recoger a los niños del colegio');
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'UX-1309 (c): at 2x the block doesn’t fit: the first lit row is in view; the one below the fold is still lit 3 s later, and is no longer lit 2 s after it has been scrolled into view',
      (tester) async {
        await saveThree(tester, day: normalDay(), textScale: 2);
        expectClear(tester, 'Comprar pan y leche');
        const later = 'Recoger a los niños del colegio';
        // The second lit row is out of view (or under the message).
        final area = agendaArea(tester);
        final message = tester.getRect(find.byType(SnackBar));
        final built = litRow(later).evaluate().isNotEmpty;
        if (built) {
          final rect = tester.getRect(litRow(later));
          expect(
            rect.top >= area.bottom || rect.bottom > message.top,
            isTrue,
            reason: 'out of view or under the message: $rect',
          );
        }
        for (var step = 0; step < 30; step++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        // The first row, seen at once, has faded.
        expect(isLit(tester, 'Comprar pan y leche'), isFalse);
        // Scrolled into view, under the app bar: still lit 3 s on.
        await tester.scrollUntilVisible(
          litRow(later),
          120,
          scrollable: agenda(),
          duration: const Duration(milliseconds: 16),
        );
        await tester.ensureVisible(litRow(later));
        await tester.pump();
        expect(isLit(tester, later), isTrue, reason: 'lit until it was seen');
        final rect = tester.getRect(litRow(later));
        expect(rect.top, greaterThanOrEqualTo(area.top - 0.5));
        expect(rect.bottom, lessThanOrEqualTo(message.top));
        for (var step = 0; step < 20; step++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(isLit(tester, later), isFalse, reason: 'faded 1.5 s after');
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );

    // ---- UX-1405 ----

    /// The app leaves for the background, and comes back after [away].
    Future<void> awayFor(
      WidgetTester tester,
      Duration away,
      void Function(Duration) advance,
    ) async {
      for (final state in [
        AppLifecycleState.inactive,
        AppLifecycleState.hidden,
        AppLifecycleState.paused,
      ]) {
        tester.binding.handleAppLifecycleStateChanged(state);
      }
      await tester.pump();
      advance(away);
      for (final state in [
        AppLifecycleState.hidden,
        AppLifecycleState.inactive,
        AppLifecycleState.resumed,
      ]) {
        tester.binding.handleAppLifecycleStateChanged(state);
      }
      await tester.pumpAndSettle();
    }

    /// Lands «Llevar el coche al taller» on Friday from Calendar.
    Future<_App> landOnFriday(WidgetTester tester, DateTime Function() clock) async {
      final day = friday();
      final app = await _App.open(tester, [], clock: clock);
      app.api.found = [
        found(
          'Llevar el coche al taller',
          at: DateTime(day.year, day.month, day.day, 17),
        ),
      ];
      await app.say(tester, 'Llevar el coche al taller el viernes a las 17');
      await tester.tap(find.byKey(const ValueKey('save-drafts')));
      await tester.pumpAndSettle();
      expect(find.text(DateFormat.MMMMEEEEd('es').format(day)), findsOneWidget);
      expect(find.text(es.todayAgenda), findsNothing);
      // The message goes.
      await tester.pump(const Duration(seconds: 11));
      await tester.pumpAndSettle();
      return app;
    }

    testWidgets(
      'UX-1405: after a landing on Friday, resuming 31 minutes later shows Agenda de hoy with today selected',
      (tester) async {
        var clock = DateTime.now();
        await landOnFriday(tester, () => clock);
        await awayFor(
          tester,
          const Duration(minutes: 31),
          (away) => clock = clock.add(away),
        );
        expect(find.text(es.todayAgenda), findsOneWidget);
        expect(
          find.text(DateFormat.MMMMEEEEd('es').format(friday())),
          findsNothing,
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'UX-1405: after a landing on Friday, resuming 5 minutes later keeps Friday',
      (tester) async {
        var clock = DateTime.now();
        await landOnFriday(tester, () => clock);
        await awayFor(
          tester,
          const Duration(minutes: 5),
          (away) => clock = clock.add(away),
        );
        expect(
          find.text(DateFormat.MMMMEEEEd('es').format(friday())),
          findsOneWidget,
        );
        expect(find.text(es.todayAgenda), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'UX-1405 / D9: a day the person picked, 5 minutes away and back, still goes to the next capture',
      (tester) async {
        // A later day in the week shown: a capture takes Calendar's day only
        // when it is after today. On a Sunday, the last day of the week, the
        // app's clock starts on Saturday at noon, so Sunday is that later day.
        final sunday = now.weekday == DateTime.sunday;
        var clock = sunday ? inDays(-1, 12) : DateTime.now();
        final app = await _App.open(tester, [], clock: () => clock);
        final picked = inDays(sunday ? 0 : 1);
        await tester.tap(
          find
              .descendant(
                of: find.byType(CalendarScreen),
                matching: find.text('${picked.day}'),
              )
              .hitTestable()
              .first,
        );
        await tester.pumpAndSettle();
        expect(
          find.text(DateFormat.MMMMEEEEd('es').format(picked)),
          findsOneWidget,
        );
        await awayFor(
          tester,
          const Duration(minutes: 5),
          (away) => clock = clock.add(away),
        );
        expect(
          find.text(DateFormat.MMMMEEEEd('es').format(picked)),
          findsOneWidget,
        );
        await app.say(tester, 'Comprar pan', submit: false);
        final day = app.store.current?.day;
        expect(day, isNotNull, reason: 'the capture got the picked day');
        expect(Task.dateKey(day!), Task.dateKey(picked));
        await tester.tap(
          find.descendant(
            of: find.byType(VoiceTaskScreen),
            matching: find.widgetWithText(TextButton, es.cancel),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'UX-1405: after midnight, resuming shows today even though a landing had chosen another day',
      (tester) async {
        // 23:50 tonight; back at 00:10, 20 minutes later, on a new day.
        var clock = at(0, 23, 50);
        await landOnFriday(tester, () => clock);
        await awayFor(
          tester,
          const Duration(minutes: 20),
          (away) => clock = clock.add(away),
        );
        expect(Task.day(clock), Task.day(inDays(1)));
        expect(find.text(es.todayAgenda), findsOneWidget);
        expect(
          find.text(DateFormat.MMMMEEEEd('es').format(friday())),
          findsNothing,
        );
        expect(tester.takeException(), isNull);
      },
    );

    // ---- P197 (UX-1628, round 2): back to today, at the top ----

    ScrollPosition agendaScroll(WidgetTester tester) =>
        tester.state<ScrollableState>(agenda()).position;

    /// The titles of the agenda's rows built now, on screen or near it.
    List<String> rows(WidgetTester tester) => [
      for (final element in find
          .descendant(
            of: find.byType(CalendarScreen),
            matching: find.byWidgetPredicate(
              (widget) => widget is TaskTile || widget is LandedTaskTile,
            ),
          )
          .evaluate())
        switch (element.widget) {
          TaskTile(:final task) => task.title,
          LandedTaskTile(:final task) => task.title,
          _ => '',
        },
    ];

    /// Eight tasks on [date] before 17:00, so a 17:00 landing scrolls at 2x.
    List<Task> busy(DateTime date, int firstId) => [
      for (var hour = 8; hour < 16; hour++)
        Task(
          id: firstId + hour,
          title: 'Tarea de las $hour',
          dueDate: DateTime(date.year, date.month, date.day, hour),
          priority: 1,
        ),
    ];

    /// The «Agenda de hoy» header is entirely inside the agenda's viewport,
    /// not just built.
    void expectTodayAtTop(WidgetTester tester) {
      final header = find.text(es.todayAgenda);
      expect(header, findsOneWidget);
      final position = agendaScroll(tester);
      expect(
        position.pixels,
        moreOrLessEquals(position.minScrollExtent, epsilon: 0.5),
        reason: 'the agenda starts at the top',
      );
      final rect = tester.getRect(header);
      final area = agendaArea(tester);
      expect(rect.top, greaterThanOrEqualTo(area.top - 0.5), reason: '$rect in $area');
      expect(rect.bottom, lessThanOrEqualTo(area.bottom + 0.5), reason: '$rect in $area');
    }

    /// At 2x on 360x800, lands «Llevar el coche al taller» at 17:00 on a busy
    /// Friday, waits for the message to go, and returns the agenda's offset,
    /// which the landing left above its minimum.
    Future<double> landLowOnFriday(
      WidgetTester tester,
      DateTime Function() clock,
    ) async {
      final day = friday();
      final app = await _App.open(
        tester,
        [...normalDay(), ...busy(day, 100)],
        clock: clock,
        size: const Size(360, 800),
        textScale: 2,
      );
      app.api.found = [
        found(
          'Llevar el coche al taller',
          at: DateTime(day.year, day.month, day.day, 17),
        ),
      ];
      await app.say(tester, 'Llevar el coche al taller el viernes a las 17');
      await tester.tap(find.byKey(const ValueKey('save-drafts')));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 11));
      await tester.pumpAndSettle();
      // Friday is shown: its rows, not today's.
      expect(rows(tester), contains('Llevar el coche al taller'));
      expect(rows(tester), isNot(contains('Comer con Ana')));
      final position = agendaScroll(tester);
      expect(
        position.pixels,
        greaterThan(position.minScrollExtent),
        reason: 'the landing scrolled the agenda',
      );
      return position.pixels;
    }

    testWidgets(
      'UX-1628: ES 2x on 360x800, after a landing on Friday that scrolled the agenda, resuming 31 minutes later selects today with the agenda at its minimum offset and Agenda de hoy inside the viewport',
      (tester) async {
        var clock = DateTime.now();
        await landLowOnFriday(tester, () => clock);
        await awayFor(
          tester,
          const Duration(minutes: 31),
          (away) => clock = clock.add(away),
        );
        expect(
          find.text(DateFormat.MMMMEEEEd('es').format(friday())),
          findsNothing,
        );
        expect(rows(tester), contains('Llamar al médico para pedir cita'));
        expect(rows(tester), isNot(contains('Llevar el coche al taller')));
        // Today is long enough at 2x that a kept offset would show.
        expect(agendaScroll(tester).maxScrollExtent, greaterThan(0));
        expectTodayAtTop(tester);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'UX-1628: ES 2x on 360x800, after a landing on today that scrolled the agenda, resuming after midnight shows the new day with the agenda at its minimum offset',
      (tester) async {
        // 23:50 tonight; back at 00:10, 20 minutes later, on a new day.
        var clock = at(0, 23, 50);
        await saveThree(
          tester,
          day: [...normalDay(), ...busy(inDays(1), 200)],
          textScale: 2,
          clock: () => clock,
        );
        await tester.pump(const Duration(seconds: 11));
        await tester.pumpAndSettle();
        final before = agendaScroll(tester);
        expect(
          before.pixels,
          greaterThan(before.minScrollExtent),
          reason: 'the landing scrolled the agenda',
        );
        await awayFor(
          tester,
          const Duration(minutes: 20),
          (away) => clock = clock.add(away),
        );
        expect(Task.day(clock), Task.day(inDays(1)));
        // The new day: its own rows lead; yesterday's open tasks, now
        // overdue, follow them (P269, UX-2302).
        expect(rows(tester).first, 'Tarea de las 8');
        expect(agendaScroll(tester).maxScrollExtent, greaterThan(0));
        expectTodayAtTop(tester);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'UX-1628: ES 2x on 360x800, resuming 5 minutes after the Friday landing keeps Friday selected and the scroll offset unchanged',
      (tester) async {
        var clock = DateTime.now();
        final offset = await landLowOnFriday(tester, () => clock);
        await awayFor(
          tester,
          const Duration(minutes: 5),
          (away) => clock = clock.add(away),
        );
        expect(rows(tester), contains('Llevar el coche al taller'));
        expect(rows(tester), isNot(contains('Comer con Ana')));
        expect(find.text(es.todayAgenda), findsNothing);
        expect(agendaScroll(tester).pixels, moreOrLessEquals(offset, epsilon: 0.5));
        expect(tester.takeException(), isNull);
      },
    );
  });

  group('P276 · a save the page can’t list lands on Calendar', () {
    Finder taskPage() => find.byWidgetPredicate(
      (widget) => widget is HomeScreen && !widget.isRoot,
    );

    /// Calendar's «Sin fecha · 1», tapped: the Sin fecha page.
    Future<void> openSinFecha(WidgetTester tester) async {
      final count = find.byKey(const ValueKey('calendar-inbox'));
      await tester.ensureVisible(count);
      await tester.pumpAndSettle();
      expect(
        find.descendant(of: count, matching: find.text(es.inboxCount(1))),
        findsOneWidget,
      );
      await tester.tap(count);
      await tester.pumpAndSettle();
      expect(taskPage(), findsOneWidget);
      expect(
        find.descendant(
          of: find.descendant(of: taskPage(), matching: find.byType(AppBar)),
          matching: find.text(es.inbox),
        ),
        findsOneWidget,
      );
    }

    /// Calendar in front on [day], [title]'s row lit and in view, clear of
    /// the save message.
    void expectLandedOn(WidgetTester tester, DateTime day, String title) {
      expect(taskPage(), findsNothing, reason: 'the page was closed');
      expect(find.byType(BottomSheet), findsNothing);
      expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        0,
      );
      expect(find.text(DateFormat.MMMMEEEEd('es').format(day)), findsOneWidget);
      final saved = find.descendant(
        of: find.byType(CalendarScreen),
        matching: row(title),
      );
      expect(saved.hitTestable(), findsOneWidget);
      expect(tester.widget<TaskTile>(saved).color, lit(tester));
      expect(
        tester.getRect(saved).bottom,
        lessThanOrEqualTo(tester.getRect(find.byType(SnackBar)).top),
      );
    }

    testWidgets(
      'UX-2307: from Calendar’s «Sin fecha · 1», a capture saved for tomorrow on the Sin fecha page lands on Calendar on tomorrow with the row lit and «Añadida al …» with Deshacer; Deshacer removes it',
      (tester) async {
        final tomorrow = inDays(1);
        final app = await _App.open(tester, [
          Task(id: 1, title: 'Ordenar el trastero', priority: 1),
        ]);
        await openSinFecha(tester);
        app.api.found = [found('Comprar pilas', on: tomorrow)];
        await app.say(tester, 'Mañana comprar pilas');
        expect(find.byType(CaptureResult), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('save-drafts')));
        await tester.pumpAndSettle();

        expectLandedOn(tester, tomorrow, 'Comprar pilas');
        final calendar = tester.element(find.byType(CalendarScreen));
        final message = es.taskAddedOn(calendar.weekdayDate(tomorrow));
        expect(message, startsWith('Añadida al '));
        expect(
          find.descendant(
            of: find.byType(SnackBar),
            matching: find.text(message),
          ),
          findsOneWidget,
        );
        final undo = find.descendant(
          of: find.byType(SnackBar),
          matching: find.text(es.undo),
        );
        expect(undo, findsOneWidget);

        await tester.tap(undo);
        await tester.pumpAndSettle();
        expect(app.tasks.titles(), isNot(contains('Comprar pilas')));
        expect(app.tasks.titles(), contains('Ordenar el trastero'));
        expect(app.store.undos, 1);
        expect(
          find.descendant(
            of: find.byType(CalendarScreen),
            matching: row('Comprar pilas'),
          ),
          findsNothing,
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'UX-2307: on a project page, a dictation that puts its task in another project lands on Calendar on the task’s day, with the row lit',
      (tester) async {
        final day = inDays(3);
        final app = await _App.open(
          tester,
          [],
          projects: [
            TaskListInfo(id: 'casa', name: 'Casa'),
            TaskListInfo(id: 'trabajo', name: 'Trabajo'),
          ],
        );
        await tester.tap(
          find.descendant(
            of: find.byType(NavigationBar),
            matching: find.text(es.tasks),
          ),
        );
        await tester.pumpAndSettle();
        unawaited(
          Navigator.of(tester.element(find.byType(HomeScreen))).push(
            MaterialPageRoute<void>(
              builder: (_) => const HomeScreen(isRoot: false, listId: 'casa'),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(taskPage(), findsOneWidget);
        app.api.found = [
          {...found('Preparar la reunión', on: day), 'list_id': 'trabajo'},
        ];
        await app.say(tester, 'Preparar la reunión de trabajo');
        expect(find.byType(CaptureResult), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('save-drafts')));
        await tester.pumpAndSettle();

        final saved = app.tasks.state.requireValue.singleWhere(
          (task) => task.title == 'Preparar la reunión',
        );
        expect(saved.listId, 'trabajo');
        expectLandedOn(tester, day, 'Preparar la reunión');
        expect(
          find.descendant(
            of: find.byType(SnackBar),
            matching: find.text(es.undo),
          ),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );
  });

  // ---- UX loop 2026-10-28-app, round 1 · P274 (UX-2203): after a landing,
  // a line on screen names the lit rows' day ----
  group('P274 · the day heading after a landing', () {
    setUpAll(() async {
      await (FontLoader(
        'Manrope',
      )..addFont(rootBundle.load('assets/fonts/Manrope.ttf'))).load();
      await (FontLoader(
        'MaterialIcons',
      )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    });

    DateTime at(int days, int hour, [int minute = 0]) =>
        DateTime(now.year, now.month, now.day + days, hour, minute);

    /// The preview suite's `normalDay()` without its own 17:00 «Recoger a
    /// los niños del colegio», as `calendar/agenda.added` opens it.
    List<Task> addedDay() => [
      Task(
        id: 1,
        title: 'Paseo por el parque',
        dueDate: at(0, 8, 30),
        priority: 1,
        isCompleted: true,
      ),
      Task(
        id: 2,
        title: 'Llamar al médico para pedir cita',
        dueDate: at(0, 10),
        priority: 2,
        notes: 'Preguntar por los resultados de los análisis.',
      ),
      Task(id: 3, title: 'Comer con Ana', dueDate: at(0, 13, 30), priority: 1),
      Task(
        id: 5,
        title: 'Clase de yoga',
        dueDate: at(0, 19, 30),
        priority: 1,
        recurrence: 'weekly',
      ),
      Task(id: 6, title: 'Comprar pilas para el mando', priority: 1),
      Task(
        id: 7,
        title: 'Pagar la factura de la luz',
        dueDate: DateTime(now.year, now.month, now.day + 2),
        hasTime: false,
        priority: 2,
      ),
    ];

    /// The preview's three-task answer: two today, one on Friday at 10.
    List<Map<String, dynamic>> threeTasks() {
      final fri = friday();
      return [
        found('Comprar pan y leche', on: inDays(0)),
        found(
          'Llamar al médico',
          at: DateTime(fri.year, fri.month, fri.day, 10),
        ),
        found('Recoger a los niños del colegio', at: at(0, 17)),
      ];
    }

    Finder litRow(String title) => find.byWidgetPredicate(
      (widget) => widget is LandedTaskTile && widget.task.title == title,
    );

    Rect agendaArea(WidgetTester tester) => tester.getRect(
      find
          .descendant(
            of: find.descendant(
              of: find.byType(CalendarScreen),
              matching: find.byType(CustomScrollView),
            ),
            matching: find.byType(Scrollable),
          )
          .first,
    );

    /// [what] at [rect] is entirely in the agenda, above the save message.
    void expectShown(WidgetTester tester, Rect rect, String what) {
      final area = agendaArea(tester);
      final message = tester.getRect(find.byType(SnackBar));
      expect(
        rect.top,
        greaterThanOrEqualTo(area.top - 0.5),
        reason: '$what $rect, agenda $area',
      );
      expect(
        rect.bottom,
        lessThanOrEqualTo(message.top + 0.5),
        reason: '$what $rect, message $message',
      );
    }

    /// The status bar and the gesture bar, 24 dp each, as on an Android
    /// phone drawn edge to edge and as the preview suite draws them.
    void phoneBars(WidgetTester tester) {
      tester.view.padding = const FakeViewPadding(top: 24, bottom: 24);
      tester.view.viewPadding = const FakeViewPadding(top: 24, bottom: 24);
      addTearDown(tester.view.reset);
    }

    /// The tap, then the message's entrance and the landing's scroll,
    /// inside the 1.5 s highlight.
    Future<void> saveAndLand(WidgetTester tester) async {
      await tester.tap(find.byKey(const ValueKey('save-drafts')));
      for (var frame = 0; frame < 48; frame++) {
        await tester.pump(const Duration(milliseconds: 25));
      }
      expect(find.byType(BottomSheet), findsNothing);
      expect(find.byType(SnackBar), findsOneWidget);
    }

    // At 360×800 the heading doesn't fit with both lit rows above the
    // message, so the message names their day instead (P297, by the
    // organizer's decision in plan.md, Round 2 (b1)).
    for (final size in [const Size(360, 800), const Size(393, 852)]) {
      final names = size.width < 380;
      testWidgets(
        'UX-2203: ES 1x on ${size.width.round()}×${size.height.round()}, '
        'calendar/agenda.added (three tasks, two today; status and gesture bars): '
        '${names ? 'the message names today and the other day' : 'the day heading «${es.todayAgenda}»'} '
        'and both lit rows show above the message',
        (tester) async {
          phoneBars(tester);
          final app = await _App.open(
            tester,
            addedDay(),
            size: size,
            clock: () => at(0, 9, 41),
          );
          expect(find.text(es.todayAgenda), findsOneWidget);
          app.api.found = threeTasks();
          await app.say(
            tester,
            'Comprar pan y leche, llamar al médico el viernes a las diez y '
            'recoger a los niños del colegio a las cinco',
          );
          await saveAndLand(tester);
          for (final title in [
            'Comprar pan y leche',
            'Recoger a los niños del colegio',
          ]) {
            expect(litRow(title), findsOneWidget, reason: title);
            expectShown(tester, tester.getRect(litRow(title)), title);
          }
          if (names) {
            final calendar = tester.element(find.byType(CalendarScreen));
            final today = calendar.weekdayDate(at(0, 0));
            final fri = calendar.weekdayDate(friday());
            expect(
              find.descendant(
                of: find.byType(SnackBar),
                matching: find.text(
                  '${es.captureTasksAddedOn(2, today)} · '
                  '${es.captureAlsoOn(fri)}',
                ),
              ),
              findsOneWidget,
            );
          } else {
            final heading = find.text(es.todayAgenda);
            expect(heading, findsOneWidget);
            expectShown(tester, tester.getRect(heading), 'the day heading');
          }
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        },
      );
    }

    testWidgets(
      'UX-2203: ES 1x on 360×800, two tasks said for tomorrow evening after '
      'two there in the morning: the day heading names tomorrow and shows '
      'with both lit rows above «2 tareas añadidas al …»',
      (tester) async {
        phoneBars(tester);
        final tomorrow = inDays(1);
        final app = await _App.open(tester, [
          for (final (index, hour) in [8, 9].indexed)
            Task(
              id: 10 + index,
              title: 'Tarea de las $hour',
              dueDate: at(1, hour),
              priority: 1,
            ),
        ], size: const Size(360, 800));
        app.api.found = [
          found('Llamar al dentista', at: at(1, 18)),
          found('Comprar pan', at: at(1, 19)),
        ];
        await app.say(tester, 'Mañana a las seis llamar al dentista y a las '
            'siete comprar pan');
        await saveAndLand(tester);
        final heading = find.text(DateFormat.MMMMEEEEd('es').format(tomorrow));
        expect(heading, findsOneWidget);
        for (final title in ['Llamar al dentista', 'Comprar pan']) {
          expect(litRow(title), findsOneWidget, reason: title);
          expectShown(tester, tester.getRect(litRow(title)), title);
        }
        expectShown(tester, tester.getRect(heading), 'the day heading');
        final calendar = tester.element(find.byType(CalendarScreen));
        expect(
          find.descendant(
            of: find.byType(SnackBar),
            matching: find.text(
              es.captureTasksAddedOn(2, calendar.weekdayDate(tomorrow)),
            ),
          ),
          findsOneWidget,
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );
  });

  // ---- UX loop 2026-10-28-app, round 2 · P297 (UX-2203): a save on
  // several days names the day Calendar lands on ----
  group('P297 · landing after a save and after Deshacer', () {
    setUpAll(() async {
      await (FontLoader(
        'Manrope',
      )..addFont(rootBundle.load('assets/fonts/Manrope.ttf'))).load();
      await (FontLoader(
        'MaterialIcons',
      )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    });

    DateTime at(int days, int hour, [int minute = 0]) =>
        DateTime(now.year, now.month, now.day + days, hour, minute);

    /// `calendar/agenda.added`'s answer: two today, one on Friday at 10.
    List<Map<String, dynamic>> threeTasks() {
      final fri = friday();
      return [
        found('Comprar pan y leche', on: inDays(0)),
        found(
          'Llamar al médico',
          at: DateTime(fri.year, fri.month, fri.day, 10),
        ),
        found('Recoger a los niños del colegio', at: at(0, 17)),
      ];
    }

    Finder inMessage(Finder finder) =>
        find.descendant(of: find.byType(SnackBar), matching: finder);

    /// Saves, waits past the message's entrance and the landing.
    Future<void> save(WidgetTester tester) async {
      await tester.tap(find.byKey(const ValueKey('save-drafts')));
      for (var frame = 0; frame < 48; frame++) {
        await tester.pump(const Duration(milliseconds: 25));
      }
      expect(find.byType(BottomSheet), findsNothing);
      expect(find.byType(SnackBar), findsOneWidget);
    }

    /// [text] is in the message, whole: not cut, inside the message and the
    /// screen.
    void expectWhole(WidgetTester tester, Finder text, Size size) {
      expect(text, findsOneWidget);
      final paragraph = tester.renderObject<RenderParagraph>(
        find.descendant(of: text, matching: find.byType(RichText)).first,
      );
      expect(paragraph.didExceedMaxLines, isFalse, reason: 'not cut');
      final box = tester.getRect(text);
      final bar = tester.getRect(find.byType(SnackBar));
      expect(box.left, greaterThanOrEqualTo(bar.left - 0.5), reason: '$box');
      expect(box.right, lessThanOrEqualTo(bar.right + 0.5), reason: '$box');
      expect(box.top, greaterThanOrEqualTo(bar.top - 0.5), reason: '$box');
      expect(box.bottom, lessThanOrEqualTo(bar.bottom + 0.5), reason: '$box');
      expect(bar.left, greaterThanOrEqualTo(0));
      expect(bar.right, lessThanOrEqualTo(size.width));
      expect(bar.bottom, lessThanOrEqualTo(size.height));
    }

    for (final (language, start) in [
      ('en', '2 tasks added to '),
      ('ca', '2 tasques afegides al '),
    ]) {
      testWidgets(
        'UX-2203: $language 2x on 360×800, two tasks today and one on Friday '
        '(calendar/agenda.added): the message names today, «$start…», then '
        'the other day, whole',
        (tester) async {
          const size = Size(360, 800);
          final l = lookupAppLocalizations(Locale(language));
          final app = await _App.open(
            tester,
            [],
            size: size,
            textScale: 2,
            language: language,
            clock: () => at(0, 9, 41),
          );
          app.api.found = threeTasks();
          await app.say(tester, 'Tres cosas', l: l);
          await save(tester);
          final calendar = tester.element(find.byType(CalendarScreen));
          final today = calendar.weekdayDate(inDays(0));
          final fri = calendar.weekdayDate(friday());
          final named = l.captureTasksAddedOn(2, today);
          expect(named, '$start$today');
          final message = '$named · ${l.captureAlsoOn(fri)}';
          expect(message, endsWith(fri));
          expectWhole(tester, inMessage(find.text(message)), size);
          expect(message, isNot(contains('…')));
          expect(inMessage(find.text(l.undo)), findsOneWidget);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        },
      );
    }

    testWidgets(
      'UX-2203: two tasks today and one with no date: the message keeps '
      '«3 tareas añadidas», no day named',
      (tester) async {
        final app = await _App.open(tester, []);
        app.api.found = [
          found('Comprar pan', at: at(0, 18)),
          found('Llamar a Ana', at: at(0, 19)),
          found('Ordenar el trastero'),
        ];
        await app.say(tester, 'Tres cosas');
        await save(tester);
        expect(es.captureTasksAdded(3), '3 tareas añadidas');
        expect(inMessage(find.text(es.captureTasksAdded(3))), findsOneWidget);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'UX-2203: two tasks for tomorrow: «2 tareas añadidas al {tomorrow}», '
      'nothing after it (P274, unchanged)',
      (tester) async {
        final app = await _App.open(tester, []);
        app.api.found = [
          found('Llamar al dentista', at: at(1, 18)),
          found('Comprar pan', at: at(1, 19)),
        ];
        await app.say(tester, 'Mañana dos cosas');
        await save(tester);
        final calendar = tester.element(find.byType(CalendarScreen));
        final message = es.captureTasksAddedOn(
          2,
          calendar.weekdayDate(inDays(1)),
        );
        expect(message, startsWith('2 tareas añadidas al '));
        expect(inMessage(find.text(message)), findsOneWidget);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'UX-2203: one task today and one on Friday: «Añadida al {today} · '
      'también el {Friday}»',
      (tester) async {
        final fri = friday();
        final app = await _App.open(tester, [], clock: () => at(0, 9, 41));
        app.api.found = [
          found('Comprar pan', at: at(0, 18)),
          found(
            'Llamar al médico',
            at: DateTime(fri.year, fri.month, fri.day, 10),
          ),
        ];
        await app.say(tester, 'Dos cosas');
        await save(tester);
        final calendar = tester.element(find.byType(CalendarScreen));
        final today = calendar.weekdayDate(inDays(0));
        final message =
            '${es.taskAddedOn(today)} · '
            '${es.captureAlsoOn(calendar.weekdayDate(fri))}';
        expect(message, startsWith('Añadida al $today · también el '));
        expect(inMessage(find.text(message)), findsOneWidget);
        // Calendar is on today, where the message says.
        expect(find.text(es.todayAgenda), findsOneWidget);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );
  });

  // ---- UX loop 2026-10-28-app, round 2 · P305 (UX-2629): Return to today
  // lands at the top again, whatever the heights ----
  group('P305 · back to today at the top, whatever the heights', () {
    setUpAll(() async {
      await (FontLoader(
        'Manrope',
      )..addFont(rootBundle.load('assets/fonts/Manrope.ttf'))).load();
      await (FontLoader(
        'MaterialIcons',
      )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    });

    DateTime at(int days, int hour, [int minute = 0]) =>
        DateTime(now.year, now.month, now.day + days, hour, minute);

    /// Today, long enough at large text that a kept offset would show.
    List<Task> today() => [
      Task(
        id: 1,
        title: 'Paseo por el parque',
        dueDate: at(0, 8, 30),
        priority: 1,
        isCompleted: true,
      ),
      Task(
        id: 2,
        title: 'Llamar al médico para pedir cita',
        dueDate: at(0, 10),
        priority: 2,
        notes: 'Preguntar por los resultados de los análisis.',
      ),
      Task(id: 3, title: 'Comer con Ana', dueDate: at(0, 13, 30), priority: 1),
      Task(
        id: 4,
        title: 'Recoger a los niños del colegio',
        dueDate: at(0, 17),
        priority: 3,
        reminderMinutes: 30,
      ),
      Task(
        id: 5,
        title: 'Clase de yoga',
        dueDate: at(0, 19, 30),
        priority: 1,
        recurrence: 'weekly',
      ),
      Task(id: 6, title: 'Comprar pilas para el mando', priority: 1),
    ];

    /// Eight tasks on [date] before 17:00, so a 17:00 landing scrolls.
    List<Task> busy(DateTime date, int firstId) => [
      for (var hour = 8; hour < 16; hour++)
        Task(
          id: firstId + hour,
          title: 'Tarea de las $hour',
          dueDate: DateTime(date.year, date.month, date.day, hour),
          priority: 1,
        ),
    ];

    Finder agenda() => find
        .descendant(
          of: find.descendant(
            of: find.byType(CalendarScreen),
            matching: find.byType(CustomScrollView),
          ),
          matching: find.byType(Scrollable),
        )
        .first;

    ScrollPosition agendaScroll(WidgetTester tester) =>
        tester.state<ScrollableState>(agenda()).position;

    /// The titles of the agenda's rows built now.
    List<String> rows(WidgetTester tester) => [
      for (final element in find
          .descendant(
            of: find.byType(CalendarScreen),
            matching: find.byWidgetPredicate(
              (widget) => widget is TaskTile || widget is LandedTaskTile,
            ),
          )
          .evaluate())
        switch (element.widget) {
          TaskTile(:final task) => task.title,
          LandedTaskTile(:final task) => task.title,
          _ => '',
        },
    ];

    /// The app leaves for the background, and comes back after [away].
    Future<void> awayFor(
      WidgetTester tester,
      Duration away,
      void Function(Duration) advance,
    ) async {
      for (final state in [
        AppLifecycleState.inactive,
        AppLifecycleState.hidden,
        AppLifecycleState.paused,
      ]) {
        tester.binding.handleAppLifecycleStateChanged(state);
      }
      await tester.pump();
      advance(away);
      for (final state in [
        AppLifecycleState.hidden,
        AppLifecycleState.inactive,
        AppLifecycleState.resumed,
      ]) {
        tester.binding.handleAppLifecycleStateChanged(state);
      }
      await tester.pumpAndSettle();
    }

    /// Lands «Llevar el coche al taller» at 17:00 on a busy Friday, waits
    /// for the message to go, and returns the offset the landing left.
    Future<double> landLowOnFriday(
      WidgetTester tester,
      DateTime Function() clock, {
      required Size size,
      required double textScale,
    }) async {
      final day = friday();
      final app = await _App.open(
        tester,
        [...today(), ...busy(day, 100)],
        clock: clock,
        size: size,
        textScale: textScale,
      );
      app.api.found = [
        found(
          'Llevar el coche al taller',
          at: DateTime(day.year, day.month, day.day, 17),
        ),
      ];
      await app.say(tester, 'Llevar el coche al taller el viernes a las 17');
      await tester.tap(find.byKey(const ValueKey('save-drafts')));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 11));
      await tester.pumpAndSettle();
      expect(rows(tester), contains('Llevar el coche al taller'));
      expect(rows(tester), isNot(contains('Comer con Ana')));
      final position = agendaScroll(tester);
      expect(
        position.pixels,
        greaterThan(position.minScrollExtent),
        reason: 'the landing scrolled the agenda',
      );
      return position.pixels;
    }

    /// Today is shown with «Agenda de hoy» whole inside the agenda, and the
    /// agenda at its minimum offset.
    void expectTodayAtTop(WidgetTester tester) {
      final header = find.text(es.todayAgenda);
      expect(header, findsOneWidget);
      final position = agendaScroll(tester);
      expect(
        position.pixels,
        moreOrLessEquals(position.minScrollExtent, epsilon: 0.5),
        reason: 'the agenda starts at the top',
      );
      final rect = tester.getRect(header);
      final area = tester.getRect(agenda());
      expect(rect.top, greaterThanOrEqualTo(area.top - 0.5), reason: '$rect in $area');
      expect(
        rect.bottom,
        lessThanOrEqualTo(area.bottom + 0.5),
        reason: '$rect in $area',
      );
    }

    // Each size and text scale gives the bottom bar, the rows and the
    // viewport other heights; the return to today must not depend on them.
    for (final (size, textScale) in [
      (const Size(360, 800), 2.0),
      (const Size(360, 740), 2.0),
      (const Size(320, 800), 2.0),
      (const Size(412, 915), 2.0),
      (const Size(360, 800), 1.5),
      (const Size(360, 640), 1.3),
    ]) {
      testWidgets(
        'UX-2629: ES ${textScale}x on '
        '${size.width.round()}×${size.height.round()}, after a Friday '
        'landing that scrolled the agenda, resuming 31 minutes later shows '
        'today at its minimum offset with «Agenda de hoy» in view, and it '
        'stays there',
        (tester) async {
          var clock = DateTime.now();
          await landLowOnFriday(
            tester,
            () => clock,
            size: size,
            textScale: textScale,
          );
          await awayFor(
            tester,
            const Duration(minutes: 31),
            (away) => clock = clock.add(away),
          );
          expect(
            find.text(DateFormat.MMMMEEEEd('es').format(friday())),
            findsNothing,
          );
          expect(rows(tester), contains('Llamar al médico para pedir cita'));
          expect(rows(tester), isNot(contains('Llevar el coche al taller')));
          // Today is long enough that a kept offset would show.
          expect(agendaScroll(tester).maxScrollExtent, greaterThan(0));
          expectTodayAtTop(tester);
          // Nothing left over from the landing moves it later.
          await tester.pump(const Duration(seconds: 2));
          await tester.pumpAndSettle();
          expectTodayAtTop(tester);
          expect(tester.takeException(), isNull);
        },
      );
    }

    testWidgets(
      'UX-2629: ES 2.0x on 360×740, resuming 5 minutes after the Friday '
      'landing keeps Friday and its scroll',
      (tester) async {
        var clock = DateTime.now();
        final offset = await landLowOnFriday(
          tester,
          () => clock,
          size: const Size(360, 740),
          textScale: 2,
        );
        await awayFor(
          tester,
          const Duration(minutes: 5),
          (away) => clock = clock.add(away),
        );
        expect(rows(tester), contains('Llevar el coche al taller'));
        expect(rows(tester), isNot(contains('Comer con Ana')));
        expect(find.text(es.todayAgenda), findsNothing);
        expect(
          agendaScroll(tester).pixels,
          moreOrLessEquals(offset, epsilon: 0.5),
        );
        expect(tester.takeException(), isNull);
      },
    );
  });
}

/// The app in Spanish with a 24-hour clock, on Calendar, with capture
/// answered by [api] and kept in [store].
class _App {
  _App(this.container, this.store, this.api, this.tasks, this.speech);
  final ProviderContainer container;
  final _Captures store;
  final _Api api;
  final _Tasks tasks;
  final _Speech speech;

  /// With [cloud], the app's own task list reads a signed-in account's
  /// repository, as on a phone, and a save writes to it.
  static Future<_App> open(
    WidgetTester tester,
    List<Task> initial, {
    Size size = const Size(390, 844),
    _SlowCloud? cloud,
    // The app's clock (calendarClockProvider), read each time it is asked.
    DateTime Function()? clock,
    double textScale = 1,
    // The account's projects, for project pages.
    List<TaskListInfo> projects = const [],
    // The app's language.
    String language = 'es',
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    if (textScale != 1) {
      tester.platformDispatcher.textScaleFactorTestValue = textScale;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    }
    final store = _Captures()..cloud = cloud;
    final api = _Api();
    final tasks = _Tasks(initial);
    final speech = _Speech();
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
            RegionalPreferences(
              language: language,
              clock: ClockFormat.twentyFour,
              weekStart: 1,
            ),
          ),
        ),
        taskListsProvider.overrideWith((ref) async => projects),
        apiClientProvider.overrideWithValue(api),
        taskRepositoryProvider.overrideWithValue(cloud ?? MemoryTasks()),
        taskProvider.overrideWith(
          (ref) => cloud == null ? tasks : TaskNotifier(cloud),
        ),
        themeStoreProvider.overrideWithValue(MemoryThemeStore()),
        captureStoreProvider.overrideWithValue(store),
        nativeSpeechProvider.overrideWithValue(speech),
        captureRecorderFactoryProvider.overrideWithValue(SilentRecorder.new),
        if (clock != null) calendarClockProvider.overrideWithValue(clock),
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
    return _App(container, store, api, tasks, speech);
  }

  /// `Añadir tarea` listening, the recognizer hears [words], then `Listo`.
  Future<void> speak(WidgetTester tester, String words) async {
    await tester.tap(find.text(es.addTask).hitTestable());
    await tester.pumpAndSettle();
    speech.send('ready');
    speech.send('segment', text: words);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, es.done));
    await tester.pumpAndSettle();
  }

  /// `Dictar una tarea` on the screen in front, `Escribir`, the words, and
  /// `Listo` unless [submit] is false.
  Future<void> say(
    WidgetTester tester,
    String words, {
    bool submit = true,
    // The app's language, when not Spanish.
    AppLocalizations? l,
  }) async {
    l ??= es;
    await tester.tap(find.text(l.addTask).hitTestable());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('capture-type-instead')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('capture-words')), words);
    await tester.pumpAndSettle();
    if (!submit) return;
    await tester.tap(find.widgetWithText(FilledButton, l.done));
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
  // Set: saving writes to this repository, as the real store's table does.
  _SlowCloud? cloud;
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
    String? language,
  }) async => current = CaptureSession(
    language: language,
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
            ? draft.copyWith(
                savedTaskId:
                    cloud?.insert(draft.task) ?? tasks!.add(draft.task),
              )
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
      if (cloud != null) {
        cloud!.remove(id);
      } else {
        await tasks!.deleteTask(id);
      }
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
  void send(String kind, {String? text}) =>
      _events.add(SpeechEvent(_run!, kind, text: text));

  @override
  Future<void> stop(int id) async {
    if (_run != null) _events.add(SpeechEvent(_run!, 'ended'));
  }

  @override
  Future<void> cancel(int id) async {}
}

/// A signed-in account's tasks on the phone, with a cloud sync that runs
/// until [gate] completes (never, unless the test says so).
class _SlowCloud extends TaskRepository {
  _SlowCloud() : super(TaskDatabase());
  final _rows = <Task>[];
  var _next = 200;
  Completer<void> gate = Completer<void>();
  int syncs = 0;
  int finished = 0;
  Completer<void>? _heldRead;

  List<String> get titles => [for (final task in _rows) task.title];

  /// The next read takes the list as it is now and answers when the returned
  /// completer completes.
  Completer<void> holdNextRead() => _heldRead = Completer<void>();

  /// The capture store's write: the task is on the phone at once.
  int insert(Task task) {
    final id = _next++;
    _rows.add(task.copyWith(id: id));
    return id;
  }

  void remove(int id) => _rows.removeWhere((task) => task.id == id);

  @override
  String get ownerKey => 'account:1';

  @override
  Future<void> sync() async {
    syncs++;
    await gate.future;
    finished++;
  }

  @override
  Future<List<Task>> getAllTasks() async {
    final snapshot = [..._rows];
    final held = _heldRead;
    if (held != null) {
      _heldRead = null;
      await held.future;
    }
    return snapshot;
  }

  @override
  Future<int> addTask(Task task) async => insert(task);

  @override
  Future<void> addTasks(List<Task> tasks) async => tasks.forEach(insert);

  @override
  Future<int> updateTask(Task task) async {
    final index = _rows.indexWhere((row) => row.id == task.id);
    if (index >= 0) _rows[index] = task;
    return index >= 0 ? 1 : 0;
  }

  @override
  Future<int> deleteTask(int id) async {
    remove(id);
    return 1;
  }
}
