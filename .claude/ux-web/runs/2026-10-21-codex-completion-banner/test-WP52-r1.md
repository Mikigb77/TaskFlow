# Independent WP52 round1 — failed AC3

Configured tester gpt-6.1-sol/xhigh; only `tests/ux-web-completion.spec.ts` changed. Group placement/identity/focus/modality/assistive/reduced-motion/overflow attribution coverage added. Test files frozen and lane returned before source repair.

- Production `SITE_URL=https://taskflow.garbar.tech npm run build`: exit0; BUILD_ID timestamp17:15:07UTC.
- Focused `npx playwright test tests/ux-web-completion.spec.ts --grep-invert "completion render" --workers=4 --reporter=dot`: exit1,36passed/4failed.
- Windows Git diff whitespace: exit0.
- An accidentally premature focused runner was cancelled before tests began: exit1; log retained. It is not passing evidence.

Two normal-motion desktop failures required incidental +10px header clearance; actual banner was unobscured with7.61px. The test was corrected to actual header boundary; rerun pending. Two mobile failures are product defects with unchanged acceptance: normal-motion native input.tap/title span.tap produce no reveal call, banner top−783.39/bottom−694.80, same native input/focus retained. Reduced-motion mobile instant reveal and desktop smooth reveal emit correct single calls. Root suspects zero-delay pointer-up expiry before compatibility click.

Repro: mobile iPhone13 Chromium hasTouch,390x664,no-preference; EN COMPLETION_TASKS14-line notes; generate/check0/check1; instant center/focus final index2; wait350ms; instrument scroll; input.tap or label span.tap; wait1200ms. Exact names: `WP52 no-preference input: final activation below tall notes reveals only for pointer or touch once` and same `title`.

Failure bundle archived `../TaskFlowWeb/artifacts/ux-web/completion-banner/failures/round1/{test-results,positions,focused.log}`. Mobile measurements17:17:10–17:17:14UTC. No fresh preview certified. Full required suite, visual matrix, rapid cancellation and native device checks remain pending. State gating, details/locales, keyboard identity/focus/status and no-side-effect acceptance passed their focused cases; overall round FAILED AC3.
