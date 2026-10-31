## UX verify — 2026-10-19-app, b4 round 1, area C (P181–P185) — 2026-10-20

**Verdict:** All 18 findings are fixed against their acceptance checks. There are 6 regressions in the changed flows: 1 major (Activity), 1 minor (the archived bar) and 4 polish.
**Evidence:** I read the code with `git diff HEAD`. Renders in `App/build/ux/{sharing,tasks,notes}/` date from 2026-10-20 19:23, and `find App/lib App/assets -newer` lists nothing newer, so they are current. AUDIT spot-checked. Tester results as given. Phone and TalkBack checks are still open.

### Findings

| ID | Result | Evidence |
|---|---|---|
| UX-1503 | fixed | `list_sharing_screen.dart:177` `inviteWho`, `:199` label `email` («Correo»), `:205-207` own-address check. `groups_screen.dart:25-30` `ownEmailProblem` (trimmed, lower-case), `:472-478` group dialog, title `inviteWho` and label `email`. ES `shareProjectHelp` «Esa persona verá…». Render `sharing/project-sharing.invite.es.light.2x.png`: «Correo» shows whole while floating. |
| UX-1513 | fixed | Shared `showInvitationSent` (`groups_screen.dart:34-71`) for both, with no `invitationEmail*`/`invitationCodeHelp`. Group pending row ⋮ `manageItem(email)` with Reenviar and a red Anular (`:709-737`), no confirmation, as the project's. The project member ⋮ offers only the other role (`list_sharing_screen.dart:290-301`). Group invite sends `role: 'editor'`, button `sendInvitation`. `nextStep` and `revokeInvitation` are gone from all 3 ARB files. Render `sharing/group.owner.es.light.1x.png`. |
| UX-1506 | fixed | Title `shared ? people : listSharing` (`list_sharing_screen.dart:352-354`). Owner's own row first, marked (tú) (`:416-430`). Member view lists `people` (`:522-525`); `yourRole`/`sharingHelp` removed. Renders `project-sharing.owner.es.light.1x.png` (María (tú) · Propietario, Ana, Paul) and `project-sharing.reader.es.light.2x.png` (Lucía, María (tú), Jordi). Two-account check on a phone still open. |
| UX-1509 | fixed | `invitation_review_screen.dart:202-222`: on 404, one FilledButton «Cerrar» → pop(true), which clears the link (`main.dart:250-252`). Offline keeps Reintentar and Ahora no. `_accessLine` (`:117-121`) shows only for viewer or admin. Renders `invitation.unavailable.es.light.1x.png` and `invitation.from-ana.ca.light.2x.png` (no access line). Note: system Back on the unavailable screen still postpones the dead link (`main.dart:254`). That was so before; not counted. |
| UX-1508 | fixed | `invitation_cards.dart:360-390`: records the joined route, waits for `closed` on the snackbar, and skips the name question if that route isn't current. |
| UX-1510 | fixed (with R1C-1) | Activity opens from local data at once (`activity_screen.dart:100-126`). The project delete shows a 48 dp spinner trailing, hides the row, then «Proyecto eliminado» (`task_lists_screen.dart:116-136`, `:363-372`). The invite dialog shows on the POST answer (`list_sharing_screen.dart:97-118`, `groups_screen.dart:422-457`). |
| UX-1514 | fixed (app half) | `activityEntry()` (`activity_screen.dart:178-190`): you, then name, then today's sentence. Render `sharing/activity.list.es.light.1x.png`: «Paul te ha asignado: Reservar el autobús». Server half and staging check: main session. |
| UX-1524 | fixed | `groupActivity` is Novedades/Updates/Novetats (render title «Novedades»). `groupHelp` has no tú/vosotros mix. CA `listSharing` «Comparteix el projecte». `activityUnassigned` is used for history (`activity_screen.dart:20`). CA «Com funciona compartir» and «ha assignat {name}» still need a native read. |
| UX-1504 | fixed (with R1C-2) | `home_screen.dart:481-483` `archived`, bar `:785-814` with `archivedListAddHelp` and «Restaurar proyecto» only for `archived && !groupArchived && canManage`. `archivedList` removed. Render `tasks/project.archived.es.light.2x.png`. |
| UX-1516 | fixed | `task_list_picker.dart:94-95` `if (!creating)`. |
| UX-1519 | fixed | `task_assignment_picker.dart:199-201`. Render `tasks/detail.created-by.es.light.1x.png`: «Lo ven todos los miembros.» |
| UX-1522 | fixed | Grupos after the projects (`task_lists_screen.dart:266-280`; renders `projects.list` and `projects.empty`). `createList` used for create only (`:616-618`). Invitation errors render nothing (`invitation_cards.dart:54`). An owner's shared row shows the count («Compartido · 5 tareas y notas», render). Folder icon on the empty state. Sheet search from 8 projects (`project_scope_control.dart:142-158`). Chip un-capped: render `tasks/tasks-tab.normal.es.light.2x.png` shows «Todos los proyectos» whole. |
| UX-1523 | fixed | One `Wrap(spacing: 8, runSpacing: 8)` then 8 dp (`home_screen.dart:566-626`). Render `tasks/project.shared.es.light.1x.png`: «Miembros · 3» and «Notas» on one row. |
| UX-1320 | fixed | `noteLeadingTitle` (`local_capture.dart:42-71`) is used by `CaptureProcessor.noteTitle` and `localDrafts`. |
| UX-1517 | fixed | `_preview` (`notes_screen.dart:318-330`). Render `notes/notes-tab.list.es.light.1x.png`: «Para la reunión del cole» / «preguntar por el comedor y por la excursión de primavera». |
| UX-1518 | fixed | `voice_task_screen.dart:2089-2093` `typesNote`. Render `notes/note-capture.typing-free-0.es.light.1x.png` has no used-up line. The Añadir nota icon is + at 0 left (`notes_screen.dart:263-265`). |
| UX-1520 | fixed | `notesHelp` removed. Search only when a note exists (`notes_screen.dart:177-187`). `checklistCount` and a folder icon on rows (`:291-306`). Renders `notes-tab.empty.es.light.1x.png` (one help text, no search) and `notes-tab.list` («Casa» with its folder). |
| UX-1521 | fixed | `task_detail_screen.dart:583-598`: `Semantics(button, label noteBody, value, onTapHint editNote)`. The words sit under `ExcludeSemantics` when tappable (`note_text.dart:37-40`). AUDIT reads button «Tu nota» with its value. A read-only note (viewer, onTap null) still reads as an unnamed SelectableText; that is outside this finding. TalkBack on a phone still open. |

### Regressions

**R1C-1 · Severity 3 · Activity says a task not yet synced may be deleted**
- Where: `App/lib/screens/activity_screen.dart:100-126` (`_open`).
- The moment: "Lucía just created it, and the app says it may have been deleted?"
- What happens: the tap looks only in the phone's database. Opening Activity doesn't sync tasks (`collaborationActivityProvider` only fetches `notifications/`). So an entry newer than the phone's last sync — «X ha creado» or «X te ha asignado» — finds nothing and shows `taskRemoved` at once. Before this change, the tap synced first and then opened the task. The message is wrong in the most common case for unread entries, and the newcomer won't try again.
- Why: error messages must say what really happened (Neusesser & Sunwall 2023); gulf of evaluation (Norman 2013).
- Fix: keep the opening at once when the task is found. When it isn't, and the action isn't `deleted`, show a small spinner on that row, await the sync already started (`loadTasks()`), and look again. Open the task if it's there now; only then say `taskRemoved`. A `deleted` entry says it at once. Update the UX-1510 test "an entry whose task isn't on the phone" to make its task missing after the sync too.
- Verify: widget test where a task appears only after the sync completes: the tap opens it and no `taskRemoved` shows. With the sync hanging, no `taskRemoved` shows before the sync ends.
- Evidence: verified in code.

**R1C-2 · Severity 2 · «Restáuralo…» shown to people who can't restore**
- Where: `App/lib/screens/home_screen.dart:793-812`; `archivedListAddHelp`.
- The moment (reader of an archived shared project, or a project archived with its group): "Restore it — how? There's no button."
- What happens: the bar always reads «Proyecto archivado. Restáuralo para añadir tareas.» The button shows only for a manager of a project archived on its own. Before, these people saw plain «Proyecto archivado».
- Why: no dead ends (lens A); recognition over recall (Nielsen 1994).
- Fix: when no «Restaurar proyecto» shows, the line reads EN “Archived project.” / ES «Proyecto archivado.» / CA «Projecte arxivat.» (new key, e.g. `archivedListNoAdd`). Keep `archivedListAddHelp` with the button.
- Verify: home_screen test: a viewer's archived project and a group-archived project show «Proyecto archivado.» with no «Restáuralo».
- Evidence: verified in code.

**R1C-3 · Severity 1 · Proyectos ⋮ «Compartir» opens a page titled «Miembros»**
- Where: `App/lib/screens/task_lists_screen.dart:405-415` (`list.canManage ? shareProject : people`) against the new title (`list_sharing_screen.dart:352-354`).
- What happens: for the owner of a shared project, the ⋮ item says «Compartir». The page it opens is titled «Miembros», and the project page's button for the same page reads «Miembros · 3».
- Fix: label the item `people` («Miembros») whenever `list.shared`, and `shareProject` only for an unshared project the person owns. That matches the project page's button.
- Verify: task_lists_widget test: a shared project's ⋮ reads «Miembros»; an unshared owned one reads «Compartir».
- Evidence: verified in code.

**R1C-4 · Severity 1 · «Miembros» said three times on the owner's page**
- Where: `App/lib/screens/list_sharing_screen.dart:413` `SectionLabel(people)` under the new app-bar title «Miembros».
- What happens: render `sharing/project-sharing.owner.es.light.1x.png`: the app bar «Miembros», then «Matemáticas», then «MIEMBROS».
- Fix: drop the section label when the title is already `people` (shared). Keep it under «Compartir proyecto».
- Verify: the owner render shows one «Miembros».
- Evidence: seen in a current render.

**R1C-5 · Severity 1 · The group page doesn't mark the account's own row «(tú)»**
- Where: `App/lib/screens/groups_screen.dart` (members list); render `sharing/group.owner.es.light.1x.png` shows «María · Propietario».
- What happens: the project's members page now marks «María (tú)», but the group's members list doesn't. The same person reads differently in two lists one tap apart.
- Fix: use `personYou(name)` for the account's own row in the group members list.
- Verify: group.owner render reads «María (tú)».
- Evidence: seen in a current render.

**R1C-6 · Severity 1 · The two invite dialogs still word their help differently**
- Where: `groupInviteHelp` (ES «Verán todos los proyectos… Les enviaremos un correo…», 27 words) under the new singular «¿A quién invitas a {group}?». The project's help became «Esa persona verá todo lo que hay en {project}.»
- Fix: EN “They’ll see every project in this group. We’ll email them an invitation.” / ES «Esa persona verá todos los proyectos de este grupo. Le enviaremos una invitación por correo.» / CA «Aquesta persona veurà tots els projectes d’aquest grup. Li enviarem una invitació per correu.»
- Verify: catalog test, and the group invite dialog in the groups test.
- Evidence: verified in code.

### Noted, not counted
- The preview fixture gives group members the role `'member'`, which the server never sends (admin/editor/viewer). `group.owner` therefore shows a raw «member» under Lucía. That's a test-fixture problem in `sharing_previews.dart:111,120,124`, not an app one.
- The archived project page still offers «Compartir» (unchanged).
