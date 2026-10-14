## UX verify — 2026-10-13-app, round 2, area B, P70 — 2026-10-14
**Verdict:** Ship. All three findings are fixed in code and covered by passing ux-tester tests. One small side effect is listed below (severity 1).
**Evidence level:** code plus ux-tester's widget and semantics tests. No preview covers the task detail screen or TaskEditor (newest renders in App/build are calendar, review and capture), so there's no render to look at. One device check is still open: TalkBack.

### Results
- **UX-471 (R1B-1) · fixed.** `App/lib/screens/task_detail_screen.dart:272-273` (Duración), `:286-287` (Fecha límite), `:302-303` (Repetir) and `:318-319` (Prioridad, shown only when `priority > 1`) all pass `onTap: canEdit ? edit : null`. That's the same `edit` → `/editTask` the title uses (`:145-146`). For a view-only task `onTap` is null, so `_detail` returns the bare row (`:521-527`). Tests: four "opens the edit form" tests and "view-only Repetir opens nothing", all passing.
- **UX-472 (R1B-2) · fixed (device check open).** `_detail` gained a `tapHint` parameter and wraps the InkWell in `Semantics(button: true, onTapHint: tapHint)` (`:487-488`, `:521-527`). The date and time rows pass `l10n.reschedule` (ES `Cambiar fecha` / CA `Reprograma` / EN `Reschedule`, `:251-252`, `:262-263`). The four other rows pass `editTask`. The title is wrapped in `Semantics(button: canEdit, onTapHint: isNote ? editNote : editTask)` (`:179-191`). No new copy. Semantics test passes. Device check still open: TalkBack reads the date row as a button with "Cambiar fecha".
- **UX-473 (R1B-3) · fixed.** `App/lib/widgets/task_editor.dart:278`: `_save()` no longer takes `undo`. Both Back (`:275`) and the Save button (`:840`) show `changesSaved` with `actionLabel: strings.undo`, and the action restores `before` (`:312-329`). D12's other rules still hold: `_back` closes an unchanged form (`:271-273`), and `validate()` keeps an emptied title on screen with its error (`:279`). The acceptance check says "Guardar", but the button reads `Guardar cambios` (`saveChangesSentence`, `:851`); the test taps that, which is correct. Test passes, and so do the UX-211 tests.

### Regressions
**R2B-1 · Severity 1 · Tapping Save with nothing changed now offers an Undo that does nothing**
- Where: `App/lib/widgets/task_editor.dart:278-331`. The Save button (`:840`) is always enabled.
- The moment: "I didn't change anything, so what is Deshacer going to undo?"
- What happens: Back with no changes just closes (`:271-273`). Save with no changes still writes the task and shows `Cambios guardados · Deshacer`; before P70 it showed `Cambios guardados` alone. Undo then writes the same task again, and nothing visible changes. So Back and Save now behave differently on an untouched form, and the snackbar claims a change that never happened.
- Why: consistency (Nielsen 1994); the feedback should match what actually happened.
- Fix (subtract): move the unchanged-form check from `_back` into `_save`, right after `validate()`. If nothing changed, `Navigator.pop` and stop: no write and no snackbar. `_back` then just calls `_save()`. No new copy.
- Verify: widget test. Open the editor, tap `Guardar cambios` without changing anything. The form closes, no snackbar shows, and `updateTask` isn't called.
- Evidence: verified in code.

### Noted, not regressions
- The detail rows' InkWell has no `borderRadius`, and the ripple stays inside AppSurface's 20 dp padding, so the highlight is a rectangle inside the rounded card. This is the same pattern P10 used for the date rows. Polish only.
