## UX loop report: run 2026-10-28-app, batch b3 (closed 2026-11-01)

**Verdict:** All 25 findings in this batch were fixed according to the reviewer. 16 are verified. 9 are verified in code but still need a phone or emulator check. Round 3 introduced two regressions in the entry-absorption rules for the widget and shortcuts, UX-2643 (S2) and UX-2644 (S1); both are open and not yet planned. Nothing was escalated. All evidence is from widget and unit tests, preview renders and AUDIT.md. None of it comes from the emulator or a physical phone.

### Verified (16)
| ID | Sev | Title | Package / round |
|---|---|---|---|
| UX-2603 | S2 | The Pro screen names two of Pro's three benefits | P290 / r1 |
| UX-2605 | S2 | Ajustes' Pro row shows billing words, not the plan | P290 / r1 |
| UX-2606 | S2 | First screen says «Inicia sesión» to people without an account | P291 / r1 |
| UX-2607 | S1 | Pro copy: a literal line, a split unit, a trial | P290 / r1 |
| UX-2610 | S1 | Phone calendars: a caveats paragraph; addresses split mid-word | P295 / r1 |
| UX-2611 | S1 | Recovery's two links touch | P291 / r1 |
| UX-2613 | S1 | Spanish widget help doesn't name the widget | P295 / r1 |
| UX-2417 | S1 | The plan offer splits «mié, 18 de nov» across lines | P293 / r1 |
| UX-2418 | S1 | Spanish «Eliminar» on a file that isn't deleted | P293 / r1 |
| UX-2510 | S1 | Notes moved, locked or deleted are called «tarea» | P294 / r1 |
| UX-2514 | S1 | Pickers mark the current choice by colour alone | P294 / r1 |
| UX-2614 | S1 | Task page's project and person chips wrap 4 dp apart | P294 / r1 |
| UX-2636 | S2 | Spoken words' card says «Según lo que has escrito» (regression R1A-1) | P309 / r2 |
| UX-2638 | S1 | Re-ticking a reopened row jumps to Completadas' top (R1B-1) | P310 / r2 |
| UX-2639 | S1 | Project sheet's last row «Nuevo proyecto» half hidden (R1C-1) | P311 / r2 |
| UX-2640 | S1 | At 2× Pro's benefit list hides the plan status (R1D-1) | P312 / r2 |

### Verified in code, still needing a device (9)
| ID | Sev | Title | Package / round | Phone or emulator check |
|---|---|---|---|---|
| UX-2110 | S1 | Two quick widget taps open two capture sheets | P292 r1 (partly fixed), P308 r2 (fixed), held through P313 r3 | Free account: double-tap «Escribir una tarea» → one form; Back → Calendar. Double-tap the widget (Pro, and free with 0 left) → one sheet or form |
| UX-2112 | S1 | Launcher shortcut icons show a 5 dp glyph | P292 / r1 | Debug build on the emulator, `launcher.shortcuts.es.light.{1.0,2.0}`: no white ring, glyph at least 14 dp. The resources were not compiled and have not been seen on a launcher |
| UX-2311 | S2 | Completadas lists today's undated tasks last | P300 / r1 | TaskFlow_Review emulator with the local API at migration 0026: tick a task offline, sync later; the server's `completed_at` is the time of the tick |
| UX-2415 | S1 | TalkBack reads each step twice in the form | P293 / r1 | TalkBack reads each checklist step once in the task form |
| UX-2609 | S1 | Language sheet stays open while reminders are rewritten | P295 / r1 | With many reminders, switch the language: the sheet closes at once, and reminders show in the new language shortly after. The background rewrite is not tested |
| UX-2612 | S2 | «Guardar como tarea» saves its one task unseen | P299 / r1 | Dictate in airplane mode, tap «Guardar como tarea» → a result card appears and nothing is saved until «Añadir al calendario»; TalkBack reads the card |
| UX-2637 | S2 | A voice tap is swallowed by an empty typing sheet (R1A-2) | P308 / r2, held through r3 | Pro: open «Escribir una tarea» from the shortcut, go Home, tap the widget's mic → one sheet, listening |
| UX-2641 | S2 | A text tap closes a voice sheet holding a recording (R2A-1) | P313 / r3 | Pro with online listening forced: mic, then the shortcut, then Cancelar → «Grabación conservada en este teléfono» |
| UX-2642 | S2 | Outside tap lands in an empty form opened for something else (R2A-2) | P313 / r3 | At 0 dictations left: shortcut, then the widget's mic → one form showing the used-up line. Open a form on a picked day, then use the shortcut → a blank form opens over it, and Back shows the day |

### Still open
- **UX-2643** · S2 · A: An entry closes a titleless form holding a date or photo (regression R3A-1 of P313, `App/lib/main.dart:220`).
  - P313 pops a blank entry form whose title is empty when the entry doesn't take it. A date, reminder, checklist or attachment picked in that form is lost without asking.
  - Fix suggested by the reviewer: close only a form where nothing changed (`_edited().toMap()` against `_unchanged`); otherwise open the entry's form over it.
  - Verified in code; no test or render covers it.
- **UX-2644** · S1 · A: Voice, text, voice taps stack two voice sheets (regression R3A-2 of P313, `App/lib/main.dart:204`).
  - The close-first pop uncovers the paused recorded voice sheet, but the entry still opens a second voice sheet and recorder over it. Nothing is lost.
  - Fix suggested by the reviewer: after the pop, check the top again and acknowledge the entry if an empty sheet of the asked mode is now current.
  - Inferred from code; no test.
- I filed three reviewer notes as S1 issues. They were not caused by this run and are not yet planned:
  - **UX-2645** (B): the remove-file dialog's help line `fileRemoveHelp` still says «Se eliminará de la tarea…». It could say «Se quitará…».
  - **UX-2646** (B): a row reopened on Completadas and then ticked on its own task page is stamped with the current time, because `task_detail_screen.dart:64` calls `toggle` without `doneAt`.
  - **UX-2647** (C): the titles of the «¿Quién es responsable?» and «Novedades del proyecto» sheets are plain rows, not headings.

### Escalations
None.

### Checks for the owner's phone
The nine rows of the device table above. The four entry-flow checks (UX-2110, UX-2637, UX-2641, UX-2642) can be run in one session on the TaskFlow_Review emulator and then a phone. UX-2311 needs the local API at migration 0026.

### Files changed
- **App code:**
  - `App/lib/main.dart`, `App/lib/screens/{subscription,settings,login,voice_task,task_detail,device_calendars,completed_tasks,edit_task}_screen.dart`;
  - `App/lib/widgets/{checklist_editor,reminder_ask_sheet,task_list_picker,task_assignment_picker,project_scope_control,project_preferences,language_selector,task_editor,task_form_entry,task_interactions,task_tile,task_list}.dart`;
  - `App/lib/models/task.dart`, `App/lib/models/task_schedule_change.dart`, `App/lib/services/task_database.dart`, `App/lib/services/reminder_engine.dart`, `App/lib/providers/task_provider.dart`.
- **Copy:** `App/lib/l10n/app_{en,es,ca}.arb`, with `App/lib/l10n/generated/*` regenerated by `flutter gen-l10n`.
- **Android:** `App/android/app/src/main/res/drawable-anydpi-v26/capture_shortcut_{voice,text}.xml`, `App/android/app/src/main/res/drawable/capture_shortcut_{voice,text}_foreground.xml`, `App/android/app/src/main/kotlin/com/example/agenda/CaptureShortcuts.kt`.
- **Tests:**
  - `App/test/{subscription_screen,settings_screen,reminder_plan_sheet,reminder_ask_sheet,capture_free_dictations,capture_sheet,attachment_panel,attachment_store,account_update,auth_gate,notes_ui,task_detail,voice_command_cards,native_resources,sync,reminder_plans,reminder_engine,project_assignment,project_scope_control,checklist,device_calendar_ui,language_selector,archive,calendar_feedback,email_verification}_test.dart`;
  - `App/test/support/design_fixtures.dart`;
  - `App/test/ux_previews/{settings,reminders,auth,tasks,notes,capture,commands,calendar}_previews.dart`.
- **Ledger:** `.claude/ux-review/ISSUES.md`.

### Verified findings locked by a test
All 25 closed findings are covered by passing tests in `App/test/`:
- UX-2603, UX-2607, UX-2640: subscription_screen_test.dart
- UX-2605, UX-2613: settings_screen_test.dart
- UX-2606, UX-2611: auth_gate_test.dart
- UX-2610: device_calendar_ui_test.dart
- UX-2609: language_selector_test.dart
- UX-2417: reminder_ask_sheet_test.dart, reminder_plan_sheet_test.dart
- UX-2418: attachment_panel_test.dart
- UX-2510, UX-2614: task_detail_test.dart
- UX-2514: project_scope_control_test.dart, voice_command_cards_test.dart
- UX-2639: project_scope_control_test.dart
- UX-2415: checklist_test.dart
- UX-2311: sync_test.dart, reminder_engine_test.dart, archive_test.dart, calendar_feedback_test.dart
- UX-2638: calendar_feedback_test.dart
- UX-2612: capture_sheet_test.dart, voice_command_cards_test.dart, capture_free_dictations_test.dart
- UX-2636, UX-2637, UX-2641: capture_sheet_test.dart
- UX-2110, UX-2642: capture_sheet_test.dart, capture_free_dictations_test.dart
- UX-2112: native_resources_test.dart (resources only)

UX-2032, UX-2203, UX-2618, UX-2619 and UX-2620 were verified in earlier batches. Their tests passed again in round 1, and I left their ledger lines unchanged.

### Rounds
| Round | Packages | Tests | Reviewer result | Regressions |
|---|---|---|---|---|
| 1 | P290, P291, P292, P293, P294, P295, P299, P300 (one wave of 8) | passed | 17 fixed; UX-2110 partly fixed (the free account's form path) | R1A-1 → UX-2636, R1A-2 → UX-2637, R1B-1 → UX-2638, R1C-1 → UX-2639, R1D-1 → UX-2640 |
| 2 | P308, P309, P310, P311, P312 (one wave of 5) | passed | 6 fixed: UX-2110, UX-2636, UX-2637, UX-2638, UX-2639, UX-2640 | R2A-1 → UX-2641, R2A-2 → UX-2642 |
| 3 | P313 (one package) | passed | 2 fixed: UX-2641, UX-2642 | R3A-1 → UX-2643, R3A-2 → UX-2644 (open) |
