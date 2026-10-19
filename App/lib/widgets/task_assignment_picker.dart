import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:agenda/l10n/region.dart';
import 'package:agenda/models/task.dart';
import 'package:agenda/models/task_list_info.dart';
import 'package:agenda/providers/auth_provider.dart';
import 'package:agenda/providers/task_lists_provider.dart';
import 'package:agenda/widgets/task_list_picker.dart';

Task taskWithProject(Task task, TaskListInfo? project) => task.copyWith(
  listId: project?.id,
  assignment: !task.isNote && project?.shared == true ? 'group' : 'personal',
  assigneeId: null,
  assigneeName: null,
);

String responsibilityLabel(BuildContext context, Task task, int? accountId) =>
    switch (task.assignment) {
      'group' => context.l10n.assignedToGroup,
      'member' =>
        task.assigneeId == accountId
            ? context.l10n.assignedToMe
            : task.assigneeName ?? context.l10n.assignmentNeeded,
      'unassigned' => context.l10n.assignmentNeeded,
      _ => context.l10n.assignedToMe,
    };

/// Destination, responsibility and audience stay together in both editors.
class TaskAssignmentPicker extends ConsumerWidget {
  const TaskAssignmentPicker({
    super.key,
    required this.task,
    this.onChanged,
    this.lockShared = false,
    this.needsReview = false,
    this.hints = const {},
    this.onReviewed,
    this.compact = false,
    this.asRow,
    this.newProjectName,
    this.onRenameProject,
  });
  final Task task;
  final ValueChanged<Task>? onChanged;
  final bool lockShared;
  final bool needsReview;
  final Map<String, String?> hints;
  final VoidCallback? onReviewed;
  final bool compact;
  final bool? asRow;

  /// The project a dictation creates for this task on its confirming tap.
  final String? newProjectName;

  /// [newProjectName] corrected from the project sheet.
  final ValueChanged<String>? onRenameProject;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projects =
        ref.watch(taskListsProvider).valueOrNull ?? <TaskListInfo>[];
    final project = projects.where((p) => p.id == task.listId).firstOrNull;
    final account = ref.watch(authProvider).account;
    final shared = project?.shared == true;
    final editable = task.listId == null || project?.canEdit == true;
    final valid =
        editable &&
        (task.assignment != 'member' ||
            project?.people.any((p) => p.id == task.assigneeId && p.canEdit) ==
                true);
    final changeable = onChanged != null && editable;
    final names = hints.values
        .whereType<String>()
        .where((s) => s.isNotEmpty)
        .toSet()
        .join(' · ');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            TaskListPicker(
              asRow: asRow ?? compact,
              listId: task.listId,
              lockShared: lockShared,
              newName: newProjectName,
              onRename: onRenameProject,
              onChanged: onChanged == null
                  ? null
                  : (project) => onChanged!(taskWithProject(task, project)),
            ),
            if (shared && !task.isNote)
              ActionChip(
                avatar: Icon(
                  task.assignment == 'group'
                      ? Icons.groups_outlined
                      : Icons.person_outline,
                  size: 18,
                ),
                // ▾ says it can be changed, as on the project chip.
                label: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 230),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          responsibilityLabel(context, task, account?.id),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (changeable)
                        const Icon(Icons.arrow_drop_down_rounded, size: 18),
                    ],
                  ),
                ),
                onPressed: !changeable
                    ? null
                    : () async {
                        final selected = await showModalBottomSheet<int>(
                          context: context,
                          showDragHandle: true,
                          isScrollControlled: true,
                          builder: (context) => SafeArea(
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                maxHeight:
                                    MediaQuery.sizeOf(context).height * .7,
                              ),
                              child: ListView(
                                shrinkWrap: true,
                                children: [
                                  ListTile(
                                    title: Text(context.l10n.assignmentChoose),
                                  ),
                                  ListTile(
                                    leading: const Icon(Icons.groups_outlined),
                                    title: Text(context.l10n.assignedToGroup),
                                    subtitle: Text(
                                      context.l10n.assignmentGroupHelp,
                                    ),
                                    selected: task.assignment == 'group',
                                    onTap: () => Navigator.pop(context, 0),
                                  ),
                                  for (final person in project!.people.where(
                                    (p) => p.canEdit,
                                  ))
                                    ListTile(
                                      leading: const Icon(Icons.person_outline),
                                      title: Text(
                                        person.id == account?.id
                                            ? '${person.name} · ${context.l10n.assignedToMe}'
                                            : person.name,
                                      ),
                                      selected:
                                          task.assignment == 'member' &&
                                          task.assigneeId == person.id,
                                      onTap: () =>
                                          Navigator.pop(context, person.id),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        );
                        if (selected == null) return;
                        final person = project!.people
                            .where((p) => p.id == selected)
                            .firstOrNull;
                        onChanged!(
                          task.copyWith(
                            assignment: selected == 0 ? 'group' : 'member',
                            assigneeId: person?.id,
                            assigneeName: person?.name,
                          ),
                        );
                      },
              ),
          ],
        ),
        if (!compact || shared)
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 8),
            child: Text(
              shared
                  ? context.l10n.audienceShared(
                      project!.groupName ?? project.name,
                    )
                  : context.l10n.audiencePersonal,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        if (needsReview) ...[
          if (names.isNotEmpty)
            Text(
              context.l10n.assignmentHeard(names),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            children: [
              Text(context.l10n.assignmentIsRight),
              TextButton(
                onPressed: valid && onChanged != null ? onReviewed : null,
                child: Text(context.l10n.yes),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
