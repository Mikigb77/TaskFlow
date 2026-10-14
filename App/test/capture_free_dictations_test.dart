// UX loop 2026-10-13-app, round 1 (batch b7): free dictations in the capture
// sheet.
// P89 (UX-497, UX-499): free accounts get the mic while dictations are left;
// typed words never count; a capture_id with every request, and a cancel
// when the words are saved as written or dropped while understood.
// P90 (UX-498): used up — the words are kept, typing takes over, and the
// sheet says when more come.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:agenda/l10n/capture_messages.dart';
import 'package:agenda/l10n/generated/app_localizations.dart';
import 'package:agenda/l10n/region.dart';
import 'package:agenda/main.dart';
import 'package:agenda/models/capture_session.dart';
import 'package:agenda/models/task.dart';
import 'package:agenda/providers/auth_provider.dart';
import 'package:agenda/providers/calendar_focus_provider.dart';
import 'package:agenda/providers/regional_provider.dart';
import 'package:agenda/providers/subscription_provider.dart';
import 'package:agenda/providers/task_lists_provider.dart';
import 'package:agenda/providers/task_provider.dart';
import 'package:agenda/providers/theme_provider.dart';
import 'package:agenda/screens/captures_screen.dart';
import 'package:agenda/screens/voice_task_screen.dart';
import 'package:agenda/services/api_client.dart';
import 'package:agenda/services/capture_entries.dart';
import 'package:agenda/services/capture_problem.dart';
import 'package:agenda/services/capture_store.dart';
import 'package:agenda/services/invitation_links.dart';
import 'package:agenda/services/native_speech.dart';
import 'package:agenda/services/revenuecat_service.dart';
import 'package:agenda/services/task_database.dart';
import 'package:agenda/widgets/app_components.dart';
import 'package:agenda/widgets/attachment_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import 'support/billing_fixtures.dart';
import 'support/capture_fixtures.dart' show SilentRecorder;
import 'support/design_fixtures.dart';

final en = lookupAppLocalizations(const Locale('en'));
final es = lookupAppLocalizations(const Locale('es'));
final ca = lookupAppLocalizations(const Locale('ca'));
AppLocalizations strings(String language) =>
    lookupAppLocalizations(Locale(language));

/// When this month's free dictations come back, as the server says it.
DateTime nextReset() {
  final now = DateTime.now().toUtc();
  return DateTime.utc(now.year, now.month + 1);
}

Map<String, dynamic> freeVoice(int left, {int limit = 10, DateTime? resets}) =>
    {
      'limit': limit,
      'left': left,
      'resets_at': (resets ?? nextReset()).toIso8601String(),
    };

bool isUuid(Object? value) =>
    value is String &&
    Uuid.isValidUUID(
      fromString: value,
      validationMode: ValidationMode.nonStrict,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final platform =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const timeoutChannel = MethodChannel('taskflow/accessibility');
  const timezone = MethodChannel('flutter_timezone');
  setUp(() {
    platform.setMockMethodCallHandler(timeoutChannel, (_) async => 10000);
    platform.setMockMethodCallHandler(timezone, (_) async => 'Europe/Madrid');
  });
  tearDown(() {
    platform.setMockMethodCallHandler(timeoutChannel, null);
    platform.setMockMethodCallHandler(timezone, null);
  });

  Finder inSheet(Finder finder) =>
      find.descendant(of: find.byType(BottomSheet), matching: finder);
  Finder words() => find.byKey(const ValueKey('capture-words'));
  Finder button(String label) => find.widgetWithText(FilledButton, label);

  /// Frames while something spins (it never settles).
  Future<void> frames(WidgetTester tester, [int count = 6]) async {
    for (var i = 0; i < count; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  /// `Añadir tarea`, then the words said to the phone's recognizer, then
  /// `Listo`. The sheet must open on the mic.
  Future<void> dictate(
    WidgetTester tester,
    _FreeApp app,
    String said, {
    AppLocalizations? l,
    bool settle = true,
  }) async {
    final s = l ?? es;
    final before = app.speech.starts;
    await tester.tap(find.text(s.addTask).hitTestable());
    await tester.pumpAndSettle();
    expect(app.speech.starts, before + 1, reason: 'the sheet listens');
    app.speech.send('ready');
    app.speech.send('segment', text: said);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(button(s.done));
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await frames(tester);
    }
  }

  /// The used-up line's date: the reset day, local, in the app's short form.
  String resetDay(WidgetTester tester, DateTime resets) =>
      tester.element(find.byType(Scaffold).first).shortDate(resets.toLocal());

  // ---- P89 · UX-497: the mic while free dictations are left ----

  testWidgets(
    'UX-497: a free account with dictations left opens Añadir tarea on the mic; its dictation carries the capture’s capture_id, and the answer’s free_voice updates the saved count',
    (tester) async {
      final app = await _FreeApp.open(tester, freeVoice: freeVoice(5));
      expect(
        find.descendant(
          of: find.widgetWithText(FilledButton, es.addTask),
          matching: find.byIcon(Icons.mic_none_rounded),
        ),
        findsOneWidget,
      );
      app.api.answerFreeVoice = freeVoice(4);
      await dictate(tester, app, 'Comprar pan');

      expect(app.recorders, greaterThan(0), reason: 'the mic was set up');
      expect(app.api.drafts, hasLength(1));
      final sent = app.api.drafts.single;
      expect(sent['source'], 'speech');
      expect(isUuid(sent['capture_id']), isTrue, reason: '$sent');
      expect(
        app.store.sessions.keys,
        contains(sent['capture_id']),
        reason: 'the capture session’s own ID',
      );
      expect(find.byType(CaptureResult), findsOneWidget);

      // The answer's count is saved with the session, for offline use.
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pumpAndSettle();
      expect(app.container.read(authProvider).account!.freeVoice!.left, 4);
      expect(app.container.read(freeVoiceLeftProvider), 4);
      expect(app.api.account!.freeVoice!.left, 4);
      // More than 3 left: nothing about the count on the result.
      expect(find.text(es.freeVoiceLeft(4)), findsNothing);
      expect(find.byKey(const ValueKey('free-voice-left')), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  for (final pro in [false, true]) {
    testWidgets(
      'UX-497: ${pro ? 'with Pro, typed words go to the assistant as today' : 'a free account’s typed words are understood on the phone with no request and use no dictation'}',
      (tester) async {
        final app = await _FreeApp.open(
          tester,
          pro: pro,
          freeVoice: pro ? null : freeVoice(5),
        );
        await tester.tap(find.text(es.addTask).hitTestable());
        await tester.pumpAndSettle();
        expect(app.speech.starts, 1, reason: 'both open on the mic');
        await tester.tap(find.byTooltip(es.captureTypeInstead));
        await tester.pumpAndSettle();
        await tester.enterText(words(), 'Comprar pan');
        await tester.pumpAndSettle();
        await tester.tap(button(es.done));
        await tester.pumpAndSettle();
        expect(find.byType(CaptureResult), findsOneWidget);
        expect(app.api.drafts, hasLength(pro ? 1 : 0));
        expect(
          app.store.sessions.values.single.drafts.single.task.title,
          'Comprar pan',
        );
        if (!pro) {
          expect(app.container.read(freeVoiceLeftProvider), 5);
          expect(find.byKey(const ValueKey('free-voice-left')), findsNothing);
        }
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'UX-497: with no free_voice block (an older server), a free account’s Añadir tarea opens typing with the + icon and no recorder',
    (tester) async {
      final app = await _FreeApp.open(tester);
      expect(
        find.descendant(
          of: find.widgetWithText(FilledButton, es.addTask),
          matching: find.byIcon(Icons.add_rounded),
        ),
        findsOneWidget,
      );
      await tester.tap(find.text(es.addTask).hitTestable());
      await tester.pumpAndSettle();
      expect(words(), findsOneWidget);
      expect(app.speech.starts, 0);
      expect(app.recorders, 0);
      expect(find.byKey(const ValueKey('free-voice-used-up')), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  for (final language in ['es', 'en', 'ca']) {
    testWidgets(
      'UX-497: with 3 or fewer left, the result of a dictation says how many free dictations are left ($language, 2× text at 320 dp)',
      (tester) async {
        final l = strings(language);
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final app = await _FreeApp.open(
          tester,
          language: language,
          freeVoice: freeVoice(3),
          size: const Size(320, 700),
        );
        app.api.answerFreeVoice = freeVoice(2);
        await dictate(tester, app, 'Comprar pan', l: l);
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pumpAndSettle();
        expect(find.byType(CaptureResult), findsOneWidget);
        final line = find.text(l.freeVoiceLeft(2));
        expect(line, findsOneWidget);
        await tester.ensureVisible(line);
        await tester.pumpAndSettle();
        final rect = tester.getRect(line);
        expect(rect.left, greaterThanOrEqualTo(0));
        expect(rect.right, lessThanOrEqualTo(320.5));
        expect(tester.takeException(), isNull);
      },
    );
  }

  test(
    'UX-497: freeVoiceLeft has a singular and a plural in EN, ES and CA, and speaks of dictations, never tasks',
    () {
      for (final (l, dictation, task) in [
        (en, 'dictation', 'task'),
        (es, 'dictado', 'tarea'),
        (ca, 'dictat', 'tasca'),
      ]) {
        final one = l.freeVoiceLeft(1);
        final three = l.freeVoiceLeft(3);
        expect(one, contains('1'));
        expect(three, contains('3'));
        expect(
          one.replaceFirst('1', 'N'),
          isNot(three.replaceFirst('3', 'N')),
          reason: '${l.localeName}: singular and plural differ',
        );
        for (final text in [one, three]) {
          expect(text.toLowerCase(), contains(dictation));
          expect(text.toLowerCase(), isNot(contains(task)));
        }
      }
    },
  );

  // ---- P89 · UX-499: capture_id, and the cancel ----

  testWidgets(
    'UX-499: Guardar tal cual while a free dictation is understood sends one DELETE for its capture_id, saves the words, ignores the 409 that follows; the next dictation uses a new capture_id',
    (tester) async {
      final app = await _FreeApp.open(tester, freeVoice: freeVoice(5));
      app.api.hold = Completer<void>();
      await dictate(tester, app, 'Llamar al médico', settle: false);
      expect(find.text(es.captureUnderstanding), findsOneWidget);
      await tester.pump(const Duration(seconds: 7));
      await tester.pump(const Duration(milliseconds: 1200));
      final save = button(es.captureSaveAsWritten);
      expect(save, findsOneWidget);
      final first = app.api.drafts.single['capture_id'];
      expect(isUuid(first), isTrue);
      expect(app.api.deletes, isEmpty);

      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(app.api.deletes, ['ai/drafts/$first/']);
      expect(find.byType(BottomSheet), findsNothing);
      expect(app.tasks.titles(), ['Llamar al médico']);

      // The held request ends with the server's 409 capture_cancelled.
      app.api.hold!.complete();
      app.api.hold = null;
      await tester.pumpAndSettle();
      expect(app.api.refusedAsCancelled, 1);
      expect(app.tasks.titles(), ['Llamar al médico']);
      expect(find.byType(MessageBanner), findsNothing);
      expect(app.api.deletes, hasLength(1), reason: 'one cancel only');

      await dictate(tester, app, 'Comprar pan');
      expect(app.api.drafts, hasLength(2));
      final second = app.api.drafts.last['capture_id'];
      expect(isUuid(second), isTrue);
      expect(second, isNot(first));
      expect(app.api.deletes, hasLength(1));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'UX-499: Volver a decirlo, then Cancelar while the new words are understood, sends one DELETE for the new capture_id and brings back the first result',
    (tester) async {
      final app = await _FreeApp.open(tester, freeVoice: freeVoice(5));
      await dictate(tester, app, 'Comprar pan');
      expect(find.byType(CaptureResult), findsOneWidget);
      final first = app.api.drafts.single['capture_id'];

      final sayAgain = find.text(es.captureSayAgain);
      await tester.ensureVisible(sayAgain);
      await tester.pumpAndSettle();
      await tester.tap(sayAgain);
      await tester.pumpAndSettle();
      expect(app.speech.starts, 2, reason: 'dictations are left: it listens');
      app.api.hold = Completer<void>();
      app.speech.send('ready');
      app.speech.send('segment', text: 'Comprar leche');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      await tester.tap(button(es.done));
      await frames(tester);
      expect(app.api.drafts, hasLength(2));
      final second = app.api.drafts.last['capture_id'];
      expect(second, isNot(first));

      await tester.tap(inSheet(find.widgetWithText(TextButton, es.cancel)));
      await frames(tester);
      expect(app.api.deletes, ['ai/drafts/$second/']);
      app.api.hold!.complete();
      await tester.pumpAndSettle();
      expect(find.byType(CaptureResult), findsOneWidget);
      expect(find.text('Comprar pan'), findsWidgets);
      expect(find.text('Comprar leche'), findsNothing);
      expect(app.api.deletes, hasLength(1));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'UX-499: closing the sheet while a dictation is understood sends no cancel, and the result waits in the pending list',
    (tester) async {
      final app = await _FreeApp.open(tester, freeVoice: freeVoice(5));
      app.api.hold = Completer<void>();
      await dictate(tester, app, 'Comprar pan', settle: false);
      await tester.tap(inSheet(find.widgetWithText(TextButton, es.cancel)));
      await frames(tester);
      expect(find.byType(BottomSheet), findsNothing);
      app.api.hold!.complete();
      await tester.pumpAndSettle();
      expect(app.api.deletes, isEmpty);
      final kept = app.store.sessions.values.single;
      expect(kept.status, isNot('discarded'));
      expect(kept.drafts, isNotEmpty);
      expect(
        (await app.container.read(
          pendingCapturesProvider.future,
        )).map((s) => s.id),
        [kept.id],
      );
      expect(tester.takeException(), isNull);
    },
  );

  // ---- P90 · UX-498: used up ----

  for (final language in ['es', 'en', 'ca']) {
    testWidgets(
      'UX-498: at 0 left, Añadir tarea opens typing with the used-up line naming the reset date and Ver Pro, and no recorder ($language)',
      (tester) async {
        final l = strings(language);
        final resets = nextReset();
        final app = await _FreeApp.open(
          tester,
          language: language,
          freeVoice: freeVoice(0, resets: resets),
        );
        expect(
          find.descendant(
            of: find.widgetWithText(FilledButton, l.addTask),
            matching: find.byIcon(Icons.add_rounded),
          ),
          findsOneWidget,
        );
        await tester.tap(find.text(l.addTask).hitTestable());
        await tester.pumpAndSettle();
        expect(words(), findsOneWidget, reason: 'it opens typing');
        expect(app.recorders, 0);
        expect(app.speech.starts, 0);
        final line = find.byKey(const ValueKey('free-voice-used-up'));
        expect(line, findsOneWidget);
        expect(
          tester.widget<Text>(line).data,
          l.freeVoiceUsedUp(resetDay(tester, resets)),
        );
        expect(find.text(l.captureSpeakingIsPro), findsNothing);
        expect(
          inSheet(find.widgetWithText(TextButton, l.voiceProAction)),
          findsOneWidget,
        );
        // Typing still works, understood on the phone.
        await tester.enterText(words(), 'Comprar pan');
        await tester.pumpAndSettle();
        await tester.tap(button(l.done));
        await tester.pumpAndSettle();
        expect(find.byType(CaptureResult), findsOneWidget);
        expect(app.api.drafts, isEmpty);
        expect(tester.takeException(), isNull);
      },
    );
  }

  test('UX-498: the used-up lines name the date in EN, ES and CA', () {
    for (final l in [en, es, ca]) {
      expect(l.freeVoiceUsedUp('DATE'), contains('DATE'));
      expect(l.freeVoiceUsedUpRecording('DATE'), contains('DATE'));
      expect(
        l.freeVoiceUsedUp('DATE'),
        isNot(l.freeVoiceUsedUpRecording('DATE')),
      );
    }
  });

  testWidgets(
    'UX-498: a 402 free_voice_used_up keeps the said words in the typing field with Guardar tal cual and the used-up line; no second request is made',
    (tester) async {
      final resets = nextReset();
      final app = await _FreeApp.open(tester, freeVoice: freeVoice(1));
      app.api.failure = ApiException(
        402,
        'Free voice used up for this month.',
        {
          'code': 'free_voice_used_up',
          'free_voice': freeVoice(0, resets: resets),
        },
      );
      await dictate(tester, app, 'Comprar pan');
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pumpAndSettle();
      expect(app.api.drafts, hasLength(1));
      expect(words(), findsOneWidget, reason: 'typing takes over');
      expect(tester.widget<TextField>(words()).controller!.text, 'Comprar pan');
      final line = find.byKey(const ValueKey('free-voice-used-up'));
      expect(line, findsOneWidget);
      expect(
        tester.widget<Text>(line).data,
        es.freeVoiceUsedUp(resetDay(tester, resets)),
      );
      expect(find.text('Free voice used up for this month.'), findsNothing);
      expect(find.text(es.tryAgain), findsNothing);
      expect(app.container.read(freeVoiceLeftProvider), 0);
      final kept = app.store.sessions.values.single;
      expect(kept.status, isNot('discarded'));

      await tester.tap(button(es.captureSaveAsWritten));
      await tester.pumpAndSettle();
      expect(app.api.drafts, hasLength(1), reason: 'no second request');
      expect(app.tasks.titles(), ['Comprar pan']);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'UX-498: a recording with no words refused with 402 stays pending with Tu grabación se conserva… and the reset date, and Capturas pendientes says the same',
    (tester) async {
      final resets = nextReset();
      final app = await _FreeApp.open(tester, freeVoice: freeVoice(1));
      final owner = app.container.read(captureOwnerProvider);
      app.store.sessions['wav'] = CaptureSession(
        id: 'wav',
        ownerKey: owner,
        timezone: 'Europe/Madrid',
        capturedAt: DateTime.now().toUtc(),
        audioPath: '${Directory.systemTemp.path}/taskflow-free-missing.wav',
        status: 'editing',
        source: 'speech',
      );
      app.api.failure = ApiException(
        402,
        'Free voice used up for this month.',
        {
          'code': 'free_voice_used_up',
          'free_voice': freeVoice(0, resets: resets),
        },
      );
      unawaited(
        showCaptureSheet(
          tester.element(find.byType(Scaffold).first),
          captureId: 'wav',
          startListening: false,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(button(es.done));
      for (var i = 0; i < 10 && app.api.drafts.isEmpty; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump();
      }
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pumpAndSettle();
      expect(app.api.drafts, hasLength(1));
      final line = find.byKey(const ValueKey('free-voice-used-up'));
      expect(line, findsOneWidget);
      final recordingLine = es.freeVoiceUsedUpRecording(
        resetDay(tester, resets),
      );
      expect(tester.widget<Text>(line).data, recordingLine);
      expect(find.text(es.captureSaveAsWritten), findsNothing);
      expect(app.store.sessions['wav']!.status, isNot('discarded'));
      // The fixture put the recording in the store directly: read afresh.
      app.container.invalidate(pendingCapturesProvider);
      expect(
        (await app.container.read(
          pendingCapturesProvider.future,
        )).map((s) => s.id),
        contains('wav'),
      );

      // Closed and kept: the pending list says when it can be understood.
      await tester.tap(
        inSheet(find.widgetWithText(FilledButton, es.captureClose)),
      );
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(app.store.sessions['wav']!.status, isNot('discarded'));
      tester
          .state<NavigatorState>(find.byType(Navigator).first)
          .pushNamed('/captures');
      await tester.pumpAndSettle();
      expect(find.byType(CapturesScreen), findsOneWidget);
      expect(find.textContaining(recordingLine), findsOneWidget);
      expect(app.api.drafts, hasLength(1));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'UX-498: a 503 billing_unavailable shows the usual try-again message, never the used-up line',
    (tester) async {
      final app = await _FreeApp.open(tester, freeVoice: freeVoice(5));
      app.api.failure = ApiException(503, 'Billing is unavailable.', {
        'code': 'billing_unavailable',
      });
      await dictate(tester, app, 'Comprar pan');
      expect(
        find.descendant(
          of: find.byType(MessageBanner),
          matching: find.text(es.captureUnavailable),
        ),
        findsOneWidget,
      );
      expect(button(es.tryAgain), findsOneWidget);
      expect(find.byKey(const ValueKey('free-voice-used-up')), findsNothing);
      expect(find.text('Billing is unavailable.'), findsNothing);
      expect(app.container.read(freeVoiceLeftProvider), 5);
      expect(tester.takeException(), isNull);
    },
  );

  group('UX-498: CaptureProblem', () {
    test('a 402 free_voice_used_up maps to freeVoiceUsedUp; a 402 without '
        'the code stays pro_required with the same text', () {
      final usedUp = CaptureProblem.from(
        ApiException(402, 'x', {'code': 'free_voice_used_up'}),
      );
      final legacy = CaptureProblem.from(ApiException(402, 'x'));
      expect(usedUp, CaptureProblem.freeVoiceUsedUp);
      expect(legacy, CaptureProblem.proRequired);
      final resets = DateTime.utc(2026, 11);
      for (final l in [en, es, ca]) {
        expect(
          captureProblemText(l, usedUp, freeVoiceResets: resets),
          captureProblemText(l, legacy, freeVoiceResets: resets),
        );
        expect(
          captureProblemText(l, usedUp, freeVoiceResets: resets),
          isNot(l.captureFailed),
        );
      }
    });
    test('a 503 billing_unavailable is the plain unavailable problem', () {
      expect(
        CaptureProblem.from(
          ApiException(503, 'x', {'code': 'billing_unavailable'}),
        ),
        CaptureProblem.unavailable,
      );
    });
  });

  // ---- P89 · UX-497: where the counts come from ----

  group('UX-497: the saved account', () {
    setUp(() => FlutterSecureStorage.setMockInitialValues({}));

    test('Account reads free_voice and storage, and leaves both null when '
        'an older server sends neither', () {
      final account = Account.fromJson({
        'id': 1,
        'email': 'a@example.invalid',
        'timezone': 'UTC',
        'free_voice': freeVoice(7, resets: DateTime.utc(2026, 11)),
        'storage': {'used_bytes': 1024, 'limit_bytes': 2048},
      });
      expect(account.freeVoice!.limit, 10);
      expect(account.freeVoice!.left, 7);
      expect(account.freeVoice!.resetsAt, DateTime.utc(2026, 11));
      expect(account.storage!.usedBytes, 1024);
      expect(account.storage!.limitBytes, 2048);
      final old = Account.fromJson({
        'id': 1,
        'email': 'a@example.invalid',
        'timezone': 'UTC',
      });
      expect(old.freeVoice, isNull);
      expect(old.storage, isNull);
    });

    test('a dictation’s free_voice is saved with the session and read back '
        'offline after a restart', () async {
      FlutterSecureStorage.setMockInitialValues({
        'taskflow.session': jsonEncode(_session(freeVoice(5))),
      });
      final api = ApiClient(url: 'http://free.test');
      addTearDown(api.close);
      await api.restore();
      expect(api.account!.freeVoice!.left, 5);
      await api.rememberFreeVoice(freeVoice(4), accountId: 1);
      expect(api.account!.freeVoice!.left, 4);
      // Another account's answer changes nothing.
      await api.rememberFreeVoice(freeVoice(1), accountId: 2);
      expect(api.account!.freeVoice!.left, 4);
      final again = ApiClient(url: 'http://free.test');
      addTearDown(again.close);
      await again.restore();
      expect(again.account!.freeVoice!.left, 4);
    });
  });

  group('UX-497: voiceAvailable', () {
    final resets = DateTime.utc(2026, 11);
    ProviderContainer container({
      bool? pro,
      Map<String, dynamic>? free,
      required DateTime now,
      SubscriptionController? subscription,
    }) {
      final api = OfflineApiClient();
      final c = ProviderContainer(
        overrides: [
          apiClientProvider.overrideWithValue(api),
          authProvider.overrideWith(
            (ref) => _AccountAuth(api, {
              'id': 1,
              'email': 'a@example.invalid',
              'timezone': 'UTC',
              if (subscription != null) 'complimentary_pro': true,
              if (free != null) 'free_voice': free,
            }),
          ),
          if (pro != null) hasProProvider.overrideWithValue(pro),
          if (subscription != null)
            subscriptionProvider.overrideWith((_) => subscription),
          calendarClockProvider.overrideWithValue(() => now),
        ],
      );
      addTearDown(c.dispose);
      addTearDown(api.close);
      return c;
    }

    test('without a free_voice block the mic follows hasPro', () {
      final now = DateTime.utc(2026, 10, 20);
      expect(
        container(pro: false, now: now).read(voiceAvailableProvider),
        isFalse,
      );
      expect(
        container(pro: true, now: now).read(voiceAvailableProvider),
        isTrue,
      );
    });

    test('a free account has the mic while left > 0; at 0 it hasn’t, until '
        'now ≥ resets_at, when the cached 0 counts as the full limit', () {
      final before = DateTime.utc(2026, 10, 31, 23, 59);
      final left = container(
        pro: false,
        free: freeVoice(2, resets: resets),
        now: before,
      );
      expect(left.read(voiceAvailableProvider), isTrue);
      expect(left.read(freeVoiceLeftProvider), 2);
      final none = container(
        pro: false,
        free: freeVoice(0, resets: resets),
        now: before,
      );
      expect(none.read(voiceAvailableProvider), isFalse);
      expect(none.read(freeVoiceLeftProvider), 0);
      for (final now in [resets, resets.add(const Duration(days: 3))]) {
        final renewed = container(
          pro: false,
          free: freeVoice(0, resets: resets),
          now: now,
        );
        expect(renewed.read(voiceAvailableProvider), isTrue, reason: '$now');
        expect(renewed.read(freeVoiceLeftProvider), 10, reason: '$now');
      }
    });

    test('Pro and complimentary accounts have the mic at 0 left, and no '
        'count', () async {
      final now = DateTime.utc(2026, 10, 20);
      final pro = container(
        pro: true,
        free: freeVoice(0, resets: resets),
        now: now,
      );
      expect(pro.read(voiceAvailableProvider), isTrue);
      expect(pro.read(freeVoiceLeftProvider), isNull);
      final controller = SubscriptionController(
        FakeRevenueCat(),
        const BillingConfiguration(apiKey: 'test_fixture', supported: true),
      );
      await controller.setIdentity(
        'owner',
        () async => 'owner-id',
        complimentary: true,
      );
      final complimentary = container(
        free: freeVoice(0, resets: resets),
        now: now,
        subscription: controller,
      );
      expect(complimentary.read(hasProProvider), isTrue);
      expect(complimentary.read(voiceAvailableProvider), isTrue);
      expect(complimentary.read(freeVoiceLeftProvider), isNull);
    });
  });

  // ---- Round 2 · P94 (UX-502, UX-503, UX-504) ----

  const freeVoiceRefusal = 'Free voice used up for this month.';

  /// A capture that is only a recording, with no words, put in the store as
  /// the phone keeps it.
  void keepRecording(_FreeApp app, {String id = 'wav'}) {
    app.store.sessions[id] = CaptureSession(
      id: id,
      ownerKey: app.container.read(captureOwnerProvider),
      timezone: 'Europe/Madrid',
      capturedAt: DateTime.now().toUtc(),
      audioPath: '${Directory.systemTemp.path}/taskflow-free-missing.wav',
      status: 'editing',
      source: 'speech',
    );
  }

  /// The recording-only capture opened in the sheet and refused with a 402
  /// free_voice_used_up.
  Future<void> refuseRecording(
    WidgetTester tester,
    _FreeApp app,
    DateTime resets,
    AppLocalizations l,
  ) async {
    keepRecording(app);
    app.api.failure = ApiException(402, freeVoiceRefusal, {
      'code': 'free_voice_used_up',
      'free_voice': freeVoice(0, resets: resets),
    });
    unawaited(
      showCaptureSheet(
        tester.element(find.byType(Scaffold).first),
        captureId: 'wav',
        startListening: false,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(button(l.done));
    for (var i = 0; i < 10 && app.api.drafts.isEmpty; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
    }
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pumpAndSettle();
    expect(app.api.drafts, hasLength(1));
  }

  /// The sheet of a recording that waits: one `Cerrar`, no typing field, no
  /// `Cancelar`, inside [width].
  void expectOnlyClose(WidgetTester tester, AppLocalizations l, double width) {
    expect(words(), findsNothing, reason: 'no typing field');
    expect(inSheet(find.byType(TextField)), findsNothing);
    expect(
      inSheet(find.widgetWithText(TextButton, l.cancel)),
      findsNothing,
      reason: 'no Cancelar',
    );
    expect(inSheet(find.text(l.cancel)), findsNothing);
    final filled = inSheet(find.byType(FilledButton));
    expect(filled, findsOneWidget, reason: 'exactly one filled button');
    final close = inSheet(find.widgetWithText(FilledButton, l.captureClose));
    expect(close, findsOneWidget);
    expect(find.byTooltip(l.captureTypeInstead), findsNothing);
    final rect = tester.getRect(close);
    expect(rect.left, greaterThanOrEqualTo(0));
    expect(rect.right, lessThanOrEqualTo(width + 0.5));
    expect(rect.bottom, lessThanOrEqualTo(740.5), reason: 'in view');
  }

  for (final (language, width) in [
    ('es', 360.0),
    ('ca', 320.0),
    ('en', 320.0),
  ]) {
    testWidgets(
      'UX-502: a recording-only capture refused with 402 shows the kept-recording line, Ver Pro and exactly one Cerrar — no typing field, no Cancelar ($language, 2× text at ${width.toInt()} dp)',
      (tester) async {
        final l = strings(language);
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final resets = nextReset();
        final app = await _FreeApp.open(
          tester,
          language: language,
          freeVoice: freeVoice(1),
          size: Size(width, 740),
        );
        await refuseRecording(tester, app, resets, l);

        final line = find.byKey(const ValueKey('free-voice-used-up'));
        expect(line, findsOneWidget);
        expect(
          tester.widget<Text>(line).data,
          l.freeVoiceUsedUpRecording(resetDay(tester, resets)),
        );
        expect(
          inSheet(find.widgetWithText(TextButton, l.voiceProAction)),
          findsOneWidget,
        );
        expect(find.text(freeVoiceRefusal), findsNothing);
        expectOnlyClose(tester, l, width);
        expect(tester.takeException(), isNull, reason: 'no overflow');
      },
    );
  }

  testWidgets(
    'UX-502: Cerrar closes the sheet at once with no question; the recording is not discarded and is listed in Capturas pendientes',
    (tester) async {
      final resets = nextReset();
      final app = await _FreeApp.open(tester, freeVoice: freeVoice(1));
      await refuseRecording(tester, app, resets, es);
      await tester.tap(
        inSheet(find.widgetWithText(FilledButton, es.captureClose)),
      );
      await tester.pump();
      expect(find.byType(AlertDialog), findsNothing, reason: 'no question');
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byType(BottomSheet), findsNothing, reason: 'closed');
      expect(app.store.sessions['wav']!.status, isNot('discarded'));

      // The fixture put the recording in the store directly: read afresh.
      app.container.invalidate(pendingCapturesProvider);
      tester
          .state<NavigatorState>(find.byType(Navigator).first)
          .pushNamed('/captures');
      await tester.pumpAndSettle();
      expect(find.byType(CapturesScreen), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(CapturesScreen),
          matching: find.byType(ListTile),
        ),
        findsOneWidget,
      );
      expect(
        find.textContaining(
          es.freeVoiceUsedUpRecording(resetDay(tester, resets)),
        ),
        findsOneWidget,
      );
      expect(app.api.drafts, hasLength(1), reason: 'nothing sent again');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'UX-502: the same recording reopened from Capturas pendientes at 0 left shows one Cerrar and no typing field; the system Back closes it with no question and it stays listed',
    (tester) async {
      final resets = nextReset();
      final app = await _FreeApp.open(
        tester,
        freeVoice: freeVoice(0, resets: resets),
        size: const Size(360, 740),
      );
      keepRecording(app);
      app.container.invalidate(pendingCapturesProvider);
      tester
          .state<NavigatorState>(find.byType(Navigator).first)
          .pushNamed('/captures');
      await tester.pumpAndSettle();
      final row = find.descendant(
        of: find.byType(CapturesScreen),
        matching: find.byType(ListTile),
      );
      expect(row, findsOneWidget);
      await tester.tap(row);
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsOneWidget);
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('free-voice-used-up')))
            .data,
        es.freeVoiceUsedUpRecording(resetDay(tester, resets)),
      );
      expectOnlyClose(tester, es, 360);
      expect(app.api.drafts, isEmpty, reason: 'nothing is asked of the server');

      // The system Back.
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(find.byType(AlertDialog), findsNothing, reason: 'no question');
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byType(BottomSheet), findsNothing, reason: 'closed');
      expect(find.byType(CapturesScreen), findsOneWidget);
      expect(app.store.sessions['wav']!.status, isNot('discarded'));
      app.container.invalidate(pendingCapturesProvider);
      await tester.pumpAndSettle();
      expect(row, findsOneWidget, reason: 'still listed');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'UX-502: spoken words refused with 402 still show the typing field with the words, Guardar tal cual and Cancelar, and Cancelar still asks whether to keep them',
    (tester) async {
      final resets = nextReset();
      final app = await _FreeApp.open(tester, freeVoice: freeVoice(1));
      app.api.failure = ApiException(402, freeVoiceRefusal, {
        'code': 'free_voice_used_up',
        'free_voice': freeVoice(0, resets: resets),
      });
      await dictate(tester, app, 'Comprar pan');
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pumpAndSettle();
      expect(words(), findsOneWidget);
      expect(tester.widget<TextField>(words()).controller!.text, 'Comprar pan');
      expect(button(es.captureSaveAsWritten), findsOneWidget);
      expect(button(es.captureClose), findsNothing);
      final cancel = inSheet(find.widgetWithText(TextButton, es.cancel));
      expect(cancel, findsOneWidget);
      await tester.tap(cancel);
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text(es.captureKeepQuestion), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  test(
    'UX-503 / UX-609: in Catalan the reset date sits mid-sentence: “Fins al dia 1 de nov. no tens”, “a partir del dia 1 de nov.” and “El dia 1 de nov. en tindràs més.”',
    () async {
      await initializeDateFormatting('ca');
      final november = DateTime(2026, 11, 1, 12);
      String day(String language) => DateFormat.MMMd(language).format(november);
      expect(day('ca'), '1 de nov.');

      // UX-609: the used-up line is shorter; the date stays mid-sentence.
      expect(
        freeVoiceUsedUpText(ca, november),
        'Fins al dia 1 de nov. no tens dictats gratuïts.',
      );
      expect(
        freeVoiceUsedUpText(ca, november, recording: true),
        contains('a partir del dia 1 de nov.'),
      );
      expect(
        ca.freeVoiceStatus(4, 10, day('ca')),
        endsWith('El dia 1 de nov. en tindràs més.'),
      );
      // The plural part is untouched.
      expect(ca.freeVoiceStatus(1, 10, 'D'), contains('et queda 1'));
      expect(ca.freeVoiceStatus(4, 10, 'D'), contains('et queden 4'));
      // The date's own full stop is not doubled by the sentence's.
      for (final text in [
        freeVoiceUsedUpText(ca, november),
        freeVoiceUsedUpText(ca, november, recording: true),
        ca.freeVoiceStatus(4, 10, day('ca')),
      ]) {
        expect(text, isNot(contains('..')), reason: text);
      }
    },
  );

  test(
    'UX-503 / UX-609: the ES and EN used-up lines are the short ones; the recording and Pro-screen lines are unchanged',
    () async {
      await initializeDateFormatting('es');
      await initializeDateFormatting('en');
      final november = DateTime(2026, 11, 1, 12);
      String day(String language) => DateFormat.MMMd(language).format(november);

      expect(
        freeVoiceUsedUpText(es, november),
        'Sin dictados gratis hasta el ${day('es')}.',
      );
      expect(
        freeVoiceUsedUpText(es, november, recording: true),
        'Tu grabación se conserva. Se podrá entender a partir del ${day('es')}, o ahora con Pro.',
      );
      expect(
        es.freeVoiceStatus(4, 10, day('es')),
        'Dictados gratis: te quedan 4 de 10 este mes. Más el ${day('es')}.',
      );
      expect(
        freeVoiceUsedUpText(en, november),
        'No free dictations until ${day('en')}.',
      );
      expect(
        freeVoiceUsedUpText(en, november, recording: true),
        'Your recording is kept. It can be understood from ${day('en')}, or now with Pro.',
      );
      expect(
        en.freeVoiceStatus(4, 10, day('en')),
        'Free dictations: 4 of 10 left this month. More on ${day('en')}.',
      );
    },
  );

  // ---- Round 3 · P98 (UX-503): the Catalan date sits mid-sentence ----

  test(
    'UX-503 / UX-609: in Catalan, for 1 November, the used-up line reads “Fins al dia 1 de nov. no tens dictats gratuïts.” and the Pro-screen line reads in full, with no doubled full stop',
    () async {
      await initializeDateFormatting('ca');
      final november = DateTime(2026, 11, 1, 12);
      final day = DateFormat.MMMd('ca').format(november);
      expect(day, '1 de nov.', reason: 'the date keeps its own full stop');

      final usedUp = freeVoiceUsedUpText(ca, november);
      final recording = freeVoiceUsedUpText(ca, november, recording: true);
      final status = ca.freeVoiceStatus(4, 10, day);
      expect(usedUp, 'Fins al dia 1 de nov. no tens dictats gratuïts.');
      expect(recording, contains('a partir del dia 1 de nov.'));
      expect(
        status,
        'Dictats gratuïts: et queden 4 de 10 aquest mes. El dia 1 de nov. en tindràs més.',
      );
      for (final text in [usedUp, recording, status]) {
        expect(text, isNot(contains('..')), reason: text);
      }
    },
  );

  test(
    'UX-503 / UX-609: in Catalan, for 1 May (a month with no abbreviation dot), the used-up line reads “Fins al dia 1 de maig no tens dictats gratuïts.” and the Pro-screen line still ends “en tindràs més.”',
    () async {
      await initializeDateFormatting('ca');
      final may = DateTime(2027, 5, 1, 12);
      final day = DateFormat.MMMd('ca').format(may);
      expect(day, '1 de maig', reason: 'no abbreviation dot');

      final usedUp = freeVoiceUsedUpText(ca, may);
      final status = ca.freeVoiceStatus(4, 10, day);
      expect(usedUp, 'Fins al dia 1 de maig no tens dictats gratuïts.');
      expect(status, endsWith('en tindràs més.'));
      expect(status.toLowerCase(), contains('el dia 1 de maig'));
      for (final text in [usedUp, status]) {
        expect(text, isNot(contains('..')), reason: text);
      }
      expect(ca.freeVoiceStatus(1, 10, day), contains('et queda 1'));
    },
  );

  testWidgets(
    'UX-503 / UX-609: the capture sheet in Catalan at 2× text on 320 dp, with free dictations used up and the words kept, shows “Fins al dia 1 de nov. no tens dictats gratuïts.” with no overflow',
    (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      // The next 1 November, at noon UTC: the 1st wherever the test runs.
      final now = DateTime.now().toUtc();
      var year = now.year;
      if (!DateTime.utc(year, 11, 1, 12).isAfter(now)) year++;
      final resets = DateTime.utc(year, 11, 1, 12);
      final app = await _FreeApp.open(
        tester,
        language: 'ca',
        freeVoice: freeVoice(1, resets: resets),
        size: const Size(320, 740),
      );
      app.api.failure = ApiException(402, freeVoiceRefusal, {
        'code': 'free_voice_used_up',
        'free_voice': freeVoice(0, resets: resets),
      });
      await dictate(tester, app, 'Comprar pa', l: ca);
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pumpAndSettle();
      expect(app.api.drafts, hasLength(1));
      expect(
        tester.widget<TextField>(words()).controller!.text,
        'Comprar pa',
        reason: 'the words are kept',
      );
      final line = find.byKey(const ValueKey('free-voice-used-up'));
      expect(line, findsOneWidget);
      final text = tester.widget<Text>(line).data!;
      expect(text, 'Fins al dia 1 de nov. no tens dictats gratuïts.');
      expect(text, isNot(contains('..')));
      await tester.ensureVisible(line);
      await tester.pumpAndSettle();
      final rect = tester.getRect(line);
      expect(rect.left, greaterThanOrEqualTo(0));
      expect(rect.right, lessThanOrEqualTo(320.5));
      expect(tester.takeException(), isNull, reason: 'no overflow');
    },
  );

  test(
    'UX-504: freeVoiceLeft(0) says none are left in EN, ES and CA; 1 and 3 are unchanged',
    () {
      expect(en.freeVoiceLeft(0), 'No free dictations left this month');
      expect(es.freeVoiceLeft(0), 'Ya no te quedan dictados gratis este mes');
      expect(
        ca.freeVoiceLeft(0),
        'Ja no et queden dictats gratuïts aquest mes',
      );
      for (final l in [en, es, ca]) {
        expect(l.freeVoiceLeft(0), isNot(contains('0')), reason: l.localeName);
      }
      expect(en.freeVoiceLeft(1), '1 free dictation left this month');
      expect(en.freeVoiceLeft(3), '3 free dictations left this month');
      expect(es.freeVoiceLeft(1), 'Te queda 1 dictado gratis este mes');
      expect(es.freeVoiceLeft(3), 'Te quedan 3 dictados gratis este mes');
      expect(ca.freeVoiceLeft(1), 'Et queda 1 dictat gratuït aquest mes');
      expect(ca.freeVoiceLeft(3), 'Et queden 3 dictats gratuïts aquest mes');
    },
  );

  test('UX-502: captureClose reads Close / Cerrar / Tanca', () {
    expect(en.captureClose, 'Close');
    expect(es.captureClose, 'Cerrar');
    expect(ca.captureClose, 'Tanca');
  });

  // ---- 2026-10-14-speed · P103 (UX-611): typing opens at once at 0 left ----

  Finder spinner() => inSheet(find.byType(CircularProgressIndicator));
  bool wordsFocused(WidgetTester tester) => tester
      .widget<EditableText>(
        find.descendant(of: words(), matching: find.byType(EditableText)),
      )
      .focusNode
      .hasFocus;

  testWidgets(
    'UX-611: a free account with 0 dictations left while billing is still loading opens Añadir tarea on the typing field, focused, with no spinner',
    (tester) async {
      final app = await _FreeApp.open(
        tester,
        freeVoice: freeVoice(0),
        billingLoading: true,
      );
      expect(app.container.read(billingLoadingProvider), isTrue);
      expect(app.container.read(freeVoiceLeftProvider), 0);
      await tester.tap(find.text(es.addTask).hitTestable());
      await frames(tester);
      expect(spinner(), findsNothing);
      expect(words(), findsOneWidget);
      expect(wordsFocused(tester), isTrue);
      expect(app.speech.starts, 0);
      expect(app.recorders, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'UX-611: with the free count unknown while billing loads, the sheet shows the spinner until billing answers, then types',
    (tester) async {
      final app = await _FreeApp.open(tester, billingLoading: true);
      expect(app.container.read(freeVoiceLeftProvider), isNull);
      await tester.tap(find.text(es.addTask).hitTestable());
      await frames(tester);
      expect(spinner(), findsOneWidget);
      expect(words(), findsNothing);
      app.container.read(_billing.notifier).state = (
        pro: false,
        loading: false,
      );
      await tester.pumpAndSettle();
      expect(spinner(), findsNothing);
      expect(words(), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'UX-611: typing opened at 0 left stays typing when billing then reports Pro; the next capture opens listening',
    (tester) async {
      final app = await _FreeApp.open(
        tester,
        freeVoice: freeVoice(0),
        billingLoading: true,
      );
      await tester.tap(find.text(es.addTask).hitTestable());
      await frames(tester);
      expect(words(), findsOneWidget);
      app.container.read(_billing.notifier).state = (pro: true, loading: false);
      await tester.pumpAndSettle();
      expect(app.container.read(voiceAvailableProvider), isTrue);
      expect(words(), findsOneWidget);
      expect(spinner(), findsNothing);
      expect(app.speech.starts, 0, reason: 'the open sheet keeps typing');
      // Closed with nothing typed: the next capture listens.
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsNothing);
      await tester.tap(find.text(es.addTask).hitTestable());
      await tester.pumpAndSettle();
      expect(app.speech.starts, 1);
      expect(find.text(es.listeningSeconds('00:00')), findsNothing);
      app.speech.send('ready');
      await tester.pump();
      expect(find.text(es.listeningSeconds('00:00')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  // ---- 2026-10-14-speed · P106 (UX-614): Volver a decirlo needs a dictation ----

  testWidgets(
    'UX-614: a free account’s result at 0 left says Ya no te quedan dictados gratis este mes and has no Volver a decirlo; Cancelar stands alone',
    (tester) async {
      final app = await _FreeApp.open(tester, freeVoice: freeVoice(1));
      app.api.answerFreeVoice = freeVoice(0);
      await dictate(tester, app, 'Comprar pan');
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pumpAndSettle();
      expect(find.byType(CaptureResult), findsOneWidget);
      expect(find.text(es.freeVoiceLeft(0)), findsOneWidget);
      expect(es.freeVoiceLeft(0), 'Ya no te quedan dictados gratis este mes');
      expect(find.text(es.captureSayAgain), findsNothing);
      expect(
        find.descendant(
          of: find.byType(CaptureResult),
          matching: find.widgetWithText(TextButton, es.cancel),
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  for (final pro in [false, true]) {
    testWidgets(
      'UX-614: ${pro ? 'with Pro' : 'with free dictations left'}, a spoken result has Volver a decirlo',
      (tester) async {
        final app = await _FreeApp.open(
          tester,
          pro: pro,
          freeVoice: pro ? null : freeVoice(5),
        );
        if (!pro) app.api.answerFreeVoice = freeVoice(4);
        await dictate(tester, app, 'Comprar pan');
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pumpAndSettle();
        expect(find.byType(CaptureResult), findsOneWidget);
        expect(
          find.descendant(
            of: find.byType(CaptureResult),
            matching: find.widgetWithText(TextButton, es.captureSayAgain),
          ),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  // ---- 2026-10-14-speed · P106 (UX-609): fewer words at 0 left ----

  group('UX-609 with the app’s fonts', () {
    setUpAll(() async {
      final font = FontLoader('Manrope')
        ..addFont(rootBundle.load('assets/fonts/Manrope.ttf'));
      await font.load();
    });

    for (final (language, expected) in [
      ('es', 'Sin dictados gratis hasta el 1 nov.'),
      ('ca', 'Fins al dia 1 de nov. no tens dictats gratuïts.'),
      ('en', 'No free dictations until Nov 1.'),
    ]) {
      testWidgets(
        'UX-609: at 0 left with free dictations back on 1 November, the typing sheet at 2× text on 320 dp ($language) reads “$expected” in at most two lines (three in Catalan), and the typing field stays above a 300 dp keyboard',
        (tester) async {
          tester.platformDispatcher.textScaleFactorTestValue = 2;
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          final now = DateTime.now().toUtc();
          var year = now.year;
          if (!DateTime.utc(year, 11, 1, 12).isAfter(now)) year++;
          final resets = DateTime.utc(year, 11, 1, 12);
          const size = Size(320, 740);
          final app = await _FreeApp.open(
            tester,
            language: language,
            freeVoice: freeVoice(0, resets: resets),
            size: size,
          );
          final l = strings(language);
          await tester.tap(find.text(l.addTask).hitTestable());
          await tester.pumpAndSettle();
          // The keyboard comes up for the focused field.
          tester.view.viewInsets = const FakeViewPadding(bottom: 300);
          addTearDown(tester.view.resetViewInsets);
          await tester.pumpAndSettle();
          expect(app.speech.starts, 0);

          final line = find.byKey(const ValueKey('free-voice-used-up'));
          expect(line, findsOneWidget);
          final text = tester.widget<Text>(line).data!;
          expect(text, expected);
          expect(text, isNot(contains('..')));
          final field = words();
          expect(field, findsOneWidget);
          final rect = tester.getRect(field);
          expect(rect.top, greaterThanOrEqualTo(0));
          expect(
            rect.bottom,
            lessThanOrEqualTo(size.height - 300 + 0.5),
            reason: 'field $rect above the keyboard',
          );
          expect(field.hitTestable(), findsOneWidget);
          // Last: the Catalan copy may take a third line (DECISIONS.md,
          // 2026-10-14: UX-609), as long as the field stays visible above.
          final paragraph = tester.renderObject<RenderParagraph>(
            find.descendant(of: line, matching: find.byType(RichText)),
          );
          // Laid out as the paragraph is: same text, scale and width.
          final painter = TextPainter(
            text: paragraph.text,
            textDirection: paragraph.textDirection,
            textScaler: paragraph.textScaler,
            locale: paragraph.locale,
            strutStyle: paragraph.strutStyle,
            textWidthBasis: paragraph.textWidthBasis,
            textHeightBehavior: paragraph.textHeightBehavior,
          )..layout(maxWidth: paragraph.constraints.maxWidth);
          addTearDown(painter.dispose);
          expect(
            painter.computeLineMetrics().length,
            lessThanOrEqualTo(language == 'ca' ? 3 : 2),
            reason: '“$text” at 2× on 320 dp',
          );

          expect(tester.takeException(), isNull);
        },
      );
    }
  });
}

Map<String, dynamic> _session(Map<String, dynamic>? free) => {
  'access': 'fixture-access',
  'refresh': 'fixture-refresh',
  'user': {
    'id': 1,
    'email': 'free@example.invalid',
    'timezone': 'Europe/Madrid',
    if (free != null) 'free_voice': free,
  },
};

Map<String, dynamic> _found(String title) => {
  'title': title,
  'due_date': null,
  'scheduled_date': null,
  'priority': 1,
  'notes': '',
  'questions': [],
};

/// What billing says: Pro, and whether it is still loading. A test can
/// change it while the app runs.
final _billing = StateProvider<({bool pro, bool loading})>(
  (ref) => (pro: false, loading: false),
);

/// An account restored from the session saved on the phone, as at launch.
class _SavedAuth extends AuthNotifier {
  _SavedAuth(super.api);
  @override
  Future<void> restore() async {
    await api.restore();
    if (mounted) state = AuthState(account: api.account);
  }
}

/// A signed-in account from [user], at once.
class _AccountAuth extends AuthNotifier {
  _AccountAuth(super.api, this.user);
  final Map<String, dynamic> user;
  @override
  Future<void> restore() async {
    state = AuthState(account: Account.fromJson(user));
  }
}

/// The app in Spanish (or [language]) on Calendar, signed in to an account
/// whose session — with its free dictations — is saved on the phone.
class _FreeApp {
  _FreeApp(this.container, this.api, this.store, this.tasks, this.speech);
  final ProviderContainer container;
  final _Api api;
  final _Captures store;
  final _Tasks tasks;
  final _Speech speech;
  int recorders = 0;

  static Future<_FreeApp> open(
    WidgetTester tester, {
    bool pro = false,
    Map<String, dynamic>? freeVoice,
    String language = 'es',
    Size size = const Size(390, 844),
    bool billingLoading = false,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    FlutterSecureStorage.setMockInitialValues({
      'taskflow.session': jsonEncode(_session(freeVoice)),
    });
    final api = _Api();
    final store = _Captures();
    final tasks = _Tasks();
    final speech = _Speech();
    final entries = CaptureEntries(
      channel: const MethodChannel('test/free-dictation-entries'),
    );
    late final _FreeApp app;
    final container = ProviderContainer(
      overrides: [
        invitationLinkProvider.overrideWith(
          (ref) => InvitationLinks(listen: false),
        ),
        _billing.overrideWith((ref) => (pro: pro, loading: billingLoading)),
        hasProProvider.overrideWith((ref) => ref.watch(_billing).pro),
        billingLoadingProvider.overrideWith(
          (ref) => ref.watch(_billing).loading,
        ),
        apiClientProvider.overrideWithValue(api),
        authProvider.overrideWith((ref) => _SavedAuth(api)),
        attachmentEntriesProvider.overrideWith((ref, taskId) async => []),
        regionalStoreProvider.overrideWithValue(
          MemoryRegionalStore(
            RegionalPreferences(
              language: language,
              clock: ClockFormat.twentyFour,
              weekStart: 1,
            ),
          ),
        ),
        taskListsProvider.overrideWith((ref) async => []),
        taskRepositoryProvider.overrideWithValue(MemoryTasks()),
        taskProvider.overrideWith((ref) => tasks),
        themeStoreProvider.overrideWithValue(MemoryThemeStore()),
        captureStoreProvider.overrideWithValue(store),
        nativeSpeechProvider.overrideWithValue(speech),
        captureRecorderFactoryProvider.overrideWithValue(() {
          app.recorders++;
          return SilentRecorder();
        }),
        captureEntriesProvider.overrideWithValue(entries),
      ],
    );
    app = _FreeApp(container, api, store, tasks, speech);
    store.tasks = tasks;
    final messenger = tester.binding.defaultBinaryMessenger;
    const channel = MethodChannel('test/free-dictation-entries');
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'pending') return [];
      return null;
    });
    addTearDown(() {
      container.dispose();
      api.close();
      messenger.setMockMethodCallHandler(channel, null);
      entries.dispose();
    });
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const MyApp()),
    );
    // The saved session is read through the (mocked) secure storage.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pumpAndSettle();
    expect(container.read(authProvider).account, isNotNull);
    return app;
  }
}

/// The assistant. Records every request; [hold] keeps an answer back;
/// [failure] refuses; a cancelled capture_id is answered with the server's
/// 409 capture_cancelled.
class _Api extends ApiClient {
  _Api() : super(url: 'http://free.test');
  final drafts = <Map<String, dynamic>>[];
  final deletes = <String>[];
  final _cancelled = <String>{};
  int refusedAsCancelled = 0;
  Completer<void>? hold;
  Object? failure;
  Map<String, dynamic>? answerFreeVoice;

  @override
  Future<dynamic> request(
    String method,
    String path, {
    Map<String, dynamic>? data,
    String? audioPath,
    bool authenticated = true,
    int? accountId,
    bool retry = true,
  }) async {
    if (method == 'DELETE' && path.startsWith('ai/drafts/')) {
      deletes.add(path);
      _cancelled.add(path.split('/')[2]);
      return null;
    }
    if (method == 'POST' && path == 'ai/drafts/') {
      drafts.add({...?data, 'audio': audioPath});
      final gate = hold;
      if (gate != null) await gate.future;
      if (_cancelled.contains(data?['capture_id'])) {
        refusedAsCancelled++;
        throw ApiException(409, 'This capture was cancelled.', {
          'code': 'capture_cancelled',
        });
      }
      final error = failure;
      if (error != null) throw error;
      final text = '${data?['text'] ?? ''}';
      return {
        'transcript': text,
        'tasks': [_found(text)],
        if (answerFreeVoice != null) 'free_voice': answerFreeVoice,
      };
    }
    throw ApiException(0, 'Offline. Retry when connected.');
  }
}

/// Tasks in memory, numbered as they are added.
class _Tasks extends DesignTaskNotifier {
  int _next = 100;
  @override
  Future<void> loadTasks() async {
    if (!state.hasValue) state = const AsyncData([]);
  }

  List<String> titles() => state.requireValue.map((t) => t.title).toList();

  int add(Task task) {
    final id = _next++;
    state = AsyncData([...state.requireValue, task.copyWith(id: id)]);
    return id;
  }
}

/// Every capture in memory, by id; new ones get a UUID, as on the phone.
class _Captures extends CaptureStore {
  _Captures() : super(TaskDatabase());
  final sessions = <String, CaptureSession>{};
  _Tasks? tasks;

  @override
  Future<CaptureSession> create(
    String ownerKey,
    String timezone, {
    String text = '',
    DateTime? now,
    bool audio = false,
    String kind = 'task',
    String? projectId,
    String? source,
    DateTime? day,
    String? id,
    String? language,
  }) async {
    final session = CaptureSession(
      language: language,
      id: id ?? const Uuid().v4(),
      ownerKey: ownerKey,
      timezone: timezone,
      capturedAt: (now ?? DateTime.now()).toUtc(),
      text: text,
      kind: kind,
      projectId: projectId,
      source: source,
      day: day,
    );
    return sessions[session.id] = session;
  }

  @override
  Future<void> update(CaptureSession value) async {
    if (sessions[value.id]?.terminal ?? false) {
      throw StateError('This capture is no longer available.');
    }
    sessions[value.id] = value;
  }

  @override
  Future<CaptureSession?> read(String id, String ownerKey) async =>
      sessions[id];
  @override
  Future<List<CaptureSession>> pending(String ownerKey) async => [
    for (final session in sessions.values)
      if (!session.terminal) session,
  ];
  @override
  Future<void> cleanFinished(String ownerKey) async {}
  @override
  Future<void> discard(String id, String ownerKey) async {
    final session = sessions[id];
    if (session != null) sessions[id] = session.copyWith(status: 'discarded');
  }

  @override
  Future<CaptureSession> saveReady(
    String id,
    String ownerKey,
    Set<String> draftIds,
  ) async {
    final current = sessions[id]!;
    final drafts = [
      for (final draft in current.drafts)
        draftIds.contains(draft.id)
            ? draft.copyWith(savedTaskId: tasks!.add(draft.task))
            : draft,
    ];
    return sessions[id] = current.copyWith(
      status: drafts.any((d) => d.pending) ? 'ready' : 'saved',
      drafts: drafts,
    );
  }

  @override
  Future<CaptureSession?> undoSave(
    CaptureSession before,
    Map<String, int> savedIds,
  ) async {
    for (final id in savedIds.values) {
      await tasks!.deleteTask(id);
    }
    return sessions[before.id] = before;
  }
}

/// The phone's recognizer: listening until stopped; the test sends what it
/// hears.
class _Speech extends NativeSpeech {
  final _events = StreamController<SpeechEvent>.broadcast(sync: true);
  int starts = 0;
  int? _run;
  @override
  Future<SpeechCapability> capability({String? language}) async =>
      const SpeechCapability(
        onDevice: true,
        language: 'es-ES',
        languageInstalled: true,
      );
  @override
  Stream<SpeechEvent> get events => _events.stream;
  @override
  Future<SpeechPermission> permission() async => SpeechPermission.granted;
  @override
  Future<void> start(
    int id,
    String language, {
    List<String> hints = const [],
  }) async {
    starts++;
    _run = id;
  }

  void send(String kind, {String? text, String? error}) =>
      _events.add(SpeechEvent(_run!, kind, text: text, error: error));
  @override
  Future<void> stop(int id) async {
    if (_run != null) send('ended');
  }

  @override
  Future<void> cancel(int id) async {}
}
