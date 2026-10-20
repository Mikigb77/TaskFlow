# UX loop run 2026-10-19-app, batch b3: report

**Verdict:** 21 of 23 findings are verified in code. 18 are done; 3 more still need a check on the phone. Two stay open: UX-1639 (S1, at 2× text the only «Sin hora» row is cut; failed once) and UX-1403 (S2, waiting on the owner as D12). Nothing was escalated. All the evidence is code, renders and widget/unit tests. There was no emulator or physical-device run in this batch.

## Verified (reviewer B said "fixed", and no test for it failed)

| ID | Title | Round, package |
|---|---|---|
| UX-1402 | The Día view opens on an empty night | r1, P180 |
| UX-1406 | A ticked task vanishes from Tareas at once | r1, P176 |
| UX-1407 | Completed tasks hide behind ✓ and ignore the project (merged UX-1511) | r1, P176 |
| UX-1413 | Reminder choices: a vague default and a clock dial | r1, P177 |
| UX-1415 | Task details put the notes last | r1, P179 |
| UX-1417 | Task detail's title is cut; edit and delete touch | r1, P179 |
| UX-1418 | Rows and counts show empty values and tiny labels | r1, P178 |
| UX-1419 | Lit rows' grey text drops to 4.39:1 | r1, P178 |
| UX-1420 | Overdue tasks in Tareas don't say so | r1, P178 |
| UX-1421 | Developer words in the task form's rarer corners | r2, P205 (r1 partly; re-checked r3, P208) |
| UX-1502 | «Todas las tareas» is ticked while only yours show | r1, P176 |
| UX-1512 | Project rows repeat the project; the assignee is bare | r1, P178 |
| UX-1633 | Día view opens scrolled past «Sin hora» and its banners (R1B-1) | r2, P202 (re-checked r3, P207) |
| UX-1634 | «Recordatorio para Ana» states this phone's default (R1B-2) | r2, P203 (re-checked r3, P208) |
| UX-1635 | Scoped Completed page hides the person filter (R1B-3) | r2, P204 (re-checked r3, P208) |
| UX-1636 | Scoped Completed rows repeat «Matemáticas» (R1B-4) | r2, P204 (re-checked r3, P208) |
| UX-1637 | View-only rows don't line up with other rows (R1B-5) | r2, P206 (re-checked r3, P208) |
| UX-1638 | «(100 MB)» breaks across lines on the refused card (R1B-6) | r2, P205 (re-checked r3, P208) |

**Verified in code, still needs a phone (`device-check`):**
- **UX-1505**: the reminder line promised reminders this phone won't give (r1, P177).
- **UX-1416**: task rows had unnamed gestures, and read-only rows looked disabled (r1, P178).
- **UX-1414**: freeing file space showed the files last and five look-alike buttons (r2, P205; re-checked r3, P208). Round 1 failed only on the catalog check, which flagged the strings about ownership transfer. P205 exempts those two strings; no copy changed.

## Still open
- **UX-1639** · S1 · at 2× text the only «Sin hora» row is cut (the regression R2B-1, caused by P202). P207 was partly fixed; failed 1 time.
  - **Done:** rows for the day being shown no longer say «Hoy», and a full-width line sits under the pinned area. At 1× the row is whole.
  - **Not met:** at 2× on 360×800, the label and the row need 226 dp, but the third of the screen gives about 197 dp. About 29 dp is cut through «Prioridad Media». The cut now ends at a visible line, and the scrollbar shows there is more.
  - **Next:** reviewer B's option is to cap the area at the larger of a third and the label plus the first whole row, and never more than half the screen. That gives 226 of 296 dp at 2×, and the 08:30 block still shows. This is the organizer's call in the next replan, because P207's brief fixed the cap at a third. It is not a product decision.
- **UX-1403** · S2 · Tareas at large text shows no task before the button. It stays a decision (D12 in plan.md, Round 2 (b3)). The recommendation is to wait for U13, unless the emulator check below closes it. Rounds 2 and 3 didn't re-check it, because what's left can only be checked on a device. The done parts have tests.

## Escalations
None.

## Checks for the owner's phone
- **UX-1403** (emulator lane `screen-tasks.list.es.light.2.0`, 393 dp, Android's non-linear 2.0 text): a whole task row shows, and «Tus tareas» / «Les teves tasques» fits on one line. If both hold, D12 closes as fixed.
- **UX-1639** (font size 2.0, 393 dp): on a Día view with one date-only task, the «Sin hora» row is whole. Android 14's non-linear scaling shrinks the day header, which may close this on its own.
- **UX-1633** (inferred from code only): at 2× with a load error, the calendar-access button and a full «Sin hora», the hours still get room above «Añadir tarea».
- **UX-1505** (two accounts): the assignee's phone rings.
- **UX-1416** (TalkBack): the actions menu on a task row offers «Cambiar fecha».
- **UX-1414** (a free account with full storage): removing one file uploads the refused one.
- **Not a phone check:** a native Catalan speaker should read the organizer's Catalan copy for UX-1421 (`changeSeriesQuestion`, `changeSeriesHelp`, `listEditingAccessHelp`, `viewOnlyNote`, `androidAlertRefreshHelp`, `backgroundAlertRefreshHelp`, `deferredAlerts`) and for UX-1634 («Recordatori per a {name}»).

## Files changed
- **Screens:**
  - `App/lib/screens/home_screen.dart`
  - `App/lib/screens/completed_tasks_screen.dart`
  - `App/lib/screens/day_timeline_screen.dart`
  - `App/lib/screens/task_detail_screen.dart`
  - `App/lib/screens/tasks_with_files_screen.dart`
- **Widgets:**
  - `App/lib/widgets/reminder_control.dart`
  - `App/lib/widgets/task_editor.dart`
  - `App/lib/widgets/task_tile.dart`
  - `App/lib/widgets/task_list.dart`
  - `App/lib/widgets/task_assignment_picker.dart`
  - `App/lib/widgets/task_list_picker.dart`
  - `App/lib/widgets/attachment_panel.dart`
  - `App/lib/widgets/task_planning_control.dart`
  - `App/lib/widgets/schedule_editor.dart`
  - `App/lib/widgets/device_calendar_events.dart`
- **Logic:**
  - `App/lib/services/task_database.dart`
  - `App/lib/l10n/region.dart`
- **Text:**
  - `App/lib/l10n/app_en.arb`, `app_es.arb`, `app_ca.arb`
  - `App/lib/l10n/generated/*`, regenerated by `flutter gen-l10n`, not edited by hand
- **Tests:**
  - `App/test/home_screen_test.dart`
  - `appearance_test.dart`
  - `capture_landing_test.dart`
  - `capture_sheet_test.dart`
  - `new_task_form_test.dart`
  - `project_people_filter_test.dart`
  - `settings_screen_test.dart`
  - `attachment_panel_test.dart`
  - `account_update_test.dart`
  - `calendar_feedback_test.dart`
  - `schedule_editor_test.dart`
  - `planning_ui_test.dart`
  - `reminder_settings_test.dart`
  - `task_rows_test.dart`
  - `task_detail_test.dart`
  - `tasks_with_files_test.dart`
  - `localization_catalog_test.dart`
  - `device_calendar_ui_test.dart`
  - `day_timeline_test.dart`
- **Previews:**
  - `App/test/ux_previews/calendar_previews.dart`
  - `tasks_previews.dart`
  - `commands_previews.dart`
  - `support/audit.dart`
- **Records:** `.claude/ux-review/ISSUES.md`

## Verified findings now protected by a test
Each test file below names the finding's ID at that line.

- **UX-1402:** `App/test/day_timeline_test.dart:179`, `:266`, `:286`, `:302`, `:323`, `:375`; `localization_catalog_test.dart:1455`
- **UX-1406:** `home_screen_test.dart:1358`, `:1399`, `:1425`; `appearance_test.dart:198`
- **UX-1407:** `home_screen_test.dart:1513`, `:1551`, `:1674`
- **UX-1413:** `reminder_settings_test.dart:1125`, `:1175`, `:1232`, `:1270`
- **UX-1415:** `task_detail_test.dart:745`, `:797`, `:834`
- **UX-1417:** `task_detail_test.dart:745`, `:865`, `:873`
- **UX-1418:** `task_rows_test.dart:412-552`; `capture_landing_test.dart:1169`
- **UX-1419:** `task_rows_test.dart:580`
- **UX-1420:** `task_rows_test.dart:629`, `:669`
- **UX-1421:** `localization_catalog_test.dart:1349-1665`; `schedule_editor_test.dart:521`, `:544`; `device_calendar_ui_test.dart:106`; `home_screen_test.dart:747`
- **UX-1502:** `home_screen_test.dart:1177` (es, en, ca)
- **UX-1512:** `task_rows_test.dart:491`, `:699`, `:729`, `:759`, `:801`
- **UX-1633:** `day_timeline_test.dart:408-611`; `capture_sheet_test.dart:1556`
- **UX-1634:** `reminder_settings_test.dart:817`, `:981-1116`
- **UX-1635:** `home_screen_test.dart:1686`, `:1751`, `:1797`
- **UX-1636:** `home_screen_test.dart:1686`, `:1877`
- **UX-1637:** `task_rows_test.dart:244`, `:333`
- **UX-1638:** `localization_catalog_test.dart:1487`, `:1501`, `:1531`
- **Device-check findings, code half:**
  - UX-1505: `reminder_settings_test.dart:779-969`
  - UX-1416: `task_rows_test.dart:162`, `:195`
  - UX-1414: `attachment_panel_test.dart:234-736`; `tasks_with_files_test.dart:458`; `localization_catalog_test.dart:1349`, `:1386`, `:1487`

## Rounds

| Round | Packages | Tests | Review B (verify-b3-rN-B) |
|---|---|---|---|
| 1 | P176 partly; P177, P178, P179, P180 done | **failed**; the not-yet findings UX-1403, UX-1414 and UX-1421 had no passing test | 14 fixed; UX-1403 and UX-1421 partly; UX-1414 not counted (the code was fixed, but its catalog check failed); 6 regressions R1B-1 to R1B-6, which became UX-1633 to UX-1638 |
| 2 | P202, P203, P204, P205, P206 done | **passed**; UX-1403 can only be checked on a device | all 8 fixed (UX-1633 to UX-1638, UX-1414, UX-1421); 1 regression, R2B-1, which became UX-1639 |
| 3 | P207 partly, P208 done | **failed**; UX-1639 was the only finding without a passing test | the 8 re-checked findings are still fixed; UX-1639 partly; no regressions |
