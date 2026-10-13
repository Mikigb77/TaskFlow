# UX loop 2026-10-13-app, batch 2: run report

**Verdict:** Batch 2 closed all 30 of its findings. That's the 19 package findings plus the 11 regressions UX-439 to UX-449. For each one, the last reviewer to check it said "fixed", and no test for it failed. 20 are **verified**. 10 are verified in code and still need **your phone**. One new small regression is still open (UX-450). I also logged one older issue a reviewer noticed in passing (UX-451). Nothing was escalated.

**Caveat:**
- The round 3 fixes (UX-447, UX-448, UX-449) passed their tests, but the round summary lists them as "unchecked", so no round check ran after round 3.
- Both round 3 reviewers also wrote that ux-tester hadn't reported test results to them yet.
- Run the full `flutter test` before committing this batch.

## Verified (20)
All 20 are protected by a test.

| ID | Title | Package / round | Test |
|---|---|---|---|
| U3 | A second mic waits on a separate capture page | P35 / r1 | `native_speech_test.dart:878`, `:964` |
| U2 | "Finished" means two things; automatic stops park the words | P35 / r1 | `native_speech_test.dart:993-1138` |
| UX-105 | At large text, live words are off-screen | P35 / r1 (also seen in a 2× render) | `native_speech_test.dart:1302`, `review_tasks_test.dart:371` |
| UX-126 | Discard sits under the primary; its dialog favours Discard | P35 / r1 | `native_speech_test.dart:1153` |
| UX-440 | Seguir shows on shared and resumed text never listened to | P54 / r2 | `native_speech_test.dart:1401`, `:1433` |
| UX-444 | English silence hint is cut at 2× text | P54 / r2 | `native_speech_test.dart:1568`, `:1579` |
| UX-111 | Review date has no weekday | P7 / r1 | `task_schedule_label_test.dart:12-78` |
| UX-205 | After typing a task, nothing shows where it went | P7 / r1 | `calendar_feedback_test.dart:1009`, `:1104` |
| UX-217 | Phone-calendar events sit above the day's tasks | P6 / r1 | `calendar_feedback_test.dart:700`, `:787` |
| UX-220 | Completed tasks jump away; Completed list is oldest first | P7 / r1 | `calendar_feedback_test.dart:1253-1325` |
| UX-226 | Passed deadlines and calendar dots rely on colour alone | P6 / r1 | `calendar_feedback_test.dart:910`, `:941` |
| UX-442 | Events error line says refresh but opens calendar choice | P52 / r2 | `calendar_feedback_test.dart:1495`, `:1558` |
| UX-445 | Tile shows schedule and deadline dates in two formats | P52 / r2 | `task_schedule_label_test.dart:84` |
| UX-447 | Events retry collapses the line; no sign it tried | P57 / r3 | `calendar_feedback_test.dart:1584-1751` |
| UX-302 | One tap shares a private task, with no way back | P12 / r1 | `project_ui_test.dart:283`, `:343`, `:361` |
| UX-308 | Projects hide behind an unlabelled icon; the picker dead-ends | P12 r1 (partly), P53 / r2 | `home_screen_test.dart:186-303`, `project_ui_test.dart:302`, `task_lists_widget_test.dart:258` |
| UX-324 | The project chip has no tap cue; warning repeats | P12 / r1 | `project_ui_test.dart:289`, `:307` |
| UX-325 | Assistant doubt about project or person shown as an error | P12 / r1 | `project_ui_test.dart:400` |
| UX-443 | A project shared without a group looks private | P53 / r2 | `project_ui_test.dart:449` |
| UX-448 | A replacing message lets the question cover its Undo | P56 / r3 | `reminder_ask_sheet_test.dart:643-741` |

UX-438 was verified in batch 1, and I rechecked it here.
- The card and its test file are gone.
- The new sheet asks only right after a dated save, so "antes" always refers to the task just saved.
- `reminder_ask_sheet_test.dart` now covers that copy. Its ledger line now points at `reminder_ask_sheet.dart:140`.

## Verified in code, waiting for your phone (10)
All 10 are protected by a test.

| ID | Title | Package / round | Test |
|---|---|---|---|
| UX-401 | Reminders off by default; nothing asks to turn them on | P51 / r1 | `reminder_ask_sheet_test.dart:124-352`, `reminder_settings_test.dart:562-602` |
| UX-439 | First dated save: reminders sheet hides the landing and Undo | P55 / r2 | `reminder_ask_sheet_test.dart:399-555` |
| UX-449 | Reminders question can open on another tab | P56 / r3 | `reminder_ask_sheet_test.dart:744`, `:777` |
| U6 | No speech-aware extraction or recognizer biasing (the app side) | P3 / r1 | `native_speech_test.dart:763-844`, `capture_recovery_test.dart:550` |
| UX-109 | TalkBack: listening auto-starts; no cues; mismatched mic labels | P35 / r1 | `native_speech_test.dart:941`, `:1169` |
| UX-441 | TalkBack says "Listo" when the user cancels or types | P54 / r2 | `native_speech_test.dart:1503-1539` |
| UX-202 | Today's tasks start below the fold | P6 r1 (partly), P52 / r2 | `calendar_feedback_test.dart:551-641`, `:1370-1436` |
| UX-203 | The calendar stays on yesterday after midnight | P7 / r1 | `calendar_feedback_test.dart:1137-1199` |
| UX-218 | Offline shows a red error about a "server address" | P6 / r1 | `calendar_feedback_test.dart:820-895` |
| UX-446 | View switcher is read as "Mostrar menú" by TalkBack | P52 / r2 | `calendar_feedback_test.dart:1457` |

U6's speech-only prompt change in `Backend/core/ai.py` is server-side and outside this loop.

## Still open
- **UX-450** · S1 · B · The events retry line is read as an enabled button while busy · `App/lib/widgets/device_calendar_events.dart:126`
  - This is regression R3B-1 from P57. It was found in round 3, the last round, so nothing was planned for it.
  - The fix is ready to plan: `Semantics(button: true, enabled: onTap != null, …)`, with no new string.
  - The test to add: a semantics check that the line is disabled while a retry runs.
- **UX-451** · S2 · A · Recognizer errors are silent to TalkBack · `App/lib/screens/voice_task_screen.dart:1098`
  - verify-b2-r2-A noticed this in passing; it is older than P54.
  - The error banner isn't a live region, and nothing is announced.
  - I'd fold it into P40 with UX-103.

I added notes from verify-b2-r2-C to two existing open lines:
- **UX-225** (P22): the `archived` key now labels projects, but still reads ES "Archivada" / CA "Arxivada". Check that no task uses the key before switching to "Archivado" / "Arxivat".
- **UX-334** (P26): on the Projects screen, a project shared person by person reads "Proyectos compartidos · Editor" (`task_lists_screen.dart:230`). The picker says "Compartido", so use `sharedProject` there too.

Reviewers noticed these too and chose not to count them, so they have no ledger line:
- After a successful phone-calendar retry, the events line blinks out briefly while the day's events load.
- If the read hangs, the spinner can't be tapped for 15 s or more.
- The voice review asks the reminder question only when nothing is left to review.
- Two dated saves within one message window push the question to the third save.
- If the 60 s limit hits with no words heard, TalkBack says "Listo".
- A stray tap on the scrim counts as an answer to the reminder question; watch for it on the phone check.

## Escalations
None. No finding failed twice in this batch. UX-202 and UX-308 each failed once, in round 1, and passed in round 2.

## Checks for your phone
Use Spanish unless a check says otherwise.
1. **UX-401, UX-439, UX-449** (reminder question; one session on a fresh account):
   - At the first dated save, the row lights up and Deshacer can be tapped before the question opens.
   - TalkBack reads the question once.
   - "Sí" leads to the Android 13+ notification dialog, and the reminder arrives on time.
   - Separately, make a first dated save on Calendario and switch to Notas within 4 s. No question appears there, and the next dated save asks.
2. **U6:** on Android 13+, dictate project names, people and days. They should come out spelled right more often than before.
3. **UX-109:** with TalkBack, open capture. It doesn't start listening by itself, "Empezar a hablar" has focus, and starting announces that it's listening.
4. **UX-441:** with TalkBack:
   - Cancelar with words is silent before the keep-or-discard question.
   - Listo says "Listo".
   - Leaving the app says "En pausa".
5. **UX-446:** with TalkBack, the "Semana ▾" button reads "Cambiar vista".
6. **UX-202:** at 1.3× text on a phone about 390×844, two of today's tasks sit fully above the buttons.
7. **UX-218:** in airplane mode, open Calendar and try signing in. There's no red banner and no "server address".
8. **UX-203:** leave Calendar on today in recent apps overnight. When reopened, it shows the new day.

## Files changed
- **App code:**
  - New: `App/lib/widgets/reminder_ask_sheet.dart`, `App/lib/providers/calendar_focus_provider.dart`, `App/lib/providers/shell_tab_provider.dart`.
  - Deleted: `App/lib/widgets/reminder_ask_card.dart`.
  - `App/lib/screens/`: calendar_screen, captures_screen, completed_tasks_screen, day_timeline_screen, home_screen, login_screen, main_shell, notes_screen, review_tasks_screen, task_detail_screen, task_lists_screen, voice_task_screen.
  - `App/lib/widgets/`: device_calendar_events, project_scope_control, task_actions, task_assignment_picker, task_editor, task_list, task_list_picker, task_planning_control, task_schedule_label, task_tile.
  - `App/lib/providers/`: reminder_provider, task_provider.
  - `App/lib/services/`: capture_processor, capture_store, native_speech, reminder_preferences.
  - Also: `App/lib/models/capture_session.dart` and `App/lib/main.dart`.
- **Native:** `App/android/app/src/main/kotlin/com/example/agenda/NativeSpeechBridge.kt`.
- **Translations:** `App/lib/l10n/app_en.arb`, `app_es.arb`, `app_ca.arb`, `region.dart` and `request_locale.dart`. `App/lib/l10n/generated/*` was regenerated by `flutter gen-l10n`, not edited by hand.
- **Unit and widget tests:**
  - New: `App/test/reminder_ask_sheet_test.dart`.
  - Deleted: `App/test/reminder_ask_card_test.dart`.
  - Changed: reminder_settings, native_speech, capture_recovery, review_tasks, calendar_feedback, home_screen, project_ui, task_lists_widget, task_schedule_label, task_creation, appearance, device_calendar_ui, regional_ui and language_selector (all `_test.dart`), plus `support/design_fixtures.dart`.
- **Integration tests:** appearance, backend_flow, capture_language, capture_process_recovery, device_calendar_flow, native_speech_flow, notes_flow, projects_flow and regional_flow (all `_test.dart`).
- **Ledger:** `.claude/ux-review/ISSUES.md`.

## Rounds
- **Round 1:**
  - Ran P51, P3, P35, P6, P7 and P12.
  - Tests: the round check failed on 5 new tests, UX-202 at 1.3× Spanish (light and dark) and UX-308 at 2× on 320 dp (es, ca, en).
  - Results: 17 findings fixed and 2 partly fixed (UX-202, UX-308).
  - Regressions: 9, which became 8 ledger lines, UX-439 to UX-446, because R1D-1 and R1B-1 are the same problem.
- **Round 2:**
  - Ran P52, P53, P54 and P55.
  - Tests: all passed.
  - Results: all 10 findings fixed (UX-202, UX-308, UX-439 to UX-446).
  - Regressions: 3, now UX-447 to UX-449.
- **Round 3:**
  - Ran P56 and P57.
  - Tests: passed for UX-447, UX-448 and UX-449; no round check ran afterwards.
  - Results: all 3 fixed.
  - Regressions: 1 (R3B-1), now UX-450.
