# Standalone notes (B23)

Tasks represent commitments; notes retain reference information. The selected type is explicit, persisted through capture recovery, sync and export/import, and immutable after saving. Calendar remains the first screen; Notes has its own navigation tab, search, list filter and unfinished-capture entry.

## Content and capture behavior

- Notes have a title, body, labels, optional list, checklist and files. They have no task schedule, deadline, duration, recurrence, reminder, priority changes or whole-note completion. Checklist progress remains available independently.
- Typed and on-device-transcribed notes are prepared locally, preserving the original words as one note. Recorded notes request transcription only, without an inferred task-extraction call. Notes processing has separate diagnostic events and must not be counted as task-extraction latency.
- The existing capture journal retains the selected type and input through navigation, restart, failure and retry. Review remains explicit; saving twice creates one item. Failed or incompatible responses retain the recording rather than turning it into tasks.
- Plain selectable body text exposes explicit HTTP(S) links. Non-web schemes, credential-bearing URLs and automatic previews are excluded. Link opening requires a user tap; no background fetch occurs.
- Notes reuse UUID/version conflicts, account-scoped caches, shared-list roles, attachment permissions and restoration. A capability check prevents uploading notes to an older backend as tasks. Shared viewers can read notes but cannot edit, delete or change checklist progress.
- SQLite migration 15 defaults existing content to tasks. Django migration 0012 adds the explicit type and structural database constraint. TaskFlow archive version 2 preserves the type; version 1 task archives remain importable. Older apps reject version 2 instead of silently importing notes as tasks.

## Verification (22 September 2026)

- All **170 Flutter tests pass**; analysis reports no issues. New coverage includes schema migration, immutable type, account/server isolation, interrupted capture, no-network local preparation, audio failure/retry, old-backend rejection, conflicts, lost-response retries, archive compatibility and idempotence, safe links, and task/calendar exclusion.
- Notes creation, review, search, details and viewer restrictions pass widget checks at 320×568 and 2× text in both themes. Core Notes copy is available in English and Spanish. Light/dark Android screenshots were inspected; body and checklist remain readable and accessible.
- All **79 backend tests pass on PostgreSQL**, including the three file-quota concurrency tests. Notes coverage includes legacy-client defaults, incompatible field rejection, immutable type, versions, account isolation, shared roles/files/revocation, transcription without extraction, and rejection of oversized transcripts without truncation. Django system checks and migration checks are clean.
- `integration_test/notes_flow_test.dart` passed twice on Android with real SQLite, JWT and Docker HTTP/PostgreSQL. It leaves typed input, resumes it from Notes, saves once, restores from an empty account cache, edits checklist progress, round-trips the archive, keeps Notes separate from Tasks, and edits the same saved identity. Only secure credential storage is substituted. The final run includes the unfinished-capture entry and visual cleanup.
- `Backend/scripts/notes_smoke_test.py` passed against the live provider using an explicitly synthetic WAV: **1.807 seconds**, 117 characters, one note preserving the transcript, saved and restored after a new login. This is one transcription measurement, not evidence of real-microphone quality or task-extraction speed.
- Synthetic accounts and scoped device fixtures were removed. Integration drivers used `--keep-app-running` to preserve existing emulator data. The API image and migrations are deployed locally. The ordinary Android x64 debug APK builds, has been restored using `adb install -r`, and launches successfully.

Logs: `App/artifacts/notes-final-tests.log`, `notes-final-analyze.log`, `notes-final-android.log`; `Backend/artifacts/notes-postgres-tests.log`, `notes-capability-tests.log`, `notes-live-transcription.log`. Screenshots live in `App/artifacts/design/notes-*.png`. Artifacts are ignored by Git.

An additional [external handoff check](HANDOFF_VALIDATION.md) confirms a note link opens Chrome and renders the local health page on Android. Real microphone recovery, installed native speech models, physical-phone behavior and first-user understanding of Task versus Note remain unverified. See [remaining evidence](VALIDATION_REMAINING.md). Automated tests do not establish product preference or retention.
