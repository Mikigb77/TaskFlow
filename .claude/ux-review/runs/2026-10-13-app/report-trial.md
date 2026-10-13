# UX report — 2026-10-13-app, trial batch

**Verdict:** 8 of the 9 findings are fixed after 3 rounds. 5 are verified, and 3 are verified in code and wait on two phone checks. The tests passed in every round. UX-421's Catalan part waits on the two-tab decision (U13), and nothing was escalated.

The trial ran two packages from the main plan: P11 (search ignores accents) and P28 (text fields and tabs you can see). Both fixed their findings, but together they caused five small regressions. Rounds 2 and 3 fixed all five, and round 3 caused no new ones.

Closed on 2026-10-13. Where the details are, all in the run folder:
- **Briefs:** plan.json (P11 and P28), plan-trial-r2.json (P45 and P46) and plan-trial-r3.json (P47).
- **Round summaries:** "Round 2 (trial)" and "Round 3 (trial)" in plan.md.
- **The reviewer's notes:** the five verify-trial-r*.md files.

## Verified (5)
- **UX-303 · Search fails when Spanish or Catalan users skip accents** (P11, round 1).
  - "medico" finds "Médico", and "collegi" finds "Col·legi".
  - This works in all four searches: Tareas and project pages, Notas, Proyectos, and the "Todos los proyectos" sheet.
  - Nothing changed on screen.
- **UX-412 · Text-field outlines are nearly invisible** (P28, round 1). Field outlines went from 1.28:1 to 3.79:1 in light, and from 1.51:1 to 4.85:1 in dark.
- **UX-413 · The selected tab is hard to tell apart** (P28, round 1).
  - The selected tab is bold and dark, with a filled icon.
  - The other tabs are grey and regular, with outlined icons.
- **UX-425 · Typing "col·" briefly shows "nothing matches"** (P46, round 2; a regression from P11).
  - A Catalan word with l·l now stays listed at every keystroke, however the dot is typed.
  - The reviewer traced every prefix of ten such words, in all three spellings. Nothing was missed, and nothing P11 found is lost.
- **UX-428 · Tab icons no longer match the Tasks and Notes screens** (P45, round 2; a regression from P28).
  - Tareas and Notas now use their tab's icon inside the screens.
  - One old Notas icon is left, on the capture page's "Revisar nota" button. It goes with that page in P35.

## Verified in code, waiting on your phone (3)
The reviewer found these fixed, and tests lock them. One part of each can only be confirmed on a phone.
- **UX-427 · Spanish "Calendario" tab label breaks mid-word at 320 dp** (P45, round 2; a regression from P28).
  - The tab labels no longer inherit letter spacing, and below 360 dp they stop growing at 1.2×.
  - "Calendario" now fits its 80 dp tab with 2.1 dp to spare.
  - This is a stopgap until the two tabs.
- **UX-432 · Below 360 dp, tab tooltips lose large text** (P47, round 3; a regression from P45).
  - P45 capped the text size of the whole tab bar. That also shrank the name that pops up when you long-press a tab.
  - Now only the label is capped. At 2× text, the pop-up is 28 px again, not 16.8 px.
- **UX-426 · Empty search still folds every text on each rebuild** (P46, round 2; a regression from P11).
  - With nothing typed, search no longer processes any text, so a task change now costs less than it did before P11.
  - Whether typing stays smooth with hundreds of long notes needs a phone.

## Still open
- **UX-421 · Tab labels are 11 sp; Catalan overflows** (S1). It's partly fixed, and what's left waits on a decision.
  - P28 made the labels 12 sp, and a test locks that.
  - Catalan "Configuració" still needs about 93 dp in an 80 dp tab on a 320 dp phone. Only the two tabs (U13) fix that. Renaming it isn't recommended: it's Android's own Catalan word for Settings.
  - It waits with U13, under "Decision needed".
  - P28's phone check asked for this fit by mistake, so it's withdrawn.
- **Five older problems the reviewers noticed along the way.** The trial didn't cause them. Each one is queued in the main-plan package that already edits its file:
  - **UX-429** (S2): the "Todos los proyectos" sheet leaves no room for the keyboard → P24. Needs a phone.
  - **UX-430** (S1): a Proyectos search that matches nothing shows only blank space → P26.
  - **UX-431** (S1): the time-zone search ignores accents → P18.
  - **UX-433** (S1): the line above the tab bar never shows → P23.
  - **UX-434** (S1): search treats ' and ’ as different characters → P16. Needs an iPhone.

## Escalated
None. No finding failed twice: each regression was fixed in the round after it appeared.

## Checks for your phone
1. **Narrow phone with the largest text: UX-427 and UX-432, in one session.**
   - Set up: Spanish, Android's font size at its largest, on a phone narrower than 360 dp (or a 360 dp phone with Display size raised).
   - Every tab label sits on one line, and the icons stay inside the bar.
   - Long-press "Calendario": its name pops up clearly bigger than the tab label. From Android 14, text doesn't scale linearly, so it may be a little under twice the size. It just has to be clearly bigger.
2. **Search speed with many long notes: UX-426.**
   - Set up: a profile build on a low-end Android phone, with about 300 notes of about 1,500 characters each.
   - Complete a task on Calendar, then type in the Notas search. No frame should take longer than 16 ms.

One check is withdrawn: "Configuració fits its tab at 320 dp and 1.3× text" (P28, UX-421). It can't pass with four tabs.

## Files changed
**App code (7):**
- App/lib/services/text_search.dart (new): P11 and P46.
- App/lib/screens/home_screen.dart: P11 and P45.
- App/lib/screens/notes_screen.dart: P11 and P45.
- App/lib/screens/task_lists_screen.dart: P11.
- App/lib/widgets/project_scope_control.dart: P11.
- App/lib/theme/app_theme.dart: P28 and P45.
- App/lib/screens/main_shell.dart: P28, P45 and P47.
  - Its _labelFontSize = 12 (:18) repeats the theme's 12 sp tab label (app_theme.dart:126). If one changes, change the other too.

**Tests (8):**
- New: App/test/text_search_test.dart, App/test/main_shell_test.dart, App/test/home_screen_test.dart and App/test/project_scope_control_test.dart.
- Changed: App/test/appearance_test.dart, App/test/notes_ui_test.dart, App/test/task_lists_widget_test.dart and App/test/support/design_fixtures.dart.

**Also worth knowing:**
- No copy changed, so no ARB files were touched.
- Nothing from the trial is committed yet. HEAD is still 29a84ff, and all of these changes are in the working tree on dev.
- App/config/ and the build/ folder at the repo root are also untracked, but no package touched them.

## Locked by tests
Every verified finding is now protected by a test.

| Finding | Status | Tests |
|---|---|---|
| UX-303 | verified | Unit: text_search_test.dart:5-51. One widget test per search: notes_ui_test.dart:156 (Notas: es, ca and en, 2× text, 320 dp, both themes), appearance_test.dart:340 (Tareas), task_lists_widget_test.dart:186 (Proyectos) and project_scope_control_test.dart:12 (the sheet; picking a match sets the chip). |
| UX-412 | verified | appearance_test.dart:376: the border is `outline`, and reaches at least 3:1 against the field, the page and a card, in both themes. |
| UX-413 | verified | appearance_test.dart:416: label weight and colour by state, in both themes. :457: every tab swaps to its filled icon. |
| UX-425 | verified | text_search_test.dart:53-85: every prefix of three spellings of col·legi. notes_ui_test.dart:200-209: Notas keeps the note listed at `col·`. |
| UX-428 | verified | home_screen_test.dart:27-92: the Tareas and project-page empty states, and a project page's Notas button. notes_ui_test.dart:223-272: the Notas empty state and every row. Both in es and en. |
| UX-427 | phone check pending | main_shell_test.dart:116-187, at 320×640: every label on one line (es at 1.3× and 2×, en at 1.3×; with Calendario selected, then Tareas); no icon pill above the bar; no letter spacing. Labels are drawn at 14.4, 12 and 15.6 px. |
| UX-432 | phone check pending | main_shell_test.dart:189-265: at 2× text, the long-press tooltip is drawn at 28 px at both 320 and 390 dp, and it stays inside the screen. The label doesn't change. |
| UX-426 | phone check pending | text_search_test.dart:87-104 locks the results: an empty query matches everything, and a long note folds intact. No test can see that an empty query skips the work, so that's a code check (text_search.dart:5). |
| UX-421 | decision | appearance_test.dart:416 locks the 12 sp size. The Catalan fit isn't tested: it waits on U13. |

## Rounds
| Round | Packages | Tests | Reviewer | Regressions |
|---|---|---|---|---|
| 1 | P11 (UX-303); P28 (UX-412, UX-413, UX-421) | Passed. New tests for UX-303, UX-412, UX-413 and UX-421. | Fixed: UX-303, UX-412, UX-413. Partly fixed: UX-421. | 4: R1C-1 → UX-425, R1C-2 → UX-426, R1D-1 → UX-427, R1D-2 → UX-428 |
| 2 | P45 (UX-427, UX-428); P46 (UX-425, UX-426) | Passed. New tests for UX-425 to UX-428. | Fixed: all four. UX-426 and UX-427 need a phone. | 1: R2D-1 → UX-432 |
| 3 | P47 (UX-432) | Passed. New tests for UX-432; UX-427's tests kept. | Fixed; needs a phone. | None |
