import 'package:agenda/l10n/region.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:collection/collection.dart';
import 'package:open_file/open_file.dart';
import 'package:path/path.dart' as path;
import 'package:agenda/models/task.dart';
import 'package:agenda/providers/task_provider.dart';
import 'package:agenda/theme/app_theme.dart';
import 'package:agenda/widgets/custom_app_bar.dart';
import 'package:agenda/widgets/app_components.dart';
import 'package:agenda/widgets/reminder_control.dart';
import 'package:agenda/widgets/task_interactions.dart';
import 'package:agenda/widgets/task_list_picker.dart';

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
                title: Text(context.l10n.deleteTaskQuestion),
                content: Text(task.isRecurring
                    ? '“${task.title}” and all its occurrences will be removed.'
                    : '“${task.title}” will be removed.'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: Text(context.l10n.keepTask)),
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

  Future<void> _open(BuildContext context, String file) async {
    try {
      final result = await OpenFile.open(file);
      if (result.type.name != 'done' && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.l10n.attachmentUnavailable)));
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.l10n.attachmentOpenError)));
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
            final attachments = [...task.filePaths, ...task.imagePaths]
                .where((file) => file.isNotEmpty)
                .toList();
            return Scaffold(
              appBar: CustomAppBar(title: context.l10n.taskDetails, actions: [
                IconButton(
                    tooltip: context.l10n.editTask,
                    onPressed: () => Navigator.pushNamed(context, '/editTask',
                        arguments: taskId),
                    icon: const Icon(Icons.edit_outlined)),
                IconButton(
                    tooltip: context.l10n.deleteTask,
                    onPressed: () => _delete(context, ref, task),
                    icon: Icon(Icons.delete_outline_rounded,
                        color: colors.onSurfaceVariant))
              ]),
              body: ListView(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
                  children: [
                    SectionLabel(task.isCompleted
                        ? context.l10n.completed
                        : context.l10n.nextStep),
                    Text(task.title,
                        style: Theme.of(context).textTheme.headlineLarge),
                    const SizedBox(height: 12),
                    Align(
                        alignment: Alignment.centerLeft,
                        child: TaskListPicker(
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
                    AppSurface(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 8),
                        child: Column(children: [
                          _detail(
                              context,
                              Icons.calendar_today_outlined,
                              task.occurrenceDate != null
                                  ? context.l10n.occurrence
                                  : task.isRecurring
                                      ? context.l10n.starts
                                      : context.l10n.date,
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
                    const SizedBox(height: 28),
                    if (task.dueDate != null)
                      Align(
                          alignment: Alignment.centerLeft,
                          child: ReminderChip(
                              task: task,
                              onChanged: (updated) async {
                                try {
                                  await ref
                                      .read(taskProvider.notifier)
                                      .updateTask(series!.copyWith(
                                          reminderMinutes:
                                              updated.reminderMinutes,
                                          reminderTime: updated.reminderTime));
                                } catch (_) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                            content: Text(context
                                                .l10n.updateReminderError)));
                                  }
                                }
                              })),
                    const SizedBox(height: 16),
                    if (task.checklist.isNotEmpty) ...[
                      SectionLabel(
                          'Checklist · ${task.checklistDone}/${task.checklist.length}'),
                      AppSurface(
                          child: Column(children: [
                        LinearProgressIndicator(
                            value: task.checklistDone / task.checklist.length,
                            semanticsLabel:
                                'Checklist, ${task.checklistDone} of ${task.checklist.length} steps completed'),
                        for (final item in task.checklist)
                          CheckboxListTile(
                              contentPadding: EdgeInsets.zero,
                              key: ValueKey('check-step-${item.id}'),
                              controlAffinity: ListTileControlAffinity.leading,
                              title: Text(item.title),
                              value: item.done(
                                  occurrence: task.checklistOccurrence),
                              onChanged: (value) async {
                                try {
                                  await ref
                                      .read(taskProvider.notifier)
                                      .setChecklistCompleted(
                                          task, item.id, value == true);
                                } catch (_) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                            content: Text(
                                                'Could not update this step. Please retry.')));
                                  }
                                }
                              }),
                        const Text(
                            'Completing the checklist does not complete the task. Use Complete when you are finished.'),
                      ])),
                      const SizedBox(height: 24),
                    ],
                    SectionLabel(context.l10n.notes),
                    AppSurface(
                        child: SizedBox(
                            width: double.infinity,
                            child: Text(
                                task.notes?.trim().isNotEmpty == true
                                    ? task.notes!
                                    : 'No notes added.',
                                style: TextStyle(
                                    color: colors.onSurfaceVariant,
                                    height: 1.6)))),
                    if (attachments.isNotEmpty) ...[
                      const SizedBox(height: 28),
                      const SectionLabel('On this device'),
                      for (final file in attachments)
                        Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: AppSurface(
                                padding: EdgeInsets.zero,
                                child: ListTile(
                                    leading: task.imagePaths.contains(file)
                                        ? ClipRRect(
                                            borderRadius:
                                                BorderRadius.circular(8),
                                            child: Image.file(File(file),
                                                width: 40,
                                                height: 40,
                                                fit: BoxFit.cover,
                                                errorBuilder: (_, __, ___) =>
                                                    const Icon(Icons
                                                        .image_not_supported_outlined)))
                                        : const Icon(
                                            Icons.insert_drive_file_outlined),
                                    title: Text(path.basename(file),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis),
                                    trailing: const Icon(
                                        Icons.open_in_new_rounded,
                                        size: 18),
                                    onTap: () => _open(context, file)))),
                    ],
                  ]),
              bottomNavigationBar: SafeArea(
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
                                icon: Icon(task.isCompleted
                                    ? Icons.undo_rounded
                                    : Icons.check_rounded),
                                label: Text(task.isCompleted
                                    ? context.l10n.reopen
                                    : context.l10n.complete)),
                            OutlinedButton.icon(
                                onPressed: () => TaskInteractions.reschedule(
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
                  title: 'Couldn’t load this task',
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
}
