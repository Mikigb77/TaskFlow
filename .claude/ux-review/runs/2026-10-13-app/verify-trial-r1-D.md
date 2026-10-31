## UX verify — 2026-10-13-app · round 1 · area D · P28 — 2026-10-13

**Verdict:** Ship after fixes. UX-412 and UX-413 are fixed and you can see it in the current renders. UX-421's 12 sp shipped. But the wider labels now break Spanish "Calendario" mid-word on 320 dp screens with large text (R1D-1). Catalan "Configuració" was already too wide, it got wider, and the P28 device check can't pass while there are four tabs.

**What I checked:**
- **Code:** `git diff HEAD` of `App/lib/theme/app_theme.dart` and `App/lib/screens/main_shell.dart`.
- **Tests:** the tester's tests in `App/test/appearance_test.dart:376-499`.
- **Renders**, all newer than the 13:57 code change:
  - `App/build/calendar-feedback-light.png` and `-dark.png`, 14:07, which I cropped and enlarged around the tab bar;
  - `App/artifacts/auth/login-light.png` and `-dark.png`, 14:08.
- **Tab-label widths,** measured from `App/assets/fonts/Manrope.ttf`. It's a variable font: weight axis 200–800, default 200.
  - The measurement includes the 0.25 letter spacing the label inherits from `bodyMedium`.
  - This model matches the current render to within about 1 dp: "Calendario" (selected) is 66.5 dp of ink in the render and 67.4 dp modelled; "Ajustes" is 43.5 vs 44.7.
- **Tab layout,** from the Flutter SDK's `material/navigation_bar.dart`:
  - the bar is a fixed 72 dp `SizedBox` holding a `Row` of `Expanded` tabs (:298-302);
  - each label is laid out with loose constraints inside its tab (:1101), so a single word that's too long wraps mid-word;
  - label scaling is capped at 1.3× (:511).

**Walked:** switching tabs (1 tap), with three personas:
- the newcomer: Spanish, 1.3–2× text, 320–360 dp;
- the daily user;
- a low-vision user.

I also looked at the sign-in fields and the Tasks search field in both themes.

### Results

**UX-412 · fixed**
- `app_theme.dart:88-90`: the enabled border is now `scheme.outline`.
- Contrast of the outline, now (before):

  | Against | Light | Dark |
  |---|---|---|
  | Field fill and cards | 3.79:1 (1.28) | 4.85:1 (1.51) |
  | Page | 3.55:1 (1.20) | 5.40:1 (1.68) |
  | `surfaceContainerLow` | 3.38:1 | 4.37:1 |
  | `surfaceContainerHighest` | 3.15:1 | 3.50:1 |

- In dialogs, the M3 `surfaceContainerHigh` is about tone 92, which gives about 3.1:1. That figure is inferred.
- In both sign-in renders, the Email and Password boxes are clearly outlined.
- Focus (2 dp primary), error and disabled borders come from the M3 defaults and haven't changed.
- The tester's test passes.

**UX-413 · fixed**
- `app_theme.dart:122-129`: the selected label is w800 in `onSurface`; unselected labels are w500 in `onSurfaceVariant`.
- Label contrast on the bar:
  - light: 14.46:1 selected, 5.26:1 unselected;
  - dark: 14.44:1 selected, 7.97:1 unselected.
- `main_shell.dart:52-71`: all four tabs now have an outlined icon and a filled one (calendar_month, check_box, description, settings).
- **Render:** in light and dark, "Calendario" is bold and dark, with a filled icon. Tareas, Notas and Ajustes have grey regular labels and outlined icons.
- The dark indicator pill is still 1.41:1. It no longer has to carry the state, because the label weight and the filled icon now do.

**UX-421 · partly**
- **Done:** labels are 12 sp in both states (`app_theme.dart:126`).
- **Not met:** P28's device check, "Configuració fits its tab at 320 dp and 1.3× text", can't pass with four tabs.
  - At the 1.3× cap, "Configuració" is 98.1 dp unselected and 103.7 dp selected. One tab at 320 dp is 80 dp wide. At 11 sp it was 93.6 dp.
  - Fitting it when selected now takes a screen at least 415 dp wide; before the change, 374 dp was enough.
  - At 320 dp, the selected label is borderline even at 1.0× text (80.4 dp).
- **What clears it:** the finding itself says only U13's two tabs remove this overflow, and U13 is still undecided. Shortening the Catalan word is the other way out, but "Configuració" is Android's own Catalan word for Settings. It's also named in `app_ca.arb:614,618`. I don't recommend renaming it.
- **The check doesn't need a device.** A widget test that loads Manrope, as `App/test/calendar_feedback_test.dart:29-31` already does, can measure the label's real height.

### Regressions

**R1D-1 · Severity 2 · Spanish "Calendario" tab label breaks mid-word at 320 dp**
- **Where:** `App/lib/theme/app_theme.dart:122-129` (12 sp, w800 selected), with the four tabs in `App/lib/screens/main_shell.dart:48-73`.
  - This is the tab bar on every root screen, in Spanish.
  - It happens on screens narrower than about 348 dp — for example a 360 dp phone with Display size raised — with Android text at 1.2× or more for the selected label, and 1.27× or more for unselected ones. That covers the newcomer's whole 1.3–2× range.
- **The moment:** "¿'Calendari' y una 'o' debajo? Se ha roto algo."
- **What happens:**
  - At the 1.3× cap, "Calendario" is 86.9 dp selected and 82.4 dp unselected, in an 80 dp tab. It wraps to "Calendari" with "o" on a second line.
  - With two lines, the icon and its pill rise a few dp over the bar's top border, and the "o" hangs a few dp below the 72 dp bar. It's about 5 dp each way with the 1.5 line height the label inherits.
  - Before the change, it was 78.5 dp (11 sp, w700) and fit any screen from 314 dp up.
  - Calendario is the start tab, so this is the first thing the newcomer sees.
- **Why it fails:**
  - Lens L: at 320 dp and 2× text, nothing should clip or break.
  - `App/docs/DESIGN.md:19` says "layouts accommodate enlarged text and small screens."
  - It's the same type of problem as recurring problem #13 (labels breaking mid-word), now in the newcomer's language on the home tab.
- **Fix:**
  1. Add `letterSpacing: 0` to the tab label style in `app_theme.dart:124-128`. Today it inherits 0.25 from `bodyMedium`.
  2. In `main_shell.dart`, wrap the `NavigationBar` in `MediaQuery.withClampedTextScaling(maxScaleFactor: 1.2, …)` when `MediaQuery.sizeOf(context).width < 360`.
  - **Measured result:** "Calendario" becomes 77.9 dp selected and 73.7 dp unselected, inside 80 dp. The label is then 14.4 px, which is no smaller than the 14.3 px before the change.
  - Keep 12 sp and the w800/w500 states everywhere else.
  - **Lasting fix:** U13's two tabs (160 dp each at 320 dp). That also clears "Configuració".
- **Verify:** a widget test that loads Manrope (as `calendar_feedback_test.dart:29-31` does), in Spanish at 320×640, with text at 1.3 and at 2.0. Assert that every tab label renders on one line — its height is no more than one line of its style — with Calendario both selected and unselected.
- **Evidence:** inferred from the measured font metrics, which match the current 390 dp render to within about 1 dp. No 320 dp Spanish render exists; it needs that test or a device check.

**R1D-2 · Severity 1 · Tab icons no longer match the Tasks and Notes screens**
- **Where:** the new tab icons at `App/lib/screens/main_shell.dart:57-66`, against the icons inside the screens:
  - `App/lib/screens/home_screen.dart:233`: the Tasks empty state still uses `checklist_rounded`;
  - `App/lib/screens/notes_screen.dart:111`: the Notes empty state uses `notes_rounded`;
  - `App/lib/screens/notes_screen.dart:170`: every note row uses `notes_rounded`;
  - `App/lib/screens/home_screen.dart:132`: the project page's *Notas* button uses `notes_rounded`.
- **What happens:**
  - The Tareas tab used to show `checklist_rounded`, the same icon as its empty state. Now it shows a check box.
  - Unselected, Notas used to show the lines icon its rows use. Now it shows a page. The selected Notas tab already showed a page before this change.
  - One concept, two icons.
- **Why it fails:** lens F — the same thing should look the same everywhere.
- **Fix:** use the tab icons inside the screens:
  - `Icons.check_box_outlined` at `home_screen.dart:233`;
  - `Icons.description_outlined` at `notes_screen.dart:111` and `:170` and at `home_screen.dart:132`.

  Leave `voice_task_screen.dart:953` and `captures_screen.dart:49` alone: the capture-sheet packages replace them.
- **Verify:** a grep finds no `notes_rounded` or `checklist_rounded` left in the Tasks and Notes screens.
- **Evidence:** verified in code.

### Checked, not regressions
- **Fields that draw their own borders:** the only ones are in `widgets/capture_review_editor.dart:305-308,334-336`, and they also set `enabledBorder: InputBorder.none`, so they're unaffected.
- **No pseudo-fields left behind:** no widget draws a field-like box with `outlineVariant` next to real fields, so nothing now looks out of step.
- **Disabled fields:** these used to draw a darker border than enabled ones (M3's 38% `onSurface`, against 1.28:1). Now enabled is the darker one, which is the right way round.
- **Ajustes:** it no longer shares `tune_rounded` with the "more options" controls (`capture_review_editor.dart:464`, `device_calendar_events.dart:35`, `task_editor.dart:712`). That's a consistency gain.
- **Calendario:** the tab's `calendar_month` matches "Vista mensual" and the phone-calendar rows, so the calendar concept still has one icon.
- **Tareas:** `check_box` doesn't collide with completed tasks, which use `task_alt_rounded`.
- **Targets, labels and reading order:** tap targets (80×72 dp per tab at 320 dp), TalkBack labels and the reading order are unchanged.
- **English:** every English label fits at 320 dp.

### Numbers
Label widths at the 1.3× cap, in dp. A tab at 320 dp is 80 dp wide.

| Label | Before (11 sp, w700) | Unselected (12 sp, w500) | Selected (12 sp, w800) | Narrowest screen where the selected label fits |
|---|---|---|---|---|
| ES Calendario | 78.5 | 82.4 | 86.9 | 314 → 348 dp |
| CA Configuració | 93.6 | 98.1 | 103.7 | 374 → 415 dp |
| CA Calendari | 69.4 | 72.7 | 76.9 | 278 → 308 dp |
| EN Calendar | 65.1 | 68.6 | 72.0 | 261 → 288 dp |

Every other label fits.

### For the organizer
- **UX-421's Catalan part waits on U13.** P28's device check expects "Configuració" to fit its tab, which four tabs at 320 dp can't allow. Route that part to U13 (D7a's timing is still open) rather than to another round.
- **R1D-1 is a small follow-up to P28,** in the same two files.

### Memory notes
- **Tabs (2026-10-13, P28):**
  - Icons, outlined when unselected and filled when selected:
    - Calendario: `calendar_month_outlined` / `calendar_month`;
    - Tareas: `check_box_outlined` / `check_box`;
    - Notas: `description_outlined` / `description`;
    - Ajustes: `settings_outlined` / `settings`.
  - Labels are 12 sp: selected w800 in `onSurface`, unselected w500 in `onSurfaceVariant`.
  - Labels inherit 0.25 letter spacing and a 1.5 line height from `bodyMedium`.
  - The bar is a fixed 72 dp, and labels are capped at 1.3×. A long single word wraps mid-word and pushes the icon up.
- **Field borders:** the enabled border is `outline` (3.79:1 light, 4.85:1 dark). The `border` fallback (`outlineVariant`) is never painted on M3 filled fields; their disabled and error borders come from M3's defaults.
- **Measuring text width without Flutter:** `Manrope.ttf` is a variable font (weight 200–800, default 200). Pillow's `set_variation_by_axes([weight])` with `getlength`, plus 0.25 × the number of characters, matched the render to within about 1 dp. Use it for "does this fit at 320 dp" checks.
- **Preview tests can measure real text:** previews that load Manrope through `FontLoader` (`calendar_feedback_test.dart:29-31`) can measure real label sizes, so "needs a device" claims about text fitting are often testable. The default flutter_test font can't measure them.
- **Recurring problem #13 has a new instance:** the Spanish "Calendario" tab at 320 dp with text at 1.2× or more (R1D-1).
