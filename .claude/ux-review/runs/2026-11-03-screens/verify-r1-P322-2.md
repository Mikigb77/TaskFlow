# Verify · round 1 · P322 (area C) · check 2 · 2026-11-03

I read the worktree `.claude/worktrees/wf_b7a20ea0-e5f-12` through the waves.py diff, with the tester's re-rendered previews (`App/build/ux/meetings/`, 2026-11-04 00:04) and AUDIT.md. No `lib/` file is newer than the renders. I did not run Flutter. All evidence is from widget tests and renders, none from a device.

## Findings

**UX-2703 · fixed.** Same as check 1.
- `meetingWhich` (`App/lib/widgets/meeting_banners.dart`) now formats an older day with `meetingDay` (`App/lib/l10n/meeting_copy.dart`), the note title's day without its time.
- Render `notes-lines.stopped-and-waiting.es.light.1x`: «Grabación de ayer, 09:00 · 1 h 42 min. Se cortó antes de que pulsaras Parar.», then «Hacer las notas» (filled), «Seguir grabando», and a red «Descartar» 12 dp below.
- CA 2×: nothing is cut, and Descartar is last.

**UX-2714 · fixed.**
- «Preparando tus notas…» has no button. `_WaitingCard`: `preparing = meeting.problem == null`.
- Discard is red on the green cards and dark red on the error card.
- `allowanceUsed` offers Discard on the screen.
- In `after-stop.pro-required.es.light.1x`, «Ver Pro» and «Descartar» sit on one centre line.

**UX-2707 · fixed.** Unchanged since check 1: the row is last, and its icon scales.

**UX-2801 · fixed (copy part).**
- `_AfterHelp` (`App/lib/screens/meeting_screen.dart`) uses the NoNotice copy unless notifications are allowed.
- Render `after-stop.preparing-no-notifications.es.light.1x`.
- Device check still owed: Android 13+ with TaskFlow's notifications off.

## Regressions from check 1

- **R1-P322-1 · no longer holds.**
  - `_DiscardButton(onError: lost)` uses `colorScheme.onErrorContainer` on the error card, the colour that card's text uses.
  - AUDIT `meetings/notes-lines · held-back`: the contrast column is 0 for all 3 renders (check 1: 4.3:1).
  - Render `held-back.es.light.1x`: dark-red «Descartar» on pink.
- **R1-P322-2 · no longer holds.**
  - `_WaitingCard` hides Discard only when `problem == null`, so a recording held back by `server` errors offers «Descartar» in Notas again.
  - The meeting screen's `working` state still has no actions. That is unchanged by this package, and Notas is the way to discard.
- **R1-P322-3 · no longer holds.**
  - `meetingRecordingOn(meetingDay(...), time)` gives ES «Grabación del martes 3 nov, 10:15» and the CA/EN equivalents, the same day format as the note title (`meetingDate` now composes `meetingDay`, so the title's output is unchanged).
  - The test checks that the day differs from `weekdayDate` and has no comma.
- **R1-P322-4 · no longer holds.**
  - `_Card.alignment`: `_WaitingCard` passes `MainAxisAlignment.start`.
  - In renders `stopped-and-waiting.es.light.1x` and `held-back.es.light.1x`, every «Descartar» is at the left edge.
  - «Abrir» on the recording card stays right-aligned. That is navigation, not Discard, so it doesn't count.
- **R1-P322-5 · no longer holds.**
  - `_AfterHelp` sits inside `Visibility(visible: _notices != null, maintainSize: true)`, so no promise is shown, or swapped, before the phone answers.
  - `didChangeAppLifecycleState(resumed)` checks again.

## New regressions

None.

## Looked at, not raised

- The stopped card's buttons stack even at 1×: 154 + 8 + 138 dp is wider than the card's ~280 dp content. They read as a clear vertical order, so I accepted this in check 1.
- On the Pro card, «Ver Pro» now sits beside «Descartar» at the start instead of at the end edge. The order is unchanged and they are 8 dp apart, as before.

## Memory notes

- On an error (pink) meeting card, `_DiscardButton(onError: true)` uses `onErrorContainer`. Elsewhere it uses `error`.
- Meeting cards align their actions to the start (`_Card.alignment`). The recording card's «Abrir» keeps the end.
- `meetingDay` is the one day format for meeting copy (the stopped card and the note title).
- `_AfterHelp` holds its line blank until the phone answers, and re-checks when the app resumes: the pattern for copy that depends on a platform check.
