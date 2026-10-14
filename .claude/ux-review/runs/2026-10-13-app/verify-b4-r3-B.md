## UX verify — 2026-10-13-app, b4 round 3, area B — 2026-10-14
**Verdict:** Ship. UX-474 is fixed; no regressions in task_editor.dart or the edit flows it touches.
**Scope:** P71 (UX-474). File: `App/lib/widgets/task_editor.dart` (the HEAD diff also carries earlier, already-verified packages such as P38; only `_back`/`_save` changed in this round).
**Evidence level:** code plus the tester's widget tests. No render needed: nothing visible changed (no new widget, no copy).

### UX-474 · fixed
- `task_editor.dart:275-280`: `_save` runs `validate()` first, then `DeepCollectionEquality().equals(_edited().toMap(), _unchanged)` → `Navigator.pop` and return. This sits before `unfocus`, the series dialog (`:283`), `_saving = true` (`:303`), `updateTask` (`:310`), the `Cambios guardados · Deshacer` feedback (`:313`) and `askAboutRemindersAfterSave` (`:332`).
- `:268-273`: `_back` is now just `if (_saving) return; await _save();`, and its doc comment says Back and Save behave the same. The comparison appears once in the file (grep: `:277` only; `_unchanged` set once at `:145` from `_edited()`, so trims and note normalization are the same on both sides).
- The PopScope wiring is unchanged (`:424-426`).
- Tests (`App/test/task_detail_test.dart:487-542`): an untouched form plus Guardar cambios closes to the detail screen, with no SnackBar, no Deshacer and `updates == 0`. A title typed and then put back counts as unchanged. With the title emptied, the form stays, shows `titleRequiredField`, shows no SnackBar and writes nothing. The UX-211/UX-473 tests pass without edits.
- Walkthrough (newcomer): opens Editar, looks, taps the big Guardar cambios → back on the task, nothing claims a change. Same as Back. The keyboard's Done on the title (`:483`, `onFieldSubmitted: _save`) behaves the same way, which is consistent.

### Regressions
None. I checked:
- Validation order: an emptied title still blocks both Back and Save (D12).
- The series dialog no longer shows for an untouched recurring task, which is correct: nothing would change.
- When nothing changed, no reminder-ask sheet shows after closing. That's correct, because nothing was saved.
- Save is disabled while `_saving` or `_pickingFile` (`:841`), as before.
