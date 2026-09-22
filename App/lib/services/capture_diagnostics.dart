import 'package:agenda/services/task_database.dart';

/// Deliberately accepts no text, transcript, account ID, audio or arbitrary tags.
enum CaptureEvent {
  opened,
  ready,
  started,
  typedStarted,
  permissionDenied,
  nativeStarted,
  firstPartial,
  nativeListening,
  recordingStopped,
  transcription,
  extraction,
  processing,
  failed,
  retried,
  edited,
  reviewOpened,
  reviewTime,
  correction,
  saved,
  discarded,
  resumed,
  leftCapturePending,
  leftReviewPending
}

extension CaptureEventLabel on CaptureEvent {
  String get label => switch (this) {
        CaptureEvent.opened => 'Capture opened',
        CaptureEvent.ready => 'Capture ready to use',
        CaptureEvent.started => 'New durable captures',
        CaptureEvent.typedStarted => 'Typed input started',
        CaptureEvent.permissionDenied => 'Microphone permission denied',
        CaptureEvent.nativeStarted => 'On-device listening started',
        CaptureEvent.firstPartial => 'First on-device words',
        CaptureEvent.nativeListening => 'On-device listening duration',
        CaptureEvent.recordingStopped => 'Saved audio duration',
        CaptureEvent.transcription => 'Online audio transcription',
        CaptureEvent.extraction => 'Online task extraction',
        CaptureEvent.processing => 'Request and retained drafts',
        CaptureEvent.failed => 'Failed requests',
        CaptureEvent.retried => 'Retried requests',
        CaptureEvent.edited => 'Draft changes',
        CaptureEvent.reviewOpened => 'Review opened',
        CaptureEvent.reviewTime => 'Time in review',
        CaptureEvent.correction => 'Correction dialog time',
        CaptureEvent.saved => 'Confirmed to local save',
        CaptureEvent.discarded => 'Explicitly discarded captures',
        CaptureEvent.resumed => 'Resumed captures',
        CaptureEvent.leftCapturePending => 'Capture kept for later',
        CaptureEvent.leftReviewPending => 'Review kept for later',
      };
}

class CaptureDiagnostics {
  final TaskDatabase database;
  CaptureDiagnostics(this.database);

  Future<void> record(CaptureEvent event, {int? elapsedMs, int? count}) async {
    try {
      final db = await database.database;
      await db.insert('diagnostics', {
        'event': event.name,
        'elapsed_ms': elapsedMs?.clamp(0, 600000),
        'count': count?.clamp(0, 100),
        'created_at': DateTime.now().toUtc().toIso8601String()
      });
      await db.rawDelete('DELETE FROM diagnostics WHERE id NOT IN '
          '(SELECT id FROM diagnostics ORDER BY id DESC LIMIT 1000)');
    } catch (_) {/* Diagnostics must not stop a capture or task save. */}
  }

  Future<List<Map<String, Object?>>> summary() async {
    final rows = await (await database.database).query('diagnostics');
    return [for (final event in CaptureEvent.values) _summarize(event, rows)];
  }

  Map<String, Object?> _summarize(
      CaptureEvent event, List<Map<String, Object?>> rows) {
    final matches = rows.where((row) => row['event'] == event.name).toList();
    final times = matches
        .map((row) => row['elapsed_ms'])
        .whereType<int>()
        .toList()
      ..sort();
    int? percentile(double p) => times.isEmpty
        ? null
        : times[((times.length * p).ceil() - 1).clamp(0, times.length - 1)];
    return {
      'event': event.name,
      'label': event.label,
      'samples': matches.length,
      'timed_samples': times.length,
      'items': matches
          .map((row) => row['count'])
          .whereType<int>()
          .fold<int>(0, (a, b) => a + b),
      'p50_ms': percentile(.5),
      'p95_ms': percentile(.95)
    };
  }

  Future<void> clear() async => (await database.database).delete('diagnostics');
}
