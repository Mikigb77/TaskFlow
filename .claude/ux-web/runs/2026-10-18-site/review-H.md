## UX web review — Area H: home, hero, demos and calls to action (`/`) — 2026-10-18

**Verdict:** Don't ship. From the first screen a newcomer can't tell what TaskFlow is or that it isn't out yet. The page is English-only, and every main button leads back to a sample form.

**Walked:**
- **Newcomer.** Phone (390 × 664 render; 320 px from the code), light and dark. There is no Spanish page, so I walked the English one. 10 steps:
  1. The WhatsApp preview.
  2. The hero.
  3. The "at a glance" bar.
  4. The feature cards.
  5. The live demo, in every state: intro, connecting, capture, recording, microphone denied, recorded, waiting, timeout, result, no tasks, tries used, budget pause, network limit.
  6. The sample walkthrough: examples, editing, saved, no JavaScript.
  7. The appearance section.
  8. The FAQ.
  9. The closing card.
  10. The menu's "Get TaskFlow".
- **Comparer.** Desktop 1440 × 1000, English, light and dark. 6 steps: header "Explore the app", then the walkthrough, then the nav's "Try voice", then the live demo, then the FAQ, then the closing card.
- **Assistive-technology user**, from the code. 5 steps: skip link, H1, the hero's reading order, the live demo by keyboard and screen reader (focus moves, live regions, the timer), then 200% text and reduced motion.
- **Leaver.** Outside this area (L/G). The home footer's "Delete account" is reached after about 11 phone screens.
- **Evidence:**
  - Renders: `home.en.{desktop,mobile}.{light,dark}.{fold,full}.png`, crops of each screen, and `opengraph-image.png`. All were rendered at 19:24 on 2026-10-18, after every source file was last changed.
  - App renders: `App/build/*.png`, 18:59–19:16 on 2026-10-18.
  - Demo states beyond the intro aren't rendered, so they're reasoned from the code.
  - I didn't call the live demo's API (budget rule).

**Numbers:**
- **First viewport:**
  - Desktop: about 104 words. Two filled buttons ("Explore the app", "See it in action"), one text link and 4 nav links.
  - Phone: about 56 words, one filled button and one text link.
  - Words that say what TaskFlow is (app, Android, task, calendar, voice) in the hero text: **0** on the phone; **1** on desktop ("calendar", in the 11 px bar at y≈847). After WEB-1: the H1 and subheadline say it in about 45 words, with 1 filled button.
- **Phone scrolling:**
  - First call to action: 0 screens.
  - The honest "not yet":
    - The launch note at y≈7450 of 7981 is **about 11 screens** down.
    - The closed FAQ item at y≈6546 is 10 screens down.
    - After WEB-3: 0.
  - The live demo: about 4.6 screens down (eyebrow at y≈3084). After WEB-10: about 1.6.
- **Calls to action:**
  - 4 labels: "Explore the app ↗", "See it in action", "Give it a try" and "Find your flow".
  - 3 of them go to `#demo`, the sample form.
  - None leads to the app or to the "not yet".
  - After WEB-4: 1 label, 1 destination (`#voice`), with the status line beside it.
- **Live demo, taps from the intro to a result:** 4, plus the microphone prompt and possibly a Cloudflare tap. After WEB-9: 2, plus the prompt. The app also takes 2: «Añadir tarea», then «Listo».
- **Type:**
  - **79** `font-size` declarations under 12 px in the hero, demos, appearance and closing card (100 site-wide).
  - The smallest is 5 px. Body text is 15 px.
- **Copy:**
  - "little" appears **26 times**: 13 on the page, 5 in VoiceDemo, 5 in TaskDemo, 3 in the footer.
  - Headings-only test: **0 of 13** headings mention Android, getting the app or price; 3 hint at what it does.
- **Claims:** 26 checked: 16 true, **2 false**, **7 outdated**, 1 unverifiable.

**Attention** (predicted from the renders, not measured; GUIDELINES §21.4):
- **`home.en.mobile.light.fold.png`:**
  1. The H1 "Make room for a clearer day." (42 px, top half, y≈157–240).
  2. "See it in action": the only filled control, in the middle band (y≈366–415).
  3. The grey 13 px subheadline, or the logo.

  The phone screenshot and the "JUST SAY THE WORD — 'A walk at six.'" card compete, but they sit in the bottom third, which gets about 14% of gaze (Lagun 2014). The 8 px eyebrow and the 10 px footnote are effectively unseen. Missing from the first three: what TaskFlow is, "Android", and that it isn't out yet.
- **`home.en.mobile.dark.fold.png`:** the same order. The mint button stands out even more. The same gaps.
- **`home.en.desktop.light.fold.png`:**
  1. The H1 (77 px, top-left quadrant).
  2. "See it in action": filled, left half, isolated. It competes with the phone screenshot, the largest image, but that sits in the right half, which gets its first look after 2–3 s (Buscher 2009).
  3. "Explore the app": a second filled button, top right. It competes with the primary action for the same destination (CT-1).

  The only voice hint (a 7–12 px card) and the 11 px bar are likely skipped.
- **`home.en.desktop.dark.fold.png`:** the same, but both buttons are equally bright mint fills, so the competition is stronger.
- **Five-second answers** (GUIDELINES §21.5), the same on all four renders:
  - Q1, what is it: "a calm planner? a calendar?" Fails the competitor test.
  - Q2, what does it do for me: "a clearer day". Vague.
  - Q3, who for and which phone: nothing.
  - Q4, what would I tap: "See it in action", which leads to a sample form.
  - Q5, what did I notice first: the H1.
  - Q6, unknown words: none in the first viewport.

  **Fail.**

### Findings (most severe first)

**WEB-1 · Severity 4 · The hero never says what TaskFlow is**
- **Where:** `src/app/page.tsx:41-127`: eyebrow :43-45, H1 :46-61, subheadline :62-66, footnote :78-83, hero art :85-126. `/`, English, phone and desktop, light and dark. Renders `home.en.{mobile,desktop}.{light,dark}.fold.png`.
- **The moment:** "Make room for a clearer day… Is this a calendar? A wellness thing? Is it an app? For my phone?"
- **What happens:**
  - The first viewport's words are "A LITTLE FOCUS. A LITTLE FLOW. / Make room for a clearer day. / Big plans. Small reminders. All the things in between. Bring them together in one calm space, and get back to living. / Less organizing. More getting on with your day."
  - None of them says app, phone, Android, task, calendar or voice: 0 of 56 words on the phone fold.
  - The only sign that you speak to it is a floating card with 6–10 px text, in the phone fold's bottom third.
  - The page's 13 headings, read alone, never say it's for Android or how to get it.
- **Why it fails:**
  - HE-1: say what it does in everyday words. On the competitor test, "Make room for a clearer day" fits any planner, a cleaning service or a meditation app.
  - HE-2 and HE-3: clear beats clever. Promotional wording cost 27% in usability (Morkes 1997).
  - HE-6.
  - AT-1 and AT-7: the value must land in the static first viewport (Liu 2010; Nielsen 2011d).
  - SC-1: the headings-only test.
  - FN-2 and FN-3: the app's own sign-in line already says it plainly (`authPitch`, `App/lib/l10n/app_en.arb:674`).
- **Fix:** replace, don't add.
  1. **Remove** the eyebrow (:43-45), the footnote (:78-83), the stage caption (:94), the "Make a little time for you" card (:111-122) and the art label (:123-125).
  2. **H1:**
     - EN "Say it, and it’s on your calendar."
     - ES «Dilo y ya está en tu calendario.»
     - CA «Digues-ho i ja és al teu calendari.»
  3. **Subheadline:**
     - EN "Tap one button and say what you need to do, even several things at once. TaskFlow puts each one on the day you say and can remind you before it. An app for Android phones."
     - ES «Toca un botón y di lo que tienes que hacer, aunque sean varias cosas a la vez. TaskFlow pone cada una en el día que digas y puede avisarte antes. Una app para móviles Android.»
     - CA «Toca un botó i digues el que has de fer, encara que siguin diverses coses alhora. TaskFlow posa cada una el dia que diguis i et pot avisar abans. Una aplicació per a mòbils Android.»
  4. **The voice card** (:96-109) keeps its place but shows the app's own teaching example (`calendarTrySaying`, `app_es.arb:221`), next to a screenshot of the two tasks it becomes (WEB-5):
     - EN "Tomorrow, call the dentist and buy bread."
     - ES «Mañana, llamar al dentista y comprar pan.»
     - CA «Demà, trucar al dentista i comprar pa.»
  5. **The footnote's slot** takes the availability line (WEB-3). The `<title>` and the link preview follow the new H1 (area G).
- **Verify:**
  - Re-render the four fold renders and answer the five-second questions from the H1 and subheadline alone: Q1–Q3 must be right.
  - Playwright: the `h1` contains "calendar" / «calendario» / «calendari»; `.hero` contains "Android"; no `.hero` text matches /a little/i.
- **Evidence:** verified in code; seen in current renders.

**WEB-2 · Severity 3 · Home, hero and demos exist only in English**
- **Where:**
  - Every string in `src/app/page.tsx`, `src/components/VoiceDemo.tsx` and `TaskDemo.tsx`.
  - Alt text: `src/components/Phone.tsx:2-8`.
  - `public/images/*.png`: an English app UI.
  - The demo's server messages, shown on the page, e.g. `src/lib/voice/policy.ts:73,80,87`.
  - `src/app/layout.tsx:43`: `lang="en"`. This file holds the other session's uncommitted edits.
  - There's no `/es/` or `/ca/` home (`artifacts/ux-web/INDEX.md:31`).
- **The moment:** the Spanish newcomer, 60+, from WhatsApp: «Está todo en inglés. Esto no es para mí.»
- **What happens:**
  - The journey "first visit on a phone in Spanish" fails at step 1.
  - The legal pages have `/es/` and `/ca/`, but the way home leads to English.
  - In the live demo, titles come back in the visitor's language, because the model keeps it. Dates follow the browser's locale (`toLocaleDateString(undefined…)`, VoiceDemo.tsx:17, :822). Every label, hint and error stays English, so the result mixes languages.
- **Why it fails:**
  - ML-5: 76% prefer their own language and 40% never buy in another (CSA 2020).
  - ML-6.
  - Lens G: every string in all three languages.
  - The owner's brief: the site's copy in EN, ES and CA (`.claude/ux-web/DECISIONS.md:21`).
  - On the reviewer's scale, an entry page that isn't in the newcomer's language is Severity 3.
- **Fix:**
  - Build `/es/` and `/ca/` homes from one copy table, as the legal pages do with `src/content/legal/{en,es,ca}.ts`. Use the copy given in WEB-1, 3, 4, 7, 9, 12 and 14.
  - Format demo dates in the page's language, not the browser's.
  - Map the API's error `code`s on the page (VoiceDemo.tsx:288-293: `visitor_limit`, `network_limit`, `budget_pause`, `processing`, `unavailable`, …) to translated messages, falling back to the server's text. No server change is needed.
  - Routing, `hreflang` and the switcher belong to area G.
- **Verify:**
  - `home.es.*` and `home.ca.*` renders exist.
  - On `/es/` and `/ca/`, a scan of `main` finds no words from an English stop-list ("the", "your", "and", "demo").
  - A mocked `visitor_limit` shows the Spanish message on `/es/`.
  - A native speaker reads the Catalan.
- **Evidence:** verified in code and INDEX.md.

**WEB-3 · Severity 3 · Nothing near a button says the app isn't out**
- **Where:**
  - Hero: `src/app/page.tsx:67-83`.
  - Closing card: :399-428. The note at :422-425 is 10 px (`global.css:1398-1407, 2302-2306`).
  - FAQ: :7-8, closed by default.
  - Menu: `src/components/Header.tsx:62-64`.
  - Renders: `home.en.mobile.light.full.png` (note at y≈7450 of 7981) and `home.en.desktop.light.full.png` (y≈5814).
- **The moment:** "It looks nice. Where do I get it? Is it on the Play Store?"
- **What happens:**
  - The only plain statement that TaskFlow can't be installed yet is a 10 px line under the very last button: "Android app in development · Public download coming soon". It's about 11 phone screens down.
  - The other is a closed FAQ item, 10 screens down.
  - The menu's "Get TaskFlow" jumps to that card, whose button ("Find your flow") sends the visitor back up to the sample form.
  - By the end of the second phone screen, the visitor hasn't read that it's for Android, that it isn't out, or what's free.
- **Why it fails:**
  - AT-1 and AT-6: the next step, "Android" and how to get it, within two phone screens.
  - AP-5: before launch, plain text, no badge.
  - AP-7: "for Android" next to the primary action.
  - CT-4: the menu item's promise isn't kept.
  - TR-2: disclose up front.
  - Lens C: calls to action are honest about what happens next.
- **Fix:** one sentence, the same words everywhere, and no Google artwork.
  1. **Under the hero button**, in the footnote's place:
     - EN "Coming soon to Google Play. You can’t download it yet."
     - ES «Muy pronto en Google Play. Todavía no se puede descargar.»
     - CA «Molt aviat a Google Play. Encara no es pot descarregar.»
  2. **The closing card** (:404-427) makes this its message.
     - H2:
       - EN "Coming soon to Android."
       - ES «Muy pronto en Android.»
       - CA «Molt aviat a Android.»
     - Paragraph:
       - EN "TaskFlow isn’t on Google Play yet. Until then, you can try it with your voice on this page."
       - ES «TaskFlow todavía no está en Google Play. Mientras tanto, puedes probarlo con tu voz en esta página.»
       - CA «TaskFlow encara no és a Google Play. Mentrestant, el pots provar amb la teva veu en aquesta pàgina.»
     - Delete the eyebrow (:408), the old H2 (:409-413), the "next chapter" line (:414-418) and the 10 px note (:422-425).
  3. **The menu item** "Get TaskFlow" becomes, with the same target:
     - EN "Download: coming soon"
     - ES «Descarga: muy pronto»
     - CA «Descàrrega: molt aviat»
  4. **The demo's ending** says it too (WEB-7).
- **Verify:**
  - On the 390 × 664 fold render, the status line is fully visible.
  - On the full mobile render, it appears above y = 1328.
  - Playwright: no `play.google.com` link exists.
- **Evidence:** verified in code; seen in current renders.

**WEB-4 · Severity 3 · Every call to action loops back to a sample form**
- **Where:**
  - Header: `src/components/Header.tsx:48-50`, "Explore the app" with the ↗ icon (`Icon.tsx:4`).
  - Hero: `src/app/page.tsx:68-76`.
  - Closing: :419-421.
  - Features link: :235-237.
  - `src/styles/voice.css:3`.
  - Renders: `home.en.desktop.{light,dark}.fold.png`.
- **The moment:** "Explore the app ↗… oh, it's a form on the website. Is this the app?" And at the end: "Find your flow… it took me back up."
- **What happens:**
  - There are 4 calls to action with 4 labels.
  - Three of them ("Explore the app", "See it in action", "Find your flow") go to `#demo`, a sample form with fixed September examples. They skip the real live demo (`#voice`) above it.
  - The ↗ icon reads as "opens the app or a store".
  - On desktop, two filled buttons share the first viewport and go to the same place.
  - The closing button sends the visitor about 5 screens back up.
  - Landing on `#voice` from "Try voice" puts the section 170 px below the top: 90 px of root `scroll-padding-top` plus 80 px of `scroll-margin-top` on the section. On a phone, "Try the live demo" lands just below the fold (button at y≈3585, viewport bottom at y≈3507).
- **Why it fails:** CT-1, CT-3 (the labels don't name what happens), CT-4 (the destination doesn't keep the promise), CT-11, NV-4, AP-13.
- **Fix:** one primary action, one label, one destination.
  1. **The hero button, the closing button and the features link** all become the same label, going to `#voice`:
     - EN "Try it with your voice"
     - ES «Pruébalo con tu voz»
     - CA «Prova-ho amb la teva veu»
  2. **The hero's secondary link** "Meet TaskFlow" becomes, still going to `#features`:
     - EN "See what it does"
     - ES «Mira lo que hace»
     - CA «Mira què fa»
  3. **Remove the header button** (Header.tsx:48-50). The nav keeps "Try voice", and the desktop fold drops to one filled button. The header is area G's.
  4. **Delete `scroll-margin-top: 80px`** (voice.css:3); the root padding already clears the header. Put the demo's first control at the top of its panel (WEB-16).
  5. **If WEB-6 removes `#demo`**, repoint "How it works" (Header.tsx:9) and the footer's "Try the demo" (Footer.tsx:22). Footer.tsx holds the other session's uncommitted edits right next to line 22, so that hunk may not separate.
- **Verify:**
  - Playwright: every link with the primary label ends in `#voice`, and the desktop fold has one filled `.button`.
  - After the hero click on the mobile project, the demo's first button is `toBeInViewport()`.
  - Update `tests/website.spec.ts:19-20`.
- **Evidence:** verified in code; the fold renders show both filled buttons. The below-fold landing is computed from the CSS and the full render, and needs a browser check.

**WEB-5 · Severity 3 · Hero and appearance screenshots show the old app**
- **Where:**
  - `public/images/agenda-{light,dark}.png` and `tasks-{light,dark}.png`, all from 2026-09-21.
  - `src/components/Phone.tsx:2-8, 22-38`; `src/app/page.tsx:110, :327`.
  - Compare with `App/build/calendar-es-1.3x-light.png`, `review-batch-light.png` and `capture-fill-by-hand-es.png`, all from 2026-10-18.
- **The moment** (after installing): "The website showed a microphone and a New task button. Where are they?"
- **What happens:**
  - The hero phone shows an old version of the app:
    - a separate microphone button beside "+ New task";
    - three tabs: Calendar, Tasks, Settings;
    - a moon switch in the app bar;
    - an "A LITTLE FOCUS. A LITTLE FLOW." eyebrow and a "Your calendar" heading.
  - Today's app is different:
    - one button, «Añadir tarea» with a microphone: the north star;
    - four tabs: Calendario, Tareas, Notas, Ajustes;
    - no switch in the app bar, since D5 moved it to Ajustes › Apariencia (`.claude/ux-review/DECISIONS.md:131`);
    - a week strip with «Semana ▾».
  - The screenshots are in English, while the newcomer will see Spanish.
  - The tasks shown have nothing to do with what the hero card says.
  - The unused `calendar-*.png` ship too.
- **Why it fails:**
  - HE-5 and FN-3: the real, current app, in the page's language; what the site shows first is what the app shows first.
  - HE-4: one input and the task it becomes.
  - AP-12.
  - TR-3: outdated screenshots are trust bugs.
- **Fix:**
  - **Replace the hero images** with current app renders, one per page language and theme. Show the result sheet for the app's own example:

    | | Said | Heading | Button |
    |---|---|---|---|
    | ES | «Mañana, llamar al dentista y comprar pan» | «2 cosas para añadir» | «Añadir 2 tareas» |
    | EN | "Tomorrow, call the dentist and buy bread" | "2 things to add" | "Add 2 tasks" |
    | CA | «Demà, trucar al dentista i comprar pa» | «2 coses per afegir» | «Afegeix 2 tasques» |

  - **Alt text** says what the image shows, for example EN "TaskFlow on an Android phone: after saying “Tomorrow, call the dentist and buy bread”, two tasks for tomorrow are ready to add." The same in ES and CA.
  - **Delete `calendar-*.png`.** The `tasks-*` pair goes with WEB-17.
  - **New renders are needed:** today's `App/build` renders hold test text, so they need fresh app previews with chosen text. That may be a main-session step outside the web loop.
- **Verify:**
  - Side by side with the app's renders: the same bottom bar, single button and labels.
  - Playwright: the `.hero-phone img` alt mentions "dentist" / «dentista» in each language.
- **Evidence:** verified by comparing the images with the app's current renders.

**WEB-6 · Severity 3 · The sample walkthrough teaches a form, not the app**
- **Where:** all of `src/components/TaskDemo.tsx`; `src/app/page.tsx:287-318`; `src/styles/global.css:892-1191` and its responsive blocks. Renders: desktop full screen 4, mobile full screens 7–8.
- **The moment:** under "No perfect wording. No field-by-field thinking.": "So I fill in a title, date, time, priority and a note? That's what I do now." Then they tap the green microphone, and nothing happens.
- **What happens:**
  - Three of the four calls to action land here (WEB-4).
  - It's an editable form with 5 fields: Task title, Date, Time, Priority and A note for later. "Add to my preview" leads to a fake saved task you can tick: a copy of the app's editor and list.
  - The examples are one task each, dated 21–25 September 2026, which is now past, and the copy says "a sample week in September 2026".
  - A filled, 50 px green microphone, a waveform and "0:08" (TaskDemo.tsx:137-161) look like a recorder and do nothing.
  - The app's real result shows the title, the date as its main line, the notes and «Más opciones», and takes one «Añadir al calendario» tap (`App/build/review-direct-light.png`).
- **Why it fails:**
  - AP-13, and the owner's rule: a demo is a taste, never a replacement (`.claude/ux-web/DECISIONS.md:11`).
  - FN-3 and FN-4: the demo's steps should match the app's loop.
  - HE-11.
  - TR-3: stale dates.
  - The speed bar: as little interaction as possible beyond speaking (`.claude/ux-review/DECISIONS.md:66-72`).
- **Fix:** subtract.
  1. **Remove the section**, `TaskDemo.tsx` and its CSS.
  2. **Add a static example** inside the live demo's intro, laid out as the app shows it, with no inputs: the spoken line from WEB-5 and its two cards (title + «mañana»). It shows without JavaScript and whenever the live demo can't run, so it takes over the walkthrough's "always available" role.
  3. **Re-point four visitor-facing messages** that mention "the sample walkthrough" to the example: VoiceDemo.tsx:828; `policy.ts:87`; `security.ts:18, :101`. Change only the strings.
  4. **Move** the useful sentence of the `<noscript>` (page.tsx:310-316) there.
  5. **Update the tests:** `tests/website.spec.ts:19-34, :96-107, :194` and `tests/voice.spec.ts:214, :236`.
- **Verify:**
  - No `#demo` in the DOM.
  - With `javaScriptEnabled: false`, the static example renders.
  - axe passes on both projects.
- **Evidence:** verified in code; seen in current renders.

**WEB-7 · Severity 3 · The live demo ends in a toy list, not the app**
- **Where:** `src/components/VoiceDemo.tsx:606-830`:
  - results: :606-817;
  - the preview list: :636-661;
  - the edit forms: :696-768;
  - "Add to preview list": :772-776;
  - the actions: :779-807;
  - tries used: :818-830.
- **The moment:** after 3 tries, at peak interest: "Great, it worked! So how do I get this? It says my 'allowance returns' tomorrow."
- **What happens:**
  - After a result, the visitor can edit each draft in a 5-field form, add it to a "preview list" and tick tasks off ("Try checking one off. That’s one less thing on your mind."): a small task manager.
  - Nothing says this is what the app does, that it's coming to Android, or what the app gives.
  - When the 3 tries are used, the page offers only: "Your allowance returns {time}. The sample walkthrough below is always available."
- **Why it fails:**
  - AP-13: after a result, the next step or the honest "not yet" is in view.
  - Lens D: each stage hands over to the next.
  - The owner's rule: teach, don't replicate.
  - Lens B: end on "I want this on my phone".
  - FN-5.
- **Fix:** end at the result, then hand over.
  1. **Remove** the preview list and ticking (the saved branch at :611-627, :636-661 and :780-786), the per-task edit forms (:696-768) and "Add to preview list" (:772-776).
  2. **Show each task as the app does:** the title, then the date and time as one line, then the notes, under the app's heading (WEB-9).
  3. **Below the tasks, one block:**
     - EN "In the app: tap Add a task, say it, then tap Add to calendar. Coming soon to Google Play."
     - ES «En la app: toca Añadir tarea, dilo y toca Añadir al calendario. Muy pronto en Google Play.»
     - CA «A l’aplicació: toca Afegeix una tasca, digues-ho i toca Afegeix al calendari. Molt aviat a Google Play.»

     Then "Say it again" and the collapsed "See what I said".
  4. **Tries used** (:818-830), followed by the same block:
     - EN "You’ve used today’s 3 tries. You can try again on {weekday} at {time}."
     - ES «Ya has usado los 3 intentos de hoy. Podrás volver a probar el {día} a las {hora}.»
     - CA «Ja has fet servir els 3 intents d’avui. Hi podràs tornar a provar {dia} a les {hora}.»
  5. **If area F agrees** the free tier may be stated, add after the block. It's true on `dev` (`.claude/ux-review/DECISIONS.md:15-24`; `freeVoiceNoticeBody`, `app_en.arb:1971`):
     - EN "In the app you get 10 free dictations a month, and you can add tasks by hand any time."
     - ES «En la app tienes 10 dictados gratis al mes y puedes añadir tareas a mano cuando quieras.»
     - CA «A l’aplicació tens 10 dictats gratuïts al mes i pots afegir tasques a mà sempre que vulguis.»
- **Verify:**
  - With a mocked API, after a result, `#voice` contains "Google Play" and no "Add to preview list" button.
  - With `remaining: 0`, both lines are visible.
  - Update `tests/voice.spec.ts:122-160`.
- **Evidence:** verified in code. These states aren't rendered, and the API wasn't called.

**WEB-8 · Severity 3 · Text in hero, demos and closing card is tiny**
- **Where:** `src/styles/global.css` and `src/styles/voice.css`. Renders: `home.en.mobile.light.fold.png` and the full renders.
- **The moment:** the newcomer, who reads larger text, squints at the grey 13 px subheadline and can't read the 8 px bar or the 10 px "coming soon" line.
- **What happens:**
  - Body text is 15 px (global.css:59).
  - The hero, demos, appearance and closing card have 79 `font-size` declarations under 12 px, the smallest 5 px.
  - On a phone (≤ 580 px):

    | Element | Size | Line |
    |---|---|---|
    | Hero eyebrow | 8 px | :1983 |
    | Subheadline | 13 px | :1997 |
    | Primary button label | 11 px | :2014 |
    | "Meet TaskFlow" | 10 px | :2009 |
    | Footnote | 10 px | :2020 |
    | Floating cards | 6–10 px | :2047-2062 |
    | Art label | 6 px | :2066 |
    | Bar | 8 px; 7 px at ≤ 360 | :2074, :2371 |
    | Closing eyebrow | 6 px | :2289 |
    | Closing paragraph | 11 px | :2297 |
    | Closing button | 11 px | :1395 |
    | Launch note | 10 px | :2303 |
    | Walkthrough text | 6–11 px | :2151, :2188 |
    | Demo card labels | 11 px | voice.css:116, :357 |
    | Appearance tag (≤ 800 px) | 5 px | :1910 |

  - Everything is in px, so a browser's default-font-size setting doesn't enlarge it.
- **Why it fails:**
  - RD-5: body ≥ 16 CSS px in rem or em; small print ≥ 12 px.
  - CT-7: the primary label holds at 200% in Spanish and Catalan.
  - OL-1: tiny type is older adults' recurring problem (Nielsen 2013; Kane 2019).
  - Lens J.
- **Fix:**
  - In these sections: body and subheadline 18 px on phones (16 px at the least), button labels 16 px or more, small print 14 px or more, nothing under 12 px. Use `rem`.
  - Most of the smallest text disappears with WEB-1, 3, 6, 11 and 17 (eyebrows, floating cards, bar, walkthrough, appearance tag). Size what remains.
  - Text contrast already passes (see Keep).
- **Verify:**
  - Playwright on both projects: every visible text node in `.hero`, `#voice` and `.closing-card` is 12 px or more, `p` is 16 px or more, and the hero subheadline is 18 px or more at 390 px.
  - A real phone at arm's length.
- **Evidence:** verified in code (the CSS values); seen in renders.

**WEB-9 · Severity 2 · Live demo: twice the app's taps, different words**
- **Where:** `src/components/VoiceDemo.tsx`:
  - Turnstile, rendered without an `appearance` option: :36-102.
  - Intro: :380-398.
  - Capture: :469-605.
  - Mode switch: :483-507.
  - Listen back: :541-556.
  - "Create drafts": :585-596.
  - Labels: :15-24, :609-627, :673-678, :808-811.
- **The moment:** "Record, stop, listen, wait for the security box, Create drafts… is the app slower than this?"
- **What happens:** from the intro to a result takes 4 taps ("Try the live demo", the microphone, stop, "Create drafts"), plus the browser's microphone prompt and Cloudflare's visible check box. The box is about 300 px wide and pokes out of the card at 320 px. The app takes 2 taps: «Añadir tarea», «Listo». The words differ at every step:

  | Site today | App: EN · ES · CA (ARB key) |
  |---|---|
  | Create drafts / stop | Done · Listo · Fet (`done`, en:842) |
  | Making a little clarity… | Understanding… · Entendiendo… · Entenent… (`captureUnderstanding`) |
  | Recording · 12s / 60s | Listening · 0:12 · Escuchando · 0:12 · S’està escoltant · 0:12 (`listeningSeconds`) |
  | 2 drafts, ready for you. | 2 things to add · 2 cosas para añadir · 2 coses per afegir (`captureThingsToAdd`) |
  | Whenever you’re ready | No date · Sin fecha · Sense data (`noDate`) |
  | Your transcript | See what I said · Ver lo que dije · Mostra què he dit (`reviewOriginal`) |
  | Try a new thought / Edit original thought | Say it again · Volver a decirlo · Torna-ho a dir (`captureSayAgain`) |
  | Type it instead | Type instead · Escribir · Escriu (`captureTypeInstead`) |
  | Getting your demo ready… | One moment… · Un momento… · Un moment… (`captureStarting`) |

  Each card also carries "Task N" and a priority chip, which the app's result doesn't show.
- **Why it fails:**
  - FN-2: the app's names, so visitors recognise them after installing.
  - FN-3.
  - The owner's speed bar (`.claude/ux-review/DECISIONS.md:66-72`).
  - CT-11.
  - AP-13.
- **Fix:**
  1. Use the app strings in the table.
  2. One tap starts listening, and «Done / Listo / Fet» stops and sends.
     - Remove the listen-back stage: "Ready when you are." (:473-480), the player and "Record again" (:541-556).
     - "Say it again" on the result records again.
     - The 3-try cap holds either way.
  3. Replace the two-button switch (:483-507) with the microphone by default and a "Type instead" link, like the app's keyboard option.
  4. Render Turnstile with `appearance: "interaction-only"`, so the box shows only when Cloudflare needs a tap. This is Cloudflare's render option; I didn't fetch its docs, so confirm there.
  5. Drop "Task N" and the priority chip (:672-679).
  6. Change the intro's privacy line to the new button name: "only when you tap Done". That line (:393-397) sits next to the other session's uncommitted link change at :396, so the hunk may stay uncommitted.
- **Verify:**
  - With a mocked API, a result appears after exactly 2 clicks once the demo is open.
  - Every label matches the table.
  - No visible `.voice-verification` box with Turnstile's always-pass test key.
  - At 320 px, nothing is wider than the panel.
- **Evidence:** verified in code against `App/build/capture-listening-es-2x.png`, `review-batch-light.png` and the ARB files. Turnstile's look needs a browser check.

**WEB-10 · Severity 2 · The proof sits 4½ phone screens below the hero**
- **Where:** `src/app/page.tsx:286`: `<VoiceDemo />` comes after `#features` (:144-284). Render `home.en.mobile.light.full.png`: the voice eyebrow is at y≈3084, screen 5.6 of 12. On desktop it's at y≈2220.
- **The moment:** a scroller (most visitors) passes a mock calendar and a microphone drawing before seeing anything real.
- **What happens:** between the hero and the live demo sit the bar and four feature cards. Their pictures are drawings ("A good week ahead", circles around a microphone), not the app.
- **Why it fails:**
  - AT-4: no screenful of decoration between the hero and the first proof.
  - AT-6.
  - HE-11: the core loop first.
  - EY-3.
- **Fix:** move `<VoiceDemo />` (:286) to directly after the hero (after :127; the bar goes with WEB-11). Nothing is added; area F's features follow it.
- **Verify:** on the new full mobile render, `#voice` starts above y = 1328. In the DOM, `#voice` comes before `#features`.
- **Evidence:** verified in code and the full renders.

**WEB-11 · Severity 2 · The "at a glance" bar says nothing concrete**
- **Where:** `src/app/page.tsx:129-142`; `global.css:607-627, 1601-1604, 1773-1781, 2068-2080, 2370-2372`. Renders: desktop fold y≈847, mobile screen 2.
- **The moment:** "A calmer kind of productive… what does it actually do?"
- **What happens:** four slogans ("A clearer calendar", "Your words, into action", "Every detail, together", "A calmer kind of productive") in muted text: 8 px on phones, 7 px at 320–360 px.
- **Why it fails:** AT-6, RD-1, HE-3, SC-6 (facts as digits), EY-5 (strip-shaped elements get skipped), RD-5.
- **Fix:**
  - Remove the bar. WEB-1 and WEB-3 put what it is, "Android" and "coming soon" in the hero.
  - If area F wants the free tier near the top, this strip is its place, at 14 px or more, instead of a new section:
    - EN "Free: 10 dictations a month"
    - ES «Gratis: 10 dictados al mes»
    - CA «Gratuït: 10 dictats al mes»
- **Verify:** no `.promise-bar`, or each of its items holds a digit or "Android".
- **Evidence:** verified in code; seen in renders.

**WEB-12 · Severity 2 · Demo copy uses jargon a newcomer can't parse**
- **Where:** `src/components/VoiceDemo.tsx:313, 370-377, 385-388, 394-395, 439, 512-515, 600-602, 812-815, 820-828`; `src/lib/voice/policy.ts:73, :80`.
- **The moment:** "Three submissions in a rolling 24 hours… shared-network limits… allowance… what?"
- **What happens:**
  - The demo is full of jargon: "voice-to-task", "AI processing", "drafts", "transcript", "Checking your allowance…", "Three submissions in a rolling 24 hours… Shared-network limits also apply.", "do not sync to the app", "without another AI call", "Your allowance returns".
  - The headings are slogans: "Say it. See it take shape." and "A minute is plenty."
  - The badge "3 free tries · no account" sits on a page that never says the app needs an account and gives 10 dictations a month, so it reads as the app's offer.
- **Why it fails:**
  - HE-10: no AI, sync, allowance or transcription on the main path.
  - RD-3.
  - OL-2.
  - PR-3: qualify every "free".
  - HE-3.
- **Fix** (WEB-9's renames aren't repeated):

  | Where | EN | ES | CA |
  |---|---|---|---|
  | H2 :371, matching the button (CT-4) | Try it with your voice | Pruébalo con tu voz | Prova-ho amb la teva veu |
  | :373-374 | Say a few things you need to do, and when. You’ll see the tasks TaskFlow would add. | Di algunas cosas que tengas que hacer y cuándo. Verás las tareas que TaskFlow añadiría. | Digues algunes coses que hagis de fer i quan. Veuràs les tasques que TaskFlow afegiria. |
  | Badge :377 | 3 tries a day · no sign-up | 3 intentos al día · sin registrarte | 3 intents al dia · sense registrar-te |
  | Intro :386-388; delete "A minute is plenty." (:385) | Speak in English, Spanish or Catalan, for up to a minute. | Habla en español, catalán o inglés, hasta un minuto. | Parla en català, castellà o anglès, fins a un minut. |
  | Fine print :600-602 and :812-815 | 3 tries a day. It can get dates wrong, so check them. Nothing here is saved to the app. | 3 intentos al día. Puede equivocarse con las fechas: revísalas. Nada de esto se guarda en la app. | 3 intents al dia. Es pot equivocar amb les dates: revisa-les. Res d’això es desa a l’aplicació. |
  | Timeout :313 | This is taking too long. Try again in a moment; it won’t count as another try. | Está tardando demasiado. Vuelve a probar en un momento; no contará como otro intento. | Està trigant massa. Torna-ho a provar d’aquí a un moment; no comptarà com un altre intent. |

  - The example (:512-515) becomes the app's example (WEB-1, step 4).
  - Remove "Checking your allowance…" (:439); the "One moment…" heading covers it.
  - The privacy line (:394-396) keeps the 60 s, Google and the link. Its retention wording is area L's.
- **Verify:** a stop-list scan of `#voice` finds none of "allowance", "rolling", "submission", "sync", "AI call", "voice-to-task" or "draft". A native speaker reads the Catalan.
- **Evidence:** verified in code.

**WEB-13 · Severity 2 · Waiting for a result: no update, no way out**
- **Where:** `src/components/VoiceDemo.tsx:447-468` (waiting); :409-419 ("Close demo" is disabled while `busy`); :285 (a 55 s timeout on the page); :309-315.
- **The moment:** 15 seconds of the same spinner: "Has it frozen? I can't even close it."
- **What happens:**
  - The text ("Making a little clarity… Finding the tasks, dates, and details in your words.") never changes.
  - "Close demo" is disabled, so the only way out is to scroll away.
  - The error comes only at 55 s, although the model's own timeout is 35 s (`src/lib/voice/model.ts:48`).
- **Why it fails:** PF-8: past about 10 s, explain and offer a way forward that keeps what was said (Nielsen 1993). OL-1.
- **Fix:**
  - At 10 s, replace the line, and show a text button:

    | | Line | Button |
    |---|---|---|
    | EN | Still understanding. This can take up to half a minute. | Stop waiting |
    | ES | Sigo entendiendo. Puede tardar hasta medio minuto. | Dejar de esperar |
    | CA | Encara ho estic entenent. Pot trigar fins a mig minut. | Deixa d’esperar |

  - The button aborts the request, keeps the recording or the text, and returns to capture with "Try again". The existing `retryPending` path fetches the stored result without spending a try (:289, :309-310).
  - Bring the page's timeout down to about 40 s.
  - Long waits are likely caused on the server.
- **Verify:** with a mock delayed by 15 s, the new line and the button appear; clicking it re-enables the microphone and keeps the typed text.
- **Evidence:** verified in code. Real wait times weren't measured.

**WEB-14 · Severity 2 · Microphone errors are raw English or dead ends**
- **Where:** `src/components/VoiceDemo.tsx:235-238, 253-258`; `src/lib/voice/recorder.ts:2-5, 92-96`.
- **The moment:** they tap "Block" on the browser prompt by reflex, then see "Microphone access was not allowed.": "How do I undo that?" Or, on a device without a microphone: "Requested device not found."
- **What happens:**
  - Only `NotAllowedError` gets a written message, and it doesn't say how to turn the microphone back on.
  - `NotFoundError`, `NotReadableError`, `AbortError` and AudioWorklet failures show the browser's own English text, such as "Could not start audio source".
  - The message sits at the top of the panel, away from the microphone.
- **Why it fails:**
  - AX-10: plain recovery steps for these errors, in three languages.
  - OL-2: older users blame themselves 90% of the time (Nielsen 2013).
  - PV-3.
- **Fix:** map each error by name, and switch the panel to typing in the same step, so the next action is in view.

  | Error | EN | ES | CA |
  |---|---|---|---|
  | `NotAllowedError` (mirrors the app's `captureMicrophoneBlocked`) | The microphone is off for this page. Turn it on in your browser’s settings for this site, or type instead. | El micrófono está desactivado para esta página. Actívalo en los ajustes del navegador para este sitio o escribe. | El micròfon està desactivat per a aquesta pàgina. Activa’l a la configuració del navegador per a aquest lloc o escriu. |
  | `NotFoundError` | We can’t find a microphone on this device. You can type instead. | No encontramos ningún micrófono en este dispositivo. Puedes escribir. | No trobem cap micròfon en aquest dispositiu. Pots escriure. |
  | Anything else | The microphone isn’t responding. Close other apps that may be using it and try again, or type instead. | El micrófono no responde. Cierra otras apps que puedan estar usándolo y vuelve a probar, o escribe. | El micròfon no respon. Tanca altres aplicacions que el puguin estar fent servir i torna-ho a provar, o escriu. |
  | No `getUserMedia` | This browser can’t record your voice. You can type instead. | Este navegador no puede grabar tu voz. Puedes escribir. | Aquest navegador no pot gravar la teva veu. Pots escriure. |
- **Verify:**
  - Stub `getUserMedia` to reject with each name: the mapped text shows with `role="alert"`, and the text box is visible and focused.
  - Device check: deny the prompt in Chrome on Android.
- **Evidence:** verified in code; the browsers' own messages need a device check.

**WEB-15 · Severity 2 · The recording timer is announced every second**
- **Where:** `src/components/VoiceDemo.tsx:532-540` (`aria-live="polite"` on the status line), updated every second while recording (:248-252).
- **The moment:** a TalkBack user starts speaking, and the phone talks over them: "Recording 1 s / 60 s… 2 s / 60 s…"
- **What happens:** the live region changes every second, so a screen reader keeps talking through the recording. The microphone may record that speech too.
- **Why it fails:** AX-9: announce the start and stop, not each tick. OL-4 / COGA: few interruptions.
- **Fix:** keep the timer visible but drop its `aria-live`. Add one visually hidden `role="status"` that speaks only three times, using the app's own words for the first two:

  | When | EN | ES | CA |
  |---|---|---|---|
  | Start | Listening | Escuchando | S’està escoltant |
  | At 50 s | 10 seconds left | Quedan 10 segundos | Queden 10 segons |
  | Sent | Understanding… | Entendiendo… | Entenent… |
- **Verify:**
  - Playwright: the timer has no `aria-live`, and the status text changes only at start, 50 s and send.
  - Device check with TalkBack: silence while recording, and no screen-reader speech in the transcript.
- **Evidence:** verified in code. The microphone picking up the screen reader is inferred and needs a TalkBack check.

**WEB-16 · Severity 2 · Four microphones look tappable; three do nothing**
- **Where:**
  - Hero card: `src/app/page.tsx:96-99`, 36 px.
  - Features card: :239-244, 75 px (area F).
  - Live demo intro: `src/components/VoiceDemo.tsx:382-384`, a 78 px orb.
  - Walkthrough: `src/components/TaskDemo.tsx:138-151`, 50 px, solid green (`global.css:977-985`).
  - The real button: `VoiceDemo.tsx:516-529` (`voice.css:229-245`).
- **The moment:** "Just say the word". They tap the big microphone above "Try the live demo". Nothing. "Did I break it?"
- **What happens:**
  - Of the five microphones on the page, only one works.
  - It appears only after "Try the live demo", and it's the palest of them:
    - a mint fill on white, at 1.20:1;
    - a border at 1.31:1;
    - an icon only, named "Start recording" for screen readers but "Tap to record" in the text below.
  - The walkthrough's fake microphone is solid green, like a primary button.
  - While capturing, the disabled "Create drafts" bar looks more primary than the microphone.
- **Why it fails:**
  - CT-5: weak signifiers take 22% longer to find (Moran 2017f).
  - AX-8 and WCAG 2.5.3: words on controls, with the visible label in the accessible name.
  - CT-1.
  - OL-2.
- **Fix:**
  - Make the intro's orb the real control: a solid green (`--green`) circle with the paper-coloured microphone, 72 px or more. Its label sits inside the button or directly attached:
    - EN "Tap to talk", ES «Toca para hablar», CA «Toca per parlar»;
    - while listening: EN "Done", ES «Listo», CA «Fet» (WEB-9).
  - Remove the walkthrough's microphone and waveform (WEB-6).
  - The hero card's small icon sits in a text card, so it's a lower risk. It can go with WEB-1's clean-up.
- **Verify:**
  - Every microphone icon 48 px or larger is inside a `button`.
  - The button's accessible name contains its visible text.
  - Its fill has 3:1 or more against the panel.
- **Evidence:** verified in code; contrast computed; seen in renders (the intro orb and the walkthrough microphone).

**WEB-17 · Severity 2 · A whole section sells the website's dark mode**
- **Where:** `src/app/page.tsx:320-358`; `src/components/ThemeProvider.tsx:75-107` (the "mood" variant); `global.css:1193-1280`. Renders: desktop screen 5, mobile screens 9–10.
- **The moment:** "A softer start. A quieter finish… Try a different mood?" They tap it, and the whole website goes dark. "Was that the app?"
- **What happens:**
  - About 1.7 phone screens about light and dark mode.
  - A tilted phone shows the outdated Tasks screenshot, whose app-bar moon switch no longer exists (D5).
  - An outline button, "Try a different mood" (border at 1.22:1), switches the website's theme, which the header switch already does.
- **Why it fails:**
  - HE-11: extras later, and briefly.
  - AT-4.
  - CT-5: a ghost button.
  - FN-3.
  - Subtract first.
- **Fix:**
  - Remove the section, its CSS and the "mood" variant. The header switch stays.
  - If the owner wants dark mode mentioned, it's one clause in area F's features.
- **Verify:** no `#appearance`. Update `tests/website.spec.ts:86, 176-178`.
- **Evidence:** verified in code; seen in renders.

**WEB-18 · Severity 1 · Without JavaScript, the live demo's button does nothing**
- **Where:** `src/components/VoiceDemo.tsx:390-392`. The button isn't disabled before the script loads, and `#voice` has no `<noscript>`.
- **The moment:** JavaScript is off, or failed to load on a slow network. "Try the live demo" does nothing.
- **What happens:** the walkthrough disables itself until ready and has a `<noscript>` note. The live demo has neither.
- **Why it fails:** lens L: nothing waits without saying why. OL-1.
- **Fix:**
  - Render the button `disabled` until the script loads, as `TaskDemo.tsx:83-88` does.
  - With WEB-6, the static example is the no-JavaScript content.
  - Add a `<noscript>` line:
    - EN "Turn on JavaScript to try it with your voice."
    - ES «Activa JavaScript para probarlo con tu voz.»
    - CA «Activa JavaScript per provar-ho amb la teva veu.»
- **Verify:** with `javaScriptEnabled: false`, the button is disabled, and the line and the example are visible.
- **Evidence:** verified in code.

**WEB-19 · Severity 1 · Decorative hero text is read aloud; div labels ignored**
- **Where:**
  - `src/app/page.tsx:85-88` and :129: `aria-label` on a plain `div`.
  - :94, :101-102, :116-117, :124: decorative captions in the reading order.
  - Capitals typed into the source: :44, :94, :101, :124, :408; `VoiceDemo.tsx:370, :612-615`.
- **The moment:** a screen-reader user hears, after the button: "JUST SAY THE WORD, A walk at six… Make a little time for you. That belongs on your list, too. YOUR DAY, LOOKING A LITTLE LIGHTER."
- **What happens:**
  - An `aria-label` on a generic `div` isn't exposed.
  - Decorative captions are read as content.
  - Some screen readers spell out text typed in capitals.
- **Why it fails:** AX-5, AX-6, WCAG 1.3.1.
- **Fix:** WEB-1 and WEB-11 remove most of this. For what stays:
  - `aria-hidden="true"` on decorative captions;
  - no `aria-label` on plain `div`s (use `role="group"` if a name is needed);
  - sentence case in the source, with `text-transform: uppercase` in CSS.
- **Verify:** axe (`aria-prohibited-attr`) on both projects; a manual pass of the hero with NVDA or TalkBack.
- **Evidence:** verified in code.

### Claims checked

| Claim (page, `path:line`) | Source of truth (`path:line`) | Verdict |
|---|---|---|
| Hero: "Small reminders" (`src/app/page.tsx:63`) | D2, `.claude/ux-review/DECISIONS.md:110-116`; `reminderAskQuestion` (`App/lib/l10n/app_en.arb:1029`) | true |
| Hero card: "Just say the word — 'A walk at six.'" (`page.tsx:101-102`) | D3, `.claude/ux-review/DECISIONS.md:117-123`; `addTask` (`app_en.arb:204`) | true (one task; the app's own example names two, `calendarTrySaying` `app_en.arb:312`) |
| Hero and alt: agenda screenshot, two buttons, three tabs, app-bar switch (`page.tsx:110`; `Phone.tsx:2-8,22-38`; `public/images/agenda-*.png`) | `App/build/calendar-es-1.3x-light.png`; D5, `.claude/ux-review/DECISIONS.md:131` | outdated |
| Bar: "A clearer calendar" (`page.tsx:131`) | Standing decision: Calendar is the first screen (`.claude/ux-review/DECISIONS.md:170`) | true |
| Bar: "Your words, into action" (`page.tsx:134`) | D3 (:117-123); `freeVoiceNoticeBody` (`app_en.arb:1971`) | true |
| Bar: "Every detail, together" (`page.tsx:137`) | `App/docs/IMPLEMENTATION_STATUS.md:27,31` (B19 files, B23 notes) | true |
| Voice: "Try real voice-to-task, right here." (`VoiceDemo.tsx:373`) | Demo uses Gemini Flash-Lite on Vertex (`src/lib/voice/model.ts:51`); the app defaults to the free AI Studio model (`.claude/ux-review/DECISIONS.md:196-201`) | unverifiable as the app's behaviour (owner question 2) |
| Voice: "One thought or a few plans" (`VoiceDemo.tsx:373-374`) | `src/lib/voice/policy.ts:136` (up to 6 tasks); DECISIONS 2026-10-15 (`.claude/ux-review/DECISIONS.md:46-53`) | true |
| "3 free tries · no account" (`VoiceDemo.tsx:377`) | `src/lib/voice/policy.ts:3-4` | true of the demo; the app needs an account and gives 10 dictations a month (`app_en.arb:1891`; `App/docs/IMPLEMENTATION_STATUS.md:47`), see WEB-12 |
| "Speak in English, Spanish, or Catalan." (`VoiceDemo.tsx:387`) | `App/lib/l10n/app_{en,es,ca}.arb`; `model.ts` prompt | true |
| "Review the transcript, then make the drafts your own." (`VoiceDemo.tsx:387-388`) | `reviewOriginal` «Ver lo que dije», collapsed (`app_es.arb:7`; `App/build/review-direct-light.png`) | outdated (wording; the transcript is collapsed at :808-811) |
| "Up to 60 seconds." (`VoiceDemo.tsx:394`) | `src/lib/voice/policy.ts:7`; `src/lib/voice/recorder.ts:23` | true |
| "sent to Google … only when you choose 'Create drafts'" (`VoiceDemo.tsx:394-395`) | `VoiceDemo.tsx:263-287` | true |
| "Three submissions in a rolling 24 hours … Shared-network limits" (`VoiceDemo.tsx:600`) | `src/lib/voice/policy.ts:3-5, 44-57` | true |
| "do not sync to the app" (`VoiceDemo.tsx:601-602, 813-814`) | `VoiceDemo.tsx:663-668` (the page only) | true |
| Result card's priority chip (`VoiceDemo.tsx:674-678`) | The app's result has no priority (`App/build/review-direct-light.png`, `review-batch-light.png`) | outdated |
| "Whenever you’re ready" for an undated task (`VoiceDemo.tsx:22`) | `noDate` "No date" / «Sin fecha» (`app_en.arb:198`, `app_es.arb:136`) | outdated (the app's name differs) |
| Walkthrough: "No microphone, AI request, or account needed." (`TaskDemo.tsx:167-168`) | `TaskDemo.tsx` (no network) | true |
| Walkthrough: "a sample week in September 2026", fixed 21–25 Sep dates (`TaskDemo.tsx:11,22,33,167`) | Today is 2026-10-18 | outdated |
| Walkthrough draft with 5 fields, Priority among them (`TaskDemo.tsx:212-272`) | The app's result: title, date line, notes, «Más opciones» (`App/build/review-direct-light.png`) | outdated |
| noscript: "an editable draft with a title, schedule, priority, and notes" (`page.tsx:312-314`) | Same render; priority sits under «Más opciones» | true in substance ("draft" isn't the app's word) |
| Appearance: "light or dark mode" (`page.tsx:341-342`) | D5 (`.claude/ux-review/DECISIONS.md:131`) | true |
| Appearance screenshot, Tasks with app-bar moon (`page.tsx:327`; `public/images/tasks-*.png`) | D5; the app's current bottom and app bars (`App/build/calendar-es-1.3x-light.png`) | outdated |
| Closing: "Android app in development · Public download coming soon" (`page.tsx:423-424`) | `.claude/ux-web/DECISIONS.md:14` | true |
| Header: "Explore the app ↗" (`src/components/Header.tsx:48-50`) | `.claude/ux-web/DECISIONS.md:14` (Google Play unpublished) | false: there's no app to explore; it opens a sample form |
| Menu: "Get TaskFlow" (`Header.tsx:62-64`) | `.claude/ux-web/DECISIONS.md:14` | false today |

### Missing from the site (app features worth telling)
- **Several things in one dictation.** The owner calls it "absolutely a must" (`.claude/ux-review/DECISIONS.md:46-53`).
  - The app teaches it on first run: «Prueba: toca Añadir tarea y di «Mañana, llamar al dentista y comprar pan»» (`calendarTrySaying`, `app_es.arb:221`), shown as «2 cosas para añadir» (`captureThingsToAdd`).
  - Where it belongs: the hero subheadline (WEB-1), the hero screenshot (WEB-5) and the demo's example (WEB-12).
  - It replaces the single-task examples: "A walk at six" and the doctor sentence at `VoiceDemo.tsx:512-515`.
- **One button, «Añadir tarea».** The north star (CLAUDE.md, Product rules; `addTask`).
  - Where it belongs: the hero screenshot (WEB-5) and the demo's hand-over line (WEB-7).
  - It replaces the old two-button image.
- **Reminders when you want them.** «¿Quieres un recordatorio antes?» at the first dated task; date-only tasks are reminded at 9:00 (D2, `.claude/ux-review/DECISIONS.md:110-116`; `reminderAskQuestion`).
  - Where it belongs: the hero subheadline ("can remind you before it").
  - It replaces "Small reminders".
- **Nothing is saved or changed without your tap, and «Deshacer» undoes it.** D3 (:117-123), D11 (:149-151), and voice changes and deletions (:11); `captureAddToCalendar`, `undo`.
  - Where it belongs: a trust clause in the live demo for the wary newcomer.
  - It replaces "AI can make mistakes; check every draft."
- **Voice commands:** create a project, assign, find, change and delete tasks by voice (`.claude/ux-review/voice-commands-plan.md`; `Backend/docs/VOICE_COMMANDS.md`). They belong in area F's features, not the hero (HE-11).

### Keep
- **The live demo asks well.** It asks for the microphone only after a tap, caps recordings at 60 s with a visible counter, and always offers typing (`VoiceDemo.tsx:227-252, 483-507`; HE-9, AX-10).
- **The page is honest about itself.** "These preview tasks stay on this page and do not sync to the app", and the closing card's "in development" line, are both there. They just need to be readable and early (WEB-3).
- **Text contrast passes in both themes.**
  - Muted text: 5.48:1 light, 8.86:1 dark.
  - Primary buttons: 5.76:1 light, 10.47:1 dark.
  - Closing card: 6.94:1.
  - Both themes look designed, and the screenshots swap with the theme.
- **Nothing in the hero moves by itself.** Reduced motion stops the reveal and the spinner (`global.css:2407-2415`; `voice.css:539-544`; HE-8, AX-7).
- **Focus follows the demo.** Each new demo stage moves focus to its heading, and errors use `role="alert"` (`VoiceDemo.tsx:195-204, 421-430`). Keep that when reworking it (AX-9).

### Questions for the owner (product decisions only)
1. **Should visitors be able to hear when TaskFlow launches?** Until Google Play, the page's only honest next step is the demo. Options:
   - no list, as today;
   - an email list, which needs privacy wording (area L);
   - Google Play pre-registration once a listing exists. It uses the same `details?id=` URL, and each country gets a 90-day window. A personal developer account created after 13 Nov 2023 first needs a closed test with at least 12 testers for 14 days, and the package ID `com.example.agenda` must change first.

   (AP-3, AP-6, CT-2)
2. **Should the website demo use the app's AI route and model?**
   - The demo calls Gemini Flash-Lite on Vertex (`src/lib/voice/model.ts:47-51`).
   - The app's extraction defaults to the free AI Studio model, with no paid fallback (`.claude/ux-review/DECISIONS.md:196-201`; UX-616 is open).
   - A demo faster or more accurate than the app makes the app feel broken after installing (FN-4).
   - Recommendation: match the route, or say on the demo that the app may take a little longer.
3. **Do you want to keep the brand line?** "A little focus. A little flow." and the "a little …" voice appear 26 times. The findings take them out of the hero and demos for clarity (HE-1, HE-3). Keep the line in the footer as the brand, or drop it everywhere?

### Cross-slice notes
- **F:**
  - The FAQ's "Do I need an account?" and "How does voice-to-task work?" say the app works without an account (`page.tsx:12, :20`). That's false since the login wall (`App/docs/IMPLEMENTATION_STATUS.md:47`; `.claude/ux-review/DECISIONS.md:73-76`), so it's a Severity 4 candidate.
  - The FAQ's "Will TaskFlow be free?" (`page.tsx:31-32`) is outdated. Today: 10 free dictations a month, a form for free accounts, and Pro (`.claude/ux-review/DECISIONS.md:15-25`).
  - The FAQ is outdated in three more places:
    - "Choose Task or Note when capturing" (`page.tsx:28`): D3 removed that choice.
    - "list(s)", where the app says «proyecto(s)» (`page.tsx:23-24`).
    - "Editors… viewers" (`page.tsx:24`; D15b).
  - The feature cards' "Sign in to upload files…" and "Sign in to back them up" (`page.tsx:257-258, :276-277`) imply that signing in is optional. "6 MiB" is jargon, and the calendar card's picture is a drawing, not the app (`page.tsx:178-223`).
- **G:**
  - The `<title>`, description and link preview (`layout.tsx:11-13`; `opengraph-image.png`) are English slogans with no product shown. They should follow WEB-1's H1 in each language.
  - The footer has 3 of the 26 "little"s (`Footer.tsx:17, :41`).
  - The header's theme switch and menu are 42 × 42 px (`global.css:313-321, 1662-1663`). All font sizes are in px (RD-5).
  - The dark hero image is never preloaded; only the light one is (`Phone.tsx:29-38`). Check LCP in dark mode.
- **L:** the demo's "How we use your data" (`VoiceDemo.tsx:396`, the other session's uncommitted change) opens `/privacy/#voice`, the app's voice section. The demo's own retention is in `#website`.
- **G and L:** removing `#demo` (WEB-6) means repointing `Header.tsx:9` and `Footer.tsx:22`. Footer.tsx holds the other session's uncommitted edits.

### Memory notes
- **Site map.**
  - `/` has these sections and anchors, in order:
    - hero (no id);
    - the `.promise-bar` div;
    - `#features`;
    - `#voice` (VoiceDemo);
    - `#demo` (TaskDemo);
    - `#appearance`;
    - `#questions`;
    - `#get-taskflow` (closing card).
  - Header nav: `/#features`, `/#demo`, `/#voice`, `/#questions`. The CTA "Explore the app" goes to `/#demo`; the menu's "Get TaskFlow" to `/#get-taskflow`. The footer adds `/#features`, `/#demo`, `/#questions` and the legal links.
  - Full renders are 6235 px on desktop (6.2 screens) and 7981 px on a phone (12 screens).
  - Positions on a phone: live demo at y≈3084, closing note at y≈7450. On desktop: live demo at y≈2220.
  - The page has only an English version.
- **Claims map.**
  - Hero: reminders at `page.tsx:63`, the voice example at :101.
  - Screenshots: `public/images/{agenda,tasks}-*.png`, from 2026-09-21. They predate D5 and the one-button bar; `calendar-*.png` is unused.
  - Demo limits: `VoiceDemo.tsx:377, 394, 600`, backed by `policy.ts:3-7`.
  - The demo's model (`model.ts:51`) differs from the app's.
  - FAQ: `page.tsx:5-34` (area F). Availability: `page.tsx:423`, `Header.tsx:48-64`.
- **App vocabulary to match** (ARB keys): `addTask`, `done`, `captureStarting`, `listeningSeconds`, `captureUnderstanding`, `captureThingsToAdd`, `captureAddTasks`, `captureAddToCalendar`, `captureSayAgain`, `reviewOriginal`, `noDate`, `captureTypeInstead`, `captureMicrophoneBlocked`, `freeVoiceLeft`, `freeVoiceNoticeBody`, `authPitch` (the app's one-line pitch) and `calendarTrySaying` (the app's teaching example).
- **Patterns.**
  - Every call to action is an in-page anchor; there's no store link yet.
  - A soft "a little …" voice runs through the copy.
  - All font sizes are in px, many under 12.
  - Eyebrows are typed in capitals in the source.
  - There are two demos: the live one (Turnstile, 3 tries per rolling 24 h, server messages in English) and a sample form.
- **Recurring problems.**
  - Slogans instead of what the product does.
  - Tiny type.
  - Decorative microphones that look like buttons.
  - Outdated screenshots.
  - English only.
  - Demos that end without a next step.
- **Techniques that worked.**
  - `crop.mjs` screen by screen, plus the PNG sizes (height ÷ viewport) to place elements.
  - Contrast computed with a small Python snippet from the CSS tokens.
  - Comparing `public/images` with `App/build/*.png`.
  - The headings-only test, and counting a repeated word.
  - For anchor landings, adding the root `scroll-padding-top` to the target's `scroll-margin-top`.
  - Listing `font-size` values under 12 px with a script that keeps each selector.
