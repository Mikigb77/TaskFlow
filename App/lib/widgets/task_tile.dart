import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:agenda/widgets/task_schedule_label.dart';
import 'package:agenda/models/task.dart';
import 'package:agenda/providers/task_provider.dart';
import 'package:agenda/theme/app_theme.dart';

class TaskTile extends ConsumerWidget {
  const TaskTile({super.key, required this.task, this.showDate = false});
  final Task task;
  final bool showDate;

  Future<void> _toggle(BuildContext context, WidgetRef ref) async {
    final container = ProviderScope.containerOf(context, listen: false);
    final notifier = ref.read(taskProvider.notifier);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await notifier.setCompleted(task, !task.isCompleted);
      if (!messenger.mounted) return;
      HapticFeedback.selectionClick();
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(SnackBar(
        content: Text(task.isCompleted ? 'Task reopened' : 'Task completed'),
        action: SnackBarAction(
            label: 'Undo',
            onPressed: () async {
              try {
                // The completed row may already be gone. Use the live account's
                // notifier and latest task so undo never reverts other edits.
                if (!messenger.mounted ||
                    !identical(
                        container.read(taskProvider.notifier), notifier)) {
                  return;
                }
                await notifier.setCompleted(task, task.isCompleted);
              } catch (_) {
                if (messenger.mounted) {
                  messenger.showSnackBar(const SnackBar(
                      content: Text('Could not undo. Please try again.')));
                }
              }
            }),
      ));
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Could not update this task. Please try again.')));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final priority = AppTheme.priorityColor(context, task.priority);
    return Material(
      color: colors.surface,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: colors.outlineVariant)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () =>
            Navigator.pushNamed(context, '/taskDetails', arguments: task.id),
        child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 14, 16, 14),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Semantics(
                  label: task.isCompleted
                      ? 'Reopen ${task.title}'
                      : 'Complete ${task.title}',
                  child: Checkbox(
                      value: task.isCompleted,
                      shape: const CircleBorder(),
                      onChanged: (_) => _toggle(context, ref))),
              const SizedBox(width: 4),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    const SizedBox(height: 3),
                    Text(task.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium!
                            .copyWith(
                                color: task.isCompleted
                                    ? colors.onSurfaceVariant
                                    : colors.onSurface,
                                decoration: task.isCompleted
                                    ? TextDecoration.lineThrough
                                    : null)),
                    const SizedBox(height: 8),
                    Wrap(
                        spacing: 12,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(Icons.schedule_rounded,
                                size: 14, color: colors.onSurfaceVariant),
                            const SizedBox(width: 5),
                            Flexible(
                                child: Text(
                                    taskScheduleLabel(task, showDate: showDate),
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: colors.onSurfaceVariant)))
                          ]),
                          if (task.isRecurring)
                            Row(mainAxisSize: MainAxisSize.min, children: [
                              Icon(Icons.repeat_rounded,
                                  size: 14, color: colors.onSurfaceVariant),
                              const SizedBox(width: 4),
                              Text(Task.repeats[task.recurrence]!,
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: colors.onSurfaceVariant)),
                            ]),
                          Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                  color: priority.withValues(alpha: .10),
                                  borderRadius: BorderRadius.circular(6)),
                              child: Text(
                                  '${AppTheme.priorityLabel(task.priority)} priority',
                                  style: TextStyle(
                                      color: priority,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700))),
                        ]),
                    if (task.notes?.trim().isNotEmpty ?? false) ...[
                      const SizedBox(height: 8),
                      Text(task.notes!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color: colors.onSurfaceVariant, fontSize: 12))
                    ],
                  ])),
            ])),
      ),
    );
  }
}
