import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:agenda/l10n/region.dart';
import 'package:agenda/main.dart';
import 'package:agenda/models/checklist_item.dart';
import 'package:agenda/models/task.dart';
import 'package:agenda/models/occurrence_exception.dart';
import 'package:agenda/repositories/task_repository.dart';
import 'package:agenda/services/task_database.dart';
import 'package:agenda/providers/first_task_provider.dart';
import 'package:agenda/providers/regional_provider.dart';
import 'package:agenda/providers/task_provider.dart';
import 'package:agenda/screens/calendar_screen.dart';
import 'package:agenda/screens/main_shell.dart';
import 'package:agenda/widgets/task_actions.dart';
import 'package:agenda/widgets/task_editor.dart';
import 'package:agenda/widgets/task_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/capture_fixtures.dart';
import 'support/design_fixtures.dart';
import 'support/never_syncing_tasks.dart';
import 'package:agenda/l10n/generated/app_localizations.dart';
import 'package:agenda/l10n/request_locale.dart';
import 'package:agenda/models/device_calendar_event.dart';
import 'package:agenda/providers/calendar_focus_provider.dart';
import 'package:agenda/providers/device_calendar_provider.dart';
import 'package:agenda/screens/completed_tasks_screen.dart';
import 'package:agenda/models/task_list_info.dart';
import 'package:agenda/screens/task_detail_screen.dart';
import 'package:agenda/screens/day_timeline_screen.dart';
import 'package:agenda/screens/home_screen.dart';
import 'package:agenda/services/capture_store.dart';
import 'package:agenda/services/local_capture.dart';
import 'package:agenda/screens/device_calendars_screen.dart';
import 'package:agenda/services/api_client.dart';
import 'package:agenda/services/device_calendars.dart';
import 'package:agenda/widgets/project_scope_control.dart';
import 'package:agenda/widgets/app_components.dart';
import 'package:agenda/widgets/device_calendar_events.dart';
import 'package:intl/intl.dart';
import 'device_calendar_test.dart'
    show FakeDeviceCalendars, MemoryCalendarPreferences, workCalendar;
import 'package:table_calendar/table_calendar.dart';

/// [day]'s cell in the calendar. The month grid also shows the last days of
/// the month before (always the 22nd or later) and the first of the month
/// after (the 14th or earlier), so a number can show twice: the month's own
/// is the last match after the 14th and the first before it. The week strip
/// never repeats one.
Finder dayCell(DateTime day) {
  final matches = find
      .descendant(
        of: find.byType(TableCalendar<Task>),
        matching: find.text('${day.day}'),
      )
      .hitTestable();
  return day.day > 14 ? matches.last : matches.first;
}

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

  testWidgets(
    'Undo stays available for the phone timeout, read on each toggle',
    (tester) async {
      const channel = MethodChannel('taskflow/accessibility');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      var recommended = 10000;
      messenger.setMockMethodCallHandler(channel, (_) async => recommended);
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final container = designContainer();
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(container: container, child: const MyApp()),
      );
      await tester.pumpAndSettle();
      final notifier = container.read(taskProvider.notifier);
      for (final task in container.read(taskProvider).requireValue) {
        await notifier.deleteTask(task.id!);
      }
      await notifier.addTask(
        Task(
          title: 'Check feedback timing',
          priority: 1,
          dueDate: DateTime.now(),
        ),
      );
      await tester.pumpAndSettle();
      final checkbox = find.descendant(
        of: find.byType(TaskTile),
        matching: find.byType(Checkbox),
      );
      final l = tester.element(find.byType(CalendarScreen)).l10n;
      await tester.ensureVisible(checkbox);
      await tester.tap(checkbox);
      await tester.pumpAndSettle();
      expect(
        tester.widget<SnackBar>(find.byType(SnackBar)).duration,
        const Duration(seconds: 10),
      );
      await tester.pump(const Duration(seconds: 5));
      await tester.tap(find.text(l.undo));
      await tester.pumpAndSettle();
      expect(
        container.read(taskProvider).requireValue.single.isCompleted,
        isFalse,
      );

      await tester.tap(checkbox);
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 9));
      // The day's only task: its tick says the day is clear (WD34).
      expect(find.text(l.dayAllClear), findsOneWidget);
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(find.byType(SnackBar), findsNothing);
      expect(
        container.read(taskProvider).requireValue.single.isCompleted,
        isTrue,
      );

      recommended = 6000;
      await tester.tap(checkbox);
      await tester.pumpAndSettle();
      expect(
        tester.widget<SnackBar>(find.byType(SnackBar)).duration,
        const Duration(seconds: 6),
      );
      await tester.pump(const Duration(seconds: 5));
      expect(find.text(l.taskReopened), findsOneWidget);
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(find.byType(SnackBar), findsNothing);
      expect(
        container.read(taskProvider).requireValue.single.isCompleted,
        isFalse,
      );
      expect(tester.takeException(), isNull);
    },
  );

  for (final language in ['en', 'es', 'ca']) {
    testWidgets(
      '$language completion feedback keeps controls accessible in both themes',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        tester.view.padding = const FakeViewPadding(top: 24, bottom: 24);
        addTearDown(tester.view.reset);
        final preview = GlobalKey();
        final container = designContainer(
          regionalStore: MemoryRegionalStore(
            RegionalPreferences(language: language),
          ),
        );
        addTearDown(container.dispose);
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: RepaintBoundary(key: preview, child: const MyApp()),
          ),
        );
        await tester.pumpAndSettle();
        final notifier = container.read(taskProvider.notifier);
        for (final task in container.read(taskProvider).requireValue) {
          await notifier.deleteTask(task.id!);
        }
        final now = DateTime.now();
        await notifier.addTask(
          Task(
            title: 'Publicar la aplicación en Google Play',
            priority: 1,
            dueDate: DateTime(now.year, now.month, now.day, 10, 20),
            notes: 'Preparar la ficha y las capturas de la aplicación.',
            checklist: [ChecklistItem(title: 'Revisar las capturas')],
          ),
        );
        for (final theme in [ThemeMode.light, ThemeMode.dark]) {
          await setAppearance(container, theme);
          await tester.pumpAndSettle();
          final l = tester.element(find.byType(CalendarScreen)).l10n;
          expect(find.text(l.checklistCount(0, 1)), findsOneWidget);
          expect(find.textContaining(' steps'), findsNothing);
          final checkbox = find.descendant(
            of: find.byType(TaskTile),
            matching: find.byType(Checkbox),
          );
          await tester.ensureVisible(checkbox);
          await tester.pumpAndSettle();
          await tester.tap(checkbox);
          await tester.pumpAndSettle();
          // The day's only task: its tick says the day is clear (WD34).
          expect(find.text(l.dayAllClear), findsOneWidget);
          expect(
            tester.getRect(find.byType(SnackBar)).bottom,
            lessThanOrEqualTo(tester.getRect(find.byType(TaskActions)).top),
          );
          expect(find.text(l.undo).hitTestable(), findsOneWidget);
          expect(find.text(l.addTask).hitTestable(), findsOneWidget);
          expect(tester.takeException(), isNull);
          if (const bool.fromEnvironment('WRITE_CALENDAR_PREVIEWS') &&
              language == 'es') {
            final boundary =
                preview.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary;
            await tester.runAsync(() async {
              final image = await boundary.toImage(pixelRatio: 2);
              final bytes = (await image.toByteData(
                format: ui.ImageByteFormat.png,
              ))!;
              await File(
                'build/calendar-feedback-${theme.name}.png',
              ).writeAsBytes(bytes.buffer.asUint8List());
              image.dispose();
            });
          }
          await tester.pump(const Duration(seconds: 3));
          await tester.tap(find.text(l.undo));
          await tester.pumpAndSettle();
          expect(
            container.read(taskProvider).requireValue.single.isCompleted,
            isFalse,
          );
          await tester.tap(checkbox);
          await tester.pumpAndSettle();
          await tester.pump(const Duration(seconds: 3));
          expect(find.text(l.dayAllClear), findsOneWidget);
          await tester.pump(const Duration(seconds: 1));
          await tester.pumpAndSettle();
          expect(find.byType(SnackBar), findsNothing);
          expect(
            container.read(taskProvider).requireValue.single.isCompleted,
            isTrue,
          );

          await tester.tap(checkbox);
          await tester.pumpAndSettle();
          expect(find.text(l.taskReopened), findsOneWidget);
          await tester.pump(const Duration(seconds: 4));
          await tester.pumpAndSettle();
          expect(find.byType(SnackBar), findsNothing);
          expect(
            container.read(taskProvider).requireValue.single.isCompleted,
            isFalse,
          );
        }
      },
    );
  }

  Future<ProviderContainer> openCalendar(
    WidgetTester tester,
    List<Task> tasks, {
    String language = 'es',
    List<Override> overrides = const [],
    ThemeMode theme = ThemeMode.light,
    String? syncError,
    Size size = const Size(390, 844),
    double textScale = 1,
    bool settle = true,
    // Typing in the capture sheet without Pro, saved in memory.
    MemoryCaptures? captures,
    // The first day of the week (1: Monday); the locale's when null.
    int? weekStart,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    if (textScale != 1) {
      tester.platformDispatcher.textScaleFactorTestValue = textScale;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    }
    final container = designContainer(
      store: MemoryThemeStore(theme.name),
      regionalStore: MemoryRegionalStore(
        RegionalPreferences(language: language, weekStart: weekStart),
      ),
      tasks: () => _GivenTasks(tasks),
      pro: captures == null,
      overrides: [
        ...overrides,
        if (captures != null) captureStoreProvider.overrideWithValue(captures),
      ],
    );
    captures?.tasks = container;
    addTearDown(container.dispose);
    // What the last sync left, as the repository reports it.
    container.read(taskRepositoryProvider).syncError = syncError;
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const MyApp()),
    );
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }
    return container;
  }

  // The agenda sits below the calendar: scroll the page, not the week strip.
  Finder agenda() => find
      .descendant(
        of: find.descendant(
          of: find.byType(CalendarScreen),
          matching: find.byType(CustomScrollView),
        ),
        matching: find.byType(Scrollable),
      )
      .first;
  Future<void> reveal(WidgetTester tester, Finder finder) async {
    await tester.scrollUntilVisible(finder, 120, scrollable: agenda());
    await tester.pumpAndSettle();
  }

  Future<void> scrollAgendaToEnd(WidgetTester tester) async {
    for (var i = 0; i < 3; i++) {
      final position = tester.state<ScrollableState>(agenda()).position;
      position.jumpTo(position.maxScrollExtent);
      await tester.pumpAndSettle();
    }
  }

  testWidgets(
    'UX-201: yesterday’s open task shows under Atrasada below today’s, counts as pending and completes with Deshacer',
    (tester) async {
      final now = DateTime.now();
      final yesterday = DateTime(now.year, now.month, now.day - 1, 10);
      final container = await openCalendar(tester, [
        Task(id: 1, title: 'Comprar pan', priority: 1, dueDate: yesterday),
        Task(
          id: 2,
          title: 'Llamar a mamá',
          priority: 1,
          dueDate: DateTime(now.year, now.month, now.day, 18),
        ),
      ]);
      final context = tester.element(find.byType(CalendarScreen));
      final l = context.l10n;
      expect(l.localeName, 'es');
      final header = find.text(l.overdueCount(1));
      final overdueRow = find.widgetWithText(TaskTile, 'Comprar pan');
      final todayRow = find.widgetWithText(TaskTile, 'Llamar a mamá');
      expect(header, findsOneWidget);
      expect(overdueRow, findsOneWidget);
      await reveal(tester, overdueRow);
      expect(todayRow, findsOneWidget);
      // UX-2302: today's own rows first, then «Atrasada · 1» and its row.
      expect(
        tester.getTopLeft(todayRow).dy,
        lessThan(tester.getTopLeft(header).dy),
      );
      expect(
        tester.getTopLeft(header).dy,
        lessThan(tester.getTopLeft(overdueRow).dy),
      );
      // The overdue row shows its own (yesterday's) date.
      expect(
        find.descendant(
          of: overdueRow,
          matching: find.textContaining(context.dayLabel(yesterday)),
        ),
        findsOneWidget,
      );
      expect(find.text(l.agendaCounts(2, 0)), findsOneWidget);

      final checkbox = find.descendant(
        of: overdueRow,
        matching: find.byType(Checkbox),
      );
      await tester.ensureVisible(checkbox);
      await tester.pumpAndSettle();
      await tester.tap(checkbox);
      await tester.pumpAndSettle();
      expect(find.text(l.taskCompleted), findsOneWidget);
      expect(find.text(l.undo), findsOneWidget);
      // UX-2304: the ticked row stays under its heading, struck through, and
      // counts as completed.
      expect(header, findsOneWidget);
      expect(overdueRow, findsOneWidget);
      expect(tester.widget<Checkbox>(checkbox).value, isTrue);
      expect(find.text(l.agendaCounts(1, 1)), findsOneWidget);
      expect(
        container
            .read(taskProvider)
            .requireValue
            .firstWhere((task) => task.id == 1)
            .isCompleted,
        isTrue,
      );
      await tester.tap(find.text(l.undo));
      await tester.pumpAndSettle();
      expect(header, findsOneWidget);
      expect(find.widgetWithText(TaskTile, 'Comprar pan'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'UX-201: with only overdue tasks Today shows the overdue section, not the empty state',
    (tester) async {
      final now = DateTime.now();
      await openCalendar(tester, [
        Task(
          id: 1,
          title: 'Comprar pan',
          priority: 1,
          dueDate: DateTime(now.year, now.month, now.day - 1, 10),
        ),
      ]);
      final l = tester.element(find.byType(CalendarScreen)).l10n;
      expect(find.text(l.overdueCount(1)), findsOneWidget);
      expect(find.widgetWithText(TaskTile, 'Comprar pan'), findsOneWidget);
      expect(find.text(l.rememberPrompt), findsNothing);
      expect(find.text(l.agendaCounts(1, 0)), findsOneWidget);
    },
  );

  testWidgets(
    'UX-201: a daily task missed for days shows once, as yesterday’s occurrence',
    (tester) async {
      final now = DateTime.now();
      final yesterday = DateTime(now.year, now.month, now.day - 1, 8);
      await openCalendar(tester, [
        Task(
          id: 1,
          title: 'Tomar la pastilla',
          priority: 1,
          dueDate: DateTime(now.year, now.month, now.day - 6, 8),
          recurrence: 'daily',
          completedDates: [Task.dateKey(now)],
        ),
      ]);
      final context = tester.element(find.byType(CalendarScreen));
      final l = context.l10n;
      expect(find.text(l.overdueCount(1)), findsOneWidget);
      final rows = find.widgetWithText(TaskTile, 'Tomar la pastilla');
      await scrollAgendaToEnd(tester);
      // Today's own (completed) occurrence, then one overdue row.
      expect(rows, findsNWidgets(2));
      expect(
        find.descendant(
          of: rows.last,
          matching: find.textContaining(context.dayLabel(yesterday)),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets('UX-201: with another day selected there is no overdue section', (
    tester,
  ) async {
    final now = DateTime.now();
    await openCalendar(tester, [
      Task(
        id: 1,
        title: 'Comprar pan',
        priority: 1,
        dueDate: DateTime(now.year, now.month, now.day - 1, 10),
      ),
    ]);
    final l = tester.element(find.byType(CalendarScreen)).l10n;
    expect(find.text(l.overdueCount(1)), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('calendar-format')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l.month).last);
    await tester.pumpAndSettle();
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    final other = tomorrow.month == now.month
        ? tomorrow
        : DateTime(now.year, now.month, now.day - 1);
    await tester.tap(dayCell(other));
    await tester.pumpAndSettle();
    expect(find.text(l.overdueCount(1)), findsNothing);
    await tester.tap(find.widgetWithText(TextButton, l.today));
    await tester.pumpAndSettle();
    // A drag on the month grid would page the month: jump the page instead.
    await scrollAgendaToEnd(tester);
    expect(find.text(l.overdueCount(1)), findsOneWidget);
  });

  testWidgets(
    'UX-101: a move’s snackbar floats and goes after the accessibility timeout',
    (tester) async {
      platform.setMockMethodCallHandler(timeoutChannel, (_) async => 10000);
      final now = DateTime.now();
      final container = await openCalendar(tester, [
        Task(
          id: 1,
          title: 'Revisar el informe',
          priority: 1,
          dueDate: DateTime(now.year, now.month, now.day, 10),
        ),
      ]);
      final l = tester.element(find.byType(CalendarScreen)).l10n;
      final row = find.widgetWithText(TaskTile, 'Revisar el informe');
      await tester.ensureVisible(row);
      await tester.pumpAndSettle();
      await tester.longPress(row);
      await tester.pumpAndSettle();
      final moved = l.movedOccurrenceDate(
        tester
            .element(find.byType(CalendarScreen))
            .weekdayDate(DateTime(now.year, now.month, now.day + 1)),
      );
      // Moving, Tomorrow applies at once.
      await tester.tap(find.widgetWithText(ChoiceChip, l.tomorrow));
      await tester.pumpAndSettle();
      expect(
        Task.day(container.read(taskProvider).requireValue.single.dueDate!),
        DateTime(now.year, now.month, now.day + 1),
      );
      expect(find.text(moved), findsOneWidget);
      final bar = tester.widget<SnackBar>(find.byType(SnackBar));
      expect(bar.duration, const Duration(seconds: 10));
      expect(bar.behavior, SnackBarBehavior.floating);
      expect(find.text(l.undo), findsOneWidget);
      await tester.pump(const Duration(seconds: 9));
      expect(find.text(moved), findsOneWidget);
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(find.byType(SnackBar), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  // ---- P9: one date sheet; a moved task names its day ----

  testWidgets(
    'UX-206 / UX-212: swipe left → Mañana closes the sheet at once, keeps the time, says Movida al <weekday> with Deshacer, and Deshacer restores the date',
    (tester) async {
      platform.setMockMethodCallHandler(timeoutChannel, (_) async => 10000);
      final now = DateTime.now();
      final today10 = DateTime(now.year, now.month, now.day, 10);
      final tomorrow = DateTime(now.year, now.month, now.day + 1);
      final container = await openCalendar(tester, [
        Task(
          id: 1,
          title: 'Revisar el informe',
          priority: 1,
          dueDate: today10,
          hasTime: true,
        ),
      ]);
      final calendar = tester.element(find.byType(CalendarScreen));
      final l = calendar.l10n;
      final row = find.widgetWithText(TaskTile, 'Revisar el informe');
      await tester.ensureVisible(row);
      await tester.pumpAndSettle();
      // Swipe left: the one date sheet, titled for a move.
      await tester.drag(row, const Offset(-300, 0));
      await tester.pumpAndSettle();
      // Known and older than this round (reported separately, not part of
      // UX-206): while dragging, the swipe background's icon-and-label Column
      // (task_tile.dart, _gestureBackground) overflows a one-line row by 8 px.
      final swipe = tester.takeException();
      expect(
        swipe == null || '$swipe'.contains('RenderFlex overflowed'),
        isTrue,
        reason: '$swipe',
      );
      expect(find.byType(BottomSheet), findsOneWidget);
      expect(find.text(l.rescheduleTask), findsOneWidget);
      expect(find.byKey(const ValueKey('schedule-done')), findsOneWidget);
      await tester.tap(find.widgetWithText(ChoiceChip, l.tomorrow));
      await tester.pumpAndSettle();
      // One tap after the swipe: the sheet is gone.
      expect(find.byType(BottomSheet), findsNothing);
      final moved = container.read(taskProvider).requireValue.single;
      expect(
        moved.dueDate,
        DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 10),
      );
      expect(moved.hasTime, isTrue);
      final message = l.movedOccurrenceDate(calendar.weekdayDate(tomorrow));
      expect(
        message,
        startsWith('Movida al ${DateFormat.E('es').format(tomorrow)}'),
      );
      expect(message, isNot(contains(l.tomorrow)));
      expect(find.text(message), findsOneWidget);
      expect(find.text(l.undo), findsOneWidget);
      await tester.tap(find.text(l.undo));
      await tester.pumpAndSettle();
      final restored = container.read(taskProvider).requireValue.single;
      expect(restored.dueDate, today10);
      expect(restored.hasTime, isTrue);
      expect(tester.takeException(), isNull);
    },
  );

  /// Calendar on a repeating task kept in memory, with the real notifier, so
  /// occurrence changes go through the app's own rules.
  Future<(ProviderContainer, _OneTask)> openRepeating(
    WidgetTester tester,
    Task task,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repository = _OneTask(task);
    final container = designContainer(
      regionalStore: MemoryRegionalStore(
        const RegionalPreferences(language: 'es'),
      ),
      tasks: () => TaskNotifier(repository),
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const MyApp()),
    );
    await tester.pumpAndSettle();
    return (container, repository);
  }

  testWidgets(
    'UX-212: a repeating task’s move offers this occurrence or the whole series; an occurrence can’t go to Sin fecha; skipping and its Deshacer work as before',
    (tester) async {
      platform.setMockMethodCallHandler(timeoutChannel, (_) async => 10000);
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final (_, repository) = await openRepeating(
        tester,
        Task(
          id: 1,
          title: 'Regar las plantas',
          priority: 1,
          dueDate: DateTime(now.year, now.month, now.day, 9),
          hasTime: true,
          recurrence: 'daily',
        ),
      );
      final l = tester.element(find.byType(CalendarScreen)).l10n;
      final row = find.widgetWithText(TaskTile, 'Regar las plantas');
      await tester.ensureVisible(row);
      await tester.pumpAndSettle();
      await tester.longPress(row);
      await tester.pumpAndSettle();
      expect(find.text(l.rescheduleRepeating), findsOneWidget);
      ChoiceChip chip(String label) =>
          tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, label));
      // This occurrence first: it can be moved or skipped, not undated.
      expect(chip(l.thisOccurrence).selected, isTrue);
      expect(chip(l.wholeSeries).selected, isFalse);
      expect(find.text(l.occurrenceRescheduleHelp), findsOneWidget);
      expect(find.widgetWithText(ChoiceChip, l.noDate), findsNothing);
      expect(find.byKey(const ValueKey('schedule-skip')), findsOneWidget);
      // The whole series can go to Sin fecha.
      await tester.tap(find.widgetWithText(ChoiceChip, l.wholeSeries));
      await tester.pumpAndSettle();
      expect(find.text(l.seriesRescheduleHelp), findsOneWidget);
      expect(find.widgetWithText(ChoiceChip, l.noDate), findsOneWidget);
      expect(find.byKey(const ValueKey('schedule-skip')), findsNothing);
      await tester.tap(find.widgetWithText(ChoiceChip, l.thisOccurrence));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('schedule-skip')));
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsNothing);
      expect(find.text(l.occurrenceSkippedNotice), findsOneWidget);
      final skipped = repository.task.exceptions.single;
      expect(skipped.skipped, isTrue);
      expect(skipped.originalDate, Task.dateKey(today));
      expect(
        repository.task.dueDate,
        DateTime(now.year, now.month, now.day, 9),
      );
      await tester.tap(find.text(l.undo));
      await tester.pumpAndSettle();
      expect(repository.task.exceptions, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'UX-212: a moved occurrence can be restored to its original date, with Deshacer',
    (tester) async {
      platform.setMockMethodCallHandler(timeoutChannel, (_) async => 10000);
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final (_, repository) = await openRepeating(
        tester,
        Task(
          id: 1,
          title: 'Regar las plantas',
          priority: 1,
          dueDate: DateTime(now.year, now.month, now.day, 9),
          hasTime: true,
          recurrence: 'daily',
          exceptions: [
            OccurrenceException(
              originalDate: Task.dateKey(today),
              date: DateTime(now.year, now.month, now.day, 18),
              hasTime: true,
            ),
          ],
        ),
      );
      final l = tester.element(find.byType(CalendarScreen)).l10n;
      final row = find.widgetWithText(TaskTile, 'Regar las plantas');
      await tester.ensureVisible(row);
      await tester.pumpAndSettle();
      await tester.longPress(row);
      await tester.pumpAndSettle();
      final restore = find.byKey(const ValueKey('schedule-restore'));
      expect(restore, findsOneWidget);
      expect(find.text(l.restoreOriginal), findsOneWidget);
      await tester.ensureVisible(restore);
      await tester.tap(restore);
      await tester.pumpAndSettle();
      expect(find.text(l.originalRestored), findsOneWidget);
      expect(repository.task.exceptions, isEmpty);
      await tester.tap(find.text(l.undo));
      await tester.pumpAndSettle();
      expect(
        repository.task.exceptions.single.date,
        DateTime(now.year, now.month, now.day, 18),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'UX-212: moving the whole series to Mañana moves its start and says Movida al <weekday>',
    (tester) async {
      platform.setMockMethodCallHandler(timeoutChannel, (_) async => 10000);
      final now = DateTime.now();
      final tomorrow = DateTime(now.year, now.month, now.day + 1);
      final (_, repository) = await openRepeating(
        tester,
        Task(
          id: 1,
          title: 'Regar las plantas',
          priority: 1,
          dueDate: DateTime(now.year, now.month, now.day, 9),
          hasTime: true,
          recurrence: 'weekly',
        ),
      );
      final calendar = tester.element(find.byType(CalendarScreen));
      final l = calendar.l10n;
      final row = find.widgetWithText(TaskTile, 'Regar las plantas');
      await tester.ensureVisible(row);
      await tester.pumpAndSettle();
      await tester.longPress(row);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ChoiceChip, l.wholeSeries));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ChoiceChip, l.tomorrow));
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsNothing);
      expect(
        repository.task.dueDate,
        DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 9),
      );
      expect(
        find.text(l.movedOccurrenceDate(calendar.weekdayDate(tomorrow))),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  // ---- P61 (UX-453, UX-454): Sin fecha moves at once; honest help ----

  testWidgets(
    'UX-453: swiping a dated task that doesn’t repeat and tapping Sin fecha moves it at once, says Se ha quitado la fecha, and Deshacer restores the date',
    (tester) async {
      platform.setMockMethodCallHandler(timeoutChannel, (_) async => 10000);
      final now = DateTime.now();
      final due = DateTime(now.year, now.month, now.day, 9);
      final (_, repository) = await openRepeating(
        tester,
        Task(
          id: 1,
          title: 'Llamar al banco',
          priority: 1,
          dueDate: due,
          hasTime: true,
        ),
      );
      final l = tester.element(find.byType(CalendarScreen)).l10n;
      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text(l.tasks),
        ),
      );
      await tester.pumpAndSettle();
      await tester.drag(
        find.widgetWithText(TaskTile, 'Llamar al banco'),
        const Offset(-500, 0),
      );
      await tester.pumpAndSettle();
      // Known and older than this round (see UX-206 above): the swipe
      // background's Column overflows a one-line row by 8 px while dragging.
      final swipe = tester.takeException();
      expect(
        swipe == null || '$swipe'.contains('RenderFlex overflowed'),
        isTrue,
        reason: '$swipe',
      );
      expect(find.byType(BottomSheet), findsOneWidget);
      await tester.tap(
        find.descendant(
          of: find.byType(BottomSheet),
          matching: find.widgetWithText(ChoiceChip, l.noDate),
        ),
      );
      await tester.pumpAndSettle();
      // No Listo needed.
      expect(find.byType(BottomSheet), findsNothing);
      expect(find.byKey(const ValueKey('schedule-done')), findsNothing);
      expect(repository.task.dueDate, isNull);
      expect(l.movedInbox, 'Se ha quitado la fecha');
      expect(find.text(l.movedInbox), findsOneWidget);
      expect(find.text(l.undo), findsOneWidget);
      await tester.tap(find.text(l.undo));
      await tester.pumpAndSettle();
      expect(repository.task.dueDate, due);
      expect(repository.task.hasTime, isTrue);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'UX-454: a repeating task’s move with Toda la serie explains «Sin fecha» detiene la repetición and offers Sin fecha, which applies at once',
    (tester) async {
      platform.setMockMethodCallHandler(timeoutChannel, (_) async => 10000);
      final now = DateTime.now();
      final (_, repository) = await openRepeating(
        tester,
        Task(
          id: 1,
          title: 'Regar las plantas',
          priority: 1,
          dueDate: DateTime(now.year, now.month, now.day, 9),
          hasTime: true,
          recurrence: 'daily',
        ),
      );
      final l = tester.element(find.byType(CalendarScreen)).l10n;
      final row = find.widgetWithText(TaskTile, 'Regar las plantas');
      await tester.ensureVisible(row);
      await tester.pumpAndSettle();
      await tester.longPress(row);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ChoiceChip, l.wholeSeries));
      await tester.pumpAndSettle();
      final help = find.textContaining('«Sin fecha» detiene la repetición');
      expect(help, findsOneWidget);
      expect(find.text(l.seriesRescheduleHelp), findsOneWidget);
      expect(find.textContaining('bandeja de entrada detiene'), findsNothing);
      final noDate = find.widgetWithText(ChoiceChip, l.noDate);
      expect(noDate, findsOneWidget);
      await tester.tap(noDate);
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsNothing);
      expect(repository.task.dueDate, isNull);
      expect(find.text(l.undo), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  // ---- P64 (UX-463): Sin fecha closes the move sheet even with an empty
  // hour ----

  /// Tasks tab, a task dated today with no time swiped to `Cambiar fecha`,
  /// `Añadir hora` turned on and the hour left empty.
  Future<(_OneTask, AppLocalizations)> moveWithEmptyHour(
    WidgetTester tester,
  ) async {
    platform.setMockMethodCallHandler(timeoutChannel, (_) async => 10000);
    final now = DateTime.now();
    final (_, repository) = await openRepeating(
      tester,
      Task(
        id: 1,
        title: 'Llamar al banco',
        priority: 1,
        dueDate: DateTime(now.year, now.month, now.day),
        hasTime: false,
      ),
    );
    final l = tester.element(find.byType(CalendarScreen)).l10n;
    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text(l.tasks),
      ),
    );
    await tester.pumpAndSettle();
    await tester.drag(
      find.widgetWithText(TaskTile, 'Llamar al banco'),
      const Offset(-500, 0),
    );
    await tester.pumpAndSettle();
    // Known and older than this round (see UX-206 above).
    final swipe = tester.takeException();
    expect(
      swipe == null || '$swipe'.contains('RenderFlex overflowed'),
      isTrue,
      reason: '$swipe',
    );
    expect(find.byType(BottomSheet), findsOneWidget);
    // The move sheet (swipe's `Cambiar fecha`), titled for moving a task.
    expect(
      find.descendant(
        of: find.byType(BottomSheet),
        matching: find.text(l.rescheduleTask),
      ),
      findsOneWidget,
    );
    expect(l.addTime, 'Añadir hora');
    await tester.tap(find.byKey(const ValueKey('schedule-has-time')));
    await tester.pumpAndSettle();
    final hour = find.byKey(const ValueKey('schedule-hour'));
    expect(hour, findsOneWidget);
    expect(tester.widget<TextFormField>(hour).controller!.text, isEmpty);
    return (repository, l);
  }

  testWidgets(
    'UX-463: in Cambiar fecha with Añadir hora on and the hour empty, one tap on Sin fecha closes the sheet, says Se ha quitado la fecha and leaves the task undated',
    (tester) async {
      final (repository, l) = await moveWithEmptyHour(tester);
      await tester.tap(
        find.descendant(
          of: find.byType(BottomSheet),
          matching: find.widgetWithText(ChoiceChip, l.noDate),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsNothing);
      expect(find.byKey(const ValueKey('schedule-done')), findsNothing);
      expect(find.text(l.movedInbox), findsOneWidget);
      expect(repository.task.dueDate, isNull);
      expect(repository.task.hasTime, isFalse);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'UX-463: in Cambiar fecha with Añadir hora on and the hour empty, Hoy keeps the sheet open and the hour shows its error',
    (tester) async {
      final (repository, l) = await moveWithEmptyHour(tester);
      final before = repository.task.dueDate;
      await tester.tap(
        find.descendant(
          of: find.byType(BottomSheet),
          matching: find.widgetWithText(ChoiceChip, l.today),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsOneWidget);
      expect(find.byKey(const ValueKey('schedule-done')), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('schedule-hour')),
          // The hour's range, on the test's 12- or 24-hour clock.
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is Text &&
                (widget.data == l.scheduleHourRange24 ||
                    widget.data == l.scheduleHourRange12),
          ),
        ),
        findsOneWidget,
      );
      expect(find.text(l.movedInbox), findsNothing);
      expect(repository.task.dueDate, before);
      expect(tester.takeException(), isNull);
    },
  );

  // ---- P6: Calendar shows today's tasks first, and offline is calm ----

  Future<void> monthView(WidgetTester tester) async {
    final l = tester.element(find.byType(CalendarScreen)).l10n;
    await tester.tap(find.byKey(const ValueKey('calendar-format')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l.month).last);
    await tester.pumpAndSettle();
  }

  /// Another day of this month, so the month grid shows it.
  DateTime otherDay() {
    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    return tomorrow.month == now.month
        ? tomorrow
        : DateTime(now.year, now.month, now.day - 1);
  }

  Future<void> tapDay(WidgetTester tester, DateTime day) async {
    await tester.tap(dayCell(day));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'UX-202: a brand-new account shows no Todos los proyectos, Tu calendario, Bandeja · 0 or completion ring, and one view switcher; another day shows Hoy',
    (tester) async {
      await openCalendar(tester, []);
      final l = tester.element(find.byType(CalendarScreen)).l10n;
      Finder inCalendar(Finder finder) =>
          find.descendant(of: find.byType(CalendarScreen), matching: finder);
      expect(inCalendar(find.text(l.projectsAll)), findsNothing);
      // `yourCalendar` and its sync button were removed with the row.
      expect(inCalendar(find.text('Tu calendario')), findsNothing);
      expect(inCalendar(find.text(l.inboxCount(0))), findsNothing);
      expect(
        inCalendar(find.byKey(const ValueKey('calendar-inbox'))),
        findsNothing,
      );
      expect(inCalendar(find.byType(CircularProgressIndicator)), findsNothing);
      // One switcher on the month line, showing the current view.
      final switcher = find.byKey(const ValueKey('calendar-format'));
      expect(switcher, findsOneWidget);
      expect(
        find.descendant(of: switcher, matching: find.text(l.week)),
        findsOneWidget,
      );
      expect(inCalendar(find.text(l.dayTimeline)), findsNothing);
      expect(inCalendar(find.text(l.month)), findsNothing);
      expect(find.widgetWithText(TextButton, l.today), findsNothing);
      await tester.tap(switcher);
      await tester.pumpAndSettle();
      for (final view in [l.week, l.month, l.day]) {
        expect(find.text(view).hitTestable(), findsWidgets, reason: view);
      }
      await tester.tap(find.text(l.month).last);
      await tester.pumpAndSettle();
      await tapDay(tester, otherDay());
      final today = find.widgetWithText(TextButton, l.today);
      expect(today, findsOneWidget);
      await tester.tap(today);
      await tester.pumpAndSettle();
      expect(find.text(l.todayAgenda), findsOneWidget);
      expect(find.widgetWithText(TextButton, l.today), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'UX-202: Día in the view switcher opens the day timeline for the selected day',
    (tester) async {
      await openCalendar(tester, []);
      final l = tester.element(find.byType(CalendarScreen)).l10n;
      await tester.tap(find.byKey(const ValueKey('calendar-format')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l.day).last);
      await tester.pumpAndSettle();
      expect(find.byType(DayTimelineScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'UX-202: Bandeja · N shows only when N > 0, under the day’s tasks',
    (tester) async {
      final now = DateTime.now();
      await openCalendar(tester, [
        Task(
          id: 1,
          title: 'Revisar el informe',
          priority: 1,
          dueDate: DateTime(now.year, now.month, now.day, 10),
        ),
        Task(id: 2, title: 'Algún día', priority: 1),
      ]);
      final l = tester.element(find.byType(CalendarScreen)).l10n;
      final inbox = find.text(l.inboxCount(1));
      await reveal(tester, inbox);
      expect(inbox, findsOneWidget);
      expect(
        tester.getTopLeft(inbox).dy,
        greaterThan(
          tester
              .getBottomLeft(
                find.widgetWithText(TaskTile, 'Revisar el informe'),
              )
              .dy,
        ),
      );
      expect(tester.takeException(), isNull);
    },
  );

  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    testWidgets(
      'UX-202: at 1.3x text in Spanish the first two tasks sit fully above the capture bar without scrolling (${mode.name})',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        tester.view.padding = const FakeViewPadding(top: 24, bottom: 24);
        tester.platformDispatcher.textScaleFactorTestValue = 1.3;
        addTearDown(tester.view.reset);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final preview = GlobalKey();
        final container = designContainer(
          store: MemoryThemeStore(mode.name),
          regionalStore: MemoryRegionalStore(
            const RegionalPreferences(language: 'es'),
          ),
        );
        addTearDown(container.dispose);
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: RepaintBoundary(key: preview, child: const MyApp()),
          ),
        );
        await tester.pumpAndSettle();
        // Written first, so the render exists even when a check fails.
        if (const bool.fromEnvironment('WRITE_CALENDAR_PREVIEWS')) {
          final boundary =
              preview.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary;
          await tester.runAsync(() async {
            final image = await boundary.toImage(pixelRatio: 2);
            final bytes = (await image.toByteData(
              format: ui.ImageByteFormat.png,
            ))!;
            await File(
              'build/calendar-es-1.3x-${mode.name}.png',
            ).writeAsBytes(bytes.buffer.asUint8List());
            image.dispose();
          });
        }
        final tiles = find.byType(TaskTile).evaluate().toList()
          ..sort(
            (a, b) => tester
                .getTopLeft(find.byWidget(a.widget))
                .dy
                .compareTo(tester.getTopLeft(find.byWidget(b.widget)).dy),
          );
        expect(tiles.length, greaterThanOrEqualTo(2));
        final bar = tester.getRect(find.byType(TaskActions)).top;
        for (final tile in tiles.take(2)) {
          final rect = tester.getRect(find.byWidget(tile.widget));
          expect(rect.top, greaterThanOrEqualTo(0));
          expect(rect.bottom, lessThanOrEqualTo(bar));
        }
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'UX-217: with four phone events the tasks come first, then three events by name and a «Ver los 4 eventos» row that opens every event',
    (tester) async {
      final now = DateTime.now();
      DateTime at(int hour, int minute) =>
          DateTime(now.year, now.month, now.day, hour, minute);
      final bridge = FakeDeviceCalendars()
        ..data = [
          for (final (i, start) in [
            at(9, 0),
            at(11, 30),
            at(16, 0),
            at(19, 15),
          ].indexed)
            DeviceCalendarEvent(
              id: '${20 + i}',
              calendarId: workCalendar.id,
              title: 'Cita $i',
              start: start,
              end: start.add(const Duration(minutes: 30)),
              allDay: false,
            ),
        ];
      addTearDown(bridge.close);
      await openCalendar(
        tester,
        [
          Task(id: 1, title: 'Comprar pan', priority: 1, dueDate: at(10, 0)),
          Task(id: 2, title: 'Llamar a mamá', priority: 1, dueDate: at(18, 0)),
        ],
        overrides: [
          deviceCalendarsProvider.overrideWithValue(bridge),
          calendarPreferenceStoreProvider.overrideWithValue(
            MemoryCalendarPreferences(
              CalendarPreferences(
                enabled: true,
                accounts: {workCalendar.accountKey},
              ),
            ),
          ),
        ],
      );
      final context = tester.element(find.byType(CalendarScreen));
      final l = context.l10n;
      final line = find.byKey(const ValueKey('calendar-events-all'));
      await reveal(tester, line);
      expect(line, findsOneWidget);
      expect(
        find.descendant(of: line, matching: find.text(l.calendarSeeAllEvents(4))),
        findsOneWidget,
      );
      // The first three events show by name; the tasks come first.
      for (final (i, start) in [at(9, 0), at(11, 30), at(16, 0)].indexed) {
        final row = find.text('Cita $i · ${context.clockTime(start)}');
        expect(row, findsOneWidget);
        for (final title in ['Comprar pan', 'Llamar a mamá']) {
          expect(
            tester.getBottomLeft(find.widgetWithText(TaskTile, title)).dy,
            lessThanOrEqualTo(tester.getTopLeft(row).dy),
          );
        }
      }
      expect(find.textContaining('Cita 3'), findsNothing);
      await tester.tap(line);
      await tester.pumpAndSettle();
      final sheet = find.byType(BottomSheet);
      expect(sheet, findsOneWidget);
      for (var i = 0; i < 4; i++) {
        expect(
          find.descendant(of: sheet, matching: find.text('Cita $i')),
          findsOneWidget,
        );
      }
      // Choosing calendars moved into the sheet.
      expect(
        find.descendant(of: sheet, matching: find.byTooltip(l.calendarChoose)),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('UX-217: a day without phone events shows no events line', (
    tester,
  ) async {
    final bridge = FakeDeviceCalendars()..data = [];
    addTearDown(bridge.close);
    final now = DateTime.now();
    await openCalendar(
      tester,
      [
        Task(
          id: 1,
          title: 'Comprar pan',
          priority: 1,
          dueDate: DateTime(now.year, now.month, now.day, 10),
        ),
      ],
      overrides: [
        deviceCalendarsProvider.overrideWithValue(bridge),
        calendarPreferenceStoreProvider.overrideWithValue(
          MemoryCalendarPreferences(
            CalendarPreferences(
              enabled: true,
              accounts: {workCalendar.accountKey},
            ),
          ),
        ),
      ],
    );
    await scrollAgendaToEnd(tester);
    expect(find.byKey(const ValueKey('calendar-events-line')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  group('UX-218: being offline is normal', () {
    for (final language in ['es', 'en', 'ca']) {
      test(
        'UX-218: a network error ($language) names no server, and outside sign-in says the tasks are still on the phone',
        () {
          final l = lookupAppLocalizations(Locale(language));
          final offline = ApiException(0, 'Cannot reach the server.');
          final outside = requestProblemText(l, offline);
          final signIn = requestProblemText(l, offline, onSignIn: true);
          expect(outside, l.requestError('networkKept'));
          expect(signIn, l.requestError('network'));
          expect(outside, startsWith(signIn));
          expect(outside.length, greaterThan(signIn.length));
          if (language == 'es') {
            expect(outside, isNot(contains('servidor')));
            expect(
              outside,
              endsWith('Tus tareas siguen guardadas en este teléfono.'),
            );
            expect(signIn, isNot(contains('Tus tareas')));
          }
          // Other failures carry the same reassurance outside sign-in.
          final other = requestProblemText(l, StateError('Surprise'));
          expect(other, l.requestError('otherKept'));
        },
      );
    }

    for (final mode in [ThemeMode.light, ThemeMode.dark]) {
      testWidgets(
        'UX-218: an offline sync error on Calendar shows the neutral line, not an error banner (${mode.name})',
        (tester) async {
          final container = await openCalendar(
            tester,
            [],
            theme: mode,
            syncError: ApiException(
              0,
              'Cannot reach the server. Check the connection.',
            ).toString(),
          );
          final context = tester.element(find.byType(CalendarScreen));
          final l = context.l10n;
          final line = find.byKey(const ValueKey('calendar-offline'));
          expect(line, findsOneWidget);
          final text = find.descendant(
            of: line,
            matching: find.text(l.calendarOffline),
          );
          expect(text, findsOneWidget);
          final colors = Theme.of(context).colorScheme;
          expect(
            tester.renderObject<RenderParagraph>(text).text.style?.color,
            colors.onSurfaceVariant,
          );
          expect(
            find.descendant(
              of: line,
              matching: find.byIcon(Icons.cloud_off_outlined),
            ),
            findsOneWidget,
          );
          expect(
            find.descendant(
              of: find.byType(CalendarScreen),
              matching: find.byType(MessageBanner),
            ),
            findsNothing,
          );
          expect(container.read(taskRepositoryProvider).syncError, isNotNull);
          expect(tester.takeException(), isNull);
        },
      );
    }

    testWidgets('UX-218: other sync errors keep the banner', (tester) async {
      await openCalendar(tester, [], syncError: 'Unexpected sync failure');
      expect(find.byKey(const ValueKey('calendar-offline')), findsNothing);
      expect(
        find.descendant(
          of: find.byType(CalendarScreen),
          matching: find.byType(MessageBanner),
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets(
    'UX-226, UX-2313: a passed deadline reads «Venció el …» once on the tile and on the detail',
    (tester) async {
      final now = DateTime.now();
      await openCalendar(tester, [
        Task(
          id: 1,
          title: 'Entregar el informe',
          priority: 1,
          dueDate: DateTime(now.year, now.month, now.day, 10),
          deadline: DateTime(now.year, now.month, now.day - 2, 12),
          deadlineHasTime: true,
        ),
      ]);
      final l = tester.element(find.byType(CalendarScreen)).l10n;
      final row = find.widgetWithText(TaskTile, 'Entregar el informe');
      expect(
        find.descendant(
          of: row,
          matching: find.textContaining(l.deadlinePassedOn('')),
        ),
        findsOneWidget,
      );
      tester
          .state<NavigatorState>(find.byType(Navigator))
          .pushNamed('/taskDetails', arguments: 1);
      await tester.pumpAndSettle();
      expect(find.textContaining(l.deadlinePassedOn('')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('UX-226: a day with only completed tasks has no dot', (
    tester,
  ) async {
    final now = DateTime.now();
    final other = otherDay();
    await openCalendar(tester, [
      Task(
        id: 1,
        title: 'Hecha',
        priority: 1,
        isCompleted: true,
        dueDate: DateTime(other.year, other.month, other.day, 10),
      ),
      Task(
        id: 2,
        title: 'Pendiente',
        priority: 1,
        dueDate: DateTime(now.year, now.month, now.day, 10),
      ),
    ]);
    await monthView(tester);
    Finder dots() => find.descendant(
      of: find.byType(TableCalendar<Task>),
      matching: find.byWidgetPredicate(
        (widget) =>
            widget is Container &&
            widget.decoration is BoxDecoration &&
            (widget.decoration! as BoxDecoration).shape == BoxShape.circle,
      ),
    );
    // Only today's open task has a dot.
    expect(dots(), findsOneWidget);
    final dot = tester.getCenter(dots());
    final todayCell = tester.getRect(dayCell(now));
    expect((dot.dx - todayCell.center.dx).abs(), lessThan(24));
    expect(tester.takeException(), isNull);
  });

  // ---- P7: Calendar shows where your task went, and follows today ----

  void leaveApp(WidgetTester tester) {
    for (final state in [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
    ]) {
      tester.binding.handleAppLifecycleStateChanged(state);
    }
  }

  void returnToApp(WidgetTester tester) {
    for (final state in [
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ]) {
      tester.binding.handleAppLifecycleStateChanged(state);
    }
  }

  /// Without Pro, the task form (2026-10-18 later): `Nueva tarea`, the
  /// title, and the day chip under it when [day] names one.
  Future<void> fillForm(
    WidgetTester tester,
    String title, {
    String? day,
  }) async {
    final l = tester.element(find.byType(MainShell)).l10n;
    await tester.tap(find.text(l.newTask).hitTestable());
    await tester.pumpAndSettle();
    expect(find.byType(TaskEditor), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('task-title')), title);
    await tester.pumpAndSettle();
    if (day != null) {
      await tester.tap(find.byKey(ValueKey(day)));
      await tester.pumpAndSettle();
    }
    await tester.tap(find.byKey(const ValueKey('task-save')));
    await tester.pumpAndSettle();
    expect(find.byType(TaskEditor), findsNothing);
  }

  testWidgets(
    'UX-205: a task for Mañana filled in from Calendario selects Mañana, shows and highlights its row, says Añadida al <weekday>, … with Deshacer, and Undo removes it',
    (tester) async {
      platform.setMockMethodCallHandler(timeoutChannel, (_) async => 10000);
      final now = DateTime.now();
      final tomorrow = DateTime(now.year, now.month, now.day + 1);
      final container = await openCalendar(tester, [
        Task(
          id: 1,
          title: 'Regar las plantas',
          priority: 1,
          dueDate: DateTime(now.year, now.month, now.day, 9),
        ),
      ], captures: MemoryCaptures());
      final calendar = tester.element(find.byType(CalendarScreen));
      final l = calendar.l10n;
      expect(find.text(l.todayAgenda), findsOneWidget);
      await fillForm(
        tester,
        'Llevar el coche al taller',
        day: 'new-task-tomorrow',
      );

      // Mañana is selected.
      expect(
        find.text(DateFormat.MMMMEEEEd('es').format(tomorrow)),
        findsOneWidget,
      );
      expect(find.text(l.todayAgenda), findsNothing);
      // Its row is in view, clear of the message, and lit up.
      final row = find.widgetWithText(TaskTile, 'Llevar el coche al taller');
      expect(row.hitTestable(), findsOneWidget);
      final message = l.taskAddedOn(calendar.weekdayDate(tomorrow));
      expect(find.text(message), findsOneWidget);
      expect(
        tester.getRect(row).bottom,
        lessThanOrEqualTo(tester.getRect(find.byType(SnackBar)).top),
      );
      expect(tester.getRect(row).top, greaterThanOrEqualTo(0));
      final colors = Theme.of(calendar).colorScheme;
      expect(tester.widget<TaskTile>(row).color, colors.primaryContainer);
      // The message leads with the weekday, never Hoy or Mañana.
      expect(message, contains(DateFormat.E('es').format(tomorrow)));
      expect(message, isNot(l.taskAddedOn(l.tomorrow)));
      expect(message, isNot(l.taskAddedOn(l.today)));
      expect(find.text(l.undo), findsOneWidget);
      // The highlight fades after about 1.5 s.
      await tester.pump(const Duration(seconds: 2));
      await tester.pump(const Duration(seconds: 1));
      expect(tester.widget<TaskTile>(row).color, colors.surface);

      await tester.tap(find.text(l.undo));
      await tester.pumpAndSettle();
      expect(
        container
            .read(taskProvider)
            .requireValue
            .where((task) => task.title == 'Llevar el coche al taller'),
        isEmpty,
      );
      expect(row, findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'UX-205: an undated task filled in from Calendario says it went to the inbox and offers Deshacer',
    (tester) async {
      platform.setMockMethodCallHandler(timeoutChannel, (_) async => 10000);
      final container = await openCalendar(
        tester,
        [],
        captures: MemoryCaptures(),
      );
      final l = tester.element(find.byType(CalendarScreen)).l10n;
      await fillForm(tester, 'Algún día');
      expect(find.text(l.taskSavedInbox), findsOneWidget);
      expect(find.text(l.todayAgenda), findsOneWidget);
      await tester.tap(find.text(l.undo));
      await tester.pumpAndSettle();
      expect(container.read(taskProvider).requireValue, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'UX-203: crossing midnight with Calendar open, and again before a resume, selects the new today',
    (tester) async {
      var clock = DateTime(2030, 3, 14, 23, 59, 58);
      await openCalendar(
        tester,
        [],
        overrides: [calendarClockProvider.overrideWithValue(() => clock)],
      );
      final l = tester.element(find.byType(CalendarScreen)).l10n;
      expect(find.text(l.todayAgenda), findsOneWidget);
      // Midnight passes while the app is open.
      clock = DateTime(2030, 3, 15, 0, 0, 2);
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
      expect(find.text(l.todayAgenda), findsOneWidget);
      expect(
        find.text(DateFormat.MMMMEEEEd('es').format(DateTime(2030, 3, 14))),
        findsNothing,
      );
      // Left in recent apps overnight, then opened again.
      leaveApp(tester);
      await tester.pump();
      clock = DateTime(2030, 3, 16, 7, 30);
      returnToApp(tester);
      await tester.pumpAndSettle();
      expect(find.text(l.todayAgenda), findsOneWidget);
      // The week strip moved too: the new today is in the grid.
      expect(
        find.descendant(
          of: find.byType(TableCalendar<Task>),
          matching: find.text('16'),
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('UX-203: a day chosen on purpose stays chosen after midnight', (
    tester,
  ) async {
    var clock = DateTime(2030, 3, 14, 23, 59, 58);
    await openCalendar(
      tester,
      [],
      overrides: [calendarClockProvider.overrideWithValue(() => clock)],
    );
    final l = tester.element(find.byType(CalendarScreen)).l10n;
    await tapDay(tester, DateTime(2030, 3, 13));
    final chosen = DateFormat.MMMMEEEEd('es').format(DateTime(2030, 3, 13));
    expect(find.text(chosen), findsOneWidget);
    clock = DateTime(2030, 3, 15, 0, 0, 2);
    leaveApp(tester);
    await tester.pump();
    returnToApp(tester);
    await tester.pumpAndSettle();
    expect(find.text(chosen), findsOneWidget);
    expect(find.text(l.todayAgenda), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'UX-203: Nueva tarea, from Calendar and from the day timeline, never gives a past day',
    (tester) async {
      final today = DateTime(2030, 3, 14, 11);
      final captures = MemoryCaptures();
      await openCalendar(
        tester,
        [],
        overrides: [calendarClockProvider.overrideWithValue(() => today)],
        captures: captures,
      );
      final calendar = tester.element(find.byType(CalendarScreen));
      final l = calendar.l10n;
      final past = DateTime(2030, 3, 11);
      await tapDay(tester, past);
      expect(
        find.text(DateFormat.MMMMEEEEd('es').format(past)),
        findsOneWidget,
      );
      Future<void> expectNoDay() async {
        await tester.tap(find.text(l.newTask).hitTestable());
        await tester.pumpAndSettle();
        expect(find.byType(TaskEditor), findsOneWidget);
        // No day chosen: neither Hoy, Mañana nor another date.
        for (final key in [
          'new-task-today',
          'new-task-tomorrow',
          'new-task-pick-day',
        ]) {
          expect(
            tester.widget<ChoiceChip>(find.byKey(ValueKey(key))).selected,
            isFalse,
            reason: key,
          );
        }
        expect(find.text(l.pickDay), findsOneWidget);
        // Empty: Back just closes it.
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(find.byType(TaskEditor), findsNothing);
      }

      await expectNoDay();

      await tester.tap(find.byKey(const ValueKey('calendar-format')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l.day).last);
      await tester.pumpAndSettle();
      expect(find.byType(DayTimelineScreen), findsOneWidget);
      // The timeline has the same one button, and no +.
      expect(find.byType(FloatingActionButton), findsNothing);
      await expectNoDay();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'UX-220: a task completed on Calendar keeps its place until the day changes or Calendar is left',
    (tester) async {
      final now = DateTime.now();
      DateTime at(int hour) => DateTime(now.year, now.month, now.day, hour);
      await openCalendar(tester, [
        Task(id: 1, title: 'Primera', priority: 1, dueDate: at(9)),
        Task(id: 2, title: 'Segunda', priority: 1, dueDate: at(12)),
        Task(id: 3, title: 'Tercera', priority: 1, dueDate: at(15)),
      ]);
      final l = tester.element(find.byType(CalendarScreen)).l10n;
      List<String> order() {
        final titles = ['Primera', 'Segunda', 'Tercera'];
        return titles..sort(
          (a, b) => tester
              .getTopLeft(find.widgetWithText(TaskTile, a))
              .dy
              .compareTo(
                tester.getTopLeft(find.widgetWithText(TaskTile, b)).dy,
              ),
        );
      }

      expect(order(), ['Primera', 'Segunda', 'Tercera']);
      final checkbox = find.descendant(
        of: find.widgetWithText(TaskTile, 'Primera'),
        matching: find.byType(Checkbox),
      );
      await tester.tap(checkbox);
      await tester.pumpAndSettle();
      expect(tester.widget<Checkbox>(checkbox).value, isTrue);
      expect(order(), ['Primera', 'Segunda', 'Tercera']);
      // Another day, then back: done tasks go last.
      await monthView(tester);
      await tapDay(tester, otherDay());
      await tester.tap(find.widgetWithText(TextButton, l.today));
      await tester.pumpAndSettle();
      await scrollAgendaToEnd(tester);
      expect(order(), ['Segunda', 'Tercera', 'Primera']);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'UX-220: a task completed on Calendar settles at the end after another screen covered Calendar',
    (tester) async {
      final now = DateTime.now();
      DateTime at(int hour) => DateTime(now.year, now.month, now.day, hour);
      await openCalendar(tester, [
        Task(id: 1, title: 'Primera', priority: 1, dueDate: at(9)),
        Task(id: 2, title: 'Segunda', priority: 1, dueDate: at(12)),
      ]);
      double top(String title) =>
          tester.getTopLeft(find.widgetWithText(TaskTile, title)).dy;
      await tester.tap(
        find.descendant(
          of: find.widgetWithText(TaskTile, 'Primera'),
          matching: find.byType(Checkbox),
        ),
      );
      await tester.pumpAndSettle();
      expect(top('Primera'), lessThan(top('Segunda')));
      tester
          .state<NavigatorState>(find.byType(Navigator))
          .pushNamed('/completedTasks');
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(top('Primera'), greaterThan(top('Segunda')));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('UX-220: Completed tasks lists the newest first', (tester) async {
    final now = DateTime.now();
    DateTime daysAgo(int days) =>
        DateTime(now.year, now.month, now.day - days, 10);
    await openCalendar(tester, [
      Task(
        id: 1,
        title: 'Hace tres días',
        priority: 1,
        isCompleted: true,
        dueDate: daysAgo(3),
      ),
      Task(
        id: 2,
        title: 'Ayer',
        priority: 1,
        isCompleted: true,
        dueDate: daysAgo(1),
      ),
      Task(
        id: 3,
        title: 'Hace dos días',
        priority: 1,
        isCompleted: true,
        dueDate: daysAgo(2),
      ),
    ]);
    tester
        .state<NavigatorState>(find.byType(Navigator))
        .pushNamed('/completedTasks');
    await tester.pumpAndSettle();
    expect(find.byType(CompletedTasksScreen), findsOneWidget);
    double top(String title) =>
        tester.getTopLeft(find.widgetWithText(TaskTile, title)).dy;
    expect(top('Ayer'), lessThan(top('Hace dos días')));
    expect(top('Hace dos días'), lessThan(top('Hace tres días')));
    expect(tester.takeException(), isNull);
  });

  // P52: room for today's tasks at large text, and three small fixes.
  final october13 = DateTime(2026, 10, 13, 9);
  Finder inCalendar(Finder finder) =>
      find.descendant(of: find.byType(CalendarScreen), matching: finder);

  testWidgets(
    'UX-202: at 1.3x text in Spanish the current month reads octubre without the year, on the same line as Semana; another year reads octubre de 2027',
    (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await openCalendar(
        tester,
        [],
        overrides: [calendarClockProvider.overrideWithValue(() => october13)],
      );
      tester.view.padding = const FakeViewPadding(top: 24, bottom: 24);
      await tester.pumpAndSettle();
      final l = tester.element(find.byType(CalendarScreen)).l10n;
      final month = inCalendar(find.text('octubre'));
      expect(month, findsOneWidget);
      expect(inCalendar(find.textContaining('2026')), findsNothing);
      final switcher = find.descendant(
        of: find.byKey(const ValueKey('calendar-format')),
        matching: find.text(l.week),
      );
      expect(switcher, findsOneWidget);
      expect(
        (tester.getCenter(month).dy - tester.getCenter(switcher).dy).abs(),
        lessThanOrEqualTo(4),
        reason: 'the month and Semana share a line',
      );
      expect(tester.takeException(), isNull);

      // Twelve months on, the year is named.
      await tester.tap(find.byKey(const ValueKey('calendar-format')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l.month).last);
      await tester.pumpAndSettle();
      for (var i = 0; i < 12; i++) {
        await tester.tap(find.byTooltip(l.nextMonth));
        await tester.pumpAndSettle();
      }
      expect(
        inCalendar(
          find.text(DateFormat.yMMMM('es').format(DateTime(2027, 10))),
        ),
        findsOneWidget,
      );
      expect(inCalendar(find.text('octubre de 2027')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  for (final (language, name) in [('ca', 'octubre'), ('en', 'October')]) {
    testWidgets(
      'UX-202: in ${language == 'ca' ? 'Catalan' : 'English'} the current month reads $name, never d’octubre',
      (tester) async {
        await openCalendar(
          tester,
          [],
          language: language,
          overrides: [calendarClockProvider.overrideWithValue(() => october13)],
        );
        expect(inCalendar(find.text(name)), findsOneWidget);
        expect(inCalendar(find.textContaining('d’octubre')), findsNothing);
        expect(inCalendar(find.textContaining("d'octubre")), findsNothing);
        expect(inCalendar(find.textContaining('2026')), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  // ---- Round 1 · P21 · UX-227: the arrows respect Remove animations ----

  for (final instant in [true, false]) {
    testWidgets(
      'UX-227: with animations ${instant ? 'off, the week and month arrows change the page at once' : 'on, the arrows still animate'}',
      (tester) async {
        if (instant) {
          tester.platformDispatcher.accessibilityFeaturesTestValue =
              const FakeAccessibilityFeatures(disableAnimations: true);
          addTearDown(
            tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
          );
        }
        await openCalendar(
          tester,
          [],
          overrides: [calendarClockProvider.overrideWithValue(() => october13)],
        );
        final l = tester.element(find.byType(CalendarScreen)).l10n;
        Finder day(int number) => find
            .descendant(
              of: find.byType(TableCalendar<Task>),
              matching: find.text('$number'),
            )
            .hitTestable();
        double page() => tester
            .widget<PageView>(
              find.descendant(
                of: find.byType(TableCalendar<Task>),
                matching: find.byType(PageView),
              ),
            )
            .controller!
            .page!;

        /// Taps [arrow] and checks the page lands at once, or animates.
        Future<void> turn(String arrow, int by) async {
          final from = page();
          await tester.tap(find.byTooltip(arrow));
          await tester.pump();
          if (instant) {
            // One frame, no time passed: the page has already changed.
            expect(page(), from + by);
            await tester.pump();
          } else {
            await tester.pump(const Duration(milliseconds: 100));
            final moving = page();
            expect(
              moving != from && moving != from + by,
              isTrue,
              reason:
                  'mid-animation the page is between $from and ${from + by}',
            );
            await tester.pumpAndSettle();
            expect(page(), from + by);
          }
        }

        // Week view: the 13th's week shows; the 20th is next week.
        expect(day(13), findsOneWidget);
        expect(day(20), findsNothing);
        await turn(l.nextWeek, 1);
        expect(day(20), findsOneWidget);
        expect(day(13), findsNothing);
        await turn(l.previousWeek, -1);
        expect(day(13), findsOneWidget);

        // Month view: the next month's name shows in the same frame.
        await monthView(tester);
        expect(inCalendar(find.text('octubre')), findsOneWidget);
        await turn(l.nextMonth, 1);
        expect(inCalendar(find.text('noviembre')), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('UX-202: with no projects the project scope takes no height', (
    tester,
  ) async {
    await openCalendar(tester, []);
    // A sliver with no extent counts as offstage, so look there too.
    final scope = find.descendant(
      of: find.byType(CalendarScreen),
      matching: find.byType(ProjectScopeControl, skipOffstage: false),
      skipOffstage: false,
    );
    expect(scope, findsOneWidget);
    expect(tester.getSize(scope).height, 0);
    expect(tester.takeException(), isNull);
  });

  for (final (language, label) in [
    ('es', 'Cambiar vista'),
    ('en', 'Change view'),
    ('ca', 'Canvia la vista'),
  ]) {
    testWidgets(
      'UX-446: the view switcher’s TalkBack label is $label, not Mostrar menú ($language)',
      (tester) async {
        final semantics = tester.ensureSemantics();
        await openCalendar(tester, [], language: language);
        final context = tester.element(find.byType(CalendarScreen));
        final l = context.l10n;
        expect(l.changeView, label);
        final switcher = find.byKey(const ValueKey('calendar-format'));
        expect(tester.widget<PopupMenuButton<String>>(switcher).tooltip, label);
        expect(
          find.descendant(of: switcher, matching: find.byTooltip(label)),
          findsOneWidget,
        );
        final data = tester.getSemantics(switcher).getSemanticsData();
        expect(data.tooltip, label);
        expect(
          data.tooltip,
          isNot(MaterialLocalizations.of(context).showMenuTooltip),
        );
        semantics.dispose();
        expect(tester.takeException(), isNull);
      },
    );
  }

  List<Override> phoneCalendar(_FlakyCalendars bridge) => [
    deviceCalendarsProvider.overrideWithValue(bridge),
    calendarPreferenceStoreProvider.overrideWithValue(
      MemoryCalendarPreferences(
        CalendarPreferences(
          enabled: true,
          accounts: {workCalendar.accountKey},
        ),
      ),
    ),
  ];

  testWidgets(
    'UX-442: when the day’s events fail to load, the line says Toca para reintentar and a tap reads them again, with no sheet or calendar choice',
    (tester) async {
      final now = DateTime.now();
      final bridge = _FlakyCalendars()
        ..failEvents = true
        ..data = [
          DeviceCalendarEvent(
            id: '30',
            calendarId: workCalendar.id,
            title: 'Dentista',
            start: DateTime(now.year, now.month, now.day, 9),
            end: DateTime(now.year, now.month, now.day, 10),
            allDay: false,
          ),
        ];
      addTearDown(bridge.close);
      await openCalendar(tester, [], overrides: phoneCalendar(bridge));
      final context = tester.element(find.byType(CalendarScreen));
      final l = context.l10n;
      expect(
        l.calendarReadRetry,
        'No se pudieron leer los eventos. Toca para reintentar.',
      );
      final line = find.byKey(const ValueKey('calendar-events-line'));
      await reveal(tester, line);
      expect(
        find.descendant(of: line, matching: find.text(l.calendarReadRetry)),
        findsOneWidget,
      );
      final before = bridge.eventReads;
      expect(before, greaterThanOrEqualTo(1));
      await tester.tap(line);
      await tester.pumpAndSettle();
      expect(bridge.eventReads, before + 1, reason: 'read again');
      expect(find.byType(BottomSheet), findsNothing);
      expect(find.byType(DeviceCalendarsScreen), findsNothing);
      expect(find.byType(CalendarScreen).hitTestable(), findsWidgets);
      // Still failing: still the retry line.
      expect(find.text(l.calendarReadRetry), findsOneWidget);

      // The read works this time: the events show.
      bridge.failEvents = false;
      await tester.tap(line);
      await tester.pumpAndSettle();
      expect(find.text(l.calendarReadRetry), findsNothing);
      expect(
        find.text(
          'Dentista · '
          '${context.clockTime(DateTime(now.year, now.month, now.day, 9))}',
        ),
        findsOneWidget,
      );
      expect(find.byType(DeviceCalendarsScreen), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'UX-442: when the phone calendars can’t be read, the line says Toca para reintentar and a tap refreshes them, not calendar choice',
    (tester) async {
      final bridge = _FlakyCalendars()
        ..failCalendars = true
        ..data = [];
      addTearDown(bridge.close);
      await openCalendar(tester, [], overrides: phoneCalendar(bridge));
      final l = tester.element(find.byType(CalendarScreen)).l10n;
      final line = find.byKey(const ValueKey('calendar-events-line'));
      await reveal(tester, line);
      expect(
        find.descendant(of: line, matching: find.text(l.calendarReadRetry)),
        findsOneWidget,
      );
      final before = bridge.calendarReads;
      bridge.failCalendars = false;
      await tester.tap(line);
      await tester.pumpAndSettle();
      expect(bridge.calendarReads, greaterThan(before), reason: 'refreshed');
      expect(find.text(l.calendarReadRetry), findsNothing);
      expect(find.byType(BottomSheet), findsNothing);
      expect(find.byType(DeviceCalendarsScreen), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  // UX-447 / P57: a tapped retry keeps its line, with a spinner in place of
  // the icon and no second tap, until the read settles.
  group('UX-447: a tapped retry keeps its line and shows progress', () {
    final line = find.byKey(const ValueKey('calendar-events-line'));
    final below = find.byKey(const ValueKey('calendar-inbox'));
    Finder spinner() => find.descendant(
      of: line,
      matching: find.byType(CircularProgressIndicator),
    );
    Finder eventIcon() =>
        find.descendant(of: line, matching: find.byIcon(Icons.event_outlined));
    // An undated task puts the inbox button right below the events line.
    final inboxTask = Task(id: 1, title: 'Algún día', priority: 1);

    _FlakyCalendars failing({required bool calendars}) {
      final now = DateTime.now();
      return _FlakyCalendars()
        ..failCalendars = calendars
        ..failEvents = !calendars
        ..data = [
          DeviceCalendarEvent(
            id: '30',
            calendarId: workCalendar.id,
            title: 'Dentista',
            start: DateTime(now.year, now.month, now.day, 9),
            end: DateTime(now.year, now.month, now.day, 10),
            allDay: false,
          ),
        ];
    }

    /// Taps the retry line with the next read held, checks the busy line,
    /// then lets that read settle.
    Future<void> retryHeld(
      WidgetTester tester,
      _FlakyCalendars bridge, {
      required bool succeed,
    }) async {
      final l = tester.element(find.byType(CalendarScreen)).l10n;
      expect(
        l.calendarReadRetry,
        'No se pudieron leer los eventos. Toca para reintentar.',
      );
      // The line and the inbox button sit at the end of the agenda.
      await scrollAgendaToEnd(tester);
      expect(below.hitTestable(), findsOneWidget);
      expect(
        find.descendant(of: line, matching: find.text(l.calendarReadRetry)),
        findsOneWidget,
      );
      expect(eventIcon(), findsOneWidget);
      expect(spinner(), findsNothing);
      final lineBefore = tester.getRect(line);
      final belowBefore = tester.getRect(below);
      expect(lineBefore.height, greaterThanOrEqualTo(48));
      bridge.held = 0;

      final gate = bridge.gate = Completer<void>();
      await tester.tap(line);
      for (var i = 0; i < 3; i++) {
        await tester.pump();
      }
      // Still the same line, in the same place and at the same height, busy.
      expect(line, findsOneWidget);
      expect(
        find.descendant(of: line, matching: find.text(l.calendarReadRetry)),
        findsOneWidget,
      );
      expect(spinner(), findsOneWidget);
      expect(eventIcon(), findsNothing);
      expect(tester.getRect(line), lineBefore);
      expect(
        tester.getRect(below),
        belowBefore,
        reason: 'the content below did not move',
      );
      // It can't be tapped again while the read is pending.
      expect(tester.widget<InkWell>(line).onTap, isNull);
      await tester.tap(line, warnIfMissed: false);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(spinner(), findsOneWidget);
      expect(bridge.held, 1, reason: 'one read for the one retry');

      if (succeed) {
        bridge.failCalendars = false;
        bridge.failEvents = false;
      }
      bridge.gate = null;
      gate.complete();
      await tester.pumpAndSettle();
      expect(spinner(), findsNothing);
    }

    for (final calendars in [true, false]) {
      final what = calendars ? 'the phone calendars' : 'the day’s events';
      testWidgets(
        'UX-447: $what read failing twice: during the retry the line keeps its place and height with a spinner and no icon; after the second failure the retry line is back with its icon',
        (tester) async {
          final bridge = failing(calendars: calendars);
          addTearDown(bridge.close);
          await openCalendar(tester, [
            inboxTask,
          ], overrides: phoneCalendar(bridge));
          final l = tester.element(find.byType(CalendarScreen)).l10n;
          await retryHeld(tester, bridge, succeed: false);
          expect(
            find.descendant(of: line, matching: find.text(l.calendarReadRetry)),
            findsOneWidget,
          );
          expect(eventIcon(), findsOneWidget);
          expect(tester.widget<InkWell>(line).onTap, isNotNull);
          expect(tester.takeException(), isNull);
        },
      );

      testWidgets(
        'UX-447: at 2x text on 320x568 in Spanish, $what retry keeps the line at its height',
        (tester) async {
          final bridge = failing(calendars: calendars);
          addTearDown(bridge.close);
          await openCalendar(
            tester,
            [inboxTask],
            overrides: phoneCalendar(bridge),
            size: const Size(320, 568),
            textScale: 2,
          );
          await retryHeld(tester, bridge, succeed: false);
          expect(eventIcon(), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );

      testWidgets(
        'UX-447: when $what retry succeeds the event shows by name with its icon and no spinner',
        (tester) async {
          final now = DateTime.now();
          final bridge = failing(calendars: calendars);
          addTearDown(bridge.close);
          await openCalendar(tester, [
            inboxTask,
          ], overrides: phoneCalendar(bridge));
          final context = tester.element(find.byType(CalendarScreen));
          final l = context.l10n;
          await retryHeld(tester, bridge, succeed: true);
          expect(find.text(l.calendarReadRetry), findsNothing);
          final name = find.text(
            'Dentista · '
            '${context.clockTime(DateTime(now.year, now.month, now.day, 9))}',
          );
          expect(name, findsOneWidget);
          final row = find.ancestor(of: name, matching: find.byType(InkWell));
          expect(
            find.descendant(of: row, matching: find.byIcon(Icons.event_outlined)),
            findsOneWidget,
          );
          expect(find.byType(CircularProgressIndicator), findsNothing);
          expect(tester.takeException(), isNull);
        },
      );
    }

    for (final calendars in [true, false]) {
      final what = calendars ? 'the phone calendars' : 'the day’s events';
      testWidgets(
        'UX-450: while $what retry runs, the events line is a button that is not enabled; idle, it is enabled',
        (tester) async {
          final semantics = tester.ensureSemantics();
          final bridge = failing(calendars: calendars);
          addTearDown(bridge.close);
          await openCalendar(tester, [
            inboxTask,
          ], overrides: phoneCalendar(bridge));
          await scrollAgendaToEnd(tester);
          expect(
            tester.getSemantics(line),
            isSemantics(
              isButton: true,
              hasEnabledState: true,
              isEnabled: true,
              hasTapAction: true,
            ),
          );
          final idle = tester.getRect(line);
          final gate = bridge.gate = Completer<void>();
          await tester.tap(line);
          for (var i = 0; i < 3; i++) {
            await tester.pump();
          }
          expect(spinner(), findsOneWidget);
          expect(
            tester.getSemantics(line),
            isSemantics(
              isButton: true,
              hasEnabledState: true,
              isEnabled: false,
              hasTapAction: false,
            ),
          );
          // Nothing moves.
          expect(tester.getRect(line), idle);
          bridge.gate = null;
          gate.complete();
          await tester.pumpAndSettle();
          expect(spinner(), findsNothing);
          expect(
            tester.getSemantics(line),
            isSemantics(
              isButton: true,
              hasEnabledState: true,
              isEnabled: true,
              hasTapAction: true,
            ),
          );
          expect(tester.takeException(), isNull);
          semantics.dispose();
        },
      );
    }

    testWidgets(
      'UX-447: on the first load, while access is still being checked, there is no events line and no spinner',
      (tester) async {
        final bridge = failing(calendars: false)..failEvents = false;
        final statusGate = bridge.statusGate = Completer<void>();
        addTearDown(bridge.close);
        await openCalendar(
          tester,
          [inboxTask],
          overrides: phoneCalendar(bridge),
          settle: false,
        );
        await reveal(tester, below);
        expect(line, findsNothing);
        expect(
          find.descendant(
            of: find.byType(DeviceCalendarEvents),
            matching: find.byType(CircularProgressIndicator),
          ),
          findsNothing,
        );
        bridge.statusGate = null;
        statusGate.complete();
        await tester.pumpAndSettle();
        // Once read, the day's event shows as usual, by name.
        expect(
          find.descendant(
            of: find.byType(DeviceCalendarEvents),
            matching: find.byIcon(Icons.event_outlined),
          ),
          findsOneWidget,
        );
        expect(find.textContaining('Dentista · '), findsOneWidget);
        expect(spinner(), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  });

  // ---- Round 1 (b9) · P43 (U11): Sin fecha replaces Bandeja ----

  for (final (language, label) in [
    ('es', 'Sin fecha · 2'),
    ('ca', 'Sense data · 2'),
    ('en', 'No date · 2'),
  ]) {
    testWidgets(
      'U11: Calendar shows $label for two undated tasks, and it opens the Sin fecha page ($language)',
      (tester) async {
        final now = DateTime.now();
        await openCalendar(tester, language: language, [
          Task(
            id: 1,
            title: 'Revisar el informe',
            priority: 1,
            dueDate: DateTime(now.year, now.month, now.day, 10),
          ),
          Task(id: 2, title: 'Algún día', priority: 1),
          Task(id: 3, title: 'Pintar la valla', priority: 1),
        ]);
        final l = tester.element(find.byType(CalendarScreen)).l10n;
        expect(l.inboxCount(2), label);
        final inbox = find.text(label);
        await reveal(tester, inbox);
        expect(inbox, findsOneWidget);
        expect(find.textContaining('Bandeja'), findsNothing);
        expect(find.textContaining('Inbox'), findsNothing);
        await tester.tap(find.byKey(const ValueKey('calendar-inbox')));
        await tester.pumpAndSettle();
        expect(
          find.descendant(
            of: find.byType(AppBar),
            matching: find.text(l.inbox),
          ),
          findsOneWidget,
        );
        expect(find.widgetWithText(TaskTile, 'Algún día'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  // ---- Round 1 · P41 (U12): a brand-new account is told what to try ----

  Finder emptyState() => find.descendant(
    of: find.byType(CalendarScreen),
    matching: find.byType(EmptyState),
  );

  testWidgets(
    'U12: a new account with Pro and no tasks shows Prueba: toca Añadir tarea y di «…»',
    (tester) async {
      await openCalendar(tester, const []);
      final l = tester.element(find.byType(CalendarScreen)).l10n;
      expect(
        l.calendarTrySaying,
        'Prueba: toca Añadir tarea y di «Mañana, llamar al dentista y comprar pan».',
      );
      expect(
        find.descendant(
          of: emptyState(),
          matching: find.text(l.rememberPrompt),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: emptyState(),
          matching: find.text(l.calendarTrySaying),
        ),
        findsOneWidget,
      );
      expect(find.text(l.calendarEmpty), findsNothing);
      expect(find.text(l.calendarTryTyping), findsNothing);
      // The instruction names the button that is on screen, and adds no
      // card or dismiss button of its own.
      expect(find.text(l.addTask), findsWidgets);
      expect(
        find.descendant(
          of: emptyState(),
          matching: find.byType(ButtonStyleButton),
        ),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'U12 / 2026-10-18 (later): a new account without Pro shows Prueba: toca Nueva tarea, escribe «…» y toca Mañana, the button on screen',
    (tester) async {
      await openCalendar(tester, const [], captures: MemoryCaptures());
      final l = tester.element(find.byType(CalendarScreen)).l10n;
      expect(
        l.calendarTryForm,
        'Prueba: toca Nueva tarea, escribe «Llamar al dentista» y toca Mañana.',
      );
      // While billing doesn't know yet, typing is still read on the phone.
      expect(
        l.calendarTryTyping,
        'Prueba: toca Añadir tarea y escribe «Mañana, llamar al dentista».',
      );
      expect(
        find.descendant(
          of: emptyState(),
          matching: find.text(l.calendarTryForm),
        ),
        findsOneWidget,
      );
      expect(find.text(l.newTask), findsWidgets);
      expect(find.text(l.calendarTryTyping), findsNothing);
      expect(find.text(l.calendarTrySaying), findsNothing);
      expect(find.text(l.calendarEmpty), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  test('U12: the instruction in English and Catalan names the real button', () {
    final en = lookupAppLocalizations(const Locale('en'));
    final ca = lookupAppLocalizations(const Locale('ca'));
    expect(
      en.calendarTrySaying,
      'Try it: tap Add a task and say “Tomorrow, call the dentist and buy bread.”',
    );
    expect(
      en.calendarTryTyping,
      'Try it: tap Add a task and type “Tomorrow, call the dentist.”',
    );
    expect(
      ca.calendarTrySaying,
      'Prova-ho: toca Afegeix una tasca i digues «Demà, trucar al dentista i comprar pa».',
    );
    expect(
      ca.calendarTryTyping,
      'Prova-ho: toca Afegeix una tasca i escriu «Demà, trucar al dentista».',
    );
    for (final l in [en, ca, lookupAppLocalizations(const Locale('es'))]) {
      expect(l.calendarTrySaying, contains(l.addTask));
      expect(l.calendarTryTyping, contains(l.addTask));
    }
  });

  for (final (name, task) in [
    (
      'a task on another day',
      Task(
        id: 1,
        title: 'Comprar pan',
        priority: 1,
        dueDate: DateTime.now().add(const Duration(days: 30)),
      ),
    ),
    ('a task with no date', Task(id: 1, title: 'Algún día', priority: 1)),
    (
      'only a note',
      Task(id: 1, title: 'Ideas para el viaje', priority: 1, kind: 'note'),
    ),
    (
      'only a completed task from yesterday',
      Task(
        id: 1,
        title: 'Hecho ayer',
        priority: 1,
        isCompleted: true,
        dueDate: DateTime.now().subtract(const Duration(days: 1)),
      ),
    ),
  ]) {
    testWidgets(
      'U12: once the account has $name, an empty day shows Nada previsto para este día.',
      (tester) async {
        await openCalendar(tester, [task]);
        final l = tester.element(find.byType(CalendarScreen)).l10n;
        expect(l.calendarEmpty, 'Nada previsto para este día.');
        expect(
          find.descendant(
            of: emptyState(),
            matching: find.text(l.calendarEmpty),
          ),
          findsOneWidget,
        );
        expect(find.text(l.calendarTrySaying), findsNothing);
        expect(find.text(l.calendarTryTyping), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'U12: once a task has existed, deleting it does not bring the instruction back',
    (tester) async {
      final container = await openCalendar(tester, [
        Task(
          id: 1,
          title: 'Comprar pan',
          priority: 1,
          dueDate: DateTime.now().add(const Duration(days: 30)),
        ),
      ]);
      final l = tester.element(find.byType(CalendarScreen)).l10n;
      expect(find.text(l.calendarEmpty), findsOneWidget);
      await container.read(taskProvider.notifier).deleteTask(1, sync: false);
      await tester.pumpAndSettle();
      expect(container.read(taskProvider).requireValue, isEmpty);
      expect(find.text(l.calendarTrySaying), findsNothing);
      expect(find.text(l.calendarEmpty), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  for (final language in ['es', 'ca']) {
    for (final pro in [true, false]) {
      testWidgets(
        'U12: at 2x text on 320x568 ($language, ${pro ? 'Pro' : 'no Pro'}) the instruction fits without overflow',
        (tester) async {
          await openCalendar(
            tester,
            const [],
            language: language,
            size: const Size(320, 568),
            textScale: 2,
            captures: pro ? null : MemoryCaptures(),
          );
          final l = tester.element(find.byType(CalendarScreen)).l10n;
          final message = find.text(
            pro ? l.calendarTrySaying : l.calendarTryForm,
          );
          // Scroll the page, not the week strip: a drag on the strip changes
          // the calendar's format.
          await scrollAgendaToEnd(tester);
          expect(message, findsOneWidget);
          final box = tester.getRect(message);
          expect(box.left, greaterThanOrEqualTo(0));
          expect(box.right, lessThanOrEqualTo(320));
          // Fully on screen, above the bottom of the 568-high view.
          expect(box.top, greaterThanOrEqualTo(0));
          expect(box.bottom, lessThanOrEqualTo(568));
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  // ---- Round 2 (b10) · P118 (U12): the instruction never comes back once
  // the account has had a task or note ----

  Task later() => Task(
    id: 1,
    title: 'Comprar pan',
    priority: 1,
    dueDate: DateTime.now().add(const Duration(days: 30)),
  );

  testWidgets(
    'U12: the flag survives a restart: a marked account with no tasks shows Nada previsto para este día.',
    (tester) async {
      final store = MemoryFirstTaskStore();
      // First run: the account has one task, then deletes it.
      final first = await openCalendar(
        tester,
        [later()],
        overrides: [firstTaskStoreProvider.overrideWithValue(store)],
      );
      await first.read(taskProvider.notifier).deleteTask(1, sync: false);
      await tester.pumpAndSettle();
      expect(
        store.owners,
        contains(first.read(taskRepositoryProvider).ownerKey),
      );
      // The app closes and opens again, with no tasks and no notes.
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      await openCalendar(
        tester,
        const [],
        overrides: [firstTaskStoreProvider.overrideWithValue(store)],
      );
      final l = tester.element(find.byType(CalendarScreen)).l10n;
      expect(
        find.descendant(of: emptyState(), matching: find.text(l.calendarEmpty)),
        findsOneWidget,
      );
      expect(find.text(l.calendarTrySaying), findsNothing);
      expect(find.text(l.calendarTryTyping), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'U12: a new container whose store is already marked for this account shows Nada previsto para este día.',
    (tester) async {
      for (final pro in [true, false]) {
        await tester.pumpWidget(const SizedBox());
        await openCalendar(
          tester,
          const [],
          captures: pro ? null : MemoryCaptures(),
          overrides: [
            firstTaskStoreProvider.overrideWithValue(
              MemoryFirstTaskStore([MemoryTasks().ownerKey]),
            ),
          ],
        );
        final l = tester.element(find.byType(CalendarScreen)).l10n;
        expect(
          find.descendant(
            of: emptyState(),
            matching: find.text(l.calendarEmpty),
          ),
          findsOneWidget,
          reason: pro ? 'Pro' : 'no Pro',
        );
        expect(find.text(l.calendarTrySaying), findsNothing);
        expect(find.text(l.calendarTryTyping), findsNothing);
        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets(
    'U12: while the remembered flag is still loading, Calendar shows the spinner and neither text',
    (tester) async {
      final never = Completer<bool>();
      await openCalendar(
        tester,
        const [],
        settle: false,
        overrides: [
          firstTaskStoreProvider.overrideWithValue(
            _PendingFirstTaskStore(never),
          ),
        ],
      );
      final l = tester.element(find.byType(CalendarScreen)).l10n;
      expect(
        find.descendant(
          of: find.byType(CalendarScreen),
          matching: find.byType(CircularProgressIndicator),
        ),
        findsWidgets,
      );
      expect(find.text(l.calendarEmpty), findsNothing);
      expect(find.text(l.calendarTrySaying), findsNothing);
      expect(find.text(l.calendarTryTyping), findsNothing);
      expect(tester.takeException(), isNull);
      // Leave nothing pending: tear the screen down before the test ends.
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'U12: the flag is per account: another account marked on this phone still gets the instruction',
    (tester) async {
      final ownerKey = MemoryTasks().ownerKey;
      final store = MemoryFirstTaskStore(['$ownerKey-another-account']);
      await openCalendar(
        tester,
        const [],
        overrides: [firstTaskStoreProvider.overrideWithValue(store)],
      );
      final l = tester.element(find.byType(CalendarScreen)).l10n;
      expect(
        find.descendant(
          of: emptyState(),
          matching: find.text(l.calendarTrySaying),
        ),
        findsOneWidget,
      );
      expect(find.text(l.calendarEmpty), findsNothing);
      expect(store.owners, isNot(contains(ownerKey)));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'U12: at 2x text on 320x568 in Catalan, deleting the only task shows calendarEmpty without overflow',
    (tester) async {
      final container = await openCalendar(
        tester,
        [later()],
        language: 'ca',
        size: const Size(320, 568),
        textScale: 2,
      );
      await container.read(taskProvider.notifier).deleteTask(1, sync: false);
      await tester.pumpAndSettle();
      expect(container.read(taskProvider).requireValue, isEmpty);
      final l = tester.element(find.byType(CalendarScreen)).l10n;
      await scrollAgendaToEnd(tester);
      final message = find.descendant(
        of: emptyState(),
        matching: find.text(l.calendarEmpty),
      );
      expect(message, findsOneWidget);
      expect(find.text(l.calendarTrySaying), findsNothing);
      expect(find.text(l.calendarTryTyping), findsNothing);
      final box = tester.getRect(message);
      expect(box.left, greaterThanOrEqualTo(0));
      expect(box.right, lessThanOrEqualTo(320));
      expect(box.top, greaterThanOrEqualTo(0));
      expect(box.bottom, lessThanOrEqualTo(568));
      expect(tester.takeException(), isNull);
    },
  );

  // ---- 2026-10-15-changes · P119 (UX-701, UX-702, UX-703): the first-run
  // line names both tasks on one day, asks no hour, and sits above the
  // button ----

  /// The words a person is told to say or type: between « » in Spanish and
  /// Catalan, between “ ” in English.
  String quoted(String line) {
    final (open, close) = line.contains('«') ? ('«', '»') : ('“', '”');
    return line.substring(line.indexOf(open) + 1, line.lastIndexOf(close));
  }

  test(
    'UX-701, UX-703: the first-run lines read exactly as planned in each language, and each names its Añadir tarea',
    () {
      final en = lookupAppLocalizations(const Locale('en'));
      final es = lookupAppLocalizations(const Locale('es'));
      final ca = lookupAppLocalizations(const Locale('ca'));
      expect(
        en.calendarTrySaying,
        'Try it: tap Add a task and say “Tomorrow, call the dentist and buy bread.”',
      );
      expect(
        es.calendarTrySaying,
        'Prueba: toca Añadir tarea y di «Mañana, llamar al dentista y comprar pan».',
      );
      expect(
        ca.calendarTrySaying,
        'Prova-ho: toca Afegeix una tasca i digues «Demà, trucar al dentista i comprar pa».',
      );
      expect(
        en.calendarTryTyping,
        'Try it: tap Add a task and type “Tomorrow, call the dentist.”',
      );
      expect(
        es.calendarTryTyping,
        'Prueba: toca Añadir tarea y escribe «Mañana, llamar al dentista».',
      );
      expect(
        ca.calendarTryTyping,
        'Prova-ho: toca Afegeix una tasca i escriu «Demà, trucar al dentista».',
      );
      for (final l in [en, es, ca]) {
        expect(l.calendarTrySaying, contains(l.addTask), reason: l.localeName);
        expect(l.calendarTryTyping, contains(l.addTask), reason: l.localeName);
      }
    },
  );

  for (final (language, title) in [
    ('es', 'Llamar al dentista y comprar pan'),
    ('en', 'Call the dentist and buy bread'),
    ('ca', 'Trucar al dentista i comprar pa'),
  ]) {
    test(
      'UX-701: Guardar como tarea on the spoken example ($language) is one task dated tomorrow, no time, no question',
      () {
        final words = quoted(
          lookupAppLocalizations(Locale(language)).calendarTrySaying,
        );
        for (final (reference, tomorrow) in [
          // Monday 19 Oct 2026 10:00 → Tuesday 20 Oct.
          (DateTime(2026, 10, 19, 10), DateTime(2026, 10, 20)),
          // Friday 16 Oct 2026 10:00 → Saturday 17 Oct.
          (DateTime(2026, 10, 16, 10), DateTime(2026, 10, 17)),
        ]) {
          final drafts = localDrafts(words, reference);
          expect(drafts, hasLength(1), reason: '$words at $reference');
          final draft = drafts.single;
          expect(draft.confirmed, isTrue, reason: words);
          expect(draft.clarifications, isEmpty, reason: words);
          expect(draft.task.dueDate, tomorrow, reason: '$words at $reference');
          expect(draft.task.hasTime, isFalse, reason: words);
          expect(draft.task.title, title, reason: words);
        }
      },
    );
  }

  for (final (language, title) in [
    ('es', 'Llamar al dentista'),
    ('en', 'Call the dentist'),
    ('ca', 'Trucar al dentista'),
  ]) {
    test(
      'UX-703: the typed example ($language) is one task dated tomorrow with no time choices',
      () {
        final words = quoted(
          lookupAppLocalizations(Locale(language)).calendarTryTyping,
        );
        final drafts = localDrafts(words, DateTime(2026, 10, 19, 10));
        expect(drafts, hasLength(1), reason: words);
        final draft = drafts.single;
        expect(draft.confirmed, isTrue, reason: words);
        expect(draft.clarifications, isEmpty, reason: words);
        expect(draft.task.dueDate, DateTime(2026, 10, 20), reason: words);
        expect(draft.task.hasTime, isFalse, reason: words);
        expect(draft.task.title, title, reason: words);
      },
    );
  }

  for (final (language, scale) in [
    ('es', 1.8),
    ('en', 1.8),
    ('ca', 1.8),
    ('es', 2.0),
    ('en', 2.0),
  ]) {
    testWidgets(
      'UX-702: on first launch at ${scale}x text, 390x844 ($language), the whole try-saying line is above Añadir tarea without scrolling',
      (tester) async {
        tester.view.padding = const FakeViewPadding(top: 24, bottom: 24);
        await openCalendar(
          tester,
          const [],
          language: language,
          textScale: scale,
        );
        final l = tester.element(find.byType(CalendarScreen)).l10n;
        expect(find.text(l.todayAgenda), findsOneWidget);
        // Not scrolled.
        expect(tester.state<ScrollableState>(agenda()).position.pixels, 0);
        final message = find.descendant(
          of: emptyState(),
          matching: find.text(l.calendarTrySaying),
        );
        expect(message, findsOneWidget);
        final actions = find.descendant(
          of: find.byType(CalendarScreen),
          matching: find.byType(TaskActions),
        );
        expect(actions, findsOneWidget);
        final line = tester.getRect(message);
        final button = tester.getRect(actions);
        expect(
          line.bottom,
          lessThanOrEqualTo(button.top),
          reason:
              'the line ends ${(line.bottom - button.top).toStringAsFixed(1)} dp below the top of Añadir tarea',
        );
        expect(line.top, greaterThanOrEqualTo(0));
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final pro in [true, false]) {
    testWidgets(
      'UX-702: first run (${pro ? 'Pro' : 'no Pro'}) shows Agenda de hoy and ¿Qué quieres recordar?, no line under the title and no icon tile',
      (tester) async {
        await openCalendar(
          tester,
          const [],
          captures: pro ? null : MemoryCaptures(),
        );
        final l = tester.element(find.byType(CalendarScreen)).l10n;
        expect(l.noScheduledTasks, 'No hay tareas para este día.');
        expect(find.text(l.todayAgenda), findsOneWidget);
        expect(
          find.descendant(
            of: emptyState(),
            matching: find.text(l.rememberPrompt),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: emptyState(),
            // Without Pro, Nueva tarea opens the form (2026-10-18 later).
            matching: find.text(pro ? l.calendarTrySaying : l.calendarTryForm),
          ),
          findsOneWidget,
        );
        expect(find.text(l.noScheduledTasks), findsNothing);
        expect(
          find.descendant(of: emptyState(), matching: find.byType(Icon)),
          findsNothing,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'UX-702 / UX-1404: with phone calendars on, first run has no No hay tareas para este día. line; once the account has had a task it does, with no icon tile',
    (tester) async {
      for (final hadTask in [false, true]) {
        await tester.pumpWidget(const SizedBox());
        final bridge = _FlakyCalendars()..data = [];
        addTearDown(bridge.close);
        await openCalendar(
          tester,
          const [],
          overrides: [
            ...phoneCalendar(bridge),
            firstTaskStoreProvider.overrideWithValue(
              MemoryFirstTaskStore([if (hadTask) MemoryTasks().ownerKey]),
            ),
          ],
        );
        final l = tester.element(find.byType(CalendarScreen)).l10n;
        expect(
          find.text(l.noScheduledTasks),
          hadTask ? findsOneWidget : findsNothing,
          reason: hadTask ? 'had a task' : 'first run',
        );
        expect(
          find.descendant(
            of: emptyState(),
            matching: find.byIcon(Icons.event_available_outlined),
          ),
          findsNothing,
        );
        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets(
    'UX-1404: an account that has had a task, on an empty day, shows only Nada previsto para este día., with no line under the title and no icon tile',
    (tester) async {
      await openCalendar(
        tester,
        const [],
        overrides: [
          firstTaskStoreProvider.overrideWithValue(
            MemoryFirstTaskStore([MemoryTasks().ownerKey]),
          ),
        ],
      );
      final l = tester.element(find.byType(CalendarScreen)).l10n;
      expect(find.text(l.todayAgenda), findsOneWidget);
      expect(
        find.descendant(of: emptyState(), matching: find.text(l.calendarEmpty)),
        findsOneWidget,
      );
      expect(find.text(l.rememberPrompt), findsNothing);
      expect(
        find.descendant(of: emptyState(), matching: find.byType(Icon)),
        findsNothing,
      );
      expect(find.text(l.calendarTrySaying), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'UX-702: when the tasks fail to load, the error keeps its icon tile',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final container = designContainer(
        regionalStore: MemoryRegionalStore(
          const RegionalPreferences(language: 'es'),
        ),
        tasks: _FailingTasks.new,
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(container: container, child: const MyApp()),
      );
      await tester.pumpAndSettle();
      final l = tester.element(find.byType(CalendarScreen)).l10n;
      final error = find.descendant(
        of: find.byType(CalendarScreen),
        matching: find.widgetWithText(EmptyState, l.loadTasksError),
      );
      expect(error, findsOneWidget);
      expect(
        find.descendant(
          of: error,
          matching: find.byIcon(Icons.event_available_outlined),
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'UX-702: EmptyState without an icon argument shows the calendar icon; with icon: null it shows no Icon but keeps its title and message',
    (tester) async {
      Future<void> pump(Widget state) => tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: Center(child: state)),
        ),
      );
      await pump(const EmptyState(title: 'Título', message: 'Mensaje'));
      expect(find.byIcon(Icons.event_available_outlined), findsOneWidget);
      expect(find.text('Título'), findsOneWidget);
      expect(find.text('Mensaje'), findsOneWidget);

      await pump(
        const EmptyState(title: 'Título', message: 'Mensaje', icon: null),
      );
      expect(find.byType(Icon), findsNothing);
      expect(find.text('Título'), findsOneWidget);
      expect(find.text('Mensaje'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  // ---- UX loop 2026-10-19-app, round 1 · P169 (UX-1404): an empty day is
  // said once ----

  /// Every line of text the empty state shows.
  List<String> emptyLines(WidgetTester tester) => [
    for (final text
        in find
            .descendant(of: emptyState(), matching: find.byType(Text))
            .evaluate())
      (text.widget as Text).data ?? '',
  ];

  testWidgets(
    'UX-1404: ES, 2x on 360x800, an empty day after the first run with no phone calendars shows only Nada previsto para este día. under Agenda de hoy, with no tile, above Añadir tarea',
    (tester) async {
      tester.view.padding = const FakeViewPadding(top: 24, bottom: 24);
      await openCalendar(
        tester,
        const [],
        size: const Size(360, 800),
        textScale: 2,
        overrides: [
          firstTaskStoreProvider.overrideWithValue(
            MemoryFirstTaskStore([MemoryTasks().ownerKey]),
          ),
        ],
      );
      final l = tester.element(find.byType(CalendarScreen)).l10n;
      final title = find.text(l.todayAgenda);
      expect(title, findsOneWidget);
      expect(emptyLines(tester), [l.calendarEmpty]);
      expect(
        find.descendant(of: emptyState(), matching: find.byType(Icon)),
        findsNothing,
      );
      expect(find.text(l.rememberPrompt), findsNothing);
      expect(find.text('Un momento de calma.'), findsNothing);
      // Nothing between the title and the agenda's one line.
      final line = tester.getRect(
        find.descendant(of: emptyState(), matching: find.text(l.calendarEmpty)),
      );
      expect(line.top, greaterThanOrEqualTo(tester.getRect(title).bottom));
      final actions = tester.getRect(
        find.descendant(
          of: find.byType(CalendarScreen),
          matching: find.byType(TaskActions),
        ),
      );
      expect(
        line.bottom,
        lessThanOrEqualTo(actions.top),
        reason:
            'the line ends ${line.bottom - actions.top} dp under Añadir tarea',
      );
      expect(line.top, greaterThanOrEqualTo(0));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'UX-1404: ES, phone calendars on, an empty day with events shows No hay tareas para este día. then the events line, and nothing else',
    (tester) async {
      final now = DateTime.now();
      final bridge = _FlakyCalendars()
        ..data = [
          DeviceCalendarEvent(
            id: '31',
            calendarId: workCalendar.id,
            title: 'Dentista',
            start: DateTime(now.year, now.month, now.day, 9),
            end: DateTime(now.year, now.month, now.day, 10),
            allDay: false,
          ),
        ];
      addTearDown(bridge.close);
      await openCalendar(
        tester,
        const [],
        overrides: [
          ...phoneCalendar(bridge),
          firstTaskStoreProvider.overrideWithValue(
            MemoryFirstTaskStore([MemoryTasks().ownerKey]),
          ),
        ],
      );
      final l = tester.element(find.byType(CalendarScreen)).l10n;
      expect(find.text(l.todayAgenda), findsOneWidget);
      expect(emptyLines(tester), [l.noScheduledTasks]);
      expect(
        find.descendant(of: emptyState(), matching: find.byType(Icon)),
        findsNothing,
      );
      final events = find.textContaining('Dentista · ');
      await reveal(tester, events);
      expect(events, findsOneWidget);
      expect(
        tester.getRect(find.text(l.noScheduledTasks)).bottom,
        lessThanOrEqualTo(tester.getRect(events).top),
        reason: 'the tasks line, then the event',
      );
      expect(find.text(l.calendarEmpty), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  // ---- UX loop 2026-10-19-app, round 1 · P175 (UX-1408, UX-1409, UX-1410,
  // UX-1412): the week strip at large text and for TalkBack ----

  /// Tuesday 20 October 2026 at 9:00, on the app's clock.
  final october20 = DateTime(2026, 10, 20, 9);
  final strip = find.byType(TableCalendar<Task>);
  Finder inStrip(Finder finder) => find.descendant(of: strip, matching: finder);
  final digits = RegExp(r'^\d{1,2}$');

  /// Every text the strip shows: day numbers and weekday names.
  List<Element> stripTexts(WidgetTester tester) =>
      inStrip(find.byType(Text)).evaluate().toList();

  /// The day cell (its pill plus margin) around the shown number [text].
  Rect cellOf(WidgetTester tester, Finder text) => tester.getRect(
    find.ancestor(of: text, matching: find.byType(AnimatedContainer)).first,
  );

  /// Every semantics node on screen, merged ones too.
  List<SemanticsData> allSemantics(WidgetTester tester) {
    final root = tester
        .binding
        .renderViews
        .first
        .owner!
        .semanticsOwner!
        .rootSemanticsNode!;
    final found = <SemanticsData>[];
    bool visit(SemanticsNode node) {
      found.add(node.getSemanticsData());
      node.visitChildren(visit);
      return true;
    }

    visit(root);
    return found;
  }

  for (final language in ['es', 'ca', 'en']) {
    testWidgets(
      'UX-1408 ($language, 2× on 360×800): no week-strip text is cut, day cells are at least 48 × 48 dp, and «20» sits whole inside its pill',
      (tester) async {
        await openCalendar(
          tester,
          const [],
          language: language,
          size: const Size(360, 800),
          textScale: 2,
          overrides: [calendarClockProvider.overrideWithValue(() => october20)],
        );
        final texts = stripTexts(tester);
        final numbers = [
          for (final element in texts)
            if (digits.hasMatch((element.widget as Text).data ?? '')) element,
        ];
        final names = [
          for (final element in texts)
            if (!digits.hasMatch((element.widget as Text).data ?? '')) element,
        ];
        expect(numbers, hasLength(7), reason: 'one week');
        expect(names, hasLength(7), reason: 'seven weekday names');
        // Weekday names: on one line, as wide as the word, inside the strip.
        for (final element in names) {
          final label = (element.widget as Text).data!;
          final paragraph = element.renderObject! as RenderParagraph;
          final whole = TextPainter(
            text: paragraph.text,
            textDirection: paragraph.textDirection,
            textScaler: paragraph.textScaler,
            locale: paragraph.locale,
            strutStyle: paragraph.strutStyle,
            textHeightBehavior: paragraph.textHeightBehavior,
          )..layout();
          expect(
            paragraph.size.height,
            moreOrLessEquals(whole.height, epsilon: 0.5),
            reason: '«$label» on one line',
          );
          expect(
            paragraph.size.width,
            greaterThanOrEqualTo(whole.width - 0.5),
            reason: '«$label» not clipped',
          );
          whole.dispose();
          final box = tester.getRect(find.byWidget(element.widget));
          expect(box.left, greaterThanOrEqualTo(0), reason: label);
          expect(box.right, lessThanOrEqualTo(360.5), reason: label);
        }
        final firstRow = tester.getRect(find.byWidget(numbers.first.widget));
        for (final element in names) {
          expect(
            tester.getRect(find.byWidget(element.widget)).bottom,
            lessThanOrEqualTo(
              cellOf(tester, find.byWidget(numbers.first.widget)).top + 0.5,
            ),
            reason: 'the names sit above the days (${firstRow.top})',
          );
        }
        // Day cells: at least 48 × 48, each number whole inside its pill.
        for (final element in numbers) {
          final label = (element.widget as Text).data!;
          final text = find.byWidget(element.widget);
          final cell = cellOf(tester, text);
          expect(cell.width, greaterThanOrEqualTo(48 - 0.01), reason: label);
          expect(cell.height, greaterThanOrEqualTo(48 - 0.01), reason: label);
          final pill = cell.deflate(4);
          final number = tester.getRect(text);
          expect(
            number.left,
            greaterThanOrEqualTo(pill.left - 0.5),
            reason: label,
          );
          expect(
            number.right,
            lessThanOrEqualTo(pill.right + 0.5),
            reason: label,
          );
          expect(
            number.top,
            greaterThanOrEqualTo(pill.top - 0.5),
            reason: label,
          );
          expect(
            number.bottom,
            lessThanOrEqualTo(pill.bottom + 0.5),
            reason: label,
          );
          final paragraph = element.renderObject! as RenderParagraph;
          expect(paragraph.didExceedMaxLines, isFalse, reason: label);
        }
        expect(numbers.map((e) => (e.widget as Text).data), contains('20'));
        expect(tester.takeException(), isNull, reason: 'no overflow');
      },
    );
  }

  testWidgets(
    'UX-1408: ES 1× on 360×800: the week strip shows the usual short weekday names, not the narrow ones',
    (tester) async {
      await openCalendar(
        tester,
        const [],
        size: const Size(360, 800),
        overrides: [calendarClockProvider.overrideWithValue(() => october20)],
      );
      for (var i = 0; i < 7; i++) {
        final name = DateFormat.E('es').format(DateTime(2026, 10, 19 + i));
        expect(inStrip(find.text(name)), findsOneWidget, reason: name);
      }
      expect(inStrip(find.text('X')), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  for (final theme in [ThemeMode.light, ThemeMode.dark]) {
    testWidgets(
      'UX-1409 (${theme.name}): the week of 26 Oct – 1 Nov draws «1» in the normal day colour, like the month’s own weekend day «31»',
      (tester) async {
        await openCalendar(
          tester,
          const [],
          theme: theme,
          size: const Size(360, 800),
          weekStart: 1,
          overrides: [
            calendarClockProvider.overrideWithValue(
              () => DateTime(2026, 10, 28, 9),
            ),
          ],
        );
        Color colour(String day) =>
            tester.widget<Text>(inStrip(find.text(day))).style!.color!;
        expect(inStrip(find.text('1')), findsOneWidget, reason: '1 Nov shows');
        expect(colour('1'), colour('31'), reason: 'both weekend days');
        expect(colour('1'), isNot(const Color(0xFFAEAEAE)));
        // A weekday of the month keeps its own, plain colour.
        expect(colour('30'), isNot(colour('31')));
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'UX-1410: TalkBack hears the chosen day as selected; today with 3 open tasks says «hoy · 3 tareas», a day with 1 open task «1 tarea»',
    (tester) async {
      final semantics = tester.ensureSemantics();
      await openCalendar(
        tester,
        [
          for (final (title, hour) in [
            ('Llamar al médico', 10),
            ('Comer con Ana', 13),
            ('Recoger a los niños', 17),
          ])
            Task(
              title: title,
              priority: 1,
              dueDate: DateTime(2026, 10, 20, hour),
            ),
          Task(
            title: 'Hecha',
            priority: 1,
            dueDate: DateTime(2026, 10, 20, 8),
            isCompleted: true,
          ),
          Task(
            title: 'Dentista',
            priority: 1,
            dueDate: DateTime(2026, 10, 22, 9),
          ),
        ],
        size: const Size(360, 800),
        overrides: [calendarClockProvider.overrideWithValue(() => october20)],
      );
      final l = tester.element(find.byType(CalendarScreen)).l10n;
      final todayValue = '${l.today.toLowerCase()} · ${l.dayTaskCount(3)}';
      expect(todayValue, 'hoy · 3 tareas');
      expect(l.dayTaskCount(1), '1 tarea');
      List<SemanticsData> withValue(String value) =>
          allSemantics(tester).where((d) => d.value == value).toList();

      final today = withValue(todayValue);
      expect(today, hasLength(1), reason: 'today is read once with its tasks');
      expect(today.single.flagsCollection.isSelected, ui.Tristate.isTrue);
      final thursday = withValue(l.dayTaskCount(1));
      expect(thursday, hasLength(1));
      expect(
        thursday.single.flagsCollection.isSelected,
        isNot(ui.Tristate.isTrue),
      );

      await tester.tap(inStrip(find.text('22')));
      await tester.pumpAndSettle();
      expect(
        withValue(l.dayTaskCount(1)).single.flagsCollection.isSelected,
        ui.Tristate.isTrue,
      );
      expect(
        withValue(todayValue).single.flagsCollection.isSelected,
        isNot(ui.Tristate.isTrue),
      );
      semantics.dispose();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('UX-1410: a long press on a day selects it, like a tap', (
    tester,
  ) async {
    await openCalendar(
      tester,
      const [],
      size: const Size(360, 800),
      overrides: [calendarClockProvider.overrideWithValue(() => october20)],
    );
    final thursday = DateTime(2026, 10, 22);
    final header = find.text(DateFormat.MMMMEEEEd('es').format(thursday));
    expect(header, findsNothing);
    await tester.longPress(inStrip(find.text('22')));
    await tester.pumpAndSettle();
    expect(header, findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'UX-1410: the arrows read «Semana anterior» / «Semana siguiente» in Semana and «Mes anterior» / «Mes siguiente» in Mes',
    (tester) async {
      await openCalendar(
        tester,
        const [],
        size: const Size(360, 800),
        overrides: [calendarClockProvider.overrideWithValue(() => october20)],
      );
      final l = tester.element(find.byType(CalendarScreen)).l10n;
      expect(
        [l.previousWeek, l.nextWeek, l.previousMonth, l.nextMonth],
        [
          'Semana anterior',
          'Semana siguiente',
          'Mes anterior',
          'Mes siguiente',
        ],
      );
      expect(find.byTooltip(l.previousWeek), findsOneWidget);
      expect(find.byTooltip(l.nextWeek), findsOneWidget);
      expect(find.byTooltip(l.previousMonth), findsNothing);
      await monthView(tester);
      expect(find.byTooltip(l.previousMonth), findsOneWidget);
      expect(find.byTooltip(l.nextMonth), findsOneWidget);
      expect(find.byTooltip(l.previousWeek), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'UX-1410 / UX-1412: in Mes the next month’s first days show and can be chosen; every cell shows its number',
    (tester) async {
      await openCalendar(
        tester,
        const [],
        size: const Size(360, 800),
        weekStart: 1,
        overrides: [calendarClockProvider.overrideWithValue(() => october20)],
      );
      await monthView(tester);
      final cells = inStrip(find.byType(AnimatedContainer)).evaluate().length;
      final numbers = [
        for (final element in stripTexts(tester))
          if (digits.hasMatch((element.widget as Text).data ?? '')) element,
      ];
      expect(cells, greaterThanOrEqualTo(35));
      expect(numbers, hasLength(cells), reason: 'no blank cell');
      // October 2026 ends on a Saturday: Sunday 1 November closes the grid.
      final ones = inStrip(find.text('1'));
      expect(ones, findsNWidgets(2), reason: '1 Oct and 1 Nov');
      await tester.tap(ones.last);
      await tester.pumpAndSettle();
      expect(
        find.text(DateFormat.MMMMEEEEd('es').format(DateTime(2026, 11, 1))),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'UX-1412: ES 1× on 360×800, in Mes, tapping a day with tasks shows Semana with that day chosen, and its first task is above «Añadir tarea»',
    (tester) async {
      await openCalendar(
        tester,
        [
          Task(
            title: 'Dentista',
            priority: 1,
            dueDate: DateTime(2026, 10, 23, 10),
          ),
        ],
        size: const Size(360, 800),
        overrides: [calendarClockProvider.overrideWithValue(() => october20)],
      );
      final l = tester.element(find.byType(CalendarScreen)).l10n;
      await monthView(tester);
      await tester.tap(inStrip(find.text('23')));
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('calendar-format')),
          matching: find.text(l.week),
        ),
        findsOneWidget,
        reason: 'back to Semana',
      );
      final numbers = [
        for (final element in stripTexts(tester))
          if (digits.hasMatch((element.widget as Text).data ?? '')) element,
      ];
      expect(numbers, hasLength(7), reason: 'one week');
      expect(
        find.text(DateFormat.MMMMEEEEd('es').format(DateTime(2026, 10, 23))),
        findsOneWidget,
      );
      final row = find.widgetWithText(TaskTile, 'Dentista');
      expect(row.hitTestable(), findsOneWidget);
      final add = find.descendant(
        of: find.byType(TaskActions),
        matching: find.text(l.addTask),
      );
      expect(
        tester.getRect(row).top,
        lessThan(tester.getRect(add).top),
        reason: 'the day’s first task shows above Añadir tarea',
      );
      expect(tester.takeException(), isNull);
    },
  );

  // ---- UX loop 2026-10-19-app, batch b2 round 2 · P201 (UX-1632): what
  // TalkBack hears for today counts the overdue tasks its agenda lists ----

  /// [own] open tasks on 20 October, one completed, and [overdue] open tasks
  /// from 15 October (outside the week shown).
  List<Task> todayWith({required int own, required int overdue}) => [
    for (var i = 0; i < own; i++)
      Task(
        id: 100 + i,
        title: 'Hoy $i',
        priority: 1,
        dueDate: DateTime(2026, 10, 20, 10 + i),
      ),
    Task(
      id: 90,
      title: 'Hecha',
      priority: 1,
      dueDate: DateTime(2026, 10, 20, 8),
      isCompleted: true,
    ),
    for (var i = 0; i < overdue; i++)
      Task(
        id: 200 + i,
        title: 'Atrasada $i',
        priority: 1,
        dueDate: DateTime(2026, 10, 15, 9 + i),
      ),
    Task(
      id: 300,
      title: 'Dentista',
      priority: 1,
      dueDate: DateTime(2026, 10, 22, 9),
    ),
  ];

  /// The values TalkBack reads for the strip's days, today's included.
  List<String> dayValues(WidgetTester tester) => [
    for (final data in allSemantics(tester))
      if (data.value.isNotEmpty) data.value,
  ];

  for (final overdue in [0, 1]) {
    testWidgets(
      'UX-1632 (es, 1× on 360×800, today selected, $overdue overdue): today’s value names the same number as the count line’s pending tasks',
      (tester) async {
        final semantics = tester.ensureSemantics();
        await openCalendar(
          tester,
          todayWith(own: 3, overdue: overdue),
          size: const Size(360, 800),
          overrides: [calendarClockProvider.overrideWithValue(() => october20)],
        );
        final l = tester.element(find.byType(CalendarScreen)).l10n;
        final pending = 3 + overdue;
        expect(find.text(l.agendaCounts(pending, 1)), findsOneWidget);
        final todayValue =
            '${l.today.toLowerCase()} · ${l.dayTaskCount(pending)}';
        expect(
          dayValues(tester).where((v) => v == todayValue),
          hasLength(1),
          reason: 'values read: ${dayValues(tester)}',
        );
        semantics.dispose();
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'UX-1632: the month fixture’s numbers: with 9 open tasks today, one completed and one overdue, today reads «hoy · 10 tareas» and the count line «10 pendientes · 1 completada»',
    (tester) async {
      final semantics = tester.ensureSemantics();
      await openCalendar(
        tester,
        todayWith(own: 9, overdue: 1),
        size: const Size(360, 800),
        overrides: [calendarClockProvider.overrideWithValue(() => october20)],
      );
      expect(find.text('10\u00a0pendientes · 1\u00a0completada'), findsOneWidget);
      expect(dayValues(tester), contains('hoy · 10 tareas'));
      expect(dayValues(tester), isNot(contains('hoy · 9 tareas')));
      semantics.dispose();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'UX-1632: with another day selected, today’s value still counts the overdue task and reads as when today is selected',
    (tester) async {
      final semantics = tester.ensureSemantics();
      await openCalendar(
        tester,
        todayWith(own: 3, overdue: 1),
        size: const Size(360, 800),
        overrides: [calendarClockProvider.overrideWithValue(() => october20)],
      );
      final l = tester.element(find.byType(CalendarScreen)).l10n;
      final todayValue = '${l.today.toLowerCase()} · ${l.dayTaskCount(4)}';
      expect(dayValues(tester), contains(todayValue));
      await tester.tap(inStrip(find.text('22')));
      await tester.pumpAndSettle();
      // Thursday's agenda now shows: today's count line is gone.
      expect(find.text(l.agendaCounts(4, 1)), findsNothing);
      expect(
        dayValues(tester).where((v) => v == todayValue),
        hasLength(1),
        reason: 'values read: ${dayValues(tester)}',
      );
      expect(dayValues(tester), contains(l.dayTaskCount(1)));
      semantics.dispose();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'UX-1632: today with no open task of its own and one overdue reads «hoy · 1 tarea»; another day with one open task still reads «1 tarea»',
    (tester) async {
      final semantics = tester.ensureSemantics();
      await openCalendar(
        tester,
        todayWith(own: 0, overdue: 1),
        size: const Size(360, 800),
        overrides: [calendarClockProvider.overrideWithValue(() => october20)],
      );
      final values = dayValues(tester);
      expect(values, contains('hoy · 1 tarea'), reason: '$values');
      expect(values, isNot(contains('hoy')), reason: '$values');
      expect(
        values.where((v) => v == '1 tarea'),
        hasLength(1),
        reason: 'Thursday: $values',
      );
      semantics.dispose();
      expect(tester.takeException(), isNull);
    },
  );

  /// The dots under the strip's days: 4 dp circles.
  Finder dots() => inStrip(
    find.byWidgetPredicate(
      (w) =>
          w is Container &&
          w.decoration is BoxDecoration &&
          (w.decoration! as BoxDecoration).shape == BoxShape.circle &&
          w.constraints?.maxWidth == 4,
    ),
  );

  /// The dots under the day whose number is [number].
  int dotsUnder(WidgetTester tester, String number) {
    final cell = cellOf(tester, inStrip(find.text(number)));
    return [
      for (final dot in dots().evaluate())
        if ((tester.getCenter(find.byWidget(dot.widget)).dx - cell.center.dx)
                .abs() <
            cell.width / 2)
          dot,
    ].length;
  }

  for (final (own, expected) in [(2, 2), (4, 3)]) {
    testWidgets(
      'UX-1632: the dots under today are still one per open task of its own ($own → $expected), whatever is overdue',
      (tester) async {
        await openCalendar(
          tester,
          todayWith(own: own, overdue: 1),
          size: const Size(360, 800),
          overrides: [calendarClockProvider.overrideWithValue(() => october20)],
        );
        expect(dotsUnder(tester, '20'), expected);
        expect(dotsUnder(tester, '22'), 1);
        expect(dots(), findsNWidgets(expected + 1));
        expect(tester.takeException(), isNull);
      },
    );
  }

  // ---- 2026-10-28-app · P268 (UX-2301): ticks and moves never wait on the
  // server; the sync runs behind ----

  group('P268 · ticks and moves show at once', () {
    // Three of today's tasks still open, so no tick here is the day's last
    // one. The date sheet's Mañana counts from the phone's own clock.
    final now = DateTime.now();
    DateTime today(int hour) => DateTime(now.year, now.month, now.day, hour);
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    List<Task> day() => [
      Task(
        id: 1,
        title: 'Comprar pan',
        priority: 1,
        dueDate: today(9),
        hasTime: true,
      ),
      Task(
        id: 2,
        title: 'Llamar a Ana',
        priority: 1,
        dueDate: today(11),
        hasTime: true,
      ),
      Task(
        id: 3,
        title: 'Regar las plantas',
        priority: 1,
        dueDate: today(13),
        hasTime: true,
      ),
    ];

    /// Calendar in Spanish at 1× on 360×800, with the real task list over
    /// tasks on the phone whose cloud sync never completes.
    Future<NeverSyncingTasks> openHanging(WidgetTester tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final cloud = NeverSyncingTasks(day());
      final container = designContainer(
        regionalStore: MemoryRegionalStore(
          const RegionalPreferences(language: 'es'),
        ),
        tasks: () => TaskNotifier(cloud),
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(container: container, child: const MyApp()),
      );
      await tester.pumpAndSettle();
      expect(cloud.syncs, greaterThan(0), reason: 'a sync is under way');
      expect(cloud.finished, 0, reason: 'and it never finishes');
      return cloud;
    }

    Finder row(String title) => find.widgetWithText(TaskTile, title);
    Finder circle(String title) =>
        find.descendant(of: row(title), matching: find.byType(Checkbox));
    bool? checked(WidgetTester tester, String title) =>
        tester.widget<Checkbox>(circle(title)).value;

    /// Two frames: what a tap shows "at once".
    Future<void> twoFrames(WidgetTester tester) async {
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
    }

    testWidgets(
      'UX-2301: with a sync that never completes, ticking a Calendar row checks it and says Tarea completada · Deshacer within two frames; Deshacer reopens it at once',
      (tester) async {
        platform.setMockMethodCallHandler(timeoutChannel, (_) async => 10000);
        final cloud = await openHanging(tester);
        final l = tester.element(find.byType(CalendarScreen)).l10n;
        await tester.ensureVisible(row('Comprar pan'));
        await tester.pumpAndSettle();
        expect(checked(tester, 'Comprar pan'), isFalse);

        await tester.tap(circle('Comprar pan'));
        await twoFrames(tester);
        expect(checked(tester, 'Comprar pan'), isTrue);
        expect(find.text(l.taskCompleted), findsOneWidget);
        expect(
          find.descendant(
            of: find.byType(SnackBar),
            matching: find.text(l.undo),
          ),
          findsOneWidget,
        );
        expect(cloud.byId(1)!.isCompleted, isTrue);
        expect(cloud.finished, 0);

        // Let the message slide in, then undo: the row reopens at once.
        await tester.pump(const Duration(milliseconds: 400));
        await tester.tap(find.text(l.undo));
        await twoFrames(tester);
        expect(checked(tester, 'Comprar pan'), isFalse);
        expect(cloud.byId(1)!.isCompleted, isFalse);
        expect(cloud.finished, 0);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'UX-2301: with the same never-ending sync, a second row ticked straight after the first checks at once too, and both are written',
      (tester) async {
        platform.setMockMethodCallHandler(timeoutChannel, (_) async => 10000);
        final cloud = await openHanging(tester);
        final l = tester.element(find.byType(CalendarScreen)).l10n;
        await tester.ensureVisible(row('Llamar a Ana'));
        await tester.pumpAndSettle();
        expect(circle('Comprar pan').hitTestable(), findsOneWidget);
        expect(circle('Llamar a Ana').hitTestable(), findsOneWidget);

        await tester.tap(circle('Comprar pan'));
        await tester.pump();
        expect(circle('Llamar a Ana').hitTestable(), findsOneWidget);
        await tester.tap(circle('Llamar a Ana'));
        await twoFrames(tester);
        expect(checked(tester, 'Comprar pan'), isTrue);
        expect(checked(tester, 'Llamar a Ana'), isTrue);
        expect(checked(tester, 'Regar las plantas'), isFalse);
        expect(find.text(l.taskCompleted), findsOneWidget);
        expect(cloud.byId(1)!.isCompleted, isTrue);
        expect(cloud.byId(2)!.isCompleted, isTrue);
        expect(cloud.finished, 0);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'UX-2301: with the same never-ending sync, Cambiar fecha › Mañana on a row says Movida al … as the sheet closes, and the row leaves the day',
      (tester) async {
        platform.setMockMethodCallHandler(timeoutChannel, (_) async => 10000);
        final cloud = await openHanging(tester);
        final calendar = tester.element(find.byType(CalendarScreen));
        final l = calendar.l10n;
        await tester.ensureVisible(row('Comprar pan'));
        await tester.pumpAndSettle();
        // A row's long press is its Cambiar fecha.
        await tester.longPress(row('Comprar pan'));
        await tester.pumpAndSettle();
        expect(find.byType(BottomSheet), findsOneWidget);
        expect(find.text(l.rescheduleTask), findsOneWidget);

        await tester.tap(find.widgetWithText(ChoiceChip, l.tomorrow));
        final moved = l.movedOccurrenceDate(calendar.weekdayDate(tomorrow));
        await twoFrames(tester);
        expect(find.text(moved), findsOneWidget);
        expect(
          find.descendant(
            of: find.byType(SnackBar),
            matching: find.text(l.undo),
          ),
          findsOneWidget,
        );
        await tester.pumpAndSettle();
        expect(find.byType(BottomSheet), findsNothing);
        expect(find.text(moved), findsOneWidget);
        expect(row('Comprar pan'), findsNothing, reason: 'it left today');
        expect(row('Llamar a Ana'), findsOneWidget);
        expect(Task.day(cloud.byId(1)!.dueDate!), tomorrow);
        expect(cloud.finished, 0);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'UX-2301: with the same never-ending sync, a swipe right on a row springs back at once, checked',
      (tester) async {
        platform.setMockMethodCallHandler(timeoutChannel, (_) async => 10000);
        final cloud = await openHanging(tester);
        final l = tester.element(find.byType(CalendarScreen)).l10n;
        await tester.ensureVisible(row('Comprar pan'));
        await tester.pumpAndSettle();
        // The row's face: what slides under the finger.
        final face = find
            .descendant(
              of: find.descendant(
                of: row('Comprar pan'),
                matching: find.byType(Dismissible),
              ),
              matching: find.byType(Material),
            )
            .first;
        final rest = tester.getRect(face);

        await tester.drag(row('Comprar pan'), const Offset(300, 0));
        // Known and older than this round: while dragging, the swipe
        // background's label can overflow a one-line row by a few pixels.
        final swipe = tester.takeException();
        expect(
          swipe == null || '$swipe'.contains('RenderFlex overflowed'),
          isTrue,
          reason: '$swipe',
        );
        // The row first slides the rest of the way out, Dismissible's own
        // 200 ms; then the tick shows within two frames, with no wait for a
        // sync.
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));
        await twoFrames(tester);
        expect(checked(tester, 'Comprar pan'), isTrue);
        expect(find.text(l.taskCompleted), findsOneWidget);
        // And it springs back home in Dismissible's own 200 ms.
        await tester.pump(const Duration(milliseconds: 200));
        await tester.pump(const Duration(milliseconds: 16));
        expect(tester.getRect(face).left, moreOrLessEquals(rest.left));
        expect(checked(tester, 'Comprar pan'), isTrue);
        expect(cloud.byId(1)!.isCompleted, isTrue);
        expect(cloud.finished, 0);
        final after = tester.takeException();
        expect(
          after == null || '$after'.contains('RenderFlex overflowed'),
          isTrue,
          reason: '$after',
        );
      },
    );
  });

  group('P276 · «Sin fecha» means no day and no deadline', () {
    // A Thursday at least two days away on the phone's own clock, and the
    // app's "today" the Tuesday before it, so both sit in one week strip
    // and the deadline is never past.
    DateTime thursday() {
      final now = DateTime.now();
      var day = DateTime(now.year, now.month, now.day + 2);
      while (day.weekday != DateTime.thursday) {
        day = DateTime(day.year, day.month, day.day + 1);
      }
      return day;
    }

    Finder row(String title) => find.widgetWithText(TaskTile, title);
    Finder inCalendar(Finder finder) =>
        find.descendant(of: find.byType(CalendarScreen), matching: finder);
    Finder sinFechaPage() => find.byWidgetPredicate(
      (widget) => widget is HomeScreen && !widget.isRoot,
    );

    testWidgets(
      'UX-2308: a deadline-only task (Thursday at 17:00) isn’t counted in «Sin fecha · N» on today or Thursday, isn’t on the Sin fecha page or under Tareas’ «Sin fecha» chip, and shows on Thursday and in Tareas; a task with neither a day nor a deadline is still counted and listed',
      (tester) async {
        final day = thursday();
        final tuesday = DateTime(day.year, day.month, day.day - 2, 10);
        await openCalendar(
          tester,
          [
            Task(
              id: 1,
              title: 'Terminar el diseño',
              priority: 1,
              deadline: DateTime(day.year, day.month, day.day, 17),
            ),
            Task(id: 2, title: 'Ordenar el trastero', priority: 1),
          ],
          overrides: [calendarClockProvider.overrideWithValue(() => tuesday)],
        );
        final l = tester.element(find.byType(CalendarScreen)).l10n;
        final count = inCalendar(find.byKey(const ValueKey('calendar-inbox')));

        // Today: one task without a day or a deadline.
        await reveal(tester, count);
        expect(
          find.descendant(of: count, matching: find.text(l.inboxCount(1))),
          findsOneWidget,
        );
        expect(inCalendar(find.text(l.inboxCount(2))), findsNothing);

        // Thursday: the deadline's row, and the same count.
        await tester.tap(dayCell(day));
        await tester.pumpAndSettle();
        expect(
          find.text(DateFormat.MMMMEEEEd('es').format(day)),
          findsOneWidget,
        );
        expect(inCalendar(row('Terminar el diseño')), findsOneWidget);
        await reveal(tester, count);
        expect(
          find.descendant(of: count, matching: find.text(l.inboxCount(1))),
          findsOneWidget,
        );
        expect(inCalendar(find.text(l.inboxCount(2))), findsNothing);

        // The page «Sin fecha · 1» opens lists only the undated task.
        await tester.tap(count);
        await tester.pumpAndSettle();
        expect(sinFechaPage(), findsOneWidget);
        expect(
          find.descendant(
            of: find.descendant(
              of: sinFechaPage(),
              matching: find.byType(AppBar),
            ),
            matching: find.text(l.inbox),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: sinFechaPage(),
            matching: row('Ordenar el trastero'),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: sinFechaPage(),
            matching: row('Terminar el diseño'),
          ),
          findsNothing,
        );
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(sinFechaPage(), findsNothing);

        // Tareas lists both; its «Sin fecha» chip only the undated one.
        await tester.tap(
          find.descendant(
            of: find.byType(NavigationBar),
            matching: find.text(l.tasks),
          ),
        );
        await tester.pumpAndSettle();
        expect(row('Terminar el diseño').hitTestable(), findsOneWidget);
        expect(row('Ordenar el trastero').hitTestable(), findsOneWidget);
        final chip = find.widgetWithText(FilterChip, l.inbox);
        await tester.ensureVisible(chip);
        await tester.pumpAndSettle();
        await tester.tap(chip);
        await tester.pumpAndSettle();
        expect(tester.widget<FilterChip>(chip).selected, isTrue);
        expect(row('Ordenar el trastero').hitTestable(), findsOneWidget);
        expect(row('Terminar el diseño'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'UX-2308: with only a deadline-only task, Calendar shows no «Sin fecha» row on any day, and the Sin fecha page doesn’t list it',
      (tester) async {
        final day = thursday();
        final tuesday = DateTime(day.year, day.month, day.day - 2, 10);
        await openCalendar(
          tester,
          [
            Task(
              id: 1,
              title: 'Terminar el diseño',
              priority: 1,
              deadline: DateTime(day.year, day.month, day.day, 17),
            ),
          ],
          overrides: [calendarClockProvider.overrideWithValue(() => tuesday)],
        );
        final l = tester.element(find.byType(CalendarScreen)).l10n;
        final count = inCalendar(find.byKey(const ValueKey('calendar-inbox')));
        await scrollAgendaToEnd(tester);
        expect(count, findsNothing);
        expect(inCalendar(find.text(l.inboxCount(1))), findsNothing);
        await tester.tap(dayCell(day));
        await tester.pumpAndSettle();
        expect(inCalendar(row('Terminar el diseño')), findsOneWidget);
        await scrollAgendaToEnd(tester);
        expect(count, findsNothing);
        expect(inCalendar(find.text(l.inboxCount(1))), findsNothing);

        unawaited(
          Navigator.of(
            tester.element(find.byType(CalendarScreen)),
          ).pushNamed('/inbox'),
        );
        await tester.pumpAndSettle();
        expect(sinFechaPage(), findsOneWidget);
        expect(
          find.descendant(of: sinFechaPage(), matching: find.byType(TaskTile)),
          findsNothing,
        );
        expect(tester.takeException(), isNull);
      },
    );
  });

  group('P269 · Today lists its own tasks first, ticked rows, the day’s last tick', () {
    // Today, early on the app's clock: none of today's timed tasks has
    // passed, and yesterday's and older ones are overdue.
    final now = DateTime.now();
    final morning = DateTime(now.year, now.month, now.day, 8);
    DateTime today(int hour) => DateTime(now.year, now.month, now.day, hour);
    DateTime daysAgo(int days) =>
        DateTime(now.year, now.month, now.day - days, 10);
    final clock = calendarClockProvider.overrideWithValue(() => morning);

    Finder inCalendar(Finder finder) =>
        find.descendant(of: find.byType(CalendarScreen), matching: finder);
    Finder row(String title) => inCalendar(find.widgetWithText(TaskTile, title));
    Finder circleIn(Finder row) =>
        find.descendant(of: row, matching: find.byType(Checkbox));
    Finder circle(String title) => circleIn(row(title));
    bool? ticked(WidgetTester tester, Finder row) =>
        tester.widget<Checkbox>(circleIn(row)).value;
    bool struck(WidgetTester tester, Finder row, String title) =>
        tester
            .widget<Text>(find.descendant(of: row, matching: find.text(title)))
            .style
            ?.decoration ==
        TextDecoration.lineThrough;

    Future<void> tick(WidgetTester tester, Finder circle) async {
      await tester.ensureVisible(circle);
      await tester.pumpAndSettle();
      await tester.tap(circle);
      await tester.pumpAndSettle();
    }

    /// Lets the message close: the phone gives no timeout here, so the
    /// app's own few seconds.
    Future<void> waitOutMessage(WidgetTester tester) async {
      await tester.pump(const Duration(seconds: 12));
      await tester.pumpAndSettle();
      expect(find.byType(SnackBar), findsNothing);
    }

    Future<void> tab(WidgetTester tester, String label) async {
      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text(label),
        ),
      );
      await tester.pumpAndSettle();
    }

    /// The swipe background's label can overflow a one-line row by a few
    /// pixels while dragging: known and older than this round.
    void allowSwipeOverflow(WidgetTester tester) {
      final error = tester.takeException();
      expect(
        error == null || '$error'.contains('RenderFlex overflowed'),
        isTrue,
        reason: '$error',
      );
    }

    testWidgets(
      'UX-2302: on today with three overdue tasks and two of today’s, ES 1× on 360×800, today’s two rows come first, in view without scrolling, and before «Atrasadas · 3» in TalkBack’s order',
      (tester) async {
        final semantics = tester.ensureSemantics();
        await openCalendar(
          tester,
          [
            Task(id: 1, title: 'Pagar el recibo', priority: 1, dueDate: daysAgo(3)),
            Task(id: 2, title: 'Comprar pan', priority: 1, dueDate: daysAgo(2)),
            Task(id: 3, title: 'Regar las plantas', priority: 1, dueDate: daysAgo(1)),
            Task(id: 4, title: 'Llamar a mamá', priority: 1, dueDate: today(10), hasTime: true),
            Task(id: 5, title: 'Ir al médico', priority: 1, dueDate: today(18), hasTime: true),
          ],
          size: const Size(360, 800),
          overrides: [clock],
        );
        final l = tester.element(find.byType(CalendarScreen)).l10n;
        expect(l.localeName, 'es');
        final heading = inCalendar(find.text(l.overdueCount(3)));
        expect(heading, findsOneWidget);
        expect(find.text(l.agendaCounts(5, 0)), findsOneWidget);

        // Without scrolling: both of today's rows whole between the top of
        // the agenda and «Añadir tarea».
        final view = tester.getRect(agenda());
        final actions = tester.getRect(
          inCalendar(find.byType(TaskActions)),
        );
        for (final title in ['Llamar a mamá', 'Ir al médico']) {
          expect(row(title), findsOneWidget, reason: title);
          final rect = tester.getRect(row(title));
          expect(rect.top, greaterThanOrEqualTo(view.top), reason: title);
          expect(rect.bottom, lessThanOrEqualTo(actions.top), reason: title);
          expect(
            tester.getTopLeft(row(title)).dy,
            lessThan(tester.getTopLeft(heading).dy),
            reason: '$title comes before «Atrasadas · 3»',
          );
        }
        expect(
          tester.getTopLeft(row('Llamar a mamá')).dy,
          lessThan(tester.getTopLeft(row('Ir al médico')).dy),
        );

        // TalkBack's order follows the screen's.
        final order = [
          for (final node in tester.semantics.simulatedAccessibilityTraversal())
            node.label,
        ];
        int at(String text) => order.indexWhere((label) => label.contains(text));
        expect(at('Llamar a mamá'), isNonNegative, reason: '$order');
        expect(at('Ir al médico'), greaterThan(at('Llamar a mamá')));
        expect(at(l.overdueCount(3)), greaterThan(at('Ir al médico')));
        await reveal(tester, row('Regar las plantas'));
        expect(row('Pagar el recibo'), findsOneWidget);
        expect(tester.takeException(), isNull);
        semantics.dispose();
      },
    );

    testWidgets(
      'Owner 2026-11-14: an overdue row ticked on today shows struck through under «Atrasada · 1», its circle reading «Reabrir», then leaves Today with its heading; today’s own ticked row stays',
      (tester) async {
        final semantics = tester.ensureSemantics();
        final container = await openCalendar(
          tester,
          [
            Task(id: 1, title: 'Comprar pan', priority: 1, dueDate: daysAgo(2)),
            Task(
              id: 2,
              title: 'Llamar a mamá',
              priority: 1,
              dueDate: today(18),
              hasTime: true,
            ),
            Task(
              id: 3,
              title: 'Ir al médico',
              priority: 1,
              dueDate: today(19),
              hasTime: true,
            ),
          ],
          size: const Size(360, 800),
          overrides: [clock],
        );
        final l = tester.element(find.byType(CalendarScreen)).l10n;
        final heading = inCalendar(find.text(l.overdueCount(1)));
        final overdue = row('Comprar pan');
        expect(heading, findsOneWidget);
        final before = tester.getRect(overdue);

        await tick(tester, circle('Comprar pan'));
        expect(
          container
              .read(taskProvider)
              .requireValue
              .firstWhere((task) => task.id == 1)
              .isCompleted,
          isTrue,
        );
        // For a moment it's still there, where it was, struck through.
        expect(heading, findsOneWidget);
        expect(overdue, findsOneWidget);
        expect(tester.getRect(overdue).top, moreOrLessEquals(before.top));
        expect(ticked(tester, overdue), isTrue);
        expect(struck(tester, overdue, 'Comprar pan'), isTrue);
        expect(
          tester.getSemantics(circle('Comprar pan')).label,
          contains(l.reopenNamedTask('Comprar pan')),
        );
        expect(find.text(l.agendaCounts(2, 1)), findsOneWidget);

        // Then it leaves Today, and its heading with it, as it was the last.
        await tester.pump(const Duration(seconds: 1));
        await tester.pumpAndSettle();
        expect(overdue, findsNothing);
        expect(heading, findsNothing);
        expect(inCalendar(find.textContaining('Atrasada')), findsNothing);
        expect(row('Llamar a mamá'), findsOneWidget);
        expect(find.text(l.agendaCounts(2, 0)), findsOneWidget);

        // Today's own task, ticked, stays on its day struck through.
        await tick(tester, circle('Llamar a mamá'));
        await tester.pump(const Duration(seconds: 2));
        await tester.pumpAndSettle();
        expect(row('Llamar a mamá'), findsOneWidget);
        expect(struck(tester, row('Llamar a mamá'), 'Llamar a mamá'), isTrue);
        expect(find.text(l.agendaCounts(1, 1)), findsOneWidget);

        expect(tester.takeException(), isNull);
        semantics.dispose();
      },
    );

    testWidgets(
      'Owner 2026-11-14: Deshacer while the ticked overdue row is leaving, or after it left, brings it back open; ticked again, it leaves again',
      (tester) async {
        await openCalendar(
          tester,
          [
            Task(id: 1, title: 'Comprar pan', priority: 1, dueDate: daysAgo(1)),
            Task(
              id: 2,
              title: 'Llamar a mamá',
              priority: 1,
              dueDate: today(18),
              hasTime: true,
            ),
          ],
          size: const Size(360, 800),
          overrides: [clock],
        );
        final l = tester.element(find.byType(CalendarScreen)).l10n;
        final overdue = row('Comprar pan');

        // Deshacer before it leaves: it stays, open.
        await tick(tester, circle('Comprar pan'));
        await tester.tap(find.text(l.undo));
        await tester.pumpAndSettle();
        await tester.pump(const Duration(seconds: 2));
        await tester.pumpAndSettle();
        expect(overdue, findsOneWidget);
        expect(ticked(tester, overdue), isFalse);
        await waitOutMessage(tester);

        // Deshacer after it left: back, open.
        await tick(tester, circle('Comprar pan'));
        await tester.pump(const Duration(seconds: 1));
        await tester.pumpAndSettle();
        expect(overdue, findsNothing);
        await tester.tap(find.text(l.undo));
        await tester.pumpAndSettle();
        expect(overdue, findsOneWidget);
        expect(ticked(tester, overdue), isFalse);
        expect(inCalendar(find.text(l.overdueCount(1))), findsOneWidget);
        await waitOutMessage(tester);

        // Ticked again: it leaves again.
        await tick(tester, circle('Comprar pan'));
        expect(overdue, findsOneWidget);
        await tester.pump(const Duration(seconds: 1));
        await tester.pumpAndSettle();
        expect(overdue, findsNothing);
        expect(row('Llamar a mamá'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'UX-2304: a ticked overdue row goes once another screen has covered Calendar',
      (tester) async {
        await openCalendar(
          tester,
          [
            Task(id: 1, title: 'Comprar pan', priority: 1, dueDate: daysAgo(1)),
            Task(id: 2, title: 'Llamar a mamá', priority: 1, dueDate: today(18), hasTime: true),
          ],
          size: const Size(360, 800),
          overrides: [clock],
        );
        final l = tester.element(find.byType(CalendarScreen)).l10n;
        await tick(tester, circle('Comprar pan'));
        expect(row('Comprar pan'), findsOneWidget);
        expect(inCalendar(find.text(l.overdueCount(1))), findsOneWidget);
        unawaited(
          tester
              .state<NavigatorState>(find.byType(Navigator))
              .pushNamed('/completedTasks'),
        );
        await tester.pumpAndSettle();
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(find.byType(CompletedTasksScreen), findsNothing);
        expect(row('Comprar pan'), findsNothing);
        expect(inCalendar(find.textContaining('Atrasada')), findsNothing);
        expect(row('Llamar a mamá'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'WD34, owner 2026-11-14: a today with only overdue tasks: the last tick says «Todo listo. Respira.» with the row struck through, then the rows have left Today',
      (tester) async {
        await openCalendar(
          tester,
          [
            Task(id: 1, title: 'Comprar pan', priority: 1, dueDate: daysAgo(2)),
            Task(
              id: 2,
              title: 'Regar las plantas',
              priority: 1,
              dueDate: daysAgo(1),
            ),
          ],
          size: const Size(360, 800),
          overrides: [clock],
        );
        final l = tester.element(find.byType(CalendarScreen)).l10n;
        expect(inCalendar(find.text(l.overdueCount(2))), findsOneWidget);

        // One overdue task still open: the usual line.
        await tick(tester, circle('Comprar pan'));
        expect(find.text(l.taskCompleted), findsOneWidget);
        expect(find.text(l.dayAllClear), findsNothing);
        await waitOutMessage(tester);
        expect(row('Comprar pan'), findsNothing);
        expect(inCalendar(find.text(l.overdueCount(1))), findsOneWidget);

        // The last one: the day is clear.
        await tick(tester, circle('Regar las plantas'));
        expect(find.text(l.dayAllClear), findsOneWidget);
        expect(find.text(l.taskCompleted), findsNothing);
        expect(find.text(l.undo), findsOneWidget);
        expect(row('Regar las plantas'), findsOneWidget);
        expect(ticked(tester, row('Regar las plantas')), isTrue);
        expect(
          struck(tester, row('Regar las plantas'), 'Regar las plantas'),
          isTrue,
        );

        await waitOutMessage(tester);
        expect(row('Regar las plantas'), findsNothing);
        expect(inCalendar(find.textContaining('Atrasada')), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'UX-2304: on Completadas a row reopened there stays in place, unticked; after leaving the page and coming back it’s gone',
      (tester) async {
        await openCalendar(
          tester,
          [
            Task(id: 1, title: 'Ayer', priority: 1, isCompleted: true, dueDate: daysAgo(1)),
            Task(id: 2, title: 'Hace dos días', priority: 1, isCompleted: true, dueDate: daysAgo(2)),
            Task(id: 3, title: 'Hace tres días', priority: 1, isCompleted: true, dueDate: daysAgo(3)),
          ],
          size: const Size(360, 800),
          overrides: [clock],
        );
        final l = tester.element(find.byType(CalendarScreen)).l10n;
        final navigator = tester.state<NavigatorState>(find.byType(Navigator));
        unawaited(navigator.pushNamed('/completedTasks'));
        await tester.pumpAndSettle();
        Finder done(String title) => find.descendant(
          of: find.byType(CompletedTasksScreen),
          matching: find.widgetWithText(TaskTile, title),
        );
        final before = {
          for (final title in ['Ayer', 'Hace dos días', 'Hace tres días'])
            title: tester.getRect(done(title)).top,
        };

        await tick(tester, circleIn(done('Hace dos días')));
        expect(find.text(l.taskReopened), findsOneWidget);
        for (final title in before.keys) {
          expect(done(title), findsOneWidget, reason: title);
          expect(
            tester.getRect(done(title)).top,
            moreOrLessEquals(before[title]!),
            reason: '$title stays where it was',
          );
        }
        expect(ticked(tester, done('Hace dos días')), isFalse);
        expect(struck(tester, done('Hace dos días'), 'Hace dos días'), isFalse);
        expect(ticked(tester, done('Ayer')), isTrue);
        await waitOutMessage(tester);
        expect(done('Hace dos días'), findsOneWidget);

        // Left and opened again: the reopened row is gone.
        navigator.pop();
        await tester.pumpAndSettle();
        expect(find.byType(CompletedTasksScreen), findsNothing);
        unawaited(navigator.pushNamed('/completedTasks'));
        await tester.pumpAndSettle();
        expect(done('Hace dos días'), findsNothing);
        expect(done('Ayer'), findsOneWidget);
        expect(done('Hace tres días'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    // WD34, in each language and at 1× and 2× on 360×800.
    for (final language in ['es', 'en', 'ca']) {
      for (final scale in [1.0, 2.0]) {
        testWidgets(
          'WD34 (UX-2303) in $language at ${scale.toInt()}×: of two open tasks, the first tick says «Tarea completada»; the last, by its circle and by a swipe right, says «Todo listo. Respira.» with Deshacer, which reopens it',
          (tester) async {
            final container = await openCalendar(
              tester,
              [
                Task(id: 1, title: 'Comprar pan', priority: 1, dueDate: today(10), hasTime: true),
                Task(id: 2, title: 'Llamar a mamá', priority: 1, dueDate: today(18), hasTime: true),
              ],
              language: language,
              size: const Size(360, 800),
              textScale: scale,
              overrides: [clock],
            );
            final l = tester.element(find.byType(CalendarScreen)).l10n;
            expect(l.localeName, language);
            // The website demo's own words.
            expect(l.dayAllClear, switch (language) {
              'es' => 'Todo listo. Respira.',
              'en' => 'All clear. Take a breath.',
              _ => 'Tot fet. Respira.',
            });
            bool done(int id) => container
                .read(taskProvider)
                .requireValue
                .firstWhere((task) => task.id == id)
                .isCompleted;
            void expectWhole(String message) {
              final text = find.text(message);
              expect(text, findsOneWidget);
              final rect = tester.getRect(text);
              final bar = tester.getRect(find.byType(SnackBar));
              expect(rect.left, greaterThanOrEqualTo(bar.left));
              expect(rect.right, lessThanOrEqualTo(bar.right));
              expect(rect.bottom, lessThanOrEqualTo(800));
              expect(
                tester.renderObject<RenderParagraph>(text).didExceedMaxLines,
                isFalse,
              );
            }

            // The first: one task still open.
            await tick(tester, circle('Comprar pan'));
            expect(done(1), isTrue);
            expectWhole(l.taskCompleted);
            expect(find.text(l.dayAllClear), findsNothing);
            await waitOutMessage(tester);

            // The last, by its circle.
            await tick(tester, circle('Llamar a mamá'));
            expect(done(2), isTrue);
            expectWhole(l.dayAllClear);
            expect(find.text(l.taskCompleted), findsNothing);
            expect(find.text(l.undo).hitTestable(), findsOneWidget);
            await tester.tap(find.text(l.undo));
            await tester.pumpAndSettle();
            expect(done(2), isFalse);
            expect(ticked(tester, row('Llamar a mamá')), isFalse);
            expect(done(1), isTrue);
            await waitOutMessage(tester);

            // The last again, by a swipe right.
            await tester.ensureVisible(row('Llamar a mamá'));
            await tester.pumpAndSettle();
            await tester.drag(row('Llamar a mamá'), const Offset(300, 0));
            allowSwipeOverflow(tester);
            await tester.pumpAndSettle();
            allowSwipeOverflow(tester);
            expect(done(2), isTrue);
            expectWhole(l.dayAllClear);
            expect(find.text(l.taskCompleted), findsNothing);
            expect(find.text(l.undo).hitTestable(), findsOneWidget);
            await tester.tap(find.text(l.undo));
            await tester.pumpAndSettle();
            expect(done(2), isFalse);
            expect(ticked(tester, row('Llamar a mamá')), isFalse);

            // Unticking still says «Tarea reabierta».
            await waitOutMessage(tester);
            await tick(tester, circle('Comprar pan'));
            expect(done(1), isFalse);
            expect(find.text(l.taskReopened), findsOneWidget);
            expect(find.text(l.dayAllClear), findsNothing);
            expect(tester.takeException(), isNull);
          },
        );
      }
    }

    testWidgets(
      'WD34 (UX-2303): on today with an open overdue task, ticking the day’s own last task says «Tarea completada»',
      (tester) async {
        await openCalendar(
          tester,
          [
            Task(id: 1, title: 'Comprar pan', priority: 1, dueDate: daysAgo(1)),
            Task(id: 2, title: 'Llamar a mamá', priority: 1, dueDate: today(18), hasTime: true),
          ],
          size: const Size(360, 800),
          overrides: [clock],
        );
        final l = tester.element(find.byType(CalendarScreen)).l10n;
        await tick(tester, circle('Llamar a mamá'));
        expect(ticked(tester, row('Llamar a mamá')), isTrue);
        expect(find.text(l.taskCompleted), findsOneWidget);
        expect(find.text(l.dayAllClear), findsNothing);
        await waitOutMessage(tester);

        // Then the overdue one, now the last open task: the day is clear.
        await tick(tester, circle('Comprar pan'));
        expect(find.text(l.dayAllClear), findsOneWidget);
        expect(find.text(l.taskCompleted), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'WD34 (UX-2303): ticking the day’s last open task on Tareas says «Tarea completada»',
      (tester) async {
        await openCalendar(
          tester,
          [
            Task(id: 1, title: 'Llamar a mamá', priority: 1, dueDate: today(18), hasTime: true),
          ],
          size: const Size(360, 800),
          overrides: [clock],
        );
        final l = tester.element(find.byType(CalendarScreen)).l10n;
        await tab(tester, l.tasks);
        final tasksRow = find.descendant(
          of: find.byType(HomeScreen),
          matching: find.widgetWithText(TaskTile, 'Llamar a mamá'),
        );
        expect(tasksRow, findsOneWidget);
        await tick(tester, circleIn(tasksRow));
        expect(ticked(tester, tasksRow), isTrue);
        expect(find.text(l.taskCompleted), findsOneWidget);
        expect(find.text(l.dayAllClear), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'WD34 (UX-2303): ticking the day’s last open task on a project page says «Tarea completada»',
      (tester) async {
        tester.view.physicalSize = const Size(360, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final container = designContainer(
          regionalStore: MemoryRegionalStore(
            const RegionalPreferences(language: 'es'),
          ),
          projects: [TaskListInfo(id: 'casa', name: 'Casa')],
          tasks: () => _GivenTasks([
            Task(
              id: 1,
              title: 'Llamar a mamá',
              priority: 1,
              dueDate: today(18),
              hasTime: true,
              listId: 'casa',
            ),
          ]),
          overrides: [clock],
        );
        addTearDown(container.dispose);
        await tester.pumpWidget(
          UncontrolledProviderScope(container: container, child: const MyApp()),
        );
        await tester.pumpAndSettle();
        final l = tester.element(find.byType(CalendarScreen)).l10n;
        unawaited(
          Navigator.of(tester.element(find.byType(CalendarScreen))).push(
            MaterialPageRoute<void>(
              builder: (_) => const HomeScreen(listId: 'casa', isRoot: false),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final projectRow = find.descendant(
          of: find.byWidgetPredicate(
            (widget) => widget is HomeScreen && widget.listId == 'casa',
          ),
          matching: find.widgetWithText(TaskTile, 'Llamar a mamá'),
        );
        expect(projectRow, findsOneWidget);
        await tick(tester, circleIn(projectRow));
        expect(ticked(tester, projectRow), isTrue);
        expect(find.text(l.taskCompleted), findsOneWidget);
        expect(find.text(l.dayAllClear), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'WD34 (UX-2303): Completar on the day’s last open task’s own page says «Tarea completada»',
      (tester) async {
        final container = await openCalendar(
          tester,
          [
            Task(id: 1, title: 'Llamar a mamá', priority: 1, dueDate: today(18), hasTime: true),
          ],
          size: const Size(360, 800),
          overrides: [clock],
        );
        final l = tester.element(find.byType(CalendarScreen)).l10n;
        unawaited(
          tester
              .state<NavigatorState>(find.byType(Navigator))
              .pushNamed('/taskDetails', arguments: 1),
        );
        await tester.pumpAndSettle();
        final complete = find.descendant(
          of: find.byType(TaskDetailScreen),
          matching: find.text(l.complete),
        );
        expect(complete, findsOneWidget);
        await tester.ensureVisible(complete);
        await tester.pumpAndSettle();
        await tester.tap(complete);
        await tester.pumpAndSettle();
        expect(
          container.read(taskProvider).requireValue.single.isCompleted,
          isTrue,
        );
        expect(find.text(l.taskCompleted), findsOneWidget);
        expect(find.text(l.dayAllClear), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  });

  // ---- Run 2026-10-28-app, round 1 · P277 (UX-2306, UX-2310): phone events
  // by name on Calendar, sheets that end with «Cerrar», read errors you can
  // retry in the events sheet ----

  group('P277 · phone events by name', () {
    final sheet = find.byType(BottomSheet);
    Finder inSheet(Finder finder) =>
        find.descendant(of: sheet, matching: finder);
    final inbox = find.byKey(const ValueKey('calendar-inbox'));

    _FlakyCalendars twoEvents() {
      final now = DateTime.now();
      return _FlakyCalendars()
        ..data = [
          DeviceCalendarEvent(
            id: '50',
            calendarId: workCalendar.id,
            title: 'Reunión de equipo',
            start: DateTime(now.year, now.month, now.day, 10),
            end: DateTime(now.year, now.month, now.day, 11),
            allDay: false,
          ),
          DeviceCalendarEvent(
            id: '51',
            calendarId: workCalendar.id,
            title: 'Cita con el dentista',
            start: DateTime(now.year, now.month, now.day, 17),
            end: DateTime(now.year, now.month, now.day, 18),
            allDay: false,
          ),
        ];
    }

    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'UX-2306: at ${scale}x on 360×800 in Spanish, two phone events read «Reunión de equipo · 10:00» and «Cita con el dentista · 17:00», at least 8 dp above «Sin fecha · 1», and a tap opens that event',
        (tester) async {
          final now = DateTime.now();
          final bridge = twoEvents();
          addTearDown(bridge.close);
          await openCalendar(
            tester,
            [Task(id: 1, title: 'Algún día', priority: 1)],
            overrides: phoneCalendar(bridge),
            size: const Size(360, 800),
            textScale: scale,
          );
          final context = tester.element(find.byType(CalendarScreen));
          final l = context.l10n;
          final ten = find.text(
            'Reunión de equipo · '
            '${context.clockTime(DateTime(now.year, now.month, now.day, 10))}',
          );
          final five = find.text(
            'Cita con el dentista · '
            '${context.clockTime(DateTime(now.year, now.month, now.day, 17))}',
          );
          await scrollAgendaToEnd(tester);
          expect(ten, findsOneWidget);
          expect(five, findsOneWidget);
          // No grey count line any more.
          expect(
            find.byKey(const ValueKey('calendar-events-line')),
            findsNothing,
          );
          expect(find.textContaining('2 eventos'), findsNothing);
          // In order, each row a 48 dp target.
          Finder row(Finder text) =>
              find.ancestor(of: text, matching: find.byType(InkWell)).first;
          expect(
            tester.getRect(row(five)).top,
            greaterThanOrEqualTo(tester.getRect(row(ten)).bottom - 0.5),
          );
          for (final text in [ten, five]) {
            expect(tester.getSize(row(text)).height, greaterThanOrEqualTo(48));
          }
          // «Sin fecha · 1» right under the events, kept 8 dp apart.
          expect(inbox, findsOneWidget);
          expect(
            find.descendant(of: inbox, matching: find.text(l.inboxCount(1))),
            findsOneWidget,
          );
          expect(
            tester.getRect(inbox).top - tester.getRect(row(five)).bottom,
            greaterThanOrEqualTo(8),
            reason: 'the last event and «Sin fecha · 1» don’t touch',
          );
          // The rows sit inside the screen, not cut at its side.
          for (final text in [ten, five]) {
            expect(tester.getRect(text).right, lessThanOrEqualTo(360));
          }
          // A tap on a row opens that event.
          await tester.tap(five);
          await tester.pumpAndSettle();
          expect(sheet, findsOneWidget);
          expect(inSheet(find.text('Cita con el dentista')), findsOneWidget);
          expect(inSheet(find.text('Reunión de equipo')), findsNothing);
          expect(inSheet(find.text(l.calendarOpenEvent)), findsOneWidget);
          // «Cerrar» closes it.
          final close = inSheet(find.widgetWithText(TextButton, l.close));
          expect(l.close, 'Cerrar');
          expect(close.hitTestable(), findsOneWidget);
          await tester.tap(close);
          await tester.pumpAndSettle();
          expect(sheet, findsNothing);
          await tester.tap(ten);
          await tester.pumpAndSettle();
          expect(inSheet(find.text('Reunión de equipo')), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );
    }

    for (final list in [false, true]) {
      final which = list ? 'the list of events' : 'an event';
      testWidgets(
        'UX-2310: when the events fail to read with $which open, its sheet says «No se pudieron leer los eventos. Toca para reintentar.», and a tap reads again, busy meanwhile',
        (tester) async {
          final now = DateTime.now();
          final bridge = _FlakyCalendars()
            ..data = [
              for (var i = 0; i < (list ? 4 : 1); i++)
                DeviceCalendarEvent(
                  id: '${60 + i}',
                  calendarId: workCalendar.id,
                  title: 'Dentista $i',
                  start: DateTime(now.year, now.month, now.day, 9 + i),
                  end: DateTime(now.year, now.month, now.day, 10 + i),
                  allDay: false,
                ),
            ];
          addTearDown(bridge.close);
          final container = await openCalendar(
            tester,
            [],
            overrides: phoneCalendar(bridge),
            size: const Size(360, 800),
          );
          final l = tester.element(find.byType(CalendarScreen)).l10n;
          expect(
            l.calendarReadRetry,
            'No se pudieron leer los eventos. Toca para reintentar.',
          );
          final opener = list
              ? find.byKey(const ValueKey('calendar-events-all'))
              : find.textContaining('Dentista 0 · ');
          await reveal(tester, opener);
          await tester.tap(opener);
          await tester.pumpAndSettle();
          expect(inSheet(find.text('Dentista 0')), findsOneWidget);

          // The phone's events can't be read now: the sheet reads them again.
          bridge.failEvents = true;
          await container.read(deviceCalendarProvider.notifier).refresh();
          await tester.pumpAndSettle();
          final line = inSheet(
            find.byKey(const ValueKey('calendar-events-line')),
          );
          expect(line, findsOneWidget);
          expect(
            find.descendant(of: line, matching: find.text(l.calendarReadRetry)),
            findsOneWidget,
          );
          expect(inSheet(find.text('Dentista 0')), findsNothing);
          expect(line.hitTestable(), findsOneWidget);
          expect(tester.widget<InkWell>(line).onTap, isNotNull);
          expect(tester.getSize(line).height, greaterThanOrEqualTo(48));
          expect(
            find.descendant(
              of: line,
              matching: find.byType(CircularProgressIndicator),
            ),
            findsNothing,
          );

          // A tap reads again; meanwhile the line stays, busy, and takes no tap.
          final reads = bridge.eventReads;
          bridge.held = 0;
          final gate = bridge.gate = Completer<void>();
          bridge.failEvents = false;
          await tester.tap(line);
          for (var i = 0; i < 3; i++) {
            await tester.pump();
          }
          expect(bridge.held, greaterThanOrEqualTo(1), reason: 'read again');
          expect(sheet, findsOneWidget, reason: 'the sheet stays open');
          expect(line, findsOneWidget);
          expect(
            find.descendant(of: line, matching: find.text(l.calendarReadRetry)),
            findsOneWidget,
          );
          expect(
            find.descendant(
              of: line,
              matching: find.byType(CircularProgressIndicator),
            ),
            findsOneWidget,
          );
          expect(tester.widget<InkWell>(line).onTap, isNull);
          bridge.gate = null;
          gate.complete();
          await tester.pumpAndSettle();

          // Read: the sheet shows the events again.
          expect(bridge.eventReads, greaterThan(reads));
          expect(line, findsNothing);
          expect(inSheet(find.text('Dentista 0')), findsOneWidget);
          if (list) {
            expect(inSheet(find.text('Dentista 3')), findsOneWidget);
          } else {
            expect(inSheet(find.text(l.calendarOpenEvent)), findsOneWidget);
          }
          expect(tester.takeException(), isNull);
        },
      );
    }

    testWidgets(
      'UX-2310: a retry in the events sheet that fails again brings the tappable line back',
      (tester) async {
        final now = DateTime.now();
        final bridge = _FlakyCalendars()
          ..data = [
            DeviceCalendarEvent(
              id: '70',
              calendarId: workCalendar.id,
              title: 'Dentista',
              start: DateTime(now.year, now.month, now.day, 9),
              end: DateTime(now.year, now.month, now.day, 10),
              allDay: false,
            ),
          ];
        addTearDown(bridge.close);
        final container = await openCalendar(
          tester,
          [],
          overrides: phoneCalendar(bridge),
          size: const Size(360, 800),
        );
        final l = tester.element(find.byType(CalendarScreen)).l10n;
        final row = find.textContaining('Dentista · ');
        await reveal(tester, row);
        await tester.tap(row);
        await tester.pumpAndSettle();
        bridge.failEvents = true;
        await container.read(deviceCalendarProvider.notifier).refresh();
        await tester.pumpAndSettle();
        final line = inSheet(
          find.byKey(const ValueKey('calendar-events-line')),
        );
        final reads = bridge.eventReads;
        await tester.tap(line);
        await tester.pumpAndSettle();
        expect(bridge.eventReads, greaterThan(reads), reason: 'read again');
        expect(
          find.descendant(of: line, matching: find.text(l.calendarReadRetry)),
          findsOneWidget,
        );
        expect(tester.widget<InkWell>(line).onTap, isNotNull);
        expect(
          find.descendant(
            of: line,
            matching: find.byType(CircularProgressIndicator),
          ),
          findsNothing,
        );
        expect(tester.takeException(), isNull);
      },
    );
  });

  // ---- UX loop 2026-10-28-app, round 1 · P300 (UX-2311, D2): Completadas
  // lists the last one done first ----
  group('P300 · completion times', () {
    final now = DateTime.now();
    DateTime daysAgo(int days, [int hour = 10]) =>
        DateTime(now.year, now.month, now.day - days, hour);
    DateTime daysAhead(int days) =>
        DateTime(now.year, now.month, now.day + days);
    DateTime todayAt(int hour, [int minute = 0]) =>
        DateTime(now.year, now.month, now.day, hour, minute);

    Finder done(String title) => find.descendant(
      of: find.byType(CompletedTasksScreen),
      matching: find.widgetWithText(TaskTile, title),
    );

    /// The rows of Completadas, top to bottom, as (title, repetition date).
    List<(String, String?)> rows(WidgetTester tester) {
      final tiles = find.descendant(
        of: find.byType(CompletedTasksScreen),
        matching: find.byType(TaskTile),
      );
      final list = tester.widgetList<TaskTile>(tiles).toList()
        ..sort(
          (a, b) => tester
              .getTopLeft(find.byWidget(a))
              .dy
              .compareTo(tester.getTopLeft(find.byWidget(b)).dy),
        );
      return [for (final tile in list) (tile.task.title, tile.task.occurrenceId)];
    }

    Future<void> openCompleted(WidgetTester tester) async {
      unawaited(
        tester
            .state<NavigatorState>(find.byType(Navigator))
            .pushNamed('/completedTasks'),
      );
      await tester.pumpAndSettle();
      expect(find.byType(CompletedTasksScreen), findsOneWidget);
    }

    Future<void> leaveAndReturn(WidgetTester tester) async {
      tester.state<NavigatorState>(find.byType(Navigator)).pop();
      await tester.pumpAndSettle();
      expect(find.byType(CompletedTasksScreen), findsNothing);
      await openCompleted(tester);
    }

    Future<void> untick(WidgetTester tester, Finder row) async {
      final circle = find.descendant(of: row, matching: find.byType(Checkbox));
      await tester.ensureVisible(circle);
      await tester.pumpAndSettle();
      await tester.tap(circle);
      await tester.pumpAndSettle();
    }

    List<Task> fourTicks() => [
      // Planned on three different days; ticked at 09:00, 10:00 and 11:00.
      Task(id: 1, title: 'Pagar la luz', priority: 1, dueDate: daysAgo(1), hasTime: false, isCompleted: true, completedAt: todayAt(9)),
      Task(id: 2, title: 'Renovar el DNI', priority: 1, dueDate: daysAgo(20), hasTime: false, isCompleted: true, completedAt: todayAt(10)),
      Task(id: 3, title: 'Reservar el hotel', priority: 1, dueDate: daysAhead(30), hasTime: false, isCompleted: true, completedAt: todayAt(11)),
      // No day, ticked last, at 11:30.
      Task(id: 4, title: 'Comprar pan', priority: 1, isCompleted: true, completedAt: todayAt(11, 30)),
    ];

    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'UX-2311: Completadas, ES ${scale.toInt()}×: three dated tasks ticked at 09:00, 10:00 and 11:00, then «Comprar pan» with no day at 11:30, read «Comprar pan», then the 11:00, 10:00 and 09:00 tasks, whatever their planned days; no row shows a time or a new line',
        (tester) async {
          await openCalendar(
            tester,
            fourTicks(),
            size: const Size(360, 800),
            textScale: scale,
          );
          await openCompleted(tester);
          final order = <String>[];
          // At 2× not every row fits: read them top to bottom, scrolling.
          for (final title in [
            'Comprar pan',
            'Reservar el hotel',
            'Renovar el DNI',
            'Pagar la luz',
          ]) {
            await tester.scrollUntilVisible(
              done(title),
              120,
              scrollable: find
                  .descendant(
                    of: find.byType(CompletedTasksScreen),
                    matching: find.byType(Scrollable),
                  )
                  .last,
            );
            await tester.pumpAndSettle();
            order.add(title);
            final texts = tester
                .widgetList<Text>(
                  find.descendant(of: done(title), matching: find.byType(Text)),
                )
                .map((text) => text.data ?? text.textSpan?.toPlainText() ?? '')
                .join(' | ');
            for (final time in ['09:00', '10:00', '11:00', '11:30', '9:00']) {
              expect(texts, isNot(contains(time)), reason: '$title: $texts');
            }
          }
          await tester.drag(
            find
                .descendant(
                  of: find.byType(CompletedTasksScreen),
                  matching: find.byType(Scrollable),
                )
                .last,
            const Offset(0, 3000),
          );
          await tester.pumpAndSettle();
          if (scale == 1.0) {
            expect(rows(tester).map((row) => row.$1), [
              'Comprar pan',
              'Reservar el hotel',
              'Renovar el DNI',
              'Pagar la luz',
            ]);
          } else {
            // The first rows in view are the newest.
            expect(rows(tester).first.$1, 'Comprar pan');
          }
          expect(tester.takeException(), isNull);
        },
      );
    }

    testWidgets(
      'UX-2311: a timed row and an untimed one of the same kind are drawn the same height: the time adds no line',
      (tester) async {
        await openCalendar(tester, [
          Task(id: 1, title: 'Comprar pan', priority: 1, isCompleted: true, completedAt: todayAt(11, 30)),
          Task(id: 2, title: 'Comprar sal', priority: 1, isCompleted: true),
        ], size: const Size(360, 800));
        await openCompleted(tester);
        expect(
          tester.getSize(done('Comprar pan')).height,
          tester.getSize(done('Comprar sal')).height,
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'UX-2311: completions with no time come after every timed row, in today’s order: latest planned day first, undated last',
      (tester) async {
        await openCalendar(tester, [
          Task(id: 1, title: 'Sin hora, hace tres días', priority: 1, dueDate: daysAgo(3), isCompleted: true),
          Task(id: 2, title: 'Sin hora, sin día', priority: 1, isCompleted: true),
          Task(id: 3, title: 'Con hora, hace un mes', priority: 1, dueDate: daysAgo(30), isCompleted: true, completedAt: daysAgo(30, 9)),
          Task(id: 4, title: 'Sin hora, ayer', priority: 1, dueDate: daysAgo(1), isCompleted: true),
          Task(id: 5, title: 'Con hora, hoy', priority: 1, dueDate: daysAgo(8), isCompleted: true, completedAt: todayAt(8)),
        ], size: const Size(360, 1400));
        await openCompleted(tester);
        expect(rows(tester).map((row) => row.$1), [
          'Con hora, hoy',
          'Con hora, hace un mes',
          'Sin hora, ayer',
          'Sin hora, hace tres días',
          'Sin hora, sin día',
        ]);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'UX-2311: a daily task’s 3rd repetition ticked after a one-off task lists above it; its 2nd, ticked earlier, lists below both',
      (tester) async {
        final second = Task.dateKey(daysAgo(2));
        final third = Task.dateKey(daysAgo(1));
        await openCalendar(tester, [
          Task(
            id: 1,
            title: 'Regar las plantas',
            priority: 1,
            dueDate: daysAgo(3, 9),
            recurrence: 'daily',
            completedDates: [second, third],
            completedTimes: {second: daysAgo(2, 9), third: todayAt(10)},
          ),
          Task(id: 2, title: 'Llamar a Ana', priority: 1, dueDate: daysAgo(5), isCompleted: true, completedAt: todayAt(9)),
        ], size: const Size(360, 1000));
        await openCompleted(tester);
        expect(rows(tester), [
          ('Regar las plantas', third),
          ('Llamar a Ana', null),
          ('Regar las plantas', second),
        ]);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'UX-2311 / UX-2304: with three timed rows, reopening the newest leaves it first, unticked, until the page is left; back on the page, it’s gone',
      (tester) async {
        await openCalendar(tester, fourTicks().sublist(0, 3), size: const Size(360, 800));
        await openCompleted(tester);
        expect(rows(tester).map((row) => row.$1), [
          'Reservar el hotel',
          'Renovar el DNI',
          'Pagar la luz',
        ]);
        await untick(tester, done('Reservar el hotel'));
        expect(rows(tester).map((row) => row.$1), [
          'Reservar el hotel',
          'Renovar el DNI',
          'Pagar la luz',
        ]);
        expect(
          tester
              .widget<Checkbox>(
                find.descendant(
                  of: done('Reservar el hotel'),
                  matching: find.byType(Checkbox),
                ),
              )
              .value,
          isFalse,
        );
        await tester.pump(const Duration(seconds: 12));
        await tester.pumpAndSettle();
        expect(rows(tester).first.$1, 'Reservar el hotel');
        await leaveAndReturn(tester);
        expect(rows(tester).map((row) => row.$1), [
          'Renovar el DNI',
          'Pagar la luz',
        ]);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'UX-2311: reopen a row on Completadas, then tap Deshacer: after leaving and coming back, the row is in its old place, and its stored time is the one it had, not the Deshacer’s',
      (tester) async {
        tester.view.physicalSize = const Size(360, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        var clock = todayAt(12);
        final repository = _StampingTasks(fourTicks(), () => clock);
        final container = designContainer(
          regionalStore: MemoryRegionalStore(
            const RegionalPreferences(language: 'es'),
          ),
          tasks: () => TaskNotifier(repository),
        );
        addTearDown(container.dispose);
        await tester.pumpWidget(
          UncontrolledProviderScope(container: container, child: const MyApp()),
        );
        await tester.pumpAndSettle();
        final l = tester.element(find.byType(CalendarScreen)).l10n;
        await openCompleted(tester);
        final before = rows(tester).map((row) => row.$1).toList();
        expect(before, [
          'Comprar pan',
          'Reservar el hotel',
          'Renovar el DNI',
          'Pagar la luz',
        ]);
        await untick(tester, done('Renovar el DNI'));
        expect(find.text(l.taskReopened), findsOneWidget);
        expect(repository.task(2).completedAt, isNull, reason: 'reopened');
        clock = todayAt(13, 45);
        await tester.tap(find.text(l.undo));
        await tester.pumpAndSettle();
        expect(repository.task(2).isCompleted, isTrue);
        expect(
          repository.task(2).completedAt,
          todayAt(10),
          reason: 'the time it had, not the Deshacer’s',
        );
        await tester.pump(const Duration(seconds: 12));
        await tester.pumpAndSettle();
        await leaveAndReturn(tester);
        expect(rows(tester).map((row) => row.$1).toList(), before);
        expect(tester.takeException(), isNull);
      },
    );
  });

  // ---- UX loop 2026-10-28-app, round 2 · P310 (UX-2638): ticking again a
  // row reopened on Completadas keeps the time it was done at ----
  group('P310 · re-ticking on Completadas keeps the time', () {
    final now = DateTime.now();
    DateTime daysAgo(int days, [int hour = 10]) =>
        DateTime(now.year, now.month, now.day - days, hour);
    DateTime todayAt(int hour, [int minute = 0]) =>
        DateTime(now.year, now.month, now.day, hour, minute);

    Finder done(String title) => find.descendant(
      of: find.byType(CompletedTasksScreen),
      matching: find.widgetWithText(TaskTile, title),
    );

    /// The rows of Completadas, top to bottom, as (title, repetition date).
    List<(String, String?)> rows(WidgetTester tester) {
      final tiles = find.descendant(
        of: find.byType(CompletedTasksScreen),
        matching: find.byType(TaskTile),
      );
      final list = tester.widgetList<TaskTile>(tiles).toList()
        ..sort(
          (a, b) => tester
              .getTopLeft(find.byWidget(a))
              .dy
              .compareTo(tester.getTopLeft(find.byWidget(b)).dy),
        );
      return [for (final tile in list) (tile.task.title, tile.task.occurrenceId)];
    }

    Future<void> openCompleted(WidgetTester tester) async {
      unawaited(
        tester
            .state<NavigatorState>(find.byType(Navigator))
            .pushNamed('/completedTasks'),
      );
      await tester.pumpAndSettle();
      expect(find.byType(CompletedTasksScreen), findsOneWidget);
    }

    Future<void> leaveAndReturn(WidgetTester tester) async {
      tester.state<NavigatorState>(find.byType(Navigator)).pop();
      await tester.pumpAndSettle();
      expect(find.byType(CompletedTasksScreen), findsNothing);
      await openCompleted(tester);
    }

    Future<void> tapCircle(WidgetTester tester, Finder row) async {
      final circle = find.descendant(of: row, matching: find.byType(Checkbox));
      await tester.ensureVisible(circle);
      await tester.pumpAndSettle();
      await tester.tap(circle);
      await tester.pumpAndSettle();
    }

    bool ticked(WidgetTester tester, Finder row) =>
        tester
            .widget<Checkbox>(
              find.descendant(of: row, matching: find.byType(Checkbox)),
            )
            .value ??
        false;

    /// The app in Spanish on 360×800, its tasks stored with the database's
    /// rule for completion times, with [clock] as now.
    Future<_StampingTasks> open(
      WidgetTester tester,
      List<Task> tasks,
      DateTime Function() clock,
    ) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final repository = _StampingTasks(tasks, clock);
      final container = designContainer(
        regionalStore: MemoryRegionalStore(
          const RegionalPreferences(language: 'es'),
        ),
        tasks: () => TaskNotifier(repository),
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(container: container, child: const MyApp()),
      );
      await tester.pumpAndSettle();
      return repository;
    }

    testWidgets(
      'UX-2638: Completadas, ES 1× on 360×800, three tasks ticked at 09:00, 10:00 and 11:00: the 10:00 row reopened and ticked again at 12:00 keeps 10:00, and on the next visit the order is 11:00, 10:00, 09:00',
      (tester) async {
        var clock = todayAt(11, 30);
        final repository = await open(tester, [
          Task(id: 1, title: 'Pagar la luz', priority: 1, dueDate: daysAgo(1), hasTime: false, isCompleted: true, completedAt: todayAt(9)),
          Task(id: 2, title: 'Renovar el DNI', priority: 1, dueDate: daysAgo(20), hasTime: false, isCompleted: true, completedAt: todayAt(10)),
          Task(id: 3, title: 'Reservar el hotel', priority: 1, dueDate: daysAgo(2), hasTime: false, isCompleted: true, completedAt: todayAt(11)),
        ], () => clock);
        await openCompleted(tester);
        const order = ['Reservar el hotel', 'Renovar el DNI', 'Pagar la luz'];
        expect(rows(tester).map((row) => row.$1), order);

        await tapCircle(tester, done('Renovar el DNI'));
        expect(ticked(tester, done('Renovar el DNI')), isFalse);
        expect(repository.task(2).isCompleted, isFalse, reason: 'reopened');
        clock = todayAt(12);
        await tapCircle(tester, done('Renovar el DNI'));
        expect(ticked(tester, done('Renovar el DNI')), isTrue);
        expect(repository.task(2).isCompleted, isTrue);
        expect(
          repository.task(2).completedAt!.isAtSameMomentAs(todayAt(10)),
          isTrue,
          reason:
              'stored ${repository.task(2).completedAt}, not the re-tick’s 12:00',
        );
        expect(rows(tester).map((row) => row.$1), order);

        await tester.pump(const Duration(seconds: 12));
        await tester.pumpAndSettle();
        await leaveAndReturn(tester);
        expect(rows(tester).map((row) => row.$1), order);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'UX-2638: a repeating task’s repetition ticked at 10:00, between rows ticked at 09:00 and 11:00: reopened and ticked again at 12:00, its time for that date stays 10:00 and it keeps its place on the next visit',
      (tester) async {
        final key = Task.dateKey(daysAgo(1));
        var clock = todayAt(11, 30);
        final repository = await open(tester, [
          Task(
            id: 1,
            title: 'Regar las plantas',
            priority: 1,
            dueDate: daysAgo(3, 9),
            recurrence: 'daily',
            completedDates: [key],
            completedTimes: {key: todayAt(10)},
          ),
          Task(id: 2, title: 'Llamar a Ana', priority: 1, dueDate: daysAgo(5), isCompleted: true, completedAt: todayAt(9)),
          Task(id: 3, title: 'Pedir cita', priority: 1, dueDate: daysAgo(6), isCompleted: true, completedAt: todayAt(11)),
        ], () => clock);
        await openCompleted(tester);
        final order = [
          ('Pedir cita', null),
          ('Regar las plantas', key),
          ('Llamar a Ana', null),
        ];
        expect(rows(tester), order);

        await tapCircle(tester, done('Regar las plantas'));
        expect(repository.task(1).completedDates, isNot(contains(key)));
        clock = todayAt(12);
        await tapCircle(tester, done('Regar las plantas'));
        expect(repository.task(1).completedDates, contains(key));
        final time = repository.task(1).completedTimes[key];
        expect(
          time != null && time.isAtSameMomentAs(todayAt(10)),
          isTrue,
          reason: 'stored $time, not the re-tick’s 12:00',
        );

        await tester.pump(const Duration(seconds: 12));
        await tester.pumpAndSettle();
        await leaveAndReturn(tester);
        expect(rows(tester), order);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'UX-2638: ticking an open task on Calendar, or on Tareas, at 12:00 still stores 12:00',
      (tester) async {
        final repository = await open(tester, [
          Task(id: 1, title: 'Llamar a Ana', priority: 1, dueDate: todayAt(0), hasTime: false),
          Task(id: 2, title: 'Comprar pan', priority: 1, dueDate: todayAt(0), hasTime: false),
        ], () => todayAt(12));
        final calendarRow = find.descendant(
          of: find.byType(CalendarScreen),
          matching: find.widgetWithText(TaskTile, 'Llamar a Ana'),
        );
        await tapCircle(tester, calendarRow);
        expect(repository.task(1).isCompleted, isTrue);
        expect(
          repository.task(1).completedAt!.isAtSameMomentAs(todayAt(12)),
          isTrue,
          reason: 'Calendar stored ${repository.task(1).completedAt}',
        );

        final es = lookupAppLocalizations(const Locale('es'));
        await tester.tap(
          find.descendant(
            of: find.byType(NavigationBar),
            matching: find.text(es.tasks),
          ),
        );
        await tester.pumpAndSettle();
        final tasksRow = find.descendant(
          of: find.byType(HomeScreen),
          matching: find.widgetWithText(TaskTile, 'Comprar pan'),
        );
        await tapCircle(tester, tasksRow);
        expect(repository.task(2).isCompleted, isTrue);
        expect(
          repository.task(2).completedAt!.isAtSameMomentAs(todayAt(12)),
          isTrue,
          reason: 'Tareas stored ${repository.task(2).completedAt}',
        );
        expect(tester.takeException(), isNull);
      },
    );
  });

  // ---- UX loop 2026-11-01-screens, round 1 · P315 (UX-2646): Completar on
  // the page of a row opened from Completadas keeps the row's time ----
  group('P315 · the task page', () {
    final now = DateTime.now();
    DateTime daysAgo(int days, [int hour = 10]) =>
        DateTime(now.year, now.month, now.day - days, hour);
    DateTime todayAt(int hour, [int minute = 0]) =>
        DateTime(now.year, now.month, now.day, hour, minute);
    final es = lookupAppLocalizations(const Locale('es'));

    Finder done(String title) => find.descendant(
      of: find.byType(CompletedTasksScreen),
      matching: find.widgetWithText(TaskTile, title),
    );

    /// The rows of Completadas, top to bottom, as (title, repetition date).
    List<(String, String?)> rows(WidgetTester tester) {
      final tiles = find.descendant(
        of: find.byType(CompletedTasksScreen),
        matching: find.byType(TaskTile),
      );
      final list = tester.widgetList<TaskTile>(tiles).toList()
        ..sort(
          (a, b) => tester
              .getTopLeft(find.byWidget(a))
              .dy
              .compareTo(tester.getTopLeft(find.byWidget(b)).dy),
        );
      return [for (final tile in list) (tile.task.title, tile.task.occurrenceId)];
    }

    Future<void> openCompleted(WidgetTester tester) async {
      unawaited(
        tester
            .state<NavigatorState>(find.byType(Navigator))
            .pushNamed('/completedTasks'),
      );
      await tester.pumpAndSettle();
      expect(find.byType(CompletedTasksScreen), findsOneWidget);
    }

    Future<void> leaveAndReturn(WidgetTester tester) async {
      tester.state<NavigatorState>(find.byType(Navigator)).pop();
      await tester.pumpAndSettle();
      expect(find.byType(CompletedTasksScreen), findsNothing);
      await openCompleted(tester);
    }

    Future<void> tapCircle(WidgetTester tester, Finder row) async {
      final circle = find.descendant(of: row, matching: find.byType(Checkbox));
      await tester.ensureVisible(circle);
      await tester.pumpAndSettle();
      await tester.tap(circle);
      await tester.pumpAndSettle();
    }

    /// Taps [row]'s title, as a person opens a task, and waits for its page.
    Future<void> openPage(WidgetTester tester, Finder row, String title) async {
      final name = find.descendant(of: row, matching: find.text(title));
      await tester.ensureVisible(name.first);
      await tester.pumpAndSettle();
      await tester.tap(name.first);
      await tester.pumpAndSettle();
      expect(find.byType(TaskDetailScreen), findsOneWidget);
    }

    Finder pageButton(String label) => find.descendant(
      of: find.byType(TaskDetailScreen),
      matching: find.text(label),
    );

    Future<void> tapOnPage(WidgetTester tester, String label) async {
      final button = pageButton(label);
      expect(button, findsOneWidget, reason: '«$label» on the page');
      await tester.ensureVisible(button);
      await tester.pumpAndSettle();
      await tester.tap(button);
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
    }

    /// Ends the snackbar's time, so leaving isn't held by it.
    Future<void> settleMessages(WidgetTester tester) async {
      await tester.pump(const Duration(seconds: 12));
      await tester.pumpAndSettle();
    }

    /// The app in Spanish on 360×800, its tasks stored with the database's
    /// rule for completion times, with [clock] as now.
    Future<_StampingTasks> open(
      WidgetTester tester,
      List<Task> tasks,
      DateTime Function() clock,
    ) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final repository = _StampingTasks(tasks, clock);
      final container = designContainer(
        regionalStore: MemoryRegionalStore(
          const RegionalPreferences(language: 'es'),
        ),
        tasks: () => TaskNotifier(repository),
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(container: container, child: const MyApp()),
      );
      await tester.pumpAndSettle();
      return repository;
    }

    List<Task> threeTicks() => [
      Task(id: 1, title: 'Pagar la luz', priority: 1, dueDate: daysAgo(1), hasTime: false, isCompleted: true, completedAt: todayAt(9)),
      Task(id: 2, title: 'Renovar el DNI', priority: 1, dueDate: daysAgo(20), hasTime: false, isCompleted: true, completedAt: todayAt(10)),
      Task(id: 3, title: 'Reservar el hotel', priority: 1, dueDate: daysAgo(2), hasTime: false, isCompleted: true, completedAt: todayAt(11)),
    ];
    const order = ['Reservar el hotel', 'Renovar el DNI', 'Pagar la luz'];

    void expectStoredAt(Task task, DateTime at) => expect(
      task.completedAt != null && task.completedAt!.isAtSameMomentAs(at),
      isTrue,
      reason: '«${task.title}» stored ${task.completedAt}, expected $at',
    );

    testWidgets(
      'UX-2646: Completadas, ES 1× on 360×800, ticked at 09:00, 10:00 and 11:00: the 10:00 row reopened with its circle, opened, and given «Completar» at 12:00 on its page: the page closes, it keeps 10:00, and the list reads 11:00, 10:00, 09:00 on this visit and the next',
      (tester) async {
        var clock = todayAt(11, 30);
        final repository = await open(tester, threeTicks(), () => clock);
        await openCompleted(tester);
        expect(rows(tester).map((row) => row.$1), order);

        await tapCircle(tester, done('Renovar el DNI'));
        expect(repository.task(2).isCompleted, isFalse, reason: 'reopened');
        await settleMessages(tester);
        expect(rows(tester).map((row) => row.$1), order);

        await openPage(tester, done('Renovar el DNI'), 'Renovar el DNI');
        clock = todayAt(12);
        await tapOnPage(tester, es.complete);
        expect(find.byType(TaskDetailScreen), findsNothing,
            reason: 'Completar closes the page');
        expect(find.byType(CompletedTasksScreen), findsOneWidget);
        expect(repository.task(2).isCompleted, isTrue);
        expectStoredAt(repository.task(2), todayAt(10));
        expect(rows(tester).map((row) => row.$1), order, reason: 'this visit');

        await settleMessages(tester);
        await leaveAndReturn(tester);
        expect(rows(tester).map((row) => row.$1), order, reason: 'next visit');
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'UX-2646: the 10:00 row’s page opened while it is done: «Reabrir» keeps the page, then «Completar» at 12:00 stores 10:00, and the next visit reads 11:00, 10:00, 09:00',
      (tester) async {
        var clock = todayAt(11, 30);
        final repository = await open(tester, threeTicks(), () => clock);
        await openCompleted(tester);
        expect(rows(tester).map((row) => row.$1), order);

        await openPage(tester, done('Renovar el DNI'), 'Renovar el DNI');
        await tapOnPage(tester, es.reopen);
        expect(find.byType(TaskDetailScreen), findsOneWidget,
            reason: 'Reabrir keeps the page');
        expect(repository.task(2).isCompleted, isFalse, reason: 'reopened');
        expect(pageButton(es.complete), findsOneWidget);
        await settleMessages(tester);

        clock = todayAt(12);
        await tapOnPage(tester, es.complete);
        expect(find.byType(TaskDetailScreen), findsNothing);
        expect(repository.task(2).isCompleted, isTrue);
        expectStoredAt(repository.task(2), todayAt(10));

        await settleMessages(tester);
        await leaveAndReturn(tester);
        expect(rows(tester).map((row) => row.$1), order, reason: 'next visit');
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'UX-2646: a repeating task’s repetition done at 10:00, between rows done at 09:00 and 11:00, reopened on Completadas and given «Completar» on its page at 12:00: its time for that date stays 10:00 and it keeps its place on the next visit',
      (tester) async {
        final key = Task.dateKey(daysAgo(1));
        var clock = todayAt(11, 30);
        final repository = await open(tester, [
          Task(
            id: 1,
            title: 'Regar las plantas',
            priority: 1,
            dueDate: daysAgo(3, 9),
            recurrence: 'daily',
            completedDates: [key],
            completedTimes: {key: todayAt(10)},
          ),
          Task(id: 2, title: 'Llamar a Ana', priority: 1, dueDate: daysAgo(5), isCompleted: true, completedAt: todayAt(9)),
          Task(id: 3, title: 'Pedir cita', priority: 1, dueDate: daysAgo(6), isCompleted: true, completedAt: todayAt(11)),
        ], () => clock);
        await openCompleted(tester);
        final repetitionOrder = [
          ('Pedir cita', null),
          ('Regar las plantas', key),
          ('Llamar a Ana', null),
        ];
        expect(rows(tester), repetitionOrder);

        await tapCircle(tester, done('Regar las plantas'));
        expect(repository.task(1).completedDates, isNot(contains(key)));
        await settleMessages(tester);

        await openPage(tester, done('Regar las plantas'), 'Regar las plantas');
        clock = todayAt(12);
        await tapOnPage(tester, es.complete);
        expect(find.byType(TaskDetailScreen), findsNothing);
        expect(repository.task(1).completedDates, contains(key));
        final time = repository.task(1).completedTimes[key];
        expect(
          time != null && time.isAtSameMomentAs(todayAt(10)),
          isTrue,
          reason: 'stored $time for $key, not the page’s 12:00',
        );

        await settleMessages(tester);
        await leaveAndReturn(tester);
        expect(rows(tester), repetitionOrder);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'UX-2646: a task’s page opened from Calendar, or from Tareas: «Completar» at 12:00 still stores 12:00',
      (tester) async {
        final repository = await open(tester, [
          Task(id: 1, title: 'Llamar a Ana', priority: 1, dueDate: todayAt(0), hasTime: false),
          Task(id: 2, title: 'Comprar pan', priority: 1, dueDate: todayAt(0), hasTime: false),
        ], () => todayAt(12));

        final calendarRow = find.descendant(
          of: find.byType(CalendarScreen),
          matching: find.widgetWithText(TaskTile, 'Llamar a Ana'),
        );
        await openPage(tester, calendarRow, 'Llamar a Ana');
        await tapOnPage(tester, es.complete);
        expect(find.byType(TaskDetailScreen), findsNothing);
        expect(repository.task(1).isCompleted, isTrue);
        expectStoredAt(repository.task(1), todayAt(12));
        await settleMessages(tester);

        await tester.tap(
          find.descendant(
            of: find.byType(NavigationBar),
            matching: find.text(es.tasks),
          ),
        );
        await tester.pumpAndSettle();
        final tasksRow = find.descendant(
          of: find.byType(HomeScreen),
          matching: find.widgetWithText(TaskTile, 'Comprar pan'),
        );
        await openPage(tester, tasksRow, 'Comprar pan');
        await tapOnPage(tester, es.complete);
        expect(find.byType(TaskDetailScreen), findsNothing);
        expect(repository.task(2).isCompleted, isTrue);
        expectStoredAt(repository.task(2), todayAt(12));
        expect(tester.takeException(), isNull);
      },
    );
  });
}

/// Tasks whose first read fails, as when the phone's database can't be read.
class _FailingTasks extends DesignTaskNotifier {
  @override
  Future<void> loadTasks() async {
    state = AsyncError(StateError('Synthetic read failure'), StackTrace.empty);
  }
}

/// A first-task store whose read never finishes, as a slow disk.
class _PendingFirstTaskStore extends MemoryFirstTaskStore {
  _PendingFirstTaskStore(this.read);
  final Completer<bool> read;
  @override
  Future<bool> hadTask(String owner) => read.future;
}

/// Phone calendars whose reads can fail with an ordinary (not permission)
/// error.
class _FlakyCalendars extends FakeDeviceCalendars {
  bool failEvents = false;
  bool failCalendars = false;
  int calendarReads = 0;

  /// While set, reads wait for [gate] and the access check for [statusGate],
  /// so a test can look at the screen with a read still pending.
  Completer<void>? gate;
  Completer<void>? statusGate;

  /// Reads that reached [gate].
  int held = 0;
  @override
  Future<CalendarAccess> status({bool request = false}) async {
    if (statusGate != null) await statusGate!.future;
    return super.status(request: request);
  }

  @override
  Future<CalendarRead<DeviceCalendarEvent>> events(
    Set<String> ids,
    DateTime day,
  ) async {
    if (gate != null) {
      held++;
      await gate!.future;
    }
    if (!failEvents) return super.events(ids, day);
    eventReads++;
    throw PlatformException(code: 'read_failed');
  }

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
}

class _GivenTasks extends DesignTaskNotifier {
  _GivenTasks(this.initial);
  final List<Task> initial;
  @override
  Future<void> loadTasks() async {
    if (!state.hasValue) state = AsyncData(initial);
  }
}

/// One task in memory behind the real notifier.
class _OneTask extends TaskRepository {
  _OneTask(this.task) : super(TaskDatabase());
  Task task;
  @override
  Future<List<Task>> getAllTasks() async => [task];
  @override
  Future<int> updateTask(Task value) async {
    task = value;
    return 1;
  }
}

/// P300: tasks in memory, written by the database's rule for completion
/// times ([Task.withCompletionTimes]) with [clock] as now.
class _StampingTasks extends TaskRepository {
  _StampingTasks(List<Task> tasks, this.clock) : super(TaskDatabase()) {
    for (final task in tasks) {
      rows[task.id!] = task;
    }
  }
  final DateTime Function() clock;
  final rows = <int, Task>{};

  Task task(int id) => rows[id]!;

  @override
  Future<List<Task>> getAllTasks() async =>
      rows.values.map((task) => Task.fromMap(task.toMap())).toList();

  @override
  Future<int> updateTask(Task task) async {
    rows[task.id!] = Task.fromMap(
      task.withCompletionTimes(rows[task.id!], clock()).toMap(),
    );
    return 1;
  }
}
