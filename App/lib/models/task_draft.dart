class TaskDraft {
  final String title;
  final DateTime? dueDate;
  final bool hasTime;
  final String recurrence;
  final DateTime? repeatUntil;
  final int priority;
  final String notes;
  final String transcript;
  final List<String> questions;

  TaskDraft.fromJson(Map<String, dynamic> data)
      : title = data['title'] as String,
        dueDate = data['due_date'] == null
            ? (data['scheduled_date'] ?? data['date']) == null
                ? null
                : DateTime.parse(
                    (data['scheduled_date'] ?? data['date']) as String)
            : DateTime.parse(data['due_date'] as String).toLocal(),
        hasTime = data['due_date'] != null,
        recurrence = data['recurrence'] as String? ?? 'none',
        repeatUntil = data['repeat_until'] == null
            ? null
            : DateTime.parse(data['repeat_until']),
        priority = data['priority'] as int,
        notes = data['notes'] as String,
        transcript = data['transcript'] as String,
        questions = List<String>.from(data['questions'] as List);
}
