import 'package:flutter/material.dart';
import 'package:agenda/l10n/region.dart';
import 'package:agenda/screens/list_sharing_screen.dart';
import 'package:agenda/providers/auth_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:agenda/models/task_list_info.dart';
import 'package:agenda/providers/task_lists_provider.dart';
import 'package:agenda/providers/task_provider.dart';
import 'package:agenda/screens/home_screen.dart';
import 'package:agenda/widgets/custom_app_bar.dart';
import 'package:agenda/widgets/app_components.dart';
import 'package:agenda/widgets/task_list_picker.dart';

class TaskListsScreen extends ConsumerWidget {
  const TaskListsScreen({super.key});

  Future<void> _edit(BuildContext context, WidgetRef ref,
      [TaskListInfo? list]) async {
    final store = ref.read(taskListStoreProvider);
    var name = list?.name ?? '';
    var color = list?.color ?? 'teal';
    final form = GlobalKey<FormState>();
    final accepted = await showDialog<bool>(
        context: context,
        builder: (context) => StatefulBuilder(
            builder: (context, setState) => AlertDialog(
                  scrollable: true,
                  title: Text(list == null
                      ? context.l10n.newList
                      : context.l10n.editList),
                  content: Form(
                      key: form,
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        TextFormField(
                            key: const ValueKey('list-name'),
                            initialValue: name,
                            maxLength: 80,
                            autofocus: true,
                            decoration: InputDecoration(
                                labelText: context.l10n.listName,
                                hintText: context.l10n.listNameHint,
                                errorMaxLines: 3),
                            onChanged: (value) => name = value,
                            validator: (value) =>
                                value?.trim().isNotEmpty == true
                                    ? null
                                    : context.l10n.listNameRequired),
                        Wrap(spacing: 8, children: [
                          for (final choice in [
                            'teal',
                            'blue',
                            'violet',
                            'amber',
                            'rose'
                          ])
                            ChoiceChip(
                                label: Text(context.listColorName(choice)),
                                avatar: Icon(Icons.circle,
                                    size: 14, color: taskListColor(choice)),
                                selected: color == choice,
                                onSelected: (_) =>
                                    setState(() => color = choice))
                        ]),
                      ])),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: Text(context.l10n.cancel)),
                    FilledButton(
                        onPressed: () {
                          if (form.currentState!.validate()) {
                            Navigator.pop(context, true);
                          }
                        },
                        child: Text(context.l10n.saveList))
                  ],
                )));
    if (accepted != true || !context.mounted) return;
    try {
      if (list == null) {
        await store.create(TaskListInfo(name: name.trim(), color: color));
      } else {
        await store.update(list.copyWith(name: name.trim(), color: color));
      }
      if (context.mounted) {
        ref.invalidate(taskListsProvider);
        ref.read(taskProvider.notifier).loadTasks();
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            behavior: SnackBarBehavior.fixed,
            content: Text(context.l10n.listSaveError)));
      }
    }
  }

  Future<void> _archive(
      BuildContext context, WidgetRef ref, TaskListInfo list) async {
    final store = ref.read(taskListStoreProvider);
    try {
      await store.update(list.copyWith(archived: !list.archived));
      if (context.mounted) {
        ref.invalidate(taskListsProvider);
        ref.read(taskProvider.notifier).loadTasks();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            behavior: SnackBarBehavior.fixed,
            content: Text(list.archived
                ? context.l10n.listRestored
                : context.l10n.listArchivedHelp)));
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            behavior: SnackBarBehavior.fixed,
            content: Text(context.l10n.listUpdateError)));
      }
    }
  }

  Future<void> _resolve(
      BuildContext context, WidgetRef ref, TaskListInfo list) async {
    final store = ref.read(taskListStoreProvider);
    final remote = TaskListInfo.fromApi(list.conflict!);
    final local = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
                scrollable: true,
                title: Text(context.l10n.chooseListDetails),
                content: Text(context.l10n.listConflictHelp(
                    '${list.name} · ${context.listColorName(list.color)}${list.archived ? ' · ${context.l10n.archived}' : ''}',
                    '${remote.name} · ${context.listColorName(remote.color)}${remote.archived ? ' · ${context.l10n.archived}' : ''}')),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(context.l10n.later)),
                  TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: Text(context.l10n.useOtherDevice)),
                  FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: Text(context.l10n.useThisPhone))
                ]));
    if (local == null || !context.mounted) return;
    try {
      await store.resolve(list.id, keepLocal: local);
      if (context.mounted) {
        ref.invalidate(taskListsProvider);
        ref.read(taskProvider.notifier).loadTasks();
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            behavior: SnackBarBehavior.fixed,
            content: Text(context.l10n.listResolveError)));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
        appBar: CustomAppBar(title: context.l10n.lists),
        body: ref.watch(taskListsProvider).when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, __) => Center(
                child: TextButton(
                    onPressed: () => ref.invalidate(taskListsProvider),
                    child: Text(context.l10n.retryLists))),
            data: (lists) =>
                ListView(padding: const EdgeInsets.all(24), children: [
                  const ListInvitations(),
                  TextButton.icon(
                      onPressed: () async {
                        ref.invalidate(invitationsProvider);
                        await ref.read(taskProvider.notifier).loadTasks();
                        ref.invalidate(taskListsProvider);
                      },
                      icon: const Icon(Icons.refresh),
                      label: Text(context.l10n.refreshLists)),
                  Text(context.l10n.listsHelp),
                  const SizedBox(height: 20),
                  if (lists.isEmpty)
                    EmptyState(
                        title: context.l10n.listsEmptyTitle,
                        message: context.l10n.listsEmptyHelp),
                  for (final list in lists) ...[
                    ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                            list.archived
                                ? Icons.inventory_2_outlined
                                : list.shared
                                    ? Icons.group_outlined
                                    : Icons.folder_outlined,
                            color: taskListColor(list.color)),
                        title: Text(list.name),
                        subtitle: Text(list.shared
                            ? '${context.l10n.sharedListRole(context.listRole(list.role))}${list.archived ? ' · ${context.l10n.archived}' : ''}'
                            : list.conflict != null
                                ? context.l10n.listConflict
                                : list.archived
                                    ? context.l10n.archivedListHelp
                                    : context.l10n.listItemCount((ref
                                                .watch(taskProvider)
                                                .valueOrNull ??
                                            [])
                                        .where((task) => task.listId == list.id)
                                        .length)),
                        onTap: () => list.conflict != null
                            ? _resolve(context, ref, list)
                            : Navigator.push(
                                context,
                                MaterialPageRoute<void>(
                                    builder: (_) => HomeScreen(
                                        isRoot: false, listId: list.id))),
                        trailing: PopupMenuButton<String>(
                            tooltip: context.l10n.manageItem(list.name),
                            itemBuilder: (_) => [
                                  if (list.canManage)
                                    PopupMenuItem(
                                        value: 'edit',
                                        child: Text(context.l10n.editList)),
                                  if (list.canManage)
                                    PopupMenuItem(
                                        value: 'archive',
                                        child: Text(list.archived
                                            ? context.l10n.restoreList
                                            : context.l10n.archiveList)),
                                  if (ref.read(authProvider).account != null &&
                                      list.version > 0)
                                    PopupMenuItem(
                                        value: 'sharing',
                                        child: Text(
                                            context.l10n.sharingAndPeople)),
                                  if (list.conflict != null && list.canManage)
                                    PopupMenuItem(
                                        value: 'resolve',
                                        child: Text(context.l10n.chooseDetails))
                                ],
                            onSelected: (action) => switch (action) {
                                  'edit' => _edit(context, ref, list),
                                  'resolve' => _resolve(context, ref, list),
                                  'sharing' => Navigator.push(
                                      context,
                                      MaterialPageRoute<void>(
                                          builder: (_) => ListSharingScreen(
                                              listId: list.id))),
                                  _ => _archive(context, ref, list)
                                })),
                    const Divider(),
                  ],
                ])),
        bottomNavigationBar: SafeArea(
            top: false,
            child: Padding(
                padding: const EdgeInsets.all(24),
                child: FilledButton.icon(
                    key: const ValueKey('new-list'),
                    onPressed: () => _edit(context, ref),
                    icon: const Icon(Icons.add_rounded),
                    label: Text(context.l10n.newList)))),
      );
}
