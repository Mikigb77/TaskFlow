## UX verify — run 2026-10-18-commands, b3 round 1, area C (P141, P142) — 2026-10-19

**Verdict:** Ship. All six findings are fixed as briefed. One small regression (R1C-1) and one polish point (R1C-2) come with the new rename path.

**Evidence:** code (`git diff HEAD`), ux-tester's passing widget tests, and current renders (03:34–03:37; no file under App/lib changed after them): `commands/cards.project-new.{es,ca}.light.2x.png` and `tasks/detail.created-by.{es,ca}.light.2x.png`. No render shows the rename dialog, the empty state for one person, or a project page opened from a search, so those rest on code and tests.

### Results

| ID | Result | Evidence |
|---|---|---|
| UX-1104 | fixed | `task_list_picker.dart:241-247`: the chip uses `commandNewProjectChip`; `asRow` and the sheet row keep `commandNewProject`. Renders: «Física (nuevo) ▾» (es 2×) and «Física (nou) ▾» (ca 2×), shown in full; the card still reads «Nuevo proyecto: Física». TalkBack reads «Física (nuevo)» (AUDIT). Still needs a phone with the real model at 1.3× and 2×. |
| UX-1105 | fixed | `capture_review_editor.dart:463-474` now uses `commandMemberNotInNew`, but only for a project the dictation creates. The ES, EN and CA copy matches the brief exactly. `shareProject` is «Compartir» / “Share” / «Comparteix», so the line points at the right button. `commandMemberNotIn` is kept for existing projects. Tested. |
| UX-1106 | fixed | `task_list_picker.dart:40,54-64,87-88`: while a dictated project is shown, the plain «Nuevo proyecto» row is hidden. A tap on the dictated row returns `+rename` and opens `_ProjectNameDialog` (`:113-168`): titled `newList`, field `listName`, name prefilled and selected, 80-character limit, «Cancelar», and «Usar este nombre», which is off while the name is blank. `voice_task_screen.dart:2419-2446` renames the card and every pending task that goes there, matched by folded name, and writes it to the capture. Nothing is created before the confirming tap. Tested. |
| UX-1103 | fixed | `task_assignment_picker.dart:71,102-119`: the ▾ shows only when `changeable`, after a flexible, ellipsized label capped at 230 dp, as on the project chip. Renders `detail.created-by` es and ca 2×: «👤 Ana ▾», inside the chip. Tested for no ▾ in a view-only project, and for 2× on 320 dp. |
| UX-1107 | fixed | `capture_command_cards.dart:600-604` passes `command.personId`. `home_screen.dart:73-86`: the account itself opens on «Para mí» (on a shared project); anyone else is set as `_person`. `_personShown` drops anyone without a chip, so the page opens on «Todas». Tested for all three. |
| UX-1109 | fixed | `home_screen.dart:584-602`: when no word, label or root filter is on and the person has a chip, the empty state reads `personNothingOpen` / `personNothingOpenHelp`; otherwise `noMatches` / `differentFilter` stay. «Para mí» keeps `noMatches`, because `_personChip` is null there. The help names the chip as the app labels it: `forTeam` is Todas / All / Totes. Tested in es, ca and en. |

### Regressions

**R1C-1 · Severity 2 · A rename to an existing project's name still says "(new)"**
- Where: `App/lib/widgets/task_list_picker.dart:99-103` (rename accepted as typed) and `App/lib/screens/voice_task_screen.dart:2419-2446`. At save, `voice_task_screen.dart:2921-2938` reuses an editable project with the same folded name.
- The moment: "I fixed it to «Física», which I already have. It still says «Física (nuevo)». Will I end up with two?"
- What happens:
  - Typing the name of an editable project you already have keeps «Nuevo proyecto: Física» on the card and «Física (nuevo)» on the chip.
  - The confirming tap then files the task into the existing project. The result said one thing and did another.
  - If the name matches a project you can only view, the save creates a second «Física».
- Why it fails: people need to see what the system will do (Budiu & Laubheimer 2018), and the screen must match what happens (Nielsen 1994, visibility of system status).
- Fix: on «Usar este nombre», if the folded name matches an editable project (`editableProjects`), treat it as tapping that project's row. Move the result's tasks for that name there (`taskWithProject`, as `_changeCommand`'s `picked` branch does) and mark the project card as that existing project, so the chip shows the plain «Física». No new copy.
- Verify: widget test with an existing project «Física»; rename a dictated «Fisica 2» to «física»; the chip reads «Física» without «(nuevo)», and saving creates no project.
- Evidence: verified in code.

**R1C-2 · Severity 1 · Nothing shows that the dictated row can be renamed**
- Where: `App/lib/widgets/task_list_picker.dart:54-64`.
- The moment: "That's the right project, it's just spelled wrong. How do I change the name?"
- What happens:
  - The row is already marked selected and has no edit cue, so nobody would expect a tap to open a name field.
  - The only way to the fix is tapping a row that looks already chosen.
- Why it fails: there is no visible signifier for the action (Norman 2013).
- Fix: add a trailing `Icons.edit_outlined`, size 20, to that row. TalkBack needs a name for it; reuse an existing key if one fits, otherwise "needs new copy" (no rename key exists; `editList` reads «Editar proyecto»). No other change.
- Verify: render the project sheet with a dictated project; the row shows the pencil.
- Evidence: verified in code; no render shows the sheet.

### Checked, no problem
- Before the change, a tap on the dictated row closed the sheet. It now opens a dialog, and «Cancelar» leaves everything as it was.
- With `onRename` null (a card that's disabled while saving), the row still just closes the sheet.
- The person chip's 230 dp cap matches the project chip. View-only chips keep no ▾.
- `copyWith(name:)` in `capture_command.dart` changes nothing for existing callers, which don't pass `name`.
