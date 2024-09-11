class Task {
  final int? id;
  final String title;
  final DateTime dueDate;
  final int priority;
  final bool isCompleted;
  final String? notes;

  Task({
    this.id,
    required this.title,
    required this.dueDate,
    required this.priority,
    this.isCompleted = false,
    this.notes,
  });

  // Add the copyWith method
  Task copyWith({
    int? id,
    String? title,
    DateTime? dueDate,
    int? priority,
    bool? isCompleted,
    String? notes,
  }) {
    return Task(
      id: id ?? this.id,
      title: title ?? this.title,
      dueDate: dueDate ?? this.dueDate,
      priority: priority ?? this.priority,
      isCompleted: isCompleted ?? this.isCompleted,
      notes: notes ?? this.notes,
    );
  }

  // Method to convert a Task to a Map (used for SQLite)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'dueDate': dueDate.toIso8601String(),
      'priority': priority,
      'isCompleted': isCompleted ? 1 : 0,
      'notes': notes,
    };
  }

  // Method to create a Task from a Map (used for SQLite)
  static Task fromMap(Map<String, dynamic> map) {
    return Task(
      id: map['id'],
      title: map['title'],
      dueDate: DateTime.parse(map['dueDate']),
      priority: map['priority'],
      isCompleted: map['isCompleted'] == 1,
      notes: map['notes'],
    );
  }
}
