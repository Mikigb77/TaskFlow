import 'package:agenda/models/archive_diagnostic.dart';
import 'dart:convert';
import 'package:agenda/models/task.dart';
import 'package:agenda/models/task_list_info.dart';
import 'package:uuid/uuid.dart';

enum ArchiveSource { taskflow, todoist }

class ImportTask {
  final String sourceId;
  final Task? task;
  final String title;
  final List<ArchiveDiagnostic> warnings;
  final ArchiveDiagnostic? error;
  const ImportTask({
    required this.sourceId,
    required this.title,
    this.task,
    this.warnings = const [],
    this.error,
  });
}

/// Parsed, bounded data only. Parsing never writes tasks or opens attachments.
class TaskArchive {
  static const maxBytes = 32 * 1024 * 1024;
  static const maxTasks = 5000;
  static const format = 'taskflow';
  static const version = 2;
  final String id;
  final ArchiveSource source;
  final List<TaskListInfo> lists;
  final List<ImportTask> tasks;
  final List<ArchiveDiagnostic> warnings;
  const TaskArchive({
    required this.id,
    required this.source,
    required this.lists,
    required this.tasks,
    this.warnings = const [],
  });

  factory TaskArchive.parse(String contents) {
    if (utf8.encode(contents).length > maxBytes) {
      throw const ArchiveDiagnostic(ArchiveCode.fileTooLarge);
    }
    final data = jsonDecode(contents);
    if (data is! Map ||
        data['format'] != format ||
        ![1, version].contains(data['version'])) {
      throw const ArchiveDiagnostic(ArchiveCode.unsupportedArchive);
    }
    _uuid(data['export_id'], 'export_id');
    final rows = _list(data['tasks'], 'tasks', maxTasks);
    final rawLists = _list(data['lists'], 'lists', 1000);
    final lists = <TaskListInfo>[];
    final listIds = <String>{};
    for (final item in rawLists) {
      if (item is! Map) throw const ArchiveDiagnostic(ArchiveCode.invalidList);
      final id = _uuid(item['id'], 'list id');
      if (!listIds.add(id)) {
        throw const ArchiveDiagnostic(ArchiveCode.duplicateLists);
      }
      final name = _string(item['name'], 'list name', 80);
      if (![
            'teal',
            'blue',
            'violet',
            'amber',
            'rose',
          ].contains(item['color']) ||
          item['archived'] is! bool) {
        throw const ArchiveDiagnostic(ArchiveCode.invalidListStyle);
      }
      lists.add(
        TaskListInfo(
          id: id,
          name: name,
          color: item['color'],
          archived: item['archived'],
        ),
      );
    }
    final tasks = <ImportTask>[];
    final ids = <String>{};
    for (var index = 0; index < rows.length; index++) {
      final row = rows[index];
      var title = '';
      var id = 'invalid-$index';
      try {
        if (row is! Map) throw const ArchiveDiagnostic(ArchiveCode.invalidTask);
        id = _uuid(row['id'], 'task identifier');
        if (!ids.add(id)) {
          throw const ArchiveDiagnostic(ArchiveCode.duplicateTask);
        }
        final values = Map<String, dynamic>.from(row)..remove('id');
        title = _string(values['title'], 'title', 160);
        final warnings = <ArchiveDiagnostic>[];
        final known = {
          ...Task(title: '', priority: 1).toApi().keys,
          'attachments',
        };
        if (values.keys.any((key) => !known.contains(key))) {
          warnings.add(const ArchiveDiagnostic(ArchiveCode.unknownFields));
        }
        final attachments = values.remove('attachments');
        if (attachments != null && attachments is! List) {
          throw const ArchiveDiagnostic(ArchiveCode.invalidAttachments);
        }
        if (attachments is List && attachments.isNotEmpty) {
          warnings.add(
            ArchiveDiagnostic(
              ArchiveCode.attachmentsOmitted,
              count: attachments.length,
            ),
          );
        }
        final task = validatedTask(values);
        if (task.listId != null && !listIds.contains(task.listId)) {
          throw const ArchiveDiagnostic(ArchiveCode.missingList);
        }
        tasks.add(
          ImportTask(
            sourceId: id,
            title: title,
            task: task,
            warnings: warnings,
          ),
        );
      } on FormatException catch (error) {
        tasks.add(
          ImportTask(
            sourceId: id,
            title: title,
            error: error is ArchiveDiagnostic
                ? error
                : const ArchiveDiagnostic(ArchiveCode.invalidTaskFields),
          ),
        );
      } catch (_) {
        tasks.add(
          ImportTask(
            sourceId: id,
            title: title,
            error: const ArchiveDiagnostic(ArchiveCode.invalidTaskFields),
          ),
        );
      }
    }
    return TaskArchive(
      id: data['export_id'],
      source: ArchiveSource.taskflow,
      lists: lists,
      tasks: tasks,
      warnings: const [ArchiveDiagnostic(ArchiveCode.personalCopies)],
    );
  }

  static Task validatedTask(Map<String, dynamic> data) {
    if (!['task', 'note'].contains(data['kind'] ?? 'task')) {
      throw const ArchiveDiagnostic(ArchiveCode.unsupportedKind);
    }
    _string(data['title'], 'title', 160);
    _string(data['notes'] ?? '', 'notes', 8000, blank: true);
    _integer(data['priority'], 'priority', 1, 3);
    if (data['is_completed'] != null && data['is_completed'] is! bool) {
      throw const ArchiveDiagnostic(ArchiveCode.invalidCompletion);
    }
    final timed = data['due_date'];
    final dated = data['scheduled_date'];
    if (timed != null) _timed(timed);
    if (dated != null) _date(dated);
    if (timed != null && dated != null) {
      throw const ArchiveDiagnostic(ArchiveCode.twoSchedules);
    }
    if (data['deadline_at'] != null) _timed(data['deadline_at']);
    if (data['deadline_date'] != null) _date(data['deadline_date']);
    if (data['deadline_at'] != null && data['deadline_date'] != null) {
      throw const ArchiveDiagnostic(ArchiveCode.twoDeadlines);
    }
    if (data['duration_minutes'] != null) {
      _integer(data['duration_minutes'], 'duration', 1, 1440);
    }
    final anchor = data['reminder_anchor'] ?? 'planned';
    if (!['planned', 'deadline'].contains(anchor) ||
        (anchor == 'deadline' &&
            data['deadline_at'] == null &&
            data['deadline_date'] == null)) {
      throw const ArchiveDiagnostic(ArchiveCode.invalidReminderDate);
    }
    final recurrence = data['recurrence'] ?? 'none';
    if (!Task.repeats.containsKey(recurrence)) {
      throw const ArchiveDiagnostic(ArchiveCode.unsupportedRepeat);
    }
    final interval = _integer(
      data['repeat_interval'] ?? 1,
      'repeat interval',
      1,
      99,
    );
    final days = _list(data['repeat_weekdays'] ?? [], 'repeat weekdays', 7);
    for (final day in days) {
      _integer(day, 'weekday', 1, 7);
    }
    if (days.isNotEmpty && recurrence != 'weekly') {
      throw const ArchiveDiagnostic(ArchiveCode.weekdaysNeedWeekly);
    }
    if (recurrence != 'none' && timed == null && dated == null) {
      throw const ArchiveDiagnostic(ArchiveCode.repeatNeedsStart);
    }
    if (data['repeat_until'] != null) _date(data['repeat_until']);
    final completed = _list(
      data['completed_dates'] ?? [],
      'completed dates',
      10000,
    );
    for (final date in completed) {
      _date(date);
    }
    final exceptions = _list(
      data['exceptions'] ?? [],
      'individual date changes',
      500,
    );
    final originalDates = <String>{};
    for (final change in exceptions) {
      if (change is! Map) {
        throw const ArchiveDiagnostic(ArchiveCode.invalidOccurrence);
      }
      _date(change['original_date']);
      if (!originalDates.add(change['original_date'])) {
        throw const ArchiveDiagnostic(ArchiveCode.duplicateOccurrence);
      }
      if (change['skipped'] is! bool) {
        throw const ArchiveDiagnostic(ArchiveCode.invalidSkipped);
      }
      final due = change['due_date'];
      final day = change['scheduled_date'];
      if (due != null) _timed(due);
      if (day != null) _date(day);
      if (change['skipped']
          ? (due != null || day != null)
          : (due == null) == (day == null)) {
        throw const ArchiveDiagnostic(ArchiveCode.invalidOccurrenceSchedule);
      }
    }
    if (recurrence == 'none' &&
        (interval != 1 ||
            data['repeat_until'] != null ||
            completed.isNotEmpty ||
            exceptions.isNotEmpty)) {
      throw const ArchiveDiagnostic(ArchiveCode.repeatSettingsNeedRepeat);
    }
    if (recurrence != 'none' && data['is_completed'] == true) {
      throw const ArchiveDiagnostic(ArchiveCode.repeatUsesCompletedDates);
    }
    if (data['list_id'] != null) _uuid(data['list_id'], 'list identifier');
    for (final label in _list(data['labels'] ?? [], 'labels', 10)) {
      _string(label, 'label', 32);
    }
    final checklistIds = <String>{};
    for (final item in _list(data['checklist'] ?? [], 'checklist', 50)) {
      if (item is! Map) {
        throw const ArchiveDiagnostic(ArchiveCode.invalidChecklist);
      }
      final id = _uuid(item['id'], 'checklist identifier');
      if (!checklistIds.add(id)) {
        throw const ArchiveDiagnostic(ArchiveCode.duplicateChecklist);
      }
      _string(item['title'], 'checklist title', 160);
      if (item['completed'] != null && item['completed'] is! bool) {
        throw const ArchiveDiagnostic(ArchiveCode.invalidChecklistProgress);
      }
      for (final date in _list(
        item['completed_dates'] ?? [],
        'checklist dates',
        10000,
      )) {
        _date(date);
      }
    }
    if (data['reminder_minutes'] != null) {
      _integer(data['reminder_minutes'], 'reminder lead', -1, 10080);
    }
    if (data['reminder_time'] != null) {
      _integer(data['reminder_time'], 'reminder time', 0, 1439);
    }
    final task = Task.fromApi({
      ...data,
      'assignment': 'personal',
      'assignee_id': null,
      'assignee_name': null,
      'created_by': null,
    });
    if (task.repeatUntil != null &&
        Task.day(task.repeatUntil!).isBefore(Task.day(task.dueDate!))) {
      throw const ArchiveDiagnostic(ArchiveCode.repeatEndBeforeStart);
    }
    for (final change in task.exceptions) {
      if (!task.isBaseOccurrence(DateTime.parse(change.originalDate))) {
        throw const ArchiveDiagnostic(ArchiveCode.occurrenceOutsideRepeat);
      }
    }
    return task;
  }

  static String encode(
    List<Map<String, dynamic>> rows,
    List<TaskListInfo> lists, {
    Map<int, List<String>> attachmentNames = const {},
  }) {
    final data = <String, dynamic>{
      'format': format,
      'version': version,
      'export_id': const Uuid().v4(),
      'created_at': DateTime.now().toUtc().toIso8601String(),
      'lists': lists
          .map(
            (list) => {
              'id': list.id,
              'name': list.name,
              'color': list.color,
              'archived': list.archived,
            },
          )
          .toList(),
      'tasks': rows.map((row) {
        final task = Task.fromMap(row);
        return {
          'id': row['sync_id'] ?? const Uuid().v4(),
          ...task
              .copyWith(
                assignment: 'personal',
                assigneeId: null,
                assigneeName: null,
                createdBy: null,
              )
              .toApi(),
          'attachments':
              attachmentNames[row['id']] ??
              [...task.filePaths, ...task.imagePaths]
                  .map((path) => path.replaceAll('\\', '/').split('/').last)
                  .toList(),
        };
      }).toList(),
    };
    final contents = const JsonEncoder.withIndent('  ').convert(data);
    if (rows.length > maxTasks ||
        lists.length > 1000 ||
        utf8.encode(contents).length > maxBytes) {
      throw const ArchiveDiagnostic(ArchiveCode.exportTooLarge);
    }
    return contents;
  }

  static List _list(Object? value, String name, int limit) {
    if (value is! List || value.length > limit) {
      throw ArchiveDiagnostic(
        ArchiveCode.invalidCollection,
        field: name,
        max: limit,
      );
    }
    return value;
  }

  static String _string(
    Object? value,
    String name,
    int limit, {
    bool blank = false,
  }) {
    if (value is! String ||
        value.length > limit ||
        (!blank && value.trim().isEmpty)) {
      throw ArchiveDiagnostic(ArchiveCode.invalidText, field: name, max: limit);
    }
    return value;
  }

  static int _integer(Object? value, String name, int min, int max) {
    if (value is! int || value < min || value > max) {
      throw ArchiveDiagnostic(
        ArchiveCode.invalidInteger,
        field: name,
        min: min,
        max: max,
      );
    }
    return value;
  }

  static String _uuid(Object? value, String name) {
    if (value is! String ||
        !RegExp(
          r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
        ).hasMatch(value)) {
      throw ArchiveDiagnostic(ArchiveCode.invalidIdentifier, field: name);
    }
    return value;
  }

  static DateTime _date(Object? value) {
    if (value is! String || !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) {
      throw const ArchiveDiagnostic(ArchiveCode.invalidDateFormat);
    }
    final parsed = DateTime.tryParse(value);
    if (parsed == null || Task.dateKey(parsed) != value) {
      throw const ArchiveDiagnostic(ArchiveCode.invalidDate);
    }
    return parsed;
  }

  static DateTime _timed(Object? value) {
    if (value is! String ||
        !RegExp(
          r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d+)?(Z|[+-]\d{2}:\d{2})$',
        ).hasMatch(value)) {
      throw const ArchiveDiagnostic(ArchiveCode.missingTimezone);
    }
    _date(value.substring(0, 10));
    if (int.parse(value.substring(11, 13)) > 23 ||
        int.parse(value.substring(14, 16)) > 59 ||
        int.parse(value.substring(17, 19)) > 59) {
      throw const ArchiveDiagnostic(ArchiveCode.invalidClock);
    }
    if (!value.endsWith('Z')) {
      final offset = value.substring(value.length - 5);
      if (int.parse(offset.substring(0, 2)) > 23 ||
          int.parse(offset.substring(3, 5)) > 59) {
        throw const ArchiveDiagnostic(ArchiveCode.invalidOffset);
      }
    }
    final parsed = DateTime.tryParse(value);
    if (parsed == null) {
      throw const ArchiveDiagnostic(ArchiveCode.invalidTimedDate);
    }
    return parsed;
  }
}
