# Verify — b3 round 2, area C — 2026-10-13

Scope: P62 (UX-459), `App/lib/screens/notes_screen.dart`. Evidence: code (`git diff HEAD`) plus ux-tester's widget tests. No Notes preview render exists in `App/build/`, and this change has no visible layout, so no render was checked.

## Results

- **UX-459 · fixed.**
  - `_shown(Task)` (`notes_screen.dart:85-91`) is now the single list filter (`isNote`, `_listId`, `matchesSearch`). `build` uses it (`:210`), so the list and the landing can't disagree.
  - `_land` (`:66-82`): after finding the newest note it clears `_newerThan` (`:70`), looks the note up (`:72`) and returns `true` early when `!_shown(note)` (`:73`). It never sets `_landedId` or `_highlight`, and it doesn't schedule `_reveal`, so the scroll stays put. `firstWhere` can't throw: `newest` comes from the same list's notes and is greater than 0.
  - The decision rests on data, not on `_landedRow.currentContext`, as the brief asked. The normal landing, with the user scrolled down, is untouched (`:74-81`).
  - The listener (`:134-137`) still clears a settling landing. Because `_land` returns `true` for a note that isn't shown, `_newerThan` is reset and no later reload can land on it.
  - Tests: `notes_ui_test.dart:381` (view-only project, `Nueva nota` saves to Personal, offset unchanged, no `primaryContainer` surface) and `:409` (search hides the new note) pass. The existing UX-304 test at `:286` still passes.
  - Brief's don't-touch list respected: sort (`:211-212`), highlight timing, `_reveal`, `_saveTo`, both buttons and the dropdown are unchanged apart from the extraction.

## Regressions

None. The change only removes behaviour (a scroll and a highlight) in a case where they pointed at nothing.

## Note for P38 (not a regression, not new to this change)

On Notas filtered to a view-only project, `Nueva nota` saves to Personal and confirms with `Nota guardada` / `Note saved` (`task_editor.dart:416`), which doesn't say where the note went. Before P62 the jump to the top was a false signal. Now there is no signal, which is the honest state. The newcomer may still ask "where did it go?". The button merge in P38 (`Añadir nota`) together with UX-314 (create buttons on view-only projects) is the place to decide this: either hide creating in a view-only scope, or name the destination in the snackbar (`Nota guardada en Personal` / `Note saved to Personal`).
