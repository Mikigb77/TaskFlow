import 'package:agenda/l10n/region.dart';
import 'package:agenda/widgets/task_planning_control.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:agenda/widgets/task_schedule_label.dart';
import 'package:agenda/models/task.dart';
import 'package:agenda/screens/task_detail_screen.dart';
import 'package:agenda/widgets/task_interactions.dart';
import 'package:agenda/theme/app_theme.dart';
import 'package:agenda/providers/task_lists_provider.dart';
import 'package:agenda/widgets/task_list_picker.dart';

class TaskTile extends ConsumerWidget {
  const TaskTile({super.key, required this.task, this.showDate = false});
  final Task task;
  final bool showDate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final priority = AppTheme.priorityColor(context, task.priority);
    final list = (ref.watch(taskListsProvider).valueOrNull ?? [])
        .where((list) => list.id == task.listId)
        .firstOrNull;
    return Dismissible(
        direction: ref.watch(listCanEditProvider(task.listId))
            ? DismissDirection.horizontal
            : DismissDirection.none,
        key: ValueKey('gesture:${task.id}:${task.occurrenceId}'),
        confirmDismiss: (direction) async {
          if (direction == DismissDirection.startToEnd) {
            await TaskInteractions.toggle(context, ref, task);
          } else {
            await TaskInteractions.reschedule(context, ref, task);
          }
          return false;
        },
        background: _gestureBackground(
            context,
            Icons.check_rounded,
            task.isCompleted ? context.l10n.reopen : context.l10n.complete,
            Alignment.centerLeft),
        secondaryBackground: _gestureBackground(context, Icons.event_outlined,
            context.l10n.reschedule, Alignment.centerRight),
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
                        occurrenceDate: task.occurrenceDate,
                        occurrenceKey: task.occurrenceId))),
            onLongPress: ref.watch(listCanEditProvider(task.listId))
                ? () => TaskInteractions.reschedule(context, ref, task)
                : null,
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
                              onChanged:
                                  ref.watch(listCanEditProvider(task.listId))
                                      ? (_) => TaskInteractions.toggle(
                                          context, ref, task)
                                      : null)),
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
                                                    showDate: showDate,
                                                    context: context),
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
                                          Flexible(
                                              child: Text(
                                                  context.repeatLabel(task),
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                      fontSize: 12,
                                                      color: colors
                                                          .onSurfaceVariant))),
                                        ]),
                                  if (task.durationMinutes != null)
                                    Text(
                                        context.l10n.durationMinutes(
                                            task.durationMinutes!),
                                        style: TextStyle(
                                            fontSize: 12,
                                            color: colors.onSurfaceVariant)),
                                  if (task.deadline != null)
                                    Text(taskDeadlineLabel(context, task),
                                        style: TextStyle(
                                            fontSize: 12,
                                            color: task.deadlinePassed(
                                                    DateTime.now())
                                                ? colors.error
                                                : colors.onSurfaceVariant)),
                                  if (list != null)
                                    ConstrainedBox(
                                        constraints:
                                            const BoxConstraints(maxWidth: 180),
                                        child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.folder_outlined,
                                                  size: 14,
                                                  color: taskListColor(
                                                      list.color)),
                                              const SizedBox(width: 4),
                                              Flexible(
                                                  child: Text(list.name,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style: TextStyle(
                                                          fontSize: 12,
                                                          color: colors
                                                              .onSurfaceVariant))),
                                            ])),
                                  if (task.checklist.isNotEmpty)
                                    Text(
                                        '${task.checklistDone}/${task.checklist.length} steps',
                                        style: TextStyle(
                                            fontSize: 12,
                                            color: colors.onSurfaceVariant)),
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
                                            context.l10n.priorityValue(context
                                                .priorityName(task.priority)),
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
