## UX verify — run 2026-10-28-app, batch b2, round 2, area D (P304, P305) — 2026-11-01

**Verdict:** Ship. All four findings meet their acceptance checks; no regression the change caused.
**Evidence level:** code (`git diff HEAD`), the re-rendered previews of 09:11–09:12 (newer than every file they show) with AUDIT.md, and the testers' widget tests. This is widget-test evidence, not a device.

### Results

**UX-2108 · fixed.** The form's primary is 60 dp.
- `App/lib/theme/app_theme.dart:106-113`: `elevatedButtonTheme` now has `minimumSize: Size(48, 48)` with `VisualDensity(vertical: 3)`, matching the filled theme at :101-105. Colours, elevation 0, shape and text style are kept, and the comment at :95-100 names the form's ElevatedButton. `task_editor.dart`'s button is unchanged: same key `task-save`, icon and labels.
- AUDIT: «Añadir tarea» and «Añadir al calendario» measure 312 × 60 dp in form/new-task · empty, «Guardar cambios» 312 × 60/65 dp in form/edit-task · existing, and «Añadir tarea» 320 × 60/64 dp in tasks/project · person-form. The «Primary 48–56» column is 0 for every form/* state, for person-form, and for every other state in the summary.
- Render `form/new-task.keyboard.es.light.2x`: the three-line title, Hoy/Mañana and «Añadir al calendario» all sit above the 300 dp keyboard. To give room, the scroll's bottom padding went from 32 to 16 dp (`task_editor.dart` ~:864); the button was not shortened. The `form/edit-task.long.es.light.2x` and `new-task.filled.es.light.1x` renders look right.

**UX-2630 · fixed.** Each icon sits beside its label's longest line.
- `subscription_screen.dart:264-266`, `data_transfer_screen.dart:200-202` and `device_calendars_screen.dart:113-115` add `textWidthBasis: TextWidthBasis.longestLine` next to `textAlign: center`.
- Renders:
  - `settings/pro.free.ca.light.2x` (and `pro.file-space-full.ca.light.2x`): the sparkle is at x≈96 dp, about 7 dp left of «subscripció», and the group is centred in the full-width button.
  - `first-run/phone-calendars.not-allowed.ca.light.2x`: the calendar icon is next to «calendaris del», the longest line, and the group is centred.
  - `settings/data-transfer.start.es.light.2x`: the download icon is about 7 dp from «Exportar archivo / TaskFlow».
- The headline ellipsis that AUDIT flags on phone-calendars (26 dp) is outside this finding: the round didn't touch the headline, and headlines scale linearly in the preview suite.

**UX-2631 · fixed.** The import button's label is centred and clears its edges.
- `app_theme.dart:121-128`: `outlinedButtonTheme` now has `minimumSize: Size(48, 44)` with `VisualDensity(vertical: 2)`, which gives 52 dp at one line and 8 dp of padding above and below a wrapped label. Its shape and `side` are kept.
- `data_transfer_screen.dart:204-208`: the label is centred, with `longestLine`.
- Render `settings/data-transfer.start.es.light.2x`: «Elegir archivo para / importar» is centred with its icon, with about 9–12 dp above and below the text.
- Render `settings/data-transfer.start.es.light.1x`: the one-line import button is about 51 dp and the export button 60 dp.
- In `tasks/detail.alert-passed.ca.light.2x`, «Canvia la data» fits on one line with no clipping.

**UX-2629 · fixed.** Acceptance is met, with a residual risk that is not a regression (see note 1).
- `calendar_screen.dart:412-443`: `_comeBack` now calls `_holdTop()`. That jumps to `minScrollExtent` after the next frame, then checks again on up to 3 later frames, and jumps again if a silent layout correction moved the offset while `_heldTop` was still set.
- `_scrolled` (:291-295) clears `_heldTop` as soon as the offset differs, so a person's own scroll wins.
- It jumps and never animates. A short return still exits early (:414-416), keeping both the day and the scroll.
- The implementer's comment gives the cause as the sliver's layout correction once rows built for the old day are laid out again from the top. The brief's other suspect, the landing reveal, was not addressed.
- Tests (tester, pass), in `App/test/capture_landing_test.dart` :2110 and on: the 31-minute return at ES 2.0× on 360×800, 360×740, 320×800 and 412×915, at 1.5× on 360×800 and at 1.3× on 360×640; the 5-minute sibling keeps Friday and its scroll; the original UX-1628 test passes.

### Regressions
None. Checked:
- the outlined-button density in every file that uses OutlinedButton, including the two with their own style;
- the theme change in the form, task detail, Pro, data-transfer and phone-calendar renders;
- `_scrolled` and `_holdTop` in the Calendar return.

### Notes for the organizer (not regressions)
1. **UX-2629's residual risk: the landing reveal is not cancelled.**
   - `_select(today)` (:105-117) does not clear `_highlight` or `_litOrder`.
   - `_scrollToLit` (:192-275) awaits `endOfFrame`, which doesn't complete while the app is paused.
   - So if the person leaves the app within the second or so of a landing's reveal and comes back after 30 minutes or more, the loop resumes on today's agenda. It can't find Friday's rows (`first == null`), so it jumps a viewport at a time (:220-227). Its first jump clears `_heldTop` through `_scrolled`, and `_holdTop` then gives way, taking it for a person's scroll.
   - The same was possible before this round, so it is not caused by the change.
   - The ledger's UX-2629 line says "`_comeBack` cancels the landing reveal", which is not what landed. Correct the ledger, or add the brief's generation counter (`_revealRun`) as step (1).
   - The device check «save for Friday, leave, come back after 31 minutes» should include leaving at once after the save.
2. **The auth/ renders are stale** (06:19, before the theme change at 09:07). The Google button (`App/lib/widgets/google_login_button.dart:15-28`) sets its own `minimumSize: Size(0, 48)` and 12 dp vertical padding but not `visualDensity`, so it now takes the theme's +8 dp: 56 dp tall with 20 dp padding, above the 48 dp «Continuar con mi correo» TextButton. That is inferred from the code. It looks harmless, since the button is bigger and still the first choice, but re-render auth/ to confirm.
3. **Same class as UX-2608 and UX-2630, not caused by this round** (it shows in renders this round touched):
   - The form's ElevatedButton label at 2× wraps left-aligned, with the check icon at the left (`form/new-task.keyboard.es.light.2x`: «Añadir al / calendario»). It has no `textAlign` or `longestLine`.
   - Task detail's reminder OutlinedButton at ca 2× (`tasks/detail.alert-passed.ca.light.2x`) has a four-line left-aligned label, with the bell icon 14 dp to its left at the button's edge.
   - Both belong to P302 or the form, not P304. If no open issue covers them, file them.
4. At 2× the two Exportar e importar buttons are content-width and unequal (about 267 and 293 dp), as they are at 1×. This is polish and not reported.
