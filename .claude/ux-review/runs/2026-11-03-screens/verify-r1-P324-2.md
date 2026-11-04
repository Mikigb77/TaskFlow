## UX verify — P324 (Stopping: failed Stop, quiet recording) — round 1, check 2 — 2026-11-03
**Verdict:** Ship after one small fix. Both findings meet their acceptance checks, and R1-P324-1 is fixed. One new regression: after a failed Stop, leaving the screen brings back the false «Grabando» claim, on the Notes tab and on the reopened screen (R1-P324-2).
**Evidence:** I read the worktree `.claude/worktrees/wf_b7a20ea0-e5f-23` and the package diff (waves.py). I read the tester's tests but didn't run them. I looked at the renders `recording.stop-failed` (es 1×, ca 2×), `after-stop.quiet-dismissed.es.light.1x`, `notes-lines.quiet-stopped.es.light.1x`, and their AUDIT entries. All renders are newer than the lib files they show. All of this is code, widget-test and preview evidence. None of it comes from a device.

### Findings
**UX-2713 · fixed**
- The snackbar now says what's true: `meetingStopFailed` ES «No se pudo terminar de parar. Lo grabado está a salvo: vuelve a pulsar Parar.», with EN and CA matching the check 1 fix, in all three ARBs (`app_es.arb:1442`). It's shown at `App/lib/screens/meeting_screen.dart:256-264`.
- While `_stopFailed` holds, `_Recording` hides «Grabando» and «Puedes bloquear el teléfono: sigue grabando.» (`meeting_screen.dart:572-608`). The render `recording.stop-failed.es.light.1x` shows only the ring, the frozen 12:03, the snackbar, «Parar» and «Descartar». TalkBack reads «12 minutos y 3 segundos grabados», then the snackbar as a live region. AUDIT found nothing beyond the intended Label ≠ text on the clock.
- The real recorder keeps the stopped session as `_unstopped`, so the second Stop finishes it (`App/lib/services/meeting_recorder.dart` `stop()`). The last piece ends at `stoppedAt`, not at the Stop that worked. Discard and suspend take the session over (`_takeUnstopped`).
- The recorder test I asked for at check 1 is now there: `meeting_stop_recorder_test.dart`, group «P324 · a Stop that fails in the store», using `_FailingLastPiece`. It shows the mic is stopped once and every file is kept. The time stays at 30 s across a second failure, the third Stop finishes with a duration of 30 s, and afterwards nothing is shown as recording. The widget test covers the string, the screen staying, and the retry.
- Still owed: no widget test asserts that «Grabando» and the help line are hidden. Only the render shows it.

**UX-2717 · fixed** (unchanged since check 1)
- Silent pieces are held while no piece with sound is kept. At Stop, a recording of 60 s or more with only held pieces becomes a stopped meeting, and the dialog asks «Casi no se oyó nada. ¿Hacer notas igualmente?», with a filled «Hacer las notas» and «Descartar» in red (`meeting_screen.dart` `_askQuiet`). A recording under 60 s is still dropped with «No se oyó nada…». The tests run the real controller, recorder, store and uploader over fakes, and match the acceptance checks.
- Dismissing the dialog leaves the stopped card, which now says the true thing (see R1-P324-1).
- Owed: the plan's phone check, a quiet real room 2–3 m away.

### Regressions
**R1-P324-1 · fixed**
- `MeetingStoppedCard` now uses `meeting.quiet ? meetingStoppedQuiet : meetingStoppedCut` (`App/lib/widgets/meeting_banners.dart:345`), with `Meeting.quiet => empty && waitingPieces > 0` (`App/lib/models/meeting.dart:165`). `waiting` counts every piece that isn't `saved`, so held pieces count.
- The renders `after-stop.quiet-dismissed.es.light.1x` and `notes-lines.quiet-stopped.es.light.1x` both read «Grabación de ayer, 09:00 · 10 min. Casi no se oyó nada.». Neither shows «Se cortó…». Both surfaces use the same card.
- Accepted edge case, as the implementer notes: a recording the phone cut off while it was still all silence also reads «Casi no se oyó nada.». That's true, and the card still offers continue, make notes or discard (MN-12). It isn't a regression.

**R1-P324-2 · Severity 2 · After a failed Stop, leaving the screen says «Grabando» again**
- Where: `_stopFailed` is local to `_MeetingScreenState` (`meeting_screen.dart:126`). Meanwhile the recorder keeps publishing the unstopped session as the recording status (`meeting_recorder.dart` `stop()` catch: `current = MeetingRecordingStatus(...)`; `recording` is true while `_unstopped != null`). The Notes tab's `_RecordingCard` (`meeting_banners.dart:312-330`) shows it as «Grabando una reunión · 12 min» with «Abrir». «Abrir» → `openMeetingRecorder` → a new `MeetingScreen` whose `_start` attaches to `recording` (`meeting_screen.dart:213-216`) with `_stopFailed = false`, so it shows «Grabando» and «Puedes bloquear el teléfono: sigue grabando.» under a clock that doesn't move.
- The moment: Stop fails. They read the snackbar, press Back, and see «Grabando una reunión» on Notas. "Oh, it's still recording after all." They leave the phone on the table for the rest of the meeting, and nothing is recorded. The recording notification has already gone. «Grabar una reunión» is also refused as busy.
- Why it fails: UN-1 and Nielsen's visibility of system status. It's the same false state claim UX-2713 removed, now on the other surfaces that show this recording (recurring problem: a state flag kept on one screen when the state lives in the service).
- Fix: make the recorder status carry the state, for example `MeetingRecordingStatus.stopFailed` (true from the catch in `stop()`), and derive the screen's `_stopFailed` from it instead of local state. The reopened screen then hides «Grabando» too. On Notas, when it's set, `_RecordingCard` reads ES «Grabación sin terminar de parar · {length}. Ábrela y pulsa Parar.» / EN “Recording not fully stopped · {length}. Open it and press Stop.” / CA «Enregistrament sense acabar d’aturar · {length}. Obre’l i prem Atura.», keeps «Abrir», and uses a non-mic icon (for example `Icons.pause_circle_outline_rounded`).
- Verify: a widget test where Stop throws, Back is pressed, and Notas doesn't show `meetingRecordingNow`; then «Abrir» opens a screen without «Grabando» or `meetingListeningHelp`, and «Parar» finishes the meeting.
- Evidence: verified in code. Inferred, not covered by any render or test. Rare in practice: it needs a store failure at Stop.

### Observations (not findings)
- Catalan at 2× (`recording.stop-failed.ca.light.2x`): the four-line snackbar covers the lower half of the clock until it goes. That's a standard snackbar overlay and it's temporary. Once it goes, nothing on the screen says Stop hasn't finished, only the still mic and the frozen time. «Parar» stays the obvious next step, so I'm not raising it.
- The space-low line «Queda poco espacio: la grabación se detiene sola si el teléfono se llena.» can still show while `_stopFailed` holds. It's an edge case and isn't raised.

### Memory notes
- Recurring type, **a screen-local flag for a service-level state**: `_stopFailed` lives in one screen's State. The recorder still publishes the session as a recording, so the Notes line and a reopened screen contradict it. When a fix hides a false claim on one screen, check every other surface that reads the same provider (here the `MeetingBanners` `_RecordingCard` and `openMeetingRecorder`).
- Meeting Stop failure: the recorder now has `_unstopped` and `stoppedAt`. A failed Stop republishes the status at level 0 with a frozen elapsed time, and the next Stop finishes it. `Meeting.quiet` = `empty && waitingPieces > 0`, and it selects `meetingStoppedQuiet` on the stopped card.
