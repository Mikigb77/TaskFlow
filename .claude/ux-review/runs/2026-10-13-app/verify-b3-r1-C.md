## UX verify — 2026-10-13-app, b3 round 1, area C (P16) — 2026-10-13
**Verdict:** Ship. All six findings in P16 are fixed in code, and ux-tester's tests pass. One small regression (severity 1): after a new note, the list can jump to the top when that note isn't in the current view.
**Evidence level:** code and widget tests. No preview covers Notes: nothing under `App/build/` or `App/artifacts/` shows NotesScreen, so there was no render to read.
**Walked:** Notas → Nueva nota → save → back on the list (newcomer, daily user). Notas in a project → Dictar una nota (newcomer). Search with no results in es, ca and en. Filter dropdown with TalkBack (assistive-technology user). Empty Notas compared with Notas that has notes.
**Numbers:** Notas with notes shows 16 fewer words (the `notesHelp` paragraph, es), down to the search field, the filter and the list. After a save, the new note is at row 1, in view, and highlighted, wherever the list was scrolled. Before, it landed in a random spot.

### Results
- **UX-304 · fixed.** `notes_screen.dart:208-210` sorts by id, newest first. `_add`/`_land`/`_reveal` (`:57-118`) record the newest note id before the editor or sheet opens. When a newer note arrives, they scroll to 0, then reveal the row. The highlight is `primaryContainer` for 1500 ms, then a 600 ms fade to `surface`, which is AppSurface's default. `MediaQuery.disableAnimations` is respected. This is the same treatment as P7 on Calendario (`calendar_screen.dart:161-163, 670-678`). The test `notes_ui_test.dart:285` starts with 12 notes and scrolls down before each of three saves, so it also covers the 12-note device check.
- **UX-313 · fixed.** `_saveTo` (`:43-44`) is the one rule both buttons use. `Dictar una nota` passes `projectId: _saveTo` (`:272-273`). Test: `notes_ui_test.dart:343`.
- **UX-312 · fixed.**
  - No results: `noteNoMatches` (`:216`).
  - Unavailable project: `listUnavailable` (`:189`).
  - Load error: `notesSavedOnDevice` (`:249-250`).
  - Editor title hint: `noteTitleHint` (`task_editor.dart:661-663`).
  - Empty-title error: `noteTitleRequired` (`:668-669`). `noteHint` stays on the body (`:718`).
  - The copy matches the brief in EN, ES and CA (`app_*.arb`).
- **UX-323 · fixed.** The filter is now `DropdownButtonFormField`, labelled `list` (Project / Proyecto / Projecte), so TalkBack reads the label and the value. The 'all' option is `allNotes` (`:177-185`). It doesn't use the global ProjectScopeControl, as the brief asked.
- **UX-337 · fixed.** `notesHelp` shows only when no item is a note (`:131-133, 141-147`). Test: `notes_ui_test.dart:467`.
- **UX-434 · fixed** (device check optional). `text_search.dart:57-58` maps `’` → `'`, and `_plainByCodeUnit` picks it up because it's above 0x80. The query and the text are folded the same way (`:4-26`). The iPhone-to-Android check is the only thing left.

### Regressions
**R1C-1 · Severity 1 · New note jumps the list when it isn't shown**
- Where: `notes_screen.dart:66-80` (`_land`), `:88-94` (`_reveal`).
- The moment: "I scrolled down, added a note, and now I'm at the top — but my note isn't there."
- What happens: `_land` takes the newest note across every note, not just the ones on screen. Two cases:
  - The current search hides the new note.
  - The note saved somewhere else: a view-only project, where `_saveTo` is null, so the dictated note goes to Calendar's project scope (`voice_task_screen.dart:477-480`).
  In both, `_landedId` matches no row, `_reveal` still scrolls to 0, and nothing is highlighted. Before this change the list stayed where it was.
- Why it fails: the jump says "here it is" without showing anything (Norman, gulf of evaluation). Minor, because the snackbar still confirms the save.
- Fix: in `_reveal`, scroll only when `_landedRow.currentContext` exists, so only a note that's in the filtered list moves the list. Nothing else changes.
- Verify: widget test. In a view-only project's Notas, scroll down, save a note with Nueva nota, and the scroll offset doesn't change.

### Notes for P38 (not regressions, nothing to fix in P16)
- With "Todas las notas", `_saveTo` is null. `Nueva nota` then saves to Personal (`task_editor.dart:159`), but `Dictar una nota` falls back to Calendar's project scope (`voice_task_screen.dart:477-480`). The behaviour is the same as before this change. When P38 merges the two buttons into `Añadir nota`, it should pick one rule for the 'all' case.
- Newest first uses the local id. Editing a note doesn't move it, which matches the brief.

### Memory notes
- Notes now uses the P7 landing pattern: snapshot of the newest id, `ref.listen`, scroll to 0, reveal, `primaryContainer` for 1500 ms with a 600 ms fade. The project filter is a labelled `DropdownButtonFormField` (Proyecto / Todas las notas), not ProjectScopeControl.
- `_saveTo` in `notes_screen.dart` is the shared rule for where a new note goes, kept for P38.
- Search folds `’` to `'`.
