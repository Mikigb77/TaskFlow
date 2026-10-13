import 'package:agenda/models/capture_session.dart';
import 'package:agenda/models/task_draft.dart';
import 'package:agenda/models/task.dart';
import 'package:uuid/uuid.dart';
import 'package:agenda/services/api_client.dart';
import 'package:agenda/services/capture_diagnostics.dart';
import 'package:agenda/services/capture_store.dart';
import 'package:agenda/services/capture_problem.dart';

class CaptureProcessor {
  static final Map<String, Future<CaptureSession>> _active = {};
  final CaptureStore store;
  final ApiClient api;
  CaptureProcessor(this.store, this.api);

  /// About how long a note title may be before it is cut at a word.
  static const noteTitleLength = 60;

  /// A note's title is its first line's first sentence, or about
  /// [noteTitleLength] characters cut at a word. Speech has no line breaks,
  /// so without this the whole transcript would become the title. The full
  /// text stays in the note's body.
  static String noteTitle(String text) {
    var title = text.trim().split('\n').first.trim();
    final sentence = RegExp(r'^(.+?[.!?…])(?=\s|$)').firstMatch(title);
    if (sentence != null) title = sentence.group(1)!;
    if (title.endsWith('.') && !title.endsWith('..')) {
      title = title.substring(0, title.length - 1);
    }
    final runes = title.runes.toList();
    if (runes.length <= noteTitleLength) return title;
    final cut = String.fromCharCodes(runes.take(noteTitleLength + 1));
    final space = cut.lastIndexOf(RegExp(r'\s'));
    final words = space > noteTitleLength ~/ 3
        ? cut.substring(0, space)
        : String.fromCharCodes(runes.take(noteTitleLength));
    return words.replaceFirst(RegExp(r'[\s,;:]+$'), '');
  }

  Future<CaptureSession> process(CaptureSession session) {
    final key = '${session.ownerKey}:${session.id}';
    return _active.putIfAbsent(
      key,
      () => _process(session).whenComplete(() {
        _active.remove(key);
      }),
    );
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
      // Typed and on-device-transcribed notes stay entirely local. Selecting
      // Note is explicit; dates in reference material never become tasks.
      if (existing.kind == 'note' && existing.audioPath == null) {
        if (existing.text.trim().isEmpty || existing.text.length > 8000) {
          throw StateError('A note needs 1 to 8000 characters.');
        }
        final next = existing.copyWith(
          status: 'ready',
          transcript: existing.text,
          drafts: [
            CaptureDraft(
              id: const Uuid().v4(),
              task: Task(
                kind: 'note',
                listId: existing.projectId,
                title: noteTitle(existing.text),
                priority: 1,
                notes: existing.text,
              ),
            ),
          ],
        );
        await store.update(next);
        await diagnostics.record(
          CaptureEvent.notePrepared,
          elapsedMs: watch.elapsedMilliseconds,
          count: 1,
        );
        return next;
      }
      if (existing.audioPath != null) {
        await CaptureStore.recoverWav(
          existing.audioPath!,
          audioFormat: existing.audioFormat,
        );
      }
      final raw = await api.request(
        'POST',
        'ai/drafts/',
        audioPath: existing.audioPath,
        authenticated: existing.ownerKey != 'local',
        accountId: existing.ownerKey == 'local'
            ? null
            : int.parse(existing.ownerKey.split('/').last),
        data: {
          'timezone': existing.timezone,
          if (existing.projectId != null) 'project_id': existing.projectId,
          'capture_type': existing.kind,
          'reference_time': existing.capturedAt.toUtc().toIso8601String(),
          if (existing.audioPath == null) 'text': existing.text,
          'source': existing.audioPath != null
              ? 'speech'
              : existing.source ?? 'typed',
        },
      );
      final response = Map<String, dynamic>.from(raw as Map);
      final transcript = response['transcript'] as String;
      final drafts = (response['tasks'] as List)
          .map(
            (item) => CaptureDraft.fromAI(
              TaskDraft.fromJson({
                ...Map<String, dynamic>.from(item),
                'transcript': transcript,
              }),
            ),
          )
          .toList();
      if (drafts.isEmpty) {
        throw StateError('No tasks were found. Your capture is kept.');
      }
      if (drafts.any((draft) => draft.task.kind != existing.kind)) {
        throw StateError(
          'This server does not support the selected capture type. Your input is kept.',
        );
      }
      final next = existing.copyWith(
        status: 'ready',
        transcript: transcript,
        drafts: drafts,
      );
      await store.update(next);
      await diagnostics.record(
        existing.kind == 'note'
            ? CaptureEvent.noteTranscribed
            : CaptureEvent.processing,
        elapsedMs: watch.elapsedMilliseconds,
        count: drafts.length,
      );
      final timings = response['timings'];
      if (timings is Map) {
        for (final entry in {
          CaptureEvent.transcription: 'transcription_ms',
          CaptureEvent.extraction: 'extraction_ms',
        }.entries) {
          if (existing.kind == 'note' && entry.key == CaptureEvent.extraction) {
            continue;
          }
          if (entry.key == CaptureEvent.transcription &&
              existing.audioPath == null) {
            continue;
          }
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
        await store.update(
          latest.copyWith(status: 'failed', error: CaptureProblem.from(error)),
        );
      }
      await diagnostics.record(
        CaptureEvent.failed,
        elapsedMs: watch.elapsedMilliseconds,
      );
      rethrow;
    }
  }
}
