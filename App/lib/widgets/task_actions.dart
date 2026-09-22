import 'package:agenda/l10n/region.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:agenda/services/capture_store.dart';

/// Reserve space for capture controls so they never cover the agenda.
class TaskActions extends ConsumerWidget {
  const TaskActions({super.key, required this.onCreate});
  final VoidCallback onCreate;
  @override
  Widget build(BuildContext context, WidgetRef ref) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ref.watch(pendingCapturesProvider).when(
              data: (sessions) => sessions.isEmpty
                  ? const SizedBox.shrink()
                  : TextButton.icon(
                      onPressed: () =>
                          Navigator.pushNamed(context, '/captures'),
                      icon: const Icon(Icons.restore_rounded, size: 18),
                      label: Text(
                          context.l10n.pendingCaptureCount(sessions.length))),
              loading: () => const SizedBox.shrink(),
              error: (_, __) => TextButton(
                  onPressed: () => Navigator.pushNamed(context, '/captures'),
                  child: Text(context.l10n.checkCaptures))),
          LayoutBuilder(builder: (context, constraints) {
            final voice = Tooltip(
                message: context.l10n.createVoiceTask,
                child: FilledButton.icon(
                    onPressed: () => Navigator.pushNamed(context, '/voiceTask',
                        arguments: true),
                    icon: const Icon(Icons.mic_none_rounded),
                    label: Text(context.l10n.sayTask)));
            final typed = Tooltip(
                message: context.l10n.createTaskTooltip,
                child: OutlinedButton.icon(
                    onPressed: onCreate,
                    icon: const Icon(Icons.edit_outlined),
                    label: Text(context.l10n.newTask)));
            if (constraints.maxWidth < 340 ||
                MediaQuery.textScalerOf(context).scale(14) > 18) {
              return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [voice, const SizedBox(height: 8), typed]);
            }
            return Row(children: [
              Expanded(child: voice),
              const SizedBox(width: 12),
              typed
            ]);
          }),
        ]),
      );
}
