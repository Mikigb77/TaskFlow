import 'package:agenda/models/day_timeline.dart';
import 'package:agenda/models/device_calendar_event.dart';
import 'package:agenda/models/task.dart';
import 'dart:async';
import 'dart:math' as math;

import 'package:agenda/l10n/generated/app_localizations.dart';
import 'package:agenda/l10n/region.dart';
import 'package:agenda/main.dart';
import 'package:agenda/providers/regional_provider.dart';
import 'package:agenda/screens/calendar_screen.dart';
import 'package:agenda/screens/day_timeline_screen.dart';
import 'package:agenda/providers/calendar_focus_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/design_fixtures.dart';
import 'device_calendar_test.dart'
    show FakeDeviceCalendars, MemoryCalendarPreferences, workCalendar;
import 'package:agenda/providers/device_calendar_provider.dart';
import 'package:agenda/providers/task_provider.dart';
import 'package:agenda/services/device_calendars.dart';
import 'package:agenda/widgets/app_components.dart';
import 'package:agenda/widgets/task_tile.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

void main() {
  test(
      'timeline distinguishes work, deadline markers, date-only tasks and source events',
      () {
    final day = DateTime(2026, 9, 22);
    final report = Task(
        id: 1,
        title: 'Report',
        priority: 1,
        dueDate: DateTime(2026, 9, 22, 9),
        durationMinutes: 90,
        deadline: DateTime(2026, 9, 22, 17),
        deadlineHasTime: true);
    final data = DayTimeline.build(day, [
      report,
      Task(id: 2, title: 'Due today', priority: 1, deadline: day),
      Task(id: 3, title: 'Inbox', priority: 1),
    ], [
      DeviceCalendarEvent(
          id: '1',
          calendarId: '1',
          title: 'Meeting',
          start: DateTime(2026, 9, 22, 9, 30).toUtc(),
          end: DateTime(2026, 9, 22, 10).toUtc(),
          allDay: false),
      DeviceCalendarEvent(
          id: '2',
          calendarId: '1',
          title: 'Holiday',
          start: DateTime.utc(2026, 9, 22),
          end: DateTime.utc(2026, 9, 23),
          allDay: true)
    ]);
    expect(data.entries.map((e) => e.kind),
        [TimelineKind.planned, TimelineKind.calendar, TimelineKind.deadline]);
    expect(data.entries.first.end, DateTime(2026, 9, 22, 10, 30));
    expect(data.entries.last.point, isTrue);
    expect(data.unblocked.single.title, 'Due today');
    expect(data.allDayEvents.single.title, 'Holiday');
    final layout = TimelineLayout.place(data.entries, data.window);
    expect(layout.lanes, 2);
    expect(layout.items.first.lane, isNot(layout.items[1].lane));
    expect(layout.items.first.durationHeight, 108);
    expect(layout.items.last.durationHeight, 2);
    expect(layout.items.last.height, 52);
  });
  test('carry-over is clipped and a short label does not invent occupied time',
      () {
    final day = DateTime(2026, 9, 22);
    final overnight = Task(
        id: 1,
        title: 'Night',
        priority: 1,
        dueDate: DateTime(2026, 9, 21, 23, 30),
        durationMinutes: 60);
    final quick = Task(
        id: 2,
        title: 'Quick',
        priority: 1,
        dueDate: DateTime(2026, 9, 22, 0, 10),
        durationMinutes: 5);
    final data = DayTimeline.build(day, [overnight, quick], []);
    final layout = TimelineLayout.place(data.entries, data.window);
    expect(layout.items[0].top, 0);
    expect(layout.items[0].durationHeight, 36);
    expect(layout.items[1].top, 12);
    expect(layout.items[1].durationHeight, 6);
    expect(layout.items[1].height, 52);
    expect(layout.lanes, 2);
    expect(DayTimeline.build(DateTime(2026, 9, 23), [overnight], []).entries,
        isEmpty);
  });
  test(
      'DST geometry has 23/25 hours and repeated labels retain distinct instants',
      () {
    tzdata.initializeTimeZones();
    final zone = tz.getLocation('Europe/Madrid');
    final spring = TimelineWindow(
        tz.TZDateTime(zone, 2026, 3, 29), tz.TZDateTime(zone, 2026, 3, 30));
    final autumn = TimelineWindow(
        tz.TZDateTime(zone, 2026, 10, 25), tz.TZDateTime(zone, 2026, 10, 26));
    expect(spring.minutes, 1380);
    expect(autumn.minutes, 1500);
    expect(spring.hours.any((hour) => hour.hour == 2), isFalse);
    final repeated = autumn.hours.where((hour) => hour.hour == 2).toList();
    expect(repeated, hasLength(2));
    expect(autumn.offset(repeated[1]) - autumn.offset(repeated[0]), 60);
    expect(repeated[0].timeZoneOffset, isNot(repeated[1].timeZoneOffset));
  });

  // ---- Round 1 · P23 · UX-224: the day timeline's arrows and copy ----

  for (final (language, previous, next) in [
    ('es', 'Día anterior', 'Día siguiente'),
    ('en', 'Previous day', 'Next day'),
    ('ca', 'Dia anterior', 'Dia següent'),
  ]) {
    testWidgets(
        'UX-224: the timeline arrows read $previous / $next, and neither help paragraph is shown ($language)',
        (tester) async {
      const timeoutChannel = MethodChannel('taskflow/accessibility');
      final platform =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      platform.setMockMethodCallHandler(timeoutChannel, (_) async => null);
      addTearDown(
          () => platform.setMockMethodCallHandler(timeoutChannel, null));
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final container = designContainer(
          regionalStore:
              MemoryRegionalStore(RegionalPreferences(language: language)));
      addTearDown(container.dispose);
      await tester.pumpWidget(UncontrolledProviderScope(
          container: container, child: const MyApp()));
      await tester.pumpAndSettle();
      unawaited(Navigator.of(tester.element(find.byType(CalendarScreen)))
          .pushNamed('/timeline', arguments: DateTime.now()));
      await tester.pumpAndSettle();
      final timeline = find.byType(DayTimelineScreen);
      expect(timeline, findsOneWidget);
      final l = lookupAppLocalizations(Locale(language));
      expect(l.previousDay, previous);
      expect(l.nextDay, next);
      Finder inTimeline(Finder finder) =>
          find.descendant(of: timeline, matching: finder);
      expect(inTimeline(find.byTooltip(previous)), findsOneWidget);
      expect(inTimeline(find.byTooltip(next)), findsOneWidget);
      // Not the calendar's week or month wording.
      for (final calendar in [
        l.previousWeek,
        l.nextWeek,
        l.previousMonth,
        l.nextMonth,
      ]) {
        expect(inTimeline(find.byTooltip(calendar)), findsNothing);
      }
      // timelineHelp and timelineShortBlocks, as they read before (keys gone).
      for (final gone in [
        'Trabajo planificado y eventos del teléfono',
        'Los eventos cortos tienen una zona táctil más grande',
        'Planned work and phone events',
        'Short events have larger tap targets',
        'Tasques planificades i esdeveniments del telèfon',
        'Els esdeveniments curts tenen una àrea tàctil més gran',
      ]) {
        expect(find.textContaining(gone), findsNothing, reason: gone);
      }
      expect(tester.takeException(), isNull);
    });
  }

  // ---- Run 2026-10-19-app, round 1 · P180 (UX-1402): the Día view opens on
  // the day's first task, in plain words ----

  final es = lookupAppLocalizations(const Locale('es'));
  final today = () {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }();
  DateTime at(int offset, [int hour = 0, int minute = 0]) =>
      DateTime(today.year, today.month, today.day + offset, hour, minute);

  /// The Día view for [day] in Spanish at [size] and [scale], the clock at
  /// [clock].
  Future<void> openDay(
    WidgetTester tester, {
    required List<Task> tasks,
    required DateTime clock,
    DateTime? day,
    Size size = const Size(360, 800),
    double scale = 1,
    TaskNotifier Function()? notifier,
    List<Override> overrides = const [],
    String theme = 'light',
    String language = 'es',
    bool settle = true,
  }) async {
    const timeoutChannel = MethodChannel('taskflow/accessibility');
    final platform =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    platform.setMockMethodCallHandler(timeoutChannel, (_) async => null);
    addTearDown(() => platform.setMockMethodCallHandler(timeoutChannel, null));
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    if (scale != 1) {
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    }
    final container = designContainer(
      store: MemoryThemeStore(theme),
      tasks: notifier ?? () => _GivenTasks(tasks),
      hadTask: true,
      regionalStore: MemoryRegionalStore(RegionalPreferences(
          language: language, clock: ClockFormat.twentyFour, weekStart: 1)),
      overrides: [
        calendarClockProvider.overrideWithValue(() => clock),
        ...overrides,
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
        UncontrolledProviderScope(container: container, child: const MyApp()));
    await tester.pumpAndSettle();
    unawaited(Navigator.of(tester.element(find.byType(CalendarScreen)))
        .pushNamed('/timeline', arguments: day ?? today));
    // Unsettled: only the Día view's very first frame (a pushed page's first
    // frame is laid out offstage, for its heroes).
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
    }
    expect(find.byType(DayTimelineScreen, skipOffstage: false), findsOneWidget);
  }

  /// Whether [finder] is wholly inside the timeline's visible area.
  bool inView(WidgetTester tester, Finder finder) {
    final view = tester.getRect(find.byKey(const ValueKey('timeline-scroll')));
    final rect = tester.getRect(finder.first);
    return rect.top >= view.top - 0.5 && rect.bottom <= view.bottom + 0.5;
  }

  List<Task> normalDay() => [
        Task(
            id: 1,
            title: 'Paseo por el parque',
            dueDate: at(0, 8, 30),
            priority: 1,
            isCompleted: true),
        Task(
            id: 2,
            title: 'Llamar al médico para pedir cita',
            dueDate: at(0, 10),
            priority: 2),
        Task(id: 3, title: 'Comer con Ana', dueDate: at(0, 13, 30), priority: 1),
        Task(
            id: 4,
            title: 'Recoger a los niños del colegio',
            dueDate: at(0, 17),
            priority: 3),
        Task(id: 5, title: 'Clase de yoga', dueDate: at(0, 19, 30), priority: 1),
      ];

  for (final scale in [1.0, 2.0]) {
    testWidgets(
        'UX-1402: at ${scale}x on 360×800 (calendar/timeline.normal, 09:41) the Día view opens with the 08:30 block in view, not at 00:00',
        (tester) async {
      await openDay(tester,
          tasks: normalDay(), clock: at(0, 9, 41), scale: scale);
      final walk = find.byTooltip('Paseo por el parque, 08:30');
      expect(walk, findsOneWidget);
      expect(inView(tester, walk), isTrue, reason: 'the 08:30 block shows');
      final midnight = find.descendant(
          of: find.byType(DayTimelineScreen), matching: find.text('00:00'));
      expect(
          midnight
              .evaluate()
              .every((e) => !inView(tester, find.byWidget(e.widget))),
          isTrue,
          reason: 'not the empty night hours');
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
      'UX-1402: going to the next day opens on that day’s first timed item',
      (tester) async {
    await openDay(tester, clock: at(0, 9, 41), tasks: [
      ...normalDay(),
      Task(id: 10, title: 'Dentista', dueDate: at(1, 16), priority: 1),
      Task(id: 11, title: 'Cena con Paul', dueDate: at(1, 21), priority: 1),
    ]);
    await tester.tap(find.byTooltip(es.nextDay));
    await tester.pumpAndSettle();
    final dentist = find.byTooltip('Dentista, 16:00');
    expect(dentist, findsOneWidget);
    expect(inView(tester, dentist), isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'UX-1402: on today at 15:00, with the first item at 08:30, the view opens near 15:00',
      (tester) async {
    await openDay(tester, clock: at(0, 15), tasks: [
      Task(
          id: 1,
          title: 'Paseo por el parque',
          dueDate: at(0, 8, 30),
          priority: 1),
      Task(id: 2, title: 'Cena', dueDate: at(0, 21), priority: 1),
    ]);
    final screen = find.byType(DayTimelineScreen);
    final three = find.descendant(of: screen, matching: find.text('15:00'));
    expect(three, findsOneWidget);
    expect(inView(tester, three), isTrue, reason: '15:00 is in view');
    expect(
        inView(tester, find.byTooltip('Paseo por el parque, 08:30')), isFalse,
        reason: 'the morning has passed');
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'UX-1402: there is no «Ir al primer elemento con hora»; a date-only task sits under «Sin hora»; a day with nothing timed says «No hay nada con hora este día.»',
      (tester) async {
    await openDay(tester, clock: at(0, 9, 41), tasks: [
      ...normalDay(),
      Task(
          id: 20,
          title: 'Pagar la factura de la luz',
          dueDate: at(0),
          hasTime: false,
          priority: 1),
    ]);
    final screen = find.byType(DayTimelineScreen);
    expect(
        find.descendant(
            of: screen, matching: find.textContaining('Ir al primer')),
        findsNothing);
    expect(
        find.descendant(
            of: screen,
            matching: find.widgetWithIcon(TextButton, Icons.schedule_outlined)),
        findsNothing);
    final label = find.descendant(
        of: screen, matching: find.text(es.timelineUnblocked.toUpperCase()));
    expect(label, findsOneWidget);
    expect(es.timelineUnblocked, 'Sin hora');
    final row = find.descendant(
        of: screen, matching: find.text('Pagar la factura de la luz'));
    expect(row, findsOneWidget);
    expect(tester.getRect(label).top, lessThan(tester.getRect(row).top));
    expect(
        find.descendant(of: screen, matching: find.text(es.timelineNoBlocks)),
        findsNothing);

    // A day with a date-only task and nothing timed.
    await tester.pumpWidget(const SizedBox());
    await openDay(tester, clock: at(0, 9, 41), tasks: [
      Task(
          id: 20,
          title: 'Pagar la factura de la luz',
          dueDate: at(0),
          hasTime: false,
          priority: 1),
    ]);
    expect(
        find.descendant(
            of: find.byType(DayTimelineScreen),
            matching: find.text('No hay nada con hora este día.')),
        findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'UX-1402: TalkBack reads each block title first («Paseo por el parque, 08:30»), with no «Planificado para» and no «Sin duración»',
      (tester) async {
    final semantics = tester.ensureSemantics();
    await openDay(tester,
        clock: at(0, 9, 41),
        size: const Size(360, 2400),
        tasks: [
          ...normalDay(),
          Task(
              id: 30,
              title: 'Reunión con el tutor',
              dueDate: at(0, 9),
              durationMinutes: 60,
              priority: 2),
          Task(
              id: 31,
              title: 'Entregar el informe',
              priority: 2,
              deadline: at(0, 14),
              deadlineHasTime: true),
        ]);
    final screen = find.byType(DayTimelineScreen);
    Finder spoken(Pattern label) =>
        find.descendant(of: screen, matching: find.bySemanticsLabel(label));
    expect(spoken('Paseo por el parque, 08:30'), findsOneWidget);
    expect(spoken('Reunión con el tutor, 09:00 – 10:00'), findsOneWidget);
    expect(spoken(RegExp('^${es.deadline}: Entregar el informe')),
        findsOneWidget);
    expect(spoken(RegExp(es.plannedFor)), findsNothing);
    expect(spoken(RegExp('Sin duración')), findsNothing);
    semantics.dispose();
  });

  // ---- Run 2026-10-19-app, round 2 · P202 (UX-1633): the notices and «Sin
  // hora» stay above the hours, in view on arrival ----

  final screen = find.byType(DayTimelineScreen);
  Finder onDay(Finder finder) => find.descendant(of: screen, matching: finder);
  final hours = find.byKey(const ValueKey('timeline-scroll'));
  final untimed = find.byKey(const ValueKey('timeline-untimed'));

  /// Whether [finder] is wholly on the screen from top to bottom, above the
  /// add button. (At 2× a timeline block is wider than the screen: the lanes
  /// scroll sideways, by design, so only its start is checked across.)
  bool onScreen(WidgetTester tester, Finder finder, [AppLocalizations? l]) {
    final rect = tester.getRect(finder.first);
    final button = tester.getRect(onDay(find.text((l ?? es).addTask)).first);
    return rect.top >= -0.5 &&
        rect.left >= -0.5 &&
        rect.left < tester.view.physicalSize.width &&
        rect.bottom <= button.top + 0.5;
  }

  /// Whether [finder] is wholly inside the pinned «Sin hora» area.
  bool inUntimed(WidgetTester tester, Finder finder) {
    final view = tester.getRect(untimed);
    final rect = tester.getRect(finder.first);
    return rect.top >= view.top - 0.5 && rect.bottom <= view.bottom + 0.5;
  }

  /// The bottom of the day header (‹ date ›).
  double headerBottom(WidgetTester tester) =>
      tester.getRect(onDay(find.byTooltip(es.previousDay))).bottom;

  /// «Sin hora»'s cap: the larger of a third of the space under the day
  /// header and its label plus its first whole row (with the row's 8 dp gap),
  /// never more than half. Read before the area is scrolled.
  void expectUntimedCap(WidgetTester tester, Finder first) {
    // The day header's whole row: its date may wrap taller than the arrows.
    final header = tester.getRect(find
        .ancestor(
            of: onDay(find.byTooltip(es.previousDay)),
            matching: find.byType(Row))
        .first);
    final space = tester.view.physicalSize.height - header.bottom;
    final area = tester.getRect(untimed);
    final head = tester.getRect(first).bottom + 8 - area.top;
    final cap = math.min(space / 2, math.max(space / 3, head));
    expect(area.height, closeTo(cap, 1),
        reason: 'area ${area.height}, head $head, space $space');
    expect(area.height, lessThanOrEqualTo(space / 2 + 0.5));
    expect(inUntimed(tester, first), isTrue, reason: 'the first row is whole');
  }

  /// Scrolls the hours until 20:00 shows.
  Future<void> scrollTo20(WidgetTester tester) async {
    final eight = onDay(find.text('20:00'));
    await tester.dragUntilVisible(eight, hours, const Offset(0, -200));
    await tester.pumpAndSettle();
    expect(inView(tester, eight), isTrue, reason: '20:00 is in view');
  }

  Task dateOnly(
          [int id = 20,
          String title = 'Pagar la factura de la luz',
          int priority = 1]) =>
      Task(
          id: id,
          title: title,
          dueDate: at(0),
          hasTime: false,
          priority: priority);

  // At 2× with priority 2, the test font wraps «Añadir tarea» to two padded
  // lines, which a phone never does: «P207, in Manrope» measures that case.
  // Titles wrap whole (P279), and the test font's square glyphs give a long
  // one five lines at 2× where Manrope gives two, so at 2× the test-font
  // cases use a short title; «P207, in Manrope» measures the long one.
  String billAt(double scale) =>
      scale == 1 ? 'Pagar la factura de la luz' : 'Pagar la luz';
  for (final (scale, priority) in [(1.0, 1), (2.0, 1), (1.0, 2)]) {
    testWidgets(
        'UX-1633: at ${scale}x on 360×800 (calendar/timeline.untimed, 09:41, priority $priority) «Sin hora», «${billAt(scale)}» and the 08:30 block are all on screen on arrival',
        (tester) async {
      await openDay(tester,
          tasks: [
            ...normalDay(),
            dateOnly(20, billAt(scale), priority)
          ],
          clock: at(0, 9, 41),
          scale: scale);
      final label = onDay(find.text(es.timelineUnblocked.toUpperCase()));
      final bill = onDay(find.text(billAt(scale)));
      final walk = find.byTooltip('Paseo por el parque, 08:30');
      expect(label, findsOneWidget);
      expect(bill, findsOneWidget);
      expect(untimed, findsOneWidget);
      for (final (name, finder) in [('Sin hora', label), ('the bill', bill)]) {
        expect(onScreen(tester, finder), isTrue, reason: '$name on screen');
        expect(inUntimed(tester, finder), isTrue, reason: '$name not cut');
        expect(tester.getRect(finder).top,
            greaterThanOrEqualTo(headerBottom(tester) - 0.5),
            reason: '$name under the day header');
      }
      // «Sin hora» sits above the hours, never under them.
      expect(tester.getRect(untimed).bottom,
          lessThanOrEqualTo(tester.getRect(hours).top + 0.5));
      expect(inView(tester, walk), isTrue, reason: 'the 08:30 block shows');
      expect(onScreen(tester, walk), isTrue);
      // Scrolling the hours leaves «Sin hora» where it is.
      final before = tester.getRect(bill);
      await scrollTo20(tester);
      expect(tester.getRect(bill), before);
      expect(tester.takeException(), isNull);
    });
  }

  for (final scale in [1.0, 2.0]) {
    testWidgets(
        'UX-1633: at ${scale}x on 360×800, with the tasks failing to load, «No se pudieron cargar tus tareas» is on screen on arrival and after the hours scroll to 20:00',
        (tester) async {
      await openDay(tester,
          tasks: const [],
          notifier: _FailingTasks.new,
          clock: at(0, 9, 41),
          scale: scale);
      expect(es.loadTasksError, 'No se pudieron cargar tus tareas');
      final error = onDay(find.text(es.loadTasksError));
      expect(error, findsOneWidget);
      expect(onScreen(tester, error), isTrue, reason: 'on arrival');
      expect(error.hitTestable(), findsOneWidget);
      await scrollTo20(tester);
      expect(onScreen(tester, error), isTrue, reason: 'after scrolling');
      expect(error.hitTestable(), findsOneWidget);
      expect(tester.getRect(error).bottom,
          lessThanOrEqualTo(tester.getRect(hours).top + 0.5),
          reason: 'above the hours, not under them');
      expect(tester.takeException(), isNull);
    });
  }

  for (final (name, bridge, copy) in [
    (
      'the phone calendar’s read failing',
      () => _UnreadableCalendars() as FakeDeviceCalendars,
      (AppLocalizations l) => l.calendarReadRetry,
    ),
    (
      'calendar access missing',
      () => FakeDeviceCalendars()..access = CalendarAccess.denied,
      (AppLocalizations l) => l.calendarDenied,
    ),
  ]) {
    testWidgets(
        'UX-1633: with $name, its notice stays on screen after the hours scroll to 20:00',
        (tester) async {
      final calendars = bridge();
      addTearDown(calendars.close);
      await openDay(tester,
          tasks: normalDay(),
          clock: at(0, 9, 41),
          overrides: [
            deviceCalendarsProvider.overrideWithValue(calendars),
            calendarPreferenceStoreProvider.overrideWithValue(
                MemoryCalendarPreferences(CalendarPreferences(
                    enabled: true, accounts: {workCalendar.accountKey}))),
          ]);
      final notice = onDay(find.text(copy(es)));
      expect(notice, findsOneWidget);
      expect(onScreen(tester, notice), isTrue, reason: 'on arrival');
      await scrollTo20(tester);
      expect(onScreen(tester, notice), isTrue, reason: 'after scrolling');
      expect(notice.hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
      'UX-1633: at 2x on 360×800, five date-only tasks keep «Sin hora» to the larger of a third of the space under the day header and its label plus first whole row, never past half, scrolling by itself, and the 08:30 task is on screen on arrival',
      (tester) async {
    await openDay(tester,
        clock: at(0, 9, 41),
        scale: 2,
        tasks: [
          Task(
              id: 1,
              title: 'Paseo por el parque',
              dueDate: at(0, 8, 30),
              priority: 1),
          for (final (i, title) in [
            'Pagar la luz',
            'Llamar a la abuela',
            'Comprar sellos',
            'Devolver el libro',
            'Regar las plantas',
          ].indexed)
            dateOnly(20 + i, title),
        ]);
    expect(untimed, findsOneWidget);
    final area = tester.getRect(untimed);
    expectUntimedCap(tester,
        onDay(find.widgetWithText(TaskTile, 'Pagar la luz')));
    expect(area.top, greaterThanOrEqualTo(headerBottom(tester) - 0.5));
    final walk = find.byTooltip('Paseo por el parque, 08:30');
    expect(inView(tester, walk), isTrue, reason: 'the 08:30 task shows');
    expect(onScreen(tester, walk), isTrue);

    // It scrolls by itself: a row past the cap comes into it, and the hours
    // stay where they are.
    final rows = [
      for (final title in [
        'Pagar la luz',
        'Llamar a la abuela',
        'Comprar sellos',
        'Devolver el libro',
        'Regar las plantas',
      ])
        onDay(find.widgetWithText(TaskTile, title)),
    ];
    final last = rows.last;
    expect(inUntimed(tester, last), isFalse, reason: 'past the cap');
    final walkBefore = tester.getRect(walk);
    await tester.dragUntilVisible(last, untimed, const Offset(0, -60));
    await tester.pumpAndSettle();
    expect(inUntimed(tester, last), isTrue);
    expect(tester.getRect(walk), walkBefore, reason: 'the hours stay put');
    expect(tester.getRect(untimed), area, reason: 'the area keeps its size');
    expect(tester.takeException(), isNull);
  });

  for (final scale in [1.0, 2.0]) {
    testWidgets(
        'UX-1633: at ${scale}x on 360×800 (calendar/timeline.normal) a day with nothing untimed shows no «Sin hora», and the 08:30 block is on screen on arrival',
        (tester) async {
      await openDay(tester,
          tasks: normalDay(), clock: at(0, 9, 41), scale: scale);
      expect(onDay(find.text(es.timelineUnblocked.toUpperCase())),
          findsNothing);
      expect(onDay(find.text(es.timelineUnblocked)), findsNothing);
      expect(untimed, findsNothing);
      final walk = find.byTooltip('Paseo por el parque, 08:30');
      expect(inView(tester, walk), isTrue);
      expect(onScreen(tester, walk), isTrue);
      expect(tester.takeException(), isNull);
    });
  }

  // ---- Run 2026-10-19-app, round 3 · P207 (UX-1639, UX-1633): the one «Sin
  // hora» row fits whole at 2×, with a line under the area. Measured in
  // Manrope, the app's font, as the previews and the phone draw it; this
  // group runs last, so the font it loads changes no earlier test. ----

  group('P207, in Manrope', () {
    setUpAll(() async {
      await (FontLoader('Manrope')
            ..addFont(rootBundle.load('assets/fonts/Manrope.ttf')))
          .load();
      await (FontLoader('MaterialIcons')
            ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
          .load();
    });

    Finder row(String title) => onDay(find.widgetWithText(TaskTile, title));
    final medium = es.priorityValue('medium');

    /// The lines drawn on the Día view outside the hours and «Sin hora».
    List<Element> pinnedLines() =>
        onDay(find.byType(Divider)).evaluate().where((line) {
          var inside = false;
          line.visitAncestorElements((above) {
            final key = above.widget.key;
            if (key == const ValueKey('timeline-scroll') ||
                key == const ValueKey('timeline-untimed')) {
              inside = true;
              return false;
            }
            return true;
          });
          return !inside;
        }).toList();

    Rect rectOf(WidgetTester tester, Element element) =>
        tester.getRect(find.byElementPredicate((e) => e == element));

    for (final scale in [1.0, 2.0]) {
      testWidgets(
          'UX-1639: at ${scale}x on 360×800 (calendar/timeline.untimed, 09:41, priority 2) «Sin hora» and the whole «Pagar la factura de la luz» row, its «Prioridad media» line included, are inside the «Sin hora» area with no «Hoy», and the 08:30 block is on screen on arrival',
          (tester) async {
        await openDay(tester,
            tasks: [
              ...normalDay(),
              dateOnly(20, 'Pagar la factura de la luz', 2),
            ],
            clock: at(0, 9, 41),
            scale: scale);
        final label = onDay(find.text(es.timelineUnblocked.toUpperCase()));
        final bill = row('Pagar la factura de la luz');
        expect(label, findsOneWidget);
        expect(bill, findsOneWidget);
        final priority = find.descendant(of: bill, matching: find.text(medium));
        expect(priority, findsOneWidget, reason: '«$medium» stays');
        // The day the header names isn't repeated on the row.
        expect(
            find.descendant(of: bill, matching: find.textContaining(es.today)),
            findsNothing,
            reason: 'no «${es.today}» on a row of the day shown');
        expect(
            find.descendant(
                of: bill, matching: find.byIcon(Icons.schedule_rounded)),
            findsNothing,
            reason: 'no date line');
        final area = tester.getRect(untimed);
        final card = tester.getRect(bill);
        for (final (name, finder) in [
          ('Sin hora', label),
          ('the whole row', bill),
          ('«$medium»', priority),
        ]) {
          expect(inUntimed(tester, finder), isTrue,
              reason: '$name inside the area: row $card, area $area');
          expect(onScreen(tester, finder), isTrue, reason: '$name on screen');
        }
        final walk = find.byTooltip('Paseo por el parque, 08:30');
        expect(inView(tester, walk), isTrue, reason: 'the 08:30 block shows');
        expect(onScreen(tester, walk), isTrue);
        expect(tester.takeException(), isNull);
      });
    }

    for (final scale in [1.0, 2.0]) {
      for (final theme in ['light', 'dark']) {
        testWidgets(
            'UX-1639: at ${scale}x on 360×800 ($theme), a 1 dp outlineVariant line spans the screen right under «Sin hora», the hours start right below it, and it stays put after the hours scroll to 20:00',
            (tester) async {
          await openDay(tester,
              tasks: [
                ...normalDay(),
                dateOnly(20, 'Pagar la factura de la luz', 2),
              ],
              clock: at(0, 9, 41),
              scale: scale,
              theme: theme);
          final lines = pinnedLines();
          expect(lines, hasLength(1), reason: 'one line under «Sin hora»');
          final line = lines.single;
          final divider = line.widget as Divider;
          final colors = Theme.of(line).colorScheme;
          expect(Theme.of(line).brightness,
              theme == 'dark' ? Brightness.dark : Brightness.light);
          expect(divider.thickness, 1);
          expect(divider.height, 1);
          expect(divider.color, colors.outlineVariant);
          final rect = rectOf(tester, line);
          final width = tester.view.physicalSize.width;
          expect(rect.left, closeTo(0, 0.5), reason: 'spans the screen');
          expect(rect.width, closeTo(width, 0.5), reason: 'spans the screen');
          expect(rect.height, closeTo(1, 0.01));
          expect(rect.top, closeTo(tester.getRect(untimed).bottom, 0.5),
              reason: 'right under the «Sin hora» area');
          expect(tester.getRect(hours).top, closeTo(rect.bottom, 0.5),
              reason: 'the hours start right below the line');
          await scrollTo20(tester);
          expect(pinnedLines(), hasLength(1));
          expect(rectOf(tester, pinnedLines().single), rect,
              reason: 'the line never scrolls');
          expect(tester.takeException(), isNull);
        });
      }
    }

    for (final scale in [1.0, 2.0]) {
      testWidgets(
          'UX-1639: at ${scale}x on 360×800 (calendar/timeline.normal) nothing untimed: no «Sin hora», no line under the header’s notices, and the 08:30 block is on screen on arrival',
          (tester) async {
        await openDay(tester,
            tasks: normalDay(), clock: at(0, 9, 41), scale: scale);
        expect(onDay(find.text(es.timelineUnblocked.toUpperCase())),
            findsNothing);
        expect(untimed, findsNothing);
        expect(pinnedLines(), isEmpty, reason: 'no line without «Sin hora»');
        final walk = find.byTooltip('Paseo por el parque, 08:30');
        expect(inView(tester, walk), isTrue);
        expect(onScreen(tester, walk), isTrue);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets(
        'UX-1639: at 1x, a timed task due yesterday whose date-only deadline is today is listed under «Sin hora» and its row still names its own day, while today’s date-only row shows no «Hoy»',
        (tester) async {
      final due = at(-1, 15);
      await openDay(tester, clock: at(0, 9, 41), tasks: [
        ...normalDay(),
        dateOnly(20, 'Pagar la factura de la luz', 2),
        Task(
            id: 40,
            title: 'Entregar el trabajo',
            dueDate: due,
            priority: 1,
            deadline: at(0),
            deadlineHasTime: false),
      ]);
      final late = row('Entregar el trabajo');
      expect(late, findsOneWidget);
      expect(find.descendant(of: untimed, matching: late), findsOneWidget,
          reason: 'listed under «Sin hora»');
      final context = tester.element(late);
      final ownDay = '${context.dayLabel(due)} · ${context.clockTime(due)}';
      expect(find.descendant(of: late, matching: find.text(ownDay)),
          findsOneWidget,
          reason: 'names its own day: «$ownDay»');
      expect(
          find.descendant(
              of: row('Pagar la factura de la luz'),
              matching: find.textContaining(es.today)),
          findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'UX-1639: at 2x on 360×800, five date-only tasks at priority 2 keep «Sin hora» to the larger of a third of the space under the day header and its label plus first whole row, never past half, scrolling by itself, and the 08:30 task is on screen on arrival',
        (tester) async {
      const titles = [
        'Pagar la factura de la luz',
        'Llamar a la abuela',
        'Comprar sellos',
        'Devolver el libro',
        'Regar las plantas',
      ];
      await openDay(tester, clock: at(0, 9, 41), scale: 2, tasks: [
        Task(
            id: 1,
            title: 'Paseo por el parque',
            dueDate: at(0, 8, 30),
            priority: 1),
        for (final (i, title) in titles.indexed) dateOnly(20 + i, title, 2),
      ]);
      final area = tester.getRect(untimed);
      expectUntimedCap(tester, row(titles.first));
      final walk = find.byTooltip('Paseo por el parque, 08:30');
      expect(inView(tester, walk), isTrue);
      expect(onScreen(tester, walk), isTrue);
      final last = row(titles.last);
      expect(inUntimed(tester, last), isFalse, reason: 'past the cap');
      final walkBefore = tester.getRect(walk);
      await tester.dragUntilVisible(last, untimed, const Offset(0, -60));
      await tester.pumpAndSettle();
      expect(inUntimed(tester, last), isTrue);
      expect(tester.getRect(walk), walkBefore, reason: 'the hours stay put');
      expect(tester.getRect(untimed), area, reason: 'the area keeps its size');
      expect(pinnedLines(), hasLength(1));
      expect(tester.takeException(), isNull);
    });

    // ---- Run 2026-10-19-app, round 1 of b3's follow-up · P209 (UX-1639,
    // UX-1633): «Sin hora» grows to fit its first whole row, never past half.

    testWidgets(
        'UX-1639: CA, at 2x on 360×800 (calendar/timeline.untimed, 09:41, priority 2) the whole «Pagar la factura de la luz» row, its priority line included, is inside «Sin hora» on arrival, and the 08:30 block is on screen',
        (tester) async {
      final ca = lookupAppLocalizations(const Locale('ca'));
      await openDay(tester,
          tasks: [
            ...normalDay(),
            dateOnly(20, 'Pagar la factura de la luz', 2),
          ],
          clock: at(0, 9, 41),
          scale: 2,
          language: 'ca');
      final label = onDay(find.text(ca.timelineUnblocked.toUpperCase()));
      final bill = row('Pagar la factura de la luz');
      expect(label, findsOneWidget);
      expect(bill, findsOneWidget);
      final caMedium = ca.priorityValue('medium');
      final priority =
          find.descendant(of: bill, matching: find.text(caMedium));
      expect(priority, findsOneWidget, reason: '«$caMedium» stays');
      expect(
          find.descendant(of: bill, matching: find.textContaining(ca.today)),
          findsNothing,
          reason: 'no «${ca.today}» on a row of the day shown');
      final area = tester.getRect(untimed);
      final card = tester.getRect(bill);
      for (final (name, finder) in [
        (ca.timelineUnblocked, label),
        ('the whole row', bill),
        ('«$caMedium»', priority),
      ]) {
        expect(inUntimed(tester, finder), isTrue,
            reason: '$name inside the area: row $card, area $area');
        expect(onScreen(tester, finder, ca), isTrue,
            reason: '$name on screen');
      }
      final walk = find.byTooltip('Paseo por el parque, 08:30');
      expect(inView(tester, walk), isTrue, reason: 'the 08:30 block shows');
      expect(onScreen(tester, walk, ca), isTrue);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'UX-1639: ES, at 1x on 360×800 (calendar/timeline.untimed, priority 2) «Sin hora» is its content’s height: it ends right under the row’s 8 dp gap, with nothing to scroll',
        (tester) async {
      await openDay(tester,
          tasks: [
            ...normalDay(),
            dateOnly(20, 'Pagar la factura de la luz', 2),
          ],
          clock: at(0, 9, 41));
      final area = tester.getRect(untimed);
      final bill = tester.getRect(row('Pagar la factura de la luz'));
      expect(area.bottom, closeTo(bill.bottom + 8, 0.5),
          reason: 'area $area, row $bill');
      final scroll = tester.state<ScrollableState>(find
          .descendant(of: untimed, matching: find.byType(Scrollable))
          .first);
      expect(scroll.position.maxScrollExtent, closeTo(0, 0.5),
          reason: 'nothing hidden below');
      expect(tester.takeException(), isNull);
    });

    for (final (name, tasks) in [
      (
        'one date-only task at priority 2 beside the normal day',
        () => [...normalDay(), dateOnly(20, 'Pagar la factura de la luz', 2)],
      ),
      (
        'five date-only tasks at priority 2 and the 08:30 task',
        () => [
              Task(
                  id: 1,
                  title: 'Paseo por el parque',
                  dueDate: at(0, 8, 30),
                  priority: 1),
              for (final (i, title) in [
                'Pagar la factura de la luz',
                'Llamar a la abuela',
                'Comprar sellos',
                'Devolver el libro',
                'Regar las plantas',
              ].indexed)
                dateOnly(20 + i, title, 2),
            ],
      ),
    ]) {
      testWidgets(
          'UX-1633: at 2x on 360×800 with $name, «Sin hora» has its final size on the Día view’s very first frame, and keeps it once the view settles',
          (tester) async {
        await openDay(tester,
            tasks: tasks(),
            clock: at(0, 9, 41),
            scale: 2,
            settle: false);
        final firstFrame =
            find.byKey(const ValueKey('timeline-untimed'), skipOffstage: false);
        expect(firstFrame, findsOneWidget, reason: 'laid out on frame one');
        final first = tester.getSize(firstFrame);
        // The first frame the person sees.
        await tester.pump();
        expect(untimed, findsOneWidget, reason: 'on screen on frame two');
        expect(tester.getSize(untimed), first);
        await tester.pumpAndSettle();
        expect(tester.getSize(untimed), first,
            reason: 'no resize after the first frame');
        final walk = find.byTooltip('Paseo por el parque, 08:30');
        expect(inView(tester, walk), isTrue, reason: 'the 08:30 block shows');
        expect(onScreen(tester, walk), isTrue);
        expect(tester.takeException(), isNull);
      });
    }
  });

  // ---- Run 2026-10-28-app, round 1 · P277 (UX-2310): a failed event read on
  // the Día view offers Calendar's retry you can tap ----

  group('P277 · Día view event read retry', () {
    final line = onDay(find.byKey(const ValueKey('calendar-events-line')));
    Finder spinner() =>
        find.descendant(of: line, matching: find.byType(CircularProgressIndicator));

    for (final calendars in [false, true]) {
      final what = calendars ? 'the phone calendars' : 'the day’s events';
      // At 2× a failed calendars read also shows «calendarDenied» under the
      // retry line, and the notices overflow the Día view's header; that was
      // so before P277 too (584 dp then, 324 dp now) and isn't this package's.
      for (final scale in calendars ? [1.0] : [1.0, 2.0]) {
        testWidgets(
            'UX-2310: at ${scale}x on 360×800, with $what failing to read, the Día view says «No se pudieron leer los eventos. Toca para reintentar.»; a tap reads again, busy meanwhile, and then shows the event',
            (tester) async {
          final bridge = _GatedCalendars()
            ..failEvents = !calendars
            ..failCalendars = calendars
            ..data = [
              DeviceCalendarEvent(
                  id: '80',
                  calendarId: workCalendar.id,
                  title: 'Reunión de equipo',
                  start: at(0, 10),
                  end: at(0, 11),
                  allDay: false),
            ];
          addTearDown(bridge.close);
          await openDay(tester,
              tasks: normalDay(),
              clock: at(0, 9, 41),
              scale: scale,
              overrides: [
                deviceCalendarsProvider.overrideWithValue(bridge),
                calendarPreferenceStoreProvider.overrideWithValue(
                    MemoryCalendarPreferences(CalendarPreferences(
                        enabled: true,
                        accounts: {workCalendar.accountKey}))),
              ]);
          expect(es.calendarReadRetry,
              'No se pudieron leer los eventos. Toca para reintentar.');
          expect(tester.takeException(), isNull, reason: 'on arrival');
          final text = onDay(find.text(es.calendarReadRetry));
          expect(text, findsOneWidget);
          // Calendar's own line, not a red banner.
          expect(find.ancestor(of: text, matching: find.byType(MessageBanner)),
              findsNothing);
          expect(line, findsOneWidget);
          expect(find.descendant(of: line, matching: text), findsOneWidget);
          expect(line.hitTestable(), findsOneWidget);
          expect(onScreen(tester, line), isTrue);
          expect(tester.getSize(line).height, greaterThanOrEqualTo(48));
          expect(tester.widget<InkWell>(line).onTap, isNotNull);
          expect(spinner(), findsNothing);
          final block = onDay(find.byWidgetPredicate((widget) =>
              widget is Tooltip &&
              (widget.message ?? '').startsWith('Reunión de equipo, ')));
          expect(block, findsNothing);

          // A tap reads again: the line stays, busy, and takes no tap.
          bridge.held = 0;
          final gate = bridge.gate = Completer<void>();
          bridge.failEvents = false;
          bridge.failCalendars = false;
          await tester.tap(line);
          for (var i = 0; i < 3; i++) {
            await tester.pump();
          }
          expect(bridge.held, greaterThanOrEqualTo(1), reason: 'read again');
          expect(line, findsOneWidget);
          expect(find.descendant(of: line, matching: text), findsOneWidget);
          expect(spinner(), findsOneWidget);
          expect(tester.widget<InkWell>(line).onTap, isNull);
          expect(tester.takeException(), isNull, reason: 'while reading');
          bridge.gate = null;
          gate.complete();
          await tester.pumpAndSettle();

          // Read: the line goes, and the event shows on the day.
          expect(line, findsNothing);
          expect(onDay(find.text(es.calendarReadRetry)), findsNothing);
          expect(block, findsOneWidget);
          expect(tester.takeException(), isNull);
        });
      }

      testWidgets(
          'UX-2310: with $what failing again after a tap, the Día view’s retry line comes back, tappable',
          (tester) async {
        final bridge = _GatedCalendars()
          ..failEvents = !calendars
          ..failCalendars = calendars;
        addTearDown(bridge.close);
        await openDay(tester,
            tasks: normalDay(),
            clock: at(0, 9, 41),
            overrides: [
              deviceCalendarsProvider.overrideWithValue(bridge),
              calendarPreferenceStoreProvider.overrideWithValue(
                  MemoryCalendarPreferences(CalendarPreferences(
                      enabled: true, accounts: {workCalendar.accountKey}))),
            ]);
        final reads = bridge.eventReads + bridge.calendarReads;
        await tester.tap(line);
        await tester.pumpAndSettle();
        expect(bridge.eventReads + bridge.calendarReads, greaterThan(reads),
            reason: 'read again');
        expect(find.descendant(
                of: line, matching: find.text(es.calendarReadRetry)),
            findsOneWidget);
        expect(tester.widget<InkWell>(line).onTap, isNotNull);
        expect(spinner(), findsNothing);
        expect(tester.takeException(), isNull);
      });
    }
  });

  // ---- Run 2026-10-28-app, round 1 · P278 (UX-2309, UX-2314): the Día view
  // fits the screen: one lane always fits, the header drops the current year,
  // no stray dash, TalkBack skips the hour labels. Measured in Manrope. ----

  group('P278 · Día view fits the screen', () {
    setUpAll(() async {
      await (FontLoader('Manrope')
            ..addFont(rootBundle.load('assets/fonts/Manrope.ttf')))
          .load();
      await (FontLoader('MaterialIcons')
            ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
          .load();
    });

    /// The preview suite's busy day (`calendar/timeline.busy`): the normal day
    /// and six more timed items, one of them an hour long beside 08:30.
    List<Task> busyDay() => [
          ...normalDay(),
          Task(
              id: 20,
              title:
                  'Reunión con el tutor de Lucía para hablar del trimestre y de las notas',
              dueDate: at(0, 9),
              durationMinutes: 60,
              priority: 2),
          Task(
              id: 21,
              title: 'Enviar el presupuesto de la reforma de la cocina',
              dueDate: at(0, 11),
              priority: 3),
          Task(
              id: 22,
              title: 'Preparar la excursión',
              dueDate: at(0, 12),
              priority: 2),
          Task(
              id: 23,
              title: 'Farmacia: recoger la receta',
              dueDate: at(0, 16, 30),
              priority: 1),
          Task(
              id: 24,
              title: 'Corregir los ejercicios del tema 4',
              dueDate: at(0, 18),
              priority: 2),
          Task(
              id: 25,
              title: 'Llamar a la abuela',
              dueDate: at(0, 20, 30),
              priority: 1),
        ];

    /// The timeline's blocks, each a tooltip with its whole label.
    final blocks = find.descendant(of: hours, matching: find.byType(Tooltip));

    /// The block whose label is [label].
    Finder block(String label) =>
        find.descendant(of: hours, matching: find.byTooltip(label));

    Finder spoken(Pattern label) =>
        find.descendant(of: screen, matching: find.bySemanticsLabel(label));

    /// Every block ends inside the screen, its title on one line that stays
    /// inside the block and ends with an ellipsis when it doesn't fit.
    /// Returns how many titles were cut.
    int expectBlocksFit(WidgetTester tester) {
      final width = tester.view.physicalSize.width;
      var cut = 0;
      for (final element in blocks.evaluate()) {
        final tooltip = element.widget as Tooltip;
        final one = find.byElementPredicate((e) => e == element);
        final rect = tester.getRect(one);
        expect(rect.left, greaterThanOrEqualTo(-0.5),
            reason: '«${tooltip.message}» starts on screen: $rect');
        expect(rect.right, lessThanOrEqualTo(width + 0.5),
            reason: '«${tooltip.message}» ends inside the screen: $rect');
        final title = find.descendant(of: one, matching: find.byType(Text)).first;
        final paragraph = tester.renderObject<RenderParagraph>(title);
        final titleRect = tester.getRect(title);
        expect(titleRect.right, lessThanOrEqualTo(rect.right + 0.5),
            reason: 'the title of «${tooltip.message}» stays in its block');
        expect(paragraph.maxLines, 1);
        if (paragraph.didExceedMaxLines) {
          cut++;
          expect(paragraph.overflow, TextOverflow.ellipsis,
              reason: '«${tooltip.message}» ends with an ellipsis');
        }
      }
      return cut;
    }

    for (final (preview, untimedTask) in [('normal', false), ('untimed', true)]) {
      for (final language in ['es', 'ca']) {
        testWidgets(
            'UX-2309: at 2x on 360×800 (calendar/timeline.$preview, $language) every block ends inside the screen, a title that doesn’t fit ends with an ellipsis inside its block, and the block’s TalkBack label and tooltip keep the whole title',
            (tester) async {
          final semantics = tester.ensureSemantics();
          await openDay(tester,
              tasks: [
                ...normalDay(),
                if (untimedTask) dateOnly(20, 'Pagar la factura de la luz', 2),
              ],
              clock: at(0, 9, 41),
              scale: 2,
              language: language);
          expect(blocks, findsNWidgets(5), reason: 'five timed tasks');
          final cut = expectBlocksFit(tester);
          expect(cut, greaterThan(0),
              reason: 'at 2× the long titles are cut, with an ellipsis');
          for (final label in [
            'Paseo por el parque, 08:30',
            'Llamar al médico para pedir cita, 10:00',
            'Recoger a los niños del colegio, 17:00',
          ]) {
            expect(block(label), findsOneWidget, reason: 'tooltip «$label»');
            expect(spoken(label), findsOneWidget, reason: 'TalkBack «$label»');
          }
          // Nothing to drag sideways: one lane fills the space by the hours.
          final sideways = find.descendant(
              of: hours,
              matching: find.byWidgetPredicate((w) =>
                  w is Scrollable && w.axisDirection == AxisDirection.right));
          expect(sideways, findsOneWidget);
          expect(
              tester.state<ScrollableState>(sideways).position.maxScrollExtent,
              closeTo(0, 0.5),
              reason: 'one lane always fits');
          expect(tester.takeException(), isNull);
          semantics.dispose();
        });
      }
    }

    testWidgets(
        'UX-2309: at 1x on 360×800 (calendar/timeline.busy, es) both lanes are inside the screen, side by side, and the long title ends with an ellipsis',
        (tester) async {
      final semantics = tester.ensureSemantics();
      await openDay(tester, tasks: busyDay(), clock: at(0, 9, 41));
      expect(blocks, findsNWidgets(11), reason: 'eleven timed tasks');
      final walk = tester.getRect(block('Paseo por el parque, 08:30'));
      const meeting =
          'Reunión con el tutor de Lucía para hablar del trimestre y de las notas, 09:00 – 10:00';
      final talk = tester.getRect(block(meeting));
      expect((walk.left - talk.left).abs(), greaterThan(20),
          reason: 'the overlap sits in two lanes: $walk, $talk');
      expectBlocksFit(tester);
      final title = tester.renderObject<RenderParagraph>(find
          .descendant(of: block(meeting), matching: find.byType(Text))
          .first);
      expect(title.didExceedMaxLines, isTrue);
      expect(title.overflow, TextOverflow.ellipsis);
      expect(spoken(meeting), findsOneWidget,
          reason: 'TalkBack reads the whole title');
      expect(tester.takeException(), isNull);
      semantics.dispose();
    });

    for (final language in ['es', 'ca']) {
      testWidgets(
          'UX-2309: at 2x on 360×800 (calendar/timeline.busy, $language) when the lanes scroll sideways, the scrollbar is shown without touching',
          (tester) async {
        await openDay(tester,
            tasks: busyDay(), clock: at(0, 9, 41), scale: 2, language: language);
        final sideways = find.descendant(
            of: hours,
            matching: find.byWidgetPredicate((w) =>
                w is Scrollable && w.axisDirection == AxisDirection.right));
        expect(sideways, findsOneWidget);
        final extent =
            tester.state<ScrollableState>(sideways).position.maxScrollExtent;
        if (extent > 0.5) {
          final bars = find
              .ancestor(of: sideways, matching: find.byType(Scrollbar))
              .evaluate()
              .map((e) => e.widget as Scrollbar)
              .where((bar) => bar.thumbVisibility == true);
          expect(bars, isNotEmpty,
              reason: 'lanes scroll sideways by $extent dp: the bar shows');
        } else {
          // Nothing to scroll: then both lanes fit inside the screen.
          expectBlocksFit(tester);
        }
        // Each lane still keeps its blocks' starts on the screen's first page.
        final walk = tester.getRect(block('Paseo por el parque, 08:30'));
        expect(walk.left, greaterThanOrEqualTo(-0.5));
        expect(walk.right, lessThanOrEqualTo(tester.view.physicalSize.width + 0.5),
            reason: 'the first lane fits on screen');
        expect(tester.takeException(), isNull);
      });
    }

    // UX-2314: the header follows Calendar's heading rule.
    final wednesday = DateTime(2026, 10, 28);

    testWidgets(
        'UX-2314: for a day of the current year the header reads «miércoles, 28 de octubre», on one line at 1x on 360×800, and Calendar’s heading is unchanged',
        (tester) async {
      await openDay(tester,
          tasks: [
            Task(
                id: 1,
                title: 'Paseo por el parque',
                dueDate: DateTime(2026, 10, 28, 8, 30),
                priority: 1),
          ],
          clock: DateTime(2026, 10, 28, 9, 41),
          day: wednesday);
      final header = onDay(find.text('miércoles, 28 de octubre'));
      expect(header, findsOneWidget);
      expect(onDay(find.textContaining('2026')), findsNothing,
          reason: 'the current year goes without saying');
      final style = Theme.of(tester.element(header)).textTheme.titleMedium;
      final line = TextPainter(
          text: TextSpan(text: 'M', style: style),
          textDirection: TextDirection.ltr,
          textScaler: MediaQuery.textScalerOf(tester.element(header)))
        ..layout();
      expect(tester.getRect(header).height, lessThan(line.height * 1.5),
          reason: 'one line');
      line.dispose();
      // Calendar, under the Día view, still names only the month.
      final calendar = find.byType(CalendarScreen, skipOffstage: false);
      expect(
          find.descendant(
              of: calendar,
              matching: find.text('octubre', skipOffstage: false)),
          findsOneWidget);
      expect(
          find.descendant(
              of: calendar,
              matching: find.text('octubre de 2026', skipOffstage: false)),
          findsNothing);
      expect(tester.takeException(), isNull);
    });

    for (final (day, heading) in [
      (DateTime(2027, 1, 13), 'miércoles, 13 de enero de 2027'),
      (DateTime(2025, 10, 29), 'miércoles, 29 de octubre de 2025'),
    ]) {
      testWidgets(
          'UX-2314: for a day of another year the header keeps the year («$heading»)',
          (tester) async {
        await openDay(tester,
            tasks: const [],
            clock: DateTime(2026, 10, 28, 9, 41),
            day: day);
        expect(onDay(find.text(heading)), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    for (final language in ['ca', 'en']) {
      testWidgets(
          'UX-2314: in $language the header drops the current year too',
          (tester) async {
        await openDay(tester,
            tasks: const [],
            clock: DateTime(2026, 10, 28, 9, 41),
            day: wednesday,
            language: language);
        final arrow = onDay(find.byTooltip(
            lookupAppLocalizations(Locale(language)).previousDay));
        final row =
            find.ancestor(of: arrow, matching: find.byType(Row)).first;
        final texts = find
            .descendant(of: row, matching: find.byType(Text))
            .evaluate()
            .map((e) => (e.widget as Text).data ?? '')
            .where((text) => text.contains('28'))
            .toList();
        expect(texts, hasLength(1), reason: 'the date heading: $texts');
        expect(texts.single, isNot(contains('2026')));
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets(
        'UX-2314: an item without a duration has no bar; one with a duration has its bar inside its block’s rounded shape',
        (tester) async {
      await openDay(tester,
          size: const Size(360, 2400),
          clock: at(0, 9, 41),
          tasks: [
            ...busyDay(),
            Task(
                id: 31,
                title: 'Entregar el informe',
                priority: 2,
                deadline: at(0, 14),
                deadlineHasTime: true),
          ]);
      final colors = Theme.of(tester.element(hours)).colorScheme;

      /// What [inBlock] paints in [color]: a box or decoration, not text.
      List<Element> bars(Finder inBlock, Color color) => find
          .descendant(
              of: inBlock,
              matching: find.byWidgetPredicate((w) =>
                  (w is ColoredBox && w.color == color) ||
                  (w is DecoratedBox &&
                      w.decoration is BoxDecoration &&
                      (w.decoration as BoxDecoration).color == color) ||
                  (w is Container && w.color == color)))
          .evaluate()
          .toList();

      // Moments: a task at 08:30 and a deadline at 14:00.
      for (final (label, color) in [
        ('Paseo por el parque, 08:30', colors.primary),
        ('Llamar al médico para pedir cita, 10:00', colors.primary),
      ]) {
        expect(block(label), findsOneWidget);
        expect(bars(block(label), color), isEmpty,
            reason: '«$label» has no duration: no bar');
      }
      final deadline = find.descendant(
          of: hours,
          matching: find.byWidgetPredicate((w) =>
              w is Tooltip &&
              (w.message ?? '').startsWith('${es.deadline}: Entregar el informe')));
      expect(deadline, findsOneWidget);
      expect(bars(deadline, colors.tertiary), isEmpty,
          reason: 'a deadline moment has no bar');

      // An hour: its bar runs its length, inside the block, which clips to
      // its rounded corners.
      const meeting =
          'Reunión con el tutor de Lucía para hablar del trimestre y de las notas, 09:00 – 10:00';
      final found = bars(block(meeting), colors.primary);
      expect(found, hasLength(1), reason: 'an hour long: one bar');
      final bar = tester.getRect(find.byElementPredicate((e) => e == found.single));
      final shape = tester.getRect(block(meeting));
      expect(bar.left, greaterThanOrEqualTo(shape.left - 0.5));
      expect(bar.top, greaterThanOrEqualTo(shape.top - 0.5));
      expect(bar.bottom, lessThanOrEqualTo(shape.bottom + 0.5));
      expect(bar.height, closeTo(72, 0.5), reason: '60 minutes at 1.2 dp');
      final material = tester.widget<Material>(find
          .ancestor(
              of: find.byElementPredicate((e) => e == found.single),
              matching: find.byType(Material))
          .first);
      expect(material.clipBehavior, isNot(Clip.none),
          reason: 'the bar is clipped to the block’s rounded corners');
      expect(material.borderRadius, BorderRadius.circular(8));
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'UX-2314: on the busy day (calendar/timeline.busy, es 1x) TalkBack stops on no hour label, while each block says its time',
        (tester) async {
      final semantics = tester.ensureSemantics();
      await openDay(tester, tasks: busyDay(), clock: at(0, 9, 41));
      // The hours are drawn…
      for (final hour in ['00:00', '08:00', '12:00', '23:00']) {
        // 00:00 twice: the day's start and its end.
        expect(onDay(find.text(hour)), findsWidgets, reason: hour);
      }
      // …but none is read aloud on its own, nor inside another label.
      expect(spoken(RegExp(r'^\d{1,2}:\d{2}')), findsNothing,
          reason: 'no hour label is a TalkBack stop');
      expect(spoken(RegExp(r'(^|\n)\d{2}:00(\n|$)')), findsNothing);
      for (final label in [
        'Paseo por el parque, 08:30',
        'Reunión con el tutor de Lucía para hablar del trimestre y de las notas, 09:00 – 10:00',
        'Llamar al médico para pedir cita, 10:00',
        'Enviar el presupuesto de la reforma de la cocina, 11:00',
        'Preparar la excursión, 12:00',
        'Comer con Ana, 13:30',
        'Farmacia: recoger la receta, 16:30',
        'Recoger a los niños del colegio, 17:00',
        'Corregir los ejercicios del tema 4, 18:00',
        'Clase de yoga, 19:30',
        'Llamar a la abuela, 20:30',
      ]) {
        expect(spoken(label), findsOneWidget, reason: label);
      }
      semantics.dispose();
    });
  });

  // ---- Run 2026-10-28-app, round 1 · P279 (UX-2313): the Día view's
  // deadline blocks aren't an alarm ----

  group('P279 · Día view deadline blocks', () {
    for (final theme in ['light', 'dark']) {
      for (final (state, offset) in [('passed', -1), ('still ahead', 1)]) {
        testWidgets(
            'UX-2313: $theme, a deadline block whose deadline is $state uses the theme’s tertiary colour, never the error colour, and keeps its «${es.deadline}:» prefix',
            (tester) async {
          await openDay(tester,
              day: at(offset),
              clock: at(0, 9, 41),
              theme: theme,
              tasks: [
                Task(
                    id: 31,
                    title: 'Entregar el informe',
                    priority: 2,
                    deadline: at(offset, 14),
                    deadlineHasTime: true),
              ]);
          final block = find.descendant(
              of: hours,
              matching: find.byWidgetPredicate((w) =>
                  w is Tooltip &&
                  (w.message ?? '')
                      .startsWith('${es.deadline}: Entregar el informe')));
          expect(block, findsOneWidget);
          final colors = Theme.of(tester.element(block)).colorScheme;
          expect(colors.tertiary, isNot(colors.error));
          final texts = [
            for (final element in find
                .descendant(of: block, matching: find.byType(Text))
                .evaluate())
              element.widget as Text,
          ];
          expect(
              texts.map((text) => text.data),
              contains('${es.deadline}: Entregar el informe'));
          final drawn = texts.map((text) => text.style?.color).toList();
          expect(drawn, contains(colors.tertiary),
              reason: 'its time in the tertiary colour');
          expect(drawn, isNot(contains(colors.error)));
          expect(
              find.descendant(
                  of: block,
                  matching: find.byWidgetPredicate((w) =>
                      (w is ColoredBox && w.color == colors.error) ||
                      (w is Icon && w.color == colors.error))),
              findsNothing);
          expect(tester.takeException(), isNull);
        });
      }
    }
  });
}

class _GivenTasks extends DesignTaskNotifier {
  _GivenTasks(this.initial);
  final List<Task> initial;
  @override
  Future<void> loadTasks() async {
    if (!state.hasValue) state = AsyncData(initial);
  }
}

class _FailingTasks extends DesignTaskNotifier {
  @override
  Future<void> loadTasks() async {
    state = AsyncError(StateError('Synthetic read failure'), StackTrace.empty);
  }
}

/// Phone calendars whose day reads fail with an ordinary (not permission)
/// error.
class _UnreadableCalendars extends FakeDeviceCalendars {
  @override
  Future<CalendarRead<DeviceCalendarEvent>> events(
      Set<String> ids, DateTime day) async {
    eventReads++;
    throw PlatformException(code: 'read_failed');
  }
}

/// P277: phone calendars whose reads can fail, and can be held at [gate] so
/// a test can look at the screen with a read still pending.
class _GatedCalendars extends FakeDeviceCalendars {
  bool failEvents = false, failCalendars = false;
  int calendarReads = 0, held = 0;
  Completer<void>? gate;

  @override
  Future<CalendarRead<DeviceCalendar>> calendars() async {
    calendarReads++;
    if (gate != null) {
      held++;
      await gate!.future;
    }
    if (failCalendars) throw PlatformException(code: 'read_failed');
    return super.calendars();
  }

  @override
  Future<CalendarRead<DeviceCalendarEvent>> events(
      Set<String> ids, DateTime day) async {
    if (gate != null) {
      held++;
      await gate!.future;
    }
    if (!failEvents) return super.events(ids, day);
    eventReads++;
    throw PlatformException(code: 'read_failed');
  }
}
