## UX web review — F: claims touched by the app's changes since 2026-10-22 01:44 (reminder plans, bulk-command D1–D4, the overdue search fix) — 2026-10-22

**Verdict:** Ship after fixes. Since reminder plans (aa2f53a), two lines are no longer true:
- the privacy policy says "The task form never sends anything to the AI", but a Pro user's reminder sheet, opened from the form, now sends their words to Google's AI;
- the calendar card says TaskFlow "asks you once" about reminders, but with reminders on it now also offers a plan for each task two weeks or more away.

Everything else the site says about reminders, free and Pro, and what goes to Google is still true.

**Walked:**
- **J1 — Newcomer, Spanish, phone 390 × 664, light and dark, from a WhatsApp link.**
  - /es/ → hero («…y puede avisarte antes», line 4 of the description) → «Qué hace» (1 tap) → the «Tu día en un calendario» card, about 4 phone screens down: «TaskFlow puede recordarte las tareas con fecha: te lo pregunta una sola vez.»
  - In the app afterwards: first dated save → «¿Quieres un recordatorio antes?» → «Sí, recuérdamelo». Weeks later she saves a task 3 weeks ahead → «Faltan 3 semanas: ¿te lo recuerdo hasta entonces?». The next far-off task gets the same question.
  - 2 steps on the site. The claim breaks at the app's second question (WEB-1102).
- **J2 — Comparer, English, desktop 1440 × 1000 and phone.**
  - Home → "Questions" (header, 1 click) → "Is TaskFlow free?" (1 click) → the Pro list.
  - Compared with the app's Pro screen summary (`billingIntro`), which reminder plans left unchanged: it matches.
  - Reminders described in your own words, the new Pro feature, aren't listed: that's WD21, not a finding.
  - The closing card's plans line and the line under the demo are unchanged and true.
- **J3 — wary Newcomer and Leaver, Spanish and Catalan, phone and desktop.**
  - Any page → footer «Privacidad» (1 tap) → summary 02. On the phone it's at the bottom of the first screen; on desktop it's the centre card, above the fold. Still true.
  - → §4, about 9–10 phone screens down (one contents link on desktop): «El formulario de tareas nunca envía nada a la IA.»
  - As a Pro user, the form's reminder row → «A tu manera» → the typed words go to Google (WEB-1101).
- **J4 — Comparer, Catalan, phone.** /ca/ → «Preguntes» → «Com afegeixo tasques parlant?» (1 tap). The voice answer and the voice card, read against D1–D4 and «atrasat», contradict nothing.
- **Evidence and freshness:**
  - No website file has changed since the last web review (`ux-web.sh changed` is empty; last content commit c7cc3b4, 01:44). The renders and `AUDIT.md` (10:19–10:31 UTC today) are current.
  - The copy findings don't depend on theme or viewport. I read them in code, and in crops of the current renders: `crops/home.es.mobile.light.full.s4-5.png` and `crops/privacy.es.mobile.light.full.s9-11.png`.
  - The FAQ answers are closed in every render (`home-faq.*` opens item 1 only), so the free/Pro and voice answers were read in code.
  - The app side was read in code at dev HEAD 8b889d9, which includes aa2f53a and 7105ae9. The app's own /ux run on reminder plans (`.claude/ux-review/runs/2026-10-22-changes/`) is in progress. I quote no sheet wording from it.

**Numbers:**

| What | Before | After the fixes |
|---|---|---|
| Claims checked | 28 (home 16, legal 12) | — |
| False today | 1 (WEB-1101) | 0 |
| Outdated | 1 (WEB-1102) | 0 |
| Incomplete, for the owner | 1 (the Pro list, WD21) | — |
| Calendar card (EN): words | 31 | 27 (36 with WD20) |
| Privacy §4's sentence about the form (EN): words | 9 | 11 |
| Home → the reminder claim, phone | 1 tap + about 4 screens | — |
| Any page → privacy §4, phone | 1 tap + about 9 screens of scrolling | — |

No site file changed, so these stand as in the last review (home, EN, phone):
- the first viewport holds about 65 words, 1 primary call to action and 1 secondary link;
- the first call to action and the honest "not yet" line need 0 scrolls;
- any page → account deletion is 1 step.

**Attention.** These are predicted from the current fold renders with GUIDELINES §21 step 4, not measured eye-tracking. The renders are unchanged since the last review.
- **Home, phone** (`home.es.mobile.light.fold.png`):
  - Fixations: 1. the H1 «Dilo y ya está en tu calendario.»; 2. the filled «Pruébalo con tu voz» (y ≈ 366–416 of 664); 3. the quote card in the bottom third.
  - Competing: the Menú pill, «Qué hace» and the status line.
  - The hero's reminder promise sits in line 4 of the description, which few scanners reach. The calendar card's sentence (WEB-1102) is about 4 screens down.
- **Home, desktop** (`home.en.desktop.light.fold.png`):
  - Fixations: 1. the H1 (top left); 2. the filled call to action; 3. the phone screenshot (right third, first looked at after about 2–3 s).
  - Competing: the quote card, the header links and the language pills.
- **Privacy, phone** (`privacy.es.mobile.light.fold.png`):
  - Fixations: 1. the H1; 2. the ringed «Español» pill and the back link; 3. summary 01.
  - Summary 02 starts at y ≈ 558, so it's seen after one short scroll. §4 (WEB-1101) is reached only by those who look for it: the wary reader and the Leaver.
- **Privacy, desktop** (`privacy.en.desktop.light.fold.png`):
  - Fixations: 1. the H1; 2. summary 01; 3. summary 02 (centre card, above the fold).
  - Competing: the two language switches, "Delete account" and "Email support", and the "On this page" list, whose item 4 leads to §4.

### Findings (most severe first)

**WEB-1101 · Severity 3 · Privacy promises the task form never reaches Google's AI**
- **Where:**
  - `src/content/legal/en.ts:55`, `es.ts:55`, `ca.ts:55`: privacy §4 "Voice, AI and sensitive information", the last sentence of the first paragraph.
  - Pages: /privacy/, /es/privacy/ and /ca/privacy/, at every viewport and theme.
  - Seen in `privacy.es.mobile.light.full.png`, screens 9–11 (crop `artifacts/ux-web/crops/privacy.es.mobile.light.full.s9-11.png`).
  - Area: F (faithfulness). The line is legal copy (L).
- **The moment:**
  - A wary person, now on Pro, thinks: «Para lo privado uso el formulario: ahí nada va a la IA.»
  - She then opens the task's reminder row and types «cada 3 días y la última semana a diario» under «A tu manera». Those words go to Google's AI.
- **What happens:**
  - The page says:
    - EN: "With Pro, words you type for the AI are sent the same way. The task form never sends anything to the AI."
    - ES: «Con Pro, lo que escribes para la IA se envía igual. El formulario de tareas nunca envía nada a la IA.»
    - CA: «Amb Pro, el que escrius per a la IA s’envia igual. El formulari de tasques no envia mai res a la IA.»
  - Since aa2f53a (2026-10-22), the task form opens a reminder sheet that can send words to Google's AI:
    - the form, new and edit, is `TaskEditor` (`App/lib/screens/edit_task_screen.dart:36, 181`);
    - its reminder row (`App/lib/widgets/task_editor.dart:977, 993, 1270`) opens the plan sheet (`App/lib/widgets/reminder_control.dart:318-320`);
    - for Pro, the sheet's «A tu manera» row (`App/lib/widgets/reminder_plan_sheet.dart:465-476`) posts the typed or said words to `POST /api/ai/reminder-plan/` (`:201-229`), with the task's day, the time zone, the reference time and the language;
    - the server reads them with Google's model, through the same Gemini API / Vertex AI route as dictation (`Backend/core/views.py:180-206`; `Backend/core/ai.py:426-430, 645-676`).
  - Contract: `Backend/docs/REMINDER_PLANS.md:11, 65, 76-91`. Owner decision: `.claude/ux-review/DECISIONS.md:11`.
  - Free accounts see a Pro badge that opens the Pro screen, and no AI call is made (`reminder_plan_sheet.dart:471-476`; the server answers 402, `views.py:191-195`). So the sentence is still true without Pro.
  - The rest still holds:
    - speech in that field is recognised only on the phone (`reminder_plan_sheet.dart:281-293`), so "only the words are sent" stays true;
    - summary 02's "to add, find or change tasks" covers setting a task's reminders. The app's own `capturePrivacy` now uses the same three verbs (`App/lib/l10n/app_en.arb:523`, `app_es.arb:306`, `app_ca.arb:285`).
- **Why it fails:**
  - PV-1: the privacy page states plainly and accurately when words go to the AI provider (GDPR art. 12; WP260 2018).
  - FN-1: every claim true today (UCPD art. 6; Play Deceptive).
  - TR-3: errors are trust bugs.
- **Why S3:**
  - Higher than WEB-1002 (S2):
    - this is an absolute "never" about a third party, broken by every use of a Pro feature;
    - the reminder sheet itself doesn't say the words go to Google (`reminderPlanYourWayHint`, `app_en.arb`), so this page is the only disclosure, and it says the opposite.
  - Lower than S4:
    - only Pro accounts are affected, and Pro isn't sold yet (test purchases);
    - what goes is a rhythm the person typed for the assistant: the model never gets the task's title or notes (`ai.py:645-676`).
- **Fix:** narrow the sentence. That's two words more in each language; leave the rest of §4 as it is.
  - EN: "The task form never sends anything to the AI." → "Without Pro, the task form never sends anything to the AI."
  - ES: «El formulario de tareas nunca envía nada a la IA.» → «Sin Pro, el formulario de tareas nunca envía nada a la IA.»
  - CA: «El formulari de tasques no envia mai res a la IA.» → «Sense Pro, el formulari de tasques no envia mai res a la IA.» Needs a native Catalan read.
  - The sentence before it, "With Pro, words you type for the AI are sent the same way", then covers the reminder words.
  - Don't name «A tu manera»: the app's /ux run 2026-10-22-changes may still rename it.
  - Rejected:
    - deleting the sentence: it would be true, but it drops a still-true reassurance for free accounts, the majority;
    - naming the reminder field: about 19 more words in a 120-word paragraph, and it would quote wording that's under review.
  - A legal edit moves these together:
    - the version in `src/content/legal/company.json:10`;
    - the date in `docs/LEGAL_RELEASE.md:3`;
    - the pinned dates at `tests/legal.spec.ts:35` and `tests/ux-web-legal.spec.ts:673-680`.
  - The new "In force since" date is the owner's to sign off (WD3).
- **Verify:**
  - A test pins the three new sentences, as `tests/ux-web-legal.spec.ts:1459` pins §4's "only the words are sent".
  - A grep of `src/content/legal/` finds no sentence beginning "The task form never", «El formulario de tareas nunca» or «El formulari de tasques no envia mai».
  - Both legal specs pass with the new date.
  - The privacy renders show §4 with nothing scrolling sideways at 320 px.
- **Evidence:** verified in code (site, app and backend), and seen in the current render. This isn't legal advice.

**WEB-1102 · Severity 2 · Calendar card says it asks once; plans ask again**
- **Where:**
  - `src/content/site/en.ts:61`, `es.ts:61`, `ca.ts:61`: home, "What TaskFlow does", the "Your day on one calendar" card, at every viewport and theme.
  - On the phone it's about 4 screens down: `home.es.mobile.light.full.png`, screens 4–5 (crop `artifacts/ux-web/crops/home.es.mobile.light.full.s4-5.png`).
  - Pinned by `tests/support/ux-web-copy.ts:48-50` and `CALENDAR_BODY` (`tests/ux-web-features.spec.ts:659-663`, WEB-1003's test at `:749`).
  - It's the clause WEB-1003 wrote (device-check). Once this lands, WEB-1003's pending Catalan read of «t’ho pregunta una sola vegada» is moot.
- **The moment:** a Newcomer reads «te lo pregunta una sola vez» and thinks "it won't pester me". Weeks later, her second far-off task gets «Faltan 3 semanas: ¿te lo recuerdo hasta entonces?»: «¿No decía que solo me lo preguntaba una vez?»
- **What happens:**
  - The card says:
    - EN: "TaskFlow can remind you of tasks with a date: it asks you once."
    - ES: «…te lo pregunta una sola vez.»
    - CA: «…t’ho pregunta una sola vegada.»
  - The one-time question is still once per account on the phone (`App/lib/widgets/reminder_ask_sheet.dart:28-36, 124-126`).
  - Since aa2f53a, with reminders on, the app also offers a plan, «Faltan N semanas: ¿te lo recuerdo hasta entonces?», after each saved task whose deadline (else day) is 14 or more days away and has no plan. That's once per task (`reminder_ask_sheet.dart:38-40, 118-123, 172-218`; `App/lib/services/reminder_plans.dart:26, 105-110`).
  - Contract: `Backend/docs/REMINDER_PLANS.md:66`. Owner decision: `.claude/ux-review/DECISIONS.md:12`.
  - So "once" stays true only for people who said no to reminders.
- **Why it fails:**
  - FN-1: true today, in these words (UCPD art. 6).
  - RD-2: the fix removes words.
- **Fix:** cut the clause.
  - EN: "TaskFlow can remind you of tasks with a date."
  - ES: «TaskFlow puede recordarte las tareas con fecha.»
  - CA: «TaskFlow et pot recordar les tasques amb data.» These words are already on the page, so there's no new Catalan.
  - Add "it asks you once", «te lo pregunta una sola vez» and «t’ho pregunta una sola vegada» to the wording that mustn't return (`OLD_CALENDAR`, `tests/ux-web-features.spec.ts:699`).
  - If the owner says yes to WD20, its clause replaces this one instead.
- **Verify:**
  - `tests/support/ux-web-copy.ts:48-50` and `CALENDAR_BODY` are updated; WEB-1003's test (`:749`) is renamed and passes.
  - WEB-705's tests still pass (`:301`, `:355`: no feature card more than a quarter empty at 1440 px, zoomed or at doubled text). The calendar drawing grows to the card's bottom edge since WEB-1004 (`src/styles/global.css:596-603`).
- **Evidence:** verified in code, on the site and in the app, and seen in the current render.

### Claims checked
English lines are cited; the Spanish and Catalan lines sit on the same or neighbouring lines and were checked too.

| Claim (page, `path:line`) | Source of truth (`path:line`) | Status |
|---|---|---|
| Hero: "puts each one on its day and can remind you before it" (`src/content/site/en.ts:49`) | `Backend/docs/REMINDER_PLANS.md:3, 55-58`; `.claude/ux-review/DECISIONS.md:5-13` | true |
| Calendar card: "can remind you of tasks with a date" (`en.ts:61`) | `App/lib/services/reminder_plans.dart:29-34` (a plan needs a deadline or a day); `REMINDER_PLANS.md:17` | true |
| Calendar card: "it asks you once" (`en.ts:61`) | `App/lib/widgets/reminder_ask_sheet.dart:28-40, 118-123, 172-218`; `reminder_plans.dart:26, 105-110`; `REMINDER_PLANS.md:66` | outdated (WEB-1102) |
| Voice card: one task for each thing said, with day and time (`en.ts:71`) | `REMINDER_PLANS.md:3` (a plan is never a copy of the task), `:69-74` (a said rhythm goes on the drafted task) | true |
| Voice card: move all of yesterday's to tomorrow, complete many (`en.ts:71`) | `Backend/docs/VOICE_COMMANDS.md:209`; `DECISIONS.md:16-26` (D1–D4) | true |
| FAQ free: 10 dictations a month; a short form with no limit (`en.ts:94`) | `DECISIONS.md:150-160`; `REMINDER_PLANS.md:9` (strengths are worked out on the phone, for everyone) | true |
| FAQ free: Pro gives unlimited dictation and file space (`en.ts:94`) | `App/lib/l10n/app_en.arb:1977` (`billingIntro`, unchanged; `app_es.arb:1091`, `app_ca.arb:795`) | true |
| FAQ free: "a safety limit of 50 dictations a day" (`en.ts:94`) | `Backend/config/settings.py:141`; `Backend/core/views.py:96-110, 197`. Reminder reads share the same 50-a-day budget, so 50 is an upper bound. | true (WD14's wording) |
| FAQ free: Pro "also turns sentences you type into tasks" (`en.ts:94`) | `DECISIONS.md:160` | true |
| FAQ free: the Pro list leaves out reminders in your own words (`en.ts:94`) | `REMINDER_PLANS.md:11`; `DECISIONS.md:11` | incomplete; owner question WD21 |
| FAQ voice: Done → one task for each, with day and time; add them all (`en.ts:104`) | unchanged since the last review | true |
| FAQ voice: move, change, complete or delete, "even all of yesterday's at once"; shown first; undo (`en.ts:104`) | `VOICE_COMMANDS.md:209`; `DECISIONS.md:16-26`. D1 (a deadline-only task moves its deadline), D3 (the day chip) and D4 («hoy» counts overdue tasks from today) refine it and contradict nothing. | true |
| FAQ voice: "It needs the internet: your words are sent to Google." (`en.ts:104`) | `Backend/core/ai.py:426-430` | true |
| FAQ offline: "understanding what you say … need[s] a connection" (`en.ts:109`) | `REMINDER_PLANS.md:65` (reading a rhythm needs a connection; strengths work offline) | true |
| Closing plans line (`en.ts:133`) | `app_en.arb:1977` | true |
| Demo `textPro`: typed sentences to tasks is Pro (`en.ts:176`) | `DECISIONS.md:150-160` | true |
| Privacy summary 02: "to add, find or change tasks" (`src/content/legal/en.ts:10`) | `app_en.arb:523` (`capturePrivacy`, the same three verbs since aa2f53a); `REMINDER_PLANS.md:11` | true. Setting a task's reminders is a change to that task. |
| Privacy §2: text submitted, suggested tasks and changes, language, time zone, reference date (`legal en.ts:33`) | `App/lib/widgets/reminder_plan_sheet.dart:213-229` | true. The task's own day travels as §4's "relevant context". |
| Privacy §3: the AI suggests titles, dates and priorities for your review (`legal en.ts:48`) | `reminder_plan_sheet.dart` (a preview, then «Listo», before a plan applies) | true in substance; the list is short, left as is |
| Privacy §4: speech recognised on the phone, so only the words are sent (`legal en.ts:55`) | `reminder_plan_sheet.dart:281-293` (it listens only with the phone's recogniser, else asks you to type) | true |
| Privacy §4: "With Pro, words you type for the AI are sent the same way." (`legal en.ts:55`) | `reminder_plan_sheet.dart:201-229`; `views.py:191-195` | true |
| Privacy §4: "The task form never sends anything to the AI." (`legal en.ts:55`) | `task_editor.dart:977, 993, 1270` → `reminder_control.dart:318-320` → `reminder_plan_sheet.dart:201-229, 465-476`; `views.py:180-206` | false for Pro since aa2f53a (WEB-1101) |
| Privacy §4: Google processes text and context; Gemini API, Vertex AI fallback (`legal en.ts:56`) | `ai.py:401-430` (the reminder read uses the same route) | true |
| Privacy §4: "You can use manual task entry instead of AI." (`legal en.ts:58`) | `REMINDER_PLANS.md:9` | true |
| Privacy §9: notifications for reminders (`legal en.ts:155`) | `App/lib/services/notification_service.dart` (aa2f53a) | true |
| Terms §3: reminders; delivery depends on the phone (`legal en.ts:221-222`) | `REMINDER_PLANS.md:57` (the phone schedules the next few) | true |
| Terms §5: AI is optional; check its output before saving (`legal en.ts:239`) | `reminder_plan_sheet.dart` (preview, «Listo») | true |
| Delete account §3: tasks and notification settings deleted (`legal en.ts:373`) | `Backend/core/models.py:219` (the plan is a task field) | true |

### Missing from the site (app features worth telling)
1. **Reminders that come more and more often as a task's day approaches.** They're free, need no AI, and work offline.
   - Sources: `.claude/ux-review/DECISIONS.md:5-13`; `Backend/docs/REMINDER_PLANS.md:3, 9, 42-48`.
   - Where it belongs: the calendar card's reminder sentence, in place of the clause WEB-1102 cuts. That's WD20.
2. **Saying the rhythm while dictating** («…recuérdamelo cada 3 días»). It's free too.
   - Source: `REMINDER_PLANS.md:10, 69-74`.
   - Where it would belong: the FAQ's voice answer.
   - Recommendation: not now. The live demo has no idea of reminders (`src/lib/voice/model.ts:53`), so a visitor who tries it would see nothing about them and use up a try (WEB-1001's reasoning).
3. **Reminders in your own words, with Pro.**
   - Source: `REMINDER_PLANS.md:11, 76-91`.
   - Where it would belong: the FAQ's Pro list. That's WD21; recommendation: not now.

### Keep (5 bullets at most)
- **Privacy summary 02, «para añadir, buscar o cambiar tareas».**
  - The app now says exactly this in all three languages (`capturePrivacy`, `app_en.arb:523`).
  - It covers reminders read by the AI. The app's own reviewers read it the same way (`.claude/ux-review/runs/2026-10-22-changes/review-A.md:260`, `review-B.md:368`).
- **The Pro line, "unlimited dictation and file space"** (FAQ, closing card, under the demo). It still mirrors the app's Pro screen summary, which reminder plans left as it was (`billingIntro`).
- **"TaskFlow shows the change first, and you can undo it."** Still exact after D1–D4: the «Atrasada» rows, the day chip and «Deshacer».
- **The hero's short "can remind you before it".** Leave plans out of the hero: the core loop comes first (HE-11).
- **"a short form, with no limit".** It's truer than before: free accounts can now set reminder plans in the form, with no AI and no limit.

### Questions for the owner (product decisions only)
WD numbers are suggestions; the organizer's plan numbers them.

**WD20 — Tell the until-the-day reminders on the calendar card?**
- **The copy:** one clause, in place of the "asks you once" that WEB-1102 cuts:
  - EN: "TaskFlow can remind you of tasks with a date, more and more often as the day gets closer."
  - ES: «TaskFlow puede recordarte las tareas con fecha, cada vez más a menudo según se acerca el día.»
  - CA: «TaskFlow et pot recordar les tasques amb data, cada cop més sovint a mesura que s’acosta el dia.» «Cada cop més sovint» is the app's phrase (`app_ca.arb:1081`); needs a native Catalan read.
- **For:**
  - it's free, needs no AI, and is true today;
  - it's the owner's own reason for the feature, a project three weeks away (lens B: desire);
  - it sharpens an existing sentence rather than adding one. The card goes 31 → 36 words (EN), and the sentence is 18 words.
- **Against:**
  - the app's /ux run is still reviewing the sheet: the row's name, how many notices a far task gets, and what the offer's «Sí» replaces;
  - the live demo can't show reminders.
- **Recommendation:** yes, on the card only, without quoting any sheet label. Not in the hero (HE-11), and not in the voice answer (see "Missing" 2).

**WD21 — Add "reminders in your own words" to the FAQ's Pro list?**
- **For:** it's Pro's newest feature, and a Comparer might value it.
- **Against:**
  - FN-6: the app's Pro screen still sums Pro up as "Unlimited dictations, and room for all your files." (`billingIntro`), which the site mirrors;
  - the free answer is already 80 words (EN), second only to the voice answer's 85, and its Pro sentence runs to 38 words;
  - the feature's name is under app review (`review-B.md`, B-Q1; `review-D.md`, UX-2007);
  - the demo can't show it.
- **Recommendation:** not now. Revisit when the price is set, or when the Pro screen's summary changes.

**Owner checks** (not decisions, not findings):
- **A spoken rhythm in the live demo.** On /es/, try «Presentar el proyecto en 3 semanas, recuérdamelo cada 3 días».
  - The demo's own prompt knows only notes («Recurrence can be described in notes», `src/lib/voice/model.ts:53`). The rhythm may therefore appear as a note, or as a second «Recordar…» task.
  - In the app, it becomes a reminder on the one task. A second task would show the visitor something the app doesn't do (FN-4).
  - The cause is likely server-side, and only the real AI can tell.
- **The new legal version.** If WEB-1101 is fixed, sign off its "In force since" date (WD3).

**Outside area F** (notes for the organizer and the app's /ux, not findings):
- **App side:** the «A tu manera» field never says the words go to Google. A Pro user who first uses the microphone there never sees capture's one-time privacy line (`review-B.md:368`). That's for /ux.
- **Considered, not reported:**
  - privacy §3's short list of what the AI suggests, which now also includes reminder rhythms;
  - §2's "reference date" for the task's own day, which §4's "relevant context" covers;
  - terms §3 in English ("optional dictation that turns what you say into tasks") against «IA opcional» in Spanish and Catalan. It's older than this change; leave it for the next legal edit.
  - AUDIT §6's 14 px «Per exemple, digues:» on /ca/: a label, in area H, unchanged by this run.

### Memory notes
- **Claims map: reminder plans (2026-10-22).**
  - The hero (`en.ts:49`) and the calendar card (`en.ts:61`) are the site's only reminder claims; legal adds privacy §9 and terms §3.
  - Privacy §4's form sentence (`legal en.ts:55`) depends on every AI path the task form can open: today, «A tu manera» in the reminder sheet (`reminder_plan_sheet.dart:201-229`).
  - Summary 02 ↔ the app's `capturePrivacy` (`app_en.arb:523`). Since aa2f53a they use the same three verbs.
  - The FAQ's Pro list (`en.ts:94`) ↔ `billingIntro` (`app_en.arb:1977`).
  - The 50-a-day budget is shared by dictation, Pro's typed text and reminder reads (`Backend/core/views.py:96-110, 180-206`).
- **The app's reminder questions:**
  - one per account, asked only while reminders are off;
  - with reminders on, a plan offer once per task whose anchor is 14 or more days away (`reminder_ask_sheet.dart`; `reminder_plans.dart:26, 105-110`).
- **Don't quote the sheet's labels** («Hasta la fecha límite», Suave/Normal/Intenso, «A tu manera») until the app's run 2026-10-22-changes settles them. B-Q1 proposes «Cada vez más a menudo».
- **The hero images are still valid after aa2f53a.** Its only row change (b287cda, `task_tile.dart`) affects rows with no date.
- **The website demo's prompt has no reminder concept** (`src/lib/voice/model.ts:53`): a rhythm may come out as notes.
- **Recurring problem:** the app adds an AI call outside capture, and a "never"/"only" privacy line breaks.
  - Technique: after `since --app`, grep `App/lib` for `'ai/` endpoints, trace each caller to the screens that open it, then grep `src/content/legal/` for "never"/«nunca»/«mai» and "only"/«solo»/«només».
- **Tools:** WSL was up on 2026-10-22, and `crop.mjs` worked.
