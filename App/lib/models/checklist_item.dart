import 'package:uuid/uuid.dart';

/// A single level of steps. Recurring tasks keep completion per occurrence.
class ChecklistItem {
  final String id;
  final String title;
  final bool completed;
  final List<String> completedDates;

  ChecklistItem(
      {String? id,
      required this.title,
      this.completed = false,
      List<String> completedDates = const []})
      : id = id ?? const Uuid().v4(),
        completedDates = List.unmodifiable(completedDates);

  bool done({String? occurrence}) =>
      occurrence == null ? completed : completedDates.contains(occurrence);

  ChecklistItem copyWith(
          {String? title, bool? completed, List<String>? completedDates}) =>
      ChecklistItem(
          id: id,
          title: title ?? this.title,
          completed: completed ?? this.completed,
          completedDates: completedDates ?? this.completedDates);

  ChecklistItem setDone(bool value, {String? occurrence}) {
    if (occurrence == null) return copyWith(completed: value);
    final dates = {...completedDates};
    value ? dates.add(occurrence) : dates.remove(occurrence);
    return copyWith(completedDates: dates.toList()..sort());
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'completed': completed,
        'completed_dates': completedDates
      };

  factory ChecklistItem.fromJson(Map<String, dynamic> json) => ChecklistItem(
      id: json['id'],
      title: json['title'],
      completed: json['completed'] == true,
      completedDates: List<String>.from(json['completed_dates'] ?? []));
}
