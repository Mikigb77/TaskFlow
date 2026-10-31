## UX review — B: the first-run line now names two tasks (UX-617) — 2026-10-15

**Verdict:** Ship after fixes. The copy reads naturally in all three languages and fits at 2× on 320 dp. Three problems remain:
- The example a newcomer is asked to say puts its two tasks on different days on every day except Thursday, so after saving only one is on screen.
- When the assistant is slow or fails, the example turns into one task with no date.
- At the largest text, the new second task sits under the button.

A shorter example with both tasks on the same day fixes the first two, and costs no extra length.

**Evidence:**
- **Code.** The diff since `refs/ux-review/last` is 83b4b10: three ARB strings and one test.
  - First-run state: `calendar_screen.dart:688-703`.
  - Save and landing: `voice_task_screen.dart:2185-2234`.
  - How the phone understands words: `quick_schedule_parser.dart:94-216` and `local_capture.dart:96-120`.
- **Renders.** None shows the first-run state.
  - `calendar-feedback-*.png` and `calendar-es-1.3x-*.png` were written 2026-10-15 18:24, after the change, but they show days that already have tasks.
  - `review-batch-light.png` and `capture-listening-es-2x.png` (2026-10-14 23:00) are newer than the last change to `voice_task_screen.dart` (19:26), so they're current.
- **Text fit.** I modelled text widths with Manrope in Pillow, using the variable weight axis.
  - Calibrated on `calendar-es-1.3x-light.png`: "Agenda de hoy" is 179.8 dp modelled vs 177.5 dp of ink; "3 pendientes · 1 completada" is 205.2 vs 203.5.
  - Heights come from widget code. That render's measured bands: scroll area 88–650 dp, the Añadir tarea area 74 dp, the navigation bar 119 dp in the test harness (its view padding is 24/24).
  - Phone counts below assume a 32 dp status bar and a 24 dp gesture bar.
  - I modelled two kinds of text scaling: linear (what `flutter_test` does), and Android 14's non-linear 200 %, where 14 sp draws at 26 px, 16 sp at 28, 20 sp at 34 and 12 sp at 24.
- **Not run.** Flutter (UX-loop rule), any phone, and any AI call.

**Walked:** as the newcomer (Spanish, 1.3× and 2×, one hand) and the TalkBack user. The daily user never sees this line after their first task.

| Path | Taps | What the person sees at the end |
|---|---|---|
| 1. Spoken, new account (free with dictations left, or Pro), any day but Thursday | 3: Añadir tarea, Listo, Añadir 2 tareas; then the reminder question | Calendar on the bread's day with "Comprar pan" lit. The dentist, said first, is out of sight; the clues are "2 tareas añadidas · también el vie, 23 oct" and a 4 px dot (UX-701) |
| 1′. Same, on a Thursday | same | Both tasks on Friday, both lit. The only weekday on which UX-617's phone check can pass |
| 2. Spoken, the assistant slow (8 s) or failing | 3: Añadir tarea, Listo, Guardar tal cual, which saves at once | One task with no date, titled with the whole sentence: "Añadida sin fecha" (UX-701) |
| 3. Typed (no voice) | 3, plus typing, plus answering the hour | "¿A qué hora? 10:00 · 22:00" before the task can be added (UX-703) |
| 4. TalkBack | +1: "Empezar a hablar", by design (UX-109) | Reads the title, then the line. Nothing changed here |
| 5. Largest font, first launch, no scrolling | — | On 360–393 dp phones the line is partly or wholly under Añadir tarea (UX-702) |

**Numbers** (before the change → now → with the fixes):
- **Words in the line,** ES/EN/CA: 14/15/14 → 18/19/18 → 13/15/14.
- **Words to remember while speaking.** The listening sheet covers the line. ES: 8 → 12 → 7. Chunks: 2 → 4 → 3.
- **Lines at 2× on 320 dp,** ES/EN/CA: 4/4/5 → 5/5/6 → 4/4/5.
- **Days of the week on which both saved tasks are on screen:** — → 1 of 7 → 7 of 7.
- **What Guardar tal cual makes of the example:**
  - now: one task with no date, titled with the 12-word sentence;
  - with the fix: one task, "Llamar al dentista y comprar pan", dated tomorrow.
- **Lines of the instruction visible without scrolling,** at Android 14's largest font (ES / EN / CA):
  - 393×851: 3/3 · 3/3 · 2/3 → 3/4 · 3/4 · 2/4 → 3/3 · 3/3 · 4/4;
  - 360×780: 0/3 · 0/3 · 0/4 → 0/4 · 0/4 · 0/5 → 3/3 · 3/3 · 3/4.
- **Unchanged:** 3 taps add the example's two tasks; a new account's Calendar has 16 tap targets.

### Findings (most severe first)

**UX-701 · Severity 3 · Example lands on two days; fallback saves one undated task**
- **Where:**
  - The text: `calendarTrySaying` in `App/lib/l10n/app_es.arb:222`, `app_en.arb:313` and `app_ca.arb:201`, shown at `App/lib/screens/calendar_screen.dart:699-701`.
  - Where the flow ends:
    - the landing, `App/lib/screens/voice_task_screen.dart:2186-2234`;
    - Guardar tal cual, `App/lib/services/quick_schedule_parser.dart:106-107` with `App/lib/services/local_capture.dart:96-99`.
  - State: a new account's first dictation.
- **The moment:**
  - "He dicho el dentista y el pan… ¿dónde está lo del dentista?"
  - On the fallback: "¿Sin fecha? Pero si he dicho el viernes."
- **What happens:**
  - **Two days.** «el viernes» and «mañana» fall on the same day only on Thursdays. On the other six days the two tasks get two dates.
    - Calendar lands on the earliest day (`days.firstOrNull`, `voice_task_screen.dart:2229`). Except on Fridays, that's the bread's day, the task said second.
    - The dentist, said first, isn't on screen. Its only traces are "· también el vie, 23 oct" at the end of the message, and a 4 px dot when Friday is in the same week.
    - On a Friday, the model chooses between today, when 10:00 may already have passed, and next week.
    - The ledger's own phone check for UX-617 ("say the example; two tasks are saved and both are lit") can pass only on a Thursday, like today.
  - **The fallback.**
    - After 8 s, Guardar tal cual becomes the filled button (`:1175`, `:1714-1717`). After a failure it's the filled button under Reintentar.
    - The phone's parser gives up when it sees two date words (`dates.length > 1` returns null).
    - So the whole sentence becomes one task with no date, saved at once with no review (`_saveAtOnce`, `:1309`, `:2058-2063`): "Llamar al dentista el viernes a las 10 y comprar pan mañana" under Sin fecha, and the message "Añadida sin fecha".
    - The line promised two tasks; the person gets one, and it isn't on the calendar.
    - On 2026-10-15 the free model failed most calls (DECISIONS.md), so this path isn't rare. Cause partly server-side (UX-616).
  - **Memory and line breaks.**
    - The quote grew from 8 to 12 words, which the person must remember once the listening sheet covers the line.
    - At 1.3–2× on narrow screens, the time breaks across lines: "el viernes a / las 10".
  - **No real-model check.** Nothing records that this sentence went through the real model in any language. 140f5cc checked the owner's three-task example; 83b4b10 ran widget tests only.
- **Why it fails:**
  - Change blindness (Rensink, O'Regan & Clark 1997): the second task is off screen and named only in a message.
  - Peak–end (Kahneman et al. 1993): this is the first ending a newcomer ever sees.
  - Visibility of system status, and match with the real world (Nielsen 1994): the person said "el viernes" and sees "sin fecha".
  - Working memory (Cowan 2001).
- **Fix:** keep two tasks, as DECISIONS 2026-10-15 says, but put both on one day, with one date word and no time.
  - ES: Prueba: toca Añadir tarea y di «Mañana, llamar al dentista y comprar pan».
  - EN: Try it: tap Add a task and say “Tomorrow, call the dentist and buy bread.”
  - CA: Prova-ho: toca Afegeix una tasca i digues «Demà, trucar al dentista i comprar pa».
  - What changes:
    - both tasks land on tomorrow, and both are lit;
    - Guardar tal cual gives one sensible task, "Llamar al dentista y comprar pan", dated tomorrow, with no question;
    - 7 words in 3 chunks;
    - the line is back to its pre-change length: 4, 4 and 5 lines at 2× on 320 dp.
  - If a time must stay: «Mañana, llamar al dentista a las 10 y comprar pan» still keeps one day. But it costs a line at 2×, and Guardar tal cual then asks 10:00 or 22:00.
- **Verify:**
  - `calendar_feedback_test.dart:2385`, `:2438` and `:2446` carry the new strings, and `:2452-2455` (each language names its real button) still pass.
  - A unit test: `localDrafts` on each language's quoted example, captured on a Monday, gives one draft that is confirmed and dated Tuesday, titled "Llamar al dentista y comprar pan" / "Call the dentist and buy bread" / "Trucar al dentista i comprar pa".
  - A widget test: two results dated tomorrow, saved from a new account's Calendar, land on tomorrow with both rows lit and no "también el" in the message.
  - The main session, with the real model as in 140f5cc: each language's example gives two tasks dated tomorrow.
  - Phone: UX-617's check, on any day but Thursday.
- **Evidence:** verified in code: the landing, the message, the parser and the save-at-once. What the model answers is inferred; it needs the real-model check.

**UX-702 · Severity 2 · At the largest text, the example sits below the button**
- **Where:**
  - "Un momento de calma.": `App/lib/screens/calendar_screen.dart:657-670`;
  - the empty state: `:690-703`;
  - the 64 dp icon tile: `App/lib/widgets/app_components.dart:137-144`.
  - State: a new account's first launch, text at 1.8–2×, phones 360–393 dp wide.
- **The moment:** at 2× the newcomer sees a green tile, "¿Qué quieres recordar?", and "Prueba: toca Añadir tarea y di «Llamar al dentista…", cut off by the button. What to say, and that it can be two things, is under the button. They don't scroll.
- **What happens:**
  - Above the line sit the week card, "Agenda de hoy", "Un momento de calma.", a 64 dp tinted icon tile with 44 dp of gaps, and the title.
  - At Android 14's largest font on a 393×851 phone (modelled), the change pushed the end of the second task under the button: «pan mañana».
  - Catalan: «dentista divendres a les 10 i / comprar pa demà».
  - English: "tomorrow."
  - On 360×780 none of the line shows, before or after the change. At 1.3× it all fits, for example 3/3 lines at 390×844.
  - The U12 tests at 2× scroll to the end first (`calendar_feedback_test.dart:2545`). They prove nothing overflows, not that the line can be seen.
- **Why it fails:**
  - Attention sits at the top (Fessenden 2018), and the newcomer doesn't explore.
  - Older users are less tolerant of hidden UI (Nielsen 2013).
  - Cognitive load theory (Sweller 1988): decoration outranks the one instruction on the screen.
  - It undercuts U12's acceptance: "a new user creates their first task from the card's instruction alone".
- **Fix:** subtract, in the first-run state only.
  - Drop the icon tile and its 16 dp gap: 80 dp. EmptyState's `icon` becomes optional, and Calendar passes none here.
  - Drop the line under "Agenda de hoy" ("Un momento de calma." / "A little breathing room." / «Una mica d’espai per respirar.»): about 40 dp at 2×. The empty state below already speaks.
  - Keep "¿Qué quieres recordar?". No copy changes.
  - With UX-701's example, the whole line shows above Añadir tarea at Android 14's largest font (modelled):
    - on 393 dp phones, in all three languages;
    - on 360 dp phones, in ES and EN, and in CA all but «i comprar pa».
- **Verify:**
  - A widget test with Manrope loaded: 390×844, view padding 24/24, a new account, no scrolling, with UX-701's example (without it, the 2.0 check fails by about 8 dp in ES and EN). Check that `getRect(find.text(calendarTrySaying)).bottom <= getRect(find.byType(TaskActions)).top`:
    - at textScale 1.8, which is about what Android 14's largest font does to 14–16 sp text, in ES, EN and CA;
    - at 2.0, in ES and EN.
  - The 320×568 no-overflow tests stay.
  - Phone: Android 14 or later, the largest font, a phone about 390 dp wide, a new account. The whole line shows above Añadir tarea.
- **Evidence:** inferred from code and the Manrope model, which is accurate to about 2 dp in width. The harness's 119 dp navigation bar is measured from a render and may include a test artefact. Needs the widget test.

**UX-703 · Severity 1 · Typed first-run example always asks 10:00 or 22:00**
- Pre-existing since b10, not caused by this change. It's the same ternary as the changed line, and its fix mirrors UX-701.
- **Where:**
  - `calendarTryTyping`: `App/lib/l10n/app_es.arb:223`, `app_en.arb:317`, `app_ca.arb:202`;
  - the bare-hour rule: `App/lib/services/quick_schedule_parser.dart:195-216`;
  - the question: `App/lib/widgets/capture_review_editor.dart:174-195`.
  - State: a new account without voice, meaning no Pro and no known free dictations.
- **The moment:** "He escrito a las 10. ¿Por qué me pregunta si son las 22:00?"
- **What happens:**
  - The phone's parser treats a bare hour from 1 to 12 as ambiguous. So «…el viernes a las 10» always gets "¿A qué hora? 10:00 · 22:00".
  - The task can't be added until that's answered, because `ready` needs `confirmed`.
  - Spoken, the same words wouldn't ask (the 2026-10-15 bare-hour rule).
  - UX-468 chose "a las 17:00" for the typing hint to avoid exactly this.
- **Why it fails:** consistency (Nielsen 1994); the speed bar (DECISIONS 2026-10-13): every question costs a tap.
- **Fix:** one task, as decided, dated tomorrow, with no question.
  - ES: Prueba: toca Añadir tarea y escribe «Mañana, llamar al dentista».
  - EN: Try it: tap Add a task and type “Tomorrow, call the dentist.”
  - CA: Prova-ho: toca Afegeix una tasca i escriu «Demà, trucar al dentista».
- **Verify:**
  - `localDrafts` on each typed example gives a task dated tomorrow, confirmed, with no clarification.
  - `calendar_feedback_test.dart:2418`, `:2442` and `:2450` are updated.
- **Evidence:** verified in code.

### Seen outside area B (not reported as a finding)
- **Area A should look at this.** Any dictation that names two days and is saved with Guardar tal cual becomes one task with no date, titled with everything said (`quick_schedule_parser.dart:107`). Now that several tasks per dictation is a must, area A should check what the slow and failed states offer for such dictations.

### Keep
- The line names the real button in all three languages, and a test holds it to that (`calendar_feedback_test.dart:2452-2455`).
- It shows only until the account's first task or note. The flag is per account and survives restarts and deletions, so the teaching never nags.
- Before anything is saved, the result says how many things it heard: "2 cosas para añadir", "Añadir 2 tareas" (`review-batch-light.png`). That's the right moment to learn that one dictation can hold several tasks.
- Each language reads naturally («Prueba…», "Try it…", «Prova-ho…»), and nothing overflows at 2× on 320 dp (tests at `:2526-2557`).
- The spoken or typed wording follows what Añadir tarea will actually open (`voiceAvailableProvider`, `calendar_screen.dart:699`).

### Progress against UX_REVIEW.md (U1–U14)
- **U12, advanced:** the first-run line now shows several things in one go. It still isn't seen without scrolling at the largest text on phones up to 393 dp (UX-702).
- **U5, still open for this case:** saving the example shows one of its two tasks on six days of the week (UX-701). U5's own code is unchanged.
- **U7, still open for this case:** Guardar tal cual can't split the example and drops its dates (UX-701).
- **U10:** unchanged (16 targets). The other items weren't touched.

### Questions for the owner (product decisions only)
- **UX-701 changes the example's words, not its two tasks.** If you chose «Llamar al dentista el viernes a las 10 y comprar pan mañana» word for word, the change is your call.
  - For keeping it: two days and a time show more of what the app understands.
  - Against: on six days of the week only one task is on screen after saving, and when the assistant is slow it becomes one task with no date.

### Memory notes
- **The Calendar's first-run state** (U12, UX-617) is EmptyState inside the scroll view, under:
  - the week card;
  - "Agenda de hoy";
  - the `breathingRoom` line;
  - a 64 dp icon tile;
  - the title.

  The line is grey 14 sp text, centred. The U12 tests at 2× scroll first, so a "visible on first look" check needs a no-scroll assertion against the top of `TaskActions`.
- **Phone-side rules any example or hint must respect** (the typed path and Guardar tal cual):
  - two date words → no parse → one task with no date, titled with the whole text (`quick_schedule_parser.dart:107`);
  - a bare hour from 1 to 12 asks a. m. or p. m. (`:195-216`);
  - Guardar tal cual saves at once when there's nothing to ask.
- **Saving several tasks:**
  - Calendar lands on the earliest day;
  - tasks on other days appear only in the message ("· también el {date}" / "también en otros N días");
  - several tasks on one day get "N tareas añadidas", which names no day.

  Teaching examples should keep all their tasks on one day.
- **Measured** in `calendar-es-1.3x` (390×844, view padding 24/24): app bar to 88 dp; week card 88–238 dp at 1.3×; scroll area ends at 650 dp; the Añadir tarea area is 74 dp; the navigation bar is 119 dp.
- **Text scaling:** Android 14's non-linear 200 % draws 14 sp at 26 px, 16 at 28, 20 at 34 and 12 at 24. `flutter_test` scales linearly; textScale 1.8 approximates the real largest font for 14–16 sp text.
- **Possible recurring problem:** teaching copy written for the happy path that the fallback can't honour (this example vs Guardar tal cual; UX-468 was the same kind of problem in the typing hint).
