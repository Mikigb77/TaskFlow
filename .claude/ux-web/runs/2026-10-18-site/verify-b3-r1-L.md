# Verify — run 2026-10-18-site, batch b3, round 1, area L — 2026-10-19

Scope: WP24 (WEB-2, WEB-208). Changed files read through `ux-web.sh diff`: `src/components/LegalPage.tsx`, `src/styles/legal.css`, `src/app/sitemap.ts`, `src/components/Icon.tsx`; plus `LanguageSwitch.tsx`, `src/content/site/index.ts` (`homePath`, `localisePath`) and `global.css:319-345` (`.language-switch`), which the change now uses. Renders and AUDIT.md are from 19:51–19:56, after the last code change (13:17): current evidence.

## Results

**WEB-2 (WP24 part) — fixed.**
- Back link: `LegalPage.tsx:110` now `href={homePath(language)}` → `/`, `/es/`, `/ca/` (`src/content/site/index.ts:26-28`); the `←` glyph is now `<Icon name="back">`, which is `aria-hidden="true"` (`Icon.tsx`, the svg). Seen in `privacy.es.mobile.light.fold.png` («Volver a TaskFlow» with an icon arrow) and `privacy.ca.desktop.dark.fold.png` («Tornar a TaskFlow»).
- The pill is now `LanguageSwitch` (`LegalPage.tsx:113`), whose links go to the same document in each language (`localisePath`, `translatedPages` includes all four documents) and write `taskflow-lang` on click (`LanguageSwitch.tsx:15-18, 43`). Tester: Català on /privacy/ → /ca/privacy/, cookie set, `/` then 307 → /ca/.
- Sitemap: `/es/` and `/ca/` added after `/`, the `publicationReady` logic kept (`sitemap.ts:14-16`).
- WEB-2's other parts (WP26–WP29, the demo) belong to other packages and aren't judged here.

**WEB-208 — fixed.**
- Current language: `aria-current="page"` (`LanguageSwitch.tsx:42`), `font-weight: 800`, `color: var(--ink)` and a 2 px inset `--green` ring (`global.css:341-345`, specificity 0,2,1, so it beats `.legal-languages a`'s 650 at 0,1,1); the mint fill stays as a second cue (`legal.css:27-29`). The old `color: var(--green)` override is gone.
- AUDIT §8: Fail 0, Weak boundary 0 (the pill's 1.12:1 / 1.43:1 rows are gone). AUDIT §7: Fail 0. AUDIT §4: no axe violations on any page. AUDIT §5: the switch's links aren't in the under-44 list (min-height 48 from `.language-switch a`).
- Wrap: `flex-wrap: wrap` and a 29 px radius (`legal.css:13-19`). `delete-account.ca.mobile-text200.light.fold.png`: Català wraps to a second row inside a rounded box, nothing cut. `privacy.ca.mobile-w320.light.fold.png`: one row, fits. AUDIT §3: no legal page scrolls sideways in text200, zoom200 or w320.
- Seen in light and dark: ring clear on mint (`privacy.es.mobile.light.fold.png`) and on the dark surface (`privacy.ca.desktop.dark.fold.png`).

## Regressions

**R1L-1 · Severity 1 · Back arrow no longer grows with the text**
- Where: `src/components/LegalPage.tsx:111` (`<Icon name="back" size={16} />`), all 12 legal pages; `delete-account.ca.mobile-text200.light.fold.png`.
- What happens: the old `←` glyph was text and doubled with the browser's font size; the icon is a fixed 16 px, so at text200 a 16 px arrow sits before 32 px «Tornar a TaskFlow», 15 px away (`.inline-link` gap). The label still carries the meaning, so it's cosmetic.
- Fix: size the icon with the text, e.g. `.legal-utility .inline-link svg { width: 1em; height: 1em; }` in `legal.css` (and, optionally, a smaller gap there, 0.5em).
- Verify: in `….mobile-text200.light.fold.png` the arrow is about as tall as the label's capitals.
- Evidence: seen in a current render; verified in code.

## Observations (not regressions, not caused by this run)
- On desktop, every legal page now shows two identical language switches about 120 px apart: the header's (WP20) and the legal pill (`privacy.ca.desktop.dark.fold.png`). WP24 made them look the same; the duplication came with WP20. On phones the header's switch is inside the menu, so the pill is the only visible one there and should stay. Subtract-first option for a later round: hide `.legal-languages` above the header's phone breakpoint (800 px). Screen readers already tell them apart («Idioma» vs «Idioma del documento», AUDIT §9).
- Without JavaScript the switch's links work but don't write the cookie (`onClick`); that's WP20's design, not this run's.
