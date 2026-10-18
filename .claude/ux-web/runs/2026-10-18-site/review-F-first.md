## UX web review — F: features, faithfulness, the funnel to download and Pro, pricing — 2026-10-18

**Verdict:** Ship after fixes — the home page still describes the September app: it promises use without an account, says nothing of the free plan or Pro, shows screens and a review step the app no longer has, and loops "Get TaskFlow" back to a demo. Every fix is copy, two screenshots or a subtraction.

**Walked:**
- *Wanting → getting, Newcomer, phone 390 × 664, EN, light and dark:* land → hero → ☰ → "Get TaskFlow" → closing card → "Find your flow" → back up 5 screens to the sample walkthrough. 4 steps, and none of them leads to getting the app. The honest "not yet" is a 10 px line under that button.
- *Wanting → getting, Comparer, desktop 1440 × 1000:* land → "Explore the app" (lands on the sample walkthrough, not the app) → scroll to the FAQ → open "Can I download TaskFlow yet?" → open "Will TaskFlow be free?" → closing card. 6 steps; no free plan or Pro anywhere.
- *Invitee, phone, ES/CA:* the invitation email (`Backend/core/invitation_email.py:18, 32, 50, 68`) says «La app llegará pronto a Google Play. Mientras tanto, puedes ver lo que hace en taskflow.garbar.tech» → English home page → nothing about projects or sharing until a closed FAQ on screen 10 calls them "lists" and says sharing is "still being tested". Dead end.
- *Site → the app's first run (continuity):* the app opens on Sign in ("Note down what you need to do, and TaskFlow puts it on your calendar.", `App/artifacts/auth/login-light.png`), then the calendar with one «Add a task» button and "Try it: tap Add a task and say “Tomorrow, call the dentist and buy bread.”" (`App/lib/l10n/app_en.arb:312`). The site says no account is needed, shows "New task" plus a separate mic, and never uses that example.
- *Free and Pro against the app,* and the *claims inventory* for the whole site: home (EN only), privacy, terms, legal notice and delete-account in EN, ES and CA, the 404, metadata and the link preview.
- Renders: all 113 PNGs are newer than the code they show (renders 19:24 on 2026-10-18; newest site code 2026-10-16). `public/images/*.png` are dated 2026-09-21. App renders compared: `App/build/calendar-es-1.3x-*.png`, `review-batch-light.png`, `review-direct-light.png`, `capture-listening-es-2x.png`, `new-task-form*.png`, `project-people-filter-es.png`, `task-created-by-es.png` (all 2026-10-18) and `App/artifacts/auth/login-light.png`.

**Numbers:**
- **Claims:** 67 checked → 6 false, 12 outdated, 7 incomplete after an app change, 5 true but named differently from the app, 2 misleading labels, 35 true. After the fixes below: 0 false or outdated.
- **FAQ:** 6 of 7 answers say something false or outdated about today's app. Only "Can I use it offline?" is right, and it calls projects "lists".
- **Screenshots:** 0 of the 4 shown match today's app. 2 of the 6 files are never used (`calendar-*.png`).
- **"You can't download it yet":** first said outside a closed FAQ on phone screen 12 of 12 (11 scrolls), in 10 px text (`src/styles/global.css:1403, 2303`); on desktop, screen 6 (5 scrolls). After WEB-102: ☰ → 1 tap → the card's first line.
- **Home page mentions:** free plan 0, Pro 0, "10 dictations" 0, several tasks in one dictation 0 (one hint in the live demo's intro), reminders 1 ("Small reminders", hero), projects 0 ("list" ×3 in one closed answer), "Android" 2 (the 10 px closing line and a closed FAQ answer, plus alt text).

**Attention** (predicted from the renders with GUIDELINES.md §21 step 4, not measured; only what bears on this area):
- `home.en.desktop.light.fold.png` (dark is the same layout): 1. the H1 "Make room for a clearer day." (largest text, upper left); 2. the phone screenshot on the right (the largest informative image), with the floating "JUST SAY THE WORD" card; 3. the filled "See it in action" button (left, y ≈ 594). Competing: the filled "Explore the app" in the header (right third, discounted), two floating cards and the vertical caption. None of the first three says it's an Android app, that it isn't on Google Play yet, or that there's a free plan. The only proof that it's a phone app is the screenshot, and it shows the old app.
- `home.en.mobile.light.fold.png` (dark the same): 1. the H1 (y ≈ 150–255, top half); 2. "See it in action" (y ≈ 366–415, middle band), competing with the paragraph above it; 3. the top of the phone screenshot and the "JUST SAY THE WORD" card, in the bottom third (y > 443, about 14% of gaze). "Android" first appears on screen 12.

### Findings (most severe first)

**WEB-101 · Severity 4 · The site says TaskFlow works without an account**
- Where: `src/app/page.tsx:19-20` (FAQ "Do I need an account?"), `:12` (last sentence of "How does voice-to-task work?"), `:257-258` ("Sign in to upload files…"), `:276-277` ("Sign in to back them up when you're connected."). Home, EN, both viewports, both themes. Renders: `home.en.mobile.light.full.png` screens 4–5 (cards), screen 10 (FAQ, closed).
- The moment: the wary Newcomer reads "You can create tasks… without an account" and thinks "Good, they won't take my email." In the app, the first screen is Sign in: "They lied to me."
- What happens: the FAQ promises tasks and "a limited daily voice allowance without an account", and "a larger AI allowance" for signing in. Two feature cards say "Sign in to…", as if signing in were optional. Since 2026-10-09 the app opens nothing before sign-in (`App/docs/IMPLEMENTATION_STATUS.md`, authentication checkpoint; owner decision `.claude/ux-review/DECISIONS.md:73-76`, "The login stays a hard wall"). Every account without Pro gets 10 dictations a month, not a daily allowance (`DECISIONS.md:78`; `Backend/config/settings.py:144`). Password sign-ups confirm a 6-digit code (`Backend/docs/EMAIL_VERIFICATION.md:3`).
- Why it fails: FN-1 (UCPD art. 6; Play Deceptive), TR-2 (disclose up front what the visitor must give), FN-3 (the app's first screen is Sign in), and the persona's wariness about giving data away (GUIDELINES "The bar").
- Fix:
  1. FAQ answer, `page.tsx:20`, keeping the question.
     - EN: "Yes. You sign in once: with Google in one tap, or with your email and a 6-digit code we send you to confirm it. Your tasks are kept in your account, so you don't lose them if you change phones."
     - ES («¿Necesito una cuenta?»): «Sí. Inicias sesión una vez: con Google, en un toque, o con tu correo y un código de 6 cifras que te enviamos para confirmarlo. Tus tareas se guardan en tu cuenta, así no las pierdes si cambias de móvil.»
     - CA («Necessito un compte?»): «Sí. Inicies la sessió una vegada: amb Google, en un toc, o amb el teu correu i un codi de 6 xifres que t’enviem per confirmar-lo. Les tasques es desen al teu compte, així no les perds si canvies de mòbil.»
  2. Delete "A limited voice trial is available without an account." (`page.tsx:12`; WEB-105 rewrites the rest of that answer).
  3. "The little details matter" body, `page.tsx:255-260`:
     - EN: "Add notes, a checklist or files to any task. Files are backed up to your account, up to 6 MB each."
     - ES: «Añade notas, una lista de pasos o archivos a cualquier tarea. Los archivos se guardan en tu cuenta, hasta 6 MB cada uno.»
     - CA: «Afegeix notes, una llista de passos o fitxers a qualsevol tasca. Els fitxers es desen al teu compte, fins a 6 MB cadascun.»
  4. Offline card body, `page.tsx:275-278`:
     - EN: "Your tasks are saved on your phone, so you can check and add them without internet. They're saved to your account when you're back online."
     - ES: «Tus tareas se guardan en el móvil, así puedes consultarlas y añadirlas sin internet. Se guardan en tu cuenta cuando vuelves a tener conexión.»
     - CA: «Les tasques es desen al mòbil, així pots consultar-les i afegir-ne sense internet. Es desen al teu compte quan tornes a tenir connexió.»
- Verify:
  - `page.tsx` contains none of "without an account", "Sign in to", "allowance" or "MiB".
  - Walkthrough: the FAQ answer describes the first app screen (`App/artifacts/auth/login-light.png`).
- Evidence: verified in code (site and app docs) and in the app's login render.

**WEB-102 · Severity 3 · "Get TaskFlow" loops back; "not yet" hides at the bottom**
- Where:
  - `src/components/Header.tsx:62-64`: "Get TaskFlow", in the mobile menu only. The desktop nav (`:7-12`) has nothing like it.
  - `src/app/page.tsx:414-425`: the closing card. "Find your flow" (`:419-421`) links to `#demo`. The only status line (`:422-425`) is 10 px.
  - `page.tsx:7-8`: the FAQ "Can I download TaskFlow yet?".
  - Renders: `home.en.mobile.light.full.png` screen 12; `home.en.desktop.light.full.png` screen 6.
- The moment: "I want this. Where do I get it?" The visitor taps "Get TaskFlow", sees a big green card and a lime button, taps it and is thrown back up to the sample walkthrough. "Is this a real app? Can I even get it?"
- What happens:
  - No step on the page leads to getting the app, because the app isn't on Google Play yet (`.claude/ux-web/DECISIONS.md:14`). That's fine, but the page never says so where people decide.
  - The FAQ answer hints at other platforms ("Android as the first testing platform") and sends people to "the real app screens", which are a month out of date (WEB-103).
  - Invitees arrive here from the invitation email looking for how to get the app, and find the same loop.
- Why it fails: CT-4 (the destination keeps the label's promise), AP-5 (before launch, say it in plain text), AP-7 ("for Android" near the action), AT-6 (how to get it within two phone screens), CT-2 (the last screenful's call to action must be real), RD-5 (small print ≥ 12 px).
- Fix:
  1. Closing card body (`page.tsx:414-418`), at body size:
     - EN: "TaskFlow is an app for Android phones, coming soon to Google Play."
     - ES: «TaskFlow es una app para móviles Android y llegará pronto a Google Play.»
     - CA: «TaskFlow és una app per a mòbils Android i arribarà aviat a Google Play.»
  2. Replace "Find your flow" (`#demo`) with one real thing to do now, linking to `#voice`: EN "Try the live demo" (the same label as `src/components/VoiceDemo.tsx:391`), ES «Prueba la demo en vivo», CA «Prova la demo en viu».
  3. Remove the 10 px line (`page.tsx:422-425`); WEB-104 puts the terms line in its place.
  4. Mobile menu item (`Header.tsx:62-64`): EN "How to get TaskFlow", ES «Cómo conseguir TaskFlow», CA «Com aconseguir TaskFlow». It still points to `#get-taskflow`.
  5. FAQ answer, `page.tsx:8`:
     - EN: "Not yet. TaskFlow is an app for Android phones, coming soon to Google Play. Until then, try the live demo on this page: say a few things and see the tasks TaskFlow makes."
     - ES: «Todavía no. TaskFlow es una app para móviles Android y llegará pronto a Google Play. Mientras tanto, prueba la demo en vivo de esta página: di varias cosas y mira las tareas que crea TaskFlow.»
     - CA: «Encara no. TaskFlow és una app per a mòbils Android i arribarà aviat a Google Play. Mentrestant, prova la demo en viu d’aquesta pàgina: digues diverses coses i mira les tasques que crea TaskFlow.»
  - A way to be told when it's out is the owner's decision (Questions, Q1).
- Verify:
  - At 390 × 664: ☰ → "How to get TaskFlow". The card's first text line names Android and Google Play, at ≥ 16 px. Its button scrolls to `#voice`.
  - `page.tsx` has no "Find your flow".
  - No label on the site promises a download.
- Evidence: verified in code and in the current renders.

**WEB-103 · Severity 3 · App screenshots show a TaskFlow that no longer exists**
- Where:
  - `public/images/agenda-{light,dark}.png`: the hero, `page.tsx:110` through `src/components/Phone.tsx:22-39`.
  - `public/images/tasks-{light,dark}.png`: `page.tsx:327`.
  - Unused: `public/images/calendar-{light,dark}.png`.
  - Alt text: `Phone.tsx:2-8`.
  - All the files are dated 2026-09-21. Renders: `home.en.*.fold.png` and screen 9 of `home.en.mobile.light.full.png`.
- The moment: the Newcomer installs later and looks for the "New task" button and the mic beside it from the site. They aren't there: "Is this the same app?" The owner's father couldn't find how to create a task; the site teaches him the wrong button.
- What happens:
  - The screenshots show "New task" with a separate mic button, a moon in the header, three tabs (Calendar, Tasks, Settings), and "Your calendar" with "A LITTLE FOCUS. A LITTLE FLOW." and "Month view".
  - Today's app has one button, «Add a task», with a mic (`App/lib/widgets/task_actions.dart:89-102`), four tabs (Calendario, Tareas, Notas, Ajustes), the theme in Settings › Appearance (D5), and a week strip with "Week ▾" (`App/build/calendar-es-1.3x-light.png`).
  - The tasks screen now has a "No date" chip (`App/lib/screens/home_screen.dart:493-503`).
- Why it fails: HE-5 (a real, current screen), FN-3 (what the site shows first, the app shows first), AP-12 (real in-app screens), TR-3 (outdated screenshots are trust bugs), EY-3.
- Fix:
  1. Replace `agenda-{light,dark}.png` with current Calendar renders in English, light and dark, showing a dictated task with its day and time and the «Add a task» button. The app's preview test only writes Spanish at 1.3× text with English task titles (`App/test/calendar_feedback_test.dart:1096-1130`), so the main session must run an English, 1.0× variant. Its renders are 780 × 1688, so update the `width`/`height` in `Phone.tsx:25-26` and `:34-35` to match.
  2. Delete `tasks-*` together with its section (WEB-112), and the unused `calendar-*`.
  3. New alt text (`Phone.tsx:3-4`):
     - EN: "TaskFlow on an Android phone: this week, today's tasks with their times, and the Add a task button."
     - ES: «TaskFlow en un móvil Android: esta semana, las tareas de hoy con su hora y el botón Añadir tarea.»
     - CA: «TaskFlow en un mòbil Android: aquesta setmana, les tasques d’avui amb la seva hora i el botó Afegeix una tasca.»
  4. If WEB-112 is refused, replace `tasks-*` with the current Tasks screen too.
- Verify:
  - The hero render shows the same button label and icon, the same four tabs and no moon as the app's latest calendar render.
  - The image dates are later than the app's last calendar change.
- Evidence: seen in current renders (site and app) and verified in code.

**WEB-104 · Severity 3 · Free plan and Pro missing; pricing answer outdated**
- Where: `page.tsx:31-32` (FAQ "Will TaskFlow be free?"), and the whole home page (0 mentions). Closing card `page.tsx:422-425`.
- The moment: the Comparer wants to know "What's free? What does Pro cost?" and reads "no paid plans". Later the app shows "Free dictations: 7 of 10 left this month" and "Explore Pro": "They hid that."
- What happens: the answer only says launch pricing isn't announced and there are no plans "on this website". The app on dev has:
  - **Free:** 10 dictations a month, the form to add tasks by hand with no limit, and 100 MB of files (`DECISIONS.md:5-25, 77-99`; `App/docs/REVENUECAT_SETUP.md:3`; `app_en.arb:1891-1983, 1999`).
  - **TaskFlow Pro:** a monthly subscription (`app_en.arb:1688-1689`) for unlimited dictation and file space.
  - Pro's price isn't set: US$9.99 is a Test Store price (`REVENUECAT_SETUP.md:24, 38`).
- Why it fails: PR-2 (what Free includes, wherever Free or Pro is mentioned), PR-3 (qualify "free"), CT-10 (the terms where people decide), FN-6, TR-2, FQ-2 (the free limit readable without opening anything), AT-6.
- Fix:
  1. FAQ, `page.tsx:31-32`:
     - EN question "Is TaskFlow free?" Answer: "Yes. Without Pro, you get 10 dictations a month (one dictation can hold several tasks), and you can always add tasks by hand, with no limit. TaskFlow Pro, a monthly subscription, gives you unlimited dictation and file space; without it, files have 100 MB in total. Pro's price isn't set yet."
     - ES: «¿TaskFlow es gratis?» — «Sí. Sin Pro tienes 10 dictados al mes (en un dictado caben varias tareas) y siempre puedes añadir tareas a mano, sin límite. TaskFlow Pro, una suscripción mensual, te da dictado y espacio para archivos ilimitados; sin Pro, los archivos tienen 100 MB en total. El precio de Pro aún no está decidido.»
     - CA: «TaskFlow és gratuït?» — «Sí. Sense Pro tens 10 dictats al mes (en un dictat hi caben diverses tasques) i sempre pots afegir tasques a mà, sense límit. TaskFlow Pro, una subscripció mensual, et dona dictat i espai per a fitxers il·limitats; sense Pro, els fitxers tenen 100 MB en total. El preu de Pro encara no està decidit.»
  2. In place of the 10 px line (`page.tsx:422-425`), at ≥ 12 px:
     - EN: "Free: 10 dictations a month, and tasks by hand with no limit. TaskFlow Pro: unlimited dictation."
     - ES: «Gratis: 10 dictados al mes y tareas a mano sin límite. TaskFlow Pro: dictado ilimitado.»
     - CA: «Gratuït: 10 dictats al mes i tasques a mà sense límit. TaskFlow Pro: dictat il·limitat.»
  - Never show a price. Leave out "100 MB" if the owner says it may still change (Q2).
- Verify:
  - With every FAQ item closed, "10 dictations a month" is on the page.
  - The numbers equal `Backend/config/settings.py:106, 144` and `app_en.arb:1891-1971`.
  - The site has no price.
- Evidence: verified in code and decisions.

**WEB-105 · Severity 3 · The selling point, several tasks in one dictation, is never told**
- Where: `page.tsx:230-234` (the voice card: "Turn a passing thought into a task"); `page.tsx:11-12` (FAQ: "suggest tasks…"). The sample walkthrough's examples are one task each (`src/components/TaskDemo.tsx:5-36`). Render `home.en.mobile.light.full.png` screen 4.
- The moment: "So I say one thing and get one task? My notebook does that." The visitor never learns that one sentence can fill the whole day.
- What happens:
  - The owner called several tasks per dictation "absolutely a must" (`DECISIONS.md:46-51`), and speed is the selling point (`:67-72`).
  - The app's first-run line teaches it: "Tomorrow, call the dentist and buy bread." (`app_en.arb:312`), and the result says "2 things to add" / "Add 2 tasks" (`:1558, :1568`).
  - Voice commands (move, change, delete or find a task, with before/after and Undo) are also untold (`Backend/docs/VOICE_COMMANDS.md:1-10`).
- Why it fails: HE-4 (one concrete example: what you said and the dated tasks it became), B lens (the benefit that creates desire), FN-3 (use the app's own first example), SC-1 (headings and first words carry the story).
- Fix:
  1. Voice card body, `page.tsx:231-234`. The example is the app's own, so visitors meet it again in the app.
     - EN: "Say a few things at once: “Tomorrow, call the dentist and buy bread.” TaskFlow makes one task for each, on its day. Check them, then add them all with one tap."
     - ES: «Di varias cosas a la vez: «Mañana, llamar al dentista y comprar pan». TaskFlow crea una tarea para cada una, en su día. Revísalas y añádelas todas con un toque.»
     - CA: «Digues diverses coses alhora: «Demà, trucar al dentista i comprar pa». TaskFlow crea una tasca per a cadascuna, al seu dia. Revisa-les i afegeix-les totes amb un toc.»
  2. FAQ, `page.tsx:11-12`. The question uses the app's words, not "voice-to-task".
     - EN: "How do I add tasks by voice?" — "Tap Add a task and say what you need to do, in your own words. Several things at once is fine. Tap Done: TaskFlow shows one task for each thing, with its day and time. Check them and add them with one tap. You can also move, change or delete a task by voice; TaskFlow shows the change first, and you can undo it. Understanding your words needs an internet connection."
     - ES: «¿Cómo añado tareas hablando?» — «Toca Añadir tarea y di lo que tienes que hacer, con tus palabras. Puedes decir varias cosas a la vez. Toca Listo: TaskFlow te muestra una tarea por cada cosa, con su día y su hora. Revísalas y añádelas con un toque. También puedes mover, cambiar o borrar una tarea hablando; TaskFlow te enseña el cambio antes y puedes deshacerlo. Para entender tus palabras necesita conexión a internet.»
     - CA: «Com afegeixo tasques parlant?» — «Toca Afegeix una tasca i digues el que has de fer, amb les teves paraules. Pots dir diverses coses alhora. Toca Fet: TaskFlow et mostra una tasca per cada cosa, amb el seu dia i la seva hora. Revisa-les i afegeix-les amb un toc. També pots moure, canviar o esborrar una tasca parlant; TaskFlow t’ensenya el canvi abans i el pots desfer. Per entendre les teves paraules necessita connexió a internet.»
  - The button names match `app_en.arb:204` (Add a task) and `:842` (Done), and `app_es.arb:142, 493` and `app_ca.arb:121` (Afegeix una tasca), plus "Fet".
- Verify:
  - The quoted example equals `calendarTrySaying` in each ARB file.
  - Headings and first sentences mention several things at once.
  - Walkthrough: a reader of the card can predict the app's "2 things to add" sheet (`App/build/review-batch-light.png`).
- Evidence: verified in code and decisions.

**WEB-106 · Severity 2 · Reminders, the third step of the core loop, are never told**
- Where: `page.tsx:172-176` (calendar card). The only mention is "Small reminders" (`page.tsx:63`).
- The moment: "If I put it in, will it remind me? I forget things." There's no answer on the page.
- What happens: TaskFlow puts tasks on the calendar and reminds people about them (CLAUDE.md). The app asks once, at the first dated task, "Want a reminder before it?" and then reminds them (D2, `DECISIONS.md:110-116`; `app_en.arb:1029-1034`). The site never says it.
- Why it fails: HE-11 (the core loop first: say it, see it on your calendar, get reminded), B lens (for older people, being reminded is a key benefit), FN-3 (prepare people for the app's one question).
- Fix: calendar card body, `page.tsx:173-176`.
  - EN: "See your tasks by day, week or month. TaskFlow can remind you of each task: it asks once, the first time you add one with a date."
  - ES: «Mira tus tareas por día, semana o mes. TaskFlow puede recordarte cada tarea: te lo pregunta una vez, la primera vez que añades una con fecha.»
  - CA: «Mira les tasques per dia, setmana o mes. TaskFlow et pot recordar cada tasca: t’ho pregunta una vegada, la primera vegada que n’afegeixes una amb data.»
- Verify: the card states reminders, and the wording matches D2 (one question, at the first dated task).
- Evidence: verified in code and decisions.

**WEB-107 · Severity 2 · Sharing FAQ says "lists", describes the old invite flow and misses family use**
- Where: `page.tsx:23-24` (FAQ "Can I share a list?"). Render: `home.en.mobile.light.full.png` screen 10.
- The moment: an invitee arrives from the email «…te invita a unirte al proyecto «Casa»» and looks for "proyecto". The site says "list", "shares a code separately" and "still being tested".
- What happens:
  - The app calls them projects: Projects, Shared projects (`app_en.arb:211, 1756`; standing decision `DECISIONS.md:172-173`).
  - The invitation email now carries the code (`Backend/core/invitation_email.py:28-29`; `app_en.arb:1873`).
  - Everyone joins as an editor (D15b).
  - Tasks show «Created by» (`app_en.arb:1953`), and shared projects can be filtered by person (`App/build/project-people-filter-es.png`).
- Why it fails: FN-2 (the app's names), FN-1 (outdated flow), B lens (sharing chores with family is the use that creates desire), SC-4 (the question's first words).
- Fix: `page.tsx:23-24`.
  - EN: "Can I share tasks with my family?" — "Yes. Share a project, such as Home or Shopping: tap Share and invite someone by email. Once they accept, you both see all its tasks; each task shows who created it, and you can see just one person's tasks."
  - ES: «¿Puedo compartir tareas con mi familia?» — «Sí. Comparte un proyecto, como Casa o Compras: toca Compartir e invita a alguien por correo. Cuando acepte, los dos veréis todas sus tareas; cada tarea muestra quién la creó y puedes ver solo las de una persona.»
  - CA: «Puc compartir tasques amb la meva família?» — «Sí. Comparteix un projecte, com Casa o Compres: toca Comparteix i convida algú per correu. Quan accepti, tots dos en veureu totes les tasques; cada tasca mostra qui l’ha creada i pots veure només les d’una persona.»
  - The project names come from `app_*.arb` `listsEmptyHelp`; the button names from `shareProject`.
- Verify:
  - No visitor-facing "list" means a project.
  - Names match `app_*.arb` (`lists`, `shareProject`, `createdBy`).
- Evidence: verified in code.

**WEB-108 · Severity 2 · Both demos show a review step the app doesn't have**
- Where:
  - `src/components/TaskDemo.tsx:212-283`: step 2 is a 5-field form, with Priority as its own field (`:248-260`) and "· High priority" in the saved line (`:326`).
  - `page.tsx:312-314`: the noscript text promises "a title, schedule, priority, and notes".
  - `src/components/VoiceDemo.tsx:672-679`: every result card opens with "Task 1 · High priority".
  - Render: `home.en.mobile.light.full.png` screens 8–9.
- The moment: "So I fill in a form?" That contradicts the section's own "No field-by-field thinking" (`page.tsx:305`). Later the app shows something else.
- What happens: the app's result shows the title, the date as its main line, the notes and «More options», then «Add to calendar». A batch shows compact cards with title and date, then «Add 2 tasks» (`App/build/review-direct-light.png`, `review-batch-light.png`; D3, `DECISIONS.md:117-123`). Priority is folded away.
- Why it fails: FN-3, FN-4 (the demo sets honest expectations), AP-13 (it teaches one thing: say it, see the dated tasks), HE-11.
- Fix (subtract):
  1. In TaskDemo, remove the Priority field (`TaskDemo.tsx:248-260`), the `priority` values in the examples, and "· {priority} priority" (`:326`). Keep the title, then date and time on one line, then the note.
  2. In VoiceDemo, remove the priority pill from the card top line (`VoiceDemo.tsx:675-678`). It can stay inside "Edit task".
  3. Noscript, `page.tsx:312-314`:
     - EN: "Turn on JavaScript to try the demo. In the app, what you say becomes tasks with their day and time; you check them, then add them with one tap."
     - ES: «Activa JavaScript para probar la demo. En la app, lo que dices se convierte en tareas con su día y su hora; las revisas y las añades con un toque.»
     - CA: «Activa JavaScript per provar la demo. A l’app, el que dius es converteix en tasques amb el seu dia i la seva hora; les revises i les afegeixes amb un toc.»
  - H owns the demos' interaction: merge with any H finding on them.
- Verify: each demo's result shows the title and then the date line, with no priority shown first, like the app's review renders.
- Evidence: verified in code; seen in the current site and app renders.

**WEB-109 · Severity 2 · The site names features differently from the app**
- Where: listed below; home, EN; also the metadata.
- The moment: after installing, the visitor looks for "voice-to-task", "drafts" or "lists" and finds «Add a task», "dictations", "things to add" and "Projects". Nothing they learned carries over.
- What happens: the site uses words the app never shows the user. A search of `app_en.arb` finds no visible "draft", "voice-to-task" or "allowance".

  | The site says | Where | The app says (EN / ES / CA) | Fixed by |
  |---|---|---|---|
  | "voice-to-task" | `page.tsx:11`, `VoiceDemo.tsx:373`, `src/app/layout.tsx:131` | dictation / dictado / dictat (`app_*.arb` `freeVoice*`) | WEB-105 for `page.tsx:11`; the rest here |
  | "drafts", "Create drafts", "{n} drafts, ready for you" | `page.tsx:12`, `VoiceDemo.tsx:388, 395, 594, 621`, `TaskDemo.tsx:167, 209` | "{n} things to add", "Add {n} tasks" / «cosas para añadir», «Añadir {n} tareas» / «coses per afegir», «Afegeix {n} tasques» (`captureThingsToAdd`, `captureAddTasks`) | here |
  | "voice trial", "daily voice allowance", "AI allowance", "tries", "Your allowance returns" | `page.tsx:12, 20`, `VoiceDemo.tsx:377, 406, 820` | "free dictations" for the app; for the website demo, say "demo tries" so the two never mix | WEB-101 for `page.tsx`; here for VoiceDemo |
  | "list", "shared list" | `page.tsx:16, 23-24` | project, shared project / proyecto / projecte (`lists`, `projectsShared`) | WEB-107; `:16` here |
  | "attachments", "6 MiB" | `page.tsx:256, 259` | Files, "6 MB" / Archivos / Fitxers (`attachments`, `requestError` fileLimit) | WEB-101 |
  | "Choose Task or Note when capturing" | `page.tsx:28` | Add a note / Añadir nota / Afegeix una nota (`addNote`) | WEB-110 |
  | "Account sync" | `page.tsx:16` | not an app term; say "saving to your account" | here |

- Why it fails: FN-2 (the app's names, in each language), G lens (one concept, one name), HE-10 (no "AI", "sync" or "allowance" on the main path).
- Fix, for the rows marked "here":
  - `VoiceDemo.tsx:373`:
    - EN: "Try a dictation right here: one thing or several."
    - ES: «Prueba a dictar aquí mismo: una cosa o varias.»
    - CA: «Prova de dictar aquí mateix: una cosa o diverses.»
  - Button `:594`: EN "Make tasks", ES «Crear tareas», CA «Crea les tasques». The privacy page quotes this label (`src/content/legal/{en,es,ca}.ts:139`), so change it there too.
  - Heading `:621`: EN "{n} things to add", ES «{n} cosas para añadir», CA «{n} coses per afegir».
  - Badges `:377, :406`:
    - EN: "3 free demo tries · no account" and "{n} of 3 demo tries left".
    - ES: «3 pruebas gratis de la demo · sin cuenta» and «Te quedan {n} de 3 pruebas de la demo».
    - CA: «3 proves gratuïtes de la demo · sense compte» and «Et queden {n} de 3 proves de la demo».
  - Allowance line `:820`: EN "Your demo tries return…", ES «Tus pruebas de la demo vuelven…», CA «Les proves de la demo tornen…».
  - Offline answer `page.tsx:16`: EN "Yes. Your tasks are saved on your phone, so you can check, add and complete them without internet. Saving to your account, understanding what you say, and uploading files need a connection." ES «Sí. Tus tareas se guardan en el móvil: puedes consultarlas, añadirlas y completarlas sin internet. Guardar en tu cuenta, entender lo que dices y subir archivos necesitan conexión.» CA «Sí. Les tasques es desen al mòbil: pots consultar-les, afegir-ne i completar-les sense internet. Desar al compte, entendre el que dius i pujar fitxers necessiten connexió.»
  - Metadata `layout.tsx:131` (G): use the app's own pitch, "Note down what you need to do, and TaskFlow puts it on your calendar." (`app_en.arb:674`).
- Verify:
  - The site's visible text contains none of "voice-to-task", "draft", "allowance" or "shared list".
  - Each feature name appears in `app_*.arb` for its language.
- Evidence: verified in code (site and ARB files).

**WEB-110 · Severity 2 · Notes FAQ describes a Task/Note choice the app removed**
- Where: `page.tsx:27-28`.
- The moment: in the app, the visitor looks for the "Task or Note" choice when adding something and can't find it.
- What happens: D3 removed the Task/Note choice from capture (`DECISIONS.md:123`). Notes are added from the Notes tab with «Add a note», written or dictated (`app_en.arb:73, 77`). "Typed notes work locally; recorded notes need online transcription" is jargon.
- Why it fails: FN-1, FN-2, HE-10.
- Fix: the answer at `page.tsx:28`.
  - EN: "Yes. The Notes tab keeps what you want to remember that isn't a task, like a Wi-Fi password. Tap Add a note, then write or dictate it; add links or a checklist if you like."
  - ES: «Sí. La pestaña Notas guarda lo que quieres recordar y no es una tarea, como la clave del wifi. Toca Añadir nota y escríbela o díctala; si quieres, añade enlaces o una lista de pasos.»
  - CA: «Sí. La pestanya Notes desa el que vols recordar i no és una tasca, com la contrasenya del wifi. Toca Afegeix una nota i escriu-la o dicta-la; si vols, afegeix-hi enllaços o una llista de passos.»
  - The example comes from `noteTitleHint`, and the steps from `notesEmptyHelp`.
- Verify: the answer has no "Choose Task or Note", and its names match `app_*.arb` (`notes`, `addNote`).
- Evidence: verified in code and decisions.

**WEB-111 · Severity 2 · Feature headings are mood lines; a scanner learns nothing**
- Where: the section H2 (`page.tsx:154-158`) and its intro (`:160-164`); card headings at `:172, :230, :254, :274`. Render: `home.en.desktop.light.full.png` screen 2.
- The moment: a skimming Comparer reads "A place for everything. / See the shape of your day. / Say it. Get on with it. / The little details matter. / Life doesn't always have Wi-Fi." and asks "But what does it do?"
- What happens: the headings-only test fails. No heading names a feature in its first two words. The facts sit in grey body text.
- Why it fails: SC-1, SC-4 (front-load the meaning), HE-3 (clear beats clever; it also translates badly), HE-11.
- Fix:
  - Section H2: EN "Say it. See it on your calendar. Get reminded." ES «Dilo. Míralo en tu calendario. Recibe un aviso.» CA «Digues-ho. Mira-ho al calendari. Rep un avís.»
  - Remove the intro paragraph (`:160-164`).
  - Card headings:
    - `:172` EN "Your day on one calendar" / ES «Tu día en un calendario» / CA «El teu dia en un calendari»;
    - `:230` EN "Say several things at once" / ES «Di varias cosas a la vez» / CA «Digues diverses coses alhora»;
    - `:254` EN "Notes, checklists and files" / ES «Notas, listas de pasos y archivos» / CA «Notes, llistes de passos i fitxers»;
    - `:274` EN "Your tasks, even offline" / ES «Tus tareas, también sin conexión» / CA «Les tasques, també sense connexió».
  - The card bodies are in WEB-101, WEB-105 and WEB-106.
- Verify: reading only the H1, the H2s and the H3s still tells what TaskFlow does: calendar, several tasks by voice, reminders, details, offline.
- Evidence: verified in code; seen in the current render.

**WEB-112 · Severity 2 · A whole section sells the theme switch**
- Where: `page.tsx:320-358` (`#appearance`, "03 / Made to feel like you"), with the outdated `tasks-*.png`. Phone renders: screens 9–10, about 2 screens.
- The moment: "Light mode, dark mode… does it remind me of things?" The scroll shows nothing new about the product.
- What happens:
  - One of only four content sections goes to light and dark mode, the app's least important feature (D5: a switch in Settings › Appearance), while several tasks at once, reminders and sharing go untold.
  - Its button only re-themes the website, and the header already has that switch (`Header.tsx:47`).
  - Its headline, "A softer start. A quieter finish.", says nothing.
- Why it fails: AT-4 (earn every scroll), HE-11, SC-1. Subtract first.
- Fix: remove the section (`page.tsx:320-358`), its `ThemeToggle variant="mood"` use and its `.appearance-*` styles, and delete `public/images/tasks-{light,dark}.png`. Using the freed space for sharing with family is a new section: Q4.
- Verify:
  - The home page has one theme control, in the header.
  - The phone render is about 2 screens shorter.
  - No outdated tasks screenshot is left.
- Evidence: verified in code; seen in the current render.

**WEB-113 · Severity 2 · Privacy page misses three app changes**
- Where:
  - `src/content/legal/en.ts:29`, `es.ts:29`, `ca.ts:29` (what Google sends).
  - `:21` in all three (automatic emails).
  - `:75` in all three (sharing).
  - `:82` in all three (Resend).
  - `:126` in all three (code expiry).
  - Renders: `privacy.{en,es,ca}.*.full.png`.
- The moment: the Leaver or the Comparer checks what TaskFlow keeps from Google, or why they got a code by email, and doesn't find it.
- What happens:
  - Google sign-in now keeps the Google first name as the account's name when it has none. The family name and photo aren't stored (commit 41c00f3, `Backend/core/google_auth.py`).
  - Password sign-ups get a 6-digit code by email from the no-reply address, valid 30 minutes (`Backend/docs/EMAIL_VERIFICATION.md:3`).
  - Members of a shared project see who created each task, «Created by» (`Backend/docs/VOICE_COMMANDS.md:321-332`; `app_en.arb:1953`).
  - The privacy text lists none of these.
- Why it fails: FN-1 (what the site says about data matches the app), PV-1, TR-2.
- Fix:
  1. `:29`:
     - EN: "…such as your Google account identifier, email, verification status and first name; if your account has no name, we use that first name. We don't keep your family name or photo."
     - ES: «…como su identificador, correo, verificación y nombre de pila; si tu cuenta no tiene nombre, usamos ese nombre. No guardamos tus apellidos ni tu foto.»
     - CA: «…com l’identificador, correu, verificació i nom de pila; si el compte no té nom, fem servir aquest nom. No desem els cognoms ni la foto.»
  2. `:21`: EN "Automated invitations, email-confirmation codes and recovery messages come from…"; ES «Las invitaciones, los códigos para confirmar el correo y los mensajes de recuperación automáticos se envían desde…»; CA «Les invitacions, els codis per confirmar el correu i els missatges de recuperació automàtics s’envien des de…».
  3. `:82`: EN "Resend: invitation, email-confirmation and recovery emails…"; ES «Resend: correo de invitaciones, confirmación de correo y recuperación…»; CA «Resend: correus d’invitació, confirmació de correu i recuperació…».
  4. `:126`: EN "invitation codes expire after seven days, and email-confirmation and recovery codes after 30 minutes"; ES «los códigos de invitación caducan a los siete días, y los de confirmación de correo y de recuperación, a los 30 minutos»; CA «els codis d’invitació caduquen als set dies, i els de confirmació de correu i de recuperació, als 30 minuts».
  5. Add to `:75`: EN "Members also see your name on the tasks you create (“Created by”)." ES «Los miembros también ven tu nombre en las tareas que creas («Creada por»).» CA «Els membres també veuen el teu nom a les tasques que crees («Creada per»).»
  - These files are the other session's untracked work, so the fixes stay uncommitted for the owner. L may report the same lines: merge.
- Verify: the privacy page names the Google first name, the email-confirmation code and «Created by» in all three languages.
- Evidence: verified in code (commit, docs and content files).

**WEB-114 · Severity 1 · Sample dates are a month old**
- Where:
  - `page.tsx:180-183`: the calendar illustration says "September 2026", with days 21–27.
  - `TaskDemo.tsx:11, 21, 31`: fixed 2026-09 dates.
  - `TaskDemo.tsx:167-168`: "a sample week in September 2026".
- The moment: it's 18 October, and the page plans a week in September: "Is anyone still working on this?"
- What happens: the samples date the page.
- Why it fails: TR-3 (keep content fresh).
- Fix:
  - Remove "September 2026" from the illustration (`page.tsx:181-183`).
  - Remove the sentence "This demo uses a sample week in September 2026." (`TaskDemo.tsx:167-168`).
  - Compute the walkthrough's dates relative to today, such as the next Friday. That part is H's.
- Verify: no month or year in sample content goes stale.
- Evidence: verified in code.

### Claims checked
Status: **true**; **false**; **outdated**; **incomplete** (true, but it misses an app change); **name** (true, in words the app doesn't use); **label** (a misleading control label); **unverifiable**.

| Claim (page, `path:line`) | Source of truth (`path:line`) | Status |
|---|---|---|
| Home: "in development, with Android as the first testing platform… public download coming later" `src/app/page.tsx:8` | `.claude/ux-web/DECISIONS.md:14`; `App/docs/REVENUECAT_SETUP.md:40` (com.example.agenda) | true; "first testing platform" unverifiable (no platform decision) |
| Home: "explore the real app screens" `page.tsx:8` | `public/images/*` (2026-09-21) vs `App/build/calendar-es-1.3x-light.png` | outdated |
| Home FAQ: AI suggests tasks with titles, dates, times, priorities, notes; check before saving `page.tsx:12` | `.claude/ux-review/DECISIONS.md:117-123`; `Backend/docs/VOICE_COMMANDS.md:40-42` | incomplete (several tasks; commands) |
| Home FAQ: "AI processing needs an internet connection" `page.tsx:12` | `App/build/capture-listening-es-2x.png` («Tus palabras van por internet») | true |
| Home FAQ: "A limited voice trial is available without an account" `page.tsx:12` | `.claude/ux-review/DECISIONS.md:73-76`; `App/docs/IMPLEMENTATION_STATUS.md` (auth checkpoint) | false |
| Home FAQ: create/edit/complete tasks offline `page.tsx:16` | `IMPLEMENTATION_STATUS.md` ("Cached account tasks remain usable offline"); `App/lib/l10n/app_en.arb:176` | true |
| Home FAQ: sync, AI, file transfers need a connection `page.tsx:16` | same | true |
| Home FAQ: downloaded files offline; "shared-list content is removed…" `page.tsx:16` | `app_en.arb:915, 211` | name ("list") |
| Home FAQ: tasks and a daily voice allowance without an account `page.tsx:20` | `DECISIONS.md:73-78`; `Backend/config/settings.py:144` | false |
| Home FAQ: "Sign in to… get a larger AI allowance" `page.tsx:20` | same | false |
| Home FAQ: account recovery `page.tsx:20` | `App/artifacts/auth/login-light.png` ("Forgot password?") | true |
| Home FAQ: "Older device-only files need an explicit upload" `page.tsx:20` | `app_en.arb:562` (pre-login-wall guests only) | outdated |
| Home FAQ: "supports shared lists" `page.tsx:24` | `app_en.arb:211` (Projects); `DECISIONS.md:172-173` | outdated (name) |
| Home FAQ: owner "shares a code separately" `page.tsx:24` | `Backend/core/invitation_email.py:28-29`; `app_en.arb:1873` | outdated |
| Home FAQ: recipients choose to accept `page.tsx:24` | `app_en.arb:1875, 1888` | true |
| Home FAQ: editors change, viewers read `page.tsx:24` | `app_en.arb:914` | true |
| Home FAQ: "still being tested before public release" `page.tsx:24` | `.claude/ux-web/DECISIONS.md:14` | true |
| Home FAQ: separate Notes view with checklists and links `page.tsx:28` | `app_en.arb:71-73, 95`; Notas tab in `App/build/calendar-es-1.3x-light.png` | true |
| Home FAQ: "Choose Task or Note when capturing" `page.tsx:28` | `DECISIONS.md:123`; `app_en.arb:77` | false (removed) |
| Home FAQ: typed notes local; recorded notes transcribed `page.tsx:28` | `app_en.arb:73`; `IMPLEMENTATION_STATUS.md` B23 | true (jargon) |
| Home FAQ: "Launch pricing has not been announced" `page.tsx:32` | `REVENUECAT_SETUP.md:24, 38` | true |
| Home FAQ: "no paid plans or subscriptions to sign up for on this website" `page.tsx:32` | `DECISIONS.md:5-25, 77-99`; `app_en.arb:1688-1689, 1891-1983` | outdated (omits Free and Pro) |
| Home hero: "Small reminders" `page.tsx:63` | `DECISIONS.md:110-116`; `IMPLEMENTATION_STATUS.md` B02–B03 | true (vague) |
| Home hero card: "JUST SAY THE WORD — ‘A walk at six.’" `page.tsx:101-102` | `DECISIONS.md:89-91` | true |
| Home hero screenshot and alt text `page.tsx:110`, `src/components/Phone.tsx:3-4` | `App/lib/widgets/task_actions.dart:89-102`; `App/build/calendar-es-1.3x-light.png` | outdated |
| Home: calendar first, month and week `page.tsx:174-175` | `App/docs/DESIGN.md`; `DECISIONS.md:170`; `app_en.arb:297-299` | true |
| Home illustration: "September 2026" `page.tsx:182` | today, 2026-10-18 | outdated (stale sample) |
| Home: "Turn a passing thought into a task… review before you save" `page.tsx:232-233` | `DECISIONS.md:117-123, 46-51` | incomplete (several tasks) |
| Home: "Notes, priorities, and attachments" `page.tsx:256` | `app_en.arb:214, 229, 231` (Files) | name |
| Home: "Sign in to upload files and download them on another device" `page.tsx:257-258` | `DECISIONS.md:73-76` | false (sign-in isn't optional) |
| Home: "task details show which files are backed up" `page.tsx:258` | `app_en.arb:622` ("Backed up to your account") | true |
| Home: "Up to 6 MiB per file" `page.tsx:259` | `Backend/config/settings.py:103`; `app_en.arb:43` ("6 MB") | name |
| Home: "Keep planning with tasks on your phone" `page.tsx:276` | `app_en.arb:176` | true |
| Home: "Sign in to back them up when you're connected" `page.tsx:276-277` | `DECISIONS.md:73-76` | false (sign-in isn't optional) |
| Home: "No perfect wording. No field-by-field thinking." `page.tsx:305` | `DECISIONS.md:117-123` | true (contradicted by `TaskDemo.tsx:212-272`) |
| Home noscript: an editable draft with title, schedule, priority, notes `page.tsx:312-314` | `App/build/review-direct-light.png` | outdated (priority folded; "draft") |
| Home: tasks screenshot `page.tsx:327` | `App/lib/screens/home_screen.dart:493-503`; 4 tabs | outdated |
| Home: light or dark mode `page.tsx:340-342` | `DECISIONS.md:131` (D5) | true |
| Home: "Android app in development · Public download coming soon" `page.tsx:423-424` | `.claude/ux-web/DECISIONS.md:14` | true (10 px) |
| Sample walkthrough: review step with Priority and "Add to my preview" `src/components/TaskDemo.tsx:212-283` | `App/build/review-direct-light.png`, `review-batch-light.png`; `app_en.arb:6, 1568` | outdated |
| Sample walkthrough: "a sample week in September 2026" `TaskDemo.tsx:167-168` | today | outdated (stale sample) |
| Live demo: preview tasks don't sync to the app `src/components/VoiceDemo.tsx:601-602, 813-814` | site code | true |
| Live demo: each result card opens with "{priority} priority" `VoiceDemo.tsx:675-678` | `App/build/review-batch-light.png` | outdated (the app leads with the date) |
| Live demo: "3 free tries · no account" `VoiceDemo.tsx:377` | `src/lib/voice/policy.ts:4`; app free plan `settings.py:144` | true of the demo; can be read as the app's terms (Q3) |
| Header (mobile menu): "Get TaskFlow" `src/components/Header.tsx:62-64` | `.claude/ux-web/DECISIONS.md:14` | label (nothing to get) |
| Header: "Explore the app" → `/#demo` `Header.tsx:48-50` | site code (sample walkthrough) | label (not the app) |
| Metadata: "calendar, priorities, and voice-to-task capture" `src/app/layout.tsx:131` | `app_en.arb:674` (the app's pitch) | name |
| Privacy summary: voice is optional and uses Google AI `src/content/legal/en.ts:10` | `.claude/ux-review/DECISIONS.md:197` | true |
| Privacy: automatic invitations and recovery from no-reply `en.ts:21` (es/ca `:21`) | `Backend/docs/EMAIL_VERIFICATION.md:3` | incomplete (confirmation codes) |
| Privacy: from Google, identifier, email, verification status `en.ts:29` (es/ca `:29`) | commit 41c00f3, `Backend/core/google_auth.py` | incomplete (first name) |
| Privacy: usage counts to apply allowances `en.ts:33` | `.claude/ux-review/free-tier-plan.md` §2.1 | true |
| Privacy: the AI suggests titles, dates, priorities `en.ts:48` | `VOICE_COMMANDS.md:40-42` | true |
| Privacy: shared content available to members by role `en.ts:75` (es/ca `:75`) | `VOICE_COMMANDS.md:321-332`; `app_en.arb:1953` | incomplete («Created by») |
| Privacy: Resend, invitation and recovery emails `en.ts:82` (es/ca `:82`) | `EMAIL_VERIFICATION.md:3` | incomplete |
| Privacy: completed tasks not erased after 30 or 90 days `en.ts:122` | `.claude/ux-review/DECISIONS.md:182` (open) | true today; open decision (Q6) |
| Privacy: invitation codes 7 days, recovery codes 30 minutes `en.ts:126` (es/ca `:126`) | `EMAIL_VERIFICATION.md:3` | incomplete |
| Privacy: microphone, notifications, files, camera, calendar permissions `en.ts:155` | `app_en.arb:145-146`; `IMPLEMENTATION_STATUS.md` B20 | true |
| Privacy: AI Studio route with a Vertex fallback; the demo uses Vertex `en.ts:56` | `.claude/ux-review/DECISIONS.md:197` | true |
| Privacy: staging uses no-charge test purchases `en.ts:84` | `REVENUECAT_SETUP.md:24` | true |
| Terms: private staging test; no public checkout or download `en.ts:205` | `.claude/ux-web/DECISIONS.md:14` | true |
| Terms: tasks/notes, calendars, reminders, "voice-to-task drafts", sync, "projects/lists" `en.ts:221` | `app_en.arb` | name |
| Terms and delete-account: Settings → Account → Delete account (ES Ajustes → Cuenta → Eliminar cuenta; CA Configuració → Compte → Suprimeix el compte) `en.ts:269, 355`; `src/content/legal/index.ts:48, 91, 134` | `App/lib/screens/settings_screen.dart:110`, `account_screen.dart:316`; `app_{en,es,ca}.arb` (`settings`, `account`, `deleteAccount`) | true |
| Delete-account: counts, handovers, save a copy without files, password or Google, needs internet, re-check if the plan changes `en.ts:355-356` | `app_en.arb:2034-2223` | true |
| Delete-account: what's deleted (incl. usage records) and what stays without your name `en.ts:373-374` | `Backend/docs/ACCOUNT_DELETION.md:20-31`; `app_en.arb:2095-2104` | true |
| Delete-account and privacy: the RevenueCat record isn't deleted automatically `en.ts:128, 375` | `ACCOUNT_DELETION.md:32, 63` | true today; open item (Q6) |
| Delete-account: no automatic confirmation email `en.ts:382` | `ACCOUNT_DELETION.md:12, 62`; CLAUDE.md (Email) | true today; one is planned next |
| Delete-account: deleting doesn't cancel a Google Play subscription `en.ts:397` | `app_en.arb:2132` | true |

Totals: 67 claims (6 false, 12 outdated, 7 incomplete, 5 name, 2 label, 35 true); the "es/ca" rows were read in all three files. The brief said the delete-account page "still says the test version has no in-app option". That's out of date: the working tree (version 2026-10-16) already describes in-app deletion correctly in all three languages (`delete-account.es.mobile.light.fold.png`).

### Missing from the site (app features worth telling)
In order of desire, the first four first; the rest briefly or later (HE-11):
1. **Several tasks in one dictation,** with one date covering the whole list and one tap to add them all. Source: `DECISIONS.md:46-51`; `app_en.arb:1558, 1568`. Where: the voice card and the FAQ (WEB-105).
2. **Reminders, asked for once.** Source: D2, `DECISIONS.md:110-116`; `app_en.arb:1029-1034`. Where: the calendar card (WEB-106).
3. **The free plan and TaskFlow Pro.** Source: `DECISIONS.md:5-25, 77-99`. Where: the FAQ and the closing card (WEB-104).
4. **Sharing a project with family:** invite by email, «Created by», a filter by person. Source: `.claude/ux-review/voice-commands-plan.md` items 5 and 8; `app_en.arb:1953`. Where: the FAQ (WEB-107). A section with a real screenshot is Q4.
5. **Moving, changing, deleting and finding by voice,** with the before and after, a tap, and «Undo». Source: `Backend/docs/VOICE_COMMANDS.md`. Where: one sentence in the FAQ (WEB-105).
6. **Undo after every change** (for example "Task completed · Undo"). Source: D11, D12; `App/build/calendar-feedback-light.png`. Where: one clause in the voice card or the FAQ. It reassures wary people.
7. **Google sign-in in one tap.** Source: `App/artifacts/auth/login-light.png`. Where: the account FAQ (WEB-101).
8. **The app in Spanish, Catalan and English.** Source: `App/lib/l10n/app_*.arb`. Where: the closing card or the FAQ. The home page itself being English-only is G's and H's.
9. **The phone's calendar events beside your tasks** (read-only, they stay on the phone). Source: `app_en.arb:145-146`; `App/lib/screens/other_settings_screen.dart:60`. Where: one clause in the calendar card, for the Comparer.
10. **A home-screen widget ("Tap to say a task."), launcher shortcuts, and sharing text into TaskFlow.** Source: `App/android/app/src/main/AndroidManifest.xml:46-61`. Where: one clause in the voice card, later.
11. **Bringing tasks over from Todoist** (CSV import). Source: `App/lib/screens/data_transfer_screen.dart:12, 180`. Where: a FAQ item for people switching. That's a new item, so it's the owner's call.
12. **Repeat, checklists and deadlines.** Source: `app_en.arb:111, 221, 232`. Where: the "Notes, checklists and files" card (WEB-111).

### Keep
- No store badge, no download button and no price anywhere on the site, as AP-5 and PR-6 ask. Only the place and size of the availability line are wrong.
- The delete-account page matches today's app in all three languages: the path names match `app_*.arb`, and its lists of what's deleted and what stays match the app's preview strings and `Backend/docs/ACCOUNT_DELETION.md`.
- The offline answer, the 6 MB file limit and the "Backed up to your account" claim are true. Only their wording needs fixing.
- No testimonials, ratings, user counts or superlatives (TR-4, TR-5).
- Before the microphone, the live demo states the 60 s limit and that audio goes to Google only on a tap, with a link to the privacy section (PV-3).

### Questions for the owner (product decisions only)
1. **A next step for people who want TaskFlow before launch** (AP-6). Options:
   - Play pre-registration. It needs the final package ID (`com.example.agenda` can't stay, `App/docs/REVENUECAT_SETUP.md:40`), and each country gets a 90-day window.
   - An open or closed test. New personal developer accounts need 12 testers for 14 days.
   - An email list. It needs consent and a privacy update.
   - Until one is chosen, the site says "coming soon to Google Play" and offers the live demo (WEB-102).
2. **How much of the free plan to publish now.**
   - 10 dictations a month is decided.
   - 100 MB of files is a reversible default (`DECISIONS.md:80-84`).
   - Pro's price isn't set (US$9.99 is a Test Store price).
   - Recommendation: publish "10 dictations a month" and "TaskFlow Pro: unlimited dictation and file space"; add "100 MB" only if it's final (WEB-104).
3. **The live demo is more generous than the free app.** The demo gives 3 AI tries a day per browser with no account, up to about 90 a month (`src/lib/voice/policy.ts:4-5`). The app gives 10 dictations a month with an account (`Backend/config/settings.py:144`).
   - FN-4 says a demo is never more forgiving than the app; the owner's goal is "teach, don't replicate".
   - Keep it, or cap the demo below the app, for example 3 tries in total per browser?
4. **A section on sharing with family,** in the space WEB-112 frees, with a real screenshot of a shared project (`App/build/project-people-filter-es.png`, `task-created-by-es.png`)? It's a new section.
5. **Platforms.** The FAQ's "first testing platform", the legal pages' Apple subscription links (`src/content/legal/en.ts:248, 402-408`) and the app's own "available in the Android and iOS app" (`app_en.arb:1695`) all suggest an iPhone version. Say "for Android phones" and nothing more, until an iPhone version is decided?
6. **Open app decisions that bind the legal pages** (no change until decided):
   - the clean-up of completed tasks (privacy `en.ts:122` says there's none);
   - deleting the RevenueCat customer (`en.ts:128, 375`);
   - stopping free dictations being reused after deleting and re-creating an account (that needs a hashed email, which the privacy page would then have to disclose);
   - the deletion confirmation email (delete-account `en.ts:382` says none is sent; `ACCOUNT_DELETION.md:62` plans one).

### Cross-slice notes
- **H:** the header button "Explore the app" (`Header.tsx:48-50`) lands on the sample walkthrough, not the app (CT-4). Consider pointing it at `#get-taskflow` with WEB-102's label.
- **H:** the hero (`page.tsx:42-84`) never says "app", "Android" or what TaskFlow does. The app's own pitch, "Note down what you need to do, and TaskFlow puts it on your calendar." (`app_en.arb:674`; ES and CA in `authPitch`), is a ready, faithful subheadline.
- **H:** the "3 free tries · no account" badge (`VoiceDemo.tsx:377`) sits among claims about the app and reads as the app's terms; WEB-109 labels it as the demo's.
- **G:** the home page and the 404 are English only, while the Newcomer and the invitation emails (`Backend/core/invitation_email.py:50, 68`) are Spanish or Catalan. Every rewrite above includes ES and CA.
- **G:** the link preview (`src/app/opengraph-image.tsx`) and the metadata (`layout.tsx:129-131`) don't say what TaskFlow is. WEB-109 suggests the app's own pitch.
- **G:** the only availability line is 10 px (`global.css:1403, 2303`); WEB-102 removes it.
- **L:** WEB-113 touches the privacy content. The privacy text quotes the demo button "Create drafts" (`en.ts:139`, `es.ts:139`, `ca.ts:139`), so it must follow WEB-109.
- **L:** the delete-account page will need the confirmation email once it ships (`ACCOUNT_DELETION.md:62`).
- **Organizer:** `src/content/legal/*` is untracked work from the other session, so WEB-113's lines stay uncommitted. `layout.tsx`, `Footer.tsx` and `VoiceDemo.tsx` carry the other session's uncommitted changes (`VoiceDemo.tsx:396`, the CSS import in `layout.tsx`). `page.tsx`, `Header.tsx`, `Phone.tsx`, `TaskDemo.tsx` and `public/images/` are clean.
- **Main session:** WEB-103 needs new English app renders, which only the main session can make (Flutter, in the app repo).

### Memory notes
- **Site map (2026-10-18):**
  - Home anchors, in order: `#features`, `#voice` (VoiceDemo, rendered before `#demo`), `#demo` (TaskDemo), `#appearance`, `#questions` (7 FAQ items in `page.tsx:5-34`), `#get-taskflow` (closing card).
  - Header nav: Features, How it works, Try voice, Questions. Its button "Explore the app" goes to `/#demo`. Only the mobile menu has "Get TaskFlow".
  - `Phone.tsx` uses `public/images/{agenda,tasks}-{light,dark}.png`; `calendar-*` is unused. All are from 2026-09-21, 1080 × 2400.
  - Legal pages: `/privacy`, `/terms`, `/legal`, `/delete-account`, plus `/es/…` and `/ca/…`, with content in `src/content/legal/{en,es,ca}.ts`. Line numbers match across the three files.
- **Claims map:**
  - account: `page.tsx:12, 20, 257, 276`
  - free and Pro: `page.tsx:32` (none elsewhere)
  - sharing: `page.tsx:24`
  - notes: `page.tsx:28`
  - offline: `page.tsx:16, 274-278`
  - voice: `page.tsx:11-12, 230-234`
  - calendar: `page.tsx:172-176`
  - theme: `page.tsx:340-342`
  - availability: `page.tsx:8, 423`
  - demo review steps: `TaskDemo.tsx:212-283`, `VoiceDemo.tsx:672-690`
  - privacy data: `en.ts:21, 29, 33, 75, 82, 122, 126`
  - deletion: `en.ts:342-424`, `index.ts:46-48`
- **The app's words to enforce** (EN / ES / CA):
  - Add a task / Añadir tarea / Afegeix una tasca
  - New task / Nueva tarea / Tasca nova (the form)
  - Done / Listo / Fet
  - Add to calendar / Añadir al calendario / Afegeix al calendari
  - Add {n} tasks / Añadir {n} tareas / Afegeix {n} tasques
  - {n} things to add / cosas para añadir / coses per afegir
  - Undo / Deshacer / Desfés
  - free dictations / dictados gratis / dictats gratuïts
  - Projects / Proyectos / Projectes
  - Notes / Notas / Notes, and Add a note / Añadir nota / Afegeix una nota
  - Settings / Ajustes / Configuració
  - Created by / Creada por / Creada per
  - "Want a reminder before it?" / «¿Quieres un recordatorio antes?» / «Vols un recordatori abans?»
  - Pitch: `authPitch`. First example: `calendarTrySaying`.
- **Recurring problem:** the home copy was written for the September guest-mode app. The login wall (2026-10-09), the capture redesign (D3), "lists" becoming projects, the free tier and voice commands all left claims behind. After any app change, check the FAQ first.
- **Techniques that worked:**
  - grep the ARB files for the site's terms;
  - compare the dates of `public/images` with `App/build` renders;
  - `App/build` previews are Spanish at 1.3× with English sample titles;
  - follow the invitation email's link to the website as a way in.
- **Delegation notes can be stale:** the delete-account page had already been updated in the working tree, on 2026-10-16.
