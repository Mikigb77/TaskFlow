# Verify · round 1 · P322 (area C) · 2026-11-03

Read in worktree `.claude/worktrees/wf_b7a20ea0-e5f-12` (waves.py diff), with the tester's renders there (`App/build/ux/`, 2026-11-03 23:55) and AUDIT.md. No Flutter run. Evidence is widget test and render level; nothing here is a device.

## Findings

**UX-2703 · fixed**
- Card line: `meetingStoppedCut(meetingWhich(...), meetingLength(...))`, `App/lib/widgets/meeting_banners.dart` (`MeetingStoppedCard`, `meetingWhich`). Render `meetings/notes-lines.stopped-and-waiting.es.light.1x`: «Grabación de hoy, 09:00 · 1 h 42 min. Se cortó antes de que pulsaras Parar.» No question, no «Terminar»/«Continuar» (keys gone from all three catalogs and from lib/test).
- Buttons (`MeetingStoppedActions`): FilledButton «Hacer las notas» → `finishMeeting`; text «Seguir grabando» → `openMeetingRecorder(continueId:)`; `_DiscardButton` in `colorScheme.error`, 12 dp below, asks first. AUDIT: primary 154 × 60 dp, 8 dp gap, Discard 12 dp below.
- TalkBack (AUDIT): «Hacer las notas de la grabación de 1 h 42 min», «Seguir grabando, 1 h 42 min hasta ahora», «Descartar la grabación de 1 h 42 min».
- ES 2× and CA 2× renders: nothing cut, Discard last.
- Meeting screen after a microphone failure (`meeting_screen.dart` `_After`): the banner's cause, then `MeetingStoppedActions(centered: true)`, no second "stopped" line. Renders `after-stop.microphone-failed.es.light.1x/2x`.

**UX-2714 · fixed**
- (a) `_WaitingCard` has no button while preparing (render stopped-and-waiting: «Preparando tus notas…» with no button; `_Card` drops the bar and bottom padding is 16).
- (b) Discard is red on every card (`_DiscardButton`), and on the screen it already was.
- (c) `_After` shows `_AfterActions` for `allowanceUsed` too: render `after-stop.allowance-used.es.light.1x` has a red «Descartar».
- (d) `WrapCrossAlignment.center`: render `after-stop.pro-required.es.light.1x` shows «Ver Pro» and «Descartar» on one centre line, and the tester measured them within 1 dp.
- See R1-P322-1 and -2: the change opened two regressions next to this one.

**UX-2707 · fixed**
- `notes_screen.dart`: the row moved after the list content (it keeps `!readOnly && !recording` and `record-meeting`). The icon is `min(24, scale(18))`.
- Renders: `notes-tab.empty.es.light.1x` shows «Un lugar para tus ideas», then «Grabar una reunión». `notes-tab.list.es.light.1x` shows search, filter and notes first, with the row below the fold.
- `notes-tab.empty.es.light.2x` opens with the row half under the bottom edge, just above «Añadir nota». It is the last list item and scrolls fully into view, so this is scroll position, not clipping. Accepted: the brief puts the row there on purpose.

**UX-2801 · fixed (copy part); device check owed**
- `_AfterHelp` reads `reminderAccessProvider.capability().allowed`. When notifications are off, or before the phone answers, it shows `meetingPreparingHelpNoNotice` / `meetingWaitingConnectionHelpNoNotice`. With them on, it shows today's copy.
- Render `after-stop.preparing-no-notifications.es.light.1x`: «Tarda unos segundos. Puedes salir de esta pantalla: las notas aparecerán en Notas.»
- No permission request was added.
- Device check owed: Android 13+ with TaskFlow's notifications off.

## Regressions

**R1-P322-1 · S2 · Red «Descartar» fails contrast on the error card**
- Where: `_DiscardButton` (`meeting_banners.dart`) on `_Card(error: true)` (lost/expired). AUDIT `meetings/notes-lines · held-back` es.light.1x: «Descartar» 4.3:1, needs 4.5:1 (#b44238 on #ffdad6). Before this change it was teal, which passed.
- Fix: on an error card, draw Discard in `colorScheme.onErrorContainer`, or in a darker red that reaches 4.5:1 on #ffdad6. Keep `error` on the green cards (4.6:1 measured) and on the screen.

**R1-P322-2 · S2 · Discard also removed while the server keeps failing**
- Where: `_WaitingCard`, `preparing = problem == null || problem == MeetingProblem.server`. The brief said "when the meeting has no problem".
- `server` is set on every non-offline API error and retried with backoff (`meeting_uploader.dart` `_failed`, piece retries), so it can last hours. The meeting screen's `working` state has no actions either, which leaves only sign-out to drop such a recording. Before this change, the Notes card offered «Descartar».
- Fix: `preparing = meeting.problem == null`.

**R1-P322-3 · S2 · Older stopped recording reads «Grabación del mar, 3 nov»**
- Where: `meetingWhich` uses `context.weekdayDate` (`DateFormat.MMMEd`). An ES Tuesday gives «Grabación del mar, 3 nov, 10:15», which reads as "recording of the sea"; CA gives «Enregistrament del dt., 3 de nov., 10:15».
- `meeting_copy.dart` `meetingDate` already avoids exactly this, with the weekday in full, for the note title fixed in P321 / UX-2710: «Reunión del martes 3 nov, 10:15».
- Fix: format the day as `meetingDate` does, without its time: ES «Grabación del martes 3 nov, 10:15», CA «Enregistrament del dimarts 3 de nov., 10:15», EN "Recording from Tuesday, Nov 3, 10:15". The tester's «older» test expects `weekdayDate`, so it changes with the fix.

**R1-P322-4 · S1 · Discard sits left on one card and right on the next**
- Where: `MeetingStoppedActions` on the card (start-aligned) next to `_WaitingCard` (end-aligned). Render `notes-lines.stopped-and-waiting.es.light.1x`: the stopped card's «Descartar» is at the left edge, the «Esperando conexión» card's at the right, one card apart.
- Fix: on the card, align the stopped card's buttons to the end as the other cards do, with Descartar still last and apart; or start-align the waiting cards' Descartar. One edge for all.

**R1-P322-5 · S1 · Help line swaps text after the screen appears**
- Where: `_AfterHelp`. `_notices` is null until `capability()` answers (two platform calls), so the line first shows «…aparecerán en Notas» and then, for everyone with notifications on, changes to «…te avisaremos cuando estén listas». It is checked once, so it doesn't update after the person turns notifications on in Ajustes and comes back.
- Fix: until the answer, show only the shared first sentence (or reserve the line and leave it empty). Re-check on `AppLifecycleState.resumed`.

## Not regressions
- Notes 2× empty: the row is half under the fold (see UX-2707).
- Notes-lines es 2×: «Descartar la grabación de 42 min» is 151 × 2 dp in AUDIT. That is the viewport edge, not a cut target.
- Dark mode: no renders. By computation, #FFB4AA on #203F37 is 6.8:1.

## Memory notes
- The stopped-meeting choices are now `MeetingStoppedActions`, shared by the Notes card and the meeting screen (`centered`): filled «Hacer las notas», text «Seguir grabando», red «Descartar» 12 dp apart. `meetingWhich` says which recording.
- `_DiscardButton` is the one Discard on meeting cards, in `error`. Watch it on error (pink) cards.
- Recurring: new date copy that uses `weekdayDate` (MMMEd) in ES gives «del mar»; meeting copy uses `meetingDate`'s full weekday.
- Recurring: copy chosen by an async platform check flips after the first frame. Look for `bool?` state defaulting to one variant.
