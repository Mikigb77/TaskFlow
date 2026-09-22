// Explicit, bounded model-setup probe. It never starts the microphone, reads
// captures, or calls TaskFlow's AI service. Model installation belongs to Android.
import 'package:agenda/services/native_speech.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

const _requestSetup = bool.fromEnvironment('REQUEST_SPEECH_MODELS');
const _requireModels = bool.fromEnvironment('REQUIRE_SPEECH_MODELS');

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('real Android speech model availability', (tester) async {
    await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: Center(child: Text('Checking speech models')))));
    final speech = NativeSpeech();
    for (final language in ['en-US', 'es-ES']) {
      var capability = await _read(speech, language);
      debugPrint(
          'SPEECH_MODEL_INITIAL: $language service=${capability.onDevice} installed=${capability.languageInstalled}');
      expect(capability.language, language);
      if (_requestSetup &&
          capability.onDevice &&
          capability.languageInstalled == false) {
        final requested = await speech.prepareLanguage(language);
        debugPrint('SPEECH_MODEL_REQUEST: $language requested=$requested');
        if (requested) {
          // A request is not installation evidence. Poll the real support API.
          for (var attempt = 0; attempt < 12; attempt++) {
            await tester.pump(const Duration(seconds: 5));
            capability = await _read(speech, language);
            if (capability.languageInstalled == true) break;
          }
        }
      }
      debugPrint(
          'SPEECH_MODEL_FINAL: $language service=${capability.onDevice} installed=${capability.languageInstalled}');
      if (_requireModels) {
        expect(capability.languageInstalled, isTrue,
            reason: '$language must be installed before recognition testing.');
      }
    }
    // This test checks the probe's execution, not a positive model/accuracy gate.
    expect(tester.takeException(), isNull);
  });
}

Future<SpeechCapability> _read(NativeSpeech speech, String language) async {
  // Bypass the production wrapper's graceful fallback: a missing bridge must
  // fail this native probe, not look like a verified unsupported device.
  final result = await speech.channel.invokeMapMethod<String, dynamic>(
      'capability', {'language': language}).timeout(const Duration(seconds: 5));
  expect(result?['language'], language);
  expect(result?['onDevice'], isA<bool>());
  expect(result?['languageInstalled'], anyOf(isNull, isA<bool>()));
  return SpeechCapability(
      onDevice: result!['onDevice'] == true,
      language: result['language'] as String,
      languageInstalled: result['languageInstalled'] as bool?);
}
