Checklists — B14
================

Tasks support up to 50 single-level steps, each with a stable UUID and a title of up to 160 characters. Add, rename, reorder, remove and check steps in manual editing or AI review. Task rows show progress; task details expose checkboxes. Finishing the checklist does not implicitly complete its parent task. A recurring task retains each step's completion per occurrence date, so the following week starts unchecked. Editing a recurring template explains that completion belongs to occurrences.

SQLite schema 8 upgrades existing tasks with an empty checklist. Django migration 0004 stores validated checklist JSON. Sync includes step identity/order/title/completion and per-date history. Existing optimistic version checks preserve a conflicting offline copy; a retry after a lost response compares checklist contents. Older API clients that omit the field do not erase a server checklist. The extraction prompt and bounded schema distinguish grouped packing/shopping steps from independent appointments, and reject oversized responses instead of truncating them.

Verification, 22 September 2026:

- All 82 Flutter tests pass. They include editing/reordering without ID changes, large text in both themes, AI review corrections, per-occurrence completion, offline sync/restoration and checklist-only conflicts. Static analysis is clean.
- All 45 rebuilt Docker backend tests pass. Checklist identity/size/title/date validation, version conflict, older-client preservation and bounded extraction are covered. Migration consistency check passes; 0004 is applied locally.
- `integration_test/checklist_flow_test.dart` passes on Android with real SQLite, HTTP and PostgreSQL. It edits a retained AI fixture in review, saves it, checks one occurrence's step, then clears only the synthetic account's task cache and restores it from the server. The following occurrence remains unchecked. Light/dark screenshots were inspected. Credential storage and AI output are fixtures; this run is not live extraction accuracy evidence. Synthetic local tasks and the exact test account were removed. The user's session and task data were preserved.
- Live configured-model extension: English packing checklist passed in 16.245 s; Spanish shopping and independent appointments failed because of a service error/timeout. Those two are unvalidated against the provider. The broader run is documented in CAPTURE_EVALUATION.md. No recognition accuracy is implied.

Reproduce the Android check with `flutter drive --keep-app-running --no-pub --driver=test_driver/appearance_test.dart --target=integration_test/checklist_flow_test.dart -d emulator-5554`. Preserve app data and restore a regular `lib/main.dart` APK after running integration tests. Logs/screenshots are in ignored `App/artifacts/checklist-*` and `App/artifacts/design/checklist-detail-*.png`; synthetic live reports are in ignored `Backend/artifacts/checklist-evaluation.*`.
