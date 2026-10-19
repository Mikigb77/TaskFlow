import 'dart:math' as math;

import 'package:agenda/models/capture_command.dart';
import 'package:agenda/models/task.dart';
import 'package:agenda/models/task_list_info.dart';
import 'package:agenda/services/text_search.dart';

/// When a task falls in a search's period, and whether at a time.
typedef _When = ({DateTime at, bool timed});

/// How a command finds the phone's own tasks (Backend/docs/VOICE_COMMANDS.md):
/// the server never searches, and no task is sent to the assistant.
///
/// Each word is looked for in the title first, then in the notes, ignoring
/// case and accents; a word may start a longer one (`medic` finds
/// `Médico`). The tasks that hold every word are kept; when none do, those
/// that hold the most. Notes are not tasks, so commands never find them.
abstract final class TaskMatcher {
  /// [text] folded into words between spaces: ` ir al medico `.
  static String _fold(String text) =>
      ' ${foldForSearch(text).replaceAll(RegExp(r'[^\p{L}\p{N}]+', unicode: true), ' ').trim()} ';

  static List<String> _folded(List<String> words) => [
    for (final word in words)
      if (_fold(word).trim() case final folded when folded.isNotEmpty) folded,
  ];

  /// How many of [words] the task holds in its title, and how many more only
  /// in its notes.
  static ({int title, int notes}) _hits(Task task, List<String> words) {
    final title = _fold(task.title);
    final notes = _fold(task.notes ?? '');
    var inTitle = 0;
    var inNotes = 0;
    for (final word in words) {
      if (title.contains(' $word')) {
        inTitle++;
      } else if (notes.contains(' $word')) {
        inNotes++;
      }
    }
    return (title: inTitle, notes: inNotes);
  }

  /// [tasks] (already in the order to show) that hold the most [words]:
  /// those with them in the title first. With [best], only those, when any
  /// holds them in the title.
  static List<Task> _ranked(
    List<Task> tasks,
    List<String> words, {
    bool best = false,
  }) {
    final folded = _folded(words);
    if (folded.isEmpty) return tasks;
    final scored = [for (final task in tasks) (task, _hits(task, folded))];
    final most = scored.fold<int>(
      0,
      (most, item) => math.max(most, item.$2.title + item.$2.notes),
    );
    if (most == 0) return const [];
    final top = scored.where((item) => item.$2.title + item.$2.notes == most);
    final inTitle = [
      for (final (task, hits) in top)
        if (hits.title == most) task,
    ];
    final inNotes = [
      for (final (task, hits) in top)
        if (hits.title != most) task,
    ];
    if (best && inTitle.isNotEmpty) return inTitle;
    return [...inTitle, ...inNotes];
  }

  /// The most recently added first: the phone numbers tasks as they arrive.
  static int _newestFirst(Task a, Task b) => (b.id ?? -1).compareTo(a.id ?? -1);

  /// A repeating task is done once no repetition is left open.
  static bool _completed(Task task) => task.isRecurring
      ? task.nextOpenOccurrence() == null
      : task.isCompleted;

  /// For [personId]: the person themselves («mis tareas») sees what `Para mí`
  /// shows; anyone else, the tasks assigned to them.
  static bool _isFor(
    Task task,
    int personId,
    int? accountId,
    Iterable<TaskListInfo> projects,
  ) {
    if (personId == accountId) {
      final project = projects.where((p) => p.id == task.listId).firstOrNull;
      return task.isForAccount(
        accountId,
        managesProject: project?.canManage == true,
      );
    }
    return task.assignment == 'member' && task.assigneeId == personId;
  }

  /// When the task falls in the period, or null when it doesn't: its planned
  /// day, or its deadline's when it has none. A repeating task, by its first
  /// repetition in the period.
  static _When? _when(Task task, DateTime? from, DateTime? to) {
    final first = from == null ? null : Task.day(from);
    final last = to == null ? null : Task.day(to);
    bool inside(DateTime day) =>
        (first == null || !day.isBefore(first)) &&
        (last == null || !day.isAfter(last));
    if (!task.isRecurring) {
      final planned = task.dueDate;
      final date = planned ?? task.deadline;
      if (date == null || !inside(Task.day(date))) return null;
      return (
        at: date,
        timed: planned != null ? task.hasTime : task.deadlineHasTime,
      );
    }
    final start = Task.day(task.dueDate!);
    var day = first == null || first.isBefore(start) ? start : first;
    final end = last ?? DateTime(day.year, day.month, day.day + 366);
    // A year of days at most, so an open period stays quick.
    for (var i = 0; i <= 366 && !day.isAfter(end); i++) {
      if (task.occurrencesOn(day).firstOrNull case final shown?) {
        return (at: shown.displayDate!, timed: shown.hasTime);
      }
      day = DateTime(day.year, day.month, day.day + 1);
    }
    return null;
  }

  /// Soonest first, as Calendar lists a day: by day, then the tasks with no
  /// time, then by time.
  static int _soonestFirst(_When a, _When b) {
    final day = Task.day(a.at).compareTo(Task.day(b.at));
    if (day != 0) return day;
    if (a.timed != b.timed) return a.timed ? 1 : -1;
    return a.timed ? a.at.compareTo(b.at) : 0;
  }

  /// `find`: the tasks the person can see, completed ones included unless
  /// [CaptureCommand.status] says otherwise. With a period, soonest first,
  /// by when each falls in it; without one, newest first. Words the title
  /// holds still come first. A project or person that wasn't found searches
  /// nothing: the card says so instead.
  static List<Task> find(
    Iterable<Task> tasks,
    CaptureCommand command, {
    int? accountId,
    Iterable<TaskListInfo> projects = const [],
  }) {
    if (command.projectName != null || command.personName != null) {
      return const [];
    }
    final period = command.from != null || command.to != null;
    final found = <(Task, _When?)>[];
    for (final task in tasks) {
      if (task.isNote) continue;
      if (command.listId != null && task.listId != command.listId) continue;
      if (command.personId != null &&
          !_isFor(task, command.personId!, accountId, projects)) {
        continue;
      }
      if (command.status == 'open' && _completed(task)) continue;
      if (command.status == 'completed' && !_completed(task)) continue;
      final when = period ? _when(task, command.from, command.to) : null;
      if (period && when == null) continue;
      found.add((task, when));
    }
    found.sort((a, b) {
      if (period) {
        final order = _soonestFirst(a.$2!, b.$2!);
        if (order != 0) return order;
      }
      return _newestFirst(a.$1, b.$1);
    });
    return _ranked([for (final (task, _) in found) task], command.words);
  }

  /// The task as the card shows it: a repeating task's repetition on [date],
  /// or its next open one. Null when it has nothing on [date].
  static Task? _shown(Task task, DateTime? date) {
    if (date == null) {
      return task.isRecurring ? task.nextOpenOccurrence() ?? task : task;
    }
    if (!task.isRecurring) {
      final key = Task.dateKey(date);
      final planned = task.dueDate == null ? null : Task.dateKey(task.dueDate!);
      final deadline = task.deadline == null
          ? null
          : Task.dateKey(task.deadline!);
      return planned == key || deadline == key ? task : null;
    }
    return task.occurrenceOn(date) ?? task.deadlinesOn(date).firstOrNull;
  }

  /// `update` and `delete`: the tasks [target] may mean, among those the
  /// person can edit, open ones first. A repeating task comes as the
  /// repetition meant. Words, a project or a day are needed: with none,
  /// nothing is found.
  static List<Task> targets(
    Iterable<Task> tasks,
    CommandTarget target, {
    required bool Function(String? listId) canEdit,
  }) {
    if (target.projectName != null) return const [];
    if (_folded(target.words).isEmpty &&
        target.date == null &&
        target.listId == null) {
      return const [];
    }
    final found = <Task>[];
    for (final task in tasks) {
      if (task.isNote || !canEdit(task.listId)) continue;
      if (target.listId != null && task.listId != target.listId) continue;
      final shown = _shown(task, target.date);
      if (shown != null) found.add(shown);
    }
    found.sort(_newestFirst);
    final best = _ranked(found, target.words, best: true);
    final open = best.where((task) => !_done(task)).toList();
    return open.isNotEmpty ? open : best;
  }

  /// A repetition is done when it is completed; a repeating task shown as a
  /// whole, when none is left open.
  static bool _done(Task shown) =>
      shown.occurrenceDate != null ? shown.isCompleted : _completed(shown);
}
