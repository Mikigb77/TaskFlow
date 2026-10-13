import 'package:agenda/l10n/region.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:agenda/models/task.dart';
import 'package:agenda/providers/task_provider.dart';
import 'package:agenda/services/feedback_timeout.dart';

/// Shared by Calendar, Tasks and details, including keyboard/accessible buttons.
class TaskInteractions {
  static Future<void> toggle(
      BuildContext context, WidgetRef ref, Task task) async {
    final container = ProviderScope.containerOf(context, listen: false);
    final notifier = ref.read(taskProvider.notifier);
    final messenger = ScaffoldMessenger.of(context);
    final strings = context.l10n;
    try {
      final timeout = FeedbackTimeout.forAction();
      await notifier.setCompleted(task, !task.isCompleted);
      final duration = await timeout;
      if (!messenger.mounted ||
          !identical(container.read(taskProvider.notifier), notifier)) {
        return;
      }
      HapticFeedback.selectionClick();
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(SnackBar(
        // Snackbars with an action persist by default in the current SDK.
        persist: false,
        duration: duration,
        content: Text(
            task.isCompleted ? strings.taskReopened : strings.taskCompleted),
        action: SnackBarAction(
            label: strings.undo,
            onPressed: () async {
              if (!messenger.mounted ||
                  !identical(container.read(taskProvider.notifier), notifier)) {
                return;
              }
              try {
                await notifier.setCompleted(task, task.isCompleted);
              } catch (_) {
                _error(messenger, strings.undoError);
              }
            }),
      ));
    } catch (_) {
      _error(messenger, strings.taskUpdateError);
    }
  }

  static Future<void> reschedule(
      BuildContext context, WidgetRef ref, Task task) async {
    final container = ProviderScope.containerOf(context, listen: false);
    final notifier = ref.read(taskProvider.notifier);
    final messenger = ScaffoldMessenger.of(context);
    final strings = context.l10n;
    final result = await showModalBottomSheet<
            ({DateTime? date, bool hasTime, String scope})>(
        context: context,
        isScrollControlled: true,
        builder: (_) => _ScheduleSheet(task: task));
    if (result == null ||
        !messenger.mounted ||
        !identical(container.read(taskProvider.notifier), notifier)) {
      return;
    }
    try {
      final seriesChange = result.scope == 'series'
          ? await notifier.rescheduleTask(task.id!, result.date, result.hasTime)
          : null;
      final occurrenceChange = result.scope != 'series'
          ? await notifier.changeOccurrence(task, result.date, result.hasTime,
              skip: result.scope == 'skip', reset: result.scope == 'reset')
          : null;
      if (!messenger.mounted) return;
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(SnackBar(
          content: Text(result.scope == 'skip'
              ? strings.occurrenceSkippedNotice
              : result.scope == 'reset'
                  ? strings.originalRestored
                  : result.date == null
                      ? strings.movedInbox
                      : strings.scheduleUpdated),
          action: SnackBarAction(
              label: strings.undo,
              onPressed: () async {
                if (!messenger.mounted ||
                    !identical(
                        container.read(taskProvider.notifier), notifier)) {
                  return;
                }
                try {
                  final restored = seriesChange != null
                      ? await notifier.undoSchedule(seriesChange)
                      : await notifier.undoOccurrence(occurrenceChange!);
                  if (!restored) {
                    _error(messenger, strings.scheduleChangedAgain);
                  }
                } catch (_) {
                  _error(messenger, strings.undoError);
                }
              })));
    } catch (_) {
      _error(messenger, strings.scheduleError);
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
  late String _scope = widget.task.isRecurring ? 'occurrence' : 'series';
  late DateTime? _date = widget.task.displayDate;
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
        firstDate: pickerFirstDate(_date),
        lastDate: pickerLastDate(_date));
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
                        ? context.l10n.rescheduleRepeating
                        : context.l10n.rescheduleTask,
                    style: Theme.of(context).textTheme.titleLarge),
                if (widget.task.isRecurring)
                  Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(spacing: 8, children: [
                              for (final scope in ['occurrence', 'series'])
                                ChoiceChip(
                                    label: Text(scope == 'occurrence'
                                        ? context.l10n.thisOccurrence
                                        : context.l10n.wholeSeries),
                                    selected: _scope == scope,
                                    onSelected: (_) => setState(() {
                                          _scope = scope;
                                          _date = scope == 'series'
                                              ? widget.task.dueDate
                                              : widget.task.displayDate;
                                          _hasTime = scope == 'series'
                                              ? widget.task.seriesHasTime
                                              : widget.task.hasTime;
                                        }))
                            ]),
                            const SizedBox(height: 8),
                            Text(_scope == 'series'
                                ? context.l10n.seriesRescheduleHelp
                                : context.l10n.occurrenceRescheduleHelp),
                          ])),
                const SizedBox(height: 16),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  ActionChip(
                      label: Text(context.l10n.today),
                      onPressed: () => _setDay(DateTime.now())),
                  ActionChip(
                      label: Text(context.l10n.tomorrow),
                      onPressed: () {
                        final now = DateTime.now();
                        _setDay(DateTime(now.year, now.month, now.day + 1));
                      }),
                  if (_scope == 'series')
                    ActionChip(
                        label: Text(context.l10n.inbox),
                        onPressed: () => _setDay(null)),
                ]),
                ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.calendar_today_outlined),
                    title: Text(_date == null
                        ? context.l10n.inboxDate
                        : DateFormat.yMMMEd(context.localeName).format(_date!)),
                    subtitle: Text(context.l10n.chooseDate),
                    onTap: _pickDay),
                if (_date != null)
                  ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.schedule_rounded),
                      title: Text(_hasTime
                          ? TimeOfDay.fromDateTime(_date!).format(context)
                          : context.l10n.anyTime),
                      subtitle: Text(context.l10n.chooseTime),
                      trailing: _hasTime
                          ? IconButton(
                              tooltip: context.l10n.removeTime,
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
                        onPressed: () => Navigator.pop(context,
                            (date: _date, hasTime: _hasTime, scope: _scope)),
                        child: Text(context.l10n.saveSchedule))),
                if (widget.task.isRecurring && _scope == 'occurrence') ...[
                  TextButton.icon(
                      onPressed: () => Navigator.pop(
                          context, (date: null, hasTime: false, scope: 'skip')),
                      icon: const Icon(Icons.event_busy_outlined),
                      label: Text(context.l10n.skipOccurrence)),
                  if (widget.task.exceptions.any((change) =>
                      change.originalDate == widget.task.occurrenceId))
                    TextButton(
                        onPressed: () => Navigator.pop(context,
                            (date: null, hasTime: false, scope: 'reset')),
                        child: Text(context.l10n.restoreOriginal)),
                ],
              ])));
}
