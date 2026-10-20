## UX review — B: Calendar, home and tasks (whole area) — 2026-10-19

**Verdict:** Ship after fixes. Nothing in area B blocks a core task, and the add–complete–move–delete loop works with Deshacer everywhere. But the person who sets the bar, using 1.3–2× text, still loses sight of things:
- the end of a several-task dictation hides one of the saved tasks (U5's promise);
- the week strip garbles days at large text;
- Tareas and the Día view open with no task in view;
- an empty day spends three lines saying "nothing".

**Evidence base:**
- **Previews:** `App/build/ux/` renders, 13:26–13:28 today, commit 3a6ad40. `find App/lib App/assets -newer …` lists no app file changed since, so they are current.
- **AUDIT.md:** read for every B screen.
- **Emulator captures:** `App/build/ux/device/`, 13:34–14:42, APK from 3a6ad40, plus the other session's uncommitted files under `App/`; nothing under `lib/` was uncommitted. I also read their uiautomator trees.
- **Code:** read in full for the area's 20 files. I also read table_calendar 3.2.1 from the pub cache.
- **Not run:** Flutter (loop rule), any phone or emulator.
- **Evidence levels:** previews are widget-test evidence, and the captures are emulator evidence.

**Walked:** Newcomer (ES, 1×/1.3×/2×, 360 and 393 dp, one hand), Daily user, TalkBack/low-vision/tremor.

| Flow | Path | Taps | Ends on |
|---|---|---|---|
| Understand today | Calendario | 0 | 2× on 360 dp (emulator): 1 of 2 tasks in view, strip reads «do» |
| Find a task | Tareas, scroll or search | 1 + scroll | 2× on 360 dp: no task before the button |
| Complete, undo | circle, Deshacer | 2 | Calendar: row stays struck. Tareas: row vanishes |
| Move to tomorrow | long-press or swipe, Mañana; or row, Cambiar fecha, Mañana | 2 / 3 | «Movida al …» + Deshacer |
| Move to Saturday | row, Cambiar fecha, 24, Listo | 4 | same |
| Reminder timing | row, chip, choice | 3 | 7 choices, two of them the same |
| Weekly repeat | row, ✏, Más detalles, Repetir, dropdown, Cada semana, Listo, Guardar cambios | 8 | «Cambios guardados» |
| Add a step | row, ✏, Más detalles, Añadir paso + Enter, Guardar cambios | 5 + typing | — |
| Free file space (refused file) | Ver tareas con archivos, task, scroll, Eliminar archivo adjunto, confirm, Back ×2 | 6 + scroll | — |
| Delete, undo | row, 🗑, Deshacer | 3 | «Tarea eliminada» |
| New task, free account | Nueva tarea, title, Mañana, Añadir al calendario | 3 + typing | lands lit (emulator `capture.result`) |
| Completed tasks | Tareas, unlabelled ✓ | 2 | every project's tasks, even from a project page |
| Día view | Semana ▾, Día | 2 | 00:00–06:00, empty |
| Landing after a 3-task dictation | (A's flow ending on Calendar) | — | 1 of the 2 lit same-day rows in view |

Also walked: overdue, undated tasks, the phone calendar's events, offline, many items, long titles, keyboard open, ES/CA/EN, dark mode.

**Numbers:**
- **Calendar, new account:** 16 tap targets (U10 target ≤ 15; unchanged).
- **Tasks in view, Calendar:** at 2× on 360 dp, 1 of 2 (emulator).
- **Tasks in view, Tareas root:**
  - 1× on 360 dp with a shared project: 1, under 12 targets;
  - 2× on 360 dp: 0 (ES and CA previews);
  - 2× on 393 dp: 1 (emulator).
- **Tasks in view, Día view on open:** 0 of 5 (normal day) and 0 of 11 (busy day).
- **Words on an empty day:** 12 (ES), or 14 with the phone's calendars → 5–6 with UX-1404.
- **Reminder choices for a timed task:** 7 → 6.
- **Buttons on a refused file's card:** 5 → 4.
- **Lit same-day rows in view after the 3-task example:** 1 of 2 → 2 of 2.

### Findings (most severe first)

**UX-1401 · Severity 3 · Saved tasks land half-hidden at large text, or off-screen**
- **Where:**
  - `App/lib/screens/calendar_screen.dart:160-219` (`_reveal`). A dated landing keeps a fixed 88 dp clearance (`:191-192`).
  - Only a no-date landing measures the save message (`:163-173`, `_messageClearance` `:246-265`). Tareas measures it for every landing (`App/lib/screens/home_screen.dart:290-293`).
  - Only the first lit row carries `_landedRow` (`:353-355`, `:781`).
  - Applies to Calendar after any capture, form save or voice change.
- **The moment:** "Dije tres cosas. Veo «Comprar pan y leche», el mensaje habla del viernes… ¿y lo de los niños a las cinco? Lo vuelvo a decir."
- **What happens:**
  - **1× on 360 dp** (`calendar/agenda.added.es.light.1x.png`). The fixture says «Comprar pan y leche, llamar al médico el viernes a las diez y recoger a los niños del colegio a las cinco». Calendar shows today with «Comprar pan y leche» lit. Today's second new task, «Recoger a los niños del colegio 17:00», is lit but out of view (AUDIT: `[off screen]`). The message reads «3 tareas añadidas · también el vie, 23 de oct».
  - **2×** (`agenda.added.es.light.2x.png`). The message is about 203 dp tall, so the 88 dp clearance leaves the lit row's second line under it.
  - **A voice move at 2×** does the same (`commands/applied.change-applied.es.light.2x.png`). «Ir a la peluquería» is lit, but its time and steps sit under «Movida al lun, 26 de oct · Deshacer».
- **Why it fails:**
  - U5's acceptance: "the saved task is visible on screen and highlighted, every time".
  - SC-10 and SC-11 (Rensink 1997; Kahneman 1993); UN-2 (Flaherty 2024).
  - The severity scale's own blocker is a saved task the person can't see and adds twice. I rate it 3 because the message gives the count and the row is one scroll away.
- **Fix:**
  - For dated landings, clear the measured message height + 8 dp, as the no-date landing and Tareas already do, instead of 88 dp.
  - When several lit rows are on the day shown, bring the block from the first to the last lit row into view whenever it fits above the message.
  - When the block doesn't fit, show the first row, and start the 1.5 s fade only for rows already in view. The others stay lit until scrolled to.
  - No copy change.
- **Verify:**
  - Preview `calendar/agenda.added` at 1× on 360 dp: both of today's lit rows are whole above the message.
  - At 2×: «Comprar pan y leche» is whole, with its time line, above the message.
  - `commands/applied.change-applied` at 2×: the lit row's time line is above the message.
  - Widget test with the three-task fixture (`test/ux_previews/capture_previews.dart:139-147`), at 1× and 2×, animations on and off.
- **Evidence:** seen in current renders; verified in code.

**UX-1402 · Severity 2 · The Día view opens on an empty night**
- **Where:** `App/lib/screens/day_timeline_screen.dart`:
  - `:180-184`: the scroll starts at 00:00;
  - `:58-61`: every day change jumps back there;
  - `:237-249`: «Ir al primer elemento con hora» scrolls in a fixed 250 ms, even with animations off;
  - `:204-207`, `:231-234`: the copy;
  - `:364-365`: the TalkBack label.
  - Reached from Calendar › «Semana ▾» › Día.
- **The moment:** "He elegido «Día» y no hay nada. ¿Y el médico de las diez?"
- **What happens:**
  - `calendar/timeline.normal.es.light.1x.png` and `timeline.busy.es.light.1x.png` are the same image, 37,363 bytes each: 00:00 to 06:00, empty.
  - None of the day's tasks is in view: 0 of 5 on the normal day, 0 of 11 on the busy one. The first, at 08:30, sits about 600 dp lower. At 2× only 00:00–04:00 shows.
  - The person must scroll, or understand «Ir al primer elemento con hora».
  - The copy talks about blocks and items:
    - date-only tasks sit under «Sin bloque de tiempo»;
    - a day with nothing timed says «No hay planes con hora para este día. Añade hora de inicio y duración para reservar un bloque.»;
    - TalkBack hears «Planificado para · Paseo por el parque · 08:30 · Sin duración · solo hora».
- **Why it fails:**
  - SC-5 (Fessenden 2018): what the person came for shows without scrolling.
  - Gulf of evaluation (Norman 2013): the person may conclude the day is empty.
  - Plain language (ISO 24495-1); SC-1 for the spoken label (Nielsen 2006f); AC-10 for the jump.
- **Fix:**
  - On open and on every day change, scroll so the first timed item sits near the top. On today, if the first item has already passed, scroll to the current hour instead. Follow "Remove animations".
  - Remove «Ir al primer elemento con hora» (5 → 4 targets).
  - Copy:
    - `timelineUnblocked`: the rows' own word, ES «Sin hora» / EN "No time" / CA «Sense hora»;
    - `timelineNoBlocks`: ES «No hay nada con hora este día.» / EN "Nothing with a time on this day." / CA «No hi ha res amb hora aquest dia.»;
    - TalkBack label, title first: «Paseo por el parque, 08:30»; a block «…, 09:00 – 10:00»; a deadline «Fecha límite: …». Drop «Planificado para» and `timelinePoint`.
- **Verify:**
  - Previews `timeline.normal` and `timeline.busy` at 1× and 2× show the 08:30 block, and differ from each other.
  - A widget test: the next day opens on its first item.
  - AUDIT: timeline TalkBack lines start with the task's title.
- **Evidence:** seen in current renders; verified in code.

**UX-1403 · Severity 2 · Tareas at large text: no task before the button**
- **Where:**
  - `App/lib/screens/home_screen.dart:427-450`: «Tus tareas» in `headlineLarge`, then «Proyectos» and ✓.
  - `:509-538`: the search, then four filter chips that wrap.
  - Above them, the project filter (`ProjectScopeControl`, area C).
- **The moment:** "Abro Tareas para buscar «Renovar el DNI» y solo veo botones."
- **What happens:**
  - **2× on 360 dp** (`tasks/tasks-tab.normal.es.light.2x.png`, `.ca.light.2x.png`): «Tus tareas» takes two lines and the chips three rows. No task shows above «Añadir tarea».
  - **Emulator, 393 dp at 2.0, no shared project** (`device/screen-tasks.list.es.light.2.0.png`, 14:08): one task.
  - **1× on 360 dp with a shared project** (`tasks-tab.normal.es.light.1x.png`): 12 tap targets above the first task, and one task in view.
  - **Three different «Todas»:**
    - «Todos los proyectos» filters projects;
    - «Todas» filters people;
    - «Todas las tareas» filters dates and priority.
    - On project pages TalkBack also names the people row's «Todas» «Todas las tareas» (UX-1110).
  - The search hint is cut at 2×: «Buscar una ta…».
- **Why it fails:**
  - SC-5 (Fessenden 2018);
  - CO-2 (Hick 1952; Cockburn 2007): many options before the first item;
  - SC-9 (WCAG 2.2 3.2.4): one word for three concepts;
  - AC-3.
- **Fix** (independent of U13; it doesn't pre-empt the two-tab decision):
  - «Tus tareas» in `titleLarge`, the size of Calendar's «Agenda de hoy». It fits one line at 2×.
  - The filter chips in one row, scrolling sideways when they don't fit and cut at the screen edge so the rest shows.
  - Drop «Todas las tareas»: Sin fecha, Hoy and Prioridad alta become toggles (tap again to clear), and with none on, the list shows everything.
  - Expected: at least one task in view at 2× on 360 dp, and two at 1× with a shared project.
- **Verify:**
  - Previews `tasks/tasks-tab.normal` ES and CA at 2× show a task above the button.
  - AUDIT shows 11 or fewer targets before the first task, and no «Todas las tareas» chip on the root.
- **Evidence:** seen in current renders and an emulator capture; verified in code.

**UX-1404 · Severity 2 · An empty day says "nothing" three times**
- **Where:**
  - `App/lib/screens/calendar_screen.dart:682-698`: the subtitle, `breathingRoom` «Un momento de calma.», or `noScheduledTasks` «No hay tareas de TaskFlow programadas».
  - `:718-736`: a 64 dp tinted icon tile, `rememberPrompt` «¿Qué quieres recordar?» and `calendarEmpty` «Nada previsto para este día.».
  - Every empty day once the first-run state is over.
- **The moment:** "«Un momento de calma»… «¿Qué quieres recordar?»… ¿Tengo algo hoy o no?"
- **What happens:**
  - 12 words (14 with the phone's calendars) and a tile say the day is empty. Only the last line says it plainly.
  - At 2× on 360 dp (`calendar/agenda.empty-day.es.light.2x.png`), «Nada previsto para este día.» is under «Añadir tarea» (AUDIT: off screen). What shows is the slogan and the question.
  - On the emulator at 1.0 (`device/share.after-back.es.light.1.0.png`, `talkback.calendar-start.es.light.1.0.png`), the screen reads: «No hay tareas de TaskFlow programadas», the tile, «¿Qué quieres recordar?», «Nada previsto para este día.».
  - UX-702 removed the tile and the slogan for the first-run state only (`runs/2026-10-15-changes/plan.md:33`).
- **Why it fails:** SC-2 (Nielsen 1997; Moran 2016); CO-5 (Sweller 1988); ON-4 (Kaplan 2021); OL-7.
- **Fix:**
  - Show one line, «Nada previsto para este día.» (the existing `calendarEmpty`): no subtitle, no tile, no title.
  - With the phone's calendars on, an events line follows, so the single line becomes `noScheduledTasks`, reworded without the brand: ES «No hay tareas para este día.» / EN "No tasks for this day." / CA «No hi ha tasques per a aquest dia.».
  - Words: 12 → 5 (14 → 6).
- **Verify:**
  - Previews `calendar/agenda.empty-day` at 1× and 2× show the line above the button.
  - AUDIT: after «Agenda de hoy», TalkBack reads one text.
- **Evidence:** seen in a current render and emulator captures; verified in code.

**UX-1405 · Severity 2 · Calendar reopens on a landed or picked day, not today**
- **Where:**
  - `App/lib/screens/calendar_screen.dart:101-106`: `_followToday` moves only a Calendar left on today. That is UX-203's rule.
  - `:268-277`: on resume.
  - `:140-147`: a landing selects the task's day.
  - `:71`: only a cold start begins on today.
- **The moment:** On Monday night she dictates «Médico el viernes», and Calendar shows Friday, lit. On Tuesday morning she opens TaskFlow: "¿Por qué sale el médico? ¿Dónde está lo de hoy?"
- **What happens:**
  - A day chosen by a landing, or tapped by the person, stays selected on every later open while Android keeps the app in memory. That includes after midnight.
  - The heading reads «viernes, 23 de octubre» instead of «Agenda de hoy». Only a small «Hoy» text button leads back.
- **Why it fails:**
  - Visibility of system status (Nielsen 1994).
  - SC-3 (Leiva 2020): the day at the top is the screen's anchor.
  - The landing chose that day; the person didn't.
- **Fix:**
  - When the app comes back after 30 minutes or more, or on a new day, Calendar selects today and clears `_picked`.
  - Shorter returns keep the day, so a picked day still reaches the next capture (UX-602, D9).
  - No copy change.
- **Verify:**
  - Widget test: land on Friday, then resume 31 minutes later: «Agenda de hoy», with today selected.
  - Resume 5 minutes later: Friday stays, and capture still receives the picked day.
  - Phone: save a task for Friday at night, then reopen the app the next morning.
- **Evidence:** verified in code. No capture covers a warm resume, so it needs a device check.

**UX-1406 · Severity 2 · A ticked task vanishes from Tareas at once**
- **Where:**
  - `App/lib/screens/home_screen.dart:131-139`: `_visible` drops completed tasks. This list serves the Tareas root, project pages and Sin fecha.
  - Calendar keeps a ticked row in place (`calendar_screen.dart:49-51`, `:328-335`; UX-220).
- **The moment:** "He tocado el círculo sin querer y la tarea ha desaparecido. ¿Dónde está?"
- **What happens:**
  - A tap on the circle, or a swipe right, removes the row at once.
  - «Tarea completada · Deshacer» is the only trace. Once it goes, the task is reachable only through the unlabelled ✓ (UX-1407).
  - On Calendar, the same tick leaves the row struck through.
- **Why it fails:** UN-2 (Flaherty 2024; Budiu 2018cb); SC-10 (Rensink 1997); OL-1 (Kane 2019: older users mis-tap more); SC-9 (consistency with Calendar).
- **Fix:**
  - A row ticked on the page stays in place, struck through, until the person leaves the tab or page, or changes the search or a filter: Calendar's `_openOnDay` rule.
  - Its circle reopens it meanwhile.
  - No copy change.
- **Verify:**
  - Widget test on the Tareas root and on a project page: tick a row, and it stays, struck through, with «Reabrir». Switch tabs and come back, and it's gone.
  - Add a `tasks/tasks-tab` «completed» preview.
- **Evidence:** verified in code. No render shows Tareas after a tick.

**UX-1407 · Severity 2 · Completed tasks hide behind ✓ and ignore the project**
- **Where:**
  - `App/lib/screens/home_screen.dart:371-375`: an icon-only `task_alt_rounded`, tooltip «Tareas completadas». It sits beside «Proyectos» on the root (`:446`) and in the app bar on project pages and Sin fecha (`:391`).
  - `App/lib/main.dart:467` and `App/lib/screens/completed_tasks_screen.dart:17-25`: no project filter.
  - `:41-47`: the heading.
- **The moment:** On «Matemáticas»: "Quiero ver lo que ya hicimos aquí." She taps ✓ and gets a list that mixes in «Paseo por el parque» and every other project.
- **What happens:**
  - The only way to completed tasks is a 48 dp circle-check with no word.
  - From a project page, it opens every project's completed tasks.
  - The page opens on a slogan, «Mira todo lo que has avanzado.».
- **Why it fails:**
  - SC-6 (Harley 2014; Leung 2011): an unlabelled icon is a guess for the newcomer.
  - SC-7 (Pernice 2016a).
  - Match with the real world (Nielsen 1994): the page you came from sets the scope.
  - CO-5.
- **Fix:**
  - On the root, a text button in «Proyectos»' style replaces the icon: ES «Completadas» / EN "Completed" / CA «Completades».
  - On a project page, the same text button sits beside «Notas» and opens that project's completed tasks.
  - Drop the icon from the app bar and from Sin fecha.
  - Drop `progressHeading` and keep the count line.
- **Verify:**
  - AUDIT for `tasks/tasks-tab` and `tasks/project` shows a labelled «Completadas» and no icon-only «Tareas completadas».
  - Widget test: opened from «Matemáticas», it lists only Matemáticas' completed tasks.
- **Evidence:** verified in code and seen in current renders.

**UX-1408 · Severity 2 · At large text the week strip cuts days and numbers**
- **Where:** `App/lib/screens/calendar_screen.dart:546-619`:
  - fixed `rowHeight: 48` (`:560`) and `daysOfWeekHeight: 30` (`:561`);
  - a 4 dp `cellMargin` (`:579`) and 11 sp weekday labels (`:610-619`);
  - day cells 42.9 dp wide at 360 dp: 20 dp of sliver padding plus 10 dp of surface padding on each side;
  - the header Wrap (`:456-531`).
- **The moment:** "¿«do»? ¿Y el 2?"
- **What happens:**
  - **Emulator, 360 dp at 2.0** (`device/screen-calendar.today-360dp.es.light.2.0.png`, 14:10): «dom» reads «do», and «19» spills out of its pill. This confirms SEEN #12.
  - **Previews at 2× (linear) on 360 dp:**
    - ES: «20» reads «2»; «jue», «dom» and «20» are clipped;
    - EN: «Mon» and «Wed» split mid-word;
    - CA: «dj.» and «dg.» are clipped.
    - AUDIT lists these as cut text on every Calendar state.
  - **Day cells** are 43 × 48 dp with 0 dp gaps at 360 dp (AUDIT), under the 48 dp floor.
  - **At 2×**, the month name and «Semana ▾» take two lines and the card grows to about 190 dp. One task fits above the button (emulator).
- **Why it fails:** AC-3 and AC-4 (WCAG 2.2 1.4.4, 1.4.10); RE-2 and RE-3 (Android Touch targets; Kobayashi 2011).
- **Fix:**
  - Grow `rowHeight` and `daysOfWeekHeight` with the text scaler.
  - Use the narrow weekday form (`DateFormat.EEEEE`: ES «L M X J V S D», CA «dl dt dc dj dv ds dg», EN "M T W T F S S") whenever the short form doesn't fit the cell.
  - Keep day numbers whole: shrink them only as far as the cell needs, and size the selected pill to the number.
  - Give each day at least 48 dp at 360 dp by trimming the card's side padding from 30 to 12 dp per side.
- **Verify:**
  - Previews `calendar/agenda.*` in ES, CA and EN at 2× on 360 dp: no strip text in AUDIT's cut list, and day cells of at least 48 × 48 dp.
  - Emulator at 360 dp and 2.0: whole weekday labels, and «19» inside its pill.
- **Evidence:** seen in an emulator capture and current renders; verified in code.

**UX-1409 · Severity 2 · Next month's days look disabled (2.22:1)**
- **Where:** `App/lib/screens/calendar_screen.dart:577-609` sets no `outsideTextStyle`, so table_calendar 3.2.1 draws the other month's days in its default #AEAEAE (`customization/calendar_style.dart:220`). This shows in the week view at a month boundary, such as 26 Oct – 1 Nov.
- **The moment:** "El 1 sale muy clarito… ¿no se puede elegir?"
- **What happens:**
  - The adjacent month's days are pale grey: «1» at 28 dp measures 2.22:1 on white (AUDIT full pass, `commands/applied.change-applied.ca.light.2x.png`).
  - They still select like any other day.
- **Why it fails:** AC-1 (WCAG 1.4.3: 3:1 even for large text). The grey reads as "unavailable", an affordance that misleads (Norman 2013).
- **Fix:** in the week view, draw other-month days like any other day: `defaultTextStyle`, or the weekend style on weekends. No copy change.
- **Verify:**
  - AUDIT's contrast pass shows no failure on that render.
  - Add a preview of a boundary week at 1×, in light and dark.
- **Evidence:** measured in a current render; verified in code and in the package source.

**UX-1410 · Severity 2 · TalkBack hears no selected day, today or task dots**
- **Where:**
  - table_calendar 3.2.1 labels every cell with its date only, under `excludeSemantics: true` (`widgets/cell_content.dart:55-58`, `:170-173`).
  - `App/lib/screens/calendar_screen.dart:621-648`: the dots carry no semantics.
  - `:578`: `outsideDaysVisible: false` leaves blank tappables in the month view.
  - Each cell offers a long press with nothing behind it (`table_calendar.dart:570`; no `onDayLongPressed`).
- **The moment (TalkBack):** "lunes, 19 de octubre de 2026" — the same words for the chosen day as for any other. And which days have something?
- **What happens:**
  - AUDIT and the emulator tree (`device/a11y/screen-calendar.today.es.light.1.0.xml`, `selected=false` on 19) show no selected state, no "hoy" and no task count.
  - The month view has 4 unlabelled tappables (AUDIT: "No label: a tappable … (tap, long press)").
  - Every day announces a long press.
  - The arrows say «Mes o semana anterior» in either view.
- **Why it fails:** AC-6 (WCAG 4.1.2: name, role and value); AC-5 (WCAG 1.4.1): the dots carry meaning only visually.
- **Fix:**
  - For every day, `markerBuilder` (which the package places outside the cell's `excludeSemantics`) returns the dots wrapped in `Semantics(selected: …, value: …)`.
    - The value: ES «hoy · 3 tareas» / EN "today · 3 tasks" / CA «avui · 3 tasques».
    - That needs a new ICU-plural key for the count, such as `dayTaskCount`, plus the existing `today`.
  - In the month view, show the adjacent month's days, labelled, readable and selectable, as the week view does. That leaves no blank targets.
  - `onDayLongPressed` selects the day, like a tap.
  - The arrows name the view: ES «Semana anterior» / «Mes anterior», EN "Previous week" / "Previous month", CA «Setmana anterior» / «Mes anterior», and the same for next.
- **Verify:**
  - AUDIT TalkBack shows `[selected]` on the chosen day and «hoy · 3 tareas» values.
  - The month view has 0 unlabelled tappables.
  - The emulator tree has `selected=true` on the chosen day.
- **Evidence:** measured in AUDIT and the emulator tree; verified in code and in the package source.

**UX-1411 · Severity 2 · Every tab announces itself as «taskflow»**
- **Where:** `App/lib/widgets/custom_app_bar.dart:26-51`. On root tabs the bar draws the brand and ignores `title`, although Calendar (`calendar_screen.dart:400`) and Tareas (`home_screen.dart:388-392`) pass «Calendario» and «Tareas».
- **The moment (TalkBack):** opening Tareas: "taskflow, encabezado" — exactly as on Calendario.
- **What happens:**
  - AUDIT names the route «taskflow» on Calendario and on Tareas. Every root tab uses the same bar.
  - On the emulator, TalkBack starts on «Cuenta» (`device/talkback.calendar-start.es.light.1.0.png`).
  - Sighted users read "taskflow" at the top-left, not the screen's name.
- **Why it fails:** AC-7 (Android A11y testing): each screen's title is announced on arrival; SC-3 (Leiva 2020).
- **Fix:**
  - Keep the logo for the eye.
  - Give the root bar's title `Semantics(header: true, namesRoute: true, label: title)`, with the brand text excluded. TalkBack then hears «Calendario», «Tareas», «Notas» and «Ajustes».
  - No visible change and no new strings.
- **Verify:** AUDIT shows the heading «Calendario» [names route] on `calendar/agenda`, and «Tareas» on `tasks/tasks-tab`. The emulator tree agrees.
- **Evidence:** measured in AUDIT; seen in an emulator capture; verified in code.

**UX-1412 · Severity 2 · Month view: a tapped day's tasks stay hidden**
- **Where:**
  - `App/lib/screens/calendar_screen.dart:567-570`: a tap only selects the day.
  - `:293-297`: Mes keeps the six-row grid above the agenda.
- **The moment:** "Toco el 30 para ver qué tengo… ¿y?"
- **What happens:**
  - In `calendar/agenda.month.es.light.1x.png` (an account with a shared project), the grid ends about 537 dp down. «Agenda de hoy · 10 pendientes» sits on the button, with no task row in view.
  - Tapping a day changes only that heading. Without shared-project chips, about one task would peek.
- **Why it fails:** SC-10 (Rensink 1997; Budiu 2018cb): the change happens away from where she's looking; gulf of evaluation (Norman 2013).
- **Fix:**
  - A day tapped in Mes switches the strip to Semana on that day, so its first tasks show under the week. Mes stays one tap away in «Semana ▾».
  - Scrolling the agenda into view would also do. Either way, the day's first task shows.
  - No copy change.
- **Verify:** preview: Mes, then tap a day with tasks. The render shows that day's first task above the button.
- **Evidence:** seen in a current render; verified in code.

**UX-1413 · Severity 2 · Reminder choices: a vague default and a clock dial**
- **Where:**
  - `App/lib/widgets/reminder_control.dart:122-124`: 7 choices for a timed task.
  - `:152-156`: `useDefault`, «Usar valor predeterminado» (`App/lib/l10n/region.dart:56-63`).
  - `:179-182`: `showTimePicker` opens on the dial.
  - `:293-311`: the form's Recordatorio row has no chevron, while Repetir does (`App/lib/widgets/task_editor.dart:1253-1272`).
- **The moment:** "«Usar valor predeterminado», ¿cuál es? ¿Y en qué se diferencia de «10 minutos antes»?" Later: "El 17 está en el círculo pequeño; he puesto las 5."
- **What happens:**
  - The detail's reminder chip offers: Usar valor predeterminado ✓, Desactivado, A la hora programada, 10 minutos antes, 30 minutos antes, 1 hora antes, 1 día antes. With the default at 10 minutes, the first and the fourth do the same thing.
  - For a task with no time, it offers Usar valor predeterminado (9:00, which isn't said), Desactivado and Elegir hora del aviso.
  - Elegir hora del aviso opens Android's dial, while the form's own time is typed (UX-1004).
  - In the new-task form, «Recordatorio · Desactivado» has no ›, while «Repetir» just below it does (`form/new-task.details.es.light.1x.png`).
- **Why it fails:**
  - CO-2 and CO-4 (Hick 1952; Chernev 2015).
  - SC-9: one name per concept.
  - FO-4 (Kane 2019; Flutter `showTimePicker`).
  - RE-3: the dial's rings are 28 dp apart, as UX-1004 measured.
- **Fix:**
  - Show the default as its value, selected when the task follows it: ES «10 minutos antes · predeterminado» / EN "10 minutes before · default" / CA «10 minuts abans · per defecte» (existing `defaultChoice`).
  - Drop the separate «Usar valor predeterminado» row and the duplicate row: 7 → 6 choices.
  - For a date-only task, show «9:00 · predeterminado» while reminders are on, and no default row when no time is set.
  - «Elegir hora del aviso» opens the picker in typing mode (`initialEntryMode: TimePickerEntryMode.input`).
  - Give the form's Recordatorio row the › chevron.
- **Verify:**
  - Widget test: the chooser lists 6 rows, with the default row labelled by its value.
  - The picker opens in input mode.
  - Preview `form/new-task.details` shows the ›.
- **Evidence:** verified in code. The chooser and the picker have no render; the row is seen in a current render.

**UX-1414 · Severity 2 · Freeing file space: files last, five look-alike buttons**
- **Where:**
  - `App/lib/screens/tasks_with_files_screen.dart:93-105`: the task opens at its top.
  - `App/lib/screens/task_detail_screen.dart:437-438`: Archivos is the last section.
  - `App/lib/widgets/attachment_panel.dart`:
    - `:287-408`: the card's buttons;
    - `:364-381`: «Reintentar transferencia», shown even while the file is refused for space;
    - `:399-407`: «Eliminar archivo adjunto», styled like the others;
    - `:109-125`: a teal filled confirm button.
  - Strings `storageFull` and `fileRetry`.
- **The moment:** "Me dice que borre archivos. Abro «Viaje a Lisboa»… ¿dónde están los archivos?" Then: "¿«Reintentar transferencia»? ¿Una transferencia de dinero?"
- **What happens:**
  - From «Tareas con archivos», the task opens at the top. The files come last, under the date, the reminder, the steps and the notes.
  - A refused file's card (`tasks/detail.file-space-full.es.light.1x.png`) shows a 23-word red sentence, then five teal text buttons 4 dp apart (AUDIT): Abrir, Reintentar transferencia, Ver Pro, Ver tareas con archivos, Eliminar archivo adjunto.
  - Reintentar can't help while the space is full, and a removal already re-sends refused files (UX-500).
  - The removal question has a filled teal «Eliminar archivo adjunto», while other deletions are red (UX-317).
- **Why it fails:**
  - CO-2 (Hick 1952);
  - RE-6 (Hoober 2017c; Harada 2013): a destructive control among frequent ones;
  - SC-9;
  - plain language (ISO 24495-1): «transferencia» reads as a bank transfer;
  - SC-5.
- **Fix:**
  - Opened from «Tareas con archivos», the task shows its Archivos section in view.
  - A file refused for space says one sentence, and the buttons say the rest: ES «Tu espacio para archivos está lleno (100 MB).» / EN "Your file space is full (100 MB)." / CA: the first sentence of the current `storageFull`.
  - While a file is refused for space, there's no Reintentar. Elsewhere it reads ES «Volver a subir» / EN "Upload again" / CA «Torna a pujar».
  - «Eliminar archivo adjunto» goes last, in the error colour, 12 dp below the others. Its confirm button is red, like other deletes.
  - Buttons on a refused card: 5 → 4.
- **Verify:**
  - Preview `tasks/detail.file-space-full` shows 4 buttons, a red remove last, and the one-sentence reason.
  - Widget test: opened from the list, Archivos is in view.
  - Catalog test: no «transferencia», "transfer" or «transferència».
- **Evidence:** seen in current renders; verified in code.

**UX-1415 · Severity 2 · Task details put the notes last**
- **Where:**
  - `App/lib/screens/task_detail_screen.dart:383-437`: the steps and then the notes (`:437`) come after the date card and the reminder chip (`:349-377`).
  - `:430-431`: a fixed rule sentence sits under the steps.
  - The edit form shows Notas right under the title (`task_editor.dart:838-840`), and the capture result shows it under the date line.
- **The moment** (opening the doctor's reminder): "¿Qué tenía que llevar? Ah, está abajo del todo."
- **What happens:**
  - The notes — the owner's "bring the blood test" — come after the reminder and after every step. At 1.3–2×, or when there are steps, they're below the fold.
  - A 13-word sentence always sits under the steps: «Marcar todos los pasos no completa la tarea. Pulsa Completar cuando hayas terminado.»
- **Why it fails:** SC-1 and SC-5 (Nielsen 2006f; Fessenden 2018); SC-9 (same order as the form); CO-5 (Sweller 1988).
- **Fix:**
  - Put the notes right after the date card, before the reminder and the steps, as in the form.
  - Drop `checklistCompletionHelp` from the detail: the «Completar» button right below is the next step. Words under the steps: 13 → 0.
- **Verify:**
  - Widget test of the order: title, date card, Notas, reminder, Pasos, Archivos.
  - A `tasks/detail` preview with notes and steps at 1.3× shows the notes above the fold.
- **Evidence:** verified in code. No current render shows a task with notes; at 2× on 360 dp, the notes would start about 560 dp down, against the buttons at about 636 dp.

**UX-1416 · Severity 2 · Task rows: unnamed gestures and disabled-looking read-only rows**
- **Where:** `App/lib/widgets/task_tile.dart`:
  - `:35-47`: `Dismissible`, which TalkBack exposes as scroll left and scroll right;
  - `:79-81`: long press opens Cambiar fecha, with no name;
  - `:87-97`: on a view-only project, a disabled checkbox merges with the row.
- **The moment (TalkBack):** "Llamar al médico… acciones: desplazar a la izquierda, desplazar a la derecha, mantener pulsado." What does each one do?
- **What happens:**
  - AUDIT lists every row as "→ tap, long press, scroll left, scroll right", none of them named.
  - A view-only row reads «Completar Comer con Ana Comer con Ana 13:30», checkbox, disabled: the title twice. In the fixture, that row is read-only because its project isn't loaded, but a viewer's tasks have the same shape.
  - On screen it's a pale circle that does nothing when tapped.
- **Why it fails:** AC-9 (Flutter CustomSemanticsAction; WCAG 2.5.1); PL-8 (Norman 2010); AC-6.
- **Fix:**
  - Editable rows: a `CustomSemanticsAction` named with the existing `reschedule`: ES «Cambiar fecha» / EN "Change date" / CA «Canvia la data». Completing stays on the circle.
  - View-only rows: no circle. TalkBack hears the row as one button, «Comer con Ana, 13:30», that opens the task, and the task says it can't be changed.
- **Verify:**
  - AUDIT TalkBack shows the named action on rows.
  - A view-only row has no checkbox node.
  - Add a preview of a viewer's project page.
- **Evidence:** measured in AUDIT; verified in code.

**UX-1417 · Severity 1 · Task detail's title is cut; edit and delete touch**
- **Where:** `App/lib/screens/task_detail_screen.dart:162-185`.
- **The moment:** "«Detalles de la tar…»"
- **What happens:**
  - «Detalles de la tarea» is 1 dp too wide at 1× on 360 dp and shows as «Detalles de la tar…». At 2× it reads «Detalles de l…» (AUDIT, renders, emulator at 2.0).
  - ✏ and 🗑 sit 0 dp apart (AUDIT). Delete is instant (with Undo).
- **Why it fails:** AC-3; RE-6 (Hoober 2017c; Harada 2013).
- **Fix:**
  - Title ES «Tarea» / EN "Task" / CA «Tasca» (a new key). Notes keep «Nota». The headline below is the task's own title.
  - Put 12 dp between ✏ and 🗑.
- **Verify:** AUDIT shows no cut text on `tasks/detail`, and a gap of at least 8 dp between the two icons.
- **Evidence:** measured in AUDIT; seen in renders and an emulator capture.

**UX-1418 · Severity 1 · Rows and counts show empty values and tiny labels**
- **Where:**
  - `App/lib/widgets/task_schedule_label.dart:19-21`;
  - `App/lib/widgets/task_tile.dart:243-263`: the priority label at 10 sp;
  - `App/lib/screens/calendar_screen.dart:689-692`: `agendaCounts`.
- **What happens:**
  - Every date-only row on a day reads «🕐 Sin hora».
  - On the Sin fecha page, every row reads «🕐 Sin fecha» (`tasks/tasks-tab.inbox.es.light.1x.png`).
  - «2 pendientes · 0 completadas» wraps to two lines at 2× on 360 dp (emulator).
  - «Prioridad Media» is drawn at 10 sp.
- **Why it fails:** defaults shown as content; CO-5 (Sweller 1988); OL-1 (Kane 2019: small text).
- **Fix:**
  - On Calendar, a date-only row shows no time line.
  - In dated lists, show the date alone («sáb, 17 de oct»), without «· Sin hora».
  - Rows on the Sin fecha page show no date line.
  - The count drops «· 0 completadas» when nothing is done.
  - The priority label is 12 sp, like the rest of the row.
- **Verify:** previews `calendar/agenda.added`, `tasks/tasks-tab.inbox` and `calendar/agenda.normal` at 2×.
- **Evidence:** seen in renders and an emulator capture; verified in code.

**UX-1419 · Severity 1 · Lit rows' grey text drops to 4.39:1**
- **Where:** `App/lib/widgets/task_tile.dart:325`: a lit row uses `primaryContainer`, and its secondary text stays `onSurfaceVariant`.
- **What happens:** «Sin hora» measures 4.39:1 on #e0eee5 (AUDIT full pass on `calendar/agenda · added` and on `commands/applied · mixed-applied`).
- **Why it fails:** AC-1 (WCAG 1.4.3; 4.39 isn't rounded up).
- **Fix:** while a row is lit, its secondary text uses `onSurface`, or the lit tint is light enough to keep 4.5:1, in light and dark.
- **Verify:** AUDIT shows no contrast failures on those renders.
- **Evidence:** measured in current renders.

**UX-1420 · Severity 1 · Overdue tasks in Tareas don't say so**
- **Where:** `App/lib/widgets/task_tile.dart:136-145`; `App/lib/screens/home_screen.dart:131-153`.
- **What happens:** in «Todas las tareas», «Renovar el DNI · sáb, 17 de oct · Sin hora» heads the list with nothing saying it's late. Calendar files it under «Atrasada».
- **Why it fails:**
  - TA-9: calm wording, with one name for the concept.
  - SC-9.
  - CO-3 (Cowan 2001): no date arithmetic left to the reader.
- **Fix:**
  - In task lists, an open task whose day has passed reads ES «sáb, 17 de oct · Atrasada» / EN "Sat, 17 Oct · Overdue" / CA «ds., 17 d’oct. · Endarrerida».
  - No colour; a new key.
- **Verify:** preview `tasks/tasks-tab.normal` shows the word.
- **Evidence:** seen in a current render; verified in code.

**UX-1421 · Severity 1 · Developer words in the task form's rarer corners**
- **Where:** strings in `App/lib/l10n/app_es.arb`, `app_en.arb` and `app_ca.arb`, used by `App/lib/widgets/task_planning_control.dart:159-181`, `App/lib/widgets/schedule_editor.dart:362-395`, `App/lib/widgets/task_interactions.dart:95-102`, `App/lib/screens/task_detail_screen.dart:206-212` and `App/lib/widgets/device_calendar_events.dart:185`.
- **What happens** (the edit form's Más detalles, Cambiar fecha errors, view-only tasks and phone events):
  - `deadlineRecurringHelp`: 34 words about «instancia original» and «margen».
  - `reminderAnchor` «Recordar con respecto a», and `reminderAnchorHelp` «Un recordatorio por instancia…».
  - `reviewInvalidTime` «Revisa este valor».
  - `scheduleError` / `scheduleChangedAgain`, which say «programación».
  - `viewOnlyTask`, which says «solo lectura… permisos de edición».
  - «Evento del calendario · solo lectura» repeated on every phone event row.
- **Why it fails:** plain language (ISO 24495-1); UN-7 (Neusesser 2023): errors say what to do; OL-2.
- **Fix:**
  - `deadlineRecurringHelp` → ES «Cada repetición tiene su propia fecha límite.» / EN "Each repeat has its own deadline." / CA «Cada repetició té el seu propi termini.»
  - Drop `reminderAnchorHelp`.
  - `reminderAnchor` → ES «Recordar antes de» / EN "Remind before" / CA «Recorda-m’ho abans de».
  - `reviewInvalidTime` split by field:
    - hour: ES «Hora del 0 al 23» (on a 12-hour clock «del 1 al 12») / EN "Hour from 0 to 23" (1 to 12) / CA «Hora del 0 al 23» (de l’1 al 12);
    - minutes: ES «Minutos del 0 al 59» / EN "Minutes from 0 to 59" / CA «Minuts del 0 al 59».
  - `scheduleError` → ES «No se pudo cambiar la fecha. Inténtalo de nuevo.» / EN "Couldn't change the date. Try again." / CA «No s’ha pogut canviar la data. Torna-ho a provar.»
  - `scheduleChangedAgain` → ES «La fecha ha vuelto a cambiar. Abre la tarea para revisarla.» / EN "The date changed again. Open the task to check it." / CA «La data ha tornat a canviar. Obre la tasca per revisar-la.»
  - `viewOnlyTask` → ES «Solo puedes ver esta tarea.» / EN "You can only view this task." / CA «Només pots veure aquesta tasca.»
  - Drop `calendarReadOnly` from the events list rows. The sheet's title already says what they are.
- **Verify:** catalog test: none of «instancia», «programación», «valor», «permisos de edición» remains in ES, nor their EN and CA equivalents.
- **Evidence:** verified in the catalogs and in code.

### Keep
- The new-task form is plain and fast:
  - the title, then Hoy · Mañana · Elegir día;
  - «Añadir hora» only once a day is chosen;
  - one button that names where the task goes;
  - it lands lit with «Añadida al mar, 20 oct · Deshacer» (emulator `capture.typing-filled`, `capture.result`).
- Today's «Atrasada · 1» is calm and grey, and the task keeps its date (`calendar/agenda.busy`).
- Every change in B can be undone: complete, move («Movida al lun, 26 de oct»), delete («Tarea eliminada») and add. The detail's date and time rows open «Cambiar fecha».
- The offline line is calm and true: «Sin conexión: tus tareas están guardadas en este teléfono.»
- «Tareas con archivos» lists the largest first, in plain words («3 archivos · 12,4 MB»), with one help line.

### Progress against UX_REVIEW.md (U1–U14)
- **U5 — still open in B.** UX-1401: dated landings at large text, and a second new task for the same day. The U5 work recorded in ISSUES.md holds.
- **U8 — holds.** Calendar, Tareas, project pages, the timeline and the form each have one filled button.
- **U10 — unchanged.** A new account's Calendar has 16 tap targets (AUDIT first-use).
- **U11 — holds in B.** The timeline's «bloque» and «elemento» copy is UX-1402.
- **U12 — holds on the emulator at 393 dp and 2.0** (`device/first-run.calendar-empty.es.light.2.0.png`: the whole line is above the button).
  - The 360 dp, linear-2× previews (ES, CA, and ES for a free account) still cut it under the button.
  - UX-702's phone check should add a 360 dp phone.
- **U13 — decision.** UX-1403 and question 2 relate to it.
- **Not in B:** U1–U4, U6, U7, U9, U14.

### Questions for the owner
1. **A default day in the form, and dates in shared text.** This has been open since 2026-10-18, alongside D9, D2 and your 2026-10-18 rule that typed text isn't read for dates.
   - **What happens:**
     - A shared «Comprar pan y leche el viernes» opens the form with no day and «Añadir tarea» (emulator `share.landing.es.light.1.0.png`).
     - One Back saves it to Sin fecha, with «el viernes» in its title (`share.after-back`: «Sin fecha · 1»).
     - From Calendar's today, a typed task with no chip tapped also goes to Sin fecha (`form/new-task.empty`).
   - **Options:**
     - (a) keep it as it is;
     - (b) read day and time in shared text, as D2 reads dictated words: they are someone else's words, not the person's typing;
     - (c) also preselect «Hoy» when the form opens from Calendar's today.
   - **Recommendation:** (b). Keep the form's empty default, which matches D9 for dictation.
     - With no day chosen, the button could say where the task goes: ES «Añadir sin fecha» / EN "Add with no date" / CA «Afegeix sense data».
     - The capture result (area A) would follow.
2. **Tareas' «Hoy» and «Sin fecha» chips** repeat Calendar's today and its «Sin fecha · N» link. Decide them with U13. Until then, UX-1403 only tidies them.
3. **The Día view.** Keep it now that UX-1402 makes it usable, or drop it from «Semana ▾» with U13 if the §7 test shows nobody opens it.
   - Recommendation: fix it now and decide with U13.

### Cross-slice notes
- **A:** `task_actions.dart:125-143`: «Sin guardar · N» sits 0 dp above «Añadir tarea» (AUDIT `calendar/agenda · pending-captures`, 2×), so two different actions touch.
- **C:** at 360 dp and 1× in Spanish, «Todos los proyectos» + «Todas» + «Para mí» wrap, and «Para mí» sits alone on a second row (`calendar/agenda.busy`). With B's «Todas las tareas», the Tareas root shows three «Todas» (UX-1403).
- **D:** «Conectar calendarios del teléfono» selects no calendar (`device_calendar_provider.dart:162-172`).
  - Calendar then shows «Elige calendarios para mostrar tus compromisos existentes.» on every day.
  - On a phone with no calendar accounts, that line is a dead end (emulator `share.after-back`, `talkback.calendar-start`).
- **D (theme):** every primary button is 52 dp tall (AUDIT flags "primary under 56 dp" on every B screen); RE-3 asks for more for older hands.
- **D:** UX-1411's fix in `custom_app_bar.dart` also gives Notas and Ajustes their spoken names.
- **D:** SEEN #10 (a reminder tap opens the day, not the task) doesn't reproduce on 3a6ad40: `notification.tap-landing.es.light.1.0.png` shows the task's details.
- **A and D:** SEEN #7 (Back from a shared form saves it with no date, and "no message") is working as designed under D6 and D12.
  - `share.after-back` was captured 38 s after `share.landing`, long after the message had closed.
  - «el viernes» staying in the title follows your 2026-10-18 rule; see question 1.

### Memory notes
- **Screen map, area B, as of 2026-10-19:**
  - The root app bar always draws «taskflow» and ignores `title` (UX-1411).
  - Calendar: an optional scope row, the week card (`TableCalendar` with `rowHeight: 48` and `daysOfWeekHeight: 30`), «Agenda de hoy» with the counts line, «Atrasada · N», rows, the events line, «Sin fecha · N», then `TaskActions`.
  - An empty day shows a subtitle, a tile, a title and a message (UX-1404).
  - The Día view starts at 00:00 (UX-1402).
  - Tareas root: scope chips, «Tus tareas» in `headlineLarge`, «Proyectos» with an icon-only ✓, search, and four ChoiceChips. `/completedTasks` ignores the project.
  - Task detail order: title, chips, «Creada por», Actividad, date card, reminder chip, steps with a fixed rule sentence, notes, files.
  - The edit form keeps «Fecha y hora ›» (the full sheet). The create form uses chips and a typed time.
  - The reminder chooser: «Usar valor predeterminado» plus the values, and a dial for «Elegir hora del aviso».
- **New recurring problem types:**
  - Fixed-size third-party widgets clip at 2×: table_calendar's `rowHeight` and `daysOfWeekHeight`, and its default outside-day grey #AEAEAE.
  - Landing reveals with a fixed clearance (88 dp) where the message's measured height is needed. Only the first lit row is revealed.
  - View state that the app chose (a landing day) persists across later opens.
  - Shared widgets override per-screen names (the root bar's 'taskflow').
- **table_calendar 3.2.1 facts:**
  - `CellContent` wraps each cell in `Semantics(label: date, excludeSemantics: true)`.
  - `markerBuilder` runs for every enabled day and sits outside that wrapper, so it can carry selected and count semantics.
  - Every cell's `GestureDetector` exposes a long press.
  - Blocked outside days in the month view are an empty, unlabelled tappable.
- **Review technique:**
  - The device lane's 360 dp captures at 2.0 use Android's non-linear scaling; previews are linear 2×.
  - «dom» → «do» shows in both; «20» → «2» only in previews. Compare both before rating a clip.
  - Two renders with identical byte sizes (the timeline's normal and busy) are a quick sign that a state isn't shown.
