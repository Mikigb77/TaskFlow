import 'package:agenda/widgets/app_components.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:agenda/l10n/region.dart';
import 'package:agenda/models/task_list_info.dart';
import 'package:agenda/providers/task_lists_provider.dart';
import 'package:agenda/providers/task_provider.dart';

Future<void> showProjectPreferences(
  BuildContext context,
  WidgetRef ref,
  TaskListInfo project,
) async {
  final store = ref.read(taskListStoreProvider);
  final choice = await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    // At large text the last choice scrolls into view (UX-2647).
    isScrollControlled: true,
    builder: (context) => SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * .7,
        ),
        child: ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Each its own node: TalkBack reads the heading, then
                  // the project's name (UX-2647).
                  Semantics(
                    container: true,
                    header: true,
                    child: Text(
                      context.l10n.projectNotifications,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  Semantics(
                    container: true,
                    child: Text(
                      project.name,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            for (final option in [
              ('all', context.l10n.updatesAll),
              ('assigned', context.l10n.updatesAssigned),
              ('muted', context.l10n.updatesMuted),
            ])
              ListTile(
                title: Text(option.$2),
                selected: project.notifications == option.$1,
                trailing: project.notifications == option.$1
                    ? const Icon(Icons.check_rounded)
                    : null,
                leading: Icon(
                  option.$1 == 'muted'
                      ? Icons.notifications_off_outlined
                      : Icons.notifications_outlined,
                ),
                onTap: () => Navigator.pop(context, option.$1),
              ),
          ],
        ),
      ),
    ),
  );
  if (choice == null || !context.mounted) return;
  try {
    await store.preferences(project.id, notifications: choice);
    ref.invalidate(taskListsProvider);
    await ref.read(taskProvider.notifier).loadTasks();
  } catch (_) {
    if (context.mounted) {
      showFeedback(ScaffoldMessenger.of(context), context.l10n.listUpdateError);
    }
  }
}
