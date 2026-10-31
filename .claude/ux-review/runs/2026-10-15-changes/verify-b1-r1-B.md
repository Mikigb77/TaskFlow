## UX verify — 2026-10-15-changes, round 1, area B (P119) — 2026-10-15

**Verdict:** all three findings fixed in code and tests; no regressions found in the changed files or the flows they touch. What's left needs a phone or the real model (listed under each finding).

**Evidence used:** `git diff HEAD` on the five source files; the tester's tests read in `App/test/calendar_feedback_test.dart:2715-3040` and `App/test/capture_landing_test.dart:930`; renders `App/build/calendar-es-1.3x-light.png` (19:16, newer than the code at 19:05). No preview renders the first-run state, so UX-702's visual judgement rests on the tester's position test, not on a render.

### UX-701 · fixed
- Copy is exact in all three catalogs: `App/lib/l10n/app_en.arb:313`, `app_es.arb:222`, `app_ca.arb:201`. One date word, said first, no hour; it still names the real button (test at `calendar_feedback_test.dart:2756-2759`).
- `@calendarTrySaying` description in app_en.arb carries the rule, as planned.
- Fallback: `localDrafts` on the quoted words gives one confirmed draft, no clarification, dated tomorrow, no time, titled per language, from a Monday and a Friday reference (`calendar_feedback_test.dart:2763-2791`).
- Landing: two tasks for tomorrow land on tomorrow, both lit, with "2 tareas añadidas", Deshacer and no "también" (`capture_landing_test.dart:934`).
- Words to remember while speaking, ES: 12 → 7. Days of the week on which both saved tasks are on screen: 1 of 7 → 7 of 7.
- Left for devices: the real model returning two tasks dated tomorrow in ES/EN/CA (main session), and the spoken flow on a phone.

### UX-702 · fixed
- `EmptyState.icon` is now nullable with the same default, and the tile plus its 16 dp gap are skipped when it's null (`App/lib/widgets/app_components.dart:129-147`). The other call sites don't pass `icon`, so they're unchanged.
- `firstRun` (`App/lib/screens/calendar_screen.dart:356`) hides the line under "Agenda de hoy" (`:660-676`) and the icon (`:700`) only in the first-run state. The error state keeps its tile (`:684-692`, default icon). An account that has had a task keeps both line and tile.
- The no-scroll position tests at 390×844, view padding 24/24 and Manrope, ES/EN/CA at 1.8 and ES/EN at 2.0, assert that the line's bottom is at or above `TaskActions`' top and that the scroll offset is 0 (`calendar_feedback_test.dart:2816-2859`). That's the check the review asked for.
- Measured cut in the first-run state: 64 + 16 dp (tile) + 4 dp and one 12 sp line (about 16 dp at 1×, 30 dp at 2×) ≈ 100–114 dp.
- Left for a device: Android 14's largest font (non-linear scaling) on a 393 dp phone.

### UX-703 · fixed
- Copy is exact (`app_en.arb:317`, `app_es.arb:223`, `app_ca.arb:202`). `localDrafts` gives one confirmed draft, with no 10:00/22:00 choice, dated tomorrow with no time (`calendar_feedback_test.dart:2793-2814`).
- Typed first task, before → after: the typing plus an hour answer → the typing only (one tap fewer).

### Regressions looked for, none found
- **Loading:** `firstRun` is true while the tasks load (`hasAny` false). The line under the title is now hidden during that load instead of briefly saying "Un momento de calma." over a day that may have tasks. `hadTask` reads a local store, so any 20 dp shift lasts a moment and is better than the old wrong text. Not reported.
- **Load error on a new account:** the line under the title is hidden and the error keeps its tile and Reintentar. Covered by the test at `:2975`.
- **Phone calendars on, first run:** "No hay tareas de TaskFlow programadas" is gone. `DeviceCalendarEvents` (`calendar_screen.dart:769`) still draws its own "N eventos · hh:mm" line below the empty state, so phone events stay distinguishable. Not a regression.
- **Notes-only account:** `hadTask` is true, so `firstRun` is false and the old look holds.
- **Days with tasks:** unchanged; `calendar-es-1.3x-light.png` still shows "3 pendientes · 1 completada" under the title.
- **TalkBack:** the removed tile had no label. The reading order is now title, prompt, instruction.
- **Copy, all three languages:** reads naturally («Mañana, llamar al dentista y comprar pan», «Demà, trucar al dentista i comprar pa», “Tomorrow, call the dentist and buy bread.”), with the quote conventions kept.
