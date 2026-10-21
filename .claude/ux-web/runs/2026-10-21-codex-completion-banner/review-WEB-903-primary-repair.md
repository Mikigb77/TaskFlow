# WEB-903: verification of the first primary-session repair

The first primary-session repair uses one instant pointer scroll, including a zero-distance call when the banner is initially visible. It is source blob `6dd78eb39d8521869d9ac864c6455591357bdccc`, production build `qOg5wXStCMHWAGD_J2Ali`. The three workflow source rounds remain exhausted; further source ownership belongs to the primary session.

The original CA dark realistic mobile case passed after this repair. All 46 affected behavior checks passed, exit 0. These are bounded checks on the primary repair, not a replacement claim for the broader full suite on the earlier source revision.

The subsequent completion capture matrix stopped after 22 passes, five intentional skips and one failed desktop EN/light/standard stress case. Its visibility assertion runs before audit and locator screenshots; screenshot-induced repositioning does not explain the failure. The banner was outside the viewport. Failure evidence is preserved in `../TaskFlowWeb/artifacts/ux-web/completion-banner/failures/primary-repair-render/`. The matrix was not complete, and WEB-903 remains unresolved.

## Exact-case investigation

One instrumented isolated EN case passed, exit 0. Root/body text was 16 px, using a real title click and natural native input focus. The forwarded input click occurred at 4547.1 ms; the product instant scroll at 4553.8 ms moved Y 2037 to 1376; native input/change followed at 4555.5–4555.6 ms. A later browser scroll at 4637.1 ms moved Y to 1187. The banner ultimately remained visible at 284–373 px below the 87 px header. This diagnostic does not invalidate the original failure.

The same natural-focus EN case then repeated five times with minimal logging, one worker, the unchanged 1200 ms settlement and unchanged visibility assertion: five passed, exit 0, 55.4 seconds. Each had one instant call at Y 1508, top −131.859375, with the final checkbox active. Native input/change followed within 0.2–0.8 ms at Y 1376; the subsequent scroll event remained at Y 1376. Banner bounds settled at 95–184 px, with input identity and focus preserved. No repeat reproduced the matrix failure, so the failure remains authoritative and unresolved.

Raw records are in `../TaskFlowWeb/artifacts/ux-web/completion-banner/positions/en.desktop-standard.light.diagnostic.json`, `desktop.en.desktop-standard.light.render.json`, and separate `en.desktop-standard.light.repeat-{0..4}.diagnostic.json` / `desktop.en.desktop-standard.light.repeat-{0..4}.render.json` files.

## Independent recommendation

The independent reviewer confirms that the synchronous effect can measure and scroll before native checkbox activation finishes. One cancellable animation frame is a defensible targeted candidate, not yet a verified solution: schedule once for a qualifying pointer completion, read bounds/header clearance inside the callback, then perform the existing instant reveal or zero-distance cancellation. Cleanup must cancel on completion reversal, reset or unmount. Preserve keyboard/assistive guards, native focus and the one-shot latch. Add no loop, timeout, focus operation or global CSS.

Verification must retain the original EN desktop and CA mobile cases, native activation ordering, one pointer operation, zero keyboard/assistive calls, stable identity/focus, header clearance and strict undo stability. Add deterministic undo/close-before-frame checks so a cancelled callback cannot scroll later. For an already-visible banner, measure displacement at the actual call and distinguish earlier insertion anchoring from product movement.

The reviewer changed no files and ran no checks. The tester's exact-case probes changed only the owned test harness. Broader captures, scoped home/demo, performance and Windows WebKit checks remain pending.
