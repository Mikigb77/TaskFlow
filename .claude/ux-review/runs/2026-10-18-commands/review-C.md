## UX review — C · Projects and sharing (person filter; project and assignee pickers for voice commands) — 2026-10-18

**Verdict:** Ship after fixes — nothing is lost and every new path ends somewhere, but at the newcomer's text sizes people chips and a new project's name drop out of sight, people show as email prefixes, and naming a person for a brand-new project ends with no next step.

**Walked** (newcomer: Spanish, 1.3×–2×, 320–393 dp; daily user; TalkBack):
1. One person's tasks in a shared project: Tareas → Proyectos → Familia → Paul. 4 taps, plus a sideways swipe nobody is told about when Paul's chip is off-screen.
2. Add a task with a person's chip on: Nueva tarea → title → Mañana → Añadir al calendario. 3 taps; the page switches back to Todas so the new task shows (good).
3. Create a project by voice with a task («Crea un proyecto de matemáticas y añade terminar la presentación para el 12»): Añadir tarea → Listo → Añadir al calendario. 3 taps; checking or changing its project (chip → sheet) adds 2.
4. A project said that doesn't exist, without «crea»: Añadir tarea → Listo → Crear «Química» → Añadir. 4 taps.
5. Assign by voice in a shared project, then correct the person by touch: 3 taps, plus 2.
6. Name a person for a project the same dictation creates: 3 taps. The way to give Paul the task is never shown.
7. Find by voice and open the project («Enséñame las tareas de Paul en Matemáticas» → Abrir «Matemáticas»): 3 taps, plus 1 to pick Paul again.

States checked: a person with nothing open; a search plus a person; the chosen person leaves; viewer; archived; first load; offline (everything here runs on the phone); 2× at 320 dp in ES and CA; dark (M3 default chip colours; no dark render).

How: `App/build/project-people-filter-es.png` and `task-created-by-es.png` (rendered 15:50, after the last change to these files at 15:48). Everything else comes from the code, plus a Manrope width model (w700, 14 sp, M3 chip padding) that matches that render's chips within 1–3 dp. I didn't run Flutter.

**Numbers:**
- Shared project page (3 people, 2 tasks): 12 → 14 visible tap targets (two person chips).
- Person chips visible without a swipe, 2 other people (today → after UX-1101):
  - 1× · 390 dp, «Ana», «Paul» (the render's case): 2/2 → 2/2;
  - 2× · 393 dp, «Ana», «Paul»: 1/2, and nothing is cut, so the row looks complete → 2/2;
  - 1.3× · 393 dp, «Ana García», «Paul»: 1/2, nothing cut → 2/2;
  - 1× · 360 dp, «ana.garcia84», «paulsmith»: 1/2 → 2/2;
  - 2× · 320 dp, «Ana», «Paul»: 0/2 (a 6 dp sliver) → 2/2.
- A new project's chip at 2× shows 0 letters of the project's name (ES «Nuevo proyec…», CA «Projecte nou: …», EN "New project: …") → the whole name.
- See Paul's tasks after asking for them by voice: 4 taps → 3.
- Fix a misheard new project's name: say everything again, or after saving go Tareas → Proyectos → ⋮ → Editar (4 taps + typing) → 1 tap + typing on the card.
- Picker sheet with a dictated project and no other project: 3 choices, two of them starting «Nuevo proyecto» → 2.

### Findings (most severe first)

**UX-1101 · Severity 3 · People chips can hide off-screen, with no sign**
- Where: `App/lib/widgets/project_scope_control.dart:262-273` (one sideways-scrolling row, clipped at the page's 24 dp side padding, `App/lib/screens/home_screen.dart:328-329`); a shared project's page with 2 or more other editors.
- The moment: "Ana's there… where's Paul? Isn't he in Familia?"
- What happens:
  - The chips sit in one row that scrolls sideways and is clipped 24 dp before the screen edge. When a gap between chips falls at the clip, the row looks complete:
    - 2× · 393 dp, «Ana», «Paul»: Ana ends 2 dp before the clip, and Paul is entirely off-screen;
    - 1.3× · 393 dp, «Ana García», «Paul»: the same;
    - 1× · 360 dp, accounts named by their email («ana.garcia84», «paulsmith», see UX-1102): Paul is hidden, and Ana is cut by 1 dp;
    - 2× · 320 dp: only Todas and Para mí show; the first person is a 6 dp sliver.
  - The newcomer doesn't know to swipe sideways.
  - The existing 2× test has to drag the row 2,000 dp to reach the last chip (`App/test/project_people_filter_test.dart`, the 320 dp case).
- Why it fails:
  - Hidden UI gets found less (Pernice & Budiu 2016), and a swipe has no signifier (Norman & Nielsen 2010).
  - Older users rely on what they can see (Nielsen 2013).
  - Material 3's chip guidance wraps filter chips onto new rows, and turns to sideways scrolling only beyond two rows (m3.material.io/components/chips/guidelines).
- Fix:
  1. Wrap the chips, as Calendar's pair already does (`project_scope_control.dart:87-91`). Keep today's sideways row only when the chips would need a third row. In that case, run it to the screen edges (the 24 dp becomes padding inside the scroll view), so the next chip is visibly cut at the edge.
  2. Keep the list where it is. On project pages, move ✓ (Tareas completadas) into the app bar (`CustomAppBar.actions`).
     - That frees the 48 dp row it sits in alone, plus its gap, about 60 dp in all (`home_screen.dart:370-386`). An archived project keeps its line, as text.
     - A wrapped second chip row costs about 50–60 dp, so the first task sits no lower than today.
  - No copy change.
- Verify:
  - A widget test with Manrope loaded, in ES and CA, with «Ana García» + «Paul» at 1.3× on 393×851 and «Ana» + «Paul» at 2× on 320×640:
    - every person chip is hit-testable and fully on screen without a drag;
    - the first task row's top is no lower than in the current build.
  - With 8 editors at 2×, the row scrolls, and the last visible chip crosses the screen's right edge.
- Evidence: the current render (1×, where everyone fits) plus the width model from code. The existing 2× test's drag confirms that chips sit off-screen. The feel at 2× needs a device check.

**UX-1102 · Severity 2 · People appear as email prefixes**
- Where:
  - the new person chips (`project_scope_control.dart:247-259`);
  - «Creada por …» (`App/lib/screens/task_detail_screen.dart:146-150`);
  - the assignee chip and its sheet (`App/lib/widgets/task_assignment_picker.dart:96`, `:125-134`);
  - the tags on task rows.
- The moment: "«mgarcia61», «tech.garbar»… which one is my wife?"
- What happens:
  - Every person's name the app shows is the server's `display_name`: the full name, or else the part of the email before the @ (`Backend/core/list_access.py:29-30`).
  - No account has a full name. Google sign-in stores none (`Backend/core/google_auth.py:77`), and the app's sign-up sends none (`App/lib/services/api_client.dart:224-229`).
  - So real chips read «ana.garcia84 · paulsmith», never the preview's «Ana · Paul». Email prefixes are also the widest labels, which makes UX-1101 worse.
  - UX-326's note accepted this for one invitation line. The person filter now makes it the label of a control.
- Why it fails: match the real world, because people know each other by name (Nielsen 1994, #2); recognition over recall (#6).
- Fix: show people by their name.
  - For Google accounts (the first sign-in option, D8), use the name on their Google account, taken at sign-in, falling back to the email prefix. The cause is likely server-side.
  - For password accounts, see Questions for the owner.
  - No app copy change.
- Verify: device check with two Google accounts sharing a project: the chips, the assignee sheet and «Creada por» show the Google names.
- Evidence: verified in the app and server code. The render's names are test fixtures that no real account can have today.

**UX-1103 · Severity 2 · The assignee chip doesn't look tappable**
- Where: `App/lib/widgets/task_assignment_picker.dart:89-96`; a task in a shared project, on the capture card, the new-task form and task details.
- The moment: "It gave it to Ana. I meant Marta — do I have to say it all again?"
- What happens:
  - Beside «📁 Matemáticas ▾», the person chip reads «👤 Ana», with no ▾. UX-324 gave the project chip its ▾ as the tap cue; the person chip never got one.
  - In `task-created-by-es.png`, «👥 Todos» looks like a fixed tag, yet tapping it opens «¿Quién es responsable?».
  - Plan item 3 promised the person "with a one-tap change". The tap exists, but nothing signals it, so the likely correction is «Volver a decirlo».
- Why it fails:
  - It needs a visible signifier (Norman 2013), and should match the chip next to it (Nielsen 1994, consistency).
  - Correcting by touch beats dictating again, which tends to repeat the error (Karat et al. 1999; Suhm, Myers & Waibel 2001).
- Fix:
  - Whenever the chip can be changed (`onChanged != null && editable`), add the same ▾ after the label (`Icons.arrow_drop_down_rounded`, 18), as `App/lib/widgets/task_list_picker.dart:169-176` does.
  - Keep the name as the label: it matches the rows' tag. The plan's longer «Asignada a Paul» would fade the name first in a 2× chip.
  - No copy change.
- Verify:
  - Widget test: on a capture card with a shared project and Ana assigned, the person chip shows ▾, and a tap opens «¿Quién es responsable?».
  - In a view-only project, no ▾.
  - At 2× on 320 dp, the ▾ isn't cut.
- Evidence: seen in a current render (task details) and verified in code.

**UX-1104 · Severity 2 · A new project's chip hides its name at large text**
- Where: `App/lib/widgets/task_list_picker.dart:133-139` (the label, `commandNewProject`) and `:167-176` (the 230 dp cap). It shows on a dictated task that goes to a project the confirming tap will create.
- The moment: "New project… which one? Did it get the name right?"
- What happens:
  - The chip reads «Nuevo proyecto: {name}», with the name last, cut at 212 dp of text:
    - ES at 1.3×: «Nuevo proyecto: Mate…»; at 2×: «Nuevo proyec…»;
    - CA at 2×: «Projecte nou: …»;
    - EN at 2×: "New project: …".
  - After «Crear «Química»» for a project that wasn't found, there's no project card. This chip, on every task going there, is the only place the name shows.
- Why it fails: put the distinguishing word first (Nielsen 2006; Pernice 2017); people need to see what the system understood (Budiu & Laubheimer 2018).
- Fix:
  - Put the name first on the chip, with a new key, `commandNewProjectChip`: EN "{name} (new)", ES «{name} (nuevo)», CA «{name} (nou)».
  - Keep `commandNewProject` for the sheet row and the project card, which wrap.
  - Modelled: at 1.3×, «Matemáticas (nuevo)» shows in full; at 2×, «Matemáticas …».
- Verify: widget test with Manrope, at 2× on 320 dp, in ES, CA and EN: the chip's text starts with the project's name and shows at least its first 8 characters.
- Evidence: verified in code, plus the width model. No render shows this chip.

**UX-1105 · Severity 2 · «Paul no está en «Matemáticas»» gives no next step**
- Where: `App/lib/widgets/capture_review_editor.dart:460-474` (`commandMemberNotIn`, under the project chip when the dictation creates the project and names a person).
- The moment: "So does Paul get it or not? How do I put him in?"
- What happens:
  - The line only states the problem.
  - On saving, the task goes into the new project as the account's own task (`App/lib/screens/voice_task_screen.dart:2763-2770`).
  - To give it to Paul: Tareas → Proyectos → Matemáticas → Compartir → his email, then wait for him to join, then pick him on the task.
  - Nothing on the card says so, and saving doesn't open the project (see Cross-slice notes).
- Why it fails:
  - A message should say how to fix it (Nielsen 2001); "what do I do now?" is a gulf of execution (Norman 2013).
  - The plan keeps inviting in Compartir, so the copy has to point there.
- Fix: a new key for this new-project case only. `commandMemberNotIn` stays for existing projects, where the person may not be allowed to share.
  - ES «{name} aún no está en «{project}». Luego, comparte el proyecto con {name}.»
  - EN "{name} isn't in “{project}” yet. Afterwards, share the project with {name}."
  - CA «{name} encara no és a «{project}». Després, comparteix el projecte amb {name}.»
  - «Compartir» is the name of the project page's button.
- Verify:
  - Widget test: «Crea el proyecto Matemáticas… Paul tiene que…», with no members, shows the new line with both names.
  - An update that names a non-member in an existing project still shows `commandMemberNotIn`.
- Evidence: verified in code.

**UX-1106 · Severity 2 · Two «Nuevo proyecto» rows; a misheard name can't be fixed**
- Where: `App/lib/widgets/task_list_picker.dart:58-64` (the dictated row; tapping it does nothing) and `:86-91` (the «Nuevo proyecto» row, shown when the account has no project it can edit).
- The moment: "«Nuevo proyecto: Quico» and «Nuevo proyecto»… which one? And it's Kiko, not Quico."
- What happens:
  - A newcomer's first project by voice: the sheet lists «Nuevo proyecto: Quico» (selected), «Sin proyecto» and «Nuevo proyecto».
  - The plain «Nuevo proyecto» row creates a project straight away, from a dialog, and that project stays even if the result is then cancelled. The dictated one waits for the confirming tap.
  - Tapping the dictated row just closes the sheet.
  - A misheard name can only be fixed by saying everything again, or after saving: Tareas → Proyectos → ⋮ → Editar (4 taps + typing).
  - The card's task title can be edited in place; the project's name can't.
- Why it fails:
  - Two different actions mustn't look alike side by side (Norman 2013, mapping).
  - Corrections should happen by touch (Karat et al. 1999; Suhm, Myers & Waibel 2001).
  - It's inconsistent with the card's own editable title.
- Fix:
  1. While a dictated project is shown (`newName != null`), hide the «Nuevo proyecto» row.
  2. Tapping the dictated row opens its name to correct:
     - the title is `newList` («Nuevo proyecto») and the field `listName` («Nombre»), prefilled;
     - the button is a new key: «Usar este nombre» / "Use this name" / «Fes servir aquest nom»;
     - the new name replaces the old one on the project card and on every task that goes there. They're linked by name, as in `_removeCommand` (`voice_task_screen.dart:2590-2620`).
     - Still, nothing is created before the confirming tap.
- Verify: widget test with no project and «Quico» dictated:
  - exactly one sheet row starts with «Nuevo proyecto»;
  - tap it, type «Kiko» and tap «Usar este nombre»: the project card and the chip read Kiko;
  - saving creates only «Kiko».
- Evidence: verified in code.

**UX-1107 · Severity 2 · «Abrir» after a search for Paul's tasks drops Paul**
- Where: `App/lib/widgets/capture_command_cards.dart:495-513` pushes `HomeScreen(isRoot: false, listId: project.id)`, and `App/lib/screens/home_screen.dart:24-29` has no way to start on a person.
- The moment: "I asked for Paul's tasks. Why is it showing everyone's?"
- What happens:
  - «Enséñame las tareas de Paul en Matemáticas» lists Paul's tasks, but «Abrir «Matemáticas»» opens the page on Todas.
  - Getting back to Paul means finding his chip, which may be off-screen (UX-1101).
  - «Mis tareas de Matemáticas» also opens on Todas, not Para mí.
- Why it fails: don't make people carry information over from the previous screen (working memory, Cowan 2001); the result and the page it opens should agree (Nielsen 1994, consistency).
- Fix:
  - Pass the search's person to the page, for example `HomeScreen(…, person: command.personId)`.
  - It opens on that person's chip, or on Para mí when the person is the account. Someone without a chip (a viewer, or someone who left) opens on Todas.
  - No copy change.
- Verify: widget test with a find for project Matemáticas and person Paul. Tap «Abrir «Matemáticas»»:
  - Paul's chip is selected, and only his open tasks are listed;
  - with the account's own id, Para mí is selected.
- Evidence: verified in code.

**UX-1108 · Severity 2 · «Para mí» and «Todas» swap places between screens**
- Where: `App/lib/widgets/project_scope_control.dart:235-246` (the people row: Todas, Para mí, …) against `:199-210` (Para mí, Todas). The second order shows on Calendar, on Tareas, and on a shared project where nobody else can edit.
- The moment: "I tapped the first chip like always — why am I seeing everyone's?"
- What happens: the same two chips come in opposite orders depending on the screen, and on a project page depending on whether anyone else can edit.
- Why it fails: consistency (Nielsen 1994); daily users tap by position, without reading.
- Fix:
  - Use one order everywhere: the one the approved plan writes («Todas · Para mí · Paul…»).
  - Swap the pair at `:199-210`, so Calendar, Tareas and the fallback also read Todas, Para mí. This touches area B's screens.
  - No copy change.
- Verify: widget test on Calendar, Tareas, a shared project with only viewers, and one with two editors: the first ChoiceChip reads Todas (CA Totes), and the second Para mí (CA Per a mi).
- Evidence: verified in code.

**UX-1109 · Severity 1 · An empty person view talks about matching**
- Where: `App/lib/screens/home_screen.dart:502-515`.
- The moment: "«No hay tareas que coincidan»? I didn't search for anything."
- What happens: tapping someone with no open tasks shows «No hay tareas que coincidan» / «Prueba otra palabra o filtro.», even though no word was typed.
- Why it fails: say what happened, plainly (ISO 24495-1; Nielsen 2001).
- Fix: when the person chip is the only filter on (no search, no label):
  - title: ES «{name} no tiene tareas pendientes aquí» / EN "{name} has nothing open here" / CA «{name} no té tasques pendents aquí»;
  - message: ES «Toca Todas para ver todas las tareas.» / EN "Tap All to see every task." / CA «Toca Totes per veure totes les tasques.»
  - With a search or a label on, `noMatches` stays.
- Verify: update the test "someone with nothing assigned" in `App/test/project_people_filter_test.dart`: the title names Marta, and with a word typed, `noMatches` comes back.
- Evidence: verified in code; the current test asserts today's text.

**UX-1110 · Severity 1 · TalkBack hears a person chip as just a name**
- Where: `App/lib/widgets/project_scope_control.dart:247-259`.
- The moment (TalkBack): "«Ana, botón» — will that call Ana?"
- What happens: each chip's accessible name is the person's name alone; nothing says that it filters the list.
- Why it fails: labels describe their purpose (WCAG 2.2, 2.4.6).
- Fix:
  - Give each person chip a semantics label, reusing `commandFindPerson`: ES «Tareas de Ana», EN "Ana's tasks", CA «Tasques assignades a Ana».
  - «Todas» uses `allTasks` («Todas las tareas»).
  - The visible text doesn't change.
- Verify: semantics test: Ana's chip has the label «Tareas de Ana» and its selected state; Todas has «Todas las tareas».
- Evidence: verified in code.

### Keep
- A task saved on a filtered project page always shows. `_land` drops Para mí or a person when they'd hide it (`home_screen.dart:135-171`), so U5 holds there.
- The chips and voice search follow one rule for "someone's tasks" (`App/lib/services/task_matcher.dart:79-95`). A person's chip lists exactly the rows tagged with their name. Viewers can't be given tasks, so they get no chip.
- A person who leaves takes their chip and their filter with them (`_personShown`, tested).
- Nothing is created before the confirming tap. Removing the project card also takes the project off its tasks, and one Deshacer takes the project back.
- The picker sheet shows the dictated project as the chosen row, with «Sin proyecto» not chosen, so the current state reads at a glance.

### Progress against UX_REVIEW.md (U1–U14)
- **U5** (land on the task):
  - advanced on project pages: a filter never hides a task just saved there;
  - still open for a project created by voice: the project itself isn't shown (see Cross-slice notes).
- **U11** (names): held. The new copy says «proyecto» throughout; «grupo» and «lista» are only understood in dictations.
- **U10:** not affected; the people row appears only on shared project pages.
- **U13:** still a decision; nothing here changes it.

### Questions for the owner
1. **Who a task is for when it's added with a person's chip on.**
   - Today, a task added while «Ana» is selected goes to «Todos», and the page switches back to Todas to show it.
   - Should it be Ana's by default, as a picked day already is (D9), and as the project page already sets the project? It shows on the form and on the card, and changes with one tap.
   - Recommendation: yes.
2. **Names for password accounts** (with UX-1102).
   - Nothing asks these accounts for a name, so they show as their email prefix. The options:
     - ask once at sign-up (one more field on the first screen);
     - ask once when they first share or join a shared project, prefilled from the email, and skippable.
   - Recommendation: the second, asked when the name starts to matter.

### Cross-slice notes
- A · `App/lib/screens/voice_task_screen.dart:2892-2937`: after a dictation creates a project, «Proyecto creado» shows, but nothing opens or highlights it. A project-only dictation lands nowhere. Making a project from Proyectos opens its page (UX-327).
- A · `App/lib/widgets/capture_command_cards.dart:209` (from `capture_review_editor.dart:293-330`): a project said that doesn't exist lists every editable project as a chip (10 projects → 12 chips). Show the similar ones (`_likeFirst`) plus one «Otro proyecto…» that opens the picker sheet.
- A · `App/lib/widgets/capture_command_cards.dart:463-471`: a search by person and project is headed «Tareas de «Matemáticas»», dropping Paul; say «Tareas de Paul en «Matemáticas»».
- A · `commandExistingProjectTasks` («Las tareas van ahí.», in all three ARB files) is plural even for a single task; make it an ICU plural.
- B · `App/lib/screens/task_detail_screen.dart:146-150`: the account's own tasks read «Creada por» plus its own name; say «Creada por ti» / "Created by you" / «Creada per tu» when `createdBy` is the account.

### Memory notes
- **The person filter (2026-10-18):**
  - On a shared project page with at least 1 other editor, `_PeopleFilter` (`project_scope_control.dart`) shows single-select ChoiceChips «Todas · Para mí · names», in one sideways row.
  - A person's chip shows the tasks assigned to them. Para mí shows the account's own tasks, Todos tasks and personal ones (plus unassigned ones for managers): the same rule as voice find (`task_matcher.dart:_isFor`).
  - Other project pages keep the old pair, «Para mí · Todas», in the opposite order (UX-1108).
  - `_land` clears both when they'd hide a saved task.
- **Area C map additions:**
  - a new way into a project page: voice find's «Abrir «X»», which carries no person;
  - a new project by voice is created only on the confirming tap. `TaskListPicker.newName` shows «Nuevo proyecto: X» as the chip and as the selected sheet row; `ProjectChoices` shows chips when a said project doesn't exist. Its tasks go in as the account's own (`'personal'`);
  - the project page header: people row, a row holding only ✓, Miembros or Compartir, Notas, search.
- **Names:** every person's label is the server's `display_name`, and no account has a full name today: Google sign-in stores none and sign-up sends none. So real chips read email prefixes; the test fixtures «Ana» and «Paul» hide this.
- **Recurring problem types:**
  - the distinguishing word comes last in a capped chip, so «Nuevo proyecto: X» shows no name at 2×. A chip-level case of "the result comes last";
  - context is dropped when a voice result opens a page (the person in «Abrir»);
  - sideways chip rows clipped inside the page padding can look complete.
- **Technique:** a chip width model. An M3 chip is 8 dp padding, plus label padding (8 dp at 1×, falling to 4 dp at 2×), plus the label (labelLarge: Manrope w700, 14 sp), plus 8 dp padding, plus 18 dp for a selected chip's check mark. It matched `project-people-filter-es.png` within 1–3 dp.
