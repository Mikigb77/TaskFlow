## UX verify — P329 (area C) — run 2026-11-04-screens, round 1 — 2026-11-04
**Verdict:** Ship. UX-2905 is fixed: notes saved by the released schema-22 build that a `meetings` row still links get their D1 mark at upgrade and keep «Crear tarea». No regressions.
**Evidence level:** code and unit tests (the tester's run, against the app's real `TaskDatabase()` open path through sqflite ffi). No UI changed, so no render applies. Device check still owed.

### UX-2905 · fixed
- `App/lib/services/task_database.dart:18`: `schemaVersion` goes from 22 to 23. `:277-294` adds a step, `if (oldVersion < 23 && newVersion >= 23)`. It selects `DISTINCT m.owner_key, m.note_id FROM meetings m JOIN tasks t ON t.id = m.note_id AND t.owner_key = m.owner_key WHERE m.note_id IS NOT NULL` and calls `MeetingNoteMarks.add(db, owner, noteId)` for each row. The comment gives the reason: D1, UX-2905, never guess from the text.
- It writes the same mark that saving does. `meeting_store.dart:943` calls `MeetingNoteMarks.add(tx, meeting.ownerKey, noteId)` with the same owner key. `add` (`meeting_note.dart:174-188`) merges with the ids already there, so existing marks are kept. The id set dedupes a note that is linked twice.
- The step can run at this point. `app_preferences` comes from `createReminderTables` and `meetings` from the `< 22` block, both earlier in `upgrade`. An upgrade from older than 22 runs the step on an empty `meetings` table. `onCreate` (`:61-93`) runs at version 23 and adds no marks.
- What the page shows: `noteMakesTask` (`widgets/note_task.dart:24-28`) needs `isNote`, the mark, and an open step. It is the rule `task_detail_screen.dart:292` uses for «Crear tarea».
- Acceptance 1 is met. The tester's test builds a schema-22 file and opens it through the real `TaskDatabase()` (onUpgrade 22 to 23). The results: `user_version` is 23; the marks are exactly {linked}; the other account gets none; `noteMakesTask` is true for the linked note and false for the unlinked one.
- Acceptance 2 is met. On `upgrade(22, 23)`, a row whose note is gone adds no mark, a mark already there is kept, and a note linked twice gets one mark. A fresh install through `onCreate` is at 23 with no marks.
- Accepted by design: notes whose meeting row was already cleaned up (`markSeen`/`clean`) stay without the mark, as the finding says. The owner needs to be told about this loss. That is a release note, not a defect.

### Regressions
None. Checked:
- The only other change outside the new tests is one assertion in `meeting_core_test.dart`, now `schemaVersion >= 22`. No other test pins version 22.
- A soft-deleted note that a meeting row still links also gets the mark. That is harmless: the page never shows it, and if Deshacer brings it back, it keeps «Crear tarea», which matches D1's rule that undo keeps the mark.
- The step only reads `meetings` and `tasks` and writes `app_preferences`. No other table is touched, and neither is `meeting_store.dart` or the mark format.

### Device checks owed
- On the owner's phone with the released staging build: install this build. A meeting note saved before it, whose meeting row still exists and which has open steps, offers «Crear tarea». Older notes, whose row was already cleaned up, don't.

### Memory notes
- Schema 23 (P329): at upgrade, the marks are filled in for notes that a `meetings.note_id` still links. Notes whose meeting row is gone stay unmarked, by design.

---

## Re-dispatched verify step — 2026-11-04 (later)
**Verdict unchanged:** Ship. UX-2905 fixed; no regressions.
- The workflow re-ran this step after P329 was already merged (merges.jsonl line 2, 2026-11-04T22:26:37, worktree `wf_a74c231d-d1a-4` removed). `git worktree list` shows only the main checkout and `wf_a74c231d-d1a-5`, so I read the merged code in the main checkout instead, read-only.
- The main checkout holds exactly what the first pass verified: `App/lib/services/task_database.dart:18` (`schemaVersion = 23`) and `:277-294` (the `< 23` step that marks the notes a `meetings` row still links, joined on the same `owner_key`). `App/test/meeting_core_test.dart:1232-1314` has the group 'P329 · meeting notes saved before the marks (UX-2905)' with its three tests. Both files are uncommitted merged work, waiting for the round commit.
- The tester's step ran nothing this time, so its "n/a" adds no new evidence. The first pass's test run is still the evidence, and the run's final check reruns the suite in the main checkout. The "infrastructure" failure (missing worktree) is the workflow's re-dispatch, not a defect in P329.
- The task's run paths had the repo root written twice (`/home/claude/TaskFlow//home/claude/TaskFlow/...`). I used `/home/claude/TaskFlow/.claude/ux-review/runs/2026-11-04-screens`.
- Device check still owed, as listed above.
