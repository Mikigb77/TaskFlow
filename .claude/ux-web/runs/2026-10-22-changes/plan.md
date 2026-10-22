# UX web loop run 2026-10-22-changes: plan

Today's reminder plans made two lines on the site untrue. Privacy §4 promises that the task form never sends anything to the AI, and the calendar card says TaskFlow asks about reminders only once.
Two small packages fix them in English, Spanish and Catalan, side by side. Whether to tell reminder plans on the site is your call: two questions, WD20 and WD21.

Sources: `review-F.md` (one reviewer, area F), covering reminder plans (server 7105ae9, app aa2f53a), your D1–D4 for bulk voice commands, and the overdue search fix.
- Review F checked 28 claims: one is false (WEB-1101) and one is outdated (WEB-1102).
- D1–D4 and the overdue fix contradict nothing on the site.

Scoped run: the packages go straight to the implementers, and neither waits on your answers. Today is 2026-10-22.

## Your decisions

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

## Packages, in order

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

## Skipped

None. Both findings are fixes.

## Owner checks (not findings)

1. **A spoken rhythm in the live demo.** On /es/, say «Presentar el proyecto en 3 semanas, recuérdamelo cada 3 días».
   - The demo's prompt knows nothing about reminders (`src/lib/voice/model.ts:53`: "Recurrence can be described in notes"), so the rhythm may come out as a note, or as a second «Recordar…» task.
   - In the app it becomes a reminder on the one task, so a second task would show visitors something the app doesn't do.
   - Only the real AI can tell.
2. **The new legal version.** After WP58, sign off "In force since 22 October 2026" and §4's narrowed sentence (WD3). That one sign-off replaces the ones still pending for 20 October (WEB-109) and 21 October (WEB-1002).
3. **A native Catalan read** of «Sense Pro, el formulari de tasques no envia mai res a la IA.»

## For the app's /ux loop (not this run)

- The reminder sheet's own-words field never says the words go to Google (`reminderPlanYourWayHint`).
- A Pro user whose first microphone use is in that field never sees capture's one-time privacy line (`.claude/ux-review/runs/2026-10-22-changes/review-B.md:368`).

## Ledger

- New lines: WEB-1101 and WEB-1102, open, for WP58 and WP59.
- WD20 and WD21 have no ledger lines. Review F counts them as owner questions, not findings, as WD18 and WD19 were before you answered them.
- WEB-1003 stays a device check for now. Once WEB-1102 is verified, its Catalan read is moot.
- Considered by review F and not reported, for a later legal edit or whole-site run:
  - privacy §3's short list of what the AI suggests (it now also suggests reminder rhythms);
  - §2's "reference date" for the task's own day, covered by §4's "relevant context";
  - terms §3's English "optional dictation that turns what you say into tasks", against «IA opcional» in Spanish and Catalan: older than this change, and incomplete rather than false;
  - the 14 px «Per exemple, digues:» on /ca/ (area H, unchanged).
