import 'package:agenda/l10n/region.dart';
import 'package:agenda/widgets/task_planning_control.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:collection/collection.dart';
import 'package:agenda/models/task.dart';
import 'package:agenda/providers/task_provider.dart';
import 'package:agenda/providers/task_lists_provider.dart';
import 'package:agenda/theme/app_theme.dart';
import 'package:agenda/widgets/custom_app_bar.dart';
import 'package:agenda/widgets/app_components.dart';
import 'package:agenda/widgets/reminder_control.dart';
import 'package:agenda/widgets/task_interactions.dart';
import 'package:agenda/widgets/task_list_picker.dart';
import 'package:agenda/widgets/attachment_panel.dart';
import 'package:agenda/widgets/note_text.dart';

class TaskDetailScreen extends ConsumerWidget {
  const TaskDetailScreen(
      {super.key,
      required this.taskId,
      this.occurrenceDate,
      this.occurrenceKey});
  final int taskId;
  final DateTime? occurrenceDate;
  final String? occurrenceKey;

  Future<void> _delete(BuildContext context, WidgetRef ref, Task task) async {
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
                title: Text(task.isNote
                    ? context.l10n.deleteNoteQuestion
                    : context.l10n.deleteTaskQuestion),
                content: Text(task.isRecurring
                    ? context.l10n.deleteSeriesHelp(task.title)
                    : context.l10n.deleteItemHelp(task.title)),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: Text(task.isNote
                          ? context.l10n.keepNote
                          : context.l10n.keepTask)),
                  FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: Text(context.l10n.delete))
                ]));
    if (confirmed != true || !context.mounted) return;
    try {
      await ref.read(taskProvider.notifier).deleteTask(taskId);
      if (context.mounted) Navigator.pop(context);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.l10n.deleteTaskError)));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    return ref.watch(taskProvider).when(
          data: (tasks) {
            final series = tasks.firstWhereOrNull((task) => task.id == taskId);
            final task = occurrenceKey != null
                ? series?.occurrenceByKey(occurrenceKey!) ??
                    series?.completedOccurrence(occurrenceKey!)
                : occurrenceDate == null
                    ? (series?.isRecurring == true
                        ? series?.nextOpenOccurrence() ?? series
                        : series)
                    : series?.occurrenceOn(occurrenceDate!) ??
                        series?.nextOpenOccurrence() ??
                        series;
            if (task == null) {
              return Scaffold(
                  appBar: CustomAppBar(title: context.l10n.taskDetails),
                  body: SingleChildScrollView(
                      child: Column(children: [
                    EmptyState(
                        title: series == null
                            ? context.l10n.taskUnavailable
                            : context.l10n.occurrenceChanged,
                        message: series == null
                            ? context.l10n.taskRemoved
                            : context.l10n.occurrenceSkipped),
                    if (series != null)
                      TextButton(
                          onPressed: () => Navigator.pushNamed(
                              context, '/editTask',
                              arguments: taskId),
                          child: Text(context.l10n.editRepeating)),
                  ])));
            }
            final canEdit = ref.watch(listCanEditProvider(task.listId));
            return Scaffold(
              appBar: CustomAppBar(
                  title: task.isNote
                      ? context.l10n.note
                      : context.l10n.taskDetails,
                  actions: [
                    if (canEdit)
                      IconButton(
                          tooltip: task.isNote
                              ? context.l10n.editNote
                              : context.l10n.editTask,
                          onPressed: () => Navigator.pushNamed(
                              context, '/editTask',
                              arguments: taskId),
                          icon: const Icon(Icons.edit_outlined)),
                    if (canEdit)
                      IconButton(
                          tooltip: task.isNote
                              ? context.l10n.delete
                              : context.l10n.deleteTask,
                          onPressed: () => _delete(context, ref, task),
                          icon: Icon(Icons.delete_outline_rounded,
                              color: colors.onSurfaceVariant))
                  ]),
              body: ListView(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
                  children: [
                    SectionLabel(task.isNote
                        ? context.l10n.note
                        : task.isCompleted
                            ? context.l10n.completed
                            : context.l10n.nextStep),
                    Text(task.title,
                        style: Theme.of(context).textTheme.headlineLarge),
                    const SizedBox(height: 12),
                    if (!canEdit)
                      MessageBanner(
                          task.isNote
                              ? context.l10n.viewOnlyNote
                              : context.l10n.viewOnlyTask,
                          icon: Icons.visibility_outlined),
                    Align(
                        alignment: Alignment.centerLeft,
                        child: TaskListPicker(
                            lockShared: true,
                            listId: task.listId,
                            onChanged: (id) async {
                              try {
                                await ref
                                    .read(taskProvider.notifier)
                                    .moveToList(task.id!, id);
                              } catch (_) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                          content:
                                              Text(context.l10n.moveError)));
                                }
                              }
                            })),
                    if (task.labels.isNotEmpty)
                      Wrap(spacing: 8, children: [
                        for (final label in task.labels)
                          Chip(label: Text('#$label'))
                      ]),
                    const SizedBox(height: 24),
                    if (!task.isNote)
                      AppSurface(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 8),
                          child: Column(children: [
                            _detail(
                                context,
                                Icons.calendar_today_outlined,
                                context.l10n.plannedFor,
                                task.displayDate == null
                                    ? context.l10n.inboxDate
                                    : context.fullDate(task.displayDate!)),
                            const Divider(),
                            _detail(
                                context,
                                Icons.schedule_outlined,
                                context.l10n.time,
                                task.hasTime
                                    ? context.clockTime(task.displayDate!)
                                    : context.l10n.anyTime),
                            if (task.durationMinutes != null) ...[
                              const Divider(),
                              _detail(
                                  context,
                                  Icons.timelapse_outlined,
                                  context.l10n.duration,
                                  '${context.l10n.durationMinutes(task.durationMinutes!)}${task.plannedEnd == null ? '' : ' · ${context.clockTime(task.displayDate!)} – ${context.shortDate(task.plannedEnd!)} ${context.clockTime(task.plannedEnd!)}'}'),
                            ],
                            if (task.deadline != null) ...[
                              const Divider(),
                              _detail(
                                  context,
                                  Icons.flag_outlined,
                                  context.l10n.deadline,
                                  '${taskDeadlineLabel(context, task)}${task.deadlineHasTime ? '' : '\n${context.l10n.deadlineEndDay}'}',
                                  color: task.deadlinePassed(DateTime.now())
                                      ? colors.error
                                      : null),
                              if (task.plannedAfterDeadline)
                                MessageBanner(context.l10n.deadlineLatePlan,
                                    icon: Icons.info_outline),
                            ],
                            if (task.isRecurring) ...[
                              const Divider(),
                              _detail(
                                  context,
                                  Icons.repeat_rounded,
                                  context.l10n.repeat,
                                  '${context.repeatLabel(task)}${task.repeatUntil == null ? '' : ' · ${context.l10n.untilDate(context.shortDate(task.repeatUntil!))}'}'),
                            ],
                            const Divider(),
                            _detail(
                                context,
                                Icons.flag_outlined,
                                context.l10n.priority,
                                context.priorityName(task.priority),
                                color: AppTheme.priorityColor(
                                    context, task.priority)),
                          ])),
                    if (!task.isNote) const SizedBox(height: 28),
                    if (task.reminderDate != null)
                      Align(
                          alignment: Alignment.centerLeft,
                          child: ReminderChip(
                              task: task,
                              onChanged: !canEdit
                                  ? null
                                  : (updated) async {
                                      try {
                                        await ref
                                            .read(taskProvider.notifier)
                                            .updateTask(series!.copyWith(
                                                reminderMinutes:
                                                    updated.reminderMinutes,
                                                reminderTime:
                                                    updated.reminderTime));
                                      } catch (_) {
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(SnackBar(
                                                  content: Text(context.l10n
                                                      .updateReminderError)));
                                        }
                                      }
                                    })),
                    if (!task.isNote) const SizedBox(height: 16),
                    if (task.isNote) ...[
                      _body(context, task),
                      const SizedBox(height: 24),
                    ],
                    if (task.checklist.isNotEmpty) ...[
                      SectionLabel(context.l10n.checklistCount(
                          task.checklistDone, task.checklist.length)),
                      AppSurface(
                          child: Column(children: [
                        LinearProgressIndicator(
                            value: task.checklistDone / task.checklist.length,
                            semanticsLabel: context.l10n.checklistSemantics(
                                task.checklistDone, task.checklist.length)),
                        for (final item in task.checklist)
                          CheckboxListTile(
                              contentPadding: EdgeInsets.zero,
                              key: ValueKey('check-step-${item.id}'),
                              controlAffinity: ListTileControlAffinity.leading,
                              title: Text(item.title),
                              value: item.done(
                                  occurrence: task.checklistOccurrence),
                              onChanged: !canEdit
                                  ? null
                                  : (value) async {
                                      try {
                                        await ref
                                            .read(taskProvider.notifier)
                                            .setChecklistCompleted(
                                                task, item.id, value == true);
                                      } catch (_) {
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(SnackBar(
                                                  content: Text(context
                                                      .l10n.stepUpdateError)));
                                        }
                                      }
                                    }),
                        if (canEdit && !task.isNote)
                          Text(context.l10n.checklistCompletionHelp),
                      ])),
                      const SizedBox(height: 24),
                    ],
                    if (!task.isNote) _body(context, task),
                    AttachmentPanel(task: task),
                  ]),
              bottomNavigationBar: !canEdit || task.isNote
                  ? null
                  : SafeArea(
                      top: false,
                      child: Padding(
                          padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
                          child: Wrap(
                              spacing: 12,
                              runSpacing: 8,
                              alignment: WrapAlignment.center,
                              children: [
                                FilledButton.icon(
                                    onPressed: () => TaskInteractions.toggle(
                                        context, ref, task),
                                    icon: Icon(task.isCompleted
                                        ? Icons.undo_rounded
                                        : Icons.check_rounded),
                                    label: Text(task.isCompleted
                                        ? context.l10n.reopen
                                        : context.l10n.complete)),
                                OutlinedButton.icon(
                                    onPressed: () =>
                                        TaskInteractions.reschedule(
                                            context, ref, task),
                                    icon: const Icon(Icons.event_outlined),
                                    label: Text(context.l10n.reschedule)),
                              ]))),
            );
          },
          loading: () =>
              const Scaffold(body: Center(child: CircularProgressIndicator())),
          error: (_, __) => Scaffold(
              appBar: CustomAppBar(title: context.l10n.taskDetails),
              body: EmptyState(
                  title: context.l10n.loadTaskError,
                  message: context.l10n.tryLater)),
        );
  }

  Widget _detail(
      BuildContext context, IconData icon, String label, String value,
      {Color? color}) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Row(children: [
          Icon(icon, color: color ?? colors.primary, size: 22),
          const SizedBox(width: 16),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(label,
                    style: TextStyle(
                        color: colors.onSurfaceVariant, fontSize: 12)),
                const SizedBox(height: 4),
                Text(value,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium!
                        .copyWith(color: color)),
              ])),
        ]));
  }

  Widget _body(BuildContext context, Task task) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SectionLabel(task.isNote ? context.l10n.noteBody : context.l10n.notes),
        AppSurface(
            child: SizedBox(
                width: double.infinity,
                child: NoteText(task.notes?.trim().isNotEmpty == true
                    ? task.notes!
                    : context.l10n.noteEmptyBody))),
      ]);
}
