# Remaining evidence after the critique backlog

Implementation and automated checks do not establish every original acceptance criterion. `IMPLEMENTATION_STATUS.md` and the feature validation documents distinguish shipped behavior, controlled fixtures, live provider results and device observations. Development stays on `dev`; no new main merge is implied.

## Outstanding checks

| Area | Evidence already available | Still needed |
|---|---|---|
| B01 capture retention | SQLite restart/transactions, WAV repair, failed requests, retry, route interruption/resume and duplicate-save checks; actual Android process termination while recording/typing, after backgrounding and after an answered emulator call, with successful recovery | Physical-device call interruption and real microphone recovery across a representative device matrix. Speech before the first recognizer result has no retained transcript. Older blank-header audio without format metadata is retained but cannot be automatically reconstructed safely. |
| B03/B13 reminders | Real Android emulator receipt with process closed, reboot recovery, Complete/Snooze, recurrence and bounded scheduling; concurrent database operations and refreshed Spanish action labels | Physical target phone tests with battery restrictions, permissions, clock/timezone changes, and supported Apple-platform behavior. Scheduling acceptance alone is not delivery. |
| B04 task extraction | Live English/Spanish regression results and bounded failure handling | The full live corpus must pass, including availability. The original run passed 5/14 and had 9 service failures; successful responses had a 31.975-second median. Two-case availability checks on both 22 and 23 September failed; the latest requests took 18.765/45.091 seconds. No sub-five-second claim is supported. |
| B07 native speech | Both English/Spanish models now installed and verified through the actual bridge; retained partials/interruption tests; actual offline recognition of synthetic clean/noisy/paused/corrected file input | Physical microphone and normal app endpointing tests. The segmented file probe produced full results for eight cases; seven matched normalized references, and one Spanish correction had two word edits. Ordinary file input emitted partials but empty finals. Segmented file input is a separate diagnostic path, not production microphone evidence. See SPEECH_VALIDATION.md. |
| B19/B20/B23 external handoff | File-byte restoration, permissions/provider events, safe links; actual Chrome page and PDF viewer display on Android, with return to TaskFlow | Google Calendar returned without displaying the synthetic provider event. Verify a configured calendar account/app and physical-device/file-type variations. See HANDOFF_VALIDATION.md. |
| B06/B22/B23 product understanding | Labeled capture/type choices, scoped shared-list workflow, English/Spanish core UI, small-screen/large-text checks | Observe first-time users finding capture, correcting mistakes, choosing task versus note, and collaborating on a household list. Functional tests do not prove preference or retention. |
| B18 localization/platform scope | English/Spanish core flows, Notes, account/list/sharing controls, notification settings and structured import diagnostics; regional preferences, 2× text and real Android list/reminder/import persistence checks | Server/platform errors and some detailed action messages still include English. OS notification copy and actual Spanish Complete/Snooze buttons now pass emulator checks. Other native platforms need their own build/device validation. See REGIONAL_VALIDATION.md. |

## Short physical-phone session

1. Use a synthetic account and harmless task text. Record a short appointment, a longer mixed list and a reference note in English and Spanish. Confirm the selected type and retained original words.
2. Repeat with a pause, correction, background interruption and network disabled. Reopen Unfinished captures; Retry/Save should create one copy. Inspect retained text/audio before explicitly discarding the synthetic capture.
3. Enable reminders intentionally, schedule a near-future task, close the app, and observe actual delivery. Exercise Complete and Snooze on that occurrence. Test reboot separately and record whether delivery happened at the intended time or only after boot recovery.
4. Open a downloaded synthetic file, a selected calendar event and an HTTP(S) reference link. Record which external app receives each handoff.
5. Remove synthetic tasks/notes, sign out and restore prior notification preferences. Preserve ordinary app data: integration drivers must use `--keep-app-running`, and APK replacement must use `adb install -r`.

Only an emulator was connected when these remaining checks were recorded. The user has been asked about a physical phone. No missing device or human result should be reported as a pass.
