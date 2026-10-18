# UX run 2026-10-18-commands, batch b2: report

**Verdict:** All 21 findings in this batch are fixed in code and protected by widget or unit tests.
- 13 are `verified`.
- 8 are `device-check`: fixed in code, but they still need the owner's phone (one of them on staging).
- Nothing from this batch is still open or escalated.

UX-909 was only partly fixed in round 1 (one failure) and was fixed in round 2. One regression came up in each of rounds 1 and 2; all of them were fixed by round 3.

Evidence: reviewers read the code (`git diff HEAD`), the Flutter SDK source and the ux-tester's widget tests, plus renders from `App/build/` for capture. No preview covers «Confirma tu correo», the command cards in the question state, or route transitions. No emulator or physical device was used.

## Verified (13)
- **UX-1204** · S2 · D · After a refused code, the screen points the wrong way. P133.
- **UX-907** · S2 · A · A search hides the day or status it used. P137.
- **UX-909** · S2 · A · «Crea el proyecto Química» can't create it beside similar names. Round 1 (P135) was partial; fixed in round 2 (P148), re-confirmed in round 3 (P150).
- **UX-911** · S2 · A · «Rellenar a mano» names a form nobody has seen yet. P138; the button now reads «Escribir».
- **UX-913** · S2 · A · Found tasks show the tick circle but open instead. P137.
- **UX-914** · S2 · A · Three ways a change can't be finished by tapping. P136.
- **UX-1011** · S2 · B · Widget and shortcut saves land on a hidden Calendar. P138.
- **UX-1215** · S2 · D · Forgotten password on the reopened screen: no way forward. Regression R1D-1; fixed in P149, re-confirmed in P151.
- **UX-915** · S1 · A · Command cards' questions look like footnotes; time hidden. P135.
- **UX-916** · S1 · A · Copy slips in command cards and the monthly notice. P137. The notice body (UX-1009, P140) and the new-project chip (UX-1104, P141) stay on their own lines.
- **UX-1216** · S1 · D · The reopened screen times the code from reopening. Regression R1D-2; fixed in P149, re-confirmed in P151.
- **UX-1218** · S1 · D · Old pending address reopens after another account signs out. Regression R1D-4; fixed in P149, re-confirmed in P151.
- **UX-1219** · S1 · A · «Otro proyecto…» sheet shows «Sin proyecto» as chosen. Regression R1A-1; fixed in P148, re-confirmed in P150.

## Verified in code, phone check still open (8, status `device-check`)
- **UX-1201** · S3 · D · After six digits, the answer hides under the keyboard. P133.
- **UX-1202** · S3 · D · Going to read the email can lose the screen. P134.
- **UX-1203** · S3 · D · A confirmed account is told «expired»; resending never arrives. P133. The check is on staging.
- **UX-908** · S2 · A · Project question asks yes/no, then lists every project. P135.
- **UX-910** · S2 · A · At 0 left, the mic widget opens a form unexplained. P138. The shortcut's wording is still an open owner question.
- **UX-1005** · S2 · B · A new task is lost if Android closes the app. P138.
- **UX-1217** · S1 · D · Sign-in flashes before the reopened screen slides in. Regression R1D-3; fixed in P149, re-confirmed in P151. The flash itself was inferred from the code.
- **UX-1220** · S1 · D · Back from the reopened verify screen animates shorter. Regression R2D-1; fixed in P151.

## Still open
None from this batch. The run's other packages (P139–P144: UX-1002–1004, UX-1006–1009, UX-1012, UX-1103–1107, UX-1109, UX-1205, UX-1207, UX-1209, UX-1210) were not part of b2 and stay `open` in the ledger.

## Escalations
None.

## Checks for the owner's phone
1. **UX-1201:** in Spanish at 1.3× and 2×, type the 6th digit on «Confirma tu correo». Android's real keyboard stays up, and the answer line shows above it.
2. **UX-1202:** with «No mantener actividades» on, sign up, open Gmail, then come back. «Confirma tu correo» reopens for that address.
3. **UX-1203 (staging):** the lost-answer case, where the code was accepted but the answer never arrived. Tapping Confirmar again opens the app, and no «ya no sirve» line shows.
4. **UX-908:** with the real model, dictate a task for a project that doesn't exist. «¿En qué proyecto la pongo?» shows at most 6 chips.
5. **UX-910:** on a free account with 0 dictations left, tap the home-screen mic widget twice in one month. The form shows the used-up line and «Ver Pro» both times.
6. **UX-1005:** with «No conservar actividades» on, type a title in «Nueva tarea», leave the app and come back. The title is waiting under «Sin guardar».
7. **UX-1217:** with «No mantener actividades» on, sign up, leave, then reopen. «Inicia sesión» doesn't flash before «Confirma tu correo».
8. **UX-1220:** after a restart, use Back and swipe-back on the reopened «Confirma tu correo». The animation matches every other Back in the app.

## Files changed
- **Area A (voice capture):**
  - `App/lib/screens/voice_task_screen.dart`
  - `App/lib/widgets/capture_command_cards.dart`
  - `App/lib/widgets/capture_review_editor.dart`
  - `App/lib/widgets/task_list_picker.dart`
  - `App/lib/models/capture_command.dart`
  - `App/lib/services/command_plan.dart`
- **Areas A/B (the form and the entries from outside the app):**
  - `App/lib/widgets/task_editor.dart`
  - `App/lib/widgets/task_form_entry.dart`
  - `App/lib/screens/edit_task_screen.dart`
  - `App/lib/main.dart`
- **Area D (email confirmation):**
  - `App/lib/screens/verify_email_screen.dart`
  - `App/lib/screens/login_screen.dart`
  - `App/lib/services/pending_verification.dart` (new)
  - `App/lib/main.dart`
- **Copy:**
  - `App/lib/l10n/app_en.arb`, `app_es.arb`, `app_ca.arb`
  - `App/lib/l10n/generated/*`, regenerated by `flutter gen-l10n`, not edited by hand
- **Tests:**
  - `App/test/voice_command_cards_test.dart`
  - `App/test/email_verification_test.dart`
  - `App/test/capture_free_dictations_test.dart`
  - `App/test/capture_sheet_test.dart`
  - `App/test/new_task_form_test.dart`
  - `App/test/localization_catalog_test.dart`
  - `App/test/auth_gate_test.dart`
  - `App/test/session_resume_test.dart`
  - `App/test/project_ui_test.dart`

## Verified findings protected by a test
All 21:
- **`App/test/email_verification_test.dart`:**
  - UX-1201: :1419, :1450, :1481
  - UX-1202: :1716–1851
  - UX-1203: :1584, :1871
  - UX-1204: :1537, :1626, :1652, :1678; also `localization_catalog_test.dart:642`
  - UX-1215: :1921, :1959, :1987
  - UX-1216: :2015, :2039
  - UX-1217: :2055
  - UX-1218: :2128
  - UX-1220: :2197, :2214
- **`App/test/voice_command_cards_test.dart`:**
  - UX-908: :3309, :3359, :3396
  - UX-909: :3440–3508, :4254–4321
  - UX-915: :3569–3607
  - UX-914: :3660–3847
  - UX-907: :3929–3999
  - UX-913: :4042
  - UX-916: :4138, :4177; also `localization_catalog_test.dart:772`
  - UX-1219: :4351; also `project_ui_test.dart:588`
- **`App/test/capture_free_dictations_test.dart` and `App/test/capture_sheet_test.dart`:**
  - UX-911: free dictations :331, :371, :2326, :2387; capture sheet :1821; also `localization_catalog_test.dart:789`
  - UX-910: free dictations :2421; capture sheet :1855
  - UX-1005: free dictations :340, :2458, :2495, :2522
  - UX-1011: free dictations :2557; capture sheet :1892

## Rounds
- **Round 1:** P133–P138.
  - **Tests failed.** The failing test was UX-909's, `voice_command_cards_test.dart:3439`.
  - **14 fixed:** UX-1201–1204, UX-907, UX-908, UX-910, UX-911, UX-913–916, UX-1005, UX-1011.
  - **Partly fixed:** UX-909. A task the server had filed in the matched project counted as ready, so one tap saved it with the question unanswered.
  - **Regressions:** R1D-1 to R1D-4 became UX-1215 to UX-1218, and R1A-1 became UX-1219.
  - Verify notes: `verify-b2-r1-A.md`, `verify-b2-r1-D.md`.
- **Round 2:** P148 and P149.
  - **Tests passed.**
  - **Fixed:** UX-909 and UX-1215 to UX-1219.
  - **Regression:** R2D-1 became UX-1220 (the 300 ms reverse-duration override).
  - Verify notes: `verify-b2-r2-A.md`, `verify-b2-r2-D.md`.
- **Round 3:** P150 (re-confirm only, no code change) and P151.
  - **Tests passed.**
  - **Fixed:** UX-1220. UX-909 and UX-1215 to UX-1219 were re-confirmed.
  - **Regressions:** none.
  - Verify notes: `verify-b2-r3-A.md`, `verify-b2-r3-D.md`.

## Ledger
`.claude/ux-review/ISSUES.md` now has these 21 lines under their new sections: 13 under Verified and 8 under Device check. No other line was changed, and no line was deleted.
