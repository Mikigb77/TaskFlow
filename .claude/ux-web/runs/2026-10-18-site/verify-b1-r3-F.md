# Verify — run 2026-10-18-site, round 3, area F — 2026-10-19

Scope: WP36 (WEB-709, alias R2F-1). Changed file: `src/styles/global.css`.
Renders checked (all written 05:20–05:21, after `global.css` at 04:58, so current):
`home.en.desktop.light.full.png` s3, `home.en.desktop.dark.full.png` s3, `home.es.desktop.light.full.png` s3,
`home.ca.desktop.dark.full.png` s3, `home.ca.desktop-text200.light.full.png` s4 (crops in `artifacts/ux-web/crops/`).

## WEB-709 · fixed

- Code matches the brief exactly: `src/styles/global.css:670-691` (`.feature-offline` becomes a two-column grid
  `minmax(0,1fr) minmax(0,1.4fr)`, gap 32 px; icon at col 1 row 1, h3 at col 1 row 2, p at col 2 rows 1–2,
  `margin-top: 0`, `max-width: 32rem`). `global.css:1073-1080` (max-width 800 px) restores `display: block`,
  `p { margin-top: 10px; max-width: 26rem }`. The 580 px block's `.feature-card { grid-column: auto }`
  (`:1209`) comes later at equal specificity, so the one-column phone grid still works. Specificity check:
  `.feature-offline p` (0,1,1) sits after `.feature-card p` (`:520`), so its margin and max-width win.
  Markup untouched (`src/components/HomePage.tsx:135-141`).
- Render, EN light and dark, 1440 px, screen 3: card x 130–1310 (1180 px). Heading at the left; paragraph
  starts at x≈646 (44% of the card from its left edge) and its lines end at x≈1138, about 85% of the
  width. Blank area: the gap between columns plus ~170 px on the right, well under half. Previously
  ~two-thirds blank. Dark looks designed: same `--soft` band, same contrast as before.
- ES light and CA dark, 1440 px: same layout; the longer headings («Tus tareas, también sin conexión»,
  «Les tasques, també sense connexió») stay on one line in column 1, nothing clipped.
- CA at 200% text, 1440 px: heading wraps to two lines in column 1, paragraph four lines in column 2, nothing
  clipped or overlapping.
- Tester: all eleven WEB-709 / WEB-705 / home tests pass (acceptance 1–4, grid check, 320 px no sideways
  scroll, axe clean light and dark). AUDIT.md §3 and §4 as quoted by the tester.
- Evidence: verified in code, seen in current Chromium renders, and measured by the tester's tests.

## Regressions (only from this change)

### R3F-1 · Severity 1 · Offline paragraph sits above its own heading
- Where: `src/styles/global.css:687-691` (`.feature-offline p { grid-row: 1 / span 2; margin-top: 0 }`),
  home `#features`, all languages, desktop > 800 px, both themes. Clearest in `home.ca.desktop.dark.full.png`
  s3: the two-line paragraph runs y≈661–688, the heading starts at y≈703, so the whole body text is above
  the heading it belongs to. In EN/ES (three lines) the paragraph starts ~48 px above the heading's top.
- The moment: the scanner's eye, moving left to right at the top of the card, meets the icon and then the
  body text before the heading ("Les tasques es desen al mòbil…" — what's this about?); the heading reads
  as a caption below.
- Why it fails: headings should lead and front-load the topic (lens F, scanning and hierarchy;
  GUIDELINES.md scanning rules). The brief chose top alignment with the icon; this is a polish cost of it,
  not a blocker. The heading still wins by size and weight, so impact is small.
- Fix (CSS only): align the paragraph's first line with the heading instead of the icon:
  `.feature-offline p { grid-column: 2; grid-row: 2; margin-top: 18px; }` (the h3 keeps its 18 px top margin
  from `.feature-card h3`, so their tops match; drop `1 / span 2`). The card grows about 15–40 px in height;
  the last child is still the paragraph, so WP35's slack check is unaffected. Acceptance 1's "paragraph top
  above heading bottom" still holds (tops equal).
- Verify: at 1440 px in EN/ES/CA, |p.top − h3.top| ≤ 2 px; WP36 acceptance 1–4 and WP35's grid test still pass.
- Evidence: seen in current renders; fix inferred from the CSS.

## Not regressions (noted, out of this change)
- "04 / A FEW GOOD QUESTIONS" and "Glad you asked." show in English on `/es/` and `/ca/` desktop renders.
  Not caused by `global.css`; if not already in ISSUES.md, it belongs to whichever package owns the FAQ copy.
- The offline icon stays 23 px at 200% text (px-sized SVG); pre-existing, and the same on every feature card.
