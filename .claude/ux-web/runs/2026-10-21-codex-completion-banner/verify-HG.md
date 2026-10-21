# Independent verification of the completion banner

Configured reviewer: `gpt-6.1-sol` / `max`. The reviewer changed no files and ran no tests, builds or captures. **All seven acceptance criteria pass for the approved browser scope; no unresolved product finding remains within that scope.** WEB-901, WEB-902 and WEB-903 move to device-check. Home performance and scoped Windows WebKit evidence are complete.

## Provenance and freshness

Product source is VoiceDemo blob `50141eab8ad5cb28543658954ced9445d903678e`, production build `bSZvNw1l8TvXtRVFnBq4Z`, BUILD_ID time 2026-10-21 18:15:39 UTC. The reviewer confirmed all 54 region audits, their metadata and 108 PNGs are newer than this build, with no missing or stale files. Audit timestamps span 18:17:05–18:23:39 UTC.

Evidence is in `../TaskFlowWeb/artifacts/ux-web/completion-banner/{INDEX.md,AUDIT.md,audit.json,.audit/,positions/}`. Fresh screenshots inspected include realistic, stress, actual doubled text, 320 px and spacing states across EN/ES/CA and light/dark themes. The primary session independently approved the fresh realistic EN desktop card at 18:22:18 UTC and mobile view at 18:22:53 UTC, with no further visual change requested.

The earlier 1,034-pass/300-skip full suite applies to pre-primary-repair VoiceDemo blob `08fd04c9ff12f23558cc1b9b3c46572ec16864e0`, build `odml96HNcvwi43MYd41Kx`. It does not cover this final source revision. Failed and provisional evidence remains archived; the workflow's three source rounds were exhausted and both later primary-session repairs are explicit escalations.

## Acceptance findings

| Criterion | Independent finding |
|---|---|
| AC1 / WEB-901: placement | Exactly one full-width banner precedes the complete generated task list as a sibling outside every task card. Nonempty/all-complete gating remains. |
| AC2: details and localization | Existing task titles, dates, notes, questions and EN/ES/CA completion copy are preserved. Desktop columns and mobile stacking remain. |
| AC3 / WEB-903: discoverability | The original EN desktop stress and CA dark realistic mobile cases pass with natural title activation and unchanged 1200 ms visibility assertions. Current diagnostics put the instant reveal after native input/change, and both banners remain visible below the header. Inputs retain identity and focus. |
| AC4: keyboard and status | All 98 current keyboard samples have zero identity failures and zero explicit scroll calls. Native inputs, modality guard and one existing atomic polite status remain; the visual banner adds no live region. All 54 regions contain one polite status. |
| AC5 / WEB-902: undo, reset and locality | Current rapid undo/close records have zero later displacement or additional completion calls. All four before-frame cases start with zero calls and retain zero calls after undo/close and frame release. Source/focused assertions cover reset paths, single status update, detail preservation and unchanged network/quota/storage. |
| AC6: accessibility and layout | Zero axe violations/incomplete results and zero clipped text. Twelve audits prove actual root32 text. Minimum completion contrast is 5.13:1; minimum measured label activation area is 222 × 47 px. Reduced-motion records disable reveal animation. Completion/list bounds pass; known badge overflow is separate below. |
| AC7: independent checks | Final original cases: 2 passed. Remaining captures: 52 passed / 6 intentional skips. Final TypeScript, scoped home/demo, home lab performance and classified Windows WebKit evidence pass. The broader suite belongs to the earlier source, and the final behavior command's setup failure/retry is retained exactly below. |

The one-shot pointer latch is consumed before a single animation frame. Geometry is measured inside that callback; cleanup cancels it on completion reversal, reset or unmount, and the callback rechecks the banner ref. The existing instant operation includes a zero-distance cancellation when already visible to cancel pending native focus movement. Keyboard/assistive completion retains reading context and relies on the one polite status. No loop, timeout, focus call or global CSS behavior was added. Physical assistive technology remains unverified.

## Exact behavior-command provenance

The final 50-case behavior command **exited 1: 49 passed, one mobile rapid-close case timed out during initial textarea setup**. The failed DOM remained in capture/voice mode, with Type instead focused and no textarea or generated task. The trace contains stability/viewport retries followed by a dispatched click; actual mode-handler activation is unproven. This occurred before completion behavior.

The unchanged exact mobile rapid-close case then passed alone, exit 0, in 10.1 seconds. It supplies the missing case's completion evidence but does not establish that the setup instability was fixed. There was no product or helper edit and no broad rerun. All four before-frame cancellation cases passed in the original 49, including the independently requested zero-call precondition.

## WEB-801 remains open

The independent raw-audit review **reproduces** the historical trial-badge overflow at actual root32: Spanish 32 px and Catalan 16 px, both themes. The sole offender is `.voice-topline > .voice-trial-badge`; no completion element is an offender. The tester's initial zero-overflow summary was incomplete and must not override these raw records. No badge source changed, no new capture is needed, and no badge fix is claimed by this package.

## Final bounded home/demo, performance and WebKit delta

The 40 fresh non-performance home/demo records, 18:24:45–18:25:06 UTC, also have zero axe/clipping findings. Their command passed 36 cases with 12 intentional project skips. Older legal records in the generic merged audit were excluded from current verification.

Home performance completed three mobile passes and three intentional desktop skips. Three-run median LCP is EN 1728 ms, ES 1900 ms and CA 1804 ms; CLS is 0. Measured TBT is 617/924/817 ms respectively. These values do not establish a TBT-budget pass, field INP or p75 Core Web Vitals compliance.

The reviewer inspected final WebKit locale metadata, localized mobile folds and completion capture for build `bSZvNw1l8TvXtRVFnBq4Z`. Corrected EN images verify actual URL, lang and heading, while mislabeled originals remain preserved. The classified probe shows ordinary partial and final taps both moving focus to BODY before native input/change; the final tap preserves the input node and native context. One instant operation leaves the banner at 81.625–170.219 px below the 73 px header. Native-click undo adds no call or residual movement. Separate keyboard Space completion/undo retains input focus/identity, with no additional scroll and zero residual movement. No product focus workaround is warranted.

The failed original focus-assumption probe, unstyled diagnostic and pre-completion setup timeout remain classified evidence, not product fixes. Port 3000 is free after verified task-owned server cleanup.

Native phone touch/undo/reduced motion, TalkBack/VoiceOver announcements, Safari/iPhone font rendering (WEB-701), native Catalan copy, real microphone/AI and real Turnstile remain unverified. WEB-801 remains separately open with reproduced badge overflow. No additional product decision or source change is required for this approved scope.
