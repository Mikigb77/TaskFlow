## UX review — Slice C: lists, notes, groups and sharing — 2026-10-13

**Verdict:** Ship after fixes. Lists and notes mostly work, but three things break trust or block people:
- Archiving or muting a project silently stops its reminders.
- One tap can share a private task with a group, with no way back.
- Someone who is invited can't find or accept the invitation without outside help.

**Walked:**
- Tasks tab compared with Calendar: 1 screen.
- Create a project: 4 taps, one of them on an unlabelled icon.
- Put a task on a project: 3 taps, or a dead end when no project exists.
- Find a task with no date: 1 tap.
- Write a note: 5 taps. Find a note: 2. Edit a note: 5.
- Share a project: 8 taps, plus typing and a code dialog.
- Accept an invitation: 3 taps through the email link. Inside the app: 5 taps, plus a code fetched from somewhere else.
- Create a group, invite someone, add a project, assign a task: about 12 taps.
- See activity: 1 tap.
- Leave a group: 6 taps. Remove a member: 5.
- Archive or restore a project: 2 taps each.

Personas: the newcomer (Spanish, 2× text, one hand) on every flow; the daily user on notes, activity and groups; TalkBack and low vision on Projects, Notes, Activity and invitations.

How I checked: I reasoned from the widget code. The renders for these screens (`artifacts/design/*`, Sep 22 – Oct 11) are older than the code, so I used them as context only. I didn't run Flutter.

Paths below are relative to `C:\Users\mikig\Desktop\Custom\MikiHacks\TaskFlow\TaskFlow\App\lib\` unless written in full.

**Numbers:**
- **Tasks tab, brand-new account:**
  - 18 tap targets.
  - About 17 concepts: project, task, inbox, personal inbox, today, priority, completed, search, activity, appearance, account, date, speak vs type, plus 4 tabs.
  - 53 words in English, 56 in Spanish.
  - After U10 + UX-311: 15 targets.
- **Notes tab, brand-new account:** 10 targets, about 12 concepts, 44 words → 9 targets (U10) and 29 words (UX-337).
- **Projects screen, brand-new account:** 6 targets, and two texts that say the same thing → 4 targets and one text.
- **Share a project:**
  - From Calendar: 8 taps → 6.
  - From inside the project: not possible today → 3.
  - Words at the invite decision: 73 → 12. Words in the code dialog: 42 → 14.
- **Accept an invitation inside the app:** 5 taps, plus copying a code of 16+ characters from outside the app.

### Findings (most severe first)

**UX-301 · Severity 3 · Archive and Mute silently switch off a project's reminders**
- **Where:**
  - Archive: `screens/task_lists_screen.dart:193-213`, from the ⋮ menu item at `:423-431`, directly under "Edit project".
  - Archive group: `screens/groups_screen.dart:588-603`.
  - "Muted": `widgets/project_preferences.dart:25-39`.
  - The effect: `services/task_database.dart:380-384` (no reminders) and `providers/project_scope_provider.dart:26` (hidden from Calendar and Tasks).
- **The moment:** "I archived 'Trabajo' to tidy up. Why didn't the dentist reminder ring? And where did Friday's tasks go?"
- **What happens:**
  - Archive takes one tap, with no confirmation and no Undo.
  - Every task in the project leaves Calendar and Tasks, and its reminders stop. In a shared project this happens for every member.
  - The only message is "Project archived. Contents kept."
  - Archive group is one tap with no message at all, and it applies to everyone in the group.
  - Notes from an archived project still appear in Notes (`notes_screen.dart:93-100`), so the rule looks random.
  - "Muted", under "Project updates", also silences your own task reminders. The label never says so.
- **Why it fails:**
  - The consequence is invisible: a gulf of evaluation (Norman).
  - Nielsen #1 (visibility of system status), #3 (user control: no undo) and #5 (error prevention).
  - Raskin 2000: prefer undo to confirmation.
- **Fix:** keep the behaviour, but say what it does and offer Undo, using the app's existing undo-snackbar pattern.
  - Archive message:
    - EN "Work archived — hidden from your calendar, no reminders. Undo"
    - ES "«Trabajo» archivado: ya no aparece en el calendario ni te avisará. Deshacer"
    - CA "«Feina» arxivat: ja no surt al calendari ni t'avisarà. Desfés"
  - Archive group: the same message, ending "…for everyone in Master" (ES "…para todos en Máster", CA "…per a tothom a Màster").
  - Mute option label:
    - EN "Muted — no updates or reminders"
    - ES "Silenciado: sin novedades ni recordatorios"
    - CA "Silenciat: sense novetats ni recordatoris"
  - Alternatively, if muting isn't meant to stop your own reminders, drop the `'muted'` check at `task_database.dart:382`.
- **Verify:**
  - Widget test: archiving shows a snackbar with Undo; Undo restores the project and reschedules its reminders.
  - Device: set a reminder 2 minutes ahead in a project, archive the project, read the message, tap Undo, and confirm the reminder fires.
- **Evidence:** verified in code.

**UX-302 · Severity 3 · One tap shares a private task, with no way back**
- **Where:**
  - The move: `widgets/task_list_picker.dart:49,68-86`, called from `screens/task_detail_screen.dart:171-191`. It saves immediately and shows no message.
  - The lock: `lockShared` at `task_detail_screen.dart:174` and `widgets/task_editor.dart:522-523`.
  - A second path: the view filter set at `widgets/project_scope_control.dart:101-104` becomes the save destination in `screens/voice_task_screen.dart:259` and `screens/create_task_screen.dart:14-20`.
- **The moment:** "I meant to tap 'Casa', not 'Física'. Now my classmates can see 'call the urologist', and I can't move it back."
- **What happens:**
  - Shared projects sit among personal ones in the "Move to a project" sheet.
  - One tap moves the task, sets it to "Everyone" (`task_assignment_picker.dart:10-15`) and syncs it. There's no confirmation, no Undo and no message.
  - From then on, the project chip is greyed out on detail and edit (disabled, about 38% contrast). The only way back is deleting the task for everyone.
  - Separately, choosing a project in the "All projects" chip just to *look at it* also makes it the destination for every new typed or spoken task.
- **Why it fails:**
  - Raskin 2000: keep confirmation for actions that truly can't be undone — and this one can't.
  - Nielsen #3 and #5.
  - A hidden mode: a view filter becomes the save destination.
  - Defaults (Johnson & Goldstein 2003): people rarely change them, so the default should stay private.
- **Fix:**
  1. When a personal task is moved into a shared project, ask once:
     - EN "Share with Master? Everyone there will see this task. It can't be made private again." [Share] [Cancel]
     - ES "¿Compartir con Máster? Todos verán esta tarea y no podrás volver a hacerla privada." [Compartir] [Cancelar]
     - CA "Vols compartir-la amb Màster? Tothom la veurà i no la podràs tornar a fer privada." [Comparteix] [Cancel·la]
  2. Replace the greyed-out chip with normal-contrast text. On tap, show "Shared tasks stay in their project." (ES "Las tareas compartidas se quedan en su proyecto.", CA "Les tasques compartides es queden al seu projecte.").
  3. When U4 hides the list chip on the capture result, keep the "Visible to everyone in Master" line whenever the destination is shared. `task_assignment_picker.dart:161-172` already shows it today.
- **Verify:**
  - `test/project_ui_test.dart`: picking a shared project for a personal task shows the dialog, and Cancel leaves the task's project unchanged.
  - Walkthrough: filter Calendar to a shared project, dictate "buy bread", and check the audience line on the result.
- **Evidence:** verified in code. The greyed chip is visible in `artifacts/design/projects-task-responsibility.png` (Oct 11, context only).

**UX-303 · Severity 3 · Search fails when Spanish or Catalan users skip accents**
- **Where:**
  - `screens/notes_screen.dart:93-99`
  - `screens/task_lists_screen.dart:340-341,365-367`
  - `widgets/project_scope_control.dart:61-62,136`
  - The same pattern in `screens/home_screen.dart:212-214` (slice B).
- **The moment:** "Busco 'medico' y me dice que no hay nada. ¡Pero si lo dicté ayer!"
- **What happens:**
  - Search lowercases the text but doesn't ignore accents. "medico" doesn't match "Médico"; "reunion", "jose" and "collegi" don't match "reunión", "José" and "col·legi".
  - The recognizer always writes the accents. People typing on a phone often leave them out.
  - The result, "No matching tasks", implies the item doesn't exist.
- **Why it fails:**
  - Nielsen #2 (match the real world) and #9 (help users recover).
  - Lens M.
- **Fix:** add one shared helper that compares accent-folded text on both sides: á/à/â/ä→a, é/è→e, í/ï→i, ó/ò→o, ú/ü→u, ñ→n, ç→c, l·l→ll. Use it in all four searches. Nothing changes on screen.
- **Verify:** unit test: "medico" finds "Médico", "collegi" finds "col·legi", "cafe" finds "Café". Then extend `test/notes_ui_test.dart`.
- **Evidence:** verified in code; nothing in `lib/` folds accents.

**UX-304 · Severity 3 · Notes have no order; a new note lands anywhere**
- **Where:**
  - `screens/notes_screen.dart:91-121`: no sort.
  - It reads from `services/task_database.dart:437-444`, a query without ORDER BY.
  - The only index on owner is `(owner_key, sync_id)` (`:71`, `:119`), so rows likely come back in random-UUID order.
- **The moment:** "Me dice 'Nota guardada'… ¿pero dónde está?"
- **What happens:**
  - After "Save note", the user returns to a list ordered neither by date nor by name.
  - The new note can be anywhere, often below the fold. Edited notes don't move either.
  - Only the snackbar proves the note was saved.
- **Why it fails:**
  - Change blindness (Rensink et al. 1997): bring the new item into view.
  - Nielsen #6: recognition over recall.
  - Jakob's law: the notes apps people already use list the newest first.
- **Fix:** sort notes newest first; local id descending is available today. After saving, the new note sits at the top, in view, briefly highlighted (the same pattern U5 proposes for tasks).
- **Verify:**
  - Widget test: three notes saved in sequence appear newest first.
  - Device: with 12 notes, save one more and check it's visible without scrolling.
- **Evidence:** inferred from code (SQLite returns rows in index order); needs a device check.

**UX-305 · Severity 3 · Sharing a list is hidden behind ⋮ and missing from the list itself**
- **Where:**
  - `screens/task_lists_screen.dart:402-463`: the share option lives only in each row's ⋮ menu, and only after the project has synced (`:432-437`).
  - `screens/home_screen.dart:105-128`: the project page shows "Members" only once the project is already shared.
  - `screens/list_sharing_screen.dart:135-206` (invite dialog) and `:75-124` (code dialog).
- **The moment:** "Quiero compartir la lista de la compra con mi mujer. Estoy dentro de la lista y no veo 'Compartir'."
- **What happens:**
  - The project page has no Share button.
  - The path from Calendar is 8 taps plus typing: Tasks → unlabelled folder icon → ⋮ → "Sharing and people" (ES "Compartir y gestionar personas") → "Invite a person" → tap the email field (no autofocus) → "Create invitation" → "Done".
  - The invite dialog shows 73 words (two paragraphs and a role choice). The code dialog adds 42 more.
  - Before the first sync, the menu item is simply missing, with no explanation.
- **Why it fails:**
  - Hidden navigation (Pernice & Budiu 2016).
  - Norman: signifiers belong on the object.
  - Hick–Hyman and Cowan: a decision plus paragraphs at the moment of acting.
  - The newcomer doesn't explore menus.
- **Fix:**
  1. On the project page, always show the existing Members button. Label it "Share" (ES "Compartir", CA "Comparteix") until someone joins, then "Members · N" (ES "Miembros · N", CA "Membres · N"). Rename the ⋮ menu item "Share" too.
  2. Cut the invite dialog down to:
     - Title: "Share Shopping" (ES "Compartir Compras", CA "Comparteix Compres").
     - One autofocused field: "Their email" (ES "Su correo", CA "El seu correu").
     - One sentence: "They'll see everything in Shopping." (ES "Verá todo lo que hay en Compras.", CA "Veurà tot el que hi ha a Compres.").
     - One button: "Send invitation" (ES "Enviar invitación", CA "Envia la invitació").
     - Remove the role dropdown: the default is Editor, and "Make viewer" already exists on the person's row. Remove both paragraphs: they're already in "How sharing works".
  3. Code dialog:
     - Title: "Invitation sent" (ES "Invitación enviada", CA "Invitació enviada").
     - One line: "If the email doesn't arrive, send them this code:" (ES "Si no le llega el correo, envíale este código:", CA "Si no li arriba el correu, envia-li aquest codi:").
     - Keep Copy code and Done.
  4. If the project hasn't synced yet, the sharing screen says "Connect to the internet to share." (ES "Conéctate a internet para compartir.", CA "Connecta't a internet per compartir.").
- **Verify:**
  - Walkthrough with the newcomer persona, starting inside a list.
  - `test/sharing_ui_test.dart`: the project page shows "Share", and the invite dialog has one field and one sentence.
- **Evidence:** verified in code. The Sep 22 sharing render is older than the code.

**UX-306 · Severity 3 · Invitees can't find invitations, then hit an unexplained code**
- **Where:**
  - Pending invitations appear only at `screens/task_lists_screen.dart:344-345` and `screens/groups_screen.dart:174` — not on Calendar, Tasks, Notes or the bell.
  - Accepting a list invitation: `list_sharing_screen.dart:425-469`, which says "Ask the project owner for the code…".
  - Accepting a group invitation: `groups_screen.dart:675-682` reuses `groupTextDialog`. It shows text written for the *inviter* (`:679`), a "Save" button (`:77`), and the empty-field error "Check the details before adding it to your calendar." (`:61`).
  - Decline: `list_sharing_screen.dart:547-552` and `groups_screen.dart:745-750`.
- **The moment:** "Mi hija dice que me ha invitado. Abro la app y no veo nada." Then, after tapping Aceptar: "¿Qué código? ¿'Les enviaremos un correo'? ¿Guardar?"
- **What happens:**
  - Without the email link, the invitation sits two levels deep behind the unlabelled folder icon.
  - Accept asks for a code of 16+ characters. For a list, the dialog sends the invitee to the owner. For a group, it shows the inviter's text: "They will see every project… We will send an email inviting them…".
  - "Decline" sits 8 dp from Accept and acts immediately with no confirmation, although it can't be undone.
- **Why it fails:**
  - A gulf of execution (Norman).
  - Nielsen #9 and #10.
  - Plain language (ISO 24495-1).
  - Fitts and spacing: a destructive button right beside the primary one.
- **Fix:**
  1. While an invitation is pending, show one card at the top of Calendar: "You're invited to Shopping · View" (ES "Te han invitado a Compras · Ver", CA "T'han convidat a Compres · Mostra"). It disappears after Accept or Decline.
  2. Use one accept dialog for both kinds of invitation:
     - Title: "Join Shopping" (ES "Unirte a Compras", CA "Uneix-te a Compres").
     - Text: "Open your invitation email and tap its link. Or paste the code from it here." (ES "Abre el correo de invitación y pulsa su enlace. O pega aquí el código que aparece.", CA "Obre el correu d'invitació i toca'n l'enllaç. O enganxa-hi el codi que hi apareix.").
     - Button: "Join" (ES "Unirme", CA "Uneix-me").
     - Empty-field error: the existing "Paste the full invitation code."
  3. Decline asks once, because it can't be undone: "Decline the invitation to Shopping? You'd need a new one to join later." (ES "¿Rechazar la invitación a Compras? Para unirte más tarde necesitarías otra.", CA "Vols rebutjar la invitació a Compres? Per unir-t'hi més endavant en necessitaries una altra."). Place Decline away from Join.
- **Verify:** `integration_test/sharing_flow_test.dart` with a second account: the card shows on Calendar; pasting the code joins; the group dialog shows the invitee's text and a "Join" button.
- **Evidence:** verified in code.

**UX-307 · Severity 3 · After joining, nothing shows what you joined**
- **Where:**
  - `screens/invitation_review_screen.dart:67-96`: after Accept the screen pops, and `main.dart:212-219` clears the link. No message.
  - Accepting inside the app: `list_sharing_screen.dart:480-492` and `groups_screen.dart:689-701`. The card just disappears.
- **The moment:** "Le he dado a Aceptar… ¿y ahora? ¿Dónde está la lista?"
- **What happens:**
  - The screen closes back to whatever was underneath, usually Calendar, with no confirmation.
  - The new project appears alphabetically on the Projects screen, two levels away.
  - Its tasks appear on Calendar only if they have a date and count as "for me".
  - "For me / Team" chips appear with no explanation.
- **Why it fails:**
  - The peak–end rule (Kahneman et al. 1993).
  - Change blindness (Rensink et al. 1997).
  - Nielsen #1.
- **Fix:** after accepting, replace the review screen with the joined project's page (list invitation) or the group's page (group invitation). Show "You joined Shopping" (ES "Te has unido a Compras", CA "T'has unit a Compres"). Do the same when accepting from the in-app card.
- **Verify:** `test/invitation_review_test.dart`: after Accept, the project page is on screen with the snackbar.
- **Evidence:** verified in code.

**UX-308 · Severity 3 · Projects hide behind an unlabelled icon; the picker dead-ends**
- **Where:**
  - `screens/home_screen.dart:89-95`: a folder icon with only a tooltip.
  - `widgets/project_scope_control.dart:85-99`: "Manage projects" is the last row of the "All projects" sheet.
  - `widgets/task_list_picker.dart:87-88`: with no projects, the picker says "Create a project from the project selector." and offers no button.
  - `widgets/task_list_picker.dart:58-61`: the sheet's title and subtitle.
- **The moment:** "Quiero hacer una lista para la compra. ¿Dónde?" Or, inside a task: taps "Bandeja personal" → reads "Crea un proyecto desde el selector de proyectos." → "¿Qué selector?"
- **What happens:**
  - The only doors to Projects are an unlabelled folder icon on the Tasks tab and the bottom row of a sheet that opens from a chip labelled "All projects".
  - Choosing a project for a task when none exist ends in that sentence — a dead end.
  - The sheet's subtitle, "Your date, reminder… stay the same", is wrong for a task that's still being created.
- **Why it fails:**
  - Unlabelled icons are guesses (Harley 2014).
  - Nielsen #6.
  - Lens A: no dead ends.
- **Fix:**
  1. Turn the folder icon into a labelled text button, "Projects" (ES "Proyectos", CA "Projectes"). Same spot, no new control.
  2. In the picker, replace the dead-end sentence with a "New project" row (ES "Nuevo proyecto", CA "Projecte nou"). It opens the existing name dialog and puts the task in the new project when saved.
  3. Title the sheet "Project" (ES "Proyecto", CA "Projecte") and drop the subtitle.
- **Numbers:** put a task on a new project: dead end today → 3 taps plus typing.
- **Verify:**
  - Walkthrough: "Make a shopping list and put 'buy bread' on it", with no help.
  - `test/task_lists_widget_test.dart`: with no projects, the sheet shows a New project row.
- **Evidence:** verified in code.

**UX-309 · Severity 3 · A note can only be edited from a pencil in the top corner**
- **Where:**
  - `screens/task_detail_screen.dart:121-145`: the pencil sits beside the delete icon in the app bar.
  - `screens/task_detail_screen.dart:381`: notes have no bottom bar.
  - `screens/task_detail_screen.dart:475-487` and `widgets/note_text.dart:32`: the body is read-only selectable text inside a card.
- **The moment:** "Toco la nota para añadir una línea y no pasa nada."
- **What happens:**
  - The body looks like a text box, but tapping it does nothing; long-press only selects.
  - The only way to edit is an unlabelled pencil in the top-right corner, right beside delete.
  - The bottom of the screen, where tasks get Complete and Reschedule, is empty for notes.
- **Why it fails:**
  - Jakob's law: Google Keep opens a note ready to edit.
  - Thumb zone (Hoober 2013; Clark 2015) and Fitts's law: the primary action sits in the hardest corner, next to a destructive one.
  - Unlabelled icons (Harley 2014).
- **Fix:**
  - For notes, put a labelled "Edit note" button (ES "Editar nota", CA "Edita la nota") in the empty bottom slot.
  - Make a tap on the body open the editor. Links keep their own buttons.
  - Remove the pencil from the app bar for notes. Delete stays there, on its own.
- **Numbers:** editing a note goes from 5 taps to 4, and the main control moves from the top corner to the bottom centre.
- **Verify:**
  - `test/notes_ui_test.dart`: tapping the body opens the editor.
  - Walkthrough: "Add a line to your note."
- **Evidence:** the code is verified; the newcomer's behaviour is inferred — check it in the 10-minute session.

**Severity 2**

**UX-310** · `l10n/app_es.arb:179,444,645,391,539,22,23`; `l10n/app_ca.arb:158,423,370,517,518,23,24`
- **Problem:** the uncommitted rename from "Lista" to "Proyecto" broke Spanish and Catalan text.
  - Checklists are now "Proyecto de pasos" / "Projecte de passos". This shows on note tiles (`notes_screen.dart:180`) and is what TalkBack reads (`checklistSemantics`).
  - Spanish now has four names for a checklist: "Proyecto de pasos", "lista de pasos", "lista de verificación" and "Pasos".
  - Projects get feminine forms: "Archivada", "Arxivada", "Modificada", "si ya no la necesitas", "Actualízala antes de eliminarla", "un proyecto compartida".
- **Fix:**
  - Use "Lista de pasos" / "Llista de passos" everywhere, including `notesEmptyHelp`.
  - Switch to masculine forms: "Archivado"/"Arxivat", "Modificat", "lo"/"el", "Actualízalo antes de eliminarlo"/"Actualitza'l abans de suprimir-lo", "compartido"/"compartit".
  - Add a check to `test/localization_catalog_test.dart` that bans "Proyecto de pasos" and "proyecto compartida".

**UX-311** · `l10n/app_en.arb:694,726` (ES `:511,:533`, CA `:490,:512`), `l10n/app_en.arb:203`, `screens/home_screen.dart:159`
- **Problem:** the list-name examples suggest creating a project called "Personal". It then sits beside "Personal inbox" and inside the "Personal projects" section. It would collide outright with U11's proposed rename to "Personal".
- **Fix:**
  - Change the examples to "Home, Work, Shopping…" (ES "Casa, Trabajo, Compras…", CA "Casa, Feina, Compres…").
  - Call the no-project option "No project" (ES "Sin proyecto", CA "Sense projecte"). It was "No list" / "Sin lista" before the uncommitted rename.
  - Drop the "Personal inbox" filter chip from the Tasks tab.

**UX-312** · `screens/notes_screen.dart:104-106,77-81,126`; `widgets/task_editor.dart:596-597,603`
- **Problem:** Notes reuse wording written for tasks: "No matching tasks", "Task unavailable", "Your saved tasks are still on your device", "Please enter a task title". The note's *title* field also has a hint that describes the body ("Ideas, meeting details, useful links…").
- **Fix:**
  - "No matching notes" (ES "No hay notas que coincidan", CA "No hi ha notes que coincideixin").
  - Use the existing "Project unavailable".
  - "Your notes are still on this phone." (ES "Tus notas siguen en este teléfono.", CA "Les notes continuen en aquest telèfon.").
  - "Give your note a title" (ES "Ponle un título a la nota", CA "Posa un títol a la nota").
  - Title hint: "e.g. Wi-Fi password" (ES "p. ej., Clave del wifi", CA "p. ex., Contrasenya del wifi").

**UX-313** · `screens/notes_screen.dart:150-157`
- **Problem:** in a project's notes, "Dictate a note" doesn't pass the project. Every time, the note saves outside the project and is missing from the list the user is looking at. "New note", right beside it, does save into the project.
- **Fix:** pass `projectId: _listId` when the project is editable — the same rule "New note" uses (`:146-148`).

**UX-314** · `screens/home_screen.dart:255-267`
- **Problem:** on a view-only shared project, "Say a task" and "New task" stay on screen. "New task" quietly creates a personal task that doesn't appear on this page. Nothing says the project is view-only.
- **Fix:** on view-only project pages, replace both buttons with the existing line "This project is read-only · The project owner manages editing access."

**UX-315** · `screens/home_screen.dart:41-45`; `widgets/project_scope_control.dart:107-119`
- **Problem:** project pages inherit the global "For me" filter, so a shared list hides tasks assigned to others ("my wife's items are missing"). Toggling the filter inside a project also changes the Calendar.
- **Fix:** project pages show all their tasks by default. A For me/Team choice made on a project page applies to that page only.

**UX-316** · `l10n/app_en.arb:1445,1448,787,1463` (ES `:1158,:1161,:566,:1176`)
- **Problem:** five words for "the other people":
  - "Team" (the filter chip).
  - "Everyone" (English assignment), but "Todo el grupo" / "Tot el grup" in Spanish and Catalan — shown even when a project is shared directly and no group exists.
  - "Members" (group page and project page).
  - "People" (sharing screen and error messages).
- **Fix:**
  - Rename the "Team" chip to "All" (ES "Todas", CA "Totes").
  - Assignment in Spanish and Catalan: "Todos" / "Tothom".
  - Use one word for people: "Members" (ES "Miembros", CA "Membres").

**UX-317** · `screens/list_sharing_screen.dart:369-385`; `screens/task_lists_screen.dart:402-463`; `screens/groups_screen.dart:612-634`
- **Problem:** a personal project can only be deleted through ⋮ → "Sharing and people" → "Delete project for everyone", even when nobody else has access. Destructive buttons and rows look exactly like normal teal ones.
- **Fix:**
  - Put "Delete project" in the ⋮ menu. Say "Delete for everyone" only when the project is shared.
  - Use `colorScheme.error` for destructive controls.

**UX-318** · `screens/list_sharing_screen.dart:332-358`
- **Problem:** tapping a pending invitation silently sends it again and invalidates the code already sent. The X revokes it instantly. The only explanation is the line "Tap a pending invitation to replace its code."
- **Fix:**
  - Make the rows not tappable.
  - Add a ⋮ menu with "Send again" (ES "Reenviar", CA "Torna a enviar") and "Cancel invitation" (ES "Anular invitación", CA "Anul·la la invitació").
  - Delete the help line.

**UX-319** · `screens/groups_screen.dart:19-82,325-365`
- **Problem:**
  - One generic dialog serves every group step. Its button says "Save" even on a "next" step.
  - An empty name or a bad email shows "Check the details before adding it to your calendar."
  - The role sheets have no title, no explanation, and don't mark the person's current role.
- **Fix:**
  - Buttons: "Create group" (ES "Crear grupo", CA "Crea el grup") and "Next" (ES "Siguiente", CA "Següent").
  - Errors: "Enter a name." (ES "Escribe un nombre.", CA "Escriu un nom."), and the existing "Enter an email address."
  - Role sheet title: "What can {name} do?" (ES "¿Qué puede hacer {name}?", CA "Què pot fer {name}?"), with the current role selected.

**UX-320** · `screens/activity_screen.dart:106-113`; `screens/groups_screen.dart:422-430,315-319`
- **Problem:**
  - When Activity or a group page fails to *load*, it says "Connect to manage group members and invitations." and "This change could not be saved…" — although nothing was being saved.
  - Group actions drop the server's specific reason (already a member, the 20-member limit), which the list-sharing flow does show.
- **Fix:**
  - For load failures: "Couldn't load. Check your connection." (ES "No se ha podido cargar. Revisa la conexión.", CA "No s'ha pogut carregar. Revisa la connexió."), plus Retry.
  - Route group errors through `requestProblemText`, as `list_sharing_screen.dart:241-243` does.

**UX-321** · `screens/activity_screen.dart:137-152,122,132-136`
- **Problem:**
  - Each row leads with the task title and puts who did what last: "Buy bread / Physics · Ana / Completed a task · Oct 12".
  - Read and unread differ only by a 16-pixel icon that TalkBack doesn't announce.
  - The empty state repeats the help sentence twice.
- **Fix:**
  - Row title "Ana completed: Buy bread" (ES "Ana ha completado: Comprar pan", CA "L'Ana ha completat: Comprar pa"), with subtitle "Physics · 12 Oct".
  - Show unread rows in bold, announced as "Unread" (ES "No leída", CA "No llegida").
  - Drop the help line at the top.

**UX-322** · `screens/home_screen.dart:121-126` vs `widgets/custom_app_bar.dart:53`
- **Problem:** the same bell icon means "Activity" in the app bar and "Project updates" settings on a shared project page.
- **Fix:** move the setting into the project's Members screen as a labelled row, and remove the second bell.

**UX-323** · `screens/notes_screen.dart:70-89`
- **Problem:** Notes filter by project with an unlabelled dropdown whose "all" option reads "Notes". It's a different control from the "All projects" chip on Calendar and Tasks, and TalkBack reads only the selected value.
- **Fix:** reuse `ProjectScopeControl` (chip plus sheet). Or label the dropdown "Project" with an "All notes" option (ES "Todas las notas", CA "Totes les notes").

**UX-324** · `widgets/task_list_picker.dart:32-48,79-80`
- **Problem:** the project chip looks like a tag, with nothing suggesting it can be tapped. Every shared row in the sheet repeats a 15-word visibility warning.
- **Fix:**
  - Add a ▾ to the chip.
  - Shared rows show the group name only.
  - The warning stays where it already is: the audience line under the chip.

**UX-325** · `widgets/task_assignment_picker.dart:173-187`
- **Problem:** when the assistant isn't sure of the project or person, the review shows red error text, an instruction, and a "Confirm project and responsibility" button.
- **Fix:** ask it as a question, in normal colour: "Is this right?" (ES "¿Es correcto?", CA "És correcte?"), with a "Yes" button (ES "Sí", CA "Sí"). The chips stay as the way to change it (Budiu & Laubheimer 2018).

**UX-326** · `screens/invitation_review_screen.dart:129,139-142,176-181`
- **Problem:**
  - The help text promises details "described below", but only the role follows.
  - The signed-in email appears with no label.
  - "Cancel" quietly discards the invitation link (`main.dart:217-219`) and reads like "reject".
  - The screen doesn't say who sent the invitation. The cause is likely server-side: the invitation data has no inviter name.
- **Fix:**
  - Help: "You'll see its tasks, notes and files." (ES "Verás sus tareas, notas y archivos.", CA "En veuràs les tasques, les notes i els fitxers.").
  - Email: "Signed in as {email}" (ES "Sesión iniciada como {email}", CA "Sessió iniciada com a {email}").
  - Rename "Cancel" to "Not now" (ES "Ahora no", CA "Ara no").

**UX-327** · `screens/task_lists_screen.dart:159-180`; `screens/groups_screen.dart:551-564`
- **Problem:**
  - After "Save project", the user stays on the Projects list. The new item is placed alphabetically, with no message.
  - From a group page, "New project" detours through a Projects screen filtered to that group, which looks unfiltered.
- **Fix:** after saving, open the new project's page from either entry point. Its empty state already says what to do next.

**UX-328** · `screens/groups_screen.dart:117-155` (with the cached list in `providers/groups_provider.dart:21-33`); `screens/list_sharing_screen.dart:203-205`
- **Problem:**
  - Offline, the Groups list loads from cache, so "New group" looks usable.
  - When creation fails, the typed name is gone and the message blames permissions.
  - A failed invite loses the typed email the same way.
- **Fix:** keep the dialog open, with the error shown inside it, until the request succeeds.

**UX-329** · `screens/task_lists_screen.dart:314-361`; `screens/list_sharing_screen.dart:508-512`; `screens/groups_screen.dart:718-721`
- **Problem:**
  - A "Projects" headline sits under an app bar that already says "Projects".
  - A help line and the empty state say the same thing.
  - There's a "Refresh projects and invitations" button, and a search box even with 0 projects.
  - Offline, two identical "Retry invitations" buttons appear.
  - A progress bar flashes every time the screen opens.
  - At 320 dp and 2× text, "Proyectos" next to "Grupos" will likely break mid-word.
- **Fix:**
  - Remove the headline and the help line.
  - Refresh automatically when the screen opens.
  - Show the search box only from about 8 projects.
  - Show one retry line for both kinds of invitation.
  - Result for a new account: 6 tap targets → 4.

**UX-330** · `screens/groups_screen.dart:465-532`; `screens/list_sharing_screen.dart:288-291`
- **Problem:**
  - On the group page, pending invitations sit under Members with no heading and no "pending" label.
  - "Your spoken name" (ES "Tu nombre para voz") is a prominent button for members only; owners can't set one at all.
  - The list-sharing screen shows people as raw emails, while groups show names.
- **Fix:**
  - Add an "Invited" heading (ES "Invitados", CA "Convidats") and mark each row "Pending".
  - Move the spoken name into each person's own row menu, owner included, labelled "Name for voice assignments" (ES "Nombre para asignarte por voz", CA "Nom per assignar-te per veu").
  - Show names first, email second.

**UX-331** · `screens/notes_screen.dart:93-99`; `screens/home_screen.dart:212-214`; `models/task.dart:408`
- **Problem:** search never crosses types. Something saved as a note can't be found from Tasks, and the reverse, so people must remember which kind they chose.
- **Fix:** when a search finds nothing, show a tappable line such as "Found in Notes: 2" (ES "En Notas: 2", CA "A Notes: 2"), and the reverse on Notes. The structural answer is U13.

**Severity 1**

**UX-332** · `screens/task_lists_screen.dart:117-138`
- **Problem:** five colour chips are a decision nobody needs in order to start a project.
- **Fix:** default to teal, and offer colours only in "Edit project".

**UX-333** · `screens/home_screen.dart:72-88`
- **Problem:** small capital labels ("EVERYTHING YOU WANT TO DO", "YOUR PROJECT", "NO DATE NEEDED") sit above a headline that repeats the app-bar title. "YOUR PROJECT" is false on someone else's project.
- **Fix:** remove those labels and the repeated headline on project and Inbox pages.

**UX-334** · `screens/task_lists_screen.dart:379,381-382,387-391`
- **Problem:**
  - TalkBack reads the "★ " pin mark as "black star".
  - A directly shared row reads "Shared projects · Editor".
  - The item count includes completed items.
- **Fix:**
  - Use a pin icon announced as "Pinned" (ES "Fijado", CA "Fixat").
  - Subtitle "Shared · Editor" (ES "Compartido · Editor", CA "Compartit · Editor").
  - Count open items only.

**UX-335** · `screens/task_lists_screen.dart:185,206,219,272`
- **Problem:** this screen's snackbars use `SnackBarBehavior.fixed`, while the rest of the app uses floating ones.
- **Fix:** drop the override.

**UX-336** · `screens/groups_screen.dart:417`
- **Problem:** a single group's page is titled "Groups".
- **Fix:** use the group's name as the title.

**UX-337** · `screens/notes_screen.dart:38-41`
- **Problem:** a permanent paragraph explaining note vs task sits above the list, every time.
- **Fix:** show it only in the empty state. The Notes tab drops from 44 words to 29.

**UX-338** · `screens/task_lists_screen.dart:91-115`
- **Problem:** choosing a group under "Where does this project belong?" gives no hint that the group will see the project.
- **Fix:** when a group is chosen, show "Everyone in Master will see it." (ES "Todos en Máster lo verán.", CA "Tothom a Màster el veurà.").

**UX-339** · `screens/list_sharing_screen.dart:263-269,331`
- **Problem:** "Your role: Owner" and "Changes sync when the app connects or you refresh." are noise for the owner. "PENDING INVITATIONS" shows even with nothing under it.
- **Fix:** drop both lines for owners, and hide empty section headings.

**UX-340** · `screens/list_sharing_screen.dart:125`; `screens/groups_screen.dart:264-266`
- **Problem:** leaving a project or group, or deleting a project, closes the screen without a word.
- **Fix:** show "You left Physics" (ES "Has salido de Física", CA "Has sortit de Física") or "Project deleted" (ES "Proyecto eliminado", CA "Projecte suprimit").

### Keep
- The visibility line beside the project chip: "Only you can see this" / "Visible to everyone in {group}" (`widgets/task_assignment_picker.dart:161-172`).
- The detailed sharing rules are folded away under "How sharing works" (`list_sharing_screen.dart:359-367`).
- Deleting a group is disabled, with the reason shown in place. Leave, remove and delete-for-everyone each ask once and state the consequence plainly (`groups_screen.dart:612-651`).
- Links in notes are explicit buttons, with a fallback message saying the link can be copied; nothing loads on its own (`widgets/note_text.dart:33-53`).
- The conflict dialog speaks plainly: "This phone: … / Other device: …" (`task_lists_screen.dart:233-260`).

### Progress against UX_REVIEW.md (U1–U14)
- **U10 — partly advanced.**
  - Done: "For me / Team" now appear only when a shared project exists (`project_scope_control.dart:18-19,107`).
  - Still open: the bell shows on every root tab, including Tasks and Notes (`custom_app_bar.dart:53`); the "All projects" chip shows with zero projects (`project_scope_control.dart:25`).
- **U11 — still open.**
  - The collision comes from the *uncommitted* rename of "No list" / "Sin lista" to "Personal inbox" / "Bandeja personal" (`app_en.arb:203`, `app_es.arb:161`).
  - "Inbox" and "Personal inbox" are adjacent chips on the Tasks tab (`home_screen.dart:158-159`) and both appear in the picker (`task_list_picker.dart:44,64`).
  - "Unfinished captures" still appears on Notes (`notes_screen.dart:53`).
  - Spanish still has "Lista para cuando tú quieras" (`app_es.arb:5`) and the short form "Bandeja · N" (`app_es.arb:139`).
  - Watch out: the proposed rename to "Personal" collides with the list-name examples (UX-311).
- **U8 — still open,** and also present on Notes (`notes_screen.dart:138-157`) and on project pages (`task_actions.dart:39-63`).
- **U4 — still open in this slice's widget:** the project chip always appears on the capture result (`capture_review_editor.dart:391` → `task_list_picker.dart:42-46`) and reads "Personal inbox".
- **U13 — undecided.** Evidence is under Questions.
- Other U items are outside this slice.

### Questions for the owner
1. **U13 — should Notes keep its own tab?**
   - The Notes tab is a whole tab for one kind of item. It has its own search (notes only), its own project filter (an unlabelled dropdown, unlike the chip used elsewhere — UX-323), and a paragraph explaining note vs task.
   - Notes are also reachable per project (project page → Notes).
   - Search never crosses kinds (UX-331).
   - The Tasks tab's distinctive content — projects — hides behind an unlabelled icon (UX-308), while its default list repeats the Calendar with the same two create buttons.
   - A single "Lists" tab (one search over tasks and notes · No date · projects · Notes · Completed) would turn three searches and two project filters into one of each.
   - If Notes get daily use, a separate tab is fine — but then make one search find both kinds.
2. **"Projects" or "Lists"?**
   - The 2026-10-11 direction (`App/docs/PROJECTS_IMPLEMENTATION.md`) renamed lists to projects.
   - The app's own examples are "Work, Personal, Shopping". In Spanish nobody calls the shopping list "un proyecto" — it's "la lista de la compra" — and the reminder text still says "En tu lista para hoy".
   - The mechanical rename also produced "Proyecto de pasos" (UX-310).
   - Options:
     - (a) Keep "Projects" and change the examples to project-like ones.
     - (b) Call personal containers "Lists" and use "Projects" only inside groups.
     - (c) Use "Lists" everywhere.
   - Whichever you choose, each object should have one name across English, Spanish and Catalan.
3. **One way to share?** Direct sharing (project → Sharing and people) and groups (Groups → New group → invite → New project) both exist. The newcomer meets the word "group" in the Projects help text before they need it. Should "Share" on a project be the only door, creating or reusing a group behind the scenes, with Groups left as an advanced view?
4. **Can verified accounts skip the code?**
   - Invitations need a separately shared code because password sign-up doesn't verify the email address (recorded 2026-10-11). Google sign-in does verify it.
   - Could Accept skip the code when the invitee is signed in with Google and the address matches?
   - That would remove the hardest step in UX-306 for most invitees, and it fits U14 option 1 (Google first).

### Cross-slice notes
- **B** · `screens/task_detail_screen.dart:121-145,381`: UX-309 changes the note version of the task detail screen.
- **B** · `screens/home_screen.dart:64-190`: at 320 dp and 2× text, the Tasks header (chip, eyebrow label, 64-sp headline, search, five wrapping filter chips) plus the two stacked create buttons likely push the first task or the empty state below the fold. Needs a device check.
- **B** · `screens/home_screen.dart:96-101` → `screens/completed_tasks_screen.dart:13-24`: the ✓ icon on a project page opens completed tasks from every project.
- **B** · `screens/home_screen.dart:212-214`: the Tasks search needs UX-303's accent folding.
- **A** · `screens/voice_task_screen.dart:259` and `widgets/capture_review_editor.dart:391`: the view filter becomes the capture destination. Keep the audience line on the result when U4 hides the chip (UX-302).
- **D** · `main.dart:200-223`: an invitation link opened while signed out waits silently. The login screen could say "Sign in to join Shopping".
- **Server-side** · `C:\Users\mikig\Desktop\Custom\MikiHacks\TaskFlow\TaskFlow\Backend\core\list_views.py:33-35` and `group_views.py:52-54`: the invitation data has no inviter name (UX-326). `Backend\templates\invitation.html`: the invitation web page and its "Copied…" message are English-only.

### Memory notes
- **New issues (2026-10-13, all OPEN):**
  - UX-301 (3) Archive and Mute silently stop a project's reminders; archive is one tap with no undo.
  - UX-302 (3) Moving a personal task into a shared project is one tap, can't be reversed (lockShared) and isn't confirmed; the view filter also becomes the capture destination.
  - UX-303 (3) Searches don't ignore accents (notes, projects, scope sheet, tasks).
  - UX-304 (3) The notes list is unsorted (no ORDER BY); a new note lands anywhere.
  - UX-305 (3) Share exists only in ⋮ on Projects, not on the project page; 8 taps and a 73-word dialog.
  - UX-306 (3) Invitations appear only on Projects and Groups; Accept needs a code; the group dialog shows the inviter's text and a "Save" button; decline acts instantly.
  - UX-307 (3) After accepting an invitation, no landing and no confirmation.
  - UX-308 (3) Projects reachable only via an unlabelled folder icon or the chip's sheet; the picker dead-ends with 0 projects.
  - UX-309 (3) A note can be edited only from the top-right pencil beside delete; the body isn't tappable.
  - UX-310–331 (2): Spanish/Catalan rename artifacts ("Proyecto de pasos", feminine forms); "Personal" collision; notes reuse task strings; dictating a note in a project ignores the project; view-only project page keeps create buttons; project pages inherit "For me"; Team/Everyone/Todo el grupo/Members/People; delete hidden under Sharing and destructive controls unstyled; tapping a pending invitation replaces its code; group dialogs ("Save", calendar error text, untitled role sheets); load-failure copy says "could not be saved"; Activity row order and unread state; bell with two meanings; Notes dropdown; picker has no tap cue and repeats the warning; assignment doubt shown as an error; invitation review copy and Cancel; no landing after creating a project; typed input lost on failure; Projects screen duplication; group page unlabelled invitations and spoken name; search doesn't cross tasks and notes.
  - UX-332–340 (1): colour chips at creation, eyebrow labels and repeated headlines, ★ / subtitle / count, fixed snackbars, group page title, permanent Notes help text, no hint when choosing a group, owner noise lines, silent leave and delete.
- **Status changes:**
  - U10: partly advanced (For me/Team now conditional); the bell and the "All projects" chip are still open.
  - U11: open; root cause is the uncommitted "No list" → "Personal inbox" rename.
  - U8: also on Notes and project pages.
  - U4: open in TaskAssignmentPicker.
  - U13: evidence logged.
- **Decisions found in docs — respect them, don't re-report as findings** (`App/docs/PROJECTS_IMPLEMENTATION.md`, 2026-10-11):
  - The interface calls lists "projects".
  - Groups contain people; a project belongs to one group or is personal; existing direct shares are kept.
  - Invitations are bound to an email address and need a separately shared code.
  - Archived groups drop out of the daily view, capture context and reminders.
- **Patterns:**
  - One global `projectScopeProvider` drives Calendar, Tasks, /inbox, project pages (via the team flag) and the capture destination.
  - `lockShared`: shared tasks can never leave their project.
  - Destructive actions use confirmation dialogs, not undo, and default teal styling.
  - `groupActionError` is reused for load failures.
  - `groupTextDialog` is reused for name, email and code.
  - Pushed screens repeat the app-bar title as a headline, with an uppercase eyebrow label above it.
  - Notes reuse task strings.
  - No accent folding anywhere; `getTasks` has no ORDER BY.
- **Screen map:**
  - Tasks tab = HomeScreen(isRoot). Chips: All / Inbox (no date) / Personal inbox (no project) / Today / High priority. Folder icon → /lists. ✓ icon → /completedTasks.
  - /inbox = HomeScreen(initialFilter 3), reached from Calendar's "Inbox · N".
  - /lists = TaskListsScreen, titled "Projects": Groups button, search, invitations, refresh, rows with ⋮ (pin, updates (shared only), edit, archive, Sharing and people (synced only), choose details (conflicts only)), New project.
  - Project page = HomeScreen(listId): For me/Team (shared only), Members + bell (shared only), Notes, search, Say a task / New task.
  - ListSharingScreen: direct sharing (owner: invite, members, pending, delete; member: leave).
  - GroupsScreen → GroupScreen: members, invite → role sheet → code, spoken name, invitations, projects, New project → TaskListsScreen(groupId, createOnOpen), then rename / archive / transfer / delete, or leave.
  - InvitationReviewScreen: opened by the `taskflow://invite` link, which is kept for 7 days.
  - ActivityScreen: opened by the app-bar bell on every root tab.
  - Notes tab = NotesScreen. A project's notes = NotesScreen(listId).
  - Note detail = TaskDetailScreen, note version (no bottom bar). Note editor = TaskEditor(kind: note).
