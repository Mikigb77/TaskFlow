## UX verify — run 2026-10-18-commands, round 2, area A (P146) — 2026-10-18
**Verdict:** Ship. UX-1212 is fixed. The change is navigation only, with no copy or layout change, and it causes no regression.

### UX-1212 · fixed
- `App/lib/screens/voice_task_screen.dart:3067-3073`: on Deshacer, when `projectsBack && page != null && page.isActive`, the code now runs `navigator.popUntil((route) => route == page); navigator.pop();`. That closes every route above the Física page, such as the task screen, and then the page itself. `removeRoute` is gone. The comment now says the page closes "with anything opened from it".
- What didn't change, as the brief asked: `opensProject` and the page push (:2986-3009), the message, the rest of the Deshacer (:3039-3066, :3074-3120), and the Calendar path.
- The result reopens over the screen under the page, through `showCaptureSheet(navigator.context, …)` (:3112-3119).
- Test: `App/test/voice_command_cards_test.dart:2889-2943`. It opens the task screen from the lit row, then taps Deshacer. Afterwards there's no TaskDetailScreen and no page; the CaptureResult shows the draft with `newProject: 'Física'`, the project is taken back, and no task exists. The P129 check also still passes, per ux-tester.
- Evidence: verified in code, plus a widget test. No preview covers this step, and it has no visual change, so there's no render to compare.

### Regressions
None.

### Notes (not regressions)
- When the page is already on top, `popUntil` stops at once and `pop()` closes the page, the same as before.
- If the person leaves the page with Back first, `page.isActive` is false and nothing is popped, the same as before.
- A capture sheet opened from the page can't be closed by this Deshacer: opening the sheet hides the earlier message (`voice_task_screen.dart:489-495`).
- Theoretical case: a Pro account opens another full screen with typing above the Física page while the message still shows, then taps Deshacer. `popUntil` would close that screen too, bypassing its leave question. This needs a deliberate Deshacer of the project that screen belongs to, and the old code left such a screen pointing at a deleted project. Not worth a fix.
