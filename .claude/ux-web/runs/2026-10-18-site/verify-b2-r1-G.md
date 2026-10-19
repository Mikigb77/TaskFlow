# Verify — run 2026-10-18-site, round 1, area G (WP20–WP23) — 2026-10-19

**Verdict:** all 12 findings are fixed within these packages. Five of them (WEB-2, WEB-4, WEB-309, WEB-313, WEB-703) still have parts in other packages (WP24–WP29), which this check didn't cover. I found three regressions, all Severity 1: the 404 lost its font preload, the language-switch links sit 4 px apart, and at 200% text the desktop header wraps to two rows.

**Evidence used:**
- **Code:** the run's own diffs (`ux-web.sh diff`) of Header, LanguageSwitch, ThemeProvider, Icon, SkipLink, Footer, NotFoundPage, not-found, layout, page metadata, `src/og/preview.tsx`, `src/content/site/*`, `global.css` and `legal.css`.
- **Built HTML:** `.next/server/app/_not-found.html` and `index.html`, built 10:25 local.
- **Renders:** made 11:02 local, after the last source change at 10:05, so they're current.
  - Link previews: `opengraph-image{,.es,.ca}.png`.
  - Phone menu: `home-menu.en.mobile.{light,dark}.fold.png`, `privacy-menu.es.mobile.light.fold.png`.
  - Homes: `home.ca.desktop.light.fold.png`, `home.es.mobile.light.fold.png`, `home.{en,ca}.desktop-text200.light.fold.png`, `home.ca.mobile-text200.light.fold.png`, `home.ca.mobile-w320.light.fold.png`.
  - 404: `not-found.ca.mobile.light.full.png`, `not-found.es.desktop.dark.fold.png`.
  - Footer crops: `crops/privacy.es.desktop.light.full.s8.png`, `crops/home.es.mobile.light.full.s8-9.png`.
- **Measurements:** `AUDIT.md` §1, §2, §3, §5, §6, §8, §9 and §11, and `audit.json` (target rows for the Catalan 404).
- **Missing:** there are no WebKit renders this round (`webkit/INDEX.md` is absent). Safari is a device check.

## Findings

| ID | Result | Evidence |
|---|---|---|
| WEB-4 | fixed (this round's parts) | `Header.tsx`: the filled “Explore the app” button and `.header-cta` / `.button-small` are gone, with no references left in `src/`. The nav is voice, features and questions with the page's prefix (`${home}#voice` …). The footer nav is the same three, and no link points at `#demo` (`Footer.tsx`). Render: `home.ca.desktop.light.fold.png`. Left: WP26 (held). |
| WEB-3 | fixed | The phone menu's last row is `frame.comingSoon` → `${home}#get-taskflow` (`Header.tsx`): “Coming soon to Android” / “Muy pronto en Android”. Renders: `home-menu.en.mobile.light`, `privacy-menu.es.mobile.light`. “Get TaskFlow” is gone from `src/`. |
| WEB-2 | fixed (this round's parts) | **The switch:** `LanguageSwitch.tsx` is plain links with `lang`, `hrefLang` and `aria-current`, an 800 weight and an inset ring, and writes the cookie on click. It appears in the header (desktop), the menu's first row and the footer. **The language:** `layout.tsx` sets `<html lang>` from the path before first paint (AUDIT §11: home es → es, ca → ca, and every legal page matches). Left: WP24 (the legal pill), WP26–WP29 (the demo; its region is still the English “Say it. See it take shape.” on `/es/` and `/ca/`, AUDIT §9). |
| WEB-304 | fixed | **Header and menu:** every string comes from `copy[language].frame` (AUDIT §9: es landmarks are “Navegación principal”, “Idioma”, “Navegación del pie de página” and “Legal y privacidad”). **Skip link:** `SkipLink.tsx` (es “Saltar al contenido”, ca “Salta al contingut”, AUDIT §9). **Footer:** its legal links use `legalPath(…, language)`. The deletion link reads “Suprimeix el compte” on `/ca/` (render `not-found.ca.mobile.light.full.png`). **Theme switch:** its names are in the page's language (`ThemeProvider.tsx`). **Accepted remainder:** without JavaScript, `<html lang>` stays `en` (review G). |
| WEB-307 | fixed | **The button:** the phone header has one 48 px pill, “Menu” / “Menú”, with an SVG icon. **Appearance row:** it has a pressed state with a check and a ring, in the app's words (`app_ca.arb:159-161`, `app_es.arb:180-182`). **Closing:** a tap outside the menu closes it (`pointerdown` handler). **Measured:** AUDIT §5 lists no header control under 44 px except the logo, which is WP25's. **Renders:** light and dark menus; `home.ca.mobile-text200` (the word grows and the menu still fits). |
| WEB-302 | fixed | **Head:** `homeMetadata()` gives the given title, description, og and twitter fields, and `og:locale` with its alternates (AUDIT §11: “none” on the three homes). **Images:** each home's preview has its own URL and alt. The renders show the title line in bold Manrope and the phone with both tasks in each language. **Layout defaults:** they're now `copy.en.meta`; no title anywhere keeps “Make room” or “voice-to-task” (§11). **Legibility:** at 300 px wide the title line is about 16 px and reads well; the task titles shrink to about 5 px, so only their shape reads. That is WD4's layout, so it isn't a finding. |
| WEB-306 | fixed | **Page:** `NotFoundPage.tsx` puts the URL's language first as the h1, with two h2 blocks, each with its own `lang`. **Removed:** the eyebrow, the pun and the ‘↗’. **Head:** title `Page not found · Página no encontrada · No hem trobat la pàgina — TaskFlow`, no canonical and no og:url (AUDIT §11). **Phone:** the first deletion link sits at y = 272–316 on `/ca/` at 390 × 664 (`audit.json`). **axe:** 0 (§1). See R1G-1 for the font. |
| WEB-313 | fixed (this round's part) | **Head:** `viewport.themeColor` holds two media entries. **Theme change:** `apply()` sets every `meta[name=theme-color]`. Left: WP25 (dark without JavaScript). Device check: a dark-mode phone. |
| WEB-311 | fixed | `next/font/local` loads the WOFF2 subset; the TTF preload is gone. AUDIT §2: the home loads one 24 KB font file, LCP 1.46–1.55 s (lab), CLS 0.000. The `global.css` `@font-face` stays until the owner commits `layout.tsx`, as the brief asks. |
| WEB-704 | fixed | The trademark line `footer.trademark` is in all three languages, on every page (render crops above). |
| WEB-703 | fixed (this round's parts) | From `audit.json` (ca 404, mobile): “Torna a dalt” is 97 × 44, the legal links are at least 58 × 44 and 8 px apart, and the footer logo is 48 tall. The name is “Back to top” with the arrow in an `aria-hidden` span. Left: the header logo, 136.7 × 34.5 (WP25). |
| WEB-309 | fixed (this round's parts) | The footer text is `0.875rem` (operator, bottom row, legal row) and its nav `0.875rem`. AUDIT §6 lists no footer element under 12 px. Left: WP25 (body 15 px, eyebrows 10/8 px, still in §6). |

## Regressions (only from these changes)

**R1G-1 · Severity 1 · The 404 lost its font preload**
- **Where:** `src/app/layout.tsx` (the manual TTF preload was removed; `next/font` now preloads per route). The built `.next/server/app/_not-found.html` has no `<link rel="preload" … .woff2>`, while `index.html` has one. Affects the 404 in every language, on phones.
- **The moment:** the Leaver follows a broken link. The page draws in the fallback font, then jumps about a second later, just as they reach for “Eliminar cuenta”.
- **What happens:** AUDIT §2 (lab data). On every 404 the font “arrives 1202–1293 ms after FCP”, with CLS 0.021–0.028 at 2.7–3.0 s from `div.not-found-links`. The LCP of `/es/` is 2.96 s ⚠ (one run; en and ca are 1.95 s). The other pages have the preload and CLS 0.000. Before this run, the layout's TTF preload covered the 404 too.
- **Why it fails:** L lens (no layout shift in the first view); PF-1 (LCP ≤ 2.5 s, here lab only, PF-2).
- **Fix:** give the 404 the same font preload as the other pages. For example, `ReactDOM.preload(url, { as: "font", type: "font/woff2", crossOrigin: "anonymous" })` from `not-found.tsx`, with the subset's built URL, or whatever makes Next emit the font's preload for `_not-found`. Change nothing else.
- **Verify:** `_not-found.html` contains the woff2 preload. AUDIT §2's not-found rows lose “arrives … after FCP” and show CLS 0.000.
- **Evidence:** measured (AUDIT §2, lab); verified in the built HTML.

**R1G-2 · Severity 1 · Language links are 4 px apart**
- **Where:** `src/styles/global.css`, `.language-switch { gap: 4px }`. Affects the header (desktop), the phone menu's first row and the footer, on every page.
- **The moment:** a thumb aiming at “Español” lands on “Català”, and the page changes to a language the visitor doesn't read.
- **What happens:** `audit.json` (footer switch, mobile) shows 80 × 48, 85 × 48 and 75 × 48 boxes with a gap of 4.
- **Why it fails:** CT-6 (8 px between neighbouring targets, Hoober 2017).
- **Fix:** `.language-switch { gap: 8px; }`. The Catalan header still fits at 1025 px: about 32 px spare, measured from `home.ca.desktop.light.fold.png`.
- **Verify:** AUDIT §5 / `audit.json` gives the switch links a gap of 8 or more. The Catalan header test at 801, 1024 and 1100 px still passes.
- **Evidence:** measured (`audit.json`).

**R1G-3 · Severity 1 · At 200% text the desktop header wraps**
- **Where:** `src/styles/global.css`, the phone-menu block `@media (max-width: 1024px)`, with `.header-inner { flex-wrap: wrap }` and the sticky `.site-header`. Affects every page at desktop width with the browser's text at 200%. Renders: `home.en.desktop-text200.light.fold.png`, `home.ca.desktop-text200.light.fold.png`.
- **The moment:** “Where did the page go?” The nav link scrolls “What it does” under the header.
- **What happens:** the nav's text now grows (1rem), so at 1440 px the header wraps. The nav is on row 1, and the switch and theme toggle are on row 2, under the logo. The sticky header is about 130 px tall, more than `scroll-padding-top: 105px`. The anchor overlap is inferred from those sizes, not rendered.
- **Why it fails:** J lens (sticky elements never cover content); K lens (text at 200% without loss).
- **Fix:** write that one breakpoint in em: `@media (max-width: 64em)`. That is 1024 px at default text and 2048 px at 200%, so large-text desktops get the compact Menu button. Nothing else changes.
- **Verify:** `home.*.desktop-text200.light.fold.png` shows the Menu button on one row, and the 100% desktop renders are unchanged.
- **Evidence:** seen in current renders; the anchor overlap is inferred.

## Not regressions (noted for the organizer)
- **“Idioma” twice in the landmarks.** AUDIT §9 flags “navigation “Idioma” appears 2 times” on desktop, where the header and the footer both have the switch. Both lists have identical links, and the WAI-ARIA APG says navigation landmarks with an identical set of links should share the same label (w3.org/WAI/ARIA/apg/patterns/landmarks/examples/navigation.html). This is correct as built.
- **The footer's “Què fa” is 43 × 44 px** (`audit.json`, ca). It's a 1 px miss on the 44 px bar and passes WCAG 2.5.8. Before this run it was much smaller, because the footer nav had no min-height. If the organizer wants it, the fix is `.footer-top nav a { min-width: 44px; justify-content: center; }`.
- **The 404's description and preview are the English home's on `/es/` and `/ca/`** (AUDIT §11). The brief only set the 404's title. A 404 isn't indexed or shared.
- **On the legal pages `twitter:title` is the English home's title** (AUDIT §11). It was the English slogan before, so it isn't new; WP30 owns the legal pages' metadata.
- **The menu panel sits 8 px right of the Menu button's edge at 801–1100 px** (`right: 24px` against a 32 px container margin). Cosmetic; not reported.
- **The Catalan 404 differs between its title and its h1:** the title is “No hem trobat la pàgina”, the h1 “No hem trobat aquesta pàgina”. Both are the brief's copy.

## Catalan for a native read (frame, 404, metadata)
`Navegació principal`, `Prova-ho amb la teva veu`, `Molt aviat a Android`, `Aparença` / `Clar` / `Fosc`, `Canvia al mode fosc` / `Canvia al mode clar`, `Salta al contingut`, `Navegació del peu de pàgina`, `Legal i privacitat`, `Escriu al suport`, `Un producte de {company}`, `Android és una marca comercial de Google LLC.`, `Torna a dalt`, `No hem trobat aquesta pàgina`, `Aquesta adreça no existeix al web de TaskFlow.`, `Ves a l’inici de TaskFlow`, `TaskFlow — Digues-ho i ja és al teu calendari`, `Apunta el que has de fer i TaskFlow ho posa al teu calendari. Digues diverses coses alhora. Per a mòbils Android, molt aviat a Google Play.`, `El calendari de TaskFlow en un mòbil Android, amb «Trucar al dentista» i «Comprar pa» per a demà`.

## Device checks left to the owner
- Android at its largest font size: the menu and the switch.
- A dark-mode Android phone on a throttled network: the toolbar is dark from the first paint.
- TalkBack on `/es/privacy/`: the title is read with a Spanish voice.
- After a deploy: a WhatsApp preview of `/es/` on a Spanish phone.
