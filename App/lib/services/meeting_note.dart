import 'package:agenda/l10n/meeting_copy.dart';
import 'package:agenda/models/checklist_item.dart';
import 'package:agenda/models/meeting.dart';
import 'package:agenda/models/task.dart';
import 'package:agenda/services/notification_service.dart';

/// The words a meeting's note uses around the server's text, in the
/// meeting's language. Every one is optional: one left null is left out.
class MeetingNoteLabels {
  const MeetingNoteLabels({
    this.decisions,
    this.openQuestions,
    this.chapters,
    this.startMissing,
    this.untitled,
  });

  /// The heading over the decisions.
  final String? decisions;

  /// The heading over the open questions.
  final String? openQuestions;

  /// The heading over the chapter lines.
  final String? chapters;

  /// The line that opens a note whose start expired on the server (MN-28).
  final String? startMissing;

  /// The title of a meeting the server gave none (no speech).
  final String? untitled;

  /// No words of the app's own: the note holds only the server's text.
  static const none = MeetingNoteLabels();
}

/// What the meeting core asks of the screens, in the app and in the
/// background worker alike: the note's words in the meeting's language,
/// and the "notes ready" notification. Tests replace them.
abstract final class MeetingHooks {
  /// The note's labels for a meeting in [language] (BCP-47, may be null).
  static MeetingNoteLabels Function(String? language) labels =
      meetingNoteLabels;

  /// Called once a meeting's notes are saved as note [noteId], in either
  /// isolate: the "notes ready" notification (MN-11).
  static Future<void> Function(SavedMeetingNote saved) notesReady =
      TaskReminders.showMeetingNotesReady;
}

/// A meeting whose notes were just saved as a note.
class SavedMeetingNote {
  const SavedMeetingNote({
    required this.meetingId,
    required this.ownerKey,
    required this.noteId,
    required this.title,
    this.language,
  });
  final String meetingId;
  final String ownerKey;
  final int noteId;
  final String title;
  final String? language;
}

/// `0:30` for 30 minutes, `1:00` for 60.
String meetingClock(int minutes) {
  final value = minutes < 0 ? 0 : minutes;
  return '${value ~/ 60}:${(value % 60).toString().padLeft(2, '0')}';
}

/// A to-do as a checklist line: its words, then who and when if they were
/// said (`Send the pilot quote · Miki · Friday`).
String meetingTodoLine(MeetingTodo todo) =>
    [todo.text, ?todo.who, ?todo.when].join(' · ');

/// The meeting's notes as an ordinary note (MN-21): the title the server
/// wrote, a body of the summary, decisions, open questions and one line
/// per chapter with its notes, and the to-dos as its checklist, so one tap
/// can turn them into a task (MN-22).
Task meetingNote(
  MeetingResult result, {
  required MeetingNoteLabels labels,
  String? projectId,
}) {
  final sections = <String>[];
  if (result.startMissing && labels.startMissing != null) {
    sections.add(labels.startMissing!);
  }
  if (result.summary.isNotEmpty) sections.add(result.summary);
  String list(String? heading, List<String> lines) =>
      [?heading, for (final line in lines) '• $line'].join('\n');
  if (result.decisions.isNotEmpty) {
    sections.add(list(labels.decisions, result.decisions));
  }
  if (result.openQuestions.isNotEmpty) {
    sections.add(list(labels.openQuestions, result.openQuestions));
  }
  final chapters = [
    for (final chapter in result.chapters)
      [
        '${meetingClock(chapter.startMinute)}–${meetingClock(chapter.endMinute)}'
                ' ${chapter.title}'
            .trim(),
        if (chapter.notes.isNotEmpty) chapter.notes,
      ].join('\n'),
  ];
  if (chapters.isNotEmpty) {
    sections.add([?labels.chapters, ...chapters].join('\n\n'));
  }
  final title = result.title.isNotEmpty
      ? result.title
      : labels.untitled ??
            (result.summary.isNotEmpty
                ? result.summary.split(RegExp(r'(?<=[.!?])\s')).first
                : '');
  final body = sections.join('\n\n');
  return Task(
    kind: 'note',
    title: title.length > 200 ? title.substring(0, 200) : title,
    priority: 1,
    listId: projectId,
    notes: body.isEmpty ? null : body,
    checklist: [
      for (final todo in result.todos) ChecklistItem(title: meetingTodoLine(todo)),
    ],
  );
}
