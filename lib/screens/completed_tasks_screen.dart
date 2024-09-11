import 'package:agenda/widgets/custom_app_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:agenda/models/task.dart';
import 'package:agenda/providers/task_provider.dart';
import 'package:agenda/utils/constants.dart';

class CompletedTasksScreen extends ConsumerWidget {
  const CompletedTasksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final taskState = ref.watch(taskProvider);

    return Scaffold(
      appBar: const CustomAppBar(title: "Completed Tasks"),
      backgroundColor: defaultBackgroundColor,
      body: taskState.when(
        data: (tasks) {
          final completedTasks =
              tasks.where((task) => task.isCompleted).toList();
          if (completedTasks.isEmpty) {
            return const Center(
              child: Text(
                'No completed tasks.',
                style: TextStyle(color: Colors.white, fontSize: 18),
              ),
            );
          } else {
            return ListView.builder(
              itemCount: completedTasks.length,
              itemBuilder: (context, index) {
                final task = completedTasks[index];

                return Container(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 12.0,
                    vertical: 4.0,
                  ),
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(12.0),
                    border: Border(
                      left: BorderSide(
                        color: Colors
                            .green[700]!, // Green marker for completed tasks
                        width: 4.0,
                      ),
                    ),
                  ),
                  child: ListTile(
                    leading: Icon(
                      Icons.check,
                      color: Colors.green[700]!,
                    ),
                    title: Text(
                      task.title,
                      style: const TextStyle(
                        color: Colors.grey,
                        decoration: TextDecoration.lineThrough,
                      ),
                    ),
                    subtitle: Text(
                      task.notes ?? '',
                      style: TextStyle(color: subtitleTextColor),
                    ),
                    trailing: Checkbox(
                      value: task.isCompleted,
                      onChanged: (bool? value) {
                        // Toggle task completion
                        _toggleTaskCompletion(task, ref);
                      },
                      activeColor: Colors.green[700],
                      checkColor: Colors.white,
                      side: const BorderSide(color: Colors.white),
                    ),
                  ),
                );
              },
            );
          }
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(
          child: Text(
            'Error: $error',
            style: const TextStyle(color: Colors.red, fontSize: 18),
          ),
        ),
      ),
    );
  }

  void _toggleTaskCompletion(Task task, WidgetRef ref) {
    final taskNotifier = ref.read(taskProvider.notifier);
    final updatedTask = task.copyWith(isCompleted: !task.isCompleted);
    taskNotifier.updateTask(updatedTask);
  }
}
