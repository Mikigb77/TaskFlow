## UX verify — run 2026-10-28-app, batch b2, round 1, area B (P280) — 2026-11-01

**Verdict:** Ship after fixes. All four findings are fixed, but Completar now closes the page under the finger, so a second, hesitant tap lands on Calendar's «Añadir tarea» (R1B2-1).

Evidence: the code (`git diff HEAD`), the UX previews re-rendered at 07:46 (newer than every changed app file; `find App/lib App/assets -newer` is empty), AUDIT.md, and the tester's widget tests. Nothing here was run on an emulator or a phone.

### Findings

| ID | Result | Evidence |
|---|---|---|
| UX-2404 | fixed | `App/lib/screens/task_detail_screen.dart:53-60`: `_toggle` pops the page before it ticks the task, and only when the task is open. «Reabrir» on a task that was already completed keeps the page. While the page leaves, `_leaving` (:49, :142) keeps the task as it was, so the button never flips to «Reabrir». `_pinned` (:45, :137-155) pins the occurrence the page opened with at the first build. No new copy: the message is still `taskCompleted` (task_interactions.dart:27-30). Tests in task_detail_test.dart, group 'P280 · a task’s page': from Calendar, Completar closes the page, ticks the row and shows one «Deshacer», which reopens the task. Opened as Activity opens it, a daily task never shows tomorrow on the page while it leaves, and a second tap doesn't complete tomorrow's occurrence. «Reabrir» keeps the page, now with «Completar». Device check still to do (notification → Completar). |
| UX-2409 | fixed | task_detail_screen.dart:644-650: read-only notes are one container node with label «Notas» (`notes`), or «Tu nota» (`noteBody`) for a note, and the text as its value. It has no button and no tap. note_text.dart:42 always leaves out the SelectableText's own node. The «Enlaces» heading is its own node (:44-50), and each link stays a TextButton. AUDIT `tasks/detail · notes-steps` #10 and `detail · full` #12 read «text «Notas» value «…»», with no unlabelled text field left. The tests cover the reader's «Tu nota», a link as its own button, and that a long press still selects the text. |
| UX-2410 | fixed | task_detail_screen.dart:329-341: one row. «Planificado para» sits over `dayHeading(date, now)` (region.dart:23, which leaves out the year for this year), with « · HH:MM» only when the task has a time. The «Hora / Sin hora» row is gone. A deadline-only task has no date row (`dated`, :210). The deadline row keeps P279's «Venció el …» and drops `deadlineEndDay`, which is now gone from all three catalogs. Renders: `detail.labels.es.1x` shows «martes, 3 de noviembre» with no «Hora» row, `detail.full.es.1x` shows «domingo, 1 de noviembre · 21:00`, and `detail.alert-passed.ca.2x` shows «diumenge, 1 de novembre» on 2 lines, against 3 before. The tests cover ES and CA at 1× and 2×: no «Sin hora», no «Sin fecha» row on a deadline-only task, and the year on a task in another year. |
| UX-2416 | fixed | task_detail_screen.dart:311-319: one `Text`, «#casa · #recados», in `onSurfaceVariant`, with no outline and no tap. Render `detail.labels.es.light.1x` shows it in grey. AUDIT `detail · labels` #8 reads it as plain text, not a button. |

### Regressions

**R1B2-1 · Severity 2 · A second tap on Completar opens «Añadir tarea»**
- Where: `App/lib/screens/task_detail_screen.dart:53-60` (`_toggle` pops at once) → `App/lib/screens/calendar_screen.dart`, the «Añadir tarea» bar. State: a page opened from Calendar → Completar.
- The moment: "I pressed Completar… did it work? I'll press again." Now the phone starts listening for a new task.
- What happens: the page starts to close in the frame of the first tap. A route that is leaving lets touches through to the screen below it. At 360×800 1×, the page's «Completar» covers 640–700 dp from the top (`tasks/detail.labels.es.light.1x`) and Calendar's «Añadir tarea» covers 608–668 dp (`calendar/agenda.busy.es.light.1x`), so the top half of Completar sits on Añadir tarea. The tester's own test hit it: App/test/task_detail_test.dart:1471-1473, "The second tap lands on Calendar, under the leaving page, where «Añadir tarea» sits". From Tareas, the same tap opens whichever row is under it. Before the fix, the second tap reopened the task (UX-2404). Now it opens capture, with the mic, a surprise for the newcomer, who is afraid of breaking something.
- Why it fails: an action that answers by moving its own target under the finger fails error prevention (Nielsen 1994). The newcomer repeats a tap when the result isn't instant (Norman 2013, gulf of evaluation). Primary actions on screens that follow each other share a spot (D, Fitts).
- Fix: on Completar, turn the button into a disabled «✓ Completar» (no new copy) for about 300 ms, then pop, so a quick second tap lands on a dead button. Also ignore taps on Calendar's «Añadir tarea» for about 500 ms after a route above it pops. Either one alone would fix it; the first is smaller.
- Verify: a widget test like 'a hesitant second tap…' that taps the button's spot again at 50 ms, 200 ms and 400 ms after Completar: the capture sheet doesn't open. Then a device check on the emulator: a double tap on Completar.
- Evidence: verified in the code and in the tester's test. Inferred for the phone, which needs a device check, because the button positions there depend on the navigation mode.

**R1B2-2 · Severity 1 · « ·» dangles at the end of the date line**
- Where: task_detail_screen.dart:338 (`'${dayHeading} · ${clockTime}'`). Renders `detail.full.es.light.1x` («domingo, 1 de noviembre ·» / «21:00») and `detail.notes-steps.es.light.2x` («lunes, 2 de» / «noviembre ·» / «09:00»).
- The moment: the time wraps alone to a new line, and the separator is left trailing at the end of the line above.
- Fix: join with no-break spaces, `' · '`, so «· 09:00» wraps together. No copy change.
- Verify: re-render `detail.full.es.1x`: the line reads «domingo, 1 de noviembre» / «· 21:00», or fits on one line.
- Evidence: seen in current renders.

### Not regressions, noted
- The reader's view still reads «Planificado para» and the date as two separate text nodes (AUDIT `detail · reader` #9-10). This was the same before the change, and only the row without a tap does it.
- The «Notas» section heading followed by the «Notas» node repeats the label. This matches what the editable note already did (UX-1521).

### Memory notes
- Task page: Completar now closes the page (`_toggle`) and «Reabrir» stays on it. The occurrence is pinned at the first build (`_pinned`), and the task as it was is held while the page leaves (`_leaving`). Date card: one row, «Planificado para» over `dayHeading` [· time], with no «Hora» row and no date row for a deadline-only task. Labels: one grey text line. Notes: one node (label `notes` or `noteBody`, value the text), and `NoteText` never exposes its own SelectableText node.
- Recurring problem: an action that closes or moves the screen under the finger turns a hesitant second tap into a tap on whatever lies beneath. Check what sits at the same spot on the screen below.
