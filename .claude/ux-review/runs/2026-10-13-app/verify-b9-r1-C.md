## UX verify — 2026-10-13-app, b9 round 1, area C (P24 P25 P26 P27 P43) — 2026-10-14

**Verdict:** Ship after fixes. All 21 findings are met in code. Two things still need a phone: UX-429 with a real keyboard, and UX-321 with TalkBack. The change caused three small regressions, all on the project and group pages.
**Evidence:** I read the code in `git diff HEAD`, and the ux-tester widget tests pass. The only current renders are the Calendar and capture previews (20:46–20:47). They don't show a shared project, an undated task or Activity, so no finding here rests on a render. I didn't run Flutter.
**Numbers:**
- Projects screen for a new account: 6 tap targets → 4. Now 2 buttons (Grupos, Nuevo proyecto) plus the app bar.
- Create-project dialog: 7 controls → 2 + Cancel/Save. The 5 colour chips are gone.
- Tareas filter chips: 5 → 4.

### Results
| ID | Result | Evidence |
|---|---|---|
| UX-314 | fixed | `home_screen.dart:280-281` `readOnly`; `:506-517` swaps TaskActions for the `readOnlyList` + `listEditingAccessHelp` ListTile |
| UX-315 | fixed | `home_screen.dart:43` `_team = true`; `:104-106` `_scope` is local for project pages; `:294-300` passes `team`/`onTeamChanged`; `project_scope_control.dart:35-41` only writes the provider when there's no callback |
| UX-219 | fixed | `home_screen.dart:459-472` `filtering` = query, label, or a root chip ≠ 0 → `noMatches`/`differentFilter` |
| UX-333 | fixed | `home_screen.dart:302-344`: no SectionLabel. The headline only on root. The archived project shows `archivedList` as a plain onSurfaceVariant line. Keys `yourList`/`everythingToDo`/`noDateNeeded` removed |
| UX-429 | fixed (device check open) | `project_scope_control.dart:83-92`: padded by `viewInsetsOf().bottom`, height `min(70%, space)`. While searching, section titles are hidden (`:226`), and Gestionar scrolls with the rows |
| UX-407 | fixed | `activity_screen.dart:29-34`: hidden without an active shared project; `groups_outlined` icon, `groupActivity` tooltip, badge kept |
| UX-322 | fixed | Project page bell removed (the `home_screen.dart` import and IconButton are gone); `list_sharing_screen.dart:325-341` `_updates` row for direct shares, owner and member branches |
| UX-321 | fixed (TalkBack on device) | `activity_screen.dart:157-189` `_ActivityRow`: `activityEntry` select with all 6 server actions + other; `{project} · {date}`; bold + `activityUnread` semantics; help line gone, empty state keeps it once |
| UX-327 | fixed | `task_lists_screen.dart:416-430` `createProject` pushes HomeScreen(listId); `groups_screen.dart:721-733` uses it with `groupId`; TaskListsScreen's `groupId`/`createOnOpen` detour removed |
| UX-329 | fixed | `task_lists_screen.dart:229-269`: no headline, help line or refresh button. It refreshes when it opens (`:36-46`), the spinner only on first load (`skipLoadingOnReload`), and search shows from 8 projects. One `PendingInvitations()` per screen, so one retry line |
| UX-430 | fixed | `task_lists_screen.dart:262-266` `projectsNoneFound` row |
| UX-332 | fixed | `task_lists_screen.dart` editTaskList: the colour Wrap shows only when `list != null`; default `'teal'` |
| UX-334 | fixed | `_projectRow`: `push_pin_outlined` with the semantic label `projectPinned`; `projectSharedRole`; count filters `!task.isCompleted` |
| UX-338 | fixed | `projectGroupSees(group.name)` when a group is picked in the create dialog from Projects |
| UX-319 | fixed | `groups_screen.dart:27-131` `action:`, `enterName`, `enterEmailAddress`; `checkBeforeAdd` removed; `_chooseRole` titled `groupRoleQuestion(name)` with selected + check on `current` |
| UX-320 | fixed | `LoadFailed` (`loadFailed` + Reintentar) on Activity, the group page and the Groups list; action errors go through `requestProblemText` (`_guard`, `_create` dialog) |
| UX-328 | fixed | The group name and invite email dialogs stay open with an error banner in `groupTextDialog` `submit`; the ListSharingScreen invite dialog does the same (`list_sharing_screen.dart` `_invite`, read in code, not tested) |
| UX-330 | fixed | The `Invitados` heading + `Pendiente` rows; voice name in the member's own row ⋮, never for the owner; ListSharingScreen `_memberRow` name first, then `email · role` |
| UX-336 | fixed | `groups_screen.dart` `_title()`: the group's name from details, then the list, then `Grupos` |
| U11 | fixed | grep: in the ES/EN/CA catalogs, `Bandeja`/`Inbox`/`Safata`/`captura` appear only in the exempt diagnostics keys. `inbox`=Sin fecha, `noList`=Sin proyecto, `unfinishedCaptures`=Sin guardar; Tareas' chip 4 removed; the schedule label is `noDate`. timezoneHelp/timezoneFallback keep b5's wording, which avoids `captura`; the brief's longer text with 'teléfono' is an owner choice |
| UX-311 | fixed | `listNameHint` / `listsEmptyHelp` read Casa, Trabajo, Compras (CA Casa, Feina, Compres) |

### Regressions (caused by this change)
**R1C-1 · Severity 2 · A read-only project's empty page says “Añade una tarea”**
- Where: `home_screen.dart:470-472` (the `listEmpty` message) with `:506-517`. A viewer's project page with no tasks.
- What the user sees: the body says "Añade una tarea a este proyecto. Tú eliges la fecha y el recordatorio." The bar below says "Este proyecto es de solo lectura" and there's no button. The viewer thinks: "Add how? Is something broken?" Before UX-314 the wrong create buttons at least matched the sentence.
- Fix: when `readOnly`, use a new key `readOnlyListEmpty`: EN `No tasks in this project yet.` / ES `Este proyecto aún no tiene tareas.` / CA `Aquest projecte encara no té tasques.`
- Evidence: verified in code.

**R1C-2 · Severity 2 · A new project's page can flash “solo lectura”**
- Where: `home_screen.dart:280-281`; `task_lists_screen.dart:416-430`; `editTaskList` calls `ref.invalidate(taskListsProvider)`.
- What happens: `createProject` pushes the new page at once. `listCanEditProvider` reads the previous list value, which doesn't have the new project yet, so `readOnly` is true. The read-only line shows instead of Añadir tarea until the local reload lands. This is the end of "create a project", the moment the user remembers (peak–end).
- Fix: `readOnly = widget.listId != null && list != null && !list.canEdit`. Say read-only only once the project is known.
- Evidence: inferred from code. Confirm on a device by creating a project and watching the bottom bar during the transition.

**R1C-3 · Severity 1 · A lone role word heads the group page**
- Where: `groups_screen.dart:624` `Text(groupRoleLabel(context, group.role))`.
- What happens: UX-336 removed the group-name headline, so the page now opens with just "Editor" or "Propietario" under the app bar, with nothing to say whose role it is. The user's own row under Miembros already shows their role.
- Fix: remove the line.
- Evidence: verified in code.

**R1C-4 · Severity 1 · The Activity button and its screen have different names**
- Where: `activity_screen.dart:37` (tooltip `groupActivity`) vs `:111` (title `activity`).
- What happens: the tooltip says "Actividad del grupo" but the screen it opens is titled "Actividad". One concept, two names.
- Fix: title the screen `groupActivity`.
- Evidence: verified in code.

### Notes, not regressions
- On a project page, `Para mí` with no tasks for you still shows "Un nuevo comienzo" + `listEmpty`, because `filtering` ignores `_team`. This is older than the change and happens less now, since the default is Todas. Adding `|| (widget.listId != null && !_team)` to `filtering` would show `noMatches`.
- The ListSharingScreen pending list uses the uppercase `pendingInvitations` SectionLabel, while the group page now says `Invitados` / `Pendiente`. The wording drifts between the two screens. Worth aligning in a later pass.
- The group invite role sheet titles itself with the email ("¿Qué puede hacer ana@…?"). Acceptable.
