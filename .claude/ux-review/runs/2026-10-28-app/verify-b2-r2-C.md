## UX verify — 2026-10-28-app, batch b2 round 2, area C (P303) — 2026-11-01

**Verdict:** Ship. All four findings are fixed as briefed, and the change caused no regressions.
**Evidence:** code read at the working tree (the P303 hunks in the five lib files); fresh renders from 09:11–09:12 today, newer than every changed lib file (09:07). The tester's widget tests all passed. Nothing was checked on an emulator or device.

### Findings

**UX-2625 · fixed** — Novedades has an icon of its own
- `App/lib/screens/activity_screen.dart:58`: `Icons.campaign_outlined`, still inside the `Badge` (count, 99+), with the tooltip `groupActivity` (:54). A grep of `App/lib` finds no `feed_outlined`.
- Renders: `tasks/tasks-tab.normal.es.light.1x.png` and `notes/notes-tab.viewer-project.es.light.1x.png`. The header megaphone no longer looks like the page-with-lines icons of the Notas tab (`description_outlined`) or the «Notas» link.
- Tests: `App/test/activity_screen_test.dart` P303 group (Calendario, Tareas, Notas; no `feed_outlined` anywhere).

**UX-2626 · fixed** — a gone project on Notas is no longer called read-only
- `App/lib/screens/notes_screen.dart:150-155`: `readOnly = shownList != null && !shownList.canEdit`, and the comment was updated.
- A gone project gets «Añadir nota». `_saveTo` (:48-49) is null because `listCanEditProvider` (`providers/task_lists_provider.dart:16-19`) is false for an unknown id, and the sheet opens with `useScope: false` (:292-295), so the note is saved with no project.
- The viewer case still shows the bar and no «Añadir nota»: see the render `notes/notes-tab.viewer-project.es.light.1x.png` and the tester's second test.
- Note, not a regression: on the gone-project filter, the note saved with no project doesn't match `_shown` (:91-93), so the list doesn't land on it, and «Nota guardada» is the only feedback. This is the rare pre-P283 path that the brief accepted (UX-2501's lineage). No new ID.

**UX-2627 · fixed** — an offline refresh on a group page says so
- `App/lib/screens/groups_screen.dart:714-731`: the messenger and strings are taken before any await. The refresh invalidates, then awaits `groupDetailsProvider(...).future` in a try/catch. On failure it shows `showFeedback(messenger, requestProblemText(strings, error, keptNote: false))`, the same message as `_guard`'s action failure (:378-381), and then runs `loadTasks()` as before.
- `skipError: true` (:694) keeps the members and projects. The Grupos list's refresh (:297-300) is untouched.
- Tests: offline refresh keeps the page and shows the floating message; online refresh shows none.

**UX-2628 · fixed** — pinning stays on Proyectos
- `App/lib/screens/task_lists_screen.dart:283-296`: `bool pin = true`, and the 'pin' item is inside `if (pin)`. The doc comment says why. Proyectos' ⋮ (:250) still passes the default.
- `App/lib/screens/home_screen.dart:557-578`: the page builds `menu` with `pin: false`. The 8 dp spacer and the ⋮ appear only when `menu.isNotEmpty`. `runProjectAction` keeps its 'pin' case.
- Render `tasks/project.personal.es.light.1x.png`: the ⋮ lists Editar / Archivar / Eliminar proyecto, with no Fijar. `tasks/project.viewer.es.light.1x.png`: a viewer still gets a ⋮ (Notificaciones), 8 dp from ✓.
- Tests: 8 role combinations plus pin on Proyectos.

### Regressions
None found in the changed files or the flows they touch: the header on Calendario, Tareas and Notas; Notas' bottom bar; the group page refresh; the project page header and its ⋮.

### Pre-existing, noted only (not caused by P303)
- `App/test/ux_previews/sharing_previews.dart:64`: the area title still reads "Activity in shared projects (from the people button on Calendar)". The button has been neither the people icon nor Calendar-only for some time. This is a preview description only; the file is untouched by P303.
- `App/lib/screens/home_screen.dart:541-546`: a project page whose project is gone still uses the read-only bar, so it now differs from Notas. This is the project page's own long-standing rule, outside UX-2626's scope.
