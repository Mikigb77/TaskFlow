## UX review — A: voice capture, judged for speed — 2026-10-14

**Verdict:** Ship after fixes. The three-tap path (Añadir tarea, Listo, Añadir al calendario) holds in code, all in the same thumb zone. But every save waits on a full server sync. A landing silently re-dates the next undated dictation. The microphone opens late, so first words can be lost. And the typing and offline path drops common Spanish dates. Fix these four before claiming capture is clearly faster than typing.

**Evidence:**
- Code, read flow by flow.
- The current renders in `App/build/`, written at 14:11 today, after the last code commit (8779bdb, 14:10). Read: `capture-listening-es-2x`, `review-direct-light/dark`, `review-batch-light/dark`, `calendar-es-1.3x-light`, `calendar-feedback-light`.
- No render covers typing, the used-up line, the slow or failed states, an opened batch card, or a result without notes.
- Flutter wasn't run (UX loop rule), and nothing ran on a phone. All timings below are estimates from code, except the staging AI timings in `../UX_REVIEW.md`.

**Walked:** each path below as the newcomer (Spanish, 1.3–2× text, one-handed), the daily user (bursts, interruptions) and the TalkBack user. For TalkBack, listening waits for "Empezar a hablar", which costs one extra tap by design.

| Path | Taps | Waits, from first touch to a saved, visible task | Screen changes and animations | Decisions |
|---|---|---|---|---|
| 1. Spoken task with a date, Calendar, warm | 3: Añadir tarea, Listo, Añadir al calendario | (a) open → "Escuchando": speech probe, timezone, capture sweep, permission, recognizer (UX-603). (b) Listo → result: recognizer finish (cap 4 s) plus AI 1.3–4.8 s on staging, once 20.5 s (UX-610). (c) save → sheet closes: local save plus a full sync (UX-601). | Calendar → sheet (listening, understanding and result in place) → Calendar. Sheet up 250 ms, down 200 ms, scroll 300 ms, highlight 1.5 s, message 4 s. | 1 (is the date right?) |
| 1. Same, cold | +0 | Adds app start, reminder setup (UX-424), and session restore plus a reminder reconcile (UX-611) | Adds the splash and the session screen | — |
| 2a. One dictation, three tasks | 3 | Same as path 1; the AI may take longer | Lands on the earliest day only; the others are out of sight (U5) | 1 per card |
| 2b. Three dictations back to back | 9 | Waits (a)–(c) × 3, including 3 syncs | After each save the user lands on that task's day; Añadir tarea is in the same place, so 1 tap to listen again. Undated tasks #2 and #3 take #1's day (UX-602). | 3 |
| 3a. Typing, free account at 0 left | 3 + typing | No AI; the sync on save remains | Sheet, then keyboard (two motions); a 17-word line every time (UX-609) | 1 |
| 3b. Offline, voice with dictations left | 3: Añadir tarea, Listo, Guardar tal cual (saves at once) | Fails at once in airplane mode; on a dead connection the slow line appears at 8 s | Saved with no review; parser gaps (UX-604) | 2 (read the error, choose a button) |
| 4. Widget or "Dictar una tarea" shortcut | Widget tap + 2 | Cold chain (UX-611), then path 1 | Launcher → splash → session screen → Calendar → sheet: 4 changes before listening | 1 |
| 5a. Correct a wrong day | +3 (date line, day, Listo), then save | Date sheet slides up and down | A second sheet | 1 |
| 5b. Correct a misheard word | +1 tap and typing | — | Keyboard | 1, with no cue that the title can be edited (UX-607) |

**Numbers (before → after the fixes below):**
- Taps for one spoken, dated task: 3 → 3. This is U4's target, unchanged.
- Avoidable waits on every capture: 2 → 0. These are the save's network sync (UX-601) and the per-open probe and capture sweep (UX-603).
- Taps to fix a day to Hoy, Mañana or Sin fecha: 3 → 2, plus the save.
- Undated tasks re-dated by a landing in a three-dictation burst: up to 2 → 0.
- Tap targets on a single spoken result: 8 → 7. They are the title, the date line, Notas, Más opciones, Añadir al calendario, Cancelar, Volver a decirlo and Ver lo que dije.
- Words in the used-up line (ES): 17 → 7.
- User-facing capture strings that say "borrador", "esborrany" or "draft": 6 → 0.

### Findings (most severe first)

**UX-601 · Severity 3 · Saving waits for a full server sync**
- **Where:**
  - `App/lib/screens/voice_task_screen.dart:2085`: `await notifier.loadTasks()` runs before the sheet closes at `:2105-2111`. Deshacer does the same at `:2161`.
  - `App/lib/providers/task_provider.dart:39-60`: `_loadLoop` awaits `_repository.sync()` at `:47`.
  - `App/lib/repositories/cloud_task_repository.dart:102-245`: the sync covers lists, one PUT per unsent task, every page of `tasks/?include_deleted=true`, then `attachments.sync`. That checksums and uploads queued files, with a 45 s timeout per file (`api_client.dart:556`).
  - State: the result, on every save from a signed-in account.
- **The moment:** "Guardando… ¿se ha colgado? Ni siquiera puedo volver atrás."
- **What happens:**
  - The task is already in the phone's database when `saveReady` returns (`:2066-2070`), but the sheet waits for the whole round trip.
  - Back is blocked meanwhile (`PopScope(canPop: !_saving)`, `:2323`), and Cancelar is disabled.
  - If a sync is already running (after a resume, or a completed task), `loadTasks` waits for it and then runs another.
  - The typed editor's `addTask` doesn't wait (`task_provider.dart:63-67`).
  - The "Confirmed to local save" timing stops before the sync, so the diagnostics never showed this wait.
  - Worst case: on a weak connection the sheet sits stuck. A newcomer kills the app, reopens it on today, can't see the Friday task, and adds it again.
- **Why it fails:**
  - Response-time limits (Miller 1968; Nielsen 1993): a local save should feel instant.
  - Visibility of system status (Nielsen 1994): "Guardando…" hides that the wait is the network.
  - User control and freedom: Back does nothing.
  - The owner's speed bar (DECISIONS 2026-10-13, late).
- **Fix:** subtract the wait.
  - After `saveReady`, read the phone's tasks once and set the list, with no network.
  - Then close the sheet and land, and start the sync without awaiting it.
  - Do the same in Deshacer. No copy change.
  - Saves one full sync per task: an estimated 0.5–3 s on a good connection. On a dead connection it's up to the 12 s request timeout, plus any queued file upload.
- **Verify:**
  - Widget test: with a repository whose `sync()` never completes, tap "Añadir al calendario". The sheet closes within a frame of the local save, the row lands lit, and Deshacer still restores it.
  - Phone: queue a photo upload on any task, then dictate and save on weak mobile data. The sheet closes at once.
- **Evidence:** verified in code. The duration is estimated and needs a phone.

**UX-602 · Severity 3 · A landing re-dates the next undated dictation**
- **Where:**
  - `App/lib/screens/calendar_screen.dart:114-124`: `_land` calls `_select(day)`.
  - `calendar_screen.dart:756`: `TaskActions(day: _selectedDay)`.
  - `voice_task_screen.dart:544-566`: the session keeps a later day.
  - `App/lib/services/capture_processor.dart:174, 243-248` and `local_capture.dart:72`: an undated result takes that day.
  - Flow: Calendar, several dictations in a row.
- **The moment:** "He dicho «comprar pan». ¿Por qué pone viernes?"
- **What happens:**
  - Dictation 1, "médico el viernes a las 5", saves. Calendar selects Friday to show it.
  - Dictation 2, "comprar pan", opens with `day: Friday`, so its undated result reads "vie, 17 oct". So does dictation 3, and the same happens when typing.
  - A fast user saves the bread on Friday. A careful one spends 3 taps fixing it (UX-608).
  - The timeline does the same: UX-466 sends Calendar to the saved day.
- **Why it fails:**
  - D9 means the day the person selected; here the app selected it as feedback.
  - "Nothing happens that the user didn't do" (UX_REVIEW §3.4).
  - Error prevention (Nielsen 1994).
  - It breaks "several in a row must stay just as fast."
- **Fix:**
  - Calendar passes a day to capture only when the person picked it, by tapping a day in the week strip or the month.
  - A landing still selects the day to show the task, but it doesn't count as a pick.
  - D9 stays as it is for days people pick. No copy change.
- **Verify:** widget test.
  - From Calendar on today, save "médico el viernes" (it lands on Friday). Then Añadir tarea and "comprar pan": the result reads "Sin fecha".
  - Then tap Friday, Añadir tarea and "comprar pan": the result reads "vie, 17 oct" (D9 kept).
- **Evidence:** verified in code.

**UX-603 · Severity 3 · The microphone opens late; first words can be lost**
- **Where:**
  - `voice_task_screen.dart:435-514`: `_load` runs before auto-start. It does three things first:
    - a speech capability probe on every open (`:446`);
    - a time-zone lookup;
    - `cleanFinished` (`:455`), which decodes every saved capture ever kept (`capture_store.dart:401-410`).
  - `voice_task_screen.dart:516-533` and `:760-836`: one frame, then a permission call, then `_speech.start`.
  - `NativeSpeechBridge.kt:122-143`: the probe builds and destroys a recognizer and waits up to 2.5 s; Dart waits up to 4 s (`native_speech.dart:53-57`).
  - `NativeSpeechBridge.kt:323-341`: the app's own microphone starts only inside `start`. "Words said before the recognizer is ready wait in the pipe" (`:339`) applies only from then on.
  - State: listening, on every open, including from the widget and the voice shortcut.
- **The moment:** "Toco y hablo enseguida… y en «Ver lo que dije» falta «mañana»."
- **What happens:**
  - The sheet appears in about 0.25 s and shows "Un momento…" until the recognizer reports ready.
  - Nothing said before `start` is recorded.
  - In Spanish the date often comes first ("Mañana llamar a Juan"), so a clipped start can lose the date.
  - "Volver a decirlo" skips `_load` and starts listening at once (`:1290`), which shows the wait isn't needed.
- **Why it fails:**
  - People act before they read (Carroll & Rosson 1987).
  - Listening must hear the person and show it (Budiu & Laubheimer 2018).
  - Response-time limits (Nielsen 1993).
- **Fix** (no new UI):
  1. Remember the capability per speech language for the app session. Probe again only after a Voz change, a language setup or a failed start.
  2. Run `cleanFinished` after listening starts, or once at app start.
  3. Start the microphone before anything else that can wait.
  4. On Android 13 and later, show "Escuchando" as soon as the app's own microphone feed is open (its words are kept), not at the recognizer's ready.
- **Verify:**
  - Phone, debug build, on Android 13+ and Android 12:
    - Clear Ajustes › Otros ajustes › Diagnóstico de captura, open capture 10 times, and read "Capture ready to use" p50 and p95.
    - Screen-record at 60 fps and count frames from the tap on Añadir tarea to "Escuchando". Target: 0.5 s or less, warm.
    - Tap and immediately say "mañana comprar pan". The task is dated tomorrow, and "Ver lo que dije" starts with "mañana".
  - Widget test: with a fake capability that takes 2 s, a second open calls `start` without waiting for it.
- **Evidence:** the order of the waits is verified in code. Their length and the lost words are inferred and need a phone.

**UX-604 · Severity 3 · Typed and saved-as-written dates miss common Spanish phrases**
- **Where:**
  - `App/lib/services/quick_schedule_parser.dart:49`: "mañana" always means tomorrow.
  - `quick_schedule_parser.dart:82-83`: two date words give no date at all.
  - `quick_schedule_parser.dart:64-65` and `:149-166`: a bare hour always asks a. m. or p. m.
  - Used by `local_capture.dart:96-119`, which serves:
    - free typing;
    - "Guardar tal cual" (`capture_processor.dart:131-156`), which saves at once when nothing is asked (`voice_task_screen.dart:1213`, `:1978-1985`).
  - No test covers these phrases (`test/quick_schedule_parser_test.dart`).
- **The moment:** "He escrito «mañana por la mañana» y pone «Sin fecha»."
- **What happens:**
  - "Llamar a mamá mañana por la mañana": no date.
  - "Médico el viernes por la mañana": no date.
  - "Llamar a Juan por la mañana": dated tomorrow, which is wrong, with the title "Llamar a Juan por la".
  - "Recoger el coche pasado mañana": dated tomorrow, which is wrong, with the title "Recoger el coche pasado". Catalan "demà passat" fails the same way.
  - "Médico el viernes a las 5 de la tarde": asks "¿A qué hora?" although "de la tarde" already answered it, and the title becomes "Médico de la tarde".
  - Offline or when the AI is slow, "Guardar tal cual" saves the first four at once, with no review.
  - The speech hints (`native_speech.dart:137-147`) push the recognizer towards exactly these phrases.
- **Why it fails:**
  - Error prevention and match with the real world (Nielsen 1994).
  - The interpretation must be right, or shown as a question (Budiu & Laubheimer 2018).
  - Free accounts type every task after their 10 dictations, so this is their everyday path. Each miss costs 3 taps to fix.
- **Fix** (parser only, no UI):
  1. "mañana" right after "la", "por la", "de la", "esta" or "cada" means the morning, not tomorrow.
  2. "pasado mañana", "demà passat" and "the day after tomorrow" mean two days from now.
  3. A part of the day next to a bare hour settles a. m. or p. m. and leaves the title:
     - a. m.: mañana, matí, morning;
     - p. m.: tarde, tarda, afternoon, noche, nit, vespre, evening, night, tonight.
  4. A part of the day with no hour stays in the title, and no time is set.
- **Verify:**
  - Parser tests for every phrase above, plus "tomorrow morning at 9" and "demà al matí a les 9".
  - Widget test without Pro: typed "Llamar a mamá mañana por la mañana" gives the date line "Mañana" and the title "Llamar a mamá por la mañana".
- **Evidence:** verified in code; no test covers these phrases.

**U5 (still open for one case) · Severity 2 · A dictation across days shows only the first day**
- **Where:**
  - `voice_task_screen.dart:2112-2132`: the landing focus is the earliest day.
  - `calendar_screen.dart:114-124, 316-321`: the no-date row lights up only when no saved task has a date.
  - `captureTasksAdded` reads "2 tareas añadidas" and names no days.
  - U5's ledger line says the two-day batch "lands as before".
- **The moment** (UX_REVIEW §7, task 3): "Recoger el coche el sábado por la mañana y pagar la luz." Calendar jumps to Saturday and the car is lit. "¿Y la luz?"
- **What happens:**
  - The undated bill goes into the no-date row at the foot of the page, unlit.
  - A task on another day is off-screen.
  - The message gives only a count.
- **Why it fails:**
  - Change blindness (Rensink, O'Regan & Clark 1997).
  - U5's acceptance: "the saved task is visible on screen and highlighted… every time".
  - The newcomer may add the task twice.
- **Fix:**
  1. When the saved tasks include an undated one, light the no-date row as well as the dated rows. It's on the same page, so nothing else moves.
  2. When dated tasks fall on more than one day, the message names the others after the count:
     - ES: "2 tareas añadidas · también el sáb, 18 oct", or "· también otros {n} días";
     - EN: "2 tasks added · also on Sat, 18 Oct", or "· also on {n} other days";
     - CA: "2 tasques afegides · també el {date}", or "· també {n} dies més" (needs a Catalan check).
- **Verify:** `capture_landing_test`:
  - Saturday plus a task with no date: it lands on Saturday, with both rows lit.
  - Friday plus Saturday: the message reads "también el sáb, 18 oct".
- **Evidence:** verified in code.

**UX-605 · Severity 2 · Cancelar on a result silently keeps it pending**
- **Where:**
  - `voice_task_screen.dart:2252-2259`: Cancelar calls `maybePop`.
  - `voice_task_screen.dart:1503-1506`: the closed result stays pending.
  - `task_actions.dart:28-46`: the "Capturas pendientes · N" link sits directly on top of Añadir tarea.
  - `voice_task_screen.dart:1372`: the question used while listening (`captureKeepQuestion`) also covers typed words.
- **The moment:** "Lo cancelo porque está mal y lo digo otra vez… ¿y qué es «Capturas pendientes · 1»?"
- **What happens:**
  - On the result, Cancelar, Back and a tap on the dimmed area close the sheet with no question and keep the result.
  - The link then sits flush on top of the main button.
  - Reopening the result and pressing Cancelar keeps it again. Discarding a single result takes Más opciones › Quitar de esta captura › Terminar: 4 hidden taps.
  - While listening, the same Cancelar asks "¿Conservar lo que has dicho?", even about typed words.
- **Why it fails:**
  - Consistency (Nielsen 1994): one button behaves two ways in one sheet.
  - U2's approved rule: "Cancel asks: keep or discard."
  - User control and freedom: a single result has no visible way to discard it.
- **Fix:**
  - Cancelar, Back and the dimmed area on the result ask the same question as while listening, worded so it fits typed words too:
    - ES "¿Quieres conservarlo para más tarde?", with [Descartar] [Conservar];
    - EN "Keep it for later?", with [Discard] [Keep];
    - CA "Ho vols conservar per a més tard?", with [Descarta] [Conserva].
  - Use the same wording while listening and typing.
  - Remove `captureKeepHelp` ("Podrás terminarlo más tarde."): the question now says it.
  - Descartar discards and closes; Conservar keeps it, as today. After "Volver a decirlo", Cancelar still goes back to the result without asking.
- **Verify:** `capture_result_exits_test`.
  - On a result, Cancelar asks the question. Descartar leaves nothing pending; Conservar keeps one capture.
  - A typed capture's question reads "¿Quieres conservarlo para más tarde?".
- **Evidence:** verified in code. Cancelar is visible in `review-direct-light.png`.

**UX-606 · Severity 2 · An empty Notas field sits on every result**
- **Where:** `App/lib/widgets/capture_review_editor.dart:452-470`, which is always shown when a card is open (`minLines: 2`). This covers the single result and opened batch cards.
- **The moment:** "¿Tengo que rellenar «Notas»?"
- **What happens:**
  - Short dictations ("comprar pan", "médico el viernes a las 5") have no notes.
  - Every single result still shows "Notas" over a two-line empty field, between the date and Más opciones. That's about 70 dp at 1×, and double at 2×.
  - Results typed without Pro almost never have notes.
- **Why it fails:**
  - Progressive disclosure (Nielsen 2006).
  - Cognitive load (Sweller 1988).
  - Hick–Hyman: one more thing to scan before deciding.
  - UX_REVIEW §3.2 shows notes only when there are some.
- **Fix:**
  - Show Notas only when the draft has notes.
  - When it's empty, "Añadir notas" becomes the first row inside Más opciones and opens the field with the keyboard up.
  - Tap targets on the result: 8 → 7.
- **Verify:**
  - `review_tasks_test`: a result without notes shows no "Notas", and Más opciones lists "Añadir notas". With notes, the field shows as today.
  - Add a preview of a direct result without notes.
- **Evidence:** verified in code. The current render has notes, so no render shows the empty case.

**UX-607 · Severity 2 · Nothing shows the title can be corrected by tapping**
- **Where:**
  - `capture_review_editor.dart:420-443`: the title field, drawn with `border: InputBorder.none` (`:435`).
  - `capture_review_editor.dart:452-470`: the notes field, also without a border (`:464`).
  - Seen in `App/build/review-direct-light.png` and `-dark.png`.
- **The moment:** "Ha entendido «Comprar pon». ¿Cómo lo arreglo? Lo diré otra vez."
- **What happens:**
  - The title is an editable field drawn as a heading with a small caption: no underline, no box, no icon. The date line has a chevron; the title has nothing.
  - A newcomer uses "Volver a decirlo" instead of fixing one word. That's slower, and for a free account it uses up one of the month's dictations.
- **Why it fails:**
  - Visible signifiers (Norman 2013).
  - Correcting by touch beats saying it again (Karat et al. 1999; Suhm, Myers & Waibel 2001).
  - This is brief path 5, the fastest correction.
- **Fix:**
  - Give the title and notes fields the theme's normal underline, in the `outline` colour UX-412 set (3.79:1 light, 4.85:1 dark).
  - Keep the label. No new control.
- **Verify:**
  - Re-render review-direct, light and dark: a line shows under the title.
  - Phone, §7 style: "it heard 'pon', make it 'pan'". The person taps the title.
- **Evidence:** seen in the current renders and the code. That newcomers miss it is inferred and needs a device check.

**UX-608 · Severity 2 · Fixing a day on the result takes three taps**
- **Where:** `App/lib/widgets/schedule_editor.dart:229-247`, opened from `capture_review_editor.dart:77-120`. Hoy, Mañana and Sin fecha apply at once only when moving a task (`:242`); on the capture result they only select.
- **The moment:** "Era mañana, no hoy." They tap the date, then Mañana, and nothing closes. Then Listo, then Añadir.
- **What happens:**
  - Fixing the day costs three taps (date line, chip, Listo) before the save.
  - "Cambiar fecha" on a saved task closes on the same chips (UX-206, UX-453), so one sheet behaves two ways.
- **Why it fails:**
  - Consistency (Nielsen 1994).
  - Correction by touch should be the fast path (Suhm, Myers & Waibel 2001).
- **Fix:**
  - On the capture result, Hoy, Mañana and Sin fecha apply and close at once, keeping the time, as when moving.
  - A day picked in the calendar, or a time, still ends with Listo.
  - Taps for these fixes: 3 → 2, plus the save. The edit form (area B) could follow.
- **Verify:** `review_tasks_test`.
  - On a result for Friday at 17:00, open the date and tap Mañana. The sheet closes, and the line reads "Mañana · 17:00".
  - Sin fecha gives "Sin fecha".
- **Evidence:** verified in code.

**UX-609 · Severity 2 · At 0 left, a 17-word line tops every typed task**
- **Where:**
  - `voice_task_screen.dart:1561-1567, 1691-1711`.
  - The `freeVoiceUsedUp` string in `app_en.arb`, `app_es.arb` and `app_ca.arb:875`.
  - State: the typing sheet of a free account at 0 left, on every open until the month resets, and after a refusal.
- **The moment:** "Ya lo sé…" At 2× text on a small phone, the line takes the room the field needs above the keyboard.
- **What happens:**
  - The ES line reads "Ya has usado los dictados gratis de este mes. Puedes escribirla aquí; tendrás más el 1 nov.", plus Ver Pro.
  - "escribirla" has nothing to refer to; UX-470 fixed the same slip elsewhere. EN "type it" has the same problem.
  - The field is already focused with the keyboard up, so "puedes escribirla aquí" adds nothing.
- **Why it fails:**
  - Banner blindness (Benway & Lane 1998).
  - Front-load the key words (Nielsen 2006).
  - Minimalist design (Nielsen 1994).
- **Fix:** one short line, with Ver Pro kept.
  - ES "Sin dictados gratis hasta el {date}."
  - EN "No free dictations until {date}."
  - CA "Fins al dia {date} no tens dictats gratuïts." The date stays mid-sentence, as UX-503 settled.
  - That's 17 → 7 words in Spanish. `freeVoiceUsedUpRecording` is unchanged, and "the app shows what's left" still holds.
- **Verify:** `capture_free_dictations_test` at 2× on 320 dp in ES, CA and EN. The line takes one or two lines, has no "..", and the field stays in view above the keyboard.
- **Evidence:** verified in code; no render covers this state.

**UX-610 · Severity 2 · Device check: the wait between Listo and the result**
- **Where:**
  - `voice_task_screen.dart:986-1008`: waits up to 4 s for the recognizer's last words (`:989`), then awaits a diagnostics write.
  - `capture_processor.dart:163-173, 265-291`: before the request, a read and a write. After the answer, a write and up to three awaited diagnostics writes (`:266`, `:288`) before the result shows.
- **The moment:** "He tocado Listo… Entendiendo… Entendiendo…"
- **What happens:**
  - Nothing measures the recognizer's finish: `_listeningWatch` stops at `:969`, before the wait.
  - The assistant itself took 1.3–4.8 s on staging, and once 20.5 s (UX_REVIEW header). That part is likely server-side.
- **Why it fails:** response-time limits (Miller 1968; Nielsen 1993). Each 100 ms on the phone adds to the longest wait in the flow.
- **Fix:**
  - Record capture diagnostics without awaiting them; `record` already swallows its own errors (`capture_diagnostics.dart:66-77`).
  - If the recognizer's finish takes more than about 1 s at the median, cap the wait at about 1.5 s and send the words on screen.
- **Verify:** phone, debug build.
  - Over 10 dictations, compare the p50 of "Request and retained drafts" with that of "Online task extraction" in Diagnóstico de captura. The gap is the phone plus the network.
  - Screen-record at 60 fps from the Listo tap to the result, on Android 13+ and Android 12. Target: the phone adds no more than 0.5 s beyond the server.
- **Evidence:** the steps are verified in code; their length needs a phone.

**UX-611 · Severity 2 · Device check: the widget and shortcuts after a cold start**
- **Where:**
  - `App/lib/main.dart:50`: start-up waits for the reminder setup (UX-424, still open).
  - `App/lib/providers/auth_provider.dart:76-82`: the session restore awaits `TaskReminders.activate`, which reconciles every reminder, before the account is set and Calendar can show.
  - `main.dart:128-195`: `_openEntries` runs only after that.
  - `voice_task_screen.dart:247-253`: for a free account at 0 left, an unlabelled spinner shows until billing answers. That can need the network at a cold start.
  - Then UX-603's chain.
- **The moment:** "He tocado el widget «Dictar una tarea»… ¿hablo ya?"
- **What happens:**
  - Widget → Android splash → reminder setup → session restore with the reminder reconcile → Calendar → sheet → UX-603's chain → "Escuchando". That's 4 screen changes before listening.
  - For a free account at 0 left, "Escribir una tarea" shows a spinner with no words.
- **Why it fails:**
  - Response-time limits (Nielsen 1993).
  - Visibility of system status (Nielsen 1994): an unlabelled spinner.
- **Fix** (in this order, after measuring):
  1. Fix UX-424.
  2. In `restore()`, set the account first and run the reminder activation without holding Calendar.
  3. For a saved account with 0 free dictations, open typing at once. An account that turns out to have Pro gets the mic on its next capture.
  4. Fix UX-603.
- **Verify:** phone.
  - Force-stop TaskFlow from the phone's app settings; no data is cleared.
  - Screen-record at 60 fps and count frames from the widget tap to "Escuchando", 5 times cold and 5 times warm.
  - Repeat for "Dictar una tarea", and for "Escribir una tarea" up to the keyboard.
  - Targets: 1 s or less warm, 3 s or less cold.
- **Evidence:** the causes are verified in code; their length needs a phone.

**UX-612 · Severity 2 · "Borrador" names the user's tasks in the batch and pending screens**
- **Where:**
  - Six used strings, all in `app_*.arb`: `reviewRemoved`, `reviewUndoSaved`, `captureRemovedDraftsHelp`, `capturesEmptyHelp`, `captureDraftSummary` and `captureWriteFailed`. EN says "draft", CA "esborrany".
  - Shown at `voice_task_screen.dart:2224, 2173, 2373` and `captures_screen.dart:28, 63`.
  - `reviewRemove` reads "Quitar de esta captura".
  - plan.md (b3, round 2) noted this as jargon but never filed it.
- **The moment:** after tapping ✕ on one of "2 cosas para añadir": "«Borrador retirado»… ¿qué borrador? ¿He borrado algo?"
- **What happens:** the header says "cosas", the button says "tareas" and the message says "Borrador". Capturas pendientes rows read "Tareas · 3 borradores · 2 listos".
- **Why it fails:** one concept, one name, and no internal terms (ISO 24495-1; the rule behind U11).
- **Fix:** exact copy, EN / ES / CA.
  - `reviewRemoved`: "Removed" / "Quitada" / "Treta".
  - `reviewUndoSaved`: "They're back here, not saved yet." / "Han vuelto aquí, sin guardar." / "Tornen a ser aquí, sense desar."
  - `captureRemovedDraftsHelp`: "Nothing will be added." / "No se añadirá nada." / "No s’afegirà res."
  - `capturesEmptyHelp`: "Recordings and tasks you leave unfinished are kept here." / "Aquí se guardan las grabaciones y las tareas que dejes a medias." / "Aquí es guarden les gravacions i les tasques que deixis a mig fer."
  - `captureDraftSummary`: "{count} not added yet" / "{count} sin añadir" / "{count} sense afegir", with ICU plurals.
    - This drops the "ready" count.
    - It also avoids Spanish "listas", which also means "lists".
  - `captureWriteFailed`: "Couldn't keep this on your phone. Try again before leaving." / "No se ha podido guardar en el teléfono. Inténtalo de nuevo antes de salir." / "No s’ha pogut conservar al telèfon. Torna-ho a provar abans de sortir."
  - `reviewRemove`: "Remove" / "Quitar" / "Treu".
- **Verify:**
  - Outside the debug-only diagnostics strings, no user-facing value contains "borrador", "esborrany" or "draft".
  - `review_tasks_test`: removing a batch card shows "Quitada · Deshacer".
- **Evidence:** verified in the ARB files and the code.

**UX-613 · Severity 1 · An opened batch card shows its title twice**
- **Where:** `capture_review_editor.dart:393-417` (the card's title in its header) and `:420-443` (the title field). Both show when a compact card is open.
- **The moment:** "¿Por qué sale dos veces?" It happens while correcting one task in a batch.
- **Fix:** when a batch card is open, its header keeps only ✕; the title lives in the field.
- **Verify:** `review_tasks_test`: open a batch card, and the title text appears once.
- **Evidence:** verified in code. plan.md (b3, round 2) noted it but never filed it. No render shows an opened card.

**UX-614 · Severity 1 · "Volver a decirlo" opens typing when no dictations are left**
- **Where:** `voice_task_screen.dart:2252-2280` shows the button on every spoken result, and `:1268` switches to typing when voice is gone.
- **The moment:** under "Ya no te quedan dictados gratis este mes", they tap "Volver a decirlo" and a keyboard appears.
- **Fix:** hide "Volver a decirlo" when there's no Pro and no free dictation left. Cancelar and touch corrections stay.
- **Verify:** `capture_free_dictations_test`: the result of the 10th dictation shows no "Volver a decirlo".
- **Evidence:** verified in code.

### Keep
- Three taps, always in one place. "Añadir tarea", "Listo" and "Añadir al calendario" are full-width filled buttons in the lower thumb zone, and nothing moves between them (renders: calendar and listening, result).
- Listening survives pauses, and the words show large and live. "Volver a decirlo" restarts in the same sheet with no setup.
- A burst of captures isn't interrupted. Opening capture hides the last Deshacer, and the reminder question waits for the save message to time out (`reminder_ask_sheet.dart:66-77`).
- "Guardar tal cual" saves at once with no extra confirmation, and a late answer can't change it.
- The date is the result's main line, a. m. or p. m. takes one chip, and one dictation with several tasks saves with a single "Añadir N tareas".

### Progress against UX_REVIEW.md (U1–U14)
- **Advanced:**
  - U2 and U3 are verified.
  - U1, U4, U6, U7, U8 and U9 are verified in code, with phone checks pending.
  - U4's three-tap acceptance holds in code.
- **Regressed:** nothing from a single change. UX-602 comes from U5's landing meeting D9.
- **Still open:**
  - U5, for a dictation across days or with an undated task (above).
  - U7 works, but its parser misses common Spanish phrases (UX-604).
  - U11: an undated save ends with three names for one place:
    - "Sin fecha" on the result;
    - "Tarea guardada en la bandeja de entrada" in the message;
    - "Bandeja · N" on the row;
    - "Capturas pendientes" is still shown too.
  - U12: P41 isn't built. Nothing teaches that one dictation can hold several tasks: 3 taps for three tasks instead of 9.
  - U10 and U13 wait on decisions.

### Questions for the owner (product decisions only)
1. **Should a result with no open question save itself, with Deshacer?**
   - This would take 2 taps instead of 3, saving about 1–2 s per task.
   - It changes D3/U4, which approved a confirmation tap. The risk is a misheard date saved without a look; the safety net would be the landing, Deshacer and the date in the message.
   - Recommendation: not before the §7 test with your father.
2. **Should the assistant's wait be cut on the server?**
   - It is typically about 5 s on staging (1.3, 4.8, 4.8, 4.8 and 20.5 s), now the largest single wait.
   - Only server work can cut it: a faster model, or understanding while the person is still speaking. It's a cost decision.
3. **Should the app teach that several things can be said at once?** One dictation gives three tasks in 3 taps; three dictations take 9. For example, P41's first-run line could teach it. Or should people find it on their own?

### Memory notes
- **Capture sheet, settled pattern:**
  - Listening shows a status line ("Un momento…", then "Escuchando · 00:0N"), large live words, a level ring that isn't a button, a full-width "Listo", and Cancelar with a keyboard icon.
  - The result appears in the same sheet. The date line is the main line, with a chevron. The title and notes are borderless fields. Más opciones is collapsed. The button reads "Añadir al calendario", "Añadir tarea" or "Añadir N tareas", with "Cancelar · Volver a decirlo" and "Ver lo que dije" below.
  - Feedback goes through `showFeedback`: floating, 4 s or Android's accessibility timeout.
  - Landing: Calendar selects the day, scrolls, and lights the row for 1.5 s. An all-undated save lights the no-date row.
- **Entry map:**
  - TaskActions on Calendar (passes `day`), Tareas and project pages (`page`), and the timeline (`day` and `page`).
  - The widget, both launcher shortcuts and share go MainActivity → CaptureEntryBridge → `main.dart` `_openEntries` → `showCaptureSheet`.
  - Capturas pendientes opens `showCaptureSheet(showCalendar: true)`.
- **Recurring problem types to check first:**
  - Awaited network or housekeeping between a tap and visible feedback: the sync on save, the per-open probe, diagnostics writes.
  - State the app moved, reused as if the user chose it: the landing day.
  - One shared sheet behaving differently by caller: the date sheet applies chips at once when moving, but only selects on the capture result.
  - Internal words leaking into copy: borrador, captura, bandeja.
  - The local parser's gaps with parts of the day.
- **Measuring hooks for device checks:** in a debug build, Diagnóstico de captura gives p50/p95 for "Capture ready to use", "First on-device words", "Request and retained drafts" and "Online task extraction". "Confirmed to local save" excludes the cloud sync.
- **Renders:** `App/build` PNGs from 14:11 on 2026-10-14 matched commit 8779bdb. No preview covers typing, the free-tier lines, the slow or failed states, or an opened batch card.
