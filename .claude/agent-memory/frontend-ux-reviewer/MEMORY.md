# frontend-ux-reviewer — memory index

Seeded on 2026-10-13 from `../UX_REVIEW.md`, which sits one folder above the repo root. Check each line against the code before relying on it.

## Owner decisions
- Calendar is the first screen (`App/docs/DESIGN.md`).
- The light/dark sun–moon switch is a deliberate feature. Where it lives is still open (UX_REVIEW §5.1).
- Proposed in UX_REVIEW §3 on 2026-10-12, not yet formally approved by the owner:
  - listening ends only when the user taps Done;
  - no separate transcript step — the user confirms the result, not the words;
  - the result appears in the same sheet;
  - after saving, the calendar shows the saved task.
- Undecided as of 2026-10-13:
  - **U13** — two tabs (Calendar + Lists), or keep Notes as its own tab;
  - **U14** — the login wall: put Google sign-in first, or allow local use before signing in.

## Open issues at seeding (UX_REVIEW IDs) — track status, don't re-report as new
- **U1** The mic stops after a ~3 s pause, or after a hesitation before speaking. One-shot recognizer session in `NativeSpeechBridge.kt`; `voice_task_screen.dart` ~348–352. OPEN
- **U2** "Finished" means two things: a manual Stop submits, an automatic stop leaves the words parked. OPEN
- **U3** A second mic waits on a separate capture page after tapping "Say a task". OPEN
- **U4** The result should appear in the same sheet, with the date as the most prominent line. OPEN
- **U5** After saving, the user isn't shown the task — the review screen pops back to whatever was underneath. OPEN
- **U6** The extraction prompt doesn't account for speech errors, and the recognizer gets no biasing strings. OPEN
- **U7** No "Save as written" fallback when the AI is slow or fails. OPEN
- **U8** Two creation buttons: "Say a task" and "New task". OPEN
- **U9** Technical options sit on the capture screen: engine, language, hold-to-talk, Task/Note. OPEN
- **U10** The home screen shows ~27 tap targets with no tasks; the bell and project chips appear without any groups. OPEN
- **U11** Naming: "Inbox" vs "Personal inbox"; "Unfinished captures"; Spanish "Lista para cuando tú quieras". OPEN
- **U12** No learn-by-doing first run; notification-permission timing. OPEN

## Patterns the app already uses — enforce consistency
- Undo snackbars for completing and saving. Snackbars sit above the capture bar.
- Date and time are edited together in one shared sheet (`lib/widgets/schedule_editor.dart`).
- All copy goes through `context.l10n`. English is the template; Spanish and Catalan are complete.
