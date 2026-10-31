# Capture recovery after Android process termination

## Defect found and fixed

The real Android recorder exposed a case that the earlier synthetic WAV tests missed. `record_android` 1.5.2 reserves 44 bytes for its WAV header and writes that header only during normal Stop. If Android terminates the process first, the samples survive but the header is entirely zero. Our previous recovery code only repaired length fields in an existing RIFF header, so retry could not produce a usable recording.

The capture journal now records the exact Android PCM format before starting the recorder: signed 16-bit, mono, 16 kHz. Retry can reconstruct the blank header for this known format, retaining the samples and original capture time/timezone. Unknown formats, malformed headers and older blank-header captures without format metadata remain intact rather than being guessed or deleted. An incomplete PCM frame produces a recoverable processing error. Existing conventional WAV length repair still works.

The new metadata lives in capture JSON; no database schema migration or server contract change is needed. It is not a promise that audio buffered only in memory survives a sudden hardware failure.

## Native verification, 22 September 2026

`integration_test/capture_process_recovery_test.dart` was run in two separate Android processes for each case on the API 36.1 emulator:

| Case | Actual host action | Recovery result |
|---|---|---|
| Recording terminated abruptly | `am force-stop` after a durable capture/audio checkpoint, without first leaving the recording screen | Pass. Journal still said recording; 73,772 retained bytes were repaired and reviewed. |
| Recording interrupted by backgrounding | Home, two-second wait, then `am force-stop` | Pass. Journal said editing, showing the lifecycle handler had stopped recording; 84,012 retained bytes remained usable. |
| Recording interrupted by an answered emulator call | Simulate ringing, answer, verify Android OFFHOOK while TaskFlow stays foreground; end that exact call, then `am force-stop` | Pass after the audio-focus fix below. The journal became editing during the call; 122,924 retained bytes survived restart and exactly one save. |
| Typed note terminated abruptly | `am force-stop` after text reached SQLite, while the capture screen was open | Pass. All original words and explicit Note type returned; processing needed no network. |

Each second launch checks the original identity, capture time/timezone, owner isolation, review, exactly one save despite repeated Save, and scoped cleanup. Audio cases compare the checkpoint's first 32,000 sample bytes by hash before and after retry and verify the reconstructed WAV length fields. Unit regression coverage additionally compares the entire nonzero sample payload and rejects unknown formats/partial frames without modifying them.

The host verified each original Android process was gone before relaunching. Disconnection and a nonzero driver exit on the first launch are **expected interruption evidence**, not a passing test. The subsequent recovery drivers all report `CAPTURE_PROCESS_VALIDATED` and pass. Initial failed preparation exposed the missing header; another assertion incorrectly required emulator-generated audio samples to all be zero and was corrected.

The emulator ran with `-audio none` and `avd hostmicoff`; it generated test samples without host microphone input. Audio processing responses were controlled fixtures, not Google speech results. These runs establish persistence/recovery and simulated Android call interruption, not real speech accuracy, carrier-call behavior or physical-phone reliability. The fixture never called an AI service, used a real account, or read/wrote another owner's task rows.

All **172 Flutter tests pass**, analysis reports no issues, and the regular Android x64 debug APK builds. Logs live in ignored `App/artifacts/capture-process-*-prepare*.log`, `capture-process-*-recovery.log`, `capture-process-all-tests.log` and `capture-process-final-analyze.log`. Original emulator data was preserved with `--keep-app-running`; only the constant synthetic owner and its canonical capture files were cleaned. Microphone permission was returned to its original denied state and the ordinary emulator launch options restored.

## Audio-focus interruption follow-up

The answered-call test exposed another defect: Android paused the recorder after losing audio focus, while the foreground screen kept saying Listening. Lifecycle callbacks alone did not cover it. The capture screen now observes recorder pause/stop/error events and finalizes the partial file without submitting it. It also checks recorder state after start returns, covering interruption before the start reply, and releases its event subscription with the screen.

Four widget regressions cover pause, unexpected stop, and each interruption during start. They check retained identity/time/audio path, no request or timer-driven restart, an enabled retry action, and recorder disposal. The current full suite has **180 passing Flutter tests**, analysis is clean, and the regular Android x64 debug APK builds. The normal emulator launch options and main APK were restored, using `adb install -r` to preserve app data. Logs: `capture-call-all-tests.log`, `capture-call-analyze.log`, `capture-call-main-build.log`.

The native host verified Android `mCallState=1` (ringing) and `mCallState=2` (offhook); TaskFlow remained the focused activity. During the active synthetic call, the screen changed to Recording kept on this phone, the WAV finalized, and no extraction request ran. The host then ended the fixture call and verified the original process was gone. A second launch verified retained sample hashes, original metadata, review, and exactly one save. The recovery driver passed. Screenshot evidence is in `App/artifacts/capture-call-active.png`; logs are `capture-call-host-fixed.log`, `capture-call-prepare-fixed.log` and `capture-call-recovery-fixed.log`.

An initial controller incorrectly treated the emulator console's empty `gsm list` result as absence of a call; Android's telephony state is the evidence used for the passing run. A pre-fix run retained audio only after later lifecycle handling, so it was not counted as a pass for foreground interruption. The final fixture removed only its own capture/task/audio and the three timestamp-verified synthetic call-log rows. Microphone permission was already granted before this follow-up and was preserved.

## Repeat the test

Use a test emulator with host audio disabled. Build/run `integration_test/capture_process_recovery_test.dart` with `--dart-define=LIFECYCLE_CASE=audio-abrupt`, `audio-background`, `audio-call`, or `text-abrupt`, using `--keep-app-running` and the existing `test_driver/appearance_test.dart` driver. Grant microphone permission temporarily for audio cases, preserving its original state.

For `audio-call`, wait for `CAPTURE_CALL_READY`, verify the emulator has no active call, then use `emu gsm call 5550102`. Confirm ringing through `shell dumpsys telephony.registry` before answering the synthetic call with `shell input keyevent KEYCODE_CALL`; confirm OFFHOOK in the same Android registry. Require `CAPTURE_CALL_RETAINED` while the call remains active, and inspect the screen for Recording kept on this phone. Cancel only this fixture with `emu gsm cancel 5550102`, then follow the termination/recovery steps below. Record the fixture call-log IDs/timestamps and remove only those rows afterward; do not clear unrelated calls.

Wait for `CAPTURE_KILL_READY: <case>`, then force-stop `com.example.agenda` on that exact emulator. For `audio-background`, press Home and wait two seconds before force-stop. Relaunch the same compiled APK with `flutter drive --keep-app-running --use-application-binary=build/app/outputs/flutter-apk/app-debug.apk` and the same driver/target; the durable marker selects recovery automatically. Do not count the first process's disconnection as a recovery result.

`LIFECYCLE_RESET_FIXTURE=true` explicitly discards only a failed preparation's synthetic captures when no recovery marker exists. It does not reset guest or signed-in data. After all cases, restore microphone permission, ordinary emulator launch options and the regular main APK with `adb install -r`.

Physical-device incoming calls, real microphone content and device/language coverage remain in [remaining validation](VALIDATION_REMAINING.md).
