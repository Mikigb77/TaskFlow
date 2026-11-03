# UX plan — scoped run 2026-11-03-screens (2026-11-03)

The two reviews of the meeting-notes feature found 30 problems. All 30 are fixes, in nine packages, P318–P326. The worst: «Crear tarea» ticks to-dos as done, the saved task can't be seen, the stopped-recording card is unclear, dictation can grab the microphone mid-meeting, the app promises a notification it can't send, and «Enviar primero» waits minutes with nothing on screen.
Seven product questions wait for you (D1–D7). None of them blocks a package. Nothing was skipped.

Evidence: code read at commit 3efed60, widget-test renders in `App/build/ux/meetings/` and `notes/` rendered from that commit, and AUDIT.md measurements. UX-2801 also rests on Android's documentation. No device captures this run. Everything Android draws itself is on the phone list in each package. `../UX_REVIEW.md` isn't in this checkout, so U1–U14 weren't assessed.

Branch: `claude/project-thread-xqvgpc` (the owner's thread workflow is a PR into main), not `dev`.

## Decisions for you
None of these blocks a package. Each package works whichever way you answer.

**D1 · «Crear tarea» on every note with an open checklist, or only on meeting notes?** (UX-2722)
Today every note with an open step shows it. The croquetas recipe note does, which turns a shopping list into a task titled «Receta de la abuela: croquetas de jamón».
*Recommendation:* only notes made from a meeting. The phone keeps a local mark, and nothing new is sent. One small package after this run.

**D2 · Should free accounts see «Grabar una reunión»?** (UX-2719)
Today a free account's tap lands on the Pro screen.
*Recommendation:* Pro only, while meeting notes are Pro-only. The Pro screen still lists the feature (P326). P322 moves the row below the notes either way.

**D3 · Ask for notifications at the first «Grabar una reunión»?** (UX-2813, the ask half of UX-2801)
On Android 13+, without the permission, «Notas listas» never arrives, and the recording's Parar/Descartar notification shows only in Android's Task Manager. Today only reminders ask (D2 of 2026-10-13).
*Recommendation:* yes. After the microphone, show one sentence: «Para pararla desde la notificación y avisarte cuando las notas estén listas.», with «Continuar», then Android's dialog. Never ask again after a refusal. P322 already stops the copy promising a notification when they're off.

**D4 · State the monthly meeting time up front?** (UX-2720, both reviews)
The build caps meetings at about 20 hours a month, and people first hear of it when it runs out.
*Recommendation:* yes, on the Pro screen's meeting benefit («…, hasta 20 horas al mes»). The number is yours. P323 already says it while recording, once it bites.

**D5 · Say what happens to the audio on the recording screen?** (UX-2721)
The build's default is no consent reminder. The flow never says the audio is sent for the notes and then deleted.
*Recommendation:* one quiet line under the time, «El audio se envía para hacer las notas y después se borra.», with the consent reminder still off. The website's privacy page must match (MN-34).

**D6 · Hide the meeting's title on the lock screen?** (UX-2814)
*Recommendation:* yes. Android shows only «Las notas de la reunión están listas» on the lock screen, and the title once unlocked. Meeting titles are written from what was said. Reminders stay as they are.

**D7 · The RevenueCat paywall.** (UX-2815)
*Recommendation:* while meetings stay Pro-only, add «Notas de las reuniones que grabas» to the paywall's benefits yourself, in the dashboard, as with «A tu manera» (D7 of 2026-10-22). P326 adds the same line to the app's Pro screen.

## Settled here (each is a line to strike if you disagree)
- **Choosing steps in «Crear tarea» (UX-2701).** The review from a note starts with every step ticked, under «Pasos que se añaden». Unticking leaves a step out, and the task gets the ticked ones as open steps. The rows have no ⋮. Other reviews and the form are unchanged.
- **The note remembers its task (UX-2702)** in a phone-local preference: no schema change, and nothing synced or sent. On another phone the button reads «Crear tarea».
- **No headings in note bodies (UX-2708).** Bodies are plain text everywhere, and headings would add a format. Instead, a note's page shows its steps above the note's words, and the meeting's sections keep their labels on their own lines.
- **A tap on «Grabar una reunión» opens the recording screen at once (UX-2715 with UX-2808).** Without Pro, the Pro screen opens over it. If you buy, recording starts straight away. If you don't, one Back lands on Notas. This replaces review C's pushReplacement idea, so a purchase can go straight on.
- **A quiet recording (UX-2717).** Until a piece with sound is kept, the phone keeps the quiet pieces. At Stop, a recording of a minute or more with no sound asks «Casi no se oyó nada. ¿Hacer notas igualmente?». Shorter ones are dropped as today.
- **New copy written by the organizer:** the Catalan «slow» sign-out line (UX-2806); the «denied but askable» microphone line, «Para grabar una reunión, TaskFlow necesita el micrófono.» (UX-2712); «Seguir grabando, {time} hasta ahora» for TalkBack (UX-2703); and «menos de 1 min» (UX-2705).

## Packages, in order (most severe first)
Each line: finding (its severity), then what changes. The full instructions are in `plan.json`. Dependencies: P321 → P322 → P324, and P321 → P323. `pkg.py --lanes auto` splits them into two lanes on this 4-CPU session.

### Severity 3
**P318 · C · L — «Crear tarea» from a note: choose the steps, land on the new task, leave without a question, make it the main button**
- UX-2701 (S3): the review's steps start ticked, under «Pasos que se añaden». Unticking leaves a step out, and the task's steps are saved open, never done.
- UX-2702 (S3): «Añadir tarea» opens the new task's page over the note. Back on the note, the button reads «Ver tarea», so there's no duplicate.
- UX-2706 (S2): Cancel, Back or a swipe close the review at once, with no «¿Conservar el texto…?». Nothing lands in «Sin guardar».
- UX-2709 (S2): «Crear tarea» or «Ver tarea» is the filled button, and «Editar nota» is outlined, at the same height.

**P319 · C · M — While a meeting records, every capture entry types instead of reaching for the microphone**
- UX-2704 (S3): during a recording, «Añadir nota», «Añadir tarea», the widget and the shortcuts open typing with «Se está grabando una reunión: escribe aquí.». The recognizer never starts.

**P320 · D · L — Signing out with a meeting**
- UX-2802 (S3): while it saves, the screen reads «Guardando las notas de la reunión… Puede tardar unos minutos. Después se cerrará la sesión.»
- UX-2803 (S2): a confirmed sign-out finishes even if you leave Cuenta. Today it is silently dropped.
- UX-2804 (S2): the question gets the title «¿Cerrar sesión?» and says «Estás grabando una reunión…» or «Las notas de una reunión aún no están listas…». The primary button becomes «Guardar notas y cerrar sesión».
- UX-2805 (S2): the buttons are ordered Descartar, Cancelar, then the primary, so the red one is no longer 8 dp from the primary.
- UX-2806 (S2): failures say offline or slow, and to tap Cerrar sesión again. When nothing can be sent, the question offers only Descartar and Cancelar, and it says how many recordings a discard deletes.

### Severity 2 (P322 is S3; it follows P321, which it builds on)
**P321 · C · M — Lengths in words, the meeting's date and to-dos first, TalkBack names**
- UX-2705 (S2): «1 h 42 min» and «12 min» replace «1:42:00» and «12:03» in prose and TalkBack. Chapters read «Minutos 0–30 · …».
- UX-2708 (S2): a note's page shows its steps above the note's words.
- UX-2710 (S2): the note opens with «Reunión del mar, 3 nov, 10:15 · 52 min».
- UX-2718 (S1): the time reads «12 minutos y 3 segundos grabados», and «Abrir» becomes «Abrir la grabación».

**P322 · C · M — The stopped card, Descartar, the Notes row, and no empty promise · after P321**
- UX-2703 (S3): «Grabación de hoy, 10:15 · 1 h 42 min. Se cortó antes de que pulsaras Parar.», then a filled «Hacer las notas», «Seguir grabando», and a red «Descartar» set apart.
- UX-2714 (S2): «Preparando tus notas…» loses its lone «Descartar». «Descartar» is red everywhere, and the allowance-used screen gets it too.
- UX-2707 (S2): «Grabar una reunión» moves below the notes and the empty state, and its icon scales with the text.
- UX-2801 (S3, the copy half): with notifications off, the text reads «…las notas aparecerán en Notas.», not «te avisaremos».

**P323 · C · L — Opening and starting a recording · after P321**
- UX-2715 (S2): the screen answers in the first frame, and two taps open one screen.
- UX-2808 (S2): after buying Pro from «Grabar una reunión», recording starts.
- UX-2712 (S2): «Permitir el micrófono» while Android can still ask, «Abrir Ajustes» only once it's blocked, a re-check on return, and «Reintentar» after a failed start.
- UX-2711 (S2): the month's time or Pro shows on the recording screen as soon as it bites, and before recording when it's already known.
- UX-2716 (S2): «Puedes salir o bloquear el teléfono: sigue grabando hasta que pulses Parar.»

**P324 · C · L — Stopping · after P322**
- UX-2713 (S2): a failed Stop says «No se pudo parar. Sigue grabando: vuelve a pulsar Parar.»
- UX-2717 (S2): a quiet recording of a minute or more asks before it's thrown away.

**P325 · D · M — Meeting notifications**
- UX-2810 (S2): the recording notification shows a running clock.
- UX-2811 (S2): «Notas listas» is cleared when the note is opened, and at sign-out.
- UX-2812 (S1): the notification's title is the note's title. Each meeting keeps its own notification.

**P326 · D · S — The Pro screen for meetings**
- UX-2807 (S2): the heading «Con Pro, tus reuniones se convierten en notas:» fits both ways in. The example reads «…y las cosas por hacer».
- UX-2809 (S2): the benefit list adds «Notas de las reuniones que grabas». The preview now shows the priced store.

## Skipped
Nothing.

## For the main session
- **UX-2710's server half** (Backend, out of this run's scope): ask the final step for «when» as an absolute day, counted from the meeting's date.
- **Review D's cross-slice note:** the delete-account page doesn't mention recordings still waiting on the phone. Look at it in a future area D review.
- **The website's privacy page** must say what happens to recordings when the feature ships: MN-34, through `/ux-web`.
