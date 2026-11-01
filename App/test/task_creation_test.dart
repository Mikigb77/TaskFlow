import 'package:agenda/main.dart';
import 'package:agenda/providers/auth_provider.dart';
import 'package:agenda/models/task.dart';
import 'package:agenda/providers/task_provider.dart';
import 'package:agenda/repositories/task_repository.dart';
import 'package:agenda/screens/calendar_screen.dart';
import 'package:agenda/services/task_database.dart';
import 'package:agenda/widgets/task_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:agenda/providers/regional_provider.dart';
import 'support/design_fixtures.dart';
import 'package:agenda/l10n/generated/app_localizations.dart';

// The task form only edits: new tasks come from the capture sheet, so each
// test opens a saved task dated the 16th, with no time.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const timeoutChannel = MethodChannel('taskflow/accessibility');
  final platform =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  setUp(
    () => platform.setMockMethodCallHandler(timeoutChannel, (_) async => null),
  );
  tearDown(() => platform.setMockMethodCallHandler(timeoutChannel, null));
  testWidgets('a task saves the chosen date and time after form changes', (
    tester,
  ) async {
    final repository = await _pumpApp(tester);
    expect(find.byType(CalendarScreen), findsOneWidget);
    expect(
      tester.state<NavigatorState>(find.byType(Navigator)).canPop(),
      isFalse,
    );
    await _openCalendarTask(tester);
    await _pickDueDateTime(tester, const TimeOfDay(hour: 14, minute: 35));
    await _showDetails(tester);

    // Opening the keyboard changes inherited dependencies while editing.
    tester.view.viewInsets = const FakeViewPadding(bottom: 250);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'Afternoon task');
    await tester.enterText(
      find.byKey(const ValueKey('task-notes')),
      'Bring notes',
    );
    tester.view.resetViewInsets();
    await tester.pumpAndSettle();
    await _saveTask(tester);

    final savedTask = (await repository.getAllTasks()).single;
    final today = DateTime.now();
    expect(savedTask.title, 'Afternoon task');
    expect(savedTask.dueDate, DateTime(today.year, today.month, 16, 14, 35));
    expect(savedTask.notes, 'Bring notes');
    expect(find.byType(CalendarScreen), findsOneWidget);

    tester
        .state<NavigatorState>(find.byType(Navigator))
        .pushNamed('/taskDetails', arguments: savedTask.id);
    await tester.pumpAndSettle();
    // UX-2410 (P280): the time is part of the one «Planned for» row,
    // after the day, with no «Time» row of its own.
    expect(find.textContaining('14:35'), findsOneWidget);
  });

  testWidgets('reopening and cancelling the picker keeps the selected time', (
    tester,
  ) async {
    final repository = await _pumpApp(tester);
    await _openCalendarTask(tester);
    await _pickDueDateTime(tester, const TimeOfDay(hour: 18, minute: 20));

    await tester.tap(_dueDateField());
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<CalendarDatePicker>(find.byType(CalendarDatePicker))
          .initialDate!
          .day,
      16,
    );
    expect(
      tester
          .widget<TextFormField>(find.byKey(const ValueKey('schedule-hour')))
          .controller!
          .text,
      '18',
    );
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).first, 'Evening task');
    await _saveTask(tester);
    final savedTask = (await repository.getAllTasks()).single;
    expect(savedTask.dueDate!.day, 16);
    expect(savedTask.dueDate!.hour, 18);
    expect(savedTask.dueDate!.minute, 20);
  });

  testWidgets('an explicit midnight stays a timed task', (tester) async {
    final repository = await _pumpApp(tester);
    await _openCalendarTask(tester);
    await tester.enterText(find.byType(TextFormField).first, 'Midnight task');
    await _pickDueDateTime(tester, const TimeOfDay(hour: 0, minute: 0));
    await _saveTask(tester);
    final today = DateTime.now();
    expect(
      (await repository.getAllTasks()).single.dueDate,
      DateTime(today.year, today.month, 16),
    );
    expect((await repository.getAllTasks()).single.hasTime, isTrue);
  });

  testWidgets('a date-only task shows Any time, and a time can be removed', (
    tester,
  ) async {
    final repository = await _pumpApp(tester);
    await _openCalendarTask(tester);
    expect(find.textContaining('Any time'), findsOneWidget);
    await _pickDueDateTime(tester, const TimeOfDay(hour: 14, minute: 35));
    await tester.tap(_dueDateField());
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('schedule-has-time')));
    await tester.tap(find.byKey(const ValueKey('schedule-has-time')));
    await tester.tap(find.byKey(const ValueKey('schedule-done')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'Pay invoice');
    await _saveTask(tester);
    final task = (await repository.getAllTasks()).single;
    expect(task.hasTime, isFalse);
    expect(task.dueDate!.day, 16);
  });

  testWidgets('clearing the date moves the task to Inbox', (tester) async {
    final repository = await _pumpApp(tester);
    await _openCalendarTask(tester);
    // The date sheet's No date clears it; the form has no Clear date.
    expect(find.text('Clear date'), findsNothing);
    await tester.tap(_dueDateField());
    await tester.pumpAndSettle();
    await tester.tap(find.text('No date'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('schedule-done')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'Someday');
    await _saveTask(tester);
    expect((await repository.getAllTasks()).single.dueDate, isNull);
  });

  testWidgets('a date-only task can repeat weekly without acquiring a time', (
    tester,
  ) async {
    final repository = await _pumpApp(tester);
    await _openCalendarTask(tester);
    await _showDetails(tester);
    // Repetir opens the same repeat sheet as the capture result.
    await tester.ensureVisible(find.byKey(const ValueKey('task-repeat')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('task-repeat')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('repeat-weekly')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Done').last);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('task-title')),
      'Water plants',
    );
    await _saveTask(tester);
    final task = (await repository.getAllTasks()).single;
    expect(task.recurrence, 'weekly');
    expect(task.hasTime, isFalse);
    expect(
      task.occurrenceOn(task.dueDate!.add(const Duration(days: 7))),
      isNotNull,
    );
  });

  testWidgets(
    'UX-212: TaskEditor has no repeat dropdown; Repetir opens the repeat sheet',
    (tester) async {
      await _pumpApp(tester);
      final l = lookupAppLocalizations(const Locale('en'));
      await _openCalendarTask(tester);
      await _showDetails(tester);
      expect(find.byType(BottomSheet), findsNothing);
      // The editor itself offers no repeat dropdown.
      expect(find.byType(DropdownButtonFormField<String>), findsNothing);
      final repeat = find.byKey(const ValueKey('task-repeat'));
      await tester.ensureVisible(repeat);
      await tester.pumpAndSettle();
      await tester.tap(repeat);
      await tester.pumpAndSettle();
      final sheet = find.byType(BottomSheet);
      expect(sheet, findsOneWidget);
      expect(
        find.descendant(of: sheet, matching: find.text(l.repeat)),
        findsOneWidget,
      );
      // UX-2407: its five choices are rows, not a dropdown.
      expect(
        find.descendant(
          of: sheet,
          matching: find.byType(DropdownButtonFormField<String>),
        ),
        findsNothing,
      );
      expect(
        find.descendant(
          of: sheet,
          matching: find.byKey(const ValueKey('repeat-daily')),
        ),
        findsOneWidget,
      );
    },
  );
}

Future<void> _showDetails(WidgetTester tester) async {
  final button = find.byKey(const ValueKey('task-more-details'));
  await tester.ensureVisible(button);
  await tester.tap(button);
  await tester.pumpAndSettle();
}

Future<_MemoryTaskRepository> _pumpApp(WidgetTester tester) async {
  tester.view.physicalSize = const Size(800, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetViewInsets);

  final repository = _MemoryTaskRepository();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authProvider.overrideWith(
          (ref) => SignedInFixtureAuth(ref.read(apiClientProvider)),
        ),
        taskRepositoryProvider.overrideWithValue(repository),
        regionalStoreProvider.overrideWithValue(MemoryRegionalStore()),
      ],
      child: const MyApp(),
    ),
  );
  await tester.pumpAndSettle();
  return repository;
}

/// Opens the form on the saved task dated the 16th, with no time.
Future<void> _openCalendarTask(WidgetTester tester) async {
  final task = (await ProviderScope.containerOf(
    tester.element(find.byType(CalendarScreen)),
  ).read(taskRepositoryProvider).getAllTasks()).single;
  tester
      .state<NavigatorState>(find.byType(Navigator))
      .push(MaterialPageRoute<void>(builder: (_) => TaskEditor(task: task)));
  await tester.pumpAndSettle();
  expect(find.byType(TaskEditor), findsOneWidget);
}

Future<void> _pickDueDateTime(WidgetTester tester, TimeOfDay time) async {
  await tester.ensureVisible(_dueDateField());
  await tester.tap(_dueDateField());
  await tester.pumpAndSettle();
  // Use the day already selected on Calendar, without tapping it again here.
  await tester.ensureVisible(find.byKey(const ValueKey('schedule-has-time')));
  if (!tester
      .widget<SwitchListTile>(find.byKey(const ValueKey('schedule-has-time')))
      .value) {
    await tester.tap(find.byKey(const ValueKey('schedule-has-time')));
    await tester.pumpAndSettle();
  }
  final use24 = MediaQuery.alwaysUse24HourFormatOf(
    tester.element(find.byKey(const ValueKey('schedule-hour'))),
  );
  final hour = use24
      ? time.hour
      : (time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod);
  await tester.enterText(find.byKey(const ValueKey('schedule-hour')), '$hour');
  await tester.enterText(
    find.byKey(const ValueKey('schedule-minute')),
    time.minute.toString().padLeft(2, '0'),
  );
  if (!use24) {
    await tester.tap(find.text(time.period == DayPeriod.am ? 'AM' : 'PM'));
  }
  await tester.tap(find.byKey(const ValueKey('schedule-done')));
  await tester.pumpAndSettle();
  expect(find.byType(CalendarDatePicker), findsNothing);
}

Finder _dueDateField() => find.byKey(const ValueKey('task-date'));

Future<void> _saveTask(WidgetTester tester) async {
  final button = find.widgetWithText(ElevatedButton, 'Save changes');
  await tester.ensureVisible(button);
  await tester.tap(button);
  await tester.pumpAndSettle();
}

// Keep the real notifier and serialization, without platform database calls.
// It starts with one task, dated the 16th of this month, with no time.
class _MemoryTaskRepository extends TaskRepository {
  _MemoryTaskRepository() : super(TaskDatabase()) {
    final now = DateTime.now();
    _rows.add(
      Task(
        id: 1,
        title: 'Draft task',
        priority: 1,
        dueDate: DateTime(now.year, now.month, 16),
        hasTime: false,
      ).toMap(),
    );
  }

  final List<Map<String, dynamic>> _rows = [];

  @override
  Future<int> updateTask(Task task) async {
    final index = _rows.indexWhere((row) => row['id'] == task.id);
    _rows[index] = task.toMap();
    return 1;
  }

  @override
  Future<int> addTask(Task task) async {
    final id = _rows.length + 1;
    _rows.add(task.copyWith(id: id).toMap());
    return id;
  }

  @override
  Future<List<Task>> getAllTasks() async => _rows.map(Task.fromMap).toList();
}
