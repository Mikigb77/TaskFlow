## UX verify — 2026-10-13-app · round 2 · area D · P45 — 2026-10-13

**Verdict:** Ship. UX-427 and UX-428 are fixed:
- On a 320 dp phone with large text, Spanish "Calendario" now stays on one line.
- Tareas and Notas now show their tab's icon inside their screens.

There's one severity-1 side effect, R2D-1: below 360 dp, the tooltips that appear when you long-press a tab no longer follow the phone's text size. It doesn't block the round.

**What I checked:**
- **Code:** `git diff HEAD` of the four files. The P45 parts are:
  - for UX-427: `App/lib/theme/app_theme.dart:127` and `App/lib/screens/main_shell.dart:75-83`;
  - for UX-428: `App/lib/screens/home_screen.dart:132,233` and `App/lib/screens/notes_screen.dart:111,170`.
  - The rest of those diffs is P28 (round 1) or P11 and P46 (area C). I didn't judge it here.
- **Tests,** read but not run:
  - `App/test/main_shell_test.dart`;
  - `App/test/home_screen_test.dart`;
  - `App/test/notes_ui_test.dart:223-272`.
- **Renders:**
  - `App/build/calendar-feedback-light.png` and `-dark.png`, from 14:53, are newer than the code (14:41–14:42). I cropped and enlarged the tab bar and measured the label ink.
  - No current render shows Tareas or Notas. `App/artifacts/design/notes-list-*.png` dates from 2026-09-22, older than the code, so it isn't evidence.
- **Label widths,** measured from `App/assets/fonts/Manrope.ttf` with the round-1 model, now without letter spacing.
  - The model still matches the render. At 390 dp and 1.0× text, the selected "Calendario" is 64.9 dp in the model and 64.0 dp of ink in the render. In round 1 the ink measured 66.5 dp.
- **Flutter 3.44.5 SDK:**
  - `material/navigation_bar.dart`:
    - `:46-48`: the text scale applies to the long-press tooltips;
    - `:297-302`: a fixed-height row of `Expanded` tabs;
    - `:506-513`: labels capped at 1.3×;
    - `:598-599` and `:1047-1054`: each tab's tooltip;
    - `:1100-1101`: loose constraints for the label.
  - `widgets/media_query.dart:1238-1251` and `:1438-1463`.
  - `material/tooltip.dart:443-447`: tooltips are 14 sp on Android.
  - `widgets/overlay.dart:1790-1797`: an OverlayPortal's child inherits from wherever the portal sits in the tree.

**Walked:**
- **Switching tabs** (1 tap):
  - the newcomer: Spanish, 320 dp, text at 1.3× and 2×;
  - the low-vision user: the same, plus a long press on a tab;
  - the daily user: 360 and 390 dp.
- **Tareas with nothing to do** → the empty state (newcomer).
- **A project page** → "Notas" → that project's notes (daily user).
- **Notas while empty** → the first note row (newcomer).
- **TalkBack:** tab names and reading order (unchanged).

**Numbers:**

| Label at 320 dp (80 dp tab) | Before P45 (1.3×, 0.25 spacing) | After P45 (1.2×, no spacing) |
|---|---|---|
| ES "Calendario", selected | 86.9 dp, wraps | 77.9 dp, fits with 2.1 dp to spare |
| ES "Calendario", unselected | 82.4 dp, wraps | 73.7 dp |
| EN "Calendar", selected | 72.0 dp | 64.6 dp |
| CA "Configuració", selected | 103.7 dp, wraps | 92.9 dp, still wraps (UX-421, waits on U13) |

- **Label size on screen,** below 360 dp with text at 1.2× or more: 15.6 → 14.4 px.
  - At 360 dp and wider it stays 15.6 px. At 360 dp and 1.3×, "Calendario" is 84.4 dp in a 90 dp tab, so the 360 dp threshold leaves no gap.
- **Icons per concept:**
  - Tareas: 2 → 1.
  - Notas: 2 → 1 on Tareas, Notas and project pages. One old icon remains in voice capture, left there on purpose.
- **Unchanged:** the number of tabs, the tap targets (80×72 dp at 320 dp) and the taps to switch tabs.

### Results

**UX-427 · fixed** (the device check is still to do)
- **`app_theme.dart:122-130`:** the label style now sets `letterSpacing: 0` (:127).
  - 12 sp is kept, with w800 in `onSurface` when selected and w500 in `onSurfaceVariant` otherwise.
- **`main_shell.dart:75-83`:** below 360 dp, the bar sits inside `MediaQuery.withClampedTextScaling(maxScaleFactor: 1.2)`.
  - From 360 dp up it isn't wrapped, so Flutter's own 1.3× cap applies.
  - `labelBehavior` and the 72 dp height are unchanged.
- **Tests,** all with the real font:
  - `main_shell_test.dart:113-135`: at 320×640, every label lays out on one line in three cases — Spanish at 1.3×, Spanish at 2.0× and English at 1.3×. Each case runs first with Calendario selected, then with Tareas. No icon pill rises above the bar.
    - The check compares each label's height with the same text laid out with no width limit. That's a sound check.
  - `:137-153`: the label has no letter spacing.
  - `:155-182`: labels are drawn at 14.4, 15.6 and 15.6 px.
- **My width model agrees:** "Calendario" is 77.9 dp selected and 73.7 dp unselected, in 80 dp.
- **Render** (390 dp, light and dark):
  - "Calendario" is bold and dark, with a filled icon and its pill.
  - Tareas, Notas and Ajustes are grey w500 with outlined icons.
  - The labels are a little tighter than before.
- **Still to do: the plan's device check.** Spanish, the largest font size, a phone narrower than 360 dp. With the test font engine there are 2.1 dp to spare.

**UX-428 · fixed**
- **`home_screen.dart:132`:** the project page's "Notas" button now shows `description_outlined`.
- **`home_screen.dart:233`:** the empty state shared by Tareas, Bandeja (the no-date list) and project pages now shows `check_box_outlined`.
- **`notes_screen.dart:111` and `:170`:** the Notas empty state and every note row now show `description_outlined`.
- **grep:** neither file has any `notes_rounded` or `checklist_rounded` left.
  - Across `App/lib`, `notes_rounded` is left only at `captures_screen.dart:49` and `voice_task_screen.dart:953`. Both were left to the capture packages on purpose.
- **Tests:** `home_screen_test.dart:27-92` and `notes_ui_test.dart:223-272`, in Spanish and English.
- **Render:** no current render covers these screens, so the evidence is the code and the tests.
  - The empty state still draws its icon at 28 dp, inside a 64 dp tinted tile (`app_components.dart:82-88`).
  - `check_box_outlined` shows a tick, not an empty box, so it doesn't look like something to tap.

### Regressions

**R2D-1 · Severity 1 · Below 360 dp, tab tooltips lose large text**
- **Where:** `App/lib/screens/main_shell.dart:78-83`.
  - The clamp wraps the whole NavigationBar, and that includes each tab's long-press tooltip (`navigation_bar.dart:598-599, 1047-1054`).
  - The tooltip is drawn through an OverlayPortal, which takes its text size from where it sits in the tree (`overlay.dart:1790-1797`). So the tooltip gets the 1.2× cap too.
- **The moment:** a low-vision user, text at 2×, on a phone narrower than 360 dp. They long-press "Calendario" to read it bigger: "Sale igual de pequeño."
- **What happens:**
  - Flutter caps tab labels at 1.3× on purpose. Its docs name the long-press tooltip as where the phone's text size applies (`navigation_bar.dart:46-48`).
  - Before P45, the tooltip followed the phone's size: 14 sp at 2× is up to 28 px. Now it's capped at 16.8 px (14 × 1.2).
  - From 360 dp up, nothing changed.
  - TalkBack is unaffected: the tooltip is excluded from semantics, and the tab name is read as before.
- **Why it fails:** lens L — text must be resizable to 200% (WCAG 2.2, 1.4.4). The bar's one full-size path is now capped.
  - It's rare. It needs a narrow screen, text above 1.2× and a long press, and the newcomer doesn't long-press.
- **Fix:** shrink only the label, not the whole bar's text scaling.
  - Drop `withClampedTextScaling`.
  - Below 360 dp, wrap the bar in a `NavigationBarTheme` whose label style sets `fontSize = 12 × min(s, 1.2) / min(s, 1.3)`, where `s = MediaQuery.textScalerOf(context).scale(12) / 12`.
  - The labels are still drawn at 12 × min(s, 1.2) px, exactly as now, and tooltips follow the phone's text size again.
  - Like the clamp, this is a stopgap that goes when U13 lands.
  - Today `main_shell_test.dart:172` asserts `fontSize == 12` in every case, 320 dp included. Below 360 dp it should check only the drawn size.
  - No copy changes.
- **Verify:** a widget test at 320×640, in Spanish, with text at 2.0×:
  - the labels are drawn at 14.4 px, on one line (the existing UX-427 tests);
  - a long press on "Calendario" shows a tooltip drawn at 28 px;
  - at 390 dp, nothing changes.
- **Evidence:** verified in code, in both the app and the Flutter 3.44.5 SDK. No test or render covers tooltips.

### Checked, not regressions
- **Rebuilds:** MainShell already depended on the whole MediaQuery through `MediaQuery.removePadding` (`main_shell.dart:50`, `media_query.dart:1246`), so `sizeOf` triggers no extra rebuilds.
  - Crossing 360 dp (rotating or unfolding) rebuilds only the bar. The selected tab and each screen's state live outside it (`main_shell.dart:53-64`).
- **Only the bar is clamped:**
  - The screens keep the full text size.
  - Icons don't scale with text, so the 24 dp icons, the 64×32 dp pill and the 80×72 dp targets are unchanged.
  - The safe-area padding still reaches the bar: the clamp copies every setting except the text scale (`media_query.dart:1452-1458`).
- **Between 348 and 359 dp,** where round 1's break began, the clamp now applies.
- **Catalan "Configuració"** is narrower than before (92.9 dp selected, 87.7 dp unselected, at 320 dp), but it still doesn't fit. That's UX-421, which waits on U13.
- **The Tareas icon next to the controls for completing things:**
  - Tasks are completed with a round checkbox (`task_tile.dart:83-84`), and steps with square ones (`checklist_editor.dart:88`, `task_detail_screen.dart:336`).
  - The tab's square with a tick (from P28) looks more like a step than a task. But it's labelled "Tareas", and the old `checklist_rounded` looked no more like the round control.
  - P45 only repeats the tab's icon in the empty state.
- **"Nueva nota"** keeps `edit_note_rounded` (`notes_screen.dart:140`). It's an action icon, and the pencil is what "new" uses elsewhere, as in "Nueva tarea".
- **`captures_screen.dart:49`:** there, `notes_rounded` means a capture that was typed, with no audio; the other option is the mic. It doesn't mean Notas.
  - Now that Notas uses the page icon, a typed task capture no longer looks like a note. That's a small gain.
- **No other icon looks like the Notas page:**
  - In the render, "Horario del día" (`view_timeline_outlined`, `calendar_screen.dart:362`) looks clearly different from it.
  - File attachments (`insert_drive_file_outlined` at `task_editor.dart:973`, `attach_file_rounded` at `attachment_panel.dart:199`) only appear next to file names.
- **Light and dark:** label colours and weights are unchanged, so contrast is as verified in round 1.

### Seen in passing (older than P45, not regressions)

**The tab bar's top hairline never shows · Severity 1**
- **What happens:** `main_shell.dart:67-74` paints an `outlineVariant` top border behind the bar, which is the decoration's default position. The NavigationBar's opaque `surface` Material then paints over it.
- **In both current renders,** the edge is only a change of tint:
  - light: (247,248,242) → white, 1.07:1;
  - dark: (18,24,22) → (28,34,33), 1.11:1.
- HEAD has the same structure, so this is older than P45.
- **Fix:** paint the border in front (`position: DecorationPosition.foreground`), or remove the DecoratedBox if the owner doesn't want a divider.
- **A correction to round 1:** I wrote "over the bar's top border". The edge you can see is the change of tint, not a border.

### For the organizer
- **R2D-1 and the hairline** are both in `main_shell.dart`. They can go in one small package.
- **UX-428's last Notas icon** is the "Revisar nota" button: `notes_rounded` at `voice_task_screen.dart:953`.
  - No package in `plan.json` names it.
  - P35's verify should check that it's gone, or that it uses `description_outlined`.

### Memory notes
- **Tabs after P45:**
  - The label style sets `letterSpacing: 0`, so it no longer inherits 0.25.
  - Below 360 dp, the whole bar is clamped to 1.2× (`main_shell.dart:75-83`). This is a stopgap until U13.
  - The clamp also caps the long-press tooltips, because OverlayPortal children inherit the MediaQuery (R2D-1).
- **The icon for each concept:**
  - Tareas is `check_box` / `check_box_outlined`, on the tab and in the Tareas, Bandeja and project empty states (`home_screen.dart:233`).
  - Notas is `description` / `description_outlined`, on the tab, the Notas empty state, every note row, and a project page's "Notas" button.
  - Tasks are completed with a round `Checkbox` (`task_tile.dart:83-84`), and steps with square ones.
- **`notes_rounded` is left in two places:**
  - `voice_task_screen.dart:953` ("Revisar nota"), for the Notas concept; it waits on P35;
  - `captures_screen.dart:49`, where it means "typed, no audio".
- **The tab bar's top hairline is hidden** under the bar's opaque Material (`main_shell.dart:67-74`). The visible edge is only a change of tint: 1.07:1 in light, 1.11:1 in dark.
- **Flutter 3.44.5 facts:**
  - NavigationBar caps labels at 1.3× (`navigation_bar.dart:506-513`). Its docs say the phone's text size applies to the long-press tooltips instead (`:46-48`).
  - Tooltips are 14 sp on Android.
  - Wrapping a widget in a MediaQuery also changes its tooltips and other OverlayPortal content.
- **The Manrope width model** still matches renders with letter spacing 0: "Calendario" is 64.9 dp modelled against 64.0 dp of ink at 390 dp and 1.0×.
