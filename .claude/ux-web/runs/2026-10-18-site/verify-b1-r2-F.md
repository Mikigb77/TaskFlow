# Verify — run 2026-10-18-site, round 2, area F (WP35) — 2026-10-19

Evidence: code (TaskFlowWeb working tree), renders made 2026-10-19 04:43–04:44, after the last edits to `HomePage.tsx` (04:21) and `global.css` (04:21), so they're current. No npm or Playwright run.

## WEB-708 · fixed
- `src/content/site/en.ts:61`, `es.ts:61`, `ca.ts:67` equal the brief's EN / ES / CA text character for character, and name the password (`password` / `contraseña` / `contrasenya`). Pinned copy matches at `tests/support/ux-web-copy.ts:146-148`.
- True of the app: password sign-up then a 6-digit emailed code (`Backend/docs/EMAIL_VERIFICATION.md:3`; `App/lib/l10n/app_en.arb:724` `verifyEmailHelp`). The button names match the app: `Continue with Google` / `Continuar con Google` / `Continua amb Google` (`app_en.arb:1760`, `app_es.arb:1098`, `app_ca.arb:802`).
- Device check left: a native Catalan speaker reads the answer.

## WEB-706 · fixed
- `src/components/HomePage.tsx:85-95` maps `features.calendar.weekdays` (7 entries); each `.mini-day` holds only its weekday `<span>` and dot `<i>`; the first gets `selected`. No dates array is left in `src/content/site/` (grep), and `.mini-day strong` is gone from `global.css`; `.mini-day` keeps `padding-block: 6px` with no `min-height` (`global.css:561-565`).
- Letters: EN `M T W T F S S` (`en.ts:22`), ES `L M X J V S D` (`es.ts:24`), CA `dl dt dc dj dv ds dg` (`ca.ts:24`).
- Renders: `home.en.desktop.light/dark.full.png` screen 3, `home.es.mobile.light.full.png` screens 4–5, `home.ca.mobile-w320.light.full.png` screens 4–5 and `home.ca.desktop-zoom200` show letters only. The selected pill doesn't look cramped (no need for the 2.75rem fallback). No drawn week can now contradict the hero image's dates.

## WEB-705 · fixed
- CSS matches the brief: base `.feature-calendar` span 7 / row span 2 (`global.css:531-536`), `.feature-voice` span 5 (:648), `.feature-details` span 5 (:663), `.feature-offline` span 12 (:670); 800 px block (:1049-1059) calendar span 6 / row span 2, voice and details span 6, offline span 12; 580 px block `.feature-card { grid-column: auto; grid-row: auto; }` (:1188-1193), later in the source than the 800 px rule, so it wins.
- Renders: at 1440 (light and dark) the calendar card spans two rows, voice over details on the right, offline full width below. Voice card ≈ 305 px tall with ≈ 66 px below its link (≈ 21%, padding included); details ≈ 223 px with ≈ 58 px below (≈ 25%, my pixel estimate; the tester measured ≤ 25%). At desktop-text200 the calendar card gets the slack (≈ 17% below the drawing), within the 25% bar. Zoom200 (720 CSS px, 800 px block) and both phones read well; phones are one column, calendar → voice → details → offline.
- No render exists between 801 and 1100 px; the tester measured 1000 px instead (pass). Accepted.
- `.voice-illustration` stays absent (no markup in `HomePage.tsx`).

## Regressions
**R2F-1 · Severity 1 · Full-width offline card is two-thirds blank**
- Where: `src/styles/global.css:670-676` (`.feature-offline` span 12, `.feature-offline p { max-width: 26rem }`); `/`, `/es/`, `/ca/` at 1440, light and dark; `home.en.desktop.light.full.png` screen 3.
- The moment: a comparer scanning the cards sees a 1180 px wide band with three short lines at its left and nothing in the other ≈ 750 px; it reads as an unfinished card rather than a feature.
- Caused by WP35 (offline went from span 6 to span 12); its acceptance only measures vertical slack, so it passes.
- Fix (CSS only, no new content): at widths above 800 px, lay the offline card out in two columns, icon and heading on the left, paragraph on the right: `.feature-offline { display: grid; grid-template-columns: minmax(0, 1fr) minmax(0, 1.4fr); column-gap: 32px; align-items: start; }` with the icon and `h3` in column 1 and the `p` (max-width 32rem) in column 2; reset to `display: block` in the 800 px block. Smaller alternative: raise `.feature-offline p` max-width to 40rem so the text fills more of the band.
- Verify: render at 1440, light and dark; no more than about half the card's width is blank.
- Evidence: seen in current render.

Nothing else in the changed files regressed on the pages they touch: account answer only text; mini-week is decorative; no sideways scroll at 320 (tester, AUDIT §3).
