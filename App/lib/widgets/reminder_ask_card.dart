import 'package:agenda/l10n/region.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:agenda/providers/reminder_provider.dart';
import 'package:agenda/providers/task_provider.dart';
import 'package:agenda/services/reminder_preferences.dart';
import 'package:agenda/widgets/app_components.dart';
import 'package:agenda/widgets/reminder_control.dart';

/// Asks once, below the tasks, whether to turn reminders on, once the account
/// has a task with a date. Either answer is remembered for this account on
/// this phone.
class ReminderAskCard extends ConsumerStatefulWidget {
  const ReminderAskCard({super.key});
  @override
  ConsumerState<ReminderAskCard> createState() => _ReminderAskCardState();
}

class _ReminderAskCardState extends ConsumerState<ReminderAskCard>
    with AutomaticKeepAliveClientMixin {
  bool _answered = false;
  bool _running = false;

  @override
  bool get wantKeepAlive => _running;

  /// Kept alive while hidden, even when the list scrolls it away, so the
  /// shared action can still use this context for the exact-alarm question
  /// and the confirmation.
  Future<void> _answer({required bool yes}) async {
    if (_answered) return;
    setState(() {
      _answered = true;
      _running = yes;
    });
    final store = ref.read(reminderPreferenceStoreProvider);
    final owner = ref.read(taskRepositoryProvider).ownerKey;
    try {
      final settings = await store.read(owner);
      await store.write(
        owner,
        ReminderPreferences(
          enabled: settings.enabled,
          leadMinutes: settings.leadMinutes,
          dateOnlyTime: settings.dateOnlyTime,
          morning: settings.morning,
          evening: settings.evening,
          asked: true,
        ),
      );
    } catch (_) {
      // The answer still holds for this session; the card stays hidden.
    }
    if (!mounted) return;
    ref.invalidate(reminderPreferencesProvider);
    if (!yes) return;
    try {
      await turnOnReminders(context);
    } finally {
      _running = false;
      if (mounted) updateKeepAlive();
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    // Watched first so the tasks at launch are recorded even while hidden.
    final dated = ref.watch(datedTasksProvider);
    // Phones without reminders (desktop builds) have nothing to turn on.
    if (_answered || !ref.watch(reminderAccessProvider).supported) {
      return const SizedBox.shrink();
    }
    final settings = ref.watch(reminderPreferencesProvider).valueOrNull;
    if (settings == null || settings.enabled || settings.asked || !dated.any) {
      return const SizedBox.shrink();
    }
    final colors = Theme.of(context).colorScheme;
    return AppSurface(
      color: colors.primaryContainer,
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            dated.savedThisSession
                ? context.l10n.reminderAskQuestion
                : context.l10n.reminderAskQuestionTasks,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: colors.onPrimaryContainer,
            ),
          ),
          const SizedBox(height: 4),
          OverflowBar(
            alignment: MainAxisAlignment.end,
            overflowAlignment: OverflowBarAlignment.end,
            spacing: 8,
            children: [
              TextButton(
                onPressed: () => _answer(yes: false),
                child: Text(context.l10n.reminderAskNotNow),
              ),
              FilledButton(
                onPressed: () => _answer(yes: true),
                child: Text(context.l10n.reminderAskYes),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
