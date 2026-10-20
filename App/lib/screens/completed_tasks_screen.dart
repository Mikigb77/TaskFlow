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

class CompletedTasksScreen extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
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
                final completed = tasks
                    .where(shown)
                    .expand((task) => task.isRecurring
                        ? task.completedDates
                            .map(task.completedOccurrence)
                            .whereType<Task>()
                        : task.isCompleted
                            ? [task]
                            : <Task>[])
                    .toList();
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
                                  const SizedBox(height: 8),
                                ],
                                Text(context.l10n
                                    .completedTaskSummary(completed.length)),
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
