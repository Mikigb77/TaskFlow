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
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            title: Text(context.l10n.projectNotifications),
            subtitle: Text(project.name),
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
