import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final captureEntriesProvider = Provider<CaptureEntries>((ref) {
  final entries = CaptureEntries();
  ref.onDispose(entries.dispose);
  return entries;
});

class CaptureEntry {
  final String id;
  final String kind;
  final String text;
  final DateTime capturedAt;
  const CaptureEntry(this.id, this.kind, this.text, this.capturedAt);
  static CaptureEntry? fromMap(Map<Object?, Object?> map) {
    final id = map['id'];
    final kind = map['kind'];
    final text = map['text'];
    final time = map['capturedAt'];
    if (id is! String ||
        !RegExp(r'^[0-9a-fA-F-]{36}$').hasMatch(id) ||
        !['voice', 'text', 'share', 'meeting'].contains(kind) ||
        text is! String ||
        text.length > 4000 ||
        time is! int ||
        time < 0 ||
        time > 4133980800000 ||
        (kind == 'share' && text.trim().isEmpty)) {
      return null;
    }
    return CaptureEntry(id, kind as String, text,
        DateTime.fromMillisecondsSinceEpoch(time, isUtc: true));
  }
}

class CaptureEntries {
  final MethodChannel channel;
  final _changes = StreamController<void>.broadcast();
  Stream<void> get changes => _changes.stream;
  CaptureEntries(
      {this.channel = const MethodChannel('taskflow/capture-entries')}) {
    channel.setMethodCallHandler((call) async {
      if (call.method == 'changed') _changes.add(null);
    });
  }
  Future<List<CaptureEntry>> pending() async {
    try {
      final values = await channel.invokeListMethod<Object?>('pending') ?? [];
      return values
          .whereType<Map>()
          .map((map) => CaptureEntry.fromMap(map))
          .whereType<CaptureEntry>()
          .toList();
    } on MissingPluginException {
      return [];
    }
  }

  Future<void> acknowledge(String id) =>
      channel.invokeMethod('acknowledge', {'id': id});
  Future<bool> pinWidget() async {
    try {
      return await channel.invokeMethod<bool>('pinWidget') ?? false;
    } on MissingPluginException {
      return false;
    }
  }

  void dispose() {
    channel.setMethodCallHandler(null);
    unawaited(_changes.close());
  }
}

/// An external entry stops any foreground recording before replacing its route.
/// Typed/partial input is flushed first, so a new share never hides a live mic.
class CaptureInterruption {
  static Future<void> Function()? active;
  static Future<void> stop() async {
    await active?.call();
  }
}
