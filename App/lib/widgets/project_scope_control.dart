import 'dart:math' as math;

import 'package:agenda/models/task_list_info.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:agenda/l10n/region.dart';
import 'package:agenda/services/text_search.dart';
import 'package:agenda/providers/auth_provider.dart';
import 'package:agenda/providers/project_scope_provider.dart';
import 'package:agenda/providers/task_lists_provider.dart';
import 'package:agenda/widgets/task_list_picker.dart';

/// The people a shared project's page can filter by, besides the account
/// itself (that is `Para mí`): the others who can be given tasks. None
/// unless the project is shared with 2 or more people.
List<ProjectMember> projectPeopleToFilter(TaskListInfo? project, int? me) =>
    project == null || !project.shared || project.people.length < 2
    ? const []
    : project.people.where((p) => p.id != me && p.canEdit).toList();

class ProjectScopeControl extends ConsumerWidget {
  const ProjectScopeControl({
    super.key,
    this.fixedProjectId,
    this.padding = EdgeInsets.zero,
    this.team,
    this.onTeamChanged,
    this.person,
    this.onPeopleChanged,
  });
  final String? fixedProjectId;

  /// A page's own `Para mí` / `Todas` choice, kept apart from Calendar's.
  /// Without it, the chips change the app-wide scope.
  final bool? team;
  final ValueChanged<bool>? onTeamChanged;

  /// A shared project page's person: their tasks only. With
  /// [onPeopleChanged], a project shared with 2 or more people shows one row
  /// of chips, `Todas · Para mí · Ana · Paul…`, in place of `Para mí` and
  /// `Todas`. It gets the page's `Todas`/`Para mí` choice ([team]) and the
  /// person (null for none).
  final int? person;
  final void Function(bool team, int? person)? onPeopleChanged;

  /// Applied only when the control draws something, so an empty one takes
  /// no room.
  final EdgeInsetsGeometry padding;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scope = ref.watch(projectScopeProvider);
    final projects = ref.watch(taskListsProvider).valueOrNull ?? [];
    final selectedId = fixedProjectId ?? scope.projectId;
    final team = this.team ?? scope.team;
    void setTeam(bool value) => onTeamChanged != null
        ? onTeamChanged!(value)
        : ref.read(projectScopeProvider.notifier).state = ProjectScope(
            projectId: scope.projectId,
            team: value,
          );
    final selected = projects.where((p) => p.id == selectedId).firstOrNull;
    final shared =
        selected?.shared ?? projects.any((p) => p.shared && !p.inactive);
    final people = fixedProjectId == null || onPeopleChanged == null
        ? const <ProjectMember>[]
        : projectPeopleToFilter(
            selected,
            ref.watch(authProvider.select((s) => s.account?.id)),
          );
    if (people.isNotEmpty) {
      return Padding(
        padding: padding,
        child: _PeopleFilter(
          people: people,
          team: team,
          person: people.any((p) => p.id == person) ? person : null,
          onChanged: onPeopleChanged!,
        ),
      );
    }
    // A scope chip means nothing until there is a project to scope to.
    final showScope =
        fixedProjectId == null && (projects.isNotEmpty || selectedId != null);
    if (!showScope && !shared) return const SizedBox.shrink();
    return Padding(
      padding: padding,
      child: Wrap(
        spacing: 8,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          if (showScope)
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
                  useSafeArea: true,
                  showDragHandle: true,
                  builder: (context) => StatefulBuilder(
                    // Above the keyboard, in the room it leaves, so the
                    // search and the first match show while typing.
                    builder: (context, change) => Padding(
                      padding: EdgeInsets.only(
                        bottom: MediaQuery.viewInsetsOf(context).bottom,
                      ),
                      child: SafeArea(
                        child: LayoutBuilder(
                          builder: (context, space) => SizedBox(
                            height: math.min(
                              MediaQuery.sizeOf(context).height * .7,
                              space.maxHeight,
                            ),
                            child: Column(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                  ),
                                  child: TextField(
                                    decoration: InputDecoration(
                                      hintText: context.l10n.projectsFind,
                                      prefixIcon: const Icon(Icons.search),
                                    ),
                                    onChanged: (s) =>
                                        change(() => query = s.trim()),
                                  ),
                                ),
                                Expanded(
                                  child: ListView(
                                    // Rows scroll together, so a match
                                    // shows first in the room left.
                                    children: [
                                      if (matchesSearch(
                                        context.l10n.projectsAll,
                                        query,
                                      ))
                                        ListTile(
                                          leading: const Icon(
                                            Icons.calendar_month_outlined,
                                          ),
                                          title: Text(context.l10n.projectsAll),
                                          selected: selectedId == null,
                                          onTap: () =>
                                              Navigator.pop(context, ''),
                                        ),
                                      ..._projectChoices(
                                        context,
                                        projects,
                                        query,
                                        selectedId,
                                      ),
                                      ListTile(
                                        leading: const Icon(Icons.tune),
                                        title: Text(
                                          context.l10n.projectsManage,
                                        ),
                                        onTap: () =>
                                            Navigator.pop(context, 'manage'),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
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
              selected: !team,
              onSelected: (_) => setTeam(false),
            ),
            ChoiceChip(
              label: Text(context.l10n.forTeam),
              selected: team,
              onSelected: (_) => setTeam(true),
            ),
          ],
        ],
      ),
    );
  }
}

/// One row of chips on a shared project's page: everyone's tasks, the
/// account's own, then each other person's. It scrolls sideways when the
/// names don't fit, so it never pushes the tasks down.
class _PeopleFilter extends StatelessWidget {
  const _PeopleFilter({
    required this.people,
    required this.team,
    required this.person,
    required this.onChanged,
  });
  final List<ProjectMember> people;
  final bool team;
  final int? person;
  final void Function(bool team, int? person) onChanged;

  @override
  Widget build(BuildContext context) {
    final chips = [
      ChoiceChip(
        key: const ValueKey('people-all'),
        label: Text(context.l10n.forTeam),
        selected: team && person == null,
        onSelected: (_) => onChanged(true, null),
      ),
      ChoiceChip(
        key: const ValueKey('people-me'),
        label: Text(context.l10n.forMe),
        selected: !team && person == null,
        onSelected: (_) => onChanged(false, null),
      ),
      for (final member in people)
        ChoiceChip(
          key: ValueKey('people-${member.id}'),
          label: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 160),
            child: Text(
              member.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          selected: person == member.id,
          onSelected: (_) => onChanged(true, member.id),
        ),
    ];
    return SingleChildScrollView(
      key: const ValueKey('people-filter'),
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var i = 0; i < chips.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            chips[i],
          ],
        ],
      ),
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
            matchesSearch('${p.name} ${p.groupName ?? ''}', query),
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
    // While searching, matches come first, without section titles.
    if (query.isEmpty) {
      yield Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
        child: Text(
          names[section]!,
          style: Theme.of(context).textTheme.labelLarge,
        ),
      );
    }
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
        subtitle:
            (project.pinned || query.isNotEmpty) && project.groupName != null
            ? Text(project.groupName!)
            : null,
        selected: project.id == selectedId,
        onTap: () => Navigator.pop(context, project.id),
      );
    }
  }
}
