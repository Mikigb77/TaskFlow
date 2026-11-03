import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:record/record.dart';
import 'package:agenda/models/meeting.dart';
import 'package:agenda/services/meeting_recorder.dart';
import 'package:agenda/services/notification_service.dart';

/// [MeetingAudioEngine] on the `record` package, recording in Android's
/// foreground service with the microphone type, so it goes on with the
/// screen off or the app in the background (MN-1).
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

  /// Counts the recordings and their files: a notification posted late,
  /// for a recording that has since stopped, isn't posted.
  int _noticeTurn = 0;

  static const bitRate = 24000;
  static const sampleRate = 16000;

  /// The channel of the recorder's foreground-service notification.
  static const channelId = 'AudioRecordingChannel';

  /// Gives the recorder's channel [MeetingNotice.channelName], in the
  /// app's language (MN-33). The recorder's service creates the channel
  /// with its English name as it starts, which may be just after [start]
  /// returns, so it's named again a moment later. Creating a channel that
  /// exists only renames it.
  void _nameChannel(MeetingNotice notice) {
    final name = notice.channelName;
    if (name == null || name.trim().isEmpty || !Platform.isAndroid) return;
    Future<void> rename() async {
      try {
        await FlutterLocalNotificationsPlugin()
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >()
            ?.createNotificationChannel(
              AndroidNotificationChannel(
                channelId,
                name,
                importance: Importance.low,
                playSound: false,
                enableVibration: false,
                showBadge: false,
              ),
            );
      } catch (_) {
        /* The channel keeps the recorder's name. */
      }
    }

    unawaited(rename());
    unawaited(Future<void>.delayed(const Duration(seconds: 2), rename));
  }

  /// Posts the app's recording notification, with Stop and Discard
  /// (MN-1, MN-25), over the recorder's plain one. The recorder's service
  /// posts its own as it starts, which may be just after [start] returns,
  /// and again on every start ([next] with Opus): so it's posted again a
  /// moment later, until the recording stops.
  void _showNotice(MeetingNotice notice) {
    if (!Platform.isAndroid) return;
    final turn = ++_noticeTurn;
    Future<void> show() async {
      if (turn != _noticeTurn || _format == null) return;
      try {
        await TaskReminders.showMeetingRecording(notice);
      } catch (_) {
        /* The recorder's own notification stays. */
      }
    }

    unawaited(show());
    for (final wait in const [400, 1500, 4000]) {
      unawaited(Future<void>.delayed(Duration(milliseconds: wait), show));
    }
  }

  @override
  Future<bool> hasPermission() => _recorder.hasPermission();

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
        androidConfig: AndroidRecordConfig(
          // The recorder's own foreground service; its replacement package
          // isn't needed while this one is kept.
          // ignore: deprecated_member_use
          service: AndroidService(title: notice.title, content: notice.text),
        ),
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
    if (format == MeetingAudioFormat.opus) {
      await _recorder.start(config, path: path);
      _nameChannel(notice);
      _showNotice(notice);
      return;
    }
    _file = await File(path).open(mode: FileMode.writeOnlyAppend);
    final stream = await _recorder.startStream(config);
    _nameChannel(notice);
    _showNotice(notice);
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
  Future<void> next(String path) async {
    final format = _format;
    final notice = _notice;
    if (format == null || notice == null) throw StateError('Not recording.');
    if (format == MeetingAudioFormat.opus) {
      // Android stops the current file, completing it, and starts the next
      // without stopping the foreground service, which posts its plain
      // notification again.
      await _recorder.start(_config(format, notice), path: path);
      _showNotice(notice);
      return;
    }
    // The stream goes on; only the file it's written to changes, between
    // two frames.
    final next = await File(path).open(mode: FileMode.writeOnlyAppend);
    final previous = _file;
    _file = next;
    await previous?.close();
  }

  @override
  Future<void> stop() async {
    _noticeTurn++;
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
      try {
        await TaskReminders.clearMeetingRecording();
      } catch (_) {
        /* The recorder's service removes its notification as it stops. */
      }
    }
  }

  @override
  Stream<double> get levels => _recorder
      .onAmplitudeChanged(const Duration(milliseconds: 200))
      .map((amplitude) => amplitude.current);

  Future<void> dispose() => _recorder.dispose();
}
