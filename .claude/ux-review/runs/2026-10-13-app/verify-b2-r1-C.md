# Verify — 2026-10-13-app, b2 round 1, area C (P12)

Scope: `git diff HEAD` of task_list_picker.dart, task_assignment_picker.dart, task_lists_screen.dart, home_screen.dart, the three ARBs; callers task_detail_screen.dart:172-192 and task_editor.dart:567-579 read for context. No current render shows the Tasks tab, the project sheet or the doubt state (build/review-direct-light.png shows only the capture review's `Bandeja personal` row with its chevron), so the judgements rest on code plus a Manrope width model.

## Findings

**UX-302 · fixed** (view-filter part excluded by the brief as an owner question)
- Dialog: `task_list_picker.dart:88-111` asks only when `lockShared` (existing task: detail `task_detail_screen.dart:175`, editor `task_editor.dart:570-571`), the chosen project is shared and the current one isn't. `{name}` = group name, else project name. Cancel returns before `onChanged`, so nothing moves.
- Copy matches the brief exactly in EN/ES/CA (`shareTaskConfirm`, `shareTask`, `cancel`).
- Locked chip: `onPressed` is no longer null (`:122-126`), so the chip is drawn enabled in normal contrast; a tap shows `sharedTaskStays` through `showFeedback`. The editor is its own Scaffold (`task_editor.dart:518`), so the snackbar is visible there too.
- Audience line kept: `task_assignment_picker.dart:155-167` (`if (!compact || shared)`).

**UX-308 · fixed** (the failing 2x/320 test measures a placeholder font — fix the test)
- `home_screen.dart:93-98`: the folder icon is now `TextButton(Text(l10n.lists))` = Projects / Proyectos / Projectes, in the same place.
- Picker: when there are no editable projects, a `Nuevo proyecto` row (`task_list_picker.dart:73-78`) opens the shared `editTaskList` dialog (`task_lists_screen.dart:335`); the project gets a client-side UUID (`task_list_info.dart:65`), and `onChanged(project)` puts the task in it. `createListHelp` is gone.
- Sheet title is `l10n.list` (Project / Proyecto / Projecte), with no subtitle; `moveToList`, `moveToListHelp` removed from all three ARBs.
- The 2x/320 overflow: `test/home_screen_test.dart` doesn't load Manrope, so text is drawn in the flutter_test font (every glyph 1 em wide): "Proyectos" at 28 px is about 252 dp there. With the app's real font (Manrope w700, 28 px, modelled with Pillow): Proyectos 143 dp, Projectes 136, Projects 119. Then the Row is 143 + 8 (M3 TextButton padding at 2x) + 48 (IconButton) ≈ 199 dp, within the 272 dp available (320 − 2×24). The heading (`Tus tareas` 312 dp at 2x) wraps inside the Wrap's 272 dp limit. So on a phone, nothing overflows and the button can be tapped.
- To do: load Manrope and MaterialIcons with `FontLoader` in home_screen_test.dart, as `test/calendar_feedback_test.dart:43-49` does, and re-run. No app change is needed for this finding.
- Side effect, not a regression: at 1.3× on a 390 dp phone, heading plus buttons come to about 365 dp (more than 342), so `Proyectos ✓` drops to a second, left-aligned line under `Tus tareas`. This is about 48 dp of extra header height. In Catalan it happens at 1.0× too. It's the cost of the label; it's acceptable.

**UX-324 · fixed**
- `task_list_picker.dart:151-156`: the chip label ends in `Icons.arrow_drop_down_rounded` when it can be changed, and not when locked. The row form keeps its chevron.
- Shared rows' subtitle is the group name (`:64-68`); `sharedListVisibility` removed.
- It leaves the gap R1C-1 for shared projects that have no group.

**UX-325 · fixed**
- `task_assignment_picker.dart:168-185`: the red `assignmentNeedsReview` line and `assignmentConfirm` button are gone. Now `Has mencionado: …` (bodySmall), then a Wrap: `¿Es correcto?` in the default text colour, plus a `Sí` TextButton (48 dp minimum from the theme) that calls `onReviewed`. The chips stay the way to change it.
- Copy matches in EN/ES/CA. Pre-existing and unchanged: `Sí` is disabled with no reason when the choice is invalid.

## Regressions

**R1C-1 · S2 · A project shared without a group looks private in the sheet**
- Where: `App/lib/widgets/task_list_picker.dart:64-68`.
- What happens: `subtitle: list.shared ? (list.groupName == null ? null : …)`. Projects shared person-by-person (`ListSharingScreen`, reached when `groupId == null`, `task_lists_screen.dart:304-306`) have no group name. They now show no subtitle and look exactly like personal projects.
- Before: they carried the visibility warning.
- Who it hurts: on the capture review and in new-task creation (`lockShared` false) there's no dialog, so a user can pick one believing it's private. The audience line appears only after the choice.
- Fix: for a shared project with no group, show the people's names as the subtitle (`list.people` names joined with `, `), or else EN `Shared` / ES `Compartido` / CA `Compartit`. Or add a trailing `Icons.group_outlined` to every shared row, so shared is visible without reading.

## Not regressions (checked)
- The reminder-ask card removed from home_screen.dart belongs to another package.
- The `_edit` → `editTaskList` extraction keeps the same dialog, validation, group dropdown and error text.
- Moving to `Bandeja personal` still works: `''` resolves to null, which leads to `onChanged(null)`.
