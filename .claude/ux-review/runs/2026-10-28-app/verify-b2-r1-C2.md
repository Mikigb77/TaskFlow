## UX verify — run 2026-10-28-app, round 1, area C (P286, P288) — 2026-11-01

**Verdict:** Ship. All four findings are fixed; one new polish-level gap (pinning from the page has no visible effect there).
**Evidence:** code (`git diff HEAD`), current renders (2026-11-01 07:46–07:47; `find App/lib App/assets -newer` the renders lists nothing), AUDIT.md, and the testers' 21+ passing widget tests. No device.

### Findings

**UX-2503 · fixed**
- `App/lib/screens/home_screen.dart:563-590`: the project page's app bar now has ✓, 8 dp, then a `PopupMenuButton` with tooltip `manageItem(list.name)` («Gestionar Casa»).
- Both menus come from one function, `projectMenuItems` (`App/lib/screens/task_lists_screen.dart`, after `ProjectDeleting`), and run through one `runProjectAction`. The page leaves out the members/«Compartir proyecto» item (`people: !_sharesHere(list)`) only where the page already has that button. This matches the brief's list (Fijar; Novedades when shared; Editar; Archivar/Restaurar; Eliminar).
- Deleting from the page (`_deleteProject`, home_screen.dart:412-438): asks, shows a spinner in place of ⋮, then `pop(true)` and «Proyecto eliminado». Proyectos drops the row at once (`gone == true` → `_deleted.add`).
- `App/lib/screens/list_sharing_screen.dart:519-546`: the delete button is now only `if (shared)` («Eliminar para todos»). The unshared «Compartir proyecto» page has no «Eliminar proyecto».
- Render `tasks/project.personal.es.light.1x`: the menu shows Fijar proyecto / Editar proyecto / Archivar proyecto / Eliminar proyecto (in red). AUDIT `tasks/project · empty`: ✓ and «Gestionar Huerto» are each 48 × 48 dp, 8 dp apart.

**UX-2516 · fixed**
- `task_lists_screen.dart` build: `groupsMatter` = has a group, or has a pending invitation with `group`. «Grupos» shows only when `groupsMatter` or a project is shared or belongs to a group.
- Render `tasks/projects.empty.es.light.1x`: only «Atrás» and «Nuevo proyecto». AUDIT lists 2 targets.

**UX-2517 · fixed**
- `home_screen.dart:514-517`: `quiet` now covers project pages (`widget.isRoot || widget.listId != null`). For a project, `filtering` includes the query and a person chip / «Para mí» (`!_team || _personShown != null`), so the search stays in those cases.
- Render `tasks/project.empty.es.light.1x` («Huerto»): «Compartir», «Notas», the empty state and «Añadir tarea». There is no search.

**UX-2509 · fixed**
- New `App/lib/widgets/search_clear.dart` `SearchField`: while the field holds text it shows a trailing `IconButton` ✕ with tooltip `clearSearch`. One tap clears the field and calls `onChanged('')`. A controller listener keeps the ✕ in step however the text changes.
- Used in all four fields: home_screen.dart (Tareas and project pages), notes_screen.dart:189, task_lists_screen.dart:113, project_scope_control.dart:151.
- The strings are in all three catalogs: ES «Borrar búsqueda», EN “Clear search”, CA «Esborra la cerca». The @description is accurate.
- Render `tasks/tasks-tab.no-match.es.light.1x`: «dentista» with the ✕ at the end, and «No hay tareas que coincidan» below it.
- AUDIT for that render: «Borrar búsqueda» is a 48 × 48 dp button inside the text field, and TalkBack reads it as item 11.
- Side note, not part of the brief's fix: on Tareas the query still survives a tab switch. That costs one tap now instead of letter-by-letter deleting, and the implementer left it out on purpose.

### Regressions

**R1C2-1 · Severity 1 · «Fijar proyecto» on the page changes nothing visible**
- Where: `App/lib/screens/task_lists_screen.dart` `projectMenuItems` 'pin', run by `pinProject`, which gives no feedback on success. It is reached now from the page's ⋮, `home_screen.dart:571-589`.
- The moment: "I tapped «Fijar proyecto»… did it do anything?" On Proyectos the row moves to «Proyectos fijados», where the person can see it. On the project page nothing changes, and there's no snackbar.
- Why it fails: visibility of system status (Nielsen 1994); gulf of evaluation (Norman 2013).
- Fix, subtract first: leave «Fijar/Desfijar proyecto» out of the page's ⋮, with a flag like the existing `people:`. Pinning is about the order on Proyectos and stays there. No copy. If the owner wants it on the page instead, show a confirmation using existing copy only.
- Verify: on the page, ⋮ no longer lists «Fijar proyecto», and Proyectos ⋮ still does.
- Evidence: verified in code.

Checked, with no regression found:
- Archiving from the page: the page shows its archived state, and the snackbar's Deshacer still works after the page closes because it uses `ProviderScope.containerOf`.
- Renaming from the page: the title follows `taskListsProvider`.
- Deleting from Proyectos after the refactor: the same steps, with the spinner from `ProjectDeleting`.
- A delete that fails: the spinner goes away and an error snackbar shows.
- The 2× Catalan project page (`project.shared.ca.light.2x`): the title «Matemàtiques» still fits beside ✓ and ⋮.
- `quiet` on shared or archived project pages: it hides only the search field; «Compartir»/«Membres» and «Notas» stay.
