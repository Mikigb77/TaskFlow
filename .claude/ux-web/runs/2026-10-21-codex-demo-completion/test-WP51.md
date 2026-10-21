# WP51 independent testing — round 1

Returned by configured `taskflow_ux_tester`, Sol 6.1/xhigh, 2026-10-21. Test/render lane is idle. No WP51 product regression was found; the existing localized trial-badge reflow issue remains visible for verifier attribution.

Owned test changes: `tests/ux-web-completion.spec.ts` (new completion regressions/evidence), `tests/support/ux-voice.ts` (`COMPLETION_TASKS` fixture), `tests/voice.spec.ts` (requested native result checkboxes supersede zero-input expectation). Existing unrelated edits and capture-stage zero-checkbox coverage remain intact.

| Check | Actual exit/result |
|---|---|
| Production build with `SITE_URL=https://taskflow.garbar.tech` | 0 |
| `npm run check` | 0 |
| `npm run legal:check` | 0 |
| `npm run test:unit` | 0, 9 passed |
| `npm test -- --reporter=dot` | **1**, 1,006 passed, 300 intentional skipped, 8 expectation failures, 20.2 minutes |
| Bounded completion/text200/legacy follow-up | **0, 26 passed** |
| Post-edit `npx tsc --noEmit` | 0 |
| Existing Windows Python WebKit helper | 0, 112 PNGs, 0 not rendered; page smoke only |

## Every original failure and its corrected rerun

The original full command remains exit 1. Logs/exits and all eight bundles were archived in `artifacts/ux-web/completion/failures/round1/` before test edits or reruns.

| Original case | Project | Corrected focused rerun |
|---|---|---|
| WP51 light / EN nonempty completion | desktop | Passed |
| WP51 light / ES nonempty completion | desktop | Passed |
| WP51 light / CA nonempty completion | desktop | Passed |
| WP51 dark / EN nonempty completion | desktop | Passed |
| WP51 dark / ES nonempty completion | desktop | Passed |
| WP51 dark / CA nonempty completion | desktop | Passed |
| `voice.spec.ts`: live text capture shows the tasks as the app does and the remaining tries | desktop | Passed |
| Same legacy live-text case | mobile | Passed |

Six completion failures asserted invariant geometry on undo when an earlier grid row naturally collapses. The primary session confirmed this normal flow is acceptable. Corrected tests retain native input DOM identity/focus and prohibit explicit scroll calls; completion insertion must preserve input/page coordinates. Two legacy failures prohibited the newly requested checkboxes. The narrow update retains the absence of fieldsets/selects/non-checkbox inputs and asserts two native initially unchecked title-labeled result checkboxes.

## Acceptance mapping

| WP51 acceptance | Independent result |
|---|---|
| No completion on initial/partial/empty/loading/error | Passed: browser regressions |
| Nonempty fully checked result rewards; all tasks/details stay | Passed: behavior tests and previews |
| Undo/recomplete, identical new result and close/reopen reset | Passed: focused/full-run tests |
| Local toggles, focus, no API/quota/storage change or forced scroll | Passed: 96 instrumented toggles, zero explicit scroll calls/identity failures; 60 insertions with exactly zero input/page displacement |
| One localized polite atomic status and native title labels | Passed for browser DOM/status mutation/accessibility names; native spoken output unverified |
| EN/ES/CA, themes, responsive/large-text/reduced-motion completion | Passed for new completion UI. Existing ES/CA trial-badge page overflow at doubled text is recorded below. |
| Required checks and fresh evidence | Composite evidence passes current acceptance; original full command remains exit 1 with exact eight corrected reruns passed. |

## Evidence and limitations

`TaskFlowWeb/artifacts/ux-web/completion/{INDEX.md,AUDIT.md,audit.json}` indexes 54 focused regions and 108 PNGs, with zero axe violations/incomplete results and zero clipped text. All 12 text200 records now measure root 32 px and reward fonts 32/36 px; capture/audit-before-tall-card ordering corrected the earlier font-reset measurement defect. Latest captures are 2026-10-21 09:36:35 UTC, after product source timestamp 09:01:30 UTC and production build timestamp 09:04:55 UTC. Minimum reward-text contrast is 5.13:1. Measured title labels are at least 284 × 47 px; older missing duplicate label cells stay explicitly pending rather than falsely measured.

Actual page overflow exists in four doubled-text phone records: unchanged `.voice-topline > .voice-trial-badge`, ES width 422 against viewport 390 (32 px), CA 406 (16 px), in light and dark. The completion block is not an overflowing element. Verifier must independently check the attribution against ownership base `66e06b3` before a baseline/out-of-scope classification is final.

`positions/` holds viewport/page coordinates, DOM identity, outline and explicit-scroll probes. `logs/` retains command exits; archived original failures remain in `failures/round1/`. All voice/API requests were stubbed and external requests blocked. No real AI budget was used.

`artifacts/ux-web/webkit/INDEX.md` is existing Windows Python engine/page smoke, not completion behavior or Safari on an iPhone. Real speech, Turnstile, native screen-reader output, permissions and physical-phone interaction remain pending. No product code, staging, commit, shared-record or review-snapshot changes were made by the tester.
