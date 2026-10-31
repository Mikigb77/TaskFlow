import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:agenda/models/task.dart';
import 'package:agenda/models/task_list_info.dart';
import 'package:agenda/providers/auth_provider.dart';

class ProjectScope {
  const ProjectScope({this.projectId, this.team = false});
  final String? projectId;
  final bool team;
}

// Switching accounts resets the selection as well as the task cache.
final projectScopeProvider = StateProvider<ProjectScope>((ref) {
  ref.watch(authProvider.select((state) => state.account?.id));
  return const ProjectScope();
});

/// The last time a landing widened the scope to show its saved tasks:
/// the scope from [before] it and the one it set ([after]).
class ScopeWidening {
  const ScopeWidening(this.landing, this.before, this.after);
  final Object landing;
  final ProjectScope before;
  final ProjectScope after;
}

final scopeWideningProvider = StateProvider<ScopeWidening?>((ref) {
  ref.watch(authProvider.select((state) => state.account?.id));
  return null;
});

/// After Deshacer takes back every task [landing] brought, puts back the
/// scope from before that landing, unless the person has chosen another
/// filter since (each choice is a new [ProjectScope]).
void narrowAfterUndo(ProviderContainer container, Object? landing) {
  if (landing == null) return;
  final widening = container.read(scopeWideningProvider);
  if (widening == null || !identical(widening.landing, landing)) return;
  if (identical(container.read(projectScopeProvider), widening.after)) {
    container.read(projectScopeProvider.notifier).state = widening.before;
  }
  container.read(scopeWideningProvider.notifier).state = null;
}

bool taskInProjectScope(
  Task task,
  ProjectScope scope,
  int? accountId,
  Iterable<TaskListInfo> projects,
) {
  if (scope.projectId != null && task.listId != scope.projectId) return false;
  final project = projects.where((p) => p.id == task.listId).firstOrNull;
  if (project?.inactive == true && scope.projectId == null) return false;
  if (scope.team) return true;
  return task.isForAccount(
    accountId,
    managesProject: project?.canManage == true,
  );
}

/// The scope that shows the just-saved [tasks], widened only as far as
/// needed: `Todas` in the same project first, then every project. [scope]
/// itself when it already shows them all.
ProjectScope scopeShowing(
  Iterable<Task> tasks,
  ProjectScope scope,
  int? accountId,
  Iterable<TaskListInfo> projects,
) {
  int shown(ProjectScope candidate) => tasks
      .where((task) => taskInProjectScope(task, candidate, accountId, projects))
      .length;
  final all = tasks.length;
  if (shown(scope) == all) return scope;
  var best = scope;
  for (final candidate in [
    ProjectScope(projectId: scope.projectId, team: true),
    ProjectScope(team: scope.team),
    const ProjectScope(team: true),
  ]) {
    final count = shown(candidate);
    if (count == all) return candidate;
    if (count > shown(best)) best = candidate;
  }
  return best;
}
