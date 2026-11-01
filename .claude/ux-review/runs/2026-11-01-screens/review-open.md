# Review: open findings left by run 2026-10-28-app (2026-11-01)

No new review ran. This report gathers the seven findings run 2026-10-28-app left open, so they can be planned and fixed as a scoped run. Each keeps its ledger ID; the full evidence is in the ledger line and the verify note named, and the briefs below come from them.

**Verdict:** two regressions this run caused in the capture entry rules (UX-2643, UX-2644) and five small S1 items filed at the batches' close.

| Sev | Count |
|---|---|
| S4 | 0 |
| S3 | 0 |
| S2 | 1 |
| S1 | 6 |

## Findings

### UX-2643

**UX-2643** · S2 · A · open · An entry closes a titleless form holding a date or photo · `App/lib/main.dart:220` · 2026-10-28-app · regression R3A-1 of P313's UX-2642 (b3 round 3, verify-b3-r3-A): a blank entry form counts as empty by its title alone (`task_editor.dart:336`), so an entry it doesn't take pops it, losing a picked date, reminder, checklist or attachment unasked (notes survive under «Sin guardar»). Fix: close only a form where nothing changed (`_edited().toMap()` against `_unchanged`); absorbing may keep the title test; otherwise open over it. Verified in code; no test or render. Not yet planned

### UX-2644

**UX-2644** · S1 · A · open · Voice, text, voice taps stack two voice sheets · `App/lib/main.dart:204` · 2026-10-28-app · regression R3A-2 of P313's UX-2641 (b3 round 3, verify-b3-r3-A): Pro, online listening: after the close-first pop uncovers the paused recorded voice sheet, a second voice sheet and recorder open over it; nothing lost. Fix: after the pop, check the top again and acknowledge if an empty sheet of the asked mode is current. Inferred from code; no test. Not yet planned

### UX-2634

**UX-2634** · S1 · D · open · Form's primary label wraps left, icon stranded, at 2× · `App/lib/widgets/task_editor.dart:1208` · 2026-10-28-app · filed by the organizer at b2 close from verify-b2-r2-D note 3 (render `form/new-task.keyboard.es.light.2x`: «Añadir al / calendario» left-aligned, the ✓ at the left edge): `textAlign: center` with `textWidthBasis: longestLine`, as UX-2608/UX-2630. Not caused by this run; not yet planned

### UX-2635

**UX-2635** · S1 · B · open · Task page's reminder button wraps to four left lines at CA 2× · `App/lib/screens/task_detail_screen.dart` · 2026-10-28-app · filed by the organizer at b2 close from verify-b2-r2-D note 3 (render `tasks/detail.alert-passed.ca.light.2x`: a four-line left-aligned label, the bell 14 dp from it at the edge): centre with `longestLine`, as UX-2631. Not caused by this run; not yet planned

### UX-2645

**UX-2645** · S1 · B · open · Remove-file dialog's help line still says «Se eliminará» · `App/lib/l10n/app_es.arb:407` · 2026-10-28-app · filed by the organizer at b3 close from verify-b3-r1-B's note: `fileRemoveHelp` «Se eliminará de la tarea…» under «¿Quitar este archivo de la tarea?» (UX-2418); could read «Se quitará de la tarea…». Not caused by this run; not yet planned

### UX-2646

**UX-2646** · S1 · B · open · Ticking on the task page re-stamps a reopened Completadas row · `App/lib/screens/task_detail_screen.dart:64` · 2026-10-28-app · filed by the organizer at b3 close from verify-b3-r2-B's note: a row reopened on Completadas, then ticked on its own page, goes through `TaskInteractions.toggle` without `doneAt`, so it is stamped now and listed first next visit (UX-2638 covers the row's own checkbox). Not caused by this run; not yet planned

### UX-2647

**UX-2647** · S1 · C · open · Two picker sheets' titles aren't headings · `App/lib/widgets/task_assignment_picker.dart:148` · 2026-10-28-app · filed by the organizer at b3 close from verify-b3-r1-C's note: «¿Quién es responsable?» (a ListTile) and «Novedades del proyecto» (`project_preferences.dart:22`) are plain rows, unlike the project and role sheets' headings (UX-2514). Not caused by this run; not yet planned

Where they come from: UX-2643 and UX-2644 in `runs/2026-10-28-app/verify-b3-r3-A.md`; UX-2634 and UX-2635 in `verify-b2-r2-D*.md` note 3; UX-2645 in `verify-b3-r1-B.md`; UX-2646 in `verify-b3-r2-B.md`; UX-2647 in `verify-b3-r1-C.md`. The run's reports: `runs/2026-10-28-app/report-b2.md` and `report-b3.md`.
