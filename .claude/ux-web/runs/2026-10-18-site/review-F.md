## UX web review — F: features, faithfulness, the funnel to download and Pro, pricing (recheck with renders, audit and the app on dev) — 2026-10-19

**Verdict:** Ship after fixes — the home still describes the September app (use without an account, no free plan or Pro, a screen the app no longer has, every "get it" looping back to a demo), and since the first review the legal pages and the live demo have fallen behind the app on RevenueCat and on typing, which is now Pro; every fix is copy, the WD4 images or a subtraction, and every decision it needs is made.

**Recheck:** all 14 findings of the first review were re-judged against the renders and `AUDIT.md` of 2026-10-18 23:52–23:56, the WebKit renders of 00:19, and the app on `dev` (HEAD 48234fa plus the app loop's uncommitted b2 round). 14 confirmed, most with updated copy or a narrower scope (each says what changed), 0 withdrawn, 4 new (WEB-501 to WEB-504).
- WEB-102, WEB-103 and WEB-112 are merged in the ledger into WEB-3, WEB-5 and WEB-17 (area H). They're written in full below with that note, so the organizer can fold them.
- WEB-104, WEB-108 and WEB-113 were "decision"; WD2, WD1 and WD3 decided them, so they're fixes now.

**Walked:**
- **Evidence:** every site render is newer than the code it shows (newest site source: `src/content/legal/*.ts`, 2026-10-16 08:01; `page.tsx` 2026-10-09; `public/images/*` 2026-09-21). App renders compared: `App/build/calendar-es-1.3x-light.png`, `calendar-feedback-light.png`, `review-batch-light.png`, `review-direct-light.png`, `capture-listening-es-2x.png`, `capture-fill-by-hand-es.png`, `new-task-form-es.png`, `project-people-filter-es.png`, `task-created-by-es.png` (2026-10-19 00:17–00:20) and `App/artifacts/auth/login-light.png` (00:19). ARB line numbers below are the working tree's (2026-10-19).
- **Wanting → getting, Newcomer, phone 390 × 664, EN, light and dark (Chromium and WebKit):** land → ☰ → "Get TaskFlow" → the dark green closing card → "Find your flow" → thrown 5 screens back up to the sample form. 4 steps; none leads to getting the app. Without the menu, the only "not yet" is a 10 px line on screen 12 of 13.
- **Wanting → getting, Comparer, desktop 1440 × 1000:** land → "Explore the app" (filled, header) → the sample form → "Questions" → open "Can I download TaskFlow yet?" → open "Will TaskFlow be free?" (the first answer snaps shut, WEB-503) → closing card. 6 steps; no free plan, no Pro, and an answer saying no account is needed.
- **Trying → wanting more, phone:** ☰ "Try voice" → "Try the live demo" → "Type it instead" → type → security check → "Create drafts" → "3 drafts, ready for you." → "Add to preview list" → tick one off → tries used: "Your allowance returns Mon 4:54 AM. The sample walkthrough below is always available." (`voice-typing`, `voice-result`, `voice-preview`, `voice-tries-used` renders). About 8 steps; it ends with no word about the app, its free plan or Pro, and the typed path is a Pro capability in the app (WEB-502).
- **Invitee, ES/CA, phone:** the invitation email («La app llegará pronto a Google Play. Mientras tanto, puedes ver lo que hace en taskflow.garbar.tech», `Backend/core/invitation_email.py:50`) → the English home → nothing about projects until a closed FAQ on screen 11 that says "list" and "shares a code separately". 3 steps, dead end.
- **Leaver, three languages:** privacy §7 and delete-account §3 say RevenueCat's customer record stays and must be requested by email; the server now deletes it (WEB-501).
- **Site → the app's first run (continuity):** Sign in ("Continue with Google", or email and a 6-digit code) → the calendar's «¿Qué quieres recordar?» with "Try it: tap Add a task and say “Tomorrow, call the dentist and buy bread.”" (`App/lib/screens/calendar_screen.dart:721-729`; `app_en.arb:312`) → "Want a reminder before it?" at the first dated task → at 0 free dictations, «Nueva tarea» and the form, then «Ver Pro». The site prepares none of these today.
- **Claims inventory:** home, header, footer, metadata, the live demo (all 67 state renders read through `INDEX.md`; the ones that carry claims viewed), the sample walkthrough, privacy, terms, legal notice and delete-account in EN, ES and CA, and the invitation email as a way in.

**Numbers:**
- **Claims:** 84 checked → 7 false, 19 outdated, 8 incomplete, 8 named differently from the app, 3 misleading labels, 39 true. (First review: 67. This time the legal pages were read line by line against the app, and the app changed on 2026-10-18: RevenueCat deletion, the form for free accounts, voice commands.) After the fixes below: 0 false or outdated.
- **FAQ:** 6 of 7 answers false or outdated; only "Can I use it offline?" is right, in words the app doesn't use ("list", "sync").
- **Home mentions in static text:** free plan 0, Pro 0, "10 dictations" 0, several tasks per dictation 0 (the live demo shows 3 tasks from one sentence, but only after it's opened and used), reminders 1 ("Small reminders"), projects 0 ("list" ×4 in the FAQ), "Android" 2 (the 10 px line and a closed answer) plus 2 alt texts.
- **"You can't download it yet":** phone screen 12 of 13 (y ≈ 7,450 of 7,981; 11 scrolls), 10 px (`AUDIT.md` §6, `.launch-note`), still 10 px with text at 200% (§3: no home text grows); desktop screen 6 of 7. After WEB-102/WEB-3: under the hero button, 0 scrolls.
- **AT-6 (by the end of phone screen 2: what it does, "Android", what's free and Pro, how to get it):** 0 of 4 today → 3 of 4 predicted after WP3 (H) and WEB-104; the free line lands after the demo, about screen 3 (measure on the new render).
- **First-viewport calls to action that lead toward getting the app:** desktop 0 of 3 ("Explore the app", "See it in action" → the walkthrough; "Meet TaskFlow" → features); phone 0 of 2.
- **Screenshots:** 0 of the 4 image files shown match today's app (hero and appearance, light and dark); 2 more files ship unused. All dated 2026-09-21; the app's renders are from 2026-10-19.

**Attention** (predicted from the render with GUIDELINES.md §21 step 4, not measured; only what bears on this area):
- `home.en.desktop.light.fold.png` (dark has the same layout):
  1. The H1 "Make room for a clearer day." (largest, highest-contrast text, upper left).
  2. The phone screenshot (largest informative image, centre-right; the right side gets its first look after about 2–3 s), with the "JUST SAY THE WORD" card competing.
  3. The filled "See it in action" (left, y ≈ 567–620, isolated). It competes with the 3-line paragraph above it and with the header's filled "Explore the app" in the top-right cell: two primary-styled buttons in one view.

  None of the three says it's an Android app, that it isn't on Google Play yet, or that there's a free plan. The only proof that it's a phone app is the screenshot, of an app that no longer looks like that.
- `home.en.mobile.light.fold.png` (dark the same):
  1. The H1 (y ≈ 155–255, top half).
  2. "See it in action" (y ≈ 366–415, middle band), competing with the paragraph above.
  3. The top of the screenshot and the "JUST SAY THE WORD" card, in the bottom third (y > 443, about 14% of gaze).

  "Android", "not yet" and "free" are absent; the first "Android" is on screen 12.
- `webkit/home.en.mobile.light.fold.png`: the same layout, but every text renders at the font's thinnest weight. The H1 loses weight against the filled button, which keeps its fill (cross-slice note for G).

### Findings (most severe first)

**WEB-101 · Severity 4 · The site says TaskFlow works without an account**
- Recheck: confirmed in code and in the current renders. Corrected copy: the app's button is "Continue with Google" (`App/lib/l10n/app_en.arb:1743`), and a password sign-up confirms a 6-digit code (`Backend/docs/EMAIL_VERIFICATION.md:3`).
- Where:
  - FAQ "Do I need an account?", `src/app/page.tsx:19-20` (closed; phone screen 11, desktop screens 5–6);
  - the last sentence of "How does voice-to-task work?", `:12`;
  - the details card, `:255-260` ("Sign in to upload files…"), visible on phone screens 4–5 (`crops/home.en.mobile.light.full.s3-4.png`) and desktop screen 2;
  - the offline card, `:275-278` ("Sign in to back them up when you're connected."), phone screen 5.
  - Home, EN, every viewport and theme (`home.en.*.full.png`).
- The moment: the wary Newcomer reads "You can create tasks… without an account" and thinks "Good, they won't take my email." The app's first screen is Sign in: "They lied to me."
- What happens:
  - The FAQ promises tasks and "a limited daily voice allowance without an account", and "a larger AI allowance" after signing in. Two cards say "Sign in to…", as if signing in were optional.
  - Since 2026-10-09 the app opens nothing before sign-in (`App/docs/IMPLEMENTATION_STATUS.md:47`; "The login stays a hard wall", `.claude/ux-review/DECISIONS.md:126-129`). Its first screen offers "Continue with Google" or an email; a password sign-up must confirm a 6-digit code before it can sign in (`DECISIONS.md:91-97`; `App/artifacts/auth/login-light.png`).
  - Without Pro, every account gets 10 free dictations a month, not a daily allowance (`Backend/config/settings.py:144`).
- Why it fails: FN-1 (UCPD art. 6; Play Deceptive), TR-2 (say up front what the visitor must give), FN-3 (the app's first screen is Sign in), and the persona's wariness about giving data away (GUIDELINES, "The bar").
- Fix:
  1. FAQ answer, `page.tsx:20`, keeping the question:
     - EN: "Yes. You sign in once: tap Continue with Google, or use your email and a 6-digit code we send you to confirm it. Your tasks are kept in your account, so you don't lose them if you change phones."
     - ES («¿Necesito una cuenta?»): «Sí. Inicias sesión una vez: toca Continuar con Google, o usa tu correo y un código de 6 cifras que te enviamos para confirmarlo. Tus tareas se guardan en tu cuenta, así no las pierdes si cambias de móvil.»
     - CA («Necessito un compte?»): «Sí. Inicies la sessió una vegada: toca Continua amb Google, o fes servir el teu correu i un codi de 6 xifres que t’enviem per confirmar-lo. Les tasques es desen al teu compte, així no les perds si canvies de mòbil.»
  2. Delete "A limited voice trial is available without an account." (`:12`; WEB-105 rewrites the rest of that answer).
  3. Details card body, `:255-260`:
     - EN: "Add notes, a checklist or files to any task. Files are backed up to your account, up to 6 MB each."
     - ES: «Añade notas, una lista de pasos o archivos a cualquier tarea. Los archivos se guardan en tu cuenta, hasta 6 MB cada uno.»
     - CA: «Afegeix notes, una llista de passos o fitxers a qualsevol tasca. Els fitxers es desen al teu compte, fins a 6 MB cadascun.»
  4. Offline card body, `:275-278`:
     - EN: "Your tasks are saved on your phone, so you can check and add them without internet. They're saved to your account when you're back online."
     - ES: «Tus tareas se guardan en el móvil, así puedes consultarlas y añadirlas sin internet. Se guardan en tu cuenta cuando vuelves a tener conexión.»
     - CA: «Les tasques es desen al mòbil, així pots consultar-les i afegir-ne sense internet. Es desen al teu compte quan tornes a tenir connexió.»
  - WEB-104's closing line ("Free with an account: …") says the same thing outside the accordion.
- Verify:
  - The home's copy, in all three languages, contains none of "without an account", "Sign in to", "allowance" or "MiB".
  - Walkthrough: the FAQ answer names the two ways in of `App/artifacts/auth/login-light.png`.
- Evidence: verified in code (site, app docs, ARB files); seen in the current site renders and the app's login render.

**WEB-102 · Severity 3 · "Get TaskFlow" loops back; "not yet" hides at the bottom** — ledger: merged into WEB-3 (H)
- Recheck: confirmed, and now measured. Copy corrected for WD7 (Android only), WD9 (no sign-up list yet), WD1 (no walkthrough) and the labels the organizer settled (plan-first, WP3 and WP6).
- Where:
  - `src/components/Header.tsx:62-64`: "Get TaskFlow", in the phone menu only (`home-menu.en.mobile.light.fold.png`).
  - `src/app/page.tsx:419-421`: "Find your flow" → `#demo`. `:422-425`: the only availability line.
  - `page.tsx:7-8`: the FAQ "Can I download TaskFlow yet?".
- The moment: "I want this. Where do I get it?" The visitor taps "Get TaskFlow", lands on a big green card with a lime button, taps it and is thrown five screens back up to a sample form. "Is this a real app?"
- What happens:
  - The availability line is 10 px (`AUDIT.md` §6, `section#get-taskflow > div.closing-card > span.launch-note`, all four home variants) and stays 10 px with text at 200% (§3). On a phone it sits on screen 12 of 13; on desktop, screen 6 of 7.
  - The FAQ hints at other platforms ("Android as the first testing platform"), sends people to "the real app screens" (a month old, WEB-103) and to the walkthrough that WD1 removes.
  - Invitees arrive from "The app is coming soon to Google Play. Until then, you can see what it does at taskflow.garbar.tech" (`Backend/core/invitation_email.py:32, 50, 68`) and meet the same loop.
- Why it fails: CT-4 (the destination keeps the label's promise), AP-5 (before launch, say it in plain text), AP-7 ("for Android" near the action), AT-6 (how to get it within two phone screens), CT-2 (the last screenful's call to action is real), RD-5 (small print ≥ 12 px).
- Fix:
  1. Closing card body (`:414-418`), at body size:
     - EN: "TaskFlow is an app for Android phones, coming soon to Google Play."
     - ES: «TaskFlow es una app para móviles Android y llegará pronto a Google Play.»
     - CA: «TaskFlow és una app per a mòbils Android i arribarà aviat a Google Play.»
  2. The closing button goes to the live demo (`#voice`), with WP3's label ("Try it with your voice"). "Find your flow" goes.
  3. Remove the 10 px line (`:422-425`); WEB-104's free line takes its place.
  4. Phone menu item (`Header.tsx:62-64`): WP6's "Coming soon to Android", still pointing to `#get-taskflow`.
  5. FAQ answer, `:8`:
     - EN: "Not yet. TaskFlow is an app for Android phones, in Spanish, Catalan and English, coming soon to Google Play. Until then, you can try it with your voice on this page."
     - ES: «Todavía no. TaskFlow es una app para móviles Android, en español, catalán e inglés, y llegará pronto a Google Play. Mientras tanto, puedes probarla con tu voz en esta página.»
     - CA: «Encara no. TaskFlow és una app per a mòbils Android, en català, castellà i anglès, i arribarà aviat a Google Play. Mentrestant, pots provar-la amb la teva veu en aquesta pàgina.»
  - The page's first "Android" carries ™, and the page says "Android is a trademark of Google LLC." (decided 2026-10-18, night).
- Verify:
  - At 390 × 664: ☰ → "Coming soon to Android" → the card's first text names Android and Google Play at ≥ 16 px, and its button lands with `#voice` in view.
  - `page.tsx` has no "Find your flow", "Get TaskFlow" or "first testing platform".
- Evidence: verified in code; seen in the current renders; measured (`AUDIT.md` §3, §6).

**WEB-103 · Severity 3 · App screenshots show a TaskFlow that no longer exists** — ledger: merged into WEB-5 (H)
- Recheck: confirmed against the app's renders of 2026-10-19 00:18. Fix corrected to WD4 (decided).
- Where:
  - Hero: `page.tsx:110` → `src/components/Phone.tsx:22-39`, with `public/images/agenda-{light,dark}.png`.
  - Appearance section: `page.tsx:327`, with `tasks-{light,dark}.png`.
  - Unused but shipped: `calendar-{light,dark}.png`. Alt text: `Phone.tsx:2-8`.
  - All six files dated 2026-09-21. Renders: `home.en.*.fold.png`; phone screens 9–10 for the tasks screen.
- The moment: after installing: "The website showed a New task button with a separate microphone, and a moon. Where are they? Is this the same app?" The owner's father couldn't find how to create a task; the site teaches him the wrong button.
- What happens:
  - The site shows "Your calendar", "A LITTLE FOCUS. A LITTLE FLOW.", a September month with "Month view", "+ New task" beside a separate mic, three tabs (Calendar, Tasks, Settings) and a moon (a sun in dark).
  - Today's app (`App/build/calendar-es-1.3x-light.png`, `calendar-feedback-light.png`) has one «Añadir tarea» button with the mic inside it (`App/lib/widgets/task_actions.dart:102`), four tabs (Calendario, Tareas, Notas, Ajustes), a «Semana ▾» week strip, and no theme switch (D5).
  - The images are English on what will become Spanish and Catalan pages (WEB-2).
- Why it fails: HE-5 (a real, current screen in the page's language and theme), FN-3 (what the site shows first, the app shows first), AP-12, TR-3 (outdated screenshots are trust bugs), EY-3.
- Fix (WD4):
  1. Hero images: `public/images/hero-calendar-<language>-<theme>.png` (en, es, ca × light, dark; 780 × 1688), which the main session renders from the app: the Calendar with "Call the dentist" and "Buy bread" on tomorrow, and the one «Añadir tarea» button.
  2. `Phone.tsx`: take the page's language; `width={780} height={1688}` (`:25-26`, `:34-35`); drop the `screen` variants.
  3. Alt text, one per language, matching the titles in the rendered image:
     - EN: "TaskFlow on an Android phone: tomorrow's tasks, “Call the dentist” and “Buy bread”, on the calendar, and the Add a task button."
     - ES: «TaskFlow en un móvil Android: las tareas de mañana, «Llamar al dentista» y «Comprar pan», en el calendario, y el botón Añadir tarea.»
     - CA: «TaskFlow en un mòbil Android: les tasques de demà, «Trucar al dentista» i «Comprar pa», al calendari, i el botó Afegeix una tasca.»
  4. Delete `agenda-*` and `calendar-*`, and `tasks-*` with WEB-112.
  5. The link preview uses the same image (WD4; WEB-302).
- Verify:
  - The hero render shows the same single button, four tabs and no theme switch as the app's latest calendar render.
  - The images are newer than the app's last calendar change.
  - Each language's alt text contains "dentist" / «dentista».
- Evidence: seen in the current renders (site and app); verified in code.

**WEB-104 · Severity 3 · Free plan and Pro missing; pricing answer outdated**
- Recheck: confirmed. It was "decision"; WD2 decided to publish, without a price and without "100 MB". Copy corrected to WD2's three places; the renewal, typed sentences and the FAQ's order are added.
- Where: the FAQ "Will TaskFlow be free?", `page.tsx:31-32` (the last of 7; phone screen 11, desktop screen 6); the closing card, `:414-425`; the end of the live demo, `src/components/VoiceDemo.tsx:812-829`; the whole home (0 mentions).
- The moment: the Comparer asks "What's free? What does Pro cost?" and reads "no paid plans". Later the app says "Free dictations: 7 of 10 left this month" and "Explore Pro": "They hid that."
- What happens:
  - The answer says launch pricing isn't announced and there are no plans "on this website".
  - On dev, without Pro:
    - 10 free dictations a month, counted per dictation (`Backend/config/settings.py:144`; `DECISIONS.md:130-153`).
    - At 0 left, the button becomes «Nueva tarea» and opens the form, "with no limit" (`app_en.arb:1945-1947, 1975`).
  - TaskFlow Pro is a monthly subscription that renews until cancelled (`app_en.arb:1696-1697`). It gives "unlimited dictation and file space" (`:1692`), and the assistant reads typed sentences only with Pro (`DECISIONS.md:68-78`).
  - Pro's price isn't set: US$9.99 is a Test Store price (`App/docs/REVENUECAT_SETUP.md`).
  - None of this can be read without opening the last FAQ item (FQ-2).
- Why it fails: PR-2 (what Free includes and what happens at the limit, wherever Free or Pro is mentioned), PR-3 (qualify "free"), PR-4 (renewal and cancelling), CT-10 (the terms where people decide), FN-6 (as the app describes them), TR-2, FQ-1, FQ-2, AT-6.
- Fix (WD2's three places; no price, no "100 MB"):
  1. FAQ: move it to second place, after the download question.
     - EN: "Is TaskFlow free?" — "Yes. You get 10 free dictations a month, and one dictation can hold several tasks. When they're used up, you keep adding tasks with a short form, with no limit, until they come back the next month. TaskFlow Pro, a monthly subscription that renews until you cancel it in Google Play, gives you unlimited dictation and file space, and also turns sentences you type into tasks. Its price isn't set yet."
     - ES: «¿TaskFlow es gratis?» — «Sí. Tienes 10 dictados gratis al mes, y en un dictado caben varias tareas. Cuando se acaban, sigues añadiendo tareas con un formulario sencillo, sin límite, hasta que vuelven el mes siguiente. TaskFlow Pro, una suscripción mensual que se renueva hasta que la cancelas en Google Play, te da dictado y espacio para archivos ilimitados, y además convierte en tareas las frases que escribes. Su precio aún no está decidido.»
     - CA: «TaskFlow és gratuït?» — «Sí. Tens 10 dictats gratuïts al mes, i en un dictat hi caben diverses tasques. Quan s’acaben, continues afegint tasques amb un formulari senzill, sense límit, fins que tornen el mes següent. TaskFlow Pro, una subscripció mensual que es renova fins que la cancel·les a Google Play, et dona dictat i espai per a fitxers il·limitats, i a més converteix en tasques les frases que escrius. El preu encara no està decidit.»
  2. Closing card, in place of the 10 px line, at ≥ 16 px:
     - EN: "Free with an account: 10 dictations a month, and tasks by hand with no limit. TaskFlow Pro, monthly: unlimited dictation and file space."
     - ES: «Gratis con una cuenta: 10 dictados al mes y tareas a mano sin límite. TaskFlow Pro, mensual: dictado y espacio para archivos ilimitados.»
     - CA: «Gratuït amb un compte: 10 dictats al mes i tasques a mà sense límit. TaskFlow Pro, mensual: dictat i espai per a fitxers il·limitats.»
  3. One line after the demo, visible in every demo state. It goes in H's WP8, and `VoiceDemo.tsx` stays uncommitted. It builds on review H's line:
     - EN: "In the app you get 10 free dictations a month, and you can add tasks by hand any time. TaskFlow Pro makes dictation unlimited."
     - ES: «En la app tienes 10 dictados gratis al mes y puedes añadir tareas a mano cuando quieras. Con TaskFlow Pro, el dictado es ilimitado.»
     - CA: «A l’app tens 10 dictats gratuïts al mes i pots afegir tasques a mà sempre que vulguis. Amb TaskFlow Pro, el dictat és il·limitat.»
  - Q1 below asks whether "unlimited" needs a fair-use clause.
- Verify:
  - With every FAQ item closed, "10" with "dictations" and "TaskFlow Pro" are on the page in each language.
  - The numbers equal `settings.py:144` and `app_en.arb:1899-1975`.
  - The site shows no price and no "MB" total.
  - On the new phone render, note the screen where the first free line appears (AT-6 asks for two).
- Evidence: verified in code (site, app, server) and decisions.

**WEB-105 · Severity 3 · Several tasks in one dictation is never told**
- Recheck: confirmed, with three corrections:
  - Voice commands are now in the app on dev (985f060: find, change and delete by voice, and create projects), so the FAQ adds them.
  - The live demo does make several tasks from one thought (`voice-result.en.mobile.light.panel.png`: "3 drafts"), but only once it's opened and used (AT-7).
  - The voice card no longer quotes the example, because WP3's hero card and WD1's static example already do.
- Where: the voice card, `page.tsx:230-234` (phone screen 4, `crops/home.en.mobile.light.full.s3-4.png`; desktop screen 2); the FAQ, `:11-12`.
- The moment: "So I say one thing and get one task? My notebook does that."
- What happens:
  - The owner called several tasks per dictation "absolutely a must" (`DECISIONS.md:99-106`), and speed is the selling point (`:120-125`).
  - The app teaches it at first run (`app_en.arb:312`, `App/lib/screens/calendar_screen.dart:729`) and answers "2 things to add" / "Add 2 tasks" (`app_en.arb:1566, 1576`; `App/build/review-batch-light.png`).
  - The static page only says "Turn a passing thought into a task" and "suggest tasks".
  - The FAQ also says "TaskFlow transcribes your recording", but the app first recognises speech on the phone (`App/android/app/src/main/kotlin/com/example/agenda/NativeSpeechBridge.kt:71`; `capturePrivacy`, `app_en.arb:422`).
  - Voice commands go untold: asking what you have this week, and moving, changing or deleting a task, with the change shown first and «Deshacer» (`Backend/docs/VOICE_COMMANDS.md:1-10`; `.claude/ux-review/voice-commands-plan.md` items 5–7; D4 of the night entry).
- Why it fails: HE-4 (one input and the dated tasks it became), HE-11 (the core loop first), B lens (the benefit that creates desire), FN-3 (the app's own first example), SC-1, FN-1 (the transcription claim).
- Fix:
  1. Voice card body, `:231-234` (the heading is in WEB-111):
     - EN: "TaskFlow makes one task for each thing you say, with its day and time. Check them, then add them all with one tap."
     - ES: «TaskFlow crea una tarea por cada cosa que dices, con su día y su hora. Revísalas y añádelas todas con un toque.»
     - CA: «TaskFlow crea una tasca per cada cosa que dius, amb el dia i l’hora. Revisa-les i afegeix-les totes amb un toc.»
     - If neither the hero card (WP3) nor the demo's static example (WD1) ends up quoting the app's example, quote it here: “Tomorrow, call the dentist and buy bread.” / «Mañana, llamar al dentista y comprar pan» / «Demà, trucar al dentista i comprar pa» (`calendarTrySaying` in each ARB).
  2. FAQ, `:11-12`, with the question in the app's words:
     - EN: "How do I add tasks by voice?" — "Tap Add a task and say what you need to do, in your own words; several things at once is fine. Tap Done, and TaskFlow shows one task for each, with its day and time. Add them all with one tap. You can also ask what you have this week, or move, change or delete a task by voice: TaskFlow shows the change first, and you can undo it. It needs the internet: your words are sent to Google to be turned into tasks."
     - ES: «¿Cómo añado tareas hablando?» — «Toca Añadir tarea y di lo que tienes que hacer, con tus palabras; puedes decir varias cosas a la vez. Toca Listo y TaskFlow te muestra una tarea por cada cosa, con su día y su hora. Añádelas todas con un toque. También puedes preguntar qué tienes esta semana, o mover, cambiar o eliminar una tarea hablando: TaskFlow te enseña el cambio antes y puedes deshacerlo. Necesita internet: tus palabras se envían a Google para convertirlas en tareas.»
     - CA: «Com afegeixo tasques parlant?» — «Toca Afegeix una tasca i digues el que has de fer, amb les teves paraules; pots dir diverses coses alhora. Toca Fet i TaskFlow et mostra una tasca per cada cosa, amb el dia i l’hora. Afegeix-les totes amb un toc. També pots preguntar què tens aquesta setmana, o moure, canviar o suprimir una tasca parlant: TaskFlow t’ensenya el canvi abans i el pots desfer. Necessita internet: les teves paraules s’envien a Google per convertir-les en tasques.»
  - The words follow the app: `addTask`, `done` (Done / Listo / Fet), `taskDeleted` (eliminar / suprimir), `undo`.
- Verify:
  - The home has no visible "voice-to-task", "transcribes" or "drafts".
  - A heading and the FAQ say several things at once.
  - Walkthrough: a reader of the card can predict the app's "2 things to add" sheet.
- Evidence: verified in code and decisions; seen in the current renders.

**WEB-106 · Severity 2 · Reminders, the core loop's third step, are never told**
- Recheck: confirmed. D2's question is in the app (`App/lib/widgets/reminder_ask_sheet.dart:140`; "Want a reminder before it?", `app_en.arb:1037`). Copy corrected: only tasks with a date get reminders.
- Where: the calendar card, `page.tsx:172-176`. The only mention is "Small reminders" (`:63`).
- The moment: "If I put it in, will it remind me? I forget things." The page has no answer.
- What happens: TaskFlow puts tasks on the calendar and reminds people about them (CLAUDE.md). The app asks once, after the first saved task with a date; date-only tasks remind at 9:00 (D2, `DECISIONS.md:163-169`). The site never says so, so the app's one question arrives unexplained.
- Why it fails: HE-11 (say it, see it on your calendar, get reminded), B lens (being reminded is a key benefit for older people), FN-3 (prepare people for the app's one question).
- Fix: the calendar card's second sentence (the first is WEB-504's):
  - EN: "TaskFlow can remind you of tasks with a date: it asks once, the first time you add one."
  - ES: «TaskFlow puede recordarte las tareas con fecha: te lo pregunta una vez, la primera vez que añades una.»
  - CA: «TaskFlow et pot recordar les tasques amb data: t’ho pregunta una vegada, la primera vegada que n’afegeixes una.»
- Verify: the card states reminders, and the wording matches D2 (one question, at the first dated task).
- Evidence: verified in code and decisions.

**WEB-107 · Severity 2 · Sharing FAQ says "lists" and describes the old invite**
- Recheck: confirmed. The person filter and «Creada por» are now in the app (44f6a08; `App/build/project-people-filter-es.png`, `task-created-by-es.png`). Invitations still need a code, which the email now carries.
- Where: the FAQ "Can I share a list?", `page.tsx:23-24` (closed; phone screen 11).
- The moment: an invitee arrives from «Ana te invita a unirte al proyecto «Casa»», looks for "proyecto", and reads "list", "shares a code separately" and "still being tested".
- What happens:
  - The app calls them projects: «Proyectos», «Proyectos compartidos» (`app_en.arb:211`; standing decision, `DECISIONS.md:225-231`).
  - The invitation email carries the code and a button (`Backend/core/invitation_email.py:28-30`).
  - Everyone joins as an editor (D15b).
  - In a shared project, each task shows «Creada por» (`App/lib/screens/task_detail_screen.dart:236`), and the project page filters by person («Todas · Para mí · Ana · Paul»).
- Why it fails: FN-2 (the app's names), FN-1 (an outdated flow), B lens (sharing chores with family creates desire), SC-4 (the question's first words).
- Fix, `page.tsx:23-24`:
  - EN: "Can I share tasks with my family?" — "Yes. Share a project, such as Home or Shopping: tap Share and invite someone by email. Once they accept, everyone in the project sees its tasks. Each task shows who created it, and you can see just one person's tasks."
  - ES: «¿Puedo compartir tareas con mi familia?» — «Sí. Comparte un proyecto, como Casa o Compras: toca Compartir e invita a alguien por correo. Cuando acepte, todos los miembros ven sus tareas. Cada tarea muestra quién la creó, y puedes ver solo las de una persona.»
  - CA: «Puc compartir tasques amb la meva família?» — «Sí. Comparteix un projecte, com Casa o Compres: toca Comparteix i convida algú per correu. Quan accepti, tots els membres en veuen les tasques. Cada tasca mostra qui l’ha creada, i pots veure només les d’una persona.»
  - The examples come from `listsEmptyHelp`, the button from `shareProject`.
- Verify: no visible "list" means a project; the names match `lists`, `shareProject` and `createdBy` in each ARB.
- Evidence: verified in code; seen in the app's renders.

**WEB-108 · Severity 2 · Both demos show a review step the app lacks**
- Recheck: confirmed. WD1 decided that the walkthrough goes, so removing it fixes that half. The live demo's half is in the ledger with WEB-9 (WP8), and the current renders still show it.
- Where:
  - The walkthrough, `src/components/TaskDemo.tsx:212-284`: Task title, Date, Time, Priority and a note, then "Add to my preview"; "· High priority" in the saved line (`:326`). Renders `sample-*.png`; phone screens 7–8.
  - The noscript text, `page.tsx:310-316`: "an editable draft with a title, schedule, priority, and notes" (`home-nojs.en.mobile.light.full.png`, screen 8).
  - The live demo, `VoiceDemo.tsx:672-679`: every card opens with "Task 1 · High Priority"; and `:22`: "Whenever you're ready" when there's no date (`voice-result.en.mobile.light.panel.png`, `voice-last-try.en.mobile.light.panel.png`).
- The moment: "So I fill in a form?", right under "No field-by-field thinking." (`page.tsx:305`).
- What happens:
  - The app's result is the title, then the date as one line, then the notes and «Más opciones», then «Añadir al calendario». A batch shows cards with title and date, then «Añadir 2 tareas» (`App/build/review-direct-light.png`, `review-batch-light.png`; D3).
  - The app folds priority away and says «Sin fecha» when there's no date.
- Why it fails: FN-3, FN-4 (the demo sets honest expectations), AP-13 (it teaches one thing), HE-11.
- Fix:
  1. Remove the walkthrough and the noscript paragraph (WD1); its static example replaces both, without JavaScript too.
  2. In WP8 (WEB-9), each card opens with the title, then the date line ("No date" / «Sin fecha» / «Sense data» when there's none), then the notes. No "Task N" and no priority pill.
- Verify: no `voice-result*` render shows a priority first or "Whenever you're ready"; the home has no `#demo` form.
- Evidence: verified in code; seen in the current renders (site and app).

**WEB-109 · Severity 2 · The site names features differently from the app**
- Recheck: confirmed, with two rows added ("Whenever you're ready", "your list"). Most rows are now fixed inside other findings.
- Where: the table; home, the live demo, metadata and the legal pages.
- The moment: after installing, the visitor looks for "voice-to-task", "drafts" or "lists", and finds Add a task, "things to add" and Projects. Nothing they learned carries over.
- What happens: the site uses words the app never shows. No visible string in the ARB files says "draft", "voice-to-task" or "allowance".

  | The site says | Where | The app says (EN / ES / CA) | Fixed by |
  |---|---|---|---|
  | "voice-to-task" | `page.tsx:11`; `VoiceDemo.tsx:373`; `layout.tsx:13`; terms `en.ts:221` | dictation / dictado / dictat (`freeVoice*`) | WEB-105; WEB-12 (WP8); WEB-302 (WP9); WEB-209 |
  | "drafts", "Create drafts", "{n} drafts, ready for you" | `page.tsx:12`; `VoiceDemo.tsx:388, 395, 594, 621`; privacy `en.ts:139` | "{n} things to add", "Add {n} tasks" / «cosas para añadir», «Añadir {n} tareas» / «coses per afegir», «Afegeix {n} tasques» | WEB-105; WEB-9 (WP7, WP8); privacy §8 with WD3 |
  | "voice trial", "daily voice allowance", "AI allowance", "Your allowance returns" | `page.tsx:12, 20`; `VoiceDemo.tsx:439, 820` | "free dictations" for the app; the demo's tries stay the demo's (WD8) | WEB-101; WEB-12 |
  | "list", "shared list", "your list" | `page.tsx:16, 23-24, 117` | project, shared project / proyecto / projecte (`lists`, `projectsShared`) | WEB-107; `:16` here; `:117` with WEB-1 (WP3) |
  | "attachments", "6 MiB" | `page.tsx:256, 259` | Files, "6 MB" / Archivos / Fitxers adjunts (`attachments`, `fileUploadHelp`) | WEB-101 |
  | "Choose Task or Note when capturing" | `page.tsx:28` | Add a note / Añadir nota / Afegeix una nota (`addNote`) | WEB-110 |
  | "Account sync" | `page.tsx:16` | not an app word; "saved to your account" | here |
  | "Whenever you're ready" (no date) | `VoiceDemo.tsx:22` | No date / Sin fecha / Sense data (`noDate`) | WEB-108, WEB-9 (WP8) |
  | "Task 1 · High priority" | `VoiceDemo.tsx:673-678` | no label: the title, then the date | WEB-108, WEB-9 (WP8) |

- Why it fails: FN-2 (the app's names, in each language), G lens (one concept, one name), HE-10 (no "AI", "sync" or "allowance" on the main path), ML-6.
- Fix, the row marked "here": the offline answer, `page.tsx:16`:
  - EN: "Yes. Your tasks are saved on your phone, so you can check, add and complete them without internet. Saving to your account, understanding what you say, and uploading files need a connection."
  - ES: «Sí. Tus tareas se guardan en el móvil: puedes consultarlas, añadirlas y completarlas sin internet. Guardar en tu cuenta, entender lo que dices y subir archivos necesitan conexión.»
  - CA: «Sí. Les tasques es desen al mòbil: pots consultar-les, afegir-ne i completar-les sense internet. Desar al compte, entendre el que dius i pujar fitxers necessiten connexió.»
- Verify: no page's visible text, alt or aria-label contains "voice-to-task", "draft", "allowance", "shared list", "MiB" or "Whenever you're ready", in any language; each feature name appears in its language's ARB.
- Evidence: verified in code (site and ARB files).

**WEB-110 · Severity 2 · Notes FAQ describes a Task/Note choice the app removed**
- Recheck: confirmed. Also outdated: "recorded notes need online transcription", because the app recognises speech on the phone where it can (`app_en.arb:422`).
- Where: `page.tsx:27-28`.
- The moment: in the app, the visitor looks for the "Task or Note" choice when adding something, and it isn't there.
- What happens: D3 removed the Task/Note choice from capture (`DECISIONS.md:170-176`). Notes come from the Notes tab with «Add a note», written or dictated (`app_en.arb:72-77`). "Typed notes work locally; recorded notes need online transcription" is jargon.
- Why it fails: FN-1, FN-2, HE-10.
- Fix, the answer at `page.tsx:28`:
  - EN: "Yes. The Notes tab keeps what you want to remember that isn't a task, like a Wi-Fi password. Tap Add a note, then write or dictate it; add links or a checklist if you like."
  - ES: «Sí. La pestaña Notas guarda lo que quieres recordar y no es una tarea, como la clave del wifi. Toca Añadir nota y escríbela o díctala; si quieres, añade enlaces o una lista de pasos.»
  - CA: «Sí. La pestanya Notes desa el que vols recordar i no és una tasca, com la contrasenya del wifi. Toca Afegeix una nota i escriu-la o dicta-la; si vols, afegeix-hi enllaços o una llista de passos.»
  - The example is `noteTitleHint`; the steps are `notesEmptyHelp`.
- Verify: no "Choose Task or Note" or "transcription"; the names match `notes` and `addNote` in each ARB.
- Evidence: verified in code and decisions.

**WEB-111 · Severity 2 · Feature headings are mood lines; a scanner learns nothing**
- Recheck: confirmed with the measured outline (`AUDIT.md` §12). Two corrections:
  - The section H2 is now "What TaskFlow does", because WP3's new H1 already says "Say it, and it's on your calendar." and WP6's menu calls this section "What it does" (NV-4).
  - The FAQ's H2 is added.
- Where: the H2, `page.tsx:154-158`, and its intro, `:160-164`; the card headings, `:172, :230, :254, :274`; the FAQ's H2, `:369`. Render: `home.en.desktop.light.full.png` screen 2.
- The moment: a skimming Comparer reads "A place for everything. / See the shape of your day. / Say it. Get on with it. / The little details matter. / Life doesn't always have Wi-Fi. / Glad you asked." and asks "But what does it do?"
- What happens: none of the home's 12 headings (`AUDIT.md` §12) names the calendar, voice, reminders, Android, the price or how to get it. Screen-reader users who move by heading or landmark get the same mood lines: the regions are named "A place for everything. A little space for you." and "Glad you asked." (§9).
- Why it fails: SC-1 (the headings-only test), SC-4 (front-load the meaning), HE-3 (clear beats clever, and it translates badly), HE-11, AX-5 (2.4.6, descriptive headings), NV-4 (link text matches the target heading).
- Fix:
  - Section H2: EN "What TaskFlow does" / ES «Qué hace TaskFlow» / CA «Què fa TaskFlow». Remove the intro paragraph (`:160-164`).
  - Card headings:
    - `:172`: EN "Your day on one calendar" / ES «Tu día en un calendario» / CA «El teu dia en un calendari»;
    - `:230`: EN "Say several things at once" / ES «Di varias cosas a la vez» / CA «Digues diverses coses alhora»;
    - `:254`: EN "Notes, checklists and files" / ES «Notas, listas de pasos y archivos» / CA «Notes, llistes de passos i fitxers»;
    - `:274`: EN "Your tasks, even offline" / ES «Tus tareas, también sin conexión» / CA «Les tasques, també sense connexió».
  - FAQ H2, `:369`: EN "Questions" / ES «Preguntas» / CA «Preguntes», the same word as its menu item.
  - The card bodies are in WEB-101, WEB-105, WEB-106 and WEB-504.
- Verify: reading only the H1, H2s and H3s tells what TaskFlow does (calendar, several things by voice, reminders, details, offline); each menu label matches the start of its target heading.
- Evidence: verified in code; measured (`AUDIT.md` §9, §12).

**WEB-112 · Severity 2 · A whole section sells the theme switch** — ledger: merged into WEB-17 (H)
- Recheck: confirmed, with its size corrected: about 1.4 phone screens (y ≈ 5,350–6,285), not 2. Measured: its footnote is 9 px and its tag 7/6 px (`AUDIT.md` §6).
- Where: `page.tsx:320-358` (`#appearance`, "03 / Made to feel like you"), with `tasks-*.png` and `ThemeToggle variant="mood"` (`:353`). Phone screens 9–10 (`crops/home.en.mobile.light.full.s9-10.png`).
- The moment: "Light mode, dark mode… does it remind me of things?" The scroll shows nothing new about the product.
- What happens: one of four content sections sells the app's least important setting (D5: a switch in Ajustes › Apariencia), with the outdated tasks screenshot. Its button re-themes the website, which the header already does (`Header.tsx:47`). "A softer start. A quieter finish." says nothing.
- Why it fails: AT-4 (earn every scroll), HE-11, SC-1. Subtract first.
- Fix: remove the section, its `ThemeToggle variant="mood"` use, its `.appearance-*` styles and `tasks-*.png`.
- Verify: the home has one theme control, in the header; the phone render is about 930 px shorter; no tasks screenshot is left.
- Evidence: verified in code; seen in the current render; measured (§6).

**WEB-113 · Severity 2 · Privacy policy is behind the app on five points** — merges WEB-201 (L)
- Recheck: confirmed. It was "decision"; WD3 decided the edit, which stays uncommitted for the owner. It merges review L's five points. Two corrections:
  - The «Creada por» sentence must say what members see when you have no name: the start of your email address (`Backend/core/list_access.py:29-30`).
  - The RevenueCat sentence, which changed after the first review, is WEB-501.
- Where: privacy, all three languages: §1 `:21`; §2 `:29`; §4 `:55`; §5 `:75` and `:82`; §7 `:126`; §9 `en.ts:155`, `es.ts:149`, `ca.ts:149` (files in `src/content/legal/`). Renders: `privacy.{en,es,ca}.*.full.png`.
- The moment:
  - "I got an email from noreply@… with a 6-digit code. The privacy page never mentions it."
  - "The app said my voice becomes text on the phone. The page says recordings go to the cloud."
- What happens (each verified):
  1. **Email confirmation codes** (6 digits, valid 30 minutes, from the no-reply address; `Backend/docs/EMAIL_VERIFICATION.md:3`) are missing from §1, from Resend's role (§5) and from the code lifetimes (§7).
  2. **Google sign-in** keeps Google's first name when the account has none, and never the surname or photo (`Backend/docs/GOOGLE_SIGN_IN.md:69`). §2 doesn't say so.
  3. **Voice.** §4 says "Recordings are sent for cloud transcription when you submit a capture". The app first recognises speech on the phone, where it keeps no audio (`NativeSpeechBridge.kt:71, 203`; `capturePrivacy`, `app_en.arb:422`).
  4. **Phone calendars.** §9 describes "calendar entries you choose to turn into TaskFlow content". No such feature exists in `App/lib`, and the app promises that events are read-only and "stay on this device; they are not uploaded or sent to AI" (`app_en.arb:146`).
  5. **«Creada por».** §5 doesn't say that members see who created each task and can filter by person.
- Why it fails: FN-1 (what the site says about data matches the app), PV-1 (plain and complete; GDPR art. 12), TR-2, FN-2.
- Fix (consistent with review L's copy):
  1. §1, `:21`: replace "Automated invitations and recovery messages come from taskflow.noreply@garbar.tech;" with:
     - EN: "Automatic emails (invitations, codes to confirm your email, and password recovery) come from taskflow.noreply@garbar.tech;"
     - ES: «Los correos automáticos (invitaciones, códigos para confirmar el correo y recuperación de la contraseña) se envían desde taskflow.noreply@garbar.tech;»
     - CA: «Els correus automàtics (invitacions, codis per confirmar el correu i recuperació de la contrasenya) s’envien des de taskflow.noreply@garbar.tech;»
  2. §2, `:29`: replace the Google sentence with:
     - EN: "With Google sign-in, we receive your Google account identifier, your email, whether Google has verified it, and your first name, which becomes your TaskFlow name if you haven't set one. We don't keep your surname or photo. Password sign-ups confirm their email with a 6-digit code that expires after 30 minutes."
     - ES: «Si entras con Google, recibimos tu identificador de Google, tu correo, si Google lo ha verificado y tu nombre de pila, que pasa a ser tu nombre en TaskFlow si no tienes otro. No guardamos tus apellidos ni tu foto. Si te registras con contraseña, confirmas tu correo con un código de 6 cifras que caduca a los 30 minutos.»
     - CA: «Si entres amb Google, rebem l’identificador de Google, el correu, si Google l’ha verificat i el teu nom de pila, que passa a ser el teu nom a TaskFlow si no en tens cap altre. No desem els cognoms ni la foto. Si et registres amb contrasenya, confirmes el correu amb un codi de 6 xifres que caduca als 30 minuts.»
  3. §4, `:55`: replace "Recordings are sent for cloud transcription when you submit a capture; typed AI input is also sent when you request interpretation." with:
     - EN: "Where your phone can recognise speech on the device, your voice becomes text on the phone and no audio is kept; only the words are sent to become tasks. Otherwise the recording is sent to be transcribed online when you submit it. With Pro, sentences you type are sent the same way; the task form never sends anything to the AI."
     - ES: «Si tu teléfono puede reconocer la voz por sí mismo, tu voz se convierte en texto en el teléfono y no se guarda audio; solo se envían las palabras para crear las tareas. Si no puede, la grabación se envía para transcribirla en línea al enviarla. Con Pro, las frases que escribes se envían igual; el formulario de tareas nunca envía nada a la IA.»
     - CA: «Si el telèfon pot reconèixer la veu pel seu compte, la veu es converteix en text al telèfon i no es desa àudio; només s’envien les paraules per crear les tasques. Si no pot, la gravació s’envia per transcriure-la en línia en enviar-la. Amb Pro, les frases que escrius s’envien igual; el formulari de tasques no envia mai res a la IA.»
  4. §5, `:75`: after the first sentence, add the sentence below, and write "shared project" for "shared project/list":
     - EN: "In a shared project, members see who created each task (“Created by”): your name or, if you haven't set one, the start of your email address. They can also show one person's tasks."
     - ES: «En un proyecto compartido, los miembros ven quién creó cada tarea («Creada por»): tu nombre o, si no tienes, el principio de tu correo. También pueden ver solo las tareas de una persona.»
     - CA: «En un projecte compartit, els membres veuen qui ha creat cada tasca («Creada per»): el teu nom o, si no en tens, l’inici del teu correu. També poden veure només les tasques d’una persona.»
  5. §5, Resend, `:82`: EN "invitation, email-confirmation and password-recovery emails"; ES «correos de invitación, de confirmación del correo y de recuperación de la contraseña»; CA «correus d’invitació, de confirmació del correu i de recuperació de la contrasenya».
  6. §7, `:126`:
     - EN: "Invitations and codes: invitation codes expire after seven days, and email-confirmation and recovery codes after 30 minutes."
     - ES: «Invitaciones y códigos: los códigos de invitación caducan a los siete días, y los de confirmación del correo y de recuperación, a los 30 minutos.»
     - CA: «Invitacions i codis: els codis d’invitació caduquen als set dies, i els de confirmació del correu i de recuperació, als 30 minuts.»
  7. §9: replace the calendar sentence:
     - EN: "Events from your phone's calendars are shown read-only and stay on the phone: they're never uploaded or sent to the AI."
     - ES: «Los eventos de los calendarios del teléfono se muestran solo para consulta y se quedan en el teléfono: no se suben ni se envían a la IA.»
     - CA: «Els esdeveniments dels calendaris del telèfon es mostren només per consultar-los i es queden al telèfon: no es pugen ni s’envien a la IA.»
  - `company.version` moves to the day of the edit (WD3). These are the other session's untracked files: the change stays uncommitted.
- Verify: Playwright text on `/privacy/`, `/es/privacy/` and `/ca/privacy/`:
  - `#controller`, `#sharing` and `#retention` mention confirmation codes;
  - `#data` mentions the first name;
  - `#voice` no longer contains "Recordings are sent for cloud transcription when you submit a capture";
  - `#sharing` names «Creada por» in each language;
  - `#permissions` says calendar events stay on the phone.
- Evidence: verified in code (both repos).

**WEB-501 · Severity 2 · Privacy and delete pages say RevenueCat's record stays**
- New since the first review: the server changed on 2026-10-18 (commit d447c5c).
- Where:
  - Privacy §7: `src/content/legal/en.ts:128`, `es.ts:128`, `ca.ts:128` ("Account deletion does not automatically delete RevenueCat's separate customer record or the store's transaction history").
  - Delete-account §3: `en.ts:375`, `es.ts:369`, `ca.ts:370` ("the in-app operation does not automatically delete the RevenueCat customer record").
  - `tests/legal.spec.ts:133-135` asserts the old sentence.
  - Renders: `privacy.*.full.png` (§7), `delete-account.*.full.png` (§3).
- The moment: the Leaver, already uneasy: "So even after I delete my account, the payment company keeps my record, and I have to email them about it?" An extra worry, and an email nobody needs to send.
- What happens:
  - Deleting an account now deletes its RevenueCat customer once the deletion commits. It's best effort: a failure is logged without the ID and never blocks the deletion (`Backend/docs/ACCOUNT_DELETION.md:32, 64`; `.claude/ux-review/DECISIONS.md:44`).
  - Google Play's own purchase records are untouched (`ACCOUNT_DELETION.md:33`).
  - Both pages, in all three languages, still say the opposite.
- Why it fails: FN-1 (every claim true today), PV-7 (the delete page says what's deleted and what's kept: TaskFlow's bar, GDPR art. 13), TR-3 (errors are trust bugs).
- Fix (WD3 allows legal edits; the other session's files, so the change stays uncommitted):
  1. Privacy §7, `:128`: replace the RevenueCat sentence with:
     - EN: "When you delete your account, we also ask RevenueCat to delete its customer record. The store keeps its own purchase history; contact support to include other provider-held data in an erasure request."
     - ES: «Cuando eliminas tu cuenta, también pedimos a RevenueCat que borre su registro de cliente. La tienda conserva su propio historial de compras; escribe a soporte para incluir otros datos de proveedores en una solicitud de supresión.»
     - CA: «Quan suprimeixes el compte, també demanem a RevenueCat que esborri el seu registre de client. La botiga conserva el seu propi historial de compres; escriu a suport per incloure altres dades de proveïdors en una sol·licitud de supressió.»
  2. Delete-account §3: start the bullet with the sentence below, then keep the rest from "contact support…":
     - EN: "Separate records: when the account is deleted, we also ask RevenueCat to delete its customer record. Store purchase history, support emails, security logs and recovery backups are separate;"
     - ES: «Registros independientes: al eliminar la cuenta, también pedimos a RevenueCat que borre su registro de cliente. El historial de compras de la tienda, los correos de soporte, los registros de seguridad y las copias de recuperación son aparte;»
     - CA: «Registres independents: en suprimir el compte, també demanem a RevenueCat que esborri el seu registre de client. L’historial de compres de la botiga, els correus de suport, els registres de seguretat i les còpies de recuperació són a part;»
  3. In `tests/legal.spec.ts:133-135`, assert "we also ask RevenueCat to delete its customer record" instead.
- Verify: `/privacy/#retention` and `/delete-account/#scope`, in all three languages, contain the new sentence and none of "does not automatically delete the RevenueCat" or its ES and CA equivalents.
- Evidence: verified in code (`Backend/core/account_deletion.py`, `billing.py`, commit d447c5c) and in the docs.

**WEB-502 · Severity 2 · The demo turns typed sentences into tasks; that's Pro**
- New: the app changed on 2026-10-18, when free accounts got a form instead of typed sentences.
- Where:
  - `src/components/VoiceDemo.tsx:494-506`: "Record a thought" / "Type it instead".
  - `:559-575`: the text box, whose sample holds three tasks.
  - `:585-596`: "Create drafts".
  - Renders: `voice-typing.en.mobile.light.panel.png`; `voice-result.en.mobile.light.panel.png` ("3 drafts, ready for you.", from a typed thought, per `INDEX.md`).
- The moment: "I'm not going to talk to my phone; I'll type it. Great, three tasks from one sentence!" After installing, a free account's keyboard opens a form for one task: "Where's the typing that made three tasks?"
- What happens:
  - In the app, turning typed words into tasks is part of Pro. "Free accounts don't create tasks from free text. They get a form… Pro is unchanged: dictation, and typed words read by the assistant." (`.claude/ux-review/DECISIONS.md:68-78`; voice-commands-plan item 7).
  - For an account without Pro, the capture sheet's «Escribir» opens the form (`App/lib/screens/voice_task_screen.dart:2130-2161`).
  - The demo offers typing as an equal alternative to speaking, and never says it's a Pro capability in the app.
- Why it fails: FN-1 ("Pro-only features say so"), FN-4 (never more forgiving than the app), lens O (never shows what the app can't do: here, the free app). The typing option itself must stay (PV-3, AX-10).
- Fix: keep the option, and say it where it's chosen, under the text box (`VoiceDemo.tsx:574`). It goes with H's WP7/WP8 and stays uncommitted.
  - EN: "In the app, turning typed sentences into tasks is part of TaskFlow Pro. Without Pro, you say them, or add each task with a short form."
  - ES: «En la app, convertir frases escritas en tareas es parte de TaskFlow Pro. Sin Pro, las dices, o añades cada tarea con un formulario sencillo.»
  - CA: «A l’app, convertir frases escrites en tasques forma part de TaskFlow Pro. Sense Pro, les dius, o afegeixes cada tasca amb un formulari senzill.»
  - WEB-104's FAQ answer says the same from the Pro side ("also turns sentences you type into tasks").
- Verify: in the `voice-typing` renders, in each language, the line shows under the text box; it doesn't show in voice mode.
- Evidence: verified in code (site and app) and decisions; seen in the current demo renders.

**WEB-504 · Severity 2 · Comparers never learn their phone calendar comes along**
- New as a finding (the first review only listed it under "Missing").
- Where: the calendar card, `page.tsx:172-176` (phone screen 3–4; desktop screen 2). No FAQ answer mentions it either.
- The moment: the Comparer, who lives in Google Calendar: "Do I have to move everything? Will I see my appointments next to these tasks?" The page doesn't say.
- What happens:
  - TaskFlow shows events from the phone's calendars beside your tasks, read-only, and they stay on the phone ("See events from calendars connected to this phone beside your tasks.", `app_en.arb:144-146`, «Calendarios del teléfono»; B20, `App/docs/IMPLEMENTATION_STATUS.md:28`; in Ajustes › Otros ajustes).
  - The site never says so, and the privacy page describes a different feature that doesn't exist (WEB-113, §9).
- Why it fails: B lens (the benefit that answers "I already have a calendar"), SC-8 (the Comparer's task), HE-11 (told briefly, inside the core loop's calendar card). It's one clause in an existing card: a sharpening, not a new section.
- Fix: the calendar card's first sentence, before WEB-106's:
  - EN: "See your tasks by day, week or month, beside the events from your phone's calendars if you like."
  - ES: «Mira tus tareas por día, semana o mes, junto a los eventos de los calendarios del teléfono si quieres.»
  - CA: «Mira les tasques per dia, setmana o mes, al costat dels esdeveniments dels calendaris del telèfon si vols.»
- Verify: the card names the phone's calendars in each language, in the words of `deviceCalendars` and `deviceCalendarHelp`.
- Evidence: verified in code (ARB files and the B20 record).

**WEB-114 · Severity 1 · Sample dates are a month old**
- Recheck: confirmed and measured. Narrowed: the walkthrough's dates go with WD1, and the hero screenshot's "Monday, 21 September" with WD4. What's left is the calendar drawing.
- Where: `page.tsx:180-183`: "A good week ahead … September 2026", days 21–27 (`AUDIT.md` §6 lists "September" and "2026" at 9/7 px). Phone screens 3–4.
- The moment: on 19 October the page plans a week in September: "Is anyone still working on this?"
- What happens: the sample dates the page.
- Why it fails: TR-3 (keep content fresh).
- Fix: remove "September 2026" (`:181-183`). Keep the day numbers without a month.
- Verify: no month or year in sample content on any page.
- Evidence: verified in code; measured.

**WEB-503 · Severity 1 · Opening one FAQ answer closes the one you read**
- New.
- Where: `src/app/page.tsx:386`: `<details … name="questions">` on all 7 items. Renders: `home-faq.en.{desktop,mobile}.light.view.png` (one answer open).
- The moment: the Comparer opens "Do I need an account?", then "Will TaskFlow be free?" to compare them, and the first answer snaps shut: "Where did that go?"
- What happens:
  - A shared `name` makes native `<details>` an exclusive accordion: opening one item closes the others.
  - Two answers can never be open side by side.
  - On a phone, closing an answer above the one just opened shortens the page above it. Browsers with scroll anchoring hold the position; others jump (inferred).
- Why it fails: FQ-3 (several items open at once; no disorienting jump on phones), FQ-1.
- Fix: remove `name="questions"` (`:386`). Nothing else changes.
- Verify: Playwright: open two FAQ items; both keep `[open]`. Device: Safari on an iPhone, open the 6th answer with the 1st open.
- Evidence: verified in code; the jump is inferred and needs a device check.

### Claims checked
Status: **true**; **false**; **outdated**; **incomplete** (true, but it misses an app change); **name** (true, in words the app doesn't use); **label** (a misleading control label). Legal lines are the same in `en.ts`, `es.ts` and `ca.ts` unless noted.

| # | Claim (page, `path:line`) | Source of truth (`path:line`) | Status |
|---|---|---|---|
| | **Home, FAQ** | | |
| 1 | In development, "Android as the first testing platform", public download later, `src/app/page.tsx:8` | `.claude/ux-web/DECISIONS.md` WD7, WD9 | outdated ("first testing platform" vs Android only) |
| 2 | "explore the real app screens" `:8` | `public/images/*` (2026-09-21) vs `App/build/calendar-es-1.3x-light.png` | outdated |
| 3 | "try the interactive walkthrough on this page" `:8` | WD1 | true until WD1 lands |
| 4 | "TaskFlow transcribes your recording" `:12` | `NativeSpeechBridge.kt:71`; `app_en.arb:422` | outdated |
| 5 | AI suggests tasks with titles, dates, times, priorities, notes; check the drafts `:12` | `Backend/docs/VOICE_COMMANDS.md`; `review-direct-light.png` | incomplete (several tasks, commands, Undo) |
| 6 | "AI processing needs an internet connection" `:12` | `app_en.arb:422-423` | true |
| 7 | "A limited voice trial is available without an account" `:12` | `.claude/ux-review/DECISIONS.md:126-129` | false |
| 8 | Offline: create, edit, complete; sync, AI and files need a connection; downloaded files work `:16` | `IMPLEMENTATION_STATUS.md:27, 47` | true (names: "sync", "shared-list") |
| 9 | Tasks and "a limited daily voice allowance without an account" `:20` | `DECISIONS.md:126-129`; `Backend/config/settings.py:144` | false |
| 10 | "Sign in to… get a larger AI allowance" `:20` | same | false |
| 11 | Account recovery `:20` | `App/artifacts/auth/login-light.png` ("Forgot password?") | true |
| 12 | "Older device-only files need an explicit upload" `:20` | `app_en.arb:1021-1022` (pre-login local files only) | outdated |
| 13 | "supports shared lists" `:24` | `app_en.arb:211`; `DECISIONS.md:225-226` | name |
| 14 | "shares a code separately" `:24` | `Backend/core/invitation_email.py:28-30` | outdated |
| 15 | Recipients choose to accept `:24` | `invitation_email.py:35` | true |
| 16 | Editors change, viewers read `:24` | `voice-commands-plan.md:15`; D15b | true |
| 17 | "still being tested before public release" `:24` | WD9, WD13 | true |
| 18 | A Notes view with checklists and links `:28` | `app_en.arb:72-77` | true |
| 19 | "Choose Task or Note when capturing" `:28` | `DECISIONS.md:176` | false |
| 20 | "recorded notes need online transcription" `:28` | `app_en.arb:422` | outdated |
| 21 | "Launch pricing has not been announced" `:32` | `App/docs/REVENUECAT_SETUP.md` (Test Store) | true |
| 22 | "no paid plans or subscriptions… on this website" `:32` | `DECISIONS.md:68-78, 130-153`; `app_en.arb:1686-1702, 1899-1975`; WD2 | outdated (omits Free and Pro) |
| | **Home, body** | | |
| 23 | "Small reminders" `:63` | D2; `app_en.arb:1037` | true |
| 24 | "JUST SAY THE WORD — ‘A walk at six.’" `:101-102` | `DECISIONS.md:107-110` | true |
| 25 | "That belongs on your list, too." `:117` | `app_en.arb:211` | name |
| 26 | Hero screenshot and alt, `:110`, `Phone.tsx:4` | `calendar-es-1.3x-light.png`; `task_actions.dart:102` | outdated |
| 27 | Calendar first; month and week `:174-175` | `app_en.arb:297-299`; `DECISIONS.md:223` | true (phone calendars untold, WEB-504) |
| 28 | "September 2026" `:182` | today, 2026-10-19 | outdated |
| 29 | "Turn a passing thought into a task… review the details before you save" `:232-233` | `DECISIONS.md:99-106` | incomplete |
| 30 | "Notes, priorities, and attachments" `:256` | `app_en.arb:229, 231` | name |
| 31 | "Sign in to upload files and download them on another device" `:257-258` | `DECISIONS.md:126-129` | false |
| 32 | "task details show which files are backed up" `:258` | `app_en.arb:622` | true |
| 33 | "Up to 6 MiB per file" `:259` | `settings.py:103`; `app_en.arb:1021` ("6 MB") | name |
| 34 | "Keep planning with tasks on your phone" `:276` | `IMPLEMENTATION_STATUS.md:47` | true |
| 35 | "Sign in to back them up when you're connected" `:276-277` | `DECISIONS.md:126-129` | false |
| 36 | "No perfect wording. No field-by-field thinking." `:305` | D3 | true (contradicted by the walkthrough, WD1) |
| 37 | Noscript: a draft "with a title, schedule, priority, and notes" `:312-314` | `review-direct-light.png` | outdated |
| 38 | Tasks screenshot and alt, `:327`, `Phone.tsx:7` | four tabs, `calendar-feedback-light.png` | outdated |
| 39 | Light or dark mode `:340-342` | D5, `DECISIONS.md:184` | true |
| 40 | "Android app in development · Public download coming soon" `:423-424` | WD9 | true (10 px) |
| | **Header, footer, metadata** | | |
| 41 | "Get TaskFlow" `Header.tsx:62-64` | WD9 | label |
| 42 | "Explore the app" → `/#demo` `Header.tsx:48-50` | site code (the walkthrough) | label |
| 43 | "Try the demo" → `/#demo` `Footer.tsx:22` | WD1 | label (the anchor goes with WD1) |
| 44 | "Contact support" → taskflow.support@garbar.tech `Footer.tsx:31` | CLAUDE.md, Email | true |
| 45 | "calm task planner… calendar, priorities, and voice-to-task capture" `layout.tsx:12-13` | `app_en.arb:674` (`authPitch`) | name |
| | **Live demo** (`src/components/VoiceDemo.tsx`) | | |
| 46 | "Try real voice-to-task" `:373` | demo `src/lib/voice/model.ts:51` (gemini-3.5-flash-lite) vs app `settings.py:126, 134` | name; another model than the app (WD8) |
| 47 | "3 free tries · no account"; "Three submissions in a rolling 24 hours" `:377, :600` | `src/lib/voice/policy.ts:3-4, 44-57` | true of the demo (WD8) |
| 48 | "Speak in English, Spanish, or Catalan" `:387` | the app's three ARB languages | true |
| 49 | Sent to Google only on "Create drafts" `:394-395` | site code | true |
| 50 | Typed sentences become tasks `:494-506, 559-575` | `DECISIONS.md:68-78`; `voice_task_screen.dart:2130-2161` | incomplete (Pro-only in the app, WEB-502) |
| 51 | Preview tasks don't reach the app `:601-602, 813-814` | site code | true |
| 52 | Cards open "Task N · {priority} priority" `:673-678` | `review-batch-light.png` | outdated |
| 53 | "Whenever you're ready" for no date `:22` | `app_en.arb:198` | name |
| 54 | "The sample walkthrough below is always available" `:828`; `src/lib/voice/security.ts:15, 98`; `policy.ts:87` | WD1 | true until WD1 lands |
| | **Sample walkthrough** (removed by WD1) | | |
| 55 | Review step with Priority, "Add to my preview" `TaskDemo.tsx:212-284` | `review-direct-light.png` | outdated |
| 56 | "a sample week in September 2026" `TaskDemo.tsx:167-168` | today | outdated |
| | **Privacy** (`src/content/legal/*.ts`) | | |
| 57 | Summary: voice is optional and uses Google AI `en.ts:10` | `app_en.arb:422` | true |
| 58 | §1 automatic emails: invitations and recovery `:21` | `EMAIL_VERIFICATION.md:3` | incomplete |
| 59 | §2 from Google: identifier, email, verification status `:29` | `GOOGLE_SIGN_IN.md:69` | incomplete |
| 60 | §2 usage counts to apply allowances `:33` | `free-tier-plan.md` §2.1 | true |
| 61 | §3 the AI suggests titles, dates, priorities `:48` | `VOICE_COMMANDS.md` | true |
| 62 | §4 "Recordings are sent for cloud transcription when you submit a capture" `:55` | `NativeSpeechBridge.kt:71`; `app_en.arb:422` | outdated |
| 63 | §4 AI Studio with a Vertex fallback; the demo on Vertex `:56` | `settings.py:126-135`; `model.ts:51` | true |
| 64 | §5 shared content by role `:75` | `task_detail_screen.dart:236`; `list_access.py:29-30` | incomplete |
| 65 | §5 Resend: invitation and recovery emails `:82` | `EMAIL_VERIFICATION.md:3` | incomplete |
| 66 | §5 "Google Play or Apple handles its own store payments" `:84` | WD7 | outdated (Apple) |
| 67 | §5 staging: no-charge test purchases `:84` | `app_en.arb:1692` | true |
| 68 | §7 completed tasks aren't erased after 30 or 90 days `:122` | `DECISIONS.md:38-40` (none for now) | true |
| 69 | §7 invitation codes 7 days, recovery codes 30 minutes `:126` | `EMAIL_VERIFICATION.md:3` | incomplete |
| 70 | §7 deletion doesn't delete RevenueCat's customer record `:128` | `ACCOUNT_DELETION.md:32` | outdated (WEB-501) |
| 71 | §8 quotes the demo's "Create drafts" `:139` | `VoiceDemo.tsx:594` | true; follows WEB-9's rename |
| 72 | §9 "calendar entries you choose to turn into TaskFlow content" `en.ts:155`, `es.ts:149`, `ca.ts:149` | `app_en.arb:146`; no such feature in `App/lib` | false |
| 73 | §9 permissions: microphone, notifications, files, camera, calendar `en.ts:155` | `app_en.arb:144-146`; B20 | true |
| | **Terms, legal notice, delete-account** | | |
| 74 | A private staging test; no public checkout or download `en.ts:205` | WD9, WD13 | true |
| 75 | "optional voice-to-task drafts… shared projects/lists" `en.ts:221` | ARB files | name |
| 76 | Manage "an Apple/Google subscription" `en.ts:248` | WD7 | outdated (Apple) |
| 77 | No web subscription payments `en.ts:249` | site code | true |
| 78 | Settings → Account → Delete account (Ajustes → Cuenta → Eliminar cuenta; Configuració → Compte → Suprimeix el compte) `en.ts:269, 355`; `es.ts:263, 349`; `ca.ts:263, 350`; `index.ts:48, 91, 134` | `settings_screen.dart:110`; `account_screen.dart:314-316`; ARBs | true |
| 79 | Counts, handovers, a copy without files; password or Google; needs internet `en.ts:355-356` | `ACCOUNT_DELETION.md:35-53` | true |
| 80 | What's deleted and what stays `en.ts:373-374` | `ACCOUNT_DELETION.md:20-31` | true |
| 81 | The in-app deletion doesn't delete the RevenueCat customer `en.ts:375`, `es.ts:369`, `ca.ts:370` | `ACCOUNT_DELETION.md:32` | outdated (WEB-501) |
| 82 | No automatic confirmation email `en.ts:382` | `ACCOUNT_DELETION.md:12, 63` | true |
| 83 | Deleting doesn't cancel a Google Play subscription `en.ts:397` | `app_en.arb:2136` | true (its Apple half: row 76, WEB-210) |
| | **A way in** | | |
| 84 | Invitation email: "coming soon to Google Play… see what it does at taskflow.garbar.tech" `invitation_email.py:32, 50, 68` | WD9 | true (lands on the English home today, WEB-2) |

Totals: 84 claims: 7 false, 19 outdated, 8 incomplete, 8 name, 3 label, 39 true.

### Missing from the site (app features worth telling)
In order of desire; the first five are findings, the rest are brief or for later (HE-11):
1. **Several tasks in one dictation**, added with one tap. Source: `DECISIONS.md:99-106`; `app_en.arb:1566, 1576`. Where: the voice card and the FAQ (WEB-105).
2. **Reminders, asked for once.** Source: D2, `DECISIONS.md:163-169`; `reminder_ask_sheet.dart:140`. Where: the calendar card (WEB-106).
3. **The free plan and TaskFlow Pro.** Source: `DECISIONS.md:68-78, 130-153`; WD2. Where: the FAQ, the closing card and after the demo (WEB-104).
4. **The phone's calendar events beside your tasks**, read-only, staying on the phone. Source: `app_en.arb:144-146`; B20. Where: the calendar card (WEB-504).
5. **Sharing a project with family**: invite by email, «Creada por», a filter by person. Source: `voice-commands-plan.md` items 4, 6, 8; `project-people-filter-es.png`. Where: the FAQ (WEB-107). A section was declined (WD10).
6. **Voice commands**: "what do I have this week?", moving, changing and deleting by voice with the change shown first and «Deshacer», creating a project by voice. Source: `Backend/docs/VOICE_COMMANDS.md`; 985f060. Where: one sentence in the FAQ (WEB-105); creating projects can wait.
7. **Undo after every change** ("Tarea completada · Deshacer"). Source: D11, D12; `App/build/calendar-feedback-light.png`. Where: the voice FAQ covers changes made by voice; more is optional. It reassures wary people (OL-1).
8. **Google sign-in in one tap.** Source: `login-light.png`. Where: the account FAQ (WEB-101).
9. **The app in Spanish, Catalan and English.** Source: `App/lib/l10n/app_*.arb`. Where: the download FAQ (WEB-102).
10. **A home-screen mic button, launcher shortcuts, and sharing text into TaskFlow.** Source: `App/android/app/src/main/AndroidManifest.xml:46-61`; `app_en.arb:325-327`. Where: one clause in the voice card, later.
11. **Bringing tasks over from Todoist** (CSV import). Source: `App/lib/screens/data_transfer_screen.dart`. Where: a FAQ item for switchers; a new item, so the owner's call.
12. **Repeat, checklists and deadlines.** Source: `app_en.arb` (`repeatEvery`, checklist «Pasos»). Where: the "Notes, checklists and files" card (WEB-111).
13. **Which phones:** Android 7.0 or later (`minSdk` 24, `App/android/app/build.gradle:60`); speech on the phone needs Android 12. Leave it to the Play listing unless the Comparer asks.

### Keep
- No store badge, no download button and no price anywhere (AP-5, PR-6). Only the place and size of the availability line are wrong.
- The delete-account path and in-app steps match the app in all three languages (`index.ts:48, 91, 134`; `account_screen.dart:314-316`), and its lists of what's deleted and what stays match `ACCOUNT_DELETION.md` (except WEB-501).
- No testimonials, ratings, user counts or superlatives (TR-4, TR-5).
- Before the microphone, the live demo states the 60 s limit, that audio goes to Google only on a tap, and that its tasks never reach the app (PV-3; `VoiceDemo.tsx:393-397, 601-602`).
- The FAQ is native `<details>`/`<summary>`, so it works without JavaScript (`home-nojs` renders). Keep it, minus the shared `name` (WEB-503).

### Questions for the owner (product decisions only)
1. **"Unlimited" with a safety limit** *(legal check)*. WD2 publishes "TaskFlow Pro: unlimited dictation and file space", as the app says (`app_en.arb:1692`). But every account, Pro included, has these limits:
   - 50 AI requests a day (`Backend/config/settings.py:141`; `Backend/core/views.py:126-131`);
   - a 200-a-day budget shared by everyone (`settings.py:142`);
   - 6 MB a file, 20 files a task and 1,000 files (`DECISIONS.md:151`: "the copy avoids promising 'unlimited' for anything else").

   Recommendation: keep "unlimited" in the closing line and the demo line, and add one clause to the FAQ answer only: EN "(with a safety limit of 50 dictations a day)" / ES «(con un límite de seguridad de 50 dictados al día)» / CA «(amb un límit de seguretat de 50 dictats al dia)». Raise the shared 200-a-day budget before launch.
- The first review's six questions are decided:
  - a way to hear about the launch: WD9;
  - how much of the free plan to publish: WD2;
  - the demo against the free app: WD8;
  - a family section: WD10;
  - platforms: WD7;
  - the open app decisions: the app's 2026-10-18 night entry. Clean-up: none. RevenueCat: deleted, now WEB-501. Re-created accounts: accepted. Confirmation email: later.

### Cross-slice notes
- **H:** five links point to `/#demo`: the hero `page.tsx:68`, the closing card `:419`, the header `Header.tsx:9, 48` and the footer `Footer.tsx:22`. They break when WD1 removes the walkthrough; WEB-4's packages must retarget all five.
- **H:** the demo's messages that name the walkthrough (`VoiceDemo.tsx:828`; `src/lib/voice/security.ts:15, 98`; `policy.ts:87`) become false with WD1 (WEB-12).
- **H:** after a result, and when the tries are used, the demo hands over to nothing (WEB-7). WEB-104's line after the demo belongs in that block.
- **G:** in the WebKit renders every text uses the font's thinnest weight. Compare `webkit/home.en.mobile.light.fold.png` with Chromium's, and check the `@font-face` weight range of `Manrope.ttf`.
- **G:** no home text grows with the browser's text size (`AUDIT.md` §3: "every size is in px"), including the availability line and the FAQ (WEB-8, WEB-309).
- **L:** legal notice §2 (`en.ts:328`) says features "are only those expressly offered in the applicable listing or checkout". Once the home states the free plan (WD2), check it doesn't read as disowning the site's own claims *(legal check)*.
- **L:** privacy §8 (`en.ts:139`) quotes "Create drafts"; it follows WEB-9's rename (WP7).
- **L, tester:** `tests/legal.spec.ts:133-135` asserts the outdated RevenueCat sentence (WEB-501).
- **Main session:** the alt text in WEB-103/WEB-5 must match the task titles rendered into WD4's six images.

### Memory notes
- **Site map (unchanged since 2026-10-09 for `page.tsx`):**
  - Home order: hero, the promise bar, `#features` (4 cards), `#voice` (live demo), `#demo` (walkthrough, going with WD1), `#appearance` (going with WEB-17), `#questions` (7 `<details>` sharing `name="questions"`), `#get-taskflow`.
  - Phone full render: 13 screens. Features on 2–5; the demo on 5–6; the walkthrough on 7–8; appearance on 9–10; the FAQ on 10–11; the closing card on 12.
- **Claims map** (`page.tsx`):
  - account `:12, 20, 257, 276`; free and Pro `:32`; sharing `:24`; notes `:28`; offline `:16, 274-278`; voice `:11-12, 230-234`; calendar `:172-183`; availability `:8, 423`.
  - Demo: typed input `VoiceDemo.tsx:494-575`; the result card `:672-679`; "no date" `:22`.
  - Privacy: `:21, 29, 55, 75, 82, 126, 128, 155` (es/ca §9 at `:149`). Delete page: RevenueCat at `en.ts:375`, `es.ts:369`, `ca.ts:370`.
- **The app's words** (EN / ES / CA):
  - Continue with Google / Continuar con Google / Continua amb Google;
  - free dictations / dictados gratis / dictats gratuïts;
  - TaskFlow Pro; Explore Pro / Ver Pro / Descobreix Pro;
  - New task / Nueva tarea / Tasca nova (the form);
  - Files / Archivos / Fitxers adjunts;
  - No date / Sin fecha / Sense data;
  - Phone calendars / Calendarios del teléfono / Calendaris del telèfon;
  - Task deleted / Tarea eliminada / Tasca suprimida.
  - Three first-run lines: `calendarTrySaying`, `calendarTryTyping` and `calendarTryForm`, by account state.
- **App facts the site depends on:**
  - typed sentences become tasks only with Pro (since 2026-10-18), and free accounts get the form;
  - RevenueCat is deleted with the account (d447c5c);
  - Pro has a safeguard of 50 AI requests a day;
  - a person without a name appears as the start of their email (`list_access.py:29-30`).
- **Techniques that worked:**
  - `AUDIT.md` §12 as the headings-only test, and §6 for small print;
  - `INDEX.md` says which demo states came from typed text;
  - `tests/*.spec.ts` assert copy, so a claim fix must update them;
  - compare `App/build` render dates with `public/images`;
  - grep the ARB files for every product word on the site.
- **Recurring problem:** each app change leaves a site claim behind: the login wall, D3, projects, the free tier, voice commands, the form for free accounts, RevenueCat. After any app change, check the FAQ and the legal pages first.
