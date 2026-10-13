/// Provider questions are data. Only these fields and explicit clock choices
/// can update a draft; arbitrary provider values never execute an action.
class CaptureClarification {
  const CaptureClarification({
    required this.question,
    this.field = 'details',
    this.times = const [],
  });
  final String question;
  final String field;
  final List<String> times;
  String get id => '$field:$question';
  factory CaptureClarification.fromJson(Map<String, dynamic> value) =>
      CaptureClarification(
        question: value['question'] as String,
        field:
            const {
              'title',
              'schedule',
              'deadline',
              'recurrence',
              'duration',
            }.contains(value['field'])
            ? value['field'] as String
            : 'details',
        times: (value['times'] as List? ?? [])
            .whereType<String>()
            .where((s) => RegExp(r'^([01]\d|2[0-3]):[0-5]\d$').hasMatch(s))
            .take(4)
            .toList(),
      );
  Map<String, dynamic> toJson() => {
    'question': question,
    'field': field,
    'times': times,
  };
}
