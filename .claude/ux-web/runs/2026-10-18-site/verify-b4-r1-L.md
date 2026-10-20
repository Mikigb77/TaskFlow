# Verify — run 2026-10-18-site, batch 4, round 1, area L — 2026-10-19

Scope: WP30 (WEB-203, WEB-205, WEB-212, WEB-213, WEB-211, WEB-312), WP31 (WEB-113, WEB-501, WEB-207, WEB-602, WEB-209, WEB-210), WP32 (WEB-202, WEB-204, WEB-206, WEB-501, WEB-210). All files are held (the other session's untracked files). Evidence: the run's own diff (`ux-web.sh diff`), the renders (00:27–00:28 on 2026-10-20, newer than every changed file: legal.css 23:30, content 23:16), AUDIT.md §1/§3/§11, and the tester's results. No device check.

Result: 15 fixed, 2 partly (WEB-205, WEB-204). 3 regressions (all small).

## WP30

### WEB-203 · fixed
- `src/components/LegalPage.tsx:120-127`: the eyebrow and the rendered description are gone; the h1 is the document's name; `index.ts` `legalMetadata` keeps `description` as meta/og/twitter description.
- H1s in `en.ts:5, 186, 305`, `es.ts`, `ca.ts` are the brief's.
- Render `privacy.es.mobile.light.fold.png`: H1 «Política de privacidad de TaskFlow» ends at about y=315 CSS px (upper half); summary 01 «No vendemos tus datos ni te mostramos anuncios.» fully visible (ends ≈ y=573 of 664).
- Tester: both WEB-203 tests pass.

### WEB-205 · partly
- Done: `legal.css` `.legal-body p, li { font-size: 1rem; line-height: 1.7; max-width: 68ch }`; px → rem across the file; phone link rows padded 12 px; sidebar padding 8 px; `.legal-hero h1 { overflow-wrap; hyphens }`. AUDIT §1: 0 targets under 44 px on every legal phone row, 0 focus not visible; §3 text grows; renders `legal.ca.mobile-text200` show the H1 and body doubling with no sideways scroll.
- Not met: the acceptance's “no line over 80 characters at 1440 px”. In Manrope at 16 px, 68ch holds about 93 characters (tester: 302 blocks over 80, longest 101). Fix: `.legal-body p, .legal-body li { max-width: 58ch; }` (≈ 80 characters), and keep `.legal-summary p` as is.
- Also left: AUDIT §1 “Body < 16 px” = 2 on every legal page (4 on delete): the company card's `dd` values (`.legal-company dd`, and `.legal-mail-details dd` on the delete page) at 0.875rem. The brief didn't ask for these; mention to the organizer, not counted against the package.

### WEB-212 · fixed
- `LegalPage.tsx`: hero ‘Delete account’ uses `arrow` (`:131-133`), related documents `arrow` (`:183`), link lists `arrowUp` only when `href` starts with `http` (`:217-219`); mailto buttons and the hero support link have no icon (`:75-77`, `:135`). `index.ts`: `support` removed; `write` = Email support / Escribir a soporte / Escriu al suport.
- Renders: `privacy.es.mobile.light.fold.png` «Eliminar cuenta →» and «Escribir a soporte» with no arrow; `legal.en.desktop.light.fold.png` the same in English.

### WEB-213 · fixed
- `company.json` version `2026-10-19`; `ui.updated` In force since / En vigor desde el / En vigor des del; `legalVersionDate()` (`index.ts:179-190`) uses `Intl.DateTimeFormat(…, { dateStyle: "long", timeZone: "UTC" })` inside `<time dateTime>`.
- Renders: “In force since 19 October 2026”, «En vigor desde el 19 de octubre de 2026», «En vigor des del 19 d’octubre del 2026». ICU's «del 2026» is correct Catalan usage; the native read can confirm.
- `docs/LEGAL_RELEASE.md:3` now says 19 October 2026.
- See R1L-2 for how the longer line now wraps on phones.

### WEB-211 · fixed
- Summary line 3: `en.ts:311` “Write to us at taskflow@garbar.tech.” and ES/CA equivalents. Registry line from `ui.registration` (`LegalPage.tsx:23`): English and Spanish lines added, Catalan keeps `company.commercialRegister`.
- Render `legal.en.desktop.light.fold.png`: summary 03 reads the new line. The owner still confirms the English and Spanish registry translations at sign-off.

### WEB-312 · fixed
- `index.ts:213-246`: `openGraph` gets type, siteName, locale, alternateLocale and the language's preview image; `twitter` with summary_large_image and the document's own title and description. AUDIT §11 and the tester: all 12 legal pages, no problems.
- Observation (not a regression; the description existed before): the English terms description still says “AI drafts” (`en.ts:144`), and it now also travels as twitter:description into chat previews. Next pass: EN `Terms and Conditions for using TaskFlow, including accounts, shared projects, dictation and subscriptions.` (ES/CA descriptions say «IA»; needs a check).

## WP31

### WEB-113 · fixed (one sentence overstates; see R1L-3)
- §1 automatic emails (`en.ts:21`), §2 Google identity, first name and the 6-digit code (`:29`), §4 speech on the phone (`:55`), §5 “Created by” (`:75`) and Resend (`:82`), §7 “We never delete your tasks on our own” and codes (`:122`, `:126`), §9 phone calendars stay on the phone (`:155`), in all three files.
- Checked against the app: 6-digit code, 30 minutes (`Backend/docs/EMAIL_VERIFICATION.md:3`); first name from Google (`Backend/core/google_auth.py:39-46`); on-device speech exists (`App/lib/services/native_speech.dart`).

### WEB-501 · fixed
- Privacy §7 (`en.ts:128` and ES/CA): “we also ask RevenueCat … to delete its record of you”; delete page §3 first bullet the same. True: `Backend/docs/ACCOUNT_DELETION.md:32` (deleted best-effort once the deletion commits). `docs/LEGAL_RELEASE.md:28, 36` say best-effort, never blocking.

### WEB-207 · fixed
- §8 opens “Live demo: we don’t keep your recording.” / «Demo en directo: no guardamos tu grabación.» / «Demo en directe: no desem la gravació.» (`en.ts:139`, ES/CA). The old 24 h/TTL paragraph is trimmed to quota records (`:141`).

### WEB-602 · fixed
- No walkthrough sentences; the button is “Done” / «Listo» / «Fet», matching `src/content/site/{en,es,ca}.ts` `done`. The language paragraph (`:142`) names taskflow-lang “for up to a year”: true, `src/components/LanguageSwitch.tsx:17` sets Max-Age=31536000; “never your location” is true, `src/proxy.ts:4-10` uses cookie then Accept-Language only. §7's Public demo bullet adds the language preference.

### WEB-209 · fixed
- Every listed term replaced in the three languages (diff checked line by line); tester's word scan passes. Words outside the brief remain in privacy §2/§4 (“drafts”, “allowances”, “transcript”, “AI Studio/Gemini API route”); not part of the acceptance.

### WEB-210 · fixed
- `grep Apple src/content/legal/*.ts`: no match. Privacy §5, terms §6 and delete §5 rewritten; the support.apple.com link removed.

## WP32

### WEB-202 · fixed
- Summary (`en.ts:345-349` and ES/CA) and §3's three bullets, §4's first paragraph and §5 are the brief's plain-word copy. No ‘customer record’, ‘base de datos’, ‘ventana móvil’, ‘Test Store’, ‘staging’ or ‘Apple’ left in #scope/#timing/#subscription. But see R1L-1: the new §4 third paragraph has a missing space in all three languages.

### WEB-204 · partly
- Done: `requestIntro` with the in-app route first, in ink at 1rem (`legal.css` `.legal-request p`), and the new bold line above the button (`LegalPage.tsx:74`, `ui.requestEmail`). At 390 × 664 the button is fully in the first screen in EN, ES and CA (render `delete-account.ca.mobile.light.fold.png`: button ends ≈ y=658).
- Not met: at 320 × 568 the button ends at 682 (EN), 716 (ES), 740 (CA) against 568 (tester; render `delete-account.en.mobile-w320.light.fold.png` ends in the middle of the in-app paragraph). Needs a layout choice; the implementer's options (a)–(c) stand. My recommendation, subtract first: (1) on the delete page, drop the box's h2 «In the app or by email» visually on phones (keep it as the section's accessible name via `aria-labelledby` on a visually-hidden h2), and (2) R1L-2's fix (the company name off the version line), which together save about 75–110 px; with (b) moving the language switch below the box, all three languages fit. That's the organizer's or owner's call.

### WEB-206 · fixed
- `ca.ts`: H1 «Suprimeix el teu compte de TaskFlow.», §3 «Què se suprimeix i què es queda», links «Demanar la supressió del compte», «Suprimir el compte i les dades associades», «supressió de comptes»; `index.ts`: title «Suprimeix el compte», button «Escriu la sol·licitud de supressió», subject «Suprimir el meu compte de TaskFlow», body «Sol·licito la supressió…». Remaining «elimin…» in `ca.ts` (`:122, :124, :125, :132, :393`) are records/exports/content, not the account: allowed by the brief. Render `delete-account.ca.mobile.light.fold.png` shows the H1, the in-app route and the button.

### WEB-210 (delete page) · fixed — see above.

## Regressions

### R1L-1 · Severity 1 · Missing space after a sentence on the delete page
- Where: `src/content/legal/en.ts:384` “Backups expire on their own.Restricted records…”, `es.ts:378` «…caducan solas.Los registros…», `ca.ts:379` «…caduquen soles.Els registres…»; /delete-account/, /es/delete-account/, /ca/delete-account/ §4 (#timing), every viewport and theme.
- The moment: a leaver reading what happens to backups sees “own.Restricted” run together; it reads as careless on the page that has to earn trust.
- Cause: WP32 replaced ‘Recovery copies expire with the provider’s configured rolling backup window.’ and dropped the space.
- Fix: add the space in all three: `Backups expire on their own. Restricted…` / `…caducan solas. Los registros…` / `…caduquen soles. Els registres…`.
- Verify: `grep -nE "[a-zà-ú]\.[A-ZÀ-Ú][a-zà-ú]" src/content/legal/*.ts` returns nothing but S.L. and domains.
- Evidence: verified in code.

### R1L-2 · Severity 1 · The version line wraps with a dangling dot on phones
- Where: `src/components/LegalPage.tsx:121-127` (`.legal-version`, flex-wrap); all 12 legal pages at 390 and 320 px. Renders `privacy.es.mobile.light.fold.png`, `delete-account.ca.mobile.light.fold.png`, `delete-account.en.mobile-w320.light.fold.png`: line 1 “GARBAR, IN-TEC, S.L. ·”, line 2 “In force since 19 October 2026”.
- What happens: the longer WEB-213 text no longer fits beside the company name, so the separator dot hangs at the end of line 1, and the line costs about 25 px more on every phone, which on the delete page pushes the email button further below the 320 × 568 fold (WEB-204).
- Fix (subtract): remove the company name and the dot from this line; the line becomes just “In force since 19 October 2026”. The company is already named in the legal notice, the company card and the footer. If the owner wants it kept, drop only the `·` span and let the two items wrap as separate lines with `column-gap: 0.75em`.
- Verify: at 390 × 664 `.legal-version` is one line in EN, ES and CA; no `·` ends a line.
- Evidence: seen in current renders.

### R1L-3 · Severity 2 · “We don’t keep your surname” isn’t always true
- Where: privacy §2, `src/content/legal/en.ts:29` “We don’t keep your surname or photo.”, `es.ts:29` «No guardamos tus apellidos ni tu foto.», `ca.ts:29` «No desem els cognoms ni la foto.»; /privacy/, /es/privacy/, /ca/privacy/ (#data).
- What happens: `Backend/core/google_auth.py:42-45` stores Google's `given_name`, and when Google sends none it falls back to the full `name` claim, which can contain the surname. The new sentence (added by WP31) promises something the server doesn't guarantee.
- Fix (subtract): EN `We don’t keep your photo.` / ES `No guardamos tu foto.` / CA `No desem la foto.` (keep “your first name, which becomes your TaskFlow name…”). The alternative, making the server keep only the first word of `name`, is app work, not a site fix.
- Verify: the three §2 bullets contain no surname / apellidos / cognoms; the Faithfulness check against `google_auth.py` passes.
- Evidence: verified in code (site and backend).

## Owner checks still open (device / native)
- A native Catalan read of all new Catalan (WP31, WP32), including «del 2026» from Intl.
- English and Spanish registry lines (WEB-211).
- Read the delete summary aloud to someone over 60 (WEB-202).
- Android Chrome's own largest text size on a legal page (WEB-205).
