import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:agenda/models/task.dart';
import 'package:agenda/providers/task_provider.dart';

/// Shared by Calendar, Tasks and details, including keyboard/accessible buttons.
class TaskInteractions {
  static Future<void> toggle(
      BuildContext context, WidgetRef ref, Task task) async {
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
              if (!messenger.mounted ||
                  !identical(container.read(taskProvider.notifier), notifier)) {
                return;
              }
              try {
                await notifier.setCompleted(task, task.isCompleted);
              } catch (_) {
                _error(messenger, 'Could not undo. Please try again.');
              }
            }),
      ));
    } catch (_) {
      _error(messenger, 'Could not update this task. Please try again.');
    }
  }

  static Future<void> reschedule(
      BuildContext context, WidgetRef ref, Task task) async {
    final container = ProviderScope.containerOf(context, listen: false);
    final notifier = ref.read(taskProvider.notifier);
    final messenger = ScaffoldMessenger.of(context);
    final result = await showModalBottomSheet<({DateTime? date, bool hasTime})>(
        context: context,
        isScrollControlled: true,
        builder: (_) => _ScheduleSheet(task: task));
    if (result == null ||
        !messenger.mounted ||
        !identical(container.read(taskProvider.notifier), notifier)) {
      return;
    }
    try {
      final change =
          await notifier.rescheduleTask(task.id!, result.date, result.hasTime);
      if (!messenger.mounted) return;
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(SnackBar(
          content:
              Text(result.date == null ? 'Moved to Inbox' : 'Schedule updated'),
          action: SnackBarAction(
              label: 'Undo',
              onPressed: () async {
                if (!messenger.mounted ||
                    !identical(
                        container.read(taskProvider.notifier), notifier)) {
                  return;
                }
                try {
                  if (!await notifier.undoSchedule(change)) {
                    _error(messenger,
                        'The schedule changed again. Open the task to review it.');
                  }
                } catch (_) {
                  _error(messenger, 'Could not undo. Please try again.');
                }
              })));
    } catch (_) {
      _error(messenger, 'Could not change the schedule. Please try again.');
    }
  }

  static void _error(ScaffoldMessengerState messenger, String text) {
    if (messenger.mounted) {
      messenger.showSnackBar(SnackBar(content: Text(text)));
    }
  }
}

class _ScheduleSheet extends StatefulWidget {
  final Task task;
  const _ScheduleSheet({required this.task});
  @override
  State<_ScheduleSheet> createState() => _ScheduleSheetState();
}

class _ScheduleSheetState extends State<_ScheduleSheet> {
  late DateTime? _date = widget.task.dueDate;
  late bool _hasTime = widget.task.hasTime;
  void _setDay(DateTime? day) => setState(() {
        _date = day == null
            ? null
            : DateTime(day.year, day.month, day.day, _hasTime ? _date!.hour : 0,
                _hasTime ? _date!.minute : 0);
        if (day == null) _hasTime = false;
      });

  Future<void> _pickDay() async {
    final date = await showDatePicker(
        context: context,
        initialDate: _date ?? DateTime.now(),
        firstDate: DateTime(2000),
        lastDate: DateTime(2101));
    if (date != null && mounted) _setDay(date);
  }

  @override
  Widget build(BuildContext context) => SafeArea(
      child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    widget.task.isRecurring
                        ? 'Reschedule repeating task'
                        : 'Reschedule task',
                    style: Theme.of(context).textTheme.titleLarge),
                if (widget.task.isRecurring)
                  const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text(
                          'This changes the start of the whole series. Moving to Inbox stops the repeat.')),
                const SizedBox(height: 16),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  ActionChip(
                      label: const Text('Today'),
                      onPressed: () => _setDay(DateTime.now())),
                  ActionChip(
                      label: const Text('Tomorrow'),
                      onPressed: () {
                        final now = DateTime.now();
                        _setDay(DateTime(now.year, now.month, now.day + 1));
                      }),
                  ActionChip(
                      label: const Text('Inbox'),
                      onPressed: () => _setDay(null)),
                ]),
                ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.calendar_today_outlined),
                    title: Text(_date == null
                        ? 'No date · Inbox'
                        : DateFormat.yMMMEd().format(_date!)),
                    subtitle: const Text('Choose date'),
                    onTap: _pickDay),
                if (_date != null)
                  ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.schedule_rounded),
                      title: Text(_hasTime
                          ? TimeOfDay.fromDateTime(_date!).format(context)
                          : 'Any time'),
                      subtitle: const Text('Choose time'),
                      trailing: _hasTime
                          ? IconButton(
                              tooltip: 'Remove time',
                              icon: const Icon(Icons.close_rounded),
                              onPressed: () => setState(() {
                                    _hasTime = false;
                                    _date = Task.day(_date!);
                                  }))
                          : null,
                      onTap: () async {
                        final time = await showTimePicker(
                            context: context,
                            initialTime: _hasTime
                                ? TimeOfDay.fromDateTime(_date!)
                                : const TimeOfDay(hour: 9, minute: 0));
                        if (time != null && mounted) {
                          setState(() {
                            _date = DateTime(_date!.year, _date!.month,
                                _date!.day, time.hour, time.minute);
                            _hasTime = true;
                          });
                        }
                      }),
                const SizedBox(height: 16),
                SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                        onPressed: () => Navigator.pop(
                            context, (date: _date, hasTime: _hasTime)),
                        child: const Text('Save schedule'))),
              ])));
}
