## UX verify — run 2026-10-18-commands, round 1, area B (P130) — 2026-10-18

**Verdict:** UX-1001 fixed. One polish regression (R1B-1).
**Evidence level:** I read the code and the ux-tester's widget tests. No preview covers a landing under «Para mí», so there's no render to check, and Flutter wasn't run.

### UX-1001 · fixed
- **The rule:** `App/lib/providers/project_scope_provider.dart:34-59`. `scopeShowing` returns the same scope object when that scope already shows every landed task. Otherwise it widens in this order and stops at the first scope that shows them all:
  1. «Todas» in the same project;
  2. all projects, keeping the «Para mí» choice;
  3. «Todas» in all projects.
- **Calendar:** `App/lib/screens/calendar_screen.dart:120-151`. `_land` widens `projectScopeProvider` before it selects the day and lights the row. Calendar's events are filtered by that provider (`:313`), so the row shows up and lights.
- **The Tareas root:** `App/lib/screens/home_screen.dart:142-202`. The page first tries clearing its own search, label and chip. If those still hide the task, it widens the app-wide scope: first keeping the search, then clearing it as well. Project pages (`listId != null`) keep their own rule, because there `wider` is simply `global`.
- **Timing:** the form (`task_editor.dart:430-438`) and both capture save paths (`voice_task_screen.dart:2477`, `:2923`) call `showLocal()` before they set `CalendarFocus`. So `_land` finds the saved tasks in `taskProvider` when it widens.
- **Acceptance:** all five checks pass in the tester's tests: `test/new_task_form_test.dart:1064`, `:1099`, `:1121` and `:1153`, and `test/voice_command_cards_test.dart:2995`.
- **Still for the phone:** say «Ana tiene que llamar al médico mañana» on Calendar, with Pro and a shared project.

### Regressions
**R1B-1 · Severity 1 · Deshacer leaves the widened filter in place**
- **Where:** `calendar_screen.dart:132-134` and `home_screen.dart:199-201`, together with the Deshacer action of the save message.
- **The moment:** "I undid it. Why is the calendar full of Ana's things now?"
- **What happens:** the landing switches «Para mí» to «Todas», or a project to «Todos los proyectos». Deshacer removes the task, but the filter stays widened, so the person's own view doesn't come back.
- **Why it matters:** anything the app does automatically should come undone with it (lens J), and the person should stay in control of their view (Nielsen, user control and freedom). It's only polish: more is shown, nothing is hidden, and the person can tap «Para mí» again.
- **Fix:** when Deshacer removes every landed task, put back the scope from before the landing, but only if the scope is still the one the landing set. No copy change.
- **Verify:** widget test. On Calendar under «Para mí», save a task for Ana, then tap Deshacer: «Para mí» is selected again.

### Not judged
`home_screen.dart` also changed in other ways in this run: a `landing` parameter, the people row moved to full width, and ✓ moved into the app bar on project pages. Those changes belong to other packages, so this check doesn't judge them.
