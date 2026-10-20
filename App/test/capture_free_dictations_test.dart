// UX loop 2026-10-13-app, round 1 (batch b7): free dictations in the capture
// sheet.
// P89 (UX-497, UX-499): free accounts get the mic while dictations are left;
// typed words never count; a capture_id with every request, and a cancel
// when the words are saved as written or dropped while understood.
// P90 (UX-498): used up — the words are kept, typing takes over, and the
// sheet says when more come.
// 2026-10-18 (DECISIONS.md): at 0 left the button's first tap of the month
// says so once.
// 2026-10-18 later: free accounts create tasks with the form. At 0 left the
// button reads Nueva tarea and opens it; with dictations left, the sheet's
// keyboard reads Escribir and opens it; typed words never reach the
// phone's parser.
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
import 'package:agenda/providers/free_voice_notice_provider.dart';
import 'package:agenda/providers/regional_provider.dart';
import 'package:agenda/providers/subscription_provider.dart';
import 'package:agenda/providers/task_lists_provider.dart';
import 'package:agenda/providers/task_provider.dart';
import 'package:agenda/providers/theme_provider.dart';
import 'package:agenda/screens/calendar_screen.dart';
import 'package:agenda/screens/captures_screen.dart';
import 'package:agenda/screens/notes_screen.dart';
import 'package:agenda/screens/subscription_screen.dart';
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
import 'package:agenda/widgets/task_actions.dart';
import 'package:agenda/widgets/task_editor.dart';
import 'package:agenda/widgets/task_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
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

  testWidgets(
    'UX-497: with Pro, typed words go to the assistant as today, through the keyboard',
    (tester) async {
      final app = await _FreeApp.open(tester, pro: true);
      await tester.tap(find.text(es.addTask).hitTestable());
      await tester.pumpAndSettle();
      expect(app.speech.starts, 1, reason: 'it opens on the mic');
      expect(find.byKey(const ValueKey('capture-fill-by-hand')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('capture-type-instead')));
      await tester.pumpAndSettle();
      await tester.enterText(words(), 'Comprar pan');
      await tester.pumpAndSettle();
      await tester.tap(button(es.done));
      await tester.pumpAndSettle();
      expect(find.byType(CaptureResult), findsOneWidget);
      expect(app.api.drafts, hasLength(1));
      expect(app.api.drafts.single['source'], 'typed');
      expect(
        app.store.sessions.values.single.drafts.single.task.title,
        'Comprar pan',
      );
      expect(tester.takeException(), isNull);
    },
  );

  // ---- 2026-10-18 (later): free accounts fill in the form ----

  Finder form() => find.byType(TaskEditor);
  String formTitle(WidgetTester tester) => tester
      .widget<TextFormField>(find.byKey(const ValueKey('task-title')))
      .controller!
      .text;
  bool formTitleFocused(WidgetTester tester) => tester
      .widget<EditableText>(
        find.descendant(
          of: find.byKey(const ValueKey('task-title')),
          matching: find.byType(EditableText),
        ),
      )
      .focusNode
      .hasFocus;

  testWidgets(
    '2026-10-18: a free account with dictations left opens Añadir tarea on the mic; the keyboard reads Escribir, and it opens the form, with nothing sent, no dictation used and nothing kept',
    (tester) async {
      final app = await _FreeApp.open(tester, freeVoice: freeVoice(5));
      await tester.tap(find.text(es.addTask).hitTestable());
      await tester.pumpAndSettle();
      expect(app.speech.starts, 1, reason: 'mic first, as today');
      expect(find.byKey(const ValueKey('capture-type-instead')), findsNothing);
      final byHand = find.byKey(const ValueKey('capture-fill-by-hand'));
      expect(byHand, findsOneWidget);
      expect(
        find.descendant(of: byHand, matching: find.text(es.captureTypeInstead)),
        findsOneWidget,
      );
      expect(es.captureTypeInstead, 'Escribir');
      await tester.tap(byHand);
      await tester.pumpAndSettle();
      expect(
        find.byType(BottomSheet),
        findsNothing,
        reason: 'the sheet closed',
      );
      expect(form(), findsOneWidget);
      expect(formTitle(tester), isEmpty);
      expect(formTitleFocused(tester), isTrue);
      expect(app.api.drafts, isEmpty);
      expect(app.container.read(freeVoiceLeftProvider), 5);
      expect(
        await app.container.read(pendingCapturesProvider.future),
        isEmpty,
        reason: 'nothing waits in Sin guardar',
      );
      // The form saves the task with no assistant and no parser.
      await tester.enterText(
        find.byKey(const ValueKey('task-title')),
        'Comprar pan mañana',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('task-save')));
      await tester.pumpAndSettle();
      expect(form(), findsNothing);
      expect(app.tasks.titles(), ['Comprar pan mañana']);
      expect(app.tasks.state.requireValue.single.dueDate, isNull);
      expect(app.api.drafts, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  for (final language in ['es', 'ca']) {
    testWidgets(
      '2026-10-18 (later): at 2× text on 320 dp ($language), the listening sheet shows Listo, Cancelar and Escribir in full, in view, with no overflow',
      (tester) async {
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final l = strings(language);
        final app = await _FreeApp.open(
          tester,
          language: language,
          freeVoice: freeVoice(5),
          size: const Size(320, 640),
        );
        await tester.tap(find.text(l.addTask).hitTestable());
        await tester.pumpAndSettle();
        expect(app.speech.starts, 1);
        app.speech.send('ready');
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));
        final byHand = find.byKey(const ValueKey('capture-fill-by-hand'));
        for (final finder in [
          byHand,
          inSheet(find.widgetWithText(TextButton, l.cancel)),
          button(l.done),
        ]) {
          expect(finder, findsOneWidget, reason: '$finder');
          expect(finder.hitTestable(), findsOneWidget, reason: '$finder');
          final rect = tester.getRect(finder);
          expect(rect.left, greaterThanOrEqualTo(0), reason: '$finder');
          expect(rect.right, lessThanOrEqualTo(320.5), reason: '$finder');
          expect(rect.bottom, lessThanOrEqualTo(640.5), reason: '$finder');
        }
        final label = find.descendant(
          of: byHand,
          matching: find.text(l.captureTypeInstead),
        );
        expect(label, findsOneWidget);
        expect(
          tester
              .renderObject<RenderParagraph>(
                find.descendant(of: label, matching: find.byType(RichText)),
              )
              .didExceedMaxLines,
          isFalse,
        );
        expect(tester.takeException(), isNull, reason: 'no overflow');
      },
    );
  }

  test(
    'UX-911: the sheet’s way to the form reads Type instead / Escribir / Escriu',
    () {
      expect(en.captureTypeInstead, 'Type instead');
      expect(es.captureTypeInstead, 'Escribir');
      expect(ca.captureTypeInstead, 'Escriu');
    },
  );

  testWidgets(
    'UX-1005: words already heard go with Escribir: they are the form’s title, unsent, and their capture waits until the task is saved',
    (tester) async {
      final app = await _FreeApp.open(tester, freeVoice: freeVoice(5));
      await tester.tap(find.text(es.addTask).hitTestable());
      await tester.pumpAndSettle();
      app.speech.send('ready');
      app.speech.send('segment', text: 'llamar al dentista');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      await tester.tap(find.byKey(const ValueKey('capture-fill-by-hand')));
      await tester.pumpAndSettle();
      expect(form(), findsOneWidget);
      expect(formTitle(tester), 'Llamar al dentista');
      expect(app.api.drafts, isEmpty, reason: 'no dictation used');
      expect(
        app.store.sessions.values.where((s) => !s.terminal),
        hasLength(1),
        reason: 'the form keeps the capture',
      );
      await tester.tap(find.byKey(const ValueKey('task-save')));
      await tester.pumpAndSettle();
      expect(app.tasks.titles(), ['Llamar al dentista']);
      expect(
        app.store.sessions.values.every((s) => s.status == 'discarded'),
        isTrue,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'UX-911: a free account’s typed or shared words never reach the phone’s parser: shared text opens straight in the form, and its capture waits until the task is saved',
    (tester) async {
      final app = await _FreeApp.open(tester, freeVoice: freeVoice(5));
      final owner = app.container.read(captureOwnerProvider);
      app.store.sessions['shared'] = CaptureSession(
        id: 'shared',
        ownerKey: owner,
        timezone: 'Europe/Madrid',
        capturedAt: DateTime.now().toUtc(),
        text: 'Comprar pilas el viernes',
        source: 'typed',
      );
      unawaited(
        showCaptureSheet(
          tester.element(find.byType(Scaffold).first),
          captureId: 'shared',
          startListening: false,
          typing: true,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsNothing);
      expect(form(), findsOneWidget);
      expect(formTitle(tester), 'Comprar pilas el viernes');
      expect(app.api.drafts, isEmpty);
      expect(app.store.sessions['shared']!.terminal, isFalse);
      await tester.tap(find.byKey(const ValueKey('task-save')));
      await tester.pumpAndSettle();
      expect(app.tasks.titles(), ['Comprar pilas el viernes']);
      expect(app.store.sessions['shared']!.status, 'discarded');
      expect(find.byType(CaptureResult), findsNothing, reason: 'no parser');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'UX-497 / 2026-10-18: with no free_voice block (an older server), a free account’s button reads Nueva tarea with the + icon and opens the form, with no recorder and no notice',
    (tester) async {
      final app = await _FreeApp.open(tester);
      expect(
        find.descendant(
          of: find.widgetWithText(FilledButton, es.newTask),
          matching: find.byIcon(Icons.add_rounded),
        ),
        findsOneWidget,
      );
      expect(find.text(es.addTask), findsNothing);
      await tester.tap(find.text(es.newTask).hitTestable());
      await tester.pumpAndSettle();
      expect(form(), findsOneWidget);
      expect(find.byType(VoiceTaskScreen), findsNothing);
      expect(find.byKey(const ValueKey('free-voice-notice')), findsNothing);
      expect(app.speech.starts, 0);
      expect(app.recorders, 0);
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
    'UX-499: Guardar como tarea while a free dictation is understood sends one DELETE for its capture_id, saves the words, ignores the 409 that follows; the next dictation uses a new capture_id',
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
      'UX-498 / 2026-10-18: at 0 left, Nueva tarea opens the form, with no recorder and no request, and the task is saved ($language)',
      (tester) async {
        final l = strings(language);
        final resets = nextReset();
        // This month's notice already seen: the tap goes straight to the form.
        final app = await _FreeApp.open(
          tester,
          language: language,
          freeVoice: freeVoice(0, resets: resets),
          noticeSeen: true,
        );
        expect(
          find.descendant(
            of: find.widgetWithText(FilledButton, l.newTask),
            matching: find.byIcon(Icons.add_rounded),
          ),
          findsOneWidget,
        );
        await tester.tap(find.text(l.newTask).hitTestable());
        await tester.pumpAndSettle();
        expect(form(), findsOneWidget, reason: 'it opens the form');
        expect(find.byType(VoiceTaskScreen), findsNothing);
        expect(formTitleFocused(tester), isTrue);
        expect(app.recorders, 0);
        expect(app.speech.starts, 0);
        await tester.enterText(
          find.byKey(const ValueKey('task-title')),
          'Comprar pan',
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('task-save')));
        await tester.pumpAndSettle();
        expect(app.tasks.titles(), ['Comprar pan']);
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
    'UX-498: a 402 free_voice_used_up keeps the said words in the typing field with Guardar como tarea and the used-up line; no second request is made',
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
    expect(find.byKey(const ValueKey('capture-type-instead')), findsNothing);
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
    'UX-502: spoken words refused with 402 still show the typing field with the words, Guardar como tarea and Cancelar, and Cancelar still asks whether to keep them',
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
          // While billing hasn't answered yet, the sheet types as before the
          // form (2026-10-18 later), with the used-up line.
          final app = await _FreeApp.open(
            tester,
            language: language,
            freeVoice: freeVoice(0, resets: resets),
            size: size,
            billingLoading: true,
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

  // ---- 2026-10-18: once the free dictations are used up, the button opens
  // the form (2026-10-18 later: Nueva tarea, replacing Escribir tarea) ----

  Finder notice() => find.byKey(const ValueKey('free-voice-notice'));
  Finder inActions(Finder finder) =>
      find.descendant(of: find.byType(TaskActions), matching: finder);
  Finder inNotice(Finder finder) =>
      find.descendant(of: notice(), matching: finder);

  /// The button reads [label], with [icon] and no other.
  void expectButton(String label, IconData icon) {
    final button = inActions(find.widgetWithText(FilledButton, label));
    expect(button, findsOneWidget);
    expect(
      find.descendant(of: button, matching: find.byIcon(icon)),
      findsOneWidget,
    );
    for (final other in [
      Icons.mic_none_rounded,
      Icons.add_rounded,
      Icons.edit_outlined,
    ]) {
      if (other == icon) continue;
      expect(inActions(find.byIcon(other)), findsNothing, reason: '$other');
    }
  }

  test(
    '2026-10-18 (later): the button reads Nueva tarea / New task / Tasca nova; the notice says tasks go on by hand, names the date before the number and offers Crear una tarea',
    () {
      expect(es.newTask, 'Nueva tarea');
      expect(en.newTask, 'New task');
      expect(ca.newTask, 'Tasca nova');
      expect(
        es.freeVoiceNoticeTitle(10),
        'Has usado tus 10 dictados gratis de este mes',
      );
      expect(
        es.freeVoiceNoticeBody(10, '1 nov'),
        'Puedes seguir creando tareas a mano, sin límite. El 1 nov tendrás 10 dictados más.',
      );
      expect(es.freeVoiceNoticeCreate, 'Crear una tarea');
      expect(es.voiceProAction, 'Ver Pro');
      expect(
        en.freeVoiceNoticeTitle(10),
        'You’ve used your 10 free dictations for this month',
      );
      expect(
        en.freeVoiceNoticeBody(10, 'Nov 1'),
        'You can keep creating tasks by hand, with no limit. On Nov 1 you’ll get 10 more dictations.',
      );
      expect(en.freeVoiceNoticeCreate, 'Create a task');
      expect(
        ca.freeVoiceNoticeTitle(10),
        'Has fet servir els 10 dictats gratuïts d’aquest mes',
      );
      // The date keeps its own full stop: «1 de nov.».
      expect(
        ca.freeVoiceNoticeBody(10, '1 de nov.'),
        'Pots continuar creant tasques a mà, sense límit. El dia 1 de nov. tindràs 10 dictats més.',
      );
      expect(ca.freeVoiceNoticeCreate, 'Crea una tasca');
      // The limit comes from the account, in the singular too.
      expect(
        es.freeVoiceNoticeTitle(1),
        'Has usado tu dictado gratis de este mes',
      );
      expect(
        es.freeVoiceNoticeBody(1, 'D'),
        endsWith('El D tendrás 1 dictado más.'),
      );
      for (final l in [en, es, ca]) {
        expect(l.freeVoiceNoticeTitle(7), contains('7'), reason: l.localeName);
        expect(l.freeVoiceNoticeBody(7, 'D'), contains('7'));
        expect(l.freeVoiceNoticeBody(7, 'D'), contains('D'));
      }
    },
  );

  test(
    '2026-10-18: with the real short dates for 1 November and 1 May, the notice never doubles a full stop',
    () async {
      for (final l in [en, es, ca]) {
        await initializeDateFormatting(l.localeName);
        for (final day in [
          DateTime(2026, 11, 1, 12),
          DateTime(2027, 5, 1, 12),
        ]) {
          final date = DateFormat.MMMd(l.localeName).format(day);
          final body = l.freeVoiceNoticeBody(10, date);
          expect(body, contains(date), reason: body);
          expect(body, isNot(contains('..')), reason: body);
        }
      }
    },
  );

  test(
    '2026-10-18 (later): the lines that name the button name Nueva tarea when it reads so; the first-run line says to tap Mañana, as the form reads no dates from words',
    () {
      for (final l in [en, es, ca]) {
        String swap(String text) => text.replaceFirst(l.addTask, l.newTask);
        expect(l.tasksEmptyForm, swap(l.tasksEmpty));
        expect(l.inboxEmptyForm, swap(l.inboxEmpty));
        for (final text in [
          l.calendarTryForm,
          l.tasksEmptyForm,
          l.inboxEmptyForm,
        ]) {
          expect(text, contains(l.newTask), reason: text);
          expect(text, isNot(contains(l.addTask)), reason: text);
        }
        expect(l.calendarTryForm, contains(l.tomorrow));
      }
      expect(
        es.calendarTryForm,
        'Prueba: toca Nueva tarea, escribe «Llamar al dentista» y toca Mañana.',
      );
      expect(
        ca.calendarTryForm,
        'Prova-ho: toca Tasca nova, escriu «Trucar al dentista» i toca Demà.',
      );
      expect(
        en.calendarTryForm,
        'Try it: tap New task, type “Call the dentist” and tap Tomorrow.',
      );
    },
  );

  for (final language in ['es', 'en', 'ca']) {
    testWidgets(
      '2026-10-18 (later): a free account with no dictations left this month sees Nueva tarea with + instead of Añadir tarea ($language)',
      (tester) async {
        final l = strings(language);
        final app = await _FreeApp.open(
          tester,
          language: language,
          freeVoice: freeVoice(0),
        );
        expect(app.container.read(freeVoiceUsedUpProvider), isTrue);
        expect(app.container.read(opensFormProvider), isTrue);
        expectButton(l.newTask, Icons.add_rounded);
        expect(find.text(l.addTask), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final (state, pro, free, loading, icon) in [
    (
      'Pro, even with a saved 0',
      true,
      freeVoice(0),
      false,
      Icons.mic_none_rounded,
    ),
    (
      'Free with dictations left',
      false,
      freeVoice(5),
      false,
      Icons.mic_none_rounded,
    ),
    (
      'Free at 0 while billing doesn’t know yet whether it has Pro',
      false,
      freeVoice(0),
      true,
      Icons.add_rounded,
    ),
  ]) {
    testWidgets(
      '2026-10-18: $state keeps Añadir tarea with today’s icon, and its tap opens the sheet with no notice',
      (tester) async {
        final app = await _FreeApp.open(
          tester,
          pro: pro,
          freeVoice: free,
          billingLoading: loading,
        );
        expect(app.container.read(freeVoiceUsedUpProvider), isFalse);
        expect(app.container.read(opensFormProvider), isFalse);
        expectButton(es.addTask, icon);
        expect(find.text(es.newTask), findsNothing);
        await tester.tap(find.text(es.addTask).hitTestable());
        await tester.pumpAndSettle();
        expect(notice(), findsNothing);
        expect(find.byType(VoiceTaskScreen), findsOneWidget);
        expect(form(), findsNothing);
        expect(app.notices.writes, 0);
        expect(app.notices.months, isEmpty);
        expect(tester.takeException(), isNull);
      },
    );
  }

  group('2026-10-18: freeVoiceUsedUp', () {
    final resets = DateTime.utc(2026, 11);
    final before = DateTime.utc(2026, 10, 20);
    ProviderContainer container({
      bool pro = false,
      bool loading = false,
      Map<String, dynamic>? free,
      DateTime? now,
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
          if (subscription != null)
            subscriptionProvider.overrideWith((_) => subscription)
          else ...[
            hasProProvider.overrideWithValue(pro),
            billingLoadingProvider.overrideWithValue(loading),
          ],
          calendarClockProvider.overrideWithValue(() => now ?? before),
        ],
      );
      addTearDown(c.dispose);
      addTearDown(api.close);
      return c;
    }

    test('only an account without Pro, at 0, once billing has answered; '
        'from the reset on, the saved 0 is a new month', () {
      bool usedUp(ProviderContainer c) => c.read(freeVoiceUsedUpProvider);
      expect(usedUp(container(free: freeVoice(0, resets: resets))), isTrue);
      expect(usedUp(container(free: freeVoice(1, resets: resets))), isFalse);
      expect(usedUp(container()), isFalse, reason: 'an older server');
      expect(
        usedUp(container(free: freeVoice(0, resets: resets), loading: true)),
        isFalse,
        reason: 'not known yet',
      );
      expect(
        usedUp(container(free: freeVoice(0, resets: resets), pro: true)),
        isFalse,
      );
      expect(
        usedUp(
          container(
            free: freeVoice(0, resets: resets),
            now: resets,
          ),
        ),
        isFalse,
      );
    });

    test('a complimentary account at 0 has not used anything up', () async {
      final controller = SubscriptionController(
        FakeRevenueCat(),
        const BillingConfiguration(apiKey: 'test_fixture', supported: true),
      );
      await controller.setIdentity(
        'owner',
        () async => 'owner-id',
        complimentary: true,
      );
      final c = container(
        free: freeVoice(0, resets: resets),
        subscription: controller,
      );
      expect(c.read(hasProProvider), isTrue);
      expect(c.read(freeVoiceUsedUpProvider), isFalse);
      // Its typed words still go to the assistant, as with Pro.
      expect(c.read(typesInFormProvider), isFalse);
      expect(c.read(opensFormProvider), isFalse);
    });

    test('2026-10-18 (later): without Pro, once billing has answered, typed '
        'words go to the form; the button opens it at once when there is no '
        'mic; Pro and billing not known yet keep today’s behaviour', () {
      bool types(ProviderContainer c) => c.read(typesInFormProvider);
      bool opens(ProviderContainer c) => c.read(opensFormProvider);
      final left = container(free: freeVoice(3, resets: resets));
      expect(types(left), isTrue);
      expect(opens(left), isFalse, reason: 'the mic first');
      final none = container(free: freeVoice(0, resets: resets));
      expect(types(none), isTrue);
      expect(opens(none), isTrue);
      final older = container();
      expect(types(older), isTrue, reason: 'an older server');
      expect(opens(older), isTrue);
      final loading = container(
        free: freeVoice(0, resets: resets),
        loading: true,
      );
      expect(types(loading), isFalse, reason: 'not known yet');
      expect(opens(loading), isFalse);
      final pro = container(free: freeVoice(0, resets: resets), pro: true);
      expect(types(pro), isFalse);
      expect(opens(pro), isFalse);
      // From the reset on, the mic is back: Añadir tarea again.
      final renewed = container(
        free: freeVoice(0, resets: resets),
        now: resets,
      );
      expect(opens(renewed), isFalse);
    });
  });

  testWidgets(
    '2026-10-18 (later): the first tap of the month at 0 left shows the notice, with the account’s limit and the local reset date; Crear una tarea opens the form, its title focused, with no recorder; the next tap opens the form at once',
    (tester) async {
      final resets = nextReset();
      final app = await _FreeApp.open(
        tester,
        freeVoice: freeVoice(0, resets: resets),
      );
      await tester.tap(find.text(es.newTask).hitTestable());
      await tester.pumpAndSettle();
      expect(notice(), findsOneWidget);
      expect(form(), findsNothing, reason: 'the notice comes first');
      expect(inNotice(find.text(es.freeVoiceNoticeTitle(10))), findsOneWidget);
      expect(
        inNotice(
          find.text(es.freeVoiceNoticeBody(10, resetDay(tester, resets))),
        ),
        findsOneWidget,
      );
      // Seen from now on, for this account and this month.
      expect(app.notices.months, {app.owner: resets});

      await tester.tap(
        inNotice(find.widgetWithText(FilledButton, es.freeVoiceNoticeCreate)),
      );
      await tester.pumpAndSettle();
      expect(notice(), findsNothing);
      expect(form(), findsOneWidget);
      expect(formTitleFocused(tester), isTrue);
      expect(find.byType(VoiceTaskScreen), findsNothing);
      expect(app.recorders, 0);
      expect(app.speech.starts, 0);

      // Closed with nothing typed: the next tap opens the form at once.
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(form(), findsNothing);
      await tester.tap(find.text(es.newTask).hitTestable());
      await tester.pumpAndSettle();
      expect(notice(), findsNothing);
      expect(form(), findsOneWidget);
      expect(formTitleFocused(tester), isTrue);
      expect(app.notices.writes, 1);
      expect(app.recorders, 0);
      expect(app.speech.starts, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    '2026-10-18: at 0 left no recorder is ever created and the mic is never readied: not on Calendar, not behind the notice, not in the form, not on the next tap',
    (tester) async {
      final app = await _FreeApp.open(tester, freeVoice: freeVoice(0));
      await frames(tester);
      expect(app.speech.warms, 0, reason: 'speech is readied only for the mic');
      await tester.tap(find.text(es.newTask).hitTestable());
      await tester.pumpAndSettle();
      expect(notice(), findsOneWidget);
      expect(app.recorders, 0);
      await tester.tap(
        inNotice(find.widgetWithText(FilledButton, es.freeVoiceNoticeCreate)),
      );
      await tester.pumpAndSettle();
      expect(form(), findsOneWidget);
      expect(app.recorders, 0);
      // Closed with nothing typed, and opened again.
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(form(), findsNothing);
      await tester.tap(find.text(es.newTask).hitTestable());
      await tester.pumpAndSettle();
      expect(form(), findsOneWidget);
      // A task saved from the form: still none, and nothing asked.
      await tester.enterText(
        find.byKey(const ValueKey('task-title')),
        'Comprar pan',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('task-save')));
      await tester.pumpAndSettle();
      expect(app.tasks.titles(), ['Comprar pan']);
      expect(app.api.drafts, isEmpty);
      expect(app.recorders, 0);
      expect(app.speech.starts, 0);
      expect(app.speech.warms, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    '2026-10-18: closing the notice opens nothing; it doesn’t come back, and the next tap opens the form at once',
    (tester) async {
      final app = await _FreeApp.open(tester, freeVoice: freeVoice(0));
      await tester.tap(find.text(es.newTask).hitTestable());
      await tester.pumpAndSettle();
      expect(notice(), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(notice(), findsNothing);
      expect(form(), findsNothing);
      await tester.tap(find.text(es.newTask).hitTestable());
      await tester.pumpAndSettle();
      expect(notice(), findsNothing);
      expect(form(), findsOneWidget);
      expect(app.notices.writes, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    '2026-10-18: Ver Pro on the notice opens the Pro screen, as the sheet’s Ver Pro does; back on Calendar, Nueva tarea opens the form at once',
    (tester) async {
      final app = await _FreeApp.open(tester, freeVoice: freeVoice(0));
      await tester.tap(find.text(es.newTask).hitTestable());
      await tester.pumpAndSettle();
      await tester.tap(
        inNotice(find.widgetWithText(TextButton, es.voiceProAction)),
      );
      await tester.pumpAndSettle();
      expect(find.byType(SubscriptionScreen), findsOneWidget);
      expect(notice(), findsNothing);
      expect(form(), findsNothing);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(SubscriptionScreen), findsNothing);
      await tester.tap(find.text(es.newTask).hitTestable());
      await tester.pumpAndSettle();
      expect(notice(), findsNothing);
      expect(form(), findsOneWidget);
      expect(app.recorders, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    '2026-10-18 (later): at 0 left, the widget’s Dictar una tarea opens the form too, after the same notice once a month',
    (tester) async {
      final app = await _FreeApp.open(tester, freeVoice: freeVoice(0));
      unawaited(
        showCaptureSheet(
          tester.element(find.byType(Scaffold).first),
          askedToSpeak: true,
        ),
      );
      await tester.pumpAndSettle();
      expect(notice(), findsOneWidget);
      await tester.tap(
        inNotice(find.widgetWithText(FilledButton, es.freeVoiceNoticeCreate)),
      );
      await tester.pumpAndSettle();
      expect(form(), findsOneWidget);
      expect(find.byType(VoiceTaskScreen), findsNothing);
      expect(app.recorders, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    '2026-10-18: seen last month, the notice shows again the first time this month runs out too; seen this month (another run of the app), it doesn’t',
    (tester) async {
      final resets = nextReset();
      final lastMonth = DateTime.utc(resets.year, resets.month - 1);
      final notices = _Notices()
        ..months['http://free.test/users/1'] = lastMonth;
      final app = await _FreeApp.open(
        tester,
        freeVoice: freeVoice(0, resets: resets),
        notices: notices,
      );
      await tester.tap(find.text(es.newTask).hitTestable());
      await tester.pumpAndSettle();
      expect(notice(), findsOneWidget);
      expect(notices.months[app.owner], resets);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      // The app starts again on this phone: still seen this month.
      await tester.pumpWidget(const SizedBox());
      await _FreeApp.open(
        tester,
        freeVoice: freeVoice(0, resets: resets),
        notices: notices,
      );
      await tester.tap(find.text(es.newTask).hitTestable());
      await tester.pumpAndSettle();
      expect(notice(), findsNothing);
      expect(form(), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    '2026-10-18: another account on the same phone, out of dictations too, gets its own notice once',
    (tester) async {
      final resets = nextReset();
      final notices = _Notices()..months['http://free.test/users/1'] = resets;
      final app = await _FreeApp.open(
        tester,
        accountId: 2,
        freeVoice: freeVoice(0, resets: resets),
        notices: notices,
      );
      expect(app.owner, 'http://free.test/users/2');
      await tester.tap(find.text(es.newTask).hitTestable());
      await tester.pumpAndSettle();
      expect(notice(), findsOneWidget);
      expect(notices.months, {
        'http://free.test/users/1': resets,
        'http://free.test/users/2': resets,
      });
      expect(tester.takeException(), isNull);
    },
  );

  for (final language in ['es', 'ca', 'en']) {
    testWidgets(
      '2026-10-18: at 2× text on 320 dp ($language), Nueva tarea and its notice read in full with no overflow; both notice buttons can be reached, and TalkBack reads the title as a heading as it opens',
      (tester) async {
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final l = strings(language);
        final resets = nextReset();
        await _FreeApp.open(
          tester,
          language: language,
          freeVoice: freeVoice(0, resets: resets),
          size: const Size(320, 640),
        );
        final label = inActions(find.text(l.newTask));
        expect(label, findsOneWidget);
        final rect = tester.getRect(label);
        expect(rect.left, greaterThanOrEqualTo(0));
        expect(rect.right, lessThanOrEqualTo(320.5));
        expect(
          tester
              .renderObject<RenderParagraph>(
                find.descendant(of: label, matching: find.byType(RichText)),
              )
              .didExceedMaxLines,
          isFalse,
        );
        await tester.tap(label.hitTestable());
        await tester.pumpAndSettle();
        expect(notice(), findsOneWidget);
        final title = inNotice(find.text(l.freeVoiceNoticeTitle(10)));
        final body = inNotice(
          find.text(l.freeVoiceNoticeBody(10, resetDay(tester, resets))),
        );
        final write = inNotice(
          find.widgetWithText(FilledButton, l.freeVoiceNoticeCreate),
        );
        final pro = inNotice(find.widgetWithText(TextButton, l.voiceProAction));
        for (final finder in [title, body, write, pro]) {
          expect(finder, findsOneWidget);
          await tester.ensureVisible(finder);
          await tester.pumpAndSettle();
          expect(finder.hitTestable(), findsOneWidget, reason: '$finder');
          final box = tester.getRect(finder);
          expect(box.left, greaterThanOrEqualTo(0), reason: '$finder');
          expect(box.right, lessThanOrEqualTo(320.5), reason: '$finder');
        }
        final heading = tester
            .getSemantics(title)
            .getSemanticsData()
            .flagsCollection;
        expect(heading.isHeader, isTrue);
        expect(heading.isLiveRegion, isTrue);
        // The heading and the line under it are read one by one.
        expect(tester.getSemantics(title).label, l.freeVoiceNoticeTitle(10));
        expect(
          tester.getSemantics(body).label,
          l.freeVoiceNoticeBody(10, resetDay(tester, resets)),
        );
        expect(
          tester.getSemantics(body).getSemanticsData().flagsCollection.isHeader,
          isFalse,
        );
        expect(tester.takeException(), isNull, reason: 'no overflow');
      },
    );
  }

  testWidgets(
    '2026-10-18 (later): at 0 left, the first-run line on Calendar and the empty Tareas and Sin fecha lists name Nueva tarea, the button they point to',
    (tester) async {
      await _FreeApp.open(tester, freeVoice: freeVoice(0));
      expect(find.text(es.calendarTryForm), findsOneWidget);
      expect(find.text(es.calendarTryTyping), findsNothing);
      tester
          .state<NavigatorState>(find.byType(Navigator).first)
          .pushNamed('/home');
      await tester.pumpAndSettle();
      expect(find.text(es.tasksEmptyForm), findsOneWidget);
      expect(find.text(es.tasksEmpty), findsNothing);
      tester
          .state<NavigatorState>(find.byType(Navigator).first)
          .pushNamed('/inbox');
      await tester.pumpAndSettle();
      expect(find.text(es.inboxEmptyForm), findsOneWidget);
      expect(find.text(es.inboxEmpty), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    '2026-10-18: with dictations left, the first-run line still says Añadir tarea and to say it',
    (tester) async {
      await _FreeApp.open(tester, freeVoice: freeVoice(5));
      expect(find.text(es.calendarTrySaying), findsOneWidget);
      expect(find.text(es.calendarTryForm), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  group('2026-10-18: the notice’s memory on the phone', () {
    const ana = 'http://free.test/users/1';
    const luis = 'http://free.test/users/2';
    final november = DateTime.utc(2026, 11);
    final december = DateTime.utc(2026, 12);

    test(
      'real SQLite: once per account and per month, still seen after '
      'the app restarts, and kept per account so deleting it erases it',
      () async {
        sqfliteFfiInit();
        final sql = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
        addTearDown(sql.close);
        await TaskDatabase.createReminderTables(sql);
        final store = FreeVoiceNoticeStore(TaskDatabase.forTesting(sql));
        final first = FreeVoiceNotice(store, ana);
        addTearDown(first.dispose);
        expect(await first.claim(november), isTrue);
        expect(await first.claim(november), isFalse, reason: 'once');
        expect(await store.seen(ana), november);

        // Another run of the app reads it back.
        final again = FreeVoiceNotice(store, ana);
        addTearDown(again.dispose);
        expect(await again.claim(november), isFalse);
        // Another account on this phone has its own.
        final other = FreeVoiceNotice(store, luis);
        addTearDown(other.dispose);
        expect(await other.claim(november), isTrue);
        // Next month, out again: once more.
        expect(await again.claim(december), isTrue);
        expect(await again.claim(december), isFalse);
        final later = FreeVoiceNotice(store, ana);
        addTearDown(later.dispose);
        expect(await later.claim(december), isFalse);
        expect(
          (await sql.query('app_preferences')).map((row) => row['scope']),
          unorderedEquals(['freeVoiceNotice:$ana', 'freeVoiceNotice:$luis']),
        );
      },
    );

    test('a phone that can’t read or write it shows it once in this run '
        'all the same', () async {
      final notice = FreeVoiceNotice(_BrokenNotices(), ana);
      addTearDown(notice.dispose);
      expect(await notice.claim(november), isTrue);
      expect(await notice.claim(november), isFalse);
    });
  });

  // ---- Run 2026-10-18-commands, round 2 (P138: UX-911, UX-910, UX-1005,
  // UX-1011): a free account's way into the form ----

  var entryCount = 0;
  Map<String, Object> entry(String kind, {String text = ''}) => {
    'id':
        '00000000-0000-4000-9000-${(++entryCount).toString().padLeft(12, '0')}',
    'kind': kind,
    'text': text,
    'capturedAt': DateTime.now().millisecondsSinceEpoch,
  };

  /// The captures still waiting under «Sin guardar».
  List<CaptureSession> waiting(_FreeApp app) => [
    for (final session in app.store.sessions.values)
      if (!session.terminal) session,
  ];

  Finder title() => find.byKey(const ValueKey('task-title'));
  Finder usedUp() => find.byKey(const ValueKey('free-voice-used-up'));

  Future<void> tapSave(WidgetTester tester) async {
    final save = find.byKey(const ValueKey('task-save'));
    await tester.ensureVisible(save);
    await tester.pumpAndSettle();
    await tester.tap(save);
    await tester.pumpAndSettle();
  }

  Future<void> openTasksTab(WidgetTester tester) async {
    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text(es.tasks),
      ),
    );
    await tester.pumpAndSettle();
  }

  for (final language in ['es', 'ca']) {
    testWidgets(
      'UX-911: at 2× on 320×640 ($language), with dictations left, the mic sheet’s keyboard button reads «${strings(language).captureTypeInstead}» with the keyboard icon, whole and on screen; it opens «Nueva tarea» with the words heard as the title',
      (tester) async {
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final l = strings(language);
        final app = await _FreeApp.open(
          tester,
          language: language,
          freeVoice: freeVoice(5),
          size: const Size(320, 640),
        );
        await tester.tap(find.text(l.addTask).hitTestable());
        await tester.pumpAndSettle();
        app.speech.send('ready');
        app.speech.send('segment', text: 'Llamar al dentista');
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));
        expect(l.captureTypeInstead, language == 'es' ? 'Escribir' : 'Escriu');
        final type = find.ancestor(
          of: find.text(l.captureTypeInstead),
          matching: find.byWidgetPredicate((widget) => widget is TextButton),
        );
        expect(type, findsOneWidget);
        expect(
          find.descendant(
            of: type,
            matching: find.byIcon(Icons.keyboard_outlined),
          ),
          findsOneWidget,
        );
        expect(type.hitTestable(), findsOneWidget);
        final rect = tester.getRect(type);
        expect(rect.left, greaterThanOrEqualTo(0));
        expect(rect.right, lessThanOrEqualTo(320.5));
        expect(rect.top, greaterThanOrEqualTo(0));
        expect(rect.bottom, lessThanOrEqualTo(640.5));
        expect(
          tester
              .renderObject<RenderParagraph>(
                find.descendant(
                  of: find.text(l.captureTypeInstead),
                  matching: find.byType(RichText),
                  matchRoot: true,
                ),
              )
              .didExceedMaxLines,
          isFalse,
        );
        expect(tester.takeException(), isNull, reason: 'no overflow');
        await tester.tap(type);
        await tester.pumpAndSettle();
        expect(form(), findsOneWidget);
        expect(find.text(l.newTask), findsWidgets);
        expect(formTitle(tester), 'Llamar al dentista');
        expect(app.api.drafts, isEmpty);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'UX-911: a typed capture «Comprar pan» under «Sin guardar», tapped, opens the form titled «Comprar pan»',
    (tester) async {
      final app = await _FreeApp.open(tester, freeVoice: freeVoice(5));
      app.store.sessions['typed'] = CaptureSession(
        id: 'typed',
        ownerKey: app.owner,
        timezone: 'Europe/Madrid',
        capturedAt: DateTime.now().toUtc(),
        text: 'Comprar pan',
        source: 'typed',
      );
      app.container.invalidate(pendingCapturesProvider);
      tester
          .state<NavigatorState>(find.byType(Navigator).first)
          .pushNamed('/captures');
      await tester.pumpAndSettle();
      expect(find.byType(CapturesScreen), findsOneWidget);
      final row = find.descendant(
        of: find.byType(CapturesScreen),
        matching: find.textContaining('Comprar pan'),
      );
      expect(row, findsOneWidget);
      await tester.tap(row);
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsNothing);
      expect(find.byType(VoiceTaskScreen), findsNothing);
      expect(form(), findsOneWidget);
      expect(formTitle(tester), 'Comprar pan');
      expect(app.api.drafts, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'UX-910: at 0 left with this month’s notice already seen, the widget’s entry opens the form with «Sin dictados gratis hasta el …» and «Ver Pro» above the title, every time; «Nueva tarea» opens it without them',
    (tester) async {
      final resets = nextReset();
      final app = await _FreeApp.open(
        tester,
        freeVoice: freeVoice(0, resets: resets),
        noticeSeen: true,
      );
      for (var time = 1; time <= 2; time++) {
        await app.deliver(tester, entry('voice'));
        expect(notice(), findsNothing, reason: 'seen this month');
        expect(form(), findsOneWidget, reason: 'entry $time');
        expect(usedUp(), findsOneWidget, reason: 'entry $time');
        final line = es.freeVoiceUsedUp(resetDay(tester, resets));
        expect(line, startsWith('Sin dictados gratis hasta el '));
        expect(tester.widget<Text>(usedUp()).data, line);
        final pro = find.widgetWithText(TextButton, es.voiceProAction);
        expect(pro, findsOneWidget);
        expect(es.voiceProAction, 'Ver Pro');
        final top = tester.getRect(title()).top;
        expect(tester.getRect(usedUp()).bottom, lessThanOrEqualTo(top));
        expect(tester.getRect(pro).bottom, lessThanOrEqualTo(top));
        expect(app.recorders, 0);
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(form(), findsNothing);
      }
      await tester.tap(find.text(es.newTask).hitTestable());
      await tester.pumpAndSettle();
      expect(form(), findsOneWidget);
      expect(usedUp(), findsNothing);
      expect(find.text(es.voiceProAction), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'UX-1005: the form opened by «Nueva tarea» keeps nothing before typing, one capture «Llamar a» after typing it, none after «Añadir tarea», and none after emptying the title and pressing Back',
    (tester) async {
      final app = await _FreeApp.open(
        tester,
        freeVoice: freeVoice(0),
        noticeSeen: true,
      );
      await tester.tap(find.text(es.newTask).hitTestable());
      await tester.pumpAndSettle();
      expect(form(), findsOneWidget);
      expect(waiting(app), isEmpty, reason: 'nothing before typing');
      await tester.enterText(title(), 'Llamar a');
      await tester.pumpAndSettle();
      expect(waiting(app), hasLength(1));
      expect(waiting(app).single.text, 'Llamar a');
      await tapSave(tester);
      expect(form(), findsNothing);
      expect(app.tasks.titles(), ['Llamar a']);
      expect(waiting(app), isEmpty, reason: 'saved');

      await tester.tap(find.text(es.newTask).hitTestable());
      await tester.pumpAndSettle();
      await tester.enterText(title(), 'Llamar a');
      await tester.pumpAndSettle();
      expect(waiting(app), hasLength(1));
      await tester.enterText(title(), '');
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(form(), findsNothing);
      expect(app.tasks.titles(), ['Llamar a'], reason: 'nothing more saved');
      expect(waiting(app), isEmpty, reason: 'closed with no title');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'UX-1005: the form keeps its title and notes in the capture: the title, a line break, then the notes, which open again from «Sin guardar»',
    (tester) async {
      final app = await _FreeApp.open(
        tester,
        freeVoice: freeVoice(0),
        noticeSeen: true,
      );
      await tester.tap(find.text(es.newTask).hitTestable());
      await tester.pumpAndSettle();
      await tester.enterText(title(), 'Llamar a Ana');
      await tester.pumpAndSettle();
      final more = find.byKey(const ValueKey('task-more-details'));
      await tester.ensureVisible(more);
      await tester.pumpAndSettle();
      await tester.tap(more);
      await tester.pumpAndSettle();
      final notes = find.byKey(const ValueKey('task-notes'));
      await tester.ensureVisible(notes);
      await tester.enterText(notes, 'Por el viaje');
      await tester.pumpAndSettle();
      expect(waiting(app), hasLength(1));
      expect(waiting(app).single.text, 'Llamar a Ana\nPor el viaje');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'UX-1005: «Escribir» in the mic sheet hands its capture to the form: typing there keeps exactly that one capture until the save',
    (tester) async {
      final app = await _FreeApp.open(tester, freeVoice: freeVoice(5));
      await tester.tap(find.text(es.addTask).hitTestable());
      await tester.pumpAndSettle();
      app.speech.send('ready');
      app.speech.send('segment', text: 'Llamar a');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      await tester.tap(find.byKey(const ValueKey('capture-fill-by-hand')));
      await tester.pumpAndSettle();
      expect(form(), findsOneWidget);
      expect(formTitle(tester), 'Llamar a');
      expect(app.store.sessions, hasLength(1), reason: 'the sheet’s');
      final sheets = app.store.sessions.keys.single;
      expect(waiting(app).single.id, sheets);
      await tester.enterText(title(), 'Llamar a Ana');
      await tester.pumpAndSettle();
      expect(
        app.store.sessions,
        hasLength(1),
        reason: 'still only the sheet’s',
      );
      expect(waiting(app).single.id, sheets);
      expect(waiting(app).single.text, 'Llamar a Ana');
      await tapSave(tester);
      expect(app.tasks.titles(), ['Llamar a Ana']);
      expect(app.store.sessions, hasLength(1));
      expect(waiting(app), isEmpty);
      expect(app.api.drafts, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'UX-1011: at 0 left, with the app on Tareas, a task saved in the form the widget’s entry opened switches to Calendario, with its day selected and its row lit',
    (tester) async {
      final app = await _FreeApp.open(
        tester,
        freeVoice: freeVoice(0),
        noticeSeen: true,
      );
      await openTasksTab(tester);
      expect(find.byType(CalendarScreen).hitTestable(), findsNothing);
      await app.deliver(tester, entry('voice'));
      expect(form(), findsOneWidget);
      await tester.enterText(title(), 'Regar las plantas');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('new-task-tomorrow')));
      await tester.pumpAndSettle();
      await tapSave(tester);
      final now = DateTime.now();
      final tomorrow = DateTime(now.year, now.month, now.day + 1);
      expect(form(), findsNothing);
      expect(find.byType(CalendarScreen).hitTestable(), findsOneWidget);
      expect(
        find.text(DateFormat.MMMMEEEEd('es').format(tomorrow)),
        findsOneWidget,
      );
      final row = find.widgetWithText(TaskTile, 'Regar las plantas');
      expect(row.hitTestable(), findsOneWidget);
      expect(
        tester.widget<TaskTile>(row).color,
        Theme.of(
          tester.element(find.byType(NavigationBar)),
        ).colorScheme.primaryContainer,
      );
      expect(tester.takeException(), isNull);
    },
  );

  // ---- Run 2026-10-18-commands, b3 · P140 (UX-1009): the used-up notice
  // says «a mano», with the date before the number ----

  group('UX-1009: the used-up notice', () {
    setUpAll(() async {
      final font = FontLoader('Manrope')
        ..addFont(rootBundle.load('assets/fonts/Manrope.ttf'));
      await font.load();
    });

    test(
      'UX-1009: freeVoiceNoticeBody names no form in any language, puts the date before the number, keeps its plurals, and the Catalan reads «El dia {date}»',
      () {
        for (final (l, form) in [
          (es, 'formulario'),
          (en, 'form'),
          (ca, 'formulari'),
        ]) {
          for (final limit in [1, 10]) {
            final body = l.freeVoiceNoticeBody(limit, 'DATE');
            expect(
              body.toLowerCase(),
              isNot(contains(form)),
              reason: '${l.localeName}: $body',
            );
            expect(
              body.indexOf('DATE'),
              lessThan(body.indexOf('$limit')),
              reason: '${l.localeName}: the date before the number: $body',
            );
          }
        }
        expect(
          es.freeVoiceNoticeBody(10, 'DATE'),
          'Puedes seguir creando tareas a mano, sin límite. El DATE tendrás 10 dictados más.',
        );
        expect(
          es.freeVoiceNoticeBody(1, 'DATE'),
          'Puedes seguir creando tareas a mano, sin límite. El DATE tendrás 1 dictado más.',
        );
        expect(
          en.freeVoiceNoticeBody(10, 'DATE'),
          'You can keep creating tasks by hand, with no limit. On DATE you’ll get 10 more dictations.',
        );
        expect(
          en.freeVoiceNoticeBody(1, 'DATE'),
          'You can keep creating tasks by hand, with no limit. On DATE you’ll get 1 more dictation.',
        );
        expect(
          ca.freeVoiceNoticeBody(10, 'DATE'),
          'Pots continuar creant tasques a mà, sense límit. El dia DATE tindràs 10 dictats més.',
        );
        expect(
          ca.freeVoiceNoticeBody(1, 'DATE'),
          'Pots continuar creant tasques a mà, sense límit. El dia DATE tindràs 1 dictat més.',
        );
        expect(ca.freeVoiceNoticeBody(10, 'DATE'), contains('El dia DATE'));
      },
    );

    testWidgets(
      'UX-1009: at 2× on 320×640 in Spanish the notice’s body reads «Puedes seguir creando tareas a mano, sin límite. El {date} tendrás 10 dictados más.» in full, with no overflow',
      (tester) async {
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final resets = nextReset();
        await _FreeApp.open(
          tester,
          freeVoice: freeVoice(0, resets: resets),
          size: const Size(320, 640),
        );
        await tester.tap(inActions(find.text(es.newTask)).hitTestable());
        await tester.pumpAndSettle();
        expect(notice(), findsOneWidget);
        final date = resetDay(tester, resets);
        final expected =
            'Puedes seguir creando tareas a mano, sin límite. El $date tendrás 10 dictados más.';
        expect(es.freeVoiceNoticeBody(10, date), expected);
        final body = inNotice(find.text(expected));
        expect(body, findsOneWidget);
        await tester.ensureVisible(body);
        await tester.pumpAndSettle();
        final rect = tester.getRect(body);
        expect(rect.left, greaterThanOrEqualTo(0));
        expect(rect.right, lessThanOrEqualTo(320.5));
        expect(rect.top, greaterThanOrEqualTo(0));
        expect(rect.bottom, lessThanOrEqualTo(640.5));
        for (final paragraph in tester.renderObjectList<RenderParagraph>(
          find.descendant(
            of: body,
            matching: find.byType(RichText),
            matchRoot: true,
          ),
        )) {
          expect(paragraph.didExceedMaxLines, isFalse);
        }
        expect(tester.takeException(), isNull, reason: 'no overflow');
      },
    );
  });

  // ---- Run 2026-10-18-commands, b4 · P153 (UX-918, D2): words dictated
  // before «Escribir» keep the day and time they name; typed and shared
  // words stay as typed ----

  group('UX-918: dictated words carried into the form by Escribir', () {
    // Monday 19 October 2026 at 10:00; that week's Friday is the 23rd.
    final monday = DateTime(2026, 10, 19, 10);
    final friday = DateTime(2026, 10, 23);
    Finder chip(String key) => find.byKey(ValueKey(key));
    bool selected(WidgetTester tester, String key) =>
        tester.widget<ChoiceChip>(chip(key)).selected;
    String chipLabel(WidgetTester tester, String key) => tester
        .widget<Text>(
          find.descendant(of: chip(key), matching: find.byType(Text)).last,
        )
        .data!;
    BuildContext formContext(WidgetTester tester) =>
        tester.element(find.byType(TaskEditor));

    /// A free account with dictations left: Añadir tarea, the mic hears
    /// [words], then Escribir.
    Future<_FreeApp> heardThenEscribir(
      WidgetTester tester,
      String words,
    ) async {
      final app = await _FreeApp.open(
        tester,
        freeVoice: freeVoice(5),
        clock: monday,
      );
      await tester.tap(find.text(es.addTask).hitTestable());
      await tester.pumpAndSettle();
      app.speech.send('ready');
      app.speech.send('segment', text: words);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      await tester.tap(find.byKey(const ValueKey('capture-fill-by-hand')));
      await tester.pumpAndSettle();
      expect(form(), findsOneWidget);
      expect(app.api.drafts, isEmpty, reason: 'no dictation used');
      return app;
    }

    testWidgets(
      'UX-918: heard «Médico el viernes a las 5 de la tarde», Escribir opens the form titled «Médico», with the third day chip reading Friday 23 and selected, and the time chip reading 17:00',
      (tester) async {
        await heardThenEscribir(
          tester,
          'Médico el viernes a las 5 de la tarde',
        );
        expect(formTitle(tester), 'Médico');
        final context = formContext(tester);
        expect(
          chipLabel(tester, 'new-task-pick-day'),
          context.weekdayDate(friday),
        );
        expect(selected(tester, 'new-task-pick-day'), isTrue);
        expect(selected(tester, 'new-task-today'), isFalse);
        expect(selected(tester, 'new-task-tomorrow'), isFalse);
        expect(
          find.widgetWithText(
            InputChip,
            context.clockTime(DateTime(2026, 10, 23, 17)),
          ),
          findsOneWidget,
        );
        expect(context.clockTime(DateTime(2026, 10, 23, 17)), '17:00');
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'UX-918: heard «Médico el viernes a las 5» (no a. m. or p. m.), the form never guesses: titled «Médico a las 5», Friday 23 selected, and «Añadir hora» with no time set',
      (tester) async {
        await heardThenEscribir(tester, 'Médico el viernes a las 5');
        expect(formTitle(tester), 'Médico a las 5');
        expect(selected(tester, 'new-task-pick-day'), isTrue);
        expect(
          chipLabel(tester, 'new-task-pick-day'),
          formContext(tester).weekdayDate(friday),
        );
        expect(find.widgetWithText(ActionChip, es.addTime), findsOneWidget);
        expect(find.byType(InputChip), findsNothing, reason: 'no time set');
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'UX-918, UX-1010: heard «Entregar la factura antes del viernes»: titled «Entregar la factura», no day chosen, the collapsed form says «Vence vie, 23 oct»; Añadir tarea lands on Friday 23 with the row lit and «Añadida · vence el vie, 23 oct»',
      (tester) async {
        final app = await heardThenEscribir(
          tester,
          'Entregar la factura antes del viernes',
        );
        expect(formTitle(tester), 'Entregar la factura');
        for (final key in [
          'new-task-today',
          'new-task-tomorrow',
          'new-task-pick-day',
        ]) {
          expect(selected(tester, key), isFalse, reason: key);
        }
        final due = es.deadlineLabel(formContext(tester).weekdayDate(friday));
        expect(find.text(due), findsOneWidget, reason: due);

        await tester.ensureVisible(find.byKey(const ValueKey('task-save')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('task-save')));
        await tester.pumpAndSettle();
        expect(form(), findsNothing);
        final saved = app.tasks.state.requireValue.single;
        expect(saved.title, 'Entregar la factura');
        expect(saved.dueDate, isNull);
        expect(Task.day(saved.deadline!), friday);
        final calendar = tester.element(find.byType(CalendarScreen));
        expect(
          find.text(DateFormat.MMMMEEEEd('es').format(friday)),
          findsOneWidget,
          reason: 'Calendar shows Friday 23',
        );
        final row = find.widgetWithText(TaskTile, 'Entregar la factura');
        expect(row.hitTestable(), findsOneWidget);
        expect(
          tester.widget<TaskTile>(row).color,
          Theme.of(calendar).colorScheme.primaryContainer,
        );
        expect(
          find.text(es.taskAddedDue(calendar.weekdayDate(friday))),
          findsOneWidget,
        );
        expect(find.text(es.undo), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'UX-918: a title typed in the form, «Médico el viernes», saved with Añadir tarea has no day; shared text «Médico el viernes» opened in the form keeps that title and no day',
      (tester) async {
        final app = await _FreeApp.open(
          tester,
          freeVoice: freeVoice(5),
          clock: monday,
        );
        // Escribir before anything is said: an empty form, typed in.
        await tester.tap(find.text(es.addTask).hitTestable());
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('capture-fill-by-hand')));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const ValueKey('task-title')),
          'Médico el viernes',
        );
        await tester.pumpAndSettle();
        expect(selected(tester, 'new-task-pick-day'), isFalse);
        await tester.tap(find.byKey(const ValueKey('task-save')));
        await tester.pumpAndSettle();
        final typed = app.tasks.state.requireValue.single;
        expect(typed.title, 'Médico el viernes');
        expect(typed.dueDate, isNull);
        expect(typed.deadline, isNull);

        // Shared text opens straight in the form.
        app.store.sessions['shared'] = CaptureSession(
          id: 'shared',
          ownerKey: app.owner,
          timezone: 'Europe/Madrid',
          capturedAt: monday.toUtc(),
          text: 'Médico el viernes',
          source: 'shared',
        );
        unawaited(
          showCaptureSheet(
            tester.element(find.byType(Scaffold).first),
            captureId: 'shared',
            startListening: false,
            typing: true,
          ),
        );
        await tester.pumpAndSettle();
        expect(form(), findsOneWidget);
        expect(formTitle(tester), 'Médico el viernes');
        for (final key in [
          'new-task-today',
          'new-task-tomorrow',
          'new-task-pick-day',
        ]) {
          expect(selected(tester, key), isFalse, reason: key);
        }
        await tester.tap(find.byKey(const ValueKey('task-save')));
        await tester.pumpAndSettle();
        final shared = app.tasks.state.requireValue.last;
        expect(shared.title, 'Médico el viernes');
        expect(shared.dueDate, isNull);
        expect(shared.deadline, isNull);
        expect(tester.takeException(), isNull);
      },
    );
  });

  // ---- UX loop 2026-10-19-app, round 1 · P167 (UX-1301) ----

  testWidgets(
    'UX-1301: a free account whose last dictation was answered with nothing found has Escribir as the filled button, and no Volver a decirlo',
    (tester) async {
      final app = await _FreeApp.open(
        tester,
        freeVoice: freeVoice(1),
        size: const Size(360, 800),
      );
      app.api
        ..findsNothing = true
        ..answerFreeVoice = freeVoice(0);
      await dictate(tester, app, 'Bueno, a ver, no sé');
      // The answer's count is saved with the session.
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pumpAndSettle();
      expect(app.container.read(freeVoiceLeftProvider), 0);
      expect(inSheet(find.text(es.captureNoTasks)), findsOneWidget);
      final filled = inSheet(find.byType(FilledButton));
      expect(filled, findsOneWidget);
      expect(
        find.descendant(of: filled, matching: find.text(es.captureTypeInstead)),
        findsOneWidget,
      );
      expect(filled.hitTestable(), findsOneWidget);
      expect(inSheet(find.text(es.captureSayAgain)), findsNothing);
      expect(inSheet(find.text(es.tryAgain)), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  // ---- UX loop 2026-10-19-app, batch b2 round 2 · P200 (UX-1630) ----
  // Today's dictation limit refuses a recording that has no words yet: the
  // banner says the recording is kept, and the only button is Cerrar.

  final limitRefusal = ApiException(
    429,
    'Too many requests.',
    null,
    const Duration(seconds: 3600),
  );

  /// Waits for the sheet's request number [requests] and its answer.
  Future<void> answered(WidgetTester tester, _FreeApp app, int requests) async {
    for (var i = 0; i < 10 && app.api.drafts.length < requests; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
    }
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pumpAndSettle();
    expect(app.api.drafts, hasLength(requests));
  }

  /// [keepRecording]'s capture opened in the sheet and sent with Listo; the
  /// server refuses it with today's limit.
  Future<_FreeApp> refusedByTheLimit(
    WidgetTester tester, {
    String language = 'es',
  }) async {
    final l = strings(language);
    final app = await _FreeApp.open(
      tester,
      freeVoice: freeVoice(5),
      language: language,
      size: const Size(360, 800),
    );
    keepRecording(app, id: 'limit-wav');
    app.api.failure = limitRefusal;
    unawaited(
      showCaptureSheet(
        tester.element(find.byType(Scaffold).first),
        captureId: 'limit-wav',
        startListening: false,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(button(l.done));
    await answered(tester, app, 1);
    return app;
  }

  /// The labels of the sheet's text buttons, filled, outlined or plain.
  List<String> sheetButtons(WidgetTester tester) => [
    for (final element in inSheet(
      find.byWidgetPredicate((w) => w is ButtonStyleButton),
    ).evaluate())
      [
        for (final text
            in find
                .descendant(
                  of: find.byWidget(element.widget),
                  matching: find.byType(Text),
                )
                .evaluate())
          (text.widget as Text).data ?? '',
      ].join(' '),
  ];

  for (final language in ['es', 'en', 'ca']) {
    testWidgets(
      'UX-1630 ($language, 1× on 360×800): a recording with no words refused by today’s limit says the recording is kept, and the only button is Cerrar',
      (tester) async {
        final l = strings(language);
        await refusedByTheLimit(tester, language: language);
        final banner = inSheet(find.byType(MessageBanner));
        expect(banner, findsOneWidget);
        expect(
          find.descendant(
            of: banner,
            matching: find.text(l.captureAllowanceRecording),
          ),
          findsOneWidget,
        );
        expect(find.text(l.captureAllowance), findsNothing);
        expect(sheetButtons(tester), [l.captureClose]);
        expect(
          inSheet(find.widgetWithText(FilledButton, l.captureClose)),
          findsOneWidget,
        );
        expect(
          inSheet(find.byKey(const ValueKey('capture-close'))).hitTestable(),
          findsOneWidget,
        );
        for (final hidden in [
          l.tryAgain,
          l.cancel,
          l.captureSaveAsWritten,
          l.recordingKept,
        ]) {
          expect(inSheet(find.text(hidden)), findsNothing, reason: hidden);
        }
        expect(tester.takeException(), isNull);
      },
    );
  }

  test(
    'UX-1630: the limit line for a recording reads as written in each language',
    () {
      expect(
        es.captureAllowanceRecording,
        'Has llegado al límite de dictados de hoy. Tu grabación se conserva; inténtalo mañana.',
      );
      expect(
        en.captureAllowanceRecording,
        'You’ve reached today’s dictation limit. Your recording is kept; try again tomorrow.',
      );
      expect(
        ca.captureAllowanceRecording,
        'Has arribat al límit de dictats d’avui. La gravació es conserva; torna-ho a provar demà.',
      );
    },
  );

  for (final (how, close) in [
    (
      'Cerrar',
      (WidgetTester tester) => tester.tap(
        inSheet(find.widgetWithText(FilledButton, es.captureClose)),
      ),
    ),
    ('Back', (WidgetTester tester) => tester.binding.handlePopRoute()),
  ]) {
    testWidgets(
      'UX-1630: in that state $how closes the sheet without the discard question, and the recording stays in Capturas pendientes',
      (tester) async {
        final app = await refusedByTheLimit(tester);
        await close(tester);
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsNothing);
        expect(find.byType(BottomSheet), findsNothing, reason: 'closed');
        expect(app.store.sessions['limit-wav']!.status, isNot('discarded'));
        app.container.invalidate(pendingCapturesProvider);
        expect(
          (await app.container.read(
            pendingCapturesProvider.future,
          )).map((s) => s.id),
          contains('limit-wav'),
        );
        tester
            .state<NavigatorState>(find.byType(Navigator).first)
            .pushNamed('/captures');
        await tester.pumpAndSettle();
        expect(find.byType(CapturesScreen), findsOneWidget);
        expect(find.text(es.voiceRecording), findsOneWidget);
        expect(app.api.drafts, hasLength(1));
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'UX-1630: the refused recording, reopened from Capturas pendientes, shows Reintentar and not the limit line; when the server answers, the result shows',
    (tester) async {
      final app = await refusedByTheLimit(tester);
      await tester.tap(
        inSheet(find.widgetWithText(FilledButton, es.captureClose)),
      );
      await tester.pumpAndSettle();
      // The fixture put the recording in the store directly: read afresh.
      app.container.invalidate(pendingCapturesProvider);
      tester
          .state<NavigatorState>(find.byType(Navigator).first)
          .pushNamed('/captures');
      await tester.pumpAndSettle();
      await tester.tap(find.text(es.voiceRecording));
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsOneWidget, reason: 'reopened');
      expect(find.text(es.captureAllowanceRecording), findsNothing);
      expect(find.text(es.captureAllowance), findsNothing);
      final retry = inSheet(find.widgetWithText(FilledButton, es.tryAgain));
      expect(retry, findsOneWidget);
      expect(retry.hitTestable(), findsOneWidget);

      // Tomorrow: the server understands it.
      app.api
        ..failure = null
        ..transcript = 'Comprar pan';
      await tester.tap(retry);
      await answered(tester, app, 2);
      expect(find.byType(CaptureResult), findsOneWidget);
      expect(find.text('Comprar pan'), findsWidgets);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'UX-1630: reopened while the limit still holds, the refusal comes back with only Cerrar',
    (tester) async {
      final app = await refusedByTheLimit(tester);
      await tester.tap(
        inSheet(find.widgetWithText(FilledButton, es.captureClose)),
      );
      await tester.pumpAndSettle();
      unawaited(
        showCaptureSheet(
          tester.element(find.byType(Scaffold).first),
          captureId: 'limit-wav',
          startListening: false,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(inSheet(find.widgetWithText(FilledButton, es.tryAgain)));
      await answered(tester, app, 2);
      expect(inSheet(find.text(es.captureAllowanceRecording)), findsOneWidget);
      expect(sheetButtons(tester), [es.captureClose]);
      expect(tester.takeException(), isNull);
    },
  );

  // ---- Run 2026-10-19-app, round 1 · P185 (UX-1518): a typed note isn't
  // told about dictations ----

  testWidgets(
    'UX-1518: a free account with 0 dictations left: Notas’ «Añadir nota» opens typing with no «Sin dictados gratis…» line and no «Ver Pro»; trying to dictate a note shows the used-up line',
    (tester) async {
      final resets = nextReset();
      final app = await _FreeApp.open(
        tester,
        freeVoice: freeVoice(0, resets: resets),
        noticeSeen: true,
      );
      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text(es.notes),
        ),
      );
      await tester.pumpAndSettle();
      final add = find.widgetWithText(FilledButton, es.addNote).hitTestable();
      expect(add, findsOneWidget);
      await tester.tap(add);
      await tester.pumpAndSettle();
      expect(find.byType(VoiceTaskScreen), findsOneWidget);
      expect(words(), findsOneWidget, reason: 'it types');
      expect(app.recorders, 0);
      expect(usedUp(), findsNothing);
      expect(find.textContaining('Sin dictados gratis'), findsNothing);
      expect(find.text(es.voiceProAction), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(VoiceTaskScreen), findsNothing);

      // A way in that asks to speak, for a note: now the limit is told.
      unawaited(
        showCaptureSheet(
          tester.element(find.byType(NotesScreen)),
          kind: 'note',
          askedToSpeak: true,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(VoiceTaskScreen), findsOneWidget);
      expect(usedUp(), findsOneWidget);
      expect(
        tester.widget<Text>(usedUp()).data,
        es.freeVoiceUsedUp(resetDay(tester, resets)),
      );
      expect(find.text(es.voiceProAction), findsOneWidget);
      expect(app.recorders, 0);
      expect(tester.takeException(), isNull);
    },
  );
}

/// A phone whose database can't be read or written.
class _BrokenNotices extends FreeVoiceNoticeStore {
  _BrokenNotices() : super(TaskDatabase());
  @override
  Future<DateTime?> seen(String owner) async =>
      throw StateError('No database.');
  @override
  Future<void> markSeen(String owner, DateTime resetsAt) async =>
      throw StateError('No database.');
}

Map<String, dynamic> _session(Map<String, dynamic>? free, {int id = 1}) => {
  'access': 'fixture-access',
  'refresh': 'fixture-refresh',
  'user': {
    'id': id,
    'email': 'free$id@example.invalid',
    'timezone': 'Europe/Madrid',
    if (free != null) 'free_voice': free,
  },
};

/// The phone's memory of the used-up notice, without sqflite: the month
/// each account has seen it for.
class _Notices extends FreeVoiceNoticeStore {
  _Notices() : super(TaskDatabase());
  final months = <String, DateTime>{};
  int writes = 0;
  @override
  Future<DateTime?> seen(String owner) async => months[owner];
  @override
  Future<void> markSeen(String owner, DateTime resetsAt) async {
    writes++;
    months[owner] = resetsAt;
  }
}

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
  _FreeApp(
    this.container,
    this.api,
    this.store,
    this.tasks,
    this.speech,
    this.notices,
  );
  final ProviderContainer container;
  final _Api api;
  final _Captures store;
  final _Tasks tasks;
  final _Speech speech;
  final _Notices notices;
  int recorders = 0;

  /// Android's queue of entries from outside the app: the widget, the
  /// shortcuts and share.
  final queue = <Map<String, Object>>[];

  /// Android hands over [entry], from the widget, a shortcut or a share.
  Future<void> deliver(WidgetTester tester, Map<String, Object> entry) async {
    queue.add(entry);
    const channel = MethodChannel('test/free-dictation-entries');
    await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
      channel.name,
      channel.codec.encodeMethodCall(const MethodCall('changed')),
      (_) {},
    );
    await tester.pumpAndSettle();
  }

  /// The signed-in account's key on this phone.
  String get owner => container.read(captureOwnerProvider);

  /// [notices] is the phone's memory of the used-up notice, kept across
  /// runs when a test passes the same one; [noticeSeen] starts with it
  /// seen for [freeVoice]'s month.
  static Future<_FreeApp> open(
    WidgetTester tester, {
    bool pro = false,
    Map<String, dynamic>? freeVoice,
    String language = 'es',
    Size size = const Size(390, 844),
    bool billingLoading = false,
    int accountId = 1,
    _Notices? notices,
    bool noticeSeen = false,
    DateTime? clock,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    FlutterSecureStorage.setMockInitialValues({
      'taskflow.session': jsonEncode(_session(freeVoice, id: accountId)),
    });
    final api = _Api();
    final store = _Captures();
    final tasks = _Tasks();
    final speech = _Speech();
    final seen = notices ?? _Notices();
    if (noticeSeen && freeVoice != null) {
      seen.months['${api.baseUrl}/users/$accountId'] = DateTime.parse(
        '${freeVoice['resets_at']}',
      );
    }
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
        freeVoiceNoticeStoreProvider.overrideWithValue(seen),
        if (clock != null) calendarClockProvider.overrideWithValue(() => clock),
      ],
    );
    app = _FreeApp(container, api, store, tasks, speech, seen);
    store.tasks = tasks;
    final messenger = tester.binding.defaultBinaryMessenger;
    const channel = MethodChannel('test/free-dictation-entries');
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'pending') return [...app.queue];
      if (call.method == 'acknowledge') {
        final id = (call.arguments as Map)['id'];
        app.queue.removeWhere((entry) => entry['id'] == id);
      }
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

  /// What the assistant heard in a recording, when set; otherwise the words
  /// sent.
  String? transcript;

  /// The assistant finds no task and no command in the words.
  bool findsNothing = false;

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
      final text = transcript ?? '${data?['text'] ?? ''}';
      return {
        'transcript': text,
        'tasks': [if (!findsNothing) _found(text)],
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
  int warms = 0;
  int? _run;
  @override
  void warm(String language) {
    warms++;
    super.warm(language);
  }

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
