## UX loop: run 2026-10-18-commands, batch 4, close (2026-10-19)

**Verdict:** All 13 findings in this batch are fixed, in two rounds, and every one has a passing test. 4 are verified. The other 9 are verified in code but still need a phone check. Round 1 fixed its 9 findings at the first try and caused four small regressions (UX-1228, UX-1229, UX-1230 and UX-1231, severities 1–2). Round 2 fixed all four and caused no new ones. No finding failed, and nothing was escalated.

Evidence: code read (`git diff HEAD`), widget and unit tests from ux-tester (all passing), and renders under `App/build/ux/` that are newer than every file in `App/lib` and `App/assets`. No emulator or device was used, and no staging server.

### Verified (4)
- **UX-920** · A search with a period («¿qué tengo esta semana?») now lists soonest first, by day and then time. Searches with no period stay newest first (P152, D4)
- **UX-1010** · Back on a new task now says «Añadida al …» / «Añadida · vence el …» / «Añadida sin fecha», with Deshacer, and lights the day on Calendar. Edits keep «Cambios guardados» (P153, D6)
- **UX-1228** · «Tareas con archivos» now counts only files the server holds, so no row reads «0,0 MB» (P163, regression R1B-1)
- **UX-1229** · When the name sheet is offline, the error now says only «No hay conexión. Revisa el wifi o los datos móviles e inténtalo de nuevo.», with nothing about tasks (P164, regression R1C-1)

### Verified in code, needs a phone (9)
- **UX-917** · Cancelar, Back, the scrim and a swipe now close at once when a result has no task or note to add. Results with a task keep U2's question (P152, D1)
- **UX-919** · «Guardar tal cual» is now «Guardar como tarea» / "Save as a task" / «Desa-ho com a tasca» everywhere (P152, D3)
- **UX-918** · Words dictated before «Escribir» now open the form with their day and time. A bare hour («a las 5») stays in the title and sets no time. Typed titles, shared text and typed captures stay as typed (P153, D2)
- **UX-1223** · When the account's own file space is full, «Ver tareas con archivos» now shows beside «Ver Pro» and under the Pro screen's storage line. It opens a new list of tasks with files, largest first (P154)
- **UX-1112** · Password accounts with no name are asked «¿Cómo te llamas?» once on this phone, after their first invitation or join. The field is prefilled from the email and can be skipped (P155, D8)
- **UX-1102** · Chips, «Creada por», the assignment picker and the row tag show the name the server sends. Google accounts take their Google first name at sign-in (server 41c00f3) (P155)
- **UX-1206** · When the resend limit is reached («resend_limited»), the screen no longer says a code was sent. «Has pedido muchos códigos. Espera {n} minutos para pedir otro.» shows and «Reenviar código» stays off until the wait ends. The typed digits are kept (P156, D9)
- **UX-1231** · The wait line now counts down with the button, and goes away in the last minute (P162, regression R1D-1)
- **UX-1230** · While «Guardar» waits, the button now shows a spinner at the same size and «Ahora no» is off. Both come back on a failure (P164, regression R1C-2)

### Still open
- None of this batch's findings in the app.
- Outside the app, for the main session: `Backend/docs/VOICE_COMMANDS.md:100` still says a search lists newest first. That contradicts UX-920 (D4).
- Not counted and not in the ledger. These were already there or were decided in the briefs, and the main session can raise them on a later run:
  - **Overlapping chips.** The form's AUDIT shows «17:00» and «Quitar hora» overlapping. This is P139's time chip.
  - **Hidden transcript.** In the slow state, the transcript scrolls under «Entendiendo…».
  - **Red outline.** The limit line on the confirm-email screen is an `errorText`, so a code that is still valid gets a red outline. Raise it with UX-1208 if the screen is revisited.
  - **Silent short refusals.** A resend refusal of 60 s or less announces nothing to TalkBack, as the brief decided.
  - **No "saving" word.** While the name sheet saves, TalkBack hears only «Guardar, desactivado».

### Escalations
None.

### Checks for the owner's phone
1. **UX-917.** On staging, with the real model, in Spanish: say «Borra la tarea del dentista» and tap Cancelar. The sheet closes at once and «Sin guardar» shows nothing new.
2. **UX-919, U7.** In airplane mode, in Spanish: dictate «médico el viernes». After the failure, tap «Guardar como tarea». The task is saved on Friday.
3. **UX-918.** On a free account with dictations left, in Spanish, with real speech: say «Médico el viernes a las 5 de la tarde» and tap Escribir. The form opens on Friday at 17:00, and Añadir tarea puts it on Friday.
4. **UX-1223.** Attach files past the 100 MB cap, open «Ver tareas con archivos», remove a file from the largest task, go back and tap «Reintentar».
5. **UX-1112.**
   - Check how TalkBack reads the name sheet.
   - After a sync, the other member sees the new name.
   - The group-invite path has no test, so walk it once.
6. **UX-1102.** After a staging deploy, two Google accounts that share a project see each other's first names.
7. **UX-1206.** On staging (d447c5c), go past the resend limit:
   - no email arrives;
   - TalkBack reads the limit line once.
8. **UX-1231.** With TalkBack on: the limit line is a live region that now changes once a minute. Check that TalkBack doesn't read it again every minute. If it does, keep its spoken text fixed after the first announcement.
9. **UX-1230.** With a password account on a slow connection, tap «Guardar» in the name sheet. The spinner shows at once, and «Ahora no» stays off until the answer comes.

### Files changed
- **Screens:**
  - `App/lib/screens/voice_task_screen.dart`
  - `App/lib/screens/edit_task_screen.dart`
  - `App/lib/screens/subscription_screen.dart`
  - `App/lib/screens/tasks_with_files_screen.dart` (new)
  - `App/lib/screens/list_sharing_screen.dart`
  - `App/lib/screens/groups_screen.dart`
  - `App/lib/screens/verify_email_screen.dart`
- **Widgets:**
  - `App/lib/widgets/capture_command_cards.dart`
  - `App/lib/widgets/task_form_entry.dart`
  - `App/lib/widgets/task_editor.dart`
  - `App/lib/widgets/attachment_panel.dart`
  - `App/lib/widgets/name_ask_sheet.dart` (new)
  - `App/lib/widgets/invitation_cards.dart`
- **Services and providers:**
  - `App/lib/services/task_matcher.dart`
  - `App/lib/services/capture_processor.dart`
  - `App/lib/services/quick_schedule_parser.dart`
  - `App/lib/services/attachment_store.dart`
  - `App/lib/services/api_client.dart`
  - `App/lib/providers/subscription_provider.dart`
  - `App/lib/providers/auth_provider.dart`
- **Text:**
  - `App/lib/l10n/app_en.arb`
  - `App/lib/l10n/app_es.arb`
  - `App/lib/l10n/app_ca.arb`
  - `App/lib/l10n/generated/*` (regenerated by `flutter gen-l10n`, not edited by hand)
- **Tests:**
  - `App/test/voice_command_cards_test.dart`
  - `App/test/capture_sheet_test.dart`
  - `App/test/voice_commands_test.dart`
  - `App/test/capture_free_dictations_test.dart`
  - `App/test/new_task_form_test.dart`
  - `App/test/attachment_panel_test.dart`
  - `App/test/subscription_screen_test.dart`
  - `App/test/email_verification_test.dart`
  - `App/test/tasks_with_files_test.dart` (new)
  - `App/test/name_ask_test.dart` (new)
  - `App/test/calendar_feedback_test.dart` (a test name only)
  - `App/test/capture_recovery_test.dart` (a test name only)
  - `App/test/quick_schedule_parser_test.dart` (comments only)
- **Previews:** `App/test/ux_previews/` — `capture_previews.dart`, `commands_previews.dart`, `form_previews.dart`, `tasks_previews.dart`, `settings_previews.dart`, `sharing_previews.dart` and `auth_previews.dart`
- **Ledger:** `.claude/ux-review/ISSUES.md`:
  - the 13 lines moved out of Open;
  - short notes added to U2, U7, UX-506, UX-901 and UX-903, which pointed at these findings as pending.

### Which tests protect which findings
Every finding in this batch has a test.
- **UX-917:** `App/test/voice_command_cards_test.dart:5475-5605` (results holding only a deletion, a change or a new project), `:2133`, `:2380`
- **UX-919:** `App/test/capture_sheet_test.dart:1978`, `:2019` (no catalog value says «tal cual»), `:2040` (2× on 320×640); `App/test/voice_command_cards_test.dart:5606`
- **UX-920:** `App/test/voice_commands_test.dart:579`, `:605`
- **UX-918:** `App/test/capture_free_dictations_test.dart:2738`, `:2763`, `:2779`, `:2827`
- **UX-1010:** `App/test/new_task_form_test.dart:420`, `:457`; `App/test/capture_free_dictations_test.dart:2779`
- **UX-1223:**
  - `App/test/tasks_with_files_test.dart:127`, `:278`, `:350`, `:385`, `:403` (2×);
  - `App/test/attachment_panel_test.dart:333`;
  - `App/test/subscription_screen_test.dart:300`.
- **UX-1112:** `App/test/name_ask_test.dart:73-371`. The group-invite path has no test.
- **UX-1102:** `App/test/name_ask_test.dart:614` covers the chip and «Creada por». The picker and the row tag are checked in code only.
- **UX-1206:** `App/test/email_verification_test.dart:2584`, `:2622`, `:2650`, `:2672`, `:2731`
- **UX-1231:** `App/test/email_verification_test.dart:2770`, `:2782`, `:2806`, `:2826`
- **UX-1228:** `App/test/tasks_with_files_test.dart:161`, `:172`, `:187`
- **UX-1229:** `App/test/name_ask_test.dart:279`, `:377`, `:415`, `:547` (ES and CA at 2×)
- **UX-1230:** `App/test/name_ask_test.dart:454`, `:495`, `:530`

### Rounds
- **Round 1** (`plan.json`):
  - **Packages:** P152 (UX-917, UX-919, UX-920), P153 (UX-918, UX-1010), P154 (UX-1223), P155 (UX-1112, UX-1102) and P156 (UX-1206), all done.
  - **Tests:** passed. All 9 findings are proven by a test, and none is device-only.
  - **Reviewers:** all 9 fixed (`verify-b4-r1-A.md` to `verify-b4-r1-D.md`).
  - **Regressions:**
    - R1B-1 became UX-1228: files waiting to upload were counted.
    - R1C-1 became UX-1229: the offline error spoke about tasks.
    - R1C-2 became UX-1230: «Guardar» showed no progress.
    - R1D-1 became UX-1231: the wait line didn't follow the countdown.
- **Round 2** (`plan-b4-r2.json`):
  - **Packages:** P162 (UX-1231), P163 (UX-1228) and P164 (UX-1229, UX-1230), all done.
  - **Tests:** passed. All 4 findings are proven by a test.
  - **Reviewers:** all 4 fixed (`verify-b4-r2-B.md`, `verify-b4-r2-C.md`, `verify-b4-r2-D.md`).
  - **Regressions:** none.
