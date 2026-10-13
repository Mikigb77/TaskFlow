## UX verify — run 2026-10-13-app, round 1, area A (P1, P33) — 2026-10-13
**Verdict:** Ship after fixes. All 7 findings meet their acceptance checks in code and tests. One new risk: an automatic session restart can wipe words that were heard but never committed.
**Evidence base:** code (diffs plus the files they touch) and the 17:16 render `App/build/calendar-feedback-light.png`. No capture-screen or Settings-sheet preview exists, so those parts rest on code alone.

### Results
- **UX-101: fixed.** `App/lib/widgets/app_components.dart:10-26`: `showFeedback` hides the current bar, then shows a floating bar with `persist: false` and `FeedbackTimeout.forAction()`. It is the only `SnackBar(` left in App/lib (grep). The review save uses it at `review_tasks_screen.dart:158`, and the hard-coded 8 s is gone. Both the review (`review_tasks_screen.dart:51-54`) and the capture (`voice_task_screen.dart:186-189`) hide stale bars when they open. TaskEditor: the save sets `_suggestionBar = null` and replaces the bar, and `dispose` clears the suggestion's Undo (`task_editor.dart:169-175`). Tests pass. Device checks left: the 1-minute accessibility timeout, and no Deshacer on a second capture.
- **UX-416: fixed.** `settings_screen.dart:283-307`: `_showWidgetHelp` opens a bottom sheet with the drag handle from the theme (`app_theme.dart:149`), the same text in bodyLarge, and a `done` FilledButton. It stays until the user closes it.
- **UX-335: fixed.** grep finds no `SnackBarBehavior.fixed`, and the helper forces `floating`. In the render, `Tarea completada · Deshacer` floats above `Dictar una tarea` and the navigation bar.
- **U1: fixed in code; needs a device.** `NativeSpeechBridge.kt:211-217`: on API 33+ an app-owned 16 kHz mono PCM AudioRecord feeds the recognizer through a pipe, with `EXTRA_SEGMENTED_SESSION = EXTRA_AUDIO_SOURCE`. Stopping closes the feed (`finishAudio`, :222-225). An automatic end restarts the session (`attemptOver`, :171-184). TIMEOUT and NO_MATCH call `finished()` and never reach Dart (:274-277). Dart appends committed segments (`voice_task_screen.dart:350-354`). The 60 s cap submits (:393), and stopping waits up to 4 s (:611-614).
- **UX-104: fixed.** `_leaving` covers only hidden, paused and detached (`voice_task_screen.dart:397-400`), used both in the lifecycle handler (:638-643) and while starting (:516). An interruption that leaves words goes to `paused`, which shows `En pausa` (:620-623, :889).
- **UX-107: fixed.** Kotlin returns `"blocked"` when the request is denied and no rationale should be shown (:346). The Dart side maps it at `native_speech.dart:65-70`. The screen shows the banner and an `Abrir Ajustes` button that calls `openAppSettings` (:913-925). On resume it checks again and starts listening (:644-659). All three languages have the copy, exactly as specified.
- **UX-108: fixed.** `_CapturePhase` replaces `_busy`'s double meaning. The starting state shows `Un momento…` with no bar. The listening state and its timer start only on `ready` or the first words (:339, :378-382).

### Regressions
**R1A-1 · Severity 3 · Words heard before a restart can vanish**
- Where: `NativeSpeechBridge.kt:268-278` (`onError` → `finished()` → new attempt) and `voice_task_screen.dart:352-354`. Applies to listening during a pause.
- The moment: "I said 'comprar pan', paused, and now it's gone from the screen."
- What happens: `_nativePrefix` only advances on a `segment` event. Suppose a session ends through `onError` (NO_MATCH, or any other error that now restarts) after it has sent partials but no segment. The next attempt's first `partial` then overwrites the field with prefix plus new partial, and the earlier partial is lost. Before this change, the session ended and the words in the field were kept.
- Why it fails: never lose what the user said (lens I; Nielsen 2001, error messages). The user isn't watching the text while speaking, so they won't notice the loss (change blindness, Rensink et al. 1997).
- Fix: in `Attempt`, remember the last partial text. Clear it on `onSegmentResults` and `onResults`. In `finished()`, when it isn't empty and no segment followed, emit it as a `segment` before calling `attemptOver`. (A Dart-only alternative: on a `ready` event while already listening, commit `_words.text` to `_nativePrefix`.)
- Verify: unit test with the channel mocked: `partial("comprar pan")`, `ready`, `partial("y leche")`, `ended` → the words read `comprar pan y leche`. On a device, run the Android 12 restart-fallback check.
- Evidence: inferred from code; needs a device.

### Device notes (not findings)
- On API 33+ the recognizer reads our pipe. Check that `onRmsChanged` still fires, so the level bar moves as live evidence of listening. If it doesn't, compute the level from the AudioRecord buffer.
