import 'dart:convert';
import 'package:agenda/models/task.dart';
import 'package:agenda/models/task_list_info.dart';
import 'package:uuid/uuid.dart';

class ImportTask {
  final String sourceId;
  final Task? task;
  final String title;
  final List<String> warnings;
  final String? error;
  const ImportTask(
      {required this.sourceId,
      required this.title,
      this.task,
      this.warnings = const [],
      this.error});
}

/// Parsed, bounded data only. Parsing never writes tasks or opens attachments.
class TaskArchive {
  static const maxBytes = 32 * 1024 * 1024;
  static const maxTasks = 5000;
  static const format = 'taskflow';
  static const version = 2;
  final String id;
  final String source;
  final List<TaskListInfo> lists;
  final List<ImportTask> tasks;
  final List<String> warnings;
  const TaskArchive(
      {required this.id,
      required this.source,
      required this.lists,
      required this.tasks,
      this.warnings = const []});

  factory TaskArchive.parse(String contents) {
    if (utf8.encode(contents).length > maxBytes) {
      throw const FormatException('Choose a file smaller than 32 MB.');
    }
    final data = jsonDecode(contents);
    if (data is! Map ||
        data['format'] != format ||
        ![1, version].contains(data['version'])) {
      throw const FormatException(
          'This is not a supported TaskFlow export (versions 1 and 2).');
    }
    _uuid(data['export_id'], 'export_id');
    final rows = _list(data['tasks'], 'tasks', maxTasks);
    final rawLists = _list(data['lists'], 'lists', 1000);
    final lists = <TaskListInfo>[];
    final listIds = <String>{};
    for (final item in rawLists) {
      if (item is! Map) throw const FormatException('Invalid list metadata.');
      final id = _uuid(item['id'], 'list id');
      if (!listIds.add(id)) {
        throw const FormatException('Duplicate list identifiers.');
      }
      final name = _string(item['name'], 'list name', 80);
      if (!['teal', 'blue', 'violet', 'amber', 'rose']
              .contains(item['color']) ||
          item['archived'] is! bool) {
        throw const FormatException('Invalid list color or archive status.');
      }
      lists.add(TaskListInfo(
          id: id,
          name: name,
          color: item['color'],
          archived: item['archived']));
    }
    final tasks = <ImportTask>[];
    final ids = <String>{};
    for (var index = 0; index < rows.length; index++) {
      final row = rows[index];
      var title = 'Task ${index + 1}';
      var id = 'invalid-$index';
      try {
        if (row is! Map) throw const FormatException('Invalid task record.');
        id = _uuid(row['id'], 'task identifier');
        if (!ids.add(id)) {
          throw const FormatException('Duplicate task identifier.');
        }
        final values = Map<String, dynamic>.from(row)..remove('id');
        title = _string(values['title'], 'title', 160);
        final warnings = <String>[];
        final known = {
          ...Task(title: '', priority: 1).toApi().keys,
          'attachments'
        };
        if (values.keys.any((key) => !known.contains(key))) {
          warnings.add('Unrecognized task fields will be omitted.');
        }
        final attachments = values.remove('attachments');
        if (attachments != null && attachments is! List) {
          throw const FormatException('Invalid attachment information.');
        }
        if (attachments is List && attachments.isNotEmpty) {
          warnings
              .add('${attachments.length} attachment files are not included.');
        }
        final task = validatedTask(values);
        if (task.listId != null && !listIds.contains(task.listId)) {
          throw const FormatException(
              'The task refers to a list missing from this file.');
        }
        tasks.add(ImportTask(
            sourceId: id, title: title, task: task, warnings: warnings));
      } on FormatException catch (error) {
        tasks.add(ImportTask(sourceId: id, title: title, error: error.message));
      } catch (_) {
        tasks.add(ImportTask(
            sourceId: id, title: title, error: 'Invalid task fields.'));
      }
    }
    return TaskArchive(
        id: data['export_id'],
        source: 'TaskFlow export',
        lists: lists,
        tasks: tasks,
        warnings: const [
          'Imports create new personal copies. Account access, files, notification preferences and unfinished captures are not included.'
        ]);
  }

  static Task validatedTask(Map<String, dynamic> data) {
    if (!['task', 'note'].contains(data['kind'] ?? 'task')) {
      throw const FormatException('Unsupported task or note type.');
    }
    _string(data['title'], 'title', 160);
    _string(data['notes'] ?? '', 'notes', 8000, blank: true);
    _integer(data['priority'], 'priority', 1, 3);
    if (data['is_completed'] != null && data['is_completed'] is! bool) {
      throw const FormatException('Invalid completion status.');
    }
    final timed = data['due_date'];
    final dated = data['scheduled_date'];
    if (timed != null) _timed(timed);
    if (dated != null) _date(dated);
    if (timed != null && dated != null) {
      throw const FormatException('A task cannot have two schedules.');
    }
    if (data['deadline_at'] != null) _timed(data['deadline_at']);
    if (data['deadline_date'] != null) _date(data['deadline_date']);
    if (data['deadline_at'] != null && data['deadline_date'] != null) {
      throw const FormatException('Choose a timed or date-only deadline.');
    }
    if (data['duration_minutes'] != null) {
      _integer(data['duration_minutes'], 'duration', 1, 1440);
    }
    final anchor = data['reminder_anchor'] ?? 'planned';
    if (!['planned', 'deadline'].contains(anchor) ||
        (anchor == 'deadline' &&
            data['deadline_at'] == null &&
            data['deadline_date'] == null)) {
      throw const FormatException('Choose an available reminder date.');
    }
    final recurrence = data['recurrence'] ?? 'none';
    if (!Task.repeats.containsKey(recurrence)) {
      throw const FormatException('Unsupported repeat rule.');
    }
    final interval =
        _integer(data['repeat_interval'] ?? 1, 'repeat interval', 1, 99);
    final days = _list(data['repeat_weekdays'] ?? [], 'repeat weekdays', 7);
    for (final day in days) {
      _integer(day, 'weekday', 1, 7);
    }
    if (days.isNotEmpty && recurrence != 'weekly') {
      throw const FormatException('Weekdays require a weekly repeat.');
    }
    if (recurrence != 'none' && timed == null && dated == null) {
      throw const FormatException('A repeating task needs a start date.');
    }
    if (data['repeat_until'] != null) _date(data['repeat_until']);
    final completed =
        _list(data['completed_dates'] ?? [], 'completed dates', 10000);
    for (final date in completed) {
      _date(date);
    }
    final exceptions =
        _list(data['exceptions'] ?? [], 'individual date changes', 500);
    final originalDates = <String>{};
    for (final change in exceptions) {
      if (change is! Map) {
        throw const FormatException('Invalid occurrence change.');
      }
      _date(change['original_date']);
      if (!originalDates.add(change['original_date'])) {
        throw const FormatException('Duplicate occurrence changes.');
      }
      if (change['skipped'] is! bool) {
        throw const FormatException('Invalid skipped date.');
      }
      final due = change['due_date'];
      final day = change['scheduled_date'];
      if (due != null) _timed(due);
      if (day != null) _date(day);
      if (change['skipped']
          ? (due != null || day != null)
          : (due == null) == (day == null)) {
        throw const FormatException('Invalid occurrence schedule.');
      }
    }
    if (recurrence == 'none' &&
        (interval != 1 ||
            data['repeat_until'] != null ||
            completed.isNotEmpty ||
            exceptions.isNotEmpty)) {
      throw const FormatException('Repeat settings need a repeating task.');
    }
    if (recurrence != 'none' && data['is_completed'] == true) {
      throw const FormatException(
          'Repeating tasks use individual completed dates.');
    }
    if (data['list_id'] != null) _uuid(data['list_id'], 'list identifier');
    for (final label in _list(data['labels'] ?? [], 'labels', 10)) {
      _string(label, 'label', 32);
    }
    final checklistIds = <String>{};
    for (final item in _list(data['checklist'] ?? [], 'checklist', 50)) {
      if (item is! Map) throw const FormatException('Invalid checklist item.');
      final id = _uuid(item['id'], 'checklist identifier');
      if (!checklistIds.add(id)) {
        throw const FormatException('Duplicate checklist identifiers.');
      }
      _string(item['title'], 'checklist title', 160);
      if (item['completed'] != null && item['completed'] is! bool) {
        throw const FormatException('Invalid checklist progress.');
      }
      for (final date
          in _list(item['completed_dates'] ?? [], 'checklist dates', 10000)) {
        _date(date);
      }
    }
    if (data['reminder_minutes'] != null) {
      _integer(data['reminder_minutes'], 'reminder lead', -1, 10080);
    }
    if (data['reminder_time'] != null) {
      _integer(data['reminder_time'], 'reminder time', 0, 1439);
    }
    final task = Task.fromApi(data);
    if (task.repeatUntil != null &&
        Task.day(task.repeatUntil!).isBefore(Task.day(task.dueDate!))) {
      throw const FormatException('Repeat end precedes the start.');
    }
    for (final change in task.exceptions) {
      if (!task.isBaseOccurrence(DateTime.parse(change.originalDate))) {
        throw const FormatException(
            'An occurrence change is outside this repeat rule.');
      }
    }
    return task;
  }

  static String encode(
      List<Map<String, dynamic>> rows, List<TaskListInfo> lists,
      {Map<int, List<String>> attachmentNames = const {}}) {
    final data = <String, dynamic>{
      'format': format,
      'version': version,
      'export_id': const Uuid().v4(),
      'created_at': DateTime.now().toUtc().toIso8601String(),
      'lists': lists
          .map((list) => {
                'id': list.id,
                'name': list.name,
                'color': list.color,
                'archived': list.archived
              })
          .toList(),
      'tasks': rows.map((row) {
        final task = Task.fromMap(row);
        return {
          'id': row['sync_id'] ?? const Uuid().v4(),
          ...task.toApi(),
          'attachments': attachmentNames[row['id']] ??
              [...task.filePaths, ...task.imagePaths]
                  .map((path) => path.replaceAll('\\', '/').split('/').last)
                  .toList()
        };
      }).toList(),
    };
    final contents = const JsonEncoder.withIndent('  ').convert(data);
    if (rows.length > maxTasks ||
        lists.length > 1000 ||
        utf8.encode(contents).length > maxBytes) {
      throw const FormatException(
          'This export exceeds the supported 32 MB or 5,000-task limit.');
    }
    return contents;
  }

  static List _list(Object? value, String name, int limit) {
    if (value is! List || value.length > limit) {
      throw FormatException('Invalid $name (maximum $limit).');
    }
    return value;
  }

  static String _string(Object? value, String name, int limit,
      {bool blank = false}) {
    if (value is! String ||
        value.length > limit ||
        (!blank && value.trim().isEmpty)) {
      throw FormatException('Invalid $name (maximum $limit characters).');
    }
    return value;
  }

  static int _integer(Object? value, String name, int min, int max) {
    if (value is! int || value < min || value > max) {
      throw FormatException('Invalid $name ($min–$max).');
    }
    return value;
  }

  static String _uuid(Object? value, String name) {
    if (value is! String ||
        !RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$')
            .hasMatch(value)) {
      throw FormatException('Invalid $name.');
    }
    return value;
  }

  static DateTime _date(Object? value) {
    if (value is! String || !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) {
      throw const FormatException('Dates must use YYYY-MM-DD.');
    }
    final parsed = DateTime.tryParse(value);
    if (parsed == null || Task.dateKey(parsed) != value) {
      throw const FormatException('Invalid calendar date.');
    }
    return parsed;
  }

  static DateTime _timed(Object? value) {
    if (value is! String ||
        !RegExp(r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d+)?(Z|[+-]\d{2}:\d{2})$')
            .hasMatch(value)) {
      throw const FormatException(
          'Timed dates need an ISO time and timezone offset.');
    }
    _date(value.substring(0, 10));
    if (int.parse(value.substring(11, 13)) > 23 ||
        int.parse(value.substring(14, 16)) > 59 ||
        int.parse(value.substring(17, 19)) > 59) {
      throw const FormatException('Invalid clock time.');
    }
    if (!value.endsWith('Z')) {
      final offset = value.substring(value.length - 5);
      if (int.parse(offset.substring(0, 2)) > 23 ||
          int.parse(offset.substring(3, 5)) > 59) {
        throw const FormatException('Invalid timezone offset.');
      }
    }
    final parsed = DateTime.tryParse(value);
    if (parsed == null) throw const FormatException('Invalid timed date.');
    return parsed;
  }
}
