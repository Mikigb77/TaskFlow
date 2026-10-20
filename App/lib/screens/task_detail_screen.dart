import 'dart:async';
import 'package:agenda/l10n/region.dart';
import 'package:agenda/screens/activity_screen.dart';
import 'package:agenda/widgets/task_planning_control.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:collection/collection.dart';
import 'package:agenda/models/task.dart';
import 'package:agenda/providers/auth_provider.dart';
import 'package:agenda/providers/task_provider.dart';
import 'package:agenda/providers/task_lists_provider.dart';
import 'package:agenda/theme/app_theme.dart';
import 'package:agenda/widgets/custom_app_bar.dart';
import 'package:agenda/widgets/app_components.dart';
import 'package:agenda/widgets/reminder_control.dart';
import 'package:agenda/widgets/task_interactions.dart';
import 'package:agenda/widgets/task_assignment_picker.dart';
import 'package:agenda/widgets/attachment_panel.dart';
import 'package:agenda/widgets/note_text.dart';

class TaskDetailScreen extends ConsumerWidget {
  const TaskDetailScreen({
    super.key,
    required this.taskId,
    this.occurrenceDate,
    this.occurrenceKey,
    this.showFiles = false,
  });
  final int taskId;
  final DateTime? occurrenceDate;
  final String? occurrenceKey;

  /// Opened to free file space: scrolls the Files section into view.
  final bool showFiles;

  /// Deletes at once, with Undo. Only a whole repeating series asks first.
  Future<void> _delete(BuildContext context, WidgetRef ref, Task task) async {
    if (task.isRecurring) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          content: Text(context.l10n.deleteSeriesHelp(task.title)),
          actions: [
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error,
              ),
              onPressed: () => Navigator.pop(context, true),
              child: Text(context.l10n.delete),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(context.l10n.keepTask),
            ),
          ],
        ),
      );
      if (confirmed != true || !context.mounted) return;
    }
    final container = ProviderScope.containerOf(context, listen: false);
    final notifier = ref.read(taskProvider.notifier);
    final messenger = ScaffoldMessenger.of(context);
    final strings = context.l10n;
    // The stored task, not an occurrence, is what Undo puts back.
    final saved = ref
        .read(taskProvider)
        .valueOrNull
        ?.firstWhereOrNull((item) => item.id == taskId);
    try {
      // Sent once Undo is no longer offered.
      await notifier.deleteTask(taskId, sync: saved == null);
    } catch (_) {
      if (messenger.mounted) showFeedback(messenger, strings.deleteTaskError);
      return;
    }
    if (context.mounted) Navigator.pop(context);
    if (saved == null) return;
    bool current() =>
        messenger.mounted &&
        identical(container.read(taskProvider.notifier), notifier);
    final feedback = await showFeedback(
      messenger,
      task.isNote ? strings.noteDeleted : strings.taskDeleted,
      actionLabel: strings.undo,
      onAction: () async {
        if (!current()) return;
        try {
          await notifier.restoreTask(saved);
        } catch (_) {
          if (messenger.mounted) showFeedback(messenger, strings.undoError);
        }
      },
    );
    final reason = await feedback?.closed;
    if (reason != SnackBarClosedReason.action && notifier.mounted) {
      unawaited(notifier.loadTasks());
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    return ref
        .watch(taskProvider)
        .when(
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
                appBar: CustomAppBar(title: context.l10n.taskScreenTitle),
                body: SingleChildScrollView(
                  child: Column(
                    children: [
                      EmptyState(
                        title: series == null
                            ? context.l10n.taskUnavailable
                            : context.l10n.occurrenceChanged,
                        message: series == null
                            ? context.l10n.taskRemoved
                            : context.l10n.occurrenceSkipped,
                      ),
                      if (series != null)
                        TextButton(
                          onPressed: () => Navigator.pushNamed(
                            context,
                            '/editTask',
                            arguments: taskId,
                          ),
                          child: Text(context.l10n.editRepeating),
                        ),
                    ],
                  ),
                ),
              );
            }
            final canEdit = ref.watch(listCanEditProvider(task.listId));
            final projects = ref.watch(taskListsProvider).valueOrNull;
            final hasProjects = projects?.isNotEmpty == true;
            // Who created it, in a shared project only. No name: the
            // account has left the project or been deleted. The signed-in
            // account is «ti», as who it's for calls it «Yo».
            final creator = task.createdByName?.trim() ?? '';
            final mine =
                task.createdBy != null &&
                task.createdBy == ref.watch(authProvider).account?.id;
            final project = projects?.firstWhereOrNull(
              (p) => p.id == task.listId,
            );
            final showCreator = creator.isNotEmpty && project?.shared == true;
            final hasBody = task.notes?.trim().isNotEmpty == true;
            void edit() =>
                Navigator.pushNamed(context, '/editTask', arguments: taskId);
            void reschedule() =>
                TaskInteractions.reschedule(context, ref, task);
            return Scaffold(
              appBar: CustomAppBar(
                title: task.isNote
                    ? context.l10n.note
                    : context.l10n.taskScreenTitle,
                actions: [
                  if (canEdit && !task.isNote)
                    IconButton(
                      tooltip: context.l10n.editTask,
                      onPressed: edit,
                      icon: const Icon(Icons.edit_outlined),
                    ),
                  // Delete is instant: keep it apart from Edit.
                  if (canEdit && !task.isNote) const SizedBox(width: 12),
                  if (canEdit)
                    IconButton(
                      tooltip: task.isNote
                          ? context.l10n.delete
                          : context.l10n.deleteTask,
                      onPressed: () => _delete(context, ref, task),
                      icon: Icon(
                        Icons.delete_outline_rounded,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
              // Built whole, so the Files section can be scrolled to.
              body: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (task.isCompleted && !task.isNote)
                      SectionLabel(context.l10n.taskCompleted),
                    Semantics(
                      button: canEdit,
                      onTapHint: task.isNote
                          ? context.l10n.editNote
                          : context.l10n.editTask,
                      child: InkWell(
                        onTap: canEdit ? edit : null,
                        borderRadius: BorderRadius.circular(12),
                        child: Text(
                          task.title,
                          style: Theme.of(context).textTheme.headlineLarge,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (!canEdit)
                      MessageBanner(
                        task.isNote
                            ? context.l10n.viewOnlyNote
                            : context.l10n.viewOnlyTask,
                        icon: Icons.visibility_outlined,
                      ),
                    if (task.listId != null || hasProjects)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TaskAssignmentPicker(
                          lockShared: true,
                          task: task,
                          onChanged: !canEdit
                              ? null
                              : (changed) async {
                                  try {
                                    await ref
                                        .read(taskProvider.notifier)
                                        .updateTask(changed);
                                  } catch (_) {
                                    if (context.mounted) {
                                      showFeedback(
                                        ScaffoldMessenger.of(context),
                                        context.l10n.moveError,
                                      );
                                    }
                                  }
                                },
                        ),
                      ),
                    if (showCreator)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          mine
                              ? context.l10n.createdByYou
                              : context.l10n.createdBy(creator),
                          key: const ValueKey('task-created-by'),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    if (task.assignment != 'personal')
                      TaskActivity(taskId: task.id!),
                    if (task.labels.isNotEmpty)
                      Wrap(
                        spacing: 8,
                        children: [
                          for (final label in task.labels)
                            Chip(label: Text('#$label')),
                        ],
                      ),
                    const SizedBox(height: 24),
                    if (!task.isNote)
                      AppSurface(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 8,
                        ),
                        child: Column(
                          children: [
                            _detail(
                              context,
                              Icons.calendar_today_outlined,
                              context.l10n.plannedFor,
                              task.displayDate == null
                                  ? context.l10n.noDate
                                  : context.fullDate(task.displayDate!),
                              onTap: canEdit ? reschedule : null,
                              tapHint: context.l10n.reschedule,
                            ),
                            const Divider(),
                            _detail(
                              context,
                              Icons.schedule_outlined,
                              context.l10n.time,
                              task.hasTime
                                  ? context.clockTime(task.displayDate!)
                                  : context.l10n.anyTime,
                              onTap: canEdit ? reschedule : null,
                              tapHint: context.l10n.reschedule,
                            ),
                            if (task.durationMinutes != null) ...[
                              const Divider(),
                              _detail(
                                context,
                                Icons.timelapse_outlined,
                                context.l10n.duration,
                                '${context.l10n.durationMinutes(task.durationMinutes!)}${task.plannedEnd == null ? '' : ' · ${context.clockTime(task.displayDate!)} – ${context.shortDate(task.plannedEnd!)} ${context.clockTime(task.plannedEnd!)}'}',
                                onTap: canEdit ? edit : null,
                                tapHint: context.l10n.editTask,
                              ),
                            ],
                            if (task.deadline != null) ...[
                              const Divider(),
                              _detail(
                                context,
                                Icons.flag_outlined,
                                context.l10n.deadline,
                                '${taskDeadlineLabel(context, task)}${task.deadlinePassed(DateTime.now()) ? ' · ${context.l10n.deadlineOverdue}' : ''}${task.deadlineHasTime ? '' : '\n${context.l10n.deadlineEndDay}'}',
                                color: task.deadlinePassed(DateTime.now())
                                    ? colors.error
                                    : null,
                                onTap: canEdit ? edit : null,
                                tapHint: context.l10n.editTask,
                              ),
                              if (task.plannedAfterDeadline)
                                MessageBanner(
                                  context.l10n.deadlineLatePlan,
                                  icon: Icons.info_outline,
                                ),
                            ],
                            if (task.isRecurring) ...[
                              const Divider(),
                              _detail(
                                context,
                                Icons.repeat_rounded,
                                context.l10n.repeat,
                                '${context.repeatLabel(task)}${task.repeatUntil == null ? '' : ' · ${context.l10n.untilDate(context.shortDate(task.repeatUntil!))}'}',
                                onTap: canEdit ? edit : null,
                                tapHint: context.l10n.editTask,
                              ),
                            ],
                            // The default (low) priority goes unsaid.
                            if (task.priority > 1) ...[
                              const Divider(),
                              _detail(
                                context,
                                Icons.flag_outlined,
                                context.l10n.priority,
                                context.priorityName(task.priority),
                                color: AppTheme.priorityColor(
                                  context,
                                  task.priority,
                                ),
                                onTap: canEdit ? edit : null,
                                tapHint: context.l10n.editTask,
                              ),
                            ],
                          ],
                        ),
                      ),
                    if (!task.isNote) const SizedBox(height: 28),
                    // The notes come first, as in the form.
                    if (hasBody) ...[
                      _body(
                        context,
                        task,
                        onTap: task.isNote && canEdit ? edit : null,
                      ),
                      const SizedBox(height: 24),
                    ],
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
                                        .updateTask(
                                          series!.copyWith(
                                            reminderMinutes:
                                                updated.reminderMinutes,
                                            reminderTime: updated.reminderTime,
                                          ),
                                        );
                                  } catch (_) {
                                    if (context.mounted) {
                                      showFeedback(
                                        ScaffoldMessenger.of(context),
                                        context.l10n.updateReminderError,
                                      );
                                    }
                                  }
                                },
                        ),
                      ),
                    if (!task.isNote && task.reminderDate != null)
                      const SizedBox(height: 16),
                    if (task.checklist.isNotEmpty) ...[
                      SectionLabel(
                        context.l10n.checklistCount(
                          task.checklistDone,
                          task.checklist.length,
                        ),
                      ),
                      AppSurface(
                        child: Column(
                          children: [
                            LinearProgressIndicator(
                              value: task.checklistDone / task.checklist.length,
                              semanticsLabel: context.l10n.checklistSemantics(
                                task.checklistDone,
                                task.checklist.length,
                              ),
                            ),
                            for (final item in task.checklist)
                              CheckboxListTile(
                                contentPadding: EdgeInsets.zero,
                                key: ValueKey('check-step-${item.id}'),
                                controlAffinity:
                                    ListTileControlAffinity.leading,
                                title: Text(item.title),
                                value: item.done(
                                  occurrence: task.checklistOccurrence,
                                ),
                                onChanged: !canEdit
                                    ? null
                                    : (value) async {
                                        try {
                                          await ref
                                              .read(taskProvider.notifier)
                                              .setChecklistCompleted(
                                                task,
                                                item.id,
                                                value == true,
                                              );
                                        } catch (_) {
                                          if (context.mounted) {
                                            showFeedback(
                                              ScaffoldMessenger.of(context),
                                              context.l10n.stepUpdateError,
                                            );
                                          }
                                        }
                                      },
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                    AttachmentPanel(task: task, reveal: showFiles),
                  ],
                ),
              ),
              bottomNavigationBar: !canEdit
                  ? null
                  : task.isNote
                  ? SafeArea(
                      top: false,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
                        child: Center(
                          heightFactor: 1,
                          child: FilledButton.icon(
                            onPressed: edit,
                            icon: const Icon(Icons.edit_outlined),
                            label: Text(context.l10n.editNote),
                          ),
                        ),
                      ),
                    )
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
                              onPressed: () =>
                                  TaskInteractions.toggle(context, ref, task),
                              icon: Icon(
                                task.isCompleted
                                    ? Icons.undo_rounded
                                    : Icons.check_rounded,
                              ),
                              label: Text(
                                task.isCompleted
                                    ? context.l10n.reopen
                                    : context.l10n.complete,
                              ),
                            ),
                            OutlinedButton.icon(
                              onPressed: reschedule,
                              icon: const Icon(Icons.event_outlined),
                              label: Text(context.l10n.reschedule),
                            ),
                          ],
                        ),
                      ),
                    ),
            );
          },
          loading: () =>
              const Scaffold(body: Center(child: CircularProgressIndicator())),
          error: (_, __) => Scaffold(
            appBar: CustomAppBar(title: context.l10n.taskScreenTitle),
            body: EmptyState(
              title: context.l10n.loadTaskError,
              message: context.l10n.tryLater,
            ),
          ),
        );
  }

  Widget _detail(
    BuildContext context,
    IconData icon,
    String label,
    String value, {
    Color? color,
    VoidCallback? onTap,
    String? tapHint,
  }) {
    final colors = Theme.of(context).colorScheme;
    final row = Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          Icon(icon, color: color ?? colors.primary, size: 22),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: colors.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: Theme.of(
                    context,
                  ).textTheme.titleMedium!.copyWith(color: color),
                ),
              ],
            ),
          ),
        ],
      ),
    );
    return onTap == null
        ? row
        : Semantics(
            button: true,
            onTapHint: tapHint,
            child: InkWell(onTap: onTap, child: row),
          );
  }

  Widget _body(BuildContext context, Task task, {VoidCallback? onTap}) {
    final surface = AppSurface(
      padding: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        excludeFromSemantics: onTap != null,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: SizedBox(
            width: double.infinity,
            child: NoteText(task.notes!, onTap: onTap),
          ),
        ),
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionLabel(task.isNote ? context.l10n.noteBody : context.l10n.notes),
        // A note that opens the editor: one button, «Tu nota», with its
        // words, and what a double tap does. Its links stay apart.
        if (onTap == null)
          surface
        else
          Semantics(
            container: true,
            button: true,
            label: context.l10n.noteBody,
            value: task.notes,
            onTapHint: context.l10n.editNote,
            onTap: onTap,
            child: surface,
          ),
      ],
    );
  }
}
