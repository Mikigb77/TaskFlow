import 'package:agenda/repositories/task_repository.dart';
import 'package:agenda/services/task_database.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
// Import the provider for TaskRepository
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter/material.dart'; // Import TimeOfDay for time handling
// Import for Riverpod

// Notification plugin initialization
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

// Schedule Morning Notification at 8:00 AM
Future<void> scheduleMorningNotification() async {
  final tasks = await TaskRepository(TaskDatabase()).getTasksForNextThreeDays();

  if (tasks.isNotEmpty) {
    String taskList = tasks
        .take(3)
        .map((task) =>
            "${task.title}: due in ${task.dueDate.difference(DateTime.now()).inDays} days")
        .join(", ");

    await flutterLocalNotificationsPlugin.zonedSchedule(
      -1,
      'Good Morning!',
      'Here are your upcoming tasks: $taskList',
      _nextInstanceOfTime(const TimeOfDay(hour: 8, minute: 0)), // 8:00 AM
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'morning_channel',
          'Morning Reminders',
          icon: 'app_notifications_icon',
        ),
      ),
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }
}

// Schedule Evening Notification at 8:00 PM
Future<void> scheduleEveningNotification() async {
  final tasks = await TaskRepository(TaskDatabase()).getTasksForNextThreeDays();

  if (tasks.isNotEmpty) {
    String taskList = tasks
        .take(3)
        .map((task) =>
            "${task.title}: due in ${task.dueDate.difference(DateTime.now()).inDays} days")
        .join(", ");

    await flutterLocalNotificationsPlugin.zonedSchedule(
      -2,
      'Evening Check-in',
      'Did you make progress on these tasks: $taskList? Consider rescheduling if needed.',
      _nextInstanceOfTime(const TimeOfDay(hour: 20, minute: 0)), // 8:00 PM
      const NotificationDetails(
          android: AndroidNotificationDetails(
        'evening_channel',
        'Evening Reminders',
        icon: 'app_notifications_icon',
      )),
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }
}

// Helper function to get the next instance of a specific time
tz.TZDateTime _nextInstanceOfTime(TimeOfDay timeOfDay) {
  final now = tz.TZDateTime.now(tz.local);
  final nextInstance = tz.TZDateTime(
    tz.local,
    now.year,
    now.month,
    now.day,
    timeOfDay.hour,
    timeOfDay.minute,
  );

  return nextInstance.isBefore(now)
      ? nextInstance.add(const Duration(days: 1))
      : nextInstance;
}
