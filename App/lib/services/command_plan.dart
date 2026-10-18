import 'package:agenda/models/capture_command.dart';
import 'package:agenda/models/task.dart';
import 'package:agenda/models/task_list_info.dart';

/// A planned day, with or without a time; no [date] means none.
typedef Schedule = ({DateTime? date, bool hasTime});

/// Why the person named can't be the task's assignee. The card says so, and
/// the assignee stays as it is.
enum AssigneeProblem {
  /// They aren't someone who can edit the task's shared project.
  notInProject,

  /// Only a task in a shared project has an assignee.
  needsShared,

  /// Two or more people have that name.
  ambiguous,
}

/// What an `update` command would do to one task, field by field: what its
/// card shows before → after, and what the confirming tap writes. Only the
/// fields asked for change; notes, steps, files, reminders and sharing stay.
class UpdatePlan {
  const UpdatePlan({
    required this.task,
    required this.shown,
    this.asked = true,
    this.title,
    this.schedule,
    this.deadline,
    this.priority,
    this.notes,
    this.assignee,
    this.problem,
    this.problemName,
    this.needsDay = false,
    this.seriesOnly = false,
  });

  /// The task as stored: a repeating one is the whole series.
  final Task task;

  /// The task as its card shows it: a repeating task's repetition.
  final Task shown;

  /// Something was asked to change. Nothing asked opens the task to edit.
  final bool asked;

  final String? title;

  /// The new planned day and time, of [shown].
  final Schedule? schedule;

  /// The new deadline, as said: for a repeating task, [shown]'s.
  final Schedule? deadline;
  final int? priority;

  /// Text added at the end of the notes, on a new line.
  final String? notes;
  final ({String assignment, int? id, String? name})? assignee;
  final AssigneeProblem? problem;
  final String? problemName;

  /// A time for a task with no day: a day has to be chosen first.
  final bool needsDay;

  /// A repeating task's day taken away: only the whole series can lose it.
  final bool seriesOnly;

  bool get repeating => task.isRecurring;

  /// Nothing would change: already as asked, or nothing was asked.
  bool get isEmpty =>
      title == null &&
      schedule == null &&
      deadline == null &&
      priority == null &&
      notes == null &&
      assignee == null;

  /// The confirming tap can apply it.
  bool get ready => !isEmpty && !needsDay;

  /// Every change but the planned day and time, on the stored task.
  Task fields() {
    var next = task;
    if (title != null) next = next.copyWith(title: title);
    if (priority != null) next = next.copyWith(priority: priority);
    if (notes != null) {
      next = next.copyWith(notes: appendToNotes(task.notes, notes!));
    }
    if (deadline case final deadline?) {
      final date = deadline.date == null
          ? null
          : task.isRecurring && shown.occurrenceId != null
          ? _seriesDeadline(deadline.date!)
          : deadline.date;
      next = next.copyWith(
        deadline: date,
        deadlineHasTime: date != null && deadline.hasTime,
      );
    }
    if (assignee case final assignee?) {
      next = next.copyWith(
        assignment: assignee.assignment,
        assigneeId: assignee.id,
        assigneeName: assignee.name,
      );
    }
    return next;
  }

  /// The stored task with every change, for a task that doesn't repeat. A
  /// reminder follows the deadline when the task has no day left.
  Task after() {
    var next = fields();
    if (schedule case final schedule?) {
      next = next.copyWith(
        dueDate: schedule.date,
        hasTime: schedule.date != null && schedule.hasTime,
      );
    }
    final anchor = next.deadline == null
        ? 'planned'
        : next.dueDate == null
        ? 'deadline'
        : next.reminderAnchor;
    return anchor == next.reminderAnchor
        ? next
        : next.copyWith(reminderAnchor: anchor);
  }

  /// A repeating task keeps its deadline as days after each repetition: the
  /// one said for [shown] becomes the series' own.
  DateTime _seriesDeadline(DateTime said) {
    final original = DateTime.parse(shown.occurrenceId!);
    final start = task.dueDate!;
    final offset = DateTime.utc(said.year, said.month, said.day)
        .difference(DateTime.utc(original.year, original.month, original.day))
        .inDays;
    return DateTime(
      start.year,
      start.month,
      start.day + offset,
      said.hour,
      said.minute,
    );
  }
}

/// [text] added at the end of [notes], on a new line, keeping the notes
/// within their 8000 characters.
String appendToNotes(String? notes, String text) {
  final before = (notes ?? '').trimRight();
  final joined = before.isEmpty ? text : '$before\n$text';
  return joined.length <= 8000 ? joined : joined.substring(0, 8000);
}

bool _same(Schedule a, Schedule b) {
  if (a.date == null || b.date == null) return a.date == b.date;
  if (a.hasTime != b.hasTime) return false;
  return a.hasTime
      ? a.date == b.date
      : Task.dateKey(a.date!) == Task.dateKey(b.date!);
}

Schedule _at(DateTime day, ({int hour, int minute})? clock) => clock == null
    ? (date: Task.day(day), hasTime: false)
    : (
        date: DateTime(day.year, day.month, day.day, clock.hour, clock.minute),
        hasTime: true,
      );

({int hour, int minute})? _clockOf(Schedule schedule) =>
    schedule.hasTime && schedule.date != null
    ? (hour: schedule.date!.hour, minute: schedule.date!.minute)
    : null;

/// What [changes] would do to [task], shown as [shown] (a repeating task's
/// repetition). [project] is the task's project, [accountId] the person's
/// own, and [day] the day chosen for a new time on a task with no day.
UpdatePlan planUpdate({
  required Task task,
  required Task shown,
  required TaskChanges changes,
  List<String> issues = const [],
  TaskListInfo? project,
  int? accountId,
  DateTime? day,
}) {
  final title = changes.title;

  // The planned day and time: a new day keeps the time, unless a time is
  // said too; a new time keeps the day.
  Schedule? schedule;
  var needsDay = false;
  var seriesOnly = false;
  if (changes.has('date') || changes.has('time')) {
    final current = (date: shown.displayDate, hasTime: shown.hasTime);
    if (changes.has('date') && changes.date == null) {
      schedule = (date: null, hasTime: false);
      seriesOnly = task.isRecurring;
    } else {
      final base = changes.has('date') ? changes.date : current.date ?? day;
      final clock = changes.has('time') ? changes.time : _clockOf(current);
      if (base != null) {
        schedule = _at(base, clock);
      } else if (changes.time != null) {
        needsDay = true;
      }
    }
    if (schedule != null && _same(schedule, current)) schedule = null;
  }

  // The deadline, the same way.
  Schedule? deadline;
  if (changes.has('deadline_date') || changes.has('deadline_time')) {
    final current = (
      date: shown.displayDeadline ?? task.deadline,
      hasTime: task.deadlineHasTime,
    );
    if (changes.has('deadline_date') && changes.deadlineDate == null) {
      deadline = (date: null, hasTime: false);
    } else {
      final base = changes.has('deadline_date')
          ? changes.deadlineDate
          : current.date;
      final clock = changes.has('deadline_time')
          ? changes.deadlineTime
          : _clockOf(current);
      if (base != null) deadline = _at(base, clock);
    }
    if (deadline != null && _same(deadline, current)) deadline = null;
  }

  // Only someone who can edit the task's shared project can be its assignee.
  ({String assignment, int? id, String? name})? assignee;
  AssigneeProblem? problem;
  String? problemName;
  if (changes.assigns) {
    final shared = project?.shared == true;
    if (changes.hasUnresolved) {
      problem = issues.contains('ambiguous_member')
          ? AssigneeProblem.ambiguous
          : shared
          ? AssigneeProblem.notInProject
          : AssigneeProblem.needsShared;
      problemName = changes.assigneeName;
    } else if (changes.assignsNobody) {
      // Nobody in particular: everyone in the project.
      if (shared && task.assignment != 'group') {
        assignee = (assignment: 'group', id: null, name: null);
      }
    } else {
      final id = changes.assigneeId!;
      final person = project?.people
          .where((p) => p.id == id && p.canEdit)
          .firstOrNull;
      if (shared && person != null) {
        if (task.assignment != 'member' || task.assigneeId != id) {
          assignee = (assignment: 'member', id: id, name: person.name);
        }
      } else if (shared || id != accountId) {
        // «Asígnamela» on a task of one's own changes nothing.
        problem = shared
            ? AssigneeProblem.notInProject
            : AssigneeProblem.needsShared;
        problemName = changes.assigneeName ?? person?.name;
      }
    }
  }

  return UpdatePlan(
    task: task,
    shown: shown,
    asked: !changes.isEmpty,
    title: title != null && title != task.title ? title : null,
    schedule: schedule,
    deadline: deadline,
    priority: changes.priority != null && changes.priority != task.priority
        ? changes.priority
        : null,
    notes: changes.notesAppend,
    assignee: assignee,
    problem: problem,
    problemName: problemName,
    needsDay: needsDay,
    seriesOnly: seriesOnly,
  );
}
