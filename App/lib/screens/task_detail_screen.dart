import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:collection/collection.dart';
import 'package:intl/intl.dart';
import 'package:open_file/open_file.dart';
import 'package:path/path.dart' as path;
import 'package:agenda/models/task.dart';
import 'package:agenda/providers/task_provider.dart';
import 'package:agenda/theme/app_theme.dart';
import 'package:agenda/widgets/custom_app_bar.dart';
import 'package:agenda/widgets/app_components.dart';
import 'package:agenda/widgets/reminder_control.dart';

class TaskDetailScreen extends ConsumerWidget {
  const TaskDetailScreen(
      {super.key, required this.taskId, this.occurrenceDate});
  final int taskId;
  final DateTime? occurrenceDate;

  Future<void> _delete(BuildContext context, WidgetRef ref, Task task) async {
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
                title: const Text('Delete task?'),
                content: Text(task.isRecurring
                    ? '“${task.title}” and all its occurrences will be removed.'
                    : '“${task.title}” will be removed.'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Keep task')),
                  FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Delete'))
                ]));
    if (confirmed != true || !context.mounted) return;
    try {
      await ref.read(taskProvider.notifier).deleteTask(taskId);
      if (context.mounted) Navigator.pop(context);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Could not delete this task. Please try again.')));
      }
    }
  }

  Future<void> _open(BuildContext context, String file) async {
    try {
      final result = await OpenFile.open(file);
      if (result.type.name != 'done' && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('This attachment is not available on this device.')));
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not open this attachment.')));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    return ref.watch(taskProvider).when(
          data: (tasks) {
            final series = tasks.firstWhereOrNull((task) => task.id == taskId);
            final task = occurrenceDate == null
                ? series
                : series?.occurrenceOn(occurrenceDate!);
            if (task == null) {
              return const Scaffold(
                  appBar: CustomAppBar(title: 'Task details'),
                  body: EmptyState(
                      title: 'Task unavailable',
                      message: 'This task may have been removed.'));
            }
            final attachments = [...task.filePaths, ...task.imagePaths]
                .where((file) => file.isNotEmpty)
                .toList();
            return Scaffold(
              appBar: CustomAppBar(title: 'Task details', actions: [
                IconButton(
                    tooltip: 'Delete task',
                    onPressed: () => _delete(context, ref, task),
                    icon: Icon(Icons.delete_outline_rounded,
                        color: colors.onSurfaceVariant))
              ]),
              body: ListView(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
                  children: [
                    SectionLabel(
                        task.isCompleted ? 'Completed' : 'Your next step'),
                    Text(task.title,
                        style: Theme.of(context).textTheme.headlineLarge),
                    const SizedBox(height: 24),
                    AppSurface(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 8),
                        child: Column(children: [
                          _detail(
                              context,
                              Icons.calendar_today_outlined,
                              task.isRecurring ? 'Starts' : 'Date',
                              task.displayDate == null
                                  ? 'No date · Inbox'
                                  : DateFormat('EEEE, d MMMM yyyy')
                                      .format(task.displayDate!)),
                          const Divider(),
                          _detail(
                              context,
                              Icons.schedule_outlined,
                              'Time',
                              task.hasTime
                                  ? DateFormat('HH:mm')
                                      .format(task.displayDate!)
                                  : 'Any time'),
                          if (task.isRecurring) ...[
                            const Divider(),
                            _detail(context, Icons.repeat_rounded, 'Repeat',
                                '${Task.repeats[task.recurrence]}${task.repeatUntil == null ? '' : ' until ${DateFormat('d MMM yyyy').format(task.repeatUntil!)}'}'),
                          ],
                          const Divider(),
                          _detail(context, Icons.flag_outlined, 'Priority',
                              AppTheme.priorityLabel(task.priority),
                              color: AppTheme.priorityColor(
                                  context, task.priority)),
                        ])),
                    const SizedBox(height: 28),
                    const SectionLabel('Notes'),
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
                                        const SnackBar(
                                            content: Text(
                                                'Could not update the reminder. Please retry.')));
                                  }
                                }
                              })),
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
                      child: FilledButton.icon(
                          onPressed: () => Navigator.pushNamed(
                              context, '/editTask',
                              arguments: taskId),
                          icon: const Icon(Icons.edit_outlined, size: 20),
                          label: const Text('Edit task')))),
            );
          },
          loading: () =>
              const Scaffold(body: Center(child: CircularProgressIndicator())),
          error: (_, __) => const Scaffold(
              appBar: CustomAppBar(title: 'Task details'),
              body: EmptyState(
                  title: 'Couldn’t load this task',
                  message: 'Please try again in a moment.')),
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
