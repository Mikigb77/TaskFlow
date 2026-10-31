## UX verify — 2026-10-13-app, batch b7, round 1, area B (P91) — 2026-10-14
**Verdict:** UX-500 fixed in code; two small follow-ups, no blocker. Phone check still needed.
**Evidence level:** code reading plus ux-tester's widget and unit tests (all pass). There's no preview of the attachment panel in `App/build/`, so I didn't use any render.

### UX-500 · fixed (needs a phone)
- **Stable token, not the server's text.**
  - `App/lib/models/task_attachment.dart:20-21,37` adds the tokens `storageFull` / `storageFullShared` and `refused`.
  - `App/lib/services/attachment_store.dart:192-210`: `_error` maps 400 `storage_full` to the own or shared token from `body['shared']`. It never touches `message`, and never goes near `requestProblem`.
- **No re-send on background sync.**
  - `attachment_store.dart:233`: the queue query skips refused rows.
  - Re-sending happens only in three places:
    - Retry: `attachment_panel.dart` Retry calls `retryRefused(id)`, then `loadTasks`, which awaits `CloudTaskRepository.sync` → `attachments.sync`.
    - Removal: `attachment_store.dart:106` calls `_releaseRefused` inside the remove transaction. Removals now sync before uploads (`:228`), so the space they free is there first.
    - Pro turning on: `App/lib/main.dart:285-305`, `retryRefused()` after `billing/access/`, then `loadTasks`.
- **Usage line.** `attachment_panel.dart:150-162`:
  - shows at 80% or more (`used*5 >= limit*4`), only without Pro, using whole MB;
  - copy `storageUsage` is in all three ARBs;
  - the tester proved EN/ES/CA at 2× and 320 dp, and nothing below 80% or with Pro.
- **Refused row** (`attachment_panel.dart:265-283`):
  - shows `storageFull({limit})` or `storageFullShared` in `colors.error`, with words, so it doesn't rely on colour alone;
  - replaces the misleading "Upload queued", and the raw-error line is suppressed;
  - "Ver Pro" (`voiceProAction`) appears only for the user's own space and only without Pro (`:379-388`).
- **Account refresh.**
  - after a removal (`:139-142`);
  - after an own refusal, `rememberStorage` → `accountUpdated` → `AuthNotifier` (`auth_provider.dart:46-55`), so the line and the cap number update at once.
- **Not in P91, correctly left out:** the Pro-screen lines (P92/P44). `billingTestMode` (string 7) was updated anyway, in all three ARBs.
- **Still needs a phone:** a free account near the cap; attach a photo that crosses it; remove a file; tap Retry.

### Regressions and follow-ups (only in the changed flow)
**R1B-1 · Severity 2 · Usage line stays hidden after uploads that cross 80%**
- **Where:** `attachment_panel.dart:150` reads `account.storage`. That value is refreshed only:
  - on restore (`auth_provider.dart:84`);
  - after a removal;
  - after an own refusal.
  A successful upload (`attachment_store.dart:260-280`) doesn't refresh it.
- **The moment:** a free user at 75% attaches three photos in one session and sees no warning. The first sign of the cap is the refusal itself, so the warning this finding asked for arrives too late.
- **Fix:** after a sync that uploaded at least one file for an account without Pro, call `authProvider.notifier.refreshAccount()` once. That's the same call the removal path already makes. No new UI.
- **Verify:** a unit or widget test. Start at 78 MB, upload succeeds, `auth/me/` answers 82 MB, and the panel shows `Files: 82 of 100 MB used`.

**R1B-2 · Severity 2 · "Remove a file to make room" has no path to the files**
- **Where:** `storageFull` in `app_en.arb`, `app_es.arb` and `app_ca.arb`, shown under a refused file in `attachment_panel.dart:265`.
- **The moment:** "Which file? This one is the only one I see." Files live on other tasks. Task rows show no attachment marker, and there's no list of files anywhere. Removing the refused file itself frees nothing.
- **Fix:** name where the files are, and lead with the action.
  - EN: `Your file space is full ({limit} MB). Remove files from other tasks to make room, or get Pro for unlimited space.`
  - ES: `Tu espacio para archivos está lleno ({limit} MB). Elimina archivos de otras tareas para hacer sitio o hazte Pro para tener espacio ilimitado.`
  - CA: `El teu espai per a fitxers és ple ({limit} MB). Treu fitxers d’altres tasques per fer lloc o fes-te Pro per tenir espai il·limitat.`
  - Whether the app should offer a way to find tasks with files is a product question for the owner, not part of this fix.
- **Verify:** a string check in all three ARBs, plus the existing refused-file widget test.

**R1B-3 · Severity 1 · "Files" in a section titled "Attachments"**
- **Where:** `storageUsage` sits under `SectionLabel(attachments)`:
  - EN: "Files: …" under "Attachments";
  - ES: "Archivos: …" under "Adjuntos";
  - CA: "Fitxers: …" under "Fitxers adjunts".
- **Why it matters:** two names for one thing, side by side (plain language: one concept, one name). Catalan already reads fine.
- **Fix:** keep "Files" / "Archivos" / "Fitxers" — the Pro screen uses the same string, where there's no heading — and keep the usage line as it is. Alternatively, rename the heading to `Files` / `Archivos`, with Catalan unchanged. Either way, only one word should remain.
- **Verify:** a string check.

### Notes, not regressions
- Removing your own file also releases refused files in shared projects. They are re-sent once and refused again, which costs some mobile data but nothing the user sees.
- Retry on a file that's still refused shows the progress bar and then the same message. That's acceptable, because the message itself says what to do.
- There's no attachment-panel preview, so a render-based check of the refused row at 2× in Spanish isn't possible. The three buttons ("Reintentar transferencia", "Ver Pro", "Eliminar archivo adjunto") sit in a `Wrap`, so they can't overflow.
