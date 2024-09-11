import 'package:agenda/screens/task_detail_screen.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:agenda/screens/home_screen.dart';
import 'package:agenda/screens/completed_tasks_screen.dart';
import 'package:agenda/screens/create_task_screen.dart';
import 'package:agenda/screens/calendar_screen.dart';
import 'package:agenda/screens/edit_task_screen.dart'; // Import the edit task screen
import 'package:flutter_local_notifications/flutter_local_notifications.dart'; // Import for local notifications
import 'package:timezone/data/latest.dart' as tz; // Import for timezone setup
import 'package:timezone/timezone.dart' as tz;
import 'package:agenda/repositories/task_repository.dart'; // Import the task repository
import 'package:agenda/services/task_database.dart'; // Import the task database
import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart'; // Import device_info_plus for Android version check

// Notification plugin initialization
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

// Task cleanup function to delete tasks overdue by 4 months
Future<void> cleanupOldTasks() async {
  final taskRepository = TaskRepository(TaskDatabase());

  // Get tasks that are overdue by more than 4 months
  final overdueTasks = await taskRepository.getTasksOverdueByFourMonths();

  if (overdueTasks.isNotEmpty) {
    final taskIdsToDelete = overdueTasks.map((task) => task.id!).toList();

    // Delete the overdue tasks
    await taskRepository.deleteTasks(taskIdsToDelete);
    if (kDebugMode) {
      print("Deleted ${taskIdsToDelete.length} overdue tasks.");
    }
  } else {
    if (kDebugMode) {
      print("No overdue tasks to delete.");
    }
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize timezone
  tz.initializeTimeZones();

  // Notification settings for Android
  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('app_icon');

  // Initialize settings for notifications
  const InitializationSettings initializationSettings =
      InitializationSettings(android: initializationSettingsAndroid);

  // Request notification permissions for Android 13+ (API level 33+)
  if (Platform.isAndroid && await _isAndroid13OrAbove()) {
    await _requestNotificationPermissionForAndroid13();
  }

  // Request exact alarm permission for Android 12+ (API level 31+)
  if (Platform.isAndroid && await _isAndroid12OrAbove()) {
    await _requestExactAlarmPermission();
  }

  // Initialize notifications
  await flutterLocalNotificationsPlugin.initialize(initializationSettings);

  // Perform task cleanup on app start
  await cleanupOldTasks(); // Clean up overdue tasks (older than 4 months)

  // Schedule the regular notifications
  await scheduleMorningNotification();
  await scheduleEveningNotification();

  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
}

// Function to schedule the morning notification
Future<void> scheduleMorningNotification() async {
  final tasks = await TaskRepository(TaskDatabase()).getTasksForNextThreeDays();

  if (tasks.isNotEmpty) {
    String taskList = tasks
        .take(3) // Limit to 3 tasks
        .map((task) {
      final timeDifference = task.dueDate.difference(DateTime.now());

      if (timeDifference.inDays == 0) {
        // Task due today: show hours and minutes
        int hours = timeDifference.inHours;
        int minutes = timeDifference.inMinutes % 60;
        return "• ${task.title}: Deadline in ${hours}h ${minutes}min";
      } else {
        // Task due in future: show days
        return "• ${task.title}: Due in ${timeDifference.inDays} days";
      }
    }).join("\n"); // Newline for each task with a bullet point

    String notificationMessage =
        "Stay on track! Here are your upcoming tasks:\n$taskList";

    await flutterLocalNotificationsPlugin.zonedSchedule(
      -1, // Use -1 for morning notification
      'Good Morning!',
      notificationMessage, // Add the formatted task list
      _nextInstanceOfTime(const TimeOfDay(hour: 8, minute: 0)), // 8:00 AM
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'morning_channel',
          'Morning Reminders',
          importance: Importance.max,
          priority: Priority.high,
          icon: 'app_notifications_icon',
        ),
      ),
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }
}

// Function to schedule the evening notification
Future<void> scheduleEveningNotification() async {
  final tasks = await TaskRepository(TaskDatabase()).getTasksForNextThreeDays();

  if (tasks.isNotEmpty) {
    String taskList = tasks
        .take(3) // Limit to 3 tasks
        .map((task) {
      final timeDifference = task.dueDate.difference(DateTime.now());

      if (timeDifference.inDays == 0) {
        // Task due today: show hours and minutes
        int hours = timeDifference.inHours;
        int minutes = timeDifference.inMinutes % 60;
        return "• ${task.title}: Deadline in ${hours}h ${minutes}min";
      } else {
        // Task due in future: show days
        return "• ${task.title}: Due in ${timeDifference.inDays} days";
      }
    }).join("\n"); // Newline for each task with a bullet point

    String notificationMessage =
        "Time to wrap up! Did you progress on these tasks?\n$taskList";

    await flutterLocalNotificationsPlugin.zonedSchedule(
      -2, // Use -2 for evening notification
      'Evening Check-in',
      notificationMessage, // Add the formatted task list
      _nextInstanceOfTime(const TimeOfDay(hour: 20, minute: 0)), // 8:00 PM
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'evening_channel',
          'Evening Reminders',
          importance: Importance.max,
          priority: Priority.high,
          icon: 'app_notifications_icon',
        ),
      ),
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
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

// Helper function to request notification permission for Android 13+
Future<void> _requestNotificationPermissionForAndroid13() async {
  var androidFlutterLocalNotificationsPlugin =
      flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

  if (androidFlutterLocalNotificationsPlugin != null) {
    await androidFlutterLocalNotificationsPlugin
        .requestNotificationsPermission();
  }
}

// Helper function to check if the device is running Android 13 or above
Future<bool> _isAndroid13OrAbove() async {
  final int sdkInt = await _getSdkInt();
  return sdkInt >= 33;
}

// Helper function to check if the device is running Android 12 or above
Future<bool> _isAndroid12OrAbove() async {
  final int sdkInt = await _getSdkInt();
  return sdkInt >= 31;
}

// Helper function to request the SCHEDULE_EXACT_ALARM permission
Future<void> _requestExactAlarmPermission() async {
  var androidFlutterLocalNotificationsPlugin =
      flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
  if (androidFlutterLocalNotificationsPlugin != null) {
    await androidFlutterLocalNotificationsPlugin.requestExactAlarmsPermission();
  }
}

// Helper function to get the Android SDK version
Future<int> _getSdkInt() async {
  if (Platform.isAndroid) {
    var androidInfo = await DeviceInfoPlugin().androidInfo;
    return androidInfo.version.sdkInt;
  }
  return 0;
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TaskFlow',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: Colors.grey[900], // Dark theme background
        textTheme: const TextTheme(
          bodyMedium: TextStyle(color: Colors.white),
        ),
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const HomeScreen(),
        '/home': (context) => const HomeScreen(),
        '/completedTasks': (context) => const CompletedTasksScreen(),
        '/createTask': (context) => const CreateTaskScreen(),
        '/calendar': (context) => const CalendarScreen(),
      },
      onGenerateRoute: (settings) {
        if (settings.name == '/taskDetails') {
          final int taskId = settings.arguments as int; // Receive task ID
          return MaterialPageRoute(
            builder: (context) => TaskDetailScreen(taskId: taskId),
          );
        }
        if (settings.name == '/editTask') {
          final int taskId = settings.arguments as int;
          return MaterialPageRoute(
            builder: (context) => EditTaskScreen(taskId: taskId),
          );
        }
        return null;
      },
    );
  }
}
