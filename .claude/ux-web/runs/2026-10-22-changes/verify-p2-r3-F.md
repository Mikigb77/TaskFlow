# Verify — plan 2, round 3, area F — 2026-10-22

Scope: WP62 (WEB-1105, alias R1F-1), a re-check with no code change. Mode: verify.

## WEB-1105 · S1 · fixed

- Code: `git -C ../TaskFlowWeb diff src/styles/global.css` and `bash .claude/ux-web/ux-web.sh diff -- src/styles/global.css` both show exactly one added line, `text-wrap: pretty;`, as the first declaration of `.feature-card p` (`src/styles/global.css:583-584`), followed by the unchanged `font-size: 1rem; line-height: 1.7; margin-top: 10px; color: var(--muted); max-width: 24rem;`. `git status --porcelain` lists only WP60's and WP61's files (`src/content/site/{en,es,ca}.ts`, `src/styles/global.css`, `tests/support/ux-web-copy.ts`, `tests/ux-web-features.spec.ts`); no other session's files. This round changed no website file (global.css last written 23:23, content files 22:51).
- Renders are current: written 23:48-23:49, after the last CSS edit (23:23).
  - `home.es.mobile.light.full.png`, screens 4-5 (crop `artifacts/ux-web/crops/home.es.mobile.light.full.s4-5.png`): calendar paragraph ends «…cada / vez más a menudo según se acerca / el día.» — two words on the last line. Drawing reaches the card's bottom edge.
  - `home.es.mobile.dark.full.png`, screens 4-5: same wrap, «el día.»; dark card reads normally.
  - `home.ca.mobile.light.full.png`, screens 4-5: ends «…cop més sovint a mesura que s’acosta / el dia.» — two words. Drawing reaches the bottom edge.
  - `home.en.desktop.light.full.png`, screen 3: paragraph ends «and more often as the day gets closer.» (full line); calendar card spans two rows beside voice over details, offline full width below; drawing reaches the card's bottom edge, no mint band.
- Copy: WP60's text intact in every render (EN «TaskFlow can remind you of tasks with a date, more and more often as the day gets closer.», ES «…según se acerca el día.», CA «…a mesura que s’acosta el dia.»).
- Tests (tester, this round): WP61's block (`tests/ux-web-features.spec.ts:1199`) — last-line word count, light and dark, desktop and mobile: pass; text-wrap pretty / 16 px / 1.7 / widths unchanged: pass. WEB-705 (`:304`, `:335`, `:358`), WEB-1004 (`:871`), `:759`, `:955` and WP60's block from `:1010` (axe light/dark, 320 px, text 200%): pass.
- Every acceptance check is met. Open device check (from the package): Safari on a real iPhone and Chrome on a real Android on /es/ and /ca/; an older Safari without `text-wrap: pretty` falls back to normal wrapping, so the lone word may return there, with nothing else broken.

## Regressions

None. No website file changed this round. The other cards' paragraphs read normally in the renders (es mobile voice card ends «muchas a la vez.»; en desktop details card ends «up to 6 MB each.»), and the grid and card heights are unchanged.
