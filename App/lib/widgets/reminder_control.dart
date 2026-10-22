import 'package:agenda/l10n/region.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:agenda/l10n/reminder_plan_words.dart';
import 'package:agenda/models/reminder_plan.dart';
import 'package:agenda/providers/auth_provider.dart';
import 'package:agenda/providers/calendar_focus_provider.dart';
import 'package:agenda/providers/reminder_provider.dart';
import 'package:agenda/providers/task_lists_provider.dart';
import 'package:agenda/providers/task_provider.dart';
import 'package:agenda/services/notification_service.dart';
import 'package:agenda/services/reminder_engine.dart';
import 'package:agenda/services/reminder_plans.dart';
import 'package:agenda/services/reminder_preferences.dart';
import 'package:agenda/services/task_database.dart';
import 'package:agenda/models/task.dart';
import 'package:agenda/models/task_list_info.dart';
import 'package:agenda/widgets/app_components.dart';
import 'package:agenda/widgets/project_preferences.dart';
import 'package:agenda/widgets/reminder_plan_sheet.dart';

final reminderCapabilityProvider = FutureProvider.autoDispose<bool>((
  ref,
) async {
  ref.watch(reminderPreferencesProvider);
  return (await ref.watch(reminderAccessProvider).capability()).allowed;
});

/// True when the task asks for a reminder that this phone won't deliver:
/// reminders are switched off here, or the phone doesn't allow notifications.
/// A [planned] task asks for its plan's, whatever its single reminder says.
bool _cannotFire(
  WidgetRef ref, {
  required bool hasDate,
  required bool hasTime,
  required int? minutes,
  required int? time,
  bool planned = false,
}) {
  final preferences = ref.watch(reminderPreferencesProvider);
  final permission = ref.watch(reminderCapabilityProvider).valueOrNull ?? true;
  final settings = preferences.valueOrNull;
  if (settings == null || !hasDate) return false;
  if (!planned) {
    if (minutes == -1) return false;
    if (!hasTime && (time ?? settings.dateOnlyTime) == null) return false;
  }
  return !settings.enabled || !permission;
}

/// True when reminders are on here and [task] has a reminder, but its alert
/// time is already past: a task without a time for today after its 9:00, a
/// timed task inside its lead time, or a day gone by. Nothing will ring. A
/// plan's are past once its last notice, the day after, has gone by.
bool _alertPassed(WidgetRef ref, Task? task) {
  final settings = ref.watch(reminderPreferencesProvider).valueOrNull;
  if (task == null ||
      settings == null ||
      !settings.enabled ||
      task.isCompleted) {
    return false;
  }
  if (ReminderPlans.active(task) == null) {
    if (task.reminderDate == null || task.reminderMinutes == -1) return false;
    if (task.reminderHasTime
        ? (task.reminderMinutes ?? settings.leadMinutes) < 0
        : (task.reminderTime ?? settings.dateOnlyTime) == null) {
      return false;
    }
  }
  return !ReminderEngine.alertAhead(
    task,
    settings,
    ref.watch(calendarClockProvider)(),
  );
}

/// A plan as its task shows it: «Cada 3 días, y a diario la última semana ·
/// próximo: sáb 25», or a strength's «Cada vez más a menudo hasta el jue 12».
String reminderPlanText(BuildContext context, WidgetRef ref, Task task) {
  final plan = ReminderPlans.active(task)!;
  final settings = ref.watch(reminderPreferencesProvider).valueOrNull;
  return planLine(
    context.l10n,
    plan,
    anchor: ReminderPlans.anchor(task)!,
    now: ref.watch(calendarClockProvider)(),
    minute: ReminderPlans.minute(plan, settings?.dateOnlyTime),
    locale: context.localeName,
  );
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
/// a default time. A task with a deadline or a day ([schedule], as it would
/// be saved) also gets the plans under the list (reminder_plan_sheet.dart):
/// the choices are exclusive, so a plan keeps [minutes] and [time] as they
/// are, unused, and a single reminder clears the [plan].
Future<void> _chooseReminder(
  BuildContext context, {
  required bool hasTime,
  required int? minutes,
  required int? time,
  required int defaultLead,
  required int? defaultTime,
  ReminderPlan? plan,
  Task? schedule,
  required void Function(int? minutes, int? time, ReminderPlan? plan) onChosen,
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
  String label(BuildContext context, int value) => value == pickTime
      ? context.l10n.chooseAlertTime
      : value == useDefault
      ? '${hasTime ? context.reminderLead(defaultLead) : _clock(context, defaultTime!)} · ${context.l10n.defaultChoice}'
      : context.reminderLead(value);
  String? subtitle(BuildContext context, int value) =>
      value == pickTime && time != null ? _clock(context, time) : null;
  final int? value;
  if (schedule != null && ReminderPlans.plannable(schedule)) {
    final active = plan;
    final choice = await showReminderPlanSheet(
      context,
      title: context.l10n.reminder,
      rows: [
        for (final row in values)
          (
            value: row,
            label: label(context, row),
            subtitle: subtitle(context, row),
          ),
      ],
      current: active == null ? current : null,
      task: schedule,
      plan: active,
    );
    if (choice == null || !context.mounted) return;
    if (choice.plan case final chosen?) {
      onChosen(minutes, time, chosen);
      return;
    }
    value = choice.value;
  } else {
    value = await _pickFrom(
      context,
      title: context.l10n.reminder,
      values: values,
      current: current,
      label: label,
      subtitle: subtitle,
    );
  }
  if (value == null || !context.mounted) return;
  if (value == pickTime) {
    final initial = time ?? defaultTime ?? 540;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: initial ~/ 60, minute: initial % 60),
      initialEntryMode: TimePickerEntryMode.input,
    );
    if (picked != null) {
      onChosen(null, picked.hour * 60 + picked.minute, null);
    }
  } else if (value == useDefault) {
    // For a date-only task the default also means the default time.
    onChosen(null, hasTime ? time : null, null);
  } else {
    onChosen(value, time, null);
  }
}

/// Opens [task]'s reminder choices, as its reminder line does, and gives
/// back the task with the one chosen. For a line that isn't the chip, such
/// as the plan read from a dictation on the capture's card.
Future<void> editTaskReminder(
  BuildContext context,
  Task task, {
  required ValueChanged<Task> onChanged,
}) async {
  final container = ProviderScope.containerOf(context, listen: false);
  ReminderPreferences settings;
  try {
    settings = await container.read(reminderPreferencesProvider.future);
  } catch (_) {
    settings = const ReminderPreferences();
  }
  if (!context.mounted) return;
  await _chooseReminder(
    context,
    hasTime: task.reminderHasTime,
    minutes: task.reminderMinutes,
    time: task.reminderTime,
    defaultLead: settings.leadMinutes,
    defaultTime: settings.dateOnlyTime,
    plan: task.reminderPlan,
    schedule: task,
    onChosen: (minutes, time, plan) => onChanged(
      task.copyWith(
        reminderMinutes: minutes,
        reminderTime: time,
        reminderPlan: plan,
      ),
    ),
  );
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
    // A plan replaces the single reminder: the chip is its one line.
    final plan = ReminderPlans.active(task);
    final reason = _reasonFor(ref, task);
    final blocked =
        reason == null &&
        _cannotFire(
          ref,
          hasDate: task.reminderDate != null || plan != null,
          hasTime: task.reminderHasTime,
          minutes: task.reminderMinutes,
          time: task.reminderTime,
          planned: plan != null,
        );
    // Last: a tap still opens the choices, where a later time can be set.
    final passed = reason == null && !blocked && _alertPassed(ref, task);
    final minute = task.reminderTime ?? preferences.dateOnlyTime;
    final label = task.reminderMinutes == -1
        ? context.l10n.off
        : task.reminderHasTime
        ? context.reminderLead(task.reminderMinutes ?? preferences.leadMinutes)
        : minute == null
        ? context.l10n.off
        : _clock(context, minute);
    final value = plan != null
        ? reminderPlanText(context, ref, task)
        : '${task.deadline == null ? '' : '${task.reminderAnchor == 'deadline' ? context.l10n.deadline : context.l10n.plannedFor} · '}$label';
    return LayoutBuilder(
      builder: (context, constraints) => ActionChip(
        key: plan == null ? null : const ValueKey('reminder-plan-line'),
        // The icon keeps its own room at any text size, so a long reading
        // wraps in the label's width instead of the label's height.
        avatarBoxConstraints: const BoxConstraints.tightFor(
          width: 20,
          height: 20,
        ),
        avatar: Icon(
          blocked || passed || reason?.silent == true
              ? Icons.notifications_off_outlined
              : plan != null
              ? Icons.notifications_active_outlined
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
                    plan == null &&
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
                : passed
                ? context.l10n.noReminderTimePassed
                : plan != null
                ? value
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
                plan: task.reminderPlan,
                schedule: task,
                onChosen: (minutes, time, plan) => onChanged?.call(
                  task.copyWith(
                    reminderMinutes: minutes,
                    reminderTime: time,
                    reminderPlan: plan,
                  ),
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

  /// The task's dates and repeat as they'd be saved, which decide whether its
  /// alert time has already passed.
  final Task? schedule;

  /// The task's plan, which replaces its single reminder while it's set.
  final ReminderPlan? plan;
  final ValueChanged<int?> onMinutes;
  final ValueChanged<int?> onTime;

  /// The choice as one change: the single reminder's minutes and time, and
  /// the plan. With it, the choices also offer plans to a task with a
  /// deadline or a day ([schedule]); [onMinutes] and [onTime] go unused.
  final void Function(int? minutes, int? time, ReminderPlan? plan)? onChanged;
  const ReminderControl({
    super.key,
    required this.hasDate,
    required this.hasTime,
    this.minutes,
    this.time,
    this.task,
    this.schedule,
    this.plan,
    required this.onMinutes,
    required this.onTime,
    this.onChanged,
  });
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preferences = ref.watch(reminderPreferencesProvider);
    final settings = preferences.valueOrNull ?? const ReminderPreferences();
    // The task as it would be saved, with this plan, when it applies.
    final planned = schedule == null || plan == null || onChanged == null
        ? null
        : schedule!.copyWith(
            reminderMinutes: minutes,
            reminderTime: time,
            reminderPlan: plan,
          );
    final active = planned == null ? null : ReminderPlans.active(planned);
    final dated = hasDate || active != null;
    final reason = dated ? _reasonFor(ref, task) : null;
    final blocked =
        reason == null &&
        _cannotFire(
          ref,
          hasDate: dated,
          hasTime: hasTime,
          minutes: minutes,
          time: time,
          planned: active != null,
        );
    final passed =
        dated &&
        reason == null &&
        !blocked &&
        _alertPassed(
          ref,
          planned ??
              schedule?.copyWith(reminderMinutes: minutes, reminderTime: time),
        );
    final minute = time ?? settings.dateOnlyTime;
    final value = active != null
        ? reminderPlanText(context, ref, planned!)
        : hasTime
        ? '${context.reminderLead(minutes ?? settings.leadMinutes)}${minutes == null ? ' · ${context.l10n.defaultChoice}' : ''}'
        : minutes == -1 || minute == null
        ? context.l10n.off
        : _clock(context, minute);
    final onTap = !dated
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
            plan: plan,
            // Plans only where they can be kept.
            schedule: onChanged == null ? null : schedule,
            onChosen: (value, chosenTime, chosenPlan) {
              if (onChanged case final changed?) {
                changed(value, chosenTime, chosenPlan);
                return;
              }
              if (value != minutes) onMinutes(value);
              if (chosenTime != time) onTime(chosenTime);
            },
          );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(
            active != null
                ? Icons.notifications_active_outlined
                : Icons.notifications_outlined,
          ),
          title: Text(context.l10n.reminder),
          subtitle: Text(
            !dated
                ? context.l10n.dateForReminder
                : reason?.text(
                        context,
                        active == null &&
                                _followsDefault(
                                  hasTime: hasTime,
                                  minutes: minutes,
                                  time: time,
                                )
                            ? null
                            : value,
                      ) ??
                      (passed ? context.l10n.noReminderTimePassed : value),
          ),
          trailing: onTap == null
              ? null
              : const Icon(Icons.chevron_right_rounded),
          onTap: onTap,
        ),
        if (preferences.hasError) Text(context.l10n.reminderDefaultsError),
        if (preferences.isLoading) Text(context.l10n.loadingReminders),
        if (blocked)
          TextButton.icon(
            onPressed: () => turnOnReminders(context),
            icon: const Icon(Icons.notifications_off_outlined, size: 18),
            label: Text(context.l10n.enableReminders),
          ),
      ],
    );
  }
}
