import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:agenda/providers/reminder_provider.dart';
import 'package:agenda/services/reminder_preferences.dart';
import 'package:agenda/models/task.dart';

class ReminderChip extends ConsumerWidget {
  final Task task;
  final ValueChanged<Task>? onChanged;
  const ReminderChip({super.key, required this.task, this.onChanged});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preferences = ref.watch(reminderPreferencesProvider).valueOrNull ??
        const ReminderPreferences();
    final minute = task.reminderTime ?? preferences.dateOnlyTime;
    final label = task.reminderMinutes == -1
        ? 'Off'
        : task.hasTime
            ? reminderLeadLabel(task.reminderMinutes ?? preferences.leadMinutes)
            : minute == null
                ? 'Off'
                : TimeOfDay(hour: minute ~/ 60, minute: minute % 60)
                    .format(context);
    return ActionChip(
        avatar: const Icon(Icons.notifications_outlined, size: 16),
        label: Text(
            'Reminder: $label${preferences.enabled ? '' : ' · device off'}'),
        onPressed: onChanged == null
            ? null
            : () async {
                var edited = task;
                final result = await showModalBottomSheet<Task>(
                    context: context,
                    isScrollControlled: true,
                    builder: (context) => StatefulBuilder(
                        builder: (context, update) => SafeArea(
                            child: SingleChildScrollView(
                                padding: const EdgeInsets.all(24),
                                child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      ReminderControl(
                                          hasDate: edited.dueDate != null,
                                          hasTime: edited.hasTime,
                                          minutes: edited.reminderMinutes,
                                          time: edited.reminderTime,
                                          onMinutes: (value) => update(() =>
                                              edited = edited.copyWith(
                                                  reminderMinutes: value)),
                                          onTime: (value) => update(() =>
                                              edited = edited.copyWith(
                                                  reminderTime: value))),
                                      const SizedBox(height: 12),
                                      FilledButton(
                                          onPressed: () =>
                                              Navigator.pop(context, edited),
                                          child: const Text('Use reminder')),
                                    ])))));
                if (result != null) onChanged?.call(result);
              });
  }
}

class ReminderControl extends ConsumerWidget {
  final bool hasDate;
  final bool hasTime;
  final int? minutes;
  final int? time;
  final ValueChanged<int?> onMinutes;
  final ValueChanged<int?> onTime;
  const ReminderControl(
      {super.key,
      required this.hasDate,
      required this.hasTime,
      this.minutes,
      this.time,
      required this.onMinutes,
      required this.onTime});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preferences = ref.watch(reminderPreferencesProvider);
    final settings = preferences.valueOrNull ?? const ReminderPreferences();
    final minute = time ?? settings.dateOnlyTime;
    final label = !hasDate
        ? 'Add a date to use a reminder'
        : hasTime
            ? '${reminderLeadLabel(minutes ?? settings.leadMinutes)}${minutes == null ? ' · default' : ''}'
            : minutes == -1 || minute == null
                ? 'Off'
                : TimeOfDay(hour: minute ~/ 60, minute: minute % 60)
                    .format(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.notifications_outlined),
          title: const Text('Reminder'),
          subtitle: Text(label),
          trailing: hasDate
              ? PopupMenuButton<int>(
                  tooltip: 'Choose reminder',
                  onSelected: (value) => onMinutes(value == -2 ? null : value),
                  itemBuilder: (_) => [
                        for (final value in hasTime
                            ? <int>{
                                -2,
                                -1,
                                0,
                                10,
                                30,
                                60,
                                1440,
                                if (minutes != null) minutes!
                              }
                            : <int>{-2, -1})
                          PopupMenuItem(
                              value: value,
                              child: Text(reminderLeadLabel(
                                  value == -2 ? null : value)))
                      ])
              : null),
      if (hasDate && !hasTime)
        Wrap(spacing: 8, children: [
          TextButton(
              onPressed: () async {
                final value = await showTimePicker(
                    context: context,
                    initialTime: TimeOfDay(
                        hour: (minute ?? 540) ~/ 60,
                        minute: (minute ?? 540) % 60));
                if (value != null) {
                  onMinutes(null);
                  onTime(value.hour * 60 + value.minute);
                }
              },
              child: const Text('Choose alert time')),
          if (time != null)
            TextButton(
                onPressed: () => onTime(null),
                child: const Text('Use default time')),
        ]),
      if (preferences.hasError)
        const Text(
            'Reminder defaults could not load. Check notification settings.'),
      if (preferences.isLoading) const Text('Loading reminder settings…'),
      if (!preferences.isLoading && !settings.enabled)
        TextButton.icon(
            onPressed: () => Navigator.pushNamed(context, '/notifications'),
            icon: const Icon(Icons.notifications_off_outlined, size: 18),
            label: const Text('Reminders are off on this device')),
    ]);
  }
}
