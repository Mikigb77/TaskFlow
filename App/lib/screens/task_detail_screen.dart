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
import 'package:agenda/services/reminder_plans.dart';
import 'package:agenda/theme/app_theme.dart';
import 'package:agenda/widgets/custom_app_bar.dart';
import 'package:agenda/widgets/app_components.dart';
import 'package:agenda/widgets/reminder_control.dart';
import 'package:agenda/widgets/task_interactions.dart';
import 'package:agenda/widgets/task_assignment_picker.dart';
import 'package:agenda/widgets/attachment_panel.dart';
import 'package:agenda/widgets/note_text.dart';

class TaskDetailScreen extends ConsumerStatefulWidget {
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

  @override
  ConsumerState<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends ConsumerState<TaskDetailScreen> {
  int get taskId => widget.taskId;

  /// The occurrence the page opened with. It stays while the page is open,
  /// so a tick doesn't move the page on to the next one.
  String? _pinned;

  /// The task as it was when Completar closed the page: shown unchanged
  /// while the page leaves.
  Task? _leaving;

  /// Completar was tapped: the page holds until it pops, its buttons off
  /// and the whole page taking no taps (UX-2633).
  bool _closing = false;

  /// Ticks the task and closes the page, as Back does, so the message and
  /// the ticked row show in the list under it. Reopening keeps the page.
  /// The page holds for 300 ms first, so a hesitant second tap lands on its
  /// own dead button rather than on the screen under it (UX-2623). If
  /// something opened over the page meanwhile (TalkBack can still reach it),
  /// the page stays and shows the ticked task, so it never stays frozen.
  Future<void> _toggle(Task task) async {
    if (task.isCompleted) {
      unawaited(TaskInteractions.toggle(context, ref, task));
      return;
    }
    setState(() {
      _leaving = task;
      _closing = true;
    });
    unawaited(TaskInteractions.toggle(context, ref, task));
    await Future<void>.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;
    final route = ModalRoute.of(context);
    if (route?.isCurrent ?? false) {
      Navigator.pop(context);
    } else if (route?.isActive ?? false) {
      // A route, sheet or dialog opened over it: stay, showing the task as
      // it is now.
      setState(() {
        _closing = false;
        _leaving = null;
      });
    }
    // Otherwise Back has already closed it.
  }

  /// Deletes at once, with Undo. Only a whole repeating series asks first.
  Future<void> _delete(Task task) async {
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
      if (confirmed != true || !mounted) return;
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
    if (mounted) Navigator.pop(context);
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
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final occurrenceKey = widget.occurrenceKey;
    final occurrenceDate = widget.occurrenceDate;
    return ref
        .watch(taskProvider)
        .when(
          data: (tasks) {
            final series = tasks.firstWhereOrNull((task) => task.id == taskId);
            final pinned = _pinned == null
                ? null
                : series?.occurrenceByKey(_pinned!) ??
                      series?.completedOccurrence(_pinned!);
            final task =
                _leaving ??
                pinned ??
                (occurrenceKey != null
                    ? series?.occurrenceByKey(occurrenceKey) ??
                          series?.completedOccurrence(occurrenceKey)
                    : occurrenceDate == null
                    ? (series?.isRecurring == true
                          ? series?.nextOpenOccurrence() ?? series
                          : series)
                    : series?.occurrenceOn(occurrenceDate) ??
                          series?.nextOpenOccurrence() ??
                          series);
            // Pinned at the first build; picked again only once the pinned
            // one is gone (the series moved, or that day was skipped).
            if (pinned == null) _pinned = task?.occurrenceId;
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
            final reminderShown =
                (task.reminderDate != null ||
                    ReminderPlans.active(task) != null) &&
                reminderShows(ref, task);
            // A reader chooses their own reminders on the tasks that ring
            // for them, and nothing else (D9).
            final ownReminders =
                !canEdit &&
                !task.isNote &&
                project?.role == 'viewer' &&
                reminderRingsHere(ref, task);
            final dated = task.displayDate != null || task.deadline == null;
            void edit() =>
                Navigator.pushNamed(context, '/editTask', arguments: taskId);
            void reschedule() =>
                TaskInteractions.reschedule(context, ref, task);
            // Inert while Completar closes it: nothing on the page opens in
            // the hold (UX-2633).
            return AbsorbPointer(
              absorbing: _closing,
              child: Scaffold(
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
                            ? context.l10n.deleteNote
                            : context.l10n.deleteTask,
                        onPressed: () => _delete(task),
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
                              : ownReminders
                              ? context.l10n.viewOnlyTaskReminders
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
                                          task.isNote
                                              ? context.l10n.moveNoteError
                                              : context.l10n.moveError,
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
                      // Labels are information, not controls: one line of text.
                      if (task.labels.isNotEmpty)
                        Text(
                          task.labels.map((label) => '#$label').join(' · '),
                          key: const ValueKey('task-labels'),
                          style: Theme.of(context).textTheme.bodyMedium!
                              .copyWith(color: colors.onSurfaceVariant),
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
                              // One row for the day and, when set, its time.
                              // A task with only a deadline has no day to say.
                              if (dated)
                                _detail(
                                  context,
                                  Icons.calendar_today_outlined,
                                  context.l10n.plannedFor,
                                  task.displayDate == null
                                      ? context.l10n.noDate
                                      : '${context.dayHeading(task.displayDate!, DateTime.now())}${task.hasTime ? ' ·\u00A0${context.clockTime(task.displayDate!)}' : ''}',
                                  onTap: canEdit ? reschedule : null,
                                  tapHint: context.l10n.reschedule,
                                ),
                              if (task.durationMinutes != null) ...[
                                if (dated) const Divider(),
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
                                if (dated || task.durationMinutes != null)
                                  const Divider(),
                                _detail(
                                  context,
                                  Icons.flag_outlined,
                                  context.l10n.deadline,
                                  task.deadlinePassed(DateTime.now())
                                      ? context.deadlinePassedLine(task)
                                      : taskDeadlineLabel(context, task),
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
                      // The task's reminder, or its plan's one line; none when
                      // its reminders are someone else's and it names nobody.
                      if (reminderShown)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: ReminderChip(
                            task: task,
                            onChanged: !canEdit && !ownReminders
                                ? null
                                : (updated) async {
                                    final tasks = ref.read(
                                      taskProvider.notifier,
                                    );
                                    try {
                                      if (canEdit) {
                                        await tasks.updateTask(
                                          series!.copyWith(
                                            reminderMinutes:
                                                updated.reminderMinutes,
                                            reminderTime: updated.reminderTime,
                                            reminderPlan: updated.reminderPlan,
                                          ),
                                        );
                                      } else {
                                        await tasks.setOwnReminders(
                                          series!.id!,
                                          minutes: updated.reminderMinutes,
                                          time: updated.reminderTime,
                                          plan: updated.reminderPlan,
                                        );
                                      }
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
                      if (!task.isNote && reminderShown)
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
                                value:
                                    task.checklistDone / task.checklist.length,
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
                      AttachmentPanel(task: task, reveal: widget.showFiles),
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
                                onPressed: _closing
                                    ? null
                                    : () => unawaited(_toggle(task)),
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
                                onPressed: _closing ? null : reschedule,
                                icon: const Icon(Icons.event_outlined),
                                label: Text(context.l10n.reschedule),
                              ),
                            ],
                          ),
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
        // One node, «Notas» or «Tu nota», with the words as its value. A
        // note that opens the editor is a button that says what a double
        // tap does; read-only words are not a field. Links stay apart.
        if (onTap == null)
          Semantics(
            container: true,
            label: task.isNote ? context.l10n.noteBody : context.l10n.notes,
            value: task.notes,
            child: surface,
          )
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
