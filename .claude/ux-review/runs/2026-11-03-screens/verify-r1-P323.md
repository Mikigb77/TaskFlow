## UX verify — P323, round 1 (run 2026-11-03-screens, area C) — 2026-11-03

**Verdict:** the five findings are fixed. Two regressions, both at large text on the recording screen: a red warning line now runs under «Parar» at ES 2×, and with a warning showing, the level ring is gone.
**Read:** the package diff (waves.py diff on worktree wf_b7a20ea0-e5f-13); `App/lib/screens/meeting_screen.dart`, `App/lib/services/meeting_controller.dart`, `meeting_audio.dart`, `meeting_recorder.dart`, and the three ARBs, in the worktree. Renders under the worktree's `App/build/ux/meetings/` (2026-11-04 00:04): recording.allowance-used.es.light.2x, recording.space-low.es.light.2x, recording.listening.ca.light.2x, recording.microphone-askable.es.light.1x, recording.start-failed.es.light.2x. For comparison, the main checkout's recording.space-low.es.light.2x (2026-11-03 22:31, from before P323). The tester's results were taken as reported. I did not run Flutter.
**Evidence level:** code, widget and unit tests (from the tester), and renders in the Flutter test engine. Nothing here comes from a device.

### Findings

**UX-2715 · fixed**
- `openMeetingRecorder` (meeting_screen.dart:28-42) now pushes `MeetingScreen(proFirst: true)` at once. A call is ignored while `_recorderRoute` is active (:33, :45). Billing is waited for on the screen's own spinner (`_hasPro`, :226-248; spinner at :451), up to 5 s as before. notes_screen.dart is unchanged.
- The tester's tests confirm it: the spinner shows in the first frame, and taps in the same frame, after one frame and after 50 ms leave exactly one MeetingScreen.
- The route is removed by pop, by `_leave` and by the note's `pushReplacement`, so the guard never stays stuck.

**UX-2808 · fixed**
- `_hasPro` pushes `/subscription` (`ProReason.meetingNotes`) over the meeting screen and awaits it (:241-247).
- With Pro when the Pro screen closes, it goes straight on to `_record()` (:219-220).
- Without Pro, `_leave()` closes the meeting screen, so one Back lands on Notas. The tester confirms both paths.
- «Seguir grabando» (`continueId`, meeting_banners.dart:281) runs the same Pro check as before. A recording already running skips it (:214-218).
- Device check owed: RevenueCat's test store.

**UX-2712 · fixed**
- (a) `MeetingAudioEngine.permission({ask})` now returns granted, denied or blocked (meeting_recorder.dart:34-37; meeting_audio.dart:103-119, using `Permission.microphone.request()`'s `isPermanentlyDenied`). `_canRecord` maps the result to `permission` or `microphoneBlocked` (meeting_controller.dart:279-286).
  - Askable: «Para grabar una reunión, TaskFlow necesita el micrófono.» with a filled «Permitir el micrófono» that calls `_record` and asks again (:653, :660-664). Render recording.microphone-askable.es.light.1x.
  - Blocked: `meetingMicrophoneBlocked` with «Abrir Ajustes» (:665-668).
- (b) `didChangeAppLifecycleState` on resume, in either refused state: it checks without asking (`microphoneAllowed`, controller :290-292) and records with no tap once allowed (:139-158). Because `_starting` guards it (:251-260), the resume that follows Android's own dialog can't start a second recording.
- (c) Start failed: a filled «Reintentar» (`tryAgain`) that starts again (:670-674). Render recording.start-failed.es.light.2x. Low space keeps its message with no button (:669).
- All three ARBs have the brief's copy, word for word.
- Device check owed: Android's dialog sequence (deny once → ask again → deny again → Ajustes → back).

**UX-2711 · fixed** (see R1-P323-1 for how it fits at 2×)
- `MeetingsState.recordingProblem` is set in `refresh()` from the active meeting's problem when it blocks uploads (controller :197-206). `allowanceUsed` is true when any meeting on this phone was refused for the month's time in this calendar month. The refusal time is taken as `retryAt` minus `blockedPause`, falling back to `stoppedAt` and then `startedAt` (:226-238).
- `_heldLine` (meeting_screen.dart:424-430) shows `meetingAllowanceUsed` or `meetingProRequired` once a piece is refused, and otherwise the new `meetingAllowanceUsedStart` from the first frame. The line uses the error colour, like the space warning (:612-620). Recording goes on, and Parar stays enabled.
- What the uploader sends and stores is unchanged.
- The tester confirms it with the real controller, recorder and uploader against a fake 402.

**UX-2716 · fixed**
- `meetingListeningHelp` has the brief's copy in ES, EN and CA (ARBs). It now sits directly under the time, before any warning (:603-611).
- At ES and CA 2× on 360×800 it shows whole above «Parar»: render recording.listening.ca.light.2x, and the tester's scroll-offset-0 test with no warning, with the start line and with the refused line.
- To make it fit, the level ring is 2/3 its size at text scale 1.5× and up (:553-556). See R1-P323-2.

### Regressions

**R1-P323-1 · Severity 2 · At 2×, the red warning runs under «Parar»**
- Where: `App/lib/screens/meeting_screen.dart:603-630` (help line moved above `warning` and `spaceLow`). Renders recording.allowance-used.es.light.2x and recording.space-low.es.light.2x (worktree).
- What happens:
  - ES 2× with the month's-time line: «…y las notas llegarán el mes» is cut at the edge of «Parar», and «que viene.» is hidden. The hidden words are the ones that say when the notes come.
  - ES 2× with low space: «…si el teléfono se llena.» is cut at the edge of «Parar». Before P323 (main checkout render, 2026-11-03 22:31) that whole warning showed, together with the ring.
  - The person at 2× doesn't scroll a recording screen. The red line says the most important thing, and they read half of it.
- Why it fails: lens L (2× text without loss, WCAG 1.4.4); lens E (what matters is visible without scrolling).
- Fix:
  - At large text, cap the scale of the elapsed time only, for example with `MediaQuery.withClampedTextScaling(maxScaleFactor: 1.3)` around the time Text. displayMedium digits at 1.3× are still the largest thing on screen, and that frees roughly 80–100 dp.
  - Keep the order: time, help line, warning.
  - No copy change.
- Verify: extend the tester's UX-2716 fit test to the space-low line, and require the whole warning in view as well as the help line and Parar: ES and CA 2×, 360×800, scroll offset 0, for the start line, the refused line and space-low. Re-render recording.allowance-used.es.light.2x and recording.space-low.{es,ca}.light.2x.

**R1-P323-2 · Severity 2 · Large text with a warning hides the level ring**
- Where: `App/lib/screens/meeting_screen.dart:553-586` (`if (!big || (warning == null && !spaceLow))`). Render recording.space-low.es.light.2x (no ring; before P323 the ring showed).
- What happens: from 1.5× text, whenever the space warning or a month's-time or Pro line shows, the ring that grows as it hears is removed. Only the counting time is left, and that shows it records, not that it hears.
- When it happens: for exactly the person who reads at large text, during a long meeting with the phone on the table. The low-space case already reached these people before this run.
- Why it fails: lens J (listening shows live evidence that it hears). The change took that evidence away to make room for the text.
- Fix: keep the ring at the 2/3 size the no-warning case uses. The space R1-P323-1's cap frees is enough for that. Don't remove it.
- Verify: a fit test at ES and CA 2×, 360×800, with each warning: `meeting-level` is present and the lines and Parar fit with no scroll. Renders as for R1-P323-1.

### Notes, not counted
- `MeetingStartProblem.signedOut` now falls into the `_` branch, so it shows «Reintentar», which can't succeed while signed out (:670-674). Before P323 the same message showed with no button. It's only reachable with Pro and no account (`api == null` or ownerKey 'local'), which looks unlikely. Worth a glance when the refused states are next touched.
- The tester saw a ring-less, clipped warning at ES 2× and accepted it, because the acceptance check asked only about the help line and Parar. That's why it's recorded here as a regression, not as a failed check.

### Memory notes
- Recording screen order since P323: ring (2/3 at ≥1.5× text, none at ≥1.5× when a warning shows) → «Grabando» → time → help line (`meeting-help`) → `meeting-held` (Pro or month's time, error colour) → space warning. The month's-time start line comes from `MeetingsState.allowanceUsed`, set by any refusal on this phone in this calendar month.
- `openMeetingRecorder` pushes at once, guarded by a module-level `_recorderRoute`. The Pro screen opens over the meeting screen. Without Pro, `_leave` closes the meeting screen too.
- The refused screen has three variants: askable («Permitir el micrófono», which asks again), blocked («Abrir Ajustes», which re-checks on resume and records with no tap), and failed («Reintentar»).
- Recurring problem: a fit test written to the acceptance check (help line and Parar) passed while the most important line, the red warning, was clipped. In fit checks, require every line that carries a warning, not only the line the brief names.
