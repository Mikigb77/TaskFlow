# UX web loop: run 2026-10-18-site, batch b5: report (2026-10-20)

**Verdict:** All seven findings still open after b1–b4 are fixed in this batch, and the ledger's Open section is now empty. The reviewers found no regressions and no test for these findings failed. Two findings are verified. Five are fixed but still need a device or person check. Two gaps were left, and the first is now closed:
- WEB-9's new test `tests/ux-web-voice.spec.ts:2144` and b5's full round check couldn't run in round 1, because WSL wouldn't start (`Wsl/Service/CreateInstance/E_UNEXPECTED`). That was setup, not the site. **Update, 2026-10-20:** once the owner had restarted WSL, the main session ran WP50 in full, and it passed (`check-b5-wp50.md`).
- Nothing from b5 can be committed in TaskFlowWeb yet: every website file it touched holds another session's uncommitted work.

## Verified
- **WEB-6** (S3, H): the sample walkthrough is gone and a static example takes its place.
  - No walkthrough or `#demo` is left in `src/`.
  - The example shows without JavaScript (`src/components/VoiceDemo.tsx:704-707`), when the demo is off (`:737-741`) and when the security check gives up (`:1026-1031`).
  - The "tries used" message no longer promises a walkthrough.
  - Source: `verify-b5-r1-H.md`.
- **WEB-730** (S1, H): the demo's privacy line now says "goes to Google" / «va a Google» / «va a Google» (`src/content/site/en.ts:148`, `es.ts:148`, `ca.ts:154`). This matches privacy §8, the FAQ and the app. Source: `verify-b5-r1-H.md`.

## Fixed, waiting on a device or person check
- **WEB-9** (S2, H): the live demo now matches the app's taps and words.
  - Fixed in code (`VoiceDemo.tsx:156-158`, Turnstile `interaction-only`, compact under 300 px, `retry: "never"`; "Type instead" at `:927-934` is a `text-link` button with no `aria-pressed` or role) and in the capture render.
  - Round 2 (`verify-b5-r2-H.md`) kept round 1's verdict.
  - Tests that passed: the Turnstile options (`:2112`) and "two clicks to a spoken result".
  - The test `:2144` passed on 2026-10-20, when WP50 ran after the WSL restart (`check-b5-wp50.md`).
- **WEB-109** (S2, F): the site now uses the app's words for its features.
  - Demo: the words are clean in EN/ES/CA (`verify-b5-r1-H.md`; word scan at `:2157`).
  - Legal text (WP47): the terms description, og:description and twitter:description; terms §2, §3, §5 ("5. AI suggestions", `#ai` kept) and §6; privacy §3 and §8 (`verify-b5-r1-L.md`).
  - The legal version is now 2026-10-20 (`src/content/legal/company.json:10`, `docs/LEGAL_RELEASE.md:3`).
  - Still needed: a native Catalan read, and the owner's WD3 sign-off of "In force since 20 October 2026".
- **WEB-707** (S2, G): the demo is now marked in the page's language. `<section id="voice" lang={language}>` uses the URL's language, with no other `lang` inside and no portal. The FAQ half is translated and sits inside the page's own `lang`. Source: `verify-b5-r1-G.md`.
- **WEB-720** (S1, H): the held "Try again" button keeps its full focus ring.
  - `src/styles/voice.css:369-372` sets `opacity: 1` with a dimmed fill, and this rule overrides the shared disabled style. Other disabled buttons still dim.
  - The test measured opacity 1 and a 3 px ring in light and dark.
- **WEB-729** (S1, L): privacy §2 and §4 now use the brief's words in EN/ES/CA: suggested tasks; the text of what you said; and "The app can use Google’s Gemini API, with Google Cloud’s Vertex AI as a fallback; the website demonstration uses Vertex AI." This is true to `Backend/core/ai.py:118-133`. §4's paid and unpaid Gemini paragraph is unchanged (WD12). Source: `verify-b5-r1-L.md`.

## Still open
None of this batch's findings is still open. The gap in evidence is closed: WP50 ran on 2026-10-20, after the owner restarted WSL (`check-b5-wp50.md`). It covered:
- the test `:2144`;
- `npm run check`;
- the re-runs of `:2112` and `:2157`;
- the round check (`legal:check`, `build`, `npm test`, `test:unit`, the renders).

All passed. The whole suite's only two failures, the 12-page axe tests, were timeouts under load and passed when re-run on their own. `artifacts/ux-web/AUDIT.md` is fresh from that run.

Agents no longer stop WSL (cd2b79b): the second `wsl --shutdown` in round 1 left it unable to start until the owner restarted it.

Still with the owner from before, not part of b5: WEB-701 (WD15, Safari on your iPhone).

## Escalations
None.

## Checks for a real device or a person
- WEB-9: the live demo in Spanish on a phone, with the real AI and a microphone (two taps: «Toca para hablar», then «Listo»).
- WEB-9: Cloudflare's real Turnstile widget on the deployed site.
- WEB-707: TalkBack in Spanish on /es/ reads the demo's heading, «Probar la demo en directo» and «Toca para hablar» with a Spanish voice.
- WEB-707: VoiceOver on an iPhone on /ca/ reads the demo in Catalan inside the `display: contents` wrapper.
- WEB-720: a keyboard on the held "Try again", in Chrome and in Safari on a Mac, with the real security check.
- WEB-109 and WEB-729: a native Catalan read of privacy §2–§4, the terms description and terms §5.
- WEB-730: optionally, a native Catalan read of «El que dius o escrius va a Google només quan toques Fet.» The verifier finds it natural.
- WEB-109: the owner's WD3 sign-off. Every legal page now reads "In force since 20 October 2026".

## Files changed

### Website (TaskFlowWeb)
All held: nothing from b5 can be committed now.

The other session created these files and hasn't committed them yet (untracked), so they can't be committed until it does:
- `src/content/legal/en.ts`
- `src/content/legal/es.ts`
- `src/content/legal/ca.ts`
- `src/content/legal/company.json`
- `docs/LEGAL_RELEASE.md`
- `tests/legal.spec.ts`

These tracked files hold another session's uncommitted work. Only this run's own lines can be committed, once they can be separated from that session's lines:
- `src/components/VoiceDemo.tsx`: also holds this run's held demo; b5 changed only `lang={language}` on `#voice`.
- `src/content/site/en.ts`, `es.ts` and `ca.ts`: b5 changed only `voice.privacy`.
- `tests/ux-web-voice.spec.ts`
- `tests/support/ux-voice.ts`
- `tests/ux-web-legal.spec.ts`

When `VoiceDemo.tsx` is committed, in the same commit:
- remove the `lang="en"` wrapper at `src/components/HomePage.tsx:52-55`, with its comment;
- change `tests/ux-web-global.spec.ts:163-192` so it checks the section's own language (drop `voice: "en"` and `voiceWrapperDisplay`).

### App repo (the loop's records)
- `.claude/ux-web/ISSUES.md`
- `.claude/ux-web/runs/2026-10-18-site/plan.md` (Round 2 and Round 3 for b5)
- `.claude/ux-web/runs/2026-10-18-site/plan-b5-r2.json`
- `.claude/ux-web/runs/2026-10-18-site/plan-b5-r3.json`
- `.claude/ux-web/runs/2026-10-18-site/verify-b5-r1-G.md`, `verify-b5-r1-H.md`, `verify-b5-r1-L.md` and `verify-b5-r2-H.md`
- `.claude/ux-web/runs/2026-10-18-site/report-b5.md` (this report, saved by the main session)

## Tests protecting the fixes
- WEB-6: `tests/ux-web-voice.spec.ts` and `tests/ux-web-home.spec.ts` (WEB-6).
- WEB-730: `tests/ux-web-voice.spec.ts:2306` and the pinned `VOICE.privacy` (`:98-102`).
- WEB-720: `tests/ux-web-voice.spec.ts:2259`.
- WEB-707: `tests/ux-web-voice.spec.ts:2176`, `:2201` and `:2240`; `tests/ux-web-features.spec.ts`; `tests/ux-web-global.spec.ts:163`.
- WEB-109: `tests/ux-web-voice.spec.ts:2157`, `tests/ux-web-legal.spec.ts`, `tests/legal.spec.ts` (pinned dates), `tests/ux-web-features.spec.ts` and `tests/website.spec.ts`.
- WEB-729: `tests/ux-web-legal.spec.ts` and `tests/legal.spec.ts`.
- WEB-9: `tests/ux-web-voice.spec.ts:2112` passes. `:2144` is written but has never run.

## Rounds
- **Round 1** (`plan.json`, WP46–WP49, all done).
  - All seven findings ruled fixed in `verify-b5-r1-G.md`, `verify-b5-r1-H.md` and `verify-b5-r1-L.md`. No regressions.
  - Tests: the targeted specs for WEB-6, WEB-9 (`:2112`), WEB-109, WEB-707, WEB-720, WEB-729 and WEB-730 passed.
  - The round check then failed when WSL stopped starting, right after the tester added `:2144`. This was setup, not the site.
- **Round 2** (`plan-b5-r2.json`, WP50, a re-run only).
  - WP50 was blocked by the same WSL error, so no test ran then. The main session ran it on 2026-10-20, after the WSL restart: everything passed (`check-b5-wp50.md`).
  - `verify-b5-r2-H.md` keeps WEB-9 fixed from the code and the render. No regressions; no file changed.
- **Round 3** (`plan-b5-r3.json`): no package. A third run would hit the same outage, so it was not run.

## Notes for the main session
- Terms §5's first paragraph (EN) still says "AI capture is optional". No reviewer flagged this older text; check it against the app at the next legal review.
- Developer-only text (`?developer=1`) is now marked `es`/`ca` on those homes while it stays English. No visitor sees it, and the conventions allow it.
- The render `voice-check-gave-up.en.mobile.light.panel.png` is cut off at the viewport's edge. That is the render tool, not the site.