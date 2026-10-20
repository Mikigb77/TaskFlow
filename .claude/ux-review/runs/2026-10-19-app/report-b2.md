## UX loop 2026-10-19-app: batch b2 report (close, 2026-10-20)

**Verdict:** batch b2 is closed. All 17 findings are fixed, and their tests pass after round 2. That's 14 planned findings plus 3 regressions from round 1, which round 2 fixed. 9 are fully verified. 8 are verified in code but still need a phone or emulator check. Nothing in this batch is still open. Nothing failed twice, so nothing was escalated. The evidence is code, widget and unit tests, preview renders and `App/build/ux/AUDIT.md`. Nothing was checked on a device or an emulator.

### Verified (the reviewer said fixed; no test failed)
- **UX-1311** · S2 · A: the capture controls and «Descartar» / «Conservar» no longer touch. There are 8 dp under «Sin guardar · N», 12 dp under the filled buttons, 8 dp between stacked actions, and the chips sit 8 dp apart (P171).
- **UX-1313** · S2 · A: when typing at 2×, the first typed line sits right under the field's border, because the hidden example no longer keeps its size (P171).
- **UX-1314** · S2 · A: the project question's chips wrap to 2 lines and start at the card's edge. «Crear «Mates»», «Otro proyecto…» and «Un altre projecte…» show whole at 2× (P172).
- **UX-1315** · S2 · A: «En Mates…» now offers «Matemáticas» and «Matemáticas II». The server's `project_candidates` come first, and a 4-letter match is the fallback. The server half is in commit 2d5d998 (P172).
- **UX-1317** · S2 · A: each «Sin guardar» row now reads its time, then «Nota», then what's left, e.g. «Ayer, 09:41 · 2 sin añadir». `captureResumeHelp` is gone (P174).
- **UX-1318** · S1 · A: rare capture errors now use plain copy with a next step in all three languages. `captureUnsupportedKind` and `captureSpeechBusy` are removed (P173).
- **UX-1409** · S2 · B: another month's days now look like the month's own, in light and dark (P175).
- **UX-1412** · S2 · B: tapping a day in Mes goes back to Semana on that day, with its tasks in view (P175).
- **UX-1631** · S1 · A (regression R1A-2 from P173): a failed save now reads `captureSaveFailed`, and only offline keeps its own line (P200).

### Verified in code; a phone or emulator check is still owed (`device-check`)
- **UX-1307** · S2 · A: six dictations in a minute now get «too fast» rather than the daily limit. A Retry-After of 120 s or less means too fast, no Retry-After means unavailable, and anything longer means the daily limit. The server half is in commit 2d5d998 (P173).
- **UX-1310** · S2 · A: every account gets the same controls: the full-width filled action, then Cancelar and a labelled «Escribir». The unlabelled keyboard icon is gone (P171).
- **UX-1321** · S1 · A: TalkBack polish:
  - the words field is labelled;
  - pick rows read as buttons;
  - the ✕ reads «No cambiar ninguna» / «No eliminar ninguna», and in Catalan «No en canviïs cap» / «No en suprimeixis cap» (P171).
- **UX-1408** · S2 · B: at large text the week strip no longer cuts days or numbers. Its heights follow the text size, narrow weekdays appear only when needed, and the cells are 48 dp at 360 dp (P175).
- **UX-1410** · S2 · B: TalkBack now hears which day is selected, today, and each day's task count («hoy · 4 tareas»). Mes shows other months' days as labelled targets, long-press picks a day, and the arrows read «Semana/Mes anterior/siguiente» (P175).
- **UX-1411** · S2 · B: each tab now announces its name («Calendario», «Tareas», «Notas», «Ajustes») as a heading, not «taskflow» (P175).
- **UX-1630** · S2 · A (regression R1A-1 from P173): when a recording with no words hits the daily limit, the sheet shows `captureAllowanceRecording` and a single «Cerrar». Reopened later, it offers «Reintentar» (P200).
- **UX-1632** · S2 · B (regression R1B-1 from P175): TalkBack's count for today now includes the overdue tasks the agenda lists. It reads «hoy · 10 tareas» above «10 pendientes · 1 completada» (P201).

### Still open
None from this batch. The rest of run 2026-10-19-app's open findings belong to later batches.

### Escalations
None.

### Noticed by the reviewer but not raised (for a later review, not counted)
- `captureAllowanceRecording`'s «Inténtalo mañana» doesn't say where the recording waits. The reviewer suggested a short clause such as ES «…; mañana la encontrarás en Capturas pendientes.» The same gap exists for recordings that wait for free dictations (verify-b2-r2-A).
- `captureTooLarge` and `captureIncompleteAudio` say «Descártala», but the sheet's button is «Cancelar», which then asks with «Descartar». It's 2 taps and it's the plan's copy (verify-b2-r1-A).
- In `cards.project-question.ca.light.2x`, P168's reveal scrolls the question's first line under the sticky header. This cost was already accepted in verify-b1-r1-A.

### Checks for the owner's phone (or the emulator, where marked)
- **Capture controls (UX-1310):** one-handed use of Listo, Cancelar and Escribir.
- **TalkBack in capture and command cards (UX-1321):** what TalkBack actually says for the words field, the pick rows and the ✕.
- **Staging (UX-1307):** seven dictations within a minute get the «too fast» line, not the daily limit.
- **Staging (UX-1630):** an account at its daily limit, with online speech, dictates. Only «Cerrar» shows. Reopened the next day, the capture offers «Reintentar».
- **Week strip (UX-1408):**
  - on the emulator at 360 dp and 2.0 (non-linear text), nothing is cut;
  - on an `es_ES` phone the narrow weekdays read «L M X J V S D». The previews use `es_US`, which gives «L M M J V S D».
- **Selected day (UX-1410):** `selected=true` shows in the uiautomator tree.
- **Tab names (UX-1411):** TalkBack's first line on each tab is the tab's name.
- **Today's count (UX-1632):** with an overdue task, TalkBack's count for today matches the agenda's count line.

### Files changed
- Screens:
  - `App/lib/screens/voice_task_screen.dart`
  - `App/lib/screens/calendar_screen.dart`
  - `App/lib/screens/captures_screen.dart`
  - `App/lib/screens/regional_settings_screen.dart`
- Widgets:
  - `App/lib/widgets/task_actions.dart`
  - `App/lib/widgets/capture_command_cards.dart`
  - `App/lib/widgets/custom_app_bar.dart`
- Logic:
  - `App/lib/models/capture_command.dart`
  - `App/lib/services/capture_problem.dart`
- Text:
  - `App/lib/l10n/capture_messages.dart`
  - `App/lib/l10n/region.dart`
  - `App/lib/l10n/app_en.arb`, `app_es.arb`, `app_ca.arb`
  - `App/lib/l10n/generated/app_localizations*.dart`, regenerated by `flutter gen-l10n`, not edited by hand
- Tests:
  - `App/test/capture_sheet_test.dart`
  - `App/test/capture_free_dictations_test.dart`
  - `App/test/capture_landing_test.dart`
  - `App/test/capture_result_exits_test.dart`
  - `App/test/native_speech_test.dart`
  - `App/test/new_task_form_test.dart`
  - `App/test/review_tasks_test.dart`
  - `App/test/voice_command_cards_test.dart`
  - `App/test/calendar_feedback_test.dart`
  - `App/test/day_timeline_test.dart`
  - `App/test/main_shell_test.dart`
  - `App/test/localization_catalog_test.dart`
  - `App/test/captures_screen_test.dart` (new)
- Previews:
  - `App/test/ux_previews/capture_previews.dart`
  - `App/test/ux_previews/calendar_previews.dart`
- Ledger: `.claude/ux-review/ISSUES.md`

### Findings now protected by a test
Every finding in this batch has a test:
- **UX-1307:** `capture_sheet_test.dart:2380`, `:2428`, `:2463`
- **UX-1310:** `capture_sheet_test.dart:2284`, `:2339`, `:2667`
- **UX-1311:** `capture_sheet_test.dart:2307`; `capture_result_exits_test.dart:197`
- **UX-1313:** `capture_sheet_test.dart:2361`, `:2704`
- **UX-1314:** `voice_command_cards_test.dart:6666`, `:6678`
- **UX-1315:** `voice_command_cards_test.dart:243`, `:6503-6623`
- **UX-1317:** `captures_screen_test.dart:143`, `:165`, `:191`
- **UX-1318:** `capture_sheet_test.dart:2256`, `:2521`, `:2572`; `voice_command_cards_test.dart:6723`; `localization_catalog_test.dart:1274`
- **UX-1321:** `capture_sheet_test.dart:2255`, `:2353`; `voice_command_cards_test.dart:6403`, `:6414`, `:6445`, `:6495`
- **UX-1408:** `calendar_feedback_test.dart:3209`, `:3306`
- **UX-1409:** `calendar_feedback_test.dart:3325`
- **UX-1410:** `calendar_feedback_test.dart:3169`, `:3352`, `:3415`, `:3434`
- **UX-1411:** `main_shell_test.dart:373`, `:378`
- **UX-1412:** `calendar_feedback_test.dart:3170`, `:3464`, `:3495`
- **UX-1630:** `capture_free_dictations_test.dart:2927-3127`; `capture_sheet_test.dart:2478`; `localization_catalog_test.dart:1314`
- **UX-1631:** `voice_command_cards_test.dart:6756`, `:6763`, `:6781`
- **UX-1632:** `calendar_feedback_test.dart:3545-3707`

### Rounds
- **Round 1** (`plan.json`):
  - Packages, all done:
    - P171: capture controls, spacing, typing field, TalkBack (UX-1310, UX-1311, UX-1313, UX-1321)
    - P172: the project question (UX-1314, UX-1315)
    - P173: capture errors (UX-1307, UX-1318)
    - P174: Capturas pendientes (UX-1317)
    - P175: the week strip and tab headings (UX-1408 to UX-1412)
  - Tests passed.
  - 14 of 14 fixed (verify-b2-r1-A, verify-b2-r1-B).
  - 3 regressions:
    - R1A-1 became UX-1630;
    - R1A-2 became UX-1631;
    - R1B-1 became UX-1632.
- **Round 2** (`plan-b2-r2.json`):
  - Packages, both done:
    - P200: UX-1630 and UX-1631
    - P201: UX-1632
  - Tests passed.
  - 3 of 3 fixed (verify-b2-r2-A, verify-b2-r2-B).
  - No regressions.
