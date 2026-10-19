# Verify — run 2026-10-18-site, round 2, area L — 2026-10-19

Scope: WP41 (WEB-714). Changed file: `src/styles/legal.css` (held, the other session's untracked file).

## WEB-714 · fixed

- Code: `src/styles/legal.css:12-15` adds `.legal-utility .inline-link svg { width: 1em; height: 1em; }` right after `.legal-utility` (`:4-11`), as briefed. The link's font size comes from `.inline-link { font-size: 1rem }` (`src/styles/global.css:218-225`), so 1em = the label's size and follows text scaling and whatever WP30 sets. `Icon.tsx:59-60` sets `width`/`height` as presentation attributes, which CSS overrides; `Icon.tsx:67` keeps `aria-hidden="true"`. `LegalPage.tsx:110-111` unchanged. No other legal.css rule (including the 800/580/360 px blocks) targets this svg.
- Renders (20:58, newer than legal.css at 20:33): `delete-account.ca.mobile-text200.light.fold.png` and `privacy.es.mobile-text200.light.fold.png` show the arrow at about the height of the capitals of «Tornar a TaskFlow» / «Volver a TaskFlow» (before: a 16 px arrow beside 32 px text). `privacy.en.mobile.dark.fold.png` at default text: arrow unchanged at 16 px beside “Back to TaskFlow”.
- Tester: `tests/ux-web-legal.spec.ts` WEB-714 passes (svg within 1 px of computed font size at default and 32 px live font size, both themes, both projects; name is the label alone; axe clean). AUDIT §3 privacy es / delete-account ca text200: no sideways scroll, no clipped text.

## Regressions

None. The selector is scoped to the back link's one svg; default-size rendering is identical (1em = 16 px). The other lines in this file's run diff (`.legal-languages` wrap, radius 29px, `aria-current="page"`) belong to earlier packages, not WP41.
