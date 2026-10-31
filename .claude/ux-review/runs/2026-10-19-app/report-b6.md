# UX loop 2026-10-19-app: batch b6 report (2026-10-21)

**Verdict:** All 7 findings in batch b6 were fixed over 2 rounds, and each is covered by a passing widget or unit test. **UX-1655** is verified. The other 6 are verified in code but still need a check on a phone, the emulator or staging, so their status is `device-check`. Round 1 caused two regressions (R1A-1 and R1D-1). Round 2 fixed both and caused no new ones. Nothing is open and nothing is escalated.

Evidence came from code review, widget and unit tests, and preview renders made after the code changed. Nothing in this batch was run on a device. The share screenshots in `App/build/ux/device/share.*` came from an APK built at commit 6ea4ab0, before this batch's changes, so they say nothing about these fixes.

## Verified
- **UX-1655** · S2 · D: Cuenta's name row doesn't look tappable. The `account-name` row in `App/lib/screens/account_screen.dart:211` now ends in `Icons.chevron_right_rounded`, like the Settings rows. The two read-only rows, «Cuenta de Google vinculada» and «Guardado en tu cuenta», still have no chevron. Current renders of `settings/account.{named,google-linked,email}` at ES 1× and at ES and CA 2× show nothing cut off. No device check is needed. (Round 2, P220, verify-b6-r2-D. This was regression R1D-1, caused by P194.)

## Verified in code, still needs a device check
- **UX-1601** · S3 · D: The reminder question promised a reminder that couldn't come. `ReminderEngine.alertAhead` now follows the same steps as `plan()`. `_ask` returns before marking the account as asked when no saved task's reminder can still fire. The chip and the form row now read «Sin recordatorio: ya ha pasado la hora del aviso». (Round 1, P190, verify-b6-r1-D)
- **UX-1602** · S3 · D: Password recovery gave a Spanish newcomer an English code. Now the code field takes digits only, at most 6, with the number pad and code autofill. The confirm request sends the email, the code and the password. «Ya tengo un código» shows the email field. A wrong code is reported under the field and the new password stays typed. An expired code triggers a new one, sent to the same address in the same language. `authEnterRecoveryCode` has been removed. The server side (commit cf39f6e) accepts this. (Round 1, P191, verify-b6-r1-D)
- **UX-1603** · S2 · D: The first screen's filled button was the long email path. The email fields now sit behind «Continuar con mi correo», under Google. The folded screen has 5 tap targets, besides the debug-only controls, and Google is the only button-shaped one. Back folds the open form. Create, recovery and the return from «Confirma tu correo» open the form already unfolded. (Round 1, P193, verify-b6-r1-D)
- **UX-1515** · S2 · C: A name asked once could never be changed. Cuenta now has a row that reads «Añadir tu nombre», or «Nombre» with the name below it, and it opens the existing name sheet. (Round 1, P194, verify-b6-r1-D. The chevron came in round 2 as UX-1655.)
- **UX-1623** · S2 · A: Shared text's day and time weren't read in the form. On a free account, shared text is now read with the same parser and rules as dictated words (D2), and the D9 day still applies. Words typed in the sheet stay as written. (Round 1, P192, verify-b6-r1-A)
- **UX-1654** · S2 · A: A shared capture resumed days later opened on a day already gone. Now a read day or deadline earlier than today is dropped, and the form opens titled with the words as written and no day, or the D9 day if there is one. A read day of today or later is kept. One side effect is that a fresh dictation whose only date has passed («ayer») also opens with no day. The reviewer accepted this because it matches the form's rule that a day gone by adds nothing. (Round 2, P219, verify-b6-r2-A. This was regression R1A-1, caused by P192.)

## Still open
None.

## Escalations
None.

## Checks for the owner's phone
- **UX-1601:**
  - A task with a date but no time, saved for today after 9:00, brings no reminder question.
  - A task with a date but no time gets its 9:00 reminder on its day.
- **UX-1602:**
  - On staging, the recovery email arrives in Spanish with a 6-digit code.
  - On the phone, the number pad and code autofill appear in the code field.
- **UX-1603:**
  - Google sign-in completes from the folded screen.
  - Back folds the open email form.
- **UX-1515 (staging):** The reviewer asked for a staging check without saying exactly what to test. My reading: a name changed in Cuenta is saved to the account.
- **UX-1623 (emulator lane):** Retake the share screenshots (`App/build/ux/device/share.landing.*` and `share.after-back.*`) with an APK that includes this batch.
- **UX-1654 (emulator lane):** Share «Llamar a Marta mañana», close the app, move the date forward a few days, and resume it from Sin guardar. The form should open with no day chosen.

## Files changed
- **App code:**
  - `App/lib/services/reminder_engine.dart`
  - `App/lib/widgets/reminder_ask_sheet.dart`
  - `App/lib/widgets/reminder_control.dart`
  - `App/lib/widgets/task_editor.dart`
  - `App/lib/widgets/capture_review_editor.dart`
  - `App/lib/widgets/task_form_entry.dart`
  - `App/lib/widgets/name_ask_sheet.dart`
  - `App/lib/screens/login_screen.dart`
  - `App/lib/screens/account_screen.dart`
  - `App/lib/screens/voice_task_screen.dart`
  - `App/lib/screens/edit_task_screen.dart`
- **Text:**
  - `App/lib/l10n/app_en.arb`, `app_es.arb` and `app_ca.arb`
  - `App/lib/l10n/generated/`, regenerated by `flutter gen-l10n`, not edited by hand
- **Tests:**
  - `App/test/reminder_ask_sheet_test.dart`
  - `App/test/reminder_engine_test.dart`
  - `App/test/reminder_settings_test.dart`
  - `App/test/auth_gate_test.dart`
  - `App/test/email_verification_test.dart`
  - `App/test/account_regional_ui_test.dart`
  - `App/test/name_ask_test.dart`
  - `App/test/session_resume_test.dart`
  - `App/test/capture_free_dictations_test.dart`
  - `App/test/capture_sheet_test.dart`
- **Previews:**
  - `App/test/ux_previews/first_run_previews.dart`
  - `App/test/ux_previews/tasks_previews.dart`
  - `App/test/ux_previews/auth_previews.dart`
  - `App/test/ux_previews/settings_previews.dart`
- **Loop record:** `.claude/ux-review/ISSUES.md`

## Which verified findings a test now protects
All seven are covered by passing tests:

| Finding | Tests |
|---|---|
| UX-1601 | `App/test/reminder_engine_test.dart:1103`, `reminder_ask_sheet_test.dart:868`, `reminder_settings_test.dart:2296` |
| UX-1602 | `App/test/auth_gate_test.dart:1269`, `:1301`, `:1688`–`:1855`, `localization_catalog_test.dart:1219` |
| UX-1603 | `App/test/auth_gate_test.dart:1887`–`:2113` |
| UX-1515 | `App/test/name_ask_test.dart:756`, `:784` |
| UX-1623 | `App/test/capture_free_dictations_test.dart:2892`, `:2831` (UX-918, updated), `capture_sheet_test.dart:621` |
| UX-1654 | `App/test/capture_free_dictations_test.dart:3077`–`:3212` (five cases) |
| UX-1655 | `App/test/name_ask_test.dart:897`, `:915`, `:940` |

## Rounds
- **Round 1** (`plan.json`): packages P190, P191, P192, P193 and P194, all done. **Tests passed.** Reviewers A and D found UX-1601, UX-1602, UX-1603, UX-1515 and UX-1623 fixed. They also found two regressions:
  - R1A-1 became UX-1654: a stale share opened on a day already gone.
  - R1D-1 became UX-1655: the name row had no chevron.
- **Round 2** (`plan-b6-r2.json`): packages P219 and P220, both done. **Tests passed.** Reviewers A and D found UX-1654 and UX-1655 fixed, with no new regressions.

## Notes
- **Preview harness:** the first auth render in the suite, `sign-in.sign-in.es.light.1x.png`, draws Google's button without its G logo. The 1.3×, 2× and email-open renders have the logo, and the button code is unchanged, so this is a harness problem, not the app.
- **AUDIT entries:** ux-tester noted two entries in `settings/account`, and the round 2 reviewer judged neither to be caused by this batch's change.
  - «Añadir tu nombre» is flagged for contrast. It measures 13.54:1, so this is a false positive from anti-aliasing.
  - «Cerrar sesión» measures 200 × 2 dp in `· named es.light.2x` because the bottom of the 2× viewport cuts it off in a scrolling view.