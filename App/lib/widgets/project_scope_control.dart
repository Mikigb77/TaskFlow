import 'package:agenda/models/task_list_info.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:agenda/l10n/region.dart';
import 'package:agenda/providers/project_scope_provider.dart';
import 'package:agenda/providers/task_lists_provider.dart';
import 'package:agenda/widgets/task_list_picker.dart';

class ProjectScopeControl extends ConsumerWidget {
  const ProjectScopeControl({super.key, this.fixedProjectId});
  final String? fixedProjectId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scope = ref.watch(projectScopeProvider);
    final projects = ref.watch(taskListsProvider).valueOrNull ?? [];
    final selectedId = fixedProjectId ?? scope.projectId;
    final selected = projects.where((p) => p.id == selectedId).firstOrNull;
    final shared =
        selected?.shared ?? projects.any((p) => p.shared && !p.inactive);
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (fixedProjectId == null)
          ActionChip(
            avatar: Icon(
              Icons.folder_outlined,
              size: 18,
              color: selected == null ? null : taskListColor(selected.color),
            ),
            label: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 200),
              child: Text(
                selected?.name ??
                    (selectedId == null
                        ? context.l10n.projectsAll
                        : context.l10n.listUnavailable),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            onPressed: () async {
              var query = '';
              final choice = await showModalBottomSheet<String>(
                context: context,
                isScrollControlled: true,
                showDragHandle: true,
                builder: (context) => StatefulBuilder(
                  builder: (context, change) => SafeArea(
                    child: SizedBox(
                      height: MediaQuery.sizeOf(context).height * .7,
                      child: Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: TextField(
                              decoration: InputDecoration(
                                hintText: context.l10n.projectsFind,
                                prefixIcon: const Icon(Icons.search),
                              ),
                              onChanged: (s) =>
                                  change(() => query = s.trim().toLowerCase()),
                            ),
                          ),
                          Expanded(
                            child: ListView(
                              children: [
                                ListTile(
                                  leading: const Icon(
                                    Icons.calendar_month_outlined,
                                  ),
                                  title: Text(context.l10n.projectsAll),
                                  selected: selectedId == null,
                                  onTap: () => Navigator.pop(context, ''),
                                ),
                                ..._projectChoices(
                                  context,
                                  projects,
                                  query,
                                  selectedId,
                                ),
                              ],
                            ),
                          ),
                          ListTile(
                            leading: const Icon(Icons.tune),
                            title: Text(context.l10n.projectsManage),
                            onTap: () => Navigator.pop(context, 'manage'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
              if (choice == null || !context.mounted) return;
              if (choice == 'manage') {
                Navigator.pushNamed(context, '/lists');
                return;
              }
              ref.read(projectScopeProvider.notifier).state = ProjectScope(
                projectId: choice.isEmpty ? null : choice,
                team: scope.team,
              );
            },
          ),
        if (shared) ...[
          ChoiceChip(
            label: Text(context.l10n.forMe),
            selected: !scope.team,
            onSelected: (_) => ref.read(projectScopeProvider.notifier).state =
                ProjectScope(projectId: scope.projectId),
          ),
          ChoiceChip(
            label: Text(context.l10n.forTeam),
            selected: scope.team,
            onSelected: (_) => ref.read(projectScopeProvider.notifier).state =
                ProjectScope(projectId: scope.projectId, team: true),
          ),
        ],
      ],
    );
  }
}

Iterable<Widget> _projectChoices(
  BuildContext context,
  List<TaskListInfo> projects,
  String query,
  String? selectedId,
) sync* {
  final matching = projects
      .where(
        (p) =>
            !p.inactive &&
            '${p.name} ${p.groupName ?? ''}'.toLowerCase().contains(query),
      )
      .toList();
  if (matching.isEmpty && query.isNotEmpty) {
    yield ListTile(title: Text(context.l10n.projectsNoneFound));
    return;
  }
  final sections = <String, List<TaskListInfo>>{};
  final names = <String, String>{
    'pinned': context.l10n.projectsPinned,
    'personal': context.l10n.projectsPersonal,
    'shared': context.l10n.projectsShared,
  };
  for (final p in matching) {
    final section = p.pinned
        ? 'pinned'
        : !p.shared
        ? 'personal'
        : p.groupId ?? 'shared';
    sections.putIfAbsent(section, () => []).add(p);
    if (p.groupId != null) {
      names[p.groupId!] = p.groupName ?? context.l10n.groups;
    }
  }
  final keys = sections.keys.toList()
    ..sort((a, b) {
      int rank(String key) => key == 'pinned'
          ? 0
          : key == 'personal'
          ? 1
          : 2;
      final order = rank(a).compareTo(rank(b));
      return order != 0 ? order : (names[a] ?? a).compareTo(names[b] ?? b);
    });
  for (final section in keys) {
    yield Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
      child: Text(
        names[section]!,
        style: Theme.of(context).textTheme.labelLarge,
      ),
    );
    for (final project in sections[section]!) {
      yield ListTile(
        leading: Icon(
          project.pinned
              ? Icons.push_pin_outlined
              : project.shared
              ? Icons.groups_outlined
              : Icons.folder_outlined,
          color: taskListColor(project.color),
        ),
        title: Text(project.name),
        subtitle: project.pinned && project.groupName != null
            ? Text(project.groupName!)
            : null,
        selected: project.id == selectedId,
        onTap: () => Navigator.pop(context, project.id),
      );
    }
  }
}
