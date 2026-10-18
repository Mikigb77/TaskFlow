## UX web review — L: legal, privacy, terms, delete-account and trust (run 2026-10-18-site) — 2026-10-18

**Verdict:** Ship after fixes. Account deletion works in one step in all three languages and meets Google Play's web-deletion rules. But the privacy policy is behind the app on five points, the phone's first screen of the privacy page gives no privacy facts, and the legal text is small, wide and technical for the Newcomer.

**Walked:**
- **Leaver, from Google Play's deletion link:**
  - English URL: `/delete-account/`, tap «Español», then tap the request button or follow the in-app steps. That's 1 or 2 steps.
  - Spanish URL: 1 step.
- **Leaver, from the home footer:** scroll to the end, tap "Delete account" (opens the English page), then tap «Español». That's 2 steps.
- **Leaver, from privacy, terms or the legal notice:** «Eliminar cuenta» is in the first screen. 1 step, in ES, CA and EN.
- **Leaver, from inside the app:** Ajustes → Cuenta → Eliminar cuenta, then confirm. That's 3 taps plus the confirmation. The app never links to the site.
- **Leaver, from a wrong URL** (`/es/borrar-cuenta/`): the 404 page is in English, then the footer, then the English delete page, then «Español». That's 3 steps.
- **Comparer:** footer → Privacy → summary → §3, to learn "we don't sell your data". That's on phone screen ≈6 in Spanish.
- **Trust:** footer → Legal Notice → company details. Support is reached by mailto from the footer and from every legal page.
- **Demo visitor:** "How we use your data" → `/privacy/#voice`.
- **Assistive-technology user:** heading outline, landmarks, `lang`, the switcher's current state, focus. 320 px and 200% text were checked in code.
- **Evidence used:**
  - 96 legal-page renders (4 pages × 3 languages × desktop and phone × light and dark × fold and full) plus the 8 renders of the 404 page. All were made at 19:24 today, after the last code change (15–16 Oct).
  - 320 px, 200% text and no JavaScript were checked from the code. No JavaScript is also covered by `tests/legal.spec.ts`.
  - `GUIDELINES.md` was present and used.

**Numbers:**
- **Delete page, first phone screen (ES):** ≈57 words and 1 filled button (the email request). The in-app steps are visible. Scrolls to the first call to action: 0.
- **Privacy page, first phone screen (ES):** ≈35 words and 0 privacy facts. The first summary card starts at y≈622 of 664.

| Page | Phone screens | Words EN / ES / CA |
|---|---|---|
| Privacy | 21.5–21.7 | 2,396 / 2,367 / 2,207 |
| Terms | 13.1–15.0 | 1,551 / 1,335 / 1,151 |
| Delete account | 9.3–9.6 | 756 / 812 / 795 |
| Legal notice | 5.3–5.6 | 269 / 250 / 231 |

- **Desktop line length of the legal body text:** ≈120–140 characters (target ≤ 75).
- **Steps to account deletion:**
  - from privacy, terms or the legal notice: 1;
  - from the home page or the 404 page: 1, in the footer, after scrolling to the end; it opens the English page;
  - from Play: 0, plus 1 to change language if the URL is the English one;
  - from the app: 3 taps plus the confirmation;
  - by email: 1 tap, then typing the account's email, then Send.
- **Claims checked:** 35. False: 0. Outdated or incomplete: 7. Misleading by implication: 1. Unverifiable: 3.

**Attention** (predicted from the renders, not measured; GUIDELINES §21 step 4):

| Render | 1st fixation | 2nd | 3rd | What competes or gets missed |
|---|---|---|---|---|
| `delete-account.es.mobile.light.fold.png` | H1 «Elimina tu cuenta de TaskFlow.» (upper half) | Filled button «Escribir solicitud de eliminación» (y≈570–623, bottom third, but isolated and filled) | Box heading «Desde la app o por correo» | The language pill and the logo compete. The in-app steps are 14 px grey text (y≈515–540) and probably not among the first three (WEB-204). |
| `delete-account.es.desktop.light.fold.png` | H1 (top left) | Two identical filled buttons: the header's English «Explore the app» (top right) and the request button (centre right) | Box heading | The in-app steps (14 px grey, y≈633) have low salience. |
| `delete-account.ca.mobile.dark.fold.png` | Same pattern | | | One screen uses «Eliminar compte», «Elimina…», «Suprimeix el compte» and «sol·licitud d'eliminació» (WEB-206). |
| `privacy.es.mobile.light.fold.png` | Slogan H1 «Tu privacidad, con claridad.» | Large grey description that restates the title | Underlined links «Eliminar cuenta ↗ · Soporte y privacidad ↗» | No privacy fact is among the first three; the summary sits at the bottom edge (WEB-203). |
| `privacy.en.desktop.light.fold.png` | H1 | Header «Explore the app» | The three summary cards (inside the fold) | The cards are generic. |
| `terms.es.mobile.light.fold.png`, `legal.ca.mobile.dark.fold.png` | Same template as privacy: slogan H1, description, links | | | Summary at the bottom edge. |

Confirming this with 5 or 6 sessions with older people is still advised (FN-7).

### Findings (most severe first)

**WEB-201 · Severity 2 · Privacy policy is behind the app on five points**
- **Where:** privacy, all three languages, desktop and phone, both themes; render `privacy.es.mobile.light.full.png`, screens 4–14.

  | Section | `en.ts` | `es.ts` | `ca.ts` |
  |---|---|---|---|
  | §1, sender of automatic emails | 21 | 21 | 21 |
  | §2, Google sign-in data | 29 | 29 | 29 |
  | §4, how voice is sent | 55 | 55 | 55 |
  | §5, shared projects | 75 | 75 | 75 |
  | §5, Resend | 82 | 82 | 82 |
  | §7, code lifetimes | 126 | 126 | 126 |
  | §9, phone calendars | 155 | 149 | 149 |

- **The moment:**
  - "I got an email from noreply@… with a 6-digit code. The privacy page never mentions it."
  - "The page says my recordings go to the cloud, but the app said my voice is turned into text on the phone."
- **What happens:**
  1. **Email confirmation codes.** These codes (6 digits, 30 minutes, sent from noreply) aren't listed:
     - not among the automatic emails (§1);
     - not in Resend's role (§5);
     - not among the code lifetimes (§7).

     Sources: `Backend/docs/EMAIL_VERIFICATION.md:3,56,67`, `Backend/core/email_verification.py:20`.
  2. **Google sign-in.** Google sign-in now keeps Google's first name as the account's name (`Backend/docs/GOOGLE_SIGN_IN.md:69`). §2 only says "such as your Google account identifier, email and verification status".
  3. **Voice.** §4 says "Recordings are sent for cloud transcription when you submit a capture".
     - The app first uses the phone's own on-device recogniser: `App/android/app/src/main/kotlin/com/example/agenda/NativeSpeechBridge.kt:71,203`.
     - When it does, no audio leaves the phone, as the app itself says (`App/lib/l10n/app_en.arb:422`).
     - So the policy says more is sent than actually is, and leaves out a reassuring fact.
  4. **Phone calendars.** §9 talks about "calendar entries you choose to turn into TaskFlow content". The app promises that events "stay on this device; they are not uploaded or sent to AI" (`App/lib/l10n/app_en.arb:146`), and the policy never says so.
  5. **«Creada por».** Shared projects now show your name on the tasks you create («Creada por») and can filter by person (`.claude/ux-review/DECISIONS.md`, 2026-10-18 later, points 4 and 6). §5 doesn't say that other members see your name.
- **Why it fails:**
  - FN-1: every claim is true today (UCPD art. 6; Play Metadata).
  - PV-1: plain, complete information (GDPR art. 12; WP260).
  - FN-2: the app's own words.
- **Fix:** the copy below. It changes text the owner approved on 16 Oct (see Questions 8).

  **EN**
  - **§1:** "Automated invitations and recovery messages come from…" → "Automatic emails (invitations, email confirmation codes and password recovery) come from taskflow.noreply@garbar.tech…"
  - **§2:** replace "With Google sign-in, we receive identity information such as your Google account identifier, email and verification status." with "With Google sign-in, we receive your Google account identifier, email, whether Google has verified it, and your first name, which becomes your TaskFlow name if you haven't set one. We don't keep your surname or photo. Password sign-ups confirm their email with a 6-digit code that expires after 30 minutes."
  - **§4:** replace "Recordings are sent for cloud transcription when you submit a capture; typed AI input is also sent when you request interpretation." with "When your phone can recognise speech on the device, your voice becomes text on the phone and no audio leaves it; only the words are sent to become tasks. Otherwise the recording is sent to be transcribed online when you submit it. With Pro, words you type for the AI are sent the same way; the manual task form never sends anything to the AI."
  - **§5:** after the first sentence, add "Members of a shared project see your name on the tasks you create there ("Created by") and can filter tasks by person." Also change "invitation and recovery emails" to "invitation, email-confirmation and recovery emails".
  - **§7:** "…invitation codes expire after seven days, and email-confirmation and recovery codes after 30 minutes."
  - **§9:** replace the calendar sentence with "Events from your phone's calendars are shown read-only and stay on the phone: they're never uploaded or sent to the AI."

  **ES**
  - **§1:** «Los correos automáticos (invitaciones, códigos para confirmar el correo y recuperación de la contraseña) se envían desde taskflow.noreply@garbar.tech…»
  - **§2:** «Si entras con Google, recibimos tu identificador de Google, tu correo, si Google lo ha verificado y tu nombre de pila, que pasa a ser tu nombre en TaskFlow si no tienes otro. No guardamos tus apellidos ni tu foto. Si te registras con contraseña, confirmas tu correo con un código de 6 cifras que caduca a los 30 minutos.»
  - **§4:** «Si tu teléfono puede reconocer la voz por sí mismo, tu voz se convierte en texto en el propio teléfono y el audio no sale de él; solo se envían las palabras para crear las tareas. Si no puede, la grabación se envía para transcribirla en línea al enviar la captura. Con Pro, lo que escribes para la IA se envía igual; el formulario manual de tareas nunca envía nada a la IA.»
  - **§5:** add «Los miembros de un proyecto compartido ven tu nombre en las tareas que creas en él («Creada por») y pueden filtrar las tareas por persona.» Resend: «correos de invitación, de confirmación del correo y de recuperación».
  - **§7:** «…los códigos de invitación caducan a los siete días, y los de confirmación del correo y de recuperación, a los 30 minutos.»
  - **§9:** «Los eventos de los calendarios del teléfono se muestran solo para consulta y se quedan en el teléfono: no se suben ni se envían a la IA.»

  **CA**
  - **§1:** «Els correus automàtics (invitacions, codis per confirmar el correu i recuperació de la contrasenya) s'envien des de taskflow.noreply@garbar.tech…»
  - **§2:** «Si entres amb Google, rebem l'identificador de Google, el correu, si Google l'ha verificat i el teu nom de pila, que passa a ser el teu nom a TaskFlow si no en tens cap altre. No desem els cognoms ni la foto. Si et registres amb contrasenya, confirmes el correu amb un codi de 6 xifres que caduca als 30 minuts.»
  - **§4:** «Si el telèfon pot reconèixer la veu pel seu compte, la veu es converteix en text al mateix telèfon i l'àudio no en surt; només s'envien les paraules per crear les tasques. Si no pot, la gravació s'envia per transcriure-la en línia en enviar la captura. Amb Pro, el que escrius per a la IA s'envia igual; el formulari manual de tasques no envia mai res a la IA.»
  - **§5:** add «Els membres d'un projecte compartit veuen el teu nom a les tasques que hi crees («Creada per») i poden filtrar les tasques per persona.» Resend: «correus d'invitació, de confirmació del correu i de recuperació».
  - **§7:** «…els codis d'invitació caduquen als set dies, i els de confirmació del correu i de recuperació, als 30 minuts.»
  - **§9:** «Els esdeveniments dels calendaris del telèfon es mostren només per consultar-los i es queden al telèfon: no es pugen ni s'envien a la IA.»

- **Verify:** Playwright text assertions on `/privacy/`, `/es/privacy/` and `/ca/privacy/`:
  - `#controller`, `#sharing` and `#retention` mention confirmation codes;
  - `#data` mentions the first name;
  - `#voice` no longer contains "Recordings are sent for cloud transcription when you submit a capture";
  - `#permissions` says calendar events stay on the phone.
- **Evidence:** verified in code, in both repos.

**WEB-202 · Severity 2 · Delete page explains what goes in jargon, not the app's words**
- **Where:** delete account, all three languages; render `delete-account.es.mobile.light.full.png`, screens 2 and 5–7.

  | Part | `en.ts` | `es.ts` | `ca.ts` |
  |---|---|---|---|
  | Summary | 345–349 | 339–343 | 340–344 |
  | §3 | 373–375 | 367–369 | 368–370 |
  | §4 | 382 | 376 | 377 |
  | §5 | 397 | 391 | 392 |

- **The moment:** "¿Qué pasa con mis tareas? «registros de archivos personales en la nube… cliente de RevenueCat… ventana móvil configurada del proveedor»… no entiendo nada."
- **What happens:**
  - The first summary line repeats the in-app steps instead of saying what gets deleted.
  - The three §3 bullets run 50–70 words each, in database and provider terms («cambio en la base de datos», «atribución de actividad», «cliente de RevenueCat»).
  - §5 says «compras actuales de Test Store en staging».
  - The app says the same thing in two plain lines:
    - «Se eliminarán tu cuenta de TaskFlow y tus tareas, notas y archivos en todos tus dispositivos.» (`App/lib/l10n/app_es.arb:1207`)
    - «N tareas que añadiste a proyectos compartidos, sin tu nombre» (`app_es.arb:1214`)
- **Why it fails:**
  - PV-7: Play asks for a clear statement of what's deleted and what's kept (Play Deletion).
  - FN-2: the app's names.
  - HE-10, RD-3: plain words, COGA.
  - OL-2: never imply fault; the person is upset.
- **Fix:** replace the plain-language lead and keep the legal limits. `docs/LEGAL_RELEASE.md:28` forbids an "all erased instantly" promise, so the "what you wrote inside doesn't change" clause stays.
  - **Summary**
    - EN: "Deleted: your account and your tasks, notes and files." / "Stays for the others: what you added to shared projects, without your name." / "Deleting your account doesn't cancel TaskFlow Pro on Google Play."
    - ES: «Se borran tu cuenta y tus tareas, notas y archivos.» / «Se queda para los demás lo que añadiste a proyectos compartidos, sin tu nombre.» / «Eliminar la cuenta no cancela TaskFlow Pro en Google Play.»
    - CA: «Se suprimeixen el compte i les teves tasques, notes i fitxers.» / «Es queda per als altres el que vas afegir a projectes compartits, sense el teu nom.» / «Suprimir el compte no cancel·la TaskFlow Pro a Google Play.»
  - **§3, English**
    1. "Deleted, on all your devices: your account, your tasks, notes and files, and projects only you use. That includes your sign-in, Google link, sessions, project and group memberships, notification settings and your count of free dictations."
    2. "Stays for the others: tasks and files you added to shared projects. Your name is removed from them, but what you wrote inside them doesn't change. Projects and groups you own pass to another member; the app tells you who before you confirm. Ask support about personal details inside shared content."
    3. "Not deleted by the app: your purchase history with Google Play and with RevenueCat (the company that checks subscriptions for us), your emails with support, security logs, and backups, which expire on their own. Ask support to delete what can be deleted; we'll tell you what must be kept, why and for how long. We can't delete copies other people saved."
  - **§3, Spanish**
    1. «Se borra, en todos tus dispositivos: tu cuenta, tus tareas, notas y archivos y los proyectos que solo usas tú. También tu acceso, el vínculo con Google, las sesiones, tu pertenencia a proyectos y grupos, tus ajustes de avisos y tu recuento de dictados gratis.»
    2. «Se queda para los demás: las tareas y archivos que añadiste a proyectos compartidos. Se quita tu nombre, pero lo que escribiste en ellos no cambia. Los proyectos y grupos que son tuyos pasan a otro miembro; la app te dice a quién antes de confirmar. Si dentro hay datos personales tuyos, escribe a soporte.»
    3. «La app no borra: tu historial de compras en Google Play y en RevenueCat (la empresa que comprueba las suscripciones por nosotros), tus correos con soporte, los registros de seguridad ni las copias de seguridad, que caducan solas. Pide a soporte que borre lo que se pueda; te diremos qué hay que conservar, por qué y cuánto tiempo. No podemos borrar las copias que hayan guardado otras personas.»
  - **§3, Catalan**
    1. «Se suprimeix, a tots els dispositius: el compte, les teves tasques, notes i fitxers i els projectes que només fas servir tu. També l'accés, el vincle amb Google, les sessions, la pertinença a projectes i grups, les preferències d'avisos i el recompte de dictats gratuïts.»
    2. «Es queda per als altres: les tasques i els fitxers que vas afegir a projectes compartits. Se'n treu el teu nom, però el que hi vas escriure no canvia. Els projectes i grups que són teus passen a un altre membre; l'app et diu a qui abans de confirmar. Si a dins hi ha dades personals teves, escriu a suport.»
    3. «L'app no suprimeix: l'historial de compres a Google Play i a RevenueCat (l'empresa que comprova les subscripcions per nosaltres), els correus amb suport, els registres de seguretat ni les còpies de seguretat, que caduquen soles. Demana a suport que suprimeixi el que es pugui; et direm què s'ha de conservar, per què i durant quant de temps. No podem suprimir les còpies que hagin desat altres persones.»
  - **§4, first paragraph**
    - EN: "In the app, your account is deleted as soon as you confirm, and its files right after (if one can't be removed then, we follow it up). You see the confirmation in the app; no email is sent. If the app shows an error, don't assume it worked: try again or write to support."
    - ES: «En la app, tu cuenta se elimina en cuanto confirmas, y sus archivos justo después (si alguno no se puede borrar en ese momento, nos ocupamos después). Ves la confirmación en la app; no se envía ningún correo. Si la app muestra un error, no lo des por hecho: vuelve a intentarlo o escribe a soporte.»
    - CA: «A l'app, el compte se suprimeix tan bon punt confirmes, i els fitxers just després (si algun no es pot suprimir en aquell moment, ens n'ocupem després). Veus la confirmació a l'app; no s'envia cap correu. Si l'app mostra un error, no ho donis per fet: torna-ho a provar o escriu a suport.»
  - **§5, the last sentence of the first paragraph**, in the app's words (`app_en.arb:1684`):
    - EN: "While TaskFlow is being tested, there are test purchases only and no real payment is taken."
    - ES: «Mientras TaskFlow está en pruebas, solo hay compras de prueba y no se realiza ningún cobro real.»
    - CA: «Mentre TaskFlow és en proves, només hi ha compres de prova i no es fa cap cobrament real.»
  - Update the text assertions at `tests/legal.spec.ts:130-135`.
- **Verify:**
  - Playwright, on the delete page in each language:
    - the summary contains "tasks, notes and files" / «tareas, notas y archivos» / «tasques, notes i fitxers»;
    - none of "RevenueCat customer record", «base de datos», «Test Store», «staging», «ventana móvil», «finestra mòbil» appear in `#scope`, `#timing` or `#subscription`.
  - Read the summary aloud to someone over 60.
- **Evidence:** verified in code; seen in current renders.

**WEB-203 · Severity 2 · The privacy page's first screen has no privacy facts**
- **Where:**
  - `src/components/LegalPage.tsx:128-130` (eyebrow, H1, description);
  - `src/content/legal/en.ts:5-12`, `es.ts:5-12`, `ca.ts:5-12`;
  - the same template on terms (`en.ts:190`) and the legal notice (`en.ts:305`);
  - `src/styles/global.css:121-126` (the eyebrow is 10 px);
  - renders `privacy.es.mobile.light.fold.png`, `terms.es.mobile.light.fold.png`.
- **The moment:** "«Tu privacidad, con claridad.» … vale, pero ¿qué hacéis con mis datos?" They scroll, find three general lines, and give up before §3.
- **What happens:**
  - On a phone, about 600 of the 664 px go to:
    - the header and the language switcher;
    - a 10 px eyebrow, the only place the page names itself;
    - a slogan H1;
    - a description that restates the title.
  - The summary's first card starts at y≈622, in the bottom third.
  - The summary is general ("Your content is used to provide TaskFlow").
  - The fact that matters most to someone wary of giving data away, "We do not sell personal data… or use task content to target advertisements" (`en.ts:48`), is on phone screen ≈6.
- **Why it fails:**
  - PV-1: layered, plain summary first (GDPR art. 12; WP260).
  - AT-2: the top half of a phone screen gets ≈70% of gaze (Lagun 2014).
  - HE-3, SC-4: clear beats clever; front-load the words that matter.
  - RD-5: small print is at least 12 px.
  - Play User Data policy: "clear labeling as a privacy policy".
- **Fix:** subtract first.
  1. **The H1 names the document.**
     - Privacy: "TaskFlow Privacy Policy" / «Política de privacidad de TaskFlow» / «Política de privacitat de TaskFlow».
     - Terms: "TaskFlow Terms and Conditions" / «Términos y condiciones de TaskFlow» / «Termes i condicions de TaskFlow».
     - Legal notice: "Legal notice: the company behind TaskFlow" / «Aviso legal: la empresa detrás de TaskFlow» / «Avís legal: l'empresa darrere de TaskFlow».

     Then remove the eyebrow (`LegalPage.tsx:128`). The delete page's H1 stays as it is.
  2. **Stop rendering the description** (`LegalPage.tsx:130`) on the four pages. Keep it as the meta description in `legalMetadata`.
  3. **Privacy summary:**
     - EN: "We don't sell your data or show you ads." / "Your words go to Google's AI only when you ask TaskFlow to turn them into tasks." / "You can get a copy of your data or delete it whenever you want."
     - ES: «No vendemos tus datos ni te mostramos anuncios.» / «Tus palabras solo van a la IA de Google cuando pides a TaskFlow que las convierta en tareas.» / «Puedes pedir una copia de tus datos o eliminarlos cuando quieras.»
     - CA: «No venem les teves dades ni et mostrem anuncis.» / «Les teves paraules només van a la IA de Google quan demanes a TaskFlow que les converteixi en tasques.» / «Pots demanar una còpia de les teves dades o suprimir-les quan vulguis.»
- **Verify:**
  - Playwright, on phone, for privacy in each language: `.legal-summary li:first-child` is fully in the viewport, and the H1 text equals the document name.
  - On the new render, the first summary line sits above y = 664.
- **Evidence:** seen in current renders; verified in code.

**WEB-204 · Severity 2 · Delete page: the quicker in-app route looks like small print**
- **Where:**
  - `src/content/legal/index.ts:46-48`, `89-91`, `132-134` (`requestTitle`, `requestIntro`);
  - `src/components/LegalPage.tsx:150-161` and `70-73`;
  - `src/styles/legal.css:94-99`;
  - renders `delete-account.es.mobile.light.fold.png` and `delete-account.es.desktop.light.fold.png`.
- **The moment:** "Me dice que escriba un correo y espere hasta un mes… ¿no lo puedo hacer yo desde el móvil?"
- **What happens:**
  - The only button is the email request, which can take up to a month.
  - The in-app route is immediate and shows a preview of what goes. Yet it's a 14 px grey line ("Ajustes → Cuenta → Eliminar cuenta. También puedes escribirnos aquí.") that predicted attention skips.
  - Nothing tells people which route is meant for whom.
- **Why it fails:**
  - CT-11: one obvious step, plus one alternative that says when to use it.
  - PV-7: the steps are prominent.
  - SC-4, RD-5.
- **Fix:**
  1. Stop rendering the hero description on this page (`LegalPage.tsx:130`). The box heading «Desde la app o por correo» already says it.
  2. `requestIntro`, in ink at 16 px (`legal.css:94-99`):
     - EN: "With the app: Settings → Account → Delete account. You'll see what goes before you confirm."
     - ES: «Con la app: Ajustes → Cuenta → Eliminar cuenta. Verás qué se borra antes de confirmar.»
     - CA: «Amb l'app: Configuració → Compte → Suprimeix el compte. Veuràs què se suprimeix abans de confirmar.»
  3. Directly above the email button (`LegalPage.tsx:70`), one line that replaces "You can also email us below":
     - EN: "No app, or can't sign in? Email us:"
     - ES: «¿Sin la app o no puedes entrar? Escríbenos:»
     - CA: «Sense l'app o no pots entrar? Escriu-nos:»

  The email button must stay fully inside the first phone screen. Play wants a request route that doesn't need the app, and `tests/legal.spec.ts:206-209` already checks this.
- **Verify:**
  - That test passes for ES and CA as well as the Catalan page it covers today.
  - On the new phone fold render, the in-app line is ink-coloured at 16 px.
  - Walkthrough: the Leaver who still has the app reads the steps without tapping the button.
- **Evidence:** seen in current renders. The attention ranking is a prediction, not a measurement.

**WEB-205 · Severity 2 · Legal text is small print, in lines of ≈130 characters on desktop**
- **Where:** `src/styles/legal.css`:

  | Lines | What | Today |
  |---|---|---|
  | 217-223 | Body text | 14 px, no max-width |
  | 171-177 | Contents links | 12 px |
  | 188-194 | Related documents | 12 px |
  | 94-99 | Request box text | 14 px |
  | 113-117, 254-258 | Labels | 12 px and 11 px |
  | 49-56 | Version line | 12 px |
  | 155-162 | Sidebar | scroll container with 2 px padding |

  Renders `privacy.en.desktop.light.full.png` screen 2, and `delete-account.es.desktop.light.full.png` screens 2–3.
- **The moment:** "Letra pequeña y gris, y renglones que cruzan toda la pantalla… lo dejo."
- **What happens:**
  - Body text is grey, 14 px, with a 1.95 line height.
  - At 1440 px the lines run ≈120–140 characters; «Abre Ajustes → Cuenta → … que se» is ≈130.
  - On phones, the contents links are 12 px in rows of ≈39 px.
  - The privacy page is 21.5 phone screens of this.
  - Contrast passes (grey text 5.48:1 light, 8.86:1 dark). The problem is size and line length.
- **Why it fails:**
  - RD-4: 50–75 characters a line (Baymard; WCAG 1.4.8).
  - RD-5: body text at least 16 px for the Newcomer.
  - CT-6: 44 px rows.
  - OL-1: older users are slower and make more errors (Nielsen 2013).
- **Fix:**
  - `.legal-body p, .legal-body li`: 16 px, `line-height: 1.7`, `max-width: 68ch`.
  - `.legal-request p`: 16 px.
  - `.legal-toc a` and `.legal-related a`: 14 px; on phones, `padding-block: 12px`, so rows are at least 44 px.
  - `dt` labels and `.legal-version`: 13 px.
  - `.legal-sidebar`: padding 8 px, so its scroll container doesn't clip the 3 px focus ring, which has a 5 px offset. This last part is inferred.
- **Verify:**
  - Computed `font-size` of `.legal-body p` is at least 16 px.
  - At 1440 px, no `.legal-body` line passes 80 characters (Range rects).
  - Contents rows are at least 44 px tall at 390 px.
  - Tab into the sidebar in both themes and screenshot the ring.
- **Evidence:** verified in code; seen in renders. The focus clipping needs a browser check.

**WEB-206 · Severity 2 · Catalan pages use three verbs for one action; the app says «Suprimeix el compte»**
- **Where:**
  - `src/content/legal/index.ts:140`, `145`, `150`, `156`;
  - `ca.ts:21`, `164`, `269`, `314`, `337`, `393`;
  - the eyebrow, H1, hero link, sidebar and `<title>` on every `/ca/` page;
  - render `delete-account.ca.mobile.dark.fold.png`.
- **The moment:** "A la web posa «Eliminar compte»; a l'app no ho trobo… ah, es diu «Suprimeix el compte»."
- **What happens:**
  - One screen shows «Eliminar compte» (eyebrow), «Elimina el teu compte» (H1), «Suprimeix el compte» (description and steps) and «Escriure sol·licitud d'eliminació» (button).
  - The app always says «Suprimeix el compte», «Suprimeix el meu compte» and «S'ha suprimit el compte» (`App/lib/l10n/app_ca.arb:909,930,944`).
  - Spanish and English already match the app.
- **Why it fails:** FN-2 (the app's names); ML-6; lens G (one concept, one name).
- **Fix:**

  | Where | Today | Becomes |
  |---|---|---|
  | `index.ts:156`, title | «Eliminar compte» | «Suprimeix el compte» |
  | `ca.ts:337`, H1 | «Elimina el teu compte de TaskFlow.» | «Suprimeix el teu compte de TaskFlow.» |
  | `index.ts:145`, button | «Escriure sol·licitud d'eliminació» | «Escriu la sol·licitud de supressió» |
  | `index.ts:150`, email subject | «Eliminar el meu compte de TaskFlow» | «Suprimir el meu compte de TaskFlow» |
  | `index.ts:140`, email body | «Sol·licito l'eliminació…» | «Sol·licito la supressió…» |
  | `ca.ts:164`, privacy link | «Demanar l'eliminació del compte» | «Demanar la supressió del compte» |
  | `ca.ts:269`, terms link | «Eliminar el compte i les dades associades» | «Suprimir el compte i les dades associades» |
  | `ca.ts:21` and `:314` | «eliminació de comptes» | «supressió de comptes» |
  | `ca.ts:393` | «Eliminar TaskFlow no elimina el compte de Google» | «El compte de Google no se suprimeix» (`app_ca.arb:927`) |

  Update `tests/legal.spec.ts:69` and `:93`. Catalan: confident, but a native read would help.
- **Verify:** on `/ca/delete-account/`, the H1, eyebrow or title, button, related link and subject all use «Suprimeix», «Suprimir» or «supressió». No «Elimin…» remains in those.
- **Evidence:** verified in code; seen in the render.

**WEB-207 · Severity 2 · The demo's "How we use your data" link lands on the app's section**
- **Where:**
  - `src/components/VoiceDemo.tsx:393-397`, the link to `/privacy/#voice`. This is H's file, and the other session has uncommitted edits in it.
  - `src/content/legal/en.ts:53-58` and `137-143`, and the same lines in `es.ts` and `ca.ts`.
- **The moment:** "I'm about to record in the demo. Will they keep my voice?" The section opens with "The mobile app can retain unfinished recordings… Recordings are sent for cloud transcription".
- **What happens:**
  - §4 (`#voice`) is about the app. The demo's facts are in §8 (`#website`), four sections further down.
  - Nowhere does the page say the demo doesn't keep the recording.
    - The committed page used to say "We do not store recordings." (`git -C ../TaskFlowWeb show HEAD:src/app/privacy/page.tsx`).
    - The server stores only the sealed text result, for 24 hours (`src/lib/voice/store.ts:118-123`).
- **Why it fails:**
  - CT-4: the destination keeps the label's promise.
  - RD-7.
  - PV-3: the note before recording says how long things are kept.
- **Fix:**
  1. The link goes to `/privacy/#website`.
  2. §8 opens with the demo's facts:
     - EN: "Live demo: we don't keep your recording. The text and drafts are kept encrypted for up to 24 hours, so a retry doesn't use another try, and are then deleted automatically."
     - ES: «Demo en vivo: no guardamos tu grabación. El texto y los borradores se guardan cifrados hasta 24 horas, para que reintentar no gaste otro intento, y después se borran automáticamente.»
     - CA: «Demo en viu: no desem la gravació. El text i els esborranys es desen xifrats fins a 24 hores, perquè tornar-ho a provar no gasti un altre intent, i després s'esborren automàticament.»
- **Verify:** Playwright: clicking "How we use your data" lands on a URL ending `/privacy/#website`, with `#website-title` in the viewport. §8's first sentence contains "we don't keep your recording" / «no guardamos tu grabación» / «no desem la gravació».
- **Evidence:** verified in code.

**WEB-208 · Severity 2 · Language switcher: current language shown by colour only; overflows with large text**
- **Where:**
  - `src/styles/legal.css:12-30`: no `flex-wrap`; the current language is a mint pill with green text;
  - `legal.css:35-41`: the H1 has no `overflow-wrap`;
  - `src/components/LegalPage.tsx:113-125`;
  - every legal page, on phones; render `delete-account.es.mobile.light.fold.png`.
- **The moment:**
  - A low-vision visitor: "¿En qué idioma estoy?"
  - A visitor with large text: «Català» goes off the edge and the page slides sideways.
- **What happens:**
  - **State by colour only.**
    - The mint pill is 1.12:1 against the page (1.43:1 dark).
    - The selected text is green on ink at 2.03:1 (1.44:1 dark).
    - Both are below 3:1, so colour is the only cue.
  - **Overflow with large text.** The switcher is a row that can't wrap.
    - At normal text it's ≈259 px wide, which fits 320 px.
    - At 200% text it needs ≈410 px, wider than a 390 px phone.
  - **Long words in the H1.** Words such as «privacidad,» and «Condiciones» at the 37 px minimum can't break either.
- **Why it fails:**
  - AX-2: WCAG 1.4.11 (a state indicator needs 3:1) and 1.4.1 (colour alone).
  - AX-3, OL-1: the Newcomer reads larger text.
  - ML-7.
- **Fix:**
  - `.legal-languages`: `flex-wrap: wrap; max-width: 100%`.
  - `.legal-languages a[aria-current]`: `box-shadow: inset 0 0 0 2px var(--green); font-weight: 800`. Green is 5.76:1 on the light page and 10.47:1 on the dark one.
  - `.legal-hero h1`: `overflow-wrap: break-word; hyphens: auto`. The article carries `lang`, so hyphenation follows the page's language.
- **Verify:**
  - Computed style of `a[aria-current]` has the 2 px ring in both themes.
  - Playwright at 390 px, with a style that doubles the font size of `.legal-utility` and `.legal-hero h1`: `scrollWidth ≤ innerWidth` on ES and CA privacy and delete pages.
  - Device check: Android at the largest font size, in Chrome.
- **Evidence:** contrast computed from the tokens (`src/styles/global.css:16-50`). The overflow is inferred from the code and needs a device or browser check.

**WEB-209 · Severity 2 · Privacy, terms and legal notice use engineering words**
- **Where:** `en.ts:30`, `56`, `80`, `84`, `140`, `141`, `156`, `205`, `328`; `es.ts:56`, `80`, `84`, `140`, `141`, `199`, `322`; `ca.ts:56`, `80`, `84`, `140`, `141`, `199`, `322`. Render `privacy.en.desktop.dark.full.png` screen 5.
- **The moment:** "«hashes con clave», «borrado TTL asíncrono», «APK», «Test Store», «SDK», «punto de acceso global»… esto no está escrito para mí."
- **What happens:** the detailed layer uses build and ops terms the Newcomer can't read. This is despite the H1 promising "clearly explained".
- **Why it fails:**
  - PV-1: GDPR art. 12 asks for "clear and plain language"; WP260 says avoid technical terms.
  - HE-10: NN/g on tech terms; Kane 2019.
  - RD-3.
- **Fix:** replace these terms in the three languages. Keep the providers' names; they're the recipients the law requires the policy to name.

  | Today | EN | ES | CA |
  |---|---|---|---|
  | "Test Store purchases… renew/expire faster" (`en.ts:205`, `es.ts:199`, `ca.ts:199`) | "Test purchases only: no real payment is taken, and test subscriptions can renew or end sooner than real ones." | «Solo compras de prueba: no se cobra nada, y las suscripciones de prueba pueden renovarse o terminar antes que las reales.» | «Només compres de prova: no es cobra res, i les subscripcions de prova poden renovar-se o acabar abans que les reals.» |
  | "private staging test" (`en.ts:205`) | "private test version" | already plain | already plain |
  | "public APK download" (`en.ts:328`, `es.ts:322`, `ca.ts:322`) | "public app download" | «…ni ofrece la app para descargar» | «…ni ofereix l'app per descarregar» |
  | "eligible for database TTL deletion, which is asynchronous" (`:141`) | "then it's deleted automatically" | «Después se borran automáticamente.» | «Després s'esborra automàticament.» |
  | "keyed hashes of network addresses; hashing does not make those records anonymous" (`:140`) | "a coded form of your network address, which still counts as personal data" | «una forma codificada de tu dirección de red, que sigue siendo un dato personal» | «una forma codificada de la teva adreça de xarxa, que continua sent una dada personal» |
  | "Processing can use a global endpoint" (`:56`) | "Google can process it outside the EU" | «Google puede procesarlo fuera de la UE» | «Google ho pot processar fora de la UE» |
  | "related SDK data" (`:84`) | "data from its component in the app" | «datos de su componente en la app» | «dades del seu component a l'app» |
  | "PostgreSQL account/content data" (`:80`) | "the database of accounts and content" | «la base de datos de cuentas y contenido» | «la base de dades de comptes i contingut» |
  | "our backend" (`en.ts:30`, `:156`) | "our servers" | already «servidor» | already «servidor» |

- **Verify:** Playwright text search across the nine `/privacy/`, `/terms/` and `/legal/` pages: none of "Test Store", "staging", "APK", "TTL", "hash", "endpoint", "SDK", "PostgreSQL" or "backend", nor their ES and CA forms.
- **Evidence:** verified in code.

**WEB-210 · Severity 1 · Apple subscriptions mentioned on an Android-only product**
- **Where:** `en.ts:84`, `248`, `397`, `398`, `405-408`; `es.ts:84`, `242`, `391`, `392`, `399-402`; `ca.ts:84`, `242`, `392`, `393`, `400-403`.
- **The moment:** "¿Hay versión para iPhone?"
- **What happens:**
  - The delete page links to "Manage Apple subscriptions" and says deleting doesn't delete "your Google or Apple account".
  - The terms and privacy pages mention Apple payments.
  - TaskFlow is an Android app (CLAUDE.md). There's no iOS build and no App Store listing. The app itself names only Google Play (`app_en.arb:2132`).
- **Why it fails:** FN-1; AP-7 (say "Android only" plainly); subtract first.
- **Fix:**
  - **Delete page §5:**
    - "…a Google Play or Apple subscription" → "Deleting your account doesn't cancel TaskFlow Pro on Google Play." / «Eliminar tu cuenta no cancela TaskFlow Pro en Google Play.» / «Suprimir el compte no cancel·la TaskFlow Pro a Google Play.»
    - "…your Google or Apple account" → "Your Google account isn't deleted." / «Tu cuenta de Google no se elimina.» / «El compte de Google no se suprimeix.»
    - Remove the Apple link.
  - **Privacy §5:** "Google Play or Apple handles…" → "Google Play handles payments…" / «Google Play tramita los pagos…» / «Google Play tramita els pagaments…»
  - **Terms §6:** "an Apple/Google subscription in the store account" → "it in the Google Play account you used to buy it" / «Gestiónala en la cuenta de Google Play con la que la compraste» / «Gestiona-la al compte de Google Play amb què la vas comprar».
  - Bring Apple back if an iPhone version ever ships.
- **Verify:** no "Apple" in the visible text of the 12 legal pages.
- **Evidence:** verified in code.

**WEB-211 · Severity 1 · Legal notice: a placeholder-sounding line, a mislabelled button, and the registry in Catalan only**
- **Where:**
  - `en.ts:311`, `es.ts:305`, `ca.ts:305`;
  - `index.ts:58`, `101`, `144` (`write`);
  - `src/components/LegalPage.tsx:63-91`;
  - `src/content/legal/company.json:5`;
  - render `legal.en.mobile.light.full.png`, screens 2–4.
- **The moment:**
  - "«Company and contact information belongs here.» Is this page finished?"
  - "«Contact TaskFlow»… which address is that?"
  - On the English page: "«Societat inscrita… Tom… Foli… Full… Inscripció»?"
- **What happens:**
  - The third summary line reads like a note to self.
  - The "Contact TaskFlow" button writes to support, while the paragraph above it gives taskflow@garbar.tech for general questions.
  - The registry line is Catalan on the English and Spanish pages, with no `lang` on it.
- **Why it fails:**
  - TR-3: errors are trust bugs.
  - RD-7, CT-3: labels say what happens.
  - ML-5; WCAG 3.1.2 (AA), a passage in another language must be marked.
- **Fix:**
  - **Summary line 3:** "Write to us at taskflow@garbar.tech." / «Escríbenos a taskflow@garbar.tech.» / «Escriu-nos a taskflow@garbar.tech.»
  - **`write` label:** "Email support" / «Escribir a soporte» / «Escriu a suport». The address shown under the button stays.
  - **Registry line, per language:**
    - EN: "Registered in the Barcelona Mercantile Registry, volume 49105, folio 130, sheet 607875, entry 1".
    - ES: «Inscrita en el Registro Mercantil de Barcelona, tomo 49105, folio 130, hoja 607875, inscripción 1».
    - CA: unchanged.

    If the owner prefers the registry's own wording everywhere, wrap it in `lang="ca"` instead.
- **Verify:** the rendered text on `/legal/` and `/es/legal/`; axe passes. The owner confirms the registry translation.
- **Evidence:** verified in code; seen in the render.

**WEB-212 · Severity 1 · Internal links carry the "leaves the site" arrow; the support link opens email without saying so**
- **Where:** `src/components/LegalPage.tsx:72`, `139`, `143-144`, `189`, `222-226`; `index.ts:45`, `88`, `131` (`support`); renders `privacy.es.mobile.light.fold.png` and `delete-account.es.mobile.light.full.png` screen 3.
- **The moment:**
  - "«Eliminar cuenta ↗»: ¿me saca de la web?"
  - "«Soporte y privacidad» me ha abierto el correo."
- **What happens:** the same ↗ marks three different things:
  - pages on this site: «Eliminar cuenta», every «Documentos legales» link, the `#rights` links;
  - other websites: Neon, the AEPD;
  - mailto buttons.

  «Soporte y privacidad» opens an email draft and says nothing about it.
- **Why it fails:** RD-7 (links say where they go); NV-8 (familiar patterns).
- **Fix:**
  - Use the plain → (`Icon name="arrow"`) for pages on this site.
  - Keep ↗ only for `http(s)` links to other websites.
  - No arrow on mailto buttons.
  - `support` label: "Email support" / «Escribir a soporte» / «Escriu a suport». Same wording as WEB-211's `write`, so the two can share one string.
- **Verify:** every `a[href^="/"]` inside `.legal-page` uses the → icon; every `a[href^="http"]` uses ↗; mailto links have no arrow.
- **Evidence:** verified in code; seen in renders.

**WEB-213 · Severity 1 · "Versión 2026-10-16" doesn't read as "in force since"**
- **Where:** `src/content/legal/index.ts:35`, `78`, `121` (`updated`); `src/components/LegalPage.tsx:131-134`; every legal page.
- **The moment:** "¿Versión 2026-10-16? ¿Es la buena?"
- **What happens:** a technical label and an ISO date sit where people expect "last updated" or "in force since". `docs/LEGAL_RELEASE.md:3` calls it the effective date.
- **Why it fails:** RD-3, ML-6.
- **Fix:**
  - "In force since 16 October 2026" / «En vigor desde el 16 de octubre de 2026» / «En vigor des del 16 d'octubre de 2026».
  - Format the date with `Intl.DateTimeFormat(language, { dateStyle: "long" })`.
  - Keep `<time dateTime="2026-10-16">`, which `tests/legal.spec.ts:32-35` checks.
- **Verify:** the rendered text in the three languages.
- **Evidence:** verified in code.

### Claims checked

Lines are the English file; Spanish and Catalan are at the same or nearby lines.

| # | Claim (page, `path:line`) | Source of truth (`path:line`) | Status |
|---|---|---|---|
| 1 | Delete in the app: Settings → Account → Delete account, with each language's names (delete, `en.ts:355`; `index.ts:47-48,90-91,133-134`) | `App/lib/screens/settings_screen.dart:108-116`; `account_screen.dart:310-319`; `app_es.arb:129,974,1205`; `app_ca.arb:108,754,909` | True on `dev`. Not true in testers' APK 1.0.5 (12 Oct) or on staging (Questions 7). |
| 2 | The screen identifies the account, counts what goes, shows what stays and who receives it (`en.ts:355`) | `delete_account_screen.dart:385-399`; `app_en.arb:2046-2128`; `Backend/docs/ACCOUNT_DELETION.md:34-41` | True |
| 3 | Save a copy first; files not included (`en.ts:355`, `269`) | `app_en.arb:2136,2144` | True |
| 4 | Confirm with password or Google; needs a connection; opening deletes nothing; a changed plan is shown again; signed out; can't be undone (`en.ts:356`) | `ACCOUNT_DELETION.md:43-59`; `app_en.arb:2148-2235` | True |
| 5 | What's deleted: profile, Google link, sessions, personal tasks, notes and files, private spaces, memberships, notification settings, usage records (`en.ts:373`) | `ACCOUNT_DELETION.md:20-25` | True |
| 6 | Shared content kept, with handovers; assignments and attribution removed (`en.ts:374`, `124`) | `ACCOUNT_DELETION.md:23-28` | True |
| 7 | The RevenueCat customer and store history aren't deleted by the app (`en.ts:375`, `128`) | `ACCOUNT_DELETION.md:32,63` | True; open decision |
| 8 | No automatic confirmation email (`en.ts:382`) | `ACCOUNT_DELETION.md:12,62`; CLAUDE.md, Email ("next") | True; changes when the email ships |
| 9 | Other devices lose access and clear their copy (`en.ts:125`, `398`) | `App/lib/services/api_client.dart:470-482`; `ACCOUNT_DELETION.md:52` | True |
| 10 | Deleting doesn't cancel a Google Play subscription (`en.ts:397`) | `app_en.arb:2132` | True |
| 11 | "…or Apple subscription", "Manage Apple subscriptions", "Google or Apple account" (`en.ts:84,248,397-408`) | CLAUDE.md (Android); `App/docs/REVENUECAT_SETUP.md:16` (iOS not built) | Misleading by implication (WEB-210) |
| 12 | Completed tasks aren't erased after 30 or 90 days (`en.ts:122`) | `ACCOUNT_DELETION.md:64`; DECISIONS, Open | True today; open decision (Questions 1) |
| 13 | Invitation codes expire after 7 days (`en.ts:126`) | `Backend/core/group_views.py:148`; `list_views.py:167` | True |
| 14 | Recovery codes expire after 30 minutes (`en.ts:126`) | `Backend/core/auth_views.py:247` | True |
| 15 | Email confirmation codes, 6 digits, 30 minutes (not mentioned) | `Backend/docs/EMAIL_VERIFICATION.md:3,56`; `Backend/core/email_verification.py:20` | Missing (WEB-201) |
| 16 | Invitation and recovery emails come from noreply, replies go to support (`en.ts:21`, `82`) | CLAUDE.md, Email | True but incomplete (WEB-201) |
| 17 | Google sign-in gives the identifier, email and verification status (`en.ts:29`) | `Backend/docs/GOOGLE_SIGN_IN.md:69` (first name kept) | Outdated (WEB-201) |
| 18 | "Recordings are sent for cloud transcription when you submit" (`en.ts:55`) | `NativeSpeechBridge.kt:71,203`; `app_en.arb:422` | Outdated: speech is recognised on the phone first (WEB-201) |
| 19 | "Calendar entries you choose to turn into TaskFlow content may then be synchronised" (`en.ts:155`) | `app_en.arb:146` | Incomplete: leaves out "stay on this device" (WEB-201) |
| 20 | Shared content is available to authorised members (`en.ts:75`) | DECISIONS 2026-10-18 later, points 4 and 6 | True; leaves out that your name shows on your tasks (WEB-201) |
| 21 | The AI gets language, time zone, reference date and project and member names (`en.ts:33`) | `Backend/docs/VOICE_COMMANDS.md:7,229` (the model never sees tasks) | True |
| 22 | Usage counts are kept to apply allowances (`en.ts:33`) | `.claude/ux-review/free-tier-plan.md`; `ACCOUNT_DELETION.md:20` | True |
| 23 | AI Studio / Gemini API route with a Vertex fallback; the demo uses Vertex (`en.ts:56`) | DECISIONS, UX-616 | True |
| 24 | Manual task entry instead of AI (`en.ts:58`) | DECISIONS 2026-10-18 later (the form) | True |
| 25 | The demo sends audio or text only on "Create drafts" (`en.ts:139`) | `src/components/VoiceDemo.tsx:263-286,594` | True |
| 26 | Turnstile loads after the demo is opened (`en.ts:140`) | `VoiceDemo.tsx:36-94` | True |
| 27 | Demo cookie 30 days, results 24 hours, quota 48 hours (`en.ts:129,140-141`) | `src/lib/voice/security.ts:66`; `store.ts:115,122` | True |
| 28 | The demo doesn't keep recordings (not stated; the committed page said so) | `src/lib/voice/store.ts:118-123` | Missing (WEB-207) |
| 29 | The theme is kept in local storage; no ad cookies or marketing analytics (`en.ts:142`) | `src/components/ThemeProvider.tsx:64`; `src/app/layout.tsx:39-53` | True; analytics is an open question |
| 30 | Neon in Frankfurt for staging (`en.ts:80`) | `Backend/docs/STAGING.md:84-86` | True |
| 31 | Staging uses test purchases at no charge (`en.ts:84,205,397`) | `REVENUECAT_SETUP.md:3`; `app_en.arb:1684` | True |
| 32 | No public download or checkout (`en.ts:205,328`) | Play not published (`.claude/ux-web/DECISIONS.md`) | True |
| 33 | Backups expire with the provider's rolling window (`en.ts:132,384`) | `STAGING.md:258-259` (restore untested; no window recorded) | Unverifiable (Questions 2) |
| 34 | Cloud Run logs kept 30 days (`en.ts:127`) | `docs/LEGAL_RELEASE.md:38` (hosting, out of scope) | Unverifiable |
| 35 | Over 18 only (`en.ts:183,214`) | `company.json:9`; the app asks no age | Unverifiable (policy) |
| — | The brief, `ACCOUNT_DELETION.md:66` and the app's DECISIONS Open list say the delete page still says there's no in-app option | `en.ts:353-357`, `es.ts:347-351`, `ca.ts:348-352` now describe in-app deletion | The records are stale, not the page |

### Missing from the site (app features worth telling)
- **"We don't sell your data or show ads"** (`en.ts:48`). It reassures the visitor who's wary of giving data away. The home page's FAQ or demo area is where it belongs. That's H's and F's page and new content, so it's the owner's call.
- **Speech recognised on the phone** (`App/lib/l10n/app_en.arb:422`; `NativeSpeechBridge.kt:71,203`). It goes in the privacy summary and §4 (WEB-201), and in the home page's voice FAQ.
- **Phone calendars never leave the phone** (`app_en.arb:146`). It goes in privacy §9 (WEB-201).
- **Delete your account in the app, with a preview of what goes** (`app_en.arb:2034-2128`). It goes in the home FAQ "Do I need an account?". That's F's area and the owner's call.

### Keep
- **The delete page meets Play's web-deletion rules in all three languages:**
  - TaskFlow and GARBAR, IN-TEC, S.L. are named;
  - both routes, and a working pre-filled email request, are in the first phone screen;
  - it says what's deleted and what's kept;
  - nobody needs to reinstall the app, give a reason or pay;
  - the subscription caveat is there.
- **Honest limits and no dark patterns:** no "everything erased instantly"; RevenueCat, backups and shared content are stated; there's no guilt or retention trick on the Leaver's path.
- **The in-app steps use the app's exact names in each language:** Ajustes → Cuenta → Eliminar cuenta; Configuració → Compte → Suprimeix el compte; Settings → Account → Delete account.
- **The pages are built well:** static pages that work without JavaScript; a print style; a language switcher that keeps the document; translated titles and descriptions; `hreflang` and canonical links once `SITE_URL` is set.
- **Contrast passes in both themes:** grey text 5.48:1 light and 8.86:1 dark; green links 5.76:1 and 10.47:1. Dark mode looks designed.

### Questions for the owner (product decisions only)
1. **Clean-up of completed tasks (open).** Privacy §7 (`en.ts:122`) says completed tasks aren't erased after 30 or 90 days.
   - Whichever option you choose, the privacy and delete pages change with it.
   - If you choose "none", a plainer line would be "We never delete your tasks, done or not, unless you do."
2. **How long do backups keep deleted data?**
   - The privacy page (`en.ts:132`) and delete page (`en.ts:384`) promise only "the provider's rolling window".
   - No number is recorded, and `Backend/docs/STAGING.md:258-259` lists backup and restore as untested.
   - Play asks you to "clearly inform users about your data retention practices". Give the window so both pages can say "Backups are deleted within N days."
3. **Free dictations after signing up again (open).** If you keep a hashed email to stop this, the privacy and delete pages must say so.
4. **Deleting the RevenueCat customer (open).** If you adopt it, delete §3 and privacy §7 change.
5. **Which deletion URL goes into Play Console?** Play takes one URL.
   - `/es/delete-account/` suits a mostly Spanish audience, and the page's switcher covers the other two languages.
   - The package ID must change first (open).
6. **The app has no link to the privacy policy.**
   - Play's User Data policy requires "a privacy policy link or text within the app".
   - The sign-up screen also shows no terms, though Terms §1 (`en.ts:206`) says terms must be available before an account is created.
   - This is an app change, in `frontend-ux-reviewer`'s lane. A grep of `App/lib/` finds no link to the website.
7. **Release order.**
   - The delete page's in-app steps are true only on `dev`. Testers' APK 1.0.5 (`App/docs/IMPLEMENTATION_STATUS.md:75`) and staging both predate account deletion.
   - Publish the legal pages together with, or after, an app and backend that have it.
8. **Editing the approved text.**
   - WEB-201–203, 206 and 209–213 change wording in the documents you approved for 16 Oct (`company.json`, `publicationApproved`). WEB-207 changes the privacy text too, and its link is in `VoiceDemo.tsx`.
   - Should the loop edit them and update `company.version`, or should they go through your legal review?
   - All of these files are the other session's untracked work, so the fixes stay uncommitted for you. WEB-205 and WEB-208 change only `legal.css`, also untracked.
9. **Which Gemini tier serves the app's dictations: a paid key or the free quota?** (legal check)
   - Privacy §4 (`en.ts:57`) hedges: "unpaid services… can involve model improvement and human review".
   - If the paid or EEA terms apply, the page can say plainly "Google doesn't use your dictations to train its models."
10. **Analytics (open).** Privacy §8 says there are none; it must change with any decision.

### Cross-slice notes
- **G: Spanish and Catalan pages in English chrome.** `<html lang="en">` on `/es/` and `/ca/` legal pages (`src/app/layout.tsx:43`). The header, skip link and footer stay English. The footer's legal links always open English pages (`src/components/Footer.tsx:26-32`), so a Spanish Leaver who taps "Delete account" on `/es/privacy/` lands on the English page.
- **G: two filled buttons on desktop.** The header's English "Explore the app" (`src/components/Header.tsx:48`) competes with the delete page's request button.
- **G: English 404 everywhere.** The 404 page under `/es/` and `/ca/` is English, with an English home link (`src/app/not-found.tsx`).
- **G: legal pages' link previews.** `legalMetadata`'s `openGraph` (`src/content/legal/index.ts:190-194`) replaces the root one. Check `siteName`, `og:locale` and the preview image when `/es/` or `/ca/` pages are shared.
- **G: small text site-wide.** The eyebrow is 10 px (`src/styles/global.css:121-126`) and the footer's legal links 12 px (`src/styles/legal.css:308-315`).
- **H: the demo's privacy note.** The fine print (`src/components/VoiceDemo.tsx:393-397`) doesn't say how long anything is kept (PV-3), and its link target is covered by WEB-207.
- **H: the back link.** «Volver a TaskFlow» on `/es/` and `/ca/` pages goes to the English home (`src/components/LegalPage.tsx:110`). Point it to the translated home once one exists.
- **H/G: invitation emails link to the English home.** Invitation emails in ES and CA link people without an account to the English home (`Backend/docs/VOICE_COMMANDS.md:345`).
- **F and H: the home FAQ contradicts the app and the legal pages.**
  - "You can create tasks… without an account" (`src/app/page.tsx:20`) vs the login wall.
  - "Launch pricing has not been announced" (`page.tsx:32`) vs 10 free dictations a month and TaskFlow Pro.
  - "viewers can read them" (`page.tsx:24`) vs everyone joining as an editor (D15b).
- **App:** see Questions 6. The app links to none of the site's pages.
- **Records:** `Backend/docs/ACCOUNT_DELETION.md:66` and `.claude/ux-review/DECISIONS.md` (Open, "Also for later") are out of date. The site's delete page already describes in-app deletion.

### Memory notes
- **Site map (legal):**
  - **Routes:** `/privacy/`, `/terms/`, `/legal/` and `/delete-account/` in English (`src/app/<doc>/page.tsx`). `/es/<doc>/` and `/ca/<doc>/` come from `src/app/[language]/[document]/page.tsx`, with `dynamicParams = false` and English slugs.
  - **Rendering:** all four are drawn by `LegalPage.tsx` from `src/content/legal/{en,es,ca}.ts`. The UI strings are `ui` in `index.ts`. Company facts, the version (2026-10-16) and `publicationApproved` are in `company.json`. Styles are in `legal.css`, which also styles the footer's legal row.
  - **Anchors:**
    - privacy: `#controller #data #purposes #voice #sharing #transfers #retention #website #permissions #rights #age-changes`;
    - terms: `#operator #account #service #content #ai #subscription #withdrawal #ending #responsibility #complaints`;
    - legal notice: `#company #scope #rights`;
    - delete: `#in-app #request #scope #timing #subscription #other-rights`.
  - **Page shape:** eyebrow, slogan H1, description, version line, action links, 3-card summary, then the contents sidebar and numbered H2 sections. The delete page adds a request box near the top.
  - **Lengths on a phone:** privacy ≈21.5 screens, terms 13–15, delete page ≈9.5.
- **Claims map (legal pages → app source):**
  - in-app steps: `en.ts:355`, `index.ts` `requestIntro` → `settings_screen.dart`, `account_screen.dart`, ARB `deleteAccount*`;
  - deletion scope: `en.ts:373-375` → `ACCOUNT_DELETION.md`;
  - no confirmation email: `en.ts:382`; changes when the deletion email ships;
  - RevenueCat: `en.ts:128,375`;
  - completed-task clean-up: `en.ts:122`, open decision;
  - code lifetimes: `en.ts:126` → `group_views`, `list_views`, `auth_views`, `email_verification`;
  - noreply and Reply-To: `en.ts:21,82,320`;
  - Google sign-in data: `en.ts:29` → `GOOGLE_SIGN_IN.md:69`;
  - voice path: `en.ts:55-57` → `NativeSpeechBridge.kt`, ARB `capturePrivacy`;
  - demo retention: `en.ts:129,139-142` → `src/lib/voice/store.ts`, `security.ts`;
  - ES and CA §8 name the English button "Create drafts" (`es.ts:139`, `ca.ts:139`); this changes if the demo is translated;
  - Apple: `en.ts:84,248,397-408`;
  - test purchases: `en.ts:84,205,397`.
- **Patterns:**
  - the language switcher keeps the document;
  - the deletion request is a mailto with a pre-filled subject and body, and the address and subject are shown as a fallback;
  - `tests/legal.spec.ts` asserts exact legal wording and keeps the deletion button in the first phone screen. Copy changes must update it.
- **Recurring problems:**
  - the records (`ACCOUNT_DELETION.md`, the DECISIONS Open list, the brief) fall behind the site;
  - app features ship without a privacy update (email confirmation, Google name, «Creada por»);
  - the legal text is written for lawyers: jargon, 14 px, ≈130-character lines;
  - Catalan verbs drift from the app's «suprimir».
- **Techniques:**
  - grep the ARB files for every UI name the legal text uses;
  - `git -C ../TaskFlowWeb show HEAD:<file>` shows what the committed page used to promise;
  - compute contrast from the `global.css` tokens;
  - read desktop line length from the full renders;
  - the legal content, `LegalPage.tsx` and `legal.css` are the other session's untracked files, so fixes stay uncommitted.
