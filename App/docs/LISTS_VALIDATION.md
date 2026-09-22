Personal lists and labels — B15
===============================

Tasks → Lists creates personal lists with a name and color. Lists can be renamed, archived and restored. Archive affects organization; tasks remain in Calendar/Tasks, and their reminders continue. Capturing from a list starts a task in that list. Manual editing, AI review and task details offer a list picker. Task rows show their list, while Tasks also offers No list and label filtering. Inbox retains its existing meaning: tasks without a scheduled date. Optional comma-separated labels are normalized and limited to ten labels of up to 32 characters each.

SQLite schema 9 and Django migration 0005 add account-scoped list metadata and task associations. Lists upload before tasks, and task movement retains the task's sync UUID, schedule, reminders, checklist and notes. List version conflicts retain both versions until the user chooses in Lists; task conflicts retain the existing offline-copy behavior. Guest import copies only referenced list metadata into the account and retains a stable import mapping. Guest lists remain available for unfinished captures or later local tasks. Server list access and task assignment require ownership; local writes also reject references to another account's list.

Verification, 22 September 2026:

- All 87 Flutter tests pass and static analysis is clean. New storage tests exercise offline creation, upload ordering, lost responses, edits during upload, both conflict choices, movement/restoration, guest import mappings and account isolation. The widget flow creates/renames a list, captures a task with labels into it, then archives/restores the list; small screens and 2× text fit both themes.
- All 48 rebuilt Docker backend tests pass; migration consistency passes. The API checks private list access, foreign-list rejection, version conflicts, archive behavior, task movement, bounds and preservation when older clients omit new fields.
- The extended `integration_test/checklist_flow_test.dart` passes on Android with real SQLite/HTTP/PostgreSQL. It saves a retained draft into Work, completes one recurring checklist step, moves the task to Personal, archives that list, and clears only the synthetic account's task/list cache before restoring from the server. List/label identity and occurrence progress survive. Light/dark list screenshots were inspected. The exact fixture account and its local task/list rows were removed; the user's persistent session was never replaced.

Logs: ignored `App/artifacts/lists-all-tests.log`, `lists-analyze.log`, `lists-android-integration.log`, and `App/artifacts/design/personal-lists-*.png`. Shared memberships and invitations remain B22; these lists are currently private to their owner.
