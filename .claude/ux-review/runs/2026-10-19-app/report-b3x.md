# UX loop report: run 2026-10-19-app, batch b3x (close, 2026-10-20)

**Verdict:** Batch b3x passed in one round. Package P209 fixed both findings. UX-1633 is verified. UX-1639 is verified in code but still needs a check on a phone at Android font size 2.0. No regressions, no escalations.

## Verified
- **UX-1633** · S2 · B: The Día view opened scrolled past «Sin hora» and its banners. Now verified again after P209 (verify-b3x-r1-B).
  - The layout is unchanged: the notices sit in the Column under the day header (`day_timeline_screen.dart:245-277`), «Sin hora» is pinned with its own scroll and scrollbar, and the hours fill the rest (`:309-311`).
  - The area's new size is worked out inside one layout pass (`:648-657`), so it is final on the first frame.
  - Renders: the 08:30 block is on screen on arrival in `calendar/timeline.untimed` (Spanish and Catalan, 1× and 2×) and in `timeline.normal`.
- **UX-1639** · S1 · B: At 2× text the only «Sin hora» row was cut off. Verified in code, so it is listed under Device check below.
  - The «Sin hora» area now gets a third of the space under the day header, or more if its label and first whole row need it. It never takes more than half (`_UntimedCap`/`_RenderUntimedCap`, `:582-659`, rule at `:651`). If the content is shorter, the area is only as tall as the content.
  - Renders `timeline.untimed.es.light.2x` and `ca.light.2x`: the whole «Pagar la factura de la luz» card shows, with «Prioridad Media» / «Prioritat Mitjana». Below it come the full-width line, 08:00 and the 08:30 block, all above «Añadir tarea».
  - AUDIT no longer reports cut text for that row.

## Still open
None from this batch.

## Escalations
None.

## Checks for the owner's phone
- **UX-1639:** In the Día view on a day with one task that has a date but no time (a «Sin hora» task), set Android font size to 2.0 on a 393 dp-wide screen. The whole row, including its priority line, should show inside «Sin hora», and the first timed item should still be on screen when the view opens. Android grows large text unevenly, so the renders can't prove this.

## Notes (not regressions)
- **Very tall first row:** if the first row is taller than half the space (for example a very long title at 2×), the area stops at half and the row scrolls inside it. The brief asked for this.
- **Notices have no height cap:** this was already noted on UX-1633. «Sin hora» can now take up to half the space, so at 2× a load error plus the calendar-access button leave the hours less room than before. The arrival tests with each notice still pass.

## Files changed
- `App/lib/screens/day_timeline_screen.dart`
- `App/test/day_timeline_test.dart`
- `App/test/ux_previews/calendar_previews.dart`
- `App/test/new_task_form_test.dart`

## Findings protected by a test
- **UX-1639:**
  - `App/test/day_timeline_test.dart`: `expectUntimedCap` at `:451-466` checks the size rule to within 1 dp and never past half. Tests at `:693`, `:739`, `:779`, `:795`, `:827`, and the new P209 tests at `:865` (Catalan 2×, whole row inside the area) and `:907` (Spanish 1×, the area is as tall as its content).
  - `App/test/new_task_form_test.dart:763`: a task saved from Thursday's Día view below another «Sin hora» row is highlighted whole inside «Sin hora».
  - `App/test/capture_sheet_test.dart:1622`.
- **UX-1633:**
  - `App/test/day_timeline_test.dart` `:489`, `:526`, `:561`, `:585`, `:639`, and the new `:952`: the area has the same size on the hidden first frame, the first visible frame, and after the view settles.
  - `App/test/capture_sheet_test.dart:1556`.

## Rounds
| Round | Packages | Tests | Verification | Fixed | Not yet | Regressions |
|---|---|---|---|---|---|---|
| 1 | P209 (done) | passed; tests prove UX-1639 and UX-1633; no device-only checks | `verify-b3x-r1-B.md` | UX-1639, UX-1633 | none | none |

## Ledger
`.claude/ux-review/ISSUES.md`:
- UX-1639 moved from Open to Device check. Its line now points to `day_timeline_screen.dart:651` and records P209.
- The UX-1633 line in Verified now records the P209 re-check, the new first-frame test, and the updated note about the notices.
