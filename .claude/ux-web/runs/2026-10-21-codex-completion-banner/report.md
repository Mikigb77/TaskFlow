# Completion banner — verified bounded correction

**WP52 / WD17: browser scope verified.** One full-width completion banner now sits immediately above the entire generated-task list, outside every task card. Tasks/details, native controls, undo, the existing EN/ES/CA copy and one atomic polite status remain. No broader page redesign, API, quota or storage change was made.

Pointer/touch completion uses one cancellable animation frame to measure current geometry after native activation, then instantly reveals offscreen feedback or cancels pending native focus movement without displacement. Keyboard/assistive activation keeps reading context and makes no explicit completion scroll. Undo/reset cancel pending work. The primary session approved the fresh desktop/mobile previews.

## Verification

See [independent verification](verify-HG.md) and [exact commands, exits and evidence](test-WP52.md).

| Final revision | Result |
|---|---|
| Production build / TypeScript | Exit 0 / 0; build `bSZvNw1l8TvXtRVFnBq4Z` |
| Original EN/CA failure paths + remaining captures | Exit 0 / 0; 2 + 52 passes, six intentional skips |
| Completion behavior batch | **Exit 1: 49 passes, one pre-completion setup timeout**; unchanged exact retry exit 0. No product fix from retry claimed. |
| Scoped home/demo / home performance | Exit 0 / 0; 36 + 3 passes, 12 + 3 intentional skips |
| Classified Windows WebKit + corrected EN captures | Exit 0 / 0; native tap/keyboard behavior and actual locale verified |

All 54 completion regions / 108 PNGs are current after the build: axe violations/incomplete/clipping 0/0/0, 12 actual root32 audits, minimum contrast 5.13:1 and label size 222 × 47 px. The 40 fresh generic home/demo rows pass; historical legal rows are excluded. [Current index](../../../../../TaskFlowWeb/artifacts/ux-web/completion-banner/INDEX.md) contains the previews and measurements.

The earlier full suite exited 0 with 1,034 passes / 300 skips on source `08fd04c`, build `odml96HNcvwi43MYd41Kx`; **it does not certify final source `50141eab`**. Its type/legal/unit gates also passed. Three worker source rounds and both primary-session repairs remain explicit in the [escalation record](escalation-WEB-903.md); no round count was reset or broad suite repeated.

## Issues and limits

WEB-901/902/903 move to **device-check**. WEB-801 remains open: only the trial badge overflows at root32 (ES 32 px / CA 16 px, both themes); completion/list bounds pass. WEB-701 remains the separate WebKit font/device question. Native phone/Safari, TalkBack/VoiceOver, native Catalan copy, real speech/permissions and real Turnstile remain unverified. Lab performance is recorded without claiming a TBT budget, field INP or p75 Core Web Vitals pass.

## Ownership and cleanup

Website commit **`406a1159588aec412134f13aaecb0b3291a178a3`** contains only the component, banner CSS and completion test. Ownership helper and staged-diff checks exited 0; see [receipt](stage.log). The website is clean on dev. App records use explicit owned paths; the final handoff and ignored `completion-banner/ownership-app.json` receipt record the records-commit and foreign-index preservation outcome.

Global review refs remain unchanged because this bounded review does not acknowledge the broader site/app diff; exact refs are in [run.json](run.json). Verified owned server PID 50661/session 20139 is stopped, with port 3000 free. Other sessions' work is preserved. Nothing was pushed, merged, deployed or changed on a phone.
