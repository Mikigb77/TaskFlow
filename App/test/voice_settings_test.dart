// P34 (U9, UX-115): the speech options live in Ajustes › Otros ajustes › Voz,
// capture listens in the language chosen there (the app's by default, never
// the phone's), and the privacy note shows in the sheet only once.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' show CheckedState;

import 'package:agenda/l10n/generated/app_localizations.dart';
import 'package:agenda/main.dart';
import 'package:agenda/providers/regional_provider.dart';
import 'package:agenda/screens/voice_settings_screen.dart';
import 'package:agenda/screens/voice_task_screen.dart';
import 'package:agenda/services/capture_store.dart';
import 'package:agenda/services/native_speech.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/capture_fixtures.dart';
import 'support/design_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final platform =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const timezone = MethodChannel('flutter_timezone');
  const timeoutChannel = MethodChannel('taskflow/accessibility');
  setUp(() {
    platform.setMockMethodCallHandler(timezone, (_) async => 'Europe/Madrid');
    platform.setMockMethodCallHandler(timeoutChannel, (_) async => 10000);
  });
  tearDown(() {
    platform.setMockMethodCallHandler(timezone, null);
    platform.setMockMethodCallHandler(timeoutChannel, null);
  });

  final es = lookupAppLocalizations(const Locale('es'));

  /// The app signed in on Calendar, its preferences kept in [store] and the
  /// recognizer played by [speech].
  Future<ProviderContainer> openApp(
    WidgetTester tester,
    _JsonRegionalStore store,
    _Speech speech, {
    Size size = const Size(390, 844),
    MemoryCaptures? captures,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final container = designContainer(
      regionalStore: store,
      overrides: [
        nativeSpeechProvider.overrideWithValue(speech),
        captureStoreProvider.overrideWithValue(captures ?? MemoryCaptures()),
        captureRecorderFactoryProvider.overrideWithValue(SilentRecorder.new),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const MyApp()),
    );
    await tester.pumpAndSettle();
    return container;
  }

  /// Ajustes › Otros ajustes › Voz, tapped through.
  Future<void> openVoice(WidgetTester tester, AppLocalizations l) async {
    tester.state<NavigatorState>(find.byType(Navigator)).pushNamed('/settings');
    await tester.pumpAndSettle();
    final other = find.text(l.otherSettings);
    await tester.scrollUntilVisible(
      other,
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();
    await tester.tap(other);
    await tester.pumpAndSettle();
    final voice = find.widgetWithText(ListTile, l.voiceSettings);
    await tester.scrollUntilVisible(
      voice,
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();
    await tester.tap(voice);
    await tester.pumpAndSettle();
    expect(find.byType(VoiceSettingsScreen), findsOneWidget);
  }

  Future<void> openCapture(WidgetTester tester) async {
    unawaited(
      showCaptureSheet(
        tester.element(find.byType(Scaffold).first),
        startListening: true,
      ),
    );
    await tester.pumpAndSettle();
  }

  bool checked(WidgetTester tester, Key key) {
    final data = tester.getSemantics(find.byKey(key)).getSemanticsData();
    return data.flagsCollection.isChecked == CheckedState.isTrue;
  }

  testWidgets(
    'U9: Ajustes › Otros ajustes › Voz shows Idioma de voz with Como la aplicación chosen on a fresh install, the two ways to turn speech into text, and the privacy note',
    (tester) async {
      final semantics = tester.ensureSemantics();
      expect(es.voiceSettings, 'Voz');
      expect(es.sameAsApp, 'Como la aplicación');
      final store = _JsonRegionalStore(
        const RegionalPreferences(language: 'es'),
      );
      await openApp(tester, store, _Speech());
      // The row in Otros ajustes names the speech language.
      tester
          .state<NavigatorState>(find.byType(Navigator))
          .pushNamed('/otherSettings');
      await tester.pumpAndSettle();
      final row = find.widgetWithText(ListTile, es.voiceSettings);
      expect(
        find.descendant(of: row, matching: find.text(es.sameAsApp)),
        findsOneWidget,
      );
      tester.state<NavigatorState>(find.byType(Navigator)).pop();
      await tester.pumpAndSettle();

      await openVoice(tester, es);
      final page = find.byType(VoiceSettingsScreen);
      expect(
        find.descendant(of: page, matching: find.text(es.speechLanguage)),
        findsOneWidget,
      );
      for (final (option, name) in [
        ('app', es.sameAsApp),
        ('en', 'English'),
        ('es', 'Español'),
        ('ca', 'Català'),
      ]) {
        final tile = find.byKey(ValueKey('speech-language-$option'));
        expect(tile, findsOneWidget, reason: option);
        expect(
          find.descendant(of: tile, matching: find.text(name)),
          findsOneWidget,
          reason: option,
        );
        expect(
          checked(tester, ValueKey('speech-language-$option')),
          option == 'app',
          reason: option,
        );
      }
      // The two ways; on-device is the default where it works.
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('speech-on-device')),
          matching: find.text(es.onDeviceTranscript),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('speech-online')),
          matching: find.text(es.onlineAudio),
        ),
        findsOneWidget,
      );
      expect(checked(tester, const ValueKey('speech-on-device')), isTrue);
      expect(checked(tester, const ValueKey('speech-online')), isFalse);
      expect(find.text(es.onDeviceUnavailable), findsNothing);
      final privacy = find.descendant(
        of: page,
        matching: find.text(es.capturePrivacy),
      );
      await tester.ensureVisible(privacy);
      await tester.pumpAndSettle();
      expect(privacy, findsOneWidget);
      semantics.dispose();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'U9: where on-device speech can’t be used for the language, Voz says so, offers set-up and Check again, and the online way is the one chosen',
    (tester) async {
      final semantics = tester.ensureSemantics();
      final store = _JsonRegionalStore(
        const RegionalPreferences(language: 'es'),
      );
      await openApp(tester, store, _Speech()..installed = false);
      await openVoice(tester, es);
      expect(find.text(es.onDeviceUnavailable), findsOneWidget);
      expect(find.text(es.setUpSpeech), findsOneWidget);
      expect(find.text(es.checkAgain), findsOneWidget);
      expect(checked(tester, const ValueKey('speech-online')), isTrue);
      expect(checked(tester, const ValueKey('speech-on-device')), isFalse);
      semantics.dispose();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'U9: Voz in Spanish at 2× text on a 320 dp screen fits without overflow',
    (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final store = _JsonRegionalStore(
        const RegionalPreferences(language: 'es'),
      );
      await openApp(
        tester,
        store,
        _Speech()..installed = false,
        size: const Size(320, 640),
      );
      await openVoice(tester, es);
      final privacy = find.text(es.capturePrivacy);
      await tester.scrollUntilVisible(
        privacy,
        200,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.pumpAndSettle();
      expect(privacy, findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'UX-115: with the app in Catalan and the phone in Spanish, capture starts the recognizer with ca-ES',
    (tester) async {
      tester.platformDispatcher.localesTestValue = const [Locale('es', 'ES')];
      addTearDown(tester.platformDispatcher.clearLocalesTestValue);
      final speech = _Speech();
      final store = _JsonRegionalStore(
        const RegionalPreferences(language: 'ca'),
      );
      await openApp(tester, store, speech);
      await openCapture(tester);
      expect(find.byType(VoiceTaskScreen), findsOneWidget);
      expect(speech.started, ['ca-ES']);
      expect(speech.checked, everyElement('ca-ES'));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'UX-115: English chosen in Voz is still chosen after a restart, and capture then listens in English',
    (tester) async {
      final semantics = tester.ensureSemantics();
      tester.platformDispatcher.localesTestValue = const [Locale('es', 'ES')];
      addTearDown(tester.platformDispatcher.clearLocalesTestValue);
      final store = _JsonRegionalStore(
        const RegionalPreferences(language: 'es'),
      );
      await openApp(tester, store, _Speech());
      await openVoice(tester, es);
      await tester.tap(find.byKey(const ValueKey('speech-language-en')));
      await tester.pumpAndSettle();
      expect(checked(tester, const ValueKey('speech-language-en')), isTrue);

      // Restart: a fresh app over what was stored.
      await tester.pumpWidget(const SizedBox());
      final speech = _Speech();
      await openApp(tester, store, speech);
      tester
          .state<NavigatorState>(find.byType(Navigator))
          .pushNamed('/otherSettings');
      await tester.pumpAndSettle();
      final row = find.widgetWithText(ListTile, es.voiceSettings);
      expect(
        find.descendant(of: row, matching: find.text('English')),
        findsOneWidget,
      );
      await tester.tap(row);
      await tester.pumpAndSettle();
      expect(checked(tester, const ValueKey('speech-language-en')), isTrue);
      expect(checked(tester, const ValueKey('speech-language-app')), isFalse);
      // Capture listens in English, though app and phone are Spanish.
      tester.state<NavigatorState>(find.byType(Navigator))
        ..pop()
        ..pop();
      await tester.pumpAndSettle();
      await openCapture(tester);
      expect(speech.started.single, startsWith('en-'));
      semantics.dispose();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'U9: the privacy line shows in the sheet on the first capture only, and stays away after a restart',
    (tester) async {
      final speech = _Speech();
      final store = _JsonRegionalStore(
        const RegionalPreferences(language: 'es'),
      );
      await openApp(tester, store, speech);
      Finder line() => find.descendant(
        of: find.byType(VoiceTaskScreen),
        matching: find.text(es.capturePrivacyLine),
      );

      await openCapture(tester);
      expect(speech.started, hasLength(1));
      speech.emit('ready');
      await tester.pumpAndSettle();
      expect(line(), findsOneWidget);
      expect(find.byKey(const ValueKey('capture-privacy')), findsOneWidget);
      // Nothing said: Back closes the sheet.
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(VoiceTaskScreen), findsNothing);

      await openCapture(tester);
      expect(speech.started, hasLength(2));
      speech.emit('ready');
      await tester.pumpAndSettle();
      expect(find.byType(VoiceTaskScreen), findsOneWidget);
      expect(line(), findsNothing);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      // Restart.
      await tester.pumpWidget(const SizedBox());
      final again = _Speech();
      await openApp(tester, store, again);
      await openCapture(tester);
      expect(again.started, hasLength(1));
      again.emit('ready');
      await tester.pumpAndSettle();
      expect(find.byType(VoiceTaskScreen), findsOneWidget);
      expect(line(), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  // ---- P81 (U9, UX-491, UX-492): one short privacy line; Voz in plain words ----

  final ca = lookupAppLocalizations(const Locale('ca'));

  /// Whether [rect] lies wholly inside a [width]×[height] screen.
  bool onScreen(Rect rect, double width, double height) =>
      rect.left >= -0.5 &&
      rect.top >= -0.5 &&
      rect.right <= width + 0.5 &&
      rect.bottom <= height + 0.5;

  /// Every piece of text shown under [of], as plain strings.
  List<String> textsUnder(WidgetTester tester, Finder of) => [
    for (final widget in tester.widgetList<RichText>(
      find.descendant(of: of, matching: find.byType(RichText)),
    ))
      widget.text.toPlainText(),
  ];

  testWidgets(
    'UX-491: on the first capture, in Spanish at 2× text on 360×740 while listening, the sheet shows the short privacy line and not the Voz paragraph; the second capture shows neither',
    (tester) async {
      expect(
        es.capturePrivacyLine,
        'Tus palabras van por internet. Más en Ajustes.',
      );
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final speech = _Speech();
      await openApp(
        tester,
        _JsonRegionalStore(const RegionalPreferences(language: 'es')),
        speech,
        size: const Size(360, 740),
      );
      await openCapture(tester);
      speech.emit('ready');
      await tester.pumpAndSettle();
      final sheet = find.byType(VoiceTaskScreen);
      final note = find.byKey(const ValueKey('capture-privacy'));
      expect(note, findsOneWidget);
      expect(
        find.descendant(of: note, matching: find.text(es.capturePrivacyLine)),
        findsOneWidget,
      );
      expect(
        find.descendant(of: sheet, matching: find.text(es.capturePrivacy)),
        findsNothing,
      );
      expect(find.text(es.capturePrivacy), findsNothing);
      expect(onScreen(tester.getRect(note), 360, 740), isTrue);
      // Nothing said: Back closes the sheet.
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(sheet, findsNothing);

      await openCapture(tester);
      speech.emit('ready');
      await tester.pumpAndSettle();
      expect(sheet, findsOneWidget);
      expect(note, findsNothing);
      expect(find.text(es.capturePrivacyLine), findsNothing);
      expect(find.text(es.capturePrivacy), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'UX-491: in Spanish at 2× text on 360×740, with the privacy line showing and the words filling the area, the newest words stay in view, the line is at most three whole lines and nothing overflows',
    (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final speech = _Speech();
      await openApp(
        tester,
        _JsonRegionalStore(const RegionalPreferences(language: 'es')),
        speech,
        size: const Size(360, 740),
      );
      await openCapture(tester);
      speech.emit('ready');
      await tester.pump();
      const newest = 'y reservar mesa para el sábado por la noche';
      speech.emit(
        'segment',
        text:
            'Comprar pan y leche en la tienda de la esquina, llamar al médico '
            'el viernes a las cinco, recoger a los niños del colegio, pagar '
            'la factura de la luz antes del lunes, regar las plantas, '
            'devolver el libro a la biblioteca, escribir a la abuela $newest',
      );
      await tester.pump();
      for (var second = 0; second < 3; second++) {
        await tester.pump(const Duration(seconds: 1));
      }
      expect(tester.takeException(), isNull);

      final note = find.byKey(const ValueKey('capture-privacy'));
      expect(note, findsOneWidget);
      final heard = find.byKey(const ValueKey('capture-heard'));
      expect(heard, findsOneWidget);
      expect(
        find.descendant(
          of: heard,
          matching: find.textContaining(newest, findRichText: true),
        ),
        findsOneWidget,
      );
      final viewport = tester.getRect(
        find.ancestor(of: heard, matching: find.byType(Scrollable)).first,
      );
      // The words fill more than the area: the newest (last) line is the one
      // in view, inside the area, which is on screen.
      expect(tester.getRect(heard).height, greaterThan(viewport.height));
      expect(
        tester.getRect(heard).bottom,
        inInclusiveRange(viewport.top, viewport.bottom + 0.5),
      );
      expect(onScreen(viewport, 360, 740), isTrue);
      // The line sits under the words, whole and on screen, and the words
      // keep most of the room.
      final line = tester.getRect(note);
      expect(line.top, greaterThanOrEqualTo(viewport.bottom - 0.5));
      expect(onScreen(line, 360, 740), isTrue);
      expect(viewport.height, greaterThan(line.height));
      // At most three lines of its own text at this size.
      final paragraph = find.descendant(
        of: note,
        matching: find.byType(RichText),
      );
      final rich = tester.widget<RichText>(paragraph);
      final oneLine = TextPainter(
        text: TextSpan(text: 'A', style: rich.text.style),
        textScaler: rich.textScaler,
        textDirection: TextDirection.ltr,
      )..layout();
      expect(
        tester.getSize(paragraph).height,
        lessThanOrEqualTo(oneLine.height * 3 + 0.5),
      );
      oneLine.dispose();
      expect(
        textsUnder(tester, find.byType(VoiceTaskScreen)),
        isNot(contains(es.capturePrivacy)),
      );
      // Close without keeping anything.
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      final discard = find.widgetWithText(TextButton, es.discard);
      if (discard.evaluate().isNotEmpty) {
        await tester.tap(discard);
        await tester.pumpAndSettle();
      }
    },
  );

  testWidgets(
    'UX-492: Voz in Spanish shows Cómo se pasa la voz a texto above En el teléfono, mientras hablas and En línea, al terminar, and still shows the full privacy paragraph',
    (tester) async {
      expect(es.speechMethod, 'Cómo se pasa la voz a texto');
      expect(es.onDeviceTranscript, 'En el teléfono, mientras hablas');
      expect(es.onlineAudio, 'En línea, al terminar');
      await openApp(
        tester,
        _JsonRegionalStore(const RegionalPreferences(language: 'es')),
        _Speech(),
        size: const Size(390, 1400),
      );
      await openVoice(tester, es);
      final page = find.byType(VoiceSettingsScreen);
      final heading = find.descendant(
        of: page,
        matching: find.text(es.speechMethod),
      );
      expect(heading, findsOneWidget);
      final onDevice = find.byKey(const ValueKey('speech-on-device'));
      final online = find.byKey(const ValueKey('speech-online'));
      expect(
        find.descendant(
          of: onDevice,
          matching: find.text(es.onDeviceTranscript),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(of: online, matching: find.text(es.onlineAudio)),
        findsOneWidget,
      );
      // After the language options, right above the two ways.
      final lastLanguage = find.byKey(const ValueKey('speech-language-ca'));
      expect(
        tester.getRect(heading).top,
        greaterThanOrEqualTo(tester.getRect(lastLanguage).bottom),
      );
      expect(
        tester.getRect(heading).bottom,
        lessThanOrEqualTo(tester.getRect(onDevice).top),
      );
      expect(
        tester.getRect(onDevice).bottom,
        lessThanOrEqualTo(tester.getRect(online).top + 0.5),
      );
      // Styled like Idioma de voz.
      final style = tester.widget<Text>(heading).style;
      final languageHeading = tester.widget<Text>(
        find.descendant(of: page, matching: find.text(es.speechLanguage)),
      );
      expect(style, languageHeading.style);
      expect(
        find.descendant(of: page, matching: find.text(es.capturePrivacy)),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'UX-492: on Voz in Spanish, where on-device speech can’t do the language, the message says TaskFlow does it online; Configurar la transcripción local then shows Sigue los pasos de Android…; no text tells the user to record or type',
    (tester) async {
      expect(
        es.onDeviceUnavailable,
        'Este teléfono no puede con este idioma por sí solo, así que TaskFlow lo hace en línea.',
      );
      expect(
        es.voiceSetupRequested,
        'Sigue los pasos de Android y luego pulsa Comprobar de nuevo.',
      );
      expect(es.setUpSpeech, 'Configurar la transcripción local');
      // The banner names the button by its real label.
      expect(es.voiceSetupRequested, contains(es.checkAgain));
      expect(ca.voiceSetupRequested, contains(ca.checkAgain));
      await openApp(
        tester,
        _JsonRegionalStore(const RegionalPreferences(language: 'es')),
        _Speech()..installed = false,
        size: const Size(390, 1600),
      );
      await openVoice(tester, es);
      final page = find.byType(VoiceSettingsScreen);
      expect(
        find.descendant(of: page, matching: find.text(es.onDeviceUnavailable)),
        findsOneWidget,
      );
      final setUp = find.descendant(
        of: page,
        matching: find.text(es.setUpSpeech),
      );
      await tester.ensureVisible(setUp);
      await tester.pumpAndSettle();
      await tester.tap(setUp);
      await tester.pumpAndSettle();
      expect(
        find.descendant(of: page, matching: find.text(es.voiceSetupRequested)),
        findsOneWidget,
      );
      expect(find.text(es.captureSetupRequested), findsNothing);
      final texts = textsUnder(tester, page);
      expect(texts, isNotEmpty);
      for (final text in texts) {
        for (final word in ['escribe', 'Graba', 'escribiendo']) {
          expect(text, isNot(contains(word)), reason: text);
        }
      }
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'UX-492: Voz in Catalan at 2× text on 320×640 fits the heading and both options without overflow',
    (tester) async {
      expect(ca.speechMethod, 'Com es passa la veu a text');
      expect(ca.onDeviceTranscript, 'Al telèfon, mentre parles');
      expect(ca.onlineAudio, 'En línia, en acabar');
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await openApp(
        tester,
        _JsonRegionalStore(const RegionalPreferences(language: 'ca')),
        _Speech()..installed = false,
        size: const Size(320, 640),
      );
      await openVoice(tester, ca);
      final page = find.byType(VoiceSettingsScreen);
      for (final text in [
        ca.speechMethod,
        ca.onDeviceTranscript,
        ca.onlineAudio,
        ca.onDeviceUnavailable,
      ]) {
        final target = find.descendant(of: page, matching: find.text(text));
        await tester.scrollUntilVisible(
          target,
          100,
          scrollable: find
              .descendant(of: page, matching: find.byType(Scrollable))
              .first,
        );
        await tester.pumpAndSettle();
        expect(target, findsOneWidget, reason: text);
        final rect = tester.getRect(target);
        expect(rect.left, greaterThanOrEqualTo(0), reason: text);
        expect(rect.right, lessThanOrEqualTo(320.5), reason: text);
        final paragraph = tester.renderObject<RenderParagraph>(
          find.descendant(of: target, matching: find.byType(RichText)).first,
        );
        expect(paragraph.didExceedMaxLines, isFalse, reason: text);
      }
      expect(tester.takeException(), isNull);
    },
  );

  test(
    'UX-491/UX-492: capturePrivacy is used only by the Voz screen; captureSetupRequested is still used by the capture messages',
    () {
      final users = <String>[];
      final setup = <String>[];
      for (final file in Directory('lib').listSync(recursive: true)) {
        if (file is! File ||
            !file.path.endsWith('.dart') ||
            file.path.replaceAll('\\', '/').contains('l10n/generated/')) {
          continue;
        }
        final source = file.readAsStringSync();
        final path = file.path.replaceAll('\\', '/');
        if (RegExp(r'\.capturePrivacy\b').hasMatch(source)) users.add(path);
        if (RegExp(r'\.captureSetupRequested\b').hasMatch(source)) {
          setup.add(path);
        }
      }
      expect(users, ['lib/screens/voice_settings_screen.dart']);
      expect(setup, contains('lib/l10n/capture_messages.dart'));
    },
  );

  // ---- P87 (UX-491, UX-492): a privacy line that fits; no 'type' on Voz ----

  /// Voz with on-device speech lacking the language; taps the set-up button.
  Future<Finder> trySetUp(
    WidgetTester tester,
    AppLocalizations l,
    String language,
    _Speech speech, {
    required Size size,
  }) async {
    await openApp(
      tester,
      _JsonRegionalStore(RegionalPreferences(language: language)),
      speech..installed = false,
      size: size,
    );
    await openVoice(tester, l);
    final page = find.byType(VoiceSettingsScreen);
    final setUp = find.descendant(of: page, matching: find.text(l.setUpSpeech));
    await tester.scrollUntilVisible(
      setUp,
      100,
      scrollable: find
          .descendant(of: page, matching: find.byType(Scrollable))
          .first,
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(setUp);
    await tester.pumpAndSettle();
    await tester.tap(setUp);
    await tester.pumpAndSettle();
    return page;
  }

  /// The set-up failure message, and nothing on Voz telling the user to
  /// record, type or use saved audio.
  void expectVoiceSetupUnavailable(WidgetTester tester, Finder page) {
    expect(
      find.descendant(of: page, matching: find.text(es.voiceSetupUnavailable)),
      findsOneWidget,
    );
    expect(find.text(es.voiceSetupRequested), findsNothing);
    expect(find.text(es.captureSetupUnavailable), findsNothing);
    final texts = textsUnder(tester, page);
    expect(texts, contains(es.voiceSetupUnavailable));
    for (final text in texts) {
      for (final word in ['escribe', 'Graba', 'escribiendo']) {
        expect(text, isNot(contains(word)), reason: text);
      }
      // The full privacy paragraph (kept on Voz on purpose by P87) describes
      // how saved audio is transcribed; nothing else may mention it.
      if (text != es.capturePrivacy) {
        expect(text, isNot(contains('audio guardado')), reason: text);
      }
    }
    expect(tester.takeException(), isNull);
  }

  testWidgets(
    'UX-492: on Voz in Spanish, when Android’s set-up can’t open (prepareLanguage false), Configurar la transcripción local shows Este teléfono no puede configurarlo, así que TaskFlow lo hace en línea.; nothing tells the user to record or type',
    (tester) async {
      expect(
        es.voiceSetupUnavailable,
        'Este teléfono no puede configurarlo, así que TaskFlow lo hace en línea.',
      );
      final page = await trySetUp(
        tester,
        es,
        'es',
        _Speech()..prepares = false,
        size: const Size(390, 1600),
      );
      expectVoiceSetupUnavailable(tester, page);
    },
  );

  testWidgets(
    'UX-492: on Voz in Spanish, when Android’s set-up throws, Configurar la transcripción local shows the same online message',
    (tester) async {
      final page = await trySetUp(
        tester,
        es,
        'es',
        _Speech()..prepareError = PlatformException(code: 'unavailable'),
        size: const Size(390, 1600),
      );
      expectVoiceSetupUnavailable(tester, page);
    },
  );

  testWidgets(
    'UX-492: on Voz in Spanish, when Android’s set-up opens, the banner still reads Sigue los pasos de Android y luego pulsa Comprobar de nuevo.',
    (tester) async {
      final page = await trySetUp(
        tester,
        es,
        'es',
        _Speech()..prepares = true,
        size: const Size(390, 1600),
      );
      expect(
        es.voiceSetupRequested,
        'Sigue los pasos de Android y luego pulsa Comprobar de nuevo.',
      );
      expect(
        find.descendant(of: page, matching: find.text(es.voiceSetupRequested)),
        findsOneWidget,
      );
      expect(find.text(es.voiceSetupUnavailable), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'UX-492: Voz in Catalan at 2× text on 320×640, after a failed set-up, shows Aquest telèfon no ho pot configurar, així que TaskFlow ho fa en línia. without overflow',
    (tester) async {
      expect(
        ca.voiceSetupUnavailable,
        'Aquest telèfon no ho pot configurar, així que TaskFlow ho fa en línia.',
      );
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final page = await trySetUp(
        tester,
        ca,
        'ca',
        _Speech()..prepares = false,
        size: const Size(320, 640),
      );
      final message = find.descendant(
        of: page,
        matching: find.text(ca.voiceSetupUnavailable),
      );
      await tester.scrollUntilVisible(
        message,
        100,
        scrollable: find
            .descendant(of: page, matching: find.byType(Scrollable))
            .first,
      );
      await tester.pumpAndSettle();
      expect(message, findsOneWidget);
      expect(find.text(ca.captureSetupUnavailable), findsNothing);
      expect(onScreen(tester.getRect(message), 320, 640), isTrue);
      final paragraph = tester.renderObject<RenderParagraph>(
        find.descendant(of: message, matching: find.byType(RichText)).first,
      );
      expect(paragraph.didExceedMaxLines, isFalse);
      for (final text in textsUnder(tester, page)) {
        if (text == ca.capturePrivacy) continue;
        for (final word in ['escriu', 'Grava', 'àudio desat']) {
          expect(text, isNot(contains(word)), reason: text);
        }
      }
      expect(tester.takeException(), isNull);
    },
  );

  test(
    'UX-491/UX-492: captureSetupUnavailable is used only by the capture messages, voiceSetupUnavailable only by Voz, capturePrivacy only by Voz',
    () {
      final uses = <String, List<String>>{
        'captureSetupUnavailable': [],
        'voiceSetupUnavailable': [],
        'capturePrivacy': [],
      };
      for (final file in Directory('lib').listSync(recursive: true)) {
        final path = file.path.replaceAll('\\', '/');
        if (file is! File ||
            !path.endsWith('.dart') ||
            path.contains('l10n/generated/')) {
          continue;
        }
        final source = file.readAsStringSync();
        for (final key in uses.keys) {
          if (RegExp('\\.$key\\b').hasMatch(source)) uses[key]!.add(path);
        }
      }
      expect(uses['captureSetupUnavailable'], [
        'lib/l10n/capture_messages.dart',
      ]);
      expect(uses['voiceSetupUnavailable'], [
        'lib/screens/voice_settings_screen.dart',
      ]);
      expect(uses['capturePrivacy'], [
        'lib/screens/voice_settings_screen.dart',
      ]);
    },
  );

  // ---- P82 (UX-493): spoken captures keep the Voz language ----

  testWidgets(
    'UX-493: with the app in Catalan, a spoken capture is kept with the speech language ca-ES; a typed one with none',
    (tester) async {
      final captures = MemoryCaptures();
      final speech = _Speech();
      final store = _JsonRegionalStore(
        const RegionalPreferences(language: 'ca'),
      );
      await openApp(tester, store, speech, captures: captures);
      await openCapture(tester);
      expect(speech.started, ['ca-ES']);
      speech.emit('ready');
      await tester.pump();
      speech.emit('segment', text: 'Comprar pa demà al matí');
      await tester.pumpAndSettle();
      expect(captures.current, isNotNull);
      expect(captures.current!.source, 'speech');
      expect(captures.current!.language, 'ca-ES');

      // A fresh app; this time the words are typed.
      await tester.pumpWidget(const SizedBox());
      final typedCaptures = MemoryCaptures();
      await openApp(tester, store, _Speech(), captures: typedCaptures);
      unawaited(
        showCaptureSheet(
          tester.element(find.byType(Scaffold).first),
          startListening: false,
        ),
      );
      await tester.pumpAndSettle();
      final keyboard = find.byIcon(Icons.keyboard_outlined);
      if (keyboard.evaluate().isNotEmpty) {
        await tester.tap(keyboard);
        await tester.pumpAndSettle();
      }
      await tester.enterText(
        find.byKey(const ValueKey('capture-words')),
        'Comprar pa demà',
      );
      await tester.pumpAndSettle();
      expect(typedCaptures.current, isNotNull);
      expect(typedCaptures.current!.source, 'typed');
      expect(typedCaptures.current!.language, isNull);
      expect(tester.takeException(), isNull);
    },
  );

  test(
    'U9: the hold-to-talk, Task/Note, raw-language help and guest-trial strings are gone from the catalogs',
    () {
      for (final language in ['en', 'es', 'ca']) {
        final catalog =
            jsonDecode(File('lib/l10n/app_$language.arb').readAsStringSync())
                as Map<String, dynamic>;
        for (final key in [
          'holdTalk',
          'holdTalkHelp',
          'nativeSpeechHelp',
          'returnCaptureHelp',
          'guestTrialHelp',
          'speechOptions',
        ]) {
          expect(catalog.containsKey(key), isFalse, reason: '$language $key');
        }
      }
    },
  );

  // Last in the file: the real fonts stay loaded for the rest of the run, and
  // the tests above were written against the test font.
  group('UX-491: the privacy line with the app’s fonts', () {
    setUpAll(() async {
      await (FontLoader(
        'Manrope',
      )..addFont(rootBundle.load('assets/fonts/Manrope.ttf'))).load();
      await (FontLoader(
        'MaterialIcons',
      )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    });

    /// The first capture, listening, at 2× text on 360×740 in [language].
    Future<RenderParagraph> privacyLine(
      WidgetTester tester,
      AppLocalizations l,
      String language,
    ) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final speech = _Speech();
      await openApp(
        tester,
        _JsonRegionalStore(RegionalPreferences(language: language)),
        speech,
        size: const Size(360, 740),
      );
      await openCapture(tester);
      speech.emit('ready');
      await tester.pumpAndSettle();
      final note = find.byKey(const ValueKey('capture-privacy'));
      expect(note, findsOneWidget);
      final text = find.descendant(
        of: note,
        matching: find.text(l.capturePrivacyLine),
      );
      expect(text, findsOneWidget);
      expect(onScreen(tester.getRect(note), 360, 740), isTrue);
      expect(tester.takeException(), isNull);
      return tester.renderObject<RenderParagraph>(
        find.descendant(of: note, matching: find.byType(RichText)),
      );
    }

    testWidgets(
      'UX-491: on the first capture in Spanish at 2× text on 360×740 the privacy line reads Tus palabras van por internet. Más en Ajustes. and is laid out whole',
      (tester) async {
        expect(
          es.capturePrivacyLine,
          'Tus palabras van por internet. Más en Ajustes.',
        );
        final paragraph = await privacyLine(tester, es, 'es');
        expect(paragraph.text.toPlainText(), es.capturePrivacyLine);
        expect(paragraph.didExceedMaxLines, isFalse);
        // The line's pointer to the details names Settings as the app does.
        expect(es.capturePrivacyLine, endsWith('${es.settings}.'));
      },
    );

    testWidgets(
      'UX-491: on the first capture in Catalan at 2× text on 360×740 the privacy line reads Les paraules van per internet. Més a Configuració. and is laid out whole',
      (tester) async {
        expect(
          ca.capturePrivacyLine,
          'Les paraules van per internet. Més a Configuració.',
        );
        final paragraph = await privacyLine(tester, ca, 'ca');
        expect(paragraph.text.toPlainText(), ca.capturePrivacyLine);
        expect(paragraph.didExceedMaxLines, isFalse);
        expect(ca.capturePrivacyLine, endsWith('${ca.settings}.'));
      },
    );
  });
}

/// Preferences written as JSON and read back, as the phone's store does
/// across a restart.
class _JsonRegionalStore extends MemoryRegionalStore {
  _JsonRegionalStore(super.value) : _json = jsonEncode(value.toJson());
  String _json;
  @override
  Future<RegionalPreferences> read() async => value =
      RegionalPreferences.fromJson(jsonDecode(_json) as Map<String, dynamic>);
  @override
  Future<void> write(RegionalPreferences value) async {
    _json = jsonEncode(value.toJson());
    this.value = value;
  }
}

/// An on-device recognizer that records the language of each check and
/// each listening run.
class _Speech extends NativeSpeech {
  final _events = StreamController<SpeechEvent>.broadcast(sync: true);
  bool installed = true;

  /// What `prepareLanguage` returns: whether Android's set-up opened.
  bool prepares = true;

  /// When set, `prepareLanguage` throws it instead of answering.
  Object? prepareError;
  int? _run;

  /// The language of each capability check.
  final checked = <String?>[];

  /// The language each listening run started with.
  final started = <String>[];
  @override
  Future<SpeechCapability> capability({String? language}) async {
    checked.add(language);
    return SpeechCapability(
      onDevice: true,
      language: language ?? '',
      languageInstalled: installed,
    );
  }

  @override
  Stream<SpeechEvent> get events => _events.stream;
  @override
  Future<SpeechPermission> permission() async => SpeechPermission.granted;
  @override
  Future<bool> prepareLanguage(String language) async {
    final error = prepareError;
    if (error != null) throw error;
    return prepares;
  }

  @override
  Future<void> start(
    int id,
    String language, {
    List<String> hints = const [],
  }) async {
    _run = id;
    started.add(language);
  }

  void emit(String kind, {String? text}) =>
      _events.add(SpeechEvent(_run!, kind, text: text));
  @override
  Future<void> stop(int id) async => emit('ended');
  @override
  Future<void> cancel(int id) async {}
}
