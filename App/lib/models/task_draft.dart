import 'package:agenda/models/checklist_item.dart';
import 'package:agenda/models/capture_clarification.dart';
import 'package:agenda/models/reminder_plan.dart';

class TaskDraft {
  final String title;
  final String kind;
  final DateTime? dueDate;
  final bool hasTime;
  final DateTime? deadline;
  final bool deadlineHasTime;
  final int? durationMinutes;
  final String recurrence;
  final int repeatInterval;
  final List<int> repeatWeekdays;
  final DateTime? repeatUntil;
  final int priority;
  final String notes;
  final String transcript;
  final List<String> questions;
  final List<CaptureClarification> clarifications;
  final List<ChecklistItem> checklist;
  final String? listId;
  final String assignment;
  final int? assigneeId;
  final String? assigneeName;
  final List<String> assignmentIssues;
  final Map<String, String?> assignmentHints;

  /// The project a `project` command of the same answer creates, by name:
  /// the task goes there once it exists.
  final String? newProject;

  /// The project as said, when none matched it and nobody asked to create
  /// it: the result offers to create it or to pick another.
  final String? projectSuggestion;

  /// Reminders said while dictating (Backend/docs/REMINDER_PLANS.md, «The
  /// dictation»): a rhythm, or a reminder some days before, as a plan; some
  /// minutes or hours before a timed task, as minutes. Absent from older
  /// servers, and when nothing was said about reminders.
  final ReminderPlan? reminderPlan;
  final int? reminderMinutes;

  TaskDraft.fromJson(Map<String, dynamic> data)
    : title = data['title'] as String,
      reminderPlan = ReminderPlan.tryParse(data['reminder_plan']),
      reminderMinutes = _minutes(data['reminder_minutes']),
      clarifications = (data['clarifications'] as List? ?? [])
          .map(
            (value) =>
                CaptureClarification.fromJson(Map<String, dynamic>.from(value)),
          )
          .toList(),
      listId = data['list_id'],
      assignment = data['assignment'] ?? 'personal',
      assigneeId = data['assignee_id'],
      assigneeName = data['assignee_name'],
      assignmentIssues = List<String>.from(data['assignment_issues'] ?? []),
      assignmentHints = Map<String, String?>.from(
        data['assignment_hints'] ?? {},
      ),
      newProject = _name(data['new_project']),
      projectSuggestion = _name(data['project_suggestion']),
      kind = data['kind'] as String? ?? 'task',
      dueDate = data['due_date'] == null
          ? (data['scheduled_date'] ?? data['date']) == null
                ? null
                : DateTime.parse(
                    (data['scheduled_date'] ?? data['date']) as String,
                  )
          : DateTime.parse(data['due_date'] as String).toLocal(),
      hasTime = data['due_date'] != null,
      deadline = data['deadline_at'] != null
          ? DateTime.parse(data['deadline_at']).toLocal()
          : data['deadline_date'] != null
          ? DateTime.parse(data['deadline_date'])
          : null,
      deadlineHasTime = data['deadline_at'] != null,
      durationMinutes = data['duration_minutes'],
      recurrence = data['recurrence'] as String? ?? 'none',
      repeatInterval = data['repeat_interval'] as int? ?? 1,
      repeatWeekdays = List<int>.from(data['repeat_weekdays'] ?? []),
      repeatUntil = data['repeat_until'] == null
          ? null
          : DateTime.parse(data['repeat_until']),
      priority = data['priority'] as int,
      notes = data['notes'] as String,
      checklist = (data['checklist'] as List? ?? [])
          .map(
            (item) => ChecklistItem.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList(),
      transcript = data['transcript'] as String,
      questions = List<String>.from(data['questions'] as List);

  /// A reminder lead the task form could also set: off, or up to a week.
  static int? _minutes(Object? value) =>
      value is int && value >= -1 && value <= 10080 ? value : null;

  /// A project name from the server: absent from older servers.
  static String? _name(Object? value) {
    if (value is! String) return null;
    final name = value.trim();
    return name.isEmpty || name.length > 80 ? null : name;
  }
}
