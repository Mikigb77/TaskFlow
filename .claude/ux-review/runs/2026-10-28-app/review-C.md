## UX review — C · Lists, notes, groups and sharing (whole area) — 2026-10-31

**Verdict:** Ship after fixes. No core task fails in this area, but four things need fixing first:
- a note added in Notas can be saved where the list doesn't show it;
- on the sharing and group pages, a change waits for a full sync, and its progress and errors show at the top of a long page, or replace the page when offline;
- a project's own page can't rename, archive or delete it;
- D9 (UX-2032) must not be built as a bare tap: the sync would turn a reader's reminder change into a duplicate task.

**Walked** (Newcomer: Spanish, 1×–2× text, 360 dp, one hand; Daily user in a shared family project; TalkBack through AUDIT's trees):
1. **Tareas compared with Calendar:** 1 tap. Searched, then cleared the search (a key per letter). Tried with and without a shared project, in ES and CA, at 1×, 1.3× and 2×, and at 2.0 on the emulator.
2. **Projects:**
   - create: Proyectos → Nuevo proyecto → name → Crear proyecto, 3 taps; it lands on its page;
   - rename the project you're on: 4 taps through Proyectos ⋮;
   - pin;
   - archive: 2 taps, then Deshacer;
   - restore: 1 tap on its page;
   - delete: 3 taps.
3. **A project's page** as owner, member, reader («lector»), filtered to one person, and archived. Also its Notas.
4. **Share a personal project:** 4 taps from its page plus typing (7 from Calendar), then the one-time name question.
5. **Invitations:**
   - from the email link: 1 tap;
   - from the card on Calendar: 2 taps plus a code;
   - offline;
   - unavailable;
   - decline: 3 taps.
6. **«Miembros»** as owner and as reader:
   - change a role: 2 taps;
   - remove: 3;
   - resend: 2;
   - revoke: 2;
   - leave: 2;
   - delete: 2;
   - «Novedades del proyecto».
7. **Groups:**
   - create: 2 taps plus a name;
   - invite: 3 taps (with «Listo») plus typing;
   - role sheet; rename; archive; transfer: 3 taps; delete; leave.
8. **Novedades:** the header button, 1 tap; open an entry; mark all as read.
9. **Notes:**
   - add, find, filter by project, open, edit;
   - delete, then Deshacer;
   - move into a shared project;
   - add in a project the account can only view.
10. **D9:** a «lector» on a «Todos» task's page.

States checked: first use and empty, loading, offline, no match, many people, view-only, archived, keyboard up, 2× at 360 dp, ES/CA/EN, dark.

**Evidence:**
- **Previews** in `App/build/ux/` (`tasks/`, `sharing/`, `notes/`, plus `calendar/agenda.invitation`), rendered from 6281e3d between 2026-10-28 17:56 and 2026-10-29 08:56. `find App/lib App/assets -newer <png>` lists nothing, and `git diff 6281e3d HEAD -- App/lib` is empty, so they're current. AUDIT.md gives TalkBack's trees, gaps and cut text.
- **Emulator captures** (30c8ce0, the same app code) cover only Tareas and Notas from this area.
- **Code** for everything else: dialogs, error states, sheets, sync, and the server half of D9 (bc80025).
- `references/guidelines.md` is present.
- Large text in the previews scales 2× linearly, while Android 14+ grows headlines far less. So mid-word headline splits at 2× («Matemátic/as») aren't counted.

**Numbers:**

| What | Now | After the fixes |
|---|---|---|
| Tareas, new account (1×) | 8 tap targets (13 on 2026-10-19) | 8 |
| Tareas with a shared project (1×), controls above the first task | 11 | 11 |
| Tareas at Android's 2.0 (emulator, 393 dp) | 2 whole tasks (1 on 2026-10-19) | 2 |
| Proyectos, new account | 3 targets: Atrás, Grupos, Nuevo proyecto | 2 (UX-2516) |
| Rename, or archive, the project you're looking at | 4 taps, or 3, through another screen | 3, or 2 (UX-2503) |
| Clear a 10-letter search | 10 key taps | 1 (UX-2509) |
| A reader's own reminder on a «Todos» task | not possible | 2 taps (UX-2032) |
| Dialogs that show a character counter | 7 («0/80», «0/254», «0/60», «0/128») | 0 (UX-2505) |
| Share a personal project | 4 taps from its page, 7 from Calendar | unchanged |
| Accept an invitation | 1 tap from the email link; 2 taps plus a code from the card | unchanged |

There are 20 new findings, UX-2501 to UX-2520, plus UX-2032, which is decided and needs its app package.

### Findings (most severe first)

**UX-2501 · Severity 2 · A note added in Notas can go where the list doesn't show it**
- **Where:**
  - `App/lib/screens/notes_screen.dart`:
    - `:256-269`: «Añadir nota» always shows;
    - `:47-48`: `_saveTo` is null when the account can't add to the project shown;
    - `:71-95`: a note the list doesn't show leaves the list as it is.
  - `App/lib/screens/voice_task_screen.dart:776-780`: with no project passed, a capture falls back to the app-wide «Todos los proyectos» choice, notes included.
  - Ways in:
    - a reader's project page has «Notas» (`App/lib/screens/home_screen.dart:614-626`; render `tasks/project.viewer.es.light.1x.png`);
    - the Notas tab's «Proyecto» dropdown also lists projects the account only views.
- **The moment:** "I added the note to «Coro» and it said «Nota guardada»… where is it?"
- **What happens:**
  1. **In a project the account only views,** «Añadir nota» saves the note outside that project: with no project, or in whatever project Calendar's chip is set to. The message is «Nota guardada», and the list, filtered to «Coro», doesn't change. Tasks already avoid this: a view-only project page has no «Añadir tarea» and shows «Este proyecto es de solo lectura» (UX-314). Seen on 2026-10-13 under UX-459 («says only "Nota guardada"») and never planned.
  2. **On «Todas las notas»,** the new note goes into the project picked on Calendar's or Tareas' «Todos los proyectos» chip, because Notas passes no project. A private thought can land in a shared project. The result card shows the project chip, but the Notas screen the person is using said «Todas las notas». Noted under UX-313 and never planned.
- **Why it fails:**
  - SC-10 and SC-11: a save ends with the item in view (Rensink 1997; Kahneman 1993).
  - UN-2: a message isn't the proof.
  - Recurring problem 1.
  - SC-9: the same rule as UX-314.
- **Fix:**
  1. While the list shows a project the account can't add to (opened from its page, or picked in the dropdown), replace «Añadir nota» with the project page's read-only bar: `readOnlyList` «Este proyecto es de solo lectura» and `listEditingAccessHelp` «Si quieres hacer cambios, pídeselo al propietario del proyecto.» The strings exist in EN, ES and CA.
  2. Notas always tells the capture where the note goes: the project shown, or, on «Todas las notas», no project at all. A note never follows another screen's filter.

  No new copy. This removes a button that couldn't do what it said.
- **Verify:**
  - Widget tests:
    - `NotesScreen(listId: <a project the account views>)` has no «Añadir nota» and shows `readOnlyList`;
    - the Notas tab with the dropdown on that project does the same, and «Todas las notas» brings the button back;
    - with Calendar's chip on «Matemáticas», a note added from «Todas las notas» is saved with no project.
  - New preview `notes/notes-tab.viewer-project`.
- **Evidence:** verified in code. The reader's «Notas» button is seen in a current render; that project's Notas isn't rendered.

**UX-2502 · Severity 2 · Sharing and group pages: a change waits for a full sync, and reports at the top**
- **Where:**
  - `App/lib/screens/list_sharing_screen.dart`:
    - `:88-130` (`_applied`, waiting at `:108-111`): a role change, a removal or a revoked invitation shows only after a full `loadTasks()` sync;
    - `:396-401`: the error banner and progress bar sit under the headline;
    - `:355-359`: with `skipLoadingOnRefresh: false`, every reload blanks the page to a spinner.
  - `App/lib/screens/groups_screen.dart`:
    - `:412-461`: rename, archive, restore, role, revoke, spoken name and transfer wait the same way;
    - `:652-661`: banner and bar at the top. While busy they add about 24 dp above the content, so the content shifts down;
    - `:363-378` (`_guard`): the page is reloaded on error. With Riverpod 2.5.1, `.when` (`skipError: false`) shows the error builder when that reload fails. So offline, the whole page becomes `LoadFailed` («No se ha podido cargar. Revisa la conexión.» + Reintentar, `:196-209`), and the action's own message never shows;
    - `:787-806` (rename) and `:593-605` (spoken name): the dialog closes before sending, so a failure drops the typed name. Create and invite keep it through `submit:` since UX-328.
- **The moment:**
  - At 2×, scrolled to «Archivar grupo», offline: "I tapped it, and the page turned into «No se ha podido cargar»… did it archive?"
  - The owner, after «Dar permiso de lectura» for Ana: "Nothing changed… now the whole page flashed."
- **What happens:**
  - The tapped control greys out. A thin bar appears at the top, out of view at 2×: the bottom actions are 2–3 screens down (renders `sharing/group.owner.es.light.2x.png`, `sharing/project-sharing.owner.es.light.2x.png`).
  - The row changes only after a whole task sync and a page reload.
  - A failure shows at the top, or replaces the page.
  - Proyectos and Novedades already report their own action failures as the floating message (`task_lists_screen.dart:90-96`, `:132-133`; `activity_screen.dart:72-77`).
- **Why it fails:**
  - RE-8: feedback beside the finger (Hoober 2017c).
  - UN-1 and PE-2: answer at once, and show progress in view (Nielsen 1993).
  - UN-7: the error next to its cause, nothing lost (Neusesser 2023).
  - UN-9: never lose input.
  - Recurring problems 12 and 18.
- **Fix** (no new copy):
  1. After role, remove, resend, revoke, rename, archive, restore, spoken name and transfer, refresh the page's own data as soon as the server answers, and run `loadTasks()` behind (`unawaited`), as the invite already does (`list_sharing_screen.dart:108-113`). Leave and delete keep waiting: they close the page.
  2. Keep the page on screen while it reloads:
     - the sharing page uses `skipLoadingOnRefresh: true`;
     - the group page doesn't swap itself for `LoadFailed` when a reload after a failed action fails (keep the data, or don't reload on error).
  3. Show progress as a 2 dp bar under the app bar: in view at any scroll, and nothing shifts. An action's failure goes through `showFeedback(requestProblemText(…))`, as on Proyectos. The top banner stays only for a page that couldn't load.
  4. Rename and the spoken name pass `submit:`, so a failure stays inside the dialog with the typed name, as `_create` and `_invite` do.
- **Verify:** widget tests:
  - with the sync held open, Ana's row reads «Lector» as soon as the request answers;
  - offline, «Archivar grupo» keeps the members on screen and shows the network message as a snackbar;
  - a failed rename keeps the dialog open, with the typed name and the error;
  - at 2×, scrolled to the bottom, the progress bar is inside the viewport.
- **Evidence:** verified in code; Riverpod 2.5.1's `AsyncValue.when` was read in the pub cache. The positions are seen in current renders.

**UX-2503 · Severity 2 · A project's page can't rename, archive or delete it**
- **Where:**
  - `App/lib/screens/home_screen.dart:494-498`: the page's app bar has only ✓.
  - The only way in is Proyectos ⋮ (`App/lib/screens/task_lists_screen.dart:374-457`).
  - An unshared project's «Compartir proyecto» page carries «Eliminar proyecto» (`App/lib/screens/list_sharing_screen.dart:490-521`): a delete inside a sharing page.
- **The moment:** "I'm in «Casaa». How do I fix the name?" The way is back to Proyectos, then the right row's ⋮, then Editar proyecto.
- **What happens:** «Casa» shows ✓, «Compartir», «Notas», the search, its tasks and «Añadir tarea» (render `tasks/project.personal.es.light.1x.png`). Nothing on the page acts on the project itself. Renaming takes 4 taps through another screen, and archiving 3.
- **Why it fails:**
  - PL-1 / Jakob's law (Nielsen 2000): a page about one thing carries that thing's actions in its app bar's ⋮, as other list apps do.
  - CO-1: deleting a project isn't the job of a sharing page.
  - CO-10.
- **Fix:**
  - Add one ⋮ in the project page's app bar, after ✓, tooltip `manageItem` («Gestionar Casa»).
  - It holds the items Proyectos ⋮ offers for that project and role: Fijar; Novedades del proyecto, when shared; Editar proyecto; Archivar or Restaurar; Eliminar.
  - Build both menus with one function, so they can't drift.
  - Deleting from the page closes it and shows «Proyecto eliminado» on Proyectos, as leaving does (UX-476).
  - Subtract: «Eliminar proyecto» leaves the unshared «Compartir proyecto» page.

  No new copy.
- **Verify:**
  - Widget tests:
    - the page ⋮ lists the same items as Proyectos ⋮ for owner, editor and reader;
    - a rename takes 3 taps;
    - Eliminar closes the page and shows the message;
    - the unshared sharing page has no delete.
  - Preview `tasks/project.personal` with the menu open.
- **Evidence:** verified in code; seen in current renders.

**UX-2504 · Severity 2 · Deleting or giving away a group: the dialogs don't say what happens**
- **Where:** `App/lib/screens/groups_screen.dart`:
  - delete (`:849-886`): the row's title is just `delete` «Eliminar». Its confirmation repeats `groupDeleteHelp`, the reason the row is off when the group has projects (`:870-875`);
  - transfer (`:557-589`): the sheet's header repeats `groupTransferHelp` (`:565-568`). The confirmation's title and its teal button are both `'${groupTransfer}: ${person.name}'` (`:581-585`); `groupConfirm` reuses the title as the button (`:236`);
  - strings: `app_es.arb:1160`, `:1155`; `app_en.arb:2124`, `:2112`; `app_ca.arb:864`, `:859`.
- **The moment:**
  - On an empty group: "«Solo puedes eliminar un grupo vacío. Archívalo para conservar sus proyectos»… isn't it empty? Should I archive it instead?"
  - "A button that says «Transferir propiedad: Ana»?"
- **What happens:**
  - The delete confirmation shows only when the group is empty. It says what you can't do, suggests archiving to keep projects there aren't, and never says what deleting does, or that it can't be undone.
  - The transfer confirmation joins a title and a name with a colon, uses that as the button, and shows the same help a second time, for a step the owner can't take back.
- **Why it fails:**
  - UN-4: name the outcome (Nielsen 2018c).
  - Recurring problem 24: help copy outlives its state.
  - LO-2: nothing concatenated.
  - CO-5: the same help twice.
- **Fix** (the new Catalan lines need a native read):

  | What | ES | EN | CA |
  |---|---|---|---|
  | Delete row's title | «Eliminar grupo» | "Delete group" | «Suprimeix el grup» |
  | Delete confirmation | «¿Eliminar «{name}»? Sus miembros dejarán de verlo. No se puede deshacer.» | "Delete “{name}”? Its members will lose it. This can’t be undone." | «Vols suprimir «{name}»? Els membres el deixaran de veure. No es pot desfer.» |
  | Delete button | «Eliminar grupo», red as now | "Delete group" | «Suprimeix el grup» |
  | Transfer title | «¿Transferir «{group}» a {person}?» | "Transfer “{group}” to {person}?" | «Vols transferir «{group}» a {person}?» |
  | Transfer button | «Transferir a {person}» | "Transfer to {person}" | «Transfereix a {person}» |

  - The row keeps `groupDeleteHelp` as its subtitle only while it's off (the group has projects).
  - The transfer confirmation keeps `groupTransferHelp` as its text. The sheet's header is just «Transferir propiedad», without the help.
- **Verify:**
  - Widget tests for each string in ES, EN and CA.
  - The row of a group with projects keeps its reason; an empty group's row has none.
  - New preview `sharing/group.delete-confirm` (ES 2×).
- **Evidence:** verified in code and the ARB files. The row's words are in AUDIT `sharing/group · owner`.

**UX-2505 · Severity 2 · Seven dialogs show a character counter, read out at every key**
- **Where:** four fields, used by seven dialogs, have `maxLength` without `counterText: ''`:
  - `App/lib/screens/groups_screen.dart:148-161` (`groupTextDialog`): the group name («0/80»), the invite email («0/254»), the spoken name («0/60») and the rename;
  - `App/lib/screens/task_lists_screen.dart:532-546`: new and edited projects («0/80»);
  - `App/lib/widgets/invitation_cards.dart:251-264`: the invitation code («0/128», or «43/128» when a link fills it);
  - `App/lib/widgets/task_list_picker.dart:150-156`: renaming a dictated project.

  The app's standard hides them: `counterText: ''` in eight places (capture, steps, the name sheet, the reminder sheet, the task form).
- **The moment:**
  - "«0/128»… does the code need 128 letters?"
  - With TalkBack, typing an address: «a… Quedan 253 caracteres… n… Quedan 252 caracteres…»
- **What happens:** the group invite shows «0/254» under «Correo» (render `sharing/group.invite.es.light.1x.png`). AUDIT reads it as a live region, «Quedan 254 caracteres», at 4.3:1 against the needed 4.5:1. The project's invite dialog, the same task, shows none.
- **Why it fails:**
  - CO-5 (Sweller 1988).
  - SC-9: the same component looks the same everywhere.
  - AC-7: announce changes politely, not at every keystroke.
  - FO-9: a code field shouldn't suggest a length it doesn't need.
- **Fix:** `counterText: ''` on these four fields; keep `maxLength`. No copy.
- **Verify:** a widget test finds no «0/80», «0/254», «0/60» or «0/128» in the seven dialogs. AUDIT for `sharing/group · invite` has no «Quedan … caracteres» node.
- **Evidence:** seen in a current render and AUDIT; verified in code.

**UX-2506 · Severity 2 · The header's people icon opens «Novedades», not people**
- **Where:**
  - `App/lib/screens/activity_screen.dart:43`: `Icons.groups_outlined`, tooltip «Novedades».
  - The same icon means:
    - «Grupos» (`task_lists_screen.dart:277`; `groups_screen.dart:316`);
    - shared projects in the «Todos los proyectos» sheet (`project_scope_control.dart:432`);
    - «Todos» as the person a task is for (`task_assignment_picker.dart:99`, `:152`; `task_tile.dart:167`).
- **The moment:** "I want to see who's in the family group. That people button at the top… no, it's a list of changes."
- **What happens:**
  - With a shared project, Calendar, Tareas and Notas show an unlabelled three-people icon with the unread count (renders `tasks/tasks-tab.normal`, `notes/notes-tab.list`).
  - TalkBack says «Novedades»; the eye sees people.
  - One tap away, on Proyectos, the same icon is labelled «Grupos».
- **Why it fails:**
  - SC-9 (WCAG 3.2.4): one icon per concept, the app's own rule (Tareas = check_box, Notas = description).
  - SC-6: few icons are understood without a label (Harley 2014).
- **Fix:**
  - Use `Icons.feed_outlined`, a page of news items, for the header button. Badge and tooltip stay.
  - Not `history` or `restore`: Notas already uses that glyph for «Sin guardar».

  No copy.
- **Verify:**
  - Widget test: the header's Novedades button uses `feed_outlined`, and `groups_outlined` appears only for groups, shared projects and «Todos».
  - Previews `tasks/tasks-tab.normal` and `notes/notes-tab.list`.
- **Evidence:** verified in code; seen in current renders.

**UX-2507 · Severity 2 · TalkBack hears a task's notes as an unnamed text field**
- **Where:**
  - `App/lib/widgets/note_text.dart:37-40`: without `onTap`, the `SelectableText` is exposed as it is.
  - `App/lib/screens/task_detail_screen.dart:364-369` and `:575-609`: `_body` names the text only for a note that opens the editor (UX-1521).
- **The moment:** TalkBack on «Ir al médico»: «Notas… campo de texto, sin etiqueta, Ir en ayunas…, solo lectura».
- **What happens:**
  - AUDIT `tasks/detail · notes-steps` (es 1×), item 11: «text field (no label) value «Ir en ayunas. Llevar la tarjeta sanitaria y el volante.» [read-only]». Its targets list «an unlabeled text field».
  - The same happens for every task with notes, and for every note in a project the account only views.
  - UX-1521 fixed only the editable note; its own line says: "Not counted: a read-only note".
- **Why it fails:** AC-6: every control has a name, role and value (WCAG 4.1.2).
- **Fix:**
  - When the text has no tap, wrap its surface in `Semantics(container: true, label: «Notas»` for a task or `«Tu nota»` for a note, `value:` the text`)`, and exclude the `SelectableText`'s own node, as the editable case does without `button` or `onTap`.
  - Long-press selection stays.

  No copy.
- **Verify:**
  - AUDIT `tasks/detail · notes-steps` lists «Notas» with the text as its value, and no unlabeled text field.
  - A reader's note reads «Tu nota».
  - A widget test with `labeledTapTargetGuideline`.
- **Evidence:** AUDIT (widget test) from a current render; verified in code. The tap path is B2's file; the widget is this area's.

**UX-2508 · Severity 2 · «Ana ha actualizado: …» never says what changed**
- **Where:**
  - `App/lib/screens/activity_screen.dart:213-225`: `activityEntry`, «{actor} ha actualizado: {title}» (`app_es.arb:1190`).
  - `:344-352`: a task's own «Actividad», «Ha actualizado una tarea» (`:1180`).
  - The server records which fields changed (`Backend/core/collaboration.py:45-48`) and returns them in a task's history (`Backend/core/task_views.py:127`), but not in Novedades items (`Backend/core/group_views.py:325`).
- **The moment:** "Ana updated «Recoger a los niños»… did she change the day? The time? I don't remember what it said before."
- **What happens:**
  - In a family project the commonest entry is a moved task, and it reads like any other edit.
  - Opening the task shows the new day, but not that it moved.
  - The task's own history says «una tarea» on that very task's page.
- **Why it fails:**
  - SH-2: show who changed what. Families wanted to see what changed and who changed it (Neustaedter 2006b; Dourish 1992).
  - CO-3: nothing to remember (Cowan 2001).
  - UX-1514 named the new assignee the same way.
- **Fix** (minimal; cause partly server-side):
  - **Server:** each Novedades item carries the changed `fields`, as UX-1514 added `assignee_name`.
  - **App, Novedades:** when only the day or time changed (`scheduled_date`, `due_date`), the entry reads ES «{actor} ha movido: {title}», EN "{actor} moved: {title}", CA «{actor} ha mogut: {title}». That's the app's own verb for moving («Mover», «Movida al …»). Everything else keeps «ha actualizado».
  - **App, a task's «Actividad»:** the same rule, from the history's `details`: ES «Ha movido la tarea», EN "Moved the task", CA «Ha mogut la tasca». The generic line becomes «Ha actualizado la tarea» / "Updated the task" / «Ha actualitzat la tasca».
- **Verify:**
  - Server test: a date move's item has `fields: ["scheduled_date"]`.
  - App widget tests in ES, EN and CA: a date move reads «Ana ha movido: Recoger a los niños»; a title change keeps «ha actualizado».
  - Preview `sharing/activity.list` with one move.
- **Evidence:** verified in code, app and server. Today's wording is seen in `sharing/activity.list`.

**UX-2509 · Severity 2 · Searches can only be cleared letter by letter**
- **Where:**
  - the four search fields: `App/lib/screens/home_screen.dart:632-646` (Tareas and project pages), `App/lib/screens/notes_screen.dart:178-185`, `App/lib/screens/task_lists_screen.dart:240-247`, `App/lib/widgets/project_scope_control.dart:150-157`;
  - their no-match states offer no way back: `home_screen.dart:732-756`, `notes_screen.dart:215-225`, `task_lists_screen.dart:257-261`.
- **The moment:** "«No hay tareas que coincidan. Prueba otra palabra o filtro.» How do I get my list back?" Backspace, backspace…
- **What happens:**
  - No search field has a clear control. At 2× text with a tremor, each letter costs one more tap.
  - On Tareas the query also stays when the person switches tabs and comes back.
- **Why it fails:**
  - UN-8: nothing found isn't a dead end (Whitenton 2014).
  - PL-1 / Jakob's law: search fields end with a clear button.
  - CO-10.
- **Fix:**
  - While a field holds text, a trailing ✕ (`IconButton`, 48 dp) clears it and shows the whole list again.
  - Tooltip: ES «Borrar búsqueda», EN "Clear search", CA «Esborra la cerca».
  - The ✕ isn't there while the field is empty, so an empty field looks the same as today.
- **Verify:** widget tests: typing «dent» shows ✕; one tap brings back every row and hides ✕; TalkBack reads «Borrar búsqueda». A preview of a no-match state with ✕.
- **Evidence:** verified in code.

**UX-2032 · Severity 1 (existing; decided as D9 (b) on 2026-10-31) · A reader can't choose reminders of their own**
- **Where:**
  - `App/lib/screens/task_detail_screen.dart:374-402`: `onChanged: !canEdit ? null : …`.
  - `App/lib/repositories/cloud_task_repository.dart:149-171`: in a project where the account is a «lector», a pending change is never sent. It becomes a personal copy, with the notice "…read-only. Your unsent task edit was kept as a personal copy."
  - The server half is done (bc80025): `Backend/core/task_views.py:51-67`; contract `Backend/docs/REMINDER_PLANS.md:39`, `:89`.
- **The moment:** a reader in «Coro», on the «Todos» task «Ensayo general»: "I want a reminder the day before… the bell line does nothing."
- **What happens:**
  - Today the line is information only.
  - If only a tap were added, the change would be saved on the phone, then turned into a duplicate personal task with a sync warning at the next sync: worse than today.
- **Why:** D9 (b), and D6: "everyone should be able to set their own pattern".
- **Fix (the app half):**
  1. **The tap.** The task page's reminder line opens the reminder choices for an account without edit rights whenever the task rings for it (`reminderRingsHere`: a «Todos» task, or one given to the reader). The change touches only `reminderMinutes`, `reminderTime` and `reminderPlan`. A task given to someone else still reads «Recordatorio para {persona}», with no tap.
  2. **The sync.** In a project where the account is a «lector», a pending change that differs from the server's copy only in its reminders is sent with `PUT`; the server keeps it with no new version, activity or notification. A 409 is taken as the server's task, with the reader's reminders kept. Never a personal copy, and never the read-only notice. Any other pending change from a reader behaves as today.
  3. **Nothing else.** The rest stays read-only: the «Solo puedes ver esta tarea.» banner, no ✓, no edit, no delete, no move. The sheet's «Estos avisos son solo para ti.» already says whose reminders they are.

  No new copy.
- **Verify:**
  - Widget tests:
    - a reader on a «Todos» task: the line is a button and opens the sheet with «Estos avisos son solo para ti.»; a choice calls `updateTask` changing only the reminder fields;
    - a reader on a task given to Marta: «Recordatorio para Marta», with no tap.
  - Repository tests:
    - a reader's reminders-only row is sent with `PUT` and acknowledged, with no copy and no notice;
    - a stale version (409) keeps the server's task.
  - Emulator, with two accounts on the local server at bc80025 or later: the reader's «1 hora antes» rings only on the reader's phone; no duplicate task appears; the owner's Novedades shows nothing.
- **Evidence:** verified in code, app and server.

**UX-2510 · Severity 1 · Notes moved, locked or deleted are called «tarea»**
- **Where:** a note's project chip and delete button (`App/lib/screens/task_detail_screen.dart:186-188`, `:227-250`, then `App/lib/widgets/task_list_picker.dart:219-241`, `:263-267`):
  - `shareTaskConfirm` (`app_es.arb:1138`, EN `:2084`);
  - `sharedTaskStays` (`:1140`, EN `:2094`, CA `:844`);
  - `moveError` (`:284`, EN `:492`, CA `:263`);
  - the delete tooltip, plain `delete` «Eliminar».
- **The moment:** "«¿Compartir con Matemáticas? Todos verán esta tarea…» It's a note, not a task."
- **What happens:**
  - Moving a personal note into a shared project asks about «esta tarea» (EN "this task"). Catalan's «Vols compartir-la…» is already neutral.
  - A shared note's locked chip says «Las tareas compartidas se quedan en su proyecto.»
  - A failed move says «No se pudo mover esta tarea.»
  - TalkBack hears the delete button as just «Eliminar» (AUDIT `notes/note · with-steps`).
  - UX-312 gave notes their own words elsewhere.
- **Why it fails:** SC-9; recurring problem 9 (copy borrowed from another context).
- **Fix:** note versions, used when the item is a note:

  | Key | ES | EN | CA |
  |---|---|---|---|
  | Share confirmation | «¿Compartir con {name}? Todos verán esta nota y no podrás volver a hacerla privada.» | "Share with {name}? Everyone there will see this note. It can’t be made private again." | unchanged |
  | Locked chip | «Las notas compartidas se quedan en su proyecto.» | "Shared notes stay in their project." | «Les notes compartides es queden al seu projecte.» |
  | Failed move | «No se pudo mover esta nota. Inténtalo de nuevo.» | "Could not move this note. Please retry." | «No s’ha pogut moure aquesta nota. Torna-ho a provar.» |
  | Delete tooltip | «Eliminar nota» | "Delete note" | «Suprimeix la nota» |
- **Verify:** widget tests on a note: the share confirmation, the locked chip's message and the tooltip use the note strings in all three languages; tasks are unchanged.
- **Evidence:** verified in code and the ARB files; the tooltip is in AUDIT.

**UX-2511 · Severity 1 · Sharing copy: sync jargon, «Mis asignaciones», and a sentence about tasks**
- **Where:**
  - `removeAccessHelp` (`app_es.arb:535`, EN `:1121`, CA `:514`), the «Retirar acceso» confirmation: «…Sus cambios compartidos pendientes se eliminarán en la próxima sincronización correcta.»
  - In «Cómo funciona el acceso compartido» (render `sharing/project-sharing.how-it-works.es.light.1x.png`):
    - `sharingRemovalHelp` (`:540`): «copias descargadas», «la próxima sincronización correcta», «borrar a distancia los dispositivos sin conexión»;
    - `sharingRolesHelp` (`:525`): «al exportarlas se crea una copia personal».
  - `updatesAssigned` «Mis asignaciones» (`:1173`), the value under «Novedades del proyecto» (`list_sharing_screen.dart:336-340`, `project_preferences.dart:26-30`). The rest of the app says «Para mí».
  - `requestProblemText` adds «Tus tareas siguen guardadas en este teléfono.» to network errors (`App/lib/l10n/request_locale.dart:49-50`). It shows on:
    - the invitation page (render `sharing/invitation.offline`);
    - the join and decline paths (`invitation_cards.dart:155`, `:229`);
    - the invite dialogs, and the sharing and group pages.

    The name sheet already leaves it out (`onSignIn: true`, UX-1229).
- **The moment:**
  - "«la próxima sincronización correcta»? What happens to Ana's things?"
  - "«Mis asignaciones»… the tasks I handed out?"
- **Why it fails:**
  - Plain language (ISO 24495-1).
  - Recurring problem 7: developer words, sync and export.
  - SC-9: «Para mí» is the app's word.
  - Recurring problem 9: borrowed copy.
- **Fix** (Catalan needs a native read):
  - `removeAccessHelp`, second sentence:
    - ES «Los cambios que aún no haya enviado se perderán.»
    - EN "Changes they haven’t sent yet will be lost."
    - CA «Els canvis que encara no hagi enviat es perdran.»
  - `sharingRemovalHelp`:
    - ES «Al salir o perder el acceso, el proyecto desaparece de este teléfono la próxima vez que se conecte. Las copias que hayas exportado se quedan.»
    - EN "When you leave or lose access, the project leaves this phone the next time it connects. Copies you exported stay."
    - CA «Quan surts del projecte o en perds l’accés, el projecte desapareix d’aquest telèfon el pròxim cop que es connecti. Les còpies que hagis exportat es queden.»
  - `sharingRolesHelp`: the last clause becomes ES «Las tareas compartidas se quedan en este proyecto.» / EN "Shared tasks stay in this project." / CA «Les tasques compartides es queden en aquest projecte.»
  - `updatesAssigned`: ES «Solo lo que es para mí», EN "Only what’s for me", CA «Només el que és per a mi».
  - The sharing, group and invitation screens call `requestProblemText(…, onSignIn: true)` (or a better-named flag), so the network error ends at «…inténtalo de nuevo.»
- **Verify:**
  - Catalog tests for the four keys.
  - The offline invitation page reads «No hay conexión. Revisa el wifi o los datos móviles e inténtalo de nuevo.», with nothing after.
  - Preview `sharing/project-sharing.how-it-works`.
- **Evidence:** seen in current renders; verified in code and the ARB files.

**UX-2512 · Severity 1 · Rows say «Prioridad Alta» under a «Prioridad alta» filter**
- **Where:**
  - `priorityValue` «Prioridad {priority}» (`App/lib/l10n/app_es.arb:324`; CA «Prioritat {priority}», `app_ca.arb:303`) takes `priorityName` «Alta» or «Media» (`:150-151`; CA «Alta» or «Mitjana», `:129-130`).
  - It's drawn by `App/lib/widgets/task_tile.dart:132-134`, and by the capture card (`capture_review_editor.dart:629`, `:804`) and the form (`task_editor.dart:948`).
- **What happens:**
  - Tareas shows the chip «Prioridad alta» and, just below it, a row tagged «Prioridad Alta» (`tasks/tasks-tab.normal.es.light.1x.png`).
  - Catalan rows read «Prioritat Mitjana» (`tasks/project.shared.ca.light.2x.png`). TalkBack reads them the same way.
  - Raised as a cross-slice line on 2026-10-19 and never filed.
- **Why it fails:** LO-10: sentence case in ES and CA. SC-9: one spelling per label.
- **Fix:**
  - In ES and CA the phrase takes the level in lower case: ES «Prioridad alta / media / baja», CA «Prioritat alta / mitjana / baixa». Use an ICU select on the level, not the standalone name.
  - EN "High / Medium / Low priority" is unchanged.
  - The task page's standalone «Alta» stays.
- **Verify:** widget tests on a high and a medium row in ES and CA; previews `tasks/tasks-tab.normal`, and `tasks/project.shared` in CA.
- **Evidence:** seen in current renders.

**UX-2513 · Severity 1 · Emails break mid-word on the members and group pages**
- **Where:**
  - `App/lib/screens/list_sharing_screen.dart:282-285` (a member's email) and `:443` (a pending invitation);
  - `App/lib/screens/groups_screen.dart:711`;
  - `App/lib/screens/invitation_review_screen.dart:171` («Sesión iniciada como …»).

  The app's helper `breakableAddress` (`App/lib/l10n/region.dart:105`) is used in Cuenta, delete account, sign-in and the email code, but not here.
- **What happens:** AUDIT `sharing/group · owner` at 1× shows «carmen.lopez@example.c» / «om» (render `sharing/group.owner.es.light.1x.png`). `project-sharing · owner` at 2× shows «ana.garcia@exam» / «ple.com».
- **Why it fails:** AC-3: no words broken mid-word. SC-9: the app's own pattern for addresses.
- **Fix:** show these addresses through `breakableAddress()`, which breaks after «@» and «.», with `withoutAddressBreaks` for TalkBack, as the other screens do. No copy.
- **Verify:** AUDIT for `sharing/group · owner` and `project-sharing · owner` shows no address split inside a word, at 1× or 2×.
- **Evidence:** AUDIT and current renders.

**UX-2514 · Severity 1 · Pickers mark the current choice by colour alone**
- **Where:** `ListTile(selected: …)` with no other cue:
  - the project sheet (`App/lib/widgets/task_list_picker.dart:76`, `:91`);
  - «Todos los proyectos» (`project_scope_control.dart:173`, `:441`);
  - «Novedades del proyecto» (`project_preferences.dart:33`);
  - «¿Quién es responsable?» (`task_assignment_picker.dart:157`, `:170`).

  No theme override, so Material 3 only tints the text and icon. The group role sheet adds a ✓ (`groups_screen.dart:524`). The project sheet also lacks the drag handle every other sheet has (`task_list_picker.dart:47-49`), and its title «Proyecto» is drawn as a plain row (`:53`).
- **What happens:** the current project or person is one teal row among dark ones. In sunlight, or with colour blindness, nothing marks it. TalkBack says «seleccionado».
- **Why it fails:** AC-5: never colour alone (WCAG 1.4.1). SC-9: the role sheet already shows the ✓.
- **Fix:**
  - A trailing ✓ on the selected row in the four sheets, as the role sheet does.
  - The project sheet gets `showDragHandle: true`, and its title becomes a header (`Semantics(header: true)`, `titleMedium`), as in `_chooseRole`.

  No copy.
- **Verify:** widget tests: in each sheet, only the selected row has a ✓. A new preview of the project sheet opened from a note (ES 1×).
- **Evidence:** verified in code; not rendered.

**UX-2515 · Severity 1 · Notas' project filter: another word for «all», shown with no notes**
- **Where:** `App/lib/screens/notes_screen.dart:188-208`:
  - label «Proyecto», first value `allNotes` «Todas las notas» (`app_es.arb:46`);
  - shown whenever the account has a project (`lists.isNotEmpty`), even with no notes, while the search waits for a first note (`:177`).
- **What happens:**
  - Calendar and Tareas call this choice «Todos los proyectos»; Notas says «Proyecto: Todas las notas» (render `notes/notes-tab.list.es.light.1x.png`).
  - An empty Notas with projects shows a filter over nothing, above «Un lugar para tus ideas».
- **Why it fails:** SC-9: one name per concept. CO-7 and recurring problem 3: controls that only matter later.
- **Fix:**
  - The first value reads `projectsAll` «Todos los proyectos» / "All projects" / «Tots els projectes».
  - The dropdown shows by the search's rule (a note exists), or when Notas was opened from a project.
  - Retire `allNotes` once nothing uses it.
  - The control itself stays a dropdown until U13 decides where Notas lives.
- **Verify:** widget tests: an empty Notas with projects has no dropdown; with notes it reads «Proyecto · Todos los proyectos». Preview `notes/notes-tab.empty` with a project.
- **Evidence:** seen in current renders; verified in code.

**UX-2516 · Severity 1 · «Grupos» shows to an account that shares nothing**
- **Where:** `App/lib/screens/task_lists_screen.dart:266-280`, always shown.
- **What happens:** a newcomer's Proyectos (`tasks/projects.empty.es.light.1x.png`) shows «Un lugar para cada parte de tu vida», «Grupos» and «Nuevo proyecto»: a second concept, groups of people, before the first project.
- **Why it fails:**
  - CO-7: progressive disclosure (Nielsen 2006).
  - AGENTS.md's product rule: show advanced things only when relevant.
  - CO-2.
- **Fix:** show «Grupos» once the account has a group, a shared project or a pending group invitation (that card already shows on Proyectos). Sharing stays one tap away on each project's page («Compartir»). No copy.
- **Verify:** widget tests: a new account's Proyectos has no «Grupos»; with a shared project or a group, it shows. Preview `tasks/projects.empty`: 2 targets.
- **Evidence:** seen in a current render; verified in code.

**UX-2517 · Severity 1 · A new project's empty page shows a search box**
- **Where:** `App/lib/screens/home_screen.dart:451` (`quiet` applies only to the Tareas root) and `:631-648`.
- **What happens:** «Nuevo proyecto» lands on the new page (UX-327). There «Buscar una tarea…» sits above «Un nuevo comienzo / Añade una tarea a este proyecto…», with nothing to search. UX-1501 removed it from an empty Tareas, but not from project pages.
- **Why it fails:** CO-7; recurring problem 3. SC-11: the end of «create a project» shows the next step, not tools.
- **Fix:** project pages use the same `quiet` rule: no search while the project has no open task and nothing is filtered. A person chip or a search that finds nothing keeps it. No copy.
- **Verify:** widget tests: an empty project page has no search field, and it appears with the first task. A new preview `tasks/project.empty`.
- **Evidence:** verified in code; not rendered.

**UX-2518 · Severity 1 · «Aceptar invitación» and «Ahora no» touch; so do Cancelar and Enviar**
- **Where:**
  - `App/lib/screens/invitation_review_screen.dart:188-222`: a filled button, then a text button, with no gap between them;
  - stacked dialog actions: `list_sharing_screen.dart:218-227` and `groups_screen.dart:179-188`. Flutter's `AlertDialog` stacks them with 0 dp between.
- **What happens:** AUDIT measures 0 dp between each pair:
  - `sharing/invitation · from-ana`: «Aceptar invitación» above «Ahora no»;
  - `sharing/invitation · offline`: «Reintentar» above «Ahora no»;
  - `sharing/project-sharing · invite` and `sharing/group · invite`: «Cancelar» above «Enviar invitación».

  The name sheet leaves 8 dp between «Guardar» and «Ahora no».
- **Why it fails:** RE-3: spacing for older hands (Jin 2007). RE-6.
- **Fix:** 8 dp between the two buttons on the invitation page, and `actionsOverflowButtonSpacing: 8` on dialogs whose actions stack (the invite dialogs, `groupTextDialog`, `groupConfirm`, the join dialog). No copy.
- **Verify:** AUDIT gaps of 8 dp or more for those pairs.
- **Evidence:** AUDIT from current renders.

**UX-2519 · Severity 1 · Section titles on the group and members pages aren't headings**
- **Where:** `SectionLabel` (`App/lib/widgets/app_components.dart:126-138`), and the group page's «Miembros», «Invitados» and «Proyectos del grupo» (`groups_screen.dart:662-665`, `:703-706`, `:753-756`).
- **What happens:** AUDIT reads them as plain text: «text «Miembros»», «text «INVITACIONES PENDIENTES»». At 2× the group page is three screens long, and TalkBack can't jump between its sections.
- **Why it fails:** AC-7: headings are marked as headers.
- **Fix:** `Semantics(header: true)` in `SectionLabel` and on the three group titles. No copy.
- **Verify:** AUDIT shows «heading «Miembros»» and so on, for `sharing/group · owner` and `project-sharing · owner`.
- **Evidence:** AUDIT.

**UX-2520 · Severity 1 · The group page's «Invitar a una persona» is quiet, below the list**
- **Where:** `App/lib/screens/groups_screen.dart:744-751`: an `OutlinedButton` after the members and invitations. The project's «Miembros» page has the same action first, and filled (`list_sharing_screen.dart:404-411`).
- **What happens:** after «Nuevo grupo», the next step is inviting someone. It's an outlined button below the member list, and the page has no filled button at all (render `sharing/group.owner.es.light.1x.png`; below the fold at 2×).
- **Why it fails:** SC-4: one primary action per screen (M3 Buttons). SC-9: same action, same look and place; UX-1513 aligned the flows, but not the button.
- **Fix:** for people who manage the group, «Invitar a una persona» is filled and comes first, right under the app bar, as on the project's «Miembros» page. No copy.
- **Verify:** preview `sharing/group.owner`: the filled button sits above «Miembros».
- **Evidence:** seen in current renders.

### Keep
- **Creating or joining lands where you look.** A new project opens on its page; a joined project or group says «Te has unido a…»; a new note is lit at the top (UX-327, UX-307, UX-304).
- **Archiving is honest.** It says what stops («ya no aparece en el calendario ni te avisará») and offers Deshacer. Destructive sharing actions are red and confirmed (UX-301, UX-317).
- **A person's chip shows exactly their tasks.** Empty, it names them and points to «Todas»; a task added under it is theirs (UX-1109, D7).
- **Failed invites keep what was typed.** The invite dialog keeps the address; the join dialog keeps a wrong code, with the reason under it (UX-328, UX-478).
- **Novedades leads with who did what.** A row that's waiting keeps its words in place (UX-321, UX-1647).

### Progress against UX_REVIEW.md (U1–U14)
- **U5 (land on the item):** held for projects, notes and joins. One path still lands nowhere: a note added in a view-only project's Notas (UX-2501).
- **U10:** held. A new account's Tareas has 8 targets (13 on 2026-10-19), and its Proyectos goes from 3 to 2 with UX-2516.
- **U11:** held for Bandeja and capturas. New slips: «Mis asignaciones» against «Para mí» (UX-2511), and «Todas las notas» against «Todos los proyectos» (UX-2515).
- **U13:** still a decision, not re-asked. New evidence:
  - at Android's 2.0 on the emulator, Tareas now shows 2 whole tasks (`device/screen-tasks.list.es.light.2.0.png`);
  - Notas keeps its own form-field filter where Calendar and Tareas use the chip, one more thing a Lists tab would unify.
- **U14:** no change here.
- **D14 (Google invitees join without the code, 2026-10-13):** still not built. The server requires the code (`Backend/core/list_views.py:273-275`, `group_views.py:283-285`), and the join dialog asks for 16 or more characters (`invitation_cards.dart:270-272`).

### Questions for the owner
None new from area C. U13 and the rest of DECISIONS.md's Open section aren't re-asked. D14 is decided, so it's a note for the main session below.

### Cross-slice notes
- **B** · `App/lib/widgets/task_tile.dart:170`: «Necesita responsable» («Cal un responsable») is drawn in the error red (`tasks/project.many-people.ca.light.2x.png`), an alarm colour for a neutral state (TA-9's calm styling).
- **B2** · `App/lib/screens/task_detail_screen.dart` hosts UX-2507's semantics (`:575-609`) and UX-2032's tap (`:374-402`).
- **A** · `App/lib/screens/voice_task_screen.dart:776-780`: a capture with no project falls back to the app-wide scope, notes included (UX-2501, part 2).
- **D** · `SectionLabel` (`App/lib/widgets/app_components.dart:126`, UX-2519) is shared by every screen, so the change reaches theirs too.
- **B1** · WD34 («Todo listo. Respira.») is Calendar's. **D and B2**: the website's Pro-screen and «A tu manera» privacy items weren't checked here.
- **Preview suite** · the run crossed midnight (17:56 → 08:56). The clock seam says Wednesday 28 October, but `dayLabel` reads the 29th, so project rows show «mié, 28 de oct» without «Atrasada» next to «Hoy» rows. Not an app bug; not filed. Render each area within one day, or have `dayLabel` read the clock seam.
- **Preview suite** · new renders worth adding: `notes/notes-tab.viewer-project`, `tasks/project.empty`, `sharing/group.delete-confirm`, and the project sheet opened from a note.

### For the main session
1. **The invitation email's website link (from the website review):** real, and minor.
   - `Backend/core/invitation_email.py:18` links `https://taskflow.garbar.tech/` in all three languages, in the text and the HTML (`:130`, `:250`).
   - The site's root follows the browser's language (`../TaskFlowWeb/src/proxy.ts`, WD5), so a Spanish or Catalan email opened in an English browser shows the English home page.
   - Fix: link `/es/` or `/ca/` by the email's own language, as `App/lib/services/site_links.dart:24-30` builds the app's links.
2. **UX-2508's server half:** add the changed `fields` to Novedades items (`Backend/core/group_views.py:325`).
3. **D9:** the server half is done (bc80025); UX-2032 is now the app package above. Build both of its parts together: the tap without the sync change would create duplicate tasks.
4. **D14 (decided 2026-10-13), if this run takes it:** the server accepts an invitee confirmed by Google whose email matches, without the code. The app half is the join dialog without its code field for that account.

### Memory notes
- **Map (area C, 2026-10-31):**
  - **Tareas root:** scope chips (with a shared project); «Tus tareas» + «Proyectos» + «Completadas»; search; «Sin fecha · Hoy · [Prioridad alta]» FilterChips; the labels dropdown. Empty: no search and no chips.
  - **Project page:** the app bar has ✓ only (no ⋮); the people row (2 people or more); «Miembros · N» or «Compartir», and «Notas», in one Wrap; a search (always on project pages); the read-only bar for readers; the archived bar with «Restaurar proyecto».
  - **«Miembros» as owner:** headline; «Invitar a una persona» (filled); the people, you first; INVITACIONES PENDIENTES, each with ⋮ (Reenviar / Anular); «Novedades del proyecto»; «Cómo funciona…»; delete.
  - **«Miembros» as member:** the people, «Novedades del proyecto», «Salir».
  - **Group page:** Miembros (the gear icon opens the role sheet, with ✓); Invitados (⋮); «Invitar a una persona» (outlined); «Proyectos del grupo» + «Nuevo proyecto»; rename, archive, transfer, then delete or leave.
  - **Novedades:** the header button (`groups_outlined` + badge), only with an active shared project.
  - **Notas:** «Sin guardar · N»; the search once a note exists; the «Proyecto» dropdown («Todas las notas»); cards, newest first; «Añadir nota» always.
- **Baselines (2026-10-31):**
  - Tareas, new account: 8 targets.
  - Tareas with a shared project: 11 controls above the first task.
  - A shared project page: 9 above the first task.
  - Proyectos, new account: 3. Notas, new account: 6.
  - Tareas at Android's 2.0 (emulator): 2 tasks.
  - Sharing a personal project: 4 taps from its page.
  - Accepting an invitation: 1 tap from the link; 2 taps plus a code from the card.
- **Standards confirmed in code:**
  - `counterText: ''` on `maxLength` fields (eight call sites);
  - `breakableAddress()` + `withoutAddressBreaks` for any email shown;
  - action errors go through `showFeedback` (Proyectos, Novedades);
  - `requestProblemText(onSignIn: true)` drops «Tus tareas siguen guardadas…»;
  - the group role sheet marks the current choice with ✓;
  - `history`/`restore` already means «Sin guardar» in Notas.
- **New recurring problem types:**
  - (37) A read-only list keeps its create button, and the item is saved elsewhere. Capture falls back to the app-wide scope when no project is passed.
  - (38) A long page reports progress and errors at its top while its actions sit at the bottom. With Riverpod 2.5.1, `.when` (`skipError: false`) swaps the page for its load error when a reload after a failed action fails offline.
  - (39) One icon carries several concepts: `groups_outlined` means Novedades, Grupos, shared projects and «Todos».
- **Technique:** anything that lets a «lector» change a field must also change `cloud_task_repository.dart:149-171`, which turns a reader's pending row into a personal copy at sync.
