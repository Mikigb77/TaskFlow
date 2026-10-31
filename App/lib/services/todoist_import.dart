import 'package:agenda/models/archive_diagnostic.dart';
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
      throw const ArchiveDiagnostic(ArchiveCode.fileTooLarge);
    }
    final rows = _csv(text.startsWith('\uFEFF') ? text.substring(1) : text);
    if (rows.isEmpty) throw const ArchiveDiagnostic(ArchiveCode.emptyCsv);
    final header =
        rows.first.map((value) => value.trim().toUpperCase()).toList();
    if (!header.contains('TYPE') ||
        !header.contains('CONTENT') ||
        header.toSet().length != header.length) {
      throw const ArchiveDiagnostic(ArchiveCode.csvHeader);
    }
    final id = const Uuid()
        .v5('6ba7b811-9dad-11d1-80b4-00c04fd430c8', 'taskflow:todoist:$text');
    final tasks = <ImportTask>[];
    final lists = <TaskListInfo>[];
    final warnings = <ArchiveDiagnostic>[
      const ArchiveDiagnostic(ArchiveCode.csvPriorities),
      const ArchiveDiagnostic(ArchiveCode.csvDates),
      const ArchiveDiagnostic(ArchiveCode.csvPersonalCopies),
    ];
    String? listId;
    var acceptsComment = false;
    for (var index = 1; index < rows.length; index++) {
      if (rows[index].every((value) => value.trim().isEmpty)) continue;
      if (rows[index].length > header.length) {
        throw ArchiveDiagnostic(ArchiveCode.csvExtraFields, row: index + 1);
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
              ArchiveDiagnostic(ArchiveCode.csvInvalidSection, row: index + 1));
        } else {
          listId = sourceId;
          lists.add(TaskListInfo(id: listId, name: content));
          if (values['DESCRIPTION']?.trim().isNotEmpty == true) {
            warnings.add(ArchiveDiagnostic(ArchiveCode.csvListDescription,
                row: index + 1));
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
                error: const ArchiveDiagnostic(ArchiveCode.notesTooLong)));
        continue;
      }
      if (type != 'task') {
        acceptsComment = false;
        warnings.add(ArchiveDiagnostic(
            type == 'note'
                ? ArchiveCode.csvOrphanComment
                : ArchiveCode.csvUnsupportedRow,
            row: index + 1));
        continue;
      }
      if (tasks.length >= TaskArchive.maxTasks) {
        throw const ArchiveDiagnostic(ArchiveCode.csvTaskLimit);
      }
      acceptsComment = true;
      try {
        final rowWarnings = <ArchiveDiagnostic>[];
        final extraNotes = <String>[];
        final priority = int.tryParse(
            values['PRIORITY']?.trim().isNotEmpty == true
                ? values['PRIORITY']!.trim()
                : '1');
        if (priority == null || priority < 1 || priority > 4) {
          throw const ArchiveDiagnostic(ArchiveCode.csvPriority);
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
            rowWarnings
                .add(const ArchiveDiagnostic(ArchiveCode.reviewSchedule));
            extraNotes.add(
                'Original schedule: $rawDate${values['TIMEZONE']?.isNotEmpty == true ? ' (${values['TIMEZONE']})' : ''}');
          }
        }
        final indent = int.tryParse(values['INDENT']?.trim().isNotEmpty == true
            ? values['INDENT']!.trim()
            : '1');
        if (indent == null || indent < 1 || indent > 4) {
          throw const ArchiveDiagnostic(ArchiveCode.csvIndent);
        }
        if (indent > 1) {
          rowWarnings
              .add(const ArchiveDiagnostic(ArchiveCode.flattenedSubtasks));
        }
        if (RegExp(r'(^|\s)@\S+').hasMatch(content)) {
          rowWarnings.add(const ArchiveDiagnostic(ArchiveCode.inlineLabels));
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
            rowWarnings.add(ArchiveDiagnostic(ArchiveCode.csvFieldInNotes,
                field: entry.key.toLowerCase()));
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
            sourceId: sourceId,
            title: content,
            error: error is ArchiveDiagnostic
                ? error
                : const ArchiveDiagnostic(ArchiveCode.invalidTaskFields)));
      }
    }
    return TaskArchive(
        id: id,
        source: ArchiveSource.todoist,
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
          throw const ArchiveDiagnostic(ArchiveCode.csvRecordLimit);
        }
      } else if (char == '"' && field.isEmpty && !closed) {
        quoted = true;
      } else {
        if (closed || char == '"') {
          throw const ArchiveDiagnostic(ArchiveCode.csvQuoting);
        }
        field.write(char);
      }
    }
    if (quoted) {
      throw const ArchiveDiagnostic(ArchiveCode.csvUnclosedQuote);
    }
    if (field.isNotEmpty || row.isNotEmpty || closed) {
      endField();
      result.add(row);
    }
    return result;
  }
}
