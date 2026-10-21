# WP51 independent verification — H/G

Returned by configured `taskflow_ux_reviewer`, Sol 6.1/max, 2026-10-21. The reviewer edited no files and ran no tests, builds or captures.

**Verdict: WP51 is verified for its scoped completion behavior. No completion defect or blocker was found. Native-device checks remain pending.** Product changes are confined to the six assigned files against ownership base `66e06b3`.

| Acceptance | Independent source/evidence verification |
|---|---|
| Initial/partial/empty/loading/failed states never reward | `VoiceDemo.tsx:290–311` guards review, nonempty result and errors; current browser regressions at `tests/ux-web-completion.spec.ts:141`, `:222`. |
| Fully checked result rewards; tasks/details remain | `VoiceDemo.tsx:986–1030`; detail preservation at test `:179`; fresh realistic EN/ES/CA desktop/mobile PNGs in both themes. Reward follows final-toggled title before details. |
| Undo/recheck/new result/reset | Local handler and resets at `:453`, `:499`, `:595`, `:630`, `:1053`; browser coverage at test `:173`, `:193`, including identical new results. |
| Local, stable native inputs; no extra requests/quota/storage/forced scroll | Local React state only; request/storage/quota assertions at test `:182–186`; raw positions show 96 toggles with zero identity failures/explicit scroll calls and 60 insertions with zero input/page shift. Natural undo row collapse is explicitly accepted and logged. |
| One localized polite atomic status and title labels | `VoiceDemo.tsx:712`, `:762`, `:990`; native name/status mutation checks at test `:151`, `:169`. Visual block is not live; leaf is decorative. AX-8/9, ML-5. Spoken native output remains pending. |
| Responsive/theme/language/text/motion | 54 fresh measured regions, 108 PNGs; zero axe violations/incomplete and clipped text. All 12 text200 records measure root 32 px, reward fonts 36/32 px. Reward contrast minimum 5.13:1 light and 7.33:1 dark. Actual label measurements exceed 44 px; missing duplicate cells remain unmeasured. Reduced motion removes the finite 260 ms reveal. AX-2/3/4/7, ML-5/7. Existing badge overflow is scoped below. |
| Checks and freshness | Build/check/legal/unit passed; 9/9 units. Original full Playwright remains **exit 1: 1,006 passed, 300 intentional skips, eight failed**. Six rejected undo-coordinate expectations and two WD16 checkbox conflicts each passed its exact corrected rerun in the **26/26 exit-0** follow-up; post-edit type check passed. No product source changed. Full mapping/log provenance is in `test-WP51.md`. |

Product source timestamp is 09:01:30 UTC, build `mVLJlrQHFYPpNKt4mX1vh` is 09:04:55 UTC, and corrected text200 captures/audits are 09:35–09:36 UTC. Evidence is `TaskFlowWeb/artifacts/ux-web/completion/{INDEX.md,AUDIT.md,audit.json,.audit/,positions/,logs/}`. This is browser/preview proof, not a whole-site or physical-device pass.

## WEB-801 · S2 · G · open — Localized tries badge overflows at doubled phone text

**Rules/impact:** AX-3, ML-7. Spanish/Catalan visitors with doubled text must pan horizontally to read the available-tries badge.

**Source:** `src/styles/voice.css:18` (`flex-shrink: 0`, `.875rem`), `.voice-topline` at `:225`; topline markup `VoiceDemo.tsx:741`; ES `triesLeft` at `es.ts:152`, CA at `ca.ts:158`.

**Reproduction:** At 390 CSS px and actual root font 32 px, open `/es/` or `/ca/`, generate a stubbed result leaving two tries, in either theme.

**Measured evidence:** The sole offender in raw `audit.json` is `div.container > div.voice-panel > div.voice-topline > span.voice-trial-badge`. ES: left 37, width 385, right/scrollWidth 422, overflow 32 px. CA: left 37, width 369, right/scrollWidth 406, overflow 16 px. All four records have root 32 px; no completion element is an overflow offender. Corresponding mobile-text200 PNGs show completion context; the badge is partly above the viewport, so raw bounds are decisive.

**Independent attribution:** The reviewer compared badge CSS, topline CSS/full markup and all EN/ES/CA `triesLeft` strings against `66e06b3`; all are unchanged. WP51 adds only checkbox/reward selectors. This existing issue is outside WP51 and does not block scoped completion verification. No exact duplicate was found; WEB-309/310/715 describe different frame/header symptoms. The primary session expressly retained this bounded scope; no CSS redesign/build round is authorized here.

**Acceptance for a future fix:** Keep the full badge inside panel/viewport at 390/root32 in ES/CA, both themes, with Close demo operable; retain normal-text 320 px reflow.

## Claims and limits

Completion adds React state only; no API, browser-storage or account-save operation. Existing localized fine print says nothing is saved to the app. The demo draft route returns results (`src/app/api/voice/draft/route.ts:87–91`); completion is an app concept (`App/lib/models/task.dart:251`, `Backend/core/models.py:221`). The aspirational “Imagine…” copy adds no persistence/capability promise.

Physical-phone interaction, TalkBack/VoiceOver announcements and a native Catalan read remain pending. The existing Windows Python WebKit helper's 112 PNGs are page/engine smoke, not completion proof on Safari/iPhone and do not resolve WEB-701. Voice/API interactions were stubbed.

Suggested verified memory: WD16 supersedes WEB-7's earlier no-ticking rule for this bounded demo result; preserve stable native inputs, final-toggled-title reward, one atomic status and reset behavior. Keep WEB-801 separate; never claim all 54 page records have zero overflow.
