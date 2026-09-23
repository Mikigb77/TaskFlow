import 'package:agenda/l10n/region.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:collection/collection.dart';
import 'package:agenda/providers/task_provider.dart';
import 'package:agenda/providers/task_lists_provider.dart';
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
            if (!ref.watch(listCanEditProvider(task.listId))) {
              return Scaffold(
                  appBar: CustomAppBar(title: context.l10n.viewOnlyTaskTitle),
                  body: EmptyState(
                      title: context.l10n.readOnlyList,
                      message: context.l10n.listEditingAccessHelp));
            }
            return TaskEditor(key: ValueKey(taskId), task: task);
          }
          return Scaffold(
              appBar: CustomAppBar(title: context.l10n.editTask),
              body: EmptyState(
                  title: context.l10n.taskUnavailable,
                  message: context.l10n.taskRemoved));
        },
        loading: () =>
            const Scaffold(body: Center(child: CircularProgressIndicator())),
        error: (_, __) => Scaffold(
            appBar: CustomAppBar(title: context.l10n.editTask),
            body: EmptyState(
                title: context.l10n.loadTaskError,
                message: context.l10n.tryLater)),
      );
}
