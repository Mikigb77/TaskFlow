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
