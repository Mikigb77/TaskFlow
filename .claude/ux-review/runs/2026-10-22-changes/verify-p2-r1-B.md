## UX verify — 2026-10-22-changes, plan 2, round 1, area B (P253, P256) — 2026-10-22
**Verdict:** all three findings fixed in code and in current renders; no regressions caused by the change. Device checks (two phones/two accounts at 0cf3431; real mic at largest font) stay with the main session.

Renders checked fresh: `find App/lib App/assets -newer App/build/ux/reminders/sheet.strength.es.light.1x.png` lists nothing (renders 2026-10-23 00:56; code 00:14–00:24).

### UX-1912 · fixed (P253)
- `App/lib/models/reminder_plan.dart:71-88`: `strengthStart = 28` with the brief's doc; Suave `PlanPhase(strengthStart, 4, 7)`, Normal `(…, 8, 3)`, Intenso `(…, 15, 2)`; daily phases unchanged; `PlanPhase.longest`, custom plans untouched.
- Renders: `reminders/sheet.strength-far.es.light.1x/2x`, `ca.light.2x` read «Cada 3 días desde 4 semanas antes, y a diario la última semana» / «Cada 3 dies des de 4 setmanes abans, i cada dia l’última setmana», «15 avisos · próximo: jue, 26 de nov, 09:00»; the dots start at the 4-week point, the left of the strip empty, which shows the later start without words. `sheet.strength` (3 weeks) still «13 avisos · próximo: mañana, 09:00» (INDEX).
- Tests: groups `P253 · UX-1912` in reminder_plans_test.dart:1076, reminder_plan_engine_test.dart:945, reminder_plan_sheet_test.dart:4215 (tester: pass).

### UX-2014 · fixed in code (P256); phone check pending
- `App/lib/widgets/reminder_control.dart:183-196`: `reminderRingsHere` (same `TaskDatabase.reminderBlock` rule as the engine) and `reminderShared`.
- `reminderLine` (:487, :502, :556-559): plan counts only when it rings here; `schedule: ringsHere ? task : null` → single list for a task given to someone else; `shared:` passed. `ReminderChip` key (:580) follows. `ReminderControl` (:648-707) the same. Form's closed-details line `task_editor.dart:956-957` uses `_responsibility`. Capture card passes `task: task` (`capture_review_editor.dart:593`).
- Sheet: `_JustYou` (`reminder_plan_sheet.dart:769-786`) above each `_Apply` (:590, :648, :741), bodyMedium, onSurfaceVariant, key `reminder-plan-just-you`. Copy in all three ARBs with @description (`app_en.arb` reminderPlanJustYou).
- Offer: `reminder_ask_sheet.dart:235-255` `ringsHere` = reminderBlock null, unknown project not asked; P255's decline count untouched.
- Renders: `sheet.shared.es.light.1x` and `ca.light.2x` (viewed): «Estos avisos son solo para ti.» / «Aquests avisos són només per a tu.» directly above Listo / Fet, uncut at 2×. `sheet.given-to-someone.es.light.1x` (viewed): «Recordatorio», «Desactivado ✓», «Elegir hora del aviso» only.
- Walk (newcomer, shared «Todos» task): chip → sheet → «Hasta la fecha límite» → reads the line right where the decision is made → Listo. 3 taps, unchanged; one new line of 6 words, only on shared tasks.

### UX-2021 · fixed (P256)
- `reminder_plan_sheet.dart:118-120` `_wordsScroll`, passed to the field (:663); after each partial in `_hear` a post-frame `jumpTo(maxScrollExtent)` (:423-427), guarded by `_closed`/`hasClients`; disposed (:218). Field stays 4 lines, unfocused while listening.
- Render `sheet.your-way-listening-long.es.light.2x` (viewed): field ends «…mañana y por la / tarde»; «Dejar de escuchar» and «Escuchando» in view. Test reminder_plan_sheet_test.dart:5825 (maxScrollExtent > 0, pixels at max).

### Regressions
None caused by these packages. Checked: watch-outside-build in the tap closures (`reminderShared` in onTap) is allowed in flutter_riverpod 2.5 (only `listen` asserts); muted-project tap on the capture card opens the project sheet, not a route away from capture; deadline-only task given to someone with a plan now reads as with no plan, as the brief asks.

### Seen, not caused by this change (for the organizer)
- `sheet.strength-far.ca.light.2x`: the strip's end label «dt., 22 de des.» wraps its final «.» alone onto a second line (`reminder_plan_sheet.dart:875-884`, each label `Expanded` = half width). Pre-existing for any far date with an abbreviated Catalan month at 2×; P253's new preview only exposes it. Possible fix: give the end label its intrinsic width (`Flexible`/no `Expanded` on «Avui») or `softWrap: false` with `FittedBox` scaleDown. S1, not filed here.

### Memory notes
- Plans are per account (D6): plan rows show only where `reminderRingsHere`; shared tasks get «Estos avisos son solo para ti.» above Listo; a plan on a task given to someone else is invisible everywhere (chip, form line, capture card).
- Strengths cap at 28 days (Suave 8, Normal 15, Intenso 22); custom/said rhythms reach up to 366.
- «A tu manera» field follows newest words while listening (scroll to end), matching capture's live words.
