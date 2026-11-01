## UX verify — 2026-10-28-app · b1 round 2 · area B (P296) — 2026-11-01
**Verdict:** Ship. UX-2032's remaining gap is closed: a reader's reminder choice is sent and kept even when the owner changed the task before this phone's sync. No regressions in the changed files.
**Evidence level:** code read plus the tester's unit tests (sharing_sync_test.dart, P296 group, all pass). No UI, copy or ARB change, so no preview is involved. The emulator check (two accounts, reader offline) was not run.

### UX-2032 · fixed (test level; device check pending)
- **Marker:** `App/lib/services/task_database.dart:76` (create) and `:248-255` (upgrade at schema 20, `:17`) add `own_reminders_pending`, persisted, default 0.
- **Set only for a reminders-only change:** `updateOwnReminders`, `:607-611`. The mark is set when the row wasn't pending, or was already marked. Local rows never get it.
- **Every other write clears it:**
  - `updateTask` `:565`;
  - delete `:647`, and the capture undo's delete `capture_store.dart:360`;
  - `restoreTask` `:668`;
  - `recoverReadOnlyDraft` `:726`;
  - `acknowledge` `:746-756` and `acceptKeepingReminders` `:779-787`, both under the revision rule;
  - `_remoteValues` `:806` (pull, `preserveConflict`);
  - the copy `preserveConflict` makes, `:899`;
  - the notification's Completar, `reminder_engine.dart:881`.

  Every other path that sets `sync_pending = 1` inserts a new row (default 0) or works on `local` rows, which can't be marked. Attachment-path writes don't make a row pending.
- **The sync:** in `App/lib/repositories/cloud_task_repository.dart:212-226`, the GET and the «equal → acknowledge» check stay first. A marked row then goes to `_sendReminders` whatever else differs. An unmarked row keeps today's order. The PUT (`:131-140`) carries only the server's fields and version plus the reader's three reminder fields.
- **The answer becomes the row:** on 200 (`:142`), `acceptKeepingReminders` takes the returned task as the row, so the owner's new title comes in under the new version. Before, `acknowledge` would have left the old title. On 409, `current` is used, as before.
- **The tester's proof (`App/test/sharing_sync_test.dart:411-697`) covers every acceptance line:**
  - the owner renames before the GET: one task, «Ensayo general», 60 min, no «(copia local)» in es/ca/en, `syncError` null, nothing pending, the server's version;
  - the PUT body matches the server's field by field, except the three reminder fields;
  - a 409 with a newer `current`;
  - a restart on the same file;
  - the editor's offline title edit, then made «lector»: still a copy and the notice;
  - a schema-19 database: it upgrades, and its unmarked row behaves as before.

  The P271 tests still pass. In `reminder_plans_test.dart:267` only the schema-number expectation changed, 19 → 20, which is expected.
- **What the person sees:**
  - The reader's task page refreshes after the sync: `task_provider.dart:55-63` reads again, then calls `TaskReminders.sync`. They see the owner's new title with their own «1 hora antes».
  - No personal copy and no red read-only notice appear, so the reader has no duplicate to wonder about.
  - The reminder that rings carries the current title.
- **Still for the main session:** the emulator lane in P296's `deviceChecks`:
  - the reader offline, the owner renames, the reader sets «1 hora antes», then goes online;
  - expected: no copy, no notice, the new title, and the reminder rings only on the reader's phone with «Posponer 10 min».

### Regressions
None found in the changed files or the flows they touch: the reader's sync, an editor's sync, delete and undo, restore, completing from a notification, the pull, and conflict copies.

Notes, not regressions:
- A phone that ran round 1's build and still holds an unsent reader reminder at schema 19 upgrades with that row unmarked. If the owner changed the task first, that one row still becomes a copy (the test at `sharing_sync_test.dart:681`). Round 1 never shipped (it is on `ux-in-progress`), so only test installs could hold such a row.
- If the owner deleted the task before the reader's sync, a marked row now follows the server's deletion: the task leaves the reader's phone with no copy. Before, the reader got a «(copia local)» copy. This is D9's intent: the reader's only change was their reminders.

### Memory notes
- The sync's D9 path is now driven by a persisted per-row marker, `tasks.own_reminders_pending` (schema 20). Only `updateOwnReminders` sets it, and every other pending write, `acknowledge` and `acceptKeepingReminders` clear it. A reader's send, on 200 or 409, takes the server's task as the row and keeps the reader's reminder fields (`acceptKeepingReminders`).
- Recurring problem type confirmed: a sync gate that compares the phone's row with the server's "now" fails whenever the other side changed first. Look for a persisted intent marker instead.
