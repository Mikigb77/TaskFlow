## UX loop: run 2026-10-18-commands, batch 3, close (2026-10-19)

**Verdict:** All 21 findings in this batch are fixed, in two rounds. 11 are verified. The other 10 are verified in code but still need a phone check. UX-1003 failed once (round 1, partly fixed) and was fixed in round 2. Round 1 caused three regressions, and round 2 fixed all of them (UX-1224, UX-1225, UX-1226). Round 2 caused one more (UX-1227, severity 1). It is a product decision (D12), not a fix. Nothing was escalated.

Evidence: code read (`git diff HEAD`), widget tests from ux-tester and current renders. No device was used.

### Verified (11)
- **UX-1006** · The attach sheet no longer explains older files on a new task (P140)
- **UX-1007** · «Menos detalles» now keeps filled notes, added files and a chosen project on screen (P140)
- **UX-1008** · «Creada por» now reads «Creada por ti» / "Created by you" / «Creada per tu» on your own tasks (P140)
- **UX-1009** · The used-up notice no longer says «el formulario», and the date comes first (P140)
- **UX-1103** · The assignee chip now shows ▾ only when the person can be changed, inside the chip at 2× (P141)
- **UX-1105** · «Paul aún no está en …» for a new project now points at «Compartir» (P141)
- **UX-1106** · There is now one «Nuevo proyecto» row, and a misheard name can be renamed before saving (P141)
- **UX-1107** · «Abrir» after a search keeps the person searched for (P142)
- **UX-1109** · An empty person view now says the person has nothing open and points at «Todas» (P142)
- **UX-1209** · At 2× the auth headings break at spaces, not mid-word (P143)
- **UX-1225** · Renaming a dictated project to an existing project's name now files the task there, and «(nuevo)» goes away (P161; regression R1C-1)

### Verified in code, needs a phone (10)
- **UX-1002** · The keyboard no longer hides the day and time (P139)
- **UX-1003** · The title wraps to 3 lines while typing and shows whole once the keyboard is down (P160; round 1's P139 only partly fixed it)
- **UX-1004** · «Elegir día» is a day-only sheet with no «Listo», and the time picker opens in typing mode (P139)
- **UX-1012** · Chip borders now use `outline` (P144)
- **UX-1104** · The new project's chip reads «Física (nuevo) ▾» (P141)
- **UX-1205** · The address is bold, the resent line names Spam and Promociones, and «Usar otro correo» focuses the email field (P143)
- **UX-1207** · Auth headings name the screen for TalkBack, and the Confirmar spinner is labelled (P143)
- **UX-1210** · The countdown is readable, follows the clock, and has 8 dp before the exit (P143)
- **UX-1224** · A year pick in «Elegir día» no longer applies a day (P160; regression R1B-1)
- **UX-1226** · The dictated project's row has a pencil labelled «Cambiar el nombre» (P161; regression R1C-2)

### Still open
- None of this batch's fixes is still open.
- **UX-1227** (S1 · B · decision D12): after a year pick in «Elegir día», Flutter keeps the same day in the new year highlighted, though nothing was applied. This came from round 2 (R2B-1). The question: accept it as Flutter polish, or build a custom month display. Recommendation: accept it until the phone check. Nothing is lost: the form's chip shows the real day.
- The other open lines in ISSUES.md (for example UX-917, UX-1010, UX-1223, UX-1206) belong to other batches of this run. This close didn't touch them.

### Escalations
None.

### Checks for the owner's phone
1. UX-1002: at the largest font on a 360 dp phone, type a title, tap Mañana, then «Añadir hora» and 17:00. The keyboard should stay down.
2. UX-1003: at the largest font on 360 dp, type a long title, then tap Mañana. Once the keyboard goes down, the whole title shows.
3. UX-1004: «Añadir hora» at the largest font with the keyboard up. The typing-mode time picker fits.
4. UX-1224 / UX-1227: «Elegir día», tap the month header, then 2027. Nothing is applied. Check whether the highlighted day makes you pause (this answers D12).
5. UX-1012: chip borders in light and dark mode on a real screen.
6. UX-1104: with the real model, a dictated new project's chip at 1.3× and 2×.
7. UX-1226: what TalkBack reads for the dictated project row («Nuevo proyecto: …», «Cambiar el nombre», selected).
8. UX-1207: what TalkBack announces when «Confirma tu correo» opens.
9. UX-1205: where Gmail files the code (Principal, Spam or Promociones), and a native speaker's read of «Correu brossa» and «Promocions».
10. UX-1210: leave the app in Gmail for 2 minutes, come back, and Reenviar should be ready.

### Files changed
- `App/lib/widgets/task_editor.dart`, `App/lib/widgets/schedule_editor.dart`
- `App/lib/screens/task_detail_screen.dart`, `App/lib/screens/voice_task_screen.dart`, `App/lib/screens/home_screen.dart`, `App/lib/screens/verify_email_screen.dart`, `App/lib/screens/login_screen.dart`
- `App/lib/widgets/task_list_picker.dart`, `App/lib/widgets/task_assignment_picker.dart`, `App/lib/widgets/capture_review_editor.dart`, `App/lib/widgets/capture_command_cards.dart`
- `App/lib/models/capture_command.dart`, `App/lib/theme/app_theme.dart`
- `App/lib/l10n/app_en.arb`, `app_es.arb`, `app_ca.arb`, and `App/lib/l10n/generated/` (regenerated by `flutter gen-l10n`)
- Tests: `App/test/new_task_form_test.dart`, `capture_free_dictations_test.dart`, `voice_command_cards_test.dart`, `project_people_filter_test.dart`, `email_verification_test.dart`, `task_detail_test.dart`, `appearance_test.dart`
- Ledger: `.claude/ux-review/ISSUES.md`

### Which tests protect which findings
Every one of the 21 has widget tests:
- **`App/test/new_task_form_test.dart`**
  - UX-1002 at `:1372` and `:1393`
  - UX-1003 at `:1431`, `:1475`, `:1490` and `:1543`
  - UX-1004 at `:1588`, `:1672` and `:1701`, plus `App/test/voice_command_cards_test.dart:4898`
  - UX-1006 at `:784` and `:1895`
  - UX-1007 at `:1934`
  - UX-1224 at `:1771`, `:1843` and `:1865`
- **`App/test/voice_command_cards_test.dart`**
  - UX-1103 at `:4818` and `:4859`
  - UX-1104 at `:4493` and `:4558`
  - UX-1105 at `:4567`
  - UX-1106 at `:4661`
  - UX-1107 at `:5029`, `:5040` and `:5052`
  - UX-1225 at `:5188`, `:5215`, `:5229` and `:5247`
  - UX-1226 at `:5282`, `:5382` and `:5398`
- **`App/test/email_verification_test.dart`**
  - UX-1205 at `:2261`, `:2287`, `:2329` and `:2347`
  - UX-1207 at `:2369`
  - UX-1209 at `:2453`
  - UX-1210 at `:2511`, `:2534` and `:2552`
- **Other test files**
  - UX-1008: `App/test/task_detail_test.dart:676`
  - UX-1009: `App/test/capture_free_dictations_test.dart:2604` and `:2654`
  - UX-1012: `App/test/appearance_test.dart:430`
  - UX-1109: `App/test/project_people_filter_test.dart:302` and `:342`

### Rounds
- **Round 1** (plan.json): P139–P144.
  - Tests failed: UX-1003's 40-character check at 2× on 320 dp; every other finding's tests passed.
  - Verification (verify-b3-r1-B/C/D): 17 fixed. UX-1003 partly fixed (its first line scrolled out of view at 2×).
  - Regressions: R1B-1 became UX-1224, R1C-1 became UX-1225, R1C-2 became UX-1226.
- **Round 2** (plan-b3-r2.json): P160 (UX-1003 and UX-1224) and P161 (UX-1225 and UX-1226).
  - Tests passed.
  - Verification (verify-b3-r2-B/C): all 4 fixed.
  - Regression: R2B-1 became UX-1227, a decision (D12, plan-b3-r3.json, which has no packages).
