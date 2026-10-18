import 'package:agenda/l10n/region.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:agenda/models/task_list_info.dart';
import 'package:agenda/providers/task_lists_provider.dart';
import 'package:agenda/screens/task_lists_screen.dart';
import 'package:agenda/widgets/app_components.dart';

Color taskListColor(String color) => switch (color) {
  'blue' => const Color(0xff497dac),
  'violet' => const Color(0xff8f72b3),
  'amber' => const Color(0xffb98526),
  'rose' => const Color(0xffb56b87),
  _ => const Color(0xff23877a),
};

/// Sheet result for the "New project" row; project ids are UUIDs.
const _newProject = '+new';

/// A pick in the project sheet: a project, or none.
typedef TaskListChoice = ({TaskListInfo? project});

/// The project sheet the project chip opens, for a task in [listId], or
/// going to [newName], a project a dictation's confirming tap creates. With
/// [none], it offers no project too. Null when it is closed without a pick.
/// «Sin proyecto» shows as chosen only when [selectedNone] is true and
/// there is no [listId] or [newName]; false while a card still asks.
Future<TaskListChoice?> chooseTaskList(
  BuildContext context,
  WidgetRef ref, {
  String? listId,
  String? newName,
  bool none = true,
  bool selectedNone = true,
}) async {
  final lists = ref.read(taskListsProvider).valueOrNull ?? <TaskListInfo>[];
  final choices = lists
      .where((list) => list.canEdit && (!list.inactive || list.id == listId))
      .toList();
  final chosen = await showModalBottomSheet<String>(
    context: context,
    builder: (context) => SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: [
          ListTile(title: Text(context.l10n.list)),
          // Keeping it closes the sheet as it is.
          if (newName != null && listId == null)
            ListTile(
              leading: const Icon(Icons.create_new_folder_outlined),
              title: Text(context.l10n.commandNewProject(newName)),
              selected: true,
              onTap: () => Navigator.pop(context),
            ),
          if (none)
            ListTile(
              leading: const Icon(Icons.folder_off_outlined),
              title: Text(context.l10n.noList),
              selected: selectedNone && listId == null && newName == null,
              onTap: () => Navigator.pop(context, ''),
            ),
          for (final list in choices)
            ListTile(
              leading: Icon(
                Icons.folder_outlined,
                color: taskListColor(list.color),
              ),
              title: Text(list.name),
              subtitle: list.shared
                  ? Text(list.groupName ?? context.l10n.sharedProject)
                  : list.inactive
                  ? Text(context.l10n.archived)
                  : null,
              selected: listId == list.id,
              onTap: () => Navigator.pop(context, list.id),
            ),
          if (choices.isEmpty)
            ListTile(
              leading: const Icon(Icons.add_rounded),
              title: Text(context.l10n.newList),
              onTap: () => Navigator.pop(context, _newProject),
            ),
        ],
      ),
    ),
  );
  if (chosen == null || !context.mounted) return null;
  if (chosen == _newProject) {
    final project = await editTaskList(context, ref);
    return project == null ? null : (project: project);
  }
  return (project: lists.where((list) => list.id == chosen).firstOrNull);
}

class TaskListPicker extends ConsumerWidget {
  const TaskListPicker({
    super.key,
    required this.listId,
    this.onChanged,
    this.asRow = false,
    this.lockShared = false,
    this.newName,
  });
  final String? listId;
  final ValueChanged<TaskListInfo?>? onChanged;

  /// The task already exists: moving it into a shared project asks first,
  /// and a shared task stays in its project.
  final bool lockShared;
  final bool asRow;

  /// A project a dictation's confirming tap creates for this task: shown by
  /// name, and chosen in the sheet, until another is picked.
  final String? newName;

  Future<void> _choose(
    BuildContext context,
    WidgetRef ref,
    TaskListInfo? selected,
  ) async {
    final choice = await chooseTaskList(
      context,
      ref,
      listId: listId,
      newName: newName,
    );
    if (choice == null || !context.mounted) return;
    final project = choice.project;
    if (lockShared && project?.shared == true && selected?.shared != true) {
      if (!context.mounted) return;
      final share = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          scrollable: true,
          content: Text(
            context.l10n.shareTaskConfirm(project!.groupName ?? project.name),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(context.l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(context.l10n.shareTask),
            ),
          ],
        ),
      );
      if (share != true) return;
    }
    onChanged!(project);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lists = ref.watch(taskListsProvider).valueOrNull ?? <TaskListInfo>[];
    final selected = lists.where((list) => list.id == listId).firstOrNull;
    final locked = lockShared && selected?.shared == true;
    final creating = newName != null && listId == null;
    final name =
        selected?.name ??
        (creating
            ? context.l10n.commandNewProject(newName!)
            : listId == null
            ? context.l10n.noList
            : context.l10n.listUnavailable);
    final VoidCallback? onPressed = locked
        ? () => showFeedback(
            ScaffoldMessenger.of(context),
            context.l10n.sharedTaskStays,
          )
        : onChanged == null
        ? null
        : () => _choose(context, ref, selected);
    final avatar = Icon(
      creating ? Icons.create_new_folder_outlined : Icons.folder_outlined,
      size: 18,
      color: selected == null ? null : taskListColor(selected.color),
    );
    if (asRow) {
      return ListTile(
        contentPadding: EdgeInsets.zero,
        leading: avatar,
        title: Text(name),
        trailing: locked
            ? null
            : const Icon(Icons.chevron_right_rounded, size: 20),
        onTap: onPressed,
      );
    }
    return ActionChip(
      labelStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface),
      avatar: avatar,
      label: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 230),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(child: Text(name, overflow: TextOverflow.ellipsis)),
            if (!locked && onChanged != null)
              const Icon(Icons.arrow_drop_down_rounded, size: 18),
          ],
        ),
      ),
      onPressed: onPressed,
    );
  }
}
