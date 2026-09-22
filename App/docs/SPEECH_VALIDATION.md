**Native speech capture**

Android uses `SpeechRecognizer.createOnDeviceSpeechRecognizer` only after checking service availability. On Android 13+, the bridge also queries whether the selected language is installed. A missing model exposes saved-audio/typed capture and a user-triggered Android model setup request. Other platforms keep the existing audio/typed path. No native bridge silently falls back to a remote recognizer.

Partial and final recognized words are serialized into the existing account-scoped capture store. A newer partial replaces the current utterance; speaking again appends a new utterance. Events from old sessions are ignored. Activity interruption stops listening. Automatic service endpointing leaves editable text without sending it; manual Stop/Review sends text for online task extraction. The optional hold gesture coexists with tap controls. Neither mode auto-saves tasks. Live-transcript mode retains words, not audio; speech before the first recognizer result cannot be recovered after abrupt process termination.

The recognizer's own endpointing is retained, rather than imposing a short silence timeout. A 59-second application limit stops and retains input. Explicit on-device recognition can work offline when its model is installed; structured AI extraction still needs the backend. Network errors retain the capture and its original reference time.

B23 adds an explicit Note type. Typed and on-device-recognized note text is prepared locally without task extraction. Saved-audio notes still need online transcription. The missing emulator speech-model and real-speech evidence described below remains unchanged.

References: [Android SpeechRecognizer](https://developer.android.com/reference/android/speech/SpeechRecognizer), [recognizer intent and silence guidance](https://developer.android.com/reference/android/speech/RecognizerIntent), [installed language support](https://developer.android.com/reference/android/speech/RecognitionSupport).

**Evidence, 22 September 2026**

- Android debug build succeeds with the native Kotlin bridge.
- Four dedicated Flutter tests cover unavailable bridge/language, partial replacement, stale session events, interruption, reopening, preserved capture time, offline extraction failure, final endpoint retention, multiple utterances, and microphone permission denial with working typing. The full 72-test Flutter suite passes.
- `native_speech_flow_test.dart` queried the actual Android 36.1 emulator: the on-device service exists, but `en-US` and `es-ES` were both reported as not installed. It then used explicitly synthetic recognizer events to exercise the real Android SQLite store and UI, including interruption, route exit/resume and owner isolation. The integration passes; its fixture captures are discarded afterward. Screenshots were inspected. This is not a speech-accuracy test.
- Logs: ignored `App/artifacts/native-speech-tests.log`, `speech-all-tests.log`, `speech-analyze.log`, `speech-android-build.log`, and `speech-android-integration.log`.

**Remaining device evaluation**

Install the desired language through the visible speech setup action, or use a physical target device with its on-device model available. Test English and Spanish short utterances, long pauses, corrections, multiple commitments, noisy input, microphone denial/revocation, activity interruption, and airplane-mode retention. Measure time to first partial, service endpoint timing and stop-to-review separately. Repeat on physical target devices before advertising offline speech or a latency/accuracy figure. Apple native speech is not implemented or validated; its audio path remains available.

Run the Android test with `flutter drive --keep-app-running --no-pub --driver=test_driver/appearance_test.dart --target=integration_test/native_speech_flow_test.dart -d emulator-5554`. Keep the flag: the default driver teardown uninstalls the app. Restore the ordinary main APK using `adb install -r` after test builds.
