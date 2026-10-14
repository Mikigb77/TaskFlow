import 'package:agenda/models/capture_session.dart';
import 'package:agenda/models/task_draft.dart';
import 'package:agenda/models/task.dart';
import 'package:agenda/services/api_client.dart';
import 'package:agenda/services/capture_diagnostics.dart';
import 'package:agenda/services/capture_store.dart';
import 'package:agenda/services/capture_problem.dart';
import 'package:agenda/services/local_capture.dart';

class CaptureProcessor {
  static final Map<String, Future<CaptureSession>> _active = {};
  // Captures saved as written while the assistant was still asked: its late
  // answer, or failure, changes nothing.
  static final Set<String> _written = {};
  final CaptureStore store;
  final ApiClient api;
  CaptureProcessor(this.store, this.api);

  /// A note's title is its first line's first sentence, or about
  /// [noteTitleLength] characters cut at a word. Speech has no line breaks,
  /// so without this the whole transcript would become the title. The full
  /// text stays in the note's body.
  static String noteTitle(String text) =>
      leadingTitle(text, noteTitleLength).title;

  /// Understands the capture's words. [local] builds the result on the phone,
  /// with no network, as typing without Pro does. A task understood with no
  /// date and no deadline gets the session's day while it is after [now]'s.
  Future<CaptureSession> process(
    CaptureSession session, {
    bool local = false,
    DateTime? now,
  }) {
    final key = _key(session);
    return _active.putIfAbsent(
      key,
      () => _process(session, local, now ?? DateTime.now()).whenComplete(() {
        _active.remove(key);
        _written.remove(key);
      }),
    );
  }

  /// `Guardar tal cual`: the words as written, understood on the phone, while
  /// the assistant is slow or after it failed. Its answer, if one still
  /// comes, is ignored.
  Future<CaptureSession> asWritten(
    CaptureSession session, {
    DateTime? now,
  }) async {
    final key = _key(session);
    _written.add(key);
    try {
      final existing = await store.read(session.id, session.ownerKey);
      if (existing == null || existing.terminal) {
        throw StateError('Capture is no longer available.');
      }
      final next = _local(existing, now ?? DateTime.now());
      await store.update(next);
      return next;
    } finally {
      if (!_active.containsKey(key)) _written.remove(key);
    }
  }

  static String _key(CaptureSession session) =>
      '${session.ownerKey}:${session.id}';

  /// Only a later day: today, or a day gone by, adds nothing.
  static DateTime? _laterDay(CaptureSession session, DateTime now) =>
      session.day != null && Task.day(session.day!).isAfter(Task.day(now))
      ? Task.day(session.day!)
      : null;

  /// The result built on the phone, with the date the words name.
  static CaptureSession _local(CaptureSession existing, DateTime now) {
    final note = existing.kind == 'note';
    if (existing.text.trim().isEmpty) {
      throw StateError(
        note
            ? 'A note needs 1 to 8000 characters.'
            : 'Say or type what you need to do first.',
      );
    }
    if (note && existing.text.length > 8000) {
      throw StateError('A note needs 1 to 8000 characters.');
    }
    return existing.copyWith(
      status: 'ready',
      transcript: existing.text,
      drafts: localDrafts(
        existing.text,
        existing.capturedAt.toLocal(),
        // Notes never get a day.
        defaultDay: note ? null : _laterDay(existing, now),
        kind: existing.kind,
        projectId: existing.projectId,
      ),
    );
  }

  Future<CaptureSession> _process(
    CaptureSession session,
    bool local,
    DateTime now,
  ) async {
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
    final day = _laterDay(existing, now);
    final key = _key(existing);
    try {
      // Typed and on-device-transcribed notes stay entirely local. Selecting
      // Note is explicit; dates in reference material never become tasks.
      // Tasks typed without Pro are understood here too.
      final note = existing.kind == 'note';
      if (existing.audioPath == null && (note || local)) {
        final next = _local(existing, now);
        await store.update(next);
        if (note) {
          await diagnostics.record(
            CaptureEvent.notePrepared,
            elapsedMs: watch.elapsedMilliseconds,
            count: 1,
          );
        }
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
      final drafts = (response['tasks'] as List).map((item) {
        final draft = CaptureDraft.fromAI(
          TaskDraft.fromJson({
            ...Map<String, dynamic>.from(item),
            'transcript': transcript,
          }),
        );
        final task = draft.task;
        return day == null ||
                task.isNote ||
                task.dueDate != null ||
                task.deadline != null
            ? draft
            : draft.copyWith(task: task.copyWith(dueDate: day, hasTime: false));
      }).toList();
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
      // Saved as written meanwhile: the answer is too late.
      if (_written.contains(key)) return _latest(existing);
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
      // Saved as written meanwhile: the assistant's failure doesn't matter.
      if (_written.contains(key)) return _latest(existing);
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

  Future<CaptureSession> _latest(CaptureSession session) async =>
      await store.read(session.id, session.ownerKey) ?? session;
}
