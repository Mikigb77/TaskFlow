## UX verify — run 2026-10-13-app, round 2 (b5-r2), area C — 2026-10-14

**Verdict:** Ship. All five findings are fixed in code, and ux-tester's widget tests cover every acceptance check. No regressions in the changed files. Two device checks are still open (P73 delete on a phone, P74 slow connection with a second account).

**Evidence:** code reading of the current working tree, plus ux-tester's widget-test results. No current preview covers the project page, the sharing screen or the join dialog. The renders re-made at 10-14 09:11 are calendar, review and capture only, so the visual judgements below rest on code.

### Results

| ID | Result | Evidence |
|---|---|---|
| UX-476 | fixed (phone check open) | `list_sharing_screen.dart:107-111` pops with `true` on delete or leave and then shows `done` on the root messenger. `home_screen.dart:346-358` pushes `MaterialPageRoute<bool>`, awaits it, and pops the project page when the result is `true` and the page is still mounted. GroupScreen pops with null, so group projects don't change. Projects ⋮ → Compartir (`task_lists_screen.dart:375-382`) still pops once and ignores the result. There's one mechanism and the message shows once. Tests: Compras deleted from its page lands on Projects with `Proyecto eliminado` and leaves no HomeScreen behind; an editor leaving Casa sees `Has salido de Casa`; the ⋮ path stays on Projects. |
| UX-477 | fixed | New key `deleteListPrivateHelp` in all three catalogs (EN :810, ES :521, CA :500) with the exact copy. Projects ⋮ `_delete` picks it by `list.shared` (`task_lists_screen.dart:103-105`). The sharing screen reads `shared` from `taskListsProvider` and falls back to `true` (`list_sharing_screen.dart:200-202`), then uses it for both the confirmation (:380-384) and the label (:398-400). Tests pass for both doors and both states. |
| UX-479 | fixed | `task_lists_screen.dart:332-342`: the item stays for every signed-in account. It reads `shareProject` when `list.canManage`, otherwise `people` (`Miembros` / `Members` / `Membres`). No new keys. Test covers editor, non-admin group member, own project and group admin. |
| UX-478 | fixed (phone check open) | `invitation_cards.dart:157-308`: the new `_JoinDialog` sends from inside the dialog. While sending, Unirme becomes a disabled FilledButton with a 20 dp spinner (strokeWidth 2, `semanticsLabel: joinInvitation`); Rechazar, Cancelar and the field are disabled; `barrierDismissible: false` plus `PopScope(canPop: !_sending)` keep it open. It waits for `respond` and then `refreshAfterInvitation`; a failed refresh is swallowed, because the person did join (:210-214). The account-switch check runs before and after the request. On failure the dialog stays, the code stays (`_entered`), and the problem shows as `errorText` (:221-225), cleared by `onChanged` (:260-263). A wrong code maps through the new `sharingProblemReason` (`request_locale.dart:48-67`, a pure extraction with the same matching as before) to `invitationCodeWrong` (EN :831, ES :528, CA :507). `_responding` is reset in `finally`. Keys are kept. |
| UX-480 | fixed | (a) `confirm-decline` now uses `backgroundColor: colorScheme.error`, `foregroundColor: colorScheme.onError` (`invitation_cards.dart:118-123`). (b) The `memberLimit` branch reads `cancel an invitation` / `anula una invitación` / `anul·la una invitació` (EN :25, ES :22, CA :23). None of them contains `revoke` or `revoca`. |

### Regressions
None caused by these changes. Things checked:
- **Every way into `HomeScreen(listId)`:** Projects, GroupScreen, and `showJoined` with push or pushReplacement over a review screen that is itself pushed over `/`. Each has a route below it, so the second pop never empties the stack.
- **Projects ⋮ → sharing:** `pop(context, true)` on that `MaterialPageRoute<void>` is accepted, and the test passes.
- **Brief label flip:** during the exit animation after delete, `taskListsProvider` is invalidated, so the label briefly falls back to the shared wording. It's invisible in practice, so I'm not reporting it.
- **Field errors that can't be fixed by retrying:** `expired`, and `accepted`, whose text speaks to the owner. These now sit under the field with Unirme still active, where before they were a snackbar. The brief specified this ("every other error … under the field, as before"), and Cancelar is visible, so it isn't a regression. The `accepted` copy aimed at the owner already existed.
- **Connection error under the field:** it reads `networkKept`, which ends "Tus tareas siguen guardadas en este teléfono". It's the same string the old snackbar used, so it isn't new.

### Still open (device)
- P73: on a phone, delete an owned project from its page; you should land on Projects with `Proyecto eliminado`, and Back must not return to an empty `Proyecto` page.
- P74: with a second account on a slow connection, the spinner should stay in the dialog until the project opens, and a wrong code should keep the dialog, the code and `Pide a quien te invitó el código actual.`

### Memory notes
- The join dialog is now the stateful `_JoinDialog` in `invitation_cards.dart`. It sends inside the dialog and shows errors as the field's `errorText`. Use it as the pattern for any code-entry dialog.
- Leaving or deleting from a pushed sharing screen pops with `true`, and the project page closes itself. That's the "result closes the parent" pattern; GroupScreen still pops with null.
- `sharingProblemReason(error)` in `request_locale.dart` is the way to branch on a sharing error without comparing translated strings.
