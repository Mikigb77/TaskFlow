import 'package:agenda/l10n/region.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:agenda/providers/auth_provider.dart';
import 'package:agenda/providers/reminder_provider.dart';
import 'package:agenda/providers/task_lists_provider.dart';
import 'package:agenda/providers/task_provider.dart';
import 'package:agenda/services/notification_service.dart';
import 'package:agenda/services/reminder_preferences.dart';
import 'package:agenda/services/task_database.dart';
import 'package:agenda/models/task.dart';
import 'package:agenda/models/task_list_info.dart';
import 'package:agenda/widgets/app_components.dart';
import 'package:agenda/widgets/project_preferences.dart';

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

/// Why the reminder line can't simply read «Recordatorio: …» on this phone:
/// the task rings only on someone else's phone, or its project gives none.
/// The chip and the form both read it, so each reason is said in one place.
class _Reason {
  const _Reason(this.block, {this.project, this.person});
  final ReminderBlock block;
  final TaskListInfo? project;

  /// Whose phone rings, for [ReminderBlock.notForAccount].
  final String? person;

  /// False when the reminder still rings, on [person]'s phone.
  bool get silent => block != ReminderBlock.notForAccount;

  /// What the line says, around the reminder's own [value]. [value] is null
  /// when the task follows the default: [person]'s phone uses their own,
  /// which this phone doesn't know, so only the person is named.
  String text(BuildContext context, String? value) => switch (block) {
    ReminderBlock.archived => context.l10n.noReminderProjectArchived,
    ReminderBlock.muted => context.l10n.noReminderProjectMuted,
    ReminderBlock.notForAccount =>
      value == null
          ? context.l10n.reminderForPersonOnly(person!)
          : context.l10n.reminderForPerson(person!, value),
  };

  /// What a tap does on a [silent] line: a muted project opens its
  /// «Novedades del proyecto», where muting is undone; an archived one
  /// offers nothing.
  VoidCallback? action(BuildContext context, WidgetRef ref) => switch (block) {
    ReminderBlock.muted => () => showProjectPreferences(context, ref, project!),
    _ => null,
  };
}

/// The reason, by the rule the reminder engine schedules with
/// ([TaskDatabase.reminderBlock]), or null when [task] reads as usual. Only
/// a task given to someone named says whose it is; other tasks that aren't
/// this account's read as before.
_Reason? _reasonFor(WidgetRef ref, Task? task) {
  if (task == null) return null;
  final project = task.listId == null
      ? null
      : (ref.watch(taskListsProvider).valueOrNull ?? const <TaskListInfo>[])
            .where((p) => p.id == task.listId)
            .firstOrNull;
  final accountId =
      task.assignment == 'member' || task.assignment == 'unassigned'
      ? ref.watch(authProvider).account?.id
      : null;
  final block = TaskDatabase.reminderBlock(
    task,
    accountId,
    archived: project?.inactive == true,
    muted: project?.notifications == 'muted',
    role: project?.role,
  );
  if (block == null) return null;
  if (block == ReminderBlock.notForAccount &&
      (task.assignment != 'member' || task.assigneeName == null)) {
    return null;
  }
  return _Reason(block, project: project, person: task.assigneeName);
}

/// True when the reminder is the default one: a timed task with no lead of
/// its own, or a date-only task with no time of its own that isn't off.
bool _followsDefault({
  required bool hasTime,
  required int? minutes,
  required int? time,
}) => hasTime ? minutes == null : time == null && minutes != -1;

String _clock(BuildContext context, int minute) =>
    TimeOfDay(hour: minute ~/ 60, minute: minute % 60).format(context);

/// The one way to turn reminders on: the phone's permission, the switch,
/// exact alarms when Android needs them, then a confirmation. True when
/// reminders ended up on; false when the phone refused or it failed.
/// [onScheduling] gets the background setting of the alerts, which completes
/// once they're set or a failure is recorded, for a screen that lists them.
Future<bool> turnOnReminders(
  BuildContext context, {
  void Function(Future<void> scheduling)? onScheduling,
}) async {
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
        actionLabel: strings.allowNotifications,
        onAction: access.openNotificationSettings,
      );
      return false;
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
                const SizedBox(height: 8),
                Text(context.l10n.exactAlarmsNextScreen),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: Text(context.l10n.allowPreciseAlarms),
                ),
                const SizedBox(height: 8),
                // Leaves as Back does.
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(context.l10n.reminderAskNotNow),
                ),
              ],
            ),
          ),
        ),
      );
      if (allow == true) await access.requestExactAccess();
      exact = (await access.capability()).exact;
    }
    // Setting the alerts can take seconds; the answer needn't wait for it.
    final scheduling = access
        .reconcile(owner)
        .catchError((Object _) => TaskReminders.recordError('refresh_failed'));
    unawaited(scheduling);
    onScheduling?.call(scheduling);
  } catch (_) {
    showFeedback(messenger, strings.notificationSaveError);
    return false;
  } finally {
    container.invalidate(reminderCapabilityProvider);
  }
  // Without exact alarms a reminder may arrive late: say so instead of "done".
  showFeedback(
    messenger,
    exact ? strings.remindersOnConfirmation : strings.exactAlarmsNeeded,
  );
  return true;
}

/// The reminder choices in one list. Picking one applies it and closes.
/// The default comes first, named by its value: [defaultLead] for a timed
/// task, [defaultTime] for a date-only one, which has no default row without
/// a default time.
Future<void> _chooseReminder(
  BuildContext context, {
  required bool hasTime,
  required int? minutes,
  required int? time,
  required int defaultLead,
  required int? defaultTime,
  required void Function(int? minutes, int? time) onChosen,
}) async {
  const useDefault = -2;
  const pickTime = -3;
  final values = hasTime
      ? (<int>{
          useDefault,
          -1,
          0,
          10,
          30,
          60,
          1440,
          if (minutes != null) minutes,
        }..remove(defaultLead))
      : <int>{if (defaultTime != null) useDefault, -1, pickTime};
  final current = hasTime
      ? minutes == null || minutes == defaultLead
            ? useDefault
            : minutes
      : minutes == -1
      ? -1
      : time != null
      ? pickTime
      : defaultTime != null
      ? useDefault
      : -1;
  final value = await _pickFrom(
    context,
    title: context.l10n.reminder,
    values: values,
    current: current,
    label: (context, value) => value == pickTime
        ? context.l10n.chooseAlertTime
        : value == useDefault
        ? '${hasTime ? context.reminderLead(defaultLead) : _clock(context, defaultTime!)} · ${context.l10n.defaultChoice}'
        : context.reminderLead(value),
    subtitle: (context, value) =>
        value == pickTime && time != null ? _clock(context, time) : null,
  );
  if (value == null || !context.mounted) return;
  if (value == pickTime) {
    final initial = time ?? defaultTime ?? 540;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: initial ~/ 60, minute: initial % 60),
      initialEntryMode: TimePickerEntryMode.input,
    );
    if (picked != null) onChosen(null, picked.hour * 60 + picked.minute);
  } else if (value == useDefault) {
    // For a date-only task the default also means the default time.
    onChosen(null, hasTime ? time : null);
  } else {
    onChosen(value, time);
  }
}

/// The default lead for tasks with a time, from the chip's list of leads.
/// This list sets the default, so it has no «default» row. Null when the
/// person leaves without picking.
Future<int?> chooseDefaultLead(
  BuildContext context, {
  required String title,
  required int current,
}) => _pickFrom(
  context,
  title: title,
  values: <int>{-1, 0, 10, 30, 60, 1440, current},
  current: current,
  label: (context, value) => context.reminderLead(value),
);

/// One-tap list: picking a row closes it with that row's value.
Future<int?> _pickFrom(
  BuildContext context, {
  required String title,
  required Iterable<int> values,
  required int current,
  required String Function(BuildContext context, int value) label,
  String? Function(BuildContext context, int value)? subtitle,
}) => showModalBottomSheet<int>(
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
            child: Text(title, style: Theme.of(context).textTheme.titleMedium),
          ),
          for (final value in values)
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 24),
              title: Text(label(context, value)),
              subtitle: switch (subtitle?.call(context, value)) {
                final String text => Text(text),
                null => null,
              },
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

class ReminderChip extends ConsumerWidget {
  final Task task;
  final ValueChanged<Task>? onChanged;
  const ReminderChip({super.key, required this.task, this.onChanged});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preferences =
        ref.watch(reminderPreferencesProvider).valueOrNull ??
        const ReminderPreferences();
    final reason = _reasonFor(ref, task);
    final blocked =
        reason == null &&
        _cannotFire(
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
        : _clock(context, minute);
    final value =
        '${task.deadline == null ? '' : '${task.reminderAnchor == 'deadline' ? context.l10n.deadline : context.l10n.plannedFor} · '}$label';
    return LayoutBuilder(
      builder: (context, constraints) => ActionChip(
        avatar: Icon(
          blocked || reason?.silent == true
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
            reason != null
                ? reason.text(
                    context,
                    _followsDefault(
                          hasTime: task.reminderHasTime,
                          minutes: task.reminderMinutes,
                          time: task.reminderTime,
                        )
                        ? null
                        : value,
                  )
                : blocked
                ? context.l10n.noReminderTurnOn
                : context.l10n.reminderValue(value),
            softWrap: true,
            maxLines: 10,
          ),
        ),
        onPressed: reason?.silent == true
            ? reason!.action(context, ref)
            : blocked
            ? () => turnOnReminders(context)
            : onChanged == null
            ? null
            : () => _chooseReminder(
                context,
                hasTime: task.reminderHasTime,
                minutes: task.reminderMinutes,
                time: task.reminderTime,
                defaultLead: preferences.leadMinutes,
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

  /// The task's project and person, which decide whether this phone rings.
  final Task? task;
  final ValueChanged<int?> onMinutes;
  final ValueChanged<int?> onTime;
  const ReminderControl({
    super.key,
    required this.hasDate,
    required this.hasTime,
    this.minutes,
    this.time,
    this.task,
    required this.onMinutes,
    required this.onTime,
  });
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preferences = ref.watch(reminderPreferencesProvider);
    final settings = preferences.valueOrNull ?? const ReminderPreferences();
    final reason = hasDate ? _reasonFor(ref, task) : null;
    final minute = time ?? settings.dateOnlyTime;
    final value = hasTime
        ? '${context.reminderLead(minutes ?? settings.leadMinutes)}${minutes == null ? ' · ${context.l10n.defaultChoice}' : ''}'
        : minutes == -1 || minute == null
        ? context.l10n.off
        : _clock(context, minute);
    final onTap = !hasDate
        ? null
        : reason?.silent == true
        ? reason!.action(context, ref)
        : () => _chooseReminder(
            context,
            hasTime: hasTime,
            minutes: minutes,
            time: time,
            defaultLead: settings.leadMinutes,
            defaultTime: settings.dateOnlyTime,
            onChosen: (value, chosenTime) {
              if (value != minutes) onMinutes(value);
              if (chosenTime != time) onTime(chosenTime);
            },
          );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.notifications_outlined),
          title: Text(context.l10n.reminder),
          subtitle: Text(
            !hasDate
                ? context.l10n.dateForReminder
                : reason?.text(
                        context,
                        _followsDefault(
                              hasTime: hasTime,
                              minutes: minutes,
                              time: time,
                            )
                            ? null
                            : value,
                      ) ??
                      value,
          ),
          trailing: onTap == null
              ? null
              : const Icon(Icons.chevron_right_rounded),
          onTap: onTap,
        ),
        if (preferences.hasError) Text(context.l10n.reminderDefaultsError),
        if (preferences.isLoading) Text(context.l10n.loadingReminders),
        if (reason == null &&
            _cannotFire(
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
