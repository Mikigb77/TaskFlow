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

/// Sheet result for the dictated project's row: its name is corrected.
const _renameProject = '+rename';

/// A pick in the project sheet: a project, or none.
typedef TaskListChoice = ({TaskListInfo? project});

/// The project sheet the project chip opens, for a task in [listId], or
/// going to [newName], a project a dictation's confirming tap creates. With
/// [none], it offers no project too. Null when it is closed without a pick.
/// «Sin proyecto» shows as chosen only when [selectedNone] is true and
/// there is no [listId] or [newName]; false while a card still asks.
/// With [onRename], a tap on [newName]'s row corrects its name, and the
/// sheet returns null.
Future<TaskListChoice?> chooseTaskList(
  BuildContext context,
  WidgetRef ref, {
  String? listId,
  String? newName,
  bool none = true,
  bool selectedNone = true,
  ValueChanged<String>? onRename,
}) async {
  final creating = newName != null && listId == null;
  final lists = ref.read(taskListsProvider).valueOrNull ?? <TaskListInfo>[];
  final choices = lists
      .where((list) => list.canEdit && (!list.inactive || list.id == listId))
      .toList();
  final chosen = await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
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
              child: Semantics(
                header: true,
                child: Text(
                  context.l10n.list,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ),
            // A tap opens its name to correct; nothing is created yet.
            if (creating)
              ListTile(
                leading: const Icon(Icons.create_new_folder_outlined),
                title: Text(context.l10n.commandNewProject(newName)),
                // ✓ marks the choice, not colour alone (UX-2514).
                trailing: onRename == null
                    ? const Icon(Icons.check_rounded)
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.check_rounded),
                          const SizedBox(width: 12),
                          Icon(
                            Icons.edit_outlined,
                            size: 20,
                            semanticLabel: context.l10n.commandRenameProject,
                          ),
                        ],
                      ),
                selected: true,
                onTap: () => Navigator.pop(
                  context,
                  onRename == null ? null : _renameProject,
                ),
              ),
            if (none)
              ListTile(
                leading: const Icon(Icons.folder_off_outlined),
                title: Text(context.l10n.noList),
                trailing: selectedNone && listId == null && newName == null
                    ? const Icon(Icons.check_rounded)
                    : null,
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
                trailing: listId == list.id
                    ? const Icon(Icons.check_rounded)
                    : null,
                selected: listId == list.id,
                onTap: () => Navigator.pop(context, list.id),
              ),
            // Last, unless the dictated project is already the new one.
            if (!creating)
              ListTile(
                leading: const Icon(Icons.add_rounded),
                title: Text(context.l10n.newList),
                onTap: () => Navigator.pop(context, _newProject),
              ),
          ],
        ),
      ),
    ),
  );
  if (chosen == null || !context.mounted) return null;
  if (chosen == _renameProject) {
    final name = await _correctName(context, newName!);
    if (name != null && name != newName.trim()) onRename!(name);
    return null;
  }
  if (chosen == _newProject) {
    final project = await editTaskList(context, ref);
    return project == null ? null : (project: project);
  }
  return (project: lists.where((list) => list.id == chosen).firstOrNull);
}

/// The name of a project a dictation creates, to correct: the name, or null
/// when cancelled.
Future<String?> _correctName(BuildContext context, String name) =>
    showDialog<String>(
      context: context,
      builder: (context) => _ProjectNameDialog(name: name),
    );

class _ProjectNameDialog extends StatefulWidget {
  const _ProjectNameDialog({required this.name});
  final String name;

  @override
  State<_ProjectNameDialog> createState() => _ProjectNameDialogState();
}

class _ProjectNameDialogState extends State<_ProjectNameDialog> {
  // Selected, so typing replaces a misheard name.
  late final _name = TextEditingController(
    text: widget.name,
  )..selection = TextSelection(baseOffset: 0, extentOffset: widget.name.length);

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    scrollable: true,
    title: Text(context.l10n.newList),
    content: TextField(
      key: const ValueKey('new-project-name'),
      controller: _name,
      maxLength: 80,
      autofocus: true,
      decoration: InputDecoration(
        labelText: context.l10n.listName,
        counterText: '',
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(context.l10n.cancel),
      ),
      ValueListenableBuilder(
        valueListenable: _name,
        builder: (context, value, _) => FilledButton(
          onPressed: value.text.trim().isEmpty
              ? null
              : () => Navigator.pop(context, _name.text.trim()),
          child: Text(context.l10n.commandUseName),
        ),
      ),
    ],
  );
}

/// [child], which TalkBack reads as [label] when there is one.
Widget spokenAs(String? label, Widget child) => label == null
    ? child
    : Semantics(label: label, excludeSemantics: true, child: child);

class TaskListPicker extends ConsumerWidget {
  const TaskListPicker({
    super.key,
    required this.listId,
    this.onChanged,
    this.asRow = false,
    this.lockShared = false,
    this.newName,
    this.onRename,
    this.note = false,
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

  /// [newName] corrected in the sheet. Nothing is created yet.
  final ValueChanged<String>? onRename;

  /// The item is a note: the share question and the locked chip say so.
  final bool note;

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
      onRename: onRename,
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
            note
                ? context.l10n.shareNoteConfirm(
                    project!.groupName ?? project.name,
                  )
                : context.l10n.shareTaskConfirm(
                    project!.groupName ?? project.name,
                  ),
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
            // The chip's name comes first, so it shows at large text.
            ? asRow
                  ? context.l10n.commandNewProject(newName!)
                  : context.l10n.commandNewProjectChip(newName!)
            : listId == null
            ? context.l10n.noList
            : context.l10n.listUnavailable);
    // TalkBack hears «Proyecto: Casa», not a bare name.
    final spoken = selected == null ? null : context.l10n.projectLabel(name);
    final VoidCallback? onPressed = locked
        ? () => showFeedback(
            ScaffoldMessenger.of(context),
            note ? context.l10n.sharedNoteStays : context.l10n.sharedTaskStays,
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
        title: spokenAs(spoken, Text(name)),
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
            Flexible(
              child: spokenAs(
                spoken,
                Text(name, overflow: TextOverflow.ellipsis),
              ),
            ),
            if (!locked && onChanged != null) const DropDownMark(),
          ],
        ),
      ),
      onPressed: onPressed,
    );
  }
}
