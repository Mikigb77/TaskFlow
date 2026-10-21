# Demo completion — verified scoped Codex run

**Run:** `2026-10-21-codex-demo-completion`; WP51; H with affected G completion states only. Current owner request authorizes implementation (WD16). **Verdict: scoped completion behavior is independently verified.** No completion defect was found. Native-device checks remain pending; the pre-existing trial-badge reflow issue WEB-801 is open outside WP51.

## Implemented

Generated tasks have local native checkboxes. A nonempty fully checked result shows a decorative leaf and a warm response immediately after the final-toggled title, before its date/notes. Every task/detail stays visible. Undo hides feedback; recording, submission, identical new results, Change text and close/reset clear completion. One existing atomic polite status announces it; the visual block is not a second live region. The finite 260 ms reveal stops under reduced motion. Toggles make no API, quota, storage or account-save change; they retain native input identity/focus and make no explicit scroll call.

- EN: “All clear. Take a breath.” / “Imagine a little more calm in your day.”
- ES: “Todo listo. Respira.” / “Imagina un poco más de calma en tu día.”
- CA: “Tot fet. Respira.” / “Imagina una mica més de calma en el teu dia.”

Product paths in TaskFlowWeb: `src/components/VoiceDemo.tsx`, `src/styles/voice.css`, `src/content/site/{types,en,es,ca}.ts`. Tester-owned changes: `tests/ux-web-completion.spec.ts`, `tests/support/ux-voice.ts`, and the narrowly updated `tests/voice.spec.ts` result expectation. Existing capture-stage zero-checkbox coverage is intact.

## Checks actually run

| Check | Actual exit/result |
|---|---|
| Scoped product whitespace check | 0 |
| `SITE_URL=https://taskflow.garbar.tech npm run build` | 0; BUILD_ID `mVLJlrQHFYPpNKt4mX1vh`, 09:04:55 UTC |
| `npm run check` | 0 |
| `npm run legal:check` | 0; identity/contact/publication configuration, not legal-compliance sign-off |
| `npm run test:unit` | 0; 9/9 |
| `npm test -- --reporter=dot` | **1; 1,006 passed, 300 intentional skipped, 8 failed; 20.2 minutes** |
| Bounded corrected follow-up | **0; 26/26 passed** |
| Post-edit `npx tsc --noEmit` | 0 |
| Existing Windows Python WebKit helper | 0; 112 PNGs, 0 not rendered; public page/engine smoke only |

The original full command remains exit 1. Six failures asserted invariant viewport geometry on natural desktop undo row collapse, which the primary session confirmed is acceptable. Two legacy failures prohibited WD16’s requested result checkboxes. Every exact original case passed its corrected rerun in the 26-case follow-up; the other cases add mobile DOM/focus/explicit-scroll probes and the 12 true doubled-text audits. All eight original bundles, log and exits are retained under `completion/failures/round1/`. `test-WP51.md` maps all eight individually. No product source changed after the green build, and no full suite/build was repeated.

## Fresh evidence and independent review

See `verify-HG.md` for all seven acceptance criteria and independent source/visual/measurement checks. Evidence is in `../TaskFlowWeb/artifacts/ux-web/completion/{INDEX.md,AUDIT.md,audit.json,.audit/,positions/,logs/}`. Product sources are 09:01:30 UTC; all captures follow the production build. Corrected text200 records extend through 09:36:35 UTC.

- 54 focused regions, 108 PNGs; zero axe violations/incomplete results and clipped text.
- All 12 text200 records measure root 32 px and reward fonts 36/32 px. Audit-before-tall-card ordering corrected the earlier font-reset measurement defect.
- Reward contrast minima: 5.13:1 light, 7.33:1 dark. Actual measured title labels are at least 284 × 47 px. Older duplicate label cells that were not measured remain explicit; they are not counted as measurements.
- 96 instrumented toggles: zero native input identity failures or explicit scroll calls. All 60 completion insertions have zero input/page displacement. Natural undo reflow is transparently recorded: e.g. desktop preceding-row collapse moves input y540.67→436.08 with focus retained and no explicit scroll; mobile anchoring adjusts scrollY while holding input position within 0.2 px.
- Ordinary captures: `completion.en.mobile-realistic.light.view.png` and `completion.en.desktop-realistic.light.view.png`, plus EN/ES/CA in both themes. Narrow/large-text/spacing/stress captures are indexed. Voice/API calls are stubbed and external calls blocked; no real AI budget is used.

The initial empty generic audit summary was invalid and is not passing evidence. The current focused audit uses actual region records, build/time provenance and formatted viewport dimensions. It does not certify global metadata or lab performance.

## WEB-801: existing baseline issue outside WP51

At actual root32 and 390 px viewport, the only overflowing element is `div.container > div.voice-panel > div.voice-topline > span.voice-trial-badge`: ES right/scrollWidth422 (32 px overflow), CA406 (16 px), both themes. No completion element is an overflow offender. Do not claim all 54 page records are overflow-free.

The independent reviewer compared badge CSS, topline CSS/full markup and every `triesLeft` string against ownership base `66e06b3`; all are unchanged. WEB-801 is S2/G, AX-3/ML-7, open in the shared ledger and skipped from this bounded package. Its reproduction, exact bounds and future acceptance are in `verify-HG.md`. The primary session expressly retained this scope rather than authorizing a badge redesign/build round.

## Commit and snapshot outcome

Both repositories stay on `dev`. Initial HEADs were app `b77341e6e8be46753fb41d84c97839797256203a`, website `772ee668d8ee5dd263c56bc95ff0b7e9374937ad`; initial indexes were empty. All unrelated edits/untracked files are preserved.

The ownership-aware staging helper **exited 1**. Exact receipt: `stage.log`. It refused `VoiceDemo.tsx`, the types/all three copy files, and `tests/voice.spec.ts` because their lines overlap earlier uncommitted work. It safely staged only CSS, the fixture and new completion spec. That partial staged diff was inspected, then exactly those three owned paths were unstaged. **The whole functional website package remains uncommitted; website index is empty and HEAD is unchanged.** No refusal was bypassed and no dependent partial commit was made. Shared records are the only app-repository commit candidates; the final handoff gives their commit result.

No global review snapshot advanced: website `refs/ux-web/last` remains `8de3f9c93428c1683ac068681adc3994446af485`; app `refs/ux-web/app-last` remains `791aa165a0c77929b951d0a8aeb3e0db3cbe4190`. Ownership base remains `66e06b3b7c6de8ff2462cc631974b4fb0294689d`. Unrelated pre-existing changes were not reviewed by this scoped run. Nothing was pushed, merged to main or deployed.

The task-owned server PID41359 was confirmed as next-server in the exact website checkout on port3000, then terminated by verified PID only. It and the listener are gone. Other servers/sessions were preserved.

## Checks still requiring a person/device

- Native TalkBack/VoiceOver announces completion once in the correct language and preserves checkbox context.
- Real phone/Safari touch, undo and reduced-motion behavior; a native Catalan copy read.
- Real speech, microphone permissions and real Turnstile remain unexercised. The Windows WebKit page smoke is not completion proof on an iPhone and does not resolve existing WEB-701.

No new owner product decision is unresolved. WEB-801 and ownership-held source remain explicit; the scoped completion implementation is ready in the working tree.
