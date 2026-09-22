/// A deliberately bounded, local parser. Suggestions are never applied until
/// the user accepts one. Unsupported phrases stay in the title unchanged.
class ScheduleSuggestion {
  final String title;
  final DateTime date;
  final bool hasTime;
  final bool ambiguousTime;
  const ScheduleSuggestion(this.title, this.date, this.hasTime,
      {this.ambiguousTime = false});
}

class QuickScheduleParser {
  static const _weekdays = {
    'monday': 1,
    'tuesday': 2,
    'wednesday': 3,
    'thursday': 4,
    'friday': 5,
    'saturday': 6,
    'sunday': 7,
    'lunes': 1,
    'martes': 2,
    'miércoles': 3,
    'miercoles': 3,
    'jueves': 4,
    'viernes': 5,
    'sábado': 6,
    'sabado': 6,
    'domingo': 7,
  };
  static final _date = RegExp(
      r'\b(?:on\s+|el\s+)?(?:(?:next|this|próximo|proximo)\s+)?(?:today|tomorrow|hoy|mañana|'
      '${_weekdays.keys.join('|')}|[0-9]{4}-[0-9]{2}-[0-9]{2})'
      r"\b(?!['’]\w)",
      caseSensitive: false);
  static final _time = RegExp(
      r'\b(?:(?:at|a las)\s+)?(?:(\d{1,2}):(\d{2})\s*(a\.?m\.?|p\.?m\.?)?|(\d{1,2})\s*(a\.?m\.?|p\.?m\.?))\b',
      caseSensitive: false);

  static ScheduleSuggestion? parse(String input, DateTime reference) {
    if (input.length > 4000) return null;
    // Quoted titles, alternatives and explicit corrections require human/AI review.
    if (RegExp('["“”]').hasMatch(input) ||
        RegExp(r'\b(?:or|actually|instead|mejor|o)\b', caseSensitive: false)
            .hasMatch(input)) {
      return null;
    }
    final dates = _date.allMatches(input).toList();
    if (dates.length != 1) return null;
    final match = dates.single;
    final phrase = match.group(0)!.toLowerCase();
    final word = phrase.split(RegExp(r'\s+')).last;
    final today = DateTime(reference.year, reference.month, reference.day);
    DateTime date;
    if (word == 'today' || word == 'hoy') {
      date = today;
    } else if (word == 'tomorrow' || word == 'mañana') {
      date = DateTime(today.year, today.month, today.day + 1);
    } else if (_weekdays.containsKey(word)) {
      var offset = (_weekdays[word]! - today.weekday + 7) % 7;
      if (offset == 0 &&
          RegExp(r'\b(next|próximo|proximo)\b').hasMatch(phrase)) {
        offset = 7;
      }
      date = DateTime(today.year, today.month, today.day + offset);
    } else {
      final parts = word.split('-').map(int.parse).toList();
      date = DateTime(parts[0], parts[1], parts[2]);
      if (date.year < 2000 ||
          date.year > 2100 ||
          date.year != parts[0] ||
          date.month != parts[1] ||
          date.day != parts[2]) {
        return null;
      }
    }
    final times = _time.allMatches(input).toList();
    if (times.length > 1) return null;
    var hasTime = false;
    var ambiguous = false;
    RegExpMatch? acceptedTime;
    if (times.isNotEmpty) {
      final time = times.single;
      var hour = int.parse(time.group(1) ?? time.group(4)!);
      final minute = int.parse(time.group(2) ?? '0');
      final period =
          (time.group(3) ?? time.group(5))?.replaceAll('.', '').toLowerCase();
      final valid =
          minute < 60 && (period == null ? hour < 24 : hour >= 1 && hour <= 12);
      if (valid) {
        if (period != null) hour = hour % 12 + (period == 'pm' ? 12 : 0);
        date = DateTime(date.year, date.month, date.day, hour, minute);
        hasTime = true;
        acceptedTime = time;
      } else {
        ambiguous = true;
      }
    } else if (RegExp(r'\b(?:at|a las)\s+\d{1,2}\b', caseSensitive: false)
        .hasMatch(input)) {
      ambiguous = true;
    }
    final ranges = [match, if (acceptedTime != null) acceptedTime]
      ..sort((a, b) => b.start.compareTo(a.start));
    var title = input;
    for (final range in ranges) {
      title = title.replaceRange(range.start, range.end, ' ');
    }
    title = title
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r'^[\s,.;:]+|[\s,.;:]+$'), '')
        .trim();
    if (title.isEmpty) return null;
    return ScheduleSuggestion(title, date, hasTime, ambiguousTime: ambiguous);
  }
}
