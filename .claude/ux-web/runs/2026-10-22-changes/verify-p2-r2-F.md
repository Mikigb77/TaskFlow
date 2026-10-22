# Verify — run 2026-10-22-changes, plan 2, round 2, area F — 2026-10-22

Scope: WP61 (WEB-1105, alias R1F-1). Changed file: `src/styles/global.css`.

## WEB-1105 · S1 · fixed

- Code: `bash .claude/ux-web/ux-web.sh diff -- src/styles/global.css` is one added line, `text-wrap: pretty;`, as the first declaration of `.feature-card p` (`src/styles/global.css:583-584`). Font size, line height, margin and `max-width: 24rem` untouched. No content, component or other CSS change in this round: `git status --porcelain` lists only WP60's files (content `{en,es,ca}.ts`, `tests/support/ux-web-copy.ts`, `tests/ux-web-features.spec.ts`) plus `global.css`.
- Renders (all written 23:32-23:33, after the CSS edit at 23:23, so current):
  - `home.es.mobile.light.full.png`, screens 4-5 (crop `artifacts/ux-web/crops/home.es.mobile.light.full.s4-5.png`): the calendar paragraph now ends «…según se acerca / el día.» — two words on the last line (was «día.» alone). Drawing below reaches the card's bottom edge.
  - `home.ca.mobile.light.full.png`, screens 4-5: ends «…a mesura que s’acosta / el dia.» — two words (was «dia.» alone). Drawing reaches the bottom edge.
  - `home.en.mobile.light.full.png`: ends «and more often as the day gets closer.» — unchanged, full line.
  - `home.en.desktop.light.full.png` and `home.es.desktop.light.full.png`, screen 3: calendar paragraph ends on a full line («and more often as the day gets closer.» / «cada vez más a menudo según se acerca el día.»); calendar card spans two rows beside voice over details, offline full width below; drawing reaches the card's bottom edge, no mint band.
  - `home.en.desktop-text200.light.full.png`, screens 4-5: paragraph ends «often as the day gets closer.»; drawing reaches the card's bottom edge.
- Copy: WP60's text intact in every render, word for word.
- Tests: the tester added `Run 2026-10-22-changes, plan 2, round 2: WP61 (WEB-1105)` at `tests/ux-web-features.spec.ts:1199` (last-line word count with Range boxes, in light and dark; computed `text-wrap` `pretty` with 16 px / 1.7 / widths unchanged). The tester reported no results, so I rely on the renders, not on a pass.
- Device check still open (from the package): Safari on a real iPhone and Chrome on a real Android on /es/ and /ca/. `text-wrap: pretty` is unsupported in older Safari; there it falls back to normal wrapping and the lone word may return, with nothing else broken.

## Regressions

None. The other three cards' paragraphs in the renders read normally (es desktop voice card ends «a la vez.», details «cada uno.», no lone single word), card heights and the grid are unchanged, and the large empty area under the drawing's two rows at 200% text is the existing WEB-1004 layout, not caused by this rule.
