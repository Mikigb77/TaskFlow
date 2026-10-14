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
      // The later day is out of sight: the message names it (P102).
      final calendar = tester.element(find.byType(CalendarScreen));
      expect(
        find.text(
          '${es.captureTasksAdded(2)} · '
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
    'U5: a Friday and a Saturday task in one save say 2 tareas añadidas · también el sáb, …; Friday, Saturday and the next Monday say 3 tareas añadidas · también en otros 2 días',
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
      final two =
          '${es.captureTasksAdded(2)} · ${es.captureAlsoOn(calendar.weekdayDate(sat))}';
      expect(two, startsWith('2 tareas añadidas · también el '));
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
      final three = '${es.captureTasksAdded(3)} · ${es.captureAlsoOnDays(2)}';
      expect(three, '3 tareas añadidas · también en otros 2 días');
      expect(find.text(three), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
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
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
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
            const RegionalPreferences(
              language: 'es',
              clock: ClockFormat.twentyFour,
              weekStart: 1,
            ),
          ),
        ),
        taskListsProvider.overrideWith((ref) async => []),
        apiClientProvider.overrideWithValue(api),
        taskRepositoryProvider.overrideWithValue(cloud ?? MemoryTasks()),
        taskProvider.overrideWith(
          (ref) => cloud == null ? tasks : TaskNotifier(cloud),
        ),
        themeStoreProvider.overrideWithValue(MemoryThemeStore()),
        captureStoreProvider.overrideWithValue(store),
        nativeSpeechProvider.overrideWithValue(speech),
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
