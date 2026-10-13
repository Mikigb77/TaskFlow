import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Where just-saved tasks went: Calendar selects [day], scrolls to the tasks'
/// rows and highlights them. With no [day] the tasks have no date, and
/// Calendar highlights its no-date row instead.
class CalendarFocus {
  const CalendarFocus(
    this.day,
    this.taskIds, {
    this.page,
    this.showCalendar = false,
  });
  final DateTime? day;
  final Set<int> taskIds;

  /// The task page (Tareas, a project) that opened capture. It shows the tasks
  /// itself, and Calendar stays as it is.
  final Object? page;

  /// Bring the Calendar tab forward first, as after saving from the pending
  /// list.
  final bool showCalendar;
}

/// Set after a save to bring Calendar, or the page that saved, to the new
/// tasks. Each save sets a new value, which they listen for.
final calendarFocusProvider = StateProvider<CalendarFocus?>((ref) => null);

/// The time Calendar reads to decide what "today" is. Tests replace it to
/// cross midnight.
final calendarClockProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
);
