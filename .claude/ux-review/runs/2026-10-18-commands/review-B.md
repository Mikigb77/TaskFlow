## UX review — B: the new-task form, Calendar and task details (changes since refs/ux-review/last) — 2026-10-18

**Verdict:** Ship after fixes. At normal text the form works for the newcomer: 3 taps plus typing, and it ends on the lit row with Deshacer. But a task made for another member disappears behind Calendar's default «Para mí». At large text the keyboard hides the day and time choices and the title can't be read back. The form also offers two different «Añadir hora».

**Walked** (newcomer: ES, 1.3×–2×, one hand; daily user; TalkBack / low vision / tremor):
1. Free account at 0 left. Calendar › «Nueva tarea» › (once a month, the used-up notice › «Crear una tarea») › title › «Mañana» › «Añadir al calendario». It lands on Mañana, with the row lit and «Añadida al lun, 19 oct · Deshacer». 3 taps plus typing; 4 the first time each month.
2. The same flow for «el viernes a las 17:00»: «Elegir día» › 23 › «Listo» › «Añadir hora» › dial › «Aceptar» › «Añadir al calendario». 8 taps.
3. Free account with dictations left: «Añadir tarea» › «Rellenar a mano» (the words heard become the title and notes) › «Mañana» › «Añadir al calendario». 4 taps.
4. From Tareas, Sin fecha, a project page and the timeline. Read in code and tests: the task lands on that page, lit.
5. The surrounding states:
   - Back with and without a title;
   - offline (saved on the phone first);
   - session expiry (the form survives);
   - a call;
   - Android closing the app during the photo picker;
   - Más detalles: notes, files, reminder, repeat, steps and project, then «Menos detalles»;
   - a failed save (the form stays filled).
6. A task for another member, saved from Calendar and from the Tareas root, under the default «Para mí».
7. Calendar's first run, and the Tareas and Sin fecha empty states, for an account whose button reads «Nueva tarea».
8. Task details in a shared project, with «Creada por».

**Evidence base:**
- Renders, all written 15:49–15:50 today, after the last code commit (15:48): `new-task-form-es`, `-details-es`, `-2x-es`, `-2x-ca`, `capture-fill-by-hand-es`, `task-created-by-es`, `project-people-filter-es` and `calendar-es-1.3x-light`.
- Widget code and tests.
- Flutter SDK source for the focus and time-picker behaviour.
- Flutter was not run. Dark mode was reasoned from the theme, because no dark render covers the form.

**Numbers:**
- **Free account at 0 left, a task for tomorrow:** 3 taps plus typing (4 the first time each month).
- **«el viernes»:** 5 → 4 taps (UX-1004).
- **«el viernes a las 17:00»:** 8 → 7 taps, and the hour is typed instead of aimed at a dial ring 28 dp from the wrong one.
- **Free account with dictations left, by hand:** 4 taps.
- **The form's first view:** 7 tap targets (8 once a day is chosen), and 18 words before the first choice.
- **At 2× on 320×640 with the keyboard up:** 3 of the form's 6 controls are in view, and two of those are cut.
- **The used-up notice:** 30 words and 2 buttons.
- **The attach sheet for a new task:** 31 words → 0.
- **Time controls in the form's flow:** 2 → 1.
- **Calendar's tap targets (U10):** unchanged; the button swap doesn't change the count.

### Findings (most severe first)

**UX-1001 · Severity 3 · A task for someone else lands out of sight**
- Where:
  - Calendar: `App/lib/screens/calendar_screen.dart:119-134`. `_land` never touches the filter, and the landing at `:296-300` and `:319-331` lights only rows the filter shows.
  - The Tareas root: `App/lib/screens/home_screen.dart:143`. It clears «Para mí» for a landing only on a project page.
  - The default: `App/lib/providers/project_scope_provider.dart:7`. `team = false`, so «Para mí» is the default for every account with a shared project.
  - The rule: `App/lib/models/task.dart:59-63`. A task for Ana isn't «for me».
- The moment: "It says «Añadida al lun, 19 oct», and I'm on Monday. Where is it? I'll add it again."
- What happens:
  - In the form, Más detalles › Familia › «Todos» → «Ana» makes a task for Ana.
  - On save, Calendar selects Monday and shows the message with Deshacer. But the row is filtered out: nothing is lit and nothing scrolls into view. The Tareas root behaves the same way.
  - Project pages, changed in this run, clear «Para mí» and the person filter for a landing. Calendar and the Tareas root don't.
  - The voice-commands plan's own example, «Paul tiene que terminar la introducción para el 8…» said on Calendar, lands the same way.
- Why it fails:
  - U5's rule: the saved task is on screen and lit, every time.
  - Change blindness (Rensink, O'Regan & Clark 1997): a message at the edge of the screen isn't enough.
  - The severity scale's own blocker example is "a saved task they can't see, so they add it twice". It is rated 3 only because it needs a shared project and a task for someone else.
- Fix:
  - Calendar's `_land`, and Tareas' at its root, should do what the project page now does. When the filter is what hides a landed task, switch to «Todas» / “All” / «Totes» (and to «Todos los proyectos» when the project filter hides it), then select the day and light the row.
  - No copy change.
- Verify:
  - Widget test: an account in a shared «Familia», with Calendar on its default «Para mí». In the form, choose Familia › Ana › Mañana › «Añadir al calendario». Calendar shows Mañana with «Todas» selected and the row lit.
  - Repeat from the Tareas root, and for a capture result assigned to Ana.
  - Phone: say «Ana tiene que llamar al médico mañana» on Calendar.
- Evidence: verified in code. `test/project_assignment_test.dart:514-520` shows the default scope leaving out a task for another member. No render covers it.

**UX-1002 · Severity 2 · The keyboard hides the day and time, then comes back**
- Where:
  - `App/lib/widgets/task_editor.dart:606`: the title takes focus when the form opens.
  - `:956-1006`: the day and time chips leave the focus on the title.
  - `:188-197` and `:226-242`: the date sheet and the time picker.
  - When a sheet or dialog closes, Flutter gives the focus back to the title (SDK `widgets/routes.dart:1166`, `:2207-2217`).
  - Nueva tarea, keyboard up, large text.
- The moment: "I wrote it. Where's the day? I only see Hoy and Mañana, cut in half." Later: "I chose 17:00 and the keyboard came back. Did it keep the time?"
- What happens:
  - In `new-task-form-2x-es.png` and `-2x-ca.png` (320×640, 2×, 300 dp keyboard), only the title and the top half of Hoy and Mañana show.
  - Elegir día, Añadir hora and Más detalles are under the keyboard, with no sign that there's more.
  - Tapping a chip leaves the keyboard up.
  - After the time picker or the date sheet closes, the title takes the focus back and the keyboard rises again, over the time chip just set.
  - The 1× render was taken only after the test removed the focus by hand (`test/new_task_form_test.dart:1046`).
- Why it fails:
  - Visibility of system status (Nielsen 1994) and the gulf of evaluation (Norman 2013): the result of a choice is hidden by a keyboard nobody asked for.
  - Older users rely on what's visible and don't scroll to look for hidden controls (Nielsen 2013).
- Fix:
  - When Hoy, Mañana, Elegir día or Añadir hora is tapped, take the focus off the title first, with `FocusScope.of(context).unfocus()`, as `_save` (`:333`) and Más detalles (`:700`) already do.
  - The keyboard goes down and the rest of the form shows, with the button at the bottom. No picker brings the keyboard back; tapping the title does.
  - No copy change.
- Verify:
  - Widget test at 2× on 320×640 with a 300 dp inset: type a title and tap Mañana. Nothing has the primary focus, and Añadir hora and Más detalles can be hit without scrolling.
  - Then open and confirm the time picker. The title isn't focused, and the time chip can be hit.
  - Phone, at the largest font on a 360 dp phone: title › Mañana › Añadir hora › 17:00. The «17:00» chip stays in view.
- Evidence: the hidden controls are seen in current renders. The keyboard's return comes from reading Flutter's code and needs a device check.

**UX-1003 · Severity 2 · The title is one line, so at 2× about 12 letters show**
- Where:
  - `App/lib/widgets/task_editor.dart:601-631`: the title field sets no `maxLines`, so it is one line.
  - The capture result's title wraps (`App/lib/widgets/capture_review_editor.dart:573-574`).
- The moment: "I can only see «…r al dentista». Did I write it right?"
- What happens:
  - At 2× on 320 dp the field holds about 12–14 characters. The render cuts even the hint, to «p. ej., Cita mé…».
  - A typed title slides sideways under the cursor.
  - Words carried over by «Rellenar a mano» can be a whole sentence of up to 160 characters (`taskTitleLength`, `App/lib/services/local_capture.dart:8`), and only its end shows.
  - The same field edits saved tasks.
- Why it fails:
  - The gulf of evaluation (Norman 2013): the person can't check what will be saved.
  - Consistency: the same title wraps on the capture result.
  - At 200% text, content must stay readable (WCAG 2.2, 1.4.4).
- Fix:
  - Set `minLines: 1, maxLines: 3, keyboardType: TextInputType.text`, and keep `TextInputAction.done`. The title wraps to three lines, and the keyboard's key still closes the keyboard rather than adding a line.
  - The limit is three lines, not unlimited, so Hoy and Mañana stay reachable above the keyboard (see UX-1002).
- Verify:
  - Widget test at 2× on 320 dp: a 40-character title shows whole on 3 lines, with no sideways scroll, and the keyboard action adds no line break.
  - At 1× on 390 dp, a 20-character title stays on one line.
  - The `new-task-form-2x-es` render shows the hint whole.
- Evidence: seen in a current render (the hint) and verified in code.

**UX-1004 · Severity 2 · Two «Añadir hora» in one form, and a picked date needs Listo**
- Where:
  - `App/lib/widgets/task_editor.dart:226-242`: the chip opens Android's clock dial.
  - `:976-984`: «Elegir día» opens the full date sheet.
  - `App/lib/widgets/schedule_editor.dart:201-204`: that sheet is titled «Fecha y hora».
  - `:284-301`: a date tapped in its calendar only selects, and the sheet has a second «Añadir hora».
  - `:412-416`: «Listo».
- The moment: "I tapped Elegir día and it says «Fecha y hora», with another Añadir hora. Which one do I use?" And: "17 is on the little inner circle. I got 5."
- What happens:
  - The form's «Añadir hora» chip opens the clock dial.
  - «Elegir día» opens the «Fecha y hora» sheet, which has its own «Añadir hora»: a switch with a typed hour and minutes. So one form has two controls with the same words.
  - In that sheet, a date tapped in the calendar only selects it, and «Listo» is a third tap. The sheet's Hoy, Mañana and Sin fecha chips apply at once.
  - On a 24-hour phone (the default in Spain), the dial puts 17 on an inner ring, 28 dp inside the 5. Flutter's dial is 256 dp, with its rings 100 dp and 72 dp from the centre (`material/time_picker.dart:49-51`, `:1525`, `:3739`). A tap slightly too far out saves 05:00.
  - Everywhere else (the capture result, the edit form and Cambiar fecha), the hour is typed.
- Why it fails:
  - Consistency, and one concept, one name (Nielsen 1994; ISO 24495-1).
  - Fitts's law and Material's 48 dp minimum: 28 dp between 5 and 17 is too close for older hands or a tremor.
  - Hick–Hyman: two ways to do one thing means a choice to make first.
- Fix:
  - From the form, open the date sheet for the day only:
    - titled «Elegir día» (`pickDay`);
    - without the time switch and the hour fields;
    - a date tapped in the calendar applies and closes the sheet, as Hoy and Mañana do.
  - This is a day-only mode beside `applyDays`; the capture result keeps the full sheet.
  - The chip opens the time already in typing mode: `showTimePicker(..., initialEntryMode: TimePickerEntryMode.input)`. Hour and minutes go in on the number keys, like the rest of the app.
  - No copy change.
- Verify:
  - Widget test, from the form: the sheet has no `schedule-has-time` and no `schedule-done`. Tapping a date closes it, and the third chip shows that day.
  - «Añadir hora» opens the picker in input mode, with the hour field focused.
  - Phone, in UX_REVIEW §7 with the father: "Move the doctor to Saturday at 5 in the afternoon."
- Evidence: verified in code. The dial's geometry comes from Flutter's code and hasn't been seen on a device.

**UX-1005 · Severity 2 · A new task is lost if Android closes the app**
- Where:
  - `App/lib/screens/edit_task_screen.dart:80-117` and `App/lib/widgets/task_editor.dart:150-175`: the new task lives only in memory, and `lib/` has no state restoration.
  - `:479-535`: «Añadir adjunto» leaves the app for the photo or file picker.
  - `App/lib/screens/voice_task_screen.dart:1488-1490`: «Rellenar a mano» discards the capture before the form opens.
- The moment: "I went to pick the photo of the prescription, and when I came back everything I'd written was gone."
- What happens:
  - The form keeps the title, notes, day and steps only in memory.
  - Choosing a photo or a file puts TaskFlow in the background. If Android closes it meanwhile, the app restarts on Calendar and the task is gone. That is common on low-memory phones, or after a long call.
  - Words carried over by «Rellenar a mano» were already removed from «Sin guardar», so a dictation is lost too. In the capture sheet they would have survived.
- Why it fails:
  - Lens I: nothing the person said or typed is lost.
  - User control and error recovery (Nielsen 1994).
  - UX_REVIEW §1a keeps "captures survive everything" as a strength, and this form is now how a free account creates every task.
- Fix:
  - Keep the words until the form saves:
    - «Rellenar a mano» hands its capture to the form instead of discarding it;
    - the form writes its title and notes to that capture, or to a new one at the first character typed (the sheet's rule since UX-102);
    - the form discards the capture when the task is saved, or when the person empties the title and leaves.
  - If Android closes the app, the words wait under «Sin guardar» and open in the form again.
  - No new copy.
- Verify:
  - Widget tests: after a title is typed, the capture store holds it; after «Añadir tarea» it doesn't; after «Rellenar a mano» the capture lasts until the save.
  - Phone: turn on Developer options › «No conservar actividades». Open Nueva tarea, type a title, then Más detalles › Añadir adjunto › Elegir una foto. Back in TaskFlow, the words are under «Sin guardar».
- Evidence: verified in code. The loss itself is inferred and needs that device check.

**UX-1006 · Severity 2 · The attach sheet explains older files to a new task**
- Where: `App/lib/widgets/task_editor.dart:496-503`, which shows `fileUploadHelp` (`App/lib/l10n/app_es.arb:556`, `app_en.arb:1005`, `app_ca.arb:535`). New task › Más detalles › «Añadir adjunto».
- The moment: "«Los archivos locales anteriores… hasta que elijas Subir»? What older files? I only want to add the photo."
- What happens:
  - Before «Elegir una foto» and «Adjuntar un archivo», a new task's sheet shows 31 words.
  - The second sentence is about older local files and a «Subir» button in the task details. Neither exists for a task that hasn't been saved yet.
  - A test asserts this paragraph (`test/new_task_form_test.dart:780-810`).
- Why it fails:
  - Minimalist design (Nielsen 1994).
  - People scan rather than read (Nielsen 1997).
  - Plain language: no internal terms such as «archivos locales» or «Subir».
- Fix:
  - For a new task, show no paragraph. The two rows speak for themselves, and `fileLimit` («Elige un archivo no vacío de hasta 6 MB…») still explains a file that's too big, when it happens.
  - Editing keeps `fileUploadHelp`.
  - Words before the choice: 31 → 0. Update that test.
- Verify: widget test: new task › Añadir adjunto shows neither `fileUploadHelp` nor `fileLocalHelp`, and an existing task's sheet is unchanged.
- Evidence: verified in code and in that test.

**UX-1007 · Severity 1 · «Menos detalles» hides filled notes, files and project**
- Where:
  - `App/lib/widgets/task_editor.dart:717-746`: when collapsed, the form shows the steps plus a summary of repeat, duration, deadline and priority.
  - `:750-768`: a new task's details.
- The moment: "I wrote the notes and chose Familia, tapped Menos detalles, and they disappeared."
- What happens: in a new task, «Menos detalles» hides Notas, the files, Recordatorio and Proyecto even when they're filled in. Steps already stay visible when collapsed.
- Why it fails:
  - Visibility of system status (Nielsen 1994).
  - Hidden content is found less often (Pernice & Budiu 2016).
  - Steps follow the rule; notes and files don't.
- Fix:
  - When collapsed, a new task keeps showing whatever holds something: Notas with text, the files, a chosen project. It already does this for steps. Empty rows stay hidden.
  - No copy change.
- Verify: widget test: type notes, add a file and a project, then tap «Menos detalles». All three are still on screen; Recordatorio and Repetir at their defaults are not.
- Evidence: verified in code.

**UX-1008 · Severity 1 · «Creada por» shows your own name instead of «ti»**
- Where:
  - `App/lib/screens/task_detail_screen.dart:146-150` and `:229-240`.
  - The server names every creator, the viewer included (`Backend/core/serializers.py:202`).
  - The assignee chip calls the viewer «Yo» (`App/lib/widgets/task_assignment_picker.dart:17-25`).
- The moment: "«Creada por Miguel»… that's me?"
- What happens: on your own task in a shared project, the line shows your name, one line under a chip that calls you «Yo».
- Why it fails:
  - Consistency (Nielsen 1994): the same screen refers to you in two ways.
  - Match with the real world: WhatsApp calls you «Tú».
- Fix: when `task.createdBy` is the signed-in account, show ES «Creada por ti», EN “Created by you” and CA «Creada per tu» (a new key, `createdByYou`).
- Verify: widget test: a shared-project task created by the account shows «Creada por ti»; one created by Ana shows «Creada por Ana».
- Evidence: verified in code.

**UX-1009 · Severity 1 · The notice calls the form «el formulario»**
- Where: `App/lib/widgets/task_form_entry.dart:96-103`, showing `freeVoiceNoticeBody` (`App/lib/l10n/app_es.arb:1196`, `app_en.arb:1959`, `app_ca.arb:900`).
- The moment: "«Con el formulario». Which form?"
- What happens:
  - The notice uses a name nobody sees anywhere else. The button and the page say «Nueva tarea», and the capture sheet calls the same thing «Rellenar a mano».
  - In ES and EN the date comes last: «Tendrás 10 dictados más el 1 nov.»
- Why it fails:
  - Plain language: one concept, one name (ISO 24495-1).
  - Front-load the key word (Nielsen 2006).
- Fix — the copy, keeping the plurals:
  - ES: «Puedes seguir creando tareas a mano, sin límite. El {date} tendrás {limit} dictados más.» For one: «El {date} tendrás 1 dictado más.»
  - EN: “You can keep creating tasks by hand, with no limit. On {date} you’ll get {limit} more dictations.” For one: “On {date} you’ll get 1 more dictation.”
  - CA: «Pots continuar creant tasques a mà, sense límit. El dia {date} tindràs {limit} dictats més.» Only «amb el formulari» changes.
- Verify: catalog test:
  - the notice contains none of «formulario», “form” or «formulari»;
  - the date comes before the number in all three languages;
  - Catalan keeps the date mid-sentence (UX-503).
- Evidence: verified in the catalogs.

### Keep
- The form opens on the title with the keyboard up, with Hoy / Mañana / Elegir día right under it. Its one filled button says where the task goes, in the capture result's words: «Añadir tarea» or «Añadir al calendario».
- Saving lands like a capture: Calendar on the day, the row lit, «Añadida al lun, 19 oct · Deshacer», and the reminder question after the first dated task. It works offline, because the task is saved on the phone first (`task_editor.dart:429-431`).
- The button and the page share one name, «Nueva tarea». The first-run line, «Prueba: toca Nueva tarea, escribe «Llamar al dentista» y toca Mañana.», teaches by doing, and the Tareas and Sin fecha empty states name the button that's on screen.
- Más detalles holds six things for a new task. Duration, deadline, priority and labels wait until the task is edited.
- «Creada por» shows only in shared projects, as one quiet line.

### Progress against UX_REVIEW.md (U1–U14)
- **U5 (land on the task) — advanced.** The form lands like a capture from Calendar, Tareas, project pages and the timeline, lit and with Deshacer.
  - Still open: a task for another member under «Para mí» (UX-1001).
  - Also still open: widget and shortcut entries saved while another tab shows (see the cross-slice notes).
- **U8 (one creation control) — held.** There is one filled button per screen. Its label follows the account: «Añadir tarea» with the mic, or «Nueva tarea» with +.
- **U12 (learn by doing) — advanced.** `calendarTryForm` teaches the form on the first visit.
- **U11 (names) — one new slip:** «el formulario» in the used-up notice (UX-1009).
- **Unchanged:** U10, because the button swap doesn't change the tap-target count. The other items aren't touched in this area.

### Questions for the owner
1. **D12 for a new task.**
   - Back with a title saves the new task and says «Cambios guardados · Deshacer» (`task_editor.dart:424-425`, locked by `test/new_task_form_test.dart:379`).
   - Saving with the button says «Añadida al lun, 19 oct · Deshacer».
   - A newcomer who presses Back to get out hears about changes he didn't make, and isn't told the day.
   - Recommendation: keep D12's saving, but for a new task show the button's message.
2. **For the open default-day question.**
   - The form never reads the title for a date (2026-10-18). Typing «Médico el viernes» and tapping «Añadir tarea» saves the task to Sin fecha (`test/new_task_form_test.dart:271`).
   - The first-run line teaches the chips, but someone used to dictating «mañana…» will type it.
   - Weigh this case when choosing the default day.

### Cross-slice notes
- **A:** voice assignments land out of sight too, from the same cause as UX-1001. Fixing Calendar's and Tareas' `_land` covers them.
- **A:** «Rellenar a mano» discards the capture before the form opens (`voice_task_screen.dart:1488-1490`). This is the sheet's half of UX-1005.
- **A:**
  - At 0 left, the widget's and the voice shortcut's «dictar» now open the form (`voice_task_screen.dart:76-87`).
  - Once that month's notice has been seen, nothing says why there's no mic. UX-106 and UX-498 used to show the reset date and «Ver Pro».
- **A:**
  - Widget and shortcut entries open capture or the form without `showCalendar` (`main.dart:195-202`).
  - So a task saved while the app was on Tareas, Notas or Ajustes lands on Calendar out of sight (`main_shell.dart:46`). This applies to the capture sheet and the form alike, and existed before this run.
- **D (theme):**
  - Chip borders use `outlineVariant`: 1.20:1 against the background and 1.28:1 on white (`app_theme.dart:152-153`).
  - The form's Hoy / Mañana / Elegir día chips are now a free account's main controls.
  - UX-412 moved text fields to `outline` (3.79:1).

### Memory notes
- **Who sees which add button** (`subscription_provider.dart` `opensFormProvider`, `typesInFormProvider`):
  - **Pro:** «Añadir tarea» with the mic opens the capture sheet. Typed words go to the assistant.
  - **Free, with dictations left:** «Añadir tarea» with the mic. In the sheet, the keyboard option reads «Rellenar a mano» and opens the form with the words heard.
  - **Free, at 0 left, or no count from the server:** «Nueva tarea» with + opens the form (route `/newTask`, `NewTaskScreen` → `TaskEditor` in create mode). The first tap each month shows the used-up notice (`task_form_entry.dart`).
  - **While billing loads:** the old typing sheet.
- **The new-task form:**
  - The title comes first and is autofocused. Then come the Hoy / Mañana / Elegir día chips, and an «Añadir hora» chip (Android's time picker) once a day is chosen.
  - Más detalles holds notes, files, reminder, repeat, steps and project.
  - The button reads «Añadir tarea» or «Añadir al calendario», like the capture result.
  - It lands through `CalendarFocus`, like capture. Back saves (D12).
- **Filters:** Calendar's and Tareas' project filter defaults to «Para mí» (`ProjectScope.team = false`) once there's a shared project, so any landing must check the filter. Project pages clear it; Calendar and the Tareas root don't yet (UX-1001).
- **Recurring problem types:**
  - Forms whose autofocused field gets its focus back after every dialog or sheet (Flutter restores the scope's focused child).
  - Single-line titles at 2×.
  - Two time-entry patterns: the date sheet's typed hour, and the system dial used for the reminder time and the form's chip.
  - Forms that keep nothing if Android closes the app, while the capture store does.
- **Previews:** the form previews come from `test/new_task_form_test.dart` with `--dart-define=WRITE_FORM_PREVIEWS=true`, which isn't in CLAUDE.md's list. They write `build/new-task-form-*.png`, `capture-fill-by-hand-es`, `project-people-filter-es` and `task-created-by-es`.
- **«Creada por»:** shown on task details only for shared projects (`task_detail_screen.dart:146`).
