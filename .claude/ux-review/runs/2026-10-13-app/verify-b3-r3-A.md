## UX verify — 2026-10-13-app, b3 round 3, area A (P63) — 2026-10-13

**Verdict:** UX-461 and UX-462 are fixed. One new minor regression (R3A-1) on a follow-on path: `Volver a decirlo` again, straight after going back during `Entendiendo…`, waits on the abandoned understanding step.
**Evidence level:** code (`git diff HEAD`) plus ux-tester's passing widget and semantics tests. I didn't run Flutter. Neither change alters any pixel, so no render was needed (`build/capture-listening-es-2x.png` at 23:52 is newer than the code at 23:37).

### UX-461 · fixed (device check open)
- `_cancel` now checks `_previousResult` before the processing branch (`App/lib/screens/voice_task_screen.dart:1032-1042`). A first capture still closes the sheet during `Entendiendo…` (:1039-1041).
- `_backToResult`'s processing path (:1088-1101) restores the stored result at once. It does `_returns++`, clears the words, invalidates the pending list and sets the phase to idle. It doesn't await `_starting`, `_stopping` or `_writes`. The listening path also bumps `_returns` (:1120).
- `_process` (:901-944) records `returns` and `replacing`. It checks `wentBack()` after `_writes`, after `_ensureSession`, after the processor returns, and in `catch`. Each time it drops the said-again capture through `_dropSaidAgain` (:977-984) without calling `_review` or `_showProblem`. `_stopRecording` has the same guard (:806-809, :851-862) for the native-stop window, which also shows `Entendiendo…`.
- Tests: `App/test/capture_result_exits_test.dart:284-379` go through the `Listo`-while-listening path (`_stopping` covers the understanding step). They pass for Cancelar, Back, a failure after Cancelar, a first capture and no Cancelar.
- Device: Back during `Entendiendo…` with real speech, and Pendientes showing one capture.

### UX-462 · fixed (device check open)
- `App/lib/widgets/capture_review_editor.dart:264-269`: the `Semantics` now has `enabled: widget.enabled` next to `button: true`, `excludeSemantics: true` and `onTap: widget.enabled ? _schedule : null`. Both date lines use it (:402, :557). Nothing visible changes.
- The test checks it's disabled with no tap while saving, and enabled with a tap that opens the date sheet otherwise.
- Device: TalkBack says "desactivado".

### Regressions
**R3A-1 · Severity 2 · Saying it again after cancelling waits silently on the server**
- Where: `App/lib/screens/voice_task_screen.dart:778` and :856, where `_process` runs inside the `_stopping` future. Also `_busy` (:310-313), `_beginRecording` (:523-526), `_sayAgain` (:1006) and `_backToResult`'s listening path (:1105-1106). The state is the said-again listening view, reached right after going back during `Entendiendo…`.
- The moment: "I said it wrong, so I cancelled. Now I tap Volver a decirlo… why won't it listen? The button is grey."
- What happens: with `Listo` tapped while listening, `_stopping` stays set until the abandoned understanding step finishes, so `_busy` is true. Going back no longer waits for it (good). But tapping `Volver a decirlo` on the restored result calls `_beginRecording`, which returns at once. The sheet shows no status line and a still mic. `Empezar a hablar` and `Escribir` are disabled until the server answers, which can take 10 s or more on slow AI. After that, listening still doesn't start by itself. `Cancelar` in that state goes to the listening path. Its `_finishRecording` returns the same `_stopping`, so Cancel also does nothing until the server answers.
- Why it fails: visibility of system status and user control (Nielsen 1994). Past about 10 s, a wait needs an explanation and a way out (Nielsen 1993). This is a gulf of evaluation (Norman 2013).
- Fix: once Cancel has gone back, the dropped step must not keep the sheet busy. In `_stopRecording`, run the understanding step with `unawaited(_process())` instead of `await _process()`, so `_stopping` ends when listening ends. `_process` already owns the processing phase and the went-back guards. Keep `_discard`'s first-capture behaviour as it is: it awaits `_stopping`, but a first capture closes during processing anyway. No new strings.
- Verify: widget test. Hold the processor, tap Cancelar during `Entendiendo…`, then `Volver a decirlo`. Listening starts (`Escuchando…`) without releasing the processor. Release it: the new listening isn't disturbed, and only the original capture is pending. A second test: Cancelar in that new listening view brings the result back at once, before the release.
- Evidence: verified in code; not covered by a test.

### Checked, no regression
- `_dropSaidAgain` only resets `_session` when it still points at the dropped capture. A later `_sayAgain` (`_session = null`) or new listening isn't overwritten.
- The `finally` blocks in `_process` (:947) and `_stopRecording` (:866-869) only move processing to idle. After going back, the phase is already idle.
- The sheet closing after going back: `_release` skips the discard because `_movedToReview` is true. The abandoned step still discards through `_store` and `_container` after the sheet unmounts.
- Typed `Listo` (`_process` not inside `_stopping`): `Volver a decirlo` after going back starts listening normally.
- No ARB or copy changes, and no layout changes. `_exits`, the 12 dp gap and the `Fecha y hora: …` label are unchanged.

### Memory notes
- In the capture sheet, `_stopping` covers the whole understanding step when `Listo` is tapped while listening. Anything gated on `_busy` (start listening, `Escribir`, `Listo`) or awaiting `_finishRecording` waits for the server on that path. Check this whenever a change lets the user leave `Entendiendo…` without closing the sheet.
