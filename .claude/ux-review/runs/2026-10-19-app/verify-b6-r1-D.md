## UX verify — 2026-10-19-app, batch b6, round 1, area D — 2026-10-21

Scope: P190 (UX-1601), P191 (UX-1602), P193 (UX-1603), P194 (UX-1515). Read `git diff HEAD` of the changed files, ux-tester's results, and renders made 2026-10-21 03:15–03:16. No file under App/lib or App/assets is newer than those renders, so they count as evidence. Level: code plus widget-test renders. No device evidence.

### Results

**UX-1601 · fixed** (device checks still to do)
- `ReminderEngine.alertAhead` (`App/lib/services/reminder_engine.dart:189-209`) takes the same steps as `plan()`: `upcoming` → `_firing` → `isAfter(now)`. It treats reminders as on, uses `dateOnlyTime ?? 540`, and returns false for a task whose reminder is off (-1). The question and the engine can't disagree.
- `_ask` (`App/lib/widgets/reminder_ask_sheet.dart:105-109`) returns before `shown = true` when no saved task passes, so the `finally` frees the slot and the account isn't marked asked. The next dated save asks.
- The clock comes from `calendarClockProvider` and is read after the save message closes.
- Chip (`App/lib/widgets/reminder_control.dart:385-436`): the passed reading comes after `reason` and after `blocked`, with the crossed-out bell. A tap still opens the chooser.
- Form row (`reminder_control.dart:502-552`): the same reading, from `schedule`. `schedule` is passed by TaskEditor (`task_editor.dart:1250`, the live repeat/date state) and by CaptureReviewEditor (`:741`).
- Copy is in all three catalogs, as briefed.
- Render `tasks/detail.alert-passed.{es.1x,es.2x,ca.2x}`: the chip is whole, 286 × 58 dp at 1×. At CA 2× it wraps to 4 lines inside the screen. TalkBack reads «Sin recordatorio: ya ha pasado la hora del aviso».
- Device only: the 9:00 reminder ringing the next day.

**UX-1602 · fixed** (device checks still to do)
- The code field (`login_screen.dart`, the `_codeField` subtree) has `TextInputType.number`, `AutofillHints.oneTimeCode`, digits only, a 6-digit limit, no suggestions, and the `verifyEmailCodeLength` validator.
- The confirm request sends `email` (`_sentTo ?? _email.text.trim()`), `code` and `password`.
- `_showsEmail` now also covers «Ya tengo un código» with no code sent here.
- `code_invalid` shows `verifyEmailCodeInvalid` as the field's errorText and keeps the password. Changing a digit clears it.
- `code_expired` clears the code, asks for a new code for the same address and language, swaps the banner to `recoveryCodeRenewed` (live region), and focuses the code field after `_run`.
- `authEnterRecoveryCode` is gone from all three ARB files.
- The server's `ResetConfirmView` (`Backend/core/auth_views.py:257-297`) takes `{email, code, password}` and answers `CODE_INVALID`/`CODE_EXPIRED`, so the contract is in.
- Renders `recovery-code-wrong` and `recovery-code-renewed` (ES/CA 2×) show no cut text.

**UX-1603 · fixed** (device checks still to do)
- `_folded` = not open, not create, not recovery, and Google supported and configured, and not sign-in-again.
- Folded, the screen shows only Google and the «Continuar con mi correo» TextButton. The «o», the fields, «¿Has olvidado…?», the submit button and «Crear una cuenta» are all hidden (`!folded` guards).
- `_openEmail` focuses Correo.
- PopScope folds the open form on Back.
- `_mode()` sets `_emailOpen = true`, so create, recovery and the return from «Confirma tu correo» all land on the open form.
- `_fieldFor` returns null when folded, so a Google error shows in the banner under the buttons.
- AUDIT `auth/sign-in · sign-in` (es.light.1x) lists 5 targets plus the debug-only «Ajustes de conexión»: Idioma, Google, «Continuar con mi correo» (264 × 48 dp), Privacidad, Términos. TalkBack reads: heading, pitch, Google, «Continuar con mi correo». The only button-shaped control is Google.
- `sign-in.email-open.*` shows the open form with the focus in Correo.
- Harness note, not app behaviour: `sign-in.sign-in.es.light.1x.png`, the suite's first auth render, draws Google's button without its G logo. The 1.3×, 2× and email-open renders have it, and the button code is unchanged.

**UX-1515 · fixed** (Staging still to do)
- In Cuenta, the `account-name` ListTile sits under the email. It reads «Añadir tu nombre» with no subtitle, or «Nombre» with the name as its subtitle.
- `editName` (`name_ask_sheet.dart:88-107`) opens `_NameAskSheet` filled with the name or `suggestedName(email)`. It never touches the asked-once flag. After a save it invalidates `taskListsProvider`.
- AUDIT `settings/account · email` measures the row at 312 × 56 dp, and `· named` at 312 × 72 dp. TalkBack reads «Nombre María», button.
- The CA 2× render shows «Afegeix el teu nom» whole.

### Regressions

**R1D-1 · Severity 2 · The Cuenta name row doesn't look tappable**
- Where: `App/lib/screens/account_screen.dart:199-212`; renders `settings/account.named.es.light.1x`, `account.email.*`.
- The moment: "I spelled my name wrong. Where do I change it? 'Nombre — María' is just telling me my name."
- What happens:
  - The new row has no trailing affordance.
  - It looks exactly like the screen's read-only ListTiles («Cuenta de Google vinculada», «Guardado en tu cuenta»), with the same leading icon, the same title style and no chevron.
  - Settings' navigation rows all end in `Icons.chevron_right_rounded` (`settings_screen.dart:105-137`), and so does the form's Recordatorio row. «Añadir tu nombre» reads as a verb, but «Nombre / María» reads as information.
- Why it fails: Norman (2013), visible signifiers. It is also inconsistent with the app's own tappable rows (Nielsen, consistency).
- Fix: add `trailing: const Icon(Icons.chevron_right_rounded)` to the `account-name` ListTile, as in the Settings rows. No new copy.
- Verify: re-render `settings/account.{named,email}` and see the chevron. AUDIT still lists the row as a button.
- Evidence: seen in a current render, and verified in code.

No other regressions found in the changed files or the flows they touch. Checked:
- the passed reading's precedence against P177's readings and UX-209;
- the 20 dp avatar box on the chip, which keeps the 16 dp icon unchanged at 1× and 2×;
- Back with the email form open, and sign-in-again;
- code_expired reached through «Ya tengo un código»;
- the Google error while folded.
