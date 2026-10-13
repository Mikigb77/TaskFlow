// Entitlement is a fixture here; real paid access is covered by projects_flow_test.
import 'package:agenda/providers/subscription_provider.dart';
// Run twice per LIFECYCLE_CASE on an emulator launched with `-audio none`.
// First run waits for an external `adb shell am force-stop`; disconnection is
// expected. The next run verifies the same SQLite journal and recording bytes.
// Disable host input with `adb emu avd hostmicoff` too. Native audio still has
// emulator-generated samples; a controlled response exercises retry/review/save
// after WAV recovery. No real microphone content or AI service is used.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:agenda/l10n/generated/app_localizations.dart';
import 'package:agenda/models/capture_session.dart';
import 'package:agenda/providers/auth_provider.dart';
import 'package:agenda/providers/regional_provider.dart';
import 'package:agenda/providers/task_provider.dart';
import 'package:agenda/providers/theme_provider.dart';
import 'package:agenda/screens/review_tasks_screen.dart';
import 'package:agenda/screens/voice_task_screen.dart';
import 'package:agenda/services/capture_store.dart';
import 'package:agenda/services/native_speech.dart';
import 'package:agenda/services/task_database.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import '../test/support/design_fixtures.dart';

const _owner = 'capture-process-fixture/users/999999';
const _marker = 'capture-process-fixture-v1';
const _case = String.fromEnvironment('LIFECYCLE_CASE');
const _words = 'Synthetic reference\nFriday at five is an example, not a task.';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('native process recovery: $_case', (tester) async {
    expect([
      'audio-abrupt',
      'audio-background',
      'audio-call',
      'text-abrupt',
    ], contains(_case));
    final database = TaskDatabase();
    final sql = await database.database;
    final store = CaptureStore(database);
    final rows = await sql.query(
      'app_preferences',
      where: 'scope = ?',
      whereArgs: [_marker],
    );
    final checkpoint = rows.isEmpty
        ? null
        : Map<String, dynamic>.from(jsonDecode(rows.single['data'] as String));
    final api = _ControlledApi(checkpoint);
    final container = ProviderContainer(
      overrides: [
        hasProProvider.overrideWithValue(true),
        captureOwnerProvider.overrideWithValue(_owner),
        apiClientProvider.overrideWithValue(api),
        // Force the real AudioRecorder path independently of model installation.
        nativeSpeechProvider.overrideWithValue(_NoNativeSpeech()),
        taskProvider.overrideWith((ref) => DesignTaskNotifier()),
        regionalStoreProvider.overrideWithValue(MemoryRegionalStore()),
        themeStoreProvider.overrideWithValue(MemoryThemeStore()),
      ],
    );
    addTearDown(() {
      container.dispose();
      api.close();
    });
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: Text('Isolated process recovery fixture')),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    if (checkpoint == null) {
      // Explicit opt-in cleanup after a failed fixture preparation. Only the
      // constant synthetic owner is eligible, never normal guest/account data.
      if (const bool.fromEnvironment('LIFECYCLE_RESET_FIXTURE')) {
        for (final orphan in await store.pending(_owner)) {
          await store.discard(orphan.id, _owner);
        }
        await sql.delete(
          'captures',
          where: 'owner_key = ?',
          whereArgs: [_owner],
        );
      }
      expect(
        await store.pending(_owner),
        isEmpty,
        reason: 'Do not overwrite a previous unfinished fixture.',
      );
      expect(await database.getTasks(ownerKey: _owner), isEmpty);
      navigator.push(
        MaterialPageRoute<void>(
          builder: (_) => const VoiceTaskScreen(
            kind: _case == 'text-abrupt' ? 'note' : 'task',
            startRecording: _case != 'text-abrupt',
          ),
        ),
      );
      await _until(tester, () async {
        if (_case == 'text-abrupt') {
          return find
              .byKey(const ValueKey('capture-words'))
              .evaluate()
              .isNotEmpty;
        }
        final pending = await store.pending(_owner);
        if (pending.isEmpty || pending.single.audioPath == null) return false;
        final file = File(pending.single.audioPath!);
        return await file.exists() && await file.length() >= 64044;
      });
      if (_case == 'text-abrupt') {
        final words = find.byKey(const ValueKey('capture-words'));
        await tester.scrollUntilVisible(
          words,
          180,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        await tester.enterText(words, _words);
        await _until(
          tester,
          () async =>
              (await store.pending(_owner)).any((s) => s.text == _words),
        );
      }
      final session = (await store.pending(_owner)).single;
      final metadata = <String, dynamic>{
        'case': _case,
        'id': session.id,
        'capturedAt': session.capturedAt.toIso8601String(),
        'timezone': session.timezone,
        'kind': session.kind,
      };
      if (session.audioPath != null) {
        final bytes = await File(session.audioPath!).readAsBytes();
        expect(session.audioFormat, CaptureSession.androidPcmWav);
        final offset = bytes.take(44).every((value) => value == 0)
            ? 44
            : _dataOffset(bytes);
        final retained = bytes.sublist(offset, offset + 32000);
        metadata['audioPath'] = session.audioPath;
        metadata['sampleOffset'] = offset;
        metadata['sampleHash'] = sha256.convert(retained).toString();
        metadata['minimumLength'] = bytes.length;
        expect(session.status, 'recording');
      }
      await sql.insert('app_preferences', {
        'scope': _marker,
        'data': jsonEncode(metadata),
      });
      if (_case == 'audio-call') {
        // The host simulates a GSM call, verifies Android's RINGING/OFFHOOK
        // states, then cancels that exact call and returns to this activity.
        debugPrint('CAPTURE_CALL_READY: $_case');
        await _until(
          tester,
          () async =>
              (await store.read(session.id, _owner))?.status == 'editing',
        );
        expect(
          find.textContaining('Listening ·'),
          findsNothing,
          reason: 'An interrupted recorder must not look active.',
        );
        expect(api.calls, 0, reason: 'An interruption must not submit audio.');
        final stopped = (await store.read(session.id, _owner))!;
        final retained = await File(stopped.audioPath!).readAsBytes();
        _dataOffset(retained); // Normal interruption must finalize the WAV.
        _assertRetainedSamples(retained, metadata);
        debugPrint('CAPTURE_CALL_RETAINED: ${retained.length} bytes');
      }
      debugPrint('CAPTURE_KILL_READY: $_case');
      // The host terminates this process before the 59-second capture limit.
      // No successful test result is possible without a second process launch.
      for (var tick = 0; tick < 300; tick++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      fail('Host did not terminate the fixture process after its checkpoint.');
    }

    expect(checkpoint['case'], _case);
    final id = checkpoint['id'] as String;
    final session = (await store.read(id, _owner))!;
    expect(session.capturedAt.toIso8601String(), checkpoint['capturedAt']);
    expect(session.timezone, checkpoint['timezone']);
    expect(session.kind, checkpoint['kind']);
    if (_case != 'text-abrupt') {
      expect(session.audioFormat, CaptureSession.androidPcmWav);
    }
    expect(await store.read(id, 'another-owner'), isNull);
    expect(session.status, _case == 'audio-abrupt' ? 'recording' : 'editing');
    if (_case == 'text-abrupt') {
      expect(session.text, _words);
      expect(session.audioPath, isNull);
    } else {
      final before = await File(session.audioPath!).readAsBytes();
      expect(before.length, greaterThanOrEqualTo(checkpoint['minimumLength']));
      _assertRetainedSamples(before, checkpoint);
      debugPrint('CAPTURE_RETAINED: $_case ${before.length} bytes');
    }

    navigator.push(
      MaterialPageRoute<void>(builder: (_) => VoiceTaskScreen(captureId: id)),
    );
    await tester.pumpAndSettle();
    if (_case == 'text-abrupt') {
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('capture-words')))
            .controller!
            .text,
        _words,
      );
    }
    final retry = find.widgetWithText(
      FilledButton,
      _case == 'text-abrupt' ? 'Review note' : 'Try this recording',
    );
    await tester.scrollUntilVisible(
      retry,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(retry);
    await _until(
      tester,
      () async => find.byType(ReviewTasksScreen).evaluate().isNotEmpty,
    );
    final ready = (await store.read(id, _owner))!;
    expect(ready.ready, hasLength(1));
    expect(api.calls, _case == 'text-abrupt' ? 0 : 1);
    final saved = await store.saveReady(id, _owner, {ready.ready.single.id});
    await store.saveReady(id, _owner, {ready.ready.single.id});
    expect(saved.status, 'saved');
    expect(await database.getTasks(ownerKey: _owner), hasLength(1));
    if (session.audioPath != null) {
      expect(await File(session.audioPath!).exists(), isFalse);
    }
    // Dispose the screen before removing only this fixture's scoped rows.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await sql.delete('tasks', where: 'owner_key = ?', whereArgs: [_owner]);
    await sql.delete('captures', where: 'owner_key = ?', whereArgs: [_owner]);
    await sql.delete(
      'app_preferences',
      where: 'scope = ?',
      whereArgs: [_marker],
    );
    debugPrint('CAPTURE_PROCESS_VALIDATED: $_case');
  }, timeout: const Timeout(Duration(minutes: 3)));
}

Future<void> _until(WidgetTester tester, Future<bool> Function() ready) async {
  final watch = Stopwatch()..start();
  while (!await ready()) {
    if (watch.elapsed > const Duration(seconds: 20)) {
      fail('Capture fixture did not reach its checkpoint.');
    }
    await tester.pump(const Duration(milliseconds: 100));
  }
  await tester.pump();
}

int _dataOffset(Uint8List bytes) {
  expect(ascii.decode(bytes.sublist(0, 4)), 'RIFF');
  expect(ascii.decode(bytes.sublist(8, 12)), 'WAVE');
  final data = ByteData.sublistView(bytes);
  var offset = 12;
  while (offset + 8 <= bytes.length) {
    if (ascii.decode(bytes.sublist(offset, offset + 4)) == 'data') {
      return offset + 8;
    }
    final size = data.getUint32(offset + 4, Endian.little);
    offset += 8 + size + (size.isOdd ? 1 : 0);
  }
  throw StateError('Native recording has no conventional WAV data chunk.');
}

void _assertRetainedSamples(Uint8List bytes, Map<String, dynamic> checkpoint) {
  final offset = checkpoint['sampleOffset'] as int;
  expect(
    sha256.convert(bytes.sublist(offset, offset + 32000)).toString(),
    checkpoint['sampleHash'],
  );
}

class _NoNativeSpeech extends NativeSpeech {
  @override
  Future<SpeechCapability> capability({String? language}) async =>
      const SpeechCapability();
}

class _ControlledApi extends OfflineApiClient {
  _ControlledApi(this.checkpoint);
  final Map<String, dynamic>? checkpoint;
  int calls = 0;
  @override
  Future<dynamic> request(
    String method,
    String path, {
    Map<String, dynamic>? data,
    String? audioPath,
    bool authenticated = true,
    int? accountId,
  }) async {
    calls++;
    expect(method, 'POST');
    expect(path, 'ai/drafts/');
    expect(data!['reference_time'], checkpoint!['capturedAt']);
    expect(data['timezone'], checkpoint!['timezone']);
    expect(audioPath, checkpoint!['audioPath']);
    final bytes = await File(audioPath!).readAsBytes();
    _assertRetainedSamples(bytes, checkpoint!);
    final offset = _dataOffset(bytes);
    final header = ByteData.sublistView(bytes);
    expect(header.getUint32(4, Endian.little), bytes.length - 8);
    expect(header.getUint32(offset - 4, Endian.little), bytes.length - offset);
    return {
      'transcript': 'Controlled lifecycle fixture; no speech service called.',
      'tasks': [
        {
          'title': 'Synthetic recovery fixture',
          'priority': 1,
          'notes': '',
          'questions': <String>[],
        },
      ],
    };
  }
}
