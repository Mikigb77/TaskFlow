# WP52: independent tester handoff

Configured tester: `gpt-6.1-sol` / `xhigh`. Source and tests are frozen. No unresolved completion failure remains in the exercised browsers. The tester edited only `tests/ux-web-completion.spec.ts`; product changes belong to the implementer and, after escalation, the primary session.

## Final revision

- Production build: `bSZvNw1l8TvXtRVFnBq4Z`, BUILD_ID time 2026-10-21 18:15:39 UTC.
- VoiceDemo Git blob: `50141eab8ad5cb28543658954ced9445d903678e`; SHA256 `C4DF08AA6F6BD688DF3C159B18C9D89689C502DFDB3BAFA71C5FE5854B8FAA97`.
- Completion test Git blob: `b08b9518078c2d68b6a94415a1b11df1aeaa675b`; SHA256 `963663049CD4C6FD47B308B79AF5EC546BCF77B59D8286A82E652A35DDCED3F4`.
- Banner CSS blob remains `66b2effe377f65d382dbb7818d7a755a735eeea2`.

Website Node/npm/Playwright commands ran in the WSL `kali-linux` website checkout after sourcing nvm. Pipeline exit statuses were preserved. Windows Git and Python stayed on Windows.

| Final-revision command | Actual result |
|---|---|
| `SITE_URL=https://taskflow.garbar.tech npm run build` | Exit 0 |
| `UX_RENDERS=1 npx playwright test tests/ux-web-completion.spec.ts --grep "desktop.*WP52 completion render en light standard\|mobile.*WP52 completion render ca dark realistic" --workers=1 --reporter=dot` | Exit 0; original two failure paths passed, 49.2 s |
| `npx playwright test tests/ux-web-completion.spec.ts --grep-invert "completion render" --workers=4 --reporter=dot` | **Exit 1; 49 passed, one initial textarea setup timeout**, 2.5 min |
| `npx playwright test tests/ux-web-completion.spec.ts --project=mobile --grep "WP52 rapid close:" --workers=1 --reporter=dot` | Exit 0; unchanged exact case passed, 10.1 s |
| `UX_RENDERS=1 npx playwright test tests/ux-web-completion.spec.ts --grep "WP52 completion render" --grep-invert "desktop.*WP52 completion render en light standard\|mobile.*WP52 completion render ca dark realistic" --workers=4 --reporter=dot` | Exit 0; 52 passed, six intentional desktop-w320 skips, 1.6 min |
| `npx tsc --noEmit` | Exit 0 |
| `UX_RENDERS=1 npx playwright test tests/ux-renders.spec.ts --grep "render home \|demo home voice-(result\|no-tasks)" --grep-invert "perf " --workers=6 --reporter=dot` | Exit 0; 36 passed, 12 intentional skips, 32 s |
| `UX_RENDERS=1 npx playwright test tests/ux-renders.spec.ts --grep "perf home " --workers=1 --reporter=dot` | Exit 0; three mobile passed, three desktop intentionally skipped |
| `git diff --check` | Exit 0 |

The 50-case command remains exit 1. The lone failure happened while initially filling the textarea: the DOM remained in capture/voice mode, Type instead was focused, and no textarea or task had been generated. The trace shows stability/viewport retries and a dispatched click; actual mode-handler activation is unproven. The unchanged isolated retry supplies that case's completion evidence. No helper/product fix, clean original batch or repaired setup instability is claimed. Failed evidence is retained under `completion-banner/failures/frame-repair-focused/`.

All four undo/close-before-frame cases passed in the original 49. They hold a public frame boundary around real mouse/touch completion, assert zero calls before cancellation, then release it and assert no stale reveal. Existing rapid-after-start checks wait for the first observable reveal and retain strict later-motion/focus checks. Original natural-focus visibility assertions remain at 1200 ms, without prepositioning or longer waits.

## Acceptance and visual evidence

All seven criteria are covered by the scoped source/browser evidence; independent review is in `verify-HG.md`. Physical devices and native screen-reader output remain pending.

There are 54 fresh completion regions and 108 PNGs, captured 18:17:05–18:23:39 UTC after the final build. All locale/theme/device combinations and relevant realistic, stress, w320, actual root32 and spacing variants are included. Axe violations/incomplete/clipped text are 0/0/0; minimum completion contrast is 5.13:1 and minimum measured label area is 222 × 47 px. Twelve audits prove actual root32. Current keyboard samples retain input identity with no explicit completion scroll. The primary session approved the fresh realistic EN desktop and mobile previews.

The original EN desktop and CA mobile diagnostic records show native change preceding the instant reveal by 3.8 ms and 5.9 ms respectively. The banner remains below the header and the checkbox node/focus survives in Chromium. Status, local-only toggles, reset paths, task details and one group-level banner pass focused assertions.

The 40 fresh generic home/demo audit rows span 18:24:45–18:25:06 UTC. Older legal rows in the merged generic index/audit are historical and are not certified by this run.

## Existing badge overflow and measurement correction

Fixed-viewport raw audits reproduce WEB-801 in four mobile root32 states: ES 32 px and CA 16 px, light and dark. The sole offender is `.voice-topline > .voice-trial-badge`; completion/list bounds pass. Some geometry records show zero because mobile `window.innerWidth` expanded to 422/406 px. The tester's initial zero-overflow summary was corrected; generated INDEX/AUDIT explain this distinction, and raw evidence was preserved. No badge fix or new capture is claimed.

## Home lab performance

| Locale | Median LCP | CLS | Measured TBT |
|---|---:|---:|---:|
| EN | 1728 ms | 0 | 617 ms |
| ES | 1900 ms | 0 | 924 ms |
| CA | 1804 ms | 0 | 817 ms |

The scoped performance command passed its existing assertions. These TBT values are measurements, not a TBT-budget pass or physical-device result.

## Windows WebKit

The existing interpreter `C:/Users/mikig/.taskflow-tools/webkit/venv/Scripts/python.exe` and `.claude/ux-web/webkit_renders.py` were reused with runtime page/output scope overrides only; no helper source was edited.

- Initial home helper: 24 PNGs, helper exit 0. The combined Python process then exited 1 on the invalid assumption that tapping must leave a checkbox focused.
- First classification attempt: exit 1 before the site, from an unstyled native-baseline hit-testing timeout. Its evidence is retained.
- Corrected bounded classification: exit 0, actual English URL/lang/heading asserted. Partial and final taps both natively move activeElement to BODY before input/change. The completed task retains the same input and native context. One instant call leaves the banner at 81.625–170.219 px below a 73 px header at 1200 ms.
- Assistive-style native-click undo: no additional reveal call and zero residual movement over 900 ms. Separate keyboard Space completion/undo retains input focus/identity, adds no scroll call and has zero residual movement. These methods are recorded separately from real touch activation.
- Windows WebKit inherited Spanish Accept-Language, so the initial eight EN-labeled home PNGs actually showed the Spanish redirect. Those originals are preserved under `webkit-home/history/locale-mismatch/`. Only those eight PNGs were replaced with locale `en-US` and actual URL/lang/heading assertions: exit 0, 18:32:39 UTC. ES/CA explicit paths and their original 16 captures were verified.

Current evidence is `completion-banner/webkit-home/INDEX.md`, `webkit-probe/native-focus-classified.json` and `webkit-probe/completion.en.mobile-webkit.light.png`. This is Windows WebKit evidence, not iPhone/Safari or native assistive-technology proof. WEB-701 remains separate.

## Prior-round coverage and preserved failures

The workflow ran three implementer source rounds, then escalated WEB-903 to the primary session without restarting or resetting the count. See `test-WP52-r1.md`, `test-WP52-r2.md`, `review-WEB-902.md`, `review-WEB-903.md`, `review-WEB-903-primary-repair.md` and `escalation-WEB-903.md`.

On pre-primary-repair source blob `08fd04c9ff12f23558cc1b9b3c46572ec16864e0`, build `odml96HNcvwi43MYd41Kx`, required `npm run check`, `npm run legal:check`, `npm run test:unit` (9/9), and `npm test -- --reporter=dot --workers=4` exited 0. The full suite had 1,034 passes and 300 intentional skips in 19.7 minutes. **It does not certify the final source.** The primary session explicitly limited final verification to affected behavior and agreed home/performance/WebKit evidence; no second broad suite was run.

The first primary repair (`6dd78eb`, build `qOg5wXStCMHWAGD_J2Ali`) passed 46 behavior cases but failed one subsequent EN desktop capture. The isolated diagnostic and five natural-focus repeats passed; they did not erase that failure. The current frame repair addresses the observed activation ordering and passes the original paths plus the fresh matrix. Generated `.tsx` provenance snapshots initially caused a build exit 1; renaming only those evidence files to `.tsx.txt` preserved hashes and allowed build retry exit 0 without a product/tsconfig change.

## Evidence and cleanup

Base directory: `../TaskFlowWeb/artifacts/ux-web/completion-banner/`. Current `INDEX.md`, `AUDIT.md`, `audit.json`, `.audit/`, `positions/`, `logs/`, all failed rounds/probes and prior evidence archives are preserved. No real AI, microphone, permissions or Turnstile call was exercised; voice/external requests were stubbed.

Owned server session 20139 was stopped only after verifying listener PID 50661, parent `next start` and the exact website checkout. Ctrl-C intentionally returned 1. The subsequent verification exited 0 and proved port 3000 free and the owned PID absent. No other process or WSL session was stopped.
