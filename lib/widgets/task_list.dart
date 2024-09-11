import 'package:flutter/material.dart';
import 'package:agenda/models/task.dart';
import 'package:agenda/utils/constants.dart';
import 'package:intl/intl.dart';
import 'package:agenda/screens/task_detail_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:agenda/providers/task_provider.dart';

class TaskList extends ConsumerWidget {
  final List<Task> tasks;

  const TaskList({
    super.key,
    required this.tasks,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final taskNotifier = ref.read(taskProvider.notifier);

    final sortedTasks = _getSortedTasks(tasks);

    return ListView.builder(
      itemCount: sortedTasks.length,
      itemBuilder: (context, index) {
        final task = sortedTasks[index];
        return Dismissible(
          key: Key(task.id.toString()),
          direction: DismissDirection.endToStart,
          confirmDismiss: (direction) async {
            return await _confirmDelete(context);
          },
          onDismissed: (direction) {
            taskNotifier.deleteTask(task.id!);
          },
          background: Container(
            color: Colors.red,
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: const Icon(Icons.delete, color: Colors.white),
          ),
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(12.0),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  spreadRadius: 1,
                  blurRadius: 3,
                  offset: const Offset(0, 2),
                ),
              ],
              border: Border(
                left: BorderSide(
                  color: _getPriorityColor(task.priority),
                  width: 4.0,
                ),
              ),
            ),
            child: ListTile(
              leading: Icon(
                _getPriorityIcon(task.priority),
                color: _getPriorityColor(task.priority),
              ),
              title: Text(
                task.title,
                style: TextStyle(color: textColor),
              ),
              subtitle: Text(
                DateFormat('dd/MM, hh:mm a').format(task.dueDate),
                style: TextStyle(color: subtitleTextColor),
              ),
              trailing: IconButton(
                icon: Icon(
                  task.isCompleted
                      ? Icons.check_box
                      : Icons.check_box_outline_blank,
                  color: task.isCompleted ? accentColor : subtitleTextColor,
                ),
                onPressed: () {
                  final updatedTask =
                      task.copyWith(isCompleted: !task.isCompleted);
                  taskNotifier.updateTask(updatedTask);
                },
              ),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => TaskDetailScreen(taskId: task.id!),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Color _getPriorityColor(int priority) {
    switch (priority) {
      case 1:
        return Colors.blueGrey[700]!;
      case 2:
        return Colors.amber[700]!;
      case 3:
        return Colors.deepOrange[900]!;
      default:
        return Colors.grey[700]!;
    }
  }

  IconData _getPriorityIcon(int priority) {
    switch (priority) {
      case 1:
        return Icons.low_priority;
      case 2:
        return Icons.flag;
      case 3:
        return Icons.priority_high;
      default:
        return Icons.label;
    }
  }

  Future<bool?> _confirmDelete(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Task'),
          content: const Text('Are you sure you want to delete this task?'),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context)
                    .pop(false); // Dismiss the dialog and don't delete
              },
            ),
            TextButton(
              child: const Text('Delete', style: TextStyle(color: Colors.red)),
              onPressed: () {
                Navigator.of(context).pop(true); // Confirm the deletion
              },
            ),
          ],
        );
      },
    );
  }

  List<Task> _getSortedTasks(List<Task> tasks) {
    List<Task> sortedTasks = List.from(tasks);

    sortedTasks.sort((a, b) {
      bool aIsOverdue = a.dueDate.isBefore(DateTime.now()) && !a.isCompleted;
      bool bIsOverdue = b.dueDate.isBefore(DateTime.now()) && !b.isCompleted;

      if (aIsOverdue && !bIsOverdue) return -1;
      if (!aIsOverdue && bIsOverdue) return 1;

      if (a.isCompleted && !b.isCompleted) return 1;
      if (!a.isCompleted && b.isCompleted) return -1;
      if (a.isCompleted && b.isCompleted) return 0;

      int aScore = _calculateTaskScore(a);
      int bScore = _calculateTaskScore(b);
      return bScore.compareTo(aScore);
    });

    return sortedTasks;
  }

  int _calculateTaskScore(Task task) {
    const int priorityWeight = 3;
    const int urgencyWeight = 1;

    int priorityScore = task.priority * priorityWeight;

    int daysUntilDue = task.dueDate.difference(DateTime.now()).inDays;
    int urgencyScore = (daysUntilDue <= 0)
        ? 100
        : (30 - daysUntilDue).clamp(0, 30) * urgencyWeight;

    return priorityScore + urgencyScore;
  }
}
