import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:agenda/providers/task_provider.dart';
import 'package:agenda/widgets/app_components.dart';
import 'package:agenda/widgets/custom_app_bar.dart';
import 'package:agenda/widgets/task_list.dart';
import 'package:agenda/widgets/task_actions.dart';
import 'package:agenda/models/task.dart';
import 'package:agenda/providers/task_lists_provider.dart';
import 'package:agenda/widgets/task_editor.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen(
      {super.key, this.initialFilter = 0, this.isRoot = true, this.listId});
  final int initialFilter;
  final bool isRoot;
  final String? listId;
  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  String _query = '';
  late int _filter = widget.initialFilter;
  String? _label;
  @override
  Widget build(BuildContext context) {
    final tasks = ref.watch(taskProvider);
    final colors = Theme.of(context).colorScheme;
    final list = (ref.watch(taskListsProvider).valueOrNull ?? [])
        .where((list) => list.id == widget.listId)
        .firstOrNull;
    final title = widget.listId != null
        ? list?.name ?? 'List'
        : widget.isRoot
            ? 'Tasks'
            : 'Inbox';
    final labels = (tasks.valueOrNull ?? [])
        .expand((task) => task.labels)
        .toSet()
        .toList()
      ..sort();
    return Scaffold(
      appBar: CustomAppBar(title: title, isRoot: widget.isRoot),
      body: NestedScrollView(
        headerSliverBuilder: (context, innerScrolled) => [
          SliverToBoxAdapter(
              child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 10, 24, 20),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SectionLabel(widget.listId != null
                            ? (list?.archived == true
                                ? 'Archived list'
                                : 'Your list')
                            : widget.isRoot
                                ? 'Everything you want to do'
                                : 'No date needed'),
                        Row(children: [
                          Expanded(
                              child: Text(widget.isRoot ? 'Your tasks' : title,
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineLarge)),
                          if (widget.isRoot)
                            IconButton(
                                tooltip: 'Lists',
                                onPressed: () =>
                                    Navigator.pushNamed(context, '/lists'),
                                icon: const Icon(Icons.folder_outlined)),
                          IconButton(
                              tooltip: 'Completed tasks',
                              onPressed: () => Navigator.pushNamed(
                                  context, '/completedTasks'),
                              icon: const Icon(Icons.task_alt_rounded)),
                        ]),
                        const SizedBox(height: 16),
                        TextField(
                            onChanged: (value) => setState(
                                () => _query = value.trim().toLowerCase()),
                            decoration: const InputDecoration(
                                hintText: 'Find a task…',
                                prefixIcon: Icon(Icons.search_rounded),
                                isDense: true)),
                        const SizedBox(height: 12),
                        if (widget.isRoot)
                          Wrap(spacing: 8, runSpacing: 4, children: [
                            for (final entry in [
                              (0, 'All tasks'),
                              (3, 'Inbox'),
                              (4, 'No list'),
                              (1, 'Today'),
                              (2, 'High priority')
                            ])
                              ChoiceChip(
                                  label: Text(entry.$2),
                                  selected: _filter == entry.$1,
                                  onSelected: (_) =>
                                      setState(() => _filter = entry.$1)),
                          ]),
                        if (labels.isNotEmpty)
                          DropdownButton<String>(
                              hint: const Text('Filter by label'),
                              value: labels.contains(_label) ? _label : null,
                              isExpanded: true,
                              items: [
                                const DropdownMenuItem(
                                    value: '', child: Text('All labels')),
                                for (final label in labels)
                                  DropdownMenuItem(
                                      value: label, child: Text('#$label'))
                              ],
                              onChanged: (value) => setState(
                                  () => _label = value == '' ? null : value)),
                      ]))),
        ],
        body: tasks.when(
          data: (all) {
            final now = DateTime.now();
            final filtered = all
                .map((task) => task.nextOpenOccurrence())
                .whereType<Task>()
                .where((task) =>
                    !task.isCompleted &&
                    (widget.listId == null || task.listId == widget.listId) &&
                    (_label == null || task.labels.contains(_label)) &&
                    (_filter == 0 ||
                        (_filter == 3 && task.dueDate == null) ||
                        (_filter == 4 && task.listId == null) ||
                        (_filter == 2 && task.priority == 3) ||
                        (_filter == 1 &&
                            DateUtils.isSameDay(task.displayDate, now))) &&
                    ('${task.title} ${task.notes ?? ''} ${task.labels.join(' ')} ${task.checklist.map((item) => item.title).join(' ')}')
                        .toLowerCase()
                        .contains(_query))
                .toList();
            if (filtered.isEmpty) {
              return ListView(children: [
                EmptyState(
                    title: _query.isNotEmpty
                        ? 'No matching tasks'
                        : 'A fresh start',
                    message: _query.isNotEmpty
                        ? 'Try a different word or filter.'
                        : widget.listId != null
                            ? 'Add a task to this list. Its date and reminder are yours to choose.'
                            : widget.isRoot
                                ? 'Use Say a task to speak, or New task to type.\nAdd a date now or leave it for later.'
                                : 'Keep ideas and to-dos here until you choose a date.\nUse Say a task or New task to begin.',
                    icon: Icons.checklist_rounded),
              ]);
            }
            return RefreshIndicator(
                onRefresh: () => ref.read(taskProvider.notifier).loadTasks(),
                child: TaskList(tasks: filtered));
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => EmptyState(
              title: 'Couldn’t load your tasks',
              message: 'Your saved tasks are still on your device.',
              action: TextButton(
                  onPressed: () => ref.read(taskProvider.notifier).loadTasks(),
                  child: Text('Try again',
                      style: TextStyle(color: colors.primary)))),
        ),
      ),
      bottomNavigationBar: TaskActions(
          onCreate: () => widget.listId == null
              ? Navigator.pushNamed(context, '/createTask')
              : Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                      builder: (_) =>
                          TaskEditor(initialListId: widget.listId)))),
    );
  }
}
