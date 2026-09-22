# Export and import

B17 adds Settings → Export & import. TaskFlow JSON version 1 preserves task notes, dates/times, priorities, reminder choices, completion dates, checklists and their progress, labels, lists (including empty/archived lists), recurrence intervals/weekdays and individual date changes. Exports contain only the active account's task/list data. Attachment basenames are included so their absence is visible; file bytes, private device paths, account credentials, unfinished captures and device preferences are excluded.

B23 extends this to version 2 with explicit task/note types. New exports use version 2 so older clients reject unsupported standalone notes instead of importing them as tasks. The current importer still accepts version 1 task archives. Shared-list exports become personal copies and do not grant membership.

The preview shows invalid rows, per-task warnings, previously imported records and selectable valid tasks before writing. Its controls and structured diagnostics support English and Spanish; switching language preserves selection and original data. Selecting a malformed replacement file clears the previous preview, while cancelling the picker preserves it. Import creates new personal copies, including the file's lists. It does not merge with or overwrite existing tasks. List identifiers are remapped consistently. SQLite migration 11 adds account-scoped import receipts; task/list writes and receipts share a transaction. Concurrent retries or reopening the same file on this phone do not duplicate its imported records. Receipts are local: a changed/new export or a different phone can create another copy. The UI states that limit.

Limits: UTF-8 files up to 32 MiB, 5,000 tasks and 1,000 lists. Unknown schema versions are rejected. Invalid task fields are excluded with a reason rather than coerced into a schedule. JSON attachment contents and unknown task properties are disclosed as unsupported before import.

Todoist project CSV is the first migration format. It supports quoted/multiline content, descriptions and following comments, sections as lists, and ISO dates/offset-bearing times. P1/P2 map to High/Medium; P3/P4 map to Low. Subtasks become independent tasks. Unsupported natural-language/recurring schedules and extra fields are retained as text in notes with warnings; inline labels remain in titles. This deliberately requires reviewing those schedules after migration. The mapping and export limitations were checked against [Todoist's CSV guide](https://www.todoist.com/help/account-and-billing/security/import-or-export-a-project-as-a-csv-file-in-todoist-YC8YvN) on 22 September 2026.

Validation:

- All 103 Flutter tests pass and static analysis is clean.
- Real SQLite tests preserve all supported fields across export, partial import, concurrent retry and account isolation. An injected database failure rolls back tasks, lists and receipts together; retry then succeeds once.
- Invalid dates/offsets, malformed CSV quoting, unknown versions, missing lists and unsupported schedules are covered. The preview can deselect tasks and disables previously imported rows. 320×568 screens at 2× text pass in light and dark modes.
- Android integration uses the actual system Save dialog to write JSON to Downloads, then the actual Open dialog to read that file back. It previews/imports the tasks, verifies duplicate-import protection, syncs the new task/list identities through Docker HTTP/PostgreSQL and restores them from an empty account cache. Recurrence exceptions, completion and checklist history match. Light/dark screenshots were inspected.
- Desktop and iOS document-provider behavior has not been run. Desktop writes the selected path explicitly; mobile document writes are performed by the installed file-picker plugin.

Runtime fixtures use a separate generated account and in-memory test credential storage. Its app rows and test account are removed, the prior reminder owner restored, and the normal app reinstalled without clearing user data. Ignored logs/screenshots live in App/artifacts.
