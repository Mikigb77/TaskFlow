class Task {
  final int? id;
  final String title;
  final DateTime dueDate;
  final int priority;
  final bool isCompleted;
  final String? notes;
  final List<String> filePaths;
  final List<String> imagePaths;

  Task({
    this.id,
    required this.title,
    required this.dueDate,
    required this.priority,
    this.isCompleted = false,
    this.notes,
    List<String>? filePaths,
    List<String>? imagePaths,
  })  : filePaths = filePaths ?? [], // Default to empty list if null
        imagePaths = imagePaths ?? []; // Default to empty list if null

  Task copyWith({
    int? id,
    String? title,
    DateTime? dueDate,
    int? priority,
    bool? isCompleted,
    String? notes,
    List<String>? filePaths,
    List<String>? imagePaths,
  }) {
    return Task(
      id: id ?? this.id,
      title: title ?? this.title,
      dueDate: dueDate ?? this.dueDate,
      priority: priority ?? this.priority,
      isCompleted: isCompleted ?? this.isCompleted,
      notes: notes ?? this.notes,
      filePaths: filePaths ?? this.filePaths,
      imagePaths: imagePaths ?? this.imagePaths,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'dueDate': dueDate.toIso8601String(),
      'priority': priority,
      'isCompleted': isCompleted ? 1 : 0,
      'notes': notes,
      'filePaths': filePaths.isNotEmpty ? filePaths.join('|') : null,
      'imagePaths': imagePaths.isNotEmpty ? imagePaths.join('|') : null,
    };
  }

  static Task fromMap(Map<String, dynamic> map) {
    return Task(
      id: map['id'],
      title: map['title'],
      dueDate: DateTime.parse(map['dueDate']),
      priority: map['priority'],
      isCompleted: map['isCompleted'] == 1,
      notes: map['notes'],
      filePaths: map['filePaths'] != null
          ? (map['filePaths'] as String)
              .split('|')
              .where((path) => path.isNotEmpty)
              .toList()
          : [],
      imagePaths: map['imagePaths'] != null
          ? (map['imagePaths'] as String)
              .split('|')
              .where((path) => path.isNotEmpty)
              .toList()
          : [],
    );
  }
}
