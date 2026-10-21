# Independent WP52 round2 — repaired touch; new cancellation defect

Configured tester gpt-6.1-sol/xhigh. Only completion spec changed; frozen and lane returned before further source repair. Total planned focused coverage46cases (8first+38complementary); only first8ran due source failure.

- Production build: exit0, BUILD_ID mtime17:21:00UTC.
- Initial filtered invocation: exit1 at collection (launchOptions scoped inside describe). Moved fake-device flags to spec top level, preserving assertions; no browser case ran. Log retained.
- Exact8retry: exit1,4passed/4failed,35s. All four original normal-motion desktop/mobile input/title cases passed. Four rapid undo/close cases failed.
- Windows Git diff--check: exit0.

NEW symptom WEB-902: after completion banner is removed and two animation frames permit layout/anchoring, native smooth scroll initiated by completion continues for another207px(desktopundo),579px(mobileundo),583px(desktopclose),1080px(mobileclose) over900ms. There is only the initial scrollBy smooth call, no new call afterclear, and no legitimate close stage scrollIntoView in raw observations. This is distinct from repaired WEB-901 touch-origin tracking. Both rapid undo and rapid close fail on both projects.

Evidence: `../TaskFlowWeb/artifacts/ux-web/completion-banner/failures/round2/{test-results,positions,focused.log}`. Raw *.rapid-*.cleared.json contain started/cleared/later coordinates and calls; captured17:22:04–17:22:17UTC after current build. No fresh preview certified. Complementary38, renders, required type/legal/unit/full regression and physical/native AT checks remain pending. Acceptance is failed, not inferred from the four repaired cases.

Independent review qualification (review-WEB-902.md): the TWO rapidundo cases independently prove the product defect. The two close cases may include legitimate existing openButton.focus() native scrolling under root smooth CSS. Preserve all four original failed bundles, but do not claim close motion is solely completion-owned. Final close acceptance verifies its established opener focus/visible destination after settling; strict rapidundo no-later-motion remains unchanged.
