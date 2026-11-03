## UX review — D · Meeting notes: sign-out, notifications and Pro — 2026-11-03

**Verdict:** Ship after fixes. Nothing here loses a recording without warning. But the notes-ready notification and the recording's Stop/Discard don't show without a permission the meeting flow never asks for. "Send first" can wait for minutes behind an unlabelled spinner. The Pro screen and the sign-out question are worded for only one of the cases that reach them.

**Scope and evidence:** commit `3efed60` (there is no `refs/ux-review/last`, so the commit's own diff is the change). I read every listed file in full or through its diff: `account_screen.dart`, `subscription_screen.dart`, `notification_service.dart`, `meeting_audio.dart`, plus `meeting_copy.dart`, `meeting_banners.dart` (the send-failure copy and the Pro entries), the meeting part of `main.dart`, and the meeting strings in all three ARB files. Renders: `meetings/sign-out.question.*` (4) and `meetings/pro.reason.*` (2), rendered 2026-11-03 22:31 from `3efed60`. `find -newer` lists no app file changed since, so they are fresh. `settings/pro.*` and `settings/account.*` (22:32) were used for comparison. AUDIT.md: `meetings/sign-out · question` (nothing flagged). No device captures exist for this run, and every notification point rests on code. `../UX_REVIEW.md` is missing from this checkout (no U1–U14 to track).

**Evidence gap, not a user finding:** `meetings/pro.reason.*` renders the Pro screen with the store unreachable: «Estado de suscripción no disponible», the test-store card, the error line, no price and no «Ver suscripción». The happy path is not shown, unlike `reminders/sheet.pro-screen.*`. The preview at `App/test/ux_previews/meeting_previews.dart:441-453` needs the priced offering that `reminders_previews.dart` uses, so the Pro findings below can be verified on a render.

**Walked** (Newcomer: ES, 2×, one hand. Daily user. TalkBack):
1. Sign out with a recording waiting, «Enviar primero»: Cuenta › Cerrar sesión › question › Enviar primero › wait (seconds to minutes) › sign-in. That's 3 taps and 3 choices in a 28-word question.
2. Same, «Descartar y cerrar sesión»: 3 taps, no undo.
3. Same, sending fails (offline, Pro lapsed, allowance used, lost piece): 3 taps › red message › what now?
4. Sign out while a meeting is still recording: the same question, which never says a recording is running.
5. Free account › Notas › Grabar una reunión › Pro screen › Ver suscripción › paywall › back › back to Notas › Grabar una reunión again: 6 taps after buying.
6. Pro lapsed with a recording held back: Notas line › Ver Pro › Pro screen.
7. Recording, phone locked: shade › «Grabando una reunión» · Parar / Descartar.
8. Notes ready with the app in the background: notification › tap › the note. Then sign out and sign in as someone else.

**Numbers:**
- Sign-out question: 28 words plus 3 buttons (ES 1×). The stacked buttons are 48 / 48 / 60 dp tall with 8 dp gaps. The red «Descartar y cerrar sesión» sits 8 dp above the filled «Enviar primero» (AUDIT).
- Taps to start recording after buying Pro: 3 → 1 possible.
- Visible words while «Enviar primero» works: 0 (the spinner's label is for TalkBack only) → 1 line.

### Findings (most severe first)

**UX-2801 · Severity 3 · Meeting notifications need a permission nobody asks for**
- Where: `App/lib/services/notification_service.dart:544` (`showMeetingNotesReady`), `:516` (`showMeetingRecording`); the only request is `turnOnReminders` (`App/lib/widgets/reminder_control.dart:295`). The meeting flow checks only the microphone (`meeting_controller.dart:234`). The promise is in `meetingPreparingHelp` and `meetingWaitingConnectionHelp` («…te avisaremos»), shown at `meeting_screen.dart:646`.
- The moment: "It said it would let me know when the notes were ready. Nothing came, so it must have failed." Or, phone locked: "How do I stop it? There's nothing in my notifications."
- What happens: reminders are off by default (D2), and the permission is asked only from the first-dated-task sheet («Sí, recuérdamelo») or from Ajustes › Notificaciones. Someone who answered «Ahora no», or whose first use is a meeting, has no POST_NOTIFICATIONS on Android 13+. Then:
  - «Las notas de tu reunión están listas» is never shown;
  - the recording's notification, with Parar and Descartar, appears only in Android's Task Manager, not in the notification drawer. Android's page: "they still see notices related to foreground services in the Task Manager but don't see them in the notification drawer".
  - The app still says «te avisaremos».
- Why it fails: ON-5 and ON-8 (ask when the feature is used, with what will arrive: Android Notif permission). UN-7 and Norman's gulf of evaluation: a promised signal that never comes reads as failure. MN-1 and MN-11 both rely on these notifications.
- Fix:
  - At the first «Grabar una reunión» of an account on this phone, if `areNotificationsEnabled()` is false, ask right after the microphone with one sentence, then Android's dialog. EN "So you can stop it from the notification and hear when the notes are ready." / ES «Para pararla desde la notificación y avisarte cuando las notas estén listas.» / CA «Per aturar-lo des de la notificació i avisar-te quan les notes estiguin a punt.» Use one «Continuar» button (ON-6). It isn't asked again after a refusal.
  - When notifications stay off, drop the promise: `meetingPreparingHelp` becomes EN "It takes a few seconds. You can leave this screen: the notes will be in Notes." / ES «Tarda unos segundos. Puedes salir de esta pantalla: las notas aparecerán en Notas.» / CA «Triga uns segons. Pots sortir d'aquesta pantalla: les notes apareixeran a Notes.» Change `meetingWaitingConnectionHelp` the same way («…y aparecerán en Notas»).
  - This is a permission request in a new place, so the main session should note it next to D2.
- Verify: a widget test with notifications refused: the ask appears once before the first recording, and the copy without the promise shows after a refusal. Phone check (Android 13+, permission denied, then granted): the recording notification is in the drawer with Parar and Descartar, and «Las notas de tu reunión están listas» arrives with the app closed.
- Evidence: verified in code, plus Android's documentation; the device behaviour needs a phone check.

**UX-2802 · Severity 3 · «Enviar primero» waits minutes with nothing written on screen**
- Where: `App/lib/screens/account_screen.dart:186-210` and `:409-416`. The status text `meetingSending` is only the spinner's `semanticsLabel`. The wait is in `meeting_controller.dart:299-317`.
- The moment: "I pressed send and now everything is greyed out with a little red circle. Is it stuck? Can I leave?"
- What happens: `uploadNow()` uploads every waiting piece and then waits for the notes themselves (the backlog counts `finishing` meetings). It retries for up to 2 minutes beyond the upload time. For an offline afternoon that is dozens of pieces. All the while the screen shows only an 18 dp spinner beside «Cerrar sesión», with every button disabled. The regular sign-out can now also wait up to 10 s longer when a note was just saved (`tellServerBeforeSignOut`, `:144`), on top of UX-508's 12 s.
- Why it fails: PE-2. Beyond 10 s, give an explanation plus a way out (Nielsen 1993; Sherwin 2014pr). Visibility of system status (Nielsen 1994).
- Fix: while sending, show the words under «Cerrar sesión», in `onSurfaceVariant`:
  - EN "Saving your meeting's notes… This can take a few minutes. Then you'll be signed out."
  - ES «Guardando las notas de la reunión… Puede tardar unos minutos. Después se cerrará la sesión.»
  - CA «Desant les notes de la reunió… Pot trigar uns minuts. Després es tancarà la sessió.»

  Keep the spinner's label as it is. The way out is UX-2803.
- Verify: a widget test with a slow fake uploader: the line shows within 1 s of «Enviar primero» and goes on sign-in or failure. Add a render `meetings/sign-out.sending.es.light.2x`.
- Evidence: verified in code.

**UX-2803 · Severity 2 · Leaving the screen mid-send silently cancels the sign-out**
- Where: `App/lib/screens/account_screen.dart:180-213` (and `:143-146`). The last step is `ref.read(authProvider.notifier).signOut()` after the awaits. Riverpod 2.6.1 throws `Cannot use "ref" after the widget was disposed` (`flutter_riverpod-2.6.1/lib/src/consumer.dart:548-551`). `_run` catches it and, unmounted, shows nothing.
- The moment: "I asked it to sign me out before lending the phone. Later it's still my account."
- What happens: nothing blocks Back during the wait (UX-2802). If the person leaves, the uploads go on, but the sign-out they confirmed never happens and nothing says so. On the «Descartar» path, the recordings are already deleted and the account stays signed in.
- Why it fails: Norman's gulf of evaluation (a confirmed action quietly not done). PE-2 asks for an explicit way out rather than an accidental one.
- Fix: a confirmed sign-out finishes even if the screen is left. Read `authProvider.notifier` and the controller before the first await and call them from those references. On failure with the screen gone, nothing changes, and the Notas line already says why the recording is waiting. Back is the way out in UX-2802's line only if the owner prefers it; then the line ends with ES «Si sales, la sesión sigue abierta.» and the code must make that true deliberately.
- Verify: a widget test: «Enviar primero» with a slow uploader, pop the Account route, let the uploader finish, and the app is on sign-in. The same for «Descartar y cerrar sesión» and the 10 s path.
- Evidence: verified in code (the Riverpod source read); inferred for a device.

**UX-2804 · Severity 2 · Sign-out question says «enviado», never "recording now"**
- Where: `meetingSignOutQuestion`, `meetingSendFirst` (all three ARB files); counted at `App/lib/screens/account_screen.dart:113-117`. The ongoing recording is stopped at `:192` and discarded by `discardAll`.
- The moment: "Sent? To whom? I'm still recording. What happens to it if I press this?"
- What happens:
  - The count lumps a running recording, recordings stopped by themselves and recordings waiting for notes, all as «aún no se ha enviado». "Sent" is the app's internal step; the person thinks in notes.
  - «Enviar primero» stops a running meeting without saying so, and «Descartar y cerrar sesión» deletes it.
  - The dialog has no title, so TalkBack opens with «Alerta» (AUDIT).
- Why it fails: plain language, ISO 24495-1 (the user's words, no internal terms). UN-4 (name the outcome). Match with the real world (Nielsen 1994).
- Fix: title EN "Sign out?" / ES «¿Cerrar sesión?» / CA «Vols tancar la sessió?». Body:
  - recording now: EN "You're recording a meeting. It stops, and its notes are made before you sign out." / ES «Estás grabando una reunión. Se parará y se harán sus notas antes de cerrar sesión.» / CA «Estàs enregistrant una reunió. S'aturarà i se'n faran les notes abans de tancar la sessió.»
  - otherwise, with plural: EN "A meeting's notes aren't ready yet, and its recording is only on this phone." / ES «Las notas de una reunión aún no están listas, y su grabación solo está en este teléfono.» / CA «Les notes d'una reunió encara no estan a punt, i l'enregistrament només és en aquest telèfon.»
  - keep the reminders sentence.

  Buttons: EN "Save notes and sign out" / ES «Guardar notas y cerrar sesión» / CA «Desa les notes i tanca la sessió», and keep «Descartar y cerrar sesión».
- Verify: re-render `meetings/sign-out.question.*`, plus a new `.recording` state, at ES/CA 2×. AUDIT's TalkBack list starts with the title.
- Evidence: verified in code and in the current renders.

**UX-2805 · Severity 2 · Irreversible «Descartar» sits 8 dp above the primary**
- Where: `App/lib/screens/account_screen.dart:158-174`. The stacked order is Cancelar, Descartar y cerrar sesión, Enviar primero (`actionsOverflowButtonSpacing: 8`). Renders: `sign-out.question.es.light.1x` and `.2x`.
- The moment: the thumb going for the big green button at the bottom lands on the red two-line text right above it, and an hour's meeting is gone.
- What happens: at every scale and language the buttons stack. The destructive one, with no undo, sits between Cancel and the primary, 8 dp from the primary (AUDIT: 196 × 48 dp; primary 148 × 60 dp).
- Why it fails: RE (keep destructive actions apart from the primary and from accidental reach: Bergstrom-Lehtovirta & Oulasvirta 2014; Hoober 2017a). UN-4 (the destructive one is never next to or like the default).
- Fix: order the actions as Descartar y cerrar sesión, Cancelar, then the primary. Cancel then separates them in the stacked and the side-by-side layouts.
- Verify: re-render. In AUDIT, the gap from «Descartar…» to the primary is Cancel's row (≥ 56 dp), not 8 dp.
- Evidence: seen in a current render and measured in AUDIT.

**UX-2806 · Severity 2 · Send failures don't say how to retry, and offer sends that can't succeed**
- Where: `meetingSendFailed`, `meetingSendFailedLost`, `meetingSendFailedPro`, `meetingSendFailedAllowance` (ARB); `meetingSendFailure` (`App/lib/widgets/meeting_banners.dart:82-92`); the 2-minute cap at `meeting_controller.dart:313`.
- The moment: "«Vuelve a intentarlo con conexión». I have Wi-Fi! Try what again, and where?"
- What happens:
  - «No se pudo enviar todo» also shows when the phone is online but the notes took over 2 minutes, which wrongly blames the connection.
  - None of the messages says that retrying means tapping «Cerrar sesión» again.
  - The question offers «Enviar primero» even when the app already knows a recording can't be sent (lost, Pro lapsed, allowance used), so the person waits only to fail.
  - «Descártala para cerrar sesión» leads to «Descartar y cerrar sesión», which deletes every waiting recording, including ones that could still be sent.
- Why it fails: UN-7 (what happened, what to do: Neusesser & Sunwall 2023). Error prevention (Nielsen 1994).
- Fix:
  - Split the generic case. Offline: EN "No connection, so the notes couldn't be made. You're still signed in; tap Sign out again once you're online." / ES «Sin conexión, no se pudieron hacer las notas. Sigues con la sesión abierta; vuelve a tocar Cerrar sesión cuando tengas conexión.» / CA «Sense connexió, no s'han pogut fer les notes. Continues amb la sessió oberta; torna a tocar Tanca la sessió quan tinguis connexió.» Slow: EN "The notes are taking longer than usual. You're still signed in; try Sign out again in a few minutes." / ES «Las notas están tardando más de lo normal. Sigues con la sesión abierta; vuelve a probar Cerrar sesión en unos minutos.» / CA needs translation.
  - When every waiting recording is already known to be blocked (lost, Pro, allowance), the question shows the matching reason as its body and offers only «Cancelar» and «Descartar y cerrar sesión».
  - Name the count in «Descártalas…» when there are several.
- Verify: widget tests per cause (offline, slow fake, lost, proRequired, allowance), checking the text and the buttons offered.
- Evidence: verified in code.

**UX-2807 · Severity 2 · Pro heading tells a waiting recording to "record a meeting"**
- Where: `billingReasonMeetingNotes` (ARB), used for both entries: `App/lib/screens/meeting_screen.dart:49-52` (Grabar una reunión) and `App/lib/widgets/meeting_banners.dart:316-320` / `meeting_screen.dart:675` (a recording held back for Pro, «Ver Pro»).
- The moment: "I already recorded it. Why does it tell me to record a meeting?"
- What happens: after Pro lapses, the Notas line says «Tu grabación espera en el teléfono» and «Ver Pro» opens a heading about recording a meeting, not about the recording that's waiting.
- Why it fails: match with the real world, and consistency (Nielsen 1994). Copy, lens G.
- Fix: one heading that fits both: EN "With Pro, your meetings become notes:" / ES «Con Pro, tus reuniones se convierten en notas:» / CA «Amb Pro, les teves reunions es converteixen en notes:». Keep the example. No new reason value.
- Verify: re-render `meetings/pro.reason.*` (with the priced store; see the evidence gap) and add a render from the held-back line.
- Evidence: verified in code.

**UX-2808 · Severity 2 · After buying Pro, the recording doesn't start**
- Where: `App/lib/screens/meeting_screen.dart:48-53`. It `await`s the Pro screen and then returns, whatever happened there.
- The moment: the meeting is starting now. "I paid. Where's the record button?"
- What happens: after the paywall the person is back on the Pro screen («Pro está activo»). They must press Back, find «Grabar una reunión» in Notas and tap it again. That's 2 extra steps at the worst moment, with no sign that the next step is back in Notas.
- Why it fails: A, next step (Norman 2013, the gulf of execution). Peak–end (Kahneman et al. 1993): the purchase ends nowhere.
- Fix: when the Pro screen was opened from «Grabar una reunión» and Pro is active once it closes, go straight on to the recording screen. Subtract the second tap rather than adding a button.
- Verify: a widget test: free → fake purchase → pop → `MeetingScreen` is pushed. Phone check with RevenueCat's test store.
- Evidence: verified in code.

**UX-2809 · Severity 2 · Pro's own benefit list leaves out meeting notes**
- Where: `App/lib/screens/subscription_screen.dart:174-179`; render `settings/pro.free.es.light.1x`.
- The moment: from Ajustes › TaskFlow Pro: "What do I get?" Meeting notes, a Pro-only feature, isn't listed, and a subscriber doesn't learn it's theirs.
- What happens: the list shows dictation, typing and reminders only. Meetings appear only as the reason heading when coming from Notas.
- Why it fails: SU-2 and SU-8 (say clearly what the subscription gives), and consistency.
- Fix: while meetings stay Pro-only (the build's default), add one line: EN "Notes from your recorded meetings" / ES «Notas de las reuniones que grabas» / CA «Notes de les reunions que enregistres». Hide it when the reason is `meetingNotes`, as reminders are hidden for `reminderPlans`. The RevenueCat paywall is external (owner question below).
- Verify: re-render `settings/pro.free.*` at CA 2×: the first benefit stays above the pinned «Ver suscripción», as P-run 2026-10-28 required.
- Evidence: verified in code and in a current render.

**UX-2810 · Severity 2 · Recording notification shows no sign it's still recording**
- Where: `App/lib/services/notification_service.dart:169-200` (`showWhen: false`, text null from `meetingNotice`, `App/lib/l10n/meeting_copy.dart:33-38`).
- The moment: phone in the pocket an hour in: "Is it still going? How much has it got?"
- What happens: the shade shows only «Grabando una reunión» with Parar and Descartar: no time and no change. The recording screen shows the elapsed time (MN-7); the notification, which is what a locked-phone user sees, doesn't.
- Why it fails: lens J (listening shows live evidence) and visibility of system status (Nielsen 1994).
- Fix: Android's own chronometer: `usesChronometer: true`, `showWhen: true`, `when` = now minus the time already recorded (for «Continuar», the time so far). No new string.
- Verify: unit test on `meetingRecordingNotificationDetails` (chronometer on, `when` set). Phone check: the shade's counter keeps time through a cut at about 5 min and after «Continuar».
- Evidence: verified in code; the look needs a phone check.

**UX-2811 · Severity 2 · «Notas listas» notification is never cleared, even after sign-out**
- Where: `App/lib/services/notification_service.dart:544-562` (posted). Nothing cancels `meetingNotesNotificationId`, neither `markSeen` (`meeting_controller.dart:286`) nor sign-out. Tap handling is at `App/lib/main.dart:385-396`.
- The moment: "I already read those notes in the app. Why is it still there?" And for the next person on the phone: "«Despido de Juan»? That's not mine." They tap it and nothing opens.
- What happens: opening the note from Notas leaves the notification up. «Guardar notas y cerrar sesión» (UX-2804) posts it moments before the sign-out, so it outlives the account and shows the meeting's title. After another account signs in, a tap is dropped (owner mismatch).
- Why it fails: NO-5 (every notification costs attention), recurring problem type "stale copy outliving its state", and a privacy slip (NO-9).
- Fix: cancel the notes-ready notification when that note is opened in the app (`markSeen`) and at sign-out. Sign-out already cancels reminders.
- Verify: unit test: `markSeen` and sign-out cancel id `0x7ffffffe`. Phone check: notes ready › open the note from Notas › the shade is empty.
- Evidence: verified in code.

**UX-2812 · Severity 1 · Notes-ready title is generic first, and the next one replaces it**
- Where: `meetingNotesReady` (ES «Las notas de tu reunión están listas», 36 characters; CA 36); `notification_service.dart:552-556` (one id for every meeting).
- What happens: the distinguishing part, the meeting's title, comes second and is cut first in a collapsed notification. Two meetings ready together (one offline day) leave only the last.
- Why it fails: NO-3 (title ≤ 30 characters, the item first: Android Notif design). NO-6.
- Fix: title = the note's title; text EN "Your meeting notes are ready" / ES «Las notas de la reunión están listas» / CA «Les notes de la reunió ja són a punt» (the current string as text). With no title, keep today's layout. Use the meeting's id as the notification's tag, or its own id, so each meeting keeps its notification.
- Verify: unit test on what `showMeetingNotesReady` posts.
- Evidence: verified in code.

### Keep
- The guard itself: sign-out never silently drops a recording, and a failed send keeps you signed in (`account_screen.dart:196-207`). MN-13 holds.
- The three Pro-specific failure messages already name the real cause («sin TaskFlow Pro», «el tiempo de reuniones de este mes»).
- Notes-ready is suppressed while that meeting's screen is in front (`meetingNotesNotified`), on its own channel («Notas de reuniones»), apart from reminders (NO-1).
- The recording notification is silent, low importance and public with a content-free title; its Discard asks in the app first, and «Seguir grabando» keeps recording.
- The Pro screen with a meeting reason keeps the settled order: reason, then plan, then benefits, with the pinned button (UX-2640).

### Progress against UX_REVIEW.md (U1–U14)
- Not assessable: `../UX_REVIEW.md` isn't in this checkout. Against North star: meetings add one quiet entry in Notas and no new step to the default task path.

### Questions for the owner (product decisions only)
- **Meeting time per month (SU-7):** the build caps meetings at about 20 hours a month (`AI_MEETING_PIECES_PER_MONTH` = 240). People first hear of it in «Has usado el tiempo de reuniones de este mes». Should the Pro screen and the Notas entry state the allowance up front, for example «hasta 20 horas al mes»? The number is yours.
- **RevenueCat paywall (as D7 of 2026-10-22):** add meeting notes to the paywall's Pro benefits in the dashboard yourself, if meetings stay Pro-only.
- **Lock-screen privacy (NO-9):** the notes-ready notification shows the meeting's title on the lock screen, as reminders show task titles. Keep it so, or hide the title there?
- **Notification ask at the first meeting (UX-2801):** it adds a permission request outside D2's first-dated-task sheet. Recommended, since the feature promises notifications.

### Cross-slice notes
- C: `meetingPreparingHelp` and `meetingWaitingConnectionHelp` promise «te avisaremos». UX-2801 changes their copy when notifications are off; C owns those screens.
- C: `openMeetingRecorder` (`meeting_screen.dart:34-53`) sends anyone whose `hasPro` is false after 5 s of billing loading to the Pro screen. A Pro subscriber whose store isn't ready (offline at the start of a meeting) may be sent there. That's inferred; it needs a phone check offline.
- Delete account (`delete_account_screen.dart`): its consequences don't mention recordings still waiting on this phone (`account_deletion.dart` erases them). Worth a line if area D's delete page is reviewed.
- Preview suite: `meetings/pro.reason` needs the priced store fake (see the evidence gap above).

### Memory notes
- Area D map: the Account screen's sign-out now has two questions. The meeting one (`meetingSignOutQuestion`) shows when a recording is running, stopped or waiting: Cancelar / Descartar y cerrar sesión / Enviar primero (stacked at every scale). Send first = `uploadNow()` up to notes saved, capped at 2 min of retries. The regular one waits up to 10 s more when a note's acknowledgement is pending (`tellServerBeforeSignOut`).
- Pro screen: `ProReason { reminderPlans, meetingNotes }`. `meetingNotes` comes from Notas › Grabar una reunión and from «Ver Pro» on a held-back recording. The benefit list hides reminders only for `reminderPlans`, and meetings aren't a listed benefit (UX-2809).
- Notifications: the recording is id 1 on `AudioRecordingChannel` (renamed «Grabación de reuniones»), re-posted over `record`'s plain one after each start or cut, with Parar/Descartar, both `showsUserInterface`. Notes-ready is one id, `0x7ffffffe`, channel `taskflow_meeting_notes`, never cancelled. Reminder row 1 moved to id `0x7fffffff`.
- Recurring problem (new type): work awaited inside a `ConsumerState` action, then `ref.read` after the awaits. Leaving the screen throws (`Cannot use "ref" after the widget was disposed`), `_run` swallows it, and a confirmed action silently doesn't happen (UX-2803). Check long awaited flows for it.
- Recurring problem: the notification permission is asked only by reminders (D2 sheet, Ajustes). Any new notification-based feature must check `areNotificationsEnabled()` itself (UX-2801). On Android 13+ without it, a foreground service's notification goes to Task Manager only.
- Technique: a preview of a Pro-gated entry must set up the priced store fake, or it renders the store-error state (`meetings/pro.reason`).
- `../UX_REVIEW.md` was absent in the 2026-11-03 cloud checkout.
