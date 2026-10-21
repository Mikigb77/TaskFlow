# Demo task completion — authorized scoped plan

Run `2026-10-21-codex-demo-completion`, round 1. Current owner request authorizes implementation; this is not a full-site review.

## WP51 — Reward completing every generated demo task

Add lightweight local completion checkboxes to generated result cards and a calm rewarding completion moment inside the existing demo card. Use a gentle decorative brand icon/subtle finite motion (honor reduced motion), brief natural EN/ES/CA copy and one polite announcement. Make feedback discoverable when the last remaining task is checked even with long mobile results, without forced scrolling or focus movement. Keep all card detail and surrounding retry path. Derive completion only for a nonempty fully checked list; hide/reset on undo, new result and close/reset. No voice/API/quota/backend or persistence changes.

Acceptance:

- Initial generation, partially checked tasks, zero-task results, loading and failed requests never show completion.
- Checking every task in a nonempty result shows localized warm completion feedback inside the demo card while all tasks, checkboxes and details stay visible.
- Undoing any task immediately removes feedback; rechecking can complete again. New results and closing/resetting begin with no checked tasks or lingering completion.
- Checkbox toggles are local, make no API calls, do not change quota and keep keyboard focus; completion never scrolls or opens a modal.
- One polite accessible announcement communicates completion in the page language, without repeated notifications for unchanged completion; checkbox names include task titles.
- Light/dark, desktop/mobile, EN/ES/CA, 320px, doubled text and reduced-motion states remain legible and operable; final-toggle feedback is discoverable without forced scrolling.
- Focused independent regressions and required check/legal/build/unit/Playwright suites pass; fresh affected screenshots and measured accessibility evidence support scoped review.

Independent tester owns only focused test/render support. Reviewer checks H/G changes and regressions using refreshed evidence. Existing global snapshots will not move because unrelated unreviewed changes remain.
