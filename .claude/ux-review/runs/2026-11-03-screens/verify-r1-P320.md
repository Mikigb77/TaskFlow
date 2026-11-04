## UX verify — P320 (signing out with a meeting) — round 1 — 2026-11-03

**Verdict:** All five findings fixed at widget level. Two regressions in the flows the change touches: one minor, one polish. Device checks are still owed.
**Read:** the package's diff (`waves.py diff --worktree …/wf_fe15d9eb-d17-4`); `App/lib/screens/account_screen.dart`, `App/lib/widgets/meeting_banners.dart`, `App/lib/services/meeting_controller.dart` and `meeting_uploader.dart` (MeetingPass), all in the worktree; the three ARB catalogs; renders `meetings/sign-out.{question.es.1x,question.es.2x,question.ca.2x,recording.es.2x,sending.es.2x,blocked.es.1x}` (23:43–23:44, newer than the code they show) and their AUDIT.md sections.
**Evidence level:** code, the tester's widget and unit tests, and renders. Nothing here comes from an emulator or a phone.

### Findings

**UX-2804 · fixed**
- Title: `account_screen.dart:186-187` sets `semanticLabel` and `title` to `meetingSignOutTitle` (ES «¿Cerrar sesión?», EN “Sign out?”, CA «Vols tancar la sessió?»). AUDIT shows TalkBack's first node as «¿Cerrar sesión?» [route, names route], not «Alerta».
- Body: `account_screen.dart:165-177`.
  - Starts with `meetingSignOutRecording` when a meeting is recording now.
  - Other waiting meetings follow as a plural count (`others` = stopped + waiting, so the recording is counted on its own).
  - `meetingSignOutReminders` ends it.
- Primary: `meetingSendFirst` now reads «Guardar notas y cerrar sesión» / “Save notes and sign out” / «Desa les notes i tanca la sessió».
- Copy matches the brief in all three ARBs.
- Renders: question.es.2x, recording.es.2x and ca.2x clip nothing; the body scrolls inside the dialog at linear 2×.
- Note, not a defect: TalkBack reads the title twice, once as the route's name and once as the text (AUDIT lines 560-561). That is how Flutter's `AlertDialog.semanticLabel` works on Android, and it is better than «Alerta». Device check: hear it on TalkBack.

**UX-2805 · fixed**
- Order: Discard, then Cancel, then the primary (`account_screen.dart:190-212`). OverflowBar stacks them top to bottom in that order, and side by side they run left to right.
- Renders question.es.2x and ca.2x show red Discard at the top, Cancel in the middle and the filled primary at the bottom: well apart.
- The tester measured the gap at ≥ 56 dp and at least Cancel's height + 8.

**UX-2802 · fixed**
- `account_screen.dart:459-472` shows `meetingSavingNotes` under «Cerrar sesión», in `onSurfaceVariant`, with `liveRegion`, while `_running == signOut && _sendingMeetings`.
- `_sendingMeetings` is set before the stop and upload (:226) and cleared in `_run`'s `finally` (:58-64), so the line goes when sign-in shows or when the send fails.
- The spinner keeps its `meetingSending` label (:445-450).
- Render sending.es.2x shows the line under Cerrar sesión.

**UX-2803 · fixed**
- `authProvider.notifier` (:109) and the meeting controller (:112) are read before the first await, and the sign-out calls go through those references (:153-154, :222-223, :248).
- Every later `setState` and `ref.read` sits behind `mounted` (:226, :235-245, `_run` :51-64).
- Neither provider is autoDispose (`auth_provider.dart:36`, `meeting_controller.dart:451`), so the references outlive Cuenta.
- The tester's handlePopRoute tests cover Save, Discard and the plain sign-out that waits on `tellServerBeforeSignOut`. The real "offline send, then Back" case is a device check.

**UX-2806 · fixed**
- (a) `uploadNow()` returns `MeetingSendResult` (done, offline, slow, blocked) without changing the loop (`meeting_controller.dart:316-351`).
- (b) `meetingSendFailure(l, meetings, result)` (`meeting_banners.dart:106-114`): held-back reason first, then offline → `meetingSendFailed` (new offline text), otherwise `meetingSendSlow`.
- (c) When every waiting recording is held back and none is recording (`account_screen.dart:166-171`):
  - the body is `meetingHeldBackReason` followed by the reminders sentence;
  - the only buttons are red Discard and a filled Cancelar (:197-201).
  - Render blocked.es.1x shows the Pro case.
- (d) `meetingDiscardDeletesAll(count)` is appended to the lost message when more than one recording waits (`meeting_banners.dart:91-95`).
- MN-13: every non-done result returns before `auth.signOut()` (:232-246), and nothing is discarded on that path.

### Regressions (the change caused these)

**R1-P320-1 · Severity 2 · A sign-out pending after Back is invisible, then lands unannounced**
- Where: `App/lib/screens/account_screen.dart:33-34`, :226, :459. The `_running` and `_sendingMeetings` state lives in Cuenta's widget state, while the work now goes on after Cuenta is popped (UX-2803).
- The moment: "I pressed Back while it was saving. I came back to Tu cuenta and Cerrar sesión is just sitting there again: did it cancel? Should I tap it again?" A few minutes later, while they're doing something else, the app jumps to sign-in.
- What happens:
  - On re-entry, `busy` is false: «Cerrar sesión» is enabled, with no spinner and no saving line. A second tap asks the question again and starts a second flow.
  - When the first upload finishes, `auth.signOut()` runs from wherever the person is, possibly over an open task form, with nothing on screen having said it would.
  - Before this package, Back silently dropped the sign-out. The deferred sign-out is new, and it has no visible status outside Cuenta.
- Why it fails: visibility of system status (Nielsen 1994); change blindness (Rensink et al. 1997); lens B and lens I.
- Fix, smallest first: keep "signing out after the notes are saved" outside the screen, for example a flag the MeetingController or a small provider holds from the tap until sign-in or failure. Cuenta reads that flag, so reopening it shows the disabled Cerrar sesión, its spinner and the `meetingSavingNotes` line again, and a second flow can't start. No new copy is needed.
- Verify: a widget test. Tap Save, press Back, push Cuenta again before the fake upload finishes: the saving line shows and Cerrar sesión is disabled. Device check: Back mid-send with a form open when the sign-out lands.
- Evidence: verified in code. The mid-form effect is inferred and needs a device check.

**R1-P320-2 · Severity 1 · A refused login after Save gets the "taking longer" text**
- Where: `App/lib/services/meeting_controller.dart:349` and `App/lib/widgets/meeting_banners.dart:111-114`.
- What happens:
  - `pass.stopped` (the account's login was refused or changed; `meeting_uploader.dart:31-33`) returns `blocked`.
  - When no waiting meeting carries a Pro, allowance or lost problem, `meetingHeldBackReason` is null.
  - Any result other than offline then shows `meetingSendSlow`: «…vuelve a probar Cerrar sesión en unos minutos». Retrying won't help, because uploads stop until the person signs in again.
- Fix: in `meetingSendFailure`, treat `blocked` with no known reason the way the app already treats a refused login (`requestProblemText`, or the auth layer's expired state), not as slow. No new copy.
- Verify: a controller and widget test with an uploader that throws the stop: no slow text.
- Evidence: verified in code. Rare in practice.

### Notes for the organizer
- The package's diff also changes `App/analysis_options.yaml` (analyzer excludes) and `App/pubspec.lock` (intl 0.20.3, matcher, meta and others). These look like environment side effects, and the pubspec files are out of the run's scope. They are not UX findings; check them before the merge.
- Device checks owed: TalkBack on the titled dialog; offline afternoon, Save, Back during the wait (from the brief); R1-P320-1 on a phone.

### Memory notes
- Sign-out with meetings now runs: «¿Cerrar sesión?» title, then Descartar, Cancelar, primary «Guardar notas y cerrar sesión». It offers only Discard and a filled Cancel when every recording is held back. The saving line sits under Cerrar sesión. `uploadNow()` returns `MeetingSendResult`.
- Recurring type: work moved out of a screen's lifetime (references read before awaits) while its progress state stayed in that screen's State, so reopening the screen loses the status.
