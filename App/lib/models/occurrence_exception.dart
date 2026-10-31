class OccurrenceException {
  final String originalDate;
  final bool skipped;
  final DateTime? date;
  final bool hasTime;
  const OccurrenceException(
      {required this.originalDate,
      this.skipped = false,
      this.date,
      this.hasTime = false});

  Map<String, dynamic> toJson() => {
        'original_date': originalDate,
        'skipped': skipped,
        'due_date':
            !skipped && hasTime ? date?.toUtc().toIso8601String() : null,
        'scheduled_date':
            !skipped && !hasTime && date != null ? _day(date!) : null,
      };
  factory OccurrenceException.fromJson(Map<String, dynamic> json) =>
      OccurrenceException(
        originalDate: json['original_date'],
        skipped: json['skipped'] == true,
        date: json['due_date'] != null
            ? DateTime.parse(json['due_date']).toLocal()
            : json['scheduled_date'] != null
                ? DateTime.parse(json['scheduled_date'])
                : null,
        hasTime: json['due_date'] != null,
      );
  bool sameAs(OccurrenceException? other) =>
      other != null &&
      originalDate == other.originalDate &&
      skipped == other.skipped &&
      date == other.date &&
      hasTime == other.hasTime;
  static String _day(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
}
