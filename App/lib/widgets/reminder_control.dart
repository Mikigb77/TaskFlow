import 'package:agenda/l10n/region.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:agenda/l10n/generated/app_localizations.dart';
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
  final permission = ref.watch(reminderCapabilityProvider).value ?? true;
  final settings = preferences.value;
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
/// plan's are past once none is left on or before the task's day: the last
/// notice, the day after, isn't a reminder of it.
bool _alertPassed(WidgetRef ref, Task? task) {
  final settings = ref.watch(reminderPreferencesProvider).value;
  if (task == null ||
      settings == null ||
      !settings.enabled ||
      task.isCompleted) {
    return false;
  }
  final now = ref.watch(calendarClockProvider)();
  if (ReminderPlans.active(task) != null) {
    return ReminderPlans.taskAlerts(
      task,
      settings.dateOnlyTime,
      now,
      defaultLead: settings.leadMinutes,
      late: false,
    ).isEmpty;
  }
  if (task.reminderDate == null || task.reminderMinutes == -1) return false;
  if (task.reminderHasTime
      ? (task.reminderMinutes ?? settings.leadMinutes) < 0
      : (task.reminderTime ?? settings.dateOnlyTime) == null) {
    return false;
  }
  return !ReminderEngine.alertAhead(task, settings, now);
}

/// The alerts this phone keeps for a task ([ReminderAccess.alertsOf]), read
/// again each time reminders are planned again or a notice's action is taken.
final _alertsProvider = FutureProvider.autoDispose
    .family<List<Map<String, Object?>>, int>((ref, taskId) {
      final changes = TaskReminders.changes.stream.listen(
        (_) => ref.invalidateSelf(),
      );
      ref.onDispose(changes.cancel);
      return ref.watch(reminderAccessProvider).alertsOf(taskId);
    });

/// When [task]'s reminder rang here, or rings again after a snooze
/// ([ReminderEngine.lastAlert]): null when it never did, as when it was
/// saved too late to ring (D1), and while the alerts are read.
({DateTime when, bool snoozed})? _lastAlert(WidgetRef ref, Task? task) {
  final id = task?.id;
  final settings = ref.watch(reminderPreferencesProvider).value;
  if (id == null || settings == null) return null;
  final alerts = ref.watch(_alertsProvider(id)).value;
  if (alerts == null || alerts.isEmpty) return null;
  return ReminderEngine.lastAlert(
    task!,
    alerts,
    settings,
    ref.watch(calendarClockProvider)(),
  );
}

/// A reminder that has rung, as its line says it: «Recordatorio enviado:
/// hoy, 09:40», or «Recordatorio pospuesto: hoy, 09:52» while a snooze is to
/// come. A [plan]'s line, once its last notice has rung, ends «· último: hoy,
/// 16:50». The day as the plan lines write it.
String _rangText(
  BuildContext context,
  WidgetRef ref,
  ({DateTime when, bool snoozed}) alert, {
  String? plan,
}) {
  final l = context.l10n;
  final now = ref.watch(calendarClockProvider)();
  final when = planWhen(alert.when, now);
  final date = planDay(alert.when, now, context.localeName);
  final time = context.clockTime(alert.when);
  return alert.snoozed
      ? l.reminderSnoozed(when, date, time)
      : plan != null
      ? l.reminderPlanLast(plan, when, date, time)
      : l.reminderSent(when, date, time);
}

/// A plan as its task shows it: «Recordatorios: cada 3 días, y a diario la
/// última semana · próximo: sáb 24, 9:00», or a strength's «Recordatorios
/// normales hasta el jue 12 · …». [bare], after a person's name, leaves the
/// noun out: «cada 3 días, … · próximo: …».
String reminderPlanText(
  BuildContext context,
  WidgetRef ref,
  Task task, {
  bool bare = false,
}) {
  final plan = ReminderPlans.active(task)!;
  final settings = ref.watch(reminderPreferencesProvider).value;
  return planLine(
    context.l10n,
    plan,
    anchor: ReminderPlans.anchor(task)!,
    now: ref.watch(calendarClockProvider)(),
    minute: ReminderPlans.minute(plan, settings?.dateOnlyTime),
    locale: context.localeName,
    clock: context.clockTime,
    done: task.isCompleted,
    bare: bare,
    dayLead: ReminderPlans.dayLead(
      task,
      (settings ?? const ReminderPreferences()).leadMinutes,
    ),
  );
}

/// Why the reminder line can't simply read «Recordatorio: …» on this phone:
/// the task's reminders are someone else's, or its project gives none.
/// The chip and the form both read it, so each reason is said in one place.
class _Reason {
  const _Reason(this.block, {this.project, this.person});
  final ReminderBlock block;
  final TaskListInfo? project;

  /// Whose reminders they are, for [ReminderBlock.notForAccount]: the
  /// member the task is given to. Null when the task names nobody.
  final String? person;

  /// False when the reminder still rings, on [person]'s phone.
  bool get silent => block != ReminderBlock.notForAccount;

  /// True when the task shows no reminder at all: its reminders are someone
  /// else's and it names nobody, so there's nothing true to say about them.
  bool get hidden => block == ReminderBlock.notForAccount && person == null;

  /// What the line says. Someone else's reminders are their own and never
  /// reach this phone, so only the person is named: none of this account's
  /// values on the task is theirs.
  String text(BuildContext context) => switch (block) {
    ReminderBlock.archived => context.l10n.noReminderProjectArchived,
    ReminderBlock.muted => context.l10n.noReminderProjectMuted,
    ReminderBlock.notForAccount => context.l10n.reminderForPersonOnly(person!),
  };

  /// What a tap does: a muted project opens its «Novedades del proyecto»,
  /// where muting is undone; an archived one, or someone else's reminders,
  /// offer nothing.
  VoidCallback? action(BuildContext context, WidgetRef ref) => switch (block) {
    ReminderBlock.muted => () => showProjectPreferences(context, ref, project!),
    _ => null,
  };
}

/// The reason, by the rule the reminder engine schedules with
/// ([TaskDatabase.reminderBlock]), or null when [task] reads as usual. A
/// task given to someone named says whose it is; another task that isn't
/// this account's is [_Reason.hidden].
_Reason? _reasonFor(WidgetRef ref, Task? task) {
  if (task == null) return null;
  final project = _projectOf(ref, task);
  final block = _blockFor(ref, task, project);
  if (block == null) return null;
  final name = task.assigneeName?.trim();
  return _Reason(
    block,
    project: project,
    person:
        block == ReminderBlock.notForAccount &&
            task.assignment == 'member' &&
            name != null &&
            name.isNotEmpty
        ? name
        : null,
  );
}

TaskListInfo? _projectOf(WidgetRef ref, Task task) => task.listId == null
    ? null
    : (ref.watch(taskListsProvider).value ?? const <TaskListInfo>[])
          .where((p) => p.id == task.listId)
          .firstOrNull;

int? _accountFor(WidgetRef ref, Task task) =>
    task.assignment == 'member' || task.assignment == 'unassigned'
    ? ref.watch(authProvider).account?.id
    : null;

ReminderBlock? _blockFor(WidgetRef ref, Task task, TaskListInfo? project) =>
    TaskDatabase.reminderBlock(
      task,
      _accountFor(ref, task),
      archived: project?.inactive == true,
      muted: project?.notifications == 'muted',
      role: project?.role,
    );

/// True when this phone rings for [task], by the rule the reminder engine
/// schedules with ([TaskDatabase.reminderBlock]): only then can a plan, which
/// is this account's own, ring at all. True for a null [task].
bool reminderRingsHere(WidgetRef ref, Task? task) =>
    task == null || _blockFor(ref, task, _projectOf(ref, task)) == null;

/// True when [task]'s reminders are someone else's, whatever its project's
/// state on this phone: it's given to another member, or it's unassigned in
/// a project this account doesn't own or administer. Their reminders are
/// theirs and never reach this phone, and a choice here would be this
/// account's own and never ring, so none is offered.
bool reminderSomeoneElses(WidgetRef ref, Task? task) =>
    task != null &&
    TaskDatabase.reminderBlock(
          task,
          _accountFor(ref, task),
          role: _projectOf(ref, task)?.role,
        ) ==
        ReminderBlock.notForAccount;

/// False when [task] shows no reminder at all on this phone: its reminders
/// are someone else's and it names nobody. True for a null [task].
bool reminderShows(WidgetRef ref, Task? task) =>
    _reasonFor(ref, task)?.hidden != true;

/// True when [task] is shared: its project is, or it's given to the project's
/// people rather than kept personal. Its plan is still only this account's.
bool reminderShared(WidgetRef ref, Task? task) =>
    task != null &&
    (task.assignment != 'personal' || _projectOf(ref, task)?.shared == true);

String _clock(BuildContext context, int minute) =>
    TimeOfDay(hour: minute ~/ 60, minute: minute % 60).format(context);

/// The one way to turn reminders on: the phone's permission, the switch,
/// exact alarms when Android needs them, then a confirmation. True when
/// reminders ended up on; false when the phone refused or it failed.
/// [onScheduling] gets the background setting of the alerts, which completes
/// once they're set or a failure is recorded, for a screen that lists them.
/// After a refusal, the message's «Permitir avisos» finishes the job once the
/// person is back from the phone's settings ([_finishOnReturn]).
Future<bool> turnOnReminders(
  BuildContext context, {
  void Function(Future<void> scheduling)? onScheduling,
}) async {
  final container = ProviderScope.containerOf(context, listen: false);
  final messenger = ScaffoldMessenger.of(context);
  final navigator = Navigator.of(context, rootNavigator: true);
  final strings = context.l10n;
  final access = container.read(reminderAccessProvider);
  try {
    if (!await access.requestPermission()) {
      showFeedback(
        messenger,
        strings.notificationPermissionOff,
        actionLabel: strings.allowNotifications,
        onAction: () => _finishOnReturn(container, navigator),
      );
      container.invalidate(reminderCapabilityProvider);
      return false;
    }
  } catch (_) {
    showFeedback(messenger, strings.notificationSaveError);
    container.invalidate(reminderCapabilityProvider);
    return false;
  }
  return _switchOn(
    container,
    navigator,
    messenger,
    strings,
    onScheduling: onScheduling,
  );
}

/// «Permitir avisos» after the phone refused: opens its notifications page
/// and remembers that this account asked for reminders. Back in the app,
/// whatever screen shows, reminders turn on as [turnOnReminders] does if the
/// phone now allows them; still refused, nothing more is said. Forgotten
/// either way ([reminderRequestsProvider]).
Future<void> _finishOnReturn(
  ProviderContainer container,
  NavigatorState navigator,
) async {
  final access = container.read(reminderAccessProvider);
  final owner = container.read(taskRepositoryProvider).ownerKey;
  final requests = container.read(reminderRequestsProvider);
  if (!requests.containsKey(owner)) {
    final settled = Completer<void>();
    requests[owner] = settled.future;
    late final AppLifecycleListener listener;
    listener = AppLifecycleListener(
      onResume: () async {
        listener.dispose();
        try {
          if (container.read(taskRepositoryProvider).ownerKey == owner &&
              (await access.capability()).allowed &&
              navigator.mounted) {
            final messenger = ScaffoldMessenger.maybeOf(navigator.context);
            if (messenger != null) {
              Future<void>? scheduling;
              if (await _switchOn(
                container,
                navigator,
                messenger,
                navigator.context.l10n,
                onScheduling: (future) => scheduling = future,
              )) {
                // A screen waiting on the request lists the alerts set.
                await scheduling;
              }
            }
          }
        } catch (_) {
          // Not finished: the switch in Ajustes › Recordatorios still is.
        } finally {
          requests.remove(owner);
          settled.complete();
        }
      },
    );
  }
  await access.openNotificationSettings();
}

/// Turns reminders on once the phone allows notifications: the switch, 9:00
/// for tasks without a time, exact alarms when Android needs them, the alerts
/// and the confirmation. False when it failed. The sheet about exact alarms
/// opens on [navigator] while it's still there.
Future<bool> _switchOn(
  ProviderContainer container,
  NavigatorState navigator,
  ScaffoldMessengerState messenger,
  AppLocalizations strings, {
  void Function(Future<void> scheduling)? onScheduling,
}) async {
  final access = container.read(reminderAccessProvider);
  var exact = false;
  try {
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
    if (!exact && navigator.mounted) {
      final allow = await showModalBottomSheet<bool>(
        context: navigator.context,
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
                  child: Text(context.l10n.allowPreciseAlarms,
                      textAlign: TextAlign.center),
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
/// are, unused, and a single reminder clears the [plan]. On a [shared] task
/// the choices say they're only for this person.
Future<void> _chooseReminder(
  BuildContext context, {
  required bool hasTime,
  required int? minutes,
  required int? time,
  required int defaultLead,
  required int? defaultTime,
  ReminderPlan? plan,
  Task? schedule,
  bool shared = false,
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
          ?minutes,
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
      // As it would be saved, with its reminder as chosen so far.
      task: schedule.copyWith(reminderMinutes: minutes, reminderTime: time),
      plan: active,
      shared: shared,
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
      note: shared ? context.l10n.reminderPlanJustYou : null,
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

/// One-tap list: picking a row closes it with that row's value. A [note]
/// sits under the title, above the first row.
Future<int?> _pickFrom(
  BuildContext context, {
  required String title,
  required Iterable<int> values,
  required int current,
  required String Function(BuildContext context, int value) label,
  String? Function(BuildContext context, int value)? subtitle,
  String? note,
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
          if (note != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: Text(
                note,
                key: const ValueKey('reminder-plan-just-you'),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
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

/// [task]'s reminder line as this phone reads it: its icon, its words and
/// what a tap does. The plan's line, «Recordatorio: 1 hora antes» («… ·
/// fecha límite» when it counts from the deadline), «Sin recordatorio ·
/// Activar» when this phone won't ring (the tap turns reminders on),
/// «Recordatorio enviado: hoy, 09:40» once it has rung, or «Sin
/// recordatorio: ya ha pasado la hora del aviso» when it never could;
/// otherwise a tap opens the reminder choices and gives [onChanged] the task
/// with the one chosen. The task's chip and a collapsed row on the capture's
/// card both read it, so they can't drift. For a task with a reminder date
/// or a plan that applies. A task given to someone else reads «Recordatorio
/// para Ana», with no tap; null when its reminders are someone else's and it
/// names nobody, which shows no reminder.
({IconData icon, String text, VoidCallback? onTap})? reminderLine(
  BuildContext context,
  WidgetRef ref,
  Task task, {
  ValueChanged<Task>? onChanged,
}) {
  final reason = _reasonFor(ref, task);
  if (reason?.hidden == true) return null;
  final preferences =
      ref.watch(reminderPreferencesProvider).value ??
      const ReminderPreferences();
  // A plan replaces the single reminder: the line is its one line. It's this
  // account's own, so it counts only where this phone rings.
  final ringsHere = reminderRingsHere(ref, task);
  final plan = ringsHere ? ReminderPlans.active(task) : null;
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
  final checked = ringsHere ? task : task.copyWith(reminderPlan: null);
  final passed = reason == null && !blocked && _alertPassed(ref, checked);
  // Its time came and it rang, or a snooze is to come: not D1's case.
  final rang = passed ? _lastAlert(ref, checked) : null;
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
      : task.deadline != null && task.reminderAnchor == 'deadline'
      ? context.l10n.reminderBeforeDeadline(label)
      : label;
  return (
    icon: blocked || (passed && rang == null) || reason?.silent == true
        ? Icons.notifications_off_outlined
        : plan != null
        ? Icons.notifications_active_outlined
        : Icons.notifications_outlined,
    text: reason != null
        ? reason.text(context)
        : blocked
        ? context.l10n.noReminderTurnOn
        : rang != null
        ? _rangText(context, ref, rang, plan: plan == null ? null : value)
        : passed
        ? context.l10n.noReminderTimePassed
        : plan != null
        ? value
        : context.l10n.reminderValue(value),
    onTap: reason != null
        ? reason.action(context, ref)
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
            plan: plan,
            // Plans only where they can ring.
            schedule: ringsHere ? task : null,
            shared: reminderShared(ref, task),
            onChosen: (minutes, time, plan) => onChanged(
              task.copyWith(
                reminderMinutes: minutes,
                reminderTime: time,
                reminderPlan: plan,
              ),
            ),
          ),
  );
}

class ReminderChip extends ConsumerWidget {
  final Task task;
  final ValueChanged<Task>? onChanged;
  const ReminderChip({super.key, required this.task, this.onChanged});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final line = reminderLine(context, ref, task, onChanged: onChanged);
    if (line == null) return const SizedBox.shrink();
    final key =
        ReminderPlans.active(task) == null || !reminderRingsHere(ref, task)
        ? null
        : const ValueKey('reminder-plan-line');
    // The icon keeps its own room at any text size, so a long reading wraps
    // in the label's width instead of the label's height.
    const avatarBox = BoxConstraints.tightFor(width: 20, height: 20);
    final avatar = Icon(line.icon, size: 16);
    return LayoutBuilder(
      builder: (context, constraints) {
        final label = ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth:
                ((constraints.maxWidth.isFinite
                            ? constraints.maxWidth
                            : MediaQuery.sizeOf(context).width) -
                        80)
                    .clamp(0, double.infinity),
          ),
          // A wrapped reading hugs its longest line, so the bell sits beside
          // it; on the chip with a tap, a control, the lines centre too.
          child: Text(
            line.text,
            softWrap: true,
            maxLines: 10,
            textAlign: line.onTap == null ? null : TextAlign.center,
            textWidthBasis: TextWidthBasis.longestLine,
          ),
        );
        // A line with no tap is information: drawn with no outline and at
        // full contrast, rather than as a control or a switched-off one. The
        // chip's own Material takes the canvas colour, so that goes clear too.
        return line.onTap == null
            ? Theme(
                data: Theme.of(
                  context,
                ).copyWith(canvasColor: Colors.transparent),
                child: Chip(
                  key: key,
                  side: BorderSide.none,
                  backgroundColor: Colors.transparent,
                  avatarBoxConstraints: avatarBox,
                  avatar: avatar,
                  label: label,
                  // In the words' colour of the chip that has a tap.
                  labelStyle: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              )
            : ActionChip(
                key: key,
                avatarBoxConstraints: avatarBox,
                avatar: avatar,
                label: label,
                onPressed: line.onTap,
              );
      },
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
    final found = _reasonFor(ref, task);
    // Someone else's reminders that name nobody: no row at all.
    if (found?.hidden == true) return const SizedBox.shrink();
    // Someone else's reminders are theirs: the row names them, with or
    // without a date, and offers nothing.
    final person = found?.block == ReminderBlock.notForAccount;
    final preferences = ref.watch(reminderPreferencesProvider);
    final settings = preferences.value ?? const ReminderPreferences();
    // The task as it would be saved, with this plan, when it applies: only
    // where this phone rings, as the plan is this account's own.
    final ringsHere = reminderRingsHere(ref, task);
    final planned =
        schedule == null || plan == null || onChanged == null || !ringsHere
        ? null
        : schedule!.copyWith(
            reminderMinutes: minutes,
            reminderTime: time,
            reminderPlan: plan,
          );
    final active = planned == null ? null : ReminderPlans.active(planned);
    final dated = hasDate || active != null;
    final reason = dated || person ? found : null;
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
    final checked =
        planned ??
        schedule?.copyWith(
          reminderMinutes: minutes,
          reminderTime: time,
          // A plan that can't ring here doesn't count.
          reminderPlan: ringsHere ? schedule!.reminderPlan : null,
        );
    final passed =
        dated && reason == null && !blocked && _alertPassed(ref, checked);
    // Its time came and it rang, or a snooze is to come: not D1's case.
    final rang = passed ? _lastAlert(ref, checked) : null;
    final minute = time ?? settings.dateOnlyTime;
    final value = active != null
        ? reminderPlanText(context, ref, planned!)
        : hasTime
        ? '${context.reminderLead(minutes ?? settings.leadMinutes)}${minutes == null ? ' · ${context.l10n.defaultChoice}' : ''}'
        : minutes == -1 || minute == null
        ? context.l10n.off
        : _clock(context, minute);
    final onTap = reason != null
        ? reason.action(context, ref)
        : !dated
        ? null
        : () => _chooseReminder(
            context,
            hasTime: hasTime,
            minutes: minutes,
            time: time,
            defaultLead: settings.leadMinutes,
            defaultTime: settings.dateOnlyTime,
            plan: plan,
            // Plans only where they can be kept, and ring.
            schedule: onChanged == null || !ringsHere ? null : schedule,
            shared: reminderShared(ref, task),
            onChosen: (value, chosenTime, chosenPlan) {
              if (onChanged case final changed?) {
                changed(value, chosenTime, chosenPlan);
                return;
              }
              if (value != minutes) onMinutes(value);
              if (chosenTime != time) onTime(chosenTime);
            },
          );
    final line =
        reason?.text(context) ??
        (!dated
            ? context.l10n.dateForReminder
            : rang != null
            ? _rangText(context, ref, rang, plan: active == null ? null : value)
            : passed
            ? context.l10n.noReminderTimePassed
            : value);
    // A line that names itself (a plan's, a reason's, one that says the
    // reminder has passed or rung) is the row's only text: no «Recordatorio»
    // over it.
    final named = reason != null || (dated && (passed || active != null));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(
            passed && rang == null
                ? Icons.notifications_off_outlined
                : active != null
                ? Icons.notifications_active_outlined
                : Icons.notifications_outlined,
          ),
          title: Text(named ? line : context.l10n.reminder),
          subtitle: named ? null : Text(line),
          trailing: onTap == null
              ? null
              : const Icon(Icons.chevron_right_rounded),
          onTap: onTap,
        ),
        if (preferences.hasError && !person)
          Text(context.l10n.reminderDefaultsError),
        if (preferences.isLoading && !person)
          Text(context.l10n.loadingReminders),
        // 8 dp from the row above and whatever comes next (UX-2205).
        if (blocked)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: TextButton.icon(
              onPressed: () => turnOnReminders(context),
              icon: const Icon(Icons.notifications_off_outlined, size: 18),
              label: Text(context.l10n.enableReminders),
            ),
          ),
      ],
    );
  }
}
