## UX verify — run 2026-10-18-commands, round 1, area C (P131) — 2026-10-18

Evidence: `git diff HEAD` of project_scope_control.dart and home_screen.dart, the ux-tester's passing tests in App/test/project_people_filter_test.dart, and the fresh render build/project-people-filter-es.png (19:00, newer than both source files at 18:18/18:19). No Flutter run by me.

### Results
- **UX-1101 · fixed (device check open).** `_PeopleFilter` now lays the chips out as a `Wrap` (spacing 8, runSpacing 4) inside `_AtMostTwoRows` (project_scope_control.dart:280-354): wraps while two rows hold it, otherwise one sideways row whose 24 dp sits inside the scroll view, so a chip is cut at the screen edge. ✓ moved to the app bar on every non-root page (home_screen.dart:357); the row that held it alone is gone; an archived project keeps «Proyecto archivado» as text (:417-425); root Tareas keeps ✓ beside «Proyectos». Tests: chips wholly on screen in ES/CA at 1.3×/393 and 2×/320; first task top no lower than 420.0 / 393.0 dp; 8 editors scroll with the last chip crossing x = 320. Render: Todas · Para mí · Ana · Paul all in view, ✓ top-right.
- **UX-1108 · fixed.** The pair at project_scope_control.dart:198-210 now reads Todas then Para mí; selection and default unchanged. Tested ES/CA on Calendar, Tareas root, a viewers-only project and a two-editor project.
- **UX-1110 · fixed (TalkBack speech is a device check).** Person chips carry `Semantics(label: commandFindPerson(name), excludeSemantics: true)` (:264-270); people-row Todas carries `allTasks` (:246-250). Visible text unchanged; label-in-name holds in all three languages (“All tasks”/All, «Todas las tareas»/Todas, «Totes les tasques»/Totes; the person name is inside each label). Tested selected = true after a tap.

### Regressions
**R1C-1 · Severity 2 · People-row choice now shown by a pale fill only**
- Where: App/lib/widgets/project_scope_control.dart:240-264 (`showCheckmark: false` on Todas, Para mí and every person chip); a shared project page with two or more other editors.
- The moment: "Which one is on? They all look the same." (low vision, colour blindness, sunlight)
- What happens: the ✓ that marked the chosen chip is removed. In the render the chosen «Todas» differs from the others only by a light teal fill, against the same outlined border. On Calendar, Tareas and a viewers-only project the same Todas/Para mí chips still show ✓, so the same component looks different from page to page.
- Why it fails: never colour alone, and state indicators need 3:1 non-text contrast (WCAG 2.2, 1.4.1 and 1.4.11); consistency (Nielsen 1994).
- Fix: delete the three `showCheckmark: false` lines and the comment at :240-241, so the default ✓ returns, as on the pair chips. If the change in width after a tap is the worry, keep the ✓ anyway: `_AtMostTwoRows` already re-lays out the rows, and the tap has already happened. No copy change.
- Verify: re-render project-people-filter-es: the chosen chip shows ✓; a widget test finds the check icon on the selected people chip.
- Evidence: verified in code; seen in the current render.

### Notes (not regressions)
- With ✓ now in the app bar on project pages, a long project title loses about 48 dp more before the ellipsis at 2×. The plan asked for this move, so I'm not reporting it.
- home_screen.dart's diff also has the `landing` parameter and the wider `_land`, from another package. I didn't judge them here.
