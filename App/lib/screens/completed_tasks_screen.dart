import 'package:agenda/l10n/region.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:agenda/providers/task_provider.dart';
import 'package:agenda/widgets/custom_app_bar.dart';
import 'package:agenda/widgets/app_components.dart';
import 'package:agenda/widgets/task_list.dart';
import 'package:agenda/models/task.dart';

class CompletedTasksScreen extends ConsumerWidget {
  const CompletedTasksScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
        appBar: CustomAppBar(title: context.l10n.completedTasks),
        body: ref.watch(taskProvider).when(
              data: (tasks) {
                final completed = tasks
                    .expand((task) => task.isRecurring
                        ? task.completedDates
                            .map(task.completedOccurrence)
                            .whereType<Task>()
                        : task.isCompleted
                            ? [task]
                            : <Task>[])
                    .toList();
                if (completed.isEmpty) {
                  return SingleChildScrollView(
                      child: EmptyState(
                          title: context.l10n.progressSmall,
                          message: context.l10n.completedEmpty,
                          icon: Icons.task_alt_rounded));
                }
                return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(context.l10n.progressHeading,
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineSmall),
                                const SizedBox(height: 8),
                                Text(
                                    '${completed.length} tasks completed. Tap a check to reopen one.'),
                              ])),
                      Expanded(child: TaskList(tasks: completed)),
                    ]);
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) => EmptyState(
                  title: context.l10n.completedLoadError,
                  message: context.l10n.tryLater),
            ),
      );
}
