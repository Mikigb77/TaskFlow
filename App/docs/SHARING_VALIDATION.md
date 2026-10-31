# Shared household lists (B22)

Implemented for a household shopping/chores workflow. Owners manage list details, invitations, membership and deletion; editors change tasks and files; viewers read. Calendar remains the landing screen. This is functional validation, not evidence that people prefer sharing in TaskFlow over their existing tools.

## Access and data behavior

- Invitations bind to an account email, expire after seven days and require the owner's separately shared, single-display code. Only a server-secret HMAC is stored. Accounts currently do not verify email ownership, so matching an email alone never grants membership. Invitations appear inside the app; TaskFlow sends no invitation email. Issuing a replacement invalidates the earlier invitation/code.
- The first invitation marks a list shared. Creator ownership does not bypass later membership removal. Editors can create, update and remove group tasks/files; viewers cannot. Shared tasks stay in the group; export/import creates an explicit personal copy.
- List/task transactions and optimistic versions protect edits. An offline conflict in a group becomes a personal copy; a viewer downgrade likewise preserves unsent edits as personal content. Removing/leaving a group instead removes its cached content on the next successful access refresh, as disclosed before joining/leaving.
- Complete, unpaginated access snapshots precede uploads. Failed or partial responses never imply revocation; generations reject stale responses. Late task/file responses cannot recreate data after access removal. Download cleanup removes only app-owned, unreferenced files, never the original picker source.
- File access follows current membership. The list owner pays the group's storage quota even for a former member's uploads. Concurrent uploads and moving file-bearing tasks into a list cannot bypass that quota. Deleting a list tombstones its tasks and removes server file blobs.
- Revocation cannot erase prior exports, original source files or an offline device remotely. Owner/role changes become enforceable locally once the device refreshes access. Reminders remain each member's device/account preference.

SQLite migration 14 preserves old lists as owner/private; Django migrations 0010 and 0011 add membership and invitation codes. Sharing copy is currently English; English/Spanish core flows remain available.

## Verification (22 September 2026)

- All **159 Flutter tests pass**; analysis reports no issues. New tests cover viewer restrictions, queued edit recovery, account-scoped cache/file removal, failed/partial/stale access snapshots, late task pages, shared conflicts, migration from schema 13, and 320×568 layouts at 2× text in both themes.
- All **74 backend tests pass**, with the three PostgreSQL-only concurrency checks skipped on SQLite and then **all three passing on PostgreSQL**, including shared-owner quota contention. Backend coverage includes invitation code/email isolation, expiry/decline/revocation/replay, every viewer write surface, creator removal, file access, version conflicts, leave, role changes, quota transfer and list deletion/file cleanup.
- `Backend/scripts/sharing_smoke_test.py` uses two authenticated HTTP clients against local PostgreSQL. Simultaneous writes with one version produce 200/409; removal racing an edit revokes subsequent task/history/file access. Synthetic accounts are removed by the script.
- `integration_test/sharing_flow_test.dart` passes on Android with real SQLite, JWT, HTTP/PostgreSQL and file bytes: owner invitation/code, recipient acceptance, shared checklist/file restoration, conflict preservation, viewer UI, membership removal, cached-file cleanup and subsequent download denial. It substitutes secure storage only, not the API. Light/dark screenshots were inspected. An initial screenshot-driver hang was corrected; two later runs passed.
- Synthetic accounts and scoped device fixtures were cleaned up. Existing emulator data was preserved with `--keep-app-running` and `adb install -r`. The backend image was rebuilt and migrations deployed locally.

Logs and screenshots live in ignored `App/artifacts` and `Backend/artifacts`. No actual invitation message was sent. Human usability, physical-device delivery and real speech remain separate outstanding checks in `IMPLEMENTATION_STATUS.md`.
