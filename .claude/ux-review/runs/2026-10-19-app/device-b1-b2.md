# Run 2026-10-19-app: batches b1 and b2 on the review emulator (2026-10-20)

The main session's check of b1's and b2's emulator checks, with the device lane. **Evidence level: emulator** (TaskFlow_Review, Android 16), not a physical phone and no real voice.

**The captures:** `App/build/ux/device/`, 234 PNGs. They're one APK (sha256 270dd3dc0a2f…), built from a clean worktree at d677d88, whose app code is b2's (dd85cca). The backend is the local Docker API, rebuilt at d677d88 that morning. Yesterday's set is kept in `device-3a6ad40/`, from 3a6ad40 against a 2026-10-14 backend image that predated voice commands and email codes.

## Confirmed on the emulator
| Finding | What the capture shows | Capture |
|---|---|---|
| UX-1305 (b1, P166) | The reason line, «Permite el micrófono para dictar tus tareas. Solo escucha mientras dictas.», shows under Android's real dialog, at 1.0 and 2.0. After «No permitir», a neutral banner reads «Sin micrófono no puedo escucharte. Toca Empezar a hablar para permitirlo, o Escribir.», with a filled «Empezar a hablar». | `permission-mic.dialog.es.light.{1.0,2.0}`, `permission-mic.denied.es.light.1.0` |
| UX-107 (b1, P166) | After a second refusal on the recording path, in ES and in CA, the sheet points to Settings. The banner reads «Per tornar a dictar, obre Configuració i toca Permisos › Micròfon › Permet.», with one filled «Obre Configuració» and no «Comença a parlar». It's whole at 2.0. This was SEEN #3, now fixed. | `permission-mic.blocked.{es,ca}.light.{1.0,2.0}` |
| UX-1303 (b1, P166), the visible half | While blocked, the sheet offers one filled «Abrir Ajustes» under a neutral banner that names the steps. | `permission-mic.blocked.es.*` |
| UX-1304 (b1, P167), the visible half | The countdown counts: «Escuchando · 00:51» with «Quedan 9 segundos». After 60 silent seconds, the sheet says «No te he entendido. Vuelve a intentarlo o escríbelo.» and offers «Empezar a hablar». These were SEEN #4 and #5, now fixed. | `capture.listening-countdown.es.light.1.0`, `capture.listening-ended.es.*` |
| UX-1408 (b2, P175) | At 360 dp and 2.0, the week strip shows whole narrow weekdays («L M X J V S D», es_ES) and whole numbers. | `screen-calendar.today-360dp.es.light.2.0` |
| UX-1410 (b2, P175) | In the uiautomator tree, the chosen day has `selected="true"` and reads «hoy · 2 tareas, martes, 20 de octubre de 2026». The arrows read «Semana anterior» and «Semana siguiente». | `a11y/screen-calendar.today.es.light.1.0.xml` |
| UX-1411 (b2, P175), in the tree | The app bar's heading is «Calendario», and the tab reads «Calendario, Pestaña 1 de 4». | the same file, and `talkback.calendar-start` |

## Still for a phone, or not shown by a still capture
- **UX-1627:** "no frame shows the reason line before the blocked banner". The stills after the second refusal show only the banner, but a still can't prove that no frame flashed. A screen recording or a phone would show it.
- **TalkBack speech:**
  - first focus on «Abrir Ajustes» (UX-1303);
  - the countdown spoken once (UX-1304);
  - each result spoken once (UX-1308);
  - the sign-in reading order (UX-1604);
  - each tab's first spoken line (UX-1411);
  - today's count with an overdue task (UX-1632).

  The emulator's TalkBack captures show focus frames, and the caption only sometimes.
- **Everything marked "phone" in `report-b1.md` and `report-b2.md`:** real speech, Android 12 in Catalan, overnight returns, a real invitation link, and staging.

## Noticed, not filed (for the next review)
- At 2.0 Android's microphone dialog reaches down over the top of the reason line's first words (`permission-mic.dialog.es.light.2.0`). It's still readable. Android places its own dialog; the app could only move the line lower.
- At a silent 60 s, «No te he entendido…» uses the red error banner, as «nothing found» does. Review A already called that red a candidate for the neutral style.
- At 360 dp and 2.0, Calendar shows one task above «Añadir tarea» («Comprar fruta» with a «Sin hora» line, and «2 pendientes · 0 completadas»). The filler line and «· 0 completadas» are UX-1418, which b3's P178 is fixing.

## The lane, fixed on the way (all committed)
- **Installs with `-d`** (dd0cde6): a build from the committed code (version code 4007) can now replace one from the main checkout (4009). The main checkout carries another session's version bump.
- **Re-runs pub get when the plugin registrant is missing** (fd1681c): a half-failed pub get had built an APK with no plugins, and sign-in failed.
- **Reopens the sheet after the blocked microphone** (e994da7): since UX-1303, the blocked sheet has no «Empezar a hablar». The dialog's caption no longer says the app gives no reason.
- **Taps the tab, not the heading that names it** (c5131f6): since UX-1411, the heading carries the tab's name.
- **No longer a lane fault:** the notifications section's "reminders not scheduled" was a cascade. The journey had stopped before the reminder question, so reminders were still off. With the journey fixed, the Spanish reminders were captured.
