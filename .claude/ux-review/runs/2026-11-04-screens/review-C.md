## UX review — C · Meeting notes: the recording screen and the note's «Crear tarea» (D1, D3, D5) — 2026-11-04

**Verdict:** Ship after fixes. D1 and D5 work as decided. D3 has four problems: its one sentence never says what it asks for, «Continuar» can do nothing at all, a stray tap spends the only ask, and D1's new read makes a meeting note's main button change on every open.

**Walked** (newcomer, daily user, TalkBack user; ES, CA, EN; 1×, 1.3×, 2×; light and dark):
- First meeting with notifications off: Notas › «Grabar una reunión» › (the microphone dialog) › recording starts › the new card › «Continuar» › Android's dialog › back to the recording › Parar › «Preparando tus notas…». That's 3 taps and up to 3 dialogs (microphone, the card, Android) before the person can put the phone down. Before D3 it was 1 tap and up to 1 dialog.
- A later meeting, or one with notifications on: Notas › «Grabar una reunión» › recording (with the new audio line) › Parar. 2 taps, no extra dialog.
- The meeting's note › «Crear tarea» › the review › «Añadir tarea». 3 taps, unchanged.
- An ordinary note with a checklist (croquetas): it opens with one filled «Editar nota». The «Crear tarea» decision point is gone.

**Numbers:**
- Recording screen: 3 tap targets (Atrás, Parar 312 × 84 dp, Descartar 92 × 48 dp), unchanged. Words shown while recording, ES: 21 → 32 (the audio line adds 11). The line is last, so at 2× with a warning it sits below the fold (`recording.allowance-used.es.light.2x`). That is the intended design.
- The card: 1 target («Continuar», 118 × 60 dp), 14 words in ES, no title. TalkBack reads «Alerta», then the sentence, then «Continuar», then «Cerrar» (the dismiss scrim) (AUDIT `meetings/recording · notify-ask`).
- Recipe note: buttons in the bottom bar 2 → 1.

Evidence base:
- Renders in `App/build/ux/meetings/` and `notes/`, rendered 2026-11-04 21:49–21:54. `find App/lib App/assets -newer` finds no newer source, so they are current.
- AUDIT.md, code, and the widget tests in `test/meeting_screens_test.dart` (group "The owner's decisions of 2026-11-04").
- No device or emulator evidence this run.

### Findings (most severe first)

**UX-2901 · Severity 2 · The notification card never says what it asks**
- Where: `App/lib/l10n/app_es.arb:1509`, `app_ca.arb:1213`, `app_en.arb:4482` (`meetingNotifyAsk`), shown by `App/lib/screens/meeting_screen.dart:331`. Screen: recording, state notify-ask (`meetings/recording.notify-ask.*`).
- The moment: "«Para pararla desde la notificación…» — ¿parar qué? ¿Qué notificación? No veo ninguna. ¿Y esto qué me pide?"
- What happens:
  - The card has no title. Its whole content is a purpose clause with no main clause: «Para pararla desde la notificación y avisarte cuando las notas estén listas.»
  - It never names the recording, and it never says that notifications are off or that Android will now ask to allow them.
  - "-la" has no antecedent on the card. In Catalan, «Per aturar-la» can't refer to the recording at all, since the screen calls it «l'enregistrament» (masculine). It can only mean «la reunió», which you don't stop from a notification.
  - At 1× the card covers «Grabando» and the time (`recording.notify-ask.es.light.1x`), so nothing visible tells the person the recording has already started.
  - English is a fragment too: "So you can stop it from the notification, and so we can tell you…".
- Why it fails:
  - ON-6 and ON-8 (Apple Privacy; Android Notif permission; Kendrick 2018): one sentence on what the person gains, tied to what will arrive. The gain is half there, but the subject and the request are missing.
  - G, plain language (ISO 24495-1): the reader can't tell what is being asked.
  - Gulf of evaluation (Norman 2013): the person can't see that the recording started.
- Fix: keep D3's shape (one sentence, one «Continuar»), but make it a whole sentence that names the recording and the notifications:
  - ES: «Ya está grabando. Activa las notificaciones para pararla desde ahí y saber cuándo están listas las notas.»
  - If it must be strictly one sentence: «Activa las notificaciones para parar la grabación desde ahí y saber cuándo están listas las notas.»
  - EN: "Turn on notifications to stop the recording from there and to know when the notes are ready."
  - CA: «Activa les notificacions per aturar l'enregistrament des d'allà i saber quan les notes estan llestes.»
  - Keep «Continuar», «Continue» and «Continua».
- Verify: re-render `recording.notify-ask.*` (ES, CA, EN at 2×); the AUDIT TalkBack line reads the new sentence; the CA pronoun agrees, or the noun is named.
- Evidence: seen in current renders; verified in the ARB files.

**UX-2902 · Severity 2 · «Continuar» does nothing where Android shows no dialog**
- Where: `App/lib/screens/meeting_screen.dart:346`. The result of `access.requestPermission()` is ignored, and the catch only covers a throw. The same path runs on `flutter_local_notifications` 22.3.3, `requestNotificationsPermission`.
- The moment: "He pulsado Continuar y no ha pasado nada. ¿Lo he hecho bien?"
- What happens:
  - On Android 7–12 (minSdk 24) there's no runtime permission. The plugin just returns `areNotificationsEnabled()` and shows no dialog.
  - On Android 13+, after the person turned TaskFlow's notifications off in Settings, or refused twice (from reminders, for instance), Android also shows nothing.
  - In both cases «Continuar» closes the card and nothing follows. Because the ask is now spent, this phone never asks again. The recording notification and «notas listas» stay off with no way in from here.
  - Reminders handle the same `false` result with a feedback line «El teléfono no deja que TaskFlow te avise.» and «Permitir avisos», which opens TaskFlow's notification settings (`App/lib/widgets/reminder_control.dart:295`).
- Why it fails:
  - B, feedback: every tap answers (Nielsen 1994, visibility of system status).
  - ON-7 (Android Permissions; Android 11 Permissions): a denial is not a dead end, so plan for the "denied twice" state.
  - F, consistency: the same `false` result gets a different outcome in reminders.
- Fix: when `requestPermission()` returns false, show the reminders' existing feedback (`notificationPermissionOff` with the `allowNotifications` action, through `showFeedback`), as `turnOnReminders` does.
  - That's one existing line and one action, with no new copy and no new ask. After a real refusal in Android's dialog it also tells the person what they chose.
  - If the owner reads that as asking again after a refusal, the narrower fix is: on Android < 13 only, «Continuar» opens `access.openNotificationSettings()` instead of `requestPermission()`.
- Verify:
  - Widget test: `FakeReminderAccess` returning false from `requestPermission`, then expect the feedback with «Permitir avisos».
  - Phone check on Android 12 or lower, and on Android 13+ after turning notifications off in Settings.
  - Also on a phone: once the permission is granted mid-recording, does the recording's own notification show in the shade at once, or only when the next piece starts (`MeetingAudioEngine.next` re-posts the notice about every 5 minutes)? The card promises «pararla desde la notificación» straight away.
- Evidence: verified in code (app and plugin). The device behaviour is inferred and needs a phone check.

**UX-2903 · Severity 2 · A meeting note's main button changes on every open**
- Where: `App/lib/screens/task_detail_screen.dart:285-296` and `:566`, `App/lib/widgets/note_task.dart:33` (`meetingNotesProvider` is `autoDispose` and read only when the page opens). Compare `App/lib/screens/main_shell.dart:89`, which pre-reads `noteTasksProvider` for exactly this reason (R1-P318-1).
- The moment: "Iba a tocar «Editar nota» y de repente ahí pone «Crear tarea»."
- What happens:
  - While the new marks load, `makesTask` is false because the set is empty, so the placeholder that holds the main button's place (`!linksRead && makesTask`) never shows.
  - The bar first draws the recipe layout: one filled «Editar nota», centred.
  - A moment later it becomes a filled «Crear tarea» plus an outlined «Editar nota». At 1× they sit side by side, and the centre where «Editar nota» was becomes the gap between them. At 2× «Crear tarea» takes the top row, where «Editar nota» was.
  - Because the provider is `autoDispose`, this happens every time a meeting note opens, not only the first time.
  - It undoes R1-P318-1's guarantee that the note's "main button shows the right label from the start".
- Why it fails:
  - D, reach (Fitts 1954): a target must not move or change under the finger.
  - Change blindness (Rensink et al. 1997).
  - F: the same component behaves the same.
- Fix: read the marks the way `noteTasksProvider` is read.
  - Make `meetingNotesProvider` keep-alive and `ref.listen` it in `main_shell.dart` beside `noteTasksProvider`.
  - Invalidate it where a meeting's note is saved (after `MeetingStore`'s save, or in the controller that reports notes ready).
  - While it is still unread, key the placeholder on "a note with an open step" rather than on `makesTask`, so the bar holds its place instead of flashing the recipe layout.
- Verify: a widget test whose `meetingNotesOverride` completes after a delay. Pump one frame and expect no filled «Editar nota» on a meeting note with open steps, and no layout change once it resolves. Then walk the note's page on the emulator.
- Evidence: verified in code. The renders show only the settled state.

**UX-2904 · Severity 2 · A stray tap outside the card spends the only ask**
- Where: `App/lib/screens/meeting_screen.dart:331` (`showDialog` with the default `barrierDismissible: true`). The ask is marked as asked before the card shows (`:327`). The test 'D3: closing the sentence asks nothing more' encodes this behaviour.
- The moment: the person has just tapped «Grabar una reunión» and is putting the phone down on the table as the meeting begins. A thumb brushes the dimmed screen, the card vanishes, and this phone never asks again.
- What happens: any touch on the scrim closes the card with no answer, and the one ask per phone is used up. After that, Parar and Descartar never show in the shade and «notas listas» never arrives. D3 says "never after a refusal", but a brush of the scrim is not a refusal.
- Why it fails:
  - I, interruptions and recovery.
  - ON-8 (Android Notif permission): swiping a dialog away "leaves the state unchanged, so plan for asking again".
  - RE-3: older hands touch the screen by accident.
- Fix: `barrierDismissible: false` on this one card. Back still closes it, which is a deliberate act, and ON-6's "if the user dismisses it, don't show the system dialog" still holds. Update the test to use Back instead of `tapAt`.
- Verify: widget test: a tap on the scrim leaves the card up, and Back closes it with no Android dialog.
- Evidence: verified in code and the test; the dismiss scrim is in AUDIT's TalkBack list («Cerrar» → dismiss).

**UX-2905 · Severity 1 · Meeting notes saved before this update lose «Crear tarea»**
- Where: `App/lib/services/meeting_note.dart` (`MeetingNoteMarks`) and `App/lib/services/meeting_store.dart:943`. Only notes saved from now on are marked, and nothing marks earlier ones.
- The moment (whoever installed the staging APK from main's 2026-11-04 03:22 release, #15): "Ayer esta nota tenía «Crear tarea». ¿Dónde está?"
- What happens: a meeting note saved by the released build, with open to-dos and no task made yet, now opens with «Editar nota» only, like a recipe. Its `meetings` row, which holds `note_id`, is deleted once the result is seen (`markSeen`, `clean`), so most of these can't be traced back.
- Why it fails: consistency over time (Nielsen 1994): a control the person has seen goes missing with no reason given. The audience is small: staging testers, the owner first.
- Fix: a one-time step at upgrade that marks every note still linked from a `meetings.note_id`. For the rest, accept the loss and tell the owner. Don't guess from the note's text.
- Verify: unit test: a database with a saved meeting row whose `note_id` is unmarked; after the upgrade step, `MeetingNoteMarks.read` includes it.
- Evidence: verified in code and git history (`3e80ab9` merged into main, which builds the staging APK per AGENTS.md).

### Keep (5 bullets at most)
- D1 does what was decided: the croquetas note opens with one filled «Editar nota» (`notes/note.with-steps.es.light.*`), and a meeting's note keeps «Crear tarea» filled with «Editar nota» outlined (`meetings/note.create-task.*`). The mark lives in the same transaction as the note (`meeting_store.dart:943`), and undo of a delete keeps the same id (`task_database.dart:705`), so the mark survives Deshacer.
- D5's line is placed right: it comes last and quieter, after the help line and any warning. At 2× it never pushes the help, a warning or Parar out of view (`recording.allowance-used.es.light.2x`, `recording.space-low.ca.light.2x`). It's hidden when stopping fails. Contrast passes in light and dark (AUDIT: no problems). TalkBack reads it after the help line.
- D3 respects ON-6: dismissing the card never opens Android's dialog, recording goes on behind it, and it never shows when notifications are on.
- The CA and EN copy for D5 reads naturally («L'àudio s'envia per fer les notes i després s'esborra.»); «Continua» matches CA's imperative buttons («Atura», «Descarta»).

### Progress against UX_REVIEW.md (U1–U14)
`../UX_REVIEW.md` isn't present in this cloud checkout, so this isn't assessed. Nothing in this change touches U2, U10 or U13. D1 subtracts one decision from every non-meeting note with steps, which is in the spirit of CO-9.

### Questions for the owner (product decisions only)
- None new. D1, D3 and D5 aren't reopened. UX-2902's narrower fix only matters if the owner treats the existing «Permitir avisos» line as "asking again after a refusal".

### Cross-slice notes
- D: the new private notes-ready notification (D6) and "up to 20 hours" (D4) are out of my slice. The lock-screen behaviour is a phone check, as the brief says.

### Phone checks owed
- Android 12 or lower, and Android 13+ with notifications turned off in Settings: what «Continuar» does (UX-2902).
- After granting mid-recording: whether the recording's notification with Parar and Descartar shows at once (UX-2902).
- TalkBack on the card: «Alerta», then the sentence; that focus lands on the card over a running recording.

### Memory notes
- New pattern: meeting notes are marked phone-locally (`MeetingNoteMarks`, scope `meetingNotes:<owner>` in `app_preferences`). Only a marked note with an open step offers «Crear tarea» (`noteMakesTask(note, ids)`). Synced copies on other phones don't.
- New pattern: D3's one-time notification ask on the recording screen, `ReminderPreferenceStore.meetingNotificationsAsked` (per phone, not per account). It's set before the card shows, so any outcome spends it.
- Recurring problem, again: a new async read added beside a pre-read one (`noteTasksProvider` is pre-read in `main_shell`, while `meetingNotesProvider` is `autoDispose`) breaks a "right label from the first frame" guarantee. Check every new provider that a button's label or layout depends on.
- Recurring problem: a permission request whose `false` result is ignored. `flutter_local_notifications`' `requestNotificationsPermission` shows no dialog on Android < 13, or once the permission is user-fixed. Every caller needs a visible outcome for `false`, as `turnOnReminders` has.
- Catalan check: a pronoun in a fragment has to agree with the noun the screen uses («l'enregistrament» is masculine, «la reunió» feminine).
