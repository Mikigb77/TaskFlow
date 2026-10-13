import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final nativeSpeechProvider = Provider<NativeSpeech>((ref) => NativeSpeech());

class SpeechCapability {
  final bool onDevice;
  final String language;
  final bool? languageInstalled;
  const SpeechCapability(
      {this.onDevice = false, this.language = '', this.languageInstalled});
  bool get usable => onDevice && languageInstalled != false;
}

/// The microphone permission answer. `blocked`: Android won't ask again, so
/// only the phone's Settings can turn the microphone on.
enum SpeechPermission { granted, denied, blocked }

/// One event of a listening run: `ready`, `partial` (the words of the segment
/// in progress), `segment` (committed words), `level`, `ended` (only after
/// stop, cancel or leaving the app) and `error` (only what can't recover).
class SpeechEvent {
  final int run;
  final String kind;
  final String? text;
  final double? level;
  final String? error;
  const SpeechEvent(this.run, this.kind, {this.text, this.level, this.error});
  factory SpeechEvent.fromMap(Map<Object?, Object?> map) =>
      SpeechEvent(map['run'] as int, map['kind'] as String,
          text: map['text'] as String?,
          level: (map['level'] as num?)?.toDouble(),
          error: map['error'] as String?);
  bool get terminal => kind == 'ended' || kind == 'error';
}

/// Only the explicit Android on-device recognizer is used. Audio fallback goes
/// through the existing retained recording flow, never a hidden cloud recognizer.
class NativeSpeech {
  final MethodChannel channel;
  final EventChannel eventChannel;
  NativeSpeech(
      {this.channel = const MethodChannel('taskflow/speech'),
      this.eventChannel = const EventChannel('taskflow/speech/events')});

  Stream<SpeechEvent> get events => eventChannel.receiveBroadcastStream().map(
      (event) => SpeechEvent.fromMap(Map<Object?, Object?>.from(event as Map)));

  Future<SpeechCapability> capability({String? language}) async {
    try {
      final result = await channel.invokeMapMethod<String, dynamic>(
          'capability',
          {'language': language}).timeout(const Duration(seconds: 4));
      return SpeechCapability(
          onDevice: result?['onDevice'] == true,
          language: result?['language'] as String? ?? language ?? '',
          languageInstalled: result?['languageInstalled'] as bool?);
    } on MissingPluginException {
      return SpeechCapability(language: language ?? '');
    } catch (_) {
      return SpeechCapability(language: language ?? '');
    }
  }

  Future<SpeechPermission> permission() async =>
      switch (await channel.invokeMethod<Object>('permission')) {
        'granted' || true => SpeechPermission.granted,
        'blocked' => SpeechPermission.blocked,
        _ => SpeechPermission.denied,
      };
  Future<bool> prepareLanguage(String language) async =>
      await channel
          .invokeMethod<bool>('prepareLanguage', {'language': language}) ??
      false;
  Future<void> start(int run, String language) =>
      channel.invokeMethod('start', {'run': run, 'language': language});
  Future<void> stop(int run) => channel.invokeMethod('stop', {'run': run});
  Future<void> cancel(int run) => channel.invokeMethod('cancel', {'run': run});
}
