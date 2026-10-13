import 'dart:io';
import 'dart:ui' as ui;
import 'package:agenda/l10n/region.dart';
import 'package:agenda/main.dart';
import 'package:agenda/models/checklist_item.dart';
import 'package:agenda/models/task.dart';
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
          expect(
            find.byTooltip(l.createVoiceTask).hitTestable(),
            findsOneWidget,
          );
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
  }) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final container = designContainer(
      regionalStore: MemoryRegionalStore(
        RegionalPreferences(language: language),
      ),
      tasks: () => _GivenTasks(tasks),
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const MyApp()),
    );
    await tester.pumpAndSettle();
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
          matching: find.textContaining(context.shortDate(yesterday)),
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
          matching: find.textContaining(context.shortDate(yesterday)),
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
      await tester.tap(find.widgetWithText(ActionChip, l.tomorrow));
      await tester.pumpAndSettle();
      final save = find.text(l.saveSchedule);
      await tester.ensureVisible(save);
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(
        Task.day(container.read(taskProvider).requireValue.single.dueDate!),
        DateTime(now.year, now.month, now.day + 1),
      );
      expect(find.text(l.scheduleUpdated), findsOneWidget);
      final bar = tester.widget<SnackBar>(find.byType(SnackBar));
      expect(bar.duration, const Duration(seconds: 10));
      expect(bar.behavior, SnackBarBehavior.floating);
      expect(find.text(l.undo), findsOneWidget);
      await tester.pump(const Duration(seconds: 9));
      expect(find.text(l.scheduleUpdated), findsOneWidget);
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(find.byType(SnackBar), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}

class _GivenTasks extends DesignTaskNotifier {
  _GivenTasks(this.initial);
  final List<Task> initial;
  @override
  Future<void> loadTasks() async {
    if (!state.hasValue) state = AsyncData(initial);
  }
}
