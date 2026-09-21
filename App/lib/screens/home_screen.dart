import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:agenda/providers/task_provider.dart';
import 'package:agenda/widgets/app_components.dart';
import 'package:agenda/widgets/custom_app_bar.dart';
import 'package:agenda/widgets/task_list.dart';
import 'package:agenda/widgets/task_actions.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});
  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  String _query = '';
  int _filter = 0;
  @override
  Widget build(BuildContext context) {
    final tasks = ref.watch(taskProvider);
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: const CustomAppBar(title: 'Tasks', isRoot: true),
      body: NestedScrollView(
        headerSliverBuilder: (context, innerScrolled) => [
          SliverToBoxAdapter(
              child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 10, 24, 20),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SectionLabel('One thing at a time'),
                        Row(children: [
                          Expanded(
                              child: Text('Your tasks',
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineLarge)),
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
                        Wrap(spacing: 8, runSpacing: 4, children: [
                          for (final entry in [
                            (0, 'All tasks'),
                            (1, 'Today'),
                            (2, 'High priority')
                          ])
                            ChoiceChip(
                                label: Text(entry.$2),
                                selected: _filter == entry.$1,
                                onSelected: (_) =>
                                    setState(() => _filter = entry.$1)),
                        ]),
                      ]))),
        ],
        body: tasks.when(
          data: (all) {
            final now = DateTime.now();
            final filtered = all
                .where((task) =>
                    !task.isCompleted &&
                    (_filter == 0 ||
                        (_filter == 2 && task.priority == 3) ||
                        (_filter == 1 &&
                            DateUtils.isSameDay(task.dueDate, now))) &&
                    ('${task.title} ${task.notes ?? ''}')
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
                        : 'Capture what’s on your mind.\nWe’ll keep it right here.',
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
          onCreate: () => Navigator.pushNamed(context, '/createTask')),
    );
  }
}
