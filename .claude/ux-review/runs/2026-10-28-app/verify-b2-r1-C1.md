## UX verify — 2026-10-28-app, batch b2, round 1, area C (P283, P284, P285, P287) — 2026-11-01

**Verdict:** All 13 findings fixed. Three regressions: one S2 (the new Novedades icon looks like the Notas tab icon) and two S1 edge cases.
**Evidence:** code (`git diff HEAD`), and the previews re-rendered at 07:46–07:47 today. `find App/lib App/assets -newer <png>` returns nothing, so the renders match the code. Also AUDIT.md and the testers' passing tests. All of this is widget-test level: there was no device run.

### Findings

| ID | Result | Evidence |
|---|---|---|
| UX-2501 | fixed | `App/lib/screens/notes_screen.dart:151-158` computes `readOnly`. In `:278-298`, the read-only bar (`readOnlyList` and `listEditingAccessHelp`, the same ListTile as `home_screen.dart:911-921`) takes the place of «Añadir nota». «Añadir nota» passes `projectId: _saveTo, useScope: false`. `voice_task_screen.dart:89, :795-797`: only Notas turns off the scope fallback. Notas is the only place that opens the sheet with `kind: 'note'` (grep). Render `notes/notes-tab.viewer-project.es.light.1x`: «Coro» shows with the bar and no «Añadir nota». In AUDIT, #7 reads the bar as one text node. |
| UX-2515 | fixed | `notes_screen.dart:200`: the dropdown shows only when there is a note or a project is shown. `:212-213`: its first item is `projectsAll`. `allNotes` is gone from all three catalogs and from lib. Renders `notes-tab.empty-with-project` (no dropdown) and `notes-tab.list.es.light.2x` («Proyecto / Todos los proyectos»). |
| UX-2502 | fixed | `list_sharing_screen.dart:88-137` and `groups_screen.dart:419-470`: after the server answers, the page refetches its own data and runs `loadTasks()` in the background. Only leave and delete still wait for the sync. The sharing page sets `skipLoadingOnRefresh: true`. The group page sets `skipError: true` (`:690`), so a refetch that fails keeps the page. Both pages show a 2 dp `LinearProgressIndicator` at the top of a Stack in the body (`list_sharing_screen.dart:376-386`, `groups_screen.dart:673-684`). Failures come through `showFeedback(requestProblemText(…, keptNote: false))`. Rename and the spoken name go through `_sendTyped` with `submit:` (`groups_screen.dart:607-655`). |
| UX-2511 | fixed (Catalan wants a native read) | `request_locale.dart:18, :52-53`: `keptNote`. It is passed as false in list_sharing (dialog, page error, `_guard`), groups (`groupTextDialog`, `_guard`), invitation_review `:182-186`, and invitation_cards `:156-159` and `:233`. ARB values match the brief in EN, ES and CA, with no «sincronización». Render `invitation.offline` ends at «…inténtalo de nuevo.». Render `project-sharing.how-it-works.es` shows the new rolesHelp and removalHelp. «Solo lo que es para mí» shows in the `project-sharing · owner` AUDIT. |
| UX-2513 | fixed | `list_sharing_screen.dart:293-297, :339-344` (`_address` with semanticsLabel), `groups_screen.dart` invitation title, `invitation_review_screen.dart:171-172`. Render `group.owner.es.1x` breaks «carmen.lopez@example.» / «com». At 2× it breaks «carmen.» / «lopez@». `project-sharing.owner.es.2x` breaks «ana.garcia@» / «example.com · Editor». AUDIT TalkBack reads each address whole. |
| UX-2518 | fixed | `invitation_review_screen.dart:220-229` adds an 8 dp SizedBox. `actionsOverflowButtonSpacing: 8` is on `groupTextDialog`, `groupConfirm`, `showInvitationSent`, the project invite dialog, and the join and decline dialogs. AUDIT gaps are 8 dp for: «Aceptar invitación»–«Ahora no», «Reintentar»–«Ahora no», «Cancelar»–«Enviar invitación» (group and project), «Cancelar»–«Eliminar grupo», and «Cancelar»–«Transferir a Paul». |
| UX-2504 | fixed (Catalan wants a native read) | The delete row and its button use `groupDeleteAction`, with `groupDeleteHelp` as the subtitle only while the group has projects. The confirmation text is `groupDeleteConfirm`. The transfer sheet header is `groupTransfer` alone. The transfer confirmation has title `groupTransferConfirm(group, person)`, text `groupTransferHelp`, and button `groupTransferAction(person)` through `groupConfirm(action:)`. Renders: `group.delete-confirm.es.2x` (red «Eliminar grupo») and `group.transfer-confirm.es.1x` («¿Transferir «Familia López» a Paul?» / «Transferir a Paul»). The 2× delete dialog shows the title «Eliminar grupo» above the question that starts «¿Eliminar…». That is redundant but follows the brief. |
| UX-2505 | fixed | `counterText: ''` is on `groupTextDialog` (`groups_screen.dart:159`), the project name in `task_lists_screen.dart:606`, the invitation code in `invitation_cards.dart:265`, and `task_list_picker.dart:157`. `maxLength` stays on all four. AUDIT `group · invite` has no «Quedan … caracteres» node. |
| UX-2519 | fixed | `app_components.dart:132-140`: `SectionLabel` is `Semantics(header: true)`, and so are the group page's three titles. AUDIT reads «Miembros», «Invitados», «Proyectos del grupo» and «INVITACIONES PENDIENTES» as headings. |
| UX-2520 | fixed | For managers, the group page starts with a FilledButton «Invitar a una persona» (`groups_screen.dart` `_page`, `if (group.canManage)`). Renders: `group.owner` at es 1× and 2×. |
| UX-2506 | fixed (see R1C1-1) | `activity_screen.dart:58`: `Icons.feed_outlined` with its badge and tooltip. Groups, the shared scope and «Todos» keep `groups_outlined` (unchanged). |
| UX-2508 | fixed (app half) | `activity_screen.dart:17-40` (`onlyMoved`, `activityLabel(item)`) and `:240-242` (the `moved` case). New `activityMoved`, and `activityUpdated` changed to «Ha actualizado la tarea», in EN, ES and CA. Render `sharing/activity.list.es.1x` reads «Ana ha movido: Recoger a los niños». The server half (Novedades items carrying `fields`) is still a note for the main session. Until it ships, Novedades always reads «ha actualizado». |
| UX-2615 | fixed | `activity_screen.dart:344-367`: one `Semantics(expanded:, hint:, onTapHint:)` around a ListTile, replacing the ExpansionTile. In AUDIT `tasks/detail · created-by`, #10 reads: button «Actividad» hint «Contraído» [collapsed], with no separate «Contraído» stop. |

### Regressions

**R1C1-1 · S2 · The Novedades icon now looks like the Notas tab icon**
- Where: `App/lib/screens/activity_screen.dart:58`, the header of Calendar, Tareas and Notas (renders `tasks/tasks-tab.normal.es.light.1x`, `notes/notes-tab.viewer-project.es.light.1x`).
- The moment: "This little page at the top is my notes, isn't it?" On Notas, the header's `feed_outlined` (a page with lines) sits right above the selected `description` tab icon (also a page with lines). On Tareas, the two look like the same thing twice.
- Why it fails: the fix takes «Novedades» off one meaning (people) and gives it another (Notas). An unlabelled icon is a guess for a newcomer (Harley 2014), and one glyph shape should have one meaning (Nielsen #4, consistency).
- Fix: use a glyph that isn't a page and that the app doesn't use yet, for example `Icons.campaign_outlined` (a megaphone, "news"). Keep the badge and tooltip. Don't use `history`/`restore` (Notas' «Sin guardar»), `notifications_*` (reminders) or `inbox_outlined` (in use). No copy.
- Verify: re-render `tasks/tasks-tab.normal` and `notes/notes-tab.list`. The header icon should share no shape with any tab icon.
- Evidence: seen in current renders.

**R1C1-2 · S1 · Notas says «solo lectura» for a project that's gone**
- Where: `App/lib/screens/notes_screen.dart:154-158`, in the state where Notas is filtered to a project that's no longer in the account's projects (the dropdown shows `listUnavailable`).
- What happens: `readOnly` is true when `shownList == null` once the projects have loaded, so the bar reads «Este proyecto es de solo lectura · pídeselo al propietario». The project isn't read-only: it's unavailable, and nobody can grant access to it. Before this change, «Añadir nota» saved the note with no project.
- Fix: show the bar only for a project the account can see but not edit (`shownList != null && !shownList.canEdit`). For a project that's gone, keep «Añadir nota»: `_saveTo` is null and `useScope: false`, so the note is saved with no project.
- Verify: a widget test with `NotesScreen(listId: 'gone')` and the projects loaded shows «Añadir nota» and no read-only bar.
- Evidence: verified in code; no render covers this state.

**R1C1-3 · S1 · Group page pull-to-refresh fails silently offline**
- Where: `App/lib/screens/groups_screen.dart` `_page`, `RefreshIndicator.onRefresh`, together with the new `skipError: true`.
- What happens: offline, pull-to-refresh used to end on «No se ha podido cargar» with Reintentar. Now the spinner ends, the page stays as it was, and nothing says the refresh failed (`loadTasks()` doesn't report on this page). That leaves a gulf of evaluation (Norman 2013), though nothing is lost.
- Fix: in `onRefresh`, await `ref.read(groupDetailsProvider(widget.groupId).future)` in a try/catch, and on error call `showFeedback(messenger, requestProblemText(strings, error, keptNote: false))`, the same message as an action's failure. No copy.
- Verify: a widget test that pulls to refresh offline and checks that the members stay and the network message shows as the floating message.
- Evidence: verified in code; inferred.

### Not regressions (pre-existing, noted only)
- `invitation.from-ana` at es and ca 2×: «Aceptar invitación» is cut at the viewport edge (AUDIT 312 × 32). The page scrolls, and the 8 dp gap below the button doesn't cause this.
- The group page's «Eliminar grupo» row, while off, keeps full-contrast text (ListTile with `onTap: null` isn't drawn disabled). This was there before. Its subtitle explains why the row is off.
