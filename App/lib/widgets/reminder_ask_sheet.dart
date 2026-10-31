import 'dart:async';
import 'package:agenda/l10n/region.dart';
import 'package:agenda/l10n/reminder_plan_words.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:agenda/models/reminder_plan.dart';
import 'package:agenda/models/task.dart';
import 'package:agenda/providers/auth_provider.dart';
import 'package:agenda/providers/calendar_focus_provider.dart';
import 'package:agenda/providers/reminder_provider.dart';
import 'package:agenda/providers/shell_tab_provider.dart';
import 'package:agenda/providers/task_lists_provider.dart';
import 'package:agenda/providers/task_provider.dart';
import 'package:agenda/services/reminder_engine.dart';
import 'package:agenda/services/reminder_plans.dart';
import 'package:agenda/services/reminder_preferences.dart';
import 'package:agenda/services/task_database.dart';
import 'package:agenda/models/task_list_info.dart';
import 'package:agenda/widgets/app_components.dart';
import 'package:agenda/widgets/reminder_control.dart';
import 'package:agenda/widgets/task_planning_control.dart';
import 'package:agenda/widgets/task_schedule_label.dart';

/// Accounts asked, in this run of the app, whether to turn reminders on.
final _askingProvider = Provider<Set<String>>((ref) => {});

/// Accounts with the question, or an offer, waiting or showing now.
final _waitingProvider = Provider<Set<String>>((ref) => {});

/// The tasks offered a plan in this run of the app, by owner and id.
final _offeredProvider = Provider<Set<String>>((ref) => {});

/// Asks once per account on this phone whether to turn reminders on, after
/// the first saved task with a date whose reminder can still ring on this
/// phone: not one for today saved after its 9:00, nor one saved inside its
/// lead time, nor one given to someone else or in a project muted or
/// archived here. Call
/// it from the saved form's context, right after its route was popped, and
/// pass the save message's [feedback]. The question waits until that route
/// is gone and the save message has closed, so the person first sees where
/// the task went and can still undo it. It isn't asked when they undid the save, moved to another
/// screen or tab, or another message replaced the save message; the next
/// dated save asks instead.
///
/// With reminders on, the question offers a plan instead, once per task: for
/// a saved task (with its id) whose deadline, else day, is two weeks or more
/// away and has none (Backend/docs/REMINDER_PLANS.md, «The offer»). Only
/// when [offerPlan]: an edit save passes false unless it moved that day.
/// After two «Ahora no» in a row from this account on this phone it's no
/// longer offered; «Hasta la fecha límite» stays in every task's sheet.
void askAboutRemindersAfterSave(
  BuildContext context,
  Iterable<Task> saved, {
  Future<ScaffoldFeatureController<SnackBar, SnackBarClosedReason>?>? feedback,
  bool offerPlan = true,
}) {
  final dated = saved
      .where(
        (task) =>
            !task.isNote && (task.dueDate != null || task.deadline != null),
      )
      .toList();
  final container = ProviderScope.containerOf(context, listen: false);
  final route = ModalRoute.of(context);
  // Phones without reminders (desktop builds) have nothing to turn on.
  if (dated.isEmpty ||
      route == null ||
      !container.read(reminderAccessProvider).supported) {
    return;
  }
  final owner = container.read(taskRepositoryProvider).ownerKey;
  if (!container.read(_waitingProvider).add(owner)) return;
  final navigator = Navigator.of(context);
  // The screen the form was over; pops nothing.
  Route<Object?>? under;
  navigator.popUntil((top) {
    under = top;
    return true;
  });
  final tabSwitches = container.read(shellTabSwitchesProvider);
  unawaited(
    _ask(
      container,
      navigator,
      route,
      under,
      tabSwitches,
      feedback,
      owner,
      dated,
      offerPlan,
    ),
  );
}

Future<void> _ask(
  ProviderContainer container,
  NavigatorState navigator,
  ModalRoute<Object?> route,
  Route<Object?>? under,
  int tabSwitches,
  Future<ScaffoldFeatureController<SnackBar, SnackBarClosedReason>?>? feedback,
  String owner,
  List<Task> dated,
  bool offerPlan,
) async {
  final store = container.read(reminderPreferenceStoreProvider);
  try {
    await route.completed;
    final bar = await feedback;
    if (bar != null) {
      // Only once the save message was seen: not after Deshacer, and not
      // when another message (Tarea completada, a new date) replaced it.
      final reason = await bar.closed;
      if (reason != SnackBarClosedReason.timeout &&
          reason != SnackBarClosedReason.swipe &&
          reason != SnackBarClosedReason.dismiss) {
        return;
      }
    }
    // Never over a screen they opened meanwhile.
    if (under != null && !under.isCurrent) return;
    // Nor over another tab, even if they came back.
    if (container.read(shellTabSwitchesProvider) != tabSwitches) return;
    final settings = await store.read(owner);
    if (!navigator.mounted ||
        container.read(taskRepositoryProvider).ownerKey != owner) {
      return;
    }
    final now = container.read(calendarClockProvider)();
    // With reminders on, the question offers a plan instead; never with
    // them off.
    if (settings.enabled) {
      if (offerPlan) {
        await _offer(
          container,
          navigator,
          store,
          owner,
          dated,
          now,
          settings.dateOnlyTime,
        );
      }
      return;
    }
    if (settings.asked || container.read(_askingProvider).contains(owner)) {
      return;
    }
    // Only for a reminder that can still come on this phone: not for a task
    // given to someone else, nor in a project muted or archived here. The
    // next dated save asks.
    final ringsHere = await _ringsHere(container);
    if (!dated.any(
      (task) =>
          ringsHere(task) && ReminderEngine.alertAhead(task, settings, now),
    )) {
      return;
    }
    if (!navigator.mounted ||
        container.read(taskRepositoryProvider).ownerKey != owner ||
        container.read(_askingProvider).contains(owner)) {
      return;
    }
    // Asked: not again in this run, whatever happens next.
    container.read(_askingProvider).add(owner);
    final yes = await showModalBottomSheet<bool>(
      context: navigator.context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => const _ReminderAskSheet(),
    );
    // Either answer, or closing the sheet, means it was asked.
    try {
      final latest = await store.read(owner);
      await store.write(
        owner,
        ReminderPreferences(
          enabled: latest.enabled,
          leadMinutes: latest.leadMinutes,
          dateOnlyTime: latest.dateOnlyTime,
          morning: latest.morning,
          evening: latest.evening,
          asked: true,
        ),
      );
    } catch (_) {
      // Not asked again in this run all the same.
    }
    container.invalidate(reminderPreferencesProvider);
    if (yes == true && navigator.mounted) {
      await turnOnReminders(navigator.context);
    }
  } catch (_) {
    // Without the saved answer the question waits for the next dated task.
  } finally {
    try {
      container.read(_waitingProvider).remove(owner);
    } catch (_) {
      // The app has gone: nothing waits any more.
    }
  }
}

/// Whether a task's reminders ring on this phone, for this account (UX-1601's
/// rule): a personal task, a «Todos» task, one given to this account, or an
/// unassigned one in a project it manages, in a project not muted or
/// archived here. A project this phone doesn't know yet doesn't ring.
Future<bool Function(Task)> _ringsHere(ProviderContainer container) async {
  final me = container.read(authProvider).account?.id;
  List<TaskListInfo> projects;
  try {
    projects = await container.read(taskListsProvider.future);
  } catch (_) {
    projects = const [];
  }
  return (task) {
    if (task.listId == null) {
      return TaskDatabase.reminderBlock(task, me) == null;
    }
    final project = projects
        .where((project) => project.id == task.listId)
        .firstOrNull;
    if (project == null) return false;
    return TaskDatabase.reminderBlock(
          task,
          me,
          archived: project.inactive,
          muted: project.notifications == 'muted',
          role: project.role,
        ) ==
        null;
  };
}

/// The offer: a saved task whose day is two weeks or more away, with no
/// plan and its reminder still the default, gets one question under its
/// title and day: «Faltan 3 semanas. ¿Te aviso cada 3 días, y a diario la
/// última semana?». «Sí, recuérdamelo» sets Normal, with Deshacer. At most
/// once per task, whatever the answer; only for a task that rings on this
/// phone (personal, «Todos», assigned to this account, or unassigned in a
/// project this account manages, in a project not muted or archived here),
/// since the plan is this account's own, and never when this phone can't
/// ring. Not after
/// two «Ahora no» in a row from this account on this phone: «Sí» starts the
/// count again, and closing the sheet without an answer leaves it as it was.
Future<void> _offer(
  ProviderContainer container,
  NavigatorState navigator,
  ReminderPreferenceStore store,
  String owner,
  List<Task> dated,
  DateTime now,
  int? dateOnlyTime,
) async {
  int declines;
  try {
    declines = await store.planOfferDeclines(owner);
  } catch (_) {
    declines = 0;
  }
  // Two «Ahora no» in a row: no longer asked.
  if (declines >= 2) return;
  final offered = container.read(_offeredProvider);
  Set<int> before;
  try {
    before = await store.planOffers(owner);
  } catch (_) {
    before = {};
  }
  // A plan is this account's own, so «Sí» rings only here, on a shared task
  // too; but not on a task for someone else, nor in a project muted or
  // archived here (UX-1601's rule).
  final ringsHere = await _ringsHere(container);
  final task = dated
      .where(
        (task) =>
            task.id != null &&
            ringsHere(task) &&
            ReminderPlans.offerable(task, now) &&
            !before.contains(task.id) &&
            !offered.contains('$owner/${task.id}'),
      )
      .firstOrNull;
  if (task == null || !navigator.mounted) return;
  if (!(await container.read(reminderAccessProvider).capability()).allowed) {
    return;
  }
  if (!navigator.mounted) return;
  // Asked: at most once per task, whatever the answer. Not offered again in
  // this run even if it can't be saved.
  offered.add('$owner/${task.id}');
  unawaited(store.addPlanOffer(owner, task.id!).catchError((Object _) {}));
  final anchor = ReminderPlans.anchor(task)!;
  final yes = await showModalBottomSheet<bool>(
    context: navigator.context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => _PlanOfferSheet(
      task: task,
      anchor: anchor,
      now: now,
      dateOnlyTime: dateOnlyTime,
    ),
  );
  // Only the answers count: «Ahora no» adds one, «Sí» starts again.
  if (yes != null) {
    unawaited(
      store
          .setPlanOfferDeclines(owner, yes ? 0 : declines + 1)
          .catchError((Object _) {}),
    );
  }
  if (yes != true || !navigator.mounted) return;
  // The task as it is now: only one that still has no plan gets Normal.
  final current = container
      .read(taskProvider)
      .valueOrNull
      ?.where((item) => item.id == task.id)
      .firstOrNull;
  if (current == null ||
      current.reminderPlan != null ||
      !ReminderPlans.plannable(current)) {
    return;
  }
  final messenger = ScaffoldMessenger.maybeOf(navigator.context);
  final strings = navigator.context.l10n;
  final done = strings.reminderPlanOfferDone(
    planDay(ReminderPlans.anchor(current)!, now, navigator.context.localeName),
  );
  final notifier = container.read(taskProvider.notifier);
  try {
    await notifier.updateTask(
      current.copyWith(
        reminderPlan: const ReminderPlan.rhythm(ReminderPlan.normal),
      ),
    );
  } catch (_) {
    if (messenger != null && messenger.mounted) {
      unawaited(showFeedback(messenger, strings.updateReminderError));
    }
    return;
  }
  if (messenger != null && messenger.mounted) {
    unawaited(
      showFeedback(
        messenger,
        done,
        actionLabel: strings.undo,
        onAction: () async {
          if (!messenger.mounted ||
              !identical(container.read(taskProvider.notifier), notifier)) {
            return;
          }
          // The task as it was before «Sí», shown at once, even while a
          // sync is under way. It stays offered: not asked again.
          try {
            await notifier.updateTask(current);
            await notifier.showLocal();
          } catch (_) {
            if (messenger.mounted) {
              unawaited(showFeedback(messenger, strings.undoError));
            }
          }
        },
      ),
    );
  }
}

class _PlanOfferSheet extends StatelessWidget {
  const _PlanOfferSheet({
    required this.task,
    required this.anchor,
    required this.now,
    required this.dateOnlyTime,
  });
  final Task task;
  final DateTime anchor;
  final DateTime now;
  final int? dateOnlyTime;

  @override
  Widget build(BuildContext context) {
    final strings = context.l10n;
    final theme = Theme.of(context);
    const plan = ReminderPlan.rhythm(ReminderPlan.normal);
    // Which task, and when: after a dictation of several, Calendar may show
    // another one lit.
    final when = task.deadline != null
        ? taskDeadlineLabel(context, task)
        : taskDayLine(context, task);
    final rhythm = planRhythm(
      strings,
      plan,
      anchor: anchor,
      now: now,
      minute: ReminderPlans.minute(plan, dateOnlyTime),
      capitalized: false,
    );
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Read out by TalkBack as the sheet opens: the task, then the
          // question. In titleMedium, both answers stay on screen at 2× on
          // a small phone.
          MergeSemantics(
            child: Semantics(
              header: true,
              liveRegion: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _TaskLine(
                    title: task.title,
                    when: when,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    planOffer(
                      strings,
                      ReminderPlans.daysUntil(anchor, now),
                      rhythm,
                    ),
                    style: theme.textTheme.titleMedium,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          FilledButton(
            key: const ValueKey('reminder-plan-offer-yes'),
            onPressed: () => Navigator.pop(context, true),
            child: Text(strings.reminderAskYes),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(strings.reminderAskNotNow),
          ),
        ],
      ),
    );
  }
}

/// «{title} · {when}» on at most two lines. A title too long for them is
/// cut with an ellipsis, never the day: it's what says which task. TalkBack
/// reads the whole line.
class _TaskLine extends StatelessWidget {
  const _TaskLine({required this.title, required this.when, this.style});
  final String title;
  final String when;
  final TextStyle? style;

  static const _lines = 2;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final full = '$title · $when';
      final scaler = MediaQuery.textScalerOf(context);
      final direction = Directionality.of(context);
      bool fits(String text) {
        final painter = TextPainter(
          text: TextSpan(text: text, style: style),
          textScaler: scaler,
          textDirection: direction,
          maxLines: _lines,
        )..layout(maxWidth: constraints.maxWidth);
        final fits = !painter.didExceedMaxLines;
        painter.dispose();
        return fits;
      }

      var shown = full;
      if (!fits(full)) {
        // The longest start of the title that fits with the day.
        final letters = title.characters;
        // The dot stays with the cut title, not at the start of a line.
        String cut(int length) =>
            '${letters.take(length).toString().trimRight()}… · $when';
        var low = 0;
        var high = letters.length;
        while (low < high) {
          final middle = (low + high + 1) ~/ 2;
          if (fits(cut(middle))) {
            low = middle;
          } else {
            high = middle - 1;
          }
        }
        shown = cut(low);
      }
      return Text(
        shown,
        semanticsLabel: full,
        maxLines: _lines,
        overflow: TextOverflow.ellipsis,
        style: style,
      );
    },
  );
}

class _ReminderAskSheet extends StatelessWidget {
  const _ReminderAskSheet();

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Read out by TalkBack as the sheet opens.
        Semantics(
          header: true,
          liveRegion: true,
          child: Text(
            context.l10n.reminderAskQuestion,
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(context.l10n.reminderAskYes),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(context.l10n.reminderAskNotNow),
        ),
      ],
    ),
  );
}
