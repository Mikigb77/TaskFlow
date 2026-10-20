## UX web verify — run 2026-10-18-site, batch b5, round 1, area H (WP46, WP49) — 2026-10-20

**Verdict:** All five findings fixed. No regressions in the changed files or the pages they touch.

**Scope read:** `ux-web.sh diff` for `src/content/site/{en,es,ca}.ts` (only `voice.privacy` changed), `src/styles/voice.css` (no diff in this run; the WEB-720 rule was already there from b4), `tests/ux-web-voice.spec.ts`; `src/components/VoiceDemo.tsx` read at :61-100, :140-199, :690-760, :905-935, :1005-1035. VoiceDemo's only run diff is `lang={language}` on `<section id="voice">`, which is WP48's (another area), so I don't rule on it here.
**Renders** (all newer than the code they show: renders 06:40–06:41, en.ts 05:44, VoiceDemo.tsx 05:10, voice.css 2026-10-19 22:24): `voice-capture.en.mobile.light.panel.png`, `voice-resend-waiting.en.desktop.light.panel.png`, `voice-check-gave-up.en.mobile.light.{panel,view}.png`, `voice-connect-paused.en.mobile.light.panel.png`. AUDIT.md §13 rows 968-975 and 1030-1031.

### Results

**WEB-6 · fixed**
- No walkthrough left: `grep -rniE "walkthrough|#demo|id=\"demo\"" src/` finds nothing. The demo's `voice` blocks in all three languages contain no walkthrough, sample, recorrido or recorregut.
- No JavaScript: the closed intro renders `<noscript>` with `t.noscript`, then `<VoiceExample>` on the server (`VoiceDemo.tsx:704-707`). The start button is `disabled={!ready}`.
- Demo off: `failureFor` maps budget_pause, paused, not_ready, budget_config and unavailable to `t.errors.off` with `off: true` (`:61-72`), and the server's own message is never shown. The off stage renders the example, then the alert (`:737-741`). The render `voice-connect-paused.en.mobile.light.panel.png` shows: example, ‘2 things to add’, two cards with ‘Tomorrow’, then ‘The live demo is off for now. The example above shows what TaskFlow does.’
- Security check given up: the stage renders the example, the alert and the hand-over (`:1026-1031`), as the render `voice-check-gave-up.en.mobile.light.view.png` shows. AUDIT.md §13 has focus on `p.voice-error`.
- Tries used: the stage renders the tries-used line and the hand-over only (`:1012-1023`), with no walkthrough promise.
- Tests: the tester reports these as passing.

**WEB-9 · fixed**
- Turnstile's options (`VoiceDemo.tsx:156-158`): `appearance: "interaction-only"`, size `compact` below 300 px and `normal` otherwise, `retry: "never"`. The holder is a bare `<div className="voice-verification">` with no aria-label (`:198`).
- ‘Type instead’ is `className="text-link voice-mode-link"`, with no aria-pressed or role (`:927-934`). The render `voice-capture.en.mobile.light.panel.png` shows it as an underlined link. The new test at `tests/ux-web-voice.spec.ts:2144` hasn't run yet (WSL failed), so the code and the existing aria-pressed scan carry this part.
- Two clicks to a spoken result: the tester's test passes.
- Device checks carried over: the real Cloudflare widget, and the real AI with a real microphone in Spanish.

**WEB-109 (the demo's words) · fixed**
- Scanned the `voice` blocks of `en.ts`, `es.ts` and `ca.ts` for draft, borrador, esborrany, allowance, transcri, sync, sincroniz, sincronitz, voice-to-task, shared list, MiB, Whenever you're ready, Record again, Create drafts, Task 1, priority, prioridad and prioritat. The only hit is the key name `invalidDraft`, whose visible text in each language is clean (en.ts:219-220, es.ts:220-221, ca.ts:229-230).
- `draftSchema` in `policy.ts` is code, not visible text.
- The capture render shows the app's words: ‘What would you like to remember?’, ‘Tap to talk’, ‘Type instead’.
- The ES and CA word scans and the all-strings test are in the spec (:2157), and the tester reports them as passing.

**WEB-720 · fixed**
- `src/styles/voice.css:369-372` is `.voice-panel .voice-retry[aria-disabled="true"] { opacity: 1; background: color-mix(in srgb, var(--green) 55%, var(--surface)); }`.
- It wins over the shared rule at :362-366. Its specificity is (0,3,0) against (0,2,1), and it comes later. The later `.voice-retry` layout rule (:379-387) sets no background.
- The shared rule still dims every other disabled button. The render `voice-resend-waiting.en.desktop.light.panel.png` shows Tap to talk faded, and Try again with a dimmed fill at full opacity.
- AUDIT.md §13:1030-1031 for voice-resend-waiting: axe 0, 0 control fails, focus on `button.voice-retry`.
- The keyboard test at `tests/ux-web-voice.spec.ts:2259` passed. It measured opacity 1 and a 3 px outline of rgb(23,110,89) in light and rgb(158,213,179) in dark.
- The white label on the dimmed fill is low in contrast, but WCAG 1.4.3 exempts inactive controls, and the moment is brief.
- Device check: a keyboard user in Chrome, and in Safari on a Mac.

**WEB-730 · fixed**
- `voice.privacy` is the organizer's exact copy in English (`en.ts:148`), Spanish (`es.ts:148`) and Catalan (`ca.ts:154`).
- `grep "IA de Google|Google’s AI" src/` finds it only in `src/content/legal/*` (the privacy summary and §EU), which the brief leaves alone.
- The render `voice-capture.en.mobile.light.panel.png` shows the line, then ‘How we use your data’.
- The line matches privacy §8 and the FAQ (‘sent to Google’). The pinned `VOICE.privacy` (`tests/ux-web-voice.spec.ts:98-102`) was updated, and the new test at :2306 passes.
- Catalan for a native read: «El que dius o escrius va a Google només quan toques Fet.» It reads naturally.

### Regressions
None.
- The privacy line is shorter, and it still wraps cleanly on the 390 px capture render. AUDIT.md §13 has axe 0 and no text, target or contrast fails for voice-capture and voice-typing, desktop and mobile, light and dark.
- Render-tool note, not a site finding: `voice-check-gave-up.en.mobile.light.panel.png` is cut at the viewport's bottom edge (the hand-over line is half shown). The page itself is fine; the `view.png` shows it continuing.

### Not counted
- `lang={language}` on `#voice` is WP48's.
- Device checks are listed above.
