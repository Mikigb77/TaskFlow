# UX loop run 2026-11-04-screens: close

**Verdict:** All 7 findings were fixed and merged, and the final check after round 1 passed.
- 4 findings are verified: UX-2901, UX-2904, UX-3001 and UX-3002.
- 3 are verified in code but still need a phone: UX-2902, UX-2903 and UX-2905. UX-2813 moves to device-check with them.
- No regressions are open, no packages were set aside, and nothing was escalated.

Evidence: code, widget and unit tests, and preview renders. There was no emulator or phone.

## Verified
- **UX-2901** · S2 · C: the notification card never says what it asks (P327).
  - It is now one sentence that names the recording. ES: «Activa las notificaciones para parar la grabación desde ahí y saber cuándo están listas las notas.» EN and CA say the same; «Continuar» is unchanged.
  - The es, ca and en 2× renders fit the card, and AUDIT reports 0 problems.
- **UX-2904** · S2 · C: a stray tap outside the card spends the only ask (P327).
  - This card alone is now `barrierDismissible: false`.
  - Back still closes it without an Android ask (ON-6).
  - The TalkBack list no longer has «Cerrar».
- **UX-3001** · S1 · D: the hours line runs on from the example (P330).
  - The gaps on the Pro screen are now 4, then 8, then 12 dp.
  - In ES 1×, ES 2× and CA 2× the hours line reads as its own line and isn't clipped.
- **UX-3002** · S1 · D: "{hours} horas" has no ICU plural (P330).
  - `proBenefitMeetingNotes` and `billingReasonMeetingNotesLimit` are whole-sentence plurals (=1 and other) in EN, ES and CA.
  - The text at 20 is unchanged, and the INDEX prose is updated.

## Verified in code, phone check still owed (device-check)
- **UX-2902** · S2 · C: «Continuar» does nothing where Android shows no dialog (P327).
  - A refused ask, or one that throws, now shows «El teléfono no deja que TaskFlow te avise.» with «Permitir avisos», which opens settings.
  - Reminders are not switched on.
- **UX-2903** · S2 · C: a meeting note's main button changes on every open (P328).
  - `meetingNotesProvider` stays alive and is read in advance in `main_shell.dart`.
  - While the marks are still loading, the bar keeps «Crear tarea»'s place for any note with an open step.
- **UX-2905** · S1 · C: meeting notes saved before this update lose «Crear tarea» (P329).
  - Schema 23 marks the notes that a `meetings.note_id` row still links.
  - Notes whose row was already cleaned up stay unmarked, by design. Tell the owner in the release notes.
- **UX-2813** · S2 · D: no notification permission ask at the first meeting. All three of its fixes from P327 are in code, so it moves to device-check.

## Still open
None of this run's findings. The decisions UX-3003 (D2) and UX-3004 (D1) are still waiting for the owner, unchanged.

## Escalations
None.

## Checks for the owner's phone
1. **P327 (UX-2902, UX-2813):** check on Android 12 or lower, and on 13+ with notifications turned off in Settings or refused twice:
   - after «Continuar», the «Permitir avisos» line appears and its action opens settings;
   - after notifications are allowed mid-recording, the recording notification with Parar appears;
   - TalkBack focus and reading on the card are right.
   - The verifier also noted, without counting it as a regression: no preview shows the refusal line at 2×. For its timeout it covers the lower part of the recording screen (the help and D5 lines), never Parar. Look at that on the phone.
2. **P328 (UX-2903):** on the emulator or a phone:
   - open a meeting's note from Notas several times, and from the notes-ready notification on a cold start. A single «Editar nota» must never flash before «Crear tarea».
   - on a cold start, open a recipe note with open steps as fast as possible. Its bar must not visibly switch from outlined to filled.
3. **P329 (UX-2905):** install this build over the released staging build.
   - A meeting note saved earlier, whose meeting row still exists and which has open steps, offers «Crear tarea».
   - Notes whose row was already cleaned up don't.
4. **Carried over:** UX-2814, the lock screen at both Android settings.

## Verified findings with a test
- UX-2901: `App/test/meeting_screens_test.dart`, P327 group. It checks the exact copy, no title, one button, and that the card fits at 2× on 360×740.
- UX-2904: `App/test/meeting_screens_test.dart:4737` and `:4768`. They check scrim taps, Back, no permission request, and that the ask is spent.
- UX-2902: `App/test/meeting_screens_test.dart:4781`, `:4818` and `:4836`. They cover a refused ask, a throwing ask and a granted ask.
- UX-2903: `App/test/meeting_screens_test.dart:4312-4470`. They cover the first frame while the marks load (1× and 2×), the real shell opened twice, a note saved after the first read, and the recipe note.
- UX-2905: `App/test/meeting_core_test.dart:1232-1314`. They test the real `TaskDatabase()` upgrade from 22 to 23, a missing note, kept marks, a note linked twice and a fresh install.
- UX-3001 and UX-3002: `App/test/subscription_screen_test.dart`, P330 group. They check the gaps in ES 1×, ES 2× and CA 2×, and the plurals at 1, 2 and 20 in EN, ES and CA. The run summary lists these two as the ones proven by test.

## Packages set aside unmerged
None. P327, P328, P329 and P330 merged with no conflicts (`merges.jsonl`, 22:25 to 22:34). For P330 the merge skipped the generated l10n files; gen-l10n then reported "ok".

## Final checks
- After round 1: passed.

## Files changed
The main checkout's `git status` shows more files than the run summary listed. P330 also changed `App/lib/screens/subscription_screen.dart`, `App/test/subscription_screen_test.dart`, `App/test/ux_previews/reminders_previews.dart` and `App/test/ux_previews/settings_previews.dart`. The full set:
- `App/lib/l10n/app_ca.arb`, `App/lib/l10n/app_en.arb`, `App/lib/l10n/app_es.arb`
- `App/lib/l10n/generated/` (`app_localizations{,_ca,_en,_es}.dart`)
- `App/lib/screens/main_shell.dart`, `App/lib/screens/meeting_screen.dart`, `App/lib/screens/subscription_screen.dart`, `App/lib/screens/task_detail_screen.dart`
- `App/lib/services/task_database.dart`
- `App/lib/widgets/note_task.dart`
- `App/test/meeting_core_test.dart`, `App/test/meeting_screens_test.dart`, `App/test/subscription_screen_test.dart`, `App/test/support/note_task_fakes.dart`
- `App/test/ux_previews/meeting_previews.dart`, `App/test/ux_previews/reminders_previews.dart`, `App/test/ux_previews/settings_previews.dart`

## Notes
- Some verify steps for P327, P328 and P329 were sent again after their worktrees had been merged and removed. They re-checked read-only against the main checkout, and each verdict stayed the same.
- On those re-sent steps the tester ran nothing, because the worktree was gone. That isn't a test failure.
- The task's run paths had the repo root written twice. The real run folder is `/home/claude/TaskFlow/.claude/ux-review/runs/2026-11-04-screens`.
- Ledger: `.claude/ux-review/ISSUES.md`. 8 lines moved: UX-2901, UX-2904, UX-3001 and UX-3002 to Verified; UX-2813, UX-2902, UX-2903 and UX-2905 to Device check. Each line keeps its earlier note after "Before:".
