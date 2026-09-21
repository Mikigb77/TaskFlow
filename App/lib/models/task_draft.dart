class TaskDraft {
  final String title;
  final DateTime? dueDate;
  final int priority;
  final String notes;
  final String transcript;
  final List<String> questions;

  TaskDraft.fromJson(Map<String, dynamic> data)
      : title = data['title'] as String,
        dueDate = data['due_date'] == null
            ? null
            : DateTime.parse(data['due_date'] as String).toLocal(),
        priority = data['priority'] as int,
        notes = data['notes'] as String,
        transcript = data['transcript'] as String,
        questions = List<String>.from(data['questions'] as List);
}
