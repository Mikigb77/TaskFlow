import 'package:agenda/l10n/region.dart';
import 'package:agenda/models/task.dart';
import 'package:agenda/widgets/app_components.dart';
import 'package:flutter/material.dart';

String taskDeadlineLabel(BuildContext context, Task task) {
  final date = task.displayDeadline;
  if (date == null) return context.l10n.deadlineUnset;
  return context.l10n.deadlineLabel(
      '${context.shortDate(date)}${task.deadlineHasTime ? ' · ${context.clockTime(date)}' : ''}');
}

/// Optional planning controls, kept behind More details for ordinary capture.
class TaskPlanningControl extends StatelessWidget {
  const TaskPlanningControl(
      {super.key, required this.task, required this.onChanged});
  final Task task;
  final ValueChanged<Task>? onChanged;

  Future<void> _duration(BuildContext context) async {
    var text = task.durationMinutes?.toString() ?? '';
    final form = GlobalKey<FormState>();
    final result = await showDialog<int>(
        context: context,
        builder: (context) => AlertDialog(
              title: Text(context.l10n.duration),
              content: SingleChildScrollView(
                  child: Form(
                      key: form,
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        TextFormField(
                            key: const ValueKey('duration-input'),
                            initialValue: text,
                            onChanged: (value) => text = value,
                            keyboardType: TextInputType.number,
                            autofocus: true,
                            decoration: InputDecoration(
                                labelText: context.l10n.durationInput),
                            validator: (value) {
                              final number = int.tryParse(value ?? '');
                              return number == null ||
                                      number < 1 ||
                                      number > 1440
                                  ? context.l10n.durationInvalid
                                  : null;
                            }),
                        const SizedBox(height: 12),
                        Wrap(spacing: 8, children: [
                          for (final minutes in [15, 30, 60, 90])
                            ActionChip(
                                label:
                                    Text(context.l10n.durationMinutes(minutes)),
                                onPressed: () =>
                                    Navigator.pop(context, minutes))
                        ]),
                      ]))),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(context.l10n.cancel)),
                FilledButton(
                    key: const ValueKey('duration-save'),
                    onPressed: () {
                      if (form.currentState!.validate()) {
                        Navigator.pop(context, int.parse(text));
                      }
                    },
                    child: Text(context.l10n.save))
              ],
            ));
    if (result != null) onChanged?.call(task.copyWith(durationMinutes: result));
  }

  Future<void> _deadline(BuildContext context) async {
    final initial = task.deadline ?? task.dueDate ?? DateTime.now();
    final date = await showDatePicker(
        context: context,
        initialDate: initial,
        firstDate: pickerFirstDate(initial),
        lastDate: pickerLastDate(initial));
    if (date == null) return;
    final old = task.deadline;
    onChanged?.call(task.copyWith(
        deadline: DateTime(
            date.year,
            date.month,
            date.day,
            task.deadlineHasTime ? old!.hour : 0,
            task.deadlineHasTime ? old!.minute : 0),
        reminderAnchor:
            task.dueDate == null ? 'deadline' : task.reminderAnchor));
  }

  Future<void> _time(BuildContext context) async {
    final date = task.deadline!;
    final value = await showTimePicker(
        context: context,
        initialTime: task.deadlineHasTime
            ? TimeOfDay.fromDateTime(date)
            : const TimeOfDay(hour: 17, minute: 0));
    if (value == null) return;
    onChanged?.call(task.copyWith(
        deadline:
            DateTime(date.year, date.month, date.day, value.hour, value.minute),
        deadlineHasTime: true));
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SectionLabel(l.planning),
      ListTile(
          key: const ValueKey('task-duration'),
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.timelapse_outlined),
          title: Text(l.duration),
          subtitle: Text(task.durationMinutes == null
              ? l.durationUnset
              : '${l.durationMinutes(task.durationMinutes!)}${task.hasTime ? '' : '\n${l.durationEstimateHelp}'}'),
          onTap: onChanged == null ? null : () => _duration(context),
          trailing: task.durationMinutes == null
              ? const Icon(Icons.add_rounded)
              : IconButton(
                  tooltip: l.removeDuration,
                  onPressed: onChanged == null
                      ? null
                      : () => onChanged!(task.copyWith(durationMinutes: null)),
                  icon: const Icon(Icons.close_rounded))),
      ListTile(
          key: const ValueKey('task-deadline'),
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.flag_outlined),
          title: Text(taskDeadlineLabel(context, task)),
          subtitle: Text(l.deadlineHelp),
          onTap: onChanged == null ? null : () => _deadline(context),
          trailing: task.deadline == null
              ? const Icon(Icons.add_rounded)
              : IconButton(
                  tooltip: l.removeDeadline,
                  onPressed: onChanged == null
                      ? null
                      : () => onChanged!(task.copyWith(
                          deadline: null,
                          deadlineHasTime: false,
                          reminderAnchor: 'planned')),
                  icon: const Icon(Icons.close_rounded))),
      if (task.deadline != null) ...[
        ListTile(
            key: const ValueKey('task-deadline-time'),
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.schedule_outlined),
            title: Text(l.deadlineTime),
            subtitle: Text(task.deadlineHasTime
                ? context.clockTime(task.deadline!)
                : l.deadlineEndDay),
            onTap: onChanged == null ? null : () => _time(context),
            trailing: task.deadlineHasTime
                ? IconButton(
                    tooltip: l.removeTime,
                    onPressed: onChanged == null
                        ? null
                        : () => onChanged!(task.copyWith(
                            deadline: Task.day(task.deadline!),
                            deadlineHasTime: false)),
                    icon: const Icon(Icons.close_rounded))
                : const Icon(Icons.add_rounded)),
        if (task.isRecurring)
          Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(l.deadlineRecurringHelp)),
        DropdownButtonFormField<String>(
            key: ValueKey('reminder-anchor-${task.reminderAnchor}'),
            initialValue: task.reminderAnchor,
            isExpanded: true,
            decoration: InputDecoration(labelText: l.reminderAnchor),
            items: [
              DropdownMenuItem(value: 'planned', child: Text(l.plannedFor)),
              DropdownMenuItem(value: 'deadline', child: Text(l.deadline))
            ],
            onChanged: onChanged == null
                ? null
                : (value) => onChanged!(task.copyWith(reminderAnchor: value))),
        Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(l.reminderAnchorHelp)),
      ],
      if (task.plannedAfterDeadline)
        MessageBanner(l.deadlineLatePlan, icon: Icons.info_outline),
    ]);
  }
}
