import 'dart:ui';

import 'package:agenda/l10n/generated/app_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:agenda/services/meeting_note.dart';
import 'package:agenda/services/meeting_recorder.dart';

/// The meeting time Pro includes each month, in hours, as the Pro screen
/// states it (D4 of 2026-11-04): the server's allowance,
/// `AI_MEETING_PIECES_PER_MONTH` (240 pieces of about 5 minutes). Change
/// both together.
const meetingHoursPerMonth = 20;

/// The words a meeting's note puts around the server's text, in the
/// meeting's language (MN-21). A language the app doesn't speak gets
/// English ones, as the app falls back to English.
MeetingNoteLabels meetingNoteLabels(String? language) {
  final l = meetingLocalizations(language);
  return MeetingNoteLabels(
    decisions: l.meetingNoteDecisions,
    openQuestions: l.meetingNoteOpenQuestions,
    chapters: l.meetingNoteChapters,
    startMissing: l.meetingNoteStartMissing,
    untitled: l.meetingNoteUntitled,
    chapterRange: (start, end) => end <= 60
        ? l.meetingNoteChapterMinutes(start, end)
        : '${meetingMinutes(l, start)} – ${meetingMinutes(l, end)}',
    meetingLine: (startedAt, length) => l.meetingNoteHeader(
      meetingDate(language, l, startedAt),
      meetingLength(l, length),
    ),
  );
}

/// When a meeting started, in its language's date format with the weekday
/// in full and the 24-hour clock: `martes 3 nov, 10:15`, `dimarts 3 de nov.,
/// 10:15`, `Tuesday, Nov 3, 10:15` (an abbreviated «mar» reads as "sea").
/// Its own locale data, as the background worker has no app to load
/// Flutter's.
String meetingDate(String? language, AppLocalizations l, DateTime startedAt) =>
    '${meetingDay(language, l, startedAt)}, '
    '${DateFormat.Hm(_meetingLocale(language, l)).format(startedAt)}';

/// [meetingDate]'s day alone: `martes 3 nov`, `dimarts 3 de nov.`,
/// `Tuesday, Nov 3`.
String meetingDay(String? language, AppLocalizations l, DateTime startedAt) {
  final locale = _meetingLocale(language, l);
  final day = switch (l.localeName) {
    'es' || 'ca' => DateFormat('EEEE d MMM', locale),
    _ => DateFormat(
      DateFormat.MMMEd(locale).pattern!.replaceAll('EEE', 'EEEE'),
      locale,
    ),
  };
  return day.format(startedAt);
}

String _meetingLocale(String? language, AppLocalizations l) {
  // Synchronous: the data is in the app. Flutter's own, when loaded, wins.
  initializeDateFormatting();
  final tag = Intl.canonicalizedLocale(language ?? l.localeName);
  return tag.startsWith(l.localeName) && DateFormat.localeExists(tag)
      ? tag
      : l.localeName;
}

/// The app's strings for [language] (a BCP-47 tag such as `es-ES`), or
/// English when the app has none for it.
AppLocalizations meetingLocalizations(String? language) {
  final code = (language ?? '').split(RegExp('[-_]')).first.toLowerCase();
  final supported = AppLocalizations.supportedLocales.any(
    (locale) => locale.languageCode == code,
  );
  return lookupAppLocalizations(Locale(supported ? code : 'en'));
}

/// The recording notification's words, its Stop and Discard, and its
/// channel's name (MN-1, MN-25), in the app's language.
MeetingNotice meetingNotice(AppLocalizations l) => MeetingNotice(
  title: l.meetingNoticeTitle,
  channelName: l.meetingRecordingChannel,
  stopLabel: l.meetingStop,
  discardLabel: l.discard,
);

/// A meeting's length in words: `12 min`, `1 h 42 min`, `2 h`, and
/// «menos de 1 min» under a minute. Not a clock, which reads as a time of
/// day (UX-2705).
String meetingLength(AppLocalizations l, Duration value) =>
    value < const Duration(minutes: 1)
    ? l.meetingLengthUnderMinute
    : meetingMinutes(l, value.inMinutes);

/// [minutes] in words: `0 min`, `30 min`, `1 h 30 min`, `2 h`.
String meetingMinutes(AppLocalizations l, int minutes) {
  final value = minutes < 0 ? 0 : minutes;
  final h = value ~/ 60;
  final m = value % 60;
  if (h == 0) return l.durationMinutes(m);
  return m == 0 ? l.meetingLengthHours(h) : l.meetingLengthHoursMinutes(h, m);
}

/// The recording screen's time for TalkBack: «12 minutos y 3 segundos
/// grabados», with hours when there are any.
String meetingElapsedLabel(AppLocalizations l, Duration value) {
  final seconds = value.isNegative ? 0 : value.inSeconds;
  final h = seconds ~/ 3600;
  final m = (seconds % 3600) ~/ 60;
  final s = seconds % 60;
  if (h > 0) return l.meetingRecordedHours(h, m, s);
  return m > 0 ? l.meetingRecordedMinutes(m, s) : l.meetingRecordedSeconds(s);
}

/// Recorded time as a clock, only for the recording screen's big counter:
/// `4:05` under an hour, `1:04:05` after.
String meetingElapsed(Duration value) {
  final seconds = value.isNegative ? 0 : value.inSeconds;
  final h = seconds ~/ 3600;
  final m = (seconds % 3600) ~/ 60;
  final s = seconds % 60;
  String two(int n) => n.toString().padLeft(2, '0');
  return h == 0 ? '$m:${two(s)}' : '$h:${two(m)}:${two(s)}';
}
