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
import 'package:agenda/widgets/invitation_cards.dart';
import 'package:agenda/widgets/task_list_picker.dart';

class TaskListsScreen extends ConsumerStatefulWidget {
  const TaskListsScreen({super.key});
  @override
  ConsumerState<TaskListsScreen> createState() => _TaskListsScreenState();
}

class _TaskListsScreenState extends ConsumerState<TaskListsScreen> {
  String _query = '';

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

  Future<void> _edit(
    BuildContext context,
    WidgetRef ref, [
    TaskListInfo? list,
  ]) => editTaskList(context, ref, list: list);

  Future<void> _archive(
    BuildContext context,
    WidgetRef ref,
    TaskListInfo list,
  ) async {
    final store = ref.read(taskListStoreProvider);
    final tasks = ref.read(taskProvider.notifier);
    try {
      await store.update(list.copyWith(archived: !list.archived));
      if (context.mounted) {
        ref.invalidate(taskListsProvider);
        tasks.loadTasks();
        final messenger = ScaffoldMessenger.of(context);
        final strings = context.l10n;
        showFeedback(
          messenger,
          list.archived
              ? strings.listRestored
              : strings.projectArchivedNoReminders(list.name),
          actionLabel: list.archived ? null : strings.undo,
          onAction: () async {
            try {
              await store.update(list);
            } catch (_) {
              showFeedback(messenger, strings.listUpdateError);
              return;
            }
            if (mounted) ref.invalidate(taskListsProvider);
            // Loading the tasks again reschedules the project's reminders.
            await tasks.loadTasks();
          },
        );
      }
    } catch (_) {
      if (context.mounted) {
        showFeedback(
          ScaffoldMessenger.of(context),
          context.l10n.listUpdateError,
        );
      }
    }
  }

  Future<void> _delete(TaskListInfo list) async {
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
        !mounted) {
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    final strings = context.l10n;
    try {
      await ref
          .read(apiClientProvider)
          .request(
            'DELETE',
            'lists/${list.id}/',
            data: {'version': list.version},
            accountId: account.id,
          );
      if (!mounted) return;
      await ref.read(taskProvider.notifier).loadTasks();
      if (!mounted) return;
      ref.invalidate(taskListsProvider);
      showFeedback(messenger, strings.projectDeleted);
    } catch (error) {
      showFeedback(messenger, requestProblemText(strings, error));
    }
  }

  Future<void> _resolve(
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

  Future<void> _pin(TaskListInfo list) async {
    try {
      await ref
          .read(taskListStoreProvider)
          .preferences(list.id, pinned: !list.pinned);
      ref.invalidate(taskListsProvider);
      await ref.read(taskProvider.notifier).loadTasks();
    } catch (_) {
      if (mounted) {
        showFeedback(
          ScaffoldMessenger.of(context),
          context.l10n.listUpdateError,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(groupsProvider);
    return Scaffold(
      appBar: CustomAppBar(title: context.l10n.lists),
      body: ref
          .watch(taskListsProvider)
          // Refreshing keeps the list on screen; the spinner shows only
          // while there's nothing to show yet.
          .when(
            skipLoadingOnReload: true,
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, __) => Center(
              child: TextButton(
                onPressed: () => ref.invalidate(taskListsProvider),
                child: Text(context.l10n.retryLists),
              ),
            ),
            data: (lists) {
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
                    const SizedBox(height: 12),
                    // Worth searching only once there are many projects.
                    if (lists.length >= 8 || _query.isNotEmpty) ...[
                      TextField(
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
              list.groupName == null
                  ? context.l10n.projectSharedRole(context.listRole(list.role))
                  : '${list.groupName} · ${context.listRole(list.role)}',
              if (list.archived) context.l10n.archived,
            ].join(' · ')
          : list.conflict != null
          ? context.l10n.listConflict
          : list.archived
          ? context.l10n.archivedListHelp
          : context.l10n.listItemCount(
              (ref.watch(taskProvider).valueOrNull ?? [])
                  .where((task) => task.listId == list.id && !task.isCompleted)
                  .length,
            ),
    ),
    onTap: () => list.conflict != null
        ? _resolve(context, ref, list)
        : Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (_) => HomeScreen(isRoot: false, listId: list.id),
            ),
          ),
    trailing: PopupMenuButton<String>(
      tooltip: context.l10n.manageItem(list.name),
      itemBuilder: (_) => [
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
              list.archived
                  ? context.l10n.restoreList
                  : context.l10n.archiveList,
            ),
          ),
        if (ref.read(authProvider).account != null)
          // Everyone can see the members and leave here;
          // only those who can invite are told “Share”.
          PopupMenuItem(
            value: 'sharing',
            child: Text(
              list.canManage ? context.l10n.shareProject : context.l10n.people,
            ),
          ),
        if (list.conflict != null && list.canManage)
          PopupMenuItem(
            value: 'resolve',
            child: Text(context.l10n.chooseDetails),
          ),
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
      ],
      onSelected: (action) => switch (action) {
        'pin' => _pin(list),
        'notifications' => showProjectPreferences(context, ref, list),
        'edit' => _edit(context, ref, list),
        'resolve' => _resolve(context, ref, list),
        'delete' => _delete(list),
        'sharing' => Navigator.push(
          context,
          MaterialPageRoute<void>(
            builder: (_) => list.groupId == null
                ? ListSharingScreen(listId: list.id)
                : GroupScreen(groupId: list.groupId!),
          ),
        ),
        _ => _archive(context, ref, list),
      },
    ),
  );
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
  final groups = (ref.read(groupsProvider).valueOrNull ?? <TaskGroupInfo>[])
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
            child: Text(context.l10n.saveList),
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
