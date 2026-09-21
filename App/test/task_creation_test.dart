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

void main() {
  testWidgets('calendar task saves the chosen date and time after form changes',
      (tester) async {
    final repository = await _pumpApp(tester);
    expect(find.byType(CalendarScreen), findsOneWidget);
    expect(
        tester.state<NavigatorState>(find.byType(Navigator)).canPop(), isFalse);
    await _openCalendarTask(tester);
    await _pickDueDateTime(tester, const TimeOfDay(hour: 14, minute: 35));

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
    expect(savedTask.dueDate.day, 16);
    expect(savedTask.dueDate.hour, 18);
    expect(savedTask.dueDate.minute, 20);
  });

  testWidgets(
      'creation without a calendar date requires a date and accepts midnight',
      (tester) async {
    final repository = await _pumpApp(tester);
    await _selectCalendarDay(tester, 15);
    tester
        .state<NavigatorState>(find.byType(Navigator))
        .pushNamed('/createTask');
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'Midnight task');
    await _saveTask(tester);
    expect(find.text('Please pick a due date and time'), findsOneWidget);
    expect(await repository.getAllTasks(), isEmpty);

    await _pickDueDateTime(tester, const TimeOfDay(hour: 0, minute: 0));
    await _saveTask(tester);
    final today = DateTime.now();
    expect((await repository.getAllTasks()).single.dueDate,
        DateTime(today.year, today.month, 16));
  });
}

Future<_MemoryTaskRepository> _pumpApp(WidgetTester tester) async {
  tester.view.physicalSize = const Size(800, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetViewInsets);

  final repository = _MemoryTaskRepository();
  await tester.pumpWidget(ProviderScope(
    overrides: [taskRepositoryProvider.overrideWithValue(repository)],
    child: const MyApp(),
  ));
  await tester.pumpAndSettle();
  return repository;
}

Future<void> _selectCalendarDay(WidgetTester tester, int day) async {
  await tester.tap(find
      .descendant(of: find.byType(CalendarScreen), matching: find.text('$day'))
      .hitTestable());
  await tester.pumpAndSettle();
}

Future<void> _openCalendarTask(WidgetTester tester) async {
  await _selectCalendarDay(tester, 15);
  await tester.tap(find.byIcon(Icons.add));
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

Finder _dueDateField() => find.byWidgetPredicate(
    (widget) => widget is GestureDetector && widget.child is AbsorbPointer);

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
