## UX verify — run 2026-10-18-commands, b4 round 1, area B (P154) — 2026-10-19

**Verdict:** UX-1223 fixed (widget-test and render evidence; the phone walk in the brief's device check is still owed). One polish regression.

### UX-1223 · S2 · A full file space gives no way to find the files — fixed
- Ways in, only when the account's own space is full: `App/lib/widgets/attachment_panel.dart:382-398` adds «Ver tareas con archivos» after «Ver Pro» only for `TaskAttachment.storageFull` and no Pro (not for `storageFullShared`); `App/lib/screens/subscription_screen.dart:132-142` shows it under «Archivos: N de 100 MB usados» only when `usedBytes >= limitBytes` and `limitBytes > 0`, in `onPrimaryContainer`. Default path unchanged.
- List: `App/lib/screens/tasks_with_files_screen.dart` — title «Tareas con archivos», help line, rows «N archivos · X,X MB» largest first, owned projects and no-project tasks only (`list.role == 'owner'`), tap opens `TaskDetailScreen`, list re-read on return (`ref.invalidate`) and on any task change (watches `taskProvider`). Empty: «No hay tareas con archivos.». Counting: `App/lib/services/attachment_store.dart:43-58` (`usageByTask`) excludes deleted, delete-pending and both refused tokens, and deleted tasks.
- Copy in all three ARBs matches the brief exactly (`app_en.arb:2074-2101`, `app_es.arb:1213-1217`, `app_ca.arb:917-921`), with a real ICU plural.
- Renders (06:55–06:56 today, no app file newer): `tasks/tasks-with-files.list.*` (ES 1×/2× light/dark, CA 2×) — rows wrap whole, no overflow, dark mode fine; `tasks-with-files.empty.*`; `tasks/detail.file-space-full.es.*` — «Ver Pro» and «Ver tareas con archivos» side by side at 1×, stacked at 2×; `settings/pro.file-space-full.*` — button directly under the usage line. AUDIT: rows 312 × 81 dp, 12 dp apart; TalkBack reads each row as title + count; the new buttons are 183 × 48 dp. The only flags on these screens are pre-existing (the Wrap's 4 dp run spacing in the file card, «Ver suscripción» height, Flutter-histogram contrast false positives).
- ux-tester: all seven acceptance checks pass.
- Still a device check: the brief's phone walk (attach past the cap → list → remove from the largest → back → «Reintentar»).

### Regressions
**R1B-1 · Severity 1 · Not-yet-uploaded files count, can read «0,0 MB»**
- Where: `App/lib/services/attachment_store.dart:47-52` (`usageByTask`), shown by `App/lib/screens/tasks_with_files_screen.dart:52-56`.
- What happens: files still waiting to upload (`upload_pending = 1`) count toward a row. They use none of the server's 100 MB yet, and a file attached from the editor is stored with size 0 until its upload starts (`App/lib/services/task_database.dart:275-278`), so its row can say «1 archivo · 0,0 MB». Removing it frees nothing, which goes against the help line's promise. This is rare: it needs a pending upload while the space is full.
- Fix: count only files the server holds: add `AND a.upload_pending = 0` (or `a.remote = 1`) to the query. Then a row never shows 0,0 MB, and the list matches the 100 MB line.
- Evidence: verified in code; no render shows it.

### Not counted as regressions
- The file card's Wrap now holds five text buttons of one style («Abrir», «Reintentar transferencia», «Ver Pro», «Ver tareas con archivos», «Eliminar archivo adjunto»), 4 dp apart in runs. The style and spacing are pre-existing; the brief asked for the button here.
- List rows read as "tappable", not "button", like 259 other rows in AUDIT. This is the app's existing pattern.
