import 'package:flutter/material.dart';
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
                  title: Text(list == null ? 'New list' : 'Edit list'),
                  content: SingleChildScrollView(
                      child: Form(
                          key: form,
                          child:
                              Column(mainAxisSize: MainAxisSize.min, children: [
                            TextFormField(
                                key: const ValueKey('list-name'),
                                initialValue: name,
                                maxLength: 80,
                                autofocus: true,
                                decoration: const InputDecoration(
                                    labelText: 'Name',
                                    hintText: 'Work, Personal, Shopping…'),
                                onChanged: (value) => name = value,
                                validator: (value) =>
                                    value?.trim().isNotEmpty == true
                                        ? null
                                        : 'Name your list.'),
                            Wrap(spacing: 8, children: [
                              for (final choice in [
                                'teal',
                                'blue',
                                'violet',
                                'amber',
                                'rose'
                              ])
                                ChoiceChip(
                                    label: Text(choice),
                                    avatar: Icon(Icons.circle,
                                        size: 14, color: taskListColor(choice)),
                                    selected: color == choice,
                                    onSelected: (_) =>
                                        setState(() => color = choice))
                            ]),
                          ]))),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancel')),
                    FilledButton(
                        onPressed: () {
                          if (form.currentState!.validate()) {
                            Navigator.pop(context, true);
                          }
                        },
                        child: const Text('Save list'))
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
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Could not save this list. Please retry.')));
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
            content: Text(list.archived
                ? 'List restored'
                : 'List archived. Its tasks and reminders stay available.')));
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Could not update this list. Please retry.')));
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
                title: const Text('Choose list details'),
                content: Text(
                    'This phone: ${list.name} · ${list.color}${list.archived ? ' · archived' : ''}\n\nOther device: ${remote.name} · ${remote.color}${remote.archived ? ' · archived' : ''}\n\nTask contents will stay the same.'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Later')),
                  TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Use other device')),
                  FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Use this phone'))
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
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Could not resolve this list. Please retry.')));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
        appBar: const CustomAppBar(title: 'Lists'),
        body: ref.watch(taskListsProvider).when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, __) => Center(
                child: TextButton(
                    onPressed: () => ref.invalidate(taskListsProvider),
                    child: const Text('Retry lists'))),
            data: (lists) =>
                ListView(padding: const EdgeInsets.all(24), children: [
                  const Text(
                      'Keep work, life and everything else in their own lists. Inbox still collects tasks without a date.'),
                  const SizedBox(height: 20),
                  if (lists.isEmpty)
                    const EmptyState(
                        title: 'A place for each part of life',
                        message:
                            'Start with Work, Personal or Shopping. Tasks can move whenever you like.'),
                  for (final list in lists) ...[
                    ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                            list.archived
                                ? Icons.inventory_2_outlined
                                : Icons.folder_outlined,
                            color: taskListColor(list.color)),
                        title: Text(list.name),
                        subtitle: Text(list.conflict != null
                            ? 'Changed on another device · choose details'
                            : list.archived
                                ? 'Archived · tasks still available'
                                : '${(ref.watch(taskProvider).valueOrNull ?? []).where((task) => task.listId == list.id).length} tasks'),
                        onTap: () => list.conflict != null
                            ? _resolve(context, ref, list)
                            : Navigator.push(
                                context,
                                MaterialPageRoute<void>(
                                    builder: (_) => HomeScreen(
                                        isRoot: false, listId: list.id))),
                        trailing: PopupMenuButton<String>(
                            tooltip: 'Manage ${list.name}',
                            itemBuilder: (_) => [
                                  const PopupMenuItem(
                                      value: 'edit', child: Text('Edit list')),
                                  PopupMenuItem(
                                      value: 'archive',
                                      child: Text(list.archived
                                          ? 'Restore list'
                                          : 'Archive list')),
                                  if (list.conflict != null)
                                    const PopupMenuItem(
                                        value: 'resolve',
                                        child: Text('Choose details'))
                                ],
                            onSelected: (action) => switch (action) {
                                  'edit' => _edit(context, ref, list),
                                  'resolve' => _resolve(context, ref, list),
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
                    label: const Text('New list')))),
      );
}
