## UX web verify — 2026-10-18-site, round 2, area G (WP40) — 2026-10-19

**Verdict:** Ship. WEB-715 is fixed; no regressions in the changed file's touched pages.

### WEB-715 · fixed
- Code: `src/styles/global.css:275-283` `.brand` now `font-size: min(1.4375rem, 28px);` with the logotype comment (WCAG 1.4.4 exemption). `.footer-top .brand` (`:889`, 1.375rem), `.brand-mark`, `min-height: 48px`, `.header-inner`, breakpoints and `scroll-padding-top` untouched, as the brief asked. Render timestamps (20:57–20:58) are newer than the CSS (20:27), so the renders are evidence.
- Renders (read at full size): `home.en.mobile-text200.light.fold.png`, `home.es.mobile-text200.light.fold.png`, `home.ca.mobile-text200.light.fold.png`, `privacy.es.mobile-text200.light.fold.png` all show the logo and ‘Menu’/‘Menú’ on one row; header bottom rule at about 73 CSS px (220 device px / 3), down from about 127 px, i.e. about 11% of the 664 px screen instead of 19%.
- `AUDIT.md` §3: home en/es/ca and privacy es text200 390 × 664 — scrolls sideways: no, clipped text: none. §4: “No violations on any page.”
- Tester: both WEB-715 tests in `tests/ux-web-global.spec.ts` pass (wordmark 28 px, Menu 32 px, header ≤ 90 px, centres within 4 px, `#questions-title` below the header; default text 23 px; axe clean), light and dark.
- Device check outstanding: Android Chrome with the system font at its largest (not run).

### Regression search (only `global.css` `.brand` and pages with the header)
- Default text: `home.es.mobile-w320.light.fold.png` — wordmark still 23 px, header one row, unchanged.
- Desktop text200: `home.es.desktop-text200.light.fold.png` — the wordmark now stops at 28 px beside a 32 px ‘Menú’; still clearly the brand, legible, one row. A logotype is exempt from 1.4.4, so not a finding.
- The rest of the `global.css` diff predates this round (earlier packages, already verified); not re-judged.
- No regressions.

Evidence levels: code read; current Chromium renders; `AUDIT.md` measurements; tester's Playwright assertions. No real device.
