# Verify — run 2026-10-21-changes, round 1, area G (WP55)

## WEB-707 — fixed (code, tests, current renders); device check pending

- **Code:** `src/components/HomePage.tsx:52` is now a bare `<VoiceDemo />`, a direct child of the home's `<div lang={language}>` (`HomePage.tsx:9`). The run's diff removes the comment ("until WP26–WP29") and both tags of the `<div lang="en" style={{ display: "contents" }}>` wrapper. A grep finds no `display: contents` and no `WP26` left in `HomePage.tsx`.
- **The demo's own mark:** `src/components/VoiceDemo.tsx:738-740` gives `<section id="voice" lang={language}>`, so `#voice`, its nearest `[lang]` ancestor and the server's HTML all carry the page's language.
- **Tests (tester, pass):**
  - `tests/ux-web-global.spec.ts:163` was renamed and rewritten. It asserts `voice`, `voiceAncestor`, hero, `#features`, `#questions` and `#get-taskflow` equal the page's language on every home, and `englishAround: []` on /es/ and /ca/. `voiceWrapperDisplay` is gone.
  - A new no-JavaScript test (`tests/ux-web-global.spec.ts`, after :1298) walks from `#voice` to `<body>` in the server HTML. It finds no `lang="en"` on /es/ or /ca/, and the nearest mark is the page's language.
  - The existing voice tests (:2176, :2201, :2240) and axe on the three homes, light and dark, also pass.
- **Renders** (from 2026-10-22 00:48–00:51, newer than `HomePage.tsx` at 2026-10-21 23:25):
  - In `home.es.desktop.light.full.png` and `home.es.mobile.light.full.png` (crops s1-2, s2-3), the layout around "Pruébalo con tu voz" is unchanged. The section starts right after the hero, with the same spacing, and the demo card is intact.
  - `AUDIT.md` (00:56) §4 reports "No violations on any page".
- **CSS:** no selector could have depended on the wrapper. The only `[lang]` selectors are the 404's (`global.css:964-976`), and no sibling or child selector reaches `#voice` or `.voice-section`.
- **Device-only:** TalkBack in Spanish on /es/ should read the live demo with a Spanish voice.

## Regressions

None.
- Checked: the hero and the demo's spacing in the es renders, both viewports; axe; the `lang` chain in the server HTML; and CSS selectors that could reach the removed wrapper.
- The rewritten test asserts the right thing. It filters only `lang="en"` between `#voice` and `<body>`, and it skips that check on `/`, where English is correct.
- Other modified files in TaskFlowWeb (content, legal, `global.css`) belong to other packages in this run. They're outside area G.
