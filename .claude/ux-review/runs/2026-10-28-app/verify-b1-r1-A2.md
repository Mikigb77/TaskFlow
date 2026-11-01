## UX verify — run 2026-10-28-app, b1 round 1, area A (P275) — 2026-11-01

**Verdict:** all five findings fixed; one minor regression (the new «Añade una fecha para repetir» row is a dead imperative).
**Evidence levels:** code read in the working tree (`git diff HEAD`), the tester's P275 widget tests read, and the renders and AUDIT from 2026-11-01 02:35–02:39. They are newer than `capture_review_editor.dart` and `reminder_control.dart` (02:25): `find App/lib App/assets -newer` returns nothing. No device evidence.

### Findings

**UX-2205 · fixed**
- `App/lib/widgets/capture_review_editor.dart:709-716`: an 8 × 48 dp opaque strip sits between a collapsed row's title and its ✕. The strip opens the card, is left out of semantics, and never removes the task.
- AUDIT `capture/result · several` (es 1×, es 1.3×, es 2×, es dark, ca 2×, en 2×, 393): there's no title→✕ gap problem any more. The title's hit area is 230 dp wide, down from 238. The gaps still listed are the row's vertical 0 dp to its date line, which isn't part of this finding.
- `reminder_control.dart:946-954`: «Activar recordatorios» has 8 dp vertical padding. AUDIT `reminders/capture-card · plan-reminders-off` es 2×: 8 dp below the reminder row and 9 dp above «Más opciones». Render: `reminders/capture-card.plan-reminders-off.es.light.2x.png`.
- Tests: `review_tasks_test.dart` P275 checks a gap of 8 dp or more at es 1×, es 2× and ca 2×, and that a tap 2 dp left of ✕ opens the card and removes nothing. `reminder_plan_sheet_test.dart` P275 has 4 tests.

**UX-2207 · fixed**
- `capture_review_editor.dart:775-776`: a note's field uses `noteBody` and `noteHint`; a task keeps `notes` and `addNotes`.
- AUDIT `notes/note-capture · result`: TalkBack reads the text field as «Tu nota». The es 2× render shows the «Tu nota» label.
- The tests check the hint after focusing the field, in es 1×, es 2× and ca 1×.

**UX-2208 · fixed**
- The `TextButton.icon` «Quitar» is gone from «Más opciones». ✕ (batch) and Cancelar (one task) remain.
- `reviewRemove` is removed from all three ARB files and from the generated code, and nothing else used it.
- `capture_review_editor.dart:907-919`: with no day, the repeat row reads `repeatNeedsDate`, with no chevron and no tap.
- `compact` (`voice_task_screen.dart:4396`) means that any card sitting beside another card has ✕. So removing «Quitar» leaves no card without its own way out.

**UX-2211 · fixed**
- «Más opciones» (`:848-881`) is wrapped in `Semantics(expanded, hint, onTapHint)`, the same pattern as `reminder_plan_sheet.dart:496-502`. AUDIT reads «Más opciones» hint «Contraído» [collapsed].
- A collapsed title (`:690-708`) has `MergeSemantics(Semantics(expanded: false, onTapHint: editTask))`. AUDIT reads «Comprar pan y leche» [collapsed].
- Caveat: unlike «Más opciones», the title carries only the expanded flag, without a `hint` text. Whether TalkBack says «Contraído» there depends on the Android/TalkBack version. «Toca dos veces para editar tarea» still tells the person what the tap does. Device check: TalkBack on the TaskFlow_Review emulator.

**UX-2212 · fixed**
- `_dateLine` (`:379-386`) drops the time while a `schedule` question with times is open, and the TalkBack label uses the same string.
- The fixture in `test/ux_previews/capture_previews.dart:714-717` no longer sends a time.
- Render `capture/result.question.es.light.1x.png`: «jue, 5 de nov» above «¿A las 5 de la mañana o de la tarde?». AUDIT: «Fecha y hora: jue, 5 de nov».
- The tests check the line after answering 17:00, and two batch rows answered one at a time.

### Regressions

**R1A2-1 · Severity 2 · «Añade una fecha para repetir» does nothing when tapped**
- Where: `App/lib/widgets/capture_review_editor.dart:907-919`, the result card › «Más opciones» on a task with no day.
- The moment: "It says add a date — I tap it — nothing."
- What happens:
  - The row now gives an instruction («Añade una fecha para repetir»), but it has no tap. It keeps the primary-coloured icon of its tappable neighbours (recurring problem 35).
  - Before, it read «No se repite», a statement, so the dead tap invited nothing.
  - On the same card, the sibling no-day line «Para recordártelo, ponle un día.» (`_needsDayLine`, `:451-475`) opens the date sheet.
  - In the form (`task_editor.dart:1322-1334`), the row keeps a chevron and a tap, so "as in the form" holds for the words only.
- Why it fails: an action label with no action is a gulf of execution (Norman 2013). It is also inconsistent with the line next to it (Nielsen's heuristic 4).
- Fix: when `task.dueDate == null`, make the row's tap `_schedule`, the date sheet, as `_needsDayLine` does, with its chevron. No copy change.
- Verify: on a one-task result with no day, open «Más opciones» and tap «Añade una fecha para repetir». The date sheet opens, and once a day is picked the row reads «No se repite» and opens the repeat editor.
- Evidence: verified in code. No render shows this state.

No other regressions in the changed files:
- the 8 dp padding around «Activar recordatorios» shows no gap or clipping problem anywhere in AUDIT;
- `reviewRemove` has no users left;
- the note label change only affects notes.
