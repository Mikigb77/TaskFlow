## UX verify — run 2026-10-18-commands, b4 round 2, area B — 2026-10-19

Scope: P163 (UX-1228). Changed file: `App/lib/services/attachment_store.dart` (P154's `usageByTask` is still uncommitted, so `git diff HEAD` shows the whole method; P163's part is the `a.remote = 1` condition and the doc comment).

### UX-1228 — fixed
- `App/lib/services/attachment_store.dart:43-55`: `usageByTask` now filters `AND a.remote = 1` alongside the kept conditions (task not deleted, file not deleted, `delete_pending = 0`, not refused via `_refusedArgs`). Doc comment matches the brief word for word.
- `remote` is 1 only when the server holds the file: set on a confirmed upload (`attachment_store.dart:304`), on server-synced rows (`TaskAttachment.fromApi` sets `remote: true`, `models/task_attachment.dart:85`, stored by `toMap` at :97 and inserted at `attachment_store.dart:380`), and when a local row matches the server copy (:404). A pending or refused upload stays `remote = 0` (`task_database.dart:241` default). So a file awaiting upload no longer counts, and the help line «Abre una tarea para eliminar los archivos que ya no necesites.» is true for every listed row.
- Tests (ux-tester, pass): `App/test/tasks_with_files_test.dart:160-185` (store, real AttachmentStore on FFI SQLite: pending-only task has no entry; 5 MB + 4 MB remote + 3 MB pending → 2 files, 9 MB) and :187 (screen, ES: «Viaje» reads «2 archivos · 9,0 MB», «Fotos» not listed, no «0,0 MB» row). The UX-1223 test's fixture gained optional `remote`/`uploadPending` flags defaulting to the old values (:108-119), so it is unchanged in effect.
- Render: `App/build/ux/tasks/tasks-with-files.list.es.light.1x.png` (2026-10-19 09:40; no app file newer) — three rows, largest first, «3 archivos · 12,4 MB», «2 archivos · 4,1 MB», «1 archivo · 0,3 MB»; layout unchanged from round 1, as the brief asked.

### Regressions — none
- Only the query changed; the screen (`tasks_with_files_screen.dart`), its copy, the storage messages and the upload/remove paths are untouched.
- Edge walked: a free account whose only files are pending sees the empty state; that cannot coincide with «Ver tareas con archivos» being shown for a full space, because a full space means the server holds files, which are `remote = 1` and listed.
- A downloaded-or-not server file (no local path) still counts, correctly, since it uses server space.

Evidence: verified in code, acceptance tests passing (widget/unit level), current render. No device check needed.
