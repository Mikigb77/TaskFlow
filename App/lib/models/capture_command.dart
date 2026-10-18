import 'package:uuid/uuid.dart';

/// What a dictation asked for besides tasks and notes: create a project, find
/// tasks, or change or delete one (Backend/docs/VOICE_COMMANDS.md). Commands
/// are data: the phone finds the tasks itself, and nothing is created,
/// changed or deleted until the person's tap.
enum CommandKind { project, find, update, delete }

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

/// Which existing task an update or a deletion is about.
class CommandTarget {
  const CommandTarget({
    this.words = const [],
    this.listId,
    this.projectName,
    this.date,
  });

  /// The distinctive words of the task, in the person's language.
  final List<String> words;

  /// The project named, resolved by the server.
  final String? listId;

  /// The project as said, when the server couldn't find it: then nothing is
  /// searched, and the card says so.
  final String? projectName;

  /// The task's current day, only when it was said.
  final DateTime? date;

  factory CommandTarget.fromJson(Object? json) {
    if (json is! Map) return const CommandTarget();
    return CommandTarget(
      words: _words(json['words']),
      listId: _text(json['list_id'], max: 64),
      projectName: _text(json['project_name'], max: 80),
      date: _day(json['date']),
    );
  }

  Map<String, dynamic> toJson() => {
    'words': words,
    'list_id': listId,
    'project_name': projectName,
    'date': date == null ? null : _dayKey(date!),
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

  bool has(String key) => values.containsKey(key);
  bool get isEmpty => values.isEmpty;

  String? get title => values['title'] as String?;

  /// The new day; null with [has] `date` takes the day away.
  DateTime? get date => _day(values['date']);

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
    this.series = false,
    this.choice,
    this.day,
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

  /// `update` and `delete`: which task, and what changes.
  final CommandTarget target;
  final TaskChanges changes;

  /// The card was taken out (✕): nothing happens for it.
  final bool removed;

  /// The confirming tap handled it: it was applied, or there was nothing to
  /// apply (a task that wasn't found).
  final bool done;

  /// The task chosen when several matched.
  final int? taskId;

  /// A repeating task's new day or time is for the whole series, not only
  /// this repetition.
  final bool series;

  /// `project` with two matching projects: `new` creates it, or the id of
  /// the existing project chosen instead.
  final String? choice;

  /// The day chosen for a new time on a task that has no day.
  final DateTime? day;

  static const createChoice = 'new';

  bool get ambiguous => issues.contains('ambiguous_project');

  /// A project that is already there: nothing to create.
  bool get existing =>
      kind == CommandKind.project &&
      (existingListId != null || (choice != null && choice != createChoice));

  /// Still waiting for the confirming tap. A search, and a project that is
  /// already there, never wait.
  bool get pending =>
      !removed &&
      !done &&
      kind != CommandKind.find &&
      !(kind == CommandKind.project && existingListId != null);

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
        );
      case CommandKind.update:
      case CommandKind.delete:
        return CaptureCommand(
          id: id,
          kind: kind,
          issues: issues,
          target: CommandTarget.fromJson(json['target']),
          changes: kind == CommandKind.update
              ? TaskChanges.fromJson(json['changes'])
              : const TaskChanges(),
        );
    }
  }

  CaptureCommand copyWith({
    bool? removed,
    bool? done,
    int? taskId,
    bool clearTaskId = false,
    bool? series,
    String? choice,
    bool clearChoice = false,
    DateTime? day,
    bool clearDay = false,
  }) => CaptureCommand(
    id: id,
    kind: kind,
    issues: issues,
    name: name,
    existingListId: existingListId,
    words: words,
    listId: listId,
    projectName: projectName,
    personId: personId,
    personName: personName,
    status: status,
    from: from,
    to: to,
    target: target,
    changes: changes,
    removed: removed ?? this.removed,
    done: done ?? this.done,
    taskId: clearTaskId ? null : taskId ?? this.taskId,
    series: series ?? this.series,
    choice: clearChoice ? null : choice ?? this.choice,
    day: clearDay ? null : day ?? this.day,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'kind': kind.name,
    'issues': issues,
    'name': name,
    'existingListId': existingListId,
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
    'series': series,
    'choice': choice,
    'day': day == null ? null : _dayKey(day!),
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
      series: json['series'] == true,
      choice: json['choice'] as String?,
      day: _day(json['day']),
    );
  }
}
