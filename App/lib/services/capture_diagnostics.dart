import 'package:agenda/services/task_database.dart';

/// Deliberately accepts no text, transcript, account ID, audio or arbitrary tags.
enum CaptureEvent {
  started,
  recordingStopped,
  transcription,
  extraction,
  processing,
  failed,
  retried,
  edited,
  saved,
  discarded,
  resumed
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
      'samples': matches.length,
      'p50_ms': percentile(.5),
      'p95_ms': percentile(.95)
    };
  }

  Future<void> clear() async => (await database.database).delete('diagnostics');
}
