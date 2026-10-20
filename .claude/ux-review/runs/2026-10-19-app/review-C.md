## UX review — C · Lists, notes, groups and sharing (whole area) — 2026-10-19

**Verdict:** Ship after fixes. Nothing here blocks a core task now. But at the newcomer's text size, Tareas shows its filters instead of its tasks. Two ticked "all" chips contradict each other. The invite field reads as "your email". And several screens promise what they don't do: the members page, the reminder line, and an archived project's «Añadir tarea».

**Walked** (newcomer: Spanish, 1×–2× text, 360–393 dp, one hand; daily user; TalkBack):
1. **Find my tasks: Tareas compared with Calendar.** 1 tap. ES and CA, 1× and 2×, with and without a shared project.
2. **One person's tasks in a shared project:** Tareas → Proyectos → Matemáticas → Ana, 4 taps. Then:
   - add a task under Ana's chip: +2–3;
   - open one to read «Creada por»: +1;
   - ✓ to see what's done: +1.
3. **Share a personal project:** 7 taps from Calendar, or 4 from the project's page, plus typing. Then the one-time name question.
4. **Accept an invitation**, four ways:
   - from the email link: 1 tap;
   - from the in-app card: 2 taps, plus a code fetched from the email;
   - from a link opened while signed out;
   - an invitation that's no longer available.
5. **A member checks who's in a project:** «Miembros · 3», 1 tap.
6. **Groups:**
   - create: 3 taps plus a name;
   - invite: 8 taps plus typing plus a role choice;
   - revoke: 1 tap;
   - archive: 1 tap plus Deshacer;
   - leave: 2 taps.
7. **Activity:** the header's people icon, then a row. 2 taps.
8. **Notes:**
   - add by voice or typing: 2–3 taps;
   - find; open; edit: 2 taps;
   - on a free account with no dictations left.
9. **Archive a project:** archive it, open it, and add a task. Also mute a project.
10. **Move a task into a new project** from its detail.

States checked: first use and empty, loading, offline, no match, many people, view-only, archived, keyboard up, 2× at 360 and 393 dp, ES/CA/EN, dark.

**Evidence:**
- **Previews:** `App/build/ux/` (`tasks/`, `sharing/`, `notes/`), rendered 13:26–13:28 from 3a6ad40. `find App/lib App/assets -newer <png>` lists nothing, so they're current. AUDIT.md gives the TalkBack trees, gaps and cut text.
- **Emulator captures** (13:31–14:42, 3a6ad40) show only Tareas, Notas and a task's detail from this area.
- **Code** for everything else.
- **GUIDELINES.md** is present.
- **SEEN-2026-10-19:** none of its 14 items is in area C. #7, Back from a shared text's form, is A/B's.
- **Previews scale 2× linearly; Android 14+ doesn't for headlines** (see Cross-slice notes). So I measured large-text claims on the emulator, or with a Manrope model of Android's 2.0 sizes.

**Numbers:**

| What | Measured | After the fixes |
|---|---|---|
| Tareas, new account (1×, 360 dp) | 13 tap targets, 33 words (2026-10-13: 18 targets, 56 words) | 8 targets: no search and no filter chips on an empty list |
| Tareas, account with a shared project (1×) | 17 controls besides the tasks, 12 of them above the first task | 15, 10 above |
| Tasks on screen at 2.0 text (emulator, 393 dp, no shared project) | Tareas 1 (first task ≈ 510 dp down); Calendar 2 (≈ 390 dp) | Tareas ≈ 2: the date chips go from 3 rows to 1 (Manrope model) |
| Tasks on screen at 2× with a shared project | 0 (preview, 360 dp, linear 2×) | ≈ 1 (model, 393 dp, Android's 2.0) |
| Project page, shared (1×) | 11 controls above the tasks; the project name repeated on every row | the name gone from rows |
| Share a personal project | 7 taps from Calendar, 4 from its page, plus typing | unchanged |
| Invite someone to a group | 8 taps plus typing plus a 2–3-way role choice; code dialog 42 words | 7 taps, no role choice; 14 words |
| Invite someone to a project | code dialog 14 words | unchanged |
| A member's «Miembros · 3» page | 0 people listed; 21 words of role line and pitch | 3 names; the 21 words gone |
| An owner's «Miembros · 3» page | 2 people listed | 3 |

### Findings (most severe first)

**UX-1501 · Severity 2 · At large text, Tareas shows filters instead of tasks**
- **Where:** the Tareas root header, `App/lib/screens/home_screen.dart`:
  - headline, «Proyectos» and ✓: `:428-450`;
  - search: `:509-518`;
  - four date filter chips: `:520-538`;
  - scope chips: `App/lib/widgets/project_scope_control.dart:87-221`.
- **The moment:** "I tapped Tareas. Where are my tasks? I only see buttons."
- **What happens:**
  - **Emulator, 2.0 text** (393 dp, no shared project; `App/build/ux/device/screen-tasks.list.es.light.2.0.png`):
    - The headline, «Proyectos ✓», the search and the chips «Todas las tareas», «Sin fecha», «Hoy» and «Prioridad alta», in three rows, push the first task down to about 510 dp.
    - One task fits above «Añadir tarea».
    - Calendar at the same size shows two (`device/screen-calendar.today.es.light.2.0.png`).
  - **With a shared project:** «Todos los proyectos · Todas · Para mí» adds two more chip rows. The 2× preview shows no task at all (`tasks/tasks-tab.normal.es.light.2x.png`).
  - **«Prioridad alta» shows when no task has a priority.** A brand-new account sees it, and the search and all four chips sit above its empty state (`tasks/tasks-tab.empty.es.light.1x.png`).
  - **The header scrolls away**, so the tasks are reachable by scrolling; hence severity 2.
- **Why it fails:**
  - SC-5: what the user came for shows without scrolling (Fessenden 2018, direction only).
  - CO-7: progressive disclosure (Nielsen 2006), and CLAUDE.md's "show advanced things only when relevant".
  - Recurring problem: controls that matter later, shown from day one.
- **Fix (subtract):**
  1. Show «Prioridad alta» only while an open task has high priority. Priority is set only in Más detalles or by the assistant.
  2. When there are no open tasks at all, hide the search and the filter chips. The empty state already says what to do. Keep them when a filter or a search empties the list.
  3. With UX-1502's change, «Sin fecha» and «Hoy» fit one row at 2.0 on 393 dp. Manrope model of Android's 2.0 sizes (14 sp → 26 dp): 144 + 8 + 75 = 227 of 345 dp.

  No copy change. Don't wait for U13: the owner's §7 test runs on this layout.
- **Verify:**
  - Widget tests:
    - no «Prioridad alta» chip unless an open task has priority 3;
    - no search and no chips with zero open tasks;
    - both are kept when a search finds nothing;
    - at 2× on 393 dp, «Sin fecha» and «Hoy» share one row.
  - Recapture `screen-tasks.list.es.light.2.0` on the emulator: 2 tasks above «Añadir tarea».
  - Don't count tasks on the linear 2× preview: at 360 dp it wraps «Tus tareas» onto two lines, which Android's 2.0 doesn't (Cross-slice notes).
- **Evidence:** seen in an emulator capture (1 task against Calendar's 2); seen in a current render (0 tasks); chip widths from the Manrope model.

**UX-1502 · Severity 2 · «Todas las tareas» is ticked while only yours show**
- **Where:**
  - `App/lib/screens/home_screen.dart:525-536`: the root filter chip `allTasks`, «Todas las tareas».
  - `App/lib/widgets/project_scope_control.dart:205-218`: the app-wide «Todas» / «Para mí».
  - `App/lib/providers/project_scope_provider.dart:7`: «Para mí» is the default.
  - `project_scope_control.dart:252-256`: on project pages, TalkBack names the people chip «Todas» as `allTasks`.
- **The moment:** "It says «Todas las tareas», ticked. So why isn't Ana's task here? And what's the other «Todas» for?"
- **What happens:**
  - With a shared project, Tareas shows «Todas» and «Para mí ✓» (people) above «Todas las tareas ✓» (dates). The two ticks disagree: «Para mí» hides other people's tasks while the chip below says "all tasks".
  - One view holds three "all" words: «Todos los proyectos», «Todas» and «Todas las tareas».
  - TalkBack reads this «Todas» as «Todas», but the people chip on a project page as «Todas las tareas», the same name as this date filter (AUDIT `tasks/tasks-tab · normal` against `tasks/project · shared`).
  - Catalan has the same clash: «Totes», «Per a mi ✓», «Totes les tasques ✓» (`tasks/tasks-tab.normal.ca.light.2x.png`).
- **Why it fails:**
  - SC-9: one name per concept (WCAG 2.2 3.2.4; COGA 2021).
  - CO-3: nothing to remember (Cowan 2001).
  - Nielsen's match between system and real world.
- **Fix (subtract one chip):**
  - Drop «Todas las tareas» from the root filters.
  - «Sin fecha», «Hoy» and «Prioridad alta» become toggles (FilterChip): one tap filters, a second tap shows everything again. "Nothing selected" means all.
  - No new copy.
  - Only if the toggle is refused: rename the people chip `forTeam` instead (ES «De todos», EN "Everyone's", CA «De tothom»; needs a Catalan read).
- **Verify:**
  - Widget tests:
    - Tareas has no chip «Todas las tareas» / "All tasks" / «Totes les tasques»;
    - tapping «Hoy» twice returns the full list, and TalkBack reports the selected state.
  - Previews `tasks/tasks-tab.normal` in ES and CA.
- **Evidence:** seen in current renders (ES 1×, CA 2×) and in AUDIT's TalkBack lists; verified in code.

**UX-1503 · Severity 2 · «Su correo» reads as "your email" in invites**
- **Where:**
  - Project invite: `App/lib/screens/list_sharing_screen.dart:201`, `:223`, `:233`:
    - title `shareProjectTitle`, «Compartir {project}»;
    - label `theirEmail`, «Su correo» (CA «El seu correu»);
    - help `shareProjectHelp`, «Verá todo lo que hay en {project}.».
  - Group invite: `App/lib/screens/groups_screen.dart:444-451`, through `groupTextDialog`, where the title is the label (`:73`, `:101-104`): `inviteeEmail`, «Correo de su cuenta» (CA «Correu del seu compte»).
- **The moment:** "«Su correo»… mine? I'll put my email." Then: «Esta persona ya tiene acceso. Gestiona su rol en Miembros.»
- **What happens:**
  - In Spanish and Catalan, «su» / «el seu» is also the formal "your" of official forms («Introduzca su correo»), and «Verá» reads as "you'll see".
  - The rest of the app says «tú».
  - The render shows «Su correo» right under «Compartir Matemáticas» (`sharing/project-sharing.invite.es.light.1x.png`).
  - Typing your own address gets the server's «Esta persona ya tiene acceso…» (`App/lib/l10n/request_locale.dart:58`, `sharingProblem` alreadyMember). It talks about a third person.
- **Why it fails:**
  - Plain language (ISO 24495-1: understandable).
  - LO-9: one form of address.
  - UN-7 and OL-2: an error that doesn't say what happened (Neusesser 2023; Nielsen 2013).
- **Fix:**
  - **Both dialog titles become a question; the label becomes a plain noun:**

    | | ES | EN | CA |
    |---|---|---|---|
    | Title | «¿A quién invitas a {name}?» | "Who are you inviting to {name}?" | «A qui convides a {name}?» |
    | Label | «Correo» | "Email" | «Correu» |

    A short label stays whole when it floats at 2×. «Correo de la persona» measures 230 dp against about 200 dp of room.
  - **Project help:** ES «Esa persona verá todo lo que hay en {project}.»; CA «Aquesta persona veurà tot el que hi ha a {project}.»; EN unchanged.
  - **The account's own address**, typed in either dialog, gets a line under the field before anything is sent: ES «Ese es tu correo. Escribe el de la persona que invitas.»; EN "That's your own email. Type the other person's."; CA «Aquest és el teu correu. Escriu el de la persona que convides.»
- **Verify:**
  - Widget tests (ES, EN, CA): both dialogs show the new title and label; the own address shows the line and makes no request.
  - Preview `sharing/project-sharing.invite`.
- **Evidence:** seen in a current render; verified in code. The misreading is a language judgement; watch for it in the §7 test.

**UX-1504 · Severity 2 · Tasks added in an archived project never reach Calendar**
- **Where:**
  - `App/lib/screens/home_screen.dart:379-385`: `readOnly` and `addTo` ignore an archived project; `:663-670`: `TaskActions`.
  - `App/lib/providers/task_lists_provider.dart:16-19`: `listCanEditProvider` ignores archiving.
  - Hidden from Calendar and Tareas: `App/lib/providers/project_scope_provider.dart:53`.
  - No reminders: `App/lib/services/task_database.dart:383-387`.
  - The picker leaves archived projects out: `App/lib/widgets/task_list_picker.dart:44-46`.
- **The moment:** "I opened «Trabajo» and added «Llamar al jefe mañana a las 9». Why didn't it ring, and why isn't it on the calendar?"
- **What happens:**
  - An archived project's page shows «Proyecto archivado» as plain grey text (`:452-459`), and still offers «Añadir tarea». The capture sheet saves there too.
  - What's added shows on that page only: never on Calendar or Tareas, and it never reminds.
  - Moving a task into an archived project is impossible from the picker, so the two doors disagree.
  - Archiving is one tap in Proyectos ⋮, and the project then moves to the end of the list.
- **Why it fails:**
  - Visibility of system status and error prevention (Nielsen 1994).
  - TA-6: reminders fire, or the app says why not.
  - Recurring problem: the app acts silently.
- **Fix:**
  - Treat an archived project like a read-only one. In place of «Añadir tarea», a bar:
    - ES «Proyecto archivado. Restáuralo para añadir tareas.»;
    - EN "Archived project. Restore it to add tasks.";
    - CA «Projecte arxivat. Restaura'l per afegir-hi tasques.»
  - Add «Restaurar proyecto» (`restoreList`) for whoever manages it.
  - A project archived with its group gets the line without the button.
  - Remove the separate `archivedList` line.
- **Verify:**
  - Widget tests:
    - an archived project's page has no «Añadir tarea», and «Restaurar proyecto» brings it back;
    - a group-archived project shows the line without the button.
  - New preview `tasks/project.archived`.
- **Evidence:** verified in code. No render of an archived project's page exists.

**UX-1505 · Severity 2 · Reminder line promises reminders this phone won't give**
- **Where:**
  - `App/lib/widgets/reminder_control.dart:19-33`: `_cannotFire` checks only the switch and the permission.
  - `:190-260`: `ReminderChip`, «Recordatorio: {value}».
  - The rule behind it: `App/lib/services/task_database.dart:383-391`. No reminders for archived or muted projects, or for tasks that aren't this account's.
- **The moment:** "It says «Recordatorio: 10 minutos antes». Why didn't my phone ring?" The project was muted. Or María reads it on Ana's task and expects a reminder herself.
- **What happens:** three cases read «Recordatorio: …» and never ring on this phone:
  - a task in a muted project («Silenciado: sin novedades ni recordatorios»);
  - a task in an archived project;
  - a shared task given to someone else. It rings on their phone only. AUDIT for `tasks/detail · created-by` shows María reading «Recordatorio: 10 minutos antes» on Ana's task.
- **Why it fails:**
  - TA-6: say why not, where reminders are set (Android Alarms).
  - UX-209 already fixed the same promise for reminders switched off.
  - SH-2: awareness in place (Neustaedter 2006).
- **Fix:** the chip also reads the task's project and person. New copy:

  | Case | ES | EN | CA |
  |---|---|---|---|
  | Someone else's task | «Recordatorio para {name}: {value}» | "Reminder for {name}: {value}" | «Recordatori per a {name}: {value}» (needs a Catalan read for the article) |
  | Muted project; a tap opens its «Novedades del proyecto» | «Sin recordatorio: proyecto silenciado» | "No reminder: project muted" | «Sense recordatori: projecte silenciat» |
  | Archived project | «Sin recordatorio: proyecto archivado» | "No reminder: project archived" | «Sense recordatori: projecte arxivat» |
- **Verify:**
  - Widget tests for the three cases on the detail and the form, in ES, EN and CA.
  - Preview `tasks/detail.created-by` reads «Recordatorio para Ana: …».
- **Evidence:** verified in code; AUDIT's TalkBack list for the detail.

**UX-1506 · Severity 2 · «Miembros · 3» opens a page that doesn't list them**
- **Where:**
  - `App/lib/screens/home_screen.dart:461-494`: the button counts `list.people`.
  - `App/lib/screens/list_sharing_screen.dart`:
    - `:412-432`, owner: rows come from `data['members']`, which leaves the owner out;
    - `:395-404` and `:515-543`, member: a role line, `sharingHelp`, Novedades and Salir, but no people;
    - `:352`: the title `listSharing`, «Compartir proyecto».
- **The moment** (member): "I tapped «Miembros · 3» to see who's in the club. It says «Compartir proyecto», «Tu rol: Lector» and something about sharing shopping."
- **What happens:**
  - **A member** of a project shared person to person, editor or reader, sees nobody (`sharing/project-sharing.reader.es.light.2x.png`):
    - the title «Compartir proyecto», though they can't share;
    - «Tu rol: Lector»;
    - `sharingHelp`: «Comparte compras y tareas de casa. Los cambios se sincronizan cuando la aplicación se conecta o cuando actualizas.» A pitch, sync jargon, and there's nothing here to refresh.
  - **The owner** sees «Miembros · 3» on the project page (`tasks/project.shared.es.light.1x.png`) and 2 rows under MIEMBROS (`sharing/project-sharing.owner.es.light.1x.png`). They aren't listed themselves.
  - **A group project's «Miembros»** opens the group page, which lists everyone. So the two kinds of shared project differ.
- **Why it fails:**
  - Gulf of evaluation (Norman 2013).
  - SC-9: the button and the page disagree.
  - SH-1: viewers need no training (Neustaedter 2006).
  - Recurring problem: copy borrowed from another context.
- **Fix:**
  - Title the page `people` («Miembros» / "Members" / «Membres») once the project is shared. Keep «Compartir proyecto» until then.
  - List everyone, the owner first:
    - members get it from `TaskListInfo.people`: names and roles, no emails, because the server gives emails to the owner only (`Backend/core/list_views.py:141-143`);
    - the owner's own row comes first, so «Miembros · 3» shows 3 rows.
  - Mark the account with a new string: ES «{name} (tú)», EN "{name} (you)", CA «{name} (tu)».
  - Remove `yourRole` and `sharingHelp` from the member view (21 words). Their own row shows the role.
- **Verify:**
  - Widget tests:
    - the member view lists 3 names, including «(tú)», with no «Comparte compras», under the title «Miembros»;
    - the owner view shows 3 rows for «Miembros · 3».
  - Previews `sharing/project-sharing.reader` and `.owner`.
- **Evidence:** seen in current renders; verified in code.

**UX-1507 · Severity 2 · An invitation opened while signed out waits silently**
- **Where:**
  - `App/lib/main.dart:228-236`: `_openInvitation` returns while signed out.
  - `App/lib/services/invitation_links.dart:79-93`: the link is kept for 7 days.
  - Sign-in (`App/lib/screens/login_screen.dart`) never mentions it.
- **The moment:** Dad, invited by his son, taps the email's link. TaskFlow opens on sign-in with no word about the invitation. He creates an account with another address, and later reads «Esta invitación no está disponible para esta cuenta».
- **What happens:**
  - The link waits until someone signs in.
  - Nothing says an invitation is waiting, or which account to use.
  - An invitation is bound to its address, so signing up with another one ends in UX-1509's dead end.
  - It was first raised as a cross-slice note in 2026-10-13 review C and never filed.
- **Why it fails:**
  - Visibility of system status (Nielsen 1994).
  - CO-3: nothing to remember, here the address the email went to (Cowan 2001).
  - OL-11: first run without a helper.
- **Fix:** while `invitationLinkProvider` holds a link and nobody is signed in, show one line above the sign-in choices. It goes once the link is used or cleared.
  - ES «Tienes una invitación. Entra con el correo en el que la recibiste.»
  - EN "You have an invitation. Sign in with the email address it was sent to."
  - CA «Tens una invitació. Entra amb el correu on l'has rebuda.»
- **Verify:**
  - Widget test: with a stored link and no account, sign-in shows the line in ES, EN and CA; without a link it doesn't.
  - New preview state `auth/sign-in.invitation`.
- **Evidence:** verified in code. The line lives on area D's screen.

**UX-1508 · Severity 2 · The name question covers «Te has unido a…»**
- **Where:** `App/lib/widgets/invitation_cards.dart:339-370`. `showJoined` pushes the page, shows `joinedInvitation` (`:361`), then at once runs `unawaited(askForNameOnce(...))` (`:368`). The sheet itself: `App/lib/widgets/name_ask_sheet.dart:45-86`.
- **The moment:** "I joined. Did it work? Now it's asking my name and the keyboard is up."
- **What happens:**
  - A password account without a name joins, through «Aceptar invitación» or «Unirme».
  - The project page opens, and at once a sheet with the keyboard up (`autofocus`) covers it.
  - The sheet and its scrim hide «Te has unido a {name}». That message has no action, so it times out while the person types.
  - The reminder question waits for its message to close first (`App/lib/widgets/reminder_ask_sheet.dart:64-75`); this one doesn't.
  - `App/test/name_ask_test.dart:235` asserts the sheet right after joining.
- **Why it fails:**
  - SC-10 and SC-11: show the change, end on visible success (Rensink 1997; Kahneman 1993).
  - Same pattern as UX-439, fixed for the reminder sheet.
- **Fix:**
  - In `showJoined`, wait for `closed` on the controller `showFeedback` returns before calling `askForNameOnce`, as `_ask` does in `reminder_ask_sheet.dart`.
  - Skip the question if the person left the joined page meanwhile.
  - No copy change.
- **Verify:** extend `App/test/name_ask_test.dart` ('joins a project with «Unirme»'):
  - right after joining, «Te has unido a Casa» shows and no BottomSheet does;
  - once the message times out, the sheet shows, once.
- **Evidence:** verified in code. No render of the joining moment exists.

**UX-1509 · Severity 2 · A dead invitation offers «Reintentar»; «Ahora no» deletes it**
- **Where:** `App/lib/screens/invitation_review_screen.dart`:
  - `:111-114`, `:169-210`: the unavailable state (`sharing/invitation.unavailable.es.light.1x.png`);
  - `:156-162`: «Acceso · Editor».
- **The moment:** "It isn't available for this account. «Reintentar»… same thing. «Ahora no»… so I can try later?"
- **What happens:**
  - **Reintentar:** for an invitation this account can't see (used, withdrawn, or sent to another address), the outlined «Reintentar» repeats the same request. It gets the same answer every time.
  - **Ahora no:** here it drops the link for good (`pop(_unavailable)` clears it). The same words elsewhere keep the link for Calendar's card.
  - **Acceso · Editor:** on a valid project invitation, Editor is the only possible role (D15b). It's a default shown as content. In Catalan at 2× it pushes «Accepta la invitació» further down (`sharing/invitation.from-ana.ca.light.2x.png`).
- **Why it fails:**
  - UN-8: "nothing found" isn't a dead end (Whitenton 2014).
  - SC-9: same words, different effect.
  - Recurring problem: defaults shown as content.
- **Fix:**
  - **Unavailable (404):** no «Reintentar». One button, ES «Cerrar» / EN "Close" / CA «Tanca», that clears the link. The message stays: it already says what to do. Offline keeps «Reintentar» and «Ahora no».
  - **The access line:** show it only when the role isn't Editor, worded as what it means.

    | Role | ES | EN | CA |
    |---|---|---|---|
    | Viewer | «Solo podrás verlo, no cambiarlo.» | "You'll be able to see it, not change it." | «Només el podràs veure, no canviar.» |
    | Group admin | «Podrás gestionar el grupo.» | "You'll be able to manage the group." | «Podràs gestionar el grup.» |
- **Verify:**
  - Widget tests:
    - the 404 state has no «Reintentar», and «Cerrar» clears the link;
    - offline still offers both buttons;
    - an editor invitation shows no access line.
  - Previews `sharing/invitation.unavailable` and `.from-ana` (ES; CA 2×).
- **Evidence:** seen in current renders; verified in code.

**UX-1510 · Severity 2 · Three taps wait for a full sync, showing nothing**
- **Where:**
  - **Activity:** `App/lib/screens/activity_screen.dart:62-96`. A tap sends a POST, then runs `loadTasks()` (`:81`), then a database lookup, then opens the task. `_busy` only stops further taps. At `:89`, a task that's gone opens nothing and says nothing.
  - **Deleting a project:** `App/lib/screens/task_lists_screen.dart:112-125`. A DELETE, then `loadTasks()` (`:122`), then the list and the message.
  - **The invitation's code dialog** waits for `loadTasks()`: `App/lib/screens/list_sharing_screen.dart:96` and `App/lib/screens/groups_screen.dart:368`.
- **The moment:** "I tapped Ana's update… nothing. Tap again… still nothing. Oh, now it opened." / "I deleted «Trabajo»; it's still there."
- **What happens:**
  - `loadTasks()` is a full server sync (`App/lib/providers/task_provider.dart:43-71`).
  - Activity shows no progress while it runs. An entry about a deleted task («Lucía ha eliminado: …») does nothing at all.
  - Deleting a project leaves its row on screen, with no sign of progress, until the sync ends.
  - After «Enviar invitación», a thin bar runs until the sync ends; only then «Invitación enviada».
- **Why it fails:**
  - UN-1 and PE-2: answer at once, show progress past 1 s (Nielsen 1993).
  - UN-8: a dead end must say so.
  - Recurring problem 18: background work awaited in the tap path.
- **Fix:** show first, sync behind (`unawaited`), as `showLocal()` does for saves.
  - **Activity:** look the task up on the phone and open it; mark it read and sync behind. If it's gone, show the existing `taskRemoved` («Es posible que esta tarea se haya eliminado.»).
  - **Delete:** once the server answers, refresh the list and show «Proyecto eliminado». While the DELETE runs, the row shows a spinner.
  - **Invite:** show the code dialog as soon as the POST returns.
- **Verify:** widget tests with a sync that never completes (as in `App/test/capture_landing_test.dart:610`):
  - an Activity tap opens the task;
  - a deleted task's entry shows `taskRemoved`;
  - «Proyecto eliminado» shows and the row goes;
  - «Invitación enviada» shows.
- **Evidence:** verified in code.

**UX-1511 · Severity 2 · ✓ on a project shows every project's completed tasks**
- **Where:**
  - `App/lib/screens/home_screen.dart`:
    - `:371-375`: `pushNamed('/completedTasks')` with no arguments;
    - `:391`: on project pages, ✓ sits in the app bar;
    - `:438-447`: on Tareas, ✓ is an icon 0 dp from «Proyectos».
  - `App/lib/screens/completed_tasks_screen.dart:10-24`: every completed task, with no project, person or scope.
- **The moment:** "What has Ana finished in Matemáticas?" ✓ shows a list mixing Casa, Trabajo, Matemáticas and everyone.
- **What happens:**
  - From «Matemáticas» with «Ana» on, ✓ lists the completed tasks of every project and person. It even ignores the app-wide «Para mí».
  - On Tareas, ✓ is unlabelled and touches «Proyectos» (AUDIT: 0 dp gap). Only the tooltip says «Tareas completadas».
- **Why it fails:**
  - Context dropped (recurring problem; CO-3).
  - SC-6: label icons on the default path (Harley 2014).
  - RE-3: spacing between different targets (Jin 2007).
- **Fix:**
  - Pass the page's project and person: `CompletedTasksScreen(listId:, person:)` filters by project and assignee, and shows the project's name under its title.
  - On Tareas, replace the icon with `TextButton.icon(task_alt, …)`, 8 dp from «Proyectos»: ES «Completadas», EN "Completed", CA «Completades».
- **Verify:**
  - Widget test: from a project page with «Ana» on, ✓ lists only Ana's completed tasks in that project.
  - Tareas shows the word «Completadas».
  - AUDIT gap of at least 8 dp.
- **Evidence:** verified in code; AUDIT from current renders.

**UX-1512 · Severity 2 · Project rows repeat the project; who it's for is bare**
- **Where:**
  - `App/lib/widgets/task_tile.dart`: `:193-217`, the project label on every row; `:218-236`, `responsibilityLabel` as plain text with no icon.
  - `App/lib/widgets/task_list.dart:5-57`: no way to leave out the page's own project.
  - `App/lib/widgets/task_assignment_picker.dart:95-118`: TalkBack reads the chip as «Ana».
- **The moment:** "Every task says «Matemáticas», and I'm in Matemáticas. And «Matemáticas Ana»: is Ana part of the name?"
- **What happens:**
  - **On a project page, every row repeats the project** (`tasks/project.shared.es.light.1x.png`):
    - at 1×, this pushes «Paul» onto a second line;
    - at 2×, it takes a whole line («Excursión de…», `tasks/project.many-people.es.light.2x.png`), and one task fits on screen.
  - **Who it's for is plain grey text:**
    - TalkBack reads «… Hoy · 18:00 Matemáticas Ana Prioridad Media», and «Todos» becomes «Matemáticas Todos».
    - On the detail and the form, the same person is a chip with a person icon, which TalkBack reads as just «Ana», next to «Matemáticas» (AUDIT `tasks/detail · created-by`).
  - **«Sin fecha» (`/inbox`) does the same:** every row says «Sin fecha» under the «Sin fecha» title (`tasks/tasks-tab.inbox.es.light.1x.png`).
- **Why it fails:**
  - CO-5: cut extraneous load (Sweller 1988).
  - SC-1: front-load each line.
  - AC-6: name, role, value (WCAG 4.1.2).
  - SH-2: who, on the item itself.
- **Fix:**
  - `TaskList` and `TaskTile` take the page's project: rows leave out a project label equal to it, and «Sin fecha» on `/inbox`.
  - Before the name, show the chip's icon: `person_outline`, or `groups_outlined` for Todos.
  - The row's and the chip's TalkBack label: ES «Responsable: {name}», EN "Assignee: {name}", CA «Responsable: {name}». «Necesita responsable» stays as it is.
  - The project chip's TalkBack label: ES «Proyecto: {name}», EN "Project: {name}", CA «Projecte: {name}».
- **Verify:**
  - Widget test: on «Matemáticas», no row carries a «Matemáticas» label, and a row's TalkBack label contains «Responsable: Ana».
  - Preview `tasks/project.many-people` at 2×: the first card loses its «Excursión de…» line, at least 40 dp.
  - AUDIT for `detail · created-by` reads «Responsable: Ana».
- **Evidence:** seen in current renders and in AUDIT's TalkBack lists; verified in code.

**UX-1513 · Severity 2 · Groups invite and manage people differently from projects**
- **Where:**
  - `App/lib/screens/groups_screen.dart`:
    - `:440-463`, `_invite`: the email dialog, then a role sheet (`_chooseRole`, `:466-512`) with Editor, Lector and Administrador;
    - `:385-430`: the code dialog;
    - `:665-671`: a member's person-with-gear icon opens the role sheet;
    - `:686-695`: a pending invitation has a red ✕, tooltip `revokeInvitation` «Revocar invitación». It has no confirmation, and the same tooltip on every row.
  - `App/lib/screens/list_sharing_screen.dart`, for comparison:
    - `:158-258`: one field, with the role fixed to editor (D15b);
    - `:104-142`: the code dialog;
    - `:296-309`: a member's ⋮;
    - `:442-468`: a pending invitation's ⋮, «Reenviar» / «Anular invitación».
- **The moment:** "Last week I shared «Casa» with one field. Now, for the family group, it asks what Ana «puede hacer»: Editor? Lector? Administrador?"
- **What happens:**

  | | Group | Project |
  |---|---|---|
  | Invite | email → «Siguiente» → a role choice of 2–3 | one field |
  | Code dialog | «Código de invitación», 42 words (`invitationEmailSent`, `invitationCodeHelp`: «…Compártelo solo con la persona destinataria. Reemplazar una invitación invalida su código anterior.») | «Invitación enviada» + «Si no le llega el correo, envíale este código:», 14 words |
  | Pending invitation | an icon-only ✕ | a ⋮ |
  | One action, two words | «Revocar invitación» | «Anular invitación» |
  | A member's row | a sheet that ticks the current role | a ⋮ that offers the current role as if it were new |
- **Why it fails:**
  - SH-5: minimal roles, changed in place; role choices during an invite are a finding (Smetters 2009).
  - D15b.
  - SC-9: same action, same word, same place (WCAG 3.2.4).
  - SC-2 and OL-7: 42 words where 14 do.
- **Fix:** groups follow the project patterns.
  1. **Invite:** no role step; everyone joins as editor, as D15b does for projects. The person's row sheet already changes the role, including to Administrador.
  2. **Code dialog:** one for both, titled `invitationSent` with `invitationCodeFallback`. Remove `invitationEmailSent`, `invitationEmailPending` and `invitationCodeHelp` from it (−28 words).
  3. **Pending rows in groups:** a ⋮ with «Reenviar» and «Anular invitación», named per address (`manageItem(email)`). Retire `revokeInvitation`.
  4. **The project member ⋮:** offer only the role the person doesn't have.

  No new strings.
- **Verify:**
  - Widget tests:
    - a group invite sends `role: editor` with no sheet;
    - both flows show the same code dialog;
    - a group's pending row has a ⋮ with both items and a tooltip unique to the row;
    - an editor's ⋮ lacks «Dar permiso de edición».
  - Previews `sharing/group.owner` and `sharing/project-sharing.owner`.
- **Evidence:** verified in code; seen in current renders. D15b's scope is in Questions.

**UX-1514 · Severity 2 · «Ha cambiado el responsable» never says who it is now**
- **Where:**
  - The ARB key `activityEntry`, case assigned: ES «{actor} ha cambiado el responsable de: {title}».
  - `App/lib/screens/activity_screen.dart:175-183`.
  - The server's activity item has no assignee (`Backend/core/group_views.py:306`), and it goes to the new and the previous person alike (`Backend/core/collaboration.py:19-22`).
- **The moment:** "Paul changed who's responsible for «Reservar el autobús»… is it mine now, or did he take it off me?"
- **What happens:** the same words reach the person who got the task and the one who lost it (`sharing/activity.list.es.light.1x.png`).
- **Why it fails:** SH-3 and SH-4: name the person; say who did what (Darley 1968; Brush 2001).
- **Fix:**
  - The server adds the new assignee to each item: the name, and whether it's the reader. Cause likely server-side.
  - The app then says:

    | | ES | EN | CA |
    |---|---|---|---|
    | To the reader | «{actor} te ha asignado: {title}» | "{actor} assigned you: {title}" | «{actor} t'ha assignat: {title}» |
    | To someone else | «{actor} ha asignado a {name}: {title}» | "{actor} assigned {name}: {title}" | «{actor} ha assignat {name}: {title}» (needs a Catalan read) |

    The second also covers "taken off you".
- **Verify:**
  - Server test for the field.
  - App widget test for both sentences in three languages.
  - Preview `sharing/activity.list`.
- **Evidence:** seen in a current render; verified in code; cause likely server-side.

**UX-1515 · Severity 2 · A name asked once can never be changed**
- **Where:**
  - `App/lib/widgets/name_ask_sheet.dart:41-86`: the account counts as asked the moment the sheet shows.
  - `setFirstName` (`App/lib/providers/auth_provider.dart:162`) has no other caller.
  - Cuenta (`App/lib/screens/account_screen.dart`) shows no name.
- **The moment:** "I tapped «Ahora no»; now Ana sees «maria.lopez84». Where do I put my name?" / "It offered «Maria», and I saved it without the accent."
- **What happens:**
  - Any of these is final: «Ahora no», Back, a swipe, a typo, or an accepted suggestion («Maria» for María, `sharing/project-sharing.name-ask.es.light.1x.png`).
  - Every member then sees the email prefix, or the typo, on chips, «Creada por», assignments and Activity.
  - Google accounts can't change Google's first name either.
- **Why it fails:**
  - OL-1: design for recovery (Kane 2019).
  - User control and freedom (Nielsen 1994).
  - D8 says the question is asked once; it doesn't say the name can't change.
- **Fix:**
  - In Cuenta, one row: ES «Nombre · María», EN "Name · María", CA «Nom · María» (label `nameAskField`).
  - It opens the same sheet, filled in with the current name.
  - One row on a rare screen, nothing on the default path. If that counts as a feature, see Questions.
- **Verify:**
  - Widget test: Cuenta shows the row for password and Google accounts; changing it sends `PATCH auth/me/`.
  - Preview `settings/account`.
- **Evidence:** verified in code. Cuenta is area D's screen.

**UX-1516 · Severity 2 · The project sheet can't start a new project**
- **Where:** `App/lib/widgets/task_list_picker.dart:94-100`: «Nuevo proyecto» appears only when `choices` is empty.
- **The moment:** "This goes in a new «Viaje» project." The chip shows only existing projects.
- **What happens:**
  - With one editable project or more, the sheet lists projects and «Sin proyecto», but no «Nuevo proyecto».
  - The way round takes about 8 taps: back out, Tareas → Proyectos → Nuevo proyecto → name → leave the new page → reopen the task → the chip → pick.
- **Why it fails:**
  - CO-10: price each step, about 8 taps against 3 (Card 1980).
  - User control and freedom.
- **Fix:**
  - Show the existing «Nuevo proyecto» row last whenever no dictated project shows (`!creating`).
  - It already creates the project and returns it (`:111-114`).
  - No new string.
- **Verify:** widget tests:
  - with 2 projects, «Nuevo proyecto» is the last row, and creating «Viaje» moves the task there;
  - with a dictated project, it stays hidden (UX-1106).
- **Evidence:** verified in code.

**UX-1517 · Severity 2 · Notes made in the sheet show their first words twice**
- **Where:**
  - `App/lib/screens/notes_screen.dart:302-307`: `_preview` drops the first line only when it equals the title.
  - `App/lib/services/local_capture.dart:57-68` and `App/lib/services/capture_processor.dart:28-33`: a note's title is its first sentence, or about 60 characters; the whole text stays in the body.
- **The moment:** "Did it save twice? «Para la reunión del cole: preguntar por el comedor y por la»… «Para la reunión del cole: preguntar por el comedor y por la excursión de primavera»."
- **What happens:**
  - Every note made in the capture sheet, dictated or typed there, has a title that is the start of its body. The result card shows both (`notes/note-capture.result.es.light.1x.png`).
  - Speech has no line breaks, so the list's preview repeats the title. Only the end is new.
- **Why it fails:**
  - CO-5: no repeated text (Sweller 1988).
  - SC-1: front-load each line.
- **Fix:**
  - When the body starts with the title, the preview shows only the rest, without the joining space or punctuation.
  - Nothing left: no preview line.
  - No copy change.
- **Verify:**
  - Widget test: that note's row shows «excursión de primavera» as its preview.
  - Preview `notes/notes-tab.list` with one dictated note.
- **Evidence:** verified in code; the result card is seen in a current render; the list case isn't rendered.

**UX-1518 · Severity 2 · At 0 dictations left, every note opens with the limit**
- **Where:**
  - `App/lib/screens/voice_task_screen.dart`:
    - `:1896-1902`: `usedUpLine` shows whenever there's no mic and the dictations are used up;
    - `:2029-2049`: the line and «Ver Pro», above the field;
    - `:84-97`: only tasks are sent to the form.
  - «Añadir nota» (`App/lib/screens/notes_screen.dart:257-268`) opens this sheet even without a mic.
- **The moment:** "I only want to write a note. Why does it tell me about dictations again?"
- **What happens:**
  - A free account with no dictations left sees «Añadir nota» with a + icon.
  - Every tap opens the typing sheet headed «Sin dictados gratis hasta el {date}.», with «Ver Pro».
  - Tasks at 0 left open the form directly, and explain the limit once a month (2026-10-18).
- **Why it fails:**
  - SU-6: no repeated nagging (Gray 2018).
  - SU-7: explain a limit when it bites; nobody tried to dictate.
  - SC-9: tasks and notes treat 0 left differently.
- **Fix:**
  - On a note, show the used-up line only after the person tries to speak, as `askedToSpeak` does.
  - Never on «Añadir nota» with the + icon.
  - No copy change.
- **Verify:**
  - Widget test (free, 0 left): «Añadir nota» opens typing with no `free-voice-used-up` line and no «Ver Pro»; trying to dictate still shows it.
  - New preview `notes/note-capture.typing-free-0`.
- **Evidence:** verified in code; not rendered. The code is in A's file; the flow is Notas.

**UX-1519 · Severity 1 · «Visible para todos» sits right under «Ana ▾»**
- **Where:**
  - The ARB key `audienceShared`: ES «Visible para todos en {name}», CA «Visible per a tothom a {name}».
  - `App/lib/widgets/task_assignment_picker.dart:183-194`.
  - Renders: `tasks/project.person-form.es.light.2x.png` and `tasks/detail.created-by.es.light.1x.png`.
  - UX-1111's watch note.
- **The moment:** "Ana ▾… visible for everyone: is it Ana's or everybody's?"
- **What happens:** right under a person's chip, «para todos» echoes «Todos», the assignee for tasks that are everyone's (`assignedToGroup`).
- **Why it fails:**
  - SC-9: «Todos» means one thing.
  - Gestalt proximity (Palmer 1992).
- **Fix:** reword the line with the established «miembros», as a pair to «Solo tú puedes verlo.»:
  - ES «Lo ven todos los miembros.»
  - EN "All members can see it."
  - CA «Ho veuen tots els membres.»
- **Verify:** the previews show the new line in ES and CA; catalog test.
- **Evidence:** seen in current renders.

**UX-1520 · Severity 1 · Notas: two help texts, an idle search, unlike rows**
- **Where:** `App/lib/screens/notes_screen.dart`:
  - `:152-158`: `notesHelp` while there are no notes, above the empty state (`:213-223`);
  - `:179-184`: the search, shown with no notes;
  - `:291-294`: note rows.
- **What happens:**
  - **Empty Notas:** two explanations, 36 words, and a search over nothing (`notes/notes-tab.empty.es.light.1x.png`):
    - «Guarda información, ideas y material de referencia. Usa una tarea para algo que tengas que hacer.»
    - then «Un lugar para tus ideas / Escribe o dicta una nota…».
  - **Rows:**
    - the step count is built by hand: «1/3 · Lista de pasos», where task rows say «Pasos · 1/3» (`checklistCount`);
    - the project is a bare grey «Casa», which reads as the end of the preview (TalkBack: «…de 2,60 m de ancho. Casa»).
- **Why it fails:** CO-5, SC-2, SC-9; LO-2 (nothing concatenated).
- **Fix:**
  - **Empty Notas:** show only the empty state, with this message:
    - ES «Guarda ideas y datos que quieras recordar. Para algo que hacer, usa una tarea.»
    - EN "Keep ideas and things to remember. For something to do, use a task."
    - CA «Desa idees i dades que vulguis recordar. Per a una cosa per fer, fes servir una tasca.»
  - Hide the search until there's a note, as Proyectos does until 8.
  - Rows use `checklistCount` and the task rows' folder icon and project name.
- **Verify:**
  - Widget test: an empty Notas has one help text and no search; a note in «Casa» shows the folder icon.
  - Previews `notes/notes-tab.empty` and `.list`.
- **Evidence:** seen in current renders; verified in code.

**UX-1521 · Severity 1 · TalkBack hears a note's text as an unnamed field**
- **Where:**
  - `App/lib/widgets/note_text.dart:36`: `SelectableText`.
  - It sits inside an `InkWell` that opens the editor: `App/lib/screens/task_detail_screen.dart:556-572`.
  - AUDIT `notes/note · with-steps`: «text field (no label) value «Bechamel…» [read-only]».
- **What happens:**
  - TalkBack hears an unnamed, read-only edit field.
  - Nothing says that a double-tap opens the editor.
- **Why it fails:** AC-6: name, role, value (WCAG 4.1.2).
- **Fix:**
  - Wrap the surface in `Semantics(label: noteBody «Tu nota», button: true, onTapHint: editNote «Editar nota»)`.
  - Long press still selects the text.
- **Verify:** AUDIT lists the body as a button «Tu nota …» with the hint «Editar nota», and no unnamed field.
- **Evidence:** AUDIT (widget test) from a current render.

**UX-1522 · Severity 1 · Projects: groups first, «Guardar» creates, idle search and retry**
- **Where:**
  - `App/lib/screens/task_lists_screen.dart`:
    - `:229-241`: «Grupos» comes before the projects;
    - `:551`: `saveList` «Guardar proyecto», also on create, while groups say «Crear grupo»;
    - `:255`, with `App/lib/widgets/invitation_cards.dart:52-55`: «Reintentar invitaciones» whenever invitations fail to load, for example offline. Calendar stays quiet in the same case (`App/lib/screens/calendar_screen.dart:282`);
    - `:313-321`: a shared row tells the owner «Compartido · Propietario», and gives no count;
    - `:256-260`: the empty state uses the default calendar icon.
  - `App/lib/widgets/project_scope_control.dart`:
    - `:137-149`: the «Todos los proyectos» sheet always has a search, even over 2 projects;
    - `:104-113`: its 200 dp cap makes the chip read «Todos los pro…» at 2× (AUDIT).
- **Why it fails:**
  - CO-7: progressive disclosure.
  - UN-4: verbs that name the outcome.
  - SC-9 and CO-5.
- **Fix:**
  - Move «Grupos» below the last project.
  - The create button reads ES «Crear proyecto», EN "Create project", CA «Crea el projecte». Edit keeps «Guardar proyecto».
  - Proyectos and Grupos ignore an invitations error, as Calendar does.
  - Owners' shared rows read «Compartido · {count}» (`listItemCount`). Members keep their role.
  - The empty state uses `Icons.folder_outlined`.
  - The sheet's search appears from 8 projects, as on Proyectos (`task_lists_screen.dart:244`).
  - «Todos los proyectos» may use the row's width.
- **Verify:**
  - Previews `tasks/projects.list` and `.empty`.
  - Widget tests for the button's label and the offline case.
- **Evidence:** seen in current renders; verified in code.

**UX-1523 · Severity 1 · «Miembros» and «Notas» touch on a project page**
- **Where:**
  - `App/lib/screens/home_screen.dart:460-508`: two TextButtons in a column, above the search.
  - AUDIT `tasks/project · shared`: «Miembros · 3» is 0 dp above «Notas», and «Notas» 0 dp above the search.
- **What happens:**
  - Two different destinations share an edge.
  - They take two rows above the tasks.
- **Why it fails:**
  - RE-3: spacing for older hands (Jin 2007).
  - SC-5.
- **Fix:**
  - Put both in one Wrap, side by side, with 8 dp between them. They wrap only when they must.
  - Leave 8 dp above the search.
- **Verify:** AUDIT gaps of at least 8 dp; the 1× preview shows the first task about 48 dp higher.
- **Evidence:** AUDIT from current renders.

**UX-1524 · Severity 1 · Copy slips: «Actividad del grupo», «colaborad», Catalan sharing**
- **Where and what:**
  - **«Actividad del grupo»** (`groupActivity`: the screen title at `App/lib/screens/activity_screen.dart:111`, and its button's tooltip at `:37`). The screen lists every shared project, including ones shared outside any group. «Novedades del proyecto» decides what appears there (`Backend/core/collaboration.py:17-22`).
  - **`groupHelp`** mixes tú and vosotros: «Invita a las personas una vez y colaborad en varios proyectos.» CA does the same: «Convida… i col·laboreu».
  - **CA `listSharing`** «Ús compartit del projecte» and `howSharingWorks` «Com funciona l'ús compartit» read as calques. Other Catalan screen titles are imperatives («Revisa la invitació»).
  - **The task history** names `unassigned` «Necesita responsable» (`activity_screen.dart:18`), while Activity says «ha quitado el responsable».
- **Why it fails:**
  - SC-9: one name per concept.
  - LO-9: one form of address.
  - LO-8: Catalan imperatives.
  - Copy that reads naturally in each language.
- **Fix:**

  | Key | ES | EN | CA |
  |---|---|---|---|
  | `groupActivity` (screen and tooltip) | «Novedades» | "Updates" | «Novetats» |
  | `groupHelp` | «Invita a las personas una vez y comparte con ellas varios proyectos.» | "Invite people once and share several projects with them." | «Convida les persones una vegada i comparteix-hi diversos projectes.» (needs a native read) |
  | `listSharing` | unchanged | unchanged | «Comparteix el projecte» (needs a native read) |
  | `howSharingWorks` | unchanged | unchanged | «Com funciona compartir» (needs a native read) |
  | History, unassigned | «Ha quitado el responsable» | "Removed the assignee" | «Ha tret el responsable» |
- **Verify:** catalog tests for the keys; previews `sharing/activity.*` and `sharing/groups.*`.
- **Evidence:** seen in current renders; verified in code.

### Keep
- **Joining or creating a project lands on its page, and says so** (UX-307, UX-327).
- **A person's chip shows exactly their tasks.**
  - Empty, it names them and points to «Todas» (UX-1109).
  - Tasks added under it are theirs (D7).
- **Inviting to a project is one autofocused field**, and it keeps the address on failure.
- **The join dialog keeps a wrong code**, with the reason under it (UX-478).
- **Destructive sharing actions are red**, and confirmed only where they reach others or can't be undone. Archiving has Deshacer (UX-301).
- **Notas:** newest first, and the new note is lit (UX-304). Every search ignores accents (UX-303).

### Progress against UX_REVIEW.md (U1–U14)
- **U5 (land on the task):**
  - Advanced in earlier runs for projects, notes and joins.
  - Regressed for joins: the name question now hides «Te has unido a…» (UX-1508).
  - An archived project's page saves tasks that appear nowhere else (UX-1504).
- **U10:** advanced. A new account's Tareas has 13 tap targets, from 18 on 2026-10-13. UX-1501 takes it to 8.
- **U11:**
  - Held for Bandeja and capturas.
  - New name clashes: «Todas» against «Todas las tareas» (UX-1502), «Su correo» (UX-1503), and «Actividad del grupo» against «Novedades del proyecto» (UX-1524).
- **U13:** still a decision. Evidence is in Questions 1.
- **U14:** an invitation link opened while signed out waits silently (UX-1507).
- **D14 (no code for Google invitees):** not built. The server still requires the code (`Backend/core/list_views.py:273-275`); that half is server-side.

### Questions for the owner
1. **U13, evidence for your test.**
   - At the newcomer's text size, Calendar shows 2 tasks and Tareas 1 (emulator at 2.0).
   - Tareas' «Hoy» and «Sin fecha» repeat what Calendar already has.
   - Tareas' own parts are search, «Prioridad alta», «Proyectos» and the completed list.
   - UX-1501 and UX-1502 make Tareas usable until you decide.
   - Suggestion: add one §7 step that needs a list, such as "What do you have with no date?", so the test informs U13.
2. **D15b and groups.** D15b dropped the role choice from "the invite dialog". UX-1513 assumes that covers group invitations too, with the role then changed on the person's row. Recommendation: yes.
3. **D8 and changing a name.**
   - D8 asks for a name once and lets people skip it.
   - UX-1515 adds one row in Cuenta to set or fix the name later. It's the only way back from «Ahora no», a typo or an unaccented suggestion.
   - Recommendation: yes. It's yours if you count it as a new feature.

### Cross-slice notes
- **B** · `App/lib/widgets/task_tile.dart:254`: tile chips read «Prioridad Alta» / «Prioridad Media» (Title Case from `priorityValue`), while the filter says «Prioridad alta» (LO-10).
- **D** · `App/lib/theme/app_theme.dart:95-97`: filled buttons are 52 dp tall app-wide. AUDIT flags every primary action against RE-3's 56 dp.
- **D** · `App/lib/screens/login_screen.dart` hosts UX-1507's line; `App/lib/screens/account_screen.dart` hosts UX-1515's row.
- **A** · `App/lib/widgets/capture_review_editor.dart` and `App/lib/services/capture_processor.dart:28-33`: a note's result card shows the same words in «Título de la nota» and «Notas» (`notes/note-capture.result`). UX-1517 fixes only the list. UX-1518's code is in `voice_task_screen.dart`.
- **Preview suite** · `App/test/ux_previews/sharing_previews.dart:110,119,123`: the fixture role 'member' isn't a server value (owner, admin, editor or viewer). So `sharing/groups.*` and `group.owner` show English «member». Use 'editor'. Not an app bug; not filed.
- **Preview suite** · `App/test/ux_previews/support/preview.dart:195`: 2× is linear; Android 14+ grows headlines far less.
  - On the emulator at 2.0, a 32 sp title measured 339 dp, against 342 dp for a model at 39.8 px. That's about 1.24×, not 2×.
  - So AUDIT's mid-word splits in headlines at 2× («Matemátic/as» on sharing, «croqueta/s» on a note) don't happen on a phone: 232 and 191 dp fit 312 dp. Not filed.
  - Body text grows about 1.75–1.9×, so 2× renders of body text stay roughly right.
  - Consider a 2× variant that uses Android's non-linear table.

### Memory notes
- **Map changes (area C, 2026-10-19):**
  - **Tareas root:** scope chips («Todos los proyectos · Todas · Para mí», with a shared project) → «Tus tareas» + «Proyectos» + ✓ → search → «Todas las tareas · Sin fecha · Hoy · Prioridad alta» → labels dropdown if any.
  - **Project page:** ✓ in the app bar; people row; «Miembros · N» or «Compartir», then «Notas», stacked; search; no headline.
  - **Sharing screen:**
    - the owner's MIEMBROS leaves the owner out;
    - members see their role, `sharingHelp`, Novedades and Salir, but no people;
    - the server sends members only to owners.
  - **Group invite:** email → «Siguiente» → role sheet → code dialog (42 words). The project invite is one field and fixes the role to editor.
  - **Name question:** after the first «Invitación enviada», and at once after a join. Nowhere to change the name later.
- **Baselines (2026-10-19):**
  - Tareas, new account: 13 targets, 33 words.
  - Tareas with a shared project: 17 controls besides the tasks, 12 above the first.
  - Tasks visible at 2.0 on the emulator: Tareas 1, Calendar 2.
  - Project page: 11 controls.
  - Group code dialog 42 words; project 14.
- **Technique:**
  - Android 14+ non-linear text at 2.0: 14 sp → 26 dp, 16 → 28, 24 → 36, 28 → 37.3, 32 → 39.8. Verified on an emulator title (339 dp measured, 342 dp modelled).
  - Judge headlines at "2×" from the emulator, or from this table, not from the linear previews.
  - `c1019_width.py` in the scratchpad holds the Manrope model with the table.
- **Fixture trap:** the previews' group role 'member' renders as English «member». Not a server value.
- **New recurring types:**
  - **A per-task status ignores project state.** The reminder line, and an archived project's «Añadir tarea», ignore mute, archive and assignee.
  - **A sheet opens over a landing.** Await the message's `closed` first, as `reminder_ask_sheet.dart` does.
  - **One concept, two flows.** Group and project invites and member menus differ.
  - **Rows repeat the page's own context:** the project on a project page, «Sin fecha» on Sin fecha.
