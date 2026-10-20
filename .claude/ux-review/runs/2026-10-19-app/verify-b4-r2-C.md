## UX verify — 2026-10-19-app, b4 round 2, area C (P210–P212) — 2026-10-20

**Verdict:** All 6 findings are fixed against their acceptance checks. There are 2 small regressions, both on the new Activity waiting row: TalkBack hears nothing while it waits (S2), and the spinner narrows the row so its text re-wraps (S1).
**Evidence:** I read the code with `git diff HEAD`. Renders in `App/build/ux/{sharing,tasks}/` date from 2026-10-20 20:35–20:36, and `find App/lib App/assets -newer` lists nothing newer, so they are current. No preview shows the Activity waiting state, so that part is reasoned from the widget code. Tester results as given. The two-account phone check for UX-1640 is still open.

### Findings

| ID | Result | Evidence |
|---|---|---|
| UX-1640 | fixed | `activity_screen.dart:105-160` `_open`. It keeps the `loadTasks()` future (`synced`). A task already on the phone opens at once (`_show`). A `deleted` entry says `taskRemoved` at once (`:125`). Any other missing task sets `_waiting` and awaits the sync (`:139`), then looks again. It opens the task if found, and says `taskRemoved` only if it's still missing. `still()` (`:133`) drops the result once the person has tapped another row (`_show` clears `_waiting`), has left Activity (`isCurrent`) or has switched account. `finally` clears the spinner. The row shows a 48/24 dp spinner and `onTap: null` while waiting (`:257-268`). `TaskNotifier.loadTasks()` returns the running loop's future and runs it again with `_loadAgain`, so the await covers a fresh sync. All 6 acceptance tests pass. Device check still open. |
| UX-1641 | fixed | `home_screen.dart:486-487` `canRestore = archived && list!.archived && !list.groupArchived && list.canManage`. `:799-802`: the line reads `archivedListAddHelp` only with `canRestore`, and `archivedListNoAdd` otherwise. `:805`: the button shows under the same condition. The catalogs are EN “Archived project.” / ES «Proyecto archivado.» / CA «Projecte arxivat.», with accurate @descriptions. The file keeps CRLF. Render `tasks/project.archived.es.light.1x.png` (owner): «Proyecto archivado. Restáuralo para añadir tareas.» with «Restaurar proyecto» under it. |
| UX-1642 | fixed | `task_lists_screen.dart:404-417`: `shareProject` only when `!shared && groupId == null && role == 'owner'`, and `people` otherwise. This matches the project page's button (`home_screen.dart:578-595`: «Compartir» for an unshared personal project, «Miembros · N» once shared). The comment is updated. Tests pass. |
| UX-1643 | fixed | `list_sharing_screen.dart:414` `if (!shared) SectionLabel(people)`. Render `sharing/project-sharing.owner.es.light.1x.png`: «Miembros» appears once, in the app bar, then «Matemáticas», «Invitar a una persona», «María (tú) · Propietario», Ana, Paul, «INVITACIONES PENDIENTES». |
| UX-1644 | fixed | `groups_screen.dart:669-673`: `person.id == me ? personYou(name) : name`. Tooltips keep the plain name. The preview fixture now uses 'editor' (`sharing_previews.dart:111,120,124`). Render `sharing/group.owner.es.light.1x.png`: «María (tú) · Propietario», «Paul · Administrador», «Lucía · Editor», with no raw «member». |
| UX-1645 | fixed | `groupInviteHelp` in the three catalogs matches the brief word for word (ES `app_es.arb:1150`, CA `:854` with ’), and @description is added in EN `:2047-2049`. It's generated (`app_localizations_es.dart:3449`). Render `sharing/group.invite.es.light.2x.png`: the help shows whole. The help is now 16 words in ES, down from 27. |

### Regressions

**R2C-1 · Severity 2 · TalkBack hears nothing while an Activity row waits**
- Where: `App/lib/screens/activity_screen.dart:257-268`, `_ActivityRow` while `waiting`.
- The moment (TalkBack user): "I double-tapped Lucía's entry. Nothing. Did it work?"
- What happens: the spinner is a `CircularProgressIndicator` with no `semanticsLabel`, so it announces nothing. `onTap: null` also takes the row's tap action away. So a TalkBack user double-taps and hears nothing until the task opens, or the "may be deleted" message arrives. On a slow network, each sync request may take up to 12 s (`api_client.dart:628-636`). A sighted user sees the spinner; a TalkBack user gets no feedback.
- Why: status messages must be announced to assistive technology (WCAG 2.2 SC 4.1.3); visibility of system status (Nielsen 1994).
- Fix: give the spinner a label, and announce it once when waiting begins (`SemanticsService.announce`, or `Semantics(liveRegion: true)` around the trailing). New key `activityFindingTask`: EN “Finding the task…” / ES «Buscando la tarea…» / CA «S’està cercant la tasca…». Don't reuse `accountSyncing` («Sincronizando»): "sync" is an internal term. The Projects delete spinner (`task_lists_screen.dart:365-374`) has the same gap but isn't in scope here.
- Verify: activity test with a hanging sync: after the tap, the row's semantics contain «Buscando la tarea…» (and an announcement is sent, if that route is taken). TalkBack check on the emulator lane.
- Evidence: verified in code.

**R2C-2 · Severity 1 · The waiting spinner re-wraps the row's text**
- Where: `App/lib/screens/activity_screen.dart:257-266`.
- The moment: "I tapped it and the words jumped."
- What happens: Activity rows have no trailing widget, so the title is about 312 dp wide at 360 dp (the ListView has 24 dp padding). While waiting, a 48 dp trailing plus ListTile's 16 dp gap appears, and the title shrinks to about 248 dp. A two-line entry at 1.3–2× text («Paul te ha asignado: …») gains a line, and the rows below shift, right under the finger that tapped. The Projects delete spinner that this copied swaps for a 48 dp ⋮ that was already there, so it never reflows.
- Why: change blindness and stable layout at the point of attention (Rensink et al. 1997); lens F, the same component behaving the same everywhere.
- Fix: keep the row's text width. Show the wait as a 2 dp `LinearProgressIndicator` along the bottom of the row, in a `Stack` or under the `ListTile` in a `Column`, and drop the trailing spinner. Or reserve no trailing slot and put a 16 dp spinner before the subtitle's date. Keep `onTap: null` while waiting.
- Verify: widget test at 360×800, 2×, with a two-line entry: the title's line count and the row's height are the same before and after the tap.
- Evidence: inferred from widget code (no preview of the waiting state).

### Noted, not counted
- Residual of UX-1640's class, not caused by P210: when the tasks sync fails (the connection drops after Activity loaded, or a server error or timeout), `TaskNotifier` catches the error. The task is still missing, so the row spins and then says «Es posible que esta tarea se haya eliminado.». The message is still not what happened. A possible follow-up: after the await, if the repository's sync failed, show `loadFailed` («No se ha podido cargar. Revisa la conexión.») instead of `taskRemoved`. The repository's `syncError` is also set for list conflicts, so the check needs care. This is rare, because Activity itself needs the network to list entries.
- Pre-existing, as the tester said: in `sharing/group.invite.es.light.2x.png` the dialog scrolls the focused field into view, so the title is cut at the top. «0/254» is cut, and «Enviar invitación» wraps to two lines. The new help is shorter than the old one, so it didn't cause any of this.
