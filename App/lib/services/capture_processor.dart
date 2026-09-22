import 'package:agenda/models/capture_session.dart';
import 'package:agenda/models/task_draft.dart';
import 'package:agenda/services/api_client.dart';
import 'package:agenda/services/capture_diagnostics.dart';
import 'package:agenda/services/capture_store.dart';

class CaptureProcessor {
  static final Map<String, Future<CaptureSession>> _active = {};
  final CaptureStore store;
  final ApiClient api;
  CaptureProcessor(this.store, this.api);

  Future<CaptureSession> process(CaptureSession session) {
    final key = '${session.ownerKey}:${session.id}';
    return _active.putIfAbsent(
        key,
        () => _process(session).whenComplete(() {
              _active.remove(key);
            }));
  }

  Future<CaptureSession> _process(CaptureSession session) async {
    final existing = await store.read(session.id, session.ownerKey);
    if (existing == null || existing.terminal) {
      throw StateError('Capture is no longer available.');
    }
    if (existing.drafts.isNotEmpty) return existing;
    final diagnostics = CaptureDiagnostics(store.database);
    final watch = Stopwatch()..start();
    if (existing.status == 'failed') {
      await diagnostics.record(CaptureEvent.retried);
    }
    await store.update(existing.copyWith(status: 'processing'));
    try {
      if (existing.audioPath != null) {
        await CaptureStore.recoverWav(existing.audioPath!);
      }
      final raw = await api.request('POST', 'ai/drafts/',
          audioPath: existing.audioPath,
          authenticated: existing.ownerKey != 'local',
          accountId: existing.ownerKey == 'local'
              ? null
              : int.parse(existing.ownerKey.split('/').last),
          data: {
            'timezone': existing.timezone,
            'reference_time': existing.capturedAt.toUtc().toIso8601String(),
            if (existing.audioPath == null) 'text': existing.text
          });
      final response = Map<String, dynamic>.from(raw as Map);
      final transcript = response['transcript'] as String;
      final drafts = (response['tasks'] as List)
          .map((item) => CaptureDraft.fromAI(TaskDraft.fromJson(
              {...Map<String, dynamic>.from(item), 'transcript': transcript})))
          .toList();
      if (drafts.isEmpty) {
        throw StateError('No tasks were found. Your capture is kept.');
      }
      final next = existing.copyWith(
          status: 'ready', transcript: transcript, drafts: drafts);
      await store.update(next);
      await diagnostics.record(CaptureEvent.processing,
          elapsedMs: watch.elapsedMilliseconds, count: drafts.length);
      final timings = response['timings'];
      if (timings is Map) {
        for (final entry in {
          CaptureEvent.transcription: 'transcription_ms',
          CaptureEvent.extraction: 'extraction_ms'
        }.entries) {
          if (entry.key == CaptureEvent.transcription &&
              existing.audioPath == null) continue;
          final elapsed = timings[entry.value];
          if (elapsed is int) {
            await diagnostics.record(entry.key, elapsedMs: elapsed);
          }
        }
      }
      return next;
    } catch (error) {
      final latest = await store.read(existing.id, existing.ownerKey);
      if (latest != null && !latest.terminal) {
        await store
            .update(latest.copyWith(status: 'failed', error: error.toString()));
      }
      await diagnostics.record(CaptureEvent.failed,
          elapsedMs: watch.elapsedMilliseconds);
      rethrow;
    }
  }
}
