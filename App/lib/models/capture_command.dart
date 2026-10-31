import 'package:uuid/uuid.dart';

/// What a dictation asked for besides tasks and notes: create a project, find
/// tasks, or change, delete or complete one, or many at once
/// (Backend/docs/VOICE_COMMANDS.md). Commands are data: the phone finds the
/// tasks itself, and nothing is created, changed, completed or deleted until
/// the person's tap.
enum CommandKind { project, find, update, delete, complete }

/// A day as the server writes it, `YYYY-MM-DD`; null for anything else.
DateTime? _day(Object? value) {
  if (value is! String) return null;
  final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(value);
  if (match == null) return null;
  final year = int.parse(match[1]!);
  final month = int.parse(match[2]!);
  final day = int.parse(match[3]!);
  final date = DateTime(year, month, day);
  // 2026-02-31 is not a day.
  return date.year == year && date.month == month && date.day == day
      ? date
      : null;
}

String _dayKey(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

/// A clock time as the server writes it, `HH:MM` (24-hour).
bool _isClock(Object? value) =>
    value is String && RegExp(r'^([01]\d|2[0-3]):[0-5]\d$').hasMatch(value);

/// A piece of text: trimmed, with no more than [max] characters. A [line]
/// keeps no line breaks.
String? _text(Object? value, {int max = 160, bool line = true}) {
  if (value is! String) return null;
  final text = line
      ? value.trim().replaceAll(RegExp(r'\s+'), ' ')
      : value.trim();
  return text.isEmpty || text.length > max ? null : text;
}

int? _int(Object? value) => value is int ? value : null;

/// The words a task is looked for by: at most 8, each 1 to 60 characters.
List<String> _words(Object? value) => value is List
    ? [
        for (final item in value)
          if (_text(item, max: 60) case final word?) word,
      ].take(8).toList()
    : const [];

List<String> _strings(Object? value) => value is List
    ? value.whereType<String>().toList()
    : const [];

/// The ids of `project_candidates` (`[{id, name}]`), in the server's order:
/// at most [CaptureCommand.candidateLimit], each kept as `existing_list_id`
/// is, and one without an id left out.
List<String> _candidates(Object? value) {
  if (value is! List) return const [];
  final ids = <String>[];
  for (final candidate in value) {
    if (ids.length == CaptureCommand.candidateLimit) break;
    if (candidate is! Map) continue;
    final id = _text(candidate['id'], max: 64);
    if (id != null && !ids.contains(id)) ids.add(id);
  }
  return ids;
}

/// Leading words that only say "the project of": `el proyecto de química`.
/// An article alone stays: `La Caixa` is a name.
final _projectLead = RegExp(
  r"^(?:(?:el|the)\s+)?(?:proyecto|projecte|project)\s+(?:(?:de|del|of)\s+|d['’])?",
  caseSensitive: false,
);

/// A project's name as said, as the server writes a new one: without quotes
/// or a leading «el proyecto de», and with a capital first letter when it
/// was said all in lowercase (`química` → `Química`, `iPhone app` stays).
String spokenProjectName(String said) {
  var name = said.trim().replaceAll(RegExp('^["\'«»“”‘’]+|["\'«»“”‘’]+\$'), '');
  final stripped = name.replaceFirst(_projectLead, '').trim();
  if (stripped.isNotEmpty) name = stripped;
  return name.isNotEmpty && name == name.toLowerCase()
      ? name[0].toUpperCase() + name.substring(1)
      : name;
}

/// Which existing task an update, a deletion or a completion is about; with
/// [all], the set of tasks it is about («todas las tareas de ayer»).
class CommandTarget {
  const CommandTarget({
    this.words = const [],
    this.listId,
    this.projectName,
    this.date,
    this.all = false,
    this.personId,
    this.personName,
    this.status = 'open',
    this.from,
    this.to,
    this.undated = false,
    this.projectCandidates = const [],
  });

  /// The distinctive words of the task, in the person's language.
  final List<String> words;

  /// The project named, resolved by the server.
  final String? listId;

  /// The project as said, when the server couldn't find it: then nothing is
  /// searched, and the card says so.
  final String? projectName;

  /// With `ambiguous_project`: the ids of the projects that matched, best
  /// first, at most [CaptureCommand.candidateLimit], as the server sent
  /// them. The card offers them.
  final List<String> projectCandidates;

  /// The task's current day, only when it was said. Never with [all]: a day
  /// said for a set is its [from] and [to].
  final DateTime? date;

  /// Every task that matches, not one (decided 2026-10-21). The fields below
  /// are a set's, with `find`'s filters.
  final bool all;

  /// The person named: their tasks. [personName] only when they couldn't
  /// be resolved; then nothing is searched, and the card says so.
  final int? personId;
  final String? personName;

  /// `open` (the default), `completed` or `any`.
  final String status;

  /// An inclusive period on the task's planned day, or its deadline's day
  /// when it has none.
  final DateTime? from;
  final DateTime? to;

  /// Only the tasks with no day.
  final bool undated;

  factory CommandTarget.fromJson(Object? json) {
    if (json is! Map) return const CommandTarget();
    if (json['all'] != true) {
      return CommandTarget(
        words: _words(json['words']),
        listId: _text(json['list_id'], max: 64),
        projectName: _text(json['project_name'], max: 80),
        date: _day(json['date']),
        projectCandidates: _candidates(json['project_candidates']),
      );
    }
    var from = _day(json['from']);
    var to = _day(json['to']);
    // A day said for the set, sent in the wrong place, is its period.
    final day = _day(json['date']);
    if (from == null && to == null && day != null) from = to = day;
    if (from != null && to != null && from.isAfter(to)) (from, to) = (to, from);
    final undated = json['undated'] == true;
    final status = json['status'];
    return CommandTarget(
      all: true,
      words: _words(json['words']),
      listId: _text(json['list_id'], max: 64),
      projectName: _text(json['project_name'], max: 80),
      personId: _int(json['person_id']),
      personName: _text(json['person_name'], max: 120),
      status: status == 'completed' || status == 'any' ? status : 'open',
      from: undated ? null : from,
      to: undated ? null : to,
      undated: undated,
      projectCandidates: _candidates(json['project_candidates']),
    );
  }

  /// This target, as if the project [listId] had been said.
  CommandTarget withProject(String listId) => CommandTarget(
    words: words,
    listId: listId,
    date: date,
    all: all,
    personId: personId,
    personName: personName,
    status: status,
    from: from,
    to: to,
    undated: undated,
  );

  Map<String, dynamic> toJson() => {
    'words': words,
    'list_id': listId,
    'project_name': projectName,
    'date': date == null ? null : _dayKey(date!),
    // In the server's shape, so [CommandTarget.fromJson] reads it back.
    if (projectCandidates.isNotEmpty)
      'project_candidates': [
        for (final id in projectCandidates) {'id': id},
      ],
    if (all) ...{
      'all': true,
      'person_id': personId,
      'person_name': personName,
      'status': status,
      'from': from == null ? null : _dayKey(from!),
      'to': to == null ? null : _dayKey(to!),
      'undated': undated,
    },
  };
}

/// Only what the person asked to change. A key that is absent leaves that
/// field as it is; a null value takes it away (the day, the time, the
/// deadline, the assignee).
class TaskChanges {
  const TaskChanges([this.values = const {}]);
  final Map<String, Object?> values;

  /// The server's `changes`, keeping only the keys and values the contract
  /// allows: anything else is left out, so it changes nothing.
  factory TaskChanges.fromJson(Object? json) {
    if (json is! Map) return const TaskChanges();
    final values = <String, Object?>{};
    void day(String key) {
      if (!json.containsKey(key)) return;
      final value = json[key];
      if (value == null) {
        values[key] = null;
      } else if (_day(value) case final date?) {
        values[key] = _dayKey(date);
      }
    }

    void clock(String key) {
      if (!json.containsKey(key)) return;
      final value = json[key];
      if (value == null || _isClock(value)) values[key] = value;
    }

    if (_text(json['title']) case final title?) values['title'] = title;
    day('date');
    // Days to move by, keeping the time; a day said instead wins.
    final shift = json['shift_days'];
    if (!values.containsKey('date') &&
        shift is int &&
        shift != 0 &&
        shift.abs() <= maxShift) {
      values['shift_days'] = shift;
    }
    clock('time');
    day('deadline_date');
    clock('deadline_time');
    // Without a day there is no time.
    if (values.containsKey('date') && values['date'] == null) {
      values['time'] = null;
    }
    if (values.containsKey('deadline_date') &&
        values['deadline_date'] == null) {
      values['deadline_time'] = null;
    }
    final priority = json['priority'];
    if (priority is int && priority >= 1 && priority <= 3) {
      values['priority'] = priority;
    }
    if (_text(json['notes_append'], max: 2000, line: false)
        case final notes?) {
      values['notes_append'] = notes;
    }
    if (json.containsKey('assignee_id') || json.containsKey('assignee_name')) {
      final id = json['assignee_id'];
      final name = _text(json['assignee_name'], max: 120);
      if (id is int) {
        values['assignee_id'] = id;
        values['assignee_name'] = name;
      } else if (json.containsKey('assignee_id') &&
          id == null &&
          json['assignee_name'] == null) {
        // Nobody.
        values['assignee_id'] = null;
        values['assignee_name'] = null;
      } else if (name != null) {
        // A name that couldn't be resolved: the assignee stays.
        values['assignee_name'] = name;
      }
    }
    return TaskChanges(values);
  }

  /// The most days `shift_days` moves by, either way.
  static const maxShift = 366;

  bool has(String key) => values.containsKey(key);
  bool get isEmpty => values.isEmpty;

  /// These changes without [keys]: a set never takes a title or notes.
  TaskChanges without(Set<String> keys) => TaskChanges({
    for (final MapEntry(:key, :value) in values.entries)
      if (!keys.contains(key)) key: value,
  });

  /// These changes moved to [day], picked on the card as if it had been
  /// said: `date` is that day and `shift_days` goes; the rest stays, a
  /// `time` said included.
  TaskChanges movedTo(DateTime day) => TaskChanges({
    for (final MapEntry(:key, :value) in values.entries)
      if (key != 'shift_days') key: value,
    'date': _dayKey(day),
  });

  String? get title => values['title'] as String?;

  /// The new day; null with [has] `date` takes the day away.
  DateTime? get date => _day(values['date']);

  /// Days to move the task by, keeping its time: later when positive. A task
  /// with only a deadline moves its deadline.
  int? get shiftDays => values['shift_days'] as int?;

  /// The new time; null with [has] `time` takes it away.
  ({int hour, int minute})? get time => _clock(values['time']);

  DateTime? get deadlineDate => _day(values['deadline_date']);
  ({int hour, int minute})? get deadlineTime => _clock(values['deadline_time']);
  int? get priority => values['priority'] as int?;
  String? get notesAppend => values['notes_append'] as String?;

  /// Someone was named for the task: [assigneeId] when they were found (or
  /// null with [assignsNobody]), and only [assigneeName] when not.
  bool get assigns => has('assignee_id') || has('assignee_name');
  bool get assignsNobody =>
      has('assignee_id') && values['assignee_id'] == null;
  bool get hasUnresolved => !has('assignee_id') && has('assignee_name');
  int? get assigneeId => values['assignee_id'] as int?;
  String? get assigneeName => values['assignee_name'] as String?;

  static ({int hour, int minute})? _clock(Object? value) {
    if (!_isClock(value)) return null;
    final parts = (value as String).split(':');
    return (hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }

  Map<String, dynamic> toJson() => Map<String, dynamic>.from(values);
}

/// One command of a dictation's result, with the person's choices on its
/// card. Kept with the capture, so a result left for later comes back as it
/// was.
class CaptureCommand {
  const CaptureCommand({
    required this.id,
    required this.kind,
    this.issues = const [],
    this.name = '',
    this.existingListId,
    this.projectCandidates = const [],
    this.words = const [],
    this.listId,
    this.projectName,
    this.personId,
    this.personName,
    this.status = 'any',
    this.from,
    this.to,
    this.target = const CommandTarget(),
    this.changes = const TaskChanges(),
    this.removed = false,
    this.done = false,
    this.taskId,
    this.memberId,
    this.series = false,
    this.choice,
    this.day,
    this.excluded = const [],
  });

  /// This card's own id, for its state; never sent anywhere.
  final String id;
  final CommandKind kind;

  /// The contract's codes: `project_not_available`, `ambiguous_project`,
  /// `member_not_available`, `ambiguous_member`.
  final List<String> issues;

  /// `project`: the name as said, and the project the person can already
  /// edit that matches it.
  final String name;
  final String? existingListId;

  /// `project` and `find` with `ambiguous_project`: the ids of the projects
  /// that matched, best first, at most 3, as the server sent them.
  final List<String> projectCandidates;

  /// The candidates the server can send for one command.
  static const candidateLimit = 3;

  /// `find`: the words, the project, the person, the status (`any`, `open`
  /// or `completed`) and an inclusive period. [projectName] and
  /// [personName] are set only when they couldn't be resolved.
  final List<String> words;
  final String? listId;
  final String? projectName;
  final int? personId;
  final String? personName;
  final String status;
  final DateTime? from;
  final DateTime? to;

  /// `update`, `delete` and `complete`: which task, or which set of them,
  /// and what changes.
  final CommandTarget target;
  final TaskChanges changes;

  /// A set's tasks unticked on its card, by their key: they are left as
  /// they are.
  final List<String> excluded;

  /// It acts on a set of tasks, not one: a bulk command.
  bool get bulk =>
      target.all &&
      (kind == CommandKind.update ||
          kind == CommandKind.delete ||
          kind == CommandKind.complete);

  /// The card was taken out (✕): nothing happens for it.
  final bool removed;

  /// The confirming tap handled it: it was applied, or there was nothing to
  /// apply (a task that wasn't found).
  final bool done;

  /// The task chosen when several matched.
  final int? taskId;

  /// The person tapped when several have the name said for the assignee.
  final int? memberId;

  /// A repeating task's new day or time is for the whole series, not only
  /// this repetition.
  final bool series;

  /// `project` with two matching projects: `new` creates it, or the id of
  /// the existing project chosen instead. A search, change, deletion or
  /// completion whose project matched several: the id of the one tapped.
  final String? choice;

  /// The day chosen for a new time on a task that has no day.
  final DateTime? day;

  static const createChoice = 'new';

  bool get ambiguous => issues.contains('ambiguous_project');

  /// A project that is already there: nothing to create. A tap on its card
  /// decides it: `new` creates it even when the server matched one.
  bool get existing =>
      kind == CommandKind.project &&
      (choice == null ? existingListId != null : choice != createChoice);

  /// The project that is already there: the one tapped, or the one matched.
  String? get existingId => existing ? choice ?? existingListId : null;

  /// Still waiting for the confirming tap. A search, and a project that is
  /// already there, never wait.
  bool get pending =>
      !removed &&
      !done &&
      kind != CommandKind.find &&
      !(kind == CommandKind.project && existing);

  /// The card shows in the result.
  bool get shown => !removed && !done;

  /// The server's command, or null for a kind this app doesn't know, or one
  /// that doesn't fit the contract: it is left out, as if it wasn't said.
  static CaptureCommand? fromServer(Object? json) {
    if (json is! Map) return null;
    final kind = switch (json['kind']) {
      'project' => CommandKind.project,
      'find' => CommandKind.find,
      'update' => CommandKind.update,
      'delete' => CommandKind.delete,
      'complete' => CommandKind.complete,
      _ => null,
    };
    if (kind == null) return null;
    final id = const Uuid().v4();
    final issues = _strings(json['issues']);
    switch (kind) {
      case CommandKind.project:
        final name = _text(json['name'], max: 80);
        if (name == null) return null;
        return CaptureCommand(
          id: id,
          kind: kind,
          issues: issues,
          name: name,
          existingListId: _text(json['existing_list_id'], max: 64),
          projectCandidates: _candidates(json['project_candidates']),
        );
      case CommandKind.find:
        var from = _day(json['from']);
        var to = _day(json['to']);
        if (from != null && to != null && from.isAfter(to)) {
          (from, to) = (to, from);
        }
        final status = json['status'];
        return CaptureCommand(
          id: id,
          kind: kind,
          issues: issues,
          words: _words(json['words']),
          listId: _text(json['list_id'], max: 64),
          projectName: _text(json['project_name'], max: 80),
          personId: _int(json['person_id']),
          personName: _text(json['person_name'], max: 120),
          status: status == 'open' || status == 'completed' ? status : 'any',
          from: from,
          to: to,
          projectCandidates: _candidates(json['project_candidates']),
        );
      case CommandKind.update:
      case CommandKind.delete:
      case CommandKind.complete:
        final target = CommandTarget.fromJson(json['target']);
        final changes = kind == CommandKind.update
            ? TaskChanges.fromJson(json['changes'])
            : const TaskChanges();
        return CaptureCommand(
          id: id,
          kind: kind,
          issues: issues,
          target: target,
          // A set never takes a title or notes: the server drops them too.
          changes: target.all
              ? changes.without(const {'title', 'notes_append'})
              : changes,
        );
    }
  }

  CaptureCommand copyWith({
    String? name,
    bool? removed,
    bool? done,
    int? taskId,
    bool clearTaskId = false,
    int? memberId,
    bool? series,
    String? choice,
    bool clearChoice = false,
    DateTime? day,
    bool clearDay = false,
    List<String>? excluded,
    TaskChanges? changes,
  }) => CaptureCommand(
    id: id,
    kind: kind,
    issues: issues,
    name: name ?? this.name,
    existingListId: existingListId,
    projectCandidates: projectCandidates,
    words: words,
    listId: listId,
    projectName: projectName,
    personId: personId,
    personName: personName,
    status: status,
    from: from,
    to: to,
    target: target,
    changes: changes ?? this.changes,
    removed: removed ?? this.removed,
    done: done ?? this.done,
    taskId: clearTaskId ? null : taskId ?? this.taskId,
    memberId: memberId ?? this.memberId,
    series: series ?? this.series,
    choice: clearChoice ? null : choice ?? this.choice,
    day: clearDay ? null : day ?? this.day,
    excluded: excluded ?? this.excluded,
  );

  /// A search, change, deletion or completion as if the project [listId]
  /// had been said, for the one tapped among those that matched. The
  /// command as it came stays as it is.
  CaptureCommand withProject(String listId) => CaptureCommand(
    id: id,
    kind: kind,
    issues: [
      for (final issue in issues)
        if (issue != 'ambiguous_project') issue,
    ],
    words: words,
    listId: kind == CommandKind.find ? listId : this.listId,
    personId: personId,
    personName: personName,
    status: status,
    from: from,
    to: to,
    target: kind == CommandKind.find ? target : target.withProject(listId),
    changes: changes,
    removed: removed,
    done: done,
    taskId: taskId,
    memberId: memberId,
    series: series,
    day: day,
    excluded: excluded,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'kind': kind.name,
    'issues': issues,
    'name': name,
    'existingListId': existingListId,
    'projectCandidates': projectCandidates,
    'words': words,
    'listId': listId,
    'projectName': projectName,
    'personId': personId,
    'personName': personName,
    'status': status,
    'from': from == null ? null : _dayKey(from!),
    'to': to == null ? null : _dayKey(to!),
    'target': target.toJson(),
    'changes': changes.toJson(),
    'removed': removed,
    'done': done,
    'taskId': taskId,
    'memberId': memberId,
    'series': series,
    'choice': choice,
    'day': day == null ? null : _dayKey(day!),
    if (excluded.isNotEmpty) 'excluded': excluded,
  };

  /// A command kept with a capture. One this app version can't read is left
  /// out, as an unknown kind is.
  static CaptureCommand? fromJson(Map<String, dynamic> json) {
    final kind = CommandKind.values
        .where((value) => value.name == json['kind'])
        .firstOrNull;
    final id = json['id'];
    if (kind == null || id is! String) return null;
    return CaptureCommand(
      id: id,
      kind: kind,
      issues: _strings(json['issues']),
      name: json['name'] as String? ?? '',
      existingListId: json['existingListId'] as String?,
      projectCandidates: _strings(
        json['projectCandidates'],
      ).take(candidateLimit).toList(),
      words: _strings(json['words']),
      listId: json['listId'] as String?,
      projectName: json['projectName'] as String?,
      personId: _int(json['personId']),
      personName: json['personName'] as String?,
      status: json['status'] as String? ?? 'any',
      from: _day(json['from']),
      to: _day(json['to']),
      target: CommandTarget.fromJson(json['target']),
      changes: TaskChanges.fromJson(json['changes']),
      removed: json['removed'] == true,
      done: json['done'] == true,
      taskId: _int(json['taskId']),
      memberId: _int(json['memberId']),
      series: json['series'] == true,
      choice: json['choice'] as String?,
      day: _day(json['day']),
      excluded: _strings(json['excluded']),
    );
  }
}
