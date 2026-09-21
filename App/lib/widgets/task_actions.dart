import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Reserve space for capture controls so they never cover the agenda.
class TaskActions extends ConsumerWidget {
  const TaskActions({super.key, required this.onCreate});
  final VoidCallback onCreate;
  @override
  Widget build(BuildContext context, WidgetRef ref) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
        child: Row(children: [
          Tooltip(
              message: 'Create task with voice',
              child: SizedBox(
                  width: 56,
                  height: 54,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.zero,
                        backgroundColor: Theme.of(context).colorScheme.surface),
                    onPressed: () => Navigator.pushNamed(context, '/voiceTask',
                        arguments: true),
                    child: const Icon(Icons.mic_none_rounded),
                  ))),
          const SizedBox(width: 12),
          Expanded(
              child: Tooltip(
                  message: 'Create task',
                  child: ElevatedButton.icon(
                      onPressed: onCreate,
                      icon: const Icon(Icons.add),
                      label: const Text('New task')))),
        ]),
      );
}
