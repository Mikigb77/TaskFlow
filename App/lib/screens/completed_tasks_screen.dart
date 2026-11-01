import 'package:agenda/l10n/region.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:agenda/providers/auth_provider.dart';
import 'package:agenda/providers/project_scope_provider.dart';
import 'package:agenda/providers/task_lists_provider.dart';
import 'package:agenda/providers/task_provider.dart';
import 'package:agenda/widgets/custom_app_bar.dart';
import 'package:agenda/widgets/project_scope_control.dart';
import 'package:agenda/widgets/app_components.dart';
import 'package:agenda/widgets/task_list.dart';
import 'package:agenda/models/task.dart';

class CompletedTasksScreen extends ConsumerStatefulWidget {
  const CompletedTasksScreen({
    super.key,
    this.listId,
    this.team = true,
    this.person,
  });

  /// The project whose completed tasks show, as its page showed them: all
  /// of them, or `Para mí`'s ([team] false), or one [person]'s. Null lists
  /// every completed task.
  final String? listId;
  final bool team;
  final int? person;

  @override
  ConsumerState<CompletedTasksScreen> createState() =>
      _CompletedTasksScreenState();
}

class _CompletedTasksScreenState extends ConsumerState<CompletedTasksScreen> {
  // Rows seen done on this page, by task occurrence. One reopened here keeps
  // its place, unticked, until the person leaves the page: Tareas' rule.
  final _doneHere = <String>{};

  static String _row(Task task) => '${task.id}:${task.occurrenceId}';

  /// [task]'s done rows, and those reopened here since they were seen done.
  List<Task> _rowsOf(Task task) {
    if (!task.isRecurring) {
      return task.isCompleted || _doneHere.contains(_row(task))
          ? [task]
          : const [];
    }
    final prefix = '${task.id}:';
    return [
      ...task.completedDates.map(task.completedOccurrence).whereType<Task>(),
      for (final row in _doneHere)
        if (row.startsWith(prefix) &&
            !task.completedDates.contains(row.substring(prefix.length)))
          ?task.occurrenceByKey(row.substring(prefix.length)),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final listId = widget.listId;
    final team = widget.team;
    final person = widget.person;
    // The page is covered by another screen: the person has left it.
    if (!TickerMode.valuesOf(context).enabled) _doneHere.clear();
    final projects = ref.watch(taskListsProvider).valueOrNull ?? [];
    final accountId = ref.watch(authProvider).account?.id;
    final project = projects.where((p) => p.id == listId).firstOrNull;
    final scope = ProjectScope(projectId: listId, team: team);
    bool shown(Task task) =>
        listId == null ||
        (taskInProjectScope(task, scope, accountId, projects) &&
            (person == null ||
                (task.assignment == 'member' && task.assigneeId == person)));
    // Under the title, the project these are from, and whose they are when
    // its page was filtered: «Matemáticas · Ana», «Matemáticas · Para mí».
    // Someone no longer in the project leaves the project's name alone.
    final personName = person == null
        ? null
        : projectPeopleToFilter(project, accountId)
            .where((p) => p.id == person)
            .firstOrNull
            ?.name;
    final name = project == null
        ? null
        : Text(
            [
              project.name,
              if (personName != null)
                personName
              else if (person == null && !team)
                context.l10n.forMe,
            ].join(' · '),
            style: Theme.of(context).textTheme.titleMedium);
    return Scaffold(
        appBar: CustomAppBar(title: context.l10n.completedTasks),
        body: ref.watch(taskProvider).when(
              data: (tasks) {
                final completed = tasks.where(shown).expand(_rowsOf).toList();
                final done = completed.where((task) => task.isCompleted);
                _doneHere.addAll(done.map(_row));
                if (completed.isEmpty) {
                  return SingleChildScrollView(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        if (name != null)
                          Padding(
                              padding:
                                  const EdgeInsets.fromLTRB(24, 12, 24, 0),
                              child: name),
                        EmptyState(
                            title: context.l10n.progressSmall,
                            message: context.l10n.completedEmpty,
                            icon: Icons.task_alt_rounded),
                      ]));
                }
                return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (name != null) ...[
                                  name,
                                  if (done.isNotEmpty) const SizedBox(height: 8),
                                ],
                                // Every row reopened here: no count to give.
                                if (done.isNotEmpty)
                                  Text(context.l10n
                                      .completedTaskSummary(done.length)),
                              ])),
                      Expanded(
                          child: TaskList(
                              tasks: completed,
                              newestFirst: true,
                              project: listId)),
                    ]);
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) => EmptyState(
                  title: context.l10n.completedLoadError,
                  message: context.l10n.tryLater),
            ),
      );
  }
}
