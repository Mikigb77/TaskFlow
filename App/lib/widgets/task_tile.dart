import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:agenda/widgets/task_schedule_label.dart';
import 'package:agenda/models/task.dart';
import 'package:agenda/screens/task_detail_screen.dart';
import 'package:agenda/widgets/task_interactions.dart';
import 'package:agenda/theme/app_theme.dart';

class TaskTile extends ConsumerWidget {
  const TaskTile({super.key, required this.task, this.showDate = false});
  final Task task;
  final bool showDate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final priority = AppTheme.priorityColor(context, task.priority);
    return Dismissible(
        key: ValueKey('gesture:${task.id}:${task.occurrenceDate}'),
        confirmDismiss: (direction) async {
          if (direction == DismissDirection.startToEnd) {
            await TaskInteractions.toggle(context, ref, task);
          } else {
            await TaskInteractions.reschedule(context, ref, task);
          }
          return false;
        },
        background: _gestureBackground(context, Icons.check_rounded,
            task.isCompleted ? 'Reopen' : 'Complete', Alignment.centerLeft),
        secondaryBackground: _gestureBackground(
            context, Icons.event_outlined, 'Reschedule', Alignment.centerRight),
        child: Material(
          color: colors.surface,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: colors.outlineVariant)),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                    settings: const RouteSettings(name: '/taskDetails'),
                    builder: (_) => TaskDetailScreen(
                        taskId: task.id!,
                        occurrenceDate: task.occurrenceDate))),
            onLongPress: () => TaskInteractions.reschedule(context, ref, task),
            child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 14, 16, 14),
                child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Semantics(
                          label: task.isCompleted
                              ? 'Reopen ${task.title}'
                              : 'Complete ${task.title}',
                          child: Checkbox(
                              value: task.isCompleted,
                              shape: const CircleBorder(),
                              onChanged: (_) =>
                                  TaskInteractions.toggle(context, ref, task))),
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
                                  Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.schedule_rounded,
                                            size: 14,
                                            color: colors.onSurfaceVariant),
                                        const SizedBox(width: 5),
                                        Flexible(
                                            child: Text(
                                                taskScheduleLabel(task,
                                                    showDate: showDate),
                                                style: TextStyle(
                                                    fontSize: 12,
                                                    color: colors
                                                        .onSurfaceVariant)))
                                      ]),
                                  if (task.isRecurring)
                                    Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.repeat_rounded,
                                              size: 14,
                                              color: colors.onSurfaceVariant),
                                          const SizedBox(width: 4),
                                          Text(Task.repeats[task.recurrence]!,
                                              style: TextStyle(
                                                  fontSize: 12,
                                                  color:
                                                      colors.onSurfaceVariant)),
                                        ]),
                                  if (task.priority > 1)
                                    Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                            color:
                                                priority.withValues(alpha: .10),
                                            borderRadius:
                                                BorderRadius.circular(6)),
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
                                      color: colors.onSurfaceVariant,
                                      fontSize: 12))
                            ],
                          ])),
                    ])),
          ),
        ));
  }

  Widget _gestureBackground(BuildContext context, IconData icon, String label,
          Alignment alignment) =>
      Container(
          alignment: alignment,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(20)),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon),
            const SizedBox(height: 4),
            Text(label),
          ]));
}
