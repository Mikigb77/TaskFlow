# UX web loop run 2026-10-22-changes: plan

## Plan 2 (2026-10-22, evening)

You said yes to WD20 and WD21. One small package, WP60, does both on the home in English, Spanish and Catalan.
Your D1–D7 for the app make nothing on the site false.

Sources:
- plan 1's `review-F.md`;
- your answers in `.claude/ux-web/DECISIONS.md` («WD20 and WD21») and `.claude/ux-review/DECISIONS.md` («D1–D7 of run 2026-10-22-changes»);
- the updated contract, `Backend/docs/REMINDER_PLANS.md`.

This is a scoped run, so WP60 goes straight to the implementer. Today is 2026-10-22.

### What changed since plan 1

- WP58 and WP59 are done, verified and committed (TaskFlowWeb 883d4d1, records 19a26a8). Plan 1 is below, as it was.
- WD20 and WD21 are answered. They're now findings WEB-1103 and WEB-1104, and WP60 builds both.
- I checked every reminder line on the site against D1–D7 again: the hero, the calendar card, the FAQ, privacy (summary 02, §2, §4, §5, §9), terms §3 and the delete page. None of them is false.
  - The site doesn't mention the details D1–D7 settle, and doesn't need to: personal plans on shared tasks, the 4 weeks, rhythms kept as said, and the question for a task with no day.
  - Your plans on shared tasks are deleted with your account, so the delete page's "notification settings" line still holds.
- No question is open.

### Your answers, and how WP60 carries them out

**WD20 → WEB-1103: the calendar card says reminders can come more often as the day gets closer.** As recommended, the card's reminder sentence gains one clause, in the words you approved:
- EN: "TaskFlow can remind you of tasks with a date, more and more often as the day gets closer."
- ES: «TaskFlow puede recordarte las tareas con fecha, cada vez más a menudo según se acerca el día.»
- CA: «TaskFlow et pot recordar les tasques amb data, cada cop més sovint a mesura que s’acosta el dia.»

The clause names no option, number or label from the app's reminder sheet. It stays true while the app's D1–D7 round changes the sheet. In English, the card goes from 27 words to 36.

**WD21 → WEB-1104: reminders in your own words join the Pro list in "Is TaskFlow free?".** My recommendation was «not now»; you said yes. The answer changes in three places:
- After the free part, a new sentence:
  - "Reminders are free too, even the ones that come more and more often as the day gets closer."
  - «Los recordatorios también son gratis, incluso los que llegan cada vez más a menudo según se acerca el día.»
  - «Els recordatoris també són gratuïts, fins i tot els que arriben cada cop més sovint a mesura que s’acosta el dia.»
- The Pro sentence now ends at "unlimited dictation and file space (with a safety limit of 50 dictations a day)".
- A second Pro sentence:
  - "It also turns sentences you type into tasks, and lets you ask for reminders in your own words."
  - «Además, convierte en tareas las frases que escribes y te deja pedir los recordatorios con tus palabras.»
  - «A més, converteix en tasques les frases que escrius i et deixa demanar els recordatoris amb les teves paraules.»

How it follows your answer:
- "In your own words" is the phrase the site already uses for dictation. It says what «A tu manera» does without quoting the name, which the app's D1–D7 round may still touch. You're adding the name to the Pro screen yourself (D7).
- The free sentence repeats the card's words, so nobody takes the reminders that come more often for a Pro feature.
- Splitting the Pro sentence keeps every sentence shorter than today's longest: 38 → 30 words in English.
- The answer grows from 80 to 108 words in English.
- The closing card and the line under the demo keep their short Pro line, as WD14 says.

### Packages, in order

**WP60 · F · S · severity 2: Home. The calendar card says reminders come more and more often as the day gets closer; "Is TaskFlow free?" says reminders are free, and that Pro adds reminders in your own words.**
- **WEB-1103** (S2, WD20): the calendar card's reminder sentence ends "…more and more often as the day gets closer."
- **WEB-1104** (S1, WD21): the free answer says reminders are free too, even the ones that come more and more often, and that Pro "lets you ask for reminders in your own words".

### Skipped

None.

### Owner checks (not findings)

1. **A spoken rhythm in the live demo** (plan 1's check 1, still open). It matters more now that the card and the FAQ tell about reminders.
   - On /es/, say «Presentar el proyecto en 3 semanas, recuérdamelo cada 3 días».
   - The demo's prompt knows nothing about reminders, so it may make a second «Recordar…» task. The app wouldn't.
   - Only the real AI can tell.
2. **The Pro screen.** After you add «A tu manera» to the paywall in RevenueCat (D7), check on a phone that it's listed, so the app's Pro screen and the FAQ agree.
3. **Native Catalan reads** of WP60's three Catalan sentences.
4. **Still pending from plan 1:**
   - your WD3 sign-off of legal version 2026-10-22;
   - the Catalan read of «Sense Pro, el formulari de tasques no envia mai res a la IA.» (WEB-1101).

### Not planned

- **A rhythm said while dictating, in the voice answer.** Review F's "not now" stands, because the live demo can't show reminders.
- **Anything about reminders on shared tasks.** Plans are personal (D6), and the single reminder on shared tasks is still open in the app's decisions.

### Ledger

- New lines: WEB-1103 and WEB-1104, open, for WP60.
- WEB-1102's note now says WD20 was answered, and the header note lists plan 2.

### Round 2 (p2)

Round 1 verified WEB-1103 and WEB-1104 as fixed, and the round check passed. One small regression came out of the longer calendar sentence, and it gets one CSS line.

**WP61 · F · S · severity 1: Home. Feature-card paragraphs wrap with `text-wrap: pretty`, so the calendar card's last line isn't one word on phones.**
- **WEB-1105** (S1, regression R1F-1 from WP60): at 390 px the calendar card's paragraph ends on a line holding only «día.» (es) or «dia.» (ca).
  - Fix: add `text-wrap: pretty;` to `.feature-card p` (`src/styles/global.css:583-589`), as two other paragraphs on the site already have it.
  - No copy changes. The card tests (WEB-705, WEB-1004) and WP60's tests must still pass.

Not re-planned: the round's failing test was infrastructure, not the site. The workflow's combined suite + renders command lost nvm's PATH in its renders half (`npx: command not found`). The tester ran the renders separately and they passed. WP61's brief says how to work around it if it happens again. The cause, the way `.claude/ux-web/webrun.py:211` wraps the line, is for whoever maintains the loop.

Escalated: none. Nothing has failed twice.

Device check: on Safari on an iPhone and Chrome on an Android phone, the last line should hold two or more words. A browser without `text-wrap: pretty` falls back to normal wrapping and may still show the lone word.

Ledger: new line WEB-1105, open, for WP61.

### Round 3 (p2)

Round 2 found nothing broken: no failing test, no regression, and the round check passed. The workflow got no verdict for WEB-1105, though, so it's checked again. No code changes.

**WP62 · F · S · severity 1: Home. Re-check WP61's `text-wrap: pretty` on the feature cards.**
- **WEB-1105** (S1, regression R1F-1 from WP60): the calendar card's paragraph ended on «día.» / «dia.» alone at 390 px.
  - What round 2 did: WP61 added one line, `text-wrap: pretty;`, to `.feature-card p` (`src/styles/global.css:583-584`). The reviewer's note (`verify-p2-r2-F.md`) reads it as fixed from the renders: es now ends «…el día.», ca «…el dia.».
  - Why it's planned again: the workflow recorded no verdict for it, and the tester reported no results for WP61's tests (`tests/ux-web-features.spec.ts:1199`).
  - This round: run WP61's tests and the card tests (WEB-705, WEB-1004, WP60), redo the renders, and record a verdict. Only if the CSS line has gone missing does it go back in.

Escalated: none. WEB-1105 hasn't failed. It just wasn't confirmed.

Device check: unchanged from round 2 (Safari on an iPhone, Chrome on an Android phone).

Ledger: WEB-1105 stays open, now for WP62.

## Plan 1 (2026-10-22): done, verified and committed

Outcome:
- WP58 and WP59 were verified in round 1 (`verify-r1-F.md`, `report.md`) and committed (TaskFlowWeb 883d4d1).
- WEB-1102 is verified. WEB-1101 is a device check: your WD3 sign-off and a native Catalan read.
- WD20 and WD21 were answered on the evening of the same day; see plan 2 above.

Today's reminder plans made two lines on the site untrue. Privacy §4 promises that the task form never sends anything to the AI, and the calendar card says TaskFlow asks about reminders only once.
Two small packages fix them in English, Spanish and Catalan, side by side. Whether to tell reminder plans on the site is your call: two questions, WD20 and WD21.

Sources: `review-F.md` (one reviewer, area F), covering reminder plans (server 7105ae9, app aa2f53a), your D1–D4 for bulk voice commands, and the overdue search fix.
- Review F checked 28 claims: one is false (WEB-1101) and one is outdated (WEB-1102).
- D1–D4 and the overdue fix contradict nothing on the site.

Scoped run: the packages go straight to the implementers, and neither waits on your answers. Today is 2026-10-22.

### Your decisions

**WD20 — Say on the calendar card that reminders can come more and more often as a task's day gets closer?**
This is reminder plans' free half: no AI, and it works offline. It would take the place of the "it asks you once" clause that WP59 cuts, so the card's sentence would read:
- EN: "TaskFlow can remind you of tasks with a date, more and more often as the day gets closer."
- ES: «TaskFlow puede recordarte las tareas con fecha, cada vez más a menudo según se acerca el día.»
- CA: «TaskFlow et pot recordar les tasques amb data, cada cop més sovint a mesura que s’acosta el dia.» (needs a native read)

Findings: none of its own. It extends the sentence WEB-1102 shortens.

My recommendation: **yes, on the card only, in these words.**
- For:
  - it's free, needs no AI, and is true today;
  - it's your own reason for the feature: a project three weeks away;
  - it sharpens the card's existing reminder sentence rather than adding one: 27 → 36 words in English, after WP59's cut;
  - it says it the app's way ("More and more often" / «Cada vez más a menudo» / «Cada cop més sovint» in the reminder sheet), without quoting a label or listing options.
- Against:
  - the app's /ux review of reminder plans is still running (the row's name, how many notices a far task gets, what the offer's «Sí» sets), though the sentence depends on none of these;
  - repeating tasks get no plan in this first version; "can" keeps the sentence true;
  - the live demo can't show reminders.
- Not in the hero (the core loop comes first), not in the FAQ's free list, and not in the voice answer: a rhythm said to the live demo may come out as a note or a second task (owner check 1).
- If you say yes, one small package changes the same three lines after WP59.

**WD21 — Add "reminders in your own words" to the Pro list in the FAQ's "Is TaskFlow free?"?**
This is the Pro half: a rhythm you type or say, read by Google's AI.

Findings: none. Review F counts the Pro list as incomplete, not false.

My recommendation: **not now.** Revisit when Pro's price is set, or when the app's Pro screen names it.
- For: it's Pro's newest feature, and someone comparing apps might value it.
- Against:
  - the site's Pro line mirrors the app's Pro screen, which still sums Pro up as "Unlimited dictations, and room for all your files." (`billingIntro`, unchanged by reminder plans);
  - the free answer is already 80 words in English, with a 38-word Pro sentence;
  - the feature's name is under the app's review;
  - the live demo can't show it.
- Nothing on the site is false without it: once WP58 lands, privacy §4 covers the words it sends.

### Packages, in order

They share no file, so they run side by side.

**WP58 · F · S · severity 3: Privacy §4. The task form's "never sends anything to the AI" is narrowed to accounts without Pro.**
- **WEB-1101** (S3): with Pro, the task form's reminder sheet now sends a typed or said rhythm to Google's AI, so §4's "The task form never sends anything to the AI." is false for Pro accounts. Without Pro, that option opens the Pro screen and nothing is sent.
  - The sentence becomes "Without Pro, the task form never sends anything to the AI." / «Sin Pro, el formulario de tareas nunca envía nada a la IA.» / «Sense Pro, el formulari de tasques no envia mai res a la IA.»
  - The sentence before it, "With Pro, words you type for the AI are sent the same way.", then covers the reminder words. Nothing else in §4 changes, and the reminder field isn't named, because the app's review may rename it.
  - The legal version moves to 2026-10-22 ("In force since 22 October 2026"), for your WD3 sign-off.

**WP59 · F · S · severity 2: Home. The calendar card's reminder sentence drops "it asks you once".**
- **WEB-1102** (S2): with reminders on, the app now also offers a plan for each task 14 or more days away, so "it asks you once" is true only for people who said no to reminders.
  - The sentence becomes "TaskFlow can remind you of tasks with a date." / «TaskFlow puede recordarte las tareas con fecha.» / «TaskFlow et pot recordar les tasques amb data.»
  - No new words, so no new Catalan.
  - WEB-1003's pending Catalan read of «t’ho pregunta una sola vegada» goes with the clause.

### Skipped

None. Both findings are fixes.

### Owner checks (not findings)

1. **A spoken rhythm in the live demo.** On /es/, say «Presentar el proyecto en 3 semanas, recuérdamelo cada 3 días».
   - The demo's prompt knows nothing about reminders (`src/lib/voice/model.ts:53`: "Recurrence can be described in notes"), so the rhythm may come out as a note, or as a second «Recordar…» task.
   - In the app it becomes a reminder on the one task, so a second task would show visitors something the app doesn't do.
   - Only the real AI can tell.
2. **The new legal version.** After WP58, sign off "In force since 22 October 2026" and §4's narrowed sentence (WD3). That one sign-off replaces the ones still pending for 20 October (WEB-109) and 21 October (WEB-1002).
3. **A native Catalan read** of «Sense Pro, el formulari de tasques no envia mai res a la IA.»

### For the app's /ux loop (not this run)

- The reminder sheet's own-words field never says the words go to Google (`reminderPlanYourWayHint`).
- A Pro user whose first microphone use is in that field never sees capture's one-time privacy line (`.claude/ux-review/runs/2026-10-22-changes/review-B.md:368`).

### Ledger

- New lines: WEB-1101 and WEB-1102, open, for WP58 and WP59.
- WD20 and WD21 have no ledger lines. Review F counts them as owner questions, not findings, as WD18 and WD19 were before you answered them.
- WEB-1003 stays a device check for now. Once WEB-1102 is verified, its Catalan read is moot.
- Considered by review F and not reported, for a later legal edit or whole-site run:
  - privacy §3's short list of what the AI suggests (it now also suggests reminder rhythms);
  - §2's "reference date" for the task's own day, covered by §4's "relevant context";
  - terms §3's English "optional dictation that turns what you say into tasks", against «IA opcional» in Spanish and Catalan: older than this change, and incomplete rather than false;
  - the 14 px «Per exemple, digues:» on /ca/ (area H, unchanged).
