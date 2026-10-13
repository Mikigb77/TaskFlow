import 'package:agenda/models/task_list_info.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

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
  /// [hints] bias the recognizer on Android 13+; see [speechHints].
  Future<void> start(
    int run,
    String language, {
    List<String> hints = const [],
  }) => channel.invokeMethod('start', {
    'run': run,
    'language': language,
    'hints': hints,
  });
  Future<void> stop(int run) => channel.invokeMethod('stop', {'run': run});
  Future<void> cancel(int run) => channel.invokeMethod('cancel', {'run': run});
}

/// Day and time-of-day words per speech language. Recognizer vocabulary, never
/// shown; the speech language can differ from the app language.
const _dayWords = {
  'en': [
    'today',
    'tomorrow',
    'the day after tomorrow',
    'next week',
    'in the morning',
    'in the afternoon',
    'in the evening',
    'tonight',
    'noon',
  ],
  'es': [
    'hoy',
    'mañana',
    'pasado mañana',
    'la semana que viene',
    'la próxima semana',
    'por la mañana',
    'por la tarde',
    'por la noche',
    'mediodía',
  ],
  'ca': [
    'avui',
    'demà',
    'demà passat',
    'la setmana que ve',
    'la setmana vinent',
    'al matí',
    'a la tarda',
    'al vespre',
    'a la nit',
    'migdia',
  ],
};

/// Words the recognizer should expect in [language] (a BCP 47 tag such as
/// `es-ES`): weekday and month names, day and time-of-day words, then the
/// names of the user's active projects and of the people in them. At most
/// 100 short strings.
List<String> speechHints(
  String language, {
  Iterable<TaskListInfo> projects = const [],
}) {
  const limit = 100;
  final tag = language.replaceAll('-', '_');
  final code = tag.split('_').first.toLowerCase();
  final symbols = dateTimeSymbolMap();
  final dates = symbols[tag] ?? symbols[code];
  final hints = <String>{};
  void add(String value) {
    final word = value.trim();
    if (word.isNotEmpty && word.length <= 40 && hints.length < limit) {
      hints.add(word);
    }
  }

  if (dates != null) {
    dates.STANDALONEWEEKDAYS.forEach(add);
    dates.STANDALONEMONTHS.forEach(add);
    dates.AMPMS.forEach(add);
  }
  (_dayWords[code] ?? const <String>[]).forEach(add);
  final active = projects.where((project) => !project.inactive).toList();
  for (final project in active) {
    add(project.name);
  }
  for (final project in active) {
    for (final person in project.people) {
      add(person.name);
      add(person.voiceName);
    }
  }
  return hints.toList();
}
