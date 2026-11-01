## UX verify — run 2026-10-28-app, batch b2, round 1, area D (P289) — 2026-11-01
**Verdict:** Ship after fixes — the capture taps are 60 dp and the wrapped labels are padded and centred, but the theme change broke the return-to-today scroll (UX-1628's test), and the form's identical-looking primary is still 54 dp.
**Walked:** Calendar «Añadir tarea» → listening «Listo» → result «Añadir al calendario» (ES 1×, 2×); Ajustes → Recordatorios (exact alarms off, CA 2×); first-run exact-alarms sheet (ES 2×); Pro screen (CA 2×); Exportar e importar (ES 1×, 2×); Calendarios del teléfono (CA 2×); a confirm dialog (sharing/group.delete-confirm ES 2×). Newcomer at 2×, tremor user.
**Numbers:** capture primary 312 × 52 → 312 × 60 dp; Calendar «Añadir tarea» 320 × 52 → 320 × 60 dp; «primary under 56 dp» flags on capture/*: several → 0; form primary still 312 × 54 dp (7 flags left: form/new-task.*, form/edit-task.*, tasks/project.person-form).
Evidence level throughout: code, current renders (2026-11-01 07:45–07:47, newer than every changed file), AUDIT.md, and the tester's suite log (`App/build/round-check/suite.log`). No device.

### Findings

**UX-2108 · partly**
- Fixed as written: `App/lib/theme/app_theme.dart:99-103` sets `minimumSize: Size(48, 48)` with `VisualDensity(vertical: 3)`, so every FilledButton (tonal and `.icon` included) is at least 60 dp. AUDIT: «Listo» 312 × 60 dp, 12 dp above «Cancelar» (capture/sheet · listening); Calendar «Añadir tarea» 320 × 60 dp; no `capture/*` render has a «primary under 56 dp» flag. Renders `capture/sheet.listening.es.light.2x` and `capture/result.one-task.es.light.2x`: the primary shows whole without scrolling. `App/lib/widgets/task_actions.dart:121-123` takes 2 dp off the top padding (10 → 8) and keeps 12 dp under the button. The tester's P289 acceptance tests all pass.
- Not met: the finding's fix asked for "one place, and the same look everywhere", and the package for every filled button. The form's primary — the confirming tap of every free account (D: the form for free accounts) — is an `ElevatedButton` styled as a filled button (`App/lib/widgets/task_editor.dart:1208`, theme `App/lib/theme/app_theme.dart:104-114`, `minimumSize: Size(48, 54)`). AUDIT still flags it «primary under 56 dp» at 312 × 54 dp in form/new-task.{empty,filled,details,from-dictation,keyboard}, form/edit-task.{existing,long} and tasks/project.person-form (that one labelled «Añadir tarea», like Calendar's 60 dp button). Two identical-looking primaries now differ by 6 dp.
- Fix for what's left: give `elevatedButtonTheme` the same `minimumSize: Size(48, 48)` and `visualDensity: VisualDensity(vertical: 3)` (or make the form's button a `FilledButton`). Verify: no `form/*` or `tasks/project.person-form` render has a «primary under 56 dp» flag.
- The UX-1628 break the tester bisected to this change is reported as R1D-1, not counted here.

**UX-2608 · fixed**
- Theme: 12 dp more padding above and below every filled label (the density's 12 dp), horizontal padding untouched (`app_theme.dart:99-103`).
- `textAlign: TextAlign.center` on all five labels: `App/lib/widgets/reminder_control.dart:420-421`, `App/lib/screens/notification_settings_screen.dart:254-255` and `:267-268`, `App/lib/screens/subscription_screen.dart:264-265`, `App/lib/screens/device_calendars_screen.dart:113`, `App/lib/screens/data_transfer_screen.dart:200-201`.
- Renders: `settings/pro.free.ca.light.2x` «Mostra la / subscripció» centred, about 12–14 dp from the text to the top and bottom edges; `first-run/reminder-question.exact-alarms.es.light.2x` «Permitir «Alarmas y / recordatorios»» centred and padded; `settings/reminders.exact-alarms-off.ca.light.2x` the same. Tester's UX-2608 tests pass.

### Regressions

**R1D-1 · Severity 2 · Return to today no longer scrolls to the top at 2×**
- Where: `App/lib/screens/calendar_screen.dart:406-420` (`_comeBack`, jump in a post-frame callback) with `:385-397` (resume also reloads tasks and phone events); test `App/test/capture_landing_test.dart:1498-1518`.
- The moment: "I opened the app this morning and it's in the middle of today — where's the top?"
- What happens: ES 2× on 360×800, after a landing on a busy Friday that scrolled the agenda, resuming 31 minutes later selects today but leaves the agenda at 321 dp instead of its minimum (`suite.log:150-156`: "Expected: 0.0 (±0.5) Actual: 321.0 — the agenda starts at the top"). «Agenda de hoy» and today's first rows are scrolled out of view: UX-1628's original symptom. The tester bisected it to this package's theme change (the taller primary changes the agenda's viewport and offsets). The 5-minute and after-midnight siblings still pass.
- Why it fails: change blindness / visibility of status — the person returns to a mid-list view with no heading naming the day (Rensink 1997; Nielsen #1).
- Fix: make the return-to-today jump the last word: after the resume's rebuild and reload settle (for example a second jump after the next frame, or cancel any pending landing reveal when `_comeBack` runs), set the offset to `minScrollExtent`. Never shorten the button to make the test pass.
- Verify: `UX-1628: ES 2x on 360x800, after a landing on Friday …` passes with the 60 dp button, and its two siblings still pass.
- Evidence: widget test (suite log); cause not pinned in code.

**R1D-2 · Severity 1 · Centred two-line labels leave their icon stranded at the edge**
- Where: `App/lib/screens/subscription_screen.dart:258-266`, `App/lib/screens/data_transfer_screen.dart:197-201`, `App/lib/screens/device_calendars_screen.dart:107-113` (all `FilledButton.icon`).
- The moment: "What's that little star doing on its own over there?"
- What happens: at 2× the wrapped label now fills the row and centres its lines, so the icon sits at the button's left edge, about 50–60 dp from the text. Renders `settings/pro.free.ca.light.2x` (sparkle at x≈41 dp, text from x≈110 dp), `settings/data-transfer.start.es.light.2x`, `first-run/phone-calendars.not-allowed.ca.light.2x`.
- Why it fails: Gestalt proximity (Wertheimer 1923) — the icon no longer reads as part of the label; F lens.
- Fix: add `textWidthBasis: TextWidthBasis.longestLine` to those three labels, so the text box hugs its longest line and icon + label centre together. (Subtract alternative: drop the three decorative icons.)
- Verify: in those three renders the icon sits 8 dp left of the label's longest line, and the pair is centred.
- Evidence: seen in current renders.

**R1D-3 · Severity 1 · Export's two stacked buttons now pad their labels differently**
- Where: `App/lib/screens/data_transfer_screen.dart:202-205` (`OutlinedButton.icon` «Elegir archivo para importar»), theme `App/lib/theme/app_theme.dart:115-120`.
- The moment: (low vision, 2×) "The green one is neat; the white one's letters touch the border."
- What happens: render `settings/data-transfer.start.es.light.2x`: right under the now padded and centred «Exportar archivo TaskFlow», «Elegir archivo para / importar» is left-aligned and its two lines touch the button's top and bottom edges. Before this change both looked alike; now the pair is inconsistent.
- Why it fails: F lens (the same component family looks the same); AC-3 / WCAG 1.4.4 at 200%.
- Fix: give the outlined theme the same vertical room without changing its 52 dp minimum — `minimumSize: Size(48, 44)` with `visualDensity: VisualDensity(vertical: 2)` (8 dp above and below a wrapped label) — and `textAlign: TextAlign.center` (plus `textWidthBasis: TextWidthBasis.longestLine`) on that label. No copy.
- Verify: in `settings/data-transfer.start.es.light.2x` the outlined label is centred with at least 8 dp to its edges; outlined buttons stay 52 dp at 1×.
- Evidence: seen in a current render.

Not counted: the suite's other two failures (`task_creation_test.dart:64` «14:35»; `appearance_test.dart:343` «Reopen» FilledButton) weren't attributed to P289 by the tester and touch no P289 line. Confirm dialogs (e.g. `sharing/group.delete-confirm.es.light.2x`) now carry a 60 dp filled action beside a 48 dp «Cancelar»: acceptable, not reported.

### Memory notes
- Filled buttons: theme now `minimumSize (48,48)` + `VisualDensity(vertical: 3)` → 60 dp min and 12 dp vertical label padding (P289). The form's primary is an `ElevatedButton` (`task_editor.dart:1208`) with its own theme at 54 dp — check it whenever "every primary" is claimed.
- Recurring: `textAlign: center` on a `FilledButton.icon` label strands the icon at the left edge when the label wraps; the pairing is `textWidthBasis: TextWidthBasis.longestLine`.
- Resume-to-today scroll (UX-1628) is fragile to layout height changes around the agenda; any change to the Calendar's bottom bar height should rerun `capture_landing_test.dart` UX-1628.
- The tester's whole-suite log lives at `App/build/round-check/suite.log` — read failures there instead of re-running Flutter.
