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
  // Two days on, matched before the single words so the whole phrase goes.
  static const _dayAfterTomorrow =
      r'pasado\s+mañana|demà\s+passat|passat\s+demà|(?:the\s+)?day\s+after\s+tomorrow';
  // `por la mañana`, `esta mañana`, `cada mañana` are the morning.
  static const _notMorning = r'(?<!\b(?:la|esta|cada)\s+)';
  static const _next = r'next|próximo|proximo|proper';
  // Catalan puts ‘next’ after the day: `dilluns vinent`.
  static const _nextAfter = 'vinent';
  // Words end at any letter, accented ones included (`demà`).
  static final _date = RegExp(
      r'\b(?:on\s+|el\s+)?(?:(?:this|' '$_next' r')\s+)?(?:'
      '$_dayAfterTomorrow|'
      '${[..._today, for (final word in _tomorrow) word == 'mañana' ? '$_notMorning$word' : word, ..._weekdays.keys].join('|')}'
      r'|[0-9]{4}-[0-9]{2}-[0-9]{2})(?:\s+' '$_nextAfter' r')?'
      r"(?![\p{L}\p{N}_])(?!['’]\w)",
      caseSensitive: false,
      unicode: true);
  // A part of the day settles an hour written without a. m. or p. m.
  static const _morning = {'mañana', 'matí', 'morning'};
  static const _afternoon = {'tarde', 'tarda', 'afternoon'};
  static const _partLinker =
      r'(?:por|de|en|a)\s+la|esta|al|del|aquesta?|in\s+the|this|at';
  // English words stand alone (`tomorrow morning at 9`); `mañana` alone is
  // tomorrow, so the Spanish and Catalan words need their linking words.
  static const _partOfDay =
      r'(?<![\p{L}\p{N}_])(?:(?:(?:' '$_partLinker'
      r')\s+)?(morning|afternoon|evening|night|tonight)|(?:' '$_partLinker'
      r')\s+(mañana|matí|tarde|tarda|noche|nit|vespre))(?![\p{L}\p{N}_])';
  static const _partGap = r'(?:\s*,\s*|\s+)';
  // A time match can already end past its trailing space (`5:30 `).
  static final _partAfter = RegExp('\\s*,?\\s*$_partOfDay',
      caseSensitive: false, unicode: true);
  static final _partBefore = RegExp('$_partOfDay$_partGap\$',
      caseSensitive: false, unicode: true);
  static final _time = RegExp(
      r'\b(?:(?:at|a las|a les)\s+)?(?:(\d{1,2}):(\d{2})\s*(a\.?m\.?|p\.?m\.?)?|(\d{1,2})\s*(a\.?m\.?|p\.?m\.?))\b',
      caseSensitive: false);
  static final _bareHour =
      RegExp(r'\b(?:at|a las|a les)\s+(\d{1,2})\b', caseSensitive: false);

  /// The one date (and time) [input] names, relative to [reference]. A time
  /// with no date words goes on [day], or on [reference]'s day; on the next
  /// day when that time has already passed. The title can be empty when the
  /// words are only a date.
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
    } else if (RegExp(_dayAfterTomorrow).hasMatch(phrase)) {
      date = DateTime(today.year, today.month, today.day + 2);
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
    Match? acceptedPart;
    // The part of the day next to [time], when it settles [hour].
    (Match, int)? settle(Match time, int hour) {
      final part = _partAfter.matchAsPrefix(input, time.end) ??
          _partBefore.firstMatch(input.substring(0, time.start));
      if (part == null ||
          [?match, ?deadlineMarker]
              .any((m) => part.start < m.end && m.start < part.end)) {
        return null;
      }
      final word = (part.group(1) ?? part.group(2))!.toLowerCase();
      final settled = _settle(hour, word);
      return settled == null ? null : (part, settled);
    }

    if (times.isNotEmpty) {
      final time = times.single;
      var hour = int.parse(time.group(1) ?? time.group(4)!);
      final minute = int.parse(time.group(2) ?? '0');
      final period =
          (time.group(3) ?? time.group(5))?.replaceAll('.', '').toLowerCase();
      final valid =
          minute < 60 && (period == null ? hour < 24 : hour >= 1 && hour <= 12);
      if (valid) {
        if (period != null) {
          hour = hour % 12 + (period == 'pm' ? 12 : 0);
        } else if (settle(time, hour) case (final part, final settled)) {
          hour = settled;
          acceptedPart = part;
        }
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
      final settled = hour == null ? null : settle(bare.single, hour);
      // 0 and 13–23 can only be a 24-hour time; 1–12 could be either, unless
      // a part of the day next to it says which.
      if (hour != null &&
          (hour == 0 || (hour >= 13 && hour <= 23) || settled != null)) {
        if (beforeDeadline) return null;
        date = DateTime(date.year, date.month, date.day, settled?.$2 ?? hour);
        hasTime = true;
        acceptedTime = bare.single;
        acceptedPart = settled?.$1;
      } else if (bare.isNotEmpty) {
        ambiguous = true;
        if (hour != null && hour >= 1 && hour <= 12 && !beforeDeadline) {
          ambiguousHour = hour;
          acceptedTime = bare.single;
        }
      }
    }
    // A time with no date words and no picked day that has already passed
    // means the next one.
    if (hasTime &&
        match == null &&
        day == null &&
        date.isBefore(DateTime(reference.year, reference.month, reference.day,
            reference.hour, reference.minute))) {
      date =
          DateTime(date.year, date.month, date.day + 1, date.hour, date.minute);
    }
    // Without date words, only a time says when.
    if (match == null && !hasTime && ambiguousHour == null) return null;
    final ranges = <Match>[
      ?match,
      if (deadlineMarker != null) deadlineMarker,
      if (acceptedTime != null) acceptedTime,
      ?acceptedPart,
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

  /// The 24-hour hour that [hour], written without a. m. or p. m., means next
  /// to the part of the day [word], or null when the two settle nothing: 12,
  /// 1–4 at night, and a 24-hour hour the part contradicts.
  static int? _settle(int hour, String word) {
    final morning = _morning.contains(word);
    final afternoon = _afternoon.contains(word);
    if (hour >= 1 && hour <= 11) {
      if (morning) return hour;
      if (afternoon || hour >= 5) return hour + 12;
      return null;
    }
    if (hour >= 13 && hour <= 23 && !morning && (afternoon || hour >= 17)) {
      return hour;
    }
    return null;
  }
}
