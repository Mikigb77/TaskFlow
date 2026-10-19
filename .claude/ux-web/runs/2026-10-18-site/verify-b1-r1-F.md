# Verify — run 2026-10-18-site, round 1, area F (WP17, WP18) — 2026-10-19

**Verdict:** all 10 findings fixed within these packages. Three regressions: one false-by-omission claim in the new account answer (S2), and two cosmetic ones (S1).

**Evidence used:** code (`src/components/HomePage.tsx`, `src/content/site/{en,es,ca}.ts`, `src/styles/global.css`, `tests/website.spec.ts`); the run's own diffs (`ux-web.sh diff`); renders made at 03:33–03:36, after the last source change (03:15), so they're current: `home.en.mobile.light.full.png` screens 4–7, `home.ca.mobile.dark.full.png` screens 7–8, `home.es.desktop.dark.full.png` screen 3, `home.es.desktop.light.full.png` screen 4, `home.ca.desktop-text200.light.full.png` screens 4–5, `home-faq.en.mobile.light.view.png`; `AUDIT.md` §3, §4, §6, §7, §12, §14 (03:38). Renders are Chromium; Safari is a device check.

## Findings

| ID | Result | Evidence |
|---|---|---|
| WEB-101 | fixed | No "Sign in to…", "without an account" or "voice trial" in `#features`, `#questions`, `#get-taskflow` (`en.ts:33-40`, `:59-61`; the voice answer `en.ts:64-66` no longer has the trial sentence). Account answer exact in all three languages (`en.ts:61`, `es.ts` and `ca.ts` items[2]). But see R1F-1: the new answer leaves out the password. |
| WEB-105 | fixed | Voice card "Say several things at once" + body exact, EN/ES/CA (`en.ts:28-32`). Render: `home.en.mobile.light.full.png` s4-5; `home.es.desktop.dark.full.png` s3. |
| WEB-106 | fixed | Calendar card's second sentence on reminders, exact in EN/ES/CA (`en.ts:20`). True: D2 in `.claude/ux-review/DECISIONS.md:163-169`. |
| WEB-504 | fixed | Calendar card's first sentence names "events from your phone’s calendars" in EN/ES/CA (`en.ts:20`). |
| WEB-111 | fixed (features part) | One h2 "What TaskFlow does" and four plain h3s, no eyebrow, no intro (`HomePage.tsx:68-139`; AUDIT §12 home en/es/ca "no problems"). The FAQ's "Glad you asked." belongs to WP19. |
| WEB-4 | fixed | Voice card link and closing button both "Try it with your voice"/"Pruébalo con tu voz"/"Prova-ho amb la teva veu" to `#voice` (`HomePage.tsx:121-123`, `:185-187`; AUDIT §14 rows 12/20 etc.). No "Give it a try", no "Find your flow". Header "Explore the app" is WP20's. |
| WEB-3 | fixed | Closing card: h2 "Coming soon to Android.", the given paragraph, the lime button and WD2's line (`HomePage.tsx:183-188`, `en.ts:85-91`). Text 16 px on phone (`global.css:781-796`), 6.94:1 (AUDIT §7). No `.launch-note`/eyebrow left. Render `home.ca.mobile.dark.full.png` s7-8. |
| WEB-104 | fixed | WD2's line under the button, visible with the FAQ closed; pricing answer second, with WD14's clause exactly as `.claude/ux-web/DECISIONS.md:55-57` gives it (EN/ES/CA). No price, no MB total in `#questions`/`#get-taskflow`. |
| WEB-503 | fixed | `<details>` has no `name` (`HomePage.tsx:161`). Safari "no jump" stays a device check. |
| WEB-308 | fixed | `.closing-card :focus-visible { outline-color: var(--lime) }` (`global.css:797-799`); `--lime` is one value in both themes (`global.css:28`); AUDIT §14: 7.57:1 light and dark. |

## Regressions (only from these changes)

**R1F-1 · Severity 2 · Account answer reads as password-free sign-in**
- Where: `src/content/site/en.ts:61`, `es.ts` and `ca.ts` faq.items[2] (the brief's copy, written verbatim). Page: home, `#questions`, every language.
- The moment: "Email and a code, no password? Easy." Then the app asks for a password of 12–128 characters (`App/lib/l10n/app_en.arb:43` `password{…}`), and only after that for the code.
- What happens: email sign-up in the app is email + password, then a 6-digit code to confirm the address (`Backend/docs/EMAIL_VERIFICATION.md:3`, `:20`; `app_en.arb:724`). The answer says "use your email and a 6-digit code we send you to confirm it" and never mentions the password.
- Why it fails: E lens (every claim true of the app, in its words); FN-3 (prepare people for what the app's first run asks).
- Fix: EN `Yes. You sign in once: tap Continue with Google, or use your email and a password, then type the 6-digit code we email you. Your tasks are kept in your account, so you don’t lose them if you change phones.` / ES `Sí. Inicias sesión una vez: toca Continuar con Google, o usa tu correo y una contraseña, y escribe el código de 6 cifras que te enviamos. Tus tareas se guardan en tu cuenta, así no las pierdes si cambias de móvil.` / CA `Sí. Inicies la sessió una vegada: toca Continua amb Google, o fes servir el teu correu i una contrasenya, i escriu el codi de 6 xifres que t’enviem. Les tasques es desen al teu compte, així no les perds si canvies de mòbil.` (Catalan needs a native read.)
- Verify: the FAQ test pins the new answer in all three languages; it contains "password"/"contraseña"/"contrasenya".
- Evidence: verified in code (site and app).

**R1F-2 · Severity 1 · Desktop voice card is mostly empty**
- Where: `src/components/HomePage.tsx:114-125`; `src/styles/global.css:652-666`. Page: home, desktop (and 801–1100 px), both themes. Render: `home.es.desktop.dark.full.png` screen 3; `home.ca.desktop-text200.light.full.png` screen 4.
- The moment: "Is something missing here?" The lavender card stretches to the calendar card's height (~576 px) with text in its top third and nothing below.
- What happens: the run removed the voice card's decorative mic and orbits (`.voice-illustration`, with its 8 px caption "One less thing to hold in your head."), which no brief asked for; the grid row keeps the calendar card's height.
- Why it fails: N lens (both themes look designed), F lens (visual weight follows content).
- Fix: put back the mic circle and the two orbits only, `aria-hidden="true"`, without the caption, pinned to the card's lower half (the old `.voice-illustration`, `.voice-circle`, `.voice-orbit` rules). Subtract-first alternative: `.feature-calendar, .feature-voice { align-self: start }` would leave an uneven row, so the drawing is the better fix.
- Verify: desktop render, screen 3: the voice card's lower half shows the mic drawing; AUDIT §6 lists nothing in `.feature-voice` under 12 px; §9 reads no caption.
- Evidence: seen in current renders; verified in the diff.

**R1F-3 · Severity 1 · "This week" over fixed dates 21–27**
- Where: `src/components/HomePage.tsx:79-93` (the dates array `["21", …, "27"]` under `features.calendar.header`). Page: home, every language and viewport (decorative, `aria-hidden`).
- The moment: on Monday 19 October, "This week: Mon 21?" — the drawing names a week that isn't this one, almost every week of the year.
- What happens: WP17 replaced "September 2026" with "This week" but kept the September dates, so the drawing now claims the current week starts on the 21st. The conventions ask that sample content be relative to today.
- Why it fails: E lens (nothing untrue, even in a drawing), conventions ("anything date-dependent is relative to today").
- Fix: remove the day numbers (`<strong>{date}</strong>` and its rule), keeping the weekday letters, the dots and the selected first day. Nothing else changes.
- Verify: `#features` contains no `21`…`27`; the drawing still shows seven weekday letters with the first selected.
- Evidence: verified in code; seen in renders.

## Not regressions (noted for the organizer)
- `/es/` and `/ca/`: the FAQ's eyebrow, H2, intro, doodle and items 4–7 are still English inside `lang="es|ca"`; WP19 owns them (`es.ts` comment). The FAQ eyebrow "04 /" now stands alone since "01 /" went; WP19 removes it.
- `h2#features-title` and `h2#closing-title` stay in px and don't grow at 200% text (AUDIT §3); unchanged styling from before this run, already large (45/57 px).
- The voice demo's "3 free tries · no account" badge contradicts WD2's line just below it on the page; the demo is held (WP26–WP29).
- The footer on `/ca/` is English (frame, WP22/WP23).

## Catalan for a native read (organizer's copy in WP17/WP18)
`Ja puc descarregar TaskFlow?`; `Aquesta setmana`; `dl dt dc dj dv ds dg`; `Un bon començament` / `Repassa els plans de la setmana`; `Una estona a l’aire lliure` / `El teu passeig preferit`.
