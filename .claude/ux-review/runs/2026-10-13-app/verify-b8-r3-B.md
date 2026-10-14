## UX verify — 2026-10-13-app, b8 round 3, area B — 2026-10-14

**Scope:** P112 (UX-622). Changed file: `App/lib/widgets/task_editor.dart`. Evidence: code plus ux-tester's widget tests. No preview renders the TaskEditor (the renders in `App/build/` cover calendar, review and capture), so no render applies.

### UX-622 · fixed (code + widget tests; the save-and-reopen check still needs a phone)
- `App/lib/widgets/task_editor.dart:551-560`: `task-more-details` onPressed reads `final expand = !_detailsExpanded;` first. Only when collapsing does it run `FocusScope.of(context).unfocus()`, `await Future<void>.microtask(() {})` and `if (!mounted) return;`, then `setState(() => _detailsExpanded = expand)`. The one-line comment points at `_save`. Expanding still toggles at once, so the keyboard stays open when the user taps Más detalles while typing the title.
- Commit path: unfocus → `_addLeft` (`checklist_editor.dart:53-55`) → `_addStep(next: false)` clears the field and calls `onChanged`, which sets `_checklist` synchronously. After the microtask `_checklist` is non-empty, so the collapsed `if (_checklist.isNotEmpty) ChecklistEditor(key: _steps, …)` (`task_editor.dart:593-600`) builds and shows `Coat`.
- The GlobalKey `_steps` and its comment are unchanged (`:39-41`). Both editors still pass `key: _steps` (`:595`, `:673`).
- Using `= expand` rather than `= !_detailsExpanded` after the await makes two fast taps land on "collapsed" twice, so the form doesn't flip back.
- Tests (`App/test/task_editor_form_test.dart:464-590`; Spanish, 1×, 360×740, a task with no steps) all pass: one `Coat` with an empty field after Menos detalles; still one `Coat` after Más detalles and a later unfocus; one `Coat` and a collapsed form after two raw taps before a frame. The tester's change to acceptance 3 is sound: with a pump between taps, the button moves, so a second tap can't reach Menos detalles. The raw-pointer version reproduces the race the brief guards against. The existing Pasaporte test (:389) still passes.
- Device check not done: on a phone, check that the step is still there after save and reopen.

### Regressions
None found in the toggle or the flows it touches: steps in the short form and full form, notes, Save, Back.
- Not reported: collapsing while typing in the title or notes now closes the keyboard. Collapsing reshapes the form, so this is acceptable, and `_save` does the same.
- Not reported: when the checklist already holds 50 steps, typed text is still dropped on collapse. This edge case predates the change (`_addStep` keeps the text in a field that is then disposed).
- Already known and out of scope: removing the last step through ⋮ in the short form hides the section along with any typed text. The brief lists it as pre-existing.
