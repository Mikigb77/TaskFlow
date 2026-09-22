import 'package:agenda/main.dart';
import 'package:agenda/models/task.dart';
import 'package:agenda/providers/task_provider.dart';
import 'package:agenda/repositories/task_repository.dart';
import 'package:agenda/screens/calendar_screen.dart';
import 'package:agenda/screens/create_task_screen.dart';
import 'package:agenda/services/task_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:agenda/providers/regional_provider.dart';
import 'support/design_fixtures.dart';

void main() {
  testWidgets('calendar task saves the chosen date and time after form changes',
      (tester) async {
    final repository = await _pumpApp(tester);
    expect(find.byType(CalendarScreen), findsOneWidget);
    expect(
        tester.state<NavigatorState>(find.byType(Navigator)).canPop(), isFalse);
    await _openCalendarTask(tester);
    await _pickDueDateTime(tester, const TimeOfDay(hour: 14, minute: 35));
    await _showDetails(tester);

    // Opening the keyboard changes inherited dependencies while editing.
    tester.view.viewInsets = const FakeViewPadding(bottom: 250);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'Afternoon task');
    await tester.enterText(find.byType(TextFormField).last, 'Bring notes');
    tester.view.resetViewInsets();
    await tester.pumpAndSettle();
    await _saveTask(tester);

    final savedTask = (await repository.getAllTasks()).single;
    final today = DateTime.now();
    expect(savedTask.dueDate, DateTime(today.year, today.month, 16, 14, 35));
    expect(savedTask.notes, 'Bring notes');
    expect(find.byType(CalendarScreen), findsOneWidget);

    tester.state<NavigatorState>(find.byType(Navigator)).pushNamed(
          '/taskDetails',
          arguments: savedTask.id,
        );
    await tester.pumpAndSettle();
    expect(find.text('14:35'), findsOneWidget);
  });

  testWidgets('reopening and cancelling the picker keeps the selected time',
      (tester) async {
    final repository = await _pumpApp(tester);
    await _openCalendarTask(tester);
    await _pickDueDateTime(tester, const TimeOfDay(hour: 18, minute: 20));

    await tester.tap(_dueDateField());
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<DatePickerDialog>(find.byType(DatePickerDialog))
            .initialDate
            ?.day,
        16);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('task-time')));
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<TimePickerDialog>(find.byType(TimePickerDialog))
            .initialTime,
        const TimeOfDay(hour: 18, minute: 20));
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).first, 'Evening task');
    await _saveTask(tester);
    final savedTask = (await repository.getAllTasks()).single;
    expect(savedTask.dueDate!.day, 16);
    expect(savedTask.dueDate!.hour, 18);
    expect(savedTask.dueDate!.minute, 20);
  });

  testWidgets('creation without a calendar date saves to Inbox',
      (tester) async {
    final repository = await _pumpApp(tester);
    await _selectCalendarDay(tester, 15);
    tester
        .state<NavigatorState>(find.byType(Navigator))
        .pushNamed('/createTask');
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'Buy coffee');
    await _saveTask(tester);
    expect((await repository.getAllTasks()).single.dueDate, isNull);
    expect((await repository.getAllTasks()).single.hasTime, isFalse);
  });

  testWidgets('an explicit midnight stays a timed task', (tester) async {
    final repository = await _pumpApp(tester);
    await _openCalendarTask(tester);
    await tester.enterText(find.byType(TextFormField).first, 'Midnight task');
    await _pickDueDateTime(tester, const TimeOfDay(hour: 0, minute: 0));
    await _saveTask(tester);
    final today = DateTime.now();
    expect((await repository.getAllTasks()).single.dueDate,
        DateTime(today.year, today.month, 16));
    expect((await repository.getAllTasks()).single.hasTime, isTrue);
  });

  testWidgets('quick capture saves plain text without expanding details',
      (tester) async {
    final repository = await _pumpApp(tester);
    tester
        .state<NavigatorState>(find.byType(Navigator))
        .pushNamed('/createTask');
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('task-notes')), findsNothing);
    await tester.enterText(
        find.byKey(const ValueKey('task-title')), 'Buy coffee');
    await _saveTask(tester);
    final task = (await repository.getAllTasks()).single;
    expect(task.title, 'Buy coffee');
    expect(task.dueDate, isNull);
  });

  testWidgets('schedule suggestion can be dismissed without changing the title',
      (tester) async {
    final repository = await _pumpApp(tester);
    tester
        .state<NavigatorState>(find.byType(Navigator))
        .pushNamed('/createTask');
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const ValueKey('task-title')), 'Call tomorrow at 5 pm');
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('schedule-suggestion')), findsOneWidget);
    await tester.tap(find.text('Keep as title'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('schedule-suggestion')), findsNothing);
    await _saveTask(tester);
    final task = (await repository.getAllTasks()).single;
    expect(task.title, 'Call tomorrow at 5 pm');
    expect(task.dueDate, isNull);
  });

  testWidgets(
      'accepted schedule is reversible and an ambiguous hour stays unset',
      (tester) async {
    final repository = await _pumpApp(tester);
    tester
        .state<NavigatorState>(find.byType(Navigator))
        .pushNamed('/createTask');
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const ValueKey('task-title')), 'Call tomorrow at 5 pm');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('schedule-suggestion')));
    await tester.pumpAndSettle();
    expect(find.text('Call'), findsOneWidget);
    expect(find.text('17:00'), findsOneWidget);
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(find.text('Call tomorrow at 5 pm'), findsOneWidget);
    expect(find.text('No date · Inbox'), findsOneWidget);
    await tester.enterText(
        find.byKey(const ValueKey('task-title')), 'Call tomorrow at 5');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('schedule-suggestion')));
    await tester.pumpAndSettle();
    await _saveTask(tester);
    final task = (await repository.getAllTasks()).single;
    final now = DateTime.now();
    expect(task.title, 'Call at 5');
    expect(task.dueDate, DateTime(now.year, now.month, now.day + 1));
    expect(task.hasTime, isFalse);
  });

  testWidgets('calendar day defaults to date only and time can be removed',
      (tester) async {
    final repository = await _pumpApp(tester);
    await _openCalendarTask(tester);
    expect(find.text('Any time'), findsOneWidget);
    await _pickDueDateTime(tester, const TimeOfDay(hour: 14, minute: 35));
    await tester.tap(find.byTooltip('Remove time'));
    await tester.enterText(find.byType(TextFormField).first, 'Pay invoice');
    await _saveTask(tester);
    final task = (await repository.getAllTasks()).single;
    expect(task.hasTime, isFalse);
    expect(task.dueDate!.day, 16);
  });

  testWidgets('clearing a calendar date moves the task to Inbox',
      (tester) async {
    final repository = await _pumpApp(tester);
    await _openCalendarTask(tester);
    await tester.tap(find.byTooltip('Clear date'));
    await tester.enterText(find.byType(TextFormField).first, 'Someday');
    await _saveTask(tester);
    expect((await repository.getAllTasks()).single.dueDate, isNull);
  });

  testWidgets('a date-only task can repeat weekly without acquiring a time',
      (tester) async {
    final repository = await _pumpApp(tester);
    await _openCalendarTask(tester);
    await _showDetails(tester);
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Weekly').last);
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const ValueKey('task-title')), 'Water plants');
    await _saveTask(tester);
    final task = (await repository.getAllTasks()).single;
    expect(task.recurrence, 'weekly');
    expect(task.hasTime, isFalse);
    expect(task.occurrenceOn(task.dueDate!.add(const Duration(days: 7))),
        isNotNull);
  });
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
  await tester.pumpWidget(ProviderScope(
    overrides: [
      taskRepositoryProvider.overrideWithValue(repository),
      regionalStoreProvider.overrideWithValue(MemoryRegionalStore())
    ],
    child: const MyApp(),
  ));
  await tester.pumpAndSettle();
  return repository;
}

Future<void> _selectCalendarDay(WidgetTester tester, int day) async {
  if (find.text('Month view').evaluate().isNotEmpty) {
    await tester.tap(find.byKey(const ValueKey('calendar-format')));
    await tester.pumpAndSettle();
  }
  await tester.tap(find
      .descendant(of: find.byType(CalendarScreen), matching: find.text('$day'))
      .hitTestable());
  await tester.pumpAndSettle();
}

Future<void> _openCalendarTask(WidgetTester tester) async {
  await _selectCalendarDay(tester, 15);
  await tester.tap(find.byTooltip('Create task'));
  await tester.pumpAndSettle();
  expect(find.byType(CreateTaskScreen), findsOneWidget);
}

Future<void> _pickDueDateTime(WidgetTester tester, TimeOfDay time) async {
  await tester.tap(_dueDateField());
  await tester.pumpAndSettle();
  await tester.tap(find.descendant(
    of: find.byType(DatePickerDialog),
    matching: find.text('16'),
  ));
  await tester.tap(find.text('OK'));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('task-time')));
  await tester.pumpAndSettle();
  final use24HourFormat = MediaQuery.alwaysUse24HourFormatOf(
      tester.element(find.byType(TimePickerDialog)));
  await tester.tap(find.byIcon(Icons.keyboard_outlined));
  await tester.pumpAndSettle();
  final timeFields = find.descendant(
    of: find.byType(TimePickerDialog),
    matching: find.byType(TextFormField),
  );
  final hour = use24HourFormat
      ? time.hour
      : (time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod);
  await tester.enterText(timeFields.at(0), hour.toString().padLeft(2, '0'));
  await tester.enterText(
      timeFields.at(1), time.minute.toString().padLeft(2, '0'));
  if (!use24HourFormat) {
    await tester.tap(find.text(time.period == DayPeriod.am ? 'AM' : 'PM'));
  }
  await tester.tap(find.text('OK'));
  await tester.pumpAndSettle();
  expect(find.byType(TimePickerDialog), findsNothing);
}

Finder _dueDateField() => find.byKey(const ValueKey('task-date'));

Future<void> _saveTask(WidgetTester tester) async {
  final button = find.widgetWithText(ElevatedButton, 'Create Task');
  await tester.ensureVisible(button);
  await tester.tap(button);
  await tester.pumpAndSettle();
}

// Keep the real notifier and serialization, without platform database calls.
class _MemoryTaskRepository extends TaskRepository {
  _MemoryTaskRepository() : super(TaskDatabase());

  final List<Map<String, dynamic>> _rows = [];

  @override
  Future<int> addTask(Task task) async {
    final id = _rows.length + 1;
    _rows.add(task.copyWith(id: id).toMap());
    return id;
  }

  @override
  Future<List<Task>> getAllTasks() async => _rows.map(Task.fromMap).toList();
}
