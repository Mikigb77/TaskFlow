import 'package:agenda/l10n/region.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:agenda/models/task.dart';
import 'package:agenda/providers/task_provider.dart';
import 'package:agenda/widgets/app_components.dart';
import 'package:agenda/widgets/schedule_editor.dart';

/// Shared by Calendar, Tasks and details, including keyboard/accessible buttons.
class TaskInteractions {
  static Future<void> toggle(
      BuildContext context, WidgetRef ref, Task task) async {
    final container = ProviderScope.containerOf(context, listen: false);
    final notifier = ref.read(taskProvider.notifier);
    final messenger = ScaffoldMessenger.of(context);
    final strings = context.l10n;
    try {
      await notifier.setCompleted(task, !task.isCompleted);
      if (!messenger.mounted ||
          !identical(container.read(taskProvider.notifier), notifier)) {
        return;
      }
      HapticFeedback.selectionClick();
      await showFeedback(messenger,
          task.isCompleted ? strings.taskReopened : strings.taskCompleted,
          actionLabel: strings.undo, onAction: () async {
        if (!messenger.mounted ||
            !identical(container.read(taskProvider.notifier), notifier)) {
          return;
        }
        try {
          await notifier.setCompleted(task, task.isCompleted);
        } catch (_) {
          _error(messenger, strings.undoError);
        }
      });
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
    final result = await editSchedule(context,
        date: task.displayDate,
        hasTime: task.hasTime,
        title: task.isRecurring
            ? strings.rescheduleRepeating
            : strings.rescheduleTask,
        moving: task);
    if (result == null ||
        !messenger.mounted ||
        !identical(container.read(taskProvider.notifier), notifier)) {
      return;
    }
    // The row may have left the screen; the messenger's context still has
    // the app's locale.
    final day = result.date == null
        ? null
        : (context.mounted ? context : messenger.context)
            .weekdayDate(result.date!);
    try {
      final seriesChange = result.scope == 'series'
          ? await notifier.rescheduleTask(task.id!, result.date, result.hasTime)
          : null;
      final occurrenceChange = result.scope != 'series'
          ? await notifier.changeOccurrence(task, result.date, result.hasTime,
              skip: result.scope == 'skip', reset: result.scope == 'reset')
          : null;
      if (!messenger.mounted) return;
      await showFeedback(
          messenger,
          result.scope == 'skip'
              ? strings.occurrenceSkippedNotice
              : result.scope == 'reset'
                  ? strings.originalRestored
                  : day == null
                      ? strings.movedInbox
                      : strings.movedOccurrenceDate(day),
          actionLabel: strings.undo, onAction: () async {
        if (!messenger.mounted ||
            !identical(container.read(taskProvider.notifier), notifier)) {
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
      });
    } catch (_) {
      _error(messenger, strings.scheduleError);
    }
  }

  static void _error(ScaffoldMessengerState messenger, String text) {
    if (messenger.mounted) showFeedback(messenger, text);
  }
}
