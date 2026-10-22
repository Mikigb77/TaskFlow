import 'package:agenda/models/capture_command.dart';
import 'package:agenda/models/task.dart';
import 'package:agenda/models/task_list_info.dart';
import 'package:agenda/services/command_plan.dart';
import 'package:agenda/services/task_matcher.dart';

/// What a bulk command's card says it does, and how its message after the
/// tap reads.
enum BulkAction {
  /// To a day: «Mover 5 tareas a mañana, jue 22».
  move,

  /// By days: «Mover 3 tareas una semana después».
  shift,

  /// To someone: «Asignar 4 tareas a Paul».
  assign,

  /// Anything else: «Cambiar 4 tareas», with what changes under it.
  change,

  /// «Marcar 4 tareas como hechas».
  complete,

  /// «Eliminar 6 tareas».
  delete,
}

/// One task of a bulk command's set, as its card lists it.
class BulkItem {
  const BulkItem({
    required this.shown,
    required this.stored,
    this.plan,
    this.overdue = false,
  });

  /// As listed: a repeating task's repetition, when a day's tasks are
  /// marked done.
  final Task shown;

  /// As stored.
  final Task stored;

  /// `update`: what changes on it.
  final UpdatePlan? plan;

  /// Taken by a «hoy» set from what Today lists under «Atrasadas»: its row
  /// says «Atrasada».
  final bool overdue;

  /// Its key on the card, kept when it is unticked: the task, or the
  /// repetition.
  String get key => TaskMatcher.keyOf(shown);
}

/// What a bulk command would do (Backend/docs/VOICE_COMMANDS.md, «Bulk
/// commands»): the tasks its card lists, each ticked unless unticked, and
/// what was left out. Nothing changes before the confirming tap. A «hoy»
/// set lists the overdue tasks it took first ([BulkItem.overdue]).
class BulkPlan {
  const BulkPlan({
    required this.action,
    this.items = const [],
    this.excluded = const {},
    this.matched = 0,
    this.repeatingTasks = const [],
    this.unassignableTasks = const [],
    this.noDayTasks = const [],
    this.viewOnly,
    this.unasked = const [],
  });

  /// More tasks than this are not listed: the card asks for fewer.
  static const limit = 200;

  final BulkAction action;

  /// The tasks that would change, in the set's order: a «hoy» set's
  /// overdue ones first.
  final List<BulkItem> items;

  /// The keys of the [items] unticked.
  final Set<String> excluded;

  /// How many tasks matched, before leaving out those already as asked.
  final int matched;

  /// Left out: repeating tasks, as stored. The card names a lone one.
  final List<Task> repeatingTasks;

  /// Left out of the assignment: tasks the person named can't be given (no
  /// shared project, or they can't edit it). Their other changes still
  /// apply.
  final List<Task> unassignableTasks;

  /// Left out: tasks with no day, which can't be moved by days or take a
  /// time.
  final List<Task> noDayTasks;

  /// How many repeating tasks were left out.
  int get repeating => repeatingTasks.length;

  /// How many tasks the person named can't be given.
  int get unassignable => unassignableTasks.length;

  /// How many tasks with no day were left out.
  int get noDay => noDayTasks.length;

  /// Nothing matched among the tasks the person can edit: the first that
  /// would have, in a project they can only view.
  final Task? viewOnly;

  /// A change that said nothing to change (`changes` empty): the tasks it
  /// matched, shown as a search shows them, each opening to edit, as one
  /// task's does.
  final List<Task> unasked;

  /// Over [limit]: no list and no button.
  bool get tooMany => matched > limit;

  /// The tasks the confirming tap changes: those still ticked.
  List<BulkItem> get selected => [
    for (final item in items)
      if (!excluded.contains(item.key)) item,
  ];

  /// The live count, on the heading and the button.
  int get count => selected.length;

  /// Every task is unticked: the button waits for one.
  bool get waits => items.isNotEmpty && count == 0;

  /// Something was left out, for the card's one line saying so.
  bool get leftOut => repeating > 0 || unassignable > 0 || noDay > 0;

  /// It only moves tasks to another day or time: «5 tareas movidas».
  bool movesOnly(TaskChanges changes) =>
      (action == BulkAction.move || action == BulkAction.shift) &&
      changes.values.keys.every(
        (key) => const {'date', 'time', 'shift_days'}.contains(key),
      );
}

/// How [command]'s card names it: moving to a day or by days first, then
/// assigning to someone found, else a change.
BulkAction bulkAction(CaptureCommand command) {
  switch (command.kind) {
    case CommandKind.delete:
      return BulkAction.delete;
    case CommandKind.complete:
      return BulkAction.complete;
    case CommandKind.update:
    case CommandKind.project:
    case CommandKind.find:
      break;
  }
  final changes = command.changes;
  if (changes.shiftDays != null) return BulkAction.shift;
  if (changes.has('date') && changes.date != null) return BulkAction.move;
  if (changes.assigneeId != null) return BulkAction.assign;
  return BulkAction.change;
}

/// Works out bulk [command] against the phone's [tasks] and [projects]:
/// its set ([TaskMatcher.bulk], today being [now]'s day), then for each task
/// what would change. A task already as asked isn't listed. The overdue
/// tasks a «hoy» set takes are marked, and moved by days they count from
/// today, like the rest (the owner's D4).
BulkPlan planBulk(
  CaptureCommand command, {
  required List<Task> tasks,
  required List<TaskListInfo> projects,
  int? accountId,
  DateTime? now,
}) {
  final action = bulkAction(command);
  final set = TaskMatcher.bulk(
    tasks,
    command.target,
    accountId: accountId,
    projects: projects,
    completing: command.kind == CommandKind.complete,
    now: now,
  );
  final today = Task.day(now ?? DateTime.now());
  final matched = set.tasks.length;
  if (matched > BulkPlan.limit) {
    return BulkPlan(
      action: action,
      matched: matched,
      repeatingTasks: set.repeatingTasks,
    );
  }
  final changes = command.changes;
  if (command.kind == CommandKind.update && changes.isEmpty) {
    return BulkPlan(
      action: action,
      matched: matched,
      repeatingTasks: set.repeatingTasks,
      viewOnly: set.viewOnly,
      unasked: set.tasks,
    );
  }
  final items = <BulkItem>[];
  final unassignable = <Task>[];
  final noDay = <Task>[];
  for (final shown in set.tasks) {
    final stored = tasks.where((task) => task.id == shown.id).firstOrNull;
    if (stored == null) continue;
    final overdue = set.overdue.contains(TaskMatcher.keyOf(shown));
    switch (command.kind) {
      case CommandKind.update:
        final plan = planUpdate(
          task: stored,
          shown: overdue ? _fromToday(shown, changes, today) : shown,
          changes: changes,
          issues: command.issues,
          project: projects.where((p) => p.id == stored.listId).firstOrNull,
          accountId: accountId,
        );
        if (plan.noDay || plan.needsDay) noDay.add(stored);
        // A name not found is said once, on the card, not for each task.
        if (!changes.hasUnresolved &&
            (plan.problem == AssigneeProblem.notInProject ||
                plan.problem == AssigneeProblem.needsShared)) {
          unassignable.add(stored);
        }
        if (!plan.isEmpty) {
          items.add(
            BulkItem(
              shown: shown,
              stored: stored,
              plan: plan,
              overdue: overdue,
            ),
          );
        }
      case CommandKind.complete:
        if (!TaskMatcher.done(shown)) {
          items.add(BulkItem(shown: shown, stored: stored, overdue: overdue));
        }
      case CommandKind.delete:
        items.add(BulkItem(shown: shown, stored: stored, overdue: overdue));
      case CommandKind.project:
      case CommandKind.find:
        break;
    }
  }
  return BulkPlan(
    action: action,
    items: items,
    excluded: command.excluded.toSet(),
    matched: matched,
    repeatingTasks: set.repeatingTasks,
    unassignableTasks: unassignable,
    noDayTasks: noDay,
    viewOnly: set.viewOnly,
  );
}

/// An overdue task of a «hoy» set, as a move by days ([changes]'
/// `shift_days`, with no day said) counts it: from [today], at its own
/// time, so «retrasa todo lo de hoy un día» puts it on tomorrow with the
/// rest. Otherwise as it is.
Task _fromToday(Task shown, TaskChanges changes, DateTime today) {
  if (changes.shiftDays == null || changes.has('date')) return shown;
  DateTime onToday(DateTime date) =>
      DateTime(today.year, today.month, today.day, date.hour, date.minute);
  if (shown.dueDate case final planned?) {
    return shown.copyWith(dueDate: onToday(planned));
  }
  if (shown.deadline case final due?) {
    return shown.copyWith(deadline: onToday(due));
  }
  return shown;
}
