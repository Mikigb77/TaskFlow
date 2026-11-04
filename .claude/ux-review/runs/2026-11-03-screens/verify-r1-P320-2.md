## UX verify — P320 (signing out with a meeting) — round 1, check 2 — 2026-11-03

**Verdict:** All five findings are still fixed. R1-P320-1 and R1-P320-2 no longer hold. The fix adds one small new problem (R1-P320-3, severity 2). Device checks are still owed.
**Read:** the package's diff (`waves.py diff --worktree …/wf_fe15d9eb-d17-4`), which covers `App/lib/screens/account_screen.dart`, `App/lib/widgets/meeting_banners.dart`, `App/lib/services/meeting_controller.dart` and the three ARBs. Also read: `meeting_uploader.dart` (MeetingPass.stopped, the 401 → `_Stop` path), `auth_provider.dart:66-75` (sessionInvalidated → expired) and `main.dart:510-513` (sign-in shown over the open screens on expiry). Render `meetings/sign-out.sending.es.light.2x.png` (23:59:49) is newer than `account_screen.dart` (23:58:00), `meeting_banners.dart` (23:58:15) and `meeting_controller.dart` (23:27:35). INDEX.md rows 164-170.
**Evidence level:** code, the tester's widget and unit tests, and renders. Nothing here comes from an emulator or a phone. The worktree has no test yet for the reopened Cuenta (R1-P320-1) or for the refused login (R1-P320-2), so both rest on code.

### Findings

- **UX-2804 · fixed.** Check 1's evidence still holds:
  - title and `semanticLabel` are `meetingSignOutTitle`;
  - the body is recording, then the count of the others, then the reminders sentence;
  - the primary is «Guardar notas y cerrar sesión».
  The fix didn't touch the dialog.
- **UX-2805 · fixed.** The order is unchanged: Descartar, then Cancelar, then the primary. The renders are unchanged too.
- **UX-2802 · fixed, and it now holds across a reopen.**
  - `account_screen.dart` shows the line while `ref.watch(meetingSignOutPendingProvider)` is true (`savingNotes`). The `account-saving-notes` key, `onSurfaceVariant` and `liveRegion` are unchanged.
  - The flag is set right before the stop and the upload, and cleared in a `finally` after `auth.signOut()`. So the line shows until sign-in shows, or until the send fails.
  - The spinner keeps `meetingSending` while `savingNotes` is true. The Discard and plain paths still show `accountSigningOut`.
  - Render sending.es.2x shows the line under Cerrar sesión.
- **UX-2803 · fixed.**
  - `auth` (`authProvider.notifier`), the meeting controller and the pending `StateController` are all read before the first await. The work runs through those references.
  - Every `setState` stays behind `mounted`.
  - The tester's handlePopRoute tests cover Save, Discard and the plain sign-out.
- **UX-2806 · fixed.**
  - `uploadNow()` returns `MeetingSendResult`.
  - `meetingSendFailure` runs in this order:
    1. the held-back reason, when one is known;
    2. otherwise offline → `meetingSendFailed`;
    3. blocked → `requestError('session')`;
    4. anything else → `meetingSendSlow`.
  - The held-back question still offers only Descartar and a filled Cancelar.
  - MN-13 holds: on a non-done result `auth.signOut()` never runs, and nothing is discarded.

### Regressions from check 1

**R1-P320-1 · no longer holds.**
- `meetingSignOutPendingProvider` is a plain `StateProvider<bool>`: global and not autoDispose.
- Cuenta watches it, and `busy` includes it. A reopened Cuenta therefore shows Cerrar sesión disabled, with its spinner and the saving line. A second sign-out can't start, and the other account actions are disabled as well.
- When the notes are saved, the sign-out still lands wherever the person is. They were told before they left: the saving line says «Después se cerrará la sesión». Whether that feels abrupt over an open form stays a device check.

**R1-P320-2 · no longer holds.**
- A refused login (`pass.stopped`, a 401 in the uploader) with no held-back reason now gets the app's own refused-login text: `requestError('session')`, «Vuelve a iniciar sesión para continuar. Tus tareas locales se conservan.». It no longer says «…vuelve a probar Cerrar sesión en unos minutos».
- A 401 also invalidates the session (`auth_provider.dart:66-75`). The app then shows sign-in over the open screens (`main.dart:510-513`), so the text agrees with what the person sees.
- No test covers this path yet.

### New regressions

**R1-P320-3 · Severity 2 · A reopened Cuenta drops the saving line with no reason**
- Where: `App/lib/screens/account_screen.dart`, `_signOutWithMeetings`. When the result isn't done, the failure message is set only `if (mounted)`, on the original State. A Cuenta opened again after Back is a new State, and reads only the bool flag.
- The moment: "It said it was saving the notes and that it would sign me out afterwards. Now the line is gone, Cerrar sesión is back and I'm still in. Did it finish? Did it cancel?"
- What happens: Save, then Back, then open Cuenta again. The person sees the saving line, which is the fix for R1-P320-1. If the send then ends offline, slow, blocked or refused, the line disappears and the button comes back. No message explains it. When the person stays on the first Cuenta, the same failure shows the offline, slow or held-back text.
- Why it fails: gulf of evaluation and visibility of system status (Norman 2013; Nielsen 1994). Error messages should say what happened and what to do (Neusesser & Sunwall 2023). Lens B and lens I.
- How bad: they can recover. Tapping Cerrar sesión again asks the question again, and a second Save on a mounted Cuenta shows the reason. The fix caused this: before it, a reopened Cuenta showed no wait at all, so nothing could vanish.
- Fix (no new copy):
  - Keep the result with the flag, outside the screen. For example, the provider holds `MeetingSendResult?` or a small sealed state (`saving`, `failed(result)`) in place of the bool.
  - Any Cuenta that is open when the send ends shows `meetingSendFailure(l, meetings, result)` as its usual error line, the one the first Cuenta shows.
  - Clear it on the next tap of Cerrar sesión, or when Cuenta is closed.
  - The brief's "with Cuenta gone, nothing more happens" still holds when no Cuenta is open.
- Verify: a widget test. Tap Save, press Back, push Cuenta again, then let a gated fake upload end offline. The reopened Cuenta shows the offline text («Sin conexión, no se pudieron hacer las notas…»), Cerrar sesión is enabled, and the account is still signed in.
- Evidence: verified in code. Not seen in a render, because no preview covers a reopened Cuenta.

### Notes for the organizer
- These diff changes are still there and outside the run's scope: `App/analysis_options.yaml` (analyzer excludes) and `App/pubspec.lock`. Check them before the merge.
- No test exists yet for R1-P320-1 (reopen during the wait: the `account-saving-notes` key and the disabled button) or for R1-P320-2 (a 401 during Save: no slow text).
- Device checks owed:
  - TalkBack on the titled dialog;
  - an offline afternoon: Save, then Back during the wait;
  - the sign-out landing over an open form after Back.

### Memory notes
- The sign-out pending flag is `meetingSignOutPendingProvider` (a global `StateProvider<bool>`, in `account_screen.dart`). Cuenta watches it for `busy`, the spinner and the saving line.
- Recurring type (a variant of the one from check 1): when progress state moves out of a screen, the outcome must move with it. Otherwise a reopened screen shows the wait but not its result.
