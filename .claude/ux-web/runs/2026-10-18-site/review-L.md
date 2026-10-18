## UX web review — L: legal, privacy, terms, delete-account and trust — recheck with renders and measurements (run 2026-10-18-site) — 2026-10-19

**Verdict:** Ship after fixes. Deletion still takes one step from every legal page, and the delete page meets Google Play's web-deletion rules in all three languages, with no axe violations, no contrast failures and visible focus on every stop. But the delete page and the privacy policy now say the opposite of what the server does with RevenueCat, the policy is behind the app on six more points, and the legal text is 14 px grey type that doesn't grow when a reader asks the browser for bigger text.

**Walked** (Leaver, Comparer, assistive-technology user, Newcomer; ES, CA, EN; light and dark):
- **Leaver from Google Play.** WD13 gives Play `/delete-account/`, the English page.
  - English: 0 steps.
  - Spanish or Catalan: 1 tap on «Español» or «Català», which sit in the upper half of the first phone screen (y≈155–203 of 664), named in their own language.
  - Then the email button (y≈569–623) or the in-app steps.
- **Leaver from privacy, terms or the legal notice:** «Eliminar cuenta» / «Eliminar compte» / "Delete account" is in the first screen. 1 step, every language.
- **Leaver from the home footer or the 404:** scroll to the end, tap "Delete account" (it opens the English page), then the language. 2 taps.
- **Leaver from inside the app:** Ajustes → Cuenta → Eliminar cuenta, then the password or Google. 3 taps plus the confirmation. The app still links to none of the site's pages (WD11 isn't built yet).
- **Leaver by email:** 1 tap, type the account's email, Send. It works without JavaScript (`tests/legal.spec.ts:81-144`).
- **Comparer:** footer → Privacy → summary → "We do not sell personal data" in §3, on phone screen ≈6 (ES).
- **Trust:** footer → Legal Notice → the company card, on screen 2.
- **Demo visitor:** "How we use your data" → `/privacy/#voice`, which is about the app.
- **Assistive technology:** landmarks and names (AUDIT §9, `aria/`), the tab order (§10, §14: 30–53 stops, focus visible on all), heading outlines (§12).
- **Viewports and states:** desktop 1440 × 1000, phone 390 × 664, 320 × 568, desktop at 200% zoom (720 × 500 CSS px), the browser's default text size doubled, WebKit (iPhone 13 and desktop), the phone menu open on `/es/privacy/`.

**Evidence:**
- **Renders:** the 96 Chromium legal renders, 96 text200, zoom200 and w320 variants, and 48 WebKit legal renders, made 23:52–00:19 on 18–19 Oct. The legal sources last changed on 15–16 Oct, so every render is current.
- **Measurements:** `AUDIT.md` §2–§14, the `aria/` snapshots and the `focus/` screenshots. Performance there is lab data, not field data (PF-2). A clean automated row isn't a pass for a person (AX-11).
- **Code:** both repos, including the app's ARB files, `Backend/docs/ACCOUNT_DELETION.md` and the deletion and billing code.
- **Still device checks:** Android Chrome's own text-size setting, TalkBack, and Safari on a real iPhone.

**Numbers:**
- **Delete page, first phone screen (ES):**
  - ≈60 words and 1 filled button, the email request (y≈569–623).
  - Scrolls to it: 0 at 390 × 664; 1 at 320 × 568 (`delete-account.ca.mobile-w320.light.fold.png`).
  - The in-app route is 14 px grey text (AUDIT §6).
- **Privacy page, first phone screen (ES):** ≈44 words and 0 privacy facts. The first summary card starts at y≈622 of 664.

  | Page | Phone screens at 390 px (EN / ES / CA) | At 320 px (ES) | Words (EN / ES / CA) |
  |---|---|---|---|
  | Privacy | 21.7 / 21.5 / 20.4 | 29.3 | 2,396 / 2,367 / 2,207 |
  | Terms | 15.0 / 14.2 / 13.1 | 18.9 | 1,551 / 1,335 / 1,151 |
  | Delete account | 9.3 / 9.6 / 9.4 | 12.7 | 756 / 812 / 795 |
  | Legal notice | 5.6 / 5.5 / 5.3 | 7.0 | 269 / 250 / 231 |

- **Type (AUDIT §6):**
  - 91–92% of the privacy page's characters are 14 px, and 3% are 16 px or more.
  - Labels are 11 px. The eyebrow is 10 px on desktop and 8 px on phones.
- **Text size (AUDIT §3):** with the browser's default text size doubled, 0 of 140 elements on the privacy page grow. The text200 renders are byte-identical to the 100% renders on all 12 legal pages.
- **Line length:** ≈135–140 characters on desktop (`privacy.es.desktop.light.full.png`, screen 2).
- **Targets under 44 px on legal pages (AUDIT §5):**
  - contents rows: 33.2 px on desktop, 39.2 px on phones, 0 px apart;
  - related documents: 36 / 38 px;
  - link lists: 35.3 px;
  - the company's email links: 19 px.
- **Focus rings cut by the desktop sidebar (AUDIT §10):** 15 on privacy, 14 on terms, 10 on the delete page, 7 on the legal notice.
- **Steps to account deletion:**
  - from any legal page: 1;
  - from Play: 0, plus 1 language tap;
  - from the home page or the 404: 2 taps, after scrolling to the end;
  - from the app: 3 taps plus the confirmation.
- **Claims checked:** 38 (first review: 35).

  | Status | Now | First review |
  |---|---|---|
  | False | 1 | 0 |
  | Outdated, incomplete or missing | 8 | 7 |
  | Misleading | 1 | 1 |
  | True today, made false by this run's own plan | 3 | — |
  | Unverifiable | 3 | 3 |

**Attention.** Predicted from the renders with GUIDELINES §21 step 4. This isn't measured (EY-7); 5–6 sessions with older, non-technical people would confirm it (FN-7).

| Render | 1st fixation | 2nd | 3rd | What competes or gets missed |
|---|---|---|---|---|
| `delete-account.es.mobile.light.fold.png` | H1 «Elimina tu cuenta de TaskFlow.» (y≈250–317, upper half) | The filled «Escribir solicitud de eliminación» (y≈569–623): bottom third, but isolated and filled | Box heading «Desde la app o por correo» (24 px bold, y≈465) | The language pill competes in the upper half. The in-app route is 14 px grey at y≈505–545, outside the first three (WEB-204). |
| `delete-account.en.mobile.light.fold.png` (Play's landing, WD13) | H1 | "Write a deletion request" | The pill «English · Español · Català» (y≈155–203) | Good for the Spanish Leaver: «Español» is in the upper half, in Spanish. |
| `delete-account.es.desktop.light.fold.png` | H1 (top left) | The header's English "Explore the app" (top right, filled) | The request button (centre right, y≈575–628) | Two filled buttons compete. The in-app line is 14 px grey at y≈633. |
| `delete-account.ca.mobile.dark.fold.png` | H1 «Elimina el teu compte de TaskFlow.» | «Escriure sol·licitud d'eliminació» | Box heading | One screen says «Eliminar compte», «Elimina», «Suprimeix el compte» and «eliminació» (WEB-206). |
| `privacy.es.mobile.light.fold.png` | Slogan H1 «Tu privacidad, con claridad.» (y≈282–355) | The grey 3-line description (y≈385–460) | The underlined «Eliminar cuenta ↗ · Soporte y privacidad ↗» (y≈535–557) | No privacy fact among the first three. The summary starts at y≈622 (WEB-203). |
| `privacy.es.desktop.light.fold.png` | H1 | The header's "Explore the app" | The three summary cards (y≈582–685) | The cards are generic: «Usamos tu contenido para prestarte TaskFlow». |
| `terms.es.mobile.light.fold.png` | Slogan H1 «Condiciones claras, desde el principio.» | Description | Links | Same template. The summary starts at y≈622. |
| `legal.es.mobile.light.fold.png` | H1 «La empresa detrás de TaskFlow.» | The description, which names GARBAR, IN-TEC, S.L. | Links | Fine for its job. The company card is on screen 2. |
| `webkit/*.fold.png` | Same order | | | Every weight renders thin, so the H1 and the buttons lose salience (see Cross-slice notes). |

**Re-judged (first review → now):**

| ID | Was | Now | What the new evidence changed |
|---|---|---|---|
| WEB-113 (my WEB-201, merged) | S2 | S2, confirmed and wider | WD3 decided it. It adds the completed-task sentence (decided "none") and the names people see in shared projects (D8). Speech on the phone is the default (`App/lib/providers/regional_provider.dart:20`). |
| WEB-202 | S2 | S2, confirmed; copy corrected | My §3 copy said RevenueCat isn't deleted, and now it is (WEB-601). The app's test-purchase line changed (`app_en.arb:1692`). PV-7 is cited as the guide now words it. |
| WEB-203 | S2 | S2, confirmed; two facts corrected | The description does name the document, and the eyebrow is 8 px on phones, not 10 (AUDIT §6). The `<title>` already meets Play's labelling rule. |
| WEB-204 | S2 | S2, confirmed | Measured: 14 px grey (AUDIT §6). At 320 × 568 the email button falls below the first screen. |
| WEB-205 | S2 | S2, confirmed and wider | Measured: no legal text grows with the browser's text size (AUDIT §3). The ring clipping was inferred and is now measured (AUDIT §10). Targets are measured (AUDIT §5). |
| WEB-206 | S2 | S2, confirmed and wider | Also the §3 and contents heading, og:title, and eight more «elimin…» lines. |
| WEB-207 | S2 | S2, confirmed | §8's new first sentence no longer waits: WD3 decided it. |
| WEB-208 | S2 | S1, half withdrawn | **Withdrawn:** the overflow. Nothing scrolls sideways at 320 px, at 200% zoom or with doubled text (AUDIT §3), because the text doesn't grow; WEB-205 carries that now. **Confirmed:** the current language is shown by colour only (AUDIT §8: 1.12:1 light, 1.43:1 dark). |
| WEB-209 | S2 | S2, confirmed and wider | More terms: Cloud Run, SDK and hashes in §2 and §9, "project/list". |
| WEB-210 | S1 | S1, confirmed | WD7 decided it. |
| WEB-211 | S1 | S1, confirmed | Seen in `legal.en.mobile.light.full.png`. |
| WEB-212 | S1 | S1, confirmed | Seen in the renders. |
| WEB-213 | S1 | S1, confirmed | WD3 also moves the date. |

New: WEB-601 (S2) and WEB-602 (S2).

### Findings (most severe first)

**WEB-601 · Severity 2 · The site says RevenueCat keeps your record; the server deletes it**
- **Where:**
  - Delete page §3, third bullet: `src/content/legal/en.ts:375`, `es.ts:369`, `ca.ts:370`. All viewports and themes; render `delete-account.es.mobile.light.full.png`, screen 7.
  - Privacy §7, "Legal and billing records": `en.ts:128`, `es.ts:128`, `ca.ts:128`.
  - The test that pins the old sentence: `tests/legal.spec.ts:133-135`.
- **The moment:** "Dice que la app no borra mi registro en RevenueCat y que escriba a soporte… otro correo, y a esperar un mes."
- **What happens:**
  - The site says deleting the account "does not automatically delete the RevenueCat customer record", and sends people to support for it.
  - Since 18 Oct the server deletes the RevenueCat customer as soon as the account deletion commits:
    - `Backend/docs/ACCOUNT_DELETION.md:32`;
    - `Backend/core/account_deletion.py:216-219` and `:300-305`;
    - `Backend/core/billing.py:47-66`.

    It was decided in `.claude/ux-review/DECISIONS.md` (2026-10-18, night).
  - Only Google Play's own purchase records stay (`ACCOUNT_DELETION.md:33`).
  - The deletion is best effort. It needs the RevenueCat key on the server (`Backend/config/settings.py:151`), and a failure is logged without the ID. The copy below says "we ask", which stays true either way.
- **Why it fails:**
  - FN-1: every claim true today (UCPD art. 6; Play Metadata).
  - PV-1: accurate information (GDPR arts. 12–13).
  - PV-7: the deletion page must match the app and the privacy policy.
- **Fix:**
  - **Delete §3:** WEB-202's rewrite carries this. Bullet 1 gains the RevenueCat sentence; bullet 3 keeps only Google Play.
  - **Privacy §7 (`:128`):** its last sentence becomes:
    - EN: "When you delete your account, we also ask RevenueCat, the company that checks subscriptions for us, to delete its record of you. Google Play keeps its own record of your purchases. To include other data our providers hold in an erasure request, write to support."
    - ES: «Al eliminar tu cuenta, también pedimos a RevenueCat, la empresa que comprueba las suscripciones por nosotros, que borre su registro tuyo. Google Play conserva su propio registro de tus compras. Para incluir en una solicitud de supresión otros datos que guarden nuestros proveedores, escribe a soporte.»
    - CA: «En suprimir el compte, també demanem a RevenueCat, l'empresa que comprova les subscripcions per nosaltres, que esborri el registre que té de tu. Google Play conserva el seu propi registre de les teves compres. Per incloure en una sol·licitud de supressió altres dades que guardin els nostres proveïdors, escriu a suport.»
  - **The test:** `tests/legal.spec.ts:133-135` asserts the new sentence instead.
  - **Not visitor-facing, but must follow:** `docs/LEGAL_RELEASE.md:28` and `:36` in the website repo.
  - The page goes out with, or after, a backend that has the key (WD13).
- **Verify:** Playwright on `/delete-account/`, `/es/delete-account/` and `/ca/delete-account/`:
  - `#scope` names RevenueCat in the "deleted" bullet;
  - it no longer contains "does not automatically delete the RevenueCat", «no elimina automáticamente el cliente de RevenueCat» or «no elimina automàticament el client de RevenueCat»;
  - `#retention` on the three privacy pages has none of "does not automatically delete RevenueCat", «no borra automáticamente el registro independiente de cliente de RevenueCat» or «no esborra automàticament el registre independent de client de RevenueCat».
- **Evidence:** verified in code, in both repos; seen in the current render.

**WEB-113 (my WEB-201, merged) · Severity 2 · Privacy policy is behind the app on six points**
- **Where:** privacy, all three languages, desktop and phone, both themes; render `privacy.es.mobile.light.full.png`, screens 4–14. The ledger keeps WEB-113; review L writes the copy.

  | Point | Section | `en.ts` | `es.ts` | `ca.ts` |
  |---|---|---|---|---|
  | 1. Email confirmation codes | §1 sender, §5 Resend, §7 lifetimes | 21, 82, 126 | 21, 82, 126 | 21, 82, 126 |
  | 2. Google's first name | §2 | 29 | 29 | 29 |
  | 3. Speech recognised on the phone | §4 | 55 | 55 | 55 |
  | 4. Phone calendars | §9 | 155 | 149 | 149 |
  | 5. Your name in shared projects | §5 | 75 | 75 | 75 |
  | 6. Completed tasks | §7 | 122 | 122 | 122 |

- **The moment:**
  - "Me llegó un correo de noreply con un código de 6 cifras; la política no lo menciona."
  - "La política dice que mi voz va a la nube, pero la app dice «En el teléfono, mientras hablas»."
  - "¿Por qué sale mi nombre en las tareas del proyecto de mi hija, si la política no lo dice?"
  - "«No se borran a los 30 o 90 días»… ¿y a los 100?"
- **What happens:**
  1. **Email confirmation codes.** A password sign-up gets a 6-digit code from the noreply address, valid for 30 minutes (`Backend/docs/EMAIL_VERIFICATION.md:3, 58, 69`; `Backend/core/email_verification.py:20`). The policy doesn't list it:
     - not among the automatic emails (§1);
     - not in Resend's role (§5);
     - not among the code lifetimes (§7).
  2. **Google's first name.** An account with no name takes Google's given name, and members of shared projects see it («Creada por», chips, the person picker). The surname and photo aren't stored (`Backend/docs/GOOGLE_SIGN_IN.md:69`). §2 says only "identity information such as your Google account identifier, email and verification status".
  3. **Speech.** §4 says "Recordings are sent for cloud transcription when you submit a capture".
     - By default the app recognises speech on the phone whenever it can: `App/lib/providers/regional_provider.dart:20` (`speechOnline = false`), `App/lib/screens/voice_task_screen.dart:573`, and `NativeSpeechBridge.kt:71, 109, 203` (`createOnDeviceSpeechRecognizer`).
     - The app says so: "On this phone, as you speak", and "no audio is retained in that mode" (`App/lib/l10n/app_en.arb:397, 422`).
     - Only phones that can't do it send the recording ("Online, after you finish", `:398`; `:412`).
  4. **Phone calendars.** §9 says "Calendar entries you choose to turn into TaskFlow content may then be synchronised like other tasks".
     - `App/lib/` has no way to turn an event into a task: events are read-only (`models/device_calendar_event.dart`, `providers/device_calendar_provider.dart`).
     - The app promises they "stay on this device; they are not uploaded or sent to AI" (`app_en.arb:146`).
  5. **Your name in shared projects.** Tasks show «Creada por» (`app_en.arb:1957`; `.claude/ux-review/DECISIONS.md`, 2026-10-18 later, points 4 and 6), and names show on assigned tasks. Password accounts are asked for a first name when they first share a project or join one (DECISIONS, night, D8). §5 says only that content is "available to its authorised members".
  6. **Completed tasks.** §7 says they "are not automatically erased after 30 or 90 days". The numbers come from a plan the main session decided against ("none for now", so nothing is ever deleted on its own; DECISIONS, night). A visitor can't tell what 30 or 90 refers to.
- **Why it fails:**
  - FN-1: every claim true today.
  - PV-1: complete, plain information (GDPR arts. 12–13; WP260).
  - FN-2: the app's own words.
- **Fix:** WD3 allows it. These are the other session's untracked files, so the change stays uncommitted.

  **EN**
  - **§1 (`:21`):** "Automated invitations and recovery messages come from…" → "Automatic emails (invitations, email confirmation codes and password recovery) come from taskflow.noreply@garbar.tech…"
  - **§2 (`:29`):** replace "With Google sign-in, we receive identity information such as your Google account identifier, email and verification status." with "With Google sign-in, we receive your Google account identifier, your email, whether Google has verified it, and your first name, which becomes your TaskFlow name if you haven't given one. We don't keep your surname or photo. Password sign-ups confirm their email with a 6-digit code that expires after 30 minutes."
  - **§4 (`:55`):** replace "Recordings are sent for cloud transcription when you submit a capture; typed AI input is also sent when you request interpretation." with "When your phone can recognise speech by itself, your voice becomes text on the phone and no audio leaves it; only the words are sent to become tasks. Otherwise the recording is sent to be transcribed online when you finish. With Pro, words you type for the AI are sent the same way. The task form never sends anything to the AI."
  - **§5 (`:75`):** after the first sentence, add "Members of a shared project see your first name on the tasks you create there ("Created by") and on tasks assigned to you." In `:82`, "invitation and recovery emails" becomes "invitation, email-confirmation and recovery emails".
  - **§7:**
    - `:122`: "Completed tasks are not automatically erased after 30 or 90 days." → "We never delete your tasks on our own, done or not."
    - `:126`: "…invitation codes expire after seven days, and email-confirmation and recovery codes after 30 minutes."
  - **§9 (`:155`):** replace the calendar sentence with "Events from your phone's calendars are shown read-only and stay on the phone: they're never uploaded or sent to the AI."

  **ES**
  - **§1:** «Los correos automáticos (invitaciones, códigos para confirmar el correo y recuperación de la contraseña) se envían desde taskflow.noreply@garbar.tech…»
  - **§2:** «Si entras con Google, recibimos tu identificador de Google, tu correo, si Google lo ha verificado y tu nombre de pila, que pasa a ser tu nombre en TaskFlow si no has puesto otro. No guardamos tus apellidos ni tu foto. Si te registras con contraseña, confirmas tu correo con un código de 6 cifras que caduca a los 30 minutos.»
  - **§4:** replace «El audio se envía a transcripción en la nube al enviar la captura; el texto se envía cuando pides interpretarlo.» with «Si tu teléfono puede reconocer la voz por sí solo, tu voz se convierte en texto en el propio teléfono y el audio no sale de él; solo se envían las palabras para crear las tareas. Si no puede, la grabación se envía para transcribirla en línea al terminar. Con Pro, lo que escribes para la IA se envía igual. El formulario de tareas nunca envía nada a la IA.»
  - **§5:** add «Los miembros de un proyecto compartido ven tu nombre en las tareas que creas en él («Creada por») y en las que tienes asignadas.» Resend: «correos de invitación, de confirmación del correo y de recuperación».
  - **§7:** «Nunca borramos tus tareas por nuestra cuenta, estén hechas o no.» and «…los códigos de invitación caducan a los siete días, y los de confirmación del correo y de recuperación, a los 30 minutos.»
  - **§9:** «Los eventos de los calendarios del teléfono se muestran solo para consulta y se quedan en el teléfono: no se suben ni se envían a la IA.»

  **CA**
  - **§1:** «Els correus automàtics (invitacions, codis per confirmar el correu i recuperació de la contrasenya) s'envien des de taskflow.noreply@garbar.tech…»
  - **§2:** «Si entres amb Google, rebem l'identificador de Google, el correu, si Google l'ha verificat i el teu nom de pila, que passa a ser el teu nom a TaskFlow si no n'has posat cap. No desem els cognoms ni la foto. Si et registres amb contrasenya, confirmes el correu amb un codi de 6 xifres que caduca als 30 minuts.»
  - **§4:** replace «L'àudio s'envia a transcripció al núvol en enviar la captura, i el text quan en demanes la interpretació.» with «Si el telèfon pot reconèixer la veu tot sol, la veu es converteix en text al mateix telèfon i l'àudio no en surt; només s'envien les paraules per crear les tasques. Si no pot, la gravació s'envia per transcriure-la en línia en acabar. Amb Pro, el que escrius per a la IA s'envia igual. El formulari de tasques no envia mai res a la IA.»
  - **§5:** add «Els membres d'un projecte compartit veuen el teu nom a les tasques que hi crees («Creada per») i a les que tens assignades.» Resend: «correus d'invitació, de confirmació del correu i de recuperació».
  - **§7:** «No esborrem mai les teves tasques pel nostre compte, fetes o no.» and «…els codis d'invitació caduquen als set dies, i els de confirmació del correu i de recuperació, als 30 minuts.»
  - **§9:** «Els esdeveniments dels calendaris del telèfon es mostren només per consultar-los i es queden al telèfon: no es pugen ni s'envien a la IA.»
- **Verify:** Playwright text assertions on `/privacy/`, `/es/privacy/` and `/ca/privacy/`:
  - `#controller`, `#sharing` and `#retention` mention the confirmation codes;
  - `#data` mentions the first name;
  - `#voice` no longer has the cloud-transcription sentence quoted above, in any of the three languages;
  - `#sharing` mentions "Created by" / «Creada por» / «Creada per»;
  - `#permissions` says events stay on the phone;
  - `#retention` no longer contains "30 or 90" / «30 o 90».
- **Evidence:** verified in code, in both repos.

**WEB-202 · Severity 2 · The delete page explains what goes in database words, not the app's**
- **Where:** delete page, all three languages; render `delete-account.es.mobile.light.full.png`, screen 2 (summary) and screens 6–8 (§3–§5).

  | Part | `en.ts` | `es.ts` | `ca.ts` |
  |---|---|---|---|
  | Summary | 345–349 | 339–343 | 340–344 |
  | §3 | 373–375 | 367–369 | 368–370 |
  | §4, first paragraph | 382 | 376 | 377 |
  | §5, last sentence of the first paragraph | 397 | 391 | 392 |

- **The moment:** "¿Qué pasa con mis tareas? «registros de archivos personales en la nube… cambio en la base de datos… ventana móvil configurada del proveedor»… no entiendo nada."
- **What happens:**
  - The summary repeats the steps («Elimina desde los ajustes de tu cuenta» / «Revisa qué contenido compartido permanece» / «Las suscripciones de tienda se cancelan aparte») instead of saying what goes.
  - The three §3 bullets run 50–70 words each, in database and provider terms: «cambio en la base de datos», «atribución de actividad», «cliente de RevenueCat».
  - §4 says «durante la solicitud confirmada… transacción», and §5 «compras actuales de Test Store en staging».
  - The app says the same thing in two plain lines:
    - «Se eliminarán tu cuenta de TaskFlow y tus tareas, notas y archivos en todos tus dispositivos.» (`App/lib/l10n/app_es.arb:1208`)
    - «N tareas que añadiste a proyectos compartidos, sin tu nombre» (`:1215`)
  - Bullet 3 is also false about RevenueCat now (WEB-601).
- **Why it fails:**
  - PV-7: saying on the page what's deleted and what's kept is TaskFlow's bar (GDPR art. 13). Play itself asks only that retention be disclosed.
  - FN-2: the app's words.
  - HE-10, RD-3: plain words (NN/g Techy terms; Kane 2019; COGA).
  - OL-2: the Leaver may be upset; never imply fault.
- **Fix:** replace with plain words and keep the legal limits. `docs/LEGAL_RELEASE.md:28` rules out an "all erased instantly" promise, so "what you wrote inside doesn't change" stays.
  - **Summary:**
    - EN: "Deleted: your account and your tasks, notes and files, on all your devices." / "Stays for the others: what you added to shared projects, without your name." / "Deleting your account doesn't cancel TaskFlow Pro on Google Play."
    - ES: «Se eliminan tu cuenta y tus tareas, notas y archivos en todos tus dispositivos.» / «Se queda para los demás lo que añadiste a proyectos compartidos, sin tu nombre.» / «Eliminar tu cuenta no cancela TaskFlow Pro en Google Play.»
    - CA: «Es suprimeixen el compte i les teves tasques, notes i fitxers a tots els dispositius.» / «Es queda per als altres el que vas afegir a projectes compartits, sense el teu nom.» / «Suprimir el compte no cancel·la TaskFlow Pro a Google Play.»
  - **§3, English:**
    1. "Deleted, on all your devices: your account, your tasks, notes and files, and projects only you use. That includes your sign-in, Google link, sessions, project and group memberships, notification settings and your count of free dictations. We also ask RevenueCat, the company that checks subscriptions for us, to delete its record of you."
    2. "Stays for the others: tasks and files you added to shared projects. Your name is taken off them, "Created by" included, but what you wrote inside them doesn't change. Projects and groups you own pass to another member; the app tells you who before you confirm. Ask support about personal details inside shared content."
    3. "Not deleted by the app: Google Play's own record of your purchases, your emails with support, security logs, and backups, which expire on their own. Ask support to delete what can be deleted; we'll tell you what must be kept, why and for how long. We can't delete copies other people saved."
  - **§3, Spanish:**
    1. «Se elimina, en todos tus dispositivos: tu cuenta, tus tareas, notas y archivos y los proyectos que solo usas tú. También tu acceso, el vínculo con Google, las sesiones, tu pertenencia a proyectos y grupos, tus ajustes de avisos y tu recuento de dictados gratis. Además, pedimos a RevenueCat, la empresa que comprueba las suscripciones por nosotros, que borre su registro tuyo.»
    2. «Se queda para los demás: las tareas y archivos que añadiste a proyectos compartidos. Se quita tu nombre, también de «Creada por», pero lo que escribiste en ellos no cambia. Los proyectos y grupos que son tuyos pasan a otro miembro; la app te dice a quién antes de confirmar. Si dentro hay datos personales tuyos, escribe a soporte.»
    3. «La app no borra: el registro de tus compras que guarda Google Play, tus correos con soporte, los registros de seguridad ni las copias de seguridad, que caducan solas. Pide a soporte que borre lo que se pueda; te diremos qué hay que conservar, por qué y cuánto tiempo. No podemos borrar las copias que hayan guardado otras personas.»
  - **§3, Catalan:**
    1. «Se suprimeix, a tots els dispositius: el compte, les teves tasques, notes i fitxers i els projectes que només fas servir tu. També l'accés, el vincle amb Google, les sessions, la pertinença a projectes i grups, les preferències d'avisos i el recompte de dictats gratuïts. A més, demanem a RevenueCat, l'empresa que comprova les subscripcions per nosaltres, que esborri el registre que té de tu.»
    2. «Es queda per als altres: les tasques i els fitxers que vas afegir a projectes compartits. Se'n treu el teu nom, també de «Creada per», però el que hi vas escriure no canvia. Els projectes i grups que són teus passen a un altre membre; l'app et diu a qui abans de confirmar. Si a dins hi ha dades personals teves, escriu a suport.»
    3. «L'app no suprimeix: el registre de les teves compres que guarda Google Play, els correus amb suport, els registres de seguretat ni les còpies de seguretat, que caduquen soles. Demana a suport que suprimeixi el que es pugui; et direm què s'ha de conservar, per què i durant quant de temps. No podem suprimir les còpies que hagin desat altres persones.»
  - **§4, first paragraph:**
    - EN: "In the app, your account is deleted as soon as you confirm, and its files right after (if one can't be removed then, we follow it up). You see the confirmation in the app; no email is sent. If the app shows an error, don't assume it worked: try again or write to support."
    - ES: «En la app, tu cuenta se elimina en cuanto confirmas, y sus archivos justo después (si alguno no se puede borrar en ese momento, nos ocupamos después). Ves la confirmación en la app; no se envía ningún correo. Si la app muestra un error, no lo des por hecho: vuelve a intentarlo o escribe a soporte.»
    - CA: «A l'app, el compte se suprimeix tan bon punt confirmes, i els fitxers just després (si algun no es pot suprimir en aquell moment, ens n'ocupem després). Veus la confirmació a l'app; no s'envia cap correu. Si l'app mostra un error, no ho donis per fet: torna-ho a provar o escriu a suport.»
  - **§5, the last sentence of the first paragraph**, in the app's current words (`app_en.arb:1692`, `app_es.arb:1082`, `app_ca.arb:786`):
    - EN: "Test purchases only: no real payment is taken."
    - ES: «Solo compras de prueba: no se realiza ningún cobro real.»
    - CA: «Només compres de prova: no es fa cap cobrament real.»
  - Update `tests/legal.spec.ts:130-135`.
- **Verify:**
  - Playwright, on the delete page in each language:
    - the summary contains "tasks, notes and files" / «tareas, notas y archivos» / «tasques, notes i fitxers»;
    - `#scope`, `#timing` and `#subscription` contain none of "customer record", «base de datos», «base de dades», "Test Store", "staging", «ventana móvil» or «finestra mòbil».
  - Read the new summary aloud to someone over 60.
- **Evidence:** verified in code; seen in current renders.

**WEB-204 · Severity 2 · Delete page: the quicker in-app route looks like small print**
- **Where:**
  - `src/content/legal/index.ts:46-48`, `89-91`, `132-134` (`requestTitle`, `requestIntro`);
  - `src/components/LegalPage.tsx:150-161` and `70-73`;
  - `src/styles/legal.css:94-99`;
  - renders `delete-account.es.mobile.light.fold.png`, `delete-account.es.desktop.light.fold.png` and `delete-account.ca.mobile-w320.light.fold.png`.
- **The moment:** "Me dice que escriba un correo y que tardan hasta un mes… ¿no lo puedo hacer yo desde el móvil?"
- **What happens:**
  - The only filled control is the email request, which support answers "within one calendar month".
  - The in-app route deletes at once and shows what goes before you confirm. Yet it's a 14 px grey line: «Ajustes → Cuenta → Eliminar cuenta. También puedes escribirnos aquí.» (`section.legal-request > div > p`: 14 px in AUDIT §6, 5.84:1 in §7). It's outside the predicted first three fixations.
  - Nothing says which route is meant for whom.
  - At 320 × 568 the email button falls below the first screen. At 390 × 664 it's inside (y≈569–623).
- **Why it fails:**
  - CT-11: one obvious step, plus one alternative that says when to use it.
  - PV-7: the request path is prominent.
  - SC-4: front-load what matters. RD-5: readable size.
- **Fix:**
  1. Stop rendering the hero description on this page (`LegalPage.tsx:130`). WEB-203 does it on every legal page, and the box heading already says the same. This lifts the button ≈80 px, into the first screen at 320 × 568.
  2. `requestIntro`, in ink at 1rem (`legal.css:94-99`), in the app's words (`deleteAccountWhatGoes`):
     - EN: "With the app: Settings → Account → Delete account. You'll see what will be deleted before you confirm."
     - ES: «Con la app: Ajustes → Cuenta → Eliminar cuenta. Verás lo que se eliminará antes de confirmar.»
     - CA: «Amb l'app: Configuració → Compte → Suprimeix el compte. Veuràs el que es suprimirà abans de confirmar.»
  3. Directly above the email button (`LegalPage.tsx:70`), one line that replaces "You can also email us below":
     - EN: "No app, or can't sign in? Email us:"
     - ES: «¿Sin la app o no puedes entrar? Escríbenos:»
     - CA: «Sense l'app o no pots entrar? Escriu-nos:»

  The email button stays fully inside the first phone screen: Play wants a request path that doesn't need the app (`tests/legal.spec.ts:206-209`).
- **Verify:**
  - That test runs for EN, ES and CA, at 390 × 664 and at 320 × 568.
  - On the new phone fold render, the in-app line is ink-coloured at ≥ 16 px.
  - Walkthrough: a Leaver who still has the app reads the steps without tapping the button.
- **Evidence:** seen in current renders; measured (AUDIT §6). The attention ranking is predicted, not measured.

**WEB-203 · Severity 2 · The privacy page's first screen has no privacy facts**
- **Where:**
  - `src/components/LegalPage.tsx:128-130` (eyebrow, H1, description);
  - `src/content/legal/en.ts:5-12`, `es.ts:5-12`, `ca.ts:5-12`;
  - the same template on terms (`en.ts:190`, `es.ts:184`, `ca.ts:184`) and on the legal notice (`en.ts:305`, `es.ts:299`, `ca.ts:299`);
  - the eyebrow's style, `src/styles/global.css:121-126`;
  - renders `privacy.es.mobile.light.fold.png`, `terms.es.mobile.light.fold.png` and `privacy.es.desktop.light.fold.png`.
- **The moment:** "«Tu privacidad, con claridad.»… vale, pero ¿qué hacéis con mis datos?" They scroll, find «Usamos tu contenido para prestarte TaskFlow», and give up before §3.
- **What happens:**
  - On a phone, the first 622 px go to:
    - the header, the back link and the language switch;
    - an 8 px letter-spaced eyebrow (AUDIT §6);
    - a slogan H1;
    - a 3-line grey description.
  - The description names the document («Política de privacidad de la app y la web de TaskFlow: …»), but the H1 doesn't. *Corrected from my first review, which said only the eyebrow named it.*
  - The first summary card starts at y≈622 of 664, and its line is generic ("Your content is used to provide TaskFlow").
  - The fact that matters most to someone wary of giving data away is on phone screen ≈6: "We do not sell personal data, run advertising trackers, or use task content to target advertisements" (`en.ts:48`).
  - The `<title>` names the document, so Play's rule is met: "Clear labeling as a privacy policy (for example, listed as 'privacy policy' in title)" (Play User Data policy). This finding is about people, not Play.
- **Why it fails:**
  - PV-1: a layered, plain summary first (GDPR art. 12; WP260).
  - AT-2: ≈70% of gaze falls on the top half of a phone screen (Lagun 2014).
  - HE-3, SC-4: clear beats clever; front-load the words that matter.
  - AX-5: descriptive headings (2.4.6).
- **Fix:** subtract first.
  1. **The H1 names the document,** and the eyebrow goes (`LegalPage.tsx:128`):
     - Privacy: "TaskFlow Privacy Policy" / «Política de privacidad de TaskFlow» / «Política de privacitat de TaskFlow».
     - Terms: "TaskFlow Terms and Conditions" / «Términos y condiciones de TaskFlow» / «Termes i condicions de TaskFlow».
     - Legal notice: "Legal notice: the company behind TaskFlow" / «Aviso legal: la empresa detrás de TaskFlow» / «Avís legal: l'empresa darrere de TaskFlow».
     - Delete page: unchanged, apart from WEB-206's Catalan verb.
  2. **Stop rendering the description** (`LegalPage.tsx:130`) on all four pages. Keep it as the meta description in `legalMetadata`.
  3. **Privacy summary** (`en.ts:8-12`, and the same lines in `es.ts` and `ca.ts`):
     - EN: "We don't sell your data or show you ads." / "Your words go to Google's AI only when you ask TaskFlow to turn them into tasks." / "You can get a copy of your data or delete it whenever you want."
     - ES: «No vendemos tus datos ni te mostramos anuncios.» / «Tus palabras solo van a la IA de Google cuando pides a TaskFlow que las convierta en tareas.» / «Puedes pedir una copia de tus datos o eliminarlos cuando quieras.»
     - CA: «No venem les teves dades ni et mostrem anuncis.» / «Les teves paraules només van a la IA de Google quan demanes a TaskFlow que les converteixi en tasques.» / «Pots demanar una còpia de les teves dades o suprimir-les quan vulguis.»
- **Verify:**
  - Playwright at 390 × 664 on the privacy page in each language: `.legal-summary li:first-child` is fully in the viewport, and the H1 text equals the document's name.
  - On the new render, the first summary line sits above y = 664 and the H1 still ends in the upper half.
  - AUDIT §12: each H1 names its document.
- **Evidence:** seen in current renders; measured (AUDIT §6, §12); verified in code.

**WEB-205 · Severity 2 · Legal text: 14 px grey, ≈140-character lines, and it doesn't grow**
- **Where:** `src/styles/legal.css`. Every size is in px.

  | Lines | What | Today (AUDIT) |
  |---|---|---|
  | 217-223 | Body text | 14 px, line-height 1.95, no max-width |
  | 171-177 | Contents links | 12 px; rows 33.2 px on desktop and 39.2 px on phones, 0 px apart (§5) |
  | 188-194 | Related documents | 12 px; rows 36 / 38 px |
  | 304-307 | Link lists | rows 35.3 px |
  | 259-264, with `LegalPage.tsx:35` | The company's email links | 19 px tall |
  | 94-99 | Request box text | 14 px |
  | 283-288 | The line under the email button | 13 px |
  | 113-117, 163-170, 254-258 | Labels | 12 px and 11 px |
  | 138-143 | Summary numbers | 11 px |
  | 49-56 | Version line | 12 px |
  | 155-162 | Sidebar | a scroll box with 2 px padding: cuts focus rings by up to 6 px (§10) |

  Renders: `privacy.es.desktop.light.full.png`, screen 2; `privacy.es.mobile-text200.light.fold.png` (byte-identical to the 100% render); `focus/delete-account.es.desktop.light.14.png`.
- **The moment:** "Letra pequeña y gris, renglones que cruzan toda la pantalla… y si le pido al navegador letra más grande, no cambia nada. Lo dejo."
- **What happens:**
  - **Size.** 91–92% of the privacy page's characters are 14 px, and 3% are 16 px or more (AUDIT §6). On the delete page, 78–79% are 14 px and 13–14% are 12–13 px.
  - **Text size setting.** When the browser's default text size is doubled, 0 of 140 elements on the privacy page grow ("every size is in px", AUDIT §3). The text200 renders are byte-identical to the 100% ones on all 12 legal pages.
    - Page zoom still works, so WCAG 1.4.4 passes (zoom200 renders, AUDIT §3).
    - But a reader who set a bigger default text size gets nothing.
  - **Line length.** At 1440 px, lines run ≈135–140 characters.
  - **Targets.** On phones, contents rows are 39 px, link rows 35 px and the company's email links 19 px tall: all under the 44 px bar.
  - **Focus.** On desktop, the sidebar's scroll box cuts the focus ring of 15 links on the privacy page by up to 6 px (AUDIT §10). The ring stays visible but is cut. *My first review inferred this; it's now measured.*
  - **Contrast passes:** grey body text is 5.47:1 light and 8.86:1 dark, and grey on mint 4.87:1 and 6.21:1 (AUDIT §7). The problem is size, line length and scaling.
- **Why it fails:**
  - RD-4: 50–75 characters a line (Baymard; Dyson & Haselgrove; WCAG 1.4.8 AAA ≤ 80).
  - RD-5: body text ≥ 16 px in rem or em. This is an expert guideline; no official minimum exists.
  - AX-3: text that responds to the reader's settings.
  - CT-6: 44 px rows.
  - OL-1: older readers' trouble with tiny type (Nielsen 2013; Kane 2019).
- **Fix:** all in `legal.css`, with sizes in rem so the browser's text size applies:
  - `.legal-body p, .legal-body li`: `font-size: 1rem; line-height: 1.7; max-width: 68ch`.
  - `.legal-request p` and `.legal-contact .legal-contact-help`: `1rem`.
  - `.legal-toc a` and `.legal-related a`: `0.875rem`; on phones, `padding-block: 12px`, so rows are ≥ 44 px.
  - `.legal-links a` and `.legal-company a`: `display: inline-block; padding-block: 12px`.
  - `dt` labels, sidebar labels and `.legal-version`: `0.8125rem`. `.legal-summary span`: `0.75rem`.
  - `.legal-sidebar`: 8 px padding, so its scroll box doesn't cut the 3 px ring drawn at a 5 px offset.
  - Once text can grow, ES and CA words mustn't push the page sideways:
    - `.legal-languages { flex-wrap: wrap }`;
    - `.legal-hero h1 { overflow-wrap: break-word; hyphens: auto }` (the article carries `lang`).

    This is WEB-208's old overflow fix, moved here.
  - The site-wide `body { font-size: 15px }` is G's (WEB-309, WP12).
- **Verify:**
  - AUDIT §3 on the next run: the text200 rows for the legal pages list the body text as grown, with no sideways scroll at 390 px. The text200 renders differ from the 100% ones.
  - The computed `font-size` of `.legal-body p` is ≥ 16 px, and at 1440 px no `.legal-body` line passes 80 characters.
  - AUDIT §5: no legal link is under 44 px tall on phones, except links inside sentences.
  - AUDIT §10: 0 rings clipped.
- **Evidence:** measured (AUDIT §3, §5, §6, §7, §10); seen in renders. Android Chrome's own text-size setting is a device check.

**WEB-206 · Severity 2 · Catalan pages say «Eliminar»; the app says «Suprimeix el compte»**
- **Where:**
  - `src/content/legal/index.ts:140` (email body), `:145` (button), `:150` (subject), `:156` (the title: eyebrow, `<title>`, og:title, related link, hero link);
  - `ca.ts:21, 75, 159, 164, 177, 242, 263, 269, 314, 337, 351, 360, 366, 368, 370, 393`;
  - `tests/legal.spec.ts:69, 93`;
  - render `delete-account.ca.mobile.dark.fold.png`; AUDIT §11 (og:title «Eliminar compte — TaskFlow»).
- **The moment:** "A la web posa «Eliminar compte»; a l'app no ho trobo… ah, es diu «Suprimeix el compte»."
- **What happens:**
  - One phone screen shows four forms:
    - «Eliminar compte» (eyebrow);
    - «Elimina el teu compte de TaskFlow.» (H1);
    - «Suprimeix el compte» (description and steps);
    - «Escriure sol·licitud d'eliminació» (button).
  - The §3 and contents heading says «Què s'elimina i què roman». The link preview says «Eliminar compte — TaskFlow».
  - The app always says «Suprimeix el compte», «El que es suprimirà», «Suprimeix el meu compte» and «S'ha suprimit el compte» (`App/lib/l10n/app_ca.arb:910, 913, 931, 945`).
  - Spanish and English already match the app.
- **Why it fails:** FN-2 (the app's names); ML-6; lens G (one concept, one name).
- **Fix:**

  | Where | Today | Becomes |
  |---|---|---|
  | `index.ts:156`, title | «Eliminar compte» | «Suprimeix el compte» |
  | `ca.ts:337`, H1 | «Elimina el teu compte de TaskFlow.» | «Suprimeix el teu compte de TaskFlow.» |
  | `index.ts:145`, button | «Escriure sol·licitud d'eliminació» | «Escriu la sol·licitud de supressió» |
  | `index.ts:150`, subject | «Eliminar el meu compte de TaskFlow» | «Suprimir el meu compte de TaskFlow» |
  | `index.ts:140`, email body | «Sol·licito l'eliminació…» | «Sol·licito la supressió…» |
  | `ca.ts:366`, §3 and contents | «3. Què s'elimina i què roman» | «3. Què se suprimeix i què es queda» |
  | `ca.ts:368, 370` | «S'elimina…», «no elimina automàticament…» | rewritten by WEB-202 |
  | `ca.ts:164`, privacy link | «Demanar l'eliminació del compte» | «Demanar la supressió del compte» |
  | `ca.ts:269`, terms link | «Eliminar el compte i les dades associades» | «Suprimir el compte i les dades associades» |
  | `ca.ts:21`, `:314` | «eliminació de comptes» | «supressió de comptes» |
  | `ca.ts:75`, `:159`, `:177`, `:263` | «eliminar el compte», «Eliminar el compte no…», «l'eliminació del compte», «demanar eliminació» | «suprimir el compte», «Suprimir el compte no…», «la supressió del compte», «demanar-ne la supressió» |
  | `ca.ts:242` | «Eliminar app o compte no cancel·la…» | «Desinstal·lar l'app o suprimir el compte no cancel·la…» |
  | `ca.ts:351`, `:360` | «no elimina res», «no elimina un compte immediatament» | «no suprimeix res», «no suprimeix cap compte immediatament» |
  | `ca.ts:393` | «Eliminar TaskFlow no elimina el compte de Google o Apple» | «El compte de Google no se suprimeix» (`app_ca.arb:928`) |

  Update `tests/legal.spec.ts:69` and `:93`. Catalan: I'm confident, but a native read would help.
- **Verify:**
  - On `/ca/delete-account/`, the H1, `<title>`, og:title, button, related link, mail subject and §3 heading use «Suprimeix», «Suprimir» or «supressió».
  - `ca.ts` has no «elimin…» left for the account. Content verbs such as «esborrar» can stay.
- **Evidence:** verified in code; seen in the render; measured (AUDIT §11).

**WEB-207 · Severity 2 · The demo's "How we use your data" lands on the app's section**
- **Where:**
  - `src/components/VoiceDemo.tsx:393-397`, the link to `/privacy/#voice`. This is H's file, and the other session has edits in it, so the change stays uncommitted.
  - `src/content/legal/en.ts:53-58` (§4) and `:136-142` (§8), and the same lines in `es.ts` and `ca.ts`.
- **The moment:** "Voy a grabar en la demo. ¿Guardan mi voz?" The section opens with the app's microphone and "Recordings are sent for cloud transcription".
- **What happens:**
  - §4 (`#voice`) is about the app. The demo's facts are in §8 (`#website`), four sections further down.
  - Nowhere does the policy say the demo keeps no recording.
    - The committed page used to: "We do not store recordings." (`git -C ../TaskFlowWeb show HEAD:src/app/privacy/page.tsx`)
    - The server keeps only the sealed text result, for 24 hours (`src/lib/voice/store.ts:118-123`).
- **Why it fails:**
  - CT-4: the destination keeps the label's promise.
  - RD-7: links say where they go.
  - PV-3: the note before recording says how long things are kept.
- **Fix:**
  1. The link goes to `/privacy/#website`, in the page's language once the demo is translated (WEB-2).
  2. §8 opens with the demo's facts:
     - EN: "Live demo: we don't keep your recording. The text and drafts are kept encrypted for up to 24 hours, so a retry doesn't use another try, and are then deleted automatically."
     - ES: «Demo en vivo: no guardamos tu grabación. El texto y los borradores se guardan cifrados hasta 24 horas, para que reintentar no gaste otro intento, y después se borran automáticamente.»
     - CA: «Demo en viu: no desem la gravació. El text i els esborranys es desen xifrats fins a 24 hores, perquè tornar-ho a provar no gasti un altre intent, i després s'esborren automàticament.»
- **Verify:** Playwright:
  - clicking "How we use your data" lands on a URL ending `/privacy/#website`, with `#website-title` in the viewport;
  - §8's first sentence contains "we don't keep your recording" / «no guardamos tu grabación» / «no desem la gravació».
- **Evidence:** verified in code.

**WEB-602 · Severity 2 · Privacy §8 will describe a site this run removes**
- **Where:** privacy §8 (`#website`), `src/content/legal/en.ts:139` and `:142`, and the same lines in `es.ts` and `ca.ts`; §7's "Public demo" bullet, `:129` in all three. It depends on three changes in this run:
  - WD1 removes the walkthrough (`.claude/ux-web/DECISIONS.md:23`);
  - WD5 remembers the chosen language (`.claude/ux-web/DECISIONS.md:39-41`);
  - the demo's button is renamed and translated (WEB-109, WEB-12).
- **The moment** (once those packages ship): "La política habla de un «recorrido de ejemplo» que no existe y de un botón «Create drafts» que no veo."
- **What happens:**
  - §8 opens with "The sample walkthrough is a simulation: edits stay in page memory…", and WD1 removes the walkthrough.
  - WD5 makes the browser remember a language picked in the language switch. WD5 itself says privacy §8 must say so, but §8 lists only `taskflow-theme`.
  - §8 names the demo's button "Create drafts", in English on the ES and CA pages too (`es.ts:139`, `ca.ts:139`), and the run renames and translates that button (WEB-109).
  - Each sentence is true today and becomes false on the day its package ships.
- **Why it fails:**
  - FN-1: the site follows its own changes, too.
  - PV-4: the storage the policy lists is complete. The AEPD exempts preferences the visitor picks from consent, but §8 presents itself as the list.
- **Fix:** in the same package as each change.
  - **With WD1:** remove §8's first two sentences ("The sample walkthrough… to AI.") in the three languages.
  - **With WD5:** §8's storage paragraph gains, after the theme sentence:
    - EN: "If you pick a language in the language switch, this browser remembers it, like the theme, so the site opens in that language next time."
    - ES: «Si eliges un idioma en el selector de idioma, este navegador lo recuerda, como el tema, para que la web se abra en ese idioma la próxima vez.»
    - CA: «Si tries un idioma al selector d'idioma, aquest navegador el recorda, com el tema, perquè el web s'obri en aquest idioma la propera vegada.»

    Name the storage key, as §8 names `taskflow-theme`. In §7's "Public demo" bullet, "The theme preference remains…" becomes "The theme and language preferences remain until you clear browser storage."
  - **With WEB-109's rename:** §8 uses the button's new label in each language.
- **Verify:**
  - A Playwright check reads the demo's button label from its copy table and asserts that `/privacy/#website` contains it, in each language.
  - `#website` contains no "walkthrough", «recorrido» or «recorregut» once WD1 ships.
  - `#website` names the language key once WD5 ships.
- **Evidence:** verified in code and in the decisions. The packages haven't run yet, so no render shows it.

**WEB-209 · Severity 2 · Privacy, terms and legal notice use engineering words**
- **Where:** the lines in the table below; render `privacy.en.desktop.dark.full.png`, screen 5.
- **The moment:** "«hashes con clave», «borrado TTL asíncrono», «APK», «Test Store», «SDK», «punto de acceso global»… esto no está escrito para mí."
- **What happens:** the detailed layer uses build and operations terms the Newcomer can't read, although the page's whole promise is "clearly explained".
- **Why it fails:**
  - PV-1: GDPR art. 12 asks for "clear and plain language", and WP260 says to avoid technical terms.
  - HE-10: NN/g Techy terms; Kane 2019.
  - RD-3: plain language.
  - FN-2: for "project/list", the app's name.
- **Fix:** replace the terms in the three languages. Keep the providers' names: they're the recipients the law requires the policy to name.

  | Today | Lines | EN | ES | CA |
  |---|---|---|---|---|
  | "Test Store purchases… renew/expire faster" | `en.ts:205`, `es.ts:199`, `ca.ts:199` | "Test purchases only: no real payment is taken, and test subscriptions can renew or end sooner than real ones." | «Solo compras de prueba: no se cobra nada, y las suscripciones de prueba pueden renovarse o terminar antes que las reales.» | «Només compres de prova: no es cobra res, i les subscripcions de prova poden renovar-se o acabar abans que les reals.» |
  | "private staging test" | `en.ts:205` | "private test version" | already plain | already plain |
  | "staging database and file storage", "staging build" | `en.ts:80`, `:84` | "The test version's database and files are in Frankfurt, Germany." / "The test version uses test purchases, with no charge." | already plain | already plain |
  | "public APK download" | `en.ts:328`, `es.ts:322`, `ca.ts:322` | "public app download" | «…ni ofrece la app para descargar» | «…ni ofereix l'app per descarregar» |
  | "eligible for database TTL deletion, which is asynchronous" | `:141` | "then it's deleted automatically" | «Después se borran automáticamente.» | «Després s'esborra automàticament.» |
  | "keyed hashes of network addresses; hashing does not make those records anonymous" | `:140` | "a coded form of your network address, which still counts as personal data" | «una forma codificada de tu dirección de red, que sigue siendo un dato personal» | «una forma codificada de la teva adreça de xarxa, que continua sent una dada personal» |
  | "password hash", "integrity hashes" (§2); "password hashing" (§9) | `en.ts:29, 31, 156`; `es.ts:29, 31, 150`; `ca.ts:29, 31, 150` | "your password, stored so it can't be read back"; "a check code that spots damaged files"; "passwords stored so they can't be read back" | «tu contraseña, guardada de forma que no se puede volver a leer»; «un código de control que detecta archivos dañados»; «contraseñas guardadas de forma que no se pueden volver a leer» | «la contrasenya, desada de manera que no es pot tornar a llegir»; «un codi de control que detecta fitxers malmesos»; «contrasenyes desades de manera que no es poden tornar a llegir» |
  | "Processing can use a global endpoint"; "AI global endpoints" | `:56`, `:114` | "Google can process it outside the EU"; "Google's AI" | «Google puede procesarlo fuera de la UE»; «la IA de Google» | «Google ho pot processar fora de la UE»; «la IA de Google» |
  | "related SDK data" (§5); "app/OS information needed by service SDKs" (§2) | `:84`, `:35` | "data from its component in the app"; "your phone's and app's versions, which our providers' components need" | «datos de su componente en la app»; «la versión del teléfono y de la app que necesitan los componentes de nuestros proveedores» | «dades del seu component a l'app»; «la versió del telèfon i de l'app que necessiten els components dels nostres proveïdors» |
  | "PostgreSQL account/content data" | `:80` | "the database of accounts and content" | «la base de datos de cuentas y contenido» | «la base de dades de comptes i contingut» |
  | "ordinary Cloud Run application logs have a 30-day retention setting" | `:127` | "our servers' logs are kept for 30 days" | «los registros de nuestros servidores se guardan 30 días» | «els registres dels nostres servidors es conserven 30 dies» |
  | "our backend" | `en.ts:30, 56, 156` | "our servers" | already «servidor» | already «servidor» |
  | "shared project/list", "shared projects/lists" | `en.ts:75, 221`; `es.ts:75, 215`; `ca.ts:75, 215` | "shared project" | «proyecto compartido» | «projecte compartit» |

- **Verify:** Playwright text search across the nine privacy, terms and legal-notice pages: none of "Test Store", "staging", "APK", "TTL", "hash", "endpoint", "SDK", "PostgreSQL", "Cloud Run", "backend" or "project/list", nor «punto de acceso», «punt d'accés», «hash», «SDK», «TTL», «Test Store», «staging» or «APK». The delete page's own terms are WEB-202's.
- **Evidence:** verified in code.

**WEB-208 · Severity 1 · Language switch: the current language is shown by colour only**
- **Where:**
  - `src/styles/legal.css:24-27` (`.legal-languages a[aria-current]`: green text on mint, at the same 650 weight as the others);
  - `src/components/LegalPage.tsx:113-125`;
  - every legal page; renders `delete-account.es.mobile.light.fold.png` and `delete-account.ca.mobile.dark.fold.png`.
- **The moment:** a colour-blind or low-vision visitor: "¿Cuál está marcado?"
- **What happens:**
  - The current language differs from the others only by colour. Its mint pill is 1.12:1 against the page (1.43:1 dark; AUDIT §8 flags it as weak). Its green text is 2.03:1 against the others' ink, computed from the tokens.
  - Screen readers do get the state (`aria-current="page"`, `LegalPage.tsx:120`).
  - Lower than my first review, because the page's own text already shows which language it is.
- **Withdrawn from the first review:** that the switch and the H1 overflow at large text sizes.
  - Measured: nothing scrolls sideways at 320 px, at 200% zoom or with doubled text, on any legal page (AUDIT §3).
  - The risk returns only once the text can grow; WEB-205 now carries the wrapping rules.
- **Why it fails:** AX-2: WCAG 1.4.11 (a state indicator needs 3:1) and 1.4.1 (colour alone).
- **Fix:** `.legal-languages a[aria-current] { box-shadow: inset 0 0 0 2px var(--green); font-weight: 800 }`. The ring is 5.13:1 against the mint pill in light and 7.33:1 in dark (the #176e59 / #e5eddf and #9ed5b3 / #243a2e pairs, AUDIT §7).
- **Verify:** the computed style of `a[aria-current]` has the 2 px ring in both themes, and AUDIT §8 no longer lists the current language as weak.
- **Evidence:** measured (AUDIT §3, §8); contrast computed from the tokens.

**WEB-210 · Severity 1 · Apple subscriptions on an Android-only product**
- **Where:** `en.ts:84, 248, 397, 398, 406-407`; `es.ts:84, 242, 391, 392, 400-401`; `ca.ts:84, 242, 392, 393, 401-402`. AUDIT §5 lists the "Manage Apple subscriptions" link on every delete page.
- **The moment:** "¿Hay versión para iPhone?"
- **What happens:**
  - The delete page links to "Manage Apple subscriptions" and says deleting doesn't delete "your Google or Apple account".
  - Terms §6 and privacy §5 mention Apple.
  - TaskFlow is Android only (CLAUDE.md; WD7), and no iOS build has been made (`App/docs/REVENUECAT_SETUP.md:16`). The app names only Google Play (`app_en.arb:2136`).
- **Why it fails:** FN-1; AP-7 (Android only, said plainly); subtract first.
- **Fix:** WD7 and WD3 decided it.
  - **Delete §5:**
    - "…a Google Play or Apple subscription" → "Deleting your account doesn't cancel TaskFlow Pro on Google Play." / «Eliminar tu cuenta no cancela TaskFlow Pro en Google Play.» / «Suprimir el compte no cancel·la TaskFlow Pro a Google Play.»
    - "…your Google or Apple account" → "Your Google account isn't deleted." / «Tu cuenta de Google no se elimina.» / «El compte de Google no se suprimeix.» These are the app's words (`deleteAccountGoogleHelp`).
    - Remove the Apple link.
  - **Privacy §5:** "Google Play or Apple handles…" → "Google Play handles payments…" / «Google Play tramita los pagos…» / «Google Play tramita els pagaments…».
  - **Terms §6:** "Manage or cancel an Apple/Google subscription in the store account used to buy it" → "Manage or cancel it in the Google Play account you used to buy it" / «Gestiónala o cancélala en la cuenta de Google Play con la que la compraste» / «Gestiona-la o cancel·la-la al compte de Google Play amb què la vas comprar».
- **Verify:** no "Apple" in the visible text of the 12 legal pages; AUDIT §5 no longer lists the Apple link.
- **Evidence:** verified in code.

**WEB-211 · Severity 1 · Legal notice: a note-to-self line, a mislabelled button, a Catalan registry line**
- **Where:**
  - summary line 3: `en.ts:311`, `es.ts:305`, `ca.ts:305`;
  - the `write` label: `index.ts:58, 101, 144`; `LegalPage.tsx:63-91`;
  - the registry line: `src/content/legal/company.json:5`;
  - render `legal.en.mobile.light.full.png`, screens 2–3.
- **The moment:**
  - "«Company and contact information belongs here.» Is this page finished?"
  - "«Contact TaskFlow»… which address is that?"
  - On the English page: "«Societat inscrita… Tom… Foli… Full… Inscripció»?"
- **What happens:**
  - The summary's third line reads like a note to self.
  - The "Contact TaskFlow" button (privacy §1 and §10, terms §10, legal notice §1) writes to support, while the paragraph above it gives taskflow@garbar.tech for general questions.
  - The registry line is in Catalan on the English and Spanish pages, with no `lang`. It's in the company card on privacy, terms and the legal notice.
- **Why it fails:**
  - TR-3: errors are trust bugs.
  - RD-7, CT-3: labels say what happens.
  - ML-5; ML-2 and WCAG 3.1.2: a passage in another language is marked.
- **Fix:**
  - **Summary line 3:** "Write to us at taskflow@garbar.tech." / «Escríbenos a taskflow@garbar.tech.» / «Escriu-nos a taskflow@garbar.tech.»
  - **`write`:** "Email support" / «Escribir a soporte» / «Escriu a suport». The address shown under the button stays.
  - **Registry line, per language:**
    - EN: "Registered in the Barcelona Mercantile Registry, volume 49105, folio 130, sheet 607875, entry 1".
    - ES: «Inscrita en el Registro Mercantil de Barcelona, tomo 49105, folio 130, hoja 607875, inscripción 1».
    - CA: unchanged.

    Alternatively, keep the registry's own wording everywhere, inside `lang="ca"`. The owner confirms the translation.
- **Verify:** the rendered text on `/legal/` and `/es/legal/`; axe passes; the owner confirms the registry wording.
- **Evidence:** verified in code; seen in the render.

**WEB-212 · Severity 1 · Internal links wear the "leaves the site" arrow; the support link opens email unannounced**
- **Where:**
  - `src/components/LegalPage.tsx:72` (mailto buttons), `:139` (the hero's «Eliminar cuenta»), `:143-144` (the hero's support link), `:189` (related documents), `:222-226` (link lists, internal and external alike);
  - `index.ts:45, 88, 131` (`support`);
  - renders `privacy.es.mobile.light.fold.png` and `privacy.es.mobile.light.full.png`, screens 2–3.
- **The moment:**
  - "«Eliminar cuenta ↗»: ¿me saca de la web?"
  - "«Soporte y privacidad» me ha abierto el correo."
- **What happens:** the same ↗ marks three different things:
  - pages on this site: «Eliminar cuenta», every «Documentos legales» link, the `#rights` and `#retention` links;
  - other websites: Neon, the AEPD;
  - mailto buttons.

  «Soporte y privacidad» opens an email draft without saying so.
- **Why it fails:** RD-7 (links say where they go); NV-8 (familiar patterns).
- **Fix:**
  - The plain → (`Icon name="arrow"`) for pages on this site.
  - ↗ only for `http(s)` links to other websites.
  - No arrow on mailto buttons.
  - `support` label: "Email support" / «Escribir a soporte» / «Escriu a suport», the same string as WEB-211's `write`.
- **Verify:** every `a[href^="/"]` inside `.legal-page` uses the → icon, every `a[href^="http"]` uses ↗, and mailto links have no arrow.
- **Evidence:** verified in code; seen in renders.

**WEB-213 · Severity 1 · "Versión 2026-10-16" doesn't read as "in force since"**
- **Where:** `index.ts:35, 78, 121` (`updated`); `LegalPage.tsx:131-134`; `company.json:10`; every legal page. A screen reader reads "Versión", then "2026-10-16" (`aria/delete-account.es.mobile.txt`).
- **The moment:** "¿Versión 2026-10-16? ¿Es la buena?"
- **What happens:**
  - A technical label and an ISO date sit where people expect "last updated" or "in force since".
  - `docs/LEGAL_RELEASE.md:3` calls it the effective date.
  - WD3 moves `company.version` to the day of the edit.
- **Why it fails:** RD-3 (plain language); ML-6 (written for each language).
- **Fix:**
  - "In force since <date>" / «En vigor desde el <date>» / «En vigor des del <date>», with the edit's date. For example: "In force since 19 October 2026" / «En vigor desde el 19 de octubre de 2026» / «En vigor des del 19 d'octubre de 2026».
  - Format it with `Intl.DateTimeFormat` and `dateStyle: "long"`, using `en-GB` for English.
  - Keep `<time dateTime>`.
  - Update `tests/legal.spec.ts:32-35` to the new date.
- **Verify:** the rendered text in the three languages, and the updated test.
- **Evidence:** verified in code; the screen-reader snapshot.

### Claims checked

Lines are the English file unless noted; Spanish and Catalan sit at the same or nearby lines.

| # | Claim (page, `path:line`) | Source of truth (`path:line`) | Status |
|---|---|---|---|
| 1 | Delete in the app: Settings → Account → Delete account, in each language's names (delete §1 `en.ts:355`, `es.ts:349`, `ca.ts:350`; `index.ts:47-48, 90-91, 133-134`; terms §8 `en.ts:269`) | `App/lib/screens/settings_screen.dart:110`; `account_screen.dart:314-316`; `app_en.arb:184, 1586, 2038`; `app_es.arb:129, 976, 1206`; `app_ca.arb:108, 756, 910` | True on `dev`; the site ships with that app (WD13) |
| 2 | The screen identifies the account, counts what goes, and shows what stays and who receives it (`en.ts:355`) | `app_en.arb:2046-2132`; `Backend/docs/ACCOUNT_DELETION.md:35-41` | True |
| 3 | Save a copy first; files aren't included (`en.ts:355`, `269`) | `app_en.arb:2140, 2148` | True |
| 4 | Confirm with your password or Google; needs a connection; opening deletes nothing; a changed plan is shown again; you're signed out; it can't be undone (`en.ts:356`) | `Backend/core/account_deletion.py:127-128`; `ACCOUNT_DELETION.md:44-58`; `app_en.arb:2152-2239` | True |
| 5 | Deleted: profile, Google link, sessions, personal tasks, notes and files, private spaces, memberships, notification settings, usage records (`en.ts:373`) | `ACCOUNT_DELETION.md:20-22` | True |
| 6 | Shared content kept, with handovers; assignments and attribution removed (`en.ts:374`, `124`) | `ACCOUNT_DELETION.md:23-28` | True |
| 7 | "Does not automatically delete the RevenueCat customer record" (`en.ts:375`, `128`; `es.ts:369`, `128`; `ca.ts:370`, `128`) | `ACCOUNT_DELETION.md:32`; `account_deletion.py:216-219, 300-305`; `Backend/core/billing.py:47-66` | **False** (WEB-601) |
| 8 | The store's purchase history isn't deleted (`en.ts:375`, `128`) | `ACCOUNT_DELETION.md:33` | True |
| 9 | No automatic confirmation email (`en.ts:382`) | `ACCOUNT_DELETION.md:12, 63`; DECISIONS, night (UX-813 later) | True; changes when that email ships |
| 10 | Other devices lose access and clear their copy (`en.ts:125`, `398`) | `ACCOUNT_DELETION.md:53` | True |
| 11 | Deleting doesn't cancel a Google Play subscription (`en.ts:397`) | `app_en.arb:2136` | True |
| 12 | "…or Apple subscription", "Manage Apple subscriptions", "Google or Apple account" (`en.ts:84, 248, 397-407`) | CLAUDE.md (Android); WD7; `App/docs/REVENUECAT_SETUP.md:16` | Misleading (WEB-210) |
| 13 | Completed tasks aren't erased after 30 or 90 days (`en.ts:122`) | DECISIONS, night ("none for now") | True; refers to a dropped plan (WEB-113) |
| 14 | Invitation codes expire after 7 days (`en.ts:126`) | `Backend/core/group_views.py:148`; `list_views.py:167` | True |
| 15 | Recovery codes expire after 30 minutes (`en.ts:126`) | `Backend/core/auth_views.py:265` | True |
| 16 | Email confirmation codes: 6 digits, 30 minutes, from noreply (not stated) | `Backend/docs/EMAIL_VERIFICATION.md:3, 58, 69`; `Backend/core/email_verification.py:20` | Missing (WEB-113) |
| 17 | Invitations and recovery come from noreply, and replies go to support (`en.ts:21, 82, 320`) | CLAUDE.md, Email | True but incomplete (WEB-113) |
| 18 | Google sign-in gives the identifier, email and verification status (`en.ts:29`) | `Backend/docs/GOOGLE_SIGN_IN.md:69` | Incomplete: the first name is kept and shown to others (WEB-113) |
| 19 | "Recordings are sent for cloud transcription when you submit a capture" (`en.ts:55`) | `App/lib/providers/regional_provider.dart:20`; `voice_task_screen.dart:573`; `NativeSpeechBridge.kt:71, 109, 203`; `app_en.arb:397, 422` | Outdated: speech is recognised on the phone by default (WEB-113) |
| 20 | "Calendar entries you choose to turn into TaskFlow content may then be synchronised" (`en.ts:155`) | `app_en.arb:146`; no conversion in `App/lib/` | Outdated: no such feature, and events stay on the phone (WEB-113) |
| 21 | Shared content is available to members by role (`en.ts:75`) | `app_en.arb:1957`; DECISIONS 2026-10-18 later (points 4, 6) and night (D8) | True; leaves out that your name shows on tasks (WEB-113) |
| 22 | The AI gets language, time zone, reference date, and project and member names (`en.ts:33`) | `Backend/docs/VOICE_COMMANDS.md:7, 229` | True |
| 23 | Usage counts are kept to apply allowances (`en.ts:33`) | `ACCOUNT_DELETION.md:20`; DECISIONS 2026-10-13 (late) | True |
| 24 | An AI Studio / Gemini API route with a Vertex fallback; the demo uses Vertex (`en.ts:56`) | DECISIONS, night (UX-616) | True |
| 25 | Manual task entry instead of the AI (`en.ts:58`) | DECISIONS 2026-10-18 later (the form) | True |
| 26 | The demo sends audio or text only on "Create drafts" (`en.ts:139`; `es.ts:139` and `ca.ts:139` quote the English) | `src/components/VoiceDemo.tsx:393-397` | True today; the button's rename makes it stale (WEB-602, WEB-109) |
| 27 | The sample walkthrough is a simulation (`en.ts:139`) | `src/components/TaskDemo.tsx`; WD1 | True today; false once WD1 ships (WEB-602) |
| 28 | Turnstile loads after the demo is opened (`en.ts:140`) | `VoiceDemo.tsx:36-94` | True |
| 29 | Demo cookie 30 days, results 24 hours, quota 48 hours (`en.ts:129, 140-141`) | `src/lib/voice/security.ts:66`; `store.ts:115, 122` | True |
| 30 | The demo keeps no recording (not stated) | `src/lib/voice/store.ts:118-123` | Missing (WEB-207) |
| 31 | Only the theme in local storage; no ad cookies or marketing analytics (`en.ts:142`) | `src/components/ThemeProvider.tsx:64`; `src/app/layout.tsx:39`; `.claude/ux-web/DECISIONS.md:55` (no analytics before launch) | True today; WD5's remembered language must join it (WEB-602) |
| 32 | Neon in Frankfurt for the test version (`en.ts:80`) | `Backend/docs/STAGING.md:84` | True |
| 33 | Test purchases, no charge (`en.ts:84, 205, 397`) | `app_en.arb:1692` | True |
| 34 | No public download or checkout (`en.ts:205, 328`) | `.claude/ux-web/DECISIONS.md:68` | True |
| 35 | Backups expire with the provider's rolling window (`en.ts:132, 384`) | `Backend/docs/STAGING.md:258` (restore untested) | Unverifiable (WD12, the owner's) |
| 36 | Cloud Run logs are kept 30 days (`en.ts:127`) | `docs/LEGAL_RELEASE.md:38` in the website repo (hosting) | Unverifiable |
| 37 | Adults 18 and over only (`en.ts:183, 214`) | `company.json:9`; the app asks no age | Unverifiable (policy) |
| 38 | "We do not sell personal data, run advertising trackers, or use task content to target advertisements" (`en.ts:48`) | `src/app/layout.tsx` (no third-party scripts); `.claude/ux-web/DECISIONS.md:55` | True |

### Missing from the site (app features worth telling)
- **"We don't sell your data or show ads"** (`en.ts:48`). It reassures the visitor who's wary of giving data away. It goes in the privacy summary (WEB-203); near the demo or in the FAQ, it's the owner's call (H, F).
- **Speech recognised on the phone by default, with no audio leaving it** (`App/lib/providers/regional_provider.dart:20`; `app_en.arb:397, 422`). It goes in the privacy summary and §4 (WEB-113), and in the home page's voice FAQ (F).
- **Phone calendars never leave the phone** (`app_en.arb:146`). It goes in privacy §9 (WEB-113).
- **Delete in the app, with a preview of what goes** (`app_en.arb:2042-2132`). It goes in the home FAQ "Do I need an account?", with F's WEB-101 rewrite.
- **The RevenueCat record is deleted with the account.** It goes on the delete page (WEB-601).

### Keep
- **The delete page meets Play's web-deletion rules in all three languages:**
  - it names TaskFlow and GARBAR, IN-TEC, S.L.;
  - both routes and a working pre-filled email request are in the first phone screen at 390 × 664;
  - it says what goes and what stays;
  - nobody needs to reinstall, give a reason or pay;
  - the subscription caveat is there;
  - it works without JavaScript.
- **Honest limits and no dark patterns on the Leaver's path:** shared content, backups and Google Play's records are stated, and there's no guilt or retention trick.
- **The in-app steps use the app's exact names in each language:** Settings → Account → Delete account; Ajustes → Cuenta → Eliminar cuenta; Configuració → Compte → Suprimeix el compte.
- **Measured clean:**
  - no axe violations;
  - no text-contrast failure (lowest 4.87:1 light, 6.21:1 dark);
  - focus visible on all of the 30–53 tab stops;
  - named landmarks and sections, and one H1 with ordered H2s;
  - `lang` on the article and on each language name;
  - hreflang complete, with `x-default` and a canonical (AUDIT §4, §7, §9–§12).
- **Fast and stable in the lab:** LCP 1.54–1.96 s and CLS 0 on every legal page (AUDIT §2, lab data). The layout is identical in WebKit, and dark mode looks designed.

### Questions for the owner (product decisions only)
None new. These two are still his (WD12), and both pages keep today's cautious wording until he answers:
- the backup window behind "the provider's rolling window" (privacy §7, delete §4);
- whether a paid or a free Gemini tier serves the app's dictations (privacy §4).

### For the organizer
- **Uncommitted:** every L fix edits the other session's untracked files (`src/content/legal/`, `LegalPage.tsx`, `legal.css`, `tests/legal.spec.ts`), so they stay uncommitted. WEB-207's link is in `VoiceDemo.tsx` (H's package).
- **Suggested grouping:**
  - privacy text: WEB-113, WEB-601's privacy part, WEB-207's §8 sentence, WEB-209, WEB-213, and WEB-210's privacy and terms parts;
  - the delete page: WEB-202, WEB-204, WEB-206, WEB-601, and WEB-210's delete part;
  - template and styles: WEB-203, WEB-205, WEB-208, WEB-212;
  - the legal notice: WEB-211.
- **WEB-602** rides with WD1's, WD5's and WEB-109's packages.
- **Test lines that change:** `tests/legal.spec.ts:32-35` (date), `:69` and `:93` (Catalan), `:125-135` (deletion wording).

### Cross-slice notes
- **G · WebKit:** every weight renders as Manrope's thinnest on all legal pages (`webkit/*.png` against Chromium), so H1s, the request button and the current-language pill lose weight. This is probably the Windows WebKit port's variable-font support (`src/styles/global.css:3-9`, `format("truetype")`); a real iPhone decides.
- **G · `/es/` and `/ca/` legal pages:** `<html lang="en">` and an English header, phone menu (`privacy-menu.es.mobile.light.fold.png`), skip link and footer (AUDIT §9, §11). That's WEB-304 and WEB-2.
- **G · Legal link previews:** no og:image or og:locale, and twitter:title is the home's English title on every legal page (AUDIT §11). That's WEB-312.
- **G · JavaScript:** the legal pages ship the shared 138 KB of JS (451 KB unzipped) for static text; lab TBT is 125–817 ms (AUDIT §2, lab data). PF-6.
- **G · Footer:** it says "Privacy" where the documents say "Privacy Policy" / «Política de privacidad», and its "Delete account" opens the English page from every language. That's WEB-304 (WP10).
- **G · Text size:** `body { font-size: 15px }` (`global.css:59`) is the site-wide px sizing behind AUDIT §3's "none grew" (WEB-309).
- **F · Home voice FAQ:** it says "TaskFlow transcribes your recording", while by default the app recognises speech on the phone (`regional_provider.dart:20`). It goes with WEB-109.
- **H · The demo's fine print:** besides WEB-207's link, it says nothing about how long anything is kept (PV-3).
- **App:**
  - WD11's Privacy and Terms links aren't in `App/lib/` yet (no `garbar.tech` link). Play's User Data policy requires "a privacy policy link or text within the app itself". When they're added: `/privacy/`, `/es/privacy/`, `/ca/privacy/` and the terms pages, by the app's language.
  - `app_en.arb:1703` still says "Subscriptions are available in the Android and iOS app" (WD7, via /ux).
- **Records:**
  - `Backend/docs/ACCOUNT_DELETION.md:65-67` (items 3–5) are stale.
  - So are `.claude/ux-review/DECISIONS.md:236-247`: the Open list still has the clean-up, re-sign-up, and "the website's delete-account page, which still says the app has no deletion option".
  - The website's `docs/LEGAL_RELEASE.md:3, 28, 36, 38` must follow WEB-601 and WD3's new date.

### Memory notes
- **Site map (legal):**
  - **Routes:** `/privacy/`, `/terms/`, `/legal/` and `/delete-account/` in English (`src/app/<doc>/page.tsx`). `/es/<doc>/` and `/ca/<doc>/` come from `src/app/[language]/[document]/page.tsx`, with `dynamicParams = false` and English slugs.
  - **Rendering:** all four are drawn by `LegalPage.tsx` from `src/content/legal/{en,es,ca}.ts`. The UI strings are `ui` in `index.ts`. Company facts and the version are in `company.json`. Styles are in `legal.css`, which also styles the footer's legal row.
  - **Anchors:**
    - privacy: `#controller #data #purposes #voice #sharing #transfers #retention #website #permissions #rights #age-changes`;
    - terms: `#operator #account #service #content #ai #subscription #withdrawal #ending #responsibility #complaints`;
    - legal notice: `#company #scope #rights`;
    - delete: `#in-app #request #scope #timing #subscription #other-rights`, plus the request box `#request-start-title`.
  - **Page shape:** back link, language pill, eyebrow, slogan H1, description, version line, action links, 3-card summary, then the contents sidebar (mint on phones) and numbered H2 sections. The delete page adds a request box above the summary.
  - **Lengths on a phone:** privacy ≈21.5 screens, terms 13–15, delete ≈9.5, legal notice ≈5.5.
- **Claims map (legal pages → app source):**
  - in-app steps: `en.ts:355`, `index.ts` `requestIntro` → `settings_screen.dart:110`, `account_screen.dart:314-316`, ARB `deleteAccount*`;
  - deletion scope: `en.ts:373-375` → `ACCOUNT_DELETION.md:20-33`;
  - RevenueCat: `en.ts:128, 375` → deleted since 18 Oct (`ACCOUNT_DELETION.md:32`);
  - no confirmation email: `en.ts:382` (UX-813 later);
  - completed tasks: `en.ts:122` (decided none);
  - code lifetimes: `en.ts:126` → `group_views`, `list_views`, `auth_views:265`, `email_verification:20`;
  - noreply: `en.ts:21, 82, 320`;
  - Google name: `en.ts:29` → `GOOGLE_SIGN_IN.md:69`;
  - voice path: `en.ts:55-57` → `regional_provider.dart:20`, `NativeSpeechBridge.kt`, ARB `capturePrivacy`;
  - calendars: `en.ts:155` → ARB `deviceCalendarPrivacy`;
  - names in projects: `en.ts:75` → ARB `createdBy`, D8;
  - demo retention: `en.ts:129, 139-142` → `src/lib/voice/store.ts`, `security.ts`;
  - §8 quotes the demo's button and describes the walkthrough (WD1 and WD5 change both);
  - Apple: `en.ts:84, 248, 397-407`;
  - test purchases: `en.ts:84, 205, 397` → ARB `billingTestMode`.
- **Patterns:**
  - the language pill keeps the document;
  - the deletion request is a mailto with a pre-filled subject and body, with the address and subject shown as a fallback;
  - `tests/legal.spec.ts` asserts exact legal wording, the version date and the deletion button in the first phone screen, so copy changes must update it.
- **Recurring problems:**
  - app and backend changes land without a privacy update (email codes, Google name, «Creada por», RevenueCat deletion);
  - the records (`ACCOUNT_DELETION.md`, the DECISIONS Open list, `docs/LEGAL_RELEASE.md`) fall behind;
  - legal text written for lawyers: jargon, 14 px, ≈140-character lines, px sizes;
  - Catalan verbs drift from the app's «suprimir».
- **Techniques:**
  - compare a text200 render with its 100% render by hash: identical files mean everything is in px;
  - for legal pages, read AUDIT §3, §5, §6, §8, §10 and §11 first;
  - crop full renders with `crop.mjs`;
  - grep the ARB files for every UI name the legal text uses;
  - `git -C ../TaskFlowWeb show HEAD:<file>` shows what the committed page used to promise;
  - the WebKit renders lose font weight, probably a Windows-port artifact, so judge layout there, not type weight.
