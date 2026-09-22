# Attachment backup and restoration — B19

Originally implemented on `dev`, 22 September 2026, for private files attached to personal tasks. B22 subsequently added shared-list file access and owner quotas; see [sharing validation](SHARING_VALIDATION.md) for the current membership rules.

## Behavior

- New attachments selected in a signed-in task are copied into durable app storage and queued in the same SQLite transaction that saves the task. Transfers run after their parent task syncs. Failed transfers leave the saved task and its file queue intact.
- Guest attachments and older device-only files remain local. Importing guest tasks does not silently upload files. Task details offers an explicit Upload action for those files. The picker/editor explains this before selection.
- Details distinguish local, queued, backed-up, downloadable, missing and removal-pending states. Download/Open/Retry/Remove controls fit small screens and large text; new strings have English/Spanish resources. Opening delegates to an installed file viewer; the initial restoration run did not exercise that viewer. The later PDF handoff check is recorded below.
- SQLite schema 12 stores account-scoped immutable file UUIDs, parent task sync IDs, private/source paths, checksums and pending operations. Attachment transfer never advances the task content version. Removing during upload cannot resurrect a file; a failed removal stays visible for retry. Local cleanup never removes an original user/picker file and preserves copies referenced by another task.
- The API enforces a 6 MiB file limit, 64 MiB / 1,000 active files per account and 20 files per task. Downloads require authentication, reject deleted objects, and use attachment/no-store/nosniff headers. Size and SHA-256 must match before a downloaded file is saved atomically.
- Server migration 0008 stores file metadata and deletion tombstones. Bytes live in the private `taskflow_media` Docker volume. UUID/name/task/bytes retries are idempotent, concurrent quotas are serialized, and deleting a task revokes its files. There is no public media route. Container persistence does not imply off-host backups.
- TaskFlow export keeps attachment filenames, including distinct files with the same name, and continues to disclose that file bytes are omitted. It exports no private paths or authenticated URLs; imported tasks are independent copies.

## Evidence

- All 62 backend tests passed: authenticated byte-exact downloads, cross-account denial, immutability, bounded uploads, quota/deletion behavior, rollback cleanup, missing-storage repair, and real PostgreSQL concurrent quota/retry races. Migration checks passed; 0008 is deployed locally.
- A 122-test Flutter suite passed after the transfer/store/editor integration. Later focused runs passed the two new attachment UI checks, same-name export regression and updated store/archive tests. They cover restart/response loss, duplicate retry identity, SHA corruption, removal during upload, failed removal recovery, original-file preservation, account isolation, Unicode filename normalization and guest import behavior.
- Attachment widget controls passed at 320 × 568 with 2× text in English/Spanish and both themes. Cancellation leaves the file unchanged; Open uses the retained path. Static analysis is clean. The regular Android x64 debug build passed and was restored with `adb install -r`, preserving existing app data.
- `integration_test/attachment_flow_test.dart` passed using the real Android document picker, SQLite, JWT client, Docker HTTP/PostgreSQL and private volume. It selected an 87-byte UTF-8 fixture from Downloads, saved/uploaded it, and confirmed the upload status.
- The API container was forcibly recreated without removing volumes. The stored fixture still matched its recorded SHA-256. The test then removed only its phone task/file cache, pulled remote metadata into a fresh cache, pressed Download in task details and verified byte-identical contents. Removal from that screen produced HTTP 404 on download and removed the private cached copy.
- Light/dark restored-attachment screenshots were inspected. Logs and screenshots live under ignored `App/artifacts`; backend test logs are under `Backend/artifacts`. The synthetic test accounts, server blob, scoped phone rows, picker cache file and Downloads fixture were cleaned up. No existing account/task data was cleared.
- Website attachment/offline FAQ copy was updated and Next.js type generation/TypeScript checks passed.

No physical-phone, iOS, internet deployment or storage-disaster recovery claim is made. A killed process during a filesystem write can leave an inaccessible private orphan; it never makes the file public. Existing AI provider availability, real speech and reminder-delivery gaps remain listed separately in IMPLEMENTATION_STATUS.md.

## Additional external viewer evidence

A later Android check opened a synthetic local PDF through the actual attachment Open control and inspected the rendered document in the installed PDF viewer. See [handoff validation](HANDOFF_VALIDATION.md). That confirms this viewer/file-type combination; other types and physical devices remain separate checks.
