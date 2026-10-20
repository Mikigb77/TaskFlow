# Verify b5 round 2, area H (2026-10-20)

Scope: WP50 (WEB-9) only. Re-run package; no site file changed in this round.

## WEB-9: fixed (round 1's code verdict kept; test evidence still pending)

The brief says to rule from the tester's run of `tests/ux-web-voice.spec.ts:2144` and keep round 1's verdict unless that test fails on the site. It didn't fail. It didn't run, because WSL still won't start (`Wsl/Service/CreateInstance/E_UNEXPECTED`). That's an infrastructure gap, not a WEB-9 failure, so round 1's "fixed" stands.

What I re-confirmed by reading the code and a render:
- `src/components/VoiceDemo.tsx:927-934`: "Type instead" is a plain `<button className="text-link voice-mode-link">`. It has no `aria-pressed`, no `role`, and no switch or checkbox. Its label comes from `t.typeInstead` / `t.talkInstead`.
- Copy: `src/content/site/en.ts:165` `Type instead`, `es.ts:165` `Escribir`, `ca.ts:172` `Escriu`. These match the app's words (conventions) and the test's `VOICE.typeInstead` (`tests/ux-web-voice.spec.ts:110`).
- The test at `:2144-2155` checks what the acceptance asks for in each language: a single named button, the `text-link` class, no `aria-pressed`, no switch or checkbox in the demo, and no fill. Nothing in it looks wrong.
- Render `artifacts/ux-web/voice-capture.en.mobile.light.panel.png` (06:41, newer than `VoiceDemo.tsx` at 05:10 and the copy at 05:44): "Type instead" is an underlined green link below the privacy line. It isn't a toggle or a filled button. The same render shows the rest of WEB-9: a single "Tap to talk" microphone, no listen-back, no "Create drafts", and the app's teaching example.
- `bash .claude/ux-web/ux-web.sh diff`: this round's changes are only round 1's held lines (`lang={language}` on `#voice`, test-file comments and tests). There are no new site changes.

Still open as evidence, not as findings:
- The `:2144` test, `npm run check` and the `:2112` / `:2157` re-runs, once WSL works.
- On a device (carried over): Cloudflare's real Turnstile widget on the deployed site, and the live demo in Spanish with the real AI and microphone on a phone (two taps: «Toca para hablar», then «Listo»).
- No `AUDIT.md` row names the demo's "Type instead" control, so I quote none.

## Regressions

None. No file changed in this round, so there's nothing that could have caused one.
