## UX verify — run 2026-10-18-commands, round 2, area C (P145) — 2026-10-18

**Verdict:** UX-1214 fixed. No regressions.

### UX-1214 · S2 · Chosen people chip shown by colour alone — **fixed**
- ✓ is back: there's no `showCheckmark` left in `App/lib/widgets/project_scope_control.dart`, so all three people-row chips (`people-all` :249, `people-me` :260, `people-<id>` :268) and the pair (:206, :212) use Material's default ✓. The "No ✓" comment is gone.
- Same look on every page: one shared const, `_chipPadding = EdgeInsets.symmetric(horizontal: 4, vertical: 8)` (:26), is used on all five chip sites. That covers the pair on Calendar, Tareas and viewers-only projects, because they share the same branch. `labelPadding`, `materialTapTargetSize`, the Wrap's spacing and runSpacing (8/4), `_AtMostTwoRows`, the semantics labels and `chipTheme` are untouched.
- Fit, from the implementer's measurements in `App/test/project_people_filter_test.dart:14-21` (Manrope, 2× text on 320 dp, against 272 dp):
  - ES: 281.0 → 265.0 dp;
  - CA: 282.7 → 266.7 dp.

  Both fit on two rows.
- Tests (ux-tester, all pass) at `App/test/project_people_filter_test.dart`:
  - ✓ kept, and Ana's chip widens by the ✓'s width (:631);
  - shared padding (:674);
  - every person chip is on screen at 2×/320 and at 1.3×/393, in ES and CA (:784);
  - the first task row is no lower (:840ff);
  - the UX-1110 semantics still hold.
- Render: `App/build/project-people-filter-es.png` (19:42, newer than the widget's 19:14 change). It shows ✓ on the tinted «Todas», with «Todas · Para mí · Ana · Paul» on one row at 1× text. The choice no longer depends on colour alone.
- Device check left to the owner: a phone, Spanish, the largest font, 360–393 dp. The ✓ should show and both names should be visible without swiping.

### Regressions (changed files only)
None.
- The 4 dp side padding plus the 2×-text labelPadding of 4 leaves about 8 dp between the border and the text at 2×. That's tight but legible, and the 48 dp touch target is unchanged. Not reported.
- The pair's «Todas» has no «Todas las tareas» TalkBack name, while the people row's does. This predates P145 (P131 scope), so it isn't counted here.
