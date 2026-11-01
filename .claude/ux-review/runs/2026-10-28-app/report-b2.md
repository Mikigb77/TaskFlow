# UX loop report: 2026-10-28-app, batch b2 (P278–P289; round 2 P301–P305; round 3 P306–P307)

**Verdict:** Every finding in this batch is closed. The reviewer said "fixed" for all 50 (the batch's 37 findings plus the 13 regressions they caused). 44 are now `verified`. 6 are `device-check`: they are verified in code but still need a phone or the emulator. Nothing is escalated. Round 1's suite failed for two reasons. One was a broken return to today (UX-1628's test), filed as UX-2629 and fixed in round 2. The other was two old tests that still expected the old behaviour. Rounds 2 and 3 passed. The last suite run passed: 3548 tests, 4 skipped (`App/build/round-check/suite.log`). The evidence is code, widget and unit tests, and up-to-date preview renders with AUDIT.md. None of it comes from a device.

## Verified (44)
**Area B: calendar, home and tasks**
- **UX-2309**: at 2×, Día view blocks stay inside the screen. Two or more lanes scroll sideways, with a visible scrollbar (P278)
- **UX-2314**: the Día view has no current year and no stray dash, and TalkBack no longer reads every hour aloud (P278)
- **UX-2305**: task titles wrap in full at large text (P279)
- **UX-2313**: a passed deadline says «Venció el …» once, in grey (P279). The Catalan still wants a native read
- **UX-2312**: «Prioridad media», no-break counts, «1 completada», «Toca» (P279)
- **UX-2616**: «Necesita responsable» is drawn in the row's grey (P279)
- **UX-2407**: the repeat sheet's choices are five one-tap rows (P281)
- **UX-2413**: chips sit 8 dp apart at 2× (P281)
- **UX-2414**: the edit form's keyboard ✓ only closes the keyboard (P281)
- **UX-2419**: the attach sheet explains phone-only files only when the task has one (P281)
- **UX-2405**: «A tu manera» says, the first time, that its words go to Google's AI (P282)
- **UX-2412**: «Recordatorio» stays fixed at the top of the reminder sheet (P282)
- **UX-2409**: TalkBack reads a task's notes as «Notas» or «Tu nota» (P280)
- **UX-2410**: the task page shows one date row, with no «Sin hora» (P280)
- **UX-2416**: labels are one grey text line, not chips that do nothing (P280)
- **UX-2621**: regression. A divider separates the repeat choices from their details (P301)
- **UX-2622**: regression. Listo is pinned in view at 2× (P301)
- **UX-2624**: regression. «·» no longer dangles at the end of a line: «… noviembre» / «· 21:00» (P302)
- **UX-2632**: regression. The repeat sheet shows a scrollbar and an edge above Listo while its details overflow (P306)

**Area C: lists, notes, groups and sharing**
- **UX-2501**: in a project you can only view, Notas shows the read-only bar, and a note goes where Notas is showing (P283)
- **UX-2515**: the Notas filter reads «Todos los proyectos» and shows only once there's a note (P283)
- **UX-2502**: the sharing and group pages update when the server answers, show progress at the top and report errors as a message (P284)
- **UX-2511**: plain sharing copy, without the sync jargon (P284). The Catalan still wants a native read
- **UX-2513**: email addresses break at «.» and «@», not mid-word (P284)
- **UX-2518**: invitation and dialog buttons sit 8 dp apart (P284)
- **UX-2504**: the group delete and transfer dialogs say what happens (P285). The Catalan still wants a native read
- **UX-2505**: no character counters in the four dialogs (P285)
- **UX-2519**: section titles are headings for TalkBack (P285)
- **UX-2520**: a filled «Invitar a una persona» comes first on the group page (P285)
- **UX-2506**: Novedades no longer uses the people icon (P287; its final icon came from UX-2625)
- **UX-2508**: «Ana ha movido: …» when only the day changed (P287). Only the app half is done: see Still open
- **UX-2615**: TalkBack reads «Actividad» with its collapsed state, not as a separate stop (P287)
- **UX-2503**: a project's page has a ⋮ menu to edit, archive or delete it (P286)
- **UX-2516**: «Grupos» shows only once groups matter (P286)
- **UX-2517**: a new project's empty page has no search box (P286)
- **UX-2509**: a ✕ «Borrar búsqueda» in all four search fields (P288)
- **UX-2625**: regression. The Novedades icon is now `campaign_outlined` (P303)
- **UX-2626**: regression. Notas no longer calls a project that's gone «solo lectura» (P303)
- **UX-2627**: regression. An offline pull-to-refresh on a group page shows the network message (P303)
- **UX-2628**: regression. «Fijar proyecto» stays on Proyectos and is gone from the project page (P303)

**Area A/D: capture taps, theme and settings**
- **UX-2108**: every primary button is 60 dp, the form's included. Round 1 (P289) only partly fixed it, and it failed once; round 2 (P304) finished it
- **UX-2608**: two-line button labels are padded and centred at 2× (P289)
- **UX-2630**: regression. Each icon sits beside its label's longest line (P304)
- **UX-2631**: regression. The import button's outlined label is centred and padded at 2× (P304)

## Device check: verified in code, waiting for a phone or emulator (6)
- **UX-1416**: no unnamed swipe actions on task rows under TalkBack (P279)
- **UX-2406**: a changed edit form is saved when Android sends the app to the background (P281)
- **UX-2404**: Completar closes the task page, with «Deshacer» (P280)
- **UX-2623**: regression. A second tap on Completar no longer opens «Añadir tarea» (P302)
- **UX-2633**: regression. The task page takes no taps during the 300 ms hold (P307)
- **UX-2629**: regression. Return to today goes back to the top at 2× (P305)

## Still open
None of this batch's findings is still open. Still to do in this area:
- **UX-2508, server half (main session):** Novedades items need `fields`. Until the server sends them, Novedades always reads «ha actualizado».
- **UX-2629, a risk the fix leaves:** the fix holds the top after a return (`_holdTop`), but it doesn't cancel the landing reveal. The ledger's round-2 note said it did; that is now corrected. Someone who leaves within about a second of a landing's reveal and comes back 30 or more minutes later can still find the agenda mid-list. This risk existed before this run. The brief's `_revealRun` counter would close it. It is folded into UX-2629's phone check.
- **Filed at close, not yet planned:** both come from the reviewer's verify-b2-r2-D note 3. They are the same class of problem as UX-2608 and UX-2630, and this run didn't cause them.
  - **UX-2634** (S1, D): at 2×, the form's primary label «Añadir al / calendario» wraps left-aligned, with its ✓ stranded at the left edge (`App/lib/widgets/task_editor.dart:1208`).
  - **UX-2635** (S1, B): at CA 2×, the task page's reminder button wraps to four left-aligned lines, with its bell icon at the edge (`App/lib/screens/task_detail_screen.dart`).
- The Catalan of UX-2313, UX-2504 and UX-2511 wants a native speaker's read.
- The rest of run 2026-10-28-app (batch b3 P290–P295, and the D1/D2 packages P299–P300) is outside this batch.

## Escalations
None.

## Checks for the owner's phone (or the TaskFlow_Review emulator)
- **UX-1416**: with TalkBack, move through a long agenda. Rows should offer no unnamed «scroll left, scroll right», and «Cambiar fecha» should be in the actions menu.
- **UX-2406**: turn on Developer options › «No conservar actividades». Edit a task, switch to another app, then come back. The change should be saved.
- **UX-2404**: open a task from a reminder notification and tap Completar. The page should close back to the list, with «Deshacer».
- **UX-2623**: on the emulator, then the phone, double-tap Completar. «Añadir tarea» should not open, and the microphone should not start.
- **UX-2633**: on the emulator, then the phone, with TalkBack: tap Completar, then quickly double-tap ✏. Nothing should open.
- **UX-2629**: the UX-1628 overnight check at the largest font. Save a task for Friday, leave, and reopen after 31 minutes or more: the agenda should be at the top of today. Repeat once leaving straight after the save.

## Files changed
App code:
- `App/lib/screens/`: `activity_screen.dart`, `calendar_screen.dart`, `data_transfer_screen.dart`, `day_timeline_screen.dart`, `device_calendars_screen.dart`, `groups_screen.dart`, `home_screen.dart`, `invitation_review_screen.dart`, `list_sharing_screen.dart`, `notes_screen.dart`, `notification_settings_screen.dart`, `subscription_screen.dart`, `task_detail_screen.dart`, `task_lists_screen.dart`, `voice_task_screen.dart`
- `App/lib/widgets/`: `app_components.dart`, `capture_review_editor.dart`, `invitation_cards.dart`, `note_text.dart`, `project_scope_control.dart`, `reminder_control.dart`, `reminder_plan_sheet.dart`, `repeat_rule_control.dart`, `schedule_editor.dart`, `search_clear.dart` (new), `task_actions.dart`, `task_editor.dart`, `task_list_picker.dart`, `task_tile.dart`
- `App/lib/theme/app_theme.dart`
- `App/lib/providers/regional_provider.dart`
- `App/lib/l10n/`: `region.dart`, `request_locale.dart`, `app_{en,es,ca}.arb`, and `generated/app_localizations{,_en,_es,_ca}.dart` (regenerated by `flutter gen-l10n`, not edited by hand)

Tests:
- `App/test/`: `activity_screen_test.dart`, `appearance_test.dart`, `attachment_panel_test.dart`, `bulk_voice_commands_test.dart`, `calendar_feedback_test.dart`, `capture_landing_test.dart`, `capture_sheet_test.dart`, `data_transfer_screen_test.dart`, `day_timeline_test.dart`, `device_calendar_ui_test.dart`, `groups_screen_test.dart`, `home_screen_test.dart`, `invitation_review_test.dart`, `localization_catalog_test.dart`, `new_task_form_test.dart`, `notes_ui_test.dart`, `project_scope_control_test.dart`, `recurrence_controls_test.dart`, `reminder_plan_sheet_test.dart`, `reminder_settings_test.dart`, `review_tasks_test.dart`, `sharing_ui_test.dart`, `subscription_screen_test.dart`, `task_creation_test.dart`, `task_detail_test.dart`, `task_editor_form_test.dart`, `task_lists_widget_test.dart`, `task_rows_test.dart`, `task_schedule_label_test.dart`, `voice_privacy_copy_test.dart`, `voice_settings_test.dart`
- `App/test/support/` (new): `button_label.dart`, `icon_button_label.dart`, `no_counter.dart`, `search_clear.dart`
- `App/test/ux_previews/`: `{calendar,form,notes,reminders,sharing,tasks}_previews.dart`, `support/app.dart`

**Before you commit:** the workflow's `filesChanged` list leaves out 6 files this batch changed. The verify notes and the diffs confirm they belong to it:
- `App/lib/widgets/app_components.dart` (UX-2519, `SectionLabel` as a heading)
- `App/lib/widgets/task_list_picker.dart` (UX-2505, `counterText`)
- `App/test/attachment_panel_test.dart` (UX-2419)
- `App/test/capture_sheet_test.dart` (UX-2108)
- `App/test/reminder_settings_test.dart` (UX-2608, UX-2108)
- `App/test/support/button_label.dart` (used by seven of this batch's tests)

Stage these too. If you don't, the commit will reference a missing test helper and carry only part of P285 and P289. `git status` shows no other session's uncommitted work.

Records:
- `.claude/ux-review/ISSUES.md`
- `runs/2026-10-28-app/plan.md`, `plan-b2-r2.json` and `plan-b2-r3.json`
- the `verify-b2-*.md` files

## Verified findings now protected by a test
A test protects all 50, the 6 device-check findings included. All files are under `App/test/`.
- **UX-2309, UX-2314**: `day_timeline_test.dart`
- **UX-2305, UX-1416, UX-2616**: `task_rows_test.dart`
- **UX-2313**: `task_rows_test.dart`, `calendar_feedback_test.dart`, `day_timeline_test.dart`, `task_schedule_label_test.dart`, `localization_catalog_test.dart`
- **UX-2312**: `task_rows_test.dart`, `review_tasks_test.dart`, `task_editor_form_test.dart`, `localization_catalog_test.dart`
- **UX-2406, UX-2414**: `new_task_form_test.dart`
- **UX-2407**: `task_editor_form_test.dart`, `task_creation_test.dart`
- **UX-2413**: `new_task_form_test.dart`, `task_editor_form_test.dart`
- **UX-2419**: `new_task_form_test.dart`, `task_editor_form_test.dart`, `attachment_panel_test.dart`
- **UX-2405**: `reminder_plan_sheet_test.dart`, `voice_settings_test.dart`
- **UX-2412**: `reminder_plan_sheet_test.dart`
- **UX-2404**: `task_detail_test.dart`, `appearance_test.dart`, `reminder_plan_sheet_test.dart`
- **UX-2409, UX-2416, UX-2623, UX-2624, UX-2633**: `task_detail_test.dart`
- **UX-2410**: `task_detail_test.dart`, `task_creation_test.dart`
- **UX-2501, UX-2515, UX-2626**: `notes_ui_test.dart`
- **UX-2502**: `sharing_ui_test.dart`, `groups_screen_test.dart`
- **UX-2511**: `sharing_ui_test.dart`, `invitation_review_test.dart`, `localization_catalog_test.dart`
- **UX-2513, UX-2518**: `sharing_ui_test.dart`, `groups_screen_test.dart`, `invitation_review_test.dart`
- **UX-2504, UX-2520, UX-2627**: `groups_screen_test.dart`
- **UX-2505**: `groups_screen_test.dart`, `invitation_review_test.dart`, `task_lists_widget_test.dart`
- **UX-2519**: `groups_screen_test.dart`, `sharing_ui_test.dart`
- **UX-2506, UX-2508, UX-2615, UX-2625**: `activity_screen_test.dart`
- **UX-2503**: `task_lists_widget_test.dart`, `sharing_ui_test.dart`
- **UX-2516, UX-2628**: `task_lists_widget_test.dart`
- **UX-2517**: `home_screen_test.dart`
- **UX-2509**: `home_screen_test.dart`, `notes_ui_test.dart`, `task_lists_widget_test.dart`, `project_scope_control_test.dart`
- **UX-2608**: `appearance_test.dart`, `subscription_screen_test.dart`, `data_transfer_screen_test.dart`, `device_calendar_ui_test.dart`, `reminder_settings_test.dart`
- **UX-2108**: `appearance_test.dart`, `capture_sheet_test.dart`, `new_task_form_test.dart`, `task_editor_form_test.dart`, `task_detail_test.dart`, `subscription_screen_test.dart`, `data_transfer_screen_test.dart`, `device_calendar_ui_test.dart`, `reminder_settings_test.dart`
- **UX-2621, UX-2622, UX-2632**: `recurrence_controls_test.dart`
- **UX-2629**: `capture_landing_test.dart` (31-minute return at 2.0×, 1.5× and 1.3× on four sizes; the 5-minute sibling; the original UX-1628 test)
- **UX-2630**: `subscription_screen_test.dart`, `data_transfer_screen_test.dart`, `device_calendar_ui_test.dart`
- **UX-2631**: `data_transfer_screen_test.dart`, `task_detail_test.dart`

## Rounds
**Round 1:** 12 packages, P278–P289, in 4 waves of 7, 2, 2 and 1.
- Packages: all done.
- Tests: **failed**, in three tests:
  - UX-1628's 31-minute return at ES 2× ended at 321 dp instead of 0. The cause was traced to P289's taller buttons, and the failure was filed as UX-2629.
  - `task_creation_test.dart:64` and `appearance_test.dart:343` still expected the old task page (a «Hora» row; «Reabrir» after Completar). They were updated to UX-2410 and UX-2404.
- Verification: 36 fixed; UX-2108 partly fixed (the form's ElevatedButton was still 54 dp).
- Regressions:
  - R1B1-1 became UX-2621
  - R1B1-2 became UX-2622
  - R1B2-1 became UX-2623
  - R1B2-2 became UX-2624
  - R1C1-1 became UX-2625
  - R1C1-2 became UX-2626
  - R1C1-3 became UX-2627
  - R1C2-1 became UX-2628
  - R1D-1 became UX-2629
  - R1D-2 became UX-2630
  - R1D-3 became UX-2631

**Round 2:** 5 packages, P301–P305, in 1 wave.
- Tests: **passed**.
- Verification: UX-2108 and UX-2621 to UX-2631 fixed.
- Regressions:
  - R2B-1 became UX-2632
  - R2B-2 became UX-2633

**Round 3:** 2 packages, P306–P307, in 1 wave.
- Tests: **passed**: the whole suite, 3548 passed and 4 skipped.
- Verification: UX-2632 and UX-2633 fixed; no regressions.

## Reviewer notes, not filed (no IDs; for the next review to weigh)
- **Día view deadline blocks** use tertiary on surfaceContainer. The reviewer thinks this is likely above 4.5:1, but it wasn't measured: no timeline preview has a deadline block.
- **Pages with no TaskActions under a leaving task page** (Activity, the Notes list, Tasks with files) have no guard of their own. Only a tap more than 300 ms after Completar, during the exit transition, could reach them. The AbsorbPointer added in round 3 reduces this further.
- **The `auth/` renders are out of date** (06:19, older than the theme change). The Google button now takes the theme's extra height (about 56 dp, 20 dp padding); this is inferred from code and looks harmless. Re-render `auth/` to confirm.
- **Invitations at es/ca 2×:** «Aceptar invitación» is cut at the viewport edge (`invitation.from-ana`). The page scrolls, and this was there before the run.
- **The group page's «Eliminar grupo» row**, while off, keeps full-contrast text. It was there before the run, and its subtitle explains why the row is off.
- **On a gone-project filter in Notas**, a new note is saved with no project, so the list doesn't land on it; «Nota guardada» is the only feedback. The brief accepted this.
- **A project page for a gone project** still shows the read-only bar, so it now differs from Notas (UX-2626). This is the project page's own long-standing rule.
- **The group delete dialog at 2×** shows the title «Eliminar grupo» above «¿Eliminar…?». It is redundant, but it follows the brief (UX-2504).
- **The repeat sheet at 1× with no weekday chosen** shows the scroll cue, because the start-date hint pushes «Sin fecha de fin» 16 dp under the edge. The cue is accurate.
- **The Exportar e importar buttons at 2×** are as wide as their content and differ in width (about 267 and 293 dp). Polish only.
- **A stale preview description:** `App/test/ux_previews/sharing_previews.dart:64` still says «from the people button on Calendar». It's only a description, never shown to users.
- **The Tareas search query survives a tab switch.** One tap on ✕ now clears it (UX-2509); the implementer left this out on purpose.
