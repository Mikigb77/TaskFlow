## UX loop report: 2026-10-14-speed, batch b1 (closed 2026-10-14)

**Verdict:** 17 of the 18 findings are verified in code.
- 10 are fully verified.
- 7 are verified in code but still need a check on a phone.
- UX-609 waits for an owner copy decision about Catalan line length. It is not a failed fix. Until the owner answers, its Catalan test in `App/test/capture_free_dictations_test.dart:1006` is the only failing test in the suite.

Three regressions appeared during the batch: R1A-1, which became UX-618; R1A-2, which became UX-619; and R2A-1, which became UX-620. All three were fixed and verified in later rounds. The round-3 review found no new regressions.

### Verified (the reviewer said "fixed" and no test for the finding fails)
| ID | Title | Round, package | Protected by test |
|---|---|---|---|
| UX-604 | Typed and saved-as-written dates miss common Spanish phrases | r1, P104 | `quick_schedule_parser_test.dart:254`, `capture_sheet_test.dart:1522` |
| UX-606 | An empty Notas field sits on every result | r1, P105 | `review_tasks_test.dart:1396` |
| UX-607 | Nothing shows the result's title can be corrected | r1, P105 | `review_tasks_test.dart:1518` |
| UX-608 | Fixing a day on the result takes three taps | r1, P105 | `review_tasks_test.dart:1575`, `schedule_editor_test.dart:449` |
| UX-612 | «Borrador» names the user's tasks in capture copy | r1, P106 | `localization_catalog_test.dart:162`, `capture_result_exits_test.dart:513` |
| UX-613 | An opened batch card shows its title twice | r1, P105 | `review_tasks_test.dart:1668` |
| UX-614 | «Volver a decirlo» opens typing at 0 left | r1, P106 | `capture_free_dictations_test.dart:1275` |
| UX-618 | A no-date time that has already passed is saved in the past (R1A-1) | r2, P107 | `quick_schedule_parser_test.dart:410` (7 cases), `capture_sheet_test.dart:1576` |
| UX-619 | Two parallel lines under the result's notes field (R1A-2) | r2, P108 | `review_tasks_test.dart:1708` (2) |
| UX-620 | No line between other rows and Más opciones (R2A-1) | r3, P109 | `review_tasks_test.dart:1781` (2) |

All 10 are protected by a test.

Notes:
- **UX-607:** the underline is shown in the renders. Whether newcomers actually notice it still needs real people in the UX_REVIEW §7 session.
- **UX-618:** the `localDrafts` doc comment is out of date. It is internal and not user-facing.

### Verified in code, still needing a phone (ledger status: device-check)
| ID | Title | Round, package | Protected by test |
|---|---|---|---|
| UX-601 | Saving waits for a full server sync | r1, P101 | `capture_landing_test.dart:610` |
| UX-610 | The wait between Listo and the result | r1, P101 | `native_speech_test.dart:1975`, `localization_catalog_test.dart:129` |
| UX-602 | A landing re-dates the next undated dictation | r1, P102 | `capture_sheet_test.dart:1619` (four D9 tests) |
| U5 | After saving, the user isn't shown the task | r1, P102 | `capture_landing_test.dart:128`, `localization_catalog_test.dart:147` |
| UX-603 | The mic opens late; first words can be lost | r1, P103 | `native_speech_test.dart:1637`, `voice_settings_test.dart:1107` |
| UX-611 | Widget and shortcuts after a cold start (P103's part) | r1, P103 | `capture_free_dictations_test.dart:1192` |
| UX-605 | Cancelar on a result silently keeps it pending | r1, P106 | `capture_result_exits_test.dart:121`, `localization_catalog_test.dart:191` |

Notes:
- **U5:** one known leftover, which is not a regression. When a capture has many dated tasks, the highlighted no-date row can sit below the fold, and the message doesn't mention it. Watch for this in §7 task 3.
- **UX-611:** the waits at app start-up and while the session is restored are still tracked as UX-424 (P30, not yet run).

### Still open
- **UX-609** (S2, A, decision) — "At 0 left, a 17-word line tops typing."
  - The copy is cut from 17 words to 7. Ver Pro and the live region are kept, and in all three languages the field stays above a 300 dp keyboard.
  - At 2× text on 320 dp, Spanish and English fit in 2 lines. The Catalan line «Fins al dia {date} no tens dictats gratuïts.» takes 3.
  - Owner question (plan.md, "Round 2 (b1)"):
    - (a) accept 3 lines in Catalan;
    - (b) use a shorter Catalan line, «Més dictats el dia {date}.», after a native speaker reads it;
    - (c) keep the wording and check only that the field stays visible.
  - Recommendation: (a) together with (c). If the owner agrees, ux-tester changes the Catalan check to "at most 3 lines, and the field stays above a 300 dp keyboard".
- This run's other owner questions are still in "Decision needed":
  - UX-615: should a result with nothing to ask save itself?
  - UX-616: the assistant's wait of about 5 s (a server and cost decision).
  - UX-617: should the first-run line teach that one dictation can hold several tasks?

### Escalations
None from repeated failures. No finding failed twice. UX-609 failed once and went to the owner as a copy decision; it was not escalated.

### Checks for the owner's phone
1. **UX-601:** on a slow connection, or with none, tap Guardar. The sheet closes and the task shows at once. Deshacer is just as fast.
2. **UX-610:** in diagnostics, read the p50 and p95 of «Last words after Done» over about 10 dictations. Do this before changing the 4-second wait for the last words.
3. **UX-602:** dictate «médico el viernes», then «comprar pan». The second task has no date.
4. **U5:** UX_REVIEW §7 tasks 2 and 3.
   - A dictation with tasks on several days, or with an undated task, highlights every landed row. The message names the other days.
   - With Android's "Remove animations" on, a task saved from Tareas sits fully above the message.
5. **UX-603:** tap the mic and speak straight away. «Escuchando» shows quickly and the first word is kept. Try after a cold start and with the app already open.
6. **UX-611:** from the home-screen widget and the shortcuts, count frames from the tap to «Escuchando», cold and warm. At 0 dictations left, typing opens with no spinner.
7. **UX-605:** on a result, use Android's back swipe. It asks Descartar / Conservar, and TalkBack reads the question.

### Files changed
- `App/lib/providers/task_provider.dart`
- `App/lib/providers/calendar_focus_provider.dart`
- `App/lib/screens/voice_task_screen.dart`
- `App/lib/screens/calendar_screen.dart`
- `App/lib/screens/captures_screen.dart`
- `App/lib/screens/voice_settings_screen.dart`
- `App/lib/services/capture_processor.dart`
- `App/lib/services/capture_diagnostics.dart`
- `App/lib/services/native_speech.dart`
- `App/lib/services/quick_schedule_parser.dart`
- `App/lib/widgets/task_actions.dart`
- `App/lib/widgets/capture_review_editor.dart`
- `App/lib/widgets/schedule_editor.dart`
- `App/android/app/src/main/kotlin/com/example/agenda/NativeSpeechBridge.kt`
- `App/lib/l10n/app_en.arb`, `app_es.arb`, `app_ca.arb`
- `App/lib/l10n/generated/*` (regenerated with `flutter gen-l10n`, not edited by hand)
- Tests:
  - `App/test/calendar_feedback_test.dart`
  - `App/test/capture_free_dictations_test.dart`
  - `App/test/capture_landing_test.dart`
  - `App/test/capture_result_exits_test.dart`
  - `App/test/capture_sheet_test.dart`
  - `App/test/localization_catalog_test.dart`
  - `App/test/native_speech_test.dart`
  - `App/test/quick_schedule_parser_test.dart`
  - `App/test/reminder_ask_sheet_test.dart`
  - `App/test/review_tasks_test.dart`
  - `App/test/schedule_editor_test.dart`
  - `App/test/voice_settings_test.dart`
- Ledger: `.claude/ux-review/ISSUES.md`

### Rounds
| Round | Packages | Tests | Reviewer result |
|---|---|---|---|
| 1 (`plan.json`) | P101–P106, all done | **Failed**: only the Catalan check for UX-609; the 14 other findings' tests pass | Fixed: UX-601, 610, 602, U5, 603, 611, 604, 606, 607, 608, 613, 605, 614, 612. Partly fixed: UX-609. Regressions: R1A-1 (S2, past times with no date word), which became UX-618; R1A-2 (S1, two lines under the notes), which became UX-619 |
| 2 (`plan-b1-r2.json`) | P107, P108, done | Passed (UX-618, UX-619) | Fixed: UX-618, UX-619. Regression: R2A-1 (S1, no separator above Más opciones under other rows), which became UX-620. UX-609 went to the owner as a decision |
| 3 (`plan-b1-r3.json`) | P109, done | Passed (UX-620) | Fixed: UX-620. No regressions |

Evidence used:
- unit and widget tests (ux-tester);
- code reading of `git diff HEAD`;
- rendered previews in `App/build/review-*.png`.

No emulator, physical phone or real microphone was used in this batch.

### Ledger changes
The 18 lines touched in `.claude/ux-review/ISSUES.md`:
- **Moved to Device check:** UX-601, UX-602, UX-603, UX-605, UX-610, UX-611, U5.
- **Moved to Verified:** UX-604, UX-606, UX-607, UX-608, UX-612, UX-613, UX-614, UX-618, UX-619, UX-620.
- **Stays in Decision needed:** UX-609, with a closing note added.

No line was deleted.
