## Verify — run 2026-10-19-app, b3 follow-up round 1, area B — 2026-10-20

Scope: P209 (UX-1639, UX-1633). Changed files: `App/lib/screens/day_timeline_screen.dart`, `App/test/day_timeline_test.dart`, `App/test/ux_previews/calendar_previews.dart`.
Renders: `calendar/timeline.untimed` and `timeline.normal` (es light 1x/2x, ca light 2x), rendered at 16:48–16:49, after the screen's last edit (16:27). No app file is newer than them, so they count as evidence. AUDIT.md is from 16:49.

### Results

| ID | Result | Evidence |
|---|---|---|
| UX-1639 | fixed (device check open) | `day_timeline_screen.dart:582-659` `_UntimedCap`/`_RenderUntimedCap`: the cap is `min(space/2, max(space/3, headBottom))` (`:651`), measured during layout. `_headBottom` (`:611-633`) adds the head's height to its offsets up to the cap (the 4 dp top padding is included; the viewport's child has no box offset, so it reads the unscrolled position). The head is `_UntimedHead` (`:343-350`): the label plus the first item with its 8 dp gap. Content shorter than the cap keeps its own height (`:652`). Render `timeline.untimed.es.light.2x`: «SIN HORA», the whole «Pagar la factura de la luz» card with «Prioridad Media», the full-width line (y about 466 dp), then 08:00 and the 08:30 block, all above «Añadir tarea». `ca.light.2x` is the same with «Prioritat Mitjana». `es.light.1x`: the area is its content's height. AUDIT no longer reports cut text for the row at 2x; its only cut text is the 10:00 timeline block, «Llamar al médico…», which was already there. The tester's tests for all 7 acceptance checks pass; `expectUntimedCap` (`day_timeline_test.dart:451-466`) checks the rule to within 1 dp and never past half. Still open: the emulator check at font size 2.0 on 393 dp, where Android grows text non-linearly. |
| UX-1633 | fixed | The structure is unchanged: notices sit in the Column (`:245-277`), «Sin hora» is pinned with its own `Scrollbar` and `timeline-untimed` scroll, and the hours are `Expanded` (`:309-311`). Arrival sees the final size on the first frame. The first layout tries the previous cap (or half), then lays out again at the final cap in the same `performLayout` (`:648-657`), with no post-frame `setState`. The new tests (`day_timeline_test.dart:951-974`) read the area's size on the offstage first frame, on the first visible frame and after the view settles; all three sizes match. In the renders, the 08:30 block is on screen on arrival in `untimed` (1x/2x, es/ca) and in `normal` (no «Sin hora», no line, opens on 08:00). |

### Regressions (changed files and the flows they touch)

None found. Checked:
- **Changing day (‹ ›):** the cached cap is tried first, then the area is laid out again whenever the content doesn't fit both the tried cap and the new one. A day with a shorter head shrinks, and one with a longer head grows, in the same frame.
- **First item an all-day phone event:** the head is the `ListTile`, with no 8 dp gap, which is correct.
- **A first row taller than half:** for example a very long title at 2x. The cap stops at half and the row scrolls inside the area under the visible scrollbar. This is the brief's rule, not a regression.
- **The saved-task highlight and `_reveal` in the area:** the new_task_form test passes; the `_landedRow` key is still on the row's Padding.
- **The line under the area:** it stays in place while the hours scroll, in light and dark, at 1x and 2x (tested).
- **TalkBack order** (AUDIT `es.light.1x`): the title, the day header, «SIN HORA», the row, then the hours. Unchanged.

Note, not a regression: the notices still have no height cap (already noted on UX-1633). With the area now allowed up to half the space, a load error and the calendar-access button at 2x would leave the hours less room than before. The arrival tests with each notice pass, so the first timed item still shows in the cases tested.
