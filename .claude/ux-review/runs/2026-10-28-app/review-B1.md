## UX review — B1: Today and the calendar (whole-app run 2026-10-28-app) — 2026-10-31

**Verdict:** Ship after fixes. Nothing in B1 blocks a core task, and every change can be undone. But a tick waits for the server before it shows, and at large text the person who sets the bar loses today's tasks behind overdue rows, cut titles and a Día view that runs off the screen.

**Evidence:**
- **Previews:** `App/build/ux/calendar/*` and `tasks/tasks-tab.*`, rendered 2026-10-28 17:59 – 2026-10-29 08:54 from 6281e3d. `find App/lib App/assets -newer …` lists nothing, and `git diff 6281e3d HEAD -- App/lib App/assets` is empty, so they are current. `App/build/calendar-feedback-light.png` (2026-10-29 09:07) is the only render of a day just finished.
- **AUDIT.md:** read for every B1 state (calendar/agenda ×16, timeline ×3, completed ×3, tasks-tab ×3).
- **Emulator captures:** `App/build/ux/device/`, 2026-10-29 09:13–10:08, APK from 30c8ce0 (the same app code), with their uiautomator trees: `screen-calendar.*`, `permission-calendar.*`, `screen-tasks.*`, `talkback.calendar-*`. Emulator evidence, against a local server, so no network delay can show there.
- **Code:** read in full: the nine scope files, plus `widgets/task_interactions.dart`, `widgets/task_actions.dart`, `providers/task_provider.dart`, `providers/calendar_focus_provider.dart`, `models/day_timeline.dart`, `l10n/region.dart` and the ARB keys they use.
- **Not run:** Flutter, any phone or emulator.

**Walked:** Newcomer (ES, 1×/1.3×/2×, 360 and 393 dp, one hand); Daily user (ticks right after opening, mobile data); assistive-technology user (TalkBack, 2× text, tremor).

| Flow | Path | Taps | Ends on |
|---|---|---|---|
| Understand today | open → Calendario | 0 | 1×: 2½ rows; 2×: 1 row, its title cut; 2× with a shared project: no row; three overdue tasks hide all of today's at 1× |
| Complete, undo | circle or swipe right → Deshacer | 1 (+1) | row struck through in place; the message only after a server sync (UX-2301) |
| Tick the day's last task | circle | 1 | «0 pendientes · 1 completada» + «Tarea completada» (UX-2303, WD34) |
| Overdue | today › «Atrasadas · N» › circle | 1 | the row and its heading vanish; «completadas» doesn't grow (UX-2304) |
| Overdue to tomorrow | long-press or swipe left › Mañana; or row › Cambiar fecha › Mañana | 2 / 3 | «Movida al …» after a sync (UX-2301) |
| No-date tasks | «Sin fecha · N» › page | 1 (+ scroll on busy days) | also lists deadline-only tasks (UX-2308); a dated save made there lands nowhere (UX-2307) |
| Phone events | the line › the list › one event | 0 / 1 / 2 | names only after a tap; no visible way out of either sheet (UX-2306) |
| Another day, and back | a day › «Hoy» | 1 + 1 | the heading names the day |
| Month | «Semana ▾» › Mes › a day | 3 | Semana on that day, its rows in view |
| Día view | «Semana ▾» › Día | 2 | the first timed item; at 2× every block cut by the screen edge (UX-2309) |
| Completed | Tareas › «Completadas» | 2 | planned-date order, no-date tasks last (UX-2311); reopening one drops it (UX-2304) |
| TalkBack | rows; Día view | — | rows offer two unnamed scroll actions (UX-1416); 25 hour labels (UX-2314) |

Also walked: offline (the calm line holds), empty and first-run days, the invitation card, pending captures, many items, long titles, ES/CA/EN, dark.

**Numbers:**
- **Calendar, new account:** 16 tap targets (U10 target ≤ 15; unchanged). An ordinary day at 1×: 21 targets in view, 26 in all.
- **Today's rows in view on 360 × 800:** 2½ at 1×; 1 at 2×, its title cut at about 23 characters; 0 at 2× with a shared project; 1½ on the emulator at 360 dp and 2.0.
- **Overdue rows that hide every one of today's own at 1× on 360 dp:** 3 → none can (UX-2302).
- **Tick → «Tarea completada · Deshacer»:** one full server sync, each request allowed 12 s → one frame (UX-2301).
- **Taps to learn what the 17:00 phone event is:** 1, then reading a 75 %-tall sheet → 0 (UX-2306).
- **The end of a day:** «0 pendientes · 1 completada» + «Tarea completada» → «1 completada» + «Todo listo. Respira.» (UX-2303, UX-2312).
- **Día view:** at 2× on 360 dp each block shows 216 of its 292 dp → all of it (UX-2309); TalkBack stops on the busy day: 42 → 17 (UX-2314).

### Findings (most severe first)

**UX-2301 · Severity 3 · Ticks and moves wait for the server to answer**
- **Where:**
  - `App/lib/widgets/task_interactions.dart:19-37`: `toggle` awaits `setCompleted`, and only then gives the haptic and «Tarea completada · Deshacer».
  - `App/lib/providers/task_provider.dart:198-222`: `setCompleted` ends with `await loadTasks()`.
  - `:43-71`: `_loadLoop` awaits `_repository.sync()` (`:54`); `:34-37`: a tick made while a load runs joins it; `:116-121`: `_mutate` queues each change behind the previous one's load.
  - The same in `rescheduleTask` (`:123-134`) and `changeOccurrence` (`:146-186`): «Cambiar fecha» from a row.
  - Every row: Calendar, Tareas, Sin fecha, project pages, Completadas.
- **The moment:** "Toco el círculo de «Comprar pan» y no se marca… Lo vuelvo a tocar." The Daily user: "Marco tres cosas seguidas y cada una tarda."
- **What happens:**
  - With no sync running, the circle fills after the phone's own write, but the haptic and «Tarea completada · Deshacer» wait for a whole sync: several requests, each allowed 12 s (`App/lib/services/api_client.dart:628-637`).
  - Opening or resuming the app starts a sync (`calendar_screen.dart:371-386`; `TaskNotifier`'s constructor), and so does every change. A tick made meanwhile joins that sync: the circle stays empty until it ends, and the message comes after a second sync.
  - A second tick in a row waits in the queue for the first tick's sync before it is even written.
  - Saves and every Deshacer don't wait: they end with `showLocal()` (`task_provider.dart:75-86`, `:142`, `:194`; UX-601).
- **Why it fails:**
  - UN-1 and PE-1 (Nielsen 1993; Forch 2017): every tap answers within 0.1 s.
  - UN-10 (Android Offline-first): what the phone saved shows at once.
  - OL-1 (Kane 2019): a tap that seems dead gets a second one, whose message replaces the first one's Deshacer (UN-6).
  - The codebase's recurring "background work awaited in the tap path".
- **Fix:** `setCompleted`, `rescheduleTask` and `changeOccurrence` end with `showLocal()` instead of `await loadTasks()`, as the saves and undos already do. The circle, the haptic and the message come from the phone at once; the sync runs behind. No copy change.
- **Verify:**
  - Widget test with a cloud sync that never completes, as `App/test/capture_landing_test.dart:644`: tick a Calendar row → checked, with «Tarea completada · Deshacer», within a frame or two; tick a second row straight away → checked too; «Cambiar fecha» › Mañana → «Movida al …» at once.
  - Phone: on throttled mobile data, open the app and tick a task within 2 s.
- **Evidence:** verified in code. Not visible in renders or on the emulator lane, which use a local server; needs a phone on a slow network.

**UX-2302 · Severity 3 · Overdue tasks push today's own tasks off the screen**
- **Where:** `App/lib/screens/calendar_screen.dart:955-986`: «Atrasadas · N», its rows and a divider come before the day's own rows; `:437-457`: oldest first, no limit. Today only. `App/test/calendar_feedback_test.dart:367-374` asserts this order.
- **The moment:** "¿Esto es lo de hoy? «Renovar el DNI, lunes»… ¿Y el médico de las diez?"
- **What happens:**
  - `calendar/agenda.busy.es.light.1x.png` (one overdue task, a shared project): the overdue row and the divider take 448–544 dp, and only the first line of today's first task shows above «Añadir tarea» (616 dp).
  - Without shared-project chips there are 306 dp between the counts and the button at 1× on 360 × 800. Each overdue row takes about 97 dp with its gap, plus 30 dp of heading and 21 of divider. With two overdue tasks today's first task is cut; with three, none of today's tasks is in view.
  - At 2× one overdue task is enough: `agenda.busy.es.light.2x.png` shows no task at all.
  - Overdue tasks pile up exactly for the person who forgets to tick: the bar.
- **Why it fails:** SC-5 (Fessenden 2018): what the person came for — «Agenda de hoy» — shows without scrolling. TA-9 (Wohl 2010; Bellotti 2004): overdue is calm and forgiving, not first. SC-3 (Leiva 2020): the day at the top is the screen's anchor.
- **Fix:** list the day's own rows first, then «Atrasadas · N» with its rows, then the phone's events and «Sin fecha · N». The same heading, counts and dates; no new copy or control. D1 holds: overdue tasks still move into Today, under «Atrasadas · N».
- **Verify:** `calendar/agenda.busy` at 1× on 360 dp shows today's first task whole above the button. A widget test with three overdue tasks and two of today's: today's rows come before «Atrasadas · 3». Update `calendar_feedback_test.dart:367-374`.
- **Evidence:** measured in a current render; verified in code. The three-task case is computed from AUDIT's row heights.

**UX-2303 · Severity 2 · Ticking the day's last task ends on «Tarea completada» (WD34)**
- **Where:** `App/lib/widgets/task_interactions.dart:25-27`, which picks the message; `App/lib/widgets/task_tile.dart:282-288` (the circle) and `:232-239` (swipe right); `App/lib/screens/calendar_screen.dart:903-912` (the count line). Owner decision WD34, 2026-10-31.
- **The moment:** "Lo he hecho todo… ¿y ya? Pone «0 pendientes»."
- **What happens:**
  - `App/build/calendar-feedback-light.png`: the day's only task ticked; the screen says «0 pendientes · 1 completada» and «Tarea completada · Deshacer».
  - At 2×, the line under «Agenda de hoy» is off-screen when the person ticks: in `calendar/agenda.completed.es.light.2x.png` the heading and the counts are scrolled away (AUDIT: off screen).
- **Why it fails:** the peak–end rule (Kahneman 1993) and SC-11: the end of a flow is what people remember, and this one ends on a zero. The owner asked for the website demo's line.
- **Fix:**
  - On Calendar, when a tick (circle or swipe right) leaves the shown day with no open task — on today, «Atrasadas» included — the message reads ES «Todo listo. Respira.» / EN "All clear. Take a breath." / CA «Tot fet. Respira.» instead of «Tarea completada», with the same Deshacer and timeout. Calendar knows the day's open count and passes it to the row's tick.
  - It's the message line: no new element, icon, animation or screen. TalkBack hears it as it hears «Tarea completada», through the message's live region. Other screens keep «Tarea completada».
  - Why the message and not the count line: at large text, or on a long day, the count line is off-screen at the moment of the tick.
  - Depends on UX-2301, so the line comes at once, and on UX-2304: without it, a today with only overdue tasks turns into «Nada previsto para este día.» as the line shows.
- **Verify:**
  - Widget test in ES, EN and CA: tick both of a day's two tasks; the second message is the new line, with Deshacer, which reopens the task. On a today with an open overdue task, ticking the day's own last task keeps «Tarea completada». Ticking the last overdue task on a today with no tasks of its own shows the line.
  - A preview state, `calendar/agenda.all-clear`, at 1× and 2×.
- **Evidence:** seen in current renders; verified in code.

**UX-2304 · Severity 2 · Ticked overdue rows and reopened completed rows vanish**
- **Where:**
  - `App/lib/screens/calendar_screen.dart:437-457`: `_overdueOn` lists only open tasks, and `Task.overdueOn` returns null once a task is done (`App/lib/models/task.dart:465-472`).
  - `calendar_screen.dart:51-53` and `:646-653`: `_openOnDay` keeps only the day's own ticked rows; `:681`: «completadas» counts only those.
  - `App/lib/screens/completed_tasks_screen.dart:64-73`: the list is rebuilt from done tasks only.
  - `App/test/calendar_feedback_test.dart:395-396` asserts the vanish.
- **The moment:** "He marcado lo del DNI y ha desaparecido con su título… ¿Lo he borrado?" On Completadas: "Toqué el círculo sin querer y la tarea se fue."
- **What happens:**
  - On today, ticking an overdue row removes it, and the «Atrasada · 1» heading with it if it was the last. The rows under the finger jump up.
  - «4 pendientes · 1 completada» becomes «3 pendientes · 1 completada»: the done task counts nowhere (UX-201's polish note, never fixed).
  - A today with only overdue tasks turns into «Nada previsto para este día.» after the last tick.
  - On Completadas, reopening a row removes it at once.
  - Today's own rows (UX-220) and Tareas (UX-1406) keep a ticked row in place, struck through, until the person leaves.
- **Why it fails:** SC-9 (WCAG 2.2 3.2.4): one rule for ticked rows. SC-10 (Rensink 1997) and UN-2 (Flaherty 2024): show the change where it happened. OL-1 (Kane 2019): a row moving under the thumb invites the next mis-tap.
- **Fix:**
  - **Calendar:** an overdue row ticked while today is shown stays under «Atrasadas», struck through, its circle reading «Reabrir», until the day changes or Calendar is covered (`_openOnDay`'s rule). It counts in «completadas». The heading counts the rows it lists.
  - **Completadas:** a row reopened there stays, unticked, until the page is left (Tareas' `_openHere` rule).
  - No copy change.
- **Verify:** widget tests. Tick an overdue row: it stays, struck through, and the line reads «… · 1 completada»; switch tabs and back: it's gone. On Completadas, reopen a row: it stays, unticked; leave and come back: it's gone.
- **Evidence:** verified in code and in its test.

**UX-2305 · Severity 2 · At large text, task titles stop after two lines**
- **Where:** `App/lib/widgets/task_tile.dart:297-300`: `maxLines: 2` with an ellipsis. Every row: Calendar, Tareas, Sin fecha, project pages, Completadas, the Día view's «Sin hora».
- **The moment:** "«Llamar al médico para p…» ¿Para qué era?"
- **What happens:**
  - 2× on 360 dp: «Llamar al médico para p…» and «Recoger a los niños del co…» (AUDIT: "ellipsis at 2 lines" on `calendar/agenda.normal`, `.completed` and `.added`, ES and CA). About 23 characters show.
  - Emulator at 2.0 on 360 dp: the 17-character «Reunión con Laura» already fills both lines (`device/screen-calendar.today-360dp.es.light.2.0.png`).
  - At 1×, titles past about 55 characters stop too (AUDIT `tasks/tasks-tab · normal`).
  - The whole title is only on the task's own page.
- **Why it fails:** AC-3 (WCAG 2.2 1.4.4): text at 200 % without loss of content. SC-1 (Nielsen 2006f): the title is what the row is for.
- **Fix:** titles wrap in full (no `maxLines`); the notes line stays at one line. No copy change.
- **Verify:** `calendar/agenda.normal` in ES and CA at 2× shows «Llamar al médico para pedir cita» whole; AUDIT lists no cut row title.
- **Evidence:** seen in current renders and an emulator capture.

**UX-2306 · Severity 2 · Phone events show as a grey count, not by name**
- **Where:**
  - `App/lib/widgets/device_calendar_events.dart:92-101`: a count and the first three start times.
  - `:114-152`: `_EventsLine` draws it in `onSurfaceVariant`, with nothing that marks it as tappable.
  - `:197-279`: the list sheet and the event sheet, both 75 % of the screen tall, with no visible way out.
  - `App/lib/screens/calendar_screen.dart:1015-1049`: the line, then «Sin fecha · N», 0 dp apart.
- **The moment:** right after connecting her calendar (D7: «Conectado. Los eventos se ven en Calendario.»): "¿«2 eventos · 10:00 · 17:00»? ¿Cuáles? ¿Dónde está el dentista?"
- **What happens:**
  - `device/permission-calendar.calendar-after.es.light.1.0.png` and `.2.0`: Calendar shows «2 eventos · 10:00 · 17:00». The names, «Reunión de equipo» and «Cita con el dentista», need a tap on a grey line that reads as a note, next to the teal «Sin fecha · 1» link.
  - The line sits 0 dp above «Sin fecha · 1»: AUDIT `calendar/agenda · phone-events`; on the emulator their bounds meet at y 1469.
  - Both sheets close only by Back, the scrim or a drag; the list opens 75 % tall for two events.
- **Why it fails:**
  - SC-1 (Nielsen 1997): the distinguishing word, the event, hides behind a count.
  - SC-6 (Harley 2014): the way to the names isn't marked; recognition over recall (Nielsen 1994).
  - RE-3 (Jin 2007): no gap between two different targets.
  - OL-5 (Harada 2013): a visible way out, the standard UX-1622 set.
- **Fix:**
  - After the day's tasks (UX-217's order stays), list up to three events as compact rows, title first: «Cita con el dentista · 17:00», with «Todo el día» for all-day ones. Each row opens its event. With more events, a fourth row opens the list: ES «Ver los {count} eventos» / EN "See all {count} events" / CA «Mostra els {count} esdeveniments». This replaces the count line.
  - At least 8 dp between the events and «Sin fecha · N».
  - Both sheets end with «Cerrar» (the existing `close`), and the list fits its content.
  - Errors and access prompts keep their one line.
- **Verify:** `calendar/agenda.phone-events` shows both titles with their times; AUDIT shows at least 8 dp to «Sin fecha · 1»; on the emulator, `permission-calendar.calendar-after` shows both names.
- **Evidence:** seen in emulator captures and a current render; measured in AUDIT; verified in code.

**UX-2307 · Severity 2 · From Sin fecha, a task given a day lands unseen**
- **Where:**
  - `App/lib/screens/home_screen.dart:222-289`: `_land`. A page that isn't a root tab keeps its filter (`:251`), so the Sin fecha page never lists a task that now has a date, and the landing waits forever (`:714-720`).
  - `TaskActions(page: this)` at `:833-840`; the page is `/inbox`, reached from Calendar's «Sin fecha · N».
  - The Día view already sends such saves back to Calendar (`App/lib/screens/day_timeline_screen.dart:112-128`).
- **The moment:** "Desde «Sin fecha» he dicho «comprar pilas el viernes». Dice «Añadida al vie, 30 oct», pero aquí no está."
- **What happens:** the capture, or the form with «Mañana» tapped, saves the task on its day. The Sin fecha page can't list it, Calendar behind it stays on today, and only the message names the day. To see the task: Back, then tap the day.
- **Why it fails:** U5's acceptance, the saved task visible and lit every time; SC-10 and SC-11 (Rensink 1997; Kahneman 1993); TA-1 (Payne 1993).
- **Fix:** when a page can't list a just-saved task even after clearing its search, it lands on Calendar as the Día view does: pop to Calendar and set `CalendarFocus(day, ids, showCalendar: true)`. No copy change. The same rule serves a project page when the dictation names another project (area C).
- **Verify:** widget test: open `/inbox` and save a task for tomorrow, by capture and by the form. Calendar shows tomorrow with the row lit and «Añadida al …» with Deshacer.
- **Evidence:** verified in code. No render or capture saves from Sin fecha.

**UX-2308 · Severity 2 · «Sin fecha» counts tasks that have a deadline date**
- **Where:** `App/lib/screens/calendar_screen.dart:654-658` (`dueDate == null`) and `App/lib/screens/home_screen.dart:151` (the Sin fecha page and Tareas' chip). The landing's own rule is "neither a day nor a deadline" (`App/lib/screens/voice_task_screen.dart:3230`), and so is the row's «Sin fecha» (UX-1725, `task_tile.dart:46-50`).
- **The moment:** with the owner's own example, «terminar el diseño para el jueves a las 5» (a deadline only): "Sale el jueves… ¿y también en «Sin fecha · 1»? Si tiene fecha."
- **What happens:** a deadline-only task shows on its deadline's day (`Task.calendarOccurrencesOn` → `deadlinesOn`) and lands there after saving (UX-902). It is also counted in «Sin fecha · N» on every day, and listed on the Sin fecha page as «Vence jue, 29 de oct · 17:00» under the title «Sin fecha».
- **Why it fails:** SC-9 (WCAG 2.2 3.2.4): one concept, one rule; match with the real world (Nielsen 1994): a task with a date filed under "no date".
- **Fix:** «Sin fecha» — Calendar's count, the page and Tareas' chip — means neither a day nor a deadline, through one helper they and the landing share. No copy change.
- **Verify:** test: a deadline-only task isn't counted in «Sin fecha · N», isn't on `/inbox` or under the chip, and shows on its deadline's day and in Tareas.
- **Evidence:** verified in code.

**UX-2309 · Severity 2 · At 2×, Día view blocks run past the screen edge**
- **Where:** `App/lib/screens/day_timeline_screen.dart:387-391`: each lane is at least `150 × scale` dp and the hour column `54 × scale`, inside a sideways scroll view (`:396-401`).
- **The moment:** "«Paseo por el pa…» ¿Y el resto? No se lee."
- **What happens:**
  - **2× on 360 dp:** a 108 dp hour column plus one 300 dp lane in 328 dp. About 76 dp of every block lies past the right edge, its title cut by the screen with no ellipsis: «Paseo por el pa», «Llamar al médic» (`calendar/timeline.untimed.es.light.2x.png`). Only a sideways drag shows the rest, and nothing says so.
  - **1×, two items at once:** two 150 dp lanes in 264 dp, so the second runs past the edge: «Reunión con e» (`timeline.busy.es.light.1x.png`).
- **Why it fails:** AC-4 (WCAG 2.2 1.4.10): reflow without sideways scrolling; SC-5; PL-8 and OL-3 (Kobayashi 2011): a sideways scroll with no visible sign.
- **Fix:** one lane always fits the space beside the hours. Side-by-side lanes share it, and scroll sideways only below a readable width, with the scrollbar always shown, as «Sin hora»'s is. Size the hour column to its widest label. Titles end with an ellipsis inside their block; the block's TalkBack label and tooltip keep the whole title.
- **Verify:** `calendar/timeline.normal` and `.untimed` in ES and CA at 2×: every block ends inside the screen. `timeline.busy` at 1×: both lanes inside, or a visible scrollbar.
- **Evidence:** seen in current renders; widths computed from the code.

**UX-2310 · Severity 2 · Event read errors say «Actualiza» with nothing to tap**
- **Where:** `App/lib/screens/day_timeline_screen.dart:258-262` (a red banner) and `App/lib/widgets/device_calendar_events.dart:215` (the events sheet) show `calendarReadError` (`app_es.arb:109`, `app_en.arb:186`, `app_ca.arb:88`). Calendar's own line retries on a tap (`calendarReadRetry`, `device_calendar_events.dart:65-70`; UX-442).
- **The moment:** "«Actualiza para volver a intentarlo»… ¿Dónde?"
- **What happens:** ES «No se pudieron leer los eventos. Actualiza para volver a intentarlo; pueden faltar compromisos en esta vista.» (19 words). The Día view refreshes only when the hours are pulled down; the sheet can't refresh at all.
- **Why it fails:** UN-7 (Neusesser 2023): an error says what to do, and it must be doable; PL-8 (Norman 2010): pull-to-refresh has no visible twin; SC-9: Calendar already says «Toca para reintentar», and retries.
- **Fix:** both places show Calendar's tappable line, with its busy state: ES «No se pudieron leer los eventos. Toca para reintentar.» / EN "Couldn’t read your events. Tap to try again." / CA «No s’han pogut llegir els esdeveniments. Toca per tornar-ho a provar.» Remove `calendarReadError` from the three catalogs.
- **Verify:** tests with a failing read: the Día view and the sheet show the retry line, and a tap reads again. Catalog test: no `calendarReadError`.
- **Evidence:** verified in code and catalogs. No render shows an event read error.

**UX-2311 · Severity 2 · Completadas lists today's undated tasks last**
- **Where:** `App/lib/widgets/task_list.dart:39-46`: `newestFirst` sorts by the task's day, with no-date tasks last. Used by `App/lib/screens/completed_tasks_screen.dart:106-109`. The app keeps no completion time; the server's task has only `updated_at`.
- **The moment:** "Marqué «Comprar pan» sin querer esta mañana. En Completadas no está arriba: está al final de todo."
- **What happens:** the list follows when tasks were planned, not when they were done. A task with no day — the usual «comprar pan», per D9 — sits after every dated one, behind months of history. A task due next month and done today sits at the top. The page's own help line is about reopening: «Pulsa una casilla para reabrir una».
- **Why it fails:** recognition over recall (Nielsen 1994); CO-3 (Cowan 2001): the page's job, reopening what was just done, needs recency.
- **Fix:** order Completadas by when each task, or each repeat, was completed, newest first. That needs a completion time saved with the tick, on the phone and on the server; the cause is likely server-side. The app half is the sort. No copy change.
- **Verify:** test: complete a no-date task after three dated ones; it's first on Completadas.
- **Evidence:** verified in code.

**UX-1416 · Severity 2 · Rows still expose two unnamed scroll actions** (already in the ledger, status device-check; still partly open)
- **Where:** `App/lib/widgets/task_tile.dart:227-251`: the `Dismissible` on every editable row.
- **The moment (TalkBack):** "«Comprar fruta». Acciones: desplazar a la izquierda, desplazar a la derecha, Cambiar fecha." Which one completes it?
- **What happens:**
  - P178 added a named «Cambiar fecha» action, but the swipe's own two actions are still there, unnamed. AUDIT lists every Calendar and Tareas row as "→ tap, scroll left, scroll right, «Cambiar fecha»". The emulator tree marks each row `scrollable="true"` (`device/a11y/screen-calendar.today.es.light.1.0.xml`, «Comprar fruta»).
  - Scroll right completes the task; scroll left opens «Cambiar fecha».
  - On a phone, TalkBack may also send its scroll and auto-scroll to a scrollable row, completing or moving a task nobody asked about. That needs checking on a phone.
- **Why it fails:** AC-9 (Flutter CustomSemanticsAction; WCAG 2.2 2.5.1) and AC-6 (WCAG 2.2 4.1.2): every action has a name that says what it does.
- **Fix:** while `MediaQuery.accessibleNavigationOf(context)` is on (TalkBack, Switch Access), the row's `Dismissible` has `direction: none`. TalkBack's own gestures replace swipes anyway, so the row offers «Cambiar fecha», and its circle completes. No copy change.
- **Verify:** a semantics test with accessible navigation on: rows have no scroll actions. Emulator tree: rows `scrollable="false"`. Phone: with TalkBack, move through a long agenda past the screen's end; nothing gets completed or moved.
- **Evidence:** measured in AUDIT and the emulator tree. The TalkBack behaviour needs a phone.

**UX-2312 · Severity 1 · Row and count copy slips**
- **Where:**
  - `priorityValue`: `app_es.arb:324`, `app_ca.arb:303`, shown by `task_tile.dart:133-135`.
  - `agendaCounts`: `app_es.arb:314`, `app_ca.arb:293`, `app_en.arb:540`, shown by `calendar_screen.dart:906`.
  - `completedTaskSummary`: `app_es.arb:992`, shown by `completed_tasks_screen.dart:103`.
- **What happens:**
  - Rows read «Prioridad Media» and «Prioridad Alta» (CA «Prioritat Mitjana») mid-phrase, while Tareas' chip says «Prioridad alta» (`calendar/agenda.normal`, `tasks/tasks-tab.normal`). Noted in run 2026-10-19-app's plan, line 227, and never filed.
  - At 2× the count line splits «4 pendientes · 1 / completada», the number from its word (`agenda.normal.es.light.2x.png`, `agenda.added.es.light.2x.png`).
  - When the day is done it reads «0 pendientes · 1 completada» (`App/build/calendar-feedback-light.png`): a zero shown as content.
  - Completadas says «Pulsa una casilla para reabrir una.»; the app's other instructions say «Toca» (19 to 6 in Spanish).
- **Why it fails:** LO-10 (sentence case); SC-9; the recurring "no-break spaces bound one word short"; defaults shown as content (CO-5, Sweller 1988).
- **Fix:**
  - `priorityValue` becomes a select by level: ES «Prioridad alta» / «Prioridad media» / «Prioridad baja»; EN "High priority" / "Medium priority" / "Low priority"; CA «Prioritat alta» / «Prioritat mitjana» / «Prioritat baixa». It also reaches the capture result and the task form (areas A2 and B2), which is the point.
  - `agendaCounts`: a no-break space between each number and its words, and inside «per fer» and "to do". With nothing left, only the done half: ES «1 completada» / «5 completadas»; EN "1 completed"; CA «1 completada» / «5 completades».
  - `completedTaskSummary`, ES: «Toca su casilla para reabrirla.» / «Toca una casilla para reabrir una.»
- **Verify:** a catalog test for the three keys; `calendar/agenda.normal` at 1× and 2×, ES and CA, shows «Prioridad media» and keeps «1 completada» on one line.
- **Evidence:** seen in current renders; verified in the catalogs.

**UX-2313 · Severity 1 · A passed deadline says it twice, in alarm red**
- **Where:** `App/lib/widgets/task_tile.dart:104-110` and `:143-150`, drawn in `colors.error`. The task's page builds the same pair (`App/lib/screens/task_detail_screen.dart:319`, area B2). The Día view draws every deadline red, passed or not (`day_timeline_screen.dart:472-476`).
- **The moment:** "«Vence lun, 26 de oct · Fecha límite vencida», en rojo. ¿He hecho algo mal?"
- **What happens:** ES «Vence lun, 26 de oct · Fecha límite vencida»: seven words, present tense then past, in red, under the calm grey «Atrasada» heading. EN "Due Mon, 26 Oct · Deadline passed"; CA «Termini: dl., 26 d’oct. · Termini vençut».
- **Why it fails:** TA-9 (Syrek 2017; Wohl 2010): overdue items are calm, with no alarm red. SC-1 and SC-2: one short phrase. OL-2 (Nielsen 2013): red reads as "you did something wrong".
- **Fix:** one phrase, in the row's usual grey: ES «Venció el lun, 26 de oct» / EN "Was due Mon, 26 Oct" / CA «Termini vençut: dl., 26 d’oct.» (worth a native Catalan read). It replaces `deadlineOverdue` wherever that pair is built. The Día view's deadline blocks use the theme's tertiary colour; their «Fecha límite:» prefix says what they are.
- **Verify:** a preview row with a passed deadline, ES and CA at 1× and 2×; AUDIT finds no error-coloured text on it.
- **Evidence:** verified in code and catalogs. No current render shows a passed deadline.

**UX-2314 · Severity 1 · Día view: the year, a stray dash, every hour aloud**
- **Where:** `App/lib/screens/day_timeline_screen.dart:227` (`fullDate`, `App/lib/l10n/region.dart:17-18`), `:527-535` (the duration bar) and `:403-426` (the hour labels).
- **What happens:**
  - The header «miércoles, 28 de octubre de 2026» takes 2 lines at 1× and 3 at 2× (`timeline.normal.es.light.1x.png`, `timeline.untimed.es.light.2x.png`). Calendar drops the current year: "The current year goes without saying" (`calendar_screen.dart:771-779`).
  - An item with no duration gets a 5 × 2 dp teal dash poking out of its block's rounded corner (`timeline.normal.es.light.1x.png`, cropped and enlarged).
  - TalkBack stops on all 25 hour labels between the items: 42 stops for 11 items on the busy day (AUDIT `calendar/timeline · busy`). Each item already says its time: «Paseo por el parque, 08:30».
- **Why it fails:** SC-9 (Calendar's own rule for the year); SC-5 at 2×; AC-15 (COGA 2021: help focus). The dash is cosmetic.
- **Fix:** the header uses Calendar's heading format, with no year when it's the current one: ES «miércoles, 28 de octubre». An item with no duration gets no bar; one with a duration has its bar clipped to the block's shape. The hour column is excluded from semantics.
- **Verify:** `calendar/timeline.*` renders show the date on one line at 1× and no dash. AUDIT for `timeline · busy`: 17 TalkBack stops, no hour labels.
- **Evidence:** seen in current renders; counted in AUDIT.

### Keep
- The calm offline line, «Sin conexión: tus tareas están guardadas en este teléfono.» (`calendar/agenda.offline`).
- A ticked row stays in place, struck through, on Calendar and Tareas (UX-220, UX-1406). UX-2304 extends that rule; it doesn't replace it.
- One filled «Añadir tarea» on Calendar, Tareas, Sin fecha and the Día view, and an empty day says so in one line (UX-1404).
- After «Mes», a tapped day returns to Semana with its rows in view (`agenda.month-day-tapped`), and «Hoy» shows only when it's needed.
- The Día view opens on the first timed item, with «Sin hora» pinned above (`timeline.untimed`). TalkBack hears the chosen day and «hoy · N tareas» on the strip (emulator tree).

### Progress against UX_REVIEW.md (U1–U14)
- **U5 — holds on Calendar:** rows land lit, clear of the measured message. Still open from the Sin fecha page (UX-2307), and for A2, where a several-day landing can scroll the day's name away (cross-slice note).
- **U8 — holds:** one filled button on every B1 screen.
- **U10 — unchanged:** 16 tap targets on a new account's Calendar (AUDIT `first-use`).
- **U11 — holds in B1** («Sin fecha», «Sin guardar»), but «Sin fecha» now also holds deadline-only tasks (UX-2308).
- **U12 — holds.** UX-702's cut at linear 2× on 360 dp is unchanged (`agenda.first-use.es.light.2x`).
- **U13 — open.** New evidence: at 2× on 360 dp with a shared project, Calendar shows no task above the button (`agenda.busy.es.light.2x`).
- **Not in B1:** U1–U4, U6, U7, U9, U14.

### Questions for the owner
None new. UX-2302 keeps D1 (overdue tasks still move into Today, under «Atrasadas · N»), and UX-2303 builds WD34 as decided.

### Cross-slice notes
- **A2:** a several-day landing's message names only the other days (`voice_task_screen.dart:3196-3206`). When the reveal scrolls «Agenda de hoy» and the strip away, nothing on screen names the day shown (`calendar/agenda.added.es.light.1x.png`). Naming it first would fix it, e.g. «3 tareas añadidas: hoy y el vie, 30 de oct».
- **A1/A2:** any voice set or search for «sin fecha» should follow UX-2308's rule (neither a day nor a deadline), as the landing's `undated` already does.
- **B2:** the task page's «Completar» and «Cambiar fecha» go through the same awaited sync, which UX-2301's fix covers. The page builds UX-2313's «Vence … · Fecha límite vencida» pair, and UX-2312's `priorityValue` change reaches the form.
- **C:** at 1× in Spanish on 360 dp, the scope chips leave «Para mí» alone on a second row, apart from «Todas» (`calendar/agenda.busy.es.light.1x.png`, `tasks/tasks-tab.normal.es.light.1x.png`). Noted on 2026-10-19, never filed. A project page can't show a task its dictation put in another project: UX-2307's mechanism.
- **D (theme):** snackbars use `surfaceContainerHighest` with an outline and no elevation (`app_theme.dart:137-147`). They look like one more task card, so «Tarea completada · Deshacer» can blend into the rows (`agenda.completed`, `calendar-feedback-light.png`); Material uses the inverse surface.
- **Preview suite (main session):** the Calendar `normal`, `added`, `completed` and `phone-events` fixtures pass no projects, so «Comer con Ana» (project «casa») renders view-only, with no circle. That isn't a product state: pass `allProjects` or drop its `listId`. `completed.list` at 1× and 2× show «Hoy» and «mié, 28 de oct» because `dayLabel` reads the real clock, as INDEX warns.
- **Not checked here:** the website review's three app items (the Pro screen's first line, «A tu manera»'s privacy line, the invitation email's link) belong to areas D and B2 and to the server.

### Memory notes
- **Screen map, area B1 (2026-10-31, code at 6281e3d):**
  - **Calendar, top to bottom:** scope chips (shared projects only); the week card (month, «Semana ▾», «Hoy» off today, ‹ ›, day cells with `selected` and «hoy · N tareas» values); the invitation card; «Agenda de hoy» or the day, with `agendaCounts`; on today only, «Atrasadas · N» rows and a divider, above the day's rows (UX-2302 moves them below); the day's rows; the phone events line (count + three times; UX-2306); «Sin fecha · N»; `TaskActions`.
  - The completion message comes from `TaskInteractions.toggle`; WD34's line goes there (UX-2303).
  - **The Sin fecha page** is `HomeScreen(initialFilter: 3, isRoot: false)`; its `_land` keeps the date filter (UX-2307).
  - **Completadas:** reached from Tareas' «Completadas» (every project) or a project page's ✓ (scoped). Ordered by planned date, no-date tasks last; no completion time exists in the app or on the server (UX-2311).
  - **Día view:** `fullDate` with the year; «Sin hora» pinned by `_UntimedCap`; lanes at least 150 × scale dp (UX-2309); hour labels in semantics (UX-2314).
- **Recurring problems:**
  - Instances of #18 (awaited work in the tap path): `setCompleted`, `rescheduleTask` and `changeOccurrence` await `loadTasks()`, network sync included; the standard is `showLocal()`.
  - **New — one concept, two rules:** «Sin fecha» is `dueDate == null` on Calendar and Tareas, but "no day and no deadline" for the row label and the landing.
  - **New — lists that drop a changed row at once:** the overdue section and Completadas, against `_openOnDay` and `_openHere` elsewhere.
- **Review techniques:**
  - The emulator tree's `scrollable="true"` on task rows reveals the `Dismissible`'s semantics scroll actions.
  - `App/build/calendar-feedback-light.png` is the only render of a day just finished.
  - The Calendar `normal` fixtures render «Comer con Ana» view-only: don't read its missing circle as a product state.
