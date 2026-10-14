## UX verify — 2026-10-13-app, b7 round 2, area B (P95) — 2026-10-14

**Verdict:** all three findings are fixed in code. One regression: the new usage refresh resets the task screens after every upload by a free account (R2B-1, S2).
**Evidence level:** code plus ux-tester's unit and widget tests. No preview covers the attachment panel (no `App/build/*.png` for it), so nothing was rendered. I didn't run Flutter.

### Results

**UX-505 · fixed (needs a phone)**
- `App/lib/services/attachment_store.dart`: `uploaded++` after the server confirms the upload. After the loop, if `uploaded > 0`, the account is the same, it has a `storage` block, and it isn't `complimentaryPro`, the store calls `api.refreshStorage` once and ignores any error.
- `App/lib/services/api_client.dart`: `refreshStorage` sends `GET auth/me/` and passes `storage` to `rememberStorage`. That goes through `_remember`, which emits `accountUpdated`. `AuthNotifier` listens to it (`auth_provider.dart:46-55`), and `_usage()` watches `account.storage` (`attachment_panel.dart:150-162`).
- A sync with no upload doesn't refresh, so it can't loop.
- Tests: `attachment_store_test.dart:408-494` (exactly 1 `auth/me/` request; 0 when nothing uploads or the only file is refused; the panel shows `Files: 82 of 100 MB used`).
- One limit: the widget test overrides `taskRepositoryProvider` with a fixed value, so the app's real rebuild-on-account-update path isn't exercised. See R2B-1.
- Phone: free account at about 75 MB; attach photos past 80%.

**UX-506 · fixed**
- `storageFull` reads exactly as the brief asked, in all three languages:
  - EN `app_en.arb:1748`;
  - ES `app_es.arb:1186`;
  - CA `app_ca.arb:880`.
- `{limit}` is kept, and the regenerated files match.
- The panel shows it in the error colour under the refused file (`attachment_panel.dart:265-269`), with `Ver Pro` / `Explore Pro` / `Descobreix Pro` (`:379-388`).
- Tests: `attachment_panel_test.dart:293-347`, covering ES, EN and CA at 2× text and 320 dp, with no overflow.

**UX-507 · fixed**
- `attachments` now reads: EN `Files` (`app_en.arb:235`), ES `Archivos` (`app_es.arb:170`), CA `Fitxers adjunts` (unchanged).
- Only the two `SectionLabel`s use the key (`attachment_panel.dart:207`, `task_editor.dart:758`), so the heading and the usage line (`Archivos: 85 de 100 MB usados`) now use one name.
- Tests: `attachment_panel_test.dart:350-389`.
- Only stale mention left: a code comment at `attachment_panel.dart:196` ("Attachments section"), which users don't see.

### Regressions

**R2B-1 · Severity 2 · After an upload, the task screen blinks and jumps to the top**
- Where:
  - `App/lib/services/attachment_store.dart` (the refresh after `uploaded > 0`) →
  - `auth_provider.dart:54` (`state = AuthState(account: account)`) →
  - `task_provider.dart:14` (`taskRepositoryProvider` watches the whole `account` object) →
  - `taskProvider` builds a new `TaskNotifier`, starting at `AsyncValue.loading()` →
  - `task_detail_screen.dart:98-100` and `:469`. The whole screen becomes a spinner Scaffold with no app bar, then comes back.
- The moment: "I added the photo and the screen went blank and jumped to the top. Did I break it? Is my photo there?"
- What happens: every successful upload by a free account now creates a new `Account` object. That rebuilds the repository and the task list, then runs one more full sync.
  - Task detail, where the user just attached the file, flashes a spinner and rebuilds from scratch: its scroll position and the panel's state are lost.
  - Calendar (`calendar_screen.dart:266`, `valueOrNull ?? []`) briefly shows an empty day.
  - Home (`home_screen.dart:481`) briefly shows a spinner.
  - This happens even below 80%, where the usage line stays hidden, so nothing visible changes in exchange. Before P95 it happened only on a refusal; now it happens on every upload.
- Why it fails: change blindness (Rensink et al. 1997). The moment the user should see the file in place, the screen resets. Visibility of system status (Nielsen): the flash looks like an error. Peak–end rule: the attach flow ends on a blink.
- Fix: an update that only changes the account's usage or free dictations must not rebuild the task screens.
  - Make the task repository depend only on which account is signed in, `account?.id`, not on the whole account. Then only the usage line, which watches `account.storage`, repaints.
  - That also removes the extra sync after each account update.
  - Optionally, `_remember` could skip the emit when the stored block is unchanged.
  - No copy change.
- Verify: a widget test that pumps `TaskDetailScreen` with the real `taskRepositoryProvider` (not overridden), scrolled to the files. After a sync that uploads and refreshes, no `CircularProgressIndicator` appears, the scroll offset is kept, and `Files: 82 of 100 MB used` shows. On a phone, attach a photo at the bottom of a long task: the screen stays put.
- Evidence: inferred from code (provider chain read end to end); needs a device check. It isn't in `ISSUES.md`. The free-dictation path in `rememberFreeVoice` causes the same rebuild after a dictation; that came earlier, so it isn't counted here.

### Lenses checked on the changed flows
- **A (next step):** the refusal names where to free space and offers Pro. Good.
- **B (feedback):** usage now updates after uploads, but see R2B-1.
- **C (load):** no new controls.
- **E (scanning):** the message leads with "Your file space is full".
- **G (copy):** one name, Files/Archivos, for the heading and the usage line. CA keeps "Fitxers adjunts" over "Fitxers:", as the brief asked.
- **L (accessibility):** 2× text at 320 dp is tested in all three languages.
- **M (localization):** all three ARB files and the regenerated files match.
- **D, F, H, J, K, N, O:** nothing changed.
