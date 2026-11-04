# UX plan — 2026-11-04-screens (screens)

D1, D4, D5 and D6 of 2026-11-04 work as decided. D3's card needs three fixes, and D1's new read makes a meeting note's bar flash on every open. Four packages share no app file, so all four can run at once. Two owner questions came up; neither blocks a package.

Scoped run: the plan goes straight to the implementers. Evidence: widget tests, preview renders (2026-11-04) and code; no device.

## Decisions for the owner

**D1 — The notes-ready notification on the lock screen (UX-3004, on D6/UX-2814).**
Review D found that `NotificationVisibility.private` is already Android's default. On a phone left at the default lock-screen setting, the meeting's title still shows on the lock screen, as before. It is hidden only where the person turned on "hide sensitive content". That is what D6 says as recorded.
- (a) Keep as recorded, no change.
- (b) A title-free lock-screen version, «Las notas de la reunión están listas», with the title once unlocked. This needs native code.
- (c) Secret: the notification doesn't appear on the lock screen at all.
- **Recommendation: (a).** It is D6 as worded, with no native code. Pick (b) only if you meant "never show the title on a locked phone". (c) hides the very thing the notification is for. Either way, a phone check covers both settings.

**D2 — «Hasta 20 horas al mes» and short meetings (UX-3003, on D4/UX-2720).**
The server counts five-minute pieces, and each meeting's last piece counts in full. A 2-minute call uses one of the 240 pieces. Many short meetings run out before 20 recorded hours.
- (a) Keep as is.
- (b) Count the last piece by its length on the server. The cost cap stays the same.
- (c) Say «unas 20 horas».
- **Recommendation: (a).** «Hasta» is truthful, and running out early would take about 8 short meetings a day all month. If staging shows otherwise, do (b) on the server. Cause: server-side.

## Packages (all can start at once; no dependencies)

**P327 · S2 · C · M — The first meeting's notification card** (`meeting_screen.dart`, the ARBs, tests, the preview)
- UX-2901: the sentence names what it asks: «Activa las notificaciones para parar la grabación desde ahí y saber cuándo están listas las notas.» (EN and CA in the brief); «Continuar» unchanged.
- UX-2904: `barrierDismissible: false`, so a stray tap no longer spends the only ask; Back still closes it.
- UX-2902: when Android shows nothing or refuses, the reminders' existing line «El teléfono no deja que TaskFlow te avise.» with «Permitir avisos» (opens the notification settings). No new copy and no new ask.

**P328 · S2 · C · M — A meeting note's bar is right from the first frame** (`note_task.dart`, `main_shell.dart`, `task_detail_screen.dart`, tests)
- UX-2903: `meetingNotesProvider` becomes keep-alive and is pre-read in the shell, like `noteTasksProvider`. It re-reads when a note is added or removed. While unread, the bar holds «Crear tarea»'s place for any note with an open step.

**P329 · S1 · C · S — Mark meeting notes saved before D1** (`task_database.dart`, a test)
- UX-2905: a schema 23 step marks every note still linked from a `meetings.note_id`. The rest can't be told apart and stay unmarked (see the note below).

**P330 · S1 · D · S — Pro screen polish** (`subscription_screen.dart`, the ARBs, tests, three previews)
- UX-3001: 8 dp, not 4, between the example and «Hasta 20 horas de reuniones al mes.».
- UX-3002: both hours strings become whole-sentence ICU plurals; the text at 20 doesn't change. The previews' descriptions now mention the hours, and ES 2× of the meeting reason gets a render.

## Skipped

Nothing.

## Notes

- **For the owner (UX-2905).** Meeting notes saved by the 2026-11-04 staging build whose meeting row was already cleaned up lose «Crear tarea». They keep «Editar nota» and their steps. P329 marks the ones that can still be traced, and nothing is guessed from a note's text.
- **For the owner (D7, UX-2815).** On the RevenueCat paywall, use the app's words with the hours: «Notas de las reuniones que grabas, hasta 20 horas al mes».
- **For the main session.** The change adds a limit people will read and D5's audio line (MN-34). Run `/ux-web` in `../TaskFlowWeb` so the site says the same.
- **Ledger.** UX-2720, UX-2721 and UX-2722 move to Verified: reviews C and D found them carried out as decided. UX-2814 moves to Device check. UX-2813 stays open until P327 is verified.
