import 'package:agenda/l10n/region.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:agenda/providers/reminder_provider.dart';
import 'package:agenda/providers/task_provider.dart';
import 'package:agenda/services/reminder_preferences.dart';
import 'package:agenda/models/task.dart';
import 'package:agenda/widgets/app_components.dart';

final reminderCapabilityProvider = FutureProvider.autoDispose<bool>((
  ref,
) async {
  ref.watch(reminderPreferencesProvider);
  return (await ref.watch(reminderAccessProvider).capability()).allowed;
});

/// True when the task asks for a reminder that this phone won't deliver:
/// reminders are switched off here, or the phone doesn't allow notifications.
bool _cannotFire(
  WidgetRef ref, {
  required bool hasDate,
  required bool hasTime,
  required int? minutes,
  required int? time,
}) {
  final preferences = ref.watch(reminderPreferencesProvider);
  final permission = ref.watch(reminderCapabilityProvider).valueOrNull ?? true;
  final settings = preferences.valueOrNull;
  if (settings == null || !hasDate || minutes == -1) return false;
  if (!hasTime && (time ?? settings.dateOnlyTime) == null) return false;
  return !settings.enabled || !permission;
}

/// The one way to turn reminders on: the phone's permission, the switch,
/// exact alarms when Android needs them, then a confirmation.
Future<void> turnOnReminders(BuildContext context) async {
  final container = ProviderScope.containerOf(context, listen: false);
  final messenger = ScaffoldMessenger.of(context);
  final strings = context.l10n;
  final access = container.read(reminderAccessProvider);
  var exact = false;
  try {
    if (!await access.requestPermission()) {
      showFeedback(
        messenger,
        strings.notificationPermissionOff,
        actionLabel: strings.openSystemSettings,
        onAction: openAppSettings,
      );
      return;
    }
    final owner = container.read(taskRepositoryProvider).ownerKey;
    final store = container.read(reminderPreferenceStoreProvider);
    final settings = await store.read(owner);
    if (!settings.enabled) {
      // Tasks without a time remind at 9:00 unless a time was already chosen.
      // Someone who turned reminders on needn't be asked about them again.
      await store.write(
        owner,
        ReminderPreferences(
          enabled: true,
          leadMinutes: settings.leadMinutes,
          dateOnlyTime: settings.dateOnlyTime ?? 540,
          morning: settings.morning,
          evening: settings.evening,
          asked: true,
        ),
      );
    }
    container.invalidate(reminderPreferencesProvider);
    exact = (await access.capability()).exact;
    if (!exact && context.mounted) {
      final allow = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        builder: (context) => SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(context.l10n.exactAlarmsNeeded),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: Text(context.l10n.allowPreciseAlarms),
                ),
              ],
            ),
          ),
        ),
      );
      if (allow == true) await access.requestExactAccess();
      exact = (await access.capability()).exact;
    }
    await access.reconcile(owner);
  } catch (_) {
    showFeedback(messenger, strings.notificationSaveError);
    return;
  } finally {
    container.invalidate(reminderCapabilityProvider);
  }
  // Without exact alarms a reminder may arrive late: say so instead of "done".
  showFeedback(
    messenger,
    exact ? strings.remindersOnConfirmation : strings.exactAlarmsNeeded,
  );
}

/// The reminder choices in one list. Picking one applies it and closes.
Future<void> _chooseReminder(
  BuildContext context, {
  required bool hasTime,
  required int? minutes,
  required int? time,
  required int? defaultTime,
  required void Function(int? minutes, int? time) onChosen,
}) async {
  const pickTime = -3;
  final values = hasTime
      ? <int>{-2, -1, 0, 10, 30, 60, 1440, if (minutes != null) minutes}
      : <int>{-2, -1, pickTime};
  final current = minutes == -1
      ? -1
      : hasTime
      ? minutes ?? -2
      : time == null
      ? -2
      : pickTime;
  final value = await showModalBottomSheet<int>(
    context: context,
    isScrollControlled: true,
    builder: (context) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: Text(
                context.l10n.reminder,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            for (final value in values)
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 24),
                title: Text(
                  value == pickTime
                      ? context.l10n.chooseAlertTime
                      : context.reminderLead(value == -2 ? null : value),
                ),
                subtitle: value == pickTime && time != null
                    ? Text(
                        TimeOfDay(
                          hour: time ~/ 60,
                          minute: time % 60,
                        ).format(context),
                      )
                    : null,
                selected: value == current,
                trailing: value == current
                    ? const Icon(Icons.check_rounded)
                    : null,
                onTap: () => Navigator.pop(context, value),
              ),
          ],
        ),
      ),
    ),
  );
  if (value == null || !context.mounted) return;
  if (value == pickTime) {
    final initial = time ?? defaultTime ?? 540;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: initial ~/ 60, minute: initial % 60),
    );
    if (picked != null) onChosen(null, picked.hour * 60 + picked.minute);
  } else if (value == -2) {
    // For a date-only task the default also means the default time.
    onChosen(null, hasTime ? time : null);
  } else {
    onChosen(value, time);
  }
}

class ReminderChip extends ConsumerWidget {
  final Task task;
  final ValueChanged<Task>? onChanged;
  const ReminderChip({super.key, required this.task, this.onChanged});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preferences =
        ref.watch(reminderPreferencesProvider).valueOrNull ??
        const ReminderPreferences();
    final blocked = _cannotFire(
      ref,
      hasDate: task.reminderDate != null,
      hasTime: task.reminderHasTime,
      minutes: task.reminderMinutes,
      time: task.reminderTime,
    );
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
        avatar: Icon(
          blocked
              ? Icons.notifications_off_outlined
              : Icons.notifications_outlined,
          size: 16,
        ),
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
            blocked
                ? context.l10n.noReminderTurnOn
                : context.l10n.reminderValue(
                    '${task.deadline == null ? '' : '${task.reminderAnchor == 'deadline' ? context.l10n.deadline : context.l10n.plannedFor} · '}$label',
                  ),
            softWrap: true,
            maxLines: 10,
          ),
        ),
        onPressed: blocked
            ? () => turnOnReminders(context)
            : onChanged == null
            ? null
            : () => _chooseReminder(
                context,
                hasTime: task.reminderHasTime,
                minutes: task.reminderMinutes,
                time: task.reminderTime,
                defaultTime: preferences.dateOnlyTime,
                onChosen: (minutes, time) => onChanged?.call(
                  task.copyWith(reminderMinutes: minutes, reminderTime: time),
                ),
              ),
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
          onTap: !hasDate
              ? null
              : () => _chooseReminder(
                  context,
                  hasTime: hasTime,
                  minutes: minutes,
                  time: time,
                  defaultTime: settings.dateOnlyTime,
                  onChosen: (value, chosenTime) {
                    if (value != minutes) onMinutes(value);
                    if (chosenTime != time) onTime(chosenTime);
                  },
                ),
        ),
        if (preferences.hasError) Text(context.l10n.reminderDefaultsError),
        if (preferences.isLoading) Text(context.l10n.loadingReminders),
        if (_cannotFire(
          ref,
          hasDate: hasDate,
          hasTime: hasTime,
          minutes: minutes,
          time: time,
        ))
          TextButton.icon(
            onPressed: () => turnOnReminders(context),
            icon: const Icon(Icons.notifications_off_outlined, size: 18),
            label: Text(context.l10n.enableReminders),
          ),
      ],
    );
  }
}
