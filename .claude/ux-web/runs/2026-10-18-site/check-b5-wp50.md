# Batch b5, WP50: the round check, re-run after the WSL outage (2026-10-20)

Run by the main session once the owner had restarted WSL (about 10:31). WP50 (`plan-b5-r2.json`) changes no file: it re-runs what the outage in b5 round 1 had stopped. The website was at TaskFlowWeb 772ee66 plus the held, uncommitted edits of b3–b5 and the other session's work, exactly as round 1 left it. Commands in WSL, from the website root; logs kept in the main session's scratchpad.

| Step | Command | Result |
|---|---|---|
| Build | `SITE_URL=https://taskflow.garbar.tech npm run build` | passed |
| WP50's own tests, both projects | `npx playwright test tests/ux-web-voice.spec.ts --grep "Type instead. is a text-link\|no string the demo can show\|Turnstile is rendered"` | passed, including WEB-9's ‘Type instead’ test (`:2144`) for the first time, the Turnstile options (`:2112`) and the word scan (`:2157`) |
| Type check | `npm run check` | passed |
| Legal check | `npm run legal:check` | passed |
| Whole suite | `npx playwright test` (1228 tests) | 986 passed, 240 skipped, 2 failed: see below |
| Unit tests | `npm run test:unit` | 9 of 9 passed |
| Renders | `UX_RENDERS=1 npx playwright test tests/ux-renders.spec.ts` | 285 passed; `artifacts/ux-web/` and its `AUDIT.md` are fresh |

**The two failures were infrastructure, not the site.** Both were `tests/ux-web-legal.spec.ts:303` ("axe reports no violations on the 12 legal pages", light and dark, desktop). Each hit the 30 s test timeout while loading the 12th page (`page.goto: net::ERR_ABORTED`) at 11:12, when the emulator lane's APK build and the app loop's tests were loading the machine (46 s and 50 s). Re-run on their own straight after the suite, both passed with no axe violations, in 23.4 s each. They loop through 12 pages in one test, so under load they sit close to the limit. `test.slow()` would make them sturdier; `tests/ux-web-legal.spec.ts` is held with the other session's legal work, so it was left as is.

**What this settles:** WP50's three acceptance checks hold, and b5's round check passes. WEB-9 keeps its status (`device-check`): the real AI, microphone and Turnstile are still for a phone and the deployed site.
