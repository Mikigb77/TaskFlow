import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:agenda/models/meeting.dart';
import 'package:agenda/services/meeting_recorder.dart';
import 'package:agenda/services/native_speech.dart';
import 'package:agenda/services/notification_service.dart';

/// [MeetingAudioEngine] on the `record` package. Recording goes on with
/// the screen off or the app in the background (MN-1) because the app
/// holds a foreground service with the microphone type for the whole
/// recording: `flutter_local_notifications`' own service, whose
/// notification is the recording's, with Stop and Discard. `record` 7
/// has no service of its own.
///
/// Mono, 16 kHz, about 24 kbps (MN-2), written to disk as it's recorded in
/// a container that survives a sudden stop (MN-3):
/// - Ogg Opus, written by Android itself, from Android 10;
/// - before that, AAC frames from the recorder's stream, each with its
///   ADTS header, appended to the file here. `record` writes AAC to a file
///   only as M4A, which a sudden stop leaves unreadable.
class RecordMeetingAudio implements MeetingAudioEngine {
  RecordMeetingAudio({AudioRecorder? recorder}) : _given = recorder;

  final AudioRecorder? _given;

  /// Made on first use: making one talks to the platform.
  late final AudioRecorder _recorder = _given ?? AudioRecorder();
  MeetingAudioFormat? _format;
  MeetingNotice? _notice;
  StreamSubscription<Uint8List>? _stream;
  Completer<void>? _streamDone;
  RandomAccessFile? _file;

  static const bitRate = 24000;
  static const sampleRate = 16000;

  /// Starts the foreground service with the recording's notification,
  /// before the microphone opens: Android 14 lets a microphone service
  /// start only while the app is in front, which it is when the person
  /// taps record or Continue. If the service can't start, recording goes
  /// on while the app is in front.
  Future<void> _startService(MeetingNotice notice) async {
    if (!Platform.isAndroid) return;
    try {
      await TaskReminders.startMeetingRecording(notice);
    } catch (_) {
      /* Recording goes on without the service. */
    }
  }

  /// Updates the running service's notification, as at each cut: posting
  /// under the service's id replaces its notification without starting
  /// the service again, which Android may refuse from the background.
  Future<void> _updateNotice(MeetingNotice notice) async {
    if (!Platform.isAndroid) return;
    try {
      await TaskReminders.showMeetingRecording(notice);
    } catch (_) {
      /* The notification keeps its earlier text. */
    }
  }

  @override
  Future<SpeechPermission> permission({bool ask = true}) async {
    if (await _recorder.hasPermission(request: false)) {
      return SpeechPermission.granted;
    }
    if (!ask) return SpeechPermission.denied;
    if (!Platform.isAndroid) {
      return await _recorder.hasPermission()
          ? SpeechPermission.granted
          : SpeechPermission.denied;
    }
    // Android says, once asked, whether it would ask again.
    final status = await Permission.microphone.request();
    if (status.isGranted) return SpeechPermission.granted;
    return status.isPermanentlyDenied || status.isRestricted
        ? SpeechPermission.blocked
        : SpeechPermission.denied;
  }

  @override
  Future<MeetingAudioFormat> format() async {
    try {
      if (Platform.isAndroid &&
          (await DeviceInfoPlugin().androidInfo).version.sdkInt >= 29 &&
          await _recorder.isEncoderSupported(AudioEncoder.opus)) {
        return MeetingAudioFormat.opus;
      }
    } catch (_) {
      /* AAC, which every Android phone encodes. */
    }
    return MeetingAudioFormat.aac;
  }

  RecordConfig _config(MeetingAudioFormat format, MeetingNotice notice) =>
      RecordConfig(
        encoder: format == MeetingAudioFormat.opus
            ? AudioEncoder.opus
            : AudioEncoder.aacLc,
        bitRate: bitRate,
        sampleRate: sampleRate,
        numChannels: 1,
      );

  @override
  Future<void> start(
    String path,
    MeetingAudioFormat format,
    MeetingNotice notice,
  ) async {
    _format = format;
    _notice = notice;
    final config = _config(format, notice);
    await _startService(notice);
    try {
      if (format == MeetingAudioFormat.opus) {
        await _recorder.start(config, path: path);
        return;
      }
      _file = await File(path).open(mode: FileMode.writeOnlyAppend);
    } catch (_) {
      _format = null;
      await _stopService();
      rethrow;
    }
    final Stream<Uint8List> stream;
    try {
      stream = await _recorder.startStream(config);
    } catch (_) {
      _format = null;
      await _file?.close();
      _file = null;
      await _stopService();
      rethrow;
    }
    final done = _streamDone = Completer<void>();
    _stream = stream.listen(
      _write,
      onDone: done.complete,
      onError: (Object _) {},
      cancelOnError: false,
    );
  }

  void _write(Uint8List chunk) {
    // Written as it comes: a killed app leaves every frame written so far.
    try {
      _file?.writeFromSync(chunk);
    } on FileSystemException {
      /* The next piece's file takes over. */
    }
  }

  @override
  Future<void> next(String path, MeetingNotice notice) async {
    final format = _format;
    if (format == null || _notice == null) throw StateError('Not recording.');
    _notice = notice;
    if (format == MeetingAudioFormat.opus) {
      // Android stops the current file, completing it, and starts the
      // next; the app's foreground service goes on through the cut.
      await _recorder.start(_config(format, notice), path: path);
      await _updateNotice(notice);
      return;
    }
    // The stream goes on; only the file it's written to changes, between
    // two frames.
    final next = await File(path).open(mode: FileMode.writeOnlyAppend);
    final previous = _file;
    _file = next;
    await previous?.close();
    await _updateNotice(notice);
  }

  @override
  Future<void> stop() async {
    try {
      await _recorder.stop();
      // The last frames arrive before the stream closes.
      await _streamDone?.future.timeout(
        const Duration(seconds: 2),
        onTimeout: () {},
      );
    } finally {
      _streamDone = null;
      await _stream?.cancel();
      _stream = null;
      await _file?.close();
      _file = null;
      _format = null;
      await _stopService();
    }
  }

  /// Stops the foreground service, which removes its notification.
  Future<void> _stopService() async {
    if (!Platform.isAndroid) return;
    try {
      await TaskReminders.clearMeetingRecording();
    } catch (_) {
      /* Android removes the service's notification with the app. */
    }
  }

  @override
  Stream<double> get levels => _recorder
      .onAmplitudeChanged(const Duration(milliseconds: 200))
      .map((amplitude) => amplitude.current);

  Future<void> dispose() => _recorder.dispose();
}
