import 'dart:convert';
import 'package:agenda/models/task.dart';
import 'package:agenda/models/task_archive.dart';
import 'package:agenda/models/task_list_info.dart';
import 'package:uuid/uuid.dart';

/// A conservative project CSV migration. Unsupported schedules remain visible
/// in notes and the preview; importing never guesses a date or calls AI.
class TodoistImport {
  static TaskArchive parse(String text) {
    if (utf8.encode(text).length > TaskArchive.maxBytes) {
      throw const FormatException('Choose a file smaller than 32 MB.');
    }
    final rows = _csv(text.startsWith('\uFEFF') ? text.substring(1) : text);
    if (rows.isEmpty) throw const FormatException('This CSV is empty.');
    final header =
        rows.first.map((value) => value.trim().toUpperCase()).toList();
    if (!header.contains('TYPE') ||
        !header.contains('CONTENT') ||
        header.toSet().length != header.length) {
      throw const FormatException(
          'Choose a Todoist project CSV with TYPE and CONTENT columns.');
    }
    final id = const Uuid()
        .v5('6ba7b811-9dad-11d1-80b4-00c04fd430c8', 'taskflow:todoist:$text');
    final tasks = <ImportTask>[];
    final lists = <TaskListInfo>[];
    final warnings = <String>[
      'Todoist priorities 3 and 4 both become Low. Subtasks become separate tasks.',
      'Only ISO calendar dates and times with explicit timezone offsets are scheduled. Other date expressions are kept in notes for you to review.',
      'This creates personal copies. Assignments, files and sharing access are not transferred. Todoist project CSV exports may omit completed tasks.',
    ];
    String? listId;
    var acceptsComment = false;
    for (var index = 1; index < rows.length; index++) {
      if (rows[index].every((value) => value.trim().isEmpty)) continue;
      if (rows[index].length > header.length) {
        throw FormatException(
            'Row ${index + 1} has more fields than the header.');
      }
      final values = {
        for (var column = 0; column < header.length; column++)
          header[column]: column < rows[index].length ? rows[index][column] : ''
      };
      final type = values['TYPE']!.trim();
      final content = values['CONTENT']!.trim();
      final sourceId = const Uuid().v5(id, 'row:$index');
      if (type == 'section') {
        acceptsComment = false;
        listId = null;
        if (content.isEmpty || content.length > 80 || lists.length >= 1000) {
          warnings.add(
              'Row ${index + 1}: section name is invalid; its tasks will have no list.');
        } else {
          listId = sourceId;
          lists.add(TaskListInfo(id: listId, name: content));
          if (values['DESCRIPTION']?.trim().isNotEmpty == true) {
            warnings
                .add('Row ${index + 1}: list descriptions are not supported.');
          }
        }
        continue;
      }
      if (type == 'note' &&
          acceptsComment &&
          tasks.isNotEmpty &&
          tasks.last.task != null) {
        final previous = tasks.removeLast();
        final notes = [
          previous.task!.notes ?? '',
          content,
          values['DESCRIPTION'] ?? ''
        ].where((value) => value.isNotEmpty).join('\n\n');
        tasks.add(notes.length <= 8000
            ? ImportTask(
                sourceId: previous.sourceId,
                title: previous.title,
                task: previous.task!.copyWith(notes: notes),
                warnings: previous.warnings)
            : ImportTask(
                sourceId: previous.sourceId,
                title: previous.title,
                error: 'Task and comments exceed 8,000 note characters.'));
        continue;
      }
      if (type != 'task') {
        acceptsComment = false;
        warnings.add(
            'Row ${index + 1}: ${type == 'note' ? 'comment has no valid preceding task' : 'unsupported record type'}; it will be skipped.');
        continue;
      }
      if (tasks.length >= TaskArchive.maxTasks) {
        throw const FormatException('Choose a CSV with at most 5,000 tasks.');
      }
      acceptsComment = true;
      try {
        final rowWarnings = <String>[];
        final extraNotes = <String>[];
        final priority = int.tryParse(
            values['PRIORITY']?.trim().isNotEmpty == true
                ? values['PRIORITY']!.trim()
                : '1');
        if (priority == null || priority < 1 || priority > 4) {
          throw const FormatException('Priority must be 1–4.');
        }
        DateTime? date;
        var hasTime = false;
        final rawDate = values['DATE']?.trim() ?? '';
        if (rawDate.isNotEmpty) {
          try {
            final sample = TaskArchive.validatedTask({
              'title': 'Schedule',
              'priority': 1,
              if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(rawDate))
                'scheduled_date': rawDate
              else
                'due_date': rawDate
            });
            date = sample.dueDate;
            hasTime = sample.hasTime;
          } catch (_) {
            rowWarnings.add(
                'The original schedule needs review; this task will go to Inbox.');
            extraNotes.add(
                'Original schedule: $rawDate${values['TIMEZONE']?.isNotEmpty == true ? ' (${values['TIMEZONE']})' : ''}');
          }
        }
        final indent = int.tryParse(values['INDENT']?.trim().isNotEmpty == true
            ? values['INDENT']!.trim()
            : '1');
        if (indent == null || indent < 1 || indent > 4) {
          throw const FormatException('Indent must be 1–4.');
        }
        if (indent > 1) rowWarnings.add('Subtask nesting will be flattened.');
        if (RegExp(r'(^|\s)@\S+').hasMatch(content)) {
          rowWarnings.add('Inline @labels remain in the title.');
        }
        const handled = {
          'TYPE',
          'CONTENT',
          'DESCRIPTION',
          'PRIORITY',
          'INDENT',
          'DATE',
          'DATE_LANG',
          'TIMEZONE'
        };
        for (final entry in values.entries) {
          if (!handled.contains(entry.key) && entry.value.trim().isNotEmpty) {
            extraNotes
                .add('Original ${entry.key.toLowerCase()}: ${entry.value}');
            rowWarnings.add(
                '${entry.key.toLowerCase()} will be kept as text in notes.');
          }
        }
        final task = Task(
            title: content,
            priority: priority == 1
                ? 3
                : priority == 2
                    ? 2
                    : 1,
            dueDate: date,
            hasTime: hasTime,
            listId: listId,
            notes: [values['DESCRIPTION'] ?? '', ...extraNotes]
                .where((value) => value.isNotEmpty)
                .join('\n\n'));
        TaskArchive.validatedTask(task.toApi());
        tasks.add(ImportTask(
            sourceId: sourceId,
            title: content,
            task: task,
            warnings: rowWarnings));
      } on FormatException catch (error) {
        tasks.add(ImportTask(
            sourceId: sourceId, title: content, error: error.message));
      }
    }
    return TaskArchive(
        id: id,
        source: 'Todoist project CSV',
        lists: lists,
        tasks: tasks,
        warnings: warnings);
  }

  static List<List<String>> _csv(String text) {
    final result = <List<String>>[];
    var row = <String>[];
    var field = StringBuffer();
    var quoted = false;
    var closed = false;
    void endField() {
      row.add(field.toString());
      field = StringBuffer();
      closed = false;
    }

    for (var i = 0; i < text.length; i++) {
      final char = text[i];
      if (quoted) {
        if (char == '"') {
          if (i + 1 < text.length && text[i + 1] == '"') {
            field.write('"');
            i++;
          } else {
            quoted = false;
            closed = true;
          }
        } else {
          field.write(char);
        }
      } else if (char == ',') {
        endField();
      } else if (char == '\r' || char == '\n') {
        endField();
        result.add(row);
        row = [];
        if (char == '\r' && i + 1 < text.length && text[i + 1] == '\n') i++;
        if (result.length > 15001) {
          throw const FormatException('This CSV has too many records.');
        }
      } else if (char == '"' && field.isEmpty && !closed) {
        quoted = true;
      } else {
        if (closed || char == '"') {
          throw const FormatException('Malformed CSV quoting.');
        }
        field.write(char);
      }
    }
    if (quoted) {
      throw const FormatException('An unfinished quoted CSV field was found.');
    }
    if (field.isNotEmpty || row.isNotEmpty || closed) {
      endField();
      result.add(row);
    }
    return result;
  }
}
