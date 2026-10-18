import 'package:agenda/models/occurrence_change.dart';
import 'package:agenda/models/task.dart';
import 'package:agenda/models/task_list_info.dart';
import 'package:agenda/models/task_schedule_change.dart';
import 'package:agenda/providers/task_provider.dart';
import 'package:agenda/services/api_client.dart';
import 'package:agenda/services/command_plan.dart';
import 'package:agenda/services/task_list_store.dart';
import 'package:collection/collection.dart';

/// One change the confirming tap made to a task, with what puts it back.
class AppliedUpdate {
  AppliedUpdate(
    this.before, {
    this.written,
    this.occurrence,
    this.series,
    this.landed,
  });

  /// The task as it was stored.
  final Task before;

  /// The task as the change wrote it, for the fields only that put back.
  final Task? written;

  /// A repeating task's repetition moved, or its whole series.
  final OccurrenceChange? occurrence;
  final TaskScheduleChange? series;

  /// The task as it lands: the day Calendar shows it on.
  final Task? landed;
}

/// What one confirming tap did, so one `Deshacer` takes all of it back.
class AppliedCommands {
  /// Projects created, by id.
  final projects = <String>[];
  final updates = <AppliedUpdate>[];

  /// Tasks deleted, as they were stored.
  final deleted = <Task>[];

  bool get isEmpty => projects.isEmpty && updates.isEmpty && deleted.isEmpty;
}

/// Creates the projects, and changes and deletes the tasks, a dictation's
/// commands asked for, the way the rest of the app does, then undoes them.
class CommandRunner {
  CommandRunner(this.tasks, this.lists, {required this.current});
  final TaskNotifier tasks;
  final TaskListStore lists;

  /// The tasks on the phone now.
  final List<Task> Function() current;

  /// A new personal project, as `Nuevo proyecto` makes one.
  Future<TaskListInfo> createProject(
    String name,
    AppliedCommands applied,
  ) async {
    final project = TaskListInfo(name: name);
    await lists.create(project);
    applied.projects.add(project.id);
    return project;
  }

  /// Applies [plan]. A repeating task's new day or time moves only the
  /// repetition shown, unless [series] (or [UpdatePlan.seriesOnly]); its
  /// other changes are the series', as the task form's are.
  Future<void> update(
    UpdatePlan plan, {
    bool series = false,
    required AppliedCommands applied,
  }) async {
    final before = plan.task;
    if (!plan.repeating) {
      final after = plan.after();
      await tasks.updateTask(after);
      applied.updates.add(AppliedUpdate(before, written: after, landed: after));
      return;
    }
    final fields = plan.fields();
    final changesFields = !const DeepCollectionEquality().equals(
      fields.toMap(),
      before.toMap(),
    );
    if (changesFields) await tasks.updateTask(fields);
    OccurrenceChange? occurrence;
    TaskScheduleChange? whole;
    Task? landed = plan.shown;
    if (plan.schedule case final schedule?) {
      final shown = plan.shown;
      if (series || plan.seriesOnly || shown.occurrenceId == null) {
        // The series starts on the day said; a new time alone keeps its
        // start day.
        final date = schedule.date;
        final sameDay =
            date != null &&
            shown.displayDate != null &&
            Task.dateKey(date) == Task.dateKey(shown.displayDate!);
        final start = before.dueDate!;
        final moved = date == null || !sameDay
            ? date
            : DateTime(
                start.year,
                start.month,
                start.day,
                date.hour,
                date.minute,
              );
        whole = await tasks.rescheduleTask(
          before.id!,
          moved,
          schedule.hasTime,
        );
        landed = whole.after.nextOpenOccurrence() ?? whole.after;
      } else {
        occurrence = await tasks.changeOccurrence(
          shown,
          schedule.date,
          schedule.hasTime,
        );
        landed = shown.copyWith(
          occurrenceDate: schedule.date,
          occurrenceHasTime: schedule.hasTime,
        );
      }
    }
    applied.updates.add(
      AppliedUpdate(
        before,
        written: changesFields ? fields : null,
        occurrence: occurrence,
        series: whole,
        landed: landed,
      ),
    );
  }

  /// Deletes [task] (the stored one) on this phone first, so `Deshacer` can
  /// bring all of it back; the next sync sends it.
  Future<void> delete(Task task, AppliedCommands applied) async {
    await tasks.deleteTask(task.id!, sync: false);
    applied.deleted.add(task);
  }

  /// Puts back the deleted tasks and the changed fields, newest first. False
  /// when something had changed again since, and was left as it is.
  Future<bool> undoChanges(AppliedCommands applied) async {
    var whole = true;
    for (final task in applied.deleted.reversed) {
      try {
        await tasks.restoreTask(task);
      } catch (_) {
        whole = false;
      }
    }
    for (final update in applied.updates.reversed) {
      try {
        if (update.occurrence case final change?) {
          if (!await tasks.undoOccurrence(change)) whole = false;
        }
        if (update.series case final change?) {
          if (!await tasks.undoSchedule(change)) whole = false;
        }
        if (update.written case final written?) {
          final now = current()
              .where((task) => task.id == update.before.id)
              .firstOrNull;
          if (now == null) {
            whole = false;
            continue;
          }
          await tasks.updateTask(restoreFields(now, update.before, written));
        }
      } catch (_) {
        whole = false;
      }
    }
    return whole;
  }

  /// Takes back the projects created, once their tasks are undone.
  Future<bool> takeBackProjects(
    AppliedCommands applied, {
    ApiClient? api,
    int? accountId,
  }) async {
    var whole = true;
    for (final id in applied.projects.reversed) {
      try {
        if (!await lists.takeBack(id, api: api, accountId: accountId)) {
          whole = false;
        }
      } catch (_) {
        whole = false;
      }
    }
    return whole;
  }
}

/// [current] with the fields a change wrote ([written]) put back as they
/// were [before]; anything changed since in other fields stays.
Task restoreFields(Task current, Task before, Task written) {
  final was = before.toMap();
  final wrote = written.toMap();
  final now = current.toMap();
  for (final key in wrote.keys) {
    if (!const DeepCollectionEquality().equals(was[key], wrote[key])) {
      now[key] = was[key];
    }
  }
  return Task.fromMap(now);
}
