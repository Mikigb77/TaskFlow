# UX loop report: 2026-10-28-app, batch b1 (P266–P277, round 2 P296–P298)

**Verdict:** Every finding in this batch is closed. The reviewer said "fixed" for all 39: 31 are now `verified` and 8 are `device-check` (verified in code, still to be checked on a phone or emulator). Nothing is escalated. Round 1's one failing test (UX-2203 at 360×800) and its three regressions were fixed in round 2, and round 2's tests passed. Evidence comes from code, widget and unit tests, and current preview renders with AUDIT. None of it was gathered on a device.

## Verified (31)
- **UX-2102**: Cancelar during «Entendiendo…» now asks before keeping the words (P273)
- **UX-2103**: «Guardar como tarea» is a quiet button while the words are being understood, and filled only after a failure (P273)
- **UX-2104**: the offline and unavailable lines now match what the buttons do (P273)
- **UX-2105**: kept words are «conservadas», never «guardadas» (P273)
- **UX-2106**: the microphone ring shows only while something is listening (P266)
- **UX-2109**: at 2× text, the error banner shows whole and only the words scroll (P273)
- **UX-2111**: the first-use privacy line names Google's AI and where to read more (P266)
- **UX-2113**: the online listening hint is honest (P266)
- **UX-2201**: set cards show every row, with no inner scroll (P267)
- **UX-2202**: Deshacer after a voice deletion restores the task without reopening the sheet (P274)
- **UX-2203**: the added message names the day Calendar lands on, «2 tareas añadidas al … · también el …» (round 1 P274 was partial; round 2 P297 finished it)
- **UX-2204**: «¿Cuál…?» answers are outlined choices, each at least 48 dp tall (P267)
- **UX-2205**: an 8 dp gap before a row's ✕ and around «Activar recordatorios» (P275)
- **UX-2206**: a reminder row that names itself no longer has «Recordatorio» over it (P270)
- **UX-2207**: a dictated note's field is labelled «Tu nota» (P275)
- **UX-2208**: «Quitar» is gone from «Más opciones», and the repeat row of a task with no date now says what it needs (P275)
- **UX-2209**: change lines name their field, for example «Prioridad: Media → Alta» (P267)
- **UX-2210**: cards that found nothing show the search icon (P267)
- **UX-2212**: while a time question is open, the row shows only the day (P275)
- **UX-2213**: «Han vuelto aquí» is a plural that follows the count (P274)
- **UX-2301**: ticks and moves show at once and no longer wait for the server (P268)
- **UX-2302**: the day's own tasks come before «Atrasadas» (P269)
- **UX-2303**: the day's last tick says «Todo listo. Respira.» (WD34, P269)
- **UX-2304**: ticked overdue rows and reopened completed rows stay in place until you leave the page (P269)
- **UX-2307**: a task given a day from Sin fecha lands on Calendar (P276)
- **UX-2308**: one «Sin fecha» rule: no day and no deadline (P276)
- **UX-2310**: a failed event read offers «Toca para reintentar»; the dead red banner is gone (P277)
- **UX-2411**: a deadline task's chip reads «{lead} · fecha límite» (P270)
- **UX-2618**: round-1 regression. At 2×, «¿Cuál…?» now opens with its ✕ in view (P297)
- **UX-2619**: round-1 regression. After Deshacer on a voice deletion, Calendar shows the task that came back, highlighted (P297)
- **UX-2620**: round-1 regression. «Añade una fecha para repetir» opens the date sheet (P298)

## Device check: verified in code, waiting for a phone or emulator (8)
- **UX-2101**: «Escribir» on the online path (P266)
- **UX-2107**: TalkBack's announcements kept out of the open microphone (P266)
- **UX-2211**: TalkBack is told when «Más opciones» or a card is expanded (P275)
- **UX-2306**: phone events listed by name, with «Cerrar» on both sheets (P277)
- **UX-2401**: tapping a reminder lands on «Recordatorio enviado» (P270)
- **UX-2403**: a reader's notice has no «Completar», and no copy is made (P271)
- **UX-2601**: allowing notifications in Android turns reminders on when you come back (P272)
- **UX-2032**: a reader can choose their own reminders, even when the owner changed the task first (round 1 P271 was partial; round 2 P296 finished it)

## Still open
None from this batch. The rest of run 2026-10-28-app still has to be done, as RESUME.md lists: batch b2 (P278–P289), batch b3 (P290–P295), the re-plan for D1 (UX-2612) and D2 (UX-2311's app half), and the main-session items D14 and preview item 5.

## Escalations
None.

## Checks for the owner's phone (or the TaskFlow_Review emulator lane)
- **UX-2101**: on the emulator, `capture.listening.ca` at 1.0 and 2.0 shows «Escriu». Tapping it after speaking asks whether to keep or discard.
- **UX-2107**: with TalkBack on a phone, the transcript contains neither «Escuchando» nor «Quedan», and the pulse at 50 s can be felt.
- **UX-2211**: with TalkBack on TaskFlow_Review, a collapsed result-card title is read as «Contraído». The title carries only the expanded flag, so whether it is read depends on the TalkBack version.
- **UX-2306**: on the emulator, `permission-calendar.calendar-after` at ES 1.0 and 2.0 shows both event names. The two event sheets were judged from code and tests only; no render shows them.
- **UX-2401**: on the emulator, "reminder rings → tap the notice" shows «Recordatorio enviado». Check that D1's «Sin recordatorio» line doesn't flash for a frame while the alerts load.
- **UX-2403**: with two accounts on the emulator lane, a reader's notice shows only «Posponer 10 min», and no «(copia local)» appears after a sync.
- **UX-2601**: on the emulator, «Sí» → «No permitir» → «Permitir avisos» → allow in Android → back shows «Listo. Recordatorios activados.», and Ajustes shows «Activados · 10 minutos antes». The pending request is held only in memory, so if Android kills the app process while the person is in its settings, they come back with reminders off. That is the old behaviour, with no wrong message.
- **UX-2032**: with two accounts, the reader goes offline, the owner renames the task, the reader sets «1 hora antes», then goes back online. Expected: no copy, no notice, the new title, and only the reader's phone rings, with «Posponer 10 min».

## Files changed
These are all uncommitted on `ux-in-progress`, on top of b0de7c8.

App code:
- `App/lib/screens/calendar_screen.dart`
- `App/lib/screens/voice_task_screen.dart`
- `App/lib/screens/day_timeline_screen.dart`
- `App/lib/screens/device_calendars_screen.dart`
- `App/lib/screens/notification_settings_screen.dart`
- `App/lib/widgets/capture_command_cards.dart`
- `App/lib/widgets/capture_review_editor.dart`
- `App/lib/widgets/device_calendar_events.dart`
- `App/lib/widgets/reminder_control.dart`
- `App/lib/providers/reminder_provider.dart`
- `App/lib/repositories/cloud_task_repository.dart`
- `App/lib/services/capture_store.dart`
- `App/lib/services/reminder_engine.dart`
- `App/lib/services/task_database.dart`
- `App/lib/l10n/app_{en,es,ca}.arb`
- `App/lib/l10n/generated/app_localizations{,_en,_es,_ca}.dart`

Tests:
- `App/test/bulk_voice_commands_test.dart`
- `App/test/calendar_feedback_test.dart`
- `App/test/capture_free_dictations_test.dart`
- `App/test/capture_landing_test.dart`
- `App/test/capture_result_exits_test.dart`
- `App/test/day_timeline_test.dart`
- `App/test/device_calendar_ui_test.dart`
- `App/test/localization_catalog_test.dart`
- `App/test/native_speech_test.dart`
- `App/test/reminder_ask_sheet_test.dart`
- `App/test/reminder_plan_sheet_test.dart`
- `App/test/reminder_plans_test.dart`
- `App/test/reminder_settings_test.dart`
- `App/test/review_tasks_test.dart`
- `App/test/sharing_sync_test.dart`
- `App/test/support/listening_fixtures.dart`
- `App/test/task_detail_test.dart`
- `App/test/voice_command_cards_test.dart`
- `App/test/ux_previews/{calendar,capture,commands,settings}_previews.dart`
- `App/test/ux_previews/support/fakes.dart`

**Note for the commit:** the workflow's `filesChanged` list leaves out 9 files this batch changed (P272, P275 and P277 work, confirmed by the verify notes and by reading the diffs):
- `App/lib/providers/reminder_provider.dart`
- `App/lib/screens/day_timeline_screen.dart`
- `App/lib/screens/device_calendars_screen.dart`
- `App/lib/screens/notification_settings_screen.dart`
- `App/lib/widgets/device_calendar_events.dart`
- `App/lib/widgets/reminder_control.dart`
- `App/test/capture_result_exits_test.dart`
- `App/test/ux_previews/settings_previews.dart`
- `App/test/ux_previews/support/fakes.dart`

Stage these too, or the commit will hold half of P272 and P277. According to RESUME.md, no other session's uncommitted work is on this branch.

Records: `.claude/ux-review/ISSUES.md`, `runs/2026-10-28-app/plan.md`, `plan-b1-r2.json` and the `verify-b1-*.md` files.

## Verified findings now protected by a test
All 39 have tests. All files are under `App/test/`.
- **UX-2101, UX-2106, UX-2107, UX-2113**: `native_speech_test.dart`
- **UX-2111**: `native_speech_test.dart`, `voice_settings_test.dart`
- **UX-2102**: `capture_free_dictations_test.dart`, `capture_result_exits_test.dart`
- **UX-2103**: `capture_free_dictations_test.dart`, `capture_sheet_test.dart`
- **UX-2104**: `capture_free_dictations_test.dart`, `capture_sheet_test.dart`, `localization_catalog_test.dart`
- **UX-2105**: `localization_catalog_test.dart`
- **UX-2109**: `capture_sheet_test.dart`
- **UX-2201**: `bulk_voice_commands_test.dart`
- **UX-2202, UX-2209, UX-2210**: `bulk_voice_commands_test.dart`, `voice_command_cards_test.dart`
- **UX-2204, UX-2213, UX-2618**: `voice_command_cards_test.dart`
- **UX-2619**: `voice_command_cards_test.dart`, `bulk_voice_commands_test.dart`
- **UX-2203**: `capture_landing_test.dart`, `voice_command_cards_test.dart`
- **UX-2205**: `review_tasks_test.dart`, `reminder_plan_sheet_test.dart`
- **UX-2206, UX-2401**: `reminder_settings_test.dart`, `reminder_plan_sheet_test.dart`
- **UX-2207, UX-2211, UX-2212, UX-2620**: `review_tasks_test.dart`
- **UX-2208**: `review_tasks_test.dart`, `capture_result_exits_test.dart`
- **UX-2301**: `calendar_feedback_test.dart`, `task_detail_test.dart`, `sync_test.dart`
- **UX-2302**: `calendar_feedback_test.dart`, `capture_landing_test.dart`
- **UX-2303, UX-2308**: `calendar_feedback_test.dart`
- **UX-2304**: `calendar_feedback_test.dart`, `bulk_voice_commands_test.dart`
- **UX-2306**: `device_calendar_ui_test.dart`, `calendar_feedback_test.dart`
- **UX-2307**: `capture_landing_test.dart`, `new_task_form_test.dart`
- **UX-2310**: `day_timeline_test.dart`, `device_calendar_ui_test.dart`, `calendar_feedback_test.dart`
- **UX-2403**: `sharing_sync_test.dart`, `reminder_plan_engine_test.dart`
- **UX-2411**: `reminder_settings_test.dart`
- **UX-2601**: `reminder_ask_sheet_test.dart`, `reminder_settings_test.dart`
- **UX-2032**: `sharing_sync_test.dart` (P296 group), `task_detail_test.dart`

## Rounds
**Round 1** (12 packages: P266–P277, in 4 waves of 5, 3, 2 and 2)
- Packages: all done except P274, which was partial.
- Tests: **failed**. The failure was UX-2203's 360×800 landing check in `capture_landing_test.dart`.
- Verification: 34 fixed; UX-2203 and UX-2032 partly fixed.
- Regressions:
  - R1A1-1 became UX-2618
  - R1A1-2 became UX-2619
  - R1A2-1 became UX-2620

**Round 2** (P296, P297 and P298, in 1 wave)
- Tests: **passed**, including the check that a plain one-task dictation still saves as before ("speed bar").
- Verification: UX-2032, UX-2203, UX-2618, UX-2619 and UX-2620 fixed; no regressions.

## Reviewer notes, not filed (no IDs; for the next review to weigh)
- **Command path, rare mix:** when a voice change lands on an earlier day than every new task, the message names the earliest *added* day, not the day Calendar lands on. This is not new.
- **«Más opciones» with no day:** «Añade una fecha para usar un recordatorio» (UX-1811) is still plain text, right next to the repeat row that now opens the date sheet. Severity 1 at most.
- **CA 2× landing (P274's `calendar_screen.dart`):** the message covers the second highlighted row. The message now names the day.
- **Translator note:** `@notificationPermissionOff` in `app_en.arb:1353` still says the line shows on the Reminders screen generally. It now shows there only while reminders are on.
- **Schema 19 upgrade:** a test install from round 1 that still holds an unsent reader reminder upgrades with that row unmarked. Only test installs could hold one.
