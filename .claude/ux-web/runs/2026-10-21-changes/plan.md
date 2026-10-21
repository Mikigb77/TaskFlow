# UX web loop run 2026-10-21-changes: plan

Re-planned on 2026-10-21 (evening), after you answered WD18 and WD19.

Nothing on the site is false, but this week's app changes left four lines behind, and you asked for two short additions. Five small packages fix and add them in English, Spanish and Catalan: WP53–WP56 as planned, and WP57 for your two answers.

The four lines left behind:
- the FAQ says voice changes one task at a time;
- the privacy summary says your words go to Google only to make tasks;
- the calendar card promises the reminder question at your first dated task;
- the hero and link-preview screenshots show two lines the app has removed.

Sources: `review-F.md` (one reviewer, area F), and your answers in `.claude/ux-web/DECISIONS.md` (2026-10-21, evening). Scoped run: the packages go straight to the implementers. Today is 2026-10-21.

## What changed since the first plan

- You answered WD18 «Yes, on the card» and WD19 «Yes, briefly», where I had recommended «not now». They're now findings WEB-1004 and WEB-1005, and one new package, WP57, builds both.
- WP57 runs right after WP53, because both change the home's copy files.
- WP53–WP56 keep their IDs and briefs.
- No question is open.

## Before the fix run

WP56 needs the app's Calendar re-rendered by the main session, because WD4 says the hero images come from the app and implementers never write in `App/`. In `App/`, once `git status --porcelain -- App/lib App/assets` is empty (if the app's /ux run on the bulk card is still editing `App/lib`, wait for its commit), run:

```
flutter test --no-pub --dart-define=WRITE_WEB_ASSETS=true test/ux_previews/website_assets_test.dart
```

Without that render, WP56 reports blocked and changes nothing. Until it's done, run the fix with `skip: [WP56]`.

## Your answers, and how WP57 carries them out

**WD18 → WEB-1004: changing many tasks at once, on the card.** My recommendation was «not now»; you said «Yes, on the card». One sentence goes at the end of the "Say several things at once" card:
- EN: "In the app, you can also move all of yesterday’s tasks to tomorrow by voice, or complete many at once."
- ES: «En la app, también puedes mover con la voz todas las tareas de ayer a mañana, o completar muchas a la vez.»
- CA: «A l’aplicació, també pots moure amb la veu totes les tasques d’ahir a demà, o completar-ne moltes alhora.»

How it follows your answer:
- Your example is there, written as what the app does, not in quotes. The card's link opens the live demo, which only adds tasks, and a visitor who said the command there would lose a try. "In the app" tells them so.
- "Complete" is the app's own word for "finish".
- The hero stays as it is, and the FAQ's voice answer (WP53) still names it too.

This has one effect on the layout. The calendar card sits beside the voice card and grows with it, so at large text sizes it would be left with an empty band under its drawing. WP57 lets the drawing reach the card's bottom edge, as it was designed to. Nothing else in the layout changes.

**WD19 → WEB-1005: the other ways in, briefly.** My recommendation was «not now»; you said «Yes, briefly». A new last question goes in the FAQ, after the notes question:
- EN: "Can I add tasks from my home screen or from WhatsApp?" — "Yes. Use the Dictate a task widget or shortcut, or share a message to TaskFlow from another app, such as WhatsApp."
- ES: «¿Puedo añadir tareas desde la pantalla de inicio o desde WhatsApp?» — «Sí. Usa el widget o el acceso directo Dictar una tarea, o comparte un mensaje con TaskFlow desde otra app, como WhatsApp.»
- CA: «Puc afegir tasques des de la pantalla d’inici o des de WhatsApp?» — «Sí. Fes servir el giny o la drecera Dicta una tasca, o comparteix un missatge amb TaskFlow des d’una altra aplicació, com WhatsApp.»

Why it has this shape:
- The names are the app's own in each language. The widget and the voice shortcut both say "Dictate a task" / «Dictar una tarea» / «Dicta una tasca».
- It's an FAQ answer rather than a line in the voice answer. WP53 pins that answer word for word, and sharing a message isn't voice.
- It comes last, because the first questions teach the main loop.
- It only names the three ways. It doesn't promise details, such as the day and time being read from the message, or what's free.

## Packages, in order

They run one at a time. WP53 and WP57 change the same files; the others touch different ones.

**WP53 · F · S · severity 2: Home copy. The voice answer names completing and changing many tasks at once; the reminder line drops "the first time".**
- **WEB-1001** (S2): the FAQ's voice answer changes from "move, change or delete a task" to "move, change, complete or delete tasks by voice, even all of yesterday's at once", and now ends "your words are sent to Google". It goes from 84 to 85 words; its longest sentence goes from 28 words to 24.
- **WEB-1003** (S1): the calendar card's reminder sentence becomes "TaskFlow can remind you of tasks with a date: it asks you once." The app asks only after a dated save whose reminder can still ring.

**WP57 · F · M · severity 2: Home. The voice card says voice can also move or complete many tasks at once; a last FAQ answer names the widget, the shortcut and sharing.**
- **WEB-1004** (S2, WD18): one sentence goes at the end of the "Say several things at once" card. The calendar card's drawing then reaches the card's bottom edge, so no card is left more than a quarter empty (WEB-705's rule).
- **WEB-1005** (S1, WD19): the FAQ's eighth and last question names the widget, the shortcut and sharing a WhatsApp message, in the app's words.

**WP54 · F · S · severity 2: Privacy. Your words go to Google to add, find or change tasks, not only to make them.**
- **WEB-1002** (S2), in four places:
  - summary 02 becomes "Your words go to Google's AI only when you ask TaskFlow to understand them: to add, find or change tasks.";
  - §2 says "suggested tasks and changes";
  - §4 drops "to become tasks";
  - §4's second paragraph says "suggested tasks and changes" too. This last one is my addition, on the same evidence, so §2 and §4 agree.

  The legal version moves to 2026-10-21 ("In force since 21 October 2026"), for your WD3 sign-off.

**WP55 · G · S · severity 2: Home. Remove the live demo's leftover English wrapper.**
- **WEB-707** (follow-up): c888d10 committed `VoiceDemo.tsx`, so the `lang="en"` wrapper and its "until WP26–WP29" comment (`HomePage.tsx:52-55`) can go now. The test that pins the wrapper changes in the same change, as the ledger asked. Meanwhile, nothing is read in the wrong language.

**WP56 · F · S · severity 1: Hero and link previews show the app's Calendar as it is today.**
- **WEB-5** (reopened, S1): the main session re-renders the six hero images from the app (see "Before the fix run"), and WP56 copies them in unchanged. The three link previews follow when the site is built. The new images no longer show «· 0 completadas» or «Sin hora».

## Skipped

None. All seven findings are fixes.

## Owner checks (not findings)

1. **Reply-To on automatic emails.** Privacy §1 says replies to automatic emails go to support.
   - That's true only in the backend's working tree (`Backend/core/email_delivery.py:142, 150`), which is another session's uncommitted work. HEAD has no Reply-To (cf39f6e).
   - It has to be committed and deployed with the site, or before it (WD13).
2. **Weekdays in the live demo.** The app's server needed a calendar of the coming days in its prompt to read «el viernes» and «esta semana» correctly (df1ccfa).
   - The demo's own prompt gives only today's full date, with its weekday (`src/lib/voice/model.ts:39-53`).
   - Only the real AI can tell: try «el viernes a las 5» on the live demo.
3. **The new legal version.** After WP54, sign off "In force since 21 October 2026" and the new summary 02 (WD3).
4. **Native Catalan reads:** WP53's two lines, WP54's three and WP57's three, listed in each package's device checks.
5. **The other ways in, on a real phone (WP57):**
   - the widget picker lists «Dictar una tarea»;
   - touching and holding the TaskFlow icon shows the same shortcut;
   - WhatsApp's share sheet offers TaskFlow, and sharing a message opens TaskFlow with it.

   The app's loop has seen the widget and the shortcuts only on an emulator.
6. **A move command in the live demo (WP57).** With the real AI, say «mueve todas las tareas de ayer a mañana» to the live demo, which only adds tasks. If it makes a task out of the command, have a look: the card's new sentence sits just above the link to the demo.

## For the app's /ux loop (not this run)

- The app's own `capturePrivacy` string (`App/lib/l10n/app_en.arb:523`, `app_es.arb:306`, `app_ca.arb:285`) still says "AI task extraction … sends your words to Google". "Extraction" is jargon, and dictation now also finds and changes tasks.
- The Spanish help for the widget (`homeCaptureInstructions` in `app_es.arb`) calls it «el widget de micrófono». The widget itself, and the English and Catalan help, call it «Dictar una tarea», "the Dictate a task widget" and «el giny Dicta una tasca». The site follows the widget's own label.

## For the verifiers

- WP57 invites people to share a message that someone else may have written. With Pro, the assistant reads a shared message for tasks (`App/lib/services/capture_store.dart:128-130`, `capture_processor.dart:216-236`), so its text goes to Google's AI like typed words.
- Privacy §2 and §4 cover "submitted recordings/text". WP54's summary 02 says "Your words go to Google's AI only when you ask TaskFlow to understand them".
- The verifier should judge whether that summary still reads as true for a shared message. WP54 keeps its brief, and nothing is planned on it.

## Ledger

- New lines: WEB-1004 and WEB-1005, open, for WP57. Before your answers, WD18 and WD19 had no findings.
- From the first plan: WEB-1001, WEB-1002 and WEB-1003 are open; WEB-5 and WEB-707 moved from Device check to Open for this run.
- Considered by review F and not reported, for the next whole-site run:
  - terms §5's leftover jargon;
  - privacy §3's short list;
  - the account answer not naming «Continuar con mi correo»;
  - privacy §1's "recovery pages" against «recuperación de acceso».
- The ledger's "Held" notes predate c888d10, which committed those files. They are history now.
