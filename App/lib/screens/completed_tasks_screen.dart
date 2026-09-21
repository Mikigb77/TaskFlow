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
        appBar: const CustomAppBar(title: 'Completed tasks'),
        body: ref.watch(taskProvider).when(
              data: (tasks) {
                final completed = tasks
                    .expand((task) => task.isRecurring
                        ? task.completedDates
                            .map((date) =>
                                task.occurrenceOn(DateTime.parse(date)))
                            .whereType<Task>()
                        : task.isCompleted
                            ? [task]
                            : <Task>[])
                    .toList();
                if (completed.isEmpty) {
                  return const SingleChildScrollView(
                      child: EmptyState(
                          title: 'Progress starts small',
                          message:
                              'Every task you finish will find a home here.',
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
                                Text('Look how far you’ve come.',
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
              error: (_, __) => const EmptyState(
                  title: 'Couldn’t load completed tasks',
                  message: 'Please try again in a moment.'),
            ),
      );
}
