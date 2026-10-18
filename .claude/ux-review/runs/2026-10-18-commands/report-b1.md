# UX run 2026-10-18-commands: report, batch b1

**Verdict:** Every finding in this batch was fixed. That is the 12 planned findings plus the 3 regressions found in round 1. The reviewer marked each one `fixed`, and passing tests cover all 15. Nothing failed, nothing was escalated and nothing is still open. 5 findings are now `verified`. The other 10 are `device-check`: the code is verified, but each still needs a check on a phone or on staging.

Evidence: the reviewers read the code and the ux-tester's widget and unit tests, and looked at a few rendered previews (`App/build/review-batch-light.png`, `App/build/project-people-filter-es.png`, `App/artifacts/auth/login-light.png`). Nothing was run on an emulator or a physical phone.

## Verified (5)
- **UX-902** · S3 · A: «Para el 12» showed and was saved as «Sin fecha». (P129)
- **UX-905** · S2 · A: the confirming button didn't say what the tap does. «Aplicar» is gone. (P128)
- **UX-906** · S2 · A: a project created by voice was never shown. Its page now opens with the tasks highlighted. (P129)
- **UX-1108** · S2 · C: «Para mí» and «Todas» swapped places between screens. The order is now «Todas · Para mí» everywhere. (P131)
- **UX-1212** · S1 · A: after opening a task from the new project page, Deshacer left that task screen open over the deleted project. Deshacer now closes the task screen and then the page. (P146, regression R1A-1)

## Verified in code, still needs a phone (10)
- **UX-901** · S3 · A: a task said with «cambia» or «busca» could dead-end. «Guardar tal cual» is now the way out, and completed tasks say «Completada». (P127)
- **UX-903** · S3 · A: not deleting a task was worded as deleting it. The ✕ now says «No eliminar …» and the message says «No se eliminará». (P128)
- **UX-904** · S2 · A: shared text was read as commands, not as a task. A share is now sent as typed text. (P127)
- **UX-1001** · S3 · B: a task for someone else was saved somewhere out of sight. The filter now widens just enough to show it. (P130)
- **UX-1101** · S3 · C: people chips could hide off-screen with no sign. They now wrap onto two rows, and ✓ moves into the app bar on project pages. (P131)
- **UX-1110** · S1 · C: TalkBack read a person chip as just a name. Chips now have a full spoken label. (P131)
- **UX-402** · S3 · D: signing in without an account was a dead end. The server's real 401 now leads to «Crear una cuenta con este correo» or to password recovery. (P132)
- **UX-1208** · S1 · D: «Demasiadas solicitudes. Espera un poco» never said how long. It now says «Demasiados intentos. Espera N minutos y vuelve a intentarlo.» (P132)
- **UX-1213** · S1 · B: Deshacer left the widened filter in place. Deshacer now puts back the filter from before. (P147, regression R1B-1)
- **UX-1214** · S2 · C: the chosen people chip was shown only by a pale fill. The ✓ is back, with narrower chip padding so the two rows still fit. (P145, regression R1C-1)

## Still open
None.

## Escalations
None.

## Checks for the owner's phone or staging
1. **UX-901**, on staging, in Spanish and Catalan: count how many of the 5 «cambia/busca» phrasings the real model reads as commands. If it's 2 or more, raise this to S4.
2. **UX-904** (Pro): share «Busca el informe de ventas» into TaskFlow. The result should be a task.
3. **UX-903**: TalkBack reads a deletion card's ✕ as «No eliminar …».
4. **UX-1001** (Pro, with a shared project): on Calendar, say «Ana tiene que llamar al médico mañana». The task appears and is highlighted.
5. **UX-1213** (Pro, spoken, shared project): do the same as check 4, then tap Deshacer. «Para mí» should be selected again.
6. **UX-1101 and UX-1214**: Spanish, the largest font, a phone 360–393 dp wide, a shared project with two other editors. All chips are visible without swiping, and the chosen chip shows ✓.
7. **UX-1110**: TalkBack reads Ana's chip with its label and whether it is selected.
8. **UX-402**, on staging: sign in with a wrong password. You should see the credentials message and «Crear una cuenta con este correo». This also unblocks the UX-484 and UX-488 phone checks.
9. **UX-1208**, on staging: enter a wrong password five times, then try a sixth. It should say «Espera 15 minutos».

## Files changed
- Screens and widgets: `App/lib/screens/voice_task_screen.dart`, `App/lib/screens/home_screen.dart`, `App/lib/screens/calendar_screen.dart`, `App/lib/screens/delete_account_screen.dart`, `App/lib/widgets/capture_command_cards.dart`, `App/lib/widgets/capture_review_editor.dart`, `App/lib/widgets/project_scope_control.dart`, `App/lib/widgets/task_editor.dart`
- Logic: `App/lib/services/capture_processor.dart`, `App/lib/services/capture_store.dart`, `App/lib/services/api_client.dart`, `App/lib/models/capture_session.dart`, `App/lib/providers/project_scope_provider.dart`, `App/lib/l10n/request_locale.dart`
- Text: `App/lib/l10n/app_en.arb`, `app_es.arb`, `app_ca.arb`, and `App/lib/l10n/generated/` (regenerated)
- Tests: `App/test/capture_recovery_test.dart`, `capture_sheet_test.dart`, `voice_command_cards_test.dart`, `capture_result_exits_test.dart`, `localization_catalog_test.dart`, `native_speech_test.dart`, `project_people_filter_test.dart`, `new_task_form_test.dart`, `email_verification_test.dart`, `delete_account_test.dart`

## Findings a test now covers
All 15. No finding relies on a device check alone.
- UX-901: `voice_command_cards_test.dart:1810-2180`, `capture_recovery_test.dart:659`
- UX-902: `voice_command_cards_test.dart:2593-2818`, `:2946`
- UX-903: `voice_command_cards_test.dart:2181-2437`
- UX-904: `capture_recovery_test.dart:603`
- UX-905: `voice_command_cards_test.dart:2438-2590`, `:3158` (Catalan at 2× text on 320×640), `localization_catalog_test.dart:515`
- UX-906: `voice_command_cards_test.dart:2819-3036`
- UX-1001: `new_task_form_test.dart:1064`, `:1099`, `:1121`, `:1153`; `voice_command_cards_test.dart:3052`
- UX-1101: `project_people_filter_test.dart:535-616`, `:703-900`
- UX-1108: `project_people_filter_test.dart:447`, `:480`
- UX-1110: `project_people_filter_test.dart:488`
- UX-402: `email_verification_test.dart:1075`, `:1103`, `:1132-1191`
- UX-1208: `email_verification_test.dart:1195-1290`, `delete_account_test.dart:2088`, `:3300-3346`
- UX-1212: `voice_command_cards_test.dart:2890`
- UX-1213: `new_task_form_test.dart:1178-1300`, `voice_command_cards_test.dart:3093`
- UX-1214: `project_people_filter_test.dart:632`, `:675`, `:784`

## Rounds
- **Round 1** (`plan.json`): packages P127, P128, P129, P130, P131 and P132 all finished. **Tests passed.** All 12 findings were fixed. It caused 3 regressions:
  - R1A-1 (S1, from P129) became UX-1212;
  - R1B-1 (S1, from P130) became UX-1213;
  - R1C-1 (S2, from P131) became UX-1214.
- **Round 2** (`plan-b1-r2.json`): packages P145, P146 and P147 all finished. **Tests passed.** All 3 regressions were fixed, with no new regressions.

## Notes from the reviewers (not findings, not planned)
- The Todas/Para mí pair's «Todas» has no «Todas las tareas» label for TalkBack, while the people row's «Todas» does. This predates this run. It could be added to UX-1110's line of work at the next review.
- On the Tareas root, the landing also clears the search, label and tab filter, and Deshacer doesn't bring them back. P147 was limited to the app-wide filter, so this was left as it was.
- After the 15-minute sign-in lock, the banner offers no next step, but «¿Has olvidado tu contraseña?» stays reachable. This is older behaviour, not a dead end.
- «Guardar tal cual» describes how it saves, not what the person gets. Renaming it waits on owner decision D3 (UX-919).
- Edge case (Pro): if another full screen is opened above the Física page and the person then taps Deshacer, that screen closes too, skipping its "leave?" question. The reviewer judged it not worth fixing.

Ledger: the lines for all 15 findings in `.claude/ux-review/ISSUES.md` were moved out of Open: 10 to Device check and 5 to Verified.