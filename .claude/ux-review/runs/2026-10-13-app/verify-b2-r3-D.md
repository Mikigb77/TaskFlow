## UX verify — 2026-10-13-app, round 3, area D (P56) — 2026-10-13

**Verdict:** Ship. Both gaps left by P55 are closed in code, the doc comment matches the behaviour, and nothing in the changed files regresses a flow. UX-449 still needs a check on a phone.

**Evidence level:** code (`git diff HEAD`; `reminder_ask_sheet.dart`, `shell_tab_provider.dart` and the test file are untracked, so I read them in full). The tests that ux-tester wrote exist but nothing was reported from running them; I didn't run Flutter. Nothing visual changed (no copy, layout or ARB edits), so no render applies.

### UX-448 · fixed
- `App/lib/widgets/reminder_ask_sheet.dart:67-77`: once `bar` is non-null, the question goes ahead only when `bar.closed` is `timeout`, `swipe` or `dismiss`. For `action`, `hide` or `remove` it returns, and `finally` (`:120-121`) releases `_askingProvider` because `shown` is still false. When `bar` is null, behaviour is unchanged.
- `showFeedback` (`App/lib/widgets/app_components.dart:13`) calls `hideCurrentSnackBar()`, so `Tarea completada` and the date-changed message close the save message with `hide`. The sheet no longer opens over their `Deshacer`.
- Tests are at `App/test/reminder_ask_sheet_test.dart:642-741`: tick, then the next save asks; move the date; swipe counts as seen.

### UX-449 · fixed (needs a phone)
- `App/lib/providers/shell_tab_provider.dart:3-5` matches the brief, word for word.
- `App/lib/screens/main_shell.dart:55-62`: the counter goes up only when `index != _index`, inside `onDestinationSelected`, followed by `setState` as before. Grep shows `main_shell.dart:60` is the only writer. The label-scale code, the destinations and the IndexedStack are untouched.
- `reminder_ask_sheet.dart:48` reads the count at the call, and `:81` returns when it has changed, right after the `under.isCurrent` check. Doc comment `:15-22` updated.
- Tests are at `reminder_ask_sheet_test.dart:743-793`: Notas, then back, then the next save asks; re-tapping Calendario doesn't block.
- A device check is still needed: switch to Notas within 4 s of the first dated save.

### Regressions
None.

Observation, not raised: if two dated tasks are saved within one save-message window, the second call is turned away because the slot is held (`:40`), and the first one skips on `hide`. So the question waits for a third dated save. That's harmless and arguably right, since it never covers the second `Deshacer`, but it's slightly looser than the doc comment's "the next dated save asks".
