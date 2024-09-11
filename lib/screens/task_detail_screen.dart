import 'package:agenda/providers/task_provider.dart';
import 'package:agenda/widgets/custom_app_bar.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:agenda/utils/constants.dart';
import 'package:intl/intl.dart';
import 'package:agenda/screens/edit_task_screen.dart';

class TaskDetailScreen extends ConsumerWidget {
  final int taskId;

  const TaskDetailScreen({super.key, required this.taskId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final taskState = ref.watch(taskProvider);

    return taskState.when(
      data: (tasks) {
        // Safely check if the task exists before trying to display it
        final task = tasks.firstWhereOrNull((task) => task.id == taskId);

        if (task == null) {
          // If the task doesn't exist, navigate back or show a message
          Future.microtask(() {
            // ignore: use_build_context_synchronously
            if (Navigator.canPop(context)) {
              // ignore: use_build_context_synchronously
              Navigator.of(context).pop();
            }
          });
          return const Center(
            child: Text(
              'Task not found.',
              style: TextStyle(color: Colors.white, fontSize: 18),
            ),
          );
        }

        return Scaffold(
          appBar: const CustomAppBar(
              title: 'Task Details'), // General title in AppBar
          backgroundColor: defaultBackgroundColor,
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.title, // Task title as the first item in the body
                  style: TextStyle(
                    color: textColor,
                    fontSize: 24.0,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16.0),
                _buildSection(
                  title: 'Due Date',
                  content: DateFormat('dd/MM/yyyy').format(task.dueDate),
                  icon: Icons.calendar_today,
                  iconColor: Colors.grey,
                ),
                _buildSection(
                  title: 'Time',
                  content: DateFormat('HH:mm').format(task.dueDate),
                  icon: Icons.access_time,
                  iconColor: Colors.lightBlueAccent,
                ),
                _buildSection(
                  title: 'Priority',
                  content: _priorityToString(task.priority),
                  icon: Icons.priority_high,
                  iconColor: _getPriorityColor(task.priority),
                ),
                _buildNotesSection(task.notes),
              ],
            ),
          ),
          floatingActionButton: _buildFloatingActionButton(context, ref),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => Center(
        child: Text(
          'Error: $error',
          style: const TextStyle(color: Colors.red, fontSize: 18),
        ),
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required String content,
    required IconData icon,
    required Color iconColor,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10.0),
      ),
      color: cardColor,
      elevation: 3,
      child: ListTile(
        leading: Icon(icon, color: iconColor),
        title: Text(
          title,
          style: TextStyle(
            color: textColor,
            fontSize: 18.0,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(
          content,
          style: TextStyle(
            color: subtitleTextColor,
            fontSize: 16.0,
          ),
        ),
      ),
    );
  }

  Widget _buildNotesSection(String? notes) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10.0),
      ),
      color: cardColor,
      elevation: 3,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Notes',
              style: TextStyle(
                color: textColor,
                fontSize: 18.0,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8.0),
            Text(
              notes ?? 'No notes added',
              style: TextStyle(
                color: subtitleTextColor,
                fontSize: 16.0,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFloatingActionButton(BuildContext context, WidgetRef ref) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        FloatingActionButton(
          heroTag: 'edit',
          backgroundColor: Colors.grey,
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => EditTaskScreen(taskId: taskId),
              ),
            );
          },
          child: const Icon(Icons.edit, color: Colors.white),
        ),
        const SizedBox(width: 16),
        FloatingActionButton(
          heroTag: 'delete',
          backgroundColor: Colors.red,
          onPressed: () {
            _confirmDelete(context, ref);
          },
          child: const Icon(Icons.delete, color: Colors.white),
        ),
      ],
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Task'),
          content: const Text('Are you sure you want to delete this task?'),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop(); // Dismiss the dialog
              },
            ),
            TextButton(
              child: const Text('Delete', style: TextStyle(color: Colors.red)),
              onPressed: () async {
                Navigator.of(context).pop(); // Dismiss the dialog

                // Trigger deletion
                await ref.read(taskProvider.notifier).deleteTask(taskId);
                // Navigate back after deletion
                // ignore: use_build_context_synchronously
                if (Navigator.canPop(context)) {
                  // ignore: use_build_context_synchronously
                  Navigator.of(context).pop();
                }
              },
            ),
          ],
        );
      },
    );
  }

  String _priorityToString(int priority) {
    switch (priority) {
      case 1:
        return 'Low';
      case 2:
        return 'Medium';
      case 3:
        return 'High';
      default:
        return 'Unknown';
    }
  }

  Color _getPriorityColor(int priority) {
    switch (priority) {
      case 1:
        return Colors.blueGrey;
      case 2:
        return Colors.amber;
      case 3:
        return Colors.deepOrange;
      default:
        return Colors.grey;
    }
  }
}
