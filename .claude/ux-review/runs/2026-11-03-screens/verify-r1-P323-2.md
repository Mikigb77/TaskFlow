## UX verify — P323, round 1, check 2 (run 2026-11-03-screens, area C) — 2026-11-03

**Verdict:** the five findings stay fixed, and both regressions from check 1 are fixed. Nothing new from the fix.
**Read:** the package diff (waves.py diff on worktree wf_b7a20ea0-e5f-13), mainly `App/lib/screens/meeting_screen.dart` (`_Recording`) and the UX-2716 fit test in `App/test/meeting_screens_test.dart`. Renders under the worktree's `App/build/ux/meetings/` (all 2026-11-04 00:16): recording.allowance-used.es.light.2x, recording.space-low.{es,ca}.light.2x, recording.listening.{es.light.1.3x, en.light.2x}. The tester's and implementer's results were taken as reported. I did not run Flutter.
**Evidence level:** code, widget tests (from the tester and implementer), renders in the Flutter test engine, and my own wrap estimate from `App/assets/fonts/Manrope.ttf` (Regular, 14 sp × scale, 0.25 letter spacing, 312 dp wide). That estimate matches the renders' line breaks (ES help 4 lines, ES start line 5, ES space 4, CA space 3). Nothing here comes from a device.

### Findings

**UX-2715 · fixed.** Unchanged since check 1. `openMeetingRecorder` pushes `MeetingScreen(proFirst: true)` at once, guarded by `_recorderRoute`. Billing is waited for on the screen's spinner (`_hasPro`). Tester: spinner in the first frame; taps in one frame, one frame apart and 50 ms apart leave one MeetingScreen.

**UX-2808 · fixed.** Unchanged since check 1. `_hasPro` opens `/subscription` (`ProReason.meetingNotes`) over the meeting screen. With Pro when it closes, it goes on to `_record()`; without it, `_leave()` closes the meeting screen, so one Back shows Notas. Device check owed: RevenueCat's test store.

**UX-2712 · fixed.** Unchanged since check 1. Askable shows `meetingMicrophoneNeeded` with a filled «Permitir el micrófono» that asks again. Blocked shows `meetingMicrophoneBlocked` with «Abrir Ajustes» and records with no tap on resume once allowed. Start failed shows a filled «Reintentar». Low space shows no button. Renders recording.microphone-askable.es.light.1x and recording.start-failed.es.light.2x. Device check owed: Android's dialog sequence.

**UX-2711 · fixed.** `_heldLine` shows `meetingAllowanceUsed` or `meetingProRequired` once a piece is refused, and `meetingAllowanceUsedStart` from the first frame when this month's time is already used. Recording goes on. At ES 2× the whole start line now shows above «Parar», including «que viene.» (recording.allowance-used.es.light.2x).

**UX-2716 · fixed.** `meetingListeningHelp` has the brief's copy in ES, EN and CA. It sits right under the time and shows whole above «Parar» at ES and CA 2× (recording.listening.ca.light.2x, recording.space-low.ca.light.2x). The fit test now requires, at ES and CA 2× on 360×800 with no warning, 'start', 'refused' and 'space-low': `meeting-level` present, scroll offset 0, the help line in the body's view above Parar, and the whole warning below the help line and inside the body.

### Regressions from check 1

**R1-P323-1 · fixed — At 2× the red warning runs under «Parar».**
- At large text (`big`, ≥1.5×), `_Recording` now holds the time's digits at 1.3× (`MediaQuery.withClampedTextScaling(maxScaleFactor: 1.3)`), puts a smaller ring beside the time in a Row, sets the lines' height to 1.3 and the vertical padding to 16.
- recording.allowance-used.es.light.2x: all five lines of «Has usado el tiempo de reuniones de este mes: puedes grabar, y las notas llegarán el mes que viene.» end about 30 dp above «Parar».
- recording.space-low.es.light.2x and .ca.light.2x: the whole space warning shows above «Parar».
- My wrap estimate says no warning wraps to more than 5 lines at ES or CA 2×, ES's start line included. CA start, ES and CA refused, and CA Pro come to 5 lines; the others come to 3–4. So the rendered ES start case is the tallest, and it fits in the previews' 528 dp body. The test's 576 dp body is looser. This is the implementer's measurement too.

**R1-P323-2 · fixed — Large text with a warning hides the level ring.**
- The ring is no longer removed when a warning shows. At ≥1.5× it is 2/3 size beside the time (`meter` in the Row) and still grows with the level.
- It shows in every 2× render: allowance-used ES, space-low ES and CA, listening EN.
- The fit test requires `meeting-level` in every case.

### New regressions
None. I checked these, and none counts:
- At 1×–1.3× the layout is unchanged: full ring above «Grabando», time, help line (recording.listening.es.light.1.3x). The 1.3× time clamp has no effect below 1.3×.
- TalkBack still reads «Grabando» and then the time's spoken label, which P321 set. The ring stays excluded from semantics, and `FittedBox` doesn't change the label.
- INDEX descriptions are true to the renders: the ring "at 2×, smaller and beside the time", and the allowance-used render's "Parar stays in view".

### Notes, not counted
- Between 1.4× and 1.49× text, my estimate puts a 5-line warning (ES/CA start or refused) 7–22 dp past the body, so it would scroll. That range sits below `big`, with the full-size ring. Android's standard font steps skip it (1.3 → 1.5), and Android 14+ scales non-linearly. Only an OEM slider with finer steps could land there. Device check if the owner's phone has one.
- If low space and a month's-time line show together, two red lines at 2× would need a scroll. That's rare, and no test or preview covers it.
- From check 1, still as it was: `MeetingStartProblem.signedOut` falls into the `_` branch and shows «Reintentar», which can't succeed while signed out. It's reachable only with Pro and no account.
- The fit margin in the previews is small (about 30 dp for ES start at 2× on 360×800). A real phone's system bars may differ from the previews' insets. Phone check: ES 2×, the month's-time start line, «Parar» fully visible with no scroll.

### Memory notes
- Recording screen since P323 check 2. Below 1.5×: ring, then «Grabando», time, help line (`meeting-help`), `meeting-held` (Pro or month's time) and the space warning. From 1.5× (`big`): «Grabando», then a Row with the ring at 2/3 and the time clamped to 1.3×, then the help line and warnings at line height 1.3, with vertical padding 16.
- Technique: Manrope wrap estimate with PIL. The font is variable (default ExtraLight), so call `set_variation_by_name(b'Regular')`. Body text is 14 sp × scale plus 0.25 letter spacing per character, at 312 dp (360 − 2 × 24). This matched the renders' line breaks exactly.
