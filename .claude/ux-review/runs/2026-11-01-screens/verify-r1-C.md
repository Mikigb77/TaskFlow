## UX verify — 2026-11-01-screens · round 1 · area C (P316) — 2026-11-01

**Verdict:** UX-2647 fixed. No regressions in the changed files or the flows they touch.

Evidence level: code, current renders (PNG 15:26–15:27, newer than both widget files, 14:59 and 15:08), AUDIT.md (widget-test semantics), and the tester's passing group in the merged main checkout. None of it is a device: what TalkBack actually says, and moving by headings, stays the device check.

### UX-2647 · fixed
- «¿Quién es responsable?»: `App/lib/widgets/task_assignment_picker.dart:148-164`. The ListTile is gone. The title is now `Padding(24, 0, 24, 8)` › `Semantics(header: true)` › `Text(titleMedium)`, the first child of the shrink-wrapped ListView. The drag handle, `isScrollControlled`, the 70% cap (`:136-145`), the rows, the ✓ and the return values are unchanged.
  - Render `tasks/detail.responsible-sheet.es.light.1x.png`: the heading sits at 24 dp, then «Todos», «María · Yo», «Ana» ✓ and «Paul». The CA 2× render shows «Qui és responsable?» whole on two lines.
  - AUDIT: `heading «¿Quién es responsable?»`, then the four buttons in order, with «Ana» [selected].
- «Novedades del proyecto»: `App/lib/widgets/project_preferences.dart:18-76`.
  - The title is `Semantics(container: true, header: true)` in titleMedium. «project.name» sits in its own `Semantics(container: true)` node in bodyMedium/onSurfaceVariant, both inside `Padding(24, 0, 24, 8)` with the Column aligned to the start.
  - The implementer also made the sheet scroll-controlled, with the 70% cap and a shrink-wrapped ListView, as the assignee sheet does. The brief allowed this only if needed; it's harmless and consistent.
  - Renders `sharing/project-sharing.updates-sheet.{es.1x,ca.2x}`: heading, then «Matemáticas», then the three choices; the ✓ on «Solo lo que es para mí». At CA 2× the last choice («Silenciat: sense novetats ni recordatoris») shows whole.
  - AUDIT reading order: `heading «Novedades del proyecto»`, `text «Matemáticas»`, then the three buttons.
- Tests: `App/test/project_scope_control_test.dart`, the group 'P316 · picker headings' (8 tests) covers:
  - header flag, titleMedium, 24 dp inset, not a ListTile;
  - the ✓ only on the chosen row;
  - «Casa» in its own non-header node;
  - the reading order;
  - at ES/CA 2× on 360×740, the heading whole and the last choice whole with no scrolling;
  - the assignee sheet's last person scrolling into view.

  All 8 pass in the merged main checkout. The worktree failure of the reading-order test isn't reproduced on main, and AUDIT's traversal agrees with it.
- Device check still open, from the package: on TaskFlow_Review with TalkBack, both titles are announced as «encabezado» and moving by headings lands on them.

### Regressions — none
Checked:
- **Every way into `showProjectPreferences`.** It is opened from `list_sharing_screen.dart:361`, `task_lists_screen.dart:355` and `reminder_control.dart:196` (the muted reminder line). All three get the same sheet. The only change is that its cap goes from 9/16 to 70%, so it gets taller only when the content needs it.
- **Every way into `TaskAssignmentPicker`.** It is used in the task page, TaskEditor and the capture review editor. Only the title row changed.
- **AUDIT findings for both new states.** The gaps under 8 dp are list rows touching by design. The «Paul» contrast flag is a histogram artefact: the text itself measures 14.46:1. No cut text, no layout errors, no unlabelled controls.
- **The preview descriptions.** They match what the PNGs show.

Nit, not a UX finding: the test file has a double blank line before the P316 group.
