## UX verify — 2026-10-13-app, b2 round 2, area C (P53) — 2026-10-13

**Verdict:** both findings fixed; no regressions caused by this change. Evidence is the code plus ux-tester's widget tests. No preview covers the Tareas heading or the project sheet; nothing in `App/build/` was rendered for them, so no render was read.

### UX-308 · fixed
- `App/lib/screens/home_screen.dart:82-108`: the heading is now an outer `Wrap(alignment: spaceBetween, crossAxisAlignment: center)` holding the `Text` and an inner `Wrap(crossAxisAlignment: center)` with `TextButton(Text(l10n.lists))` (only on the root) and the completed-tasks `IconButton`. Nothing in the heading is a fixed-width `Row` now, so it can't overflow: when the pair doesn't fit beside "Tareas" it moves to the next line as a pair, and if the label is too long the icon moves under the label.
- Round 1's work is still there: the labelled `Proyectos` / `Projectes` / `Projects` button with no folder icon, and in the picker the `Nuevo proyecto` row (`task_list_picker.dart:72-77`) and the `Proyecto` title with no subtitle (`:52`).
- The test harness loads Manrope and MaterialIcons in `setUpAll` (`App/test/home_screen_test.dart:30-37`), as the brief asked.
- Tests:
  - at 320×640 and 2× text in es, ca and en: no overflow; both controls are hit-testable and inside the 320 dp screen; tapping them opens `/lists` and `/completedTasks` (`:234-283`);
  - at 390×844 and 1× text in Spanish, both controls sit on one line (`:286-303`);
  - the test that failed last round (`:208-231`) now passes.
- Walkthrough (newcomer, es, 2×): "Tareas" fills the first line and `Proyectos` + ✓ start the second line on the left. Both are big enough to tap, and the labelled word is still the door to projects.

### UX-443 · fixed
- `App/lib/widgets/task_list_picker.dart:64-69`: every shared row's subtitle is now `list.groupName ?? l10n.sharedProject`. A project shared person by person reads `Compartido` / `Shared` / `Compartit`, a group project shows its group name, a personal one shows nothing, and an unshared archived one keeps `archived`.
- The three catalogs add `sharedProject`; the keys this package left unused (`sharedListVisibility`, `createListHelp`, `moveToListHelp`) are gone from lib and the ARBs. The masculine `Compartido` / `Compartit` agrees with "proyecto" / "projecte".
- Test `App/test/project_ui_test.dart:447-505` (es, en, ca) checks the three subtitles and the exact copy.

### Regressions (changed files and the flows they touch only)
None caused by P53.

### Notes for the organizer (not regressions: older than this change, not in ISSUES.md)
- **Word mismatch.** `App/lib/screens/task_lists_screen.dart:230`: on the Projects screen, a project shared person by person is labelled `Proyectos compartidos · Editor`. That's the plural section name used as a row label, so the same state is called `Compartido` in the picker and `Proyectos compartidos` on Projects. Suggested fix: use `sharedProject` there too ("One concept, one name", ISO 24495-1). Severity 1–2.
- **Wrong gender.** The `archived` key reads ES `Archivada` / CA `Arxivada`, feminine (left over from "lista"). It now labels projects (`task_list_picker.dart:68`, `task_lists_screen.dart:93,230`). "Proyecto" is masculine, so it should be `Archivado` / `Arxivat`, unless a task (feminine "tarea" / "tasca") also uses the key. Check before renaming. Severity 1.
- **Edge case.** A shared project that is also archived shows only the shared subtitle in the picker (shared is checked first, as before this change). It's rare, because archived rows only appear when that project is the task's current one.
