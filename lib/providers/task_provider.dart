import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:agenda/models/task.dart';
import 'package:agenda/repositories/task_repository.dart';
import 'package:agenda/services/task_database.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

// Notification plugin initialization
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

// Define a provider for TaskRepository
final taskRepositoryProvider = Provider<TaskRepository>((ref) {
  return TaskRepository(TaskDatabase());
});

// Define a StateNotifierProvider for managing tasks with AsyncValue
final taskProvider =
    StateNotifierProvider<TaskNotifier, AsyncValue<List<Task>>>((ref) {
  return TaskNotifier(ref.read(taskRepositoryProvider));
});

// TaskNotifier class to manage the state of the task list
class TaskNotifier extends StateNotifier<AsyncValue<List<Task>>> {
  final TaskRepository _taskRepository;

  TaskNotifier(this._taskRepository) : super(const AsyncValue.loading()) {
    loadTasks();
  }

  // Load tasks from the database
  Future<void> loadTasks() async {
    try {
      final tasks = await _taskRepository.getAllTasks();
      state = AsyncValue.data(tasks);
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
    }
  }

  // Add a new task and schedule important task notifications
  Future<void> addTask(Task task) async {
    try {
      // Get the generated task ID after inserting it into the database
      int taskId = await _taskRepository.addTask(task);

      // Update the task with the new ID
      task = task.copyWith(id: taskId);

      loadTasks(); // Refresh the task list

      // Schedule the important task reminder if the task is important
      if (task.priority == 3 && !task.isCompleted) {
        final tz.TZDateTime dueTime =
            tz.TZDateTime.from(task.dueDate, tz.local);
        final tz.TZDateTime reminderTime = dueTime.subtract(
            const Duration(minutes: 10)); // 10 minutes before due time
        if (kDebugMode) {
          print("notification time before function: $reminderTime");
        }

        if (reminderTime.isAfter(tz.TZDateTime.now(tz.local))) {
          // Schedule notification 10 minutes before due time
          try {
            await flutterLocalNotificationsPlugin.zonedSchedule(
              task.id!, // Use the updated task ID
              'Task Reminder',
              'Your important task "${task.title}" is due soon!',
              reminderTime,
              androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
              const NotificationDetails(
                android: AndroidNotificationDetails(
                  'important_task_channel', // Channel for important task notifications
                  'Important Task Reminders',
                  importance: Importance.max, // Set maximum importance
                  priority: Priority.high, // High priority notification
                  icon: 'app_notifications_icon',
                  fullScreenIntent:
                      true, // Ensure the notification shows on idle devices
                ),
              ),
              uiLocalNotificationDateInterpretation:
                  UILocalNotificationDateInterpretation.absoluteTime,
              matchDateTimeComponents: DateTimeComponents.time,
            );
            if (kDebugMode) {
              print("notification time after function: $reminderTime");
            }
          } catch (e) {
            if (kDebugMode) {
              print("Error scheduling notification: $e");
            }
          }
        } else {
          if (kDebugMode) {
            print("Reminder time is in the past, notification not scheduled.");
          }
        }
        if (kDebugMode) {
          print("Notification scheduling process completed.");
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error adding task: $e');
      }
    }
  }

  // Update a task and reschedule notifications if necessary
  Future<void> updateTask(Task updatedTask) async {
    try {
      await _taskRepository.updateTask(updatedTask);
      loadTasks(); // Refresh the task list

      // Cancel the old notification if it exists
      await flutterLocalNotificationsPlugin.cancel(updatedTask.id!);

      // Reschedule the notification for the updated task if it is important
      if (updatedTask.priority == 3 && !updatedTask.isCompleted) {
        final tz.TZDateTime dueTime =
            tz.TZDateTime.from(updatedTask.dueDate, tz.local);
        final tz.TZDateTime reminderTime = dueTime.subtract(
            const Duration(minutes: 10)); // 10 minutes before due time

        if (reminderTime.isAfter(tz.TZDateTime.now(tz.local))) {
          // Schedule new notification with updated due date
          try {
            await flutterLocalNotificationsPlugin.zonedSchedule(
              updatedTask.id!, // Use the updated task ID
              'Task Reminder',
              'Your important task "${updatedTask.title}" is due soon!',
              reminderTime,
              androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
              const NotificationDetails(
                android: AndroidNotificationDetails(
                  'important_task_channel',
                  'Important Task Reminders',
                  importance: Importance.max, // Set maximum importance
                  priority: Priority.high, // High priority notification
                  icon: 'app_notifications_icon',
                  fullScreenIntent:
                      true, // Ensure the notification shows on idle devices
                ),
              ),
              uiLocalNotificationDateInterpretation:
                  UILocalNotificationDateInterpretation.absoluteTime,
              matchDateTimeComponents: DateTimeComponents.time,
            );
          } catch (e) {
            if (kDebugMode) {
              print("Error rescheduling notification: $e");
            }
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error updating task: $e');
      }
    }
  }

  // Delete a task and cancel its notification
  Future<void> deleteTask(int taskId) async {
    try {
      await _taskRepository.deleteTask(taskId);
      loadTasks(); // Refresh the task list

      // Cancel the notification for the deleted task
      await flutterLocalNotificationsPlugin.cancel(taskId);
    } catch (e) {
      if (kDebugMode) {
        print('Error deleting task: $e');
      }
    }
  }
}
