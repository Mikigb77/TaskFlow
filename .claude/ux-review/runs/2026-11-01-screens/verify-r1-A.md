## UX verify — run 2026-11-01-screens, round 1, area A (P314) — 2026-11-01
**Verdict:** Ship. Both findings are fixed at widget-test level, and the change caused no regression in the entry flows it touches.
**Scope:** P314 (UX-2643, UX-2644). Diffs read: `App/lib/main.dart`, `App/lib/screens/edit_task_screen.dart`, `App/lib/widgets/task_editor.dart`, and the P314 groups in `App/test/capture_free_dictations_test.dart` and `App/test/capture_sheet_test.dart`. The task_editor.dart hunk on the save button's `textAlign`/`textWidthBasis` belongs to P317 (UX-2634, area D) and isn't judged here.
**Evidence level:** code and widget tests. No preview covers entries from outside the app (the conventions say so), and P314 changes nothing drawn, so no render was needed. The device checks in P314 are still the owner's: the TaskFlow_Review emulator, then a phone.

### UX-2643 · fixed
- `NewTaskRoute.untouched` (edit_task_screen.dart:133-137) sits next to `empty`, and its doc names UX-2643.
- `untouchedEntryFormOnTop` (edit_task_screen.dart:170-188) is true only for the current `NewTaskRoute` opened `blank` that is both `empty` and `untouched`.
- `_markRoute` (task_editor.dart:343-351) sets `untouched = !_detailsExpanded && !_pickingFile && DeepCollectionEquality().equals(_edited().toMap(), _unchanged)`, the same comparison `_save` uses (:601). Three things keep it current:
  - every rebuild calls it (`build`, :876);
  - the `_title` and `_notes` listeners call it (:318-319);
  - `didChangeDependencies` calls it when the route is first attached (:334).
- `_openEntries` closes a form only when `untouchedEntryFormOnTop(navigator)` is true (main.dart:226-227). Absorbing still uses the title-only `emptyTaskFormOnTop`, unchanged (main.dart:208-214), as the brief settled.
- The brief's caution about `_responsibility` doesn't apply here. A blank form gets a `listId` only from Calendar's scope, and only when `listCanEditProvider` already sees the lists loaded (edit_task_screen.dart:229-231; task_lists_provider.dart:16-19). With no lists, `listId` is null and the derived assignment stays 'personal'. So the whole-map comparison is stable from the moment the form opens.
- Walkthrough, newcomer at 5 dictations left: the shortcut's form → taps «Mañana» → goes Home → taps the widget's mic. The listening sheet opens over the form; Cancelar shows the form with «Mañana» still chosen. Before this fix, «Mañana» was lost without a word.
- Tests: the P314 group in capture_free_dictations_test.dart (5 tests) matches acceptance checks 1–5 one for one:
  - «Mañana» at 5 left, and at 0 left;
  - a step, with Más detalles closed again;
  - Más detalles opened only;
  - absorbing at 0 left.
  P313's untouched cases are unchanged and pass in the whole suite (tester's report).

### UX-2644 · fixed
- `takes()` (main.dart:206-214) is written once, as a local function in the `if (!shared)` block. It runs before any pop (:215-218) and once more right after the single `navigator.pop()` (:228-232). When it matches, the entry is acknowledged and nothing opens.
- Only what the rules close is popped: an empty sheet of the other mode with no recording, or an untouched blank form.
- The comment above the block (main.dart:189-204) names UX-2643 and UX-2644 and is true.
- Test: the P314 group in capture_sheet_test.dart (:4325 on), with the P313 helpers lifted out unchanged. Voice (recorded, paused) → text → voice leaves one sheet, and it is the paused one: «Grabación conservada en este teléfono» is hit-testable. Also checked there:
  - all 3 entries are acknowledged;
  - no recorder is built for the second voice entry, and the first recorder started once;
  - the capture keeps its `audioPath`;
  - no keep-or-discard question appears.

### Regressions
None found. Edge cases checked in code:
- **A title typed and then cleared, or Más detalles opened and then closed with nothing in it.** The form is untouched again and an entry may close it. Nothing is held, so nothing is lost.
- **A file pick in progress.** `_pickingFile` makes the form "touched", so an entry opens over it and never disposes the editor mid-pick. That is better than before.
- **Re-checking after closing a sheet that has an entry's form under it,** for a free account (VOICE sheet over a form with «Mañana», then a TEXT entry). The uncovered form takes the entry: one form shows, with «Mañana». This is the intended absorbing rule.
- **`_markRoute` on every build.** It is one map comparison per frame of the form, and nothing the user would notice.

### Notes for the organizer
- The P314 device checks remain open for the owner: they need the emulator, then a phone.
