import 'dart:io';
import 'package:agenda/models/task.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';
import 'package:timezone/timezone.dart' as tz;

class TaskReminders {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static Future<void> _queue = Future.value();
  static int _generation = 0;

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
        final upcoming = tasks
            .where((task) => !task.isCompleted && task.dueDate.isAfter(now))
            .toList()
          ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
        for (final task in upcoming
            .where((t) => t.priority == 3 && t.id != null)
            .take(50)) {
          if (generation != _generation) return;
          final when = tz.TZDateTime.from(task.dueDate, tz.local)
              .subtract(const Duration(minutes: 10));
          if (when.isAfter(now)) {
            await _schedule(task.id!, 'Task Reminder',
                '${task.title} is due in 10 minutes.', when);
          }
        }
        if (upcoming.isEmpty || generation != _generation) return;
        final summary = upcoming
            .take(3)
            .map((task) =>
                '${task.title}: ${DateFormat('dd/MM HH:mm').format(task.dueDate)}')
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
              daily: true);
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
