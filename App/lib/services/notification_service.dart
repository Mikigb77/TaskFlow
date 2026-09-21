import 'dart:io';
import 'package:agenda/models/task.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:agenda/widgets/task_schedule_label.dart';
import 'package:timezone/timezone.dart' as tz;

class TaskReminders {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static Future<void> _queue = Future.value();
  static int _generation = 0;

  /// A bounded window replenished on launch, resume and task changes.
  static List<Task> upcoming(List<Task> tasks, DateTime now) {
    final result = <Task>[];
    for (final task in tasks) {
      if (task.isRecurring) {
        for (var offset = 0; offset <= 60; offset++) {
          final occurrence = task
              .occurrenceOn(DateTime(now.year, now.month, now.day + offset));
          if (occurrence != null &&
              !occurrence.isCompleted &&
              (occurrence.hasTime
                  ? occurrence.displayDate!.isAfter(now)
                  : !Task.day(occurrence.displayDate!)
                      .isBefore(Task.day(now)))) {
            result.add(occurrence);
          }
        }
      } else if (!task.isCompleted &&
          task.dueDate != null &&
          (task.hasTime
              ? task.dueDate!.isAfter(now)
              : !Task.day(task.dueDate!).isBefore(Task.day(now)))) {
        result.add(task);
      }
    }
    return result..sort(Task.compareBySchedule);
  }

  static Future<void> sync(List<Task> tasks) {
    final generation = ++_generation;
    _queue = _queue.catchError((_) {}).then((_) async {
      if (generation != _generation ||
          !(Platform.isAndroid || Platform.isIOS)) {
        return;
      }
      try {
        await _plugin.cancelAll();
        final now = tz.TZDateTime.now(tz.local);
        final scheduled = upcoming(tasks, now);
        var notificationId = 1;
        for (final task
            in scheduled.where((t) => t.priority == 3 && t.hasTime).take(50)) {
          if (generation != _generation) return;
          final when = tz.TZDateTime.from(task.displayDate!, tz.local)
              .subtract(const Duration(minutes: 10));
          if (when.isAfter(now)) {
            await _schedule(notificationId++, 'Task Reminder',
                '${task.title} is due in 10 minutes.', when);
          }
        }
        if (scheduled.isEmpty || generation != _generation) return;
        final summary = scheduled
            .take(3)
            .map((task) => '${task.title}: ${taskScheduleLabel(task)}')
            .join('\n');
        for (final hour in [8, 20]) {
          if (generation != _generation) return;
          var when =
              tz.TZDateTime(tz.local, now.year, now.month, now.day, hour);
          if (!when.isAfter(now)) {
            when =
                tz.TZDateTime(tz.local, now.year, now.month, now.day + 1, hour);
          }
          await _schedule(hour == 8 ? -1 : -2,
              hour == 8 ? 'Good Morning!' : 'Evening Check-in', summary, when,
              daily: false);
        }
      } catch (_) {
        /* Saved tasks remain usable when notification permission is denied. */
      }
    });
    return _queue;
  }

  static Future<void> _schedule(
          int id, String title, String body, tz.TZDateTime when,
          {bool daily = false}) =>
      _plugin.zonedSchedule(
        id,
        title,
        body,
        when,
        const NotificationDetails(
          android: AndroidNotificationDetails(
              'taskflow_reminders', 'Task reminders',
              importance: Importance.high,
              priority: Priority.high,
              icon: 'app_notifications_icon'),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: daily ? DateTimeComponents.time : null,
      );
}
