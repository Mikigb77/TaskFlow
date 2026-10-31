## UX verify — 2026-10-22-changes, plan 3 round 1, area B (P259) — 2026-10-23

**Verdict:** Ship after one small fix. UX-2024, UX-2027 and UX-2028 are fixed. UX-2025 is fixed on screen, but on the capture card's collapsed row TalkBack still announces Marta's line as disabled.

Evidence levels: verified in code (`git diff HEAD`), the renders re-rendered at 11:54 today (no file under App/lib is newer than them), and AUDIT.md's TalkBack tree. TalkBack speech itself still needs a device check.

### Findings

**UX-2024 · fixed**
- `App/lib/widgets/reminder_control.dart:136-140`: `_Reason.text(context)` takes no value. A task given to someone else always reads `reminderForPersonOnly(person)`.
- `reminderForPerson` is gone from all three ARB files. `@reminderForPersonOnly` carries the new description (`app_en.arb:764-772`).
- The same text reaches four places, because each one goes through `reminderLine` or `ReminderControl`:
  - the chip (`:558-560`);
  - the form's and the card's row (`:779-785`);
  - the collapsed row (`capture_review_editor.dart:411-438`);
  - the subtitle of «Más opciones» (`:835`).
- Renders: `reminders/task-line.given-to-someone.es.light.1x` shows «Recordatorio para Ana» with no value, although the task carries 60 minutes. The ca 2× render shows «Recordatori per a Ana», whole, with its bell.

**UX-2025 · partly**
- Fixed:
  - **The chip.** `ReminderChip` (`reminder_control.dart:625-645`) draws a plain `Chip` in `onSurface` when the line has no tap. AUDIT reads it as «text Recordatorio para Ana», with no button and no tap.
  - **The form and card rows.** `ReminderControl` (`:687-692`, `:741-744`) decides the person line before `dated`. That gives no tap, no chevron, no «Activar recordatorios» (`blocked` needs `reason == null`), and no loading or error lines. The undated row still reads the person line.
  - **«Recordar antes de».** It is hidden by `showReminderAnchor: !reminderSomeoneElses(...)` (`task_editor.dart:1047-1050`, `capture_review_editor.dart:886`, `task_planning_control.dart:175`). «Fecha límite» stays.
  - **The needs-day line.** `needsDay` excludes someone else's task (`capture_review_editor.dart:574-580`).
- Not fixed: **TalkBack on the collapsed row.** `capture_review_editor.dart:415-419` still sets `enabled: onTap != null`.
  - Marta's line has no tap, so the node is now `hasEnabledState` and not enabled. TalkBack would say «Recordatorio para Marta, desactivado», which reads as "the reminder is off": the switched-off control the brief rules out.
  - The tester's check (`reminder_plan_sheet_test.dart:6670`) asserts only `isButton: false, hasTapAction: false`, so it passes.
  - Before P259 this line had a tap (enabled). The disabled state is new for it.
  - Fix: `enabled: line.onTap == null ? null : widget.enabled`. That keeps UX-462's "disabled while saving" for lines that do have a tap. The test should also assert that the node has no enabled state.
  - Device check: TalkBack on Marta's collapsed row.

**UX-2027 · fixed**
- On a shared task, `_chooseReminder` passes `note: reminderPlanJustYou` (`reminder_control.dart:410`). `_pickFrom` draws it under the title, padded 24/0/24/8, in bodyMedium onSurfaceVariant, with the key `reminder-plan-just-you` (`:471-481`).
- `chooseDefaultLead` passes no note, so the line never shows in Settings.
- «Recordar antes de» gets `helperText: reminderNote, helperMaxLines: 3` (`task_planning_control.dart:180-184`). The editor and the card pass it only when `reminderShared(...)`.
- Renders: `sheet.shared-repeating` es 1× («Estos avisos son solo para ti.») and ca 2× («Aquests avisos són només per a tu.», whole on two lines). AUDIT's order: «Recordatorio», then the note, then the first row.

**UX-2028 · fixed**
- `_Reason.hidden` (`reminder_control.dart:131`) covers a task that isn't this account's and names nobody. When it applies, nothing shows:
  - `reminderLine` returns null (`:518-519`);
  - `ReminderChip` and `ReminderControl` build `SizedBox.shrink`;
  - the detail drops the chip and its 16 dp gap (`task_detail_screen.dart:162-165`, `:374`, `:404`);
  - the card hides the row, the collapsed line, the subtitle of «Más opciones» and the needs-day line (`capture_review_editor.dart:582-593`);
  - «Recordar antes de» is hidden.
- An unassigned task in a project this account manages has no `notForAccount` block, so it reads as before.

### Regressions

**R1B-1 · Severity 1 · Chip with no tap looks like the tappable chips**
- Where: `App/lib/widgets/reminder_control.dart:628-638`, the task detail on a task given to someone else, and an archived project's chip.
- The moment: "It's a button like 'Matemáticas' next to it. I press it and nothing happens. Is it broken?"
- What happens: the plain `Chip` keeps the same outlined 8 dp border and height as the tappable project, assignee and reminder chips. The render `task-line.given-to-someone.es.light.1x` shows «Recordatorio para Ana» in the same box as «Matemáticas» and «Ana ▾». Before P259 a tap did something, and the archived chip looked disabled at 38%. Now both are full-contrast boxes that do nothing.
- Why it fails: a signifier that promises an action the control doesn't have (Norman 2013). The newcomer is afraid of breaking things and reads a dead tap as a fault.
- Fix: draw the no-tap line as information, not as a control. Use `side: BorderSide.none` with a transparent background, or the icon and text in a `Row` like the card's collapsed line. Keep the words, the bell and the full contrast. No new copy.
- Verify: re-render `reminders/task-line.given-to-someone` (es 1×, ca 2×). The reminder line has no outline, while the «Matemáticas» chip keeps one.
- Evidence: seen in a current render, verified in code.

### Noted, not regressions
- **Muted project.** A task given to Ana in a project muted on this phone still reads «Sin recordatorio: proyecto silenciado» and opens «Novedades del proyecto». So does an unassigned «Club» task there: it shows the muted line rather than nothing. The brief keeps muted and archived words and taps, and `reminderBlock` checks muted before the owner, so this matches the behaviour before P259.
- **Contract.** Nothing to add to Backend/docs/REMINDER_PLANS.md from this package.
