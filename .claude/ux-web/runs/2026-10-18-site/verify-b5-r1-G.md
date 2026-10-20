## UX web verify — run 2026-10-18-site, batch b5, round 1, area G — 2026-10-20

**Scope:** WP48 (WEB-707, alias R1G-1). Changed file: `src/components/VoiceDemo.tsx` (held). The run's diff is one line: `lang={language}` on `<section id="voice">`.

**Evidence freshness:** `VoiceDemo.tsx` modified 2026-10-20 05:10 local; `AUDIT.md` build 04:09 UTC (06:09 local), measured 04:40–04:44 UTC. Renders and audit are newer than the code. Language of parts isn't visible in a render and AUDIT.md doesn't measure it, so this rests on code plus the tester's Playwright assertions.

### WEB-707 — fixed

Demo half:
- `src/components/VoiceDemo.tsx:680-685`: `<section id="voice" lang={language} …>`; `language` comes from `useSiteLanguage()` at :202 (the URL, not the browser). On /, `lang="en"`; on /es/ and /ca/, `es` / `ca`.
- The section holds everything the brief names: the `h2` (:688), the start button (:696-703), the `<noscript>` line (:704-706), `VoiceExample` (:707, :739, :1028) and `.voice-plans` (:1058), which sits inside `.container` inside the section. Nothing in the demo is rendered through a portal (no `createPortal` in the file), so no demo text escapes the section's `lang`.
- No other `lang` attribute in `VoiceDemo.tsx` or `VoiceExample.tsx`, so the section's language is the nearest one for every element inside it.
- The committed wrapper `src/components/HomePage.tsx:52-55` (`<div lang="en" style={{display:"contents"}}>`) is unchanged, as the brief says. The nearer `lang` on the section wins, so on /es/ and /ca/ the demo reads as Spanish and Catalan now.
- Error text the visitor sees is localised on the client (`failureFor(t, code)`, :316-321, :556), not the server's English `DemoError` messages, so marking the alert box `es`/`ca` is correct.
- Tester: `tests/ux-web-voice.spec.ts:2176` (heading, start button, example quote, `.voice-plans`, nearest `[lang]` on all three homes; no other `[lang]` inside `#voice`), `:2201` (capture heading, the record button's label through `aria-labelledby`, a stubbed result's heading on /es/ and /ca/; no inner `[lang]` at capture or result), `:2240` (JavaScript off: the server's HTML has `section#voice[lang]`). All pass. `AUDIT.md` §1: axe 0 (0) on every home, language, viewport and theme.

FAQ half:
- `src/content/site/es.ts:83-122` and `ca.ts:89-128`: all seven questions and answers translated; they differ from `en.ts:87-121` item by item.
- `HomePage.tsx:136-157` draws `#questions` inside the page's `<div lang={language}>` (:9), outside the `lang="en"` wrapper (which holds only `<VoiceDemo />`). Nearest `[lang]` is the page's language.
- Tester: `tests/ux-web-features.spec.ts` (FAQ half) and `tests/ux-web-global.spec.ts:163` (committed, unchanged) pass.

Device checks still owed (not blocking the verdict): TalkBack in Spanish on /es/ reads the demo's heading, «Probar la demo en directo» and «Toca para hablar» with a Spanish voice; VoiceOver on an iPhone on /ca/ reads the demo in Catalan inside the `display: contents` wrapper.

### Regressions

None. I looked only at `VoiceDemo.tsx` and the home it renders on.
- Developer-only text (`?developer=1`: "Developer testing · … left" :713-714, the developer details :1033-1052, the developer sentence at :937-938) is still English, and is now marked `es`/`ca` on those pages. Conventions allow it to stay English, and no visitor sees it, so this isn't a finding.
- The visitor's own words ("See what I said", :1006) and the AI's task titles are in whatever language the visitor spoke. Marking them as the page's language is the right default.

### Note for the main session (not a finding)

When `VoiceDemo.tsx` is committed, remove the wrapper at `HomePage.tsx:52-55` as the brief plans. Keeping it does no harm, because the section's own `lang` wins. But the committed test `tests/ux-web-global.spec.ts:163` ("the still-English live demo is marked English") would then describe something that's no longer true. Change it in the same commit, so it asserts the section's language.
