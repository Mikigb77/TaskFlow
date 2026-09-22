import 'package:agenda/models/checklist_item.dart';

class TaskDraft {
  final String title;
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
  final List<ChecklistItem> checklist;

  TaskDraft.fromJson(Map<String, dynamic> data)
      : title = data['title'] as String,
        dueDate = data['due_date'] == null
            ? (data['scheduled_date'] ?? data['date']) == null
                ? null
                : DateTime.parse(
                    (data['scheduled_date'] ?? data['date']) as String)
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
            .map((item) =>
                ChecklistItem.fromJson(Map<String, dynamic>.from(item)))
            .toList(),
        transcript = data['transcript'] as String,
        questions = List<String>.from(data['questions'] as List);
}
