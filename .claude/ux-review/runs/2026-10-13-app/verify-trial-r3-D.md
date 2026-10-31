## UX verify — 2026-10-13-app · round 3 · area D · P47 — 2026-10-13

**Verdict:** Ship. UX-432 is fixed: on a phone narrower than 360 dp with large text, long-pressing a tab shows its name at the phone's text size again (28 px at 2×, not 16.8 px). The labels look exactly as they did after P45. No regressions. The phone check is still to do.

**What I checked:**
- **Code:** `git diff HEAD -- App/lib/screens/main_shell.dart`. That diff also holds P28 (round 1, the icons). The P47 part:
  - `:10-18`: three named constants. The 1.3 cap's comment says it mirrors Flutter's private `_kMaxLabelTextScaleFactor`.
  - `:31-35`: the reworded comment. Below 360 dp only the label stops at 1.2×, the tooltips keep the phone's size, and it's a stopgap.
  - `:36-49`: below 360 dp, the label style is built from the theme's resolver with `copyWith(fontSize: 12 × min(s, 1.2) / min(s, 1.3))`.
  - `:51`: that style is passed through `NavigationBar.labelTextStyle`. From 360 dp up it's null, so the theme applies.
  - `withClampedTextScaling` is gone from `App/lib`: grep finds nothing. Nothing wraps the bar or a destination in a MediaQuery any more.
  - The DecoratedBox (`:99-108`), the icons, `labelBehavior`, the 72 dp height and the 360 dp threshold are unchanged.
  - `app_theme.dart:118-130` was not touched in this round (12 sp, `letterSpacing: 0`, w800 selected and w500 otherwise).
- **Tests,** read but not run. Everything is in `App/test/main_shell_test.dart`:
  - `:116-138`: every label on one line at 320×640 (Spanish at 1.3× and 2.0×, English at 1.3×), first with Calendario and then with Tareas selected, and no icon pill above the bar. These are unchanged; only their line numbers moved by 3.
  - `:140-156`: `letterSpacing` 0 and Manrope. This runs at 320 dp and 1.3×, so it now checks P47's `copyWith` path.
  - `:158-187`: drawn sizes of 14.4 px (320 dp, 2.0×), 12 px (320 dp, 1.0×, new), and 15.6 px at 360 and 390 dp (1.3×). `fontSize == 12` is asserted only from 360 dp up (`:177`).
  - `:189-265`: the tester's UX-432 tests at 320×640 and 390×844, at 2.0× text. A long press on Calendario adds exactly one non-label "Calendario" paragraph. It's drawn at 28 px and is inside the screen. The label is still 14.4 or 15.6 px.
    - The 320 dp case would fail under P45's clamp (16.8 px), so the test really tells the two apart.
- **Renders:** `App/build/calendar-feedback-light.png` and `-dark.png` (15:26) are newer than `main_shell.dart` (15:20) and the test (15:23). I cropped and measured the tab bar.
- **Flutter 3.44.5 SDK:**
  - `material/navigation_bar.dart`:
    - `:31`: the 1.3 label cap;
    - `:46-48`: the phone's text size applies to the long-press tooltips;
    - `:482-494`: the bar's own `labelTextStyle` wins over the theme;
    - `:505-513`: the label's own 1.3× clamp. It sits inside the tooltip, not around it.
    - `:596-599` and `:1047-1054`: the tooltip wraps the whole destination.
  - `material/tooltip.dart:443-448`: tooltips are 14 sp on Android.
  - `material/tooltip.dart:519-527`: the tooltip box is built where the Tooltip sits.
  - `widgets/overlay.dart:1791-1798`: an OverlayPortal child inherits from the portal's place in the tree.
  - `painting/geometry.dart:41-67`: tooltips are kept 10 dp from the screen edges.

**Walked:**
- **The low-vision user:** Spanish, 320 dp, text at 2×, long-presses "Calendario" to read it bigger. The tooltip is now 28 px, about twice the 14.4 px label (`main_shell_test.dart:189-265`). TalkBack is unchanged: the tooltip is excluded from semantics (`navigation_bar.dart:1051`).
- **The newcomer:** Spanish, 320 dp, text at 1.3× and 2×, switching tabs (1 tap). The labels are drawn at 14.4 px on one line, the same as after P45.
- **The daily user:** 360 and 390 dp. Nothing changes: the style is the theme's and the labels are drawn at 15.6 px.
- **Other states:**
  - switching between light and dark;
  - rotating or unfolding across 360 dp;
  - changing the phone's font size while the app is open.

  MainShell reads the theme, the width and the text scale, so it rebuilds the label style each time. The selected tab is kept in `_MainShellState`.

**Numbers:**

| At 2.0× text | HEAD (before P45) | After P45 (round 2) | After P47 |
|---|---|---|---|
| Tab tooltip, 320 dp | 28 px | 16.8 px | 28 px (tested) |
| Tab tooltip, 390 dp | 28 px | 28 px | 28 px (tested) |
| Tab label, 320 dp | 15.6 px, "Calendario" wraps | 14.4 px, one line | 14.4 px, one line (tested) |
| Tab label, 360–390 dp, 1.3× | 15.6 px | 15.6 px | 15.6 px (tested) |

- **Label style below 360 dp:**
  - 11.08 sp from 1.3× text up (12 × 1.2 / 1.3); Flutter's 1.3× cap draws it at 14.4 px;
  - 11.52 sp at 1.25× text, also drawn at 14.4 px;
  - 12 sp at 1.2× and below.

  The drawn size is the same as P45's, so the layout and the glyphs are identical too.
- **Render at 390 dp and 1.0×,** the same as round 2:
  - "Calendario" ink is 64.0 dp wide (round 2: 64.0 dp), and the label ink is 9.5 dp high.
  - The bar's tint edge is unchanged: (247,248,242) → white in light, and (18,24,22) → (28,34,33) in dark.
- **Unchanged:** taps to switch tabs (1), tap targets (80×72 dp at 320 dp), and the number of tabs (4).

### Results

**UX-432 · fixed** (the phone check is still to do)
- **`main_shell.dart:36-51`:** below 360 dp, only the label's font size changes, through `NavigationBar.labelTextStyle`. The bar keeps the phone's text scaling, so its tooltips are full size again.
  - Each state keeps its own weight, colour, family and letter spacing, because the style comes from the theme's resolver plus `copyWith(fontSize:)`.
- **Acceptance:**
  1. 320×640, Spanish, 2.0×: the tooltip is drawn at 28 px. Met (`:189-265`, passes).
  2. 390×844, 2.0×: 28 px. Met (same test).
  3. At 320 dp, labels are drawn at 14.4 px at 2.0× and 12 px at 1.0×; at 360 and 390 dp, 15.6 px with a 12 sp style. Met (`:158-187`).
  4. The UX-427 one-line, pill, letter-spacing and Manrope tests are kept. Met (`:116-156`).
  5. No `withClampedTextScaling` in `main_shell.dart`; below 360 dp only the label font size changes. Met (code and grep).
  6. Render at 390 dp: the tab bar is as it was after round 2. Met (measurements above).
- **Still to do:** the plan's device check.
  - From Android 14, text scaling isn't linear. So on a phone the 14 sp tooltip can come out a little under 28 px at the largest font size, while the label still lands on about 14.4 px.
  - Confirm that the tooltip is clearly bigger than the label. Also recheck P45's one-line check for UX-427: Spanish, the largest font size, a phone narrower than 360 dp.

### Regressions

None. P47 caused no new problem in `main_shell.dart` or the flows it touches:
- switching tabs;
- long-pressing a tab;
- TalkBack on the bar.

### Checked, not regressions
- **Nothing else in the bar scales with text.** In `navigation_bar.dart`, the only uses of the text scale are the label clamp (`:506`) and the tooltip. So removing the bar-wide clamp changes the tooltip and nothing else; icons, the 64×32 dp pill and the targets stay the same.
- **Tooltip placement at 2× on a 320 dp phone:** it sits above the bar, at least 10 dp from the screen edges (`geometry.dart:60-65`).
  - "Calendario" at 28 px is about 150–160 dp wide with padding, so it fits; the tooltip test checks that it's inside the screen.
  - This is the same as HEAD and as 390 dp today. The tooltip covers the capture buttons only for its 1.5 s show time, after the finger lifts.
- **Light and dark:** the colours come from whichever theme is current, including during the 220 ms theme animation. Contrast is as verified in round 1.
- **Phones below 1.0× text:** the label style stays 12 sp, the same as before.
- **The 12 sp constant** in `main_shell.dart:18` repeats the theme's 12 sp (`app_theme.dart:126`). They match today. If the theme's size ever changes, change both, or narrow phones get a different size from wider ones. Nothing a user sees now.

### Seen in passing
Nothing new. The tab bar's hidden top hairline is still UX-433, in P23.

### For the organizer
- **Ledger line numbers have moved:**
  - UX-432 cites `main_shell.dart:78`; the code is now at `:36-51`.
  - UX-433 cites `main_shell.dart:67`; the DecoratedBox is now at `:99-108`.
- **Device check still open:**
  - The narrow-phone, largest-font check now covers both UX-432 (the tooltip is clearly bigger than the label) and UX-427 (every label on one line, icons inside the bar).
  - One session on one phone covers both.

### Memory notes
- **Tabs after P47:**
  - Below 360 dp, MainShell passes `NavigationBar.labelTextStyle` = the theme's resolver plus `copyWith(fontSize: 12 × min(s, 1.2) / min(s, 1.3))` (`main_shell.dart:36-51`). Flutter's 1.3× label cap then draws it at 14.4 px.
  - Nothing wraps the bar in a MediaQuery, so tab tooltips follow the phone's text size (28 px at 2×).
  - This is a stopgap until U13.
- **The pattern to enforce:** never shrink text by wrapping a NavigationBar, or anything with tooltips, in a MediaQuery.
  - OverlayPortal content (tooltips, menus) inherits that MediaQuery.
  - Shrink the style instead.
- **`_labelFontSize = 12`** in `main_shell.dart` mirrors the theme's 12 sp tab label (`app_theme.dart:126`). The two must move together.
- **Render baseline** (`calendar-feedback` at 390 dp, 1.0×):
  - "Calendario" ink is 64.0 dp wide and the label ink is 9.5 dp high;
  - the tint edge is (247,248,242) → white in light, and (18,24,22) → (28,34,33) in dark.
