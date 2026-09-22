# Synthetic Android speech probe

This separate, debug-only APK tests the installed on-device recognizer with eight reproducible English/Spanish PCM fixtures. It does not depend on TaskFlow, read its data, call its backend, or contain an Internet permission. It is not a human microphone test or an end-to-end TaskFlow test.

The fixtures use offline Windows System.Speech voices (Zira en-US and Helena es-ES), 16 kHz mono PCM16, 250 ms lead-in and two seconds of trailing silence. Cases include clean speech, deterministic white noise at 12 dB SNR, an extra 1.5-second pause between sentences, and a spoken time correction. Reference words and PCM hashes travel with each result. Neither text hints nor altered silence thresholds are supplied to the recognizer.

The probe uses Android 13's [EXTRA_AUDIO_SOURCE](https://developer.android.com/reference/android/speech/RecognizerIntent#EXTRA_AUDIO_SOURCE). **Run only on a disposable test emulator started with `-audio none`, with `adb emu avd hostmicoff` applied.** A provider that does not support the supplied descriptor can otherwise open the microphone. This restriction also prevents accidental ambient recording. Preserve the emulator's existing data; do not wipe its AVD or uninstall TaskFlow.

Model setup is separate. `integration_test/speech_model_probe_test.dart` queries TaskFlow's real native capability bridge. `REQUEST_SPEECH_MODELS=true` requests Android setup, which can present an install confirmation. `REQUIRE_SPEECH_MODELS=true` fails unless both language models are actually reported installed. A successful request alone is not installation evidence.

## Build and run

From `App`, using a Windows SDK with build-tools 36.1.0 / platform android-36.1, a JDK, Python 3, and the two installed Windows voices:

```powershell
./test_support/android_speech_probe/build.ps1 -JavaHome <jdk-directory> -Python <python.exe>
adb -s emulator-5554 install -r artifacts/android-speech-probe/speech-probe.apk
adb -s emulator-5554 shell pm grant com.example.taskflow.speechprobe android.permission.RECORD_AUDIO
adb -s emulator-5554 shell am start -W -n com.example.taskflow.speechprobe/.ProbeActivity
```

The app runs each case once with a 25-second bound and saves progress after each terminal result. Wait for `complete: true` in its private `files/results.json` before copying or scoring the final report. Use `adb shell run-as com.example.taskflow.speechprobe cat files/results.json` and save as UTF-8 under `artifacts/android-speech-probe/`. `score.py <report.json>` adds word-edit counts after ignoring punctuation/case/accents and equating only 5/five/cinco and 6/six/seis. It never fills in words from partials. There is no claimed population accuracy threshold.

For an offline run, first record airplane mode, Wi-Fi and mobile-data settings. Disable the radios and verify Android reports `Active default network: none`. Restore those exact settings afterward, including on failure. Explicit on-device selection and a disconnected emulator are separate pieces of evidence.

Keep raw `transcript`, `segments`, `partials`, final bundle, ready/first-partial/terminal timings and native errors. If a provider emits partials but empty finals for ordinary file input, retain that failure report. A separate run with `am start ... --ez segmented true` explicitly requests `EXTRA_SEGMENTED_SESSION=EXTRA_AUDIO_SOURCE`. Its committed segments measure file recognition; its session ends at file EOF, which differs from TaskFlow's normal microphone endpointing. Joining committed segments is diagnostic reporting, not TaskFlow's microphone implementation. File input timing, synthetic pronunciation and the emulator cannot establish real microphone quality or production endpoint timing.

Cleanup removes only `com.example.taskflow.speechprobe`. Restore the emulator's original launch/audio configuration. If Flutter integration probes were run, rebuild TaskFlow's normal `lib/main.dart` target and replace it with `adb install -r`; never uninstall it or clear its data. All generated audio, APKs and raw reports stay under the ignored `App/artifacts` directory.
