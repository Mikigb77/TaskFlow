import 'package:agenda/l10n/region.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:agenda/providers/reminder_provider.dart';
import 'package:agenda/services/reminder_preferences.dart';
import 'package:agenda/models/task.dart';
import 'package:agenda/services/notification_service.dart';

final reminderCapabilityProvider = FutureProvider.autoDispose<bool>((
  ref,
) async {
  ref.watch(reminderPreferencesProvider);
  if (!TaskReminders.supported) return true;
  await TaskReminders.initialize();
  return (await TaskReminders.engine.driver.capability()).allowed;
});

class ReminderChip extends ConsumerWidget {
  final Task task;
  final ValueChanged<Task>? onChanged;
  const ReminderChip({super.key, required this.task, this.onChanged});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preferences =
        ref.watch(reminderPreferencesProvider).valueOrNull ??
        const ReminderPreferences();
    final minute = task.reminderTime ?? preferences.dateOnlyTime;
    final label = task.reminderMinutes == -1
        ? context.l10n.off
        : task.reminderHasTime
        ? context.reminderLead(task.reminderMinutes ?? preferences.leadMinutes)
        : minute == null
        ? context.l10n.off
        : TimeOfDay(hour: minute ~/ 60, minute: minute % 60).format(context);
    return LayoutBuilder(
      builder: (context, constraints) => ActionChip(
        avatar: const Icon(Icons.notifications_outlined, size: 16),
        label: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth:
                ((constraints.maxWidth.isFinite
                            ? constraints.maxWidth
                            : MediaQuery.sizeOf(context).width) -
                        80)
                    .clamp(0, double.infinity),
          ),
          child: Text(
            context.l10n.reminderValue(
              '${task.deadline == null ? '' : '${task.reminderAnchor == 'deadline' ? context.l10n.deadline : context.l10n.plannedFor} · '}$label${preferences.enabled ? '' : ' · ${context.l10n.deviceOff}'}',
            ),
            softWrap: true,
            maxLines: 10,
          ),
        ),
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
                              hasDate: edited.reminderDate != null,
                              hasTime: edited.reminderHasTime,
                              minutes: edited.reminderMinutes,
                              time: edited.reminderTime,
                              onMinutes: (value) => update(
                                () => edited = edited.copyWith(
                                  reminderMinutes: value,
                                ),
                              ),
                              onTime: (value) => update(
                                () => edited = edited.copyWith(
                                  reminderTime: value,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            FilledButton(
                              onPressed: () => Navigator.pop(context, edited),
                              child: Text(context.l10n.useReminder),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
                if (result != null) onChanged?.call(result);
              },
      ),
    );
  }
}

class ReminderControl extends ConsumerWidget {
  final bool hasDate;
  final bool hasTime;
  final int? minutes;
  final int? time;
  final ValueChanged<int?> onMinutes;
  final ValueChanged<int?> onTime;
  const ReminderControl({
    super.key,
    required this.hasDate,
    required this.hasTime,
    this.minutes,
    this.time,
    required this.onMinutes,
    required this.onTime,
  });
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preferences = ref.watch(reminderPreferencesProvider);
    final settings = preferences.valueOrNull ?? const ReminderPreferences();
    final permission =
        ref.watch(reminderCapabilityProvider).valueOrNull ?? true;
    final minute = time ?? settings.dateOnlyTime;
    final label = !hasDate
        ? context.l10n.dateForReminder
        : hasTime
        ? '${context.reminderLead(minutes ?? settings.leadMinutes)}${minutes == null ? ' · ${context.l10n.defaultChoice}' : ''}'
        : minutes == -1 || minute == null
        ? context.l10n.off
        : TimeOfDay(hour: minute ~/ 60, minute: minute % 60).format(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.notifications_outlined),
          title: Text(context.l10n.reminder),
          subtitle: Text(label),
          trailing: hasDate
              ? PopupMenuButton<int>(
                  tooltip: context.l10n.chooseReminder,
                  onSelected: (value) {
                    onMinutes(value == -2 ? null : value);
                    ref.invalidate(reminderCapabilityProvider);
                  },
                  itemBuilder: (_) => [
                    for (final value
                        in hasTime
                            ? <int>{
                                -2,
                                -1,
                                0,
                                10,
                                30,
                                60,
                                1440,
                                if (minutes != null) minutes!,
                              }
                            : <int>{-2, -1})
                      PopupMenuItem(
                        value: value,
                        child: Text(
                          context.reminderLead(value == -2 ? null : value),
                        ),
                      ),
                  ],
                )
              : null,
        ),
        if (hasDate && !hasTime)
          Wrap(
            spacing: 8,
            children: [
              TextButton(
                onPressed: () async {
                  final value = await showTimePicker(
                    context: context,
                    initialTime: TimeOfDay(
                      hour: (minute ?? 540) ~/ 60,
                      minute: (minute ?? 540) % 60,
                    ),
                  );
                  if (value != null) {
                    onMinutes(null);
                    onTime(value.hour * 60 + value.minute);
                  }
                },
                child: Text(context.l10n.chooseAlertTime),
              ),
              if (time != null)
                TextButton(
                  onPressed: () => onTime(null),
                  child: Text(context.l10n.defaultTime),
                ),
            ],
          ),
        if (preferences.hasError) Text(context.l10n.reminderDefaultsError),
        if (preferences.isLoading) Text(context.l10n.loadingReminders),
        if (!preferences.isLoading &&
            hasDate &&
            (hasTime || minute != null) &&
            minutes != -1 &&
            (!settings.enabled || !permission))
          TextButton.icon(
            onPressed: () => Navigator.pushNamed(context, '/notifications'),
            icon: const Icon(Icons.notifications_off_outlined, size: 18),
            label: Text(context.l10n.remindersDisabled),
          ),
      ],
    );
  }
}
