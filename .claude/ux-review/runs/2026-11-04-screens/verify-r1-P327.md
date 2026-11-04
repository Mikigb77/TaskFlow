## UX verify — P327 (area C), round 1 — 2026-11-04
**Verdict:** Ship. All three findings are fixed as the package's acceptance asked; no regression found in the changed files or the flows they touch.
**Read:** the package diff (`waves.py diff --worktree .claude/worktrees/wf_a74c231d-d1a-2`), `App/lib/screens/meeting_screen.dart:314-364` and its Scaffold (`:562-620`), `showFeedback` (`App/lib/widgets/app_components.dart:11-35`), `turnOnReminders` (`App/lib/widgets/reminder_control.dart:285-310`), the generated catalogs, the new P327 test group and the edited D3 test, and the renders `meetings/recording.notify-ask.{es.light.1x, es.light.2x, ca.light.2x, en.light.2x}` with AUDIT's `meetings/recording · notify-ask` section. Renders are dated 2026-11-04 22:18, and no file under App/lib or App/assets is newer, so they are current.
**Evidence level:** code, widget tests (as the tester reported them; Flutter not run here) and preview renders. No device.

### Findings
**UX-2901 · fixed**
- ARBs: ES `app_es.arb:1509` «Activa las notificaciones para parar la grabación desde ahí y saber cuándo están listas las notas.», EN `app_en.arb:4482` "Turn on notifications to stop the recording from there and to know when the notes are ready.", CA `app_ca.arb:1213` «Activa les notificacions per aturar l’enregistrament des d’allà i saber quan les notes estan llestes.» (typographic ’). `@meetingNotifyAsk` description updated; «Continuar»/"Continue"/«Continua» unchanged. Generated catalogs carry the same strings (`app_localizations_{es,en,ca}.dart`).
- The card is still one sentence and one button with no title (`meeting_screen.dart:335-345`); the subject (the recording), the request (turn on notifications) and the gain are now all in it. The CA pronoun problem is gone: the noun is named.
- Renders: es/ca/en 2× show the whole sentence and the button inside the card, nothing cut off; es 1× reads in four lines. AUDIT: no problems in any of the 6 renders. Tests check the exact copy, no title, one button, no other Text, and 2× containment on 360×740.

**UX-2904 · fixed**
- `meeting_screen.dart:337` `barrierDismissible: false` on this one `showDialog`; no other dialog touched. `setMeetingNotificationsAsked()` not moved (D3 kept).
- Back still closes it: `go` is null, so `return` before `requestPermission` (`:349`), which keeps ON-6.
- AUDIT's TalkBack list now reads «Alerta» → the new sentence → «Continuar», with no «Cerrar» dismiss node. Tests tap the scrim in four places (card stays), then Back closes it with permissionRequests 0, the ask spent, and the recording screen and help line still there.

**UX-2902 · fixed** (device behaviour still owed, see deviceChecks)
- `meeting_screen.dart:349-363`: the result of `requestPermission()` is now kept, a throw counts as not allowed, and when not allowed and still mounted it shows `notificationPermissionOff` with `allowNotifications` → `access.openNotificationSettings()` through `showFeedback`, the messenger and strings captured before the dialog (`:330-331`). Existing copy only; reminders are not switched on (no `turnOnReminders`/`_finishOnReturn`), matching the brief.
- The line floats above the bottom bar (`showFeedback` is floating with no margin; Parar/Descartar live in `bottomNavigationBar`, `:575`), so it never covers Parar.
- Tests: refused → card closes, «El teléfono no deja que TaskFlow te avise.» with «Permitir avisos», action opens settings once, no reminder-setting writes, Android asked once, a later meeting doesn't ask; a throwing request → same line and action; granted → no SnackBar, and no later ask even with notifications off again.

### Regressions
None. Checked: the stray-tap change keeps Back working and ON-6; the new line can't show over a popped screen (`mounted` check) and sits above Parar; the existing D3 tests still assert one ask per phone; the preview description matches the new sentence.

### Notes (not regressions)
- No preview renders the refusal line after «Continuar» on the recording screen. From the code, at 2× the action wraps under the text (`_FeedbackWithAction`), so for its timeout the line covers the lower part of the recording body (help/D5 lines), not Parar. Transient and the same pattern reminders use; worth a look in the device check.
- After «Permitir avisos» and a return from Settings nothing confirms the change on this screen (by design: the brief rules out `_finishOnReturn`). Whether the recording notification with Parar appears at once is already in the package's deviceChecks.
- Owner-level, already raised in review-C ("Questions for the owner"): on Android 13+, a first refusal in Android's own dialog now also gets the «Permitir avisos» line. The plan treats it as no second ask (D3); not reopened here.

### Device checks still owed (from the package)
Android ≤12 and 13+ (off in Settings / refused twice) «Continuar» line and settings action; recording notification right after a mid-recording grant; TalkBack focus and reading on the card.

### Memory notes
- D3's card on the recording screen is now `barrierDismissible: false` (Back only), and a false/throwing `requestPermission()` shows reminders' `notificationPermissionOff` + «Permitir avisos» (opens settings only; never switches reminders on). One sentence: «Activa las notificaciones para parar la grabación desde ahí y saber cuándo están listas las notas.»

---

## Re-check (replayed verify step) — 2026-11-04, after 22:38
This verify step was dispatched again after P327 had been merged (merges.jsonl, 22:25:09) and its worktree `.claude/worktrees/wf_a74c231d-d1a-2` removed, so the worktree diff could not be read. I re-checked read-only in the main checkout (`git diff HEAD -- App/lib/screens/meeting_screen.dart`, the ARBs, generated catalogs, tests and renders), which by now also holds P328, P329 and P330. Flutter not run.

**Result: verdict unchanged, Ship. All three findings still fixed in main; the later merges (P330 also edits the ARBs and meeting_previews.dart, P328 adds tests to meeting_screens_test.dart) did not undo any P327 change.**
- UX-2901 fixed: `app_es.arb:1509`, `app_en.arb:4482` (with the new `@meetingNotifyAsk` description), `app_ca.arb:1213` carry the exact sentences; `meetingNotifyAskContinue` unchanged; generated `app_localizations_{es,en,ca}.dart` match. Render `meetings/recording.notify-ask.ca.light.2x.png` (22:38:31; `find App/lib App/assets -newer` it is empty, so current) shows the whole Catalan sentence in seven lines and «Continua» inside the card, nothing cut off. AUDIT `meetings/recording · notify-ask`: 6 renders, 0 problems.
- UX-2904 fixed: `meeting_screen.dart` `showDialog(... barrierDismissible: false ...)` in `_askNotifications` (:318 on); `setMeetingNotificationsAsked()` not moved; `go != true` returns before `requestPermission`. AUDIT TalkBack list (es.light.1x): «Alerta» → the new sentence → «Continuar», no «Cerrar». Tests `meeting_screens_test.dart:4737` (four scrim taps, then Back; permissionRequests 0, marked, help line shown) and `:4768`; D3 test edited at `:4531`.
- UX-2902 fixed (device behaviour owed): `ScaffoldMessenger` captured before the dialog; `allowed = await access.requestPermission()`, throw → false; `if (allowed || !mounted) return;` then `showFeedback(messenger, l.notificationPermissionOff, actionLabel: l.allowNotifications, onAction: openNotificationSettings)`. No `turnOnReminders`/`_finishOnReturn`. Tests `:4781` (refused: line, action opens settings once, `store.writes` 0, no re-ask on a later meeting), `:4818` (throwing), `:4836` (granted: no SnackBar).

**Regressions:** none found. Earlier notes (unrendered refusal line at 2×, no confirmation after Settings, Android 13+ first refusal getting the line) stand as notes, not regressions.
