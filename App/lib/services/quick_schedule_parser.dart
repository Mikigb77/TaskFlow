import 'package:agenda/models/task.dart';

/// A deliberately bounded, local parser for typed English, Spanish and Catalan
/// words. A date it finds applies at once; the capture result keeps the words
/// as typed one tap away. Unsupported phrases stay in the title unchanged.
class ScheduleSuggestion {
  final String title;
  final DateTime date;
  final bool hasTime;
  final bool ambiguousTime;

  /// A bare hour from 1 to 12 (`a las 5`): morning or afternoon is asked, not
  /// guessed. Its words are left out of [title].
  final int? ambiguousHour;
  final bool isDeadline;
  const ScheduleSuggestion(this.title, this.date, this.hasTime,
      {this.ambiguousTime = false,
      this.ambiguousHour,
      this.isDeadline = false});
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
    'dilluns': 1,
    'dimarts': 2,
    'dimecres': 3,
    'dijous': 4,
    'divendres': 5,
    'dissabte': 6,
    'diumenge': 7,
  };
  static const _today = {'today', 'hoy', 'avui'};
  static const _tomorrow = {'tomorrow', 'mañana', 'demà'};
  static const _next = r'next|próximo|proximo|proper';
  // Catalan puts ‘next’ after the day: `dilluns vinent`.
  static const _nextAfter = 'vinent';
  // Words end at any letter, accented ones included (`demà`).
  static final _date = RegExp(
      r'\b(?:on\s+|el\s+)?(?:(?:this|' '$_next' r')\s+)?(?:'
      '${[..._today, ..._tomorrow, ..._weekdays.keys].join('|')}'
      r'|[0-9]{4}-[0-9]{2}-[0-9]{2})(?:\s+' '$_nextAfter' r')?'
      r"(?![\p{L}\p{N}_])(?!['’]\w)",
      caseSensitive: false,
      unicode: true);
  static final _time = RegExp(
      r'\b(?:(?:at|a las|a les)\s+)?(?:(\d{1,2}):(\d{2})\s*(a\.?m\.?|p\.?m\.?)?|(\d{1,2})\s*(a\.?m\.?|p\.?m\.?))\b',
      caseSensitive: false);
  static final _bareHour =
      RegExp(r'\b(?:at|a las|a les)\s+(\d{1,2})\b', caseSensitive: false);

  /// The one date (and time) [input] names, relative to [reference]. A time
  /// with no date words goes on [day], or on [reference]'s day. The title can
  /// be empty when the words are only a date.
  static ScheduleSuggestion? parse(
    String input,
    DateTime reference, {
    DateTime? day,
  }) {
    if (input.length > 4000) return null;
    // Quoted titles, alternatives and explicit corrections require human/AI review.
    if (RegExp('["“”]').hasMatch(input) ||
        RegExp(r'\b(?:or|actually|instead|mejor|o)\b', caseSensitive: false)
            .hasMatch(input)) {
      return null;
    }
    final dates = _date.allMatches(input).toList();
    if (dates.length > 1) return null;
    final match = dates.singleOrNull;
    final deadlineMarker = match == null
        ? null
        : RegExp(
                r'\b(?:by|due(?:\s+by)?|deadline(?:\s+is)?|antes\s+de(?:l)?|vence|fecha\s+l[ií]mite(?:\s+es)?)\s*$',
                caseSensitive: false)
            .firstMatch(input.substring(0, match.start));
    final phrase = match?.group(0)!.toLowerCase() ?? '';
    final words = phrase.split(RegExp(r'\s+'));
    final word = words.lastWhere((w) => w != _nextAfter, orElse: () => '');
    final today = DateTime(reference.year, reference.month, reference.day);
    DateTime date;
    if (match == null) {
      date = Task.day(day ?? today);
    } else if (_today.contains(word)) {
      date = today;
    } else if (_tomorrow.contains(word)) {
      date = DateTime(today.year, today.month, today.day + 1);
    } else if (_weekdays.containsKey(word)) {
      var offset = (_weekdays[word]! - today.weekday + 7) % 7;
      if (offset == 0 &&
          words.any(
              (w) => w == _nextAfter || RegExp('^(?:$_next)\$').hasMatch(w))) {
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
    if (deadlineMarker != null &&
        times.isNotEmpty &&
        times.single.end <= deadlineMarker.start) {
      return null;
    }
    var hasTime = false;
    var ambiguous = false;
    int? ambiguousHour;
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
    } else {
      final bare = _bareHour.allMatches(input).toList();
      final hour = bare.length == 1 ? int.parse(bare.single.group(1)!) : null;
      final beforeDeadline = deadlineMarker != null &&
          bare.length == 1 &&
          bare.single.end <= deadlineMarker.start;
      // 0 and 13–23 can only be a 24-hour time; 1–12 could be either.
      if (hour != null && (hour == 0 || (hour >= 13 && hour <= 23))) {
        if (beforeDeadline) return null;
        date = DateTime(date.year, date.month, date.day, hour);
        hasTime = true;
        acceptedTime = bare.single;
      } else if (bare.isNotEmpty) {
        ambiguous = true;
        if (hour != null && hour >= 1 && hour <= 12 && !beforeDeadline) {
          ambiguousHour = hour;
          acceptedTime = bare.single;
        }
      }
    }
    // Without date words, only a time says when.
    if (match == null && !hasTime && ambiguousHour == null) return null;
    final ranges = [
      ?match,
      if (deadlineMarker != null) deadlineMarker,
      if (acceptedTime != null) acceptedTime
    ]..sort((a, b) => b.start.compareTo(a.start));
    var title = input;
    for (final range in ranges) {
      title = title.replaceRange(range.start, range.end, ' ');
    }
    title = title
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r'^[\s,.;:]+|[\s,.;:]+$'), '')
        .trim();
    return ScheduleSuggestion(title, date, hasTime,
        ambiguousTime: ambiguous,
        ambiguousHour: ambiguousHour,
        isDeadline: deadlineMarker != null);
  }
}
