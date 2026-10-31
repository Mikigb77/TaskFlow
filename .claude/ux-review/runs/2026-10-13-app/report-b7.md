# UX loop report: run 2026-10-13-app, batch b7 (closed 2026-10-14)

**Verdict:** 18 of 19 findings were handled. 11 are verified, and 7 are verified in code but still need a phone or a real server. UX-511 is still open: the fix half-worked once, and the batch ended after round 3. Nothing was escalated. A test covers all 18 handled findings.

**Evidence:** code reading plus ux-tester's widget and unit tests. One render was used: `App/build/capture-listening-es-2x.png`, which shows the listening path unchanged. No preview covers the used-up states, the attachment panel, Account or the Pro screen. Nothing ran on an emulator or a phone.

## Verified (reviewer said "fixed", no failing test)
- **UX-408** · Account: manual sync dominates; sign-out unconfirmed (P44)
  - The sync card is now one line: "Guardado en tu cuenta".
  - Sincronizar shows its own spinner.
  - Importar shows only when there are local items.
  - "Detalles de conexión" shows only in debug builds.
  - Sign-out now asks first.
  - Buttons on a typical account: 4 → 2.
- **UX-496** · After a failed set-up, Voz says the same thing twice (P93). Only the banner remains after a failed set-up.
- **UX-499** · Cancel or "Guardar tal cual" while understanding must not cost a dictation (P89)
  - Every request sends `capture_id`.
  - Cancelling sends `DELETE ai/drafts/<id>/` without waiting.
- **UX-501** · The Pro screen hid the free tier's numbers, and the test-mode copy misstated Pro (P92)
  - Free accounts now see the dictation count and file usage; Pro accounts don't.
  - The test-mode copy is corrected.
- **UX-503** · Catalan read "el 1 de nov." (P98; P94 only partly fixed it in round 2)
  - The copy is now "el dia {date} en tindràs més."
  - No doubled full stop for any month.
- **UX-504** · "Te quedan 0 dictados" (P94). Now "Ya no te quedan dictados gratis este mes" (EN and CA too).
- **UX-506** · "Remove a file to make room" didn't say where the files are (P95). Now "Elimina archivos de otras tareas para hacer sitio…".
- **UX-507** · "Files" sat under an "Attachments" heading (P95). The heading is now "Files" / "Archivos"; Catalan is unchanged.
- **UX-509** · Billing messages said "refresh", but that button is gone (P96). They now say to open the screen again, or to tap "Restaurar compras".
- **UX-510** · The Pro screen said 100 MB; the task editor said 64 MiB (P96). The per-account cap is gone from `fileUploadHelp`.
- **UX-512** · The file limit said 6 MB in one place and 6 MiB next door (P99). Every file-size message now says "6 MB"; "MiB" no longer appears in any ARB file.

## Verified in code, still needs a phone (device-check)
- **UX-497** · Free accounts can dictate their 10 free dictations a month (P89).
- **UX-498** · Running out of free dictations keeps the words and offers typing (P90).
- **UX-500** · A warning near the 100 MB cap; refused files are no longer re-sent on every sync (P91).
- **UX-423** · Long export intro and extra Pro-screen buttons (P44). Pro screen buttons for a past buyer: 5 → 3.
- **UX-502** · Kept recording at 0 left (P94). The only control is now one "Cerrar" button, with no field and no dialog.
- **UX-505** · The usage line now refreshes after uploads (P95).
- **UX-508** · Sign-out now shows a spinner inside the button (P96).

## Still open
- **UX-511** · S2 · B · After an upload, the task screen blinks and jumps to the top.
  - **Attempts:** P97 in round 3 is the only one. The reviewer rated it partly fixed (1 failure).
  - **What works:** the task repository and the capture owner now watch only `account?.id`. An account update no longer turns Task details into a spinner or runs a second sync.
  - **What still fails:** the scroll position moves after every sync while the task is open. `App/test/account_update_test.dart:381-396` ("stays where the user scrolled") fails.
  - **Cause:** it's outside P97's files. `attachments.when(...)` at `App/lib/widgets/attachment_panel.dart:218` swaps the file cards for a progress bar on each reload, because `skipLoadingOnReload` defaults to false.
  - **Reviewer's fix:** pass `skipLoadingOnReload: true` there. No copy change.
  - **Status:** not re-planned, because b7 ended after round 3. It's one failure, not two, so it's still open rather than escalated. It should go first in the next batch.

## Escalations
None.

## Checks for the owner's phone
1. **UX-497:** on a free account against the real server, dictate and watch the count on the Pro screen drop. Do the same from the home-screen widget and the voice shortcut.
2. **UX-498:** with 0 dictations left, open capture from the home-screen widget. It opens in typing, with the reset date and "Ver Pro".
3. **UX-500:** use a free account near the 100 MB cap.
   - Attach a photo that crosses the cap.
   - Remove a file, then tap Reintentar.
4. **UX-423:** come back from the store after a purchase. The Pro status updates without any button.
5. **UX-502:** on a free account at 0 left, reopen a kept recording from Capturas pendientes. No keyboard rises, and "Cerrar" closes it with the recording kept.
6. **UX-505:** on a free account at about 75 MB, attach photos past 80%. "Archivos: N de 100 MB usados" appears.
7. **UX-508:** sign out on a slow network. The spinner shows in the Cerrar sesión button until the sign-in screen appears.
8. **UX-511, after its fix:** on a free account, open a long task, scroll to the bottom and attach a photo. The card never disappears and the view stays put.

## Reviewer notes, not filed
- **Owner question, not blocking (UX-506):** should the app offer a way to find the tasks that have files?
- The sign-out spinner has no TalkBack label. The Sync and Import spinners are the same, so this isn't worse than before.
- `accountUnavailable` still says "Connect to the TaskFlow server", which is technical. That is the copy the plan set.
- "6 MB" slightly understates the real 6 MiB limit. It errs on the generous side, so no user is harmed.

## Files changed
- **Services:**
  - `App/lib/services/api_client.dart`
  - `App/lib/services/capture_processor.dart`
  - `App/lib/services/capture_problem.dart`
  - `App/lib/services/capture_store.dart`
  - `App/lib/services/attachment_store.dart`
- **Providers:**
  - `App/lib/providers/auth_provider.dart`
  - `App/lib/providers/subscription_provider.dart`
  - `App/lib/providers/task_provider.dart`
- **Repositories and models:**
  - `App/lib/repositories/task_repository.dart`
  - `App/lib/repositories/cloud_task_repository.dart`
  - `App/lib/models/task_attachment.dart`
- **Screens:**
  - `App/lib/screens/voice_task_screen.dart`
  - `App/lib/screens/captures_screen.dart`
  - `App/lib/screens/notes_screen.dart`
  - `App/lib/screens/voice_settings_screen.dart`
  - `App/lib/screens/account_screen.dart`
  - `App/lib/screens/subscription_screen.dart`
  - `App/lib/screens/data_transfer_screen.dart`
- **Widgets:**
  - `App/lib/widgets/task_actions.dart`
  - `App/lib/widgets/attachment_panel.dart`
- **App entry:** `App/lib/main.dart`
- **Text:**
  - `App/lib/l10n/app_en.arb`, `app_es.arb`, `app_ca.arb`
  - `App/lib/l10n/capture_messages.dart`
  - `App/lib/l10n/generated/*`, regenerated by `flutter gen-l10n`, not edited by hand
- **Tests:**
  - `App/test/capture_free_dictations_test.dart`
  - `App/test/capture_sheet_test.dart`
  - `App/test/voice_settings_test.dart`
  - `App/test/attachment_store_test.dart`
  - `App/test/attachment_panel_test.dart`
  - `App/test/subscription_screen_test.dart`
  - `App/test/account_regional_ui_test.dart`
  - `App/test/data_transfer_screen_test.dart`
  - `App/test/account_update_test.dart`

## Tests covering the handled findings
| Test file | Findings |
|---|---|
| `capture_free_dictations_test.dart` | UX-497, UX-498, UX-499, UX-502, UX-503 (:1031-1151), UX-504 |
| `voice_settings_test.dart` | UX-496 |
| `attachment_panel_test.dart` | UX-500, UX-506 (:293-347), UX-507 (:350-389), UX-510, UX-512 |
| `attachment_store_test.dart` | UX-500, UX-505 (:408-494) |
| `subscription_screen_test.dart` | UX-423, UX-501, UX-509 |
| `data_transfer_screen_test.dart` | UX-423 |
| `account_regional_ui_test.dart` | UX-408, UX-508 |
| `account_update_test.dart` | UX-511: covers the part that works; the scroll test still fails |

## Rounds
**Round 1** (`plan.json`; P89, P90, P91, P44, P92, P93): **tests passed.**
- Fixed: UX-496, UX-497, UX-498, UX-499, UX-500, UX-408, UX-423, UX-501.
- Nine regressions, filed as UX-502 to UX-510:
  - R1A-1 → UX-502
  - R1A-2 → UX-503
  - R1A-3 → UX-504
  - R1B-1 → UX-505
  - R1B-2 → UX-506
  - R1B-3 → UX-507
  - R1D-1 → UX-508
  - R1D-2 → UX-509
  - R1D-3 → UX-510

**Round 2** (`plan-b7-r2.json`; P94, P95, P96): **tests failed.** Per the verify notes, the failure was UX-503's Catalan acceptance check: the text read "nov..".
- Fixed: UX-502, UX-504 to UX-510.
- Partly fixed: UX-503.
- Regressions: R2B-1 → UX-511, R2D-1 → UX-512.

**Round 3** (`plan-b7-r3.json`; P97, P98, P99): **tests failed.** Per the verify notes, the failure was `account_update_test.dart` "stays where the user scrolled" (UX-511).
- Fixed: UX-503, UX-512.
- Partly fixed: UX-511.
- No regressions.

## Ledger
`.claude/ux-review/ISSUES.md` is updated:
- 11 lines moved to Verified;
- 7 lines moved to Device check, including UX-497 to UX-500, which had been sitting in that section with the status `open`;
- UX-511 rewritten in Open, with its main path changed to `App/lib/widgets/attachment_panel.dart:218`.

Titles longer than 10 words were shortened: UX-497, UX-498, UX-499, UX-500 and UX-501.
