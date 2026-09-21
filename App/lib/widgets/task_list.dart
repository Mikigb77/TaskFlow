import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:agenda/models/task.dart';
import 'package:agenda/providers/task_provider.dart';
import 'package:agenda/widgets/task_tile.dart';

class TaskList extends ConsumerWidget {
  const TaskList({super.key, required this.tasks});
  final List<Task> tasks;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sorted = [...tasks]..sort(Task.compareBySchedule);
    final colors = Theme.of(context).colorScheme;
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
      itemCount: sorted.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final task = sorted[index];
        return Dismissible(
            key: ValueKey('${task.id}:${task.occurrenceDate}'),
            direction: DismissDirection.endToStart,
            confirmDismiss: (_) async {
              final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                          title: const Text('Delete task?'),
                          content: Text(task.isRecurring
                              ? '“${task.title}” and all its occurrences will be removed.'
                              : '“${task.title}” will be removed.'),
                          actions: [
                            TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text('Keep task')),
                            FilledButton(
                                onPressed: () => Navigator.pop(context, true),
                                child: const Text('Delete'))
                          ]));
              if (confirmed != true) return false;
              try {
                await ref.read(taskProvider.notifier).deleteTask(task.id!);
                return true;
              } catch (_) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text(
                          'Could not delete the task. Please try again.')));
                }
                return false;
              }
            },
            background: Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                    color: colors.errorContainer,
                    borderRadius: BorderRadius.circular(20)),
                child:
                    Icon(Icons.delete_outline, color: colors.onErrorContainer)),
            child: TaskTile(task: task, showDate: true));
      },
    );
  }
}
