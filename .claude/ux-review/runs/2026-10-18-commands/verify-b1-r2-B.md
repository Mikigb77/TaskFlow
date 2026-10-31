## UX verify — run 2026-10-18-commands, round 2, area B (P147) — 2026-10-18

**Verdict:** UX-1213 fixed. No regressions found in the changed lines or the flows they touch.

Evidence level: code reading, plus ux-tester's widget tests (six acceptance checks, all pass). No render applies: P147 changes no pixels; the only visible effect is which filter chip is selected after Deshacer, and the tests assert that. Device check (Pro, spoken, shared project) is left to the owner.

### UX-1213 · fixed
- Record and helper: `App/lib/providers/project_scope_provider.dart:20-43`. `ScopeWidening(landing, before, after)`; `scopeWideningProvider` resets on account change (:27-30), like `projectScopeProvider`. `narrowAfterUndo` restores `before` only when the record's landing is identical to the undone save's focus and the scope is still identical to `after` (:39-41); it clears the record whenever the landing matches (:42).
- Landings set the record only when they widen: Calendar `App/lib/screens/calendar_screen.dart:132-138` (`ScopeWidening(focus, scope, wider)`); Tareas root `App/lib/screens/home_screen.dart:199-206` (`ScopeWidening(focus, global, scope)`). On project pages `wider == global` (:147-148), so the record is never touched there, as the brief says.
- The three Deshacer handlers call it after a complete undo, with the focus their own save set:
  - the form: `App/lib/widgets/task_editor.dart:439-446` keeps `focus`; :459 calls the helper after `deleteTask` succeeds, not in the catch;
  - a capture's plain save: `App/lib/screens/voice_task_screen.dart:2519` / :2535-2544 / :2576, after `restored != null` and `showLocal()`. `focus` stays null on a partial save, so nothing happens;
  - a result with commands: `voice_task_screen.dart:2992` / :3011-3023 / :3077, only when `whole && restored != null`. `focus` is null when the project page opened instead.
- The user's own choice in between: every filter tap creates a new `ProjectScope`, so the `identical` check leaves «Todas» in place (acceptance check 4, tested).
- A save that didn't widen: no record is set and the helper returns early, so «Para mí» stays and nothing changes (check 6, tested).

### Regressions
None. Checked for:
- an older snackbar's Deshacer matching a newer landing: the helper matches the landing by identity, so it can't;
- a stale record after an account switch: it resets;
- a double landing: Calendar lands only when `page == null` and Tareas only when the page is identical, so they never both land;
- the ordering against the result sheet reopening: the narrow happens first, so the result reopens over the restored filter;
- a command result that also updated tasks: the whole undo reverts them as well, so narrowing back is correct.

Not new and not caused by P147: on the Tareas root, the landing also clears the search, label and tab filter (home_screen.dart:180-185), and Deshacer doesn't bring them back. The brief limited P147 to the app-wide scope, so that's left as it was.
