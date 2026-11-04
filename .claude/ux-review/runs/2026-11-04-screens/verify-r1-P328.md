## UX verify — P328 (area C), round 1 — 2026-11-04 (second pass, after merge)

**Verdict:** UX-2903 fixed. No regressions in the changed files or the flows they touch. Same verdict as the first pass (22:26).
**Why a second pass:** the package worktree `.claude/worktrees/wf_a74c231d-d1a-3` no longer exists. `merges.jsonl` (22:26:44) shows P328 applied to the main checkout with no conflicts and the worktree removed. So this pass read the merged code in the main checkout (`git diff HEAD -- <file>`), read-only. The tester step for this pass ran nothing (infrastructure: missing worktree). That is not a test failure of the fix.
**Evidence level:** code, the widget tests already in main (not re-run here, Flutter not run per the brief), and renders in main's `App/build/ux/` made at 22:38, after the merged code (22:26:44). No emulator or phone.

### UX-2903 · fixed
- `App/lib/widgets/note_task.dart:30-45`: `meetingNotesProvider` is a plain (keep-alive) `FutureProvider`, not `.autoDispose`. It watches `taskProvider.select(...)` mapped to a comma-joined String of note ids, so it re-reads the marks only when a note comes or goes. Value equality on the String means task edits and reloads that keep the same notes don't re-read. The `captureOwnerProvider` watch (:48) and the try/catch returning `{}` are kept. The doc comment no longer says "read again each time a note's page opens". No provider cycle: `task_provider.dart` doesn't read `meetingNotesProvider`.
- `App/lib/screens/main_shell.dart:88-92`: `ref.listen(meetingNotesProvider, (_, _) {});` sits next to `noteTasksProvider`, and the comment names both reads (R1-P318-1, UX-2903).
- `App/lib/screens/task_detail_screen.dart:296-302`: `holds = !linksRead && task.isNote && any open step`. At :573 `if (holds)` draws the invisible, untappable «Crear tarea» placeholder (`Visibility`, `maintainSize`, no semantics). At :606 «Editar nota» is outlined when `holds || made != null || makesTask`. While either read is pending, a meeting note with open steps never shows the single filled «Editar nota». Once read, «Crear tarea» takes the held place and «Editar nota» doesn't move or change style. The bar's copy, button order and the non-note task bar are unchanged in the diff.
- Acceptance 1–2 (first frame while marks load, 1× and 2×): `App/test/meeting_screens_test.dart:4312-4357`. A `Completer` delays the marks. On the first frame there's no filled «Editar nota», there's one outlined «Editar nota» and the placeholder. After the read, filled «Crear tarea» takes `held`, «Editar nota»'s rect equals `first`, and at 2× `held.bottom <= first.top`.
- Acceptance 3 (shell open, opened twice): `:4402-4421` uses the real provider through `MemoryMeetingNoteMarks` under the real `MainShell`. «Crear tarea» shows on the first onstage frame of both opens, and `reads` stays unchanged.
- Acceptance 4 (note saved after the first read): `:4423-4442`. A note added along with its mark, then `showLocal()`, re-reads the marks (`reads` grows), and the page's first frame shows «Crear tarea».
- Acceptance 5 (recipe): `:4444-4470`. Croquetas with open steps, marks read, shows one filled «Editar nota» and no «Crear tarea»/«Ver tarea» on the first frame and when settled. Render `notes/note.with-steps.es.light.1x` (22:38) shows a single filled, centred «Editar nota». Render `meetings/note.create-task.es.light.2x` (22:38) shows filled «Crear tarea» above an outlined «Editar nota» of the same height. Both renders show only the settled state. The first frame is covered only by the widget tests.
- The test fake (`App/test/support/note_task_fakes.dart:78-99`) keeps existing callers working: `meetingNotesOverride([ids, ready])` has optional positional parameters.

### Regressions
None.

Checked and not counted:
- A recipe note with open steps, opened during a cold-start read, shows outlined «Editar nota» plus the hidden place, then settles to one filled «Editar nota». The brief chose this trade-off in step 3. It's only possible in the first milliseconds after a cold start, since the shell pre-reads both providers. Covered by the device check.
- A note whose steps are all done but which has a made task (`made != null`) can still go from a single filled «Editar nota» to «Ver tarea» + outlined while links are unread. The old condition (`!linksRead && makesTask`) had the same flaw, because `makesTask` also needs an open step. So the change didn't cause it.
- The kept provider keeps a failed read (`{}`) until a note comes or goes or the account changes. Before, every open retried. It's a local one-row read, so this is unlikely. Noted only.

### Device checks still owed
- On the emulator or a phone: open a meeting's note from Notas several times, and from the notes-ready notification on a cold start. The bar must never flash the single «Editar nota» before «Crear tarea». Also, on a cold start, open a recipe note with open steps as fast as possible: the bar must not visibly switch from outlined to filled.

### Memory notes
- Riverpod 3: a `ref.listen` in the shell's build keeps a keep-alive provider live under pushed pages. A `ref.watch` in a hidden widget is paused.
- Pattern: note-page bar providers (`noteTasksProvider`, `meetingNotesProvider`) are keep-alive and pre-read in `main_shell.dart`. While either is unread, the bar holds «Crear tarea»'s place for any note with an open step (UX-2903).
- Process: a verify step can arrive after its worktree was merged and removed. Check `merges.jsonl`, then verify read-only against the main checkout's `git diff HEAD`.
