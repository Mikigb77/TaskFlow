import 'dart:async';

import 'package:agenda/models/capture_command.dart';
import 'package:agenda/models/capture_session.dart';
import 'package:agenda/models/task_draft.dart';
import 'package:agenda/models/task.dart';
import 'package:agenda/services/api_client.dart';
import 'package:agenda/services/capture_diagnostics.dart';
import 'package:agenda/services/capture_store.dart';
import 'package:agenda/services/capture_problem.dart';
import 'package:agenda/services/local_capture.dart';
import 'package:uuid/uuid.dart';

class CaptureProcessor {
  static final Map<String, Future<CaptureSession>> _active = {};
  // Captures saved as written, or dropped, while the assistant was still
  // asked: its late answer, or failure, changes nothing.
  static final Set<String> _written = {};
  // The capture_id of each request to the assistant still in flight.
  static final Map<String, String> _asking = {};
  // Captures whose request was cancelled ask again under a new capture_id:
  // the server refuses a cancelled one for a while.
  static final Map<String, String> _renewed = {};
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

  /// `Guardar como tarea`: the words as written, understood on the phone, while
  /// the assistant is slow or after it failed. Its answer, if one still
  /// comes, is ignored. On a result whose commands found nothing, [text] is
  /// its words (a dictation transcribed online has no text of its own); the
  /// commands are dropped, none applied.
  Future<CaptureSession> asWritten(
    CaptureSession session, {
    DateTime? now,
    String? text,
  }) async {
    final key = _key(session);
    _written.add(key);
    _cancelRequest(session);
    try {
      final existing = await store.read(session.id, session.ownerKey);
      if (existing == null || existing.terminal) {
        throw StateError('Capture is no longer available.');
      }
      final words = text != null && text.trim().isNotEmpty
          ? existing.copyWith(text: text)
          : existing;
      final next = _local(words, now ?? DateTime.now());
      await store.update(next);
      return next;
    } finally {
      if (!_active.containsKey(key)) _written.remove(key);
    }
  }

  /// Words dropped while the assistant understands them (Cancel after
  /// `Volver a decirlo`): the request is cancelled, so it uses no free
  /// dictation, and its late answer changes nothing.
  void cancel(CaptureSession session) {
    final key = _key(session);
    if (!_active.containsKey(key)) return;
    _written.add(key);
    _cancelRequest(session);
  }

  /// Tells the server, without waiting, that the request in flight for
  /// [session] is no longer wanted. The refusal that follows is ignored.
  void _cancelRequest(CaptureSession session) {
    final key = _key(session);
    final id = _asking[key];
    if (id == null) return;
    _renewed[key] = const Uuid().v4();
    final account = _accountId(session);
    if (account == null || !_validId(id)) return;
    unawaited(
      api
          .request('DELETE', 'ai/drafts/$id/', accountId: account)
          .then<void>((_) {}, onError: (Object _, StackTrace __) {}),
    );
  }

  static int? _accountId(CaptureSession session) => session.ownerKey == 'local'
      ? null
      : int.tryParse(session.ownerKey.split('/').last);

  static bool _validId(String id) => Uuid.isValidUUID(
    fromString: id,
    validationMode: ValidationMode.nonStrict,
  );

  /// The free dictations left, from a dictation's answer or refusal, go
  /// into the saved account without holding up the result.
  void _rememberFreeVoice(Object? block, CaptureSession session) {
    final account = _accountId(session);
    if (block == null || account == null) return;
    unawaited(
      api
          .rememberFreeVoice(block, accountId: account)
          .catchError((Object _) {}),
    );
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
      // Only tasks: a result's commands, if any, aren't kept.
      commands: const [],
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
    if (existing.hasResult) return existing;
    final diagnostics = CaptureDiagnostics(store.database);
    final watch = Stopwatch()..start();
    if (existing.status == 'failed') {
      unawaited(diagnostics.record(CaptureEvent.retried));
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
          unawaited(
            diagnostics.record(
              CaptureEvent.notePrepared,
              elapsedMs: watch.elapsedMilliseconds,
              count: 1,
            ),
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
      // Dropped, or saved as written, before the request went out.
      if (_written.contains(key)) return _latest(existing);
      // The capture's own ID, so the server can tell a retry from new words
      // and a cancel can find the request.
      final captureId = _renewed[key] ?? existing.id;
      _asking[key] = captureId;
      final shared = existing.audioPath == null && existing.source == 'shared';
      final dynamic raw;
      try {
        raw = await api.request(
          'POST',
          'ai/drafts/',
          audioPath: existing.audioPath,
          authenticated: existing.ownerKey != 'local',
          accountId: existing.ownerKey == 'local'
              ? null
              : int.parse(existing.ownerKey.split('/').last),
          data: {
            if (_validId(captureId)) 'capture_id': captureId,
            'timezone': existing.timezone,
            if (existing.projectId != null) 'project_id': existing.projectId,
            'capture_type': existing.kind,
            'reference_time': existing.capturedAt.toUtc().toIso8601String(),
            if (existing.audioPath == null) 'text': existing.text,
            // The server knows speech and typed: shared text is typed.
            'source': existing.audioPath != null || existing.source == 'speech'
                ? 'speech'
                : 'typed',
            if (existing.language != null) 'language': existing.language,
            // Create a project, find, change or delete a task, besides tasks
            // (Backend/docs/VOICE_COMMANDS.md). A multipart form sends it as
            // `true` too. Shared text is someone else's words: only tasks.
            if (!shared) 'commands': true,
          },
        );
      } finally {
        _asking.remove(key);
      }
      final response = Map<String, dynamic>.from(raw as Map);
      // Even when saved as written meanwhile: an answered dictation counts.
      _rememberFreeVoice(response['free_voice'], existing);
      final transcript = response['transcript'] as String;
      // An older server sends no commands: the answer is today's. Kinds this
      // app doesn't know are left out. Notes take no commands.
      final commands = existing.kind == 'note' || response['commands'] is! List
          ? const <CaptureCommand>[]
          : [
              for (final item in response['commands'] as List)
                ?CaptureCommand.fromServer(item),
            ];
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
      // With commands, an answer may hold no task.
      if (drafts.isEmpty && commands.isEmpty) {
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
        commands: commands,
      );
      // Saved as written meanwhile: the answer is too late.
      if (_written.contains(key)) return _latest(existing);
      await store.update(next);
      unawaited(
        diagnostics.record(
          existing.kind == 'note'
              ? CaptureEvent.noteTranscribed
              : CaptureEvent.processing,
          elapsedMs: watch.elapsedMilliseconds,
          count: drafts.length,
        ),
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
            unawaited(diagnostics.record(entry.key, elapsedMs: elapsed));
          }
        }
      }
      return next;
    } catch (error) {
      if (error is ApiException) {
        _rememberFreeVoice(error.body?['free_voice'], existing);
      }
      // Saved as written meanwhile: the assistant's failure doesn't matter.
      if (_written.contains(key)) return _latest(existing);
      final latest = await store.read(existing.id, existing.ownerKey);
      if (latest != null && !latest.terminal) {
        await store.update(
          latest.copyWith(status: 'failed', error: CaptureProblem.from(error)),
        );
      }
      unawaited(
        diagnostics.record(
          CaptureEvent.failed,
          elapsedMs: watch.elapsedMilliseconds,
        ),
      );
      rethrow;
    }
  }

  Future<CaptureSession> _latest(CaptureSession session) async =>
      await store.read(session.id, session.ownerKey) ?? session;
}
