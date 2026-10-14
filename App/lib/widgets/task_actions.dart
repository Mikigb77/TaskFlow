import 'package:agenda/l10n/region.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:agenda/providers/subscription_provider.dart';
import 'package:agenda/services/capture_store.dart';
import 'package:agenda/screens/voice_task_screen.dart';

/// The one way to add a task: `Añadir tarea` opens the capture sheet,
/// listening with Pro and typing without it. Its space is reserved so it
/// never covers the agenda.
class TaskActions extends ConsumerWidget {
  const TaskActions({super.key, this.projectId, this.page, this.day});

  /// The project a new task goes to, when the user can add to it.
  final String? projectId;

  /// A task page that shows what capture saves, instead of Calendar.
  final Object? page;

  /// The day shown: Calendar's selected day or the timeline's.
  final DateTime? day;
  @override
  Widget build(BuildContext context, WidgetRef ref) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ref
            .watch(pendingCapturesProvider)
            .when(
              data: (sessions) => sessions.isEmpty
                  ? const SizedBox.shrink()
                  : TextButton.icon(
                      onPressed: () =>
                          Navigator.pushNamed(context, '/captures'),
                      icon: const Icon(Icons.restore_rounded, size: 18),
                      label: Text(
                        context.l10n.pendingCaptureCount(sessions.length),
                      ),
                    ),
              loading: () => const SizedBox.shrink(),
              error: (_, __) => TextButton(
                onPressed: () => Navigator.pushNamed(context, '/captures'),
                child: Text(context.l10n.checkCaptures),
              ),
            ),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () => showCaptureSheet(
              context,
              projectId: projectId,
              page: page,
              day: day,
            ),
            icon: Icon(
              ref.watch(hasProProvider)
                  ? Icons.mic_none_rounded
                  : Icons.add_rounded,
            ),
            label: Text(context.l10n.addTask),
          ),
        ),
      ],
    ),
  );
}
