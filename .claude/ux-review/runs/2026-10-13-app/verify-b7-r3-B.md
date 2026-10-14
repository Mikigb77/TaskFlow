## UX verify — 2026-10-13-app, b7 round 3, area B (P97) — 2026-10-14
**Verdict:** UX-511 is partly fixed. The cause the finding named is gone: an account update no longer rebuilds the task repository, so Task details no longer turns into a spinner, and no second sync runs. But after an upload, the screen still jumps. The files list briefly collapses at the end of every sync, so the user's scroll position isn't kept.
**Evidence level:** code, plus ux-tester's unit and widget tests (`App/test/account_update_test.dart`). No preview renders Task details or the attachment panel, so there was no render to read. I didn't run Flutter.

### Results

**UX-511 · partly fixed (needs a phone)**
- Fixed, verified in code:
  - `App/lib/providers/task_provider.dart:14-18` now selects `account?.id` and passes the id to `CloudTaskRepository`.
  - `App/lib/services/capture_store.dart:16` selects `s.account?.id`. Both match `groups_provider.dart:10` and `project_scope_provider.dart:14`.
  - The comment above the refresh in `attachment_store.dart` and the one in `attachment_store_test.dart` now say why the refresh can't loop. The test still asserts a single `auth/me/` request.
  - ux-tester's tests pass for the same repository and the same `TaskNotifier`, no return to loading, one sync, a new repository on sign-out and on sign-in as account 2, and `captureOwnerProvider` / `pendingCapturesProvider` left untouched.
  - In the widget test (real providers, scrolled down to the files), the app bar stays, no spinner appears, and `Files: 82 of 100 MB used` shows.
- Still failing — the scroll offset changes (`account_update_test.dart:381-396`). The cause is outside the files this package changed:
  - `attachmentEntriesProvider` (`App/lib/widgets/attachment_panel.dart:25-29`) watches `taskProvider`.
  - At the end of every sync, `TaskNotifier._loadLoop` emits a new list (`task_provider.dart:51`), and the provider re-runs. That counts as a reload.
  - `attachments.when(...)` at `attachment_panel.dart:218` uses Riverpod 2.5.1's default `skipLoadingOnReload: false`. So for that frame, the file cards are swapped for a 4 dp `LinearProgressIndicator`.
  - On a long task, the panel is the last thing in the `ListView` (`task_detail_screen.dart:415`). The user is at the bottom, so the shorter content clamps the scroll offset upward. When the cards come back, the view stays where it was pushed — a jump of about one card per file.
  - This happens on every sync that ends with the task open: after attaching, and again after a sync — so the attach flow still ends on a flicker and a jump, which is what the finding asks to remove.
  - It wasn't caused by this round, and the ledger doesn't list it yet.
- Fix (smallest): at `attachment_panel.dart:218`, pass `skipLoadingOnReload: true` to `attachments.when(...)`, so a reload keeps the cards on screen. The `_busy` `LinearProgressIndicator` at `:208` already shows progress for the user's own actions. No copy change.
- Verify: re-run `account_update_test.dart` "stays where the user scrolled". On a phone: open a long task on a free account, scroll to the bottom and attach a photo. The card must not disappear, and the view must not move.

### Regressions in the changed files
None found.
- I checked whether anything relied on the old rebuild when an account changed:
  - Becoming Pro is handled in `main.dart:297-302` (`retryRefused` + `loadTasks`).
  - `CloudTaskRepository` only ever used the id.
  - Sign-in, sign-out and a switch of account still change the id, so the repository is still rebuilt then (tested).
  - The capture owner key only ever used the id.
- The `attachment_store.dart` diff against HEAD also contains P91/P95 work from earlier rounds, which was verified then. It is out of scope here.
