import 'package:agenda/models/capture_clarification.dart';
import 'package:agenda/models/capture_session.dart';
import 'package:agenda/models/task.dart';
import 'package:agenda/services/quick_schedule_parser.dart';
import 'package:uuid/uuid.dart';

/// About how long a task title may be before it is cut at a word.
const taskTitleLength = 160;

/// About how long a note title may be before it is cut at a word.
const noteTitleLength = 60;

/// The title words lead with: the first line's first sentence, or about
/// [limit] characters cut at a word. [rest] is the words after it.
({String title, String rest}) leadingTitle(String text, int limit) {
  final words = text.trim();
  final lineEnd = words.indexOf('\n');
  var end = lineEnd < 0 ? words.length : lineEnd;
  final line = words.substring(0, end).trim();
  var title = line;
  final sentence = RegExp(r'^(.+?[.!?…])(?=\s|$)').firstMatch(line);
  if (sentence != null) {
    title = sentence.group(1)!;
    end = sentence.end;
  }
  if (title.endsWith('.') && !title.endsWith('..')) {
    title = title.substring(0, title.length - 1);
  }
  final runes = title.runes.toList();
  if (runes.length > limit) {
    final cut = String.fromCharCodes(runes.take(limit + 1));
    final space = cut.lastIndexOf(RegExp(r'\s'));
    title = space > limit ~/ 3
        ? cut.substring(0, space)
        : String.fromCharCodes(runes.take(limit));
    end = title.length;
    title = title.replaceFirst(RegExp(r'[\s,;:]+$'), '');
  }
  return (title: title.trim(), rest: words.substring(end).trim());
}

/// A capture's result built on the phone, with no network: typing without
/// Pro, and saving the words as written.
///
/// A note's title leads its words, which all stay in its body. A task takes
/// the date the words name ([reference] is when they were captured), without
/// those words in its title; an ambiguous hour (`a las 5`) asks morning or
/// afternoon. A time alone goes on [defaultDay], or on [reference]'s day. A
/// task with no date and no deadline gets [defaultDay], without a time.
List<CaptureDraft> localDrafts(
  String text,
  DateTime reference, {
  DateTime? defaultDay,
  String kind = 'task',
  String? projectId,
}) {
  final words = text.trim();
  if (kind == 'note') {
    return [
      CaptureDraft(
        id: const Uuid().v4(),
        task: Task(
          kind: 'note',
          listId: projectId,
          title: leadingTitle(words, noteTitleLength).title,
          priority: 1,
          notes: words,
        ),
      ),
    ];
  }
  final day = defaultDay == null ? null : Task.day(defaultDay);
  Task task(String words, {ScheduleSuggestion? found}) {
    final lead = leadingTitle(words, taskTitleLength);
    final deadline = found != null && found.isDeadline;
    return Task(
      // A task's title starts with a capital, as the assistant writes it.
      title: lead.title.isEmpty
          ? lead.title
          : lead.title[0].toUpperCase() + lead.title.substring(1),
      listId: projectId,
      priority: 1,
      notes: lead.rest.isEmpty ? null : lead.rest,
      dueDate: found == null
          ? day
          : deadline
          ? null
          : found.date,
      hasTime: found != null && !deadline && found.hasTime,
      deadline: deadline ? found.date : null,
      deadlineHasTime: deadline && found.hasTime,
      reminderAnchor: deadline ? 'deadline' : 'planned',
    );
  }

  final typed = task(words);
  final found = QuickScheduleParser.parse(words, reference, day: day);
  if (found == null) {
    return [CaptureDraft(id: const Uuid().v4(), task: typed)];
  }
  final hour = found.ambiguousHour;
  String clock(int hour) => '${hour.toString().padLeft(2, '0')}:00';
  final question = hour == null
      ? null
      : CaptureClarification(
          question: '',
          field: found.isDeadline ? 'deadline' : 'schedule',
          times: [clock(hour % 12), clock(hour % 12 + 12)],
        );
  return [
    CaptureDraft(
      id: const Uuid().v4(),
      // Words that are only a date stay the title.
      task: task(found.title.isEmpty ? words : found.title, found: found),
      clarifications: [?question],
      confirmed: question == null,
      asTyped: typed,
    ),
  ];
}
