import 'package:intl/intl.dart';

import 'generated/app_localizations.dart';
import '../services/api_client.dart';
import '../services/capture_problem.dart';

/// Free dictations used up, naming the local day more come ([resetsAt]).
/// [recording]: a capture that is only a recording, kept until then.
String freeVoiceUsedUpText(
  AppLocalizations l,
  DateTime resetsAt, {
  bool recording = false,
}) {
  final date = DateFormat.MMMd(l.localeName).format(resetsAt.toLocal());
  return recording ? l.freeVoiceUsedUpRecording(date) : l.freeVoiceUsedUp(date);
}

/// [freeVoiceResets]: when free dictations come back, for a refusal of
/// spoken words. [recording]: a capture that is only a recording, with no
/// words to save as written.
String captureProblemText(
  AppLocalizations l,
  String value, {
  DateTime? freeVoiceResets,
  bool recording = false,
}) => switch (CaptureProblem.from(value)) {
  CaptureProblem.gone => l.captureGone,
  CaptureProblem.noteLength => l.captureNoteLength,
  CaptureProblem.noTasks => l.captureNoTasks,
  CaptureProblem.offline =>
    recording ? l.captureOfflineRecording : l.captureOffline,
  CaptureProblem.timeout || CaptureProblem.unavailable => l.captureUnavailable,
  CaptureProblem.tooFast => l.captureTooFast,
  CaptureProblem.allowance => l.captureAllowance,
  CaptureProblem.freeVoiceUsedUp ||
  CaptureProblem.proRequired => freeVoiceUsedUpText(
    l,
    freeVoiceResets ?? FreeVoice.nextReset(DateTime.now()),
  ),
  CaptureProblem.signIn => l.captureSignIn,
  CaptureProblem.forbidden => l.captureForbidden,
  CaptureProblem.tooLarge => l.captureTooLarge,
  CaptureProblem.typedFirst => l.captureTypedFirst,
  CaptureProblem.microphone => l.captureMicrophone,
  CaptureProblem.recordingFirst => l.captureRecordingFirst,
  CaptureProblem.empty => l.captureEmptyInput,
  CaptureProblem.speechStopped => l.captureSpeechStopped,
  CaptureProblem.noSpeech => l.captureNoSpeech,
  // The phone's own recognizer failed, and listening online did too.
  CaptureProblem.speechLanguage ||
  CaptureProblem.speechUnavailable => l.captureCantListen,
  CaptureProblem.incompleteAudio => l.captureIncompleteAudio,
  CaptureProblem.writeFailed => l.captureWriteFailed,
  CaptureProblem.stopFailed => l.captureStopFailed,
  CaptureProblem.discardFailed => l.captureDiscardFailed,
  CaptureProblem.reviewWriteFailed => l.captureReviewWriteFailed,
  CaptureProblem.saveFailed => l.captureSaveFailed,
  CaptureProblem.setupRequested => l.captureSetupRequested,
  CaptureProblem.setupUnavailable => l.captureSetupUnavailable,
  // Never a server's or the platform's own words; nor a choice of capture
  // the server can't take, or a microphone already in use: rare, and
  // trying again is all there is to do.
  _ => l.captureFailed,
};
