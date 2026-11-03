import 'dart:async';

import 'package:flutter/material.dart';
import 'package:agenda/l10n/region.dart';
import 'package:agenda/services/text_search.dart';
import 'package:agenda/models/task_group.dart';
import 'package:agenda/providers/groups_provider.dart';
import 'package:agenda/providers/invitations_provider.dart';
import 'package:agenda/screens/groups_screen.dart';
import 'package:agenda/widgets/project_preferences.dart';
import 'package:agenda/screens/list_sharing_screen.dart';
import 'package:agenda/providers/auth_provider.dart';
import 'package:agenda/l10n/request_locale.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:agenda/models/task_list_info.dart';
import 'package:agenda/providers/task_lists_provider.dart';
import 'package:agenda/providers/task_provider.dart';
import 'package:agenda/screens/home_screen.dart';
import 'package:agenda/widgets/custom_app_bar.dart';
import 'package:agenda/widgets/app_components.dart';
import 'package:agenda/widgets/search_clear.dart';
import 'package:agenda/widgets/invitation_cards.dart';
import 'package:agenda/widgets/task_list_picker.dart';

class TaskListsScreen extends ConsumerStatefulWidget {
  const TaskListsScreen({super.key});
  @override
  ConsumerState<TaskListsScreen> createState() => _TaskListsScreenState();
}

class _TaskListsScreenState extends ConsumerState<TaskListsScreen> {
  String _query = '';

  /// Projects whose DELETE is on its way (their row shows a spinner), and
  /// those the server deleted, gone from the list before the sync catches up.
  final _deleting = <String>{};
  final _deleted = <String>{};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_refresh());
    });
  }

  Future<void> _refresh() async {
    ref.invalidate(pendingInvitationsProvider);
    await ref.read(taskProvider.notifier).loadTasks();
    if (mounted) ref.invalidate(taskListsProvider);
  }

  Future<void> _delete(TaskListInfo list) async {
    final messenger = ScaffoldMessenger.of(context);
    final strings = context.l10n;
    final gone = await deleteProject(
      context,
      ref,
      list,
      onSending: () => setState(() => _deleting.add(list.id)),
    );
    if (!mounted) return;
    // The row goes now; the sync takes the project's tasks off this phone
    // behind it.
    setState(() {
      _deleting.remove(list.id);
      if (gone) _deleted.add(list.id);
    });
    if (!gone) return;
    showFeedback(messenger, strings.projectDeleted);
    unawaited(_refresh());
  }

  @override
  Widget build(BuildContext context) {
    final groupsMatter =
        ref.watch(groupsProvider).value?.isNotEmpty == true ||
        ref
                .watch(pendingInvitationsProvider)
                .value
                ?.any((invitation) => invitation.group) ==
            true;
    return Scaffold(
      appBar: CustomAppBar(title: context.l10n.lists),
      body: ref
          .watch(taskListsProvider)
          // Refreshing keeps the list on screen; the spinner shows only
          // while there's nothing to show yet.
          .when(
            skipLoadingOnReload: true,
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, _) => Center(
              child: TextButton(
                onPressed: () => ref.invalidate(taskListsProvider),
                child: Text(context.l10n.retryLists),
              ),
            ),
            data: (all) {
              final lists = all.where((p) => !_deleted.contains(p.id)).toList();
              final shown = lists
                  .where(
                    (p) =>
                        matchesSearch('${p.name} ${p.groupName ?? ''}', _query),
                  )
                  .toList();
              return RefreshIndicator(
                onRefresh: _refresh,
                child: ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    // Worth searching only once there are many projects.
                    if (lists.length >= 8 || _query.isNotEmpty) ...[
                      SearchField(
                        decoration: InputDecoration(
                          hintText: context.l10n.projectsFind,
                          prefixIcon: const Icon(Icons.search),
                        ),
                        onChanged: (value) =>
                            setState(() => _query = value.trim()),
                      ),
                      const SizedBox(height: 12),
                    ],
                    const PendingInvitations(),
                    if (lists.isEmpty)
                      EmptyState(
                        title: context.l10n.listsEmptyTitle,
                        message: context.l10n.listsEmptyHelp,
                        icon: Icons.folder_outlined,
                      )
                    else if (shown.isEmpty)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(context.l10n.projectsNoneFound),
                      ),
                    for (final list in shown) ...[
                      _projectRow(context, list),
                      const Divider(),
                    ],
                    // Groups come after the projects they hold, once the
                    // account shares something or is asked to join a group.
                    if (groupsMatter ||
                        lists.any((p) => p.shared || p.groupId != null)) ...[
                      const SizedBox(height: 12),
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: TextButton.icon(
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute<void>(
                              builder: (_) => const GroupsScreen(),
                            ),
                          ),
                          icon: const Icon(Icons.groups_outlined),
                          label: Text(context.l10n.groups),
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: FilledButton.icon(
            key: const ValueKey('new-list'),
            onPressed: () => createProject(context, ref),
            icon: const Icon(Icons.add_rounded),
            label: Text(context.l10n.newList),
          ),
        ),
      ),
    );
  }

  /// What's open in [list]: «3 tareas y notas».
  String _itemCount(BuildContext context, TaskListInfo list) =>
      context.l10n.listItemCount(
        (ref.watch(taskProvider).value ?? [])
            .where((task) => task.listId == list.id && !task.isCompleted)
            .length,
      );

  /// A shared project's detail: its count for the owner, a member's role.
  String _sharedDetail(BuildContext context, TaskListInfo list) =>
      list.role == 'owner'
      ? _itemCount(context, list)
      : context.listRole(list.role);

  Widget _projectRow(BuildContext context, TaskListInfo list) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: Icon(
      list.archived
          ? Icons.inventory_2_outlined
          : list.shared
          ? Icons.group_outlined
          : Icons.folder_outlined,
      color: taskListColor(list.color),
    ),
    title: Row(
      children: [
        if (list.pinned) ...[
          Icon(
            Icons.push_pin_outlined,
            size: 18,
            semanticLabel: context.l10n.projectPinned,
          ),
          const SizedBox(width: 6),
        ],
        Flexible(child: Text(list.name)),
      ],
    ),
    subtitle: Text(
      list.shared
          ? [
              // A group project names its group; a direct share says so.
              // The owner reads how much is in it; members, their role.
              list.groupName == null
                  ? context.l10n.projectSharedRole(_sharedDetail(context, list))
                  : '${list.groupName} · ${_sharedDetail(context, list)}',
              if (list.archived) context.l10n.archived,
            ].join(' · ')
          : list.conflict != null
          ? context.l10n.listConflict
          : list.archived
          ? context.l10n.archivedListHelp
          : _itemCount(context, list),
    ),
    onTap: _deleting.contains(list.id)
        ? null
        : () async {
            if (list.conflict != null) {
              return resolveProject(context, ref, list);
            }
            final gone = await Navigator.push(
              context,
              MaterialPageRoute<bool>(
                builder: (_) => HomeScreen(isRoot: false, listId: list.id),
              ),
            );
            // Deleted from its page: the row goes before the sync catches up.
            if (gone == true && mounted) setState(() => _deleted.add(list.id));
          },
    trailing: _deleting.contains(list.id)
        ? const ProjectDeleting()
        : PopupMenuButton<String>(
            tooltip: context.l10n.manageItem(list.name),
            itemBuilder: (_) => projectMenuItems(context, ref, list),
            onSelected: (action) => runProjectAction(
              context,
              ref,
              list,
              action,
              delete: () => _delete(list),
            ),
          ),
  );
}

/// In place of a project's ⋮ while its DELETE is on its way.
class ProjectDeleting extends StatelessWidget {
  const ProjectDeleting({super.key});

  @override
  Widget build(BuildContext context) => const SizedBox.square(
    dimension: 48,
    child: Center(
      child: SizedBox.square(
        dimension: 24,
        child: CircularProgressIndicator(strokeWidth: 2.5),
      ),
    ),
  );
}

/// What ⋮ offers for [list], on Proyectos and on the project's own page, so
/// the two can't drift. Without [people], the item that opens its members
/// or its group goes: the project page has its own button for that. Without
/// [pin], pinning goes: it only reorders Proyectos, so the page shows
/// nothing happen.
List<PopupMenuEntry<String>> projectMenuItems(
  BuildContext context,
  WidgetRef ref,
  TaskListInfo list, {
  bool people = true,
  bool pin = true,
}) => [
  if (pin)
    PopupMenuItem(
      value: 'pin',
      child: Text(
        list.pinned ? context.l10n.unpinProject : context.l10n.pinProject,
      ),
    ),
  if (list.shared)
    PopupMenuItem(
      value: 'notifications',
      child: Text(context.l10n.projectNotifications),
    ),
  if (list.canManage)
    PopupMenuItem(value: 'edit', child: Text(context.l10n.editList)),
  if (list.canManage)
    PopupMenuItem(
      value: 'archive',
      child: Text(
        list.archived ? context.l10n.restoreList : context.l10n.archiveList,
      ),
    ),
  if (people && ref.read(authProvider).account != null)
    // Everyone can see the members and leave here. As on the project page,
    // only the owner of an unshared personal project is told “Share”; the
    // page it opens is “Members” in every other case.
    PopupMenuItem(
      value: 'sharing',
      child: Text(
        !list.shared && list.groupId == null && list.role == 'owner'
            ? context.l10n.shareProject
            : context.l10n.people,
      ),
    ),
  if (list.conflict != null && list.canManage)
    PopupMenuItem(value: 'resolve', child: Text(context.l10n.chooseDetails)),
  // The server deletes it, so only a project it knows.
  if (list.groupId == null &&
      list.role == 'owner' &&
      list.version > 0 &&
      ref.read(authProvider).account != null)
    PopupMenuItem(
      value: 'delete',
      child: Text(
        list.shared
            ? context.l10n.deleteListForEveryone
            : context.l10n.deleteList,
        style: TextStyle(color: Theme.of(context).colorScheme.error),
      ),
    ),
];

/// Carries out the [projectMenuItems] [action] chosen for [list]; each place
/// deletes its own way, through [delete]. True when the members or group
/// page it opened says the project is gone for this account.
Future<bool> runProjectAction(
  BuildContext context,
  WidgetRef ref,
  TaskListInfo list,
  String action, {
  required Future<void> Function() delete,
}) async {
  switch (action) {
    case 'pin':
      await pinProject(context, ref, list);
    case 'notifications':
      await showProjectPreferences(context, ref, list);
    case 'edit':
      await editTaskList(context, ref, list: list);
    case 'resolve':
      await resolveProject(context, ref, list);
    case 'delete':
      await delete();
    case 'sharing':
      final gone = await Navigator.push(
        context,
        MaterialPageRoute<bool>(
          builder: (_) => list.groupId == null
              ? ListSharingScreen(listId: list.id)
              : GroupScreen(groupId: list.groupId!),
        ),
      );
      return gone == true;
    default:
      await archiveProject(context, ref, list);
  }
  return false;
}

/// Pins [list] to the top of the project lists, or unpins it.
Future<void> pinProject(
  BuildContext context,
  WidgetRef ref,
  TaskListInfo list,
) async {
  try {
    await ref
        .read(taskListStoreProvider)
        .preferences(list.id, pinned: !list.pinned);
    ref.invalidate(taskListsProvider);
    await ref.read(taskProvider.notifier).loadTasks();
  } catch (_) {
    if (context.mounted) {
      showFeedback(ScaffoldMessenger.of(context), context.l10n.listUpdateError);
    }
  }
}

/// Archives [list], with Deshacer, or restores an archived one.
Future<void> archiveProject(
  BuildContext context,
  WidgetRef ref,
  TaskListInfo list,
) async {
  if (list.archived) return restoreProject(context, ref, list);
  final store = ref.read(taskListStoreProvider);
  final tasks = ref.read(taskProvider.notifier);
  // Deshacer can come after the page that archived it has closed.
  final container = ProviderScope.containerOf(context, listen: false);
  try {
    await store.update(list.copyWith(archived: true));
    if (context.mounted) {
      ref.invalidate(taskListsProvider);
      tasks.loadTasks();
      final messenger = ScaffoldMessenger.of(context);
      final strings = context.l10n;
      showFeedback(
        messenger,
        strings.projectArchivedNoReminders(list.name),
        actionLabel: strings.undo,
        onAction: () async {
          try {
            await store.update(list);
          } catch (_) {
            showFeedback(messenger, strings.listUpdateError);
            return;
          }
          container.invalidate(taskListsProvider);
          // Loading the tasks again reschedules the project's reminders.
          await tasks.loadTasks();
        },
      );
    }
  } catch (_) {
    if (context.mounted) {
      showFeedback(ScaffoldMessenger.of(context), context.l10n.listUpdateError);
    }
  }
}

/// Asks, then deletes [list] on the server; [onSending] runs once the person
/// has confirmed. True once it's gone; a failure says why.
Future<bool> deleteProject(
  BuildContext context,
  WidgetRef ref,
  TaskListInfo list, {
  required VoidCallback onSending,
}) async {
  final account = ref.read(authProvider).account;
  if (account == null ||
      !await groupConfirm(
        context,
        context.l10n.deleteList,
        list.shared
            ? context.l10n.deleteListHelp
            : context.l10n.deleteListPrivateHelp(list.name),
        destructive: true,
      ) ||
      !context.mounted) {
    return false;
  }
  final messenger = ScaffoldMessenger.of(context);
  final strings = context.l10n;
  final api = ref.read(apiClientProvider);
  onSending();
  try {
    await api.request(
      'DELETE',
      'lists/${list.id}/',
      data: {'version': list.version},
      accountId: account.id,
    );
    return true;
  } catch (error) {
    showFeedback(messenger, requestProblemText(strings, error));
    return false;
  }
}

/// Asks which details of [list] to keep when this phone and another device
/// changed it apart.
Future<void> resolveProject(
  BuildContext context,
  WidgetRef ref,
  TaskListInfo list,
) async {
  final store = ref.read(taskListStoreProvider);
  final remote = TaskListInfo.fromApi(list.conflict!);
  final local = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      scrollable: true,
      title: Text(context.l10n.chooseListDetails),
      content: Text(
        context.l10n.listConflictHelp(
          '${list.name} · ${context.listColorName(list.color)}${list.archived ? ' · ${context.l10n.archived}' : ''}',
          '${remote.name} · ${context.listColorName(remote.color)}${remote.archived ? ' · ${context.l10n.archived}' : ''}',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(context.l10n.later),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(context.l10n.useOtherDevice),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(context.l10n.useThisPhone),
        ),
      ],
    ),
  );
  if (local == null || !context.mounted) return;
  try {
    await store.resolve(list.id, keepLocal: local);
    if (context.mounted) {
      ref.invalidate(taskListsProvider);
      ref.read(taskProvider.notifier).loadTasks();
    }
  } catch (_) {
    if (context.mounted) {
      showFeedback(
        ScaffoldMessenger.of(context),
        context.l10n.listResolveError,
      );
    }
  }
}

/// Restores the archived [list], as Proyectos ⋮ does, and says so. Loading
/// the tasks again reschedules the project's reminders.
Future<void> restoreProject(
  BuildContext context,
  WidgetRef ref,
  TaskListInfo list,
) async {
  try {
    await ref
        .read(taskListStoreProvider)
        .update(list.copyWith(archived: false));
    if (!context.mounted) return;
    ref.invalidate(taskListsProvider);
    ref.read(taskProvider.notifier).loadTasks();
    showFeedback(ScaffoldMessenger.of(context), context.l10n.listRestored);
  } catch (_) {
    if (context.mounted) {
      showFeedback(ScaffoldMessenger.of(context), context.l10n.listUpdateError);
    }
  }
}

/// Asks for a new project's name, then opens the saved project's page, whose
/// empty state says what to do next. [groupId] puts it in that group.
Future<void> createProject(
  BuildContext context,
  WidgetRef ref, {
  String? groupId,
}) async {
  final saved = await editTaskList(context, ref, groupId: groupId);
  if (saved == null || !context.mounted) return;
  await Navigator.push(
    context,
    MaterialPageRoute<void>(
      builder: (_) => HomeScreen(isRoot: false, listId: saved.id),
    ),
  );
}

/// Opens the project name dialog. Returns the project once it's saved.
Future<TaskListInfo?> editTaskList(
  BuildContext context,
  WidgetRef ref, {
  TaskListInfo? list,
  String? groupId,
}) async {
  final store = ref.read(taskListStoreProvider);
  var name = list?.name ?? '';
  var color = list?.color ?? 'teal';
  final groups = (ref.read(groupsProvider).value ?? <TaskGroupInfo>[])
      .where((g) => g.canManage && !g.archived)
      .toList();
  var group = groups.where((g) => g.id == groupId).firstOrNull;
  if (list == null && groupId != null && group == null) {
    showFeedback(ScaffoldMessenger.of(context), context.l10n.groupActionError);
    return null;
  }
  final form = GlobalKey<FormState>();
  final accepted = await showDialog<bool>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        scrollable: true,
        title: Text(
          list == null ? context.l10n.newList : context.l10n.editList,
        ),
        content: Form(
          key: form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                key: const ValueKey('list-name'),
                initialValue: name,
                maxLength: 80,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: context.l10n.listName,
                  hintText: context.l10n.listNameHint,
                  counterText: '',
                  errorMaxLines: 3,
                ),
                onChanged: (value) => name = value,
                validator: (value) => value?.trim().isNotEmpty == true
                    ? null
                    : context.l10n.listNameRequired,
              ),
              if (list == null && groupId == null && groups.isNotEmpty)
                DropdownButtonFormField<String>(
                  initialValue: '',
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: context.l10n.projectDestination,
                  ),
                  items: [
                    DropdownMenuItem(
                      value: '',
                      child: Text(context.l10n.projectsPersonal),
                    ),
                    for (final choice in groups)
                      DropdownMenuItem(
                        value: choice.id,
                        child: Text(
                          choice.name,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (id) => setState(
                    () => group = groups.where((g) => g.id == id).firstOrNull,
                  ),
                ),
              if (list == null && groupId == null && group != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(context.l10n.projectGroupSees(group!.name)),
                  ),
                ),
              // New projects start teal; the colour changes in Edit project.
              if (list != null) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final choice in [
                      'teal',
                      'blue',
                      'violet',
                      'amber',
                      'rose',
                    ])
                      ChoiceChip(
                        label: Text(context.listColorName(choice)),
                        avatar: Icon(
                          Icons.circle,
                          size: 14,
                          color: taskListColor(choice),
                        ),
                        selected: color == choice,
                        onSelected: (_) => setState(() => color = choice),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.cancel),
          ),
          FilledButton(
            onPressed: () {
              if (form.currentState!.validate()) {
                Navigator.pop(context, true);
              }
            },
            child: Text(
              list == null ? context.l10n.createList : context.l10n.saveList,
            ),
          ),
        ],
      ),
    ),
  );
  if (accepted != true || !context.mounted) return null;
  try {
    final saved = list == null
        ? TaskListInfo(
            name: name.trim(),
            color: color,
            groupId: group?.id,
            groupName: group?.name,
            ownerId: group?.ownerId,
            shared: group != null,
            role: group?.role ?? 'owner',
            people: group?.people ?? [],
          )
        : list.copyWith(name: name.trim(), color: color);
    if (list == null) {
      await store.create(saved);
    } else {
      await store.update(saved);
    }
    if (context.mounted) {
      ref.invalidate(taskListsProvider);
      ref.read(taskProvider.notifier).loadTasks();
    }
    return saved;
  } catch (_) {
    if (context.mounted) {
      showFeedback(ScaffoldMessenger.of(context), context.l10n.listSaveError);
    }
    return null;
  }
}
