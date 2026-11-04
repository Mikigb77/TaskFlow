## UX verify — P324 (Stopping: failed Stop, quiet recording) — round 1, re-applied package — 2026-11-03
**Verdict:** Ship after one small fix. UX-2717 is fixed, and R1-P324-1 and R1-P324-2 from the earlier checks are both fixed in this attempt. UX-2713 is partly fixed: what it says and does is right, but at 1× text the failed-Stop screen now draws the ring and the time off to the left (R1-P324-3, the tester's failing centring test).
**Evidence:** worktree `.claude/worktrees/wf_ffe605e9-07e-3`, the package diff (waves.py), the tester's tests (read, not run), and the renders `recording.stop-failed` (es 1×, ca 2×), `notes-lines.stop-failed.es.light.1x`, `after-stop.quiet-question.es.light.1x` and `after-stop.quiet-dismissed.es.light.1x`. All renders are newer than the lib files (00:57 vs 00:48). This is code, widget-test and preview evidence only. None of it comes from a device.
**Scope note (not UX):** the package also changes `App/lib/models/meeting.dart`, `App/lib/services/meeting_store.dart`, `App/lib/widgets/meeting_banners.dart` and `App/lib/screens/account_screen.dart`, which aren't in its file list. In Cuenta › «Enviar primero», a quiet recording stopped by sign-out is now finished into notes, the same as any stopped meeting. That matches what the person chose and MN-13. It's not a regression.

### Findings
**UX-2713 · partly fixed**
- Done:
  - The message has its own key, `meetingStopFailed`, in all three ARBs: ES «No se pudo terminar de parar. Lo grabado está a salvo: vuelve a pulsar Parar.» It uses the check 1 correction, so it doesn't make the untrue «Sigue grabando» claim. It's shown from `App/lib/screens/meeting_screen.dart:321-329`.
  - `_stopFailed` keeps the screen in place (`:425`).
  - The recorder keeps the stopped session (`_unstopped`, `stoppedAt`), so the next Stop finishes it at its true length (`App/lib/services/meeting_recorder.dart` `stop()`).
  - The status carries `stopFailed`. The screen hides «Grabando» and «Puedes bloquear el teléfono: sigue grabando.» when either the local flag or the status says so (`meeting_screen.dart:518`, `:676-707`). The tests the tester lists pass for the string, the screen staying, «Parar» enabled, and a second «Parar» going on to «Preparando tus notas…». A real-recorder test shows the mic stops once, the files are kept, and the time stays frozen.
- Not done: at 1× text the time and ring aren't centred once the two lines are hidden. See R1-P324-3. The render `recording.stop-failed.es.light.1x` shows the ring and «12:03» against the left edge, above a centred «Parar». The tester measured the time's centre at 92 dp on a 360 dp screen, against 180 dp while recording. At 2× (`recording.stop-failed.ca.light.2x`) it's centred, because the big-text Row fills the width.

**UX-2717 · fixed**
- Silent pieces are held (`hold: _holds(session)`, state `held` and numbered below 0, in `meeting_store.dart` `closePiece`). When a piece with sound is kept, the held pieces are dropped and their files deleted (`_dropHeld`, MN-4).
- At Stop, a recording of 60 s (`askWhenSilent`) or more that is empty and has held pieces becomes `stopQuiet` → `interrupted`. Anything else goes through `finish(keepHeld: false)`, so 30 s of silence is still dropped with «No se oyó nada…» (`meeting_screen.dart:334-339`). A recording that ends by itself also passes `keepHeld: false`, so it's unchanged as the brief asks.
- `_askQuiet` shows «Casi no se oyó nada. ¿Hacer notas igualmente?» with «Descartar» in `colorScheme.error` and a filled «Hacer las notas».
  - «Hacer las notas» → `finishMeeting`, which renumbers the held pieces 0..n-1 as pending, then «Preparando tus notas…».
  - «Descartar» → `discardMeeting` → `_leave()`.
  - Dismissing the dialog leaves the stopped card.
- The render `after-stop.quiet-question.es.light.1x` matches the acceptance check: the two actions are stacked with the filled one last, and the safe action stands out.
- Tests over the real controller, recorder, store and uploader cover every acceptance check, including MN-4 with sound in the third piece.
- Owed: the plan's phone check, a quiet real room 2–3 m away.

### Regressions
**R1-P324-1 · fixed** (from check 1)
- `MeetingStoppedCard` uses `meeting.quiet ? meetingStoppedQuiet : meetingStoppedCut` (`App/lib/widgets/meeting_banners.dart:352`), with `Meeting.quiet => empty && waitingPieces > 0` (`App/lib/models/meeting.dart:165`).
- The renders `after-stop.quiet-dismissed.es.light.1x` and `notes-lines.quiet-stopped.es.light.1x` read «Grabación de ayer, 09:00 · 10 min. Casi no se oyó nada.». Neither says «Se cortó…».

**R1-P324-2 · fixed** (from check 2)
- `MeetingRecordingStatus.stopFailed` is set in the catch in `stop()`.
- On Notas, `_RecordingCard` then shows `meetingRecordingUnstopped`, ES «Grabación sin terminar de parar · 12 min. Ábrela y pulsa Parar.», with the pause icon instead of the mic (`meeting_banners.dart:318-328`). The render `notes-lines.stop-failed.es.light.1x` shows this.
- The reopened screen hides «Grabando» from the status (`meeting_screen.dart:518`).
- The tester's widget test covers Back → Notas → «Abrir» → «Parar».

**R1-P324-3 · Severity 2 · After a failed Stop, the ring and time jump to the left**
- Where: `App/lib/screens/meeting_screen.dart:575-597`. `_Centered` puts a `Column` with `crossAxisAlignment.center` in a `SingleChildScrollView`, and the `ConstrainedBox` around it sets only `minHeight`. The Column is as wide as its widest child. While recording, that's the full-width help line. With `stopFailed` hiding «Grabando» and the help line (`:676-707`), the widest child is the 136 dp ring, so the Column sits at the left padding. This happens at 1× and up to just under the `big` threshold. At 2× the Row fills the width.
- The moment: Stop has just failed. The snackbar says to press Parar again, and the ring and «12:03» suddenly sit at the left above a centred «Parar». "Something broke on the screen too. Is it frozen?" This adds doubt to a moment that's already an error.
- Why it fails: a stable layout across states (CRAP alignment; UN-1, visibility of system status, where the screen looks broken rather than paused). The package caused it by removing the only full-width children.
- Fix: give the Column the full width in `_Centered`, for example `BoxConstraints(minWidth: math.max(0, constraints.maxWidth - 48), minHeight: …)`. No copy changes. `_Centered` is shared with the refused and after stages, so re-render those as well. Everything in them is centred already, so nothing should move.
- Verify: the tester's test "after a failed Stop, the time stays in the middle of the screen" passes (time centre 180 ± 1 dp at 360 dp), and `recording.stop-failed.es.light.1x` shows the ring and time centred above «Parar».
- Evidence: seen in the current render. The tester's widget test measures it.

### Observations (not findings)
- On the failed-Stop screen the ring still holds the mic icon, while the Notas line now uses the pause icon. Without «Grabando», the time and the snackbar carry the state, and «Parar» is still the next step. This is minor and not raised. If the implementer touches the ring for R1-P324-3, using `Icons.pause_circle_outline_rounded` (or the pause glyph) when `stopFailed` would match Notas.
- The failed-Stop snackbar follows the person to Notas (`notes-lines.stop-failed`). It's a root-messenger snackbar and the same message, so that's fine.

### Memory notes
- Recurring type, **removing the full-width child un-centres a shrink-wrapped Column**: `_Centered` (meeting screen) only centres because a long text line stretches the Column. Any state that hides text lines (stop failed, short copy, a shorter language) pushes the rest to the left. When a fix hides lines in a `SingleChildScrollView > Column`, check the cross-axis width.
- Meeting Stop failure (this attempt): the status now carries `MeetingRecordingStatus.stopFailed`. Notas shows `meetingRecordingUnstopped` with a pause icon, and the reopened screen reads the flag from the status.
