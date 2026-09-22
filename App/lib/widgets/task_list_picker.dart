import 'package:agenda/l10n/region.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:agenda/models/task_list_info.dart';
import 'package:agenda/providers/task_lists_provider.dart';

Color taskListColor(String color) => switch (color) {
      'blue' => const Color(0xff497dac),
      'violet' => const Color(0xff8f72b3),
      'amber' => const Color(0xffb98526),
      'rose' => const Color(0xffb56b87),
      _ => const Color(0xff23877a),
    };

class TaskListPicker extends ConsumerWidget {
  const TaskListPicker(
      {super.key,
      required this.listId,
      this.onChanged,
      this.lockShared = false});
  final String? listId;
  final ValueChanged<String?>? onChanged;
  final bool lockShared;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lists = ref.watch(taskListsProvider).valueOrNull ?? <TaskListInfo>[];
    final selected = lists.where((list) => list.id == listId).firstOrNull;
    return ActionChip(
        labelStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface),
        avatar: Icon(Icons.folder_outlined,
            size: 18,
            color: selected == null ? null : taskListColor(selected.color)),
        label: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 230),
            child: Text(
                selected?.name ??
                    (listId == null
                        ? context.l10n.noList
                        : context.l10n.listUnavailable),
                overflow: TextOverflow.ellipsis)),
        onPressed: onChanged == null || (lockShared && selected?.shared == true)
            ? null
            : () async {
                final chosen = await showModalBottomSheet<String>(
                    context: context,
                    builder: (context) => SafeArea(
                            child: ListView(shrinkWrap: true, children: [
                          ListTile(
                              title: Text(context.l10n.moveToList),
                              subtitle: Text(context.l10n.moveToListHelp)),
                          ListTile(
                              leading: const Icon(Icons.folder_off_outlined),
                              title: Text(context.l10n.noList),
                              selected: listId == null,
                              onTap: () => Navigator.pop(context, '')),
                          for (final list in lists.where((list) =>
                              list.canEdit &&
                              (!list.archived || list.id == listId)))
                            ListTile(
                                leading: Icon(Icons.folder_outlined,
                                    color: taskListColor(list.color)),
                                title: Text(list.name),
                                subtitle: list.shared
                                    ? const Text(
                                        'Shared · everyone in this list can see tasks, notes and uploaded files')
                                    : list.archived
                                        ? Text(context.l10n.archived)
                                        : null,
                                selected: listId == list.id,
                                onTap: () => Navigator.pop(context, list.id)),
                          if (lists.isEmpty)
                            ListTile(title: Text(context.l10n.createListHelp)),
                        ])));
                if (chosen != null) onChanged!(chosen.isEmpty ? null : chosen);
              });
  }
}
