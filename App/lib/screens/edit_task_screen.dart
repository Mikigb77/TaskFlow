import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:collection/collection.dart';
import 'package:agenda/providers/task_provider.dart';
import 'package:agenda/widgets/task_editor.dart';
import 'package:agenda/widgets/custom_app_bar.dart';
import 'package:agenda/widgets/app_components.dart';

class EditTaskScreen extends ConsumerWidget {
  const EditTaskScreen({super.key, required this.taskId});
  final int taskId;
  @override
  Widget build(BuildContext context, WidgetRef ref) => ref
      .watch(taskProvider)
      .when(
        data: (tasks) {
          final task = tasks.firstWhereOrNull((task) => task.id == taskId);
          if (task != null) {
            return TaskEditor(key: ValueKey(taskId), task: task);
          }
          return const Scaffold(
              appBar: CustomAppBar(title: 'Edit task'),
              body: EmptyState(
                  title: 'Task unavailable',
                  message: 'This task may have been removed.'));
        },
        loading: () =>
            const Scaffold(body: Center(child: CircularProgressIndicator())),
        error: (_, __) => const Scaffold(
            appBar: CustomAppBar(title: 'Edit task'),
            body: EmptyState(
                title: 'Couldn’t load this task',
                message: 'Please try again in a moment.')),
      );
}
