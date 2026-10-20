# Verify — b4 round 2, area L (WP44) — 2026-10-19

Evidence: this run's diff (`ux-web.sh diff`) of `src/styles/legal.css`, `src/components/LegalPage.tsx`, `src/content/legal/{en,es,ca}.ts`, `tests/legal.spec.ts`, `tests/ux-web-legal.spec.ts`; renders and AUDIT.md of 2026-10-20 02:32–02:35 (newer than every changed file, 01:21–01:29). Tester reported no failures. No npm/Playwright run by me.

## Findings

| ID | Result | Evidence |
|---|---|---|
| WEB-205 | fixed | `legal.css:228` `max-width: 52ch` (the floor the brief allowed; implementer went to 52ch, test renamed at `tests/ux-web-legal.spec.ts:462`, ruler `:477`). `.legal-mail-details dd` and `.legal-company dd` are `1rem` (`legal.css` ~:124, ~:271). AUDIT §1: ‘Body < 16 px’ = 0 on all 12 legal pages, both viewports, both themes; §3: no sideways scroll, no clipped text at w320, text200 (390 and 1440) and zoom200. Render crop `privacy.en.desktop.light.full` screen 2: longest body lines ≈ 73–76 characters (52ch ≈ 71 average in Manrope by the 68ch→93 ratio; the 101-char outlier scales to ≈ 77). Line-length test not failing per tester. |
| WEB-204 | fixed | 320 × 568 renders: button bottom ≈ 498 px EN, 523 ES, 547 CA (`delete-account.{en,es,ca}.mobile-w320.light.fold.png`, 2× scale), all inside 568; in-app line first, bold ‘No app, or can’t sign in? Email us:’ / «¿Sin la app o no puedes entrar? Escríbenos:» / «Sense l’app o no pots entrar? Escriu-nos:» directly above. 390 × 664 dark CA render: same, well inside. h2 hidden on phones via the clip rule (`legal.css` 520 px block) and `.legal-request { position: relative }`; aria snapshot `aria/delete-account.es.mobile.txt`: region “Desde la app o por correo” with heading level 2 kept. Desktop ES render: h2 visible. Language switch moved after the request section (`LegalPage.tsx:157-161`), top row only for the other 9 pages (`:117-119`); navigation “Idioma del documento” sits between the region and the summary in the snapshot. New `@media (max-width: 360px)` block before print. AUDIT §10/§14: keyboard reaches the end, 0 focus issues. |
| WEB-726 | fixed | `LegalPage.tsx:122-127`: `.legal-version` is only `<span>{t.updated} <time>…</time></span>`; `gap`/`flex-wrap` removed (`legal.css` .legal-version). Renders: one line ‘In force since 19 October 2026’ / ‘En vigor desde el 19 de octubre de 2026’ / ‘En vigor des del 19 d’octubre del 2026’ at 320 and 390. `tests/legal.spec.ts:28-31` asserts no GARBAR in the version line and GARBAR in the footer. |
| WEB-727 | fixed | `en.ts:29` ‘We don’t keep your photo.’, `es.ts:29` ‘No guardamos tu foto.’, `ca.ts:29` ‘No desem la foto.’; no surname/apellidos/cognoms left in §2. First-name sentence unchanged. |
| WEB-725 | fixed | `en.ts:384` ‘Backups expire on their own. Restricted…’, `es.ts:378` ‘…caducan solas. Los registros…’, `ca.ts:379` ‘…caduquen soles. Els registres…’. The grep over `src/content/legal/*.ts` now matches only `index.ts:185` `Intl.DateTimeFormat` (code, not copy; same kind as the allowed domain hits); no S.L. hit shows because the pattern needs a lowercase letter after the capital. No copy hits. |

Device checks still open (from the package): real 320 px phone on /es/delete-account/; TalkBack/VoiceOver announcing the hidden heading; Android Chrome at largest text; native Catalan read.

## Regressions

**R2L-1 · S2 · The support address breaks mid-domain on 320 px phones**
- Where: `src/components/LegalPage.tsx` (Contact, the `.legal-mail-details` ‘Send to’ value) with `src/styles/legal.css` `.legal-mail-details dd` (now 1rem, `overflow-wrap: anywhere`); /delete-account/, /es/…, /ca/… at 320 × 568, light and dark. Render: `delete-account.{en,ca}.mobile-w320.light.full.png`, screen 2.
- The moment: the leaver whose mail app didn't open copies the address by hand and reads ‘taskflow.support@garbar.t’ / ‘ech’ — “is it garbar.t? What is ech?”
- What happens: at 16 px the 28-character address is ≈ 234 px against ≈ 214 px of room in the box (request padding 18 + details padding 18), so `overflow-wrap: anywhere` splits it inside `.tech`. At the old 14 px it was ≈ 205 px and fit; the round's 0.875rem → 1rem change caused it. The company card's addresses on /legal/ fit (crop `legal.en.mobile-w320` screen 4).
- Fix: give the address a sensible break point instead of shrinking it: render the value as `taskflow.support<wbr />@garbar.tech` (split the address at ‘@’ in JSX), so it wraps as ‘taskflow.support’ / ‘@garbar.tech’ only when needed; keep 1rem. `<wbr>` adds nothing to copied text.
- Verify: at 320 × 568, the ‘Send to’ dd has no line that starts with anything but ‘taskflow’ or ‘@’ (Range rects per character: no break inside ‘garbar.tech’); copied text equals `taskflow.support@garbar.tech`.
- Evidence: seen in current renders; width arithmetic from the render.

## Notes (not regressions)
- Desktop: the body column is now 52ch (≈ 520 px) while the company card and section rules span ≈ 860 px, leaving a wide empty band right of the prose (`privacy.en.desktop.light.full`). Prescribed by the brief; polish at most.
- Desktop delete page: two language switches in the first viewport (header and the pill under the box). Prescribed by the brief; the top-row one was there before.
- `.legal-company dd` ‘Registered in the Barcelona Mercantile Registry, volume 49105, folio 130, sheet 607875, entry 1’ runs ≈ 95 characters on one line at 1440 px; it's a data value, outside the acceptance's p/li.
