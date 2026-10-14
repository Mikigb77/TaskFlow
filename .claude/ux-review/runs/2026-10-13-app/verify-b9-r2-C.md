## UX verify — 2026-10-13-app, b9 round 2, area C — 2026-10-14

**Verdict:** Ship. All five findings are fixed in code; one rare edge case is new (R2C-1, severity 1).
**Evidence level:** code reading plus the tester's widget tests (home_screen_test.dart, activity_screen_test.dart, groups_screen_test.dart). No preview covers the project page, the group page or the Activity screen (the PNGs in App/build/ re-rendered at 21:13 are calendar, review and capture only), so no render evidence.

### P114
- **UX-626 — fixed.** `App/lib/screens/home_screen.dart:282` `final readOnly = widget.listId != null && list != null && !list.canEdit;`, with the comment at :279-281 saying why. `listCanEditProvider` (`App/lib/providers/task_lists_provider.dart:15-19`) is unchanged, and so is the `TaskActions` branch (:522-527). A new project's page (`createProject` → `editTaskList` invalidates `taskListsProvider`, then pushes) is no longer read-only while the list reloads. Phone check of the transition still open (deviceChecks).
- **UX-625 — fixed.** The empty-state message order at :471-479 is filtering → `differentFilter`; readOnly → `readOnlyListEmpty`; project → `listEmpty`; then `tasksEmpty` / `inboxEmpty`. It uses the same `readOnly` as the bottom bar (:510). Key in all three ARBs next to `listEmpty`: en:330 `No tasks in this project yet.` (with a description at :331), es:239 `Este proyecto aún no tiene tareas.`, ca:218 `Aquest projecte encara no té tasques.` Tests: home_screen_test.dart:674, :687.
- **UX-629 — fixed.** `filtering` at :460-464 now includes `(widget.listId != null && !_team)`, so `Para mí` with nothing for the user shows `No hay tareas que coincidan` / `Prueba otra palabra o filtro.`. The `Todas` chip that undoes it is in view at the top (`ProjectScopeControl`, shown for shared projects).

### P115
- **UX-627 — fixed.** The group page's ListView (`App/lib/screens/groups_screen.dart:621-637`) now starts with the error banner, the progress bar or `Miembros`. The lone role line is gone. The 20 dp spacer appears only when `_error != null || _busy` (:633). The role still shows in each member row (:643). `groupRoleLabel` is still used at :264, :493 and :643.
- **UX-628 — fixed.** `App/lib/screens/activity_screen.dart:111` `CustomAppBar(title: context.l10n.groupActivity)` matches the tooltip at :37. The per-task history keeps `activity` (:231). ActivityButton is the only way in (`custom_app_bar.dart:50`). Tests: activity_screen_test.dart:240 and :280 (2× text, Catalan, 320×568).

### Regressions
**R2C-1 · Severity 1 · Project page offers adding after the project disappears**
- Where: `App/lib/screens/home_screen.dart:282` with `:522-527` and `:475-476`. This is a project page whose project is no longer in `taskListsProvider` once it settles: the user was removed from a shared project, or the project was deleted on another device while its page stayed open.
- The moment: "It says add a task to this project. I added one… where is it?"
- What happens: before this change, an unknown project showed the read-only bar. Now `list == null` makes `readOnly` false, so the page shows `Añadir tarea` and the empty state `Añade una tarea a este proyecto…` under the fallback title `Proyecto`. But `TaskActions` gets `projectId: null`, because `listCanEditProvider` is false for an unknown id. The new task is saved outside this project and never appears on the page.
- Why it fails: visibility of system status, and "after create, the user sees the item where it went" (Norman's gulf of evaluation; change blindness).
- Fix: treat "unknown" as "not yet known" only while the lists are loading: `final lists = ref.watch(taskListsProvider); final readOnly = widget.listId != null && (list == null ? !lists.isLoading && lists.hasValue : !list.canEdit);`. `createProject` invalidates the provider before the push, so `isLoading` (refreshing) covers the new-project window and nothing flashes. A project still missing after the reload goes back to the read-only bar and `readOnlyListEmpty`. Alternatively, pop the page when its project is gone, as the sharing screen's `gone == true` path already does. No copy change.
- Verify: a widget test where `taskListsProvider` resolves without `p1` and isn't reloading. The page shows no `Añadir tarea` and shows the read-only line. The UX-626 acceptance test (the provider reloading without `p1`) still shows no read-only line.
- Evidence: inferred from code. It is rare and needs a second device or account to reproduce.

No other regressions in home_screen.dart, groups_screen.dart, activity_screen.dart or the three ARB entries.
