import 'package:flutter/services.dart';
import 'api_client.dart';

/// Locale-independent values in retained captures; old English values still
/// resolve at display time. Unknown server/platform details are left intact.
abstract final class CaptureProblem {
  static const gone = 'capture_problem:gone';
  static const noteLength = 'capture_problem:note_length';
  static const noTasks = 'capture_problem:no_tasks';
  static const unsupportedKind = 'capture_problem:unsupported_kind';
  static const offline = 'capture_problem:offline';
  static const timeout = 'capture_problem:timeout';
  static const unavailable = 'capture_problem:unavailable';
  static const allowance = 'capture_problem:allowance';
  static const signIn = 'capture_problem:sign_in';
  static const forbidden = 'capture_problem:forbidden';
  static const tooLarge = 'capture_problem:too_large';
  static const typedFirst = 'capture_problem:typed_first';
  static const microphone = 'capture_problem:microphone';
  static const recordingFirst = 'capture_problem:recording_first';
  static const empty = 'capture_problem:empty';
  static const speechStopped = 'capture_problem:speech_stopped';
  static const noSpeech = 'capture_problem:no_speech';
  static const speechLanguage = 'capture_problem:speech_language';
  static const speechUnavailable = 'capture_problem:speech_unavailable';
  static const speechBusy = 'capture_problem:speech_busy';
  static const incompleteAudio = 'capture_problem:incomplete_audio';
  static const writeFailed = 'capture_problem:write_failed';
  static const stopFailed = 'capture_problem:stop_failed';
  static const discardFailed = 'capture_problem:discard_failed';
  static const reviewWriteFailed = 'capture_problem:review_write_failed';
  static const saveFailed = 'capture_problem:save_failed';
  static const setupRequested = 'capture_problem:setup_requested';
  static const setupUnavailable = 'capture_problem:setup_unavailable';

  static const _legacy = {
    'This capture is no longer available.': gone,
    'Capture is no longer available.': gone,
    'Capture not found in this account.': gone,
    'A note needs 1 to 8000 characters.': noteLength,
    'No tasks were found. Your capture is kept.': noTasks,
    'This server does not support the selected capture type. Your input is kept.':
        unsupportedKind,
    'Save or discard this typed capture before starting a recording.':
        typedFirst,
    'Allow microphone access to record, or type below.': microphone,
    'Microphone access was denied. You can type instead.': microphone,
    'Retry this recording or discard it before recording another.':
        recordingFirst,
    'Say or type what you need to do first.': empty,
    'Speech stopped. Your retained words are safe.': speechStopped,
    'On-device speech stopped. Retained words are safe; record audio or type to continue.':
        speechStopped,
    'No clear speech was detected. Retained words are still available.':
        noSpeech,
    'On-device speech is not installed for this language. Choose another language, record audio, or type.':
        speechLanguage,
    'The retained PCM frame is incomplete.': incompleteAudio,
  };

  static String from(Object error) {
    if (error is ApiException) {
      if (error.status == 0 &&
          error.message ==
              'The server took too long to respond. Your local tasks are safe.') {
        return timeout;
      }
      if (error.status == 0) return offline;
      if (error.status == 401) return signIn;
      if (error.status == 403) return forbidden;
      if (error.status == 413) return tooLarge;
      if (error.status == 429) return allowance;
      if (error.status >= 500 && error.status < 600) return unavailable;
    }
    if (error is PlatformException) {
      final known = switch (error.code) {
        'permission' => microphone,
        'unavailable' || 'speech_unavailable' => speechUnavailable,
        'busy' => speechBusy,
        _ => null,
      };
      if (known != null) return known;
    }
    final original = error.toString();
    final message = original.startsWith('Bad state: ')
        ? original.substring('Bad state: '.length)
        : original.startsWith('FormatException: ')
            ? original.substring('FormatException: '.length)
            : original;
    return _legacy[message] ?? original;
  }
}
