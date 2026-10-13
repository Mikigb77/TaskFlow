import 'dart:async';
import 'package:agenda/l10n/region.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:agenda/models/task.dart';
import 'package:agenda/providers/reminder_provider.dart';
import 'package:agenda/providers/shell_tab_provider.dart';
import 'package:agenda/providers/task_provider.dart';
import 'package:agenda/services/reminder_preferences.dart';
import 'package:agenda/widgets/reminder_control.dart';

/// Accounts asked, or being asked, in this run of the app.
final _askingProvider = Provider<Set<String>>((ref) => {});

/// Asks once per account on this phone whether to turn reminders on, after
/// the first task with a date is saved. Call it from the saved form's
/// context, right after its route was popped, and pass the save message's
/// [feedback]. The question waits until that route is gone and the save
/// message has closed, so the person first sees where the task went and can
/// still undo it. It isn't asked when they undid the save, moved to another
/// screen or tab, or another message replaced the save message; the next
/// dated save asks instead.
void askAboutRemindersAfterSave(
  BuildContext context,
  Iterable<Task> saved, {
  Future<ScaffoldFeatureController<SnackBar, SnackBarClosedReason>?>? feedback,
}) {
  final dated = saved.any(
    (task) => !task.isNote && (task.dueDate != null || task.deadline != null),
  );
  final container = ProviderScope.containerOf(context, listen: false);
  final route = ModalRoute.of(context);
  // Phones without reminders (desktop builds) have nothing to turn on.
  if (!dated ||
      route == null ||
      !container.read(reminderAccessProvider).supported) {
    return;
  }
  final owner = container.read(taskRepositoryProvider).ownerKey;
  if (!container.read(_askingProvider).add(owner)) return;
  final navigator = Navigator.of(context);
  // The screen the form was over; pops nothing.
  Route<Object?>? under;
  navigator.popUntil((top) {
    under = top;
    return true;
  });
  final tabSwitches = container.read(shellTabSwitchesProvider);
  unawaited(
    _ask(container, navigator, route, under, tabSwitches, feedback, owner),
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
) async {
  final store = container.read(reminderPreferenceStoreProvider);
  var shown = false;
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
    if (settings.enabled ||
        settings.asked ||
        !navigator.mounted ||
        container.read(taskRepositoryProvider).ownerKey != owner) {
      return;
    }
    shown = true;
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
    if (!shown) container.read(_askingProvider).remove(owner);
  }
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
