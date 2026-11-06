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
  /// or its next open one. Null when it has nothing on [date]. With [today]
  /// (marking one done with no day said), a repeating task comes as today's
  /// repetition, as ticking it on Today does, or else the one Today lists as
  /// overdue.
  static Task? _shown(
    Task task,
    DateTime? date, {
    DateTime? today,
    bool reopening = false,
  }) {
    if (date == null) {
      if (!task.isRecurring) return task;
      if (reopening) {
        // To mark one not done: today's repetition if it is done, else the
        // latest one done.
        final todays = today == null ? null : task.occurrenceOn(today);
        if (todays != null && todays.isCompleted) return todays;
        final done = [...task.completedDates]..sort();
        for (final key in done.reversed) {
          if (task.completedOccurrence(key) case final shown?) return shown;
        }
        return task.nextOpenOccurrence() ?? task;
      }
      if (today != null) {
        final shown = task.occurrenceOn(today) ?? task.overdueOn(today);
        if (shown != null) return shown;
      }
      return task.nextOpenOccurrence() ?? task;
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

  /// `update`, `delete` and `complete`: the tasks [target] may mean, among
  /// those the person can edit, open ones first. A repeating task comes as
  /// the repetition meant; [completing] with no day said, today's (see
  /// [_shown]). [reopening] (`reopen`) looks for done ones first instead,
  /// and a repeating task with no day said comes as today's repetition if
  /// done, else its latest one done. Words, a project or a day are needed:
  /// with none, nothing is found.
  static List<Task> targets(
    Iterable<Task> tasks,
    CommandTarget target, {
    required bool Function(String? listId) canEdit,
    bool completing = false,
    bool reopening = false,
    DateTime? now,
  }) {
    if (target.projectName != null) return const [];
    if (_folded(target.words).isEmpty &&
        target.date == null &&
        target.listId == null) {
      return const [];
    }
    final today = completing || reopening
        ? Task.day(now ?? DateTime.now())
        : null;
    final found = <Task>[];
    for (final task in tasks) {
      if (task.isNote || !canEdit(task.listId)) continue;
      if (target.listId != null && task.listId != target.listId) continue;
      final shown = _shown(
        task,
        target.date,
        today: today,
        reopening: reopening,
      );
      if (shown != null) found.add(shown);
    }
    found.sort(_newestFirst);
    final best = _ranked(found, target.words, best: true);
    final preferred = best
        .where((task) => reopening ? _done(task) : !_done(task))
        .toList();
    return preferred.isNotEmpty ? preferred : best;
  }

  /// A repetition is done when it is completed; a repeating task shown as a
  /// whole, when none is left open.
  static bool _done(Task shown) =>
      shown.occurrenceDate != null ? shown.isCompleted : _completed(shown);

  /// A task as a command shows it is done: a repetition, or the task.
  static bool done(Task shown) => _done(shown);

  /// Whose tasks a set holds: the person's own (outside shared projects, or
  /// assigned to them in one); anyone's in the project named; or, with a
  /// person named, theirs.
  static bool _inSet(
    Task task,
    CommandTarget target,
    int? accountId,
    Iterable<TaskListInfo> projects,
  ) {
    final shared = projects.any((p) => p.id == task.listId && p.shared);
    bool assignedTo(int? id) =>
        task.assignment == 'member' && task.assigneeId == id;
    final mine = !shared || assignedTo(accountId);
    if (target.personId case final person?) {
      return person == accountId ? mine : assignedTo(person);
    }
    return target.listId != null || mine;
  }

  /// A repeating task left out of a set: it has a repetition in the period
  /// (between [first] and [last], a year at most) with the status asked.
  static bool _repeatsIn(
    Task task,
    CommandTarget target,
    DateTime? first,
    DateTime? last,
  ) {
    if (first == null && last == null) {
      return switch (target.status) {
        'completed' => task.completedDates.isNotEmpty,
        'any' => true,
        _ => !_completed(task),
      };
    }
    final start = Task.day(task.dueDate!);
    var day = first == null || first.isBefore(start) ? start : first;
    final end = last ?? DateTime(day.year, day.month, day.day + 366);
    for (var i = 0; i <= 366 && !day.isAfter(end); i++) {
      for (final shown in task.occurrencesOn(day)) {
        if (_hasStatus(shown.isCompleted, target.status)) return true;
      }
      day = DateTime(day.year, day.month, day.day + 1);
    }
    return false;
  }

  static bool _hasStatus(bool completed, String status) => switch (status) {
    'completed' => completed,
    'any' => true,
    _ => !completed,
  };

  /// A task's key on a set's card: the task, or the repetition.
  static String keyOf(Task shown) => shown.occurrenceId == null
      ? '${shown.id}'
      : '${shown.id}@${shown.occurrenceId}';

  /// A bulk command's set ([CommandTarget.all]; Backend/docs/VOICE_COMMANDS.md,
  /// «Bulk commands»), from the phone's own copy:
  /// - the person's own tasks and those assigned to them in shared projects;
  ///   other people's only with the project or the person named;
  /// - only tasks the person can edit, never notes; a project put away
  ///   (archived) only when it is the one named;
  /// - the status asked, `open` by default;
  /// - the period on the planned day, or the deadline's day without one; or
  ///   only the tasks with no day;
  /// - the words, as for `find`.
  ///
  /// Repeating tasks are left out and counted (`repeatingTasks` lists
  /// them), except when [completing] over one day: then each one's
  /// repetition on that day is in the set.
  ///
  /// «Hoy»: a pending set for exactly today ([now]'s day, as Calendar's)
  /// also takes the open tasks Today lists under «Atrasadas»
  /// ([Task.overdueOn]): a task from an earlier day, or a repeating task's
  /// latest missed repetition when [completing] (else that task is left out
  /// and counted, once). They come first, oldest first, as Today lists
  /// them, and `overdue` holds their keys ([keyOf]).
  ///
  /// The rest of the set comes soonest first, as Calendar lists it, the
  /// tasks with no day last. A project or person that wasn't found holds
  /// nothing.
  static ({
    List<Task> tasks,
    int repeating,
    List<Task> repeatingTasks,
    Task? viewOnly,
    Set<String> overdue,
  })
  bulk(
    Iterable<Task> tasks,
    CommandTarget target, {
    int? accountId,
    Iterable<TaskListInfo> projects = const [],
    bool completing = false,
    DateTime? now,
  }) {
    if (target.projectName != null || target.personName != null) {
      return (
        tasks: const [],
        repeating: 0,
        repeatingTasks: const [],
        viewOnly: null,
        overdue: const {},
      );
    }
    final first = target.from == null ? null : Task.day(target.from!);
    final last = target.to == null ? null : Task.day(target.to!);
    final oneDay = completing && first != null && first == last;
    final today = Task.day(now ?? DateTime.now());
    // «Hoy» takes what Today lists as overdue too (the owner's D2).
    final hoy =
        target.status == 'open' &&
        !target.undated &&
        first == today &&
        last == today;
    bool editable(String? id) =>
        id == null || projects.any((p) => p.id == id && p.canEdit);
    bool putAway(String? id) =>
        id != target.listId && projects.any((p) => p.id == id && p.inactive);
    final found = <(Task, _When?)>[];
    final overdue = <Task>[];
    final repeating = <Task>[];
    final viewOnly = <Task>[];
    for (final task in tasks) {
      if (task.isNote || putAway(task.listId)) continue;
      if (target.listId != null && task.listId != target.listId) continue;
      if (!_inSet(task, target, accountId, projects)) continue;
      final edit = editable(task.listId);
      final missed = hoy ? task.overdueOn(today) : null;
      if (task.isRecurring) {
        if (target.undated) continue;
        if (oneDay) {
          final shownToday = task.occurrencesOn(first);
          for (final shown in shownToday) {
            if (!_hasStatus(shown.isCompleted, target.status)) continue;
            if (edit) {
              found.add((
                shown,
                (at: shown.displayDate!, timed: shown.hasTime),
              ));
            } else {
              viewOnly.add(shown);
            }
          }
          if (missed != null &&
              !shownToday.any((shown) => keyOf(shown) == keyOf(missed))) {
            (edit ? overdue : viewOnly).add(missed);
          }
        } else if (missed != null || _repeatsIn(task, target, first, last)) {
          (edit ? repeating : viewOnly).add(task);
        }
        continue;
      }
      if (missed != null) {
        (edit ? overdue : viewOnly).add(task);
        continue;
      }
      if (!_hasStatus(task.isCompleted, target.status)) continue;
      final planned = task.dueDate;
      final date = planned ?? task.deadline;
      if (target.undated && date != null) continue;
      _When? when;
      if (date != null) {
        final day = Task.day(date);
        if (first != null && day.isBefore(first)) continue;
        if (last != null && day.isAfter(last)) continue;
        when = (
          at: date,
          timed: planned != null ? task.hasTime : task.deadlineHasTime,
        );
      } else if (first != null || last != null) {
        continue;
      }
      if (edit) {
        found.add((task, when));
      } else {
        viewOnly.add(task);
      }
    }
    // The words, as a search keeps them: every word, or else the most.
    final kept = _ranked([
      ...overdue,
      for (final (task, _) in found) task,
      ...repeating,
      ...viewOnly,
    ], target.words).toSet();
    found
      ..removeWhere((item) => !kept.contains(item.$1))
      ..sort((a, b) {
        final (aWhen, bWhen) = (a.$2, b.$2);
        if (aWhen == null || bWhen == null) {
          if (aWhen != bWhen) return aWhen == null ? 1 : -1;
        } else {
          final order = _soonestFirst(aWhen, bWhen);
          if (order != 0) return order;
        }
        return _newestFirst(a.$1, b.$1);
      });
    // Oldest first, as Today lists its «Atrasadas».
    overdue
      ..removeWhere((task) => !kept.contains(task))
      ..sort((a, b) {
        final order = (a.displayDate ?? a.displayDeadline!).compareTo(
          b.displayDate ?? b.displayDeadline!,
        );
        return order != 0 ? order : _newestFirst(a, b);
      });
    final left = repeating.where(kept.contains).toList();
    return (
      tasks: [...overdue, for (final (task, _) in found) task],
      repeating: left.length,
      repeatingTasks: left,
      viewOnly: viewOnly.where(kept.contains).firstOrNull,
      overdue: {for (final task in overdue) keyOf(task)},
    );
  }
}
