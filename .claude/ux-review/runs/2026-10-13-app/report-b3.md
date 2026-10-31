# UX loop report: run 2026-10-13-app, batch b3 (closed 2026-10-13)

**Verdict:** 30 findings were handled in three rounds:
- **22 verified.**
- **6 verified in code** that still need a phone check.
- **2 escalated:** U5 and UX-460. Tareas does now scroll the new task into view, but with animations off the task ends up partly under the "Añadida…" message.
- **1 new open regression:** UX-464, S2, from round 3. It wasn't planned because round 3 was the last round.

All three rounds ended with at least one failing test. The only failing test the verify notes name is in `capture_landing_test.dart`, for U5 on Tareas (round 1: the row isn't hit-testable; rounds 2–3: 'U5: with animations off…'). The round 3 summary says "failed" without naming the test. It's most likely the same U5 test, which wasn't re-planned, but that's inferred. Every finding below marked verified has its own tests passing.

## Verified (22)
| ID | Title | Round, package | Locked by test |
|---|---|---|---|
| UX-450 | Events retry line read as an enabled button while busy | r1, P58 | `calendar_feedback_test.dart:2190` |
| UX-206 | A moved task vanishes; the message names no day | r1, P9 | `calendar_feedback_test.dart:527` |
| UX-212 | Two date pickers and two repeat editors | r1, P9 | `calendar_feedback_test.dart:614`, `:672`, `:720`; `task_creation_test.dart:306` |
| UX-221 | Typed and picked times have AM/PM traps (the P9 part; the typed-time chips stay in P38) | r1, P9 | `quick_schedule_parser_test.dart:105`; `schedule_editor_test.dart:257`, `:276`, `:324` |
| UX-110 | AM/PM question shows four buttons | r1, P19 | `review_tasks_test.dart:702`, `:768`, `:802` |
| UX-116 | Batch cards hide questions and the remove button | r1, P19 | `review_tasks_test.dart:833` |
| UX-117 | Nothing left to review: disabled button, tiny exit | r1, P19/P36 | `review_tasks_test.dart:901` |
| UX-113 | Voice notes get the whole transcript as title | r1, P19 | `notes_test.dart:239`; `review_tasks_test.dart:1052` |
| UX-124 | "Task Title" casing; "Ver lo que dije" for typed text | r1, P19 | `review_tasks_test.dart:986` |
| UX-127 | "Más opciones" lists default values as if chosen | r1, P19 | `review_tasks_test.dart:1008` |
| UX-304 | Notes have no order; a new note lands anywhere | r1, P16 | `notes_ui_test.dart:286` (also covers the 12-note device check) |
| UX-313 | Dictating a note in a project ignores the project | r1, P16 | `notes_ui_test.dart:434` |
| UX-312 | Notes reuse wording written for tasks | r1, P16 | `notes_ui_test.dart:479`, `:520`, `:543` |
| UX-323 | Notes' project filter is an unlabelled dropdown | r1, P16 | `notes_ui_test.dart:479` |
| UX-337 | A permanent note-versus-task paragraph tops Notes | r1, P16 | `notes_ui_test.dart:558` |
| UX-434 | Search treats straight and curly apostrophes as different | r1, P16 | `text_search_test.dart:107-117` (an iPhone check is optional) |
| UX-453 | Moving: Hoy and Mañana apply at once, Sin fecha doesn't | r2, P61 | `calendar_feedback_test.dart:763`; `schedule_editor_test.dart:419` |
| UX-454 | Series help line names an Inbox control that's gone | r2, P61 | `calendar_feedback_test.dart:818` |
| UX-455 | Repeat sheet confirms "No se repite" with "Guardar repetición" | r2, P61 | `schedule_editor_test.dart:449` |
| UX-457 | The capture result has no visible way out | r2, P60 | `capture_result_exits_test.dart:140`, `:154` |
| UX-459 | New note jumps Notas to the top when not shown | r2, P62 | `notes_ui_test.dart:381`, `:409` |
| UX-463 | Sin fecha needs a second tap after an empty hour | r3, P64 | `calendar_feedback_test.dart:915`, `:930` |

A test now protects all 22 verified findings.

## Verified in code, still need a phone (6)
| ID | Title | Round, package | Test |
|---|---|---|---|
| U4 | The result isn't in the same sheet, and the date isn't the hero | r1, P36 (D3) | `review_tasks_test.dart:1073-1235`; `capture_landing_test.dart:91` |
| UX-452 | Listo seems dead when the a. m./p. m. error is off-screen | r2, P61 | `schedule_editor_test.dart:349` |
| UX-456 | Volver a decirlo discards the result, flush under Añadir | r2, P60 | `capture_result_exits_test.dart:61`, `:93`, `:154` |
| UX-458 | Result date line has no "date" name for TalkBack | r2, P60 | `capture_result_exits_test.dart:193` |
| UX-461 | Cancel while understanding re-said words leaves two pending | r3, P63 | `capture_result_exits_test.dart:285-363` |
| UX-462 | Date line hides disabled state from TalkBack while saving | r3, P63 | `capture_result_exits_test.dart:379` |

## Still open
- **UX-464 · S2 · A** · After Cancel, "Volver a decirlo" waits silently on the server. This is regression R3A-1 from P63, at `App/lib/screens/voice_task_screen.dart:856`.
  - **What happens:** the person taps Listo while listening, then Cancelar during "Entendiendo…". The sheet stays busy (`_stopping`) until the dropped understanding step answers, which can take 10 s or more. Until then, Volver a decirlo, Empezar a hablar and Escribir do nothing, and Cancelar waits too.
  - **Proposed fix:** in `_stopRecording`, call `unawaited(_process())`. Keep how `_discard` treats a first capture. No new strings.
  - **Evidence:** seen in the code; no test covers it yet.
  - **Status:** not planned, because round 3 was the last round. It goes first in the next run.

## Escalations (for the owner)
- **U5 · P0 · A** · After saving, the user isn't shown the task (Tareas only).
  - **Already working (verified):** the landing on Calendar, the two-day batch, and the pending list returning to Calendar.
  - **Attempt 1, P37 (round 1):** `showOnScreen` inside the NestedScrollView. Nothing moved.
  - **Attempt 2, P59 (round 2):** measures the row on screen, then moves the header, then the list. It passes with animations on, at 2× text, when the row already shows, and on Calendar.
  - **Still failing with animations off:** the row sits at y 427–550 and the message starts at y 503, so 47 of the row's 123 px are covered.
  - **Likely cause** (inferred from the code): `_messageTop` reads the message before it settles.
  - **Recommendation:** allow one narrow third attempt, in `home_screen.dart` only. Base the clearance on the message's final height (size.height + 8), with at most one correction, and keep the existing test unchanged.
  - **Failing test:** `capture_landing_test.dart` 'U5: with animations off…'.
  - **Owner question:** in plan.md Round 3 (b3).
- **UX-460 · S2 · A** · With animations off, the new Tareas row sits half under the save message. This is regression R2A-1 from P59, the part of U5 that failed twice, so it's escalated together with U5.

## Checks for the owner's phone
1. **U4:** UX_REVIEW §7 task 1. Say a task, and the result appears in the same sheet with the date as the largest line.
2. **U5:** UX_REVIEW §7 task 2. Save from capture on Tareas, and the new row shows in full. Repeat with Android's "Remove animations" on (UX-460).
3. **UX-452:** on a 12-hour clock with large text, type 5 and tap Listo. The keyboard drops, "Elige a. m. o p. m." shows, and TalkBack reads it.
4. **UX-456:** one-handed on the result, tapping Añadir never hits Volver a decirlo.
5. **UX-458:** TalkBack reads "Fecha y hora: Hoy, botón" on the result's date line.
6. **UX-461:** with real speech, tap Volver a decirlo, then Listo, then Back during "Entendiendo…". The previous result comes back, and Pendientes shows one capture.
7. **UX-462:** while saving, TalkBack says "desactivado" on the date line.
8. **UX-434 (optional):** a note typed on an iPhone with ’ is found from Android when searching with '.

## Files changed
- Screens:
  - `App/lib/screens/voice_task_screen.dart`
  - `App/lib/screens/home_screen.dart`
  - `App/lib/screens/calendar_screen.dart`
  - `App/lib/screens/main_shell.dart`
  - `App/lib/screens/captures_screen.dart`
  - `App/lib/screens/notes_screen.dart`
  - `App/lib/screens/review_tasks_screen.dart` (deleted)
- Widgets:
  - `App/lib/widgets/capture_review_editor.dart`
  - `App/lib/widgets/schedule_editor.dart`
  - `App/lib/widgets/repeat_rule_control.dart`
  - `App/lib/widgets/task_interactions.dart`
  - `App/lib/widgets/task_editor.dart`
  - `App/lib/widgets/task_actions.dart`
  - `App/lib/widgets/task_list.dart`
  - `App/lib/widgets/task_tile.dart`
  - `App/lib/widgets/task_schedule_label.dart`
  - `App/lib/widgets/app_components.dart`
  - `App/lib/widgets/device_calendar_events.dart`
- Providers and services:
  - `App/lib/providers/calendar_focus_provider.dart`
  - `App/lib/services/capture_processor.dart`
  - `App/lib/services/quick_schedule_parser.dart`
  - `App/lib/services/text_search.dart`
- Translations:
  - `App/lib/l10n/app_en.arb`, `app_es.arb`, `app_ca.arb`
  - `App/lib/l10n/generated/*` (regenerated by `flutter gen-l10n`, not edited by hand)
- Tests:
  - `App/test/capture_landing_test.dart`
  - `App/test/capture_result_exits_test.dart`
  - `App/test/review_tasks_test.dart`
  - `App/test/calendar_feedback_test.dart`
  - `App/test/schedule_editor_test.dart`
  - `App/test/quick_schedule_parser_test.dart`
  - `App/test/recurrence_controls_test.dart`
  - `App/test/task_creation_test.dart`
  - `App/test/notes_ui_test.dart`
  - `App/test/notes_test.dart`
  - `App/test/text_search_test.dart`
  - `App/test/appearance_test.dart`
  - `App/test/native_speech_test.dart`
  - `App/test/reminder_ask_sheet_test.dart`
  - `App/test/localization_catalog_test.dart`
  - `App/test/support/capture_fixtures.dart` (new)
- Integration tests: `App/integration_test/` backend_flow, capture_process_recovery, checklist_flow, notes_flow, planning_flow and projects_flow tests.

## Rounds
| Round | Packages | Tests | Result |
|---|---|---|---|
| 1 (plan.json) | P58, P19, P36, P37, P9, P16 | failed (the U5 Tareas test: the row isn't hit-testable) | 17 fixed; U5 only partly fixed. Regressions: R1B-1 to R1B-4 (UX-452 to UX-455), R1A-1 to R1A-3 (UX-456 to UX-458), R1C-1 (UX-459) |
| 2 (plan-b3-r2.json) | P59, P60, P61, P62 | failed ('U5: with animations off…') | 8 fixed; U5 only partly fixed. Regressions: R2A-1 (UX-460), R2A-2 (UX-461), R2A-3 (UX-462), R2B-1 (UX-463) |
| 3 (plan-b3-r3.json) | P63, P64 | failed (test not named; most likely the unchanged U5 test, inferred) | UX-461, UX-462 and UX-463 fixed. Regression: R3A-1 (UX-464). U5 and UX-460 escalated |

## Ledger
Updated `C:\Users\mikig\Desktop\Custom\MikiHacks\TaskFlow\TaskFlow\.claude\ux-review\ISSUES.md`:
- 22 lines moved to Verified and 6 to Device check.
- UX-464 added under Open.
- U5 and UX-460 left under Escalated; their lines were already current.
- No line deleted, and the file keeps its CRLF line endings.
