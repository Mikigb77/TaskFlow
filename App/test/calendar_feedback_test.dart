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
import 'package:agenda/providers/regional_provider.dart';
import 'package:agenda/providers/task_provider.dart';
import 'package:agenda/screens/calendar_screen.dart';
import 'package:agenda/widgets/task_actions.dart';
import 'package:agenda/widgets/task_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/design_fixtures.dart';
import 'package:agenda/l10n/generated/app_localizations.dart';
import 'package:agenda/l10n/request_locale.dart';
import 'package:agenda/models/device_calendar_event.dart';
import 'package:agenda/providers/calendar_focus_provider.dart';
import 'package:agenda/providers/device_calendar_provider.dart';
import 'package:agenda/screens/completed_tasks_screen.dart';
import 'package:agenda/screens/create_task_screen.dart';
import 'package:agenda/screens/day_timeline_screen.dart';
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
      expect(find.text(l.taskCompleted), findsOneWidget);
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
          expect(find.text(l.taskCompleted), findsOneWidget);
          expect(
            tester.getRect(find.byType(SnackBar)).bottom,
            lessThanOrEqualTo(tester.getRect(find.byType(TaskActions)).top),
          );
          expect(find.text(l.undo).hitTestable(), findsOneWidget);
          expect(
            find.byTooltip(l.createTaskTooltip).hitTestable(),
            findsOneWidget,
          );
          expect(find.text(l.sayTask).hitTestable(), findsOneWidget);
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
          expect(find.text(l.taskCompleted), findsOneWidget);
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
        RegionalPreferences(language: language),
      ),
      tasks: () => _GivenTasks(tasks),
      overrides: overrides,
    );
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
    'UX-201: yesterday’s open task shows under Atrasada above today’s, counts as pending and completes with Deshacer',
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
      await reveal(tester, todayRow);
      expect(todayRow, findsOneWidget);
      expect(
        tester.getTopLeft(header).dy,
        lessThan(tester.getTopLeft(overdueRow).dy),
      );
      expect(
        tester.getTopLeft(overdueRow).dy,
        lessThan(tester.getTopLeft(todayRow).dy),
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
      expect(header, findsNothing);
      expect(overdueRow, findsNothing);
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
      // One overdue row and today's own (completed) occurrence.
      expect(rows, findsNWidgets(2));
      expect(
        find.descendant(
          of: rows.first,
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
    await tester.tap(
      find
          .descendant(
            of: find.byType(TableCalendar<Task>),
            matching: find.text('${other.day}'),
          )
          .hitTestable(),
    );
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
    'UX-453: swiping a dated task that doesn’t repeat and tapping Sin fecha moves it at once, says Movida a la bandeja de entrada, and Deshacer restores the date',
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
      await tester.tap(find.widgetWithText(ChoiceChip, l.noDate));
      await tester.pumpAndSettle();
      // No Listo needed.
      expect(find.byType(BottomSheet), findsNothing);
      expect(find.byKey(const ValueKey('schedule-done')), findsNothing);
      expect(repository.task.dueDate, isNull);
      expect(l.movedInbox, 'Movida a la bandeja de entrada');
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
    'UX-463: in Cambiar fecha with Añadir hora on and the hour empty, one tap on Sin fecha closes the sheet, says Movida a la bandeja de entrada and leaves the task undated',
    (tester) async {
      final (repository, l) = await moveWithEmptyHour(tester);
      await tester.tap(find.widgetWithText(ChoiceChip, l.noDate));
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
          matching: find.text(l.reviewInvalidTime),
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
    await tester.tap(
      find
          .descendant(
            of: find.byType(TableCalendar<Task>),
            matching: find.text('${day.day}'),
          )
          .hitTestable(),
    );
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
    'UX-217: with four phone events the tasks come first, and one 4 eventos · … line under them opens every event',
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
                selected: {workCalendar.selectionKey},
              ),
            ),
          ),
        ],
      );
      final context = tester.element(find.byType(CalendarScreen));
      final l = context.l10n;
      final line = find.byKey(const ValueKey('calendar-events-line'));
      await reveal(tester, line);
      expect(line, findsOneWidget);
      expect(
        find.descendant(
          of: line,
          matching: find.text(
            [
              l.calendarEventCount(4),
              context.clockTime(at(9, 0)),
              context.clockTime(at(11, 30)),
              context.clockTime(at(16, 0)),
            ].join(' · '),
          ),
        ),
        findsOneWidget,
      );
      // The events aren't listed in the agenda; the tasks come first.
      expect(find.text('Cita 0'), findsNothing);
      for (final title in ['Comprar pan', 'Llamar a mamá']) {
        expect(
          tester.getBottomLeft(find.widgetWithText(TaskTile, title)).dy,
          lessThanOrEqualTo(tester.getTopLeft(line).dy),
        );
      }
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
              selected: {workCalendar.selectionKey},
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
    'UX-226: a passed deadline reads “· Fecha límite vencida” on the tile and on the detail',
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
          matching: find.textContaining(' · ${l.deadlineOverdue}'),
        ),
        findsOneWidget,
      );
      tester
          .state<NavigatorState>(find.byType(Navigator))
          .pushNamed('/taskDetails', arguments: 1);
      await tester.pumpAndSettle();
      expect(find.textContaining(' · ${l.deadlineOverdue}'), findsOneWidget);
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
    final todayCell = tester.getRect(
      find
          .descendant(
            of: find.byType(TableCalendar<Task>),
            matching: find.text('${now.day}'),
          )
          .first,
    );
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

  testWidgets(
    'UX-205: a Friday task typed from Calendario selects Friday, shows and highlights its row, says Añadida al vie, … with Deshacer, and Undo removes it',
    (tester) async {
      platform.setMockMethodCallHandler(timeoutChannel, (_) async => 10000);
      final now = DateTime.now();
      var friday = DateTime(now.year, now.month, now.day + 1);
      while (friday.weekday != DateTime.friday) {
        friday = DateTime(friday.year, friday.month, friday.day + 1);
      }
      final container = await openCalendar(tester, [
        Task(
          id: 1,
          title: 'Regar las plantas',
          priority: 1,
          dueDate: DateTime(now.year, now.month, now.day, 9),
        ),
      ]);
      final calendar = tester.element(find.byType(CalendarScreen));
      final l = calendar.l10n;
      expect(find.text(l.todayAgenda), findsOneWidget);
      await tester.tap(find.text(l.newTask).hitTestable());
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('task-title')),
        'Llevar el coche al taller',
      );
      final date = find.byKey(const ValueKey('task-date'));
      await tester.ensureVisible(date);
      await tester.tap(date);
      await tester.pumpAndSettle();
      final picker = find.byType(CalendarDatePicker);
      if (friday.month != now.month) {
        await tester.tap(
          find.descendant(
            of: picker,
            matching: find.byTooltip(
              MaterialLocalizations.of(tester.element(picker)).nextMonthTooltip,
            ),
          ),
        );
        await tester.pumpAndSettle();
      }
      await tester.tap(
        find.descendant(of: picker, matching: find.text('${friday.day}')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('schedule-done')));
      await tester.pumpAndSettle();
      final save = find.text(l.createTask);
      await tester.ensureVisible(save);
      await tester.tap(save);
      await tester.pumpAndSettle();

      // Friday is selected.
      expect(
        find.text(DateFormat.MMMMEEEEd('es').format(friday)),
        findsOneWidget,
      );
      expect(find.text(l.todayAgenda), findsNothing);
      // Its row is in view, clear of the message, and lit up.
      final row = find.widgetWithText(TaskTile, 'Llevar el coche al taller');
      expect(row.hitTestable(), findsOneWidget);
      final message = l.taskAddedOn(calendar.weekdayDate(friday));
      expect(find.text(message), findsOneWidget);
      expect(
        tester.getRect(row).bottom,
        lessThanOrEqualTo(tester.getRect(find.byType(SnackBar)).top),
      );
      expect(tester.getRect(row).top, greaterThanOrEqualTo(0));
      final colors = Theme.of(calendar).colorScheme;
      expect(tester.widget<TaskTile>(row).color, colors.primaryContainer);
      // The message leads with the weekday, never Hoy or Mañana.
      expect(message, contains(DateFormat.E('es').format(friday)));
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
    'UX-205: an undated task typed from Calendario says it went to the inbox and offers Deshacer',
    (tester) async {
      platform.setMockMethodCallHandler(timeoutChannel, (_) async => 10000);
      final container = await openCalendar(tester, []);
      final l = tester.element(find.byType(CalendarScreen)).l10n;
      await tester.tap(find.text(l.newTask).hitTestable());
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('task-title')),
        'Algún día',
      );
      final date = find.byKey(const ValueKey('task-date'));
      await tester.ensureVisible(date);
      await tester.tap(date);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ChoiceChip, l.noDate));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('schedule-done')));
      await tester.pumpAndSettle();
      final save = find.text(l.createTask);
      await tester.ensureVisible(save);
      await tester.tap(save);
      await tester.pumpAndSettle();
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
    'UX-203: Nueva tarea and the day timeline’s + never pre-fill a past day',
    (tester) async {
      final today = DateTime(2030, 3, 14, 11);
      await openCalendar(
        tester,
        [],
        overrides: [calendarClockProvider.overrideWithValue(() => today)],
      );
      final calendar = tester.element(find.byType(CalendarScreen));
      final l = calendar.l10n;
      final past = DateTime(2030, 3, 11);
      await tapDay(tester, past);
      expect(
        find.text(DateFormat.MMMMEEEEd('es').format(past)),
        findsOneWidget,
      );
      Future<void> expectToday() async {
        expect(find.byType(CreateTaskScreen), findsOneWidget);
        final date = find.byKey(const ValueKey('task-date'));
        expect(
          find.descendant(
            of: date,
            matching: find.textContaining(calendar.weekdayDate(today)),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: date,
            matching: find.textContaining(calendar.weekdayDate(past)),
          ),
          findsNothing,
        );
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
      }

      await tester.tap(find.text(l.newTask).hitTestable());
      await tester.pumpAndSettle();
      await expectToday();

      await tester.tap(find.byKey(const ValueKey('calendar-format')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l.day).last);
      await tester.pumpAndSettle();
      expect(find.byType(DayTimelineScreen), findsOneWidget);
      await tester.tap(find.byTooltip(l.newTask));
      await tester.pumpAndSettle();
      await expectToday();
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
        await tester.tap(find.byTooltip(l.nextPeriod));
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
          selected: {workCalendar.selectionKey},
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
        find.descendant(
          of: line,
          matching: find.text(
            [
              l.calendarEventCount(1),
              context.clockTime(DateTime(now.year, now.month, now.day, 9)),
            ].join(' · '),
          ),
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
        'UX-447: when $what retry succeeds the line shows the event count with its icon and no spinner',
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
          expect(
            find.descendant(
              of: line,
              matching: find.text(
                [
                  l.calendarEventCount(1),
                  context.clockTime(DateTime(now.year, now.month, now.day, 9)),
                ].join(' · '),
              ),
            ),
            findsOneWidget,
          );
          expect(eventIcon(), findsOneWidget);
          expect(spinner(), findsNothing);
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
        // Once read, the day's event shows as usual.
        expect(eventIcon(), findsOneWidget);
        expect(spinner(), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  });
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
