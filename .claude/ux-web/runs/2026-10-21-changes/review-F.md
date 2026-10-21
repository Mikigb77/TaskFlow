## UX web review — F: claims touched by the app's changes since 2026-10-20 (bulk voice commands, mark done, the whole-app run's wording, password recovery) — 2026-10-21

**Verdict:** Ship after fixes. Nothing on the site is false today, but:
- the FAQ describes voice changes as one task at a time. It never mentions marking a task done, or changing many tasks at once, which is the owner's newest feature;
- the privacy summary says your words go to Google "only … to turn them into tasks", but dictation now also finds and changes tasks;
- the hero and link-preview screenshots still show two lines the app has since removed.

**Walked:**
- **J1 — Comparer and Newcomer.** Phone 390 and desktop 1440, EN/ES/CA. Shared link → home → about 6.5 phone screens down to Questions → open "How do I add tasks by voice?" (1 tap) → read. That's 3 steps after landing. What they learn: tasks can be changed by voice, but only one at a time. Nothing about sets, nothing about marking done.
- **J2 — wary Newcomer and Leaver.** Phone and desktop, EN/ES/CA. Any page → footer Privacy (1 tap) → summary 02 (at the bottom of the phone's first screen; in the centre card above the fold on desktop) → §2 and §4 for the detail.
- **J3 — Newcomer.** Hero → "What it does" (1 tap) → the calendar card's reminder sentence → later, the app's first dated save, where the reminder question appears.
- **J4 — Newcomer from a shared link.** WhatsApp preview (`opengraph-image*.png`) → hero (on desktop the phone screenshot is in the first viewport; on a phone it's in the second screen) → later, the app's Calendar.
- **J5 — Leaver who forgot their password.** Privacy §1, §2, §5 and §7, and delete-account §1–§2, read against `Backend/docs/PASSWORD_RECOVERY.md`. From any page to account deletion: 1 step (the footer link).
- **Evidence and freshness:**
  - The copy findings don't depend on the theme. The six hero PNGs share one scenario and one render time (2026-10-19 00:48).
  - The site's renders and `AUDIT.md` were measured 2026-10-21 18:45–18:50 UTC, after the last content change (11:01 local), so they're current.
  - The app's renders in `App/build/ux/` date from 2026-10-21 20:31–20:32, also current.
  - WSL is up: `crop.mjs` ran.

**Numbers:**

| What | Before | After the fixes |
|---|---|---|
| Claims checked | 31 (home 19, legal 12) | — |
| False claims | 0 | 0 |
| Outdated or incomplete claims | 7, in 4 findings | 0 |
| FAQ voice answer (EN): words | 84 | 85 |
| FAQ voice answer (EN): longest sentence | 28 words | 24 words |
| FAQ voice answer: voice actions named | add, ask, move, change, delete — "a task" | adds "complete" and "even all of yesterday's at once" |
| Privacy summary 02 (EN): words | 16 | 20 |
| Privacy summary 02: purposes named | 1 (tasks) | 3 (add, find, change) |
| Calendar card (EN): words | 36 | 31 |
| Images that no longer match the app | 6 hero PNGs and 3 link previews | 0, after a re-render |

These are unchanged by this run (home, EN, phone):
- the first viewport holds about 65 words, 1 primary call to action and 1 secondary link;
- the first call to action and the honest "not yet" status line need 0 scrolls;
- any page → account deletion is 1 step.

**Attention.** Predicted from the renders with GUIDELINES §21 step 4; not measured eye-tracking.
- **Home, phone** (`home.{en,es,ca}.mobile.{light,dark}.fold.png`):
  - Fixations: 1. the H1; 2. the first words of the description; 3. the filled "Try it with your voice" (y ≈ 366–416 of 664, on its own).
  - Competing: the Menu pill (top right), the quote card in the bottom third (about 14% of gaze, AT-2), and the pale status line.
  - The phone screenshot isn't in this viewport: only the top edge of its frame shows, at y ≈ 640. So WEB-5's mismatch sits in screen 2 on phones.
- **Home, desktop** (`home.*.desktop.*.fold.png`):
  - Fixations: 1. the H1 (top left); 2. the filled call to action (left, on its own); 3. the phone screenshot (right third; the right side gets its first look after about 2–3 s).
  - Competing: the quote card above the phone, the header's three links, and the language pills.
  - The screenshot's outdated lines are about 9 px tall here, too small to read at a glance. That's why WEB-5 is rated S1.
- **Privacy, phone** (`privacy.es.mobile.light.fold.png`):
  - Fixations: 1. the H1; 2. the back link and the ringed language pill; 3. summary 01.
  - Summary 02 straddles the fold (y ≈ 558–664), so it's the first thing seen after one scroll.
- **Privacy, desktop** (`privacy.en.desktop.light.fold.png`):
  - Fixations: 1. the H1; 2. summary 01 (left card); 3. summary 02 (centre card, y ≈ 493–628, above the fold).
  - Competing: the two language switches (header and page), the Delete account and Email support links, and the table of contents.

### Findings (most severe first)

**WEB-1001 · Severity 2 · FAQ tells voice changes one task at a time**
- **Where:**
  - `src/content/site/en.ts:104`, `es.ts:104`, `ca.ts:110`: home, FAQ item 4, "How do I add tasks by voice?" / «¿Cómo añado tareas hablando?» / «Com afegeixo tasques parlant?». Every viewport and theme.
  - Pinned by `tests/support/ux-web-copy.ts:163` and its ES/CA strings.
  - No render shows this answer open: `home-faq.*` opens item 1 only. Reviewed in code.
- **The moment:**
  - Comparer: "Can I tell it to push everything I didn't do yesterday to tomorrow? It says 'move… a task', so one at a time."
  - Newcomer, in Spanish: «Si ayer no hice nada, ¿tengo que cambiarlas una a una?»
- **What happens:**
  - The answer says "…or move, change or delete a task by voice: TaskFlow shows the change first, and you can undo it". It ends "your words are sent to Google to be turned into tasks".
  - Since 2026-10-21 the app does more:
    - it marks a task done by voice («ya he llamado al dentista»);
    - it moves, changes, completes or deletes a whole set of tasks from one sentence («pasa todo lo de ayer a mañana»). One card shows the change first, and one «Deshacer» undoes all of it.
  - Sources:
    - `.claude/ux-review/DECISIONS.md:5-20`;
    - `Backend/docs/VOICE_COMMANDS.md:161-169` and `:171-219`;
    - `App/lib/l10n/app_en.arb:3073, 3116, 3197, 3206`;
    - the app render `App/build/ux/commands/cards.bulk-move.es.light.1x.png` (2026-10-21 20:31).
  - Nothing in the answer is false. But the singular "a task" undersells what the owner just asked for and built, and "to be turned into tasks" no longer covers everything a dictation does.
  - The fourth sentence is also 28 words long (RD-3 asks for 20 or fewer).
- **Why it fails:**
  - FN-1: every claim true today, and the site follows the app (UCPD art. 6; Play Metadata).
  - Lens B: concrete outcomes create desire. Rearranging a day with one sentence is what a Comparer switches apps for.
  - FN-2: the app's own verbs.
  - RD-3: sentences of 20 words or fewer (Loranger 2017p; COGA 2021).
- **Fix:**
  - Replace the answer's last two sentences, and keep the rest.
  - Don't add a quoted example: a visitor could try it in the live demo, which only adds tasks, and it would cost them a try.
  - New copy:
    - EN: "You can also ask what you have this week, or move, change, complete or delete tasks by voice, even all of yesterday’s at once. TaskFlow shows the change first, and you can undo it. It needs the internet: your words are sent to Google."
    - ES: «También puedes preguntar qué tienes esta semana, o mover, cambiar, completar o eliminar tareas hablando, incluso todas las de ayer a la vez. TaskFlow te enseña el cambio antes y puedes deshacerlo. Necesita internet: tus palabras se envían a Google.»
    - CA: «També pots preguntar què tens aquesta setmana, o moure, canviar, completar o suprimir tasques parlant, fins i tot totes les d’ahir alhora. TaskFlow t’ensenya el canvi abans i el pots desfer. Necessita internet: les teves paraules s’envien a Google.» Needs a native Catalan read.
  - The verbs are the app's own:
    - move, change and delete come from the bulk card (`commandBulkMove`, `commandBulkChange`, `commandBulkDelete`; ES «Eliminar», CA «Suprimeix»);
    - "complete" / «completar» is the app's task action (`complete`, `app_es.arb:165`, `app_ca.arb:144`), and the site's offline answer already uses it (`en.ts:109`).
  - The fix doesn't quote the bulk card itself, whose wording the app's /ux review may still change.
  - Keep the question as it is: it's the Newcomer's own question (FQ-1).
- **Verify:**
  - `tests/support/ux-web-copy.ts:163` and its ES/CA strings are updated.
  - `tests/ux-web-features.spec.ts:542` and the word scan at `:561` pass in EN/ES/CA.
  - No sentence in the answer is longer than 24 words.
  - With item 4 open, nothing scrolls sideways at 320 px or at 200% phone text.
  - A native Catalan read.
- **Evidence:** verified in code, on both the site and the app; the app render is current. No device needed.

**WEB-1002 · Severity 2 · Privacy summary narrows when words go to Google**
- **Where:**
  - `src/content/legal/en.ts:10` (summary 02), `:33` (§2 "Voice and AI") and `:55` (§4); the same lines in `es.ts` and `ca.ts`.
  - Pages: /privacy/, /es/privacy/ and /ca/privacy/.
  - Summary 02 is in the desktop first viewport (`privacy.en.desktop.light.fold.png`, centre card) and at the bottom of the phone's first screen (`privacy.es.mobile.light.fold.png`).
  - Area: F (faithfulness). The lines are legal copy (area L).
- **The moment:**
  - A wary Newcomer reads: «Vale: mis palabras solo van a Google cuando creo tareas.»
  - Later she says «pasa todo lo de ayer a mañana» or «¿qué tengo esta semana?», and those words go to Google too.
- **What happens:**
  - Summary 02 says:
    - EN: "Your words go to Google’s AI only when you ask TaskFlow to turn them into tasks."
    - ES: «…solo… cuando pides a TaskFlow que las convierta en tareas.»
    - CA: «…només… quan demanes a TaskFlow que les converteixi en tasques.»
  - §2 lists only "suggested tasks", and §4 says "only the words are sent to become tasks".
  - In the app, every dictation goes to the model. Besides tasks, it now returns:
    - searches;
    - changes, completions and deletions, for one task or a whole set;
    - and, as before, notes and projects.
  - Sources: `Backend/docs/VOICE_COMMANDS.md:3, 59, 161, 171`; `.claude/ux-review/DECISIONS.md:5-20, 122`.
  - Why S2 and not S4:
    - the trigger is still the person's own dictation;
    - the model never sees their tasks (`VOICE_COMMANDS.md:7`);
    - so nobody shares more than what they chose to say.
  - Still, an "only when" sentence in the privacy summary has to be literally true.
- **Why it fails:**
  - PV-1: the summary must state the surprising parts (voice, the AI provider) plainly and accurately (GDPR art. 12; WP260 2018).
  - FN-1: every claim true today.
- **Fix:** three substitutions, in all three languages.
  - **Summary 02:**
    - EN: "Your words go to Google’s AI only when you ask TaskFlow to understand them: to add, find or change tasks."
    - ES: «Tus palabras solo van a la IA de Google cuando pides a TaskFlow que las entienda: para añadir, buscar o cambiar tareas.»
    - CA: «Les teves paraules només van a la IA de Google quan demanes a TaskFlow que les entengui: per afegir, cercar o canviar tasques.» Needs a native Catalan read; «cercar» follows the app's «Cerca una tasca…».
  - **§2:**
    - "suggested tasks" → "suggested tasks and changes";
    - «tareas sugeridas» → «tareas y cambios sugeridos»;
    - «tasques suggerides» → «tasques i canvis suggerits».
  - **§4:** cut the purpose clause:
    - EN: "only the words are sent.";
    - ES: «solo se envían las palabras.»;
    - CA: «només s’envien les paraules.»
  - Leave §3 ("The AI suggests titles, dates and priorities for your review", `en.ts:48`) as it is: its point, that nothing happens without your review, still holds.
  - Changing the legal text moves these together:
    - the version in `src/content/legal/company.json:10`;
    - the effective date in `docs/LEGAL_RELEASE.md:3`;
    - the pinned dates at `tests/legal.spec.ts:35` and `tests/ux-web-legal.spec.ts:673-680`.
  - The new "In force since" date is the owner's to sign off (WD3).
- **Verify:**
  - A grep of `src/content/legal/` finds none of: "turn them into tasks", «las convierta en tareas», «les converteixi en tasques», "to become tasks", «para crear las tareas», «per crear les tasques».
  - The privacy first-viewport renders show the new summary 02 in all three languages, with nothing scrolling sideways at 320 px.
  - `npm run legal:check` and both legal specs pass with the new date.
- **Evidence:**
  - Verified in code, and seen in the current privacy first-viewport renders.
  - This isn't legal advice: the owner's sign-off stands.

**WEB-5 (reopened) · Severity 1 · Hero and preview screenshots show rows the app removed**
- **Where:**
  - `public/images/hero-calendar-{en,es,ca}-{light,dark}.png`, rendered 2026-10-19 00:48.
  - Shown by `src/components/Phone.tsx:22`, and in the three link previews through `src/og/preview.tsx:14`.
  - Seen in `home.*.desktop.*.fold.png` (first viewport), in the phone's second screen, and in `opengraph-image.png`, `.es.png` and `.ca.png`.
  - This is WEB-5's problem again: the app changed after WD4's images were made.
- **The moment:**
  - The owner, or a Newcomer who installs the app: "That's TaskFlow, but the real one doesn't say 'Any time' under each task."
  - Few people would notice, but this is the proof image and the WhatsApp preview.
- **What happens:**
  - The images show:
    - "2 to do · 0 completed" / «2 pendientes · 0 completadas» / «2 per fer · 0 completades»;
    - "Any time" / «Sin hora» / «Sense hora» under each task.
  - The app now leaves out the completed count when nothing is done (`App/lib/l10n/app_en.arb:533`, `app_es.arb:313`, `app_ca.arb:292`).
  - It also shows no line on the row of a task without a time (`App/lib/widgets/task_tile.dart:29-30`; run 2026-10-19-app, batch b3, 2026-10-20 17:06).
  - The current app render of the same view, `App/build/ux/calendar/agenda.month-day-tapped.es.light.1x.png` (2026-10-21 20:32), shows «1 pendiente» and no «Sin hora».
- **Why it fails:**
  - HE-5 and FN-3: the hero shows the app as it is now, matching its current renders.
  - TR-3: outdated screenshots are trust bugs.
  - ML-9: the link preview shows the real product.
- **Fix:**
  - Re-render the six images from the app at its current commit, with the same WD4 scenario: "Call the dentist" and "Buy bread" on tomorrow, and the one Add a task button.
  - The main session made the WD4 images this way. The three link previews follow automatically.
  - Do this with WEB-114's re-render before publishing (the images show their render date), or now and again then.
- **Verify:**
  - The new PNGs are newer than the app's HEAD.
  - The Spanish light hero reads «2 pendientes» with no «Sin hora», side by side with the app render above.
  - `tests/ux-web-home.spec.ts:62` passes.
  - The link-preview renders show the same phone.
- **Evidence:** seen in current site renders and current app renders; the app's code confirms the change.

**WEB-1003 · Severity 1 · Reminder line promises the question at the first dated task**
- **Where:**
  - `src/content/site/en.ts:61`, `es.ts:61`, `ca.ts:61`: home, the "Your day on one calendar" card.
  - Pinned by `tests/support/ux-web-copy.ts:48` and its ES/CA strings.
- **The moment:** a Newcomer adds "buy bread today" at 15:00: "The website said it would ask about reminders the first time I added a task with a date. It didn't."
- **What happens:**
  - The card says "it asks once, the first time you add one".
  - Since batch b6 (2026-10-21; D1 of 2026-10-20), the app asks once, after the first dated save whose reminder can still ring:
    - not for a task for today saved after 9:00;
    - not for one saved inside its reminder's lead time;
    - in those cases, the next dated save asks instead.
  - Sources: `App/lib/widgets/reminder_ask_sheet.dart:17-20` and `:105-108`; `.claude/ux-review/DECISIONS.md:45-48`.
- **Why it fails:**
  - FN-1: true today, in these words.
  - RD-2: the fix removes words.
- **Fix:** cut the clause.
  - EN: "TaskFlow can remind you of tasks with a date: it asks you once."
  - ES: «TaskFlow puede recordarte las tareas con fecha: te lo pregunta una sola vez.»
  - CA: «TaskFlow et pot recordar les tasques amb data: t’ho pregunta una sola vegada.» Needs a native Catalan read.
- **Verify:**
  - `tests/support/ux-web-copy.ts:48` and its ES/CA strings are updated, and `tests/ux-web-features.spec.ts:51` passes.
  - WEB-705's test still passes (calendar card spanning two rows, no more than 25% empty), because shortening a card's copy can leave it half empty.
- **Evidence:** verified in code.

### Claims checked
English lines are cited; Spanish and Catalan sit on the same or neighbouring lines and were checked too.

| Claim (page, `path:line`) | Source of truth (`path:line`) | Status |
|---|---|---|
| Hero: tap one button, say several things, each goes on its day, can remind you (`src/content/site/en.ts:49`) | `.claude/ux-review/DECISIONS.md:157-162`; `App/lib/l10n/app_en.arb:242` | true |
| Hero image alt: tomorrow's calendar, two tasks, the Add a task button (`en.ts:55`) | WD4; `app_en.arb:242` | true |
| Hero and link-preview screenshots (`public/images/hero-calendar-*.png`; `src/og/preview.tsx:14`) | `app_en.arb:533`; `App/lib/widgets/task_tile.dart:29-30`; `App/build/ux/calendar/agenda.month-day-tapped.es.light.1x.png` | outdated (WEB-5) |
| Calendar card: phone calendars' events beside your tasks (`en.ts:61`) | `app_en.arb:164` (`deviceCalendarIntro`); `DECISIONS.md:54` (D7) | true |
| Calendar card: reminder question at the first dated task (`en.ts:61`) | `App/lib/widgets/reminder_ask_sheet.dart:17-20, 105-108`; `DECISIONS.md:45-48` | outdated (WEB-1003) |
| Voice card: one task for each thing said, with day and time; add them all with one tap (`en.ts:71`) | `app_en.arb:1860` (`captureAddTasks`) | true |
| Details card: notes, checklists, files backed up, 6 MB each (`en.ts:76`) | `app_en.arb:722`; `DECISIONS.md:209` | true |
| FAQ download: Android; Spanish, Catalan and English; not on Google Play yet (`en.ts:89`) | `.claude/ux-web/DECISIONS.md` (WD7, Google Play not published) | true |
| FAQ free and Pro: 10 a month, the form with no limit, Pro monthly, unlimited dictation and file space, 50 a day (`en.ts:94`) | `app_en.arb:2245, 1974`; `DECISIONS.md:126-136, 189-209`; WD14 | true |
| FAQ account: Continue with Google, or email and password, then a 6-digit code (`en.ts:99`) | `app_en.arb:2032-2033`; `Backend/docs/EMAIL_VERIFICATION.md:3` | true. The app's second button is now "Continue with email" / «Continuar con mi correo»; the site describes that path without naming the button. |
| FAQ voice: Add a task → say it → Done → one task for each → add them all (`en.ts:104`) | `app_en.arb:242, 1064` (`App/lib/screens/voice_task_screen.dart:2273-2277`), `:1860` | true |
| FAQ voice: ask what you have this week (`en.ts:104`) | `Backend/docs/VOICE_COMMANDS.md` (`find`); `DECISIONS.md:72` | true |
| FAQ voice: "move, change or delete a task by voice", shown first, undo (`en.ts:104`) | `VOICE_COMMANDS.md:161-219`; `DECISIONS.md:5-20` | incomplete (WEB-1001) |
| FAQ voice: words sent to Google "to be turned into tasks" (`en.ts:104`) | `VOICE_COMMANDS.md:3, 59` | incomplete (WEB-1001) |
| FAQ offline: check, add and complete without internet (`en.ts:109`) | unchanged since the last review | true |
| FAQ sharing: Share, invite by email, created by, one person's tasks (`en.ts:114`) | `app_en.arb:1066, 1088, 2303` | true |
| FAQ notes: the Notes tab, Add a note, write or dictate it, links or a checklist (`en.ts:119`) | `app_en.arb:90, 266, 111, 722`; `App/lib/screens/notes_screen.dart:262-268`. `notesEmptyHelp` (`:83`) was reworded but doesn't contradict the site. | true |
| Closing plans line (`en.ts:128`) | `app_en.arb:1974, 2245` | true |
| Demo hand-over: tap Add a task, say it, tap Done, add it to your calendar (`en.ts:186`) | `app_en.arb:242, 1064, 1858` | true |
| Widget and shortcuts, «Dictate a task» | `DECISIONS.md:29-34`; `app_en.arb:404` | not claimed anywhere on the site (no widget, shortcut or "Say a task" in `src/`) |
| Privacy summary 02: words go to Google only to turn them into tasks (`src/content/legal/en.ts:10`) | `VOICE_COMMANDS.md:3, 59, 161, 171` | incomplete (WEB-1002) |
| Privacy §1: covers "invitations and recovery pages" (`legal en.ts:19`) | `Backend/docs/PASSWORD_RECOVERY.md:33-38`: the old page still serves old codes; recovery itself now happens in the app | true. ES/CA say «recuperación de acceso». |
| Privacy §1: automatic emails, password recovery included, come from noreply; replies go to support (`legal en.ts:21`) | `PASSWORD_RECOVERY.md` ("The email"); `Backend/core/email_delivery.py:142, 150` | true in the backend's working tree only. Reply-To is in another session's uncommitted work, not in HEAD (cf39f6e). Owner check below. |
| Privacy §2: password sign-ups confirm with a 6-digit code, 30 minutes (`legal en.ts:29`) | `EMAIL_VERIFICATION.md:3` | true |
| Privacy §2: voice data, "suggested tasks", project and member names (`legal en.ts:33`) | `VOICE_COMMANDS.md:7, 355` | the names are true; "suggested tasks" is incomplete (WEB-1002) |
| Privacy §3: the AI suggests titles, dates and priorities for your review (`legal en.ts:48`) | `VOICE_COMMANDS.md:8, 38` | true in substance; the list is short, left as is |
| Privacy §4: only the words are sent "to become tasks" (`legal en.ts:55`) | `VOICE_COMMANDS.md:3` | incomplete (WEB-1002) |
| Privacy §5: Resend sends recovery emails (`legal en.ts:82`) | `PASSWORD_RECOVERY.md` ("The email") | true |
| Privacy §7: email-confirmation and recovery codes expire after 30 minutes (`legal en.ts:126`) | `PASSWORD_RECOVERY.md:3, 35, 42` | true |
| Terms §5: check the AI's output before saving or sharing (`legal en.ts:239`) | `VOICE_COMMANDS.md:8` | true. It doesn't name voice changes to existing tasks, but isn't misleading. |
| Legal notice: automated messages come from noreply (`legal en.ts:320`) | CLAUDE.md, "Email" | true |
| Delete account §1: confirm with your password or Google (`legal en.ts:356`) | `DECISIONS.md:99` (UX-815) | true |

### Missing from the site (app features worth telling)
1. **Changing many tasks at once by voice, and marking a task done by voice.**
   - Sources: `.claude/ux-review/DECISIONS.md:5-20`; `Backend/docs/VOICE_COMMANDS.md:161-219`.
   - Where it belongs: the FAQ's voice answer, which WEB-1001 handles. Anything more prominent is Q1 below.
2. **Sharing a message into TaskFlow from another app (WhatsApp).** It opens a task with the message's day and time already read.
   - Sources: D3, `DECISIONS.md:50`; `App/lib/l10n/app_en.arb:404`.
   - Where it would belong: one clause in the FAQ's voice answer.
   - The owner's call. Recommendation: not now. The share sheet is a hard step for the Newcomer, and the site teaches one loop first (HE-11).
3. **The home-screen widget, «Dictate a task», and the launcher shortcuts.**
   - Sources: `DECISIONS.md:29-34`; `app_en.arb:404`.
   - Recommendation: not now; reconsider after launch.

### Keep (5 bullets at most)
- "TaskFlow shows the change first, and you can undo it" is still the app's exact promise, for one task and for a set (`VOICE_COMMANDS.md:8, 216`). Keep it in the rewrite.
- The legal lines about emailed codes (privacy §1, §2, §5 and §7) stay true now that recovery uses a 6-digit code valid for 30 minutes (`PASSWORD_RECOVERY.md:3`). No edit needed.
- Privacy §2's "relevant project/member names used to interpret a request" already covers what a bulk command sends. The model gets names, never tasks (`VOICE_COMMANDS.md:7`).
- Every button the site quotes still matches the app's strings in all three languages:
  - Add a task / Añadir tarea / Afegeix una tasca;
  - Done / Listo / Fet;
  - Continue with Google;
  - Share / Compartir / Comparteix;
  - Add a note / Añadir nota / Afegeix una nota.
- The Pro line ("unlimited dictation and file space") now reads like the app's own Pro screen (`billingIntro`, `app_en.arb:1974`).

### Questions for the owner (product decisions only)
- **WD? — Show "move all of yesterday's tasks to tomorrow" beyond the FAQ?** For example, one sentence on the "Say several things at once" card, or a second example under the hero.
  - For: it's the newest capability, the owner asked for it himself, and it's what a Comparer would switch for.
  - Against:
    - HE-11: the core loop comes first;
    - changes need tasks, which a first-time visitor doesn't have yet;
    - the app's /ux review of the bulk card is still running;
    - the live demo can't show it, because it only adds tasks.
  - Recommendation: not now. Keep only WEB-1001's FAQ line, and revisit after the app's review and the test with the owner's father.

**Owner checks** (not decisions, not findings):
- **Reply-To on automatic emails.** Privacy §1's "replies are directed to support" (`legal en.ts:21`) is true only in the backend's working tree (`Backend/core/email_delivery.py:142, 150`, another session's uncommitted work). HEAD has no Reply-To (see cf39f6e's message). It has to be committed and deployed with the site, or before it (WD13).
- **Weekdays in the live demo.** The app's server needed a calendar in its prompt to read «el viernes» and «esta semana» correctly (df1ccfa; "Dates" in `VOICE_COMMANDS.md`). The site's demo has its own prompt, which is outside this review's lane. Only the real AI can tell: try «el viernes a las 5» on the live demo.
- **The new legal version.** If WEB-1002 is fixed, sign off its new "In force since" date.

**Outside area F, for the organizer** (follow-ups to existing issues, not new findings):
- **WEB-707's follow-up is due.** `src/components/VoiceDemo.tsx` was committed in c888d10 (2026-10-21). But `src/components/HomePage.tsx:52-55` still wraps it in `<div lang="en" style="display:contents">`, with the old "until WP26–WP29" comment. Nothing is read in the wrong language, because the section's own `lang` wins. ISSUES.md already says to remove the wrapper and change `tests/ux-web-global.spec.ts:163-192` in the same commit.
- **The "Held" notes in ISSUES.md are stale.** c888d10 committed the other session's legal, content and VoiceDemo files, and TaskFlowWeb was clean when this run started.

### Memory notes
- **Claims map additions:**
  - **FAQ voice answer** (`src/content/site/en.ts:104`, `es.ts:104`, `ca.ts:110`) ↔ `VOICE_COMMANDS.md`, the "Bulk commands" section and the `complete` kind. After WEB-1001 it names move, change, complete and delete, and "all of yesterday's at once". Never quote the bulk card: its wording is under the app's review.
  - **Privacy lines on why words go to Google:** summary 02 (`legal en.ts:10`), §2's voice bullet (`:33`) and §4 (`:55`). Re-check them every time the app gains a voice capability.
  - **Calendar card's reminder clause** (`en.ts:61`) ↔ `App/lib/widgets/reminder_ask_sheet.dart:17-20`.
  - **Hero and link-preview images** ↔ the app's Calendar rows. The closest current app render is `App/build/ux/calendar/agenda.month-day-tapped.*` (a day other than today, week view). Batch b3 (2026-10-20) removed the "Any time" lines and "· 0 completed".
  - **Emailed codes:**
    - privacy §2 ↔ `EMAIL_VERIFICATION.md:3`;
    - §7 ↔ `PASSWORD_RECOVERY.md:3`;
    - §1's Reply-To ↔ `Backend/core/email_delivery.py`, uncommitted as of 2026-10-21.
  - **Widget and shortcuts:** the site never mentions them ("Dictate a task"), so nothing changes when they do.
- **Site state:**
  - c888d10 (2026-10-21) committed the other session's legal, content and VoiceDemo files, so "Held" no longer applies to them.
  - The `lang="en"` wrapper at `HomePage.tsx:52-55` remains (WEB-707's follow-up).
- **A new recurring problem type: the app's UX runs outdate the site** — through its screenshots, and through "only" claims that new features make too narrow. Technique that worked:
  - after `since --app`, grep the site for "only" / «solo» / «només» claims;
  - compare the hero PNGs with the app's current `App/build/ux/calendar/` renders;
  - check which app UX batch touched the file a claim rests on (`git log --since` on it).
- **Considered, not reported:**
  - terms §5's leftover jargon, "AI capture is optional", and its checklist, which doesn't name voice changes to existing tasks: candidates for a whole-site run;
  - privacy §3's short list;
  - the FAQ's account answer not naming «Continuar con mi correo»: its description is still true;
  - privacy §1 saying "recovery pages" in English but «recuperación de acceso» in Spanish and Catalan.
- **App-side, for /ux:** the app's own `capturePrivacy` (`app_en.arb:523`) also limits it to "AI task extraction ... sends your words to Google", and still uses the word "extraction".
- **Tools:** WSL was up on 2026-10-21, and `crop.mjs` worked.
