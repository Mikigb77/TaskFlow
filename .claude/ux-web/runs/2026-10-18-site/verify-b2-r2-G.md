## UX web verify — run 2026-10-18-site, round 2, area G (WP37, WP38) — 2026-10-19

**Verdict:** all four findings fixed; no regressions in `src/styles/global.css` or `src/app/not-found.tsx`.

Evidence base: this run's diffs (`ux-web.sh diff`), the built HTML in `.next/server/app/` (12:23, after both source edits at 11:35 and 12:04), the renders and `AUDIT.md`/`audit.json` re-made at 12:42–12:48 (newer than the code), and the tester's tests in `tests/ux-web-global.spec.ts:750-930` and `tests/ux-web-frame.spec.ts:369-470` (tester reported no failures). No device check.

### WEB-711 (R1G-2) · fixed
- `src/styles/global.css` `.language-switch { gap: 8px }` (the rule after `.header-actions`); nothing else in the switch changed.
- `audit.json`, home light: header switch on /, /es/, /ca/ at 1440 = 80–86 × 48 px, gap 8; footer switch desktop and mobile = 74–86 × 48, gap 8 (e.g. /ca/ desktop English 989→1069, Español 1077: 8 px).
- Catalan 1025/1100 px fit: not rendered; covered by `tests/ux-web-global.spec.ts:792-809` (desktop nav and switch visible, no Menu, no sideways scroll, header ≤ 105 px, links ≥ 48 px and 8 px apart). The 1440 render `home.ca.desktop.light.fold.png` looks as before apart from the wider gaps.
- Menu-open language links on a phone: the audit has no menu-open target rows; covered by the test at `:764`.

### WEB-712 (R1G-3) · fixed
- `global.css:1018-1019`: the comment reads exactly as the brief asks, and the block opens `@media (max-width: 64em)`. Other breakpoints (1100, 800, 580, 360 px) and `scroll-padding-top` untouched. Only `matchMedia` in `src/` is the colour-scheme one (`layout.tsx:53`, `ThemeProvider.tsx:37`).
- Renders: `home.en.desktop-text200.light.fold.png` and `home.ca.desktop-text200.light.fold.png` show a one-row header, ~87 px, logo left and a “Menu” / “Menú” pill right. Same on `privacy.es.desktop-text200.light.fold.png` and `not-found.ca.desktop-text200.light.fold.png`. `audit.json` variants: rootFontSize 32, overflow 0 on all three homes.
- Anchor landing under the header at 200%: test at `:811-863` (live `Page.setFontSizes`, title top ≥ header bottom).

### WEB-703 (footer part) · fixed
- `.footer-top nav a` now has `min-width: 44px; justify-content: center;`.
- `audit.json`: “Què fa” on /ca/ = 44 × 44 at 1440 and 390 (was 43). Every other footer nav link ≥ 63 × 44. Test at `:880`.
- The header-logo part stays WP25's.

### In passing: `.section-eyebrow > span` · done
- The rule is gone (`grep -c` = 0); `.section-eyebrow` itself is intact.

### WEB-713 (R1G-1) · fixed (option 2)
- `src/app/not-found.tsx`: one `import { preload } from "react-dom"` and one `preload(...)` call with the comment the brief asks for. The rest of the 404 (metadata, inline language script, `NotFoundPage`) is not this package's.
- Built `.next/server/app/_not-found.html` holds exactly one `<link rel="preload" href="/_next/static/media/Manrope_latin-s.p.1xbpjvy34wz9n.woff2" as="font" crossorigin="" type="font/woff2"/>`, byte-identical to `index.html`, `es.html` and `ca.html`.
- `AUDIT.md` §2 (lab): not-found en/es/ca CLS 0.000 (was 0.021–0.028), LCP 1.64 / 1.52 / 1.44 s (es was 2.96 s), one font file (the same woff2, 24 KB), 11 requests. No row says the font arrives after FCP. Tests at `tests/ux-web-frame.spec.ts:393-470`.
- Option 1's outcome isn't stated in the code. The implementer's notes should say what it produced.

### Regressions (changed files and pages they touch)
None found.
- The 64em block hides `.header-actions > .theme-toggle` along with the nav and switch. At 200% text the theme choice moves into the menu (`.appearance-choice`), so nothing is lost.
- The menu panel at 200% on desktop (width `min(26rem, …)` = 832 px at a 32 px root) fits 1440. That's inferred from the CSS, because no render shows the menu open at 200% text.
- The 404's hard-coded hashed URL is a maintenance coupling, not a visitor issue, and the test at `:393` guards it.

Not this round's, seen in passing (already outside these packages):
- At 200% text, the hero's secondary link “What it does” / “Què fa” wraps, with its chevron set apart (`home.*.desktop-text200.light.fold.png`).
- The /ca/ voice section still shows English strings (held demo work).
