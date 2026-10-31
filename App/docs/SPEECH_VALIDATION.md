**Native speech capture**

Android uses `SpeechRecognizer.createOnDeviceSpeechRecognizer` only after checking service availability. On Android 13+, the bridge also queries whether the selected language is installed. A missing model exposes saved-audio/typed capture and a user-triggered Android model setup request. Other platforms keep the existing audio/typed path. No native bridge silently falls back to a remote recognizer.

Partial and final recognized words are serialized into the existing account-scoped capture store. A newer partial replaces the current utterance; speaking again appends a new utterance. Events from old sessions are ignored. Activity interruption stops listening. Automatic service endpointing leaves editable text without sending it; manual Stop/Review sends text for online task extraction. The optional hold gesture coexists with tap controls. Neither mode auto-saves tasks. Live-transcript mode retains words, not audio; speech before the first recognizer result cannot be recovered after abrupt process termination.

The recognizer's own endpointing is retained, rather than imposing a short silence timeout. A 59-second application limit stops and retains input. Explicit on-device recognition can work offline when its model is installed; structured AI extraction still needs the backend. Network errors retain the capture and its original reference time.

B23 adds an explicit Note type. Typed and on-device-recognized note text is prepared locally without task extraction. Saved-audio notes still need online transcription. Both emulator language models are now installed; synthetic model evidence and the remaining microphone gap are described below.

References: [Android SpeechRecognizer](https://developer.android.com/reference/android/speech/SpeechRecognizer), [recognizer intent and silence guidance](https://developer.android.com/reference/android/speech/RecognizerIntent), [installed language support](https://developer.android.com/reference/android/speech/RecognitionSupport).

**Evidence, 22 September 2026**

- Android debug build succeeds with the native Kotlin bridge.
- Four dedicated Flutter tests cover unavailable bridge/language, partial replacement, stale session events, interruption, reopening, preserved capture time, offline extraction failure, final endpoint retention, multiple utterances, and microphone permission denial with working typing. The prototype checkpoint passed 72 Flutter tests; the current cross-feature baseline is 184 passing tests.
- The initial `native_speech_flow_test.dart` queried the actual Android 36.1 emulator: the on-device service existed, but `en-US` and `es-ES` were both reported as not installed. It then used explicitly synthetic recognizer events to exercise the real Android SQLite store and UI, including interruption, route exit/resume and owner isolation. The integration passed; its fixture captures were discarded afterward. Screenshots were inspected. This is not a speech-accuracy test.
- Logs: ignored `App/artifacts/native-speech-tests.log`, `speech-all-tests.log`, `speech-analyze.log`, `speech-android-build.log`, and `speech-android-integration.log`.

**Installed models and actual synthetic recognition, later on 22 September 2026**

`speech_model_probe_test.dart` calls TaskFlow's actual native capability bridge directly. The Android setup requests displayed system download confirmations for English (US) and Spanish (Spain), which were accepted on the test emulator. The subsequent run with both `REQUEST_SPEECH_MODELS=true` and `REQUIRE_SPEECH_MODELS=true` passed: service available and language installed were true for both `en-US` and `es-ES`. Request acceptance alone was not treated as success. Logs: ignored `App/artifacts/speech-model-probe.log` and `speech-model-required.log`.

The separate debug APK in `test_support/android_speech_probe` then supplied synthetic PCM through Android's `EXTRA_AUDIO_SOURCE`. It never opened TaskFlow's database or called its backend. Windows' offline Zira/Helena voices generated clean, noisy (12 dB SNR), paused (extra 1.5 seconds) and corrected phrases in each language. Reference text, PCM hashes and all callbacks are retained. Emulator audio was disabled and host microphone input was off. The offline runs additionally disabled Wi-Fi/mobile data and verified `Active default network: none`.

Results must distinguish the input modes:

- The first ordinary file-input run had one native `ERROR_SERVER_DISCONNECTED` on the first English case. Later cases emitted partial words, but empty final results. The second run, offline and with complete callback instrumentation, emitted partial words for all eight cases but no usable final text or committed segments. Those runs do not pass complete-transcript scoring. Their reports remain available; partials were not promoted to final results.
- A separate offline run explicitly requested `EXTRA_SEGMENTED_SESSION=EXTRA_AUDIO_SOURCE`. All eight cases produced committed sentence segments with no native errors. Seven matched the reference after punctuation/case/accent normalization and equating 5/6 with their spoken words. The Spanish correction transcribed `No, mejor a las seis` as `no mejora las seis` (two word edits out of that case's 17 reference words). No overall speech-accuracy claim follows from eight synthetic phrases.
- In the segmented run, first partials arrived 0.864–1.123 seconds after the request. Sessions ended at source EOF, 8.531–11.463 seconds after the request, including spoken audio and trailing silence. These are file-probe measurements, not app startup, real microphone endpointing, AI extraction or end-to-end capture latency.

Reports: ignored `App/artifacts/android-speech-probe/results-initial.json`, `results-offline.json`, `results-offline-scored.json`, `results-offline-segmented.json` and `results-offline-segmented-scored.json`. The scorer retains original callbacks and never supplies missing words from the reference. See the probe README for reproduction and microphone-isolation requirements. Static analysis remains clean (`App/artifacts/speech-probe-analyze.log`).

This narrows the model availability/recognition gap, but it does not validate TaskFlow's normal microphone path. Explicit segmentation changes the session contract and is used only by the diagnostic APK; no production speech behavior was changed to make the fixture pass.

After the probes, the companion APK and temporary model-setup UI dump were removed. The original emulator launch configuration and airplane/Wi-Fi/mobile-data settings were restored. TaskFlow's microphone permission remained granted, and its data was preserved. The ordinary Android x64 `lib/main.dart` APK built successfully and was restored with `adb install -r` (`App/artifacts/speech-probe-main-build.log`). The restored process showed the Calendar landing screen with its capture controls; no fatal/unhandled app exception appeared in the inspected launch log.

**Remaining device evaluation**

Android saved-audio recovery now also has actual process-termination evidence for recording, background/call interruption and typed input. Those tests found and fixed the native recorder's blank-until-Stop WAV header and foreground audio-focus handling; see [process recovery validation](CAPTURE_PROCESS_VALIDATION.md). They used emulator-generated audio and controlled processing responses, so real microphone/device coverage remains outstanding.

Use a physical target device with its on-device model available. Test English and Spanish short utterances, long pauses, corrections, multiple commitments, noisy input, microphone denial/revocation, activity interruption, and airplane-mode retention. Measure time to first partial, service endpoint timing and stop-to-review separately. Repeat on physical target devices before advertising offline speech or a latency/accuracy figure. Apple native speech is not implemented or validated; its audio path remains available.

Run the Android test with `flutter drive --keep-app-running --no-pub --driver=test_driver/appearance_test.dart --target=integration_test/native_speech_flow_test.dart -d emulator-5554`. Keep the flag: the default driver teardown uninstalls the app. Restore the ordinary main APK using `adb install -r` after test builds.
