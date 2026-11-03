import 'package:agenda/l10n/region.dart';
import 'package:agenda/providers/auth_provider.dart';
import 'package:agenda/providers/calendar_focus_provider.dart';
import 'package:agenda/widgets/task_assignment_picker.dart';
import 'package:agenda/widgets/task_planning_control.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:agenda/widgets/task_schedule_label.dart';
import 'package:agenda/models/task.dart';
import 'package:agenda/screens/task_detail_screen.dart';
import 'package:agenda/widgets/task_interactions.dart';
import 'package:agenda/theme/app_theme.dart';
import 'package:agenda/providers/task_lists_provider.dart';
import 'package:agenda/widgets/task_list_picker.dart';

class TaskTile extends ConsumerWidget {
  const TaskTile({
    super.key,
    required this.task,
    this.showDate = false,
    this.color,
    this.project,
    this.showUndated = true,
    this.markOverdue = false,
    this.lastOpen = false,
    this.doneAt,
  });
  final Task task;

  /// The date line leads with the day. Without it a row shows its time
  /// alone, and a row with a date but no time shows no line.
  final bool showDate;

  /// Replaces the surface colour, for example to highlight a new task.
  final Color? color;

  /// The page's project: a row leaves out a project label naming it.
  final String? project;

  /// Whether a row with no date and no deadline says so. On the Sin fecha page it doesn't; a row with a deadline shows its «Vence …» line instead.
  final bool showUndated;

  /// In task lists, an open task whose day has passed says «Atrasada».
  final bool markOverdue;

  /// The open task left on Calendar's shown day: ticking it says the day is
  /// clear rather than «Tarea completada».
  final bool lastOpen;

  /// The time a row on Completadas was done at, given back when it is
  /// ticked again, on the row or on its page.
  final DateTime? doneAt;

  /// The row's date line, or null when it has nothing to say.
  String? _dateLine(BuildContext context, WidgetRef ref) {
    final date = task.displayDate;
    if (date == null) {
      return showUndated && task.deadline == null ? context.l10n.noDate : null;
    }
    if (!showDate) return task.hasTime ? context.clockTime(date) : null;
    final line = taskDayLine(context, task);
    final today = DateUtils.dateOnly(ref.watch(calendarClockProvider)());
    return markOverdue &&
            !task.isCompleted &&
            !task.isNote &&
            DateUtils.dateOnly(date).isBefore(today)
        ? context.l10n.overdueDate(line)
        : line;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final priority = AppTheme.priorityColor(context, task.priority);
    final lists = ref.watch(taskListsProvider);
    final list = (lists.value ?? [])
        .where((list) => list.id == task.listId)
        .firstOrNull;
    final editable = ref.watch(listCanEditProvider(task.listId));
    // Known not to be changeable: while the projects load, a task in one
    // keeps its circle, so the row doesn't shift when they arrive.
    final viewOnly = !editable && lists.hasValue;
    // On a lit row the grey text darkens, so it stays readable on the tint.
    final muted = (color ?? colors.surface) == colors.surface
        ? colors.onSurfaceVariant
        : colors.onSurface;
    final small = TextStyle(fontSize: 12, color: muted);
    Widget iconText(
      IconData icon,
      String text, {
      Color? iconColor,
      Color? textColor,
      String? semanticsLabel,
      bool wraps = false,
    }) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: iconColor ?? textColor ?? muted),
        const SizedBox(width: 4),
        Flexible(
          child: spokenAs(
            semanticsLabel,
            Text(
              text,
              overflow: wraps ? null : TextOverflow.ellipsis,
              style: small.copyWith(color: textColor),
            ),
          ),
        ),
      ],
    );
    final when = _dateLine(context, ref);
    final deadlinePassed =
        task.deadline != null && task.deadlinePassed(DateTime.now());
    final deadline = task.deadline == null
        ? null
        : deadlinePassed
        ? context.deadlinePassedLine(task)
        : taskDeadlineLabel(context, task);
    // Who a task in a shared project is for, and what TalkBack reads for it.
    final assignee = list?.shared == true
        ? responsibilityLabel(
            context,
            task,
            ref.watch(authProvider).account?.id,
          )
        : null;
    final unassigned = task.assignment == 'unassigned';
    final assigneeSpoken = assignee == null || unassigned
        ? assignee
        : context.l10n.assigneeLabel(assignee);
    final repeat = task.isRecurring ? context.repeatLabel(task) : null;
    final duration = task.durationMinutes == null
        ? null
        : context.l10n.durationMinutes(task.durationMinutes!);
    final steps = task.checklist.isEmpty
        ? null
        : context.l10n.checklistCount(
            task.checklistDone,
            task.checklist.length,
          );
    final importance = task.priority > 1
        ? context.priorityPhrase(task.priority)
        : null;
    final notes = (task.notes?.trim().isNotEmpty ?? false) ? task.notes! : null;
    // Each detail under the title, and what TalkBack reads for it.
    final details = <(Widget, String)>[
      if (when != null)
        (iconText(Icons.schedule_rounded, when, wraps: true), when),
      if (repeat != null) (iconText(Icons.repeat_rounded, repeat), repeat),
      if (duration != null) (Text(duration, style: small), duration),
      if (deadline != null) (Text(deadline, style: small), deadline),
      if (list != null && list.id != project)
        (
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 180),
            child: iconText(
              Icons.folder_outlined,
              list.name,
              iconColor: taskListColor(list.color),
            ),
          ),
          list.name,
        ),
      if (assignee != null)
        (
          iconText(
            task.assignment == 'group'
                ? Icons.groups_outlined
                : Icons.person_outline,
            assignee,
            semanticsLabel: assigneeSpoken,
            wraps: true,
          ),
          assigneeSpoken!,
        ),
      if (steps != null) (Text(steps, style: small), steps),
      if (importance != null)
        (
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: priority.withValues(alpha: .10),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              importance,
              style: TextStyle(
                color: priority,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          importance,
        ),
    ];
    final titleOnly = details.isEmpty && notes == null;
    void open() => Navigator.push(
      context,
      MaterialPageRoute<void>(
        settings: const RouteSettings(name: '/taskDetails'),
        builder: (_) => TaskDetailScreen(
          taskId: task.id!,
          occurrenceDate: task.occurrenceDate,
          occurrenceKey: task.occurrenceId,
          doneAt: doneAt,
        ),
      ),
    );
    void reschedule() => TaskInteractions.reschedule(context, ref, task);
    Future<void> toggle() => TaskInteractions.toggle(
      context,
      ref,
      task,
      doneMessage: lastOpen ? context.l10n.dayAllClear : null,
      doneAt: doneAt,
    );
    return Semantics(
      container: true,
      // A row that can't be changed is one button that opens the task. An
      // editable one names what its long press does, and its circle is apart.
      button: viewOnly,
      label: !viewOnly
          ? null
          : [
              task.title,
              for (final (_, text) in details) text,
              ?notes,
            ].join(', '),
      excludeSemantics: viewOnly,
      onTap: open,
      customSemanticsActions: editable
          ? {CustomSemanticsAction(label: context.l10n.reschedule): reschedule}
          : null,
      child: Dismissible(
        // With TalkBack or Switch Access on, the swipe's scroll actions
        // would complete or move the task unseen: the circle completes and
        // «Cambiar fecha» stays as the row's custom action.
        direction: editable && !MediaQuery.accessibleNavigationOf(context)
            ? DismissDirection.horizontal
            : DismissDirection.none,
        key: ValueKey('gesture:${task.id}:${task.occurrenceId}'),
        confirmDismiss: (direction) async {
          if (direction == DismissDirection.startToEnd) {
            await toggle();
          } else {
            await TaskInteractions.reschedule(context, ref, task);
          }
          return false;
        },
        background: _gestureBackground(
          context,
          Icons.check_rounded,
          task.isCompleted ? context.l10n.reopen : context.l10n.complete,
          Alignment.centerLeft,
        ),
        secondaryBackground: _gestureBackground(
          context,
          Icons.event_outlined,
          context.l10n.reschedule,
          Alignment.centerRight,
        ),
        child: Material(
          color: color ?? colors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: colors.outlineVariant),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            // The Semantics above carries the tap and names the long press.
            excludeFromSemantics: true,
            onTap: open,
            onLongPress: editable ? reschedule : null,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 14, 16, 14),
              child: Row(
                // A title alone sits level with its circle.
                crossAxisAlignment: titleOnly
                    ? CrossAxisAlignment.center
                    : CrossAxisAlignment.start,
                children: [
                  // A task that can't be changed has no circle to tick; an
                  // empty slot as wide as the circle and its gap keeps its
                  // title in line with the others.
                  if (viewOnly)
                    const SizedBox(width: kMinInteractiveDimension + 4)
                  else ...[
                    Semantics(
                      label: task.isCompleted
                          ? context.l10n.reopenNamedTask(task.title)
                          : context.l10n.completeNamedTask(task.title),
                      child: Checkbox(
                        value: task.isCompleted,
                        shape: const CircleBorder(),
                        onChanged: editable
                            ? (_) => toggle()
                            : null,
                      ),
                    ),
                    const SizedBox(width: 4),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (!titleOnly) const SizedBox(height: 3),
                        Text(
                          task.title,
                          style: Theme.of(context).textTheme.titleMedium!
                              .copyWith(
                                color: task.isCompleted
                                    ? muted
                                    : colors.onSurface,
                                decoration: task.isCompleted
                                    ? TextDecoration.lineThrough
                                    : null,
                              ),
                        ),
                        if (details.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 12,
                            runSpacing: 6,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              for (final (detail, _) in details) detail,
                            ],
                          ),
                        ],
                        if (notes != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            notes,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: small,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _gestureBackground(
    BuildContext context,
    IconData icon,
    String label,
    Alignment alignment,
  ) => Container(
    alignment: alignment,
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.primaryContainer,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [Icon(icon), const SizedBox(height: 4), Text(label)],
    ),
  );
}

/// A just-saved task: its tile lights up, then fades back when [lit] turns
/// off. With animations off it changes at once.
class LandedTaskTile extends StatelessWidget {
  const LandedTaskTile({
    super.key,
    required this.task,
    required this.lit,
    this.showDate = false,
    this.project,
    this.showUndated = true,
    this.markOverdue = false,
    this.lastOpen = false,
  });
  final Task task;
  final bool lit;
  final bool showDate;
  final String? project;
  final bool showUndated;
  final bool markOverdue;
  final bool lastOpen;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return TweenAnimationBuilder<Color?>(
      tween: ColorTween(end: lit ? colors.primaryContainer : colors.surface),
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 600),
      builder: (context, color, _) => TaskTile(
        task: task,
        showDate: showDate,
        color: color,
        project: project,
        showUndated: showUndated,
        markOverdue: markOverdue,
        lastOpen: lastOpen,
      ),
    );
  }
}
