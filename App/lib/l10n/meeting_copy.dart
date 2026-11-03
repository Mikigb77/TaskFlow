import 'dart:ui';

import 'package:agenda/l10n/generated/app_localizations.dart';
import 'package:agenda/services/meeting_note.dart';
import 'package:agenda/services/meeting_recorder.dart';

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
  );
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

/// Recorded time as a clock: `4:05` under an hour, `1:04:05` after.
String meetingElapsed(Duration value) {
  final seconds = value.isNegative ? 0 : value.inSeconds;
  final h = seconds ~/ 3600;
  final m = (seconds % 3600) ~/ 60;
  final s = seconds % 60;
  String two(int n) => n.toString().padLeft(2, '0');
  return h == 0 ? '$m:${two(s)}' : '$h:${two(m)}:${two(s)}';
}
