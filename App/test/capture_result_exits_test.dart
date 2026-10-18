// P60 (UX-456, UX-457, UX-458): the capture result has a visible Cancelar,
// `Volver a decirlo` no longer throws the result away, and TalkBack hears
// which line is the date.
import 'dart:async';
import 'dart:ui' show Tristate;

import 'package:agenda/l10n/generated/app_localizations.dart';
import 'package:agenda/main.dart';
import 'package:agenda/models/capture_session.dart';
import 'package:agenda/models/task.dart';
import 'package:agenda/providers/auth_provider.dart';
import 'package:agenda/providers/regional_provider.dart';
import 'package:agenda/providers/subscription_provider.dart';
import 'package:agenda/providers/task_lists_provider.dart';
import 'package:agenda/providers/task_provider.dart';
import 'package:agenda/providers/theme_provider.dart';
import 'package:agenda/screens/voice_task_screen.dart';
import 'package:agenda/services/api_client.dart';
import 'package:agenda/services/capture_store.dart';
import 'package:agenda/services/invitation_links.dart';
import 'package:agenda/services/native_speech.dart';
import 'package:agenda/services/task_database.dart';
import 'package:agenda/widgets/app_components.dart' show MessageBanner;
import 'package:agenda/widgets/attachment_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/capture_fixtures.dart' show SilentRecorder;
import 'support/design_fixtures.dart';

final es = lookupAppLocalizations(const Locale('es'));
final ca = lookupAppLocalizations(const Locale('ca'));

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

  Finder title() => find.byKey(const ValueKey('task-title'));
  String titleText(WidgetTester tester) =>
      tester.widget<TextFormField>(title()).controller!.text;
  Finder resultButton(String label) => find.descendant(
    of: find.byType(CaptureResult),
    matching: find.widgetWithText(TextButton, label),
  );

  testWidgets(
    'UX-456: after Volver a decirlo, Cancelar while listening brings back the same result with its edits, asks nothing, and leaves only the original pending',
    (tester) async {
      final app = await _App.open(tester);
      app.api.found = [_found('Comprar pan')];
      await app.speak(tester, 'Comprar pan');
      expect(find.byType(CaptureResult), findsOneWidget);
      final original = app.store.pendingIds.single;
      await tester.enterText(title(), 'Comprar pan integral');
      await tester.pumpAndSettle();

      await tester.tap(resultButton(es.captureSayAgain));
      await tester.pumpAndSettle();
      expect(find.byType(CaptureResult), findsNothing);
      expect(app.speech.starts, 2, reason: 'listening again');
      // Something is heard before changing one's mind.
      app.speech.send('ready');
      app.speech.send('segment', text: 'Comprar leche');
      await tester.pumpAndSettle();
      expect(find.text('Comprar leche'), findsOneWidget);

      await tester.tap(find.widgetWithText(TextButton, es.cancel));
      await tester.pumpAndSettle();
      expect(find.text(es.captureKeepQuestion), findsNothing);
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byType(CaptureResult), findsOneWidget);
      expect(titleText(tester), 'Comprar pan integral');
      expect(app.store.pendingIds, [original]);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'UX-456: after Volver a decirlo, new words that are understood replace the result, and the previous capture leaves the pending list',
    (tester) async {
      final app = await _App.open(tester);
      app.api.found = [_found('Comprar pan')];
      await app.speak(tester, 'Comprar pan');
      final original = app.store.pendingIds.single;
      // Still pending while listening again: a mis-tap loses nothing.
      await tester.tap(resultButton(es.captureSayAgain));
      await tester.pumpAndSettle();
      expect(app.store.pendingIds, contains(original));

      app.api.found = [_found('Comprar leche')];
      app.speech.send('ready');
      app.speech.send('segment', text: 'Comprar leche');
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, es.done));
      await tester.pumpAndSettle();

      expect(find.byType(CaptureResult), findsOneWidget);
      expect(titleText(tester), 'Comprar leche');
      expect(app.store.pendingIds, hasLength(1));
      expect(app.store.pendingIds.single, isNot(original));
      expect(app.store.sessions[original]!.status, 'discarded');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'UX-457 / UX-605: the result shows Cancelar; it asks to keep, and Conservar closes the sheet with the capture pending',
    (tester) async {
      final app = await _App.open(tester);
      app.api.found = [_found('Comprar pan')];
      await app.speak(tester, 'Comprar pan');
      expect(es.cancel, 'Cancelar');
      final cancel = resultButton(es.cancel);
      expect(cancel.hitTestable(), findsOneWidget);
      final id = app.store.pendingIds.single;
      await tester.tap(cancel);
      await tester.pumpAndSettle();
      expect(find.text(es.captureKeepQuestion), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, es.keep));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byType(CaptureResult), findsNothing);
      expect(find.byType(BottomSheet), findsNothing);
      expect(app.store.pendingIds, [id]);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('UX-457: a typed result shows Cancelar and no Volver a decirlo', (
    tester,
  ) async {
    final app = await _App.open(tester);
    app.api.found = [_found('Comprar pan')];
    await app.type(tester, 'Comprar pan');
    expect(find.byType(CaptureResult), findsOneWidget);
    expect(resultButton(es.cancel).hitTestable(), findsOneWidget);
    expect(find.text(es.captureSayAgain), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final (language, l) in [('es', es), ('ca', ca)]) {
    testWidgets(
      'UX-456 / UX-457: at 2× text on 360×740 ($language), ${l.cancel} and ${l.captureSayAgain} are both reachable, nothing overflows, and they sit at least 12 dp under the add button',
      (tester) async {
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final app = await _App.open(
          tester,
          language: language,
          size: const Size(360, 740),
        );
        await app.openResult(
          tester,
          _spoken(app, 'Comprar pan', DateTime.now()),
        );
        expect(find.byType(CaptureResult), findsOneWidget);
        expect(l.cancel, language == 'es' ? 'Cancelar' : 'Cancel·la');
        expect(
          l.captureSayAgain,
          language == 'es' ? 'Volver a decirlo' : 'Torna-ho a dir',
        );
        final cancel = resultButton(l.cancel);
        final again = resultButton(l.captureSayAgain);
        expect(cancel.hitTestable(), findsOneWidget);
        expect(again.hitTestable(), findsOneWidget);
        final save = tester.getRect(find.byKey(const ValueKey('save-drafts')));
        final below = [
          tester.getRect(cancel),
          tester.getRect(again),
        ].where((rect) => rect.top >= save.top).toList();
        expect(below, hasLength(2), reason: 'both are under the add button');
        final nearest = below
            .map((rect) => rect.top)
            .reduce((a, b) => a < b ? a : b);
        expect(nearest - save.bottom, greaterThanOrEqualTo(12));
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'UX-458: TalkBack reads the result’s date line as Fecha y hora: Hoy, and its tap opens the date sheet',
    (tester) async {
      final semantics = tester.ensureSemantics();
      final app = await _App.open(tester);
      final now = DateTime.now();
      await app.openResult(
        tester,
        _spoken(app, 'Comprar pan', DateTime(now.year, now.month, now.day)),
      );
      expect(es.reviewSchedule, 'Fecha y hora');
      final label = '${es.reviewSchedule}: ${es.today}';
      expect(label, 'Fecha y hora: Hoy');
      final node = find.semantics.byLabel(label);
      expect(node, findsOne);
      expect(
        node.evaluate().single.getSemanticsData().hasAction(
          SemanticsAction.tap,
        ),
        isTrue,
      );
      expect(
        node.evaluate().single.getSemanticsData().flagsCollection.isButton,
        isTrue,
      );
      tester.semantics.tap(node);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('schedule-done')), findsOneWidget);
      semantics.dispose();
    },
  );

  // ---- P63 (UX-461, UX-462): Cancel while the words said again are
  // understood brings the result back; the date line is disabled while
  // saving ----

  /// Frames while `Entendiendo…` spins (it never settles).
  Future<void> frames(WidgetTester tester) async {
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  /// A spoken result edited to `Comprar pan integral`, then `Volver a
  /// decirlo`, `Comprar leche` heard and `Listo`, with understanding held
  /// until the test releases it. Returns the original capture's id.
  Future<(_App, String)> sayAgainHeld(WidgetTester tester) async {
    final app = await _App.open(tester);
    app.api.found = [_found('Comprar pan')];
    await app.speak(tester, 'Comprar pan');
    final original = app.store.pendingIds.single;
    await tester.enterText(title(), 'Comprar pan integral');
    await tester.pumpAndSettle();
    await tester.tap(resultButton(es.captureSayAgain));
    await tester.pumpAndSettle();
    app.api.found = [_found('Comprar leche')];
    app.api.hold = Completer<void>();
    app.speech.send('ready');
    app.speech.send('segment', text: 'Comprar leche');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, es.done));
    await frames(tester);
    expect(es.captureUnderstanding, 'Entendiendo…');
    expect(find.text(es.captureUnderstanding), findsOneWidget);
    expect(find.byType(CaptureResult), findsNothing);
    return (app, original);
  }

  /// The previous result is back, with its edit, and nothing asks.
  void expectPreviousBack(WidgetTester tester) {
    expect(find.text(es.captureKeepQuestion), findsNothing);
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.byType(CaptureResult), findsOneWidget);
    expect(find.text(es.captureUnderstanding), findsNothing);
    expect(titleText(tester), 'Comprar pan integral');
  }

  /// Understanding ended: the result is unchanged, no problem shows, and only
  /// the original capture is pending.
  void expectOnlyOriginal(WidgetTester tester, _App app, String original) {
    expect(find.byType(CaptureResult), findsOneWidget);
    expect(titleText(tester), 'Comprar pan integral');
    expect(find.text('Comprar leche'), findsNothing);
    expect(find.byType(MessageBanner), findsNothing);
    expect(find.byType(SnackBar), findsNothing);
    expect(find.byType(AlertDialog), findsNothing);
    expect(app.store.pendingIds, [original]);
    final others = app.store.sessions.values.where((s) => s.id != original);
    expect(others, isNotEmpty, reason: 'the words said again had a capture');
    expect(others.every((s) => s.status == 'discarded'), isTrue);
  }

  testWidgets(
    'UX-461: after Volver a decirlo and Listo, Cancelar during Entendiendo… brings the edited result back at once, asks nothing, and only the original stays pending',
    (tester) async {
      final (app, original) = await sayAgainHeld(tester);
      await tester.tap(find.widgetWithText(TextButton, es.cancel));
      await tester.pump();
      expectPreviousBack(tester);

      app.api.hold!.complete();
      await tester.pumpAndSettle();
      expectOnlyOriginal(tester, app, original);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'UX-461: after Volver a decirlo and Listo, system Back during Entendiendo… keeps the sheet open with the edited result and only the original pending',
    (tester) async {
      final (app, original) = await sayAgainHeld(tester);
      await tester.binding.handlePopRoute();
      await tester.pump();
      expectPreviousBack(tester);

      app.api.hold!.complete();
      await tester.pumpAndSettle();
      expectOnlyOriginal(tester, app, original);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'UX-461: when understanding the words said again fails after Cancelar, the previous result stays with no error and only the original pending',
    (tester) async {
      final (app, original) = await sayAgainHeld(tester);
      await tester.tap(find.widgetWithText(TextButton, es.cancel));
      await tester.pump();
      expectPreviousBack(tester);

      app.api.hold!.completeError(ApiException(503, 'Service unavailable'));
      await tester.pumpAndSettle();
      expectOnlyOriginal(tester, app, original);
      expect(find.textContaining('Service unavailable'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'UX-461: a first capture’s Cancelar during Entendiendo… still closes the sheet, and the capture is pending once understood',
    (tester) async {
      final app = await _App.open(tester);
      app.api.found = [_found('Comprar pan')];
      app.api.hold = Completer<void>();
      await tester.tap(find.text(es.addTask).hitTestable());
      await tester.pumpAndSettle();
      app.speech.send('ready');
      app.speech.send('segment', text: 'Comprar pan');
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, es.done));
      await frames(tester);
      expect(find.text(es.captureUnderstanding), findsOneWidget);

      await tester.tap(find.widgetWithText(TextButton, es.cancel));
      await tester.pumpAndSettle();
      expect(find.text(es.captureUnderstanding), findsNothing);
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byType(CaptureResult), findsNothing);

      app.api.hold!.complete();
      await tester.pumpAndSettle();
      expect(find.byType(CaptureResult), findsNothing);
      final id = app.store.pendingIds.single;
      final kept = app.store.sessions[id]!;
      expect(kept.status, 'ready');
      expect(kept.drafts.single.task.title, 'Comprar pan');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'UX-461: after Volver a decirlo and Listo with no Cancelar, the new result shows once understood and only the new capture stays pending',
    (tester) async {
      final (app, original) = await sayAgainHeld(tester);
      app.api.hold!.complete();
      await tester.pumpAndSettle();
      expect(find.byType(CaptureResult), findsOneWidget);
      expect(titleText(tester), 'Comprar leche');
      expect(find.byType(MessageBanner), findsNothing);
      expect(app.store.pendingIds, hasLength(1));
      expect(app.store.pendingIds.single, isNot(original));
      expect(app.store.sessions[original]!.status, 'discarded');
      expect(tester.takeException(), isNull);
    },
  );

  // ---- P66 (UX-464): going back during Entendiendo… never leaves the sheet
  // waiting on the abandoned step ----

  /// The sheet's keyboard button, `Escribir`.
  IconButton typeButton(WidgetTester tester) => tester.widget<IconButton>(
    find.ancestor(
      of: find.byIcon(Icons.keyboard_outlined),
      matching: find.byType(IconButton),
    ),
  );

  testWidgets(
    'UX-464: after Cancelar during Entendiendo…, Volver a decirlo listens at once and Escribir is enabled while the abandoned step is still held; Cancelar there brings the result back at once; the late answer changes nothing',
    (tester) async {
      final (app, original) = await sayAgainHeld(tester);
      await tester.tap(find.widgetWithText(TextButton, es.cancel));
      await tester.pump();
      expectPreviousBack(tester);
      expect(app.speech.starts, 2);

      // The understanding step is still held: nothing here waits for it.
      await tester.tap(resultButton(es.captureSayAgain));
      await frames(tester);
      expect(find.byType(CaptureResult), findsNothing);
      expect(app.speech.starts, 3, reason: 'listening started again at once');
      app.speech.send('ready');
      await frames(tester);
      expect(find.text(es.listeningSeconds('00:00')), findsOneWidget);
      expect(typeButton(tester).onPressed, isNotNull, reason: 'Escribir');

      await tester.tap(find.widgetWithText(TextButton, es.cancel));
      await frames(tester);
      expectPreviousBack(tester);

      // The abandoned step answers late: the sheet stays as it is.
      app.api.hold!.complete();
      await tester.pumpAndSettle();
      expectOnlyOriginal(tester, app, original);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'UX-464: with TalkBack, after Cancelar during Entendiendo…, Volver a decirlo shows Empezar a hablar and Escribir enabled; both work before the abandoned step answers, Cancelar brings the result back, and the late answer changes nothing',
    (tester) async {
      final (app, original) = await sayAgainHeld(tester);
      await tester.tap(find.widgetWithText(TextButton, es.cancel));
      await tester.pump();
      expectPreviousBack(tester);
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(accessibleNavigation: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      await frames(tester);

      await tester.tap(resultButton(es.captureSayAgain));
      await frames(tester);
      final start = find.widgetWithText(FilledButton, es.captureStartTalking);
      expect(start, findsOneWidget);
      expect(tester.widget<FilledButton>(start).onPressed, isNotNull);
      expect(typeButton(tester).onPressed, isNotNull, reason: 'Escribir');

      await tester.tap(start);
      await frames(tester);
      expect(app.speech.starts, 3, reason: 'Empezar a hablar listens at once');
      app.speech.send('ready');
      await frames(tester);
      expect(find.text(es.listeningSeconds('00:00')), findsOneWidget);

      await tester.tap(find.byTooltip(es.captureTypeInstead));
      await frames(tester);
      final field = find.byKey(const ValueKey('capture-words'));
      expect(field, findsOneWidget);
      expect(tester.widget<TextField>(field).readOnly, isFalse);
      await tester.enterText(field, 'Comprar leche');
      await frames(tester);

      // The abandoned step answers while typing: the words stay as typed.
      app.api.hold!.complete();
      await frames(tester);
      expect(find.byType(CaptureResult), findsNothing);
      expect(tester.widget<TextField>(field).controller!.text, 'Comprar leche');
      expect(find.byType(MessageBanner), findsNothing);

      await tester.tap(find.widgetWithText(TextButton, es.cancel));
      await tester.pumpAndSettle();
      expectPreviousBack(tester);
      expect(app.store.pendingIds, [original]);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'UX-462: while saving, the date line reads Fecha y hora: Hoy, is disabled and has no tap; otherwise it is enabled and its tap opens the date sheet',
    (tester) async {
      final semantics = tester.ensureSemantics();
      final app = await _App.open(tester);
      final now = DateTime.now();
      await app.openResult(
        tester,
        _spoken(app, 'Comprar pan', DateTime(now.year, now.month, now.day)),
      );
      final label = '${es.reviewSchedule}: ${es.today}';
      expect(label, 'Fecha y hora: Hoy');
      SemanticsData data() =>
          find.semantics.byLabel(label).evaluate().single.getSemanticsData();

      expect(find.semantics.byLabel(label), findsOne);
      expect(data().flagsCollection.isEnabled, Tristate.isTrue);
      expect(data().hasAction(SemanticsAction.tap), isTrue);

      app.store.holdSave = Completer<void>();
      await tester.tap(find.byKey(const ValueKey('save-drafts')));
      await frames(tester);
      expect(find.semantics.byLabel(label), findsOne);
      expect(data().flagsCollection.isButton, isTrue);
      expect(data().flagsCollection.isEnabled, Tristate.isFalse);
      expect(data().hasAction(SemanticsAction.tap), isFalse);

      // Saving ends (here it fails): the line works again.
      app.store.holdSave!.complete();
      await tester.pumpAndSettle();
      expect(data().flagsCollection.isEnabled, Tristate.isTrue);
      expect(data().hasAction(SemanticsAction.tap), isTrue);
      tester.semantics.tap(find.semantics.byLabel(label));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('schedule-done')), findsOneWidget);
      semantics.dispose();
    },
  );

  // ---- 2026-10-14-speed · P106 (UX-605, UX-612): leaving a result asks ----

  Finder dialog() => find.byType(AlertDialog);

  /// The one question, with its two buttons and no second line. It names
  /// the words: said, or typed.
  void expectKeepQuestion(WidgetTester tester, {bool spoken = true}) {
    final question = spoken
        ? es.captureKeepQuestion
        : es.captureKeepTextQuestion;
    expect(dialog(), findsOneWidget);
    expect(
      find.descendant(of: dialog(), matching: find.text(question)),
      findsOneWidget,
    );
    expect(
      question,
      spoken
          ? '¿Conservar lo que has dicho para más tarde?'
          : '¿Conservar el texto para más tarde?',
    );
    expect(tester.widget<AlertDialog>(dialog()).content, isNull);
    expect(
      find.descendant(
        of: dialog(),
        matching: find.widgetWithText(TextButton, es.discard),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: dialog(),
        matching: find.widgetWithText(FilledButton, es.keep),
      ),
      findsOneWidget,
    );
  }

  /// Calendar's pending-captures link, `Capturas pendientes · n`.
  Finder pendingLink(int count) => find.text(es.pendingCaptureCount(count));

  testWidgets(
    'UX-605: on a spoken result, Cancelar asks ¿Conservar lo que has dicho para más tarde? with Descartar and Conservar and no second line; Descartar closes the sheet and nothing is pending',
    (tester) async {
      final app = await _App.open(tester);
      app.api.found = [_found('Comprar pan')];
      await app.speak(tester, 'Comprar pan');
      expect(app.store.pendingIds, hasLength(1));
      await tester.tap(resultButton(es.cancel));
      await tester.pumpAndSettle();
      expectKeepQuestion(tester);
      await tester.tap(find.widgetWithText(TextButton, es.discard));
      await tester.pumpAndSettle();
      expect(dialog(), findsNothing);
      expect(find.byType(CaptureResult), findsNothing);
      expect(find.byType(BottomSheet), findsNothing);
      expect(app.store.pendingIds, isEmpty);
      expect(pendingLink(1), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'UX-605: on a spoken result, Conservar closes the sheet and one capture is pending under Capturas pendientes · 1',
    (tester) async {
      final app = await _App.open(tester);
      app.api.found = [_found('Comprar pan')];
      await app.speak(tester, 'Comprar pan');
      await tester.tap(resultButton(es.cancel));
      await tester.pumpAndSettle();
      expectKeepQuestion(tester);
      await tester.tap(find.widgetWithText(FilledButton, es.keep));
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsNothing);
      expect(app.store.pendingIds, hasLength(1));
      expect(pendingLink(1), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'UX-605: on a result, the system Back and a tap on the dimmed area above the sheet show the same question; dismissing it leaves the result open',
    (tester) async {
      final app = await _App.open(tester);
      app.api.found = [_found('Comprar pan')];
      await app.speak(tester, 'Comprar pan');
      final id = app.store.pendingIds.single;

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expectKeepQuestion(tester);
      // Dismissed: a tap outside the dialog.
      await tester.tapAt(const Offset(8, 8));
      await tester.pumpAndSettle();
      expect(dialog(), findsNothing);
      expect(find.byType(CaptureResult), findsOneWidget);

      final sheetTop = tester.getRect(find.byType(BottomSheet)).top;
      expect(sheetTop, greaterThan(40), reason: 'room above the sheet');
      await tester.tapAt(Offset(195, sheetTop / 2));
      await tester.pumpAndSettle();
      expectKeepQuestion(tester);
      await tester.tapAt(const Offset(8, 8));
      await tester.pumpAndSettle();
      expect(dialog(), findsNothing);
      expect(find.byType(CaptureResult), findsOneWidget);
      expect(titleText(tester), 'Comprar pan');
      expect(app.store.pendingIds, [id]);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'UX-605: while typing, Cancelar with words asks ¿Conservar el texto para más tarde?',
    (tester) async {
      await _App.open(tester);
      await tester.tap(find.text(es.addTask).hitTestable());
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip(es.captureTypeInstead));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('capture-words')),
        'Comprar pan',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, es.cancel));
      await tester.pumpAndSettle();
      expectKeepQuestion(tester, spoken: false);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'UX-605: while listening with words, Cancelar asks ¿Conservar lo que has dicho para más tarde?',
    (tester) async {
      final app = await _App.open(tester);
      await tester.tap(find.text(es.addTask).hitTestable());
      await tester.pumpAndSettle();
      app.speech.send('ready');
      app.speech.send('segment', text: 'Comprar pan');
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, es.cancel));
      await tester.pumpAndSettle();
      expectKeepQuestion(tester);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'UX-605: with every batch card removed, Back closes the sheet with no question and nothing is pending',
    (tester) async {
      final app = await _App.open(tester);
      final session = _spoken(app, 'Comprar pan', null);
      await app.openResult(
        tester,
        session.copyWith(
          drafts: [
            ...session.drafts,
            CaptureDraft(
              id: 'b',
              task: Task(title: 'Llamar a mamá', priority: 1),
            ),
          ],
        ),
      );
      expect(app.store.pendingIds, hasLength(1));
      // ✕ on the first card; the one left shows as a single result, removed
      // with Quitar under Más opciones.
      await tester.tap(find.byTooltip(es.removeCaptureItem('Comprar pan')));
      await tester.pumpAndSettle();
      // Past the `Quitada` message, which sits over the card.
      await tester.pump(const Duration(seconds: 11));
      await tester.pumpAndSettle();
      final options = find.byKey(const ValueKey('draft-options-b'));
      await tester.ensureVisible(options);
      await tester.pumpAndSettle();
      await tester.tap(options);
      await tester.pumpAndSettle();
      final remove = find.widgetWithText(TextButton, es.reviewRemove);
      await tester.ensureVisible(remove);
      await tester.pumpAndSettle();
      await tester.tap(remove);
      await tester.pumpAndSettle();
      expect(find.text(es.captureNothingToReview), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(dialog(), findsNothing);
      expect(find.byType(BottomSheet), findsNothing);
      expect(app.store.pendingIds, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'UX-605: Añadir tarea on a result still closes the sheet and lands, with no question',
    (tester) async {
      final app = await _App.open(tester);
      app.api.found = [_found('Comprar pan')];
      await app.speak(tester, 'Comprar pan');
      await tester.tap(find.byKey(const ValueKey('save-drafts')));
      await tester.pumpAndSettle();
      expect(dialog(), findsNothing);
      expect(find.byType(BottomSheet), findsNothing);
      expect(find.text(es.taskSavedInbox), findsOneWidget);
      expect(find.text(es.undo), findsOneWidget);
      expect(app.store.pendingIds, isEmpty);
      expect(
        app.container.read(taskProvider).requireValue.map((t) => t.title),
        contains('Comprar pan'),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'UX-612: removing a batch card says Quitada with Deshacer; Capturas pendientes lists a capture with three cards left as Tareas · 3 sin añadir',
    (tester) async {
      final app = await _App.open(tester);
      final session = _spoken(app, 'Comprar pan', null);
      await app.openResult(
        tester,
        session.copyWith(
          drafts: [
            ...session.drafts,
            for (final (i, title) in [
              'Llamar a mamá',
              'Pagar la luz',
              'Regar',
            ].indexed)
              CaptureDraft(
                id: 'more$i',
                task: Task(title: title, priority: 1),
              ),
          ],
        ),
      );
      await tester.tap(find.byTooltip(es.removeCaptureItem('Regar')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      final message = find.byType(SnackBar);
      expect(message, findsOneWidget);
      expect(es.reviewRemoved, 'Quitada');
      expect(
        find.descendant(of: message, matching: find.text(es.reviewRemoved)),
        findsOneWidget,
      );
      expect(
        find.descendant(of: message, matching: find.text(es.undo)),
        findsOneWidget,
      );
      await tester.pumpAndSettle();
      // Kept for later with three cards left.
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, es.keep));
      await tester.pumpAndSettle();
      expect(app.store.pendingIds, hasLength(1));
      unawaited(
        Navigator.of(
          tester.element(find.byType(Scaffold).first),
        ).pushNamed('/captures'),
      );
      await tester.pumpAndSettle();
      final summary = '${es.tasks} · ${es.captureDraftSummary(3)}';
      expect(summary, 'Tareas · 3 sin añadir');
      expect(find.text(summary), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}

Map<String, dynamic> _found(String title) => {
  'title': title,
  'due_date': null,
  'scheduled_date': null,
  'priority': 1,
  'notes': '',
  'questions': [],
};

/// A spoken capture of [title] on [day], already understood.
CaptureSession _spoken(_App app, String title, DateTime? day) => CaptureSession(
  id: 'stored',
  ownerKey: app.container.read(captureOwnerProvider),
  timezone: 'Europe/Madrid',
  capturedAt: DateTime.now().toUtc(),
  status: 'ready',
  source: 'speech',
  transcript: title,
  drafts: [
    CaptureDraft(
      id: 'a',
      task: Task(title: title, priority: 1, dueDate: day, hasTime: false),
    ),
  ],
);

/// The app with a 24-hour clock, on Calendar, with capture answered by [api]
/// and every capture kept in [store], as the phone's table does.
class _App {
  _App(this.container, this.store, this.api, this.speech);
  final ProviderContainer container;
  final _Captures store;
  final _Api api;
  final _Speech speech;

  static Future<_App> open(
    WidgetTester tester, {
    String language = 'es',
    Size size = const Size(390, 844),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final store = _Captures();
    final api = _Api();
    final speech = _Speech();
    final container = ProviderContainer(
      overrides: [
        invitationLinkProvider.overrideWith(
          (ref) => InvitationLinks(listen: false),
        ),
        hasProProvider.overrideWithValue(true),
        authProvider.overrideWith((ref) => SignedInFixtureAuth(api)),
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
        apiClientProvider.overrideWithValue(api),
        taskRepositoryProvider.overrideWithValue(MemoryTasks()),
        taskProvider.overrideWith((ref) => DesignTaskNotifier()),
        themeStoreProvider.overrideWithValue(MemoryThemeStore()),
        captureStoreProvider.overrideWithValue(store),
        nativeSpeechProvider.overrideWithValue(speech),
        captureRecorderFactoryProvider.overrideWithValue(SilentRecorder.new),
      ],
    );
    store.tasks = container;
    addTearDown(() {
      container.dispose();
      api.close();
    });
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const MyApp()),
    );
    await tester.pumpAndSettle();
    return _App(container, store, api, speech);
  }

  /// `Dictar una tarea`, the recognizer hears [words], then `Listo`.
  Future<void> speak(WidgetTester tester, String words) async {
    await tester.tap(find.text(es.addTask).hitTestable());
    await tester.pumpAndSettle();
    speech.send('ready');
    speech.send('segment', text: words);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, es.done));
    await tester.pumpAndSettle();
  }

  /// `Dictar una tarea`, `Escribir`, [words], then `Listo`.
  Future<void> type(WidgetTester tester, String words) async {
    await tester.tap(find.text(es.addTask).hitTestable());
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip(es.captureTypeInstead));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('capture-words')), words);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, es.done));
    await tester.pumpAndSettle();
  }

  /// Opens the capture sheet on [session]'s result, as resuming it does.
  Future<void> openResult(WidgetTester tester, CaptureSession session) async {
    store.sessions[session.id] = session;
    unawaited(
      showCaptureSheet(
        tester.element(find.byType(Scaffold).first),
        captureId: session.id,
        startListening: false,
      ),
    );
    await tester.pumpAndSettle();
  }
}

/// The assistant: returns [found] for every capture. While [hold] is set,
/// understanding waits for the test to complete it (or fail it).
class _Api extends OfflineApiClient {
  List<Map<String, dynamic>> found = [];
  Completer<void>? hold;
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
    if (!path.startsWith('ai/')) {
      throw ApiException(0, 'Offline. Retry when connected.');
    }
    final gate = hold;
    if (gate != null) await gate.future;
    return {'transcript': data?['text'] ?? '', 'tasks': found};
  }
}

/// Every capture in memory, by id; the pending list is every one not saved
/// or discarded, as the real table's query is.
class _Captures extends CaptureStore {
  _Captures() : super(TaskDatabase());
  final sessions = <String, CaptureSession>{};
  var _next = 0;

  /// While set, `Añadir…` stays saving until the test completes it.
  Completer<void>? holdSave;

  /// The app's task list: a save adds to it, as the real store's table does.
  ProviderContainer? tasks;

  @override
  Future<CaptureSession> saveReady(
    String id,
    String ownerKey,
    Set<String> draftIds,
  ) async {
    final gate = holdSave;
    if (gate == null) {
      final current = sessions[id]!;
      final list = tasks!.read(taskProvider).requireValue;
      // The ids the in-memory list gives them, in the order they are added.
      var next = list.fold<int>(0, (max, t) => t.id! > max ? t.id! : max);
      final drafts = [
        for (final draft in current.drafts)
          draftIds.contains(draft.id)
              ? draft.copyWith(savedTaskId: ++next)
              : draft,
      ];
      await tasks!.read(taskProvider.notifier).addTasks([
        for (final draft in current.drafts)
          if (draftIds.contains(draft.id)) draft.task,
      ]);
      return sessions[id] = current.copyWith(
        status: drafts.any((d) => d.pending) ? 'ready' : 'saved',
        drafts: drafts,
      );
    }
    await gate.future;
    throw StateError('Not saved in this test.');
  }

  List<String> get pendingIds => [
    for (final session in sessions.values)
      if (!session.terminal) session.id,
  ];

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
      id: 'capture-${_next++}',
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
    if (session != null) {
      sessions[id] = session.copyWith(status: 'discarded');
    }
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

  void send(String kind, {String? text}) =>
      _events.add(SpeechEvent(_run!, kind, text: text));
  @override
  Future<void> stop(int id) async {
    if (_run != null) send('ended');
  }

  @override
  Future<void> cancel(int id) async {}
}
