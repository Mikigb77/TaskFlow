import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Where a just-saved task went: Calendar selects [day], scrolls to the task's
/// row and highlights it.
class CalendarFocus {
  const CalendarFocus(this.day, this.taskId);
  final DateTime day;
  final int taskId;
}

/// Set after a save to bring Calendar to the new task. Each save sets a new
/// value, which Calendar listens for.
final calendarFocusProvider = StateProvider<CalendarFocus?>((ref) => null);

/// The time Calendar reads to decide what "today" is. Tests replace it to
/// cross midnight.
final calendarClockProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
);
