## UX verify — run 2026-10-19-app, b3 round 3, area B — 2026-10-20

Scope: P207 (UX-1639, UX-1633), P208 (UX-1634, UX-1635, UX-1636, UX-1414, UX-1421, UX-1638, UX-1637).
Changed files: `App/lib/screens/day_timeline_screen.dart`, `App/test/day_timeline_test.dart`.
Renders: `calendar/timeline.untimed` and `timeline.normal` (es light 1x/2x) re-rendered 16:12, after the screen's last edit (15:55); no app file is newer. The P208 renders (15:36) are newer than every app file except `day_timeline_screen.dart`, which none of them shows, so they still count.

### Results

| ID | Result | Evidence |
|---|---|---|
| UX-1639 | partly | (a) `day_timeline_screen.dart:207-209` `otherDay(task)`; `:322-328` both `LandedTaskTile` and `TaskTile` in the pinned area take `showDate: otherDay(task)`, so a row of the day shown has no «Hoy» and a task listed for its date-only deadline whose own date is another day keeps naming that day. (b) `:332-339` a full-width `Divider(height: 1, thickness: 1, outlineVariant)` outside the `ConstrainedBox` and its scroll view, shown only with the pinned area. Render `timeline.untimed.es.light.1x`: whole row, no «Hoy», line across the screen, 08:00 and the 08:30 block below. AUDIT (1x) TalkBack reads «Pagar la factura de la luz Prioridad Media», no «Hoy». Not met: render `…2x` still cuts the row through «Prioridad Media» (tester measured row 257–434 dp, area 208–405.3 dp, about 29 dp cut). The cut now ends at a visible edge, and the scrollbar thumb shows there is more, so it reads as "more below" rather than a broken card. That is less severe, but acceptance 1 still fails. Device check (font size 2.0, 393 dp) still open. Next round: the label (49 dp) plus the one row (177 dp) need 226 dp, and the third gives 197 dp. Shortening the day header alone won't close that gap. The smallest structural option is to let the cap be the larger of a third and the label plus the first whole row, but never more than half the space. At 2x on 360x800 that's 226 of 296 dp, and the 08:30 block still shows above «Añadir tarea». This is the organizer's call, because the brief froze the cap. |
| UX-1633 | fixed | The round-2 structure is unchanged by P207: the notices are in the Column at `:245-277`; «Sin hora» is pinned in `ConstrainedBox(maxHeight: space.maxHeight / 3)` (`:283-285`) with its own `Scrollbar` and `timeline-untimed` scroll; the hours are in `Expanded(_hours…)` (`:340-342`). Renders 1x/2x: «SIN HORA», the row (the whole row at 1x) and the 08:30 block are on screen on arrival; `timeline.normal` 1x/2x shows no «Sin hora» and no line, and opens on 08:00. |
| UX-1634 | fixed | `reminder_control.dart:62` returns `reminderForPersonOnly(person)` for the default; ARB EN “Reminder for {name}” / ES «Recordatorio para {name}» / CA «Recordatori per a {name}». AUDIT `tasks/detail · created-by` reads the button «Recordatorio para Ana», with no lead time. The Catalan still needs a native read (a note). |
| UX-1635 | fixed | `completed_tasks_screen.dart:45,57` (`projectPeopleToFilter`, `forMe`). Render `calendar/completed.project-person.es.light.1x`: «Matemáticas · Ana». |
| UX-1636 | fixed | `completed_tasks_screen.dart:109` `project: listId`. The render shows the row with date, «Ana» and priority, and no «Matemáticas» (see the round-2 notes for `completed.list`). |
| UX-1414 | fixed | Catalog scan on the current tree: the EN values containing “transfer” are only `groupTransfer` and `archiveCsvPersonalCopies`; ES matches only `groupTransfer` («Transferir propiedad», which is about ownership). |
| UX-1421 | fixed | No ARB changes since round 2; `schedule` is in none of the three catalogs. The round-2 tests pass in the whole suite. The Catalan still needs a native read (a note). |
| UX-1638 | fixed | `storageFull` ends `({limit}\xa0MB).` in EN, ES and CA. Render `tasks/detail.file-space-full.es.light.2x`: «(100 MB).» on one line. |
| UX-1637 | fixed | `task_tile.dart:274` `SizedBox(width: kMinInteractiveDimension + 4)` in the circle's slot for view-only rows. Render `tasks/project.viewer.es.light.1x`: «Comer con Ana» and «Ensayo general del concierto» start at the same x, with no icon in the circle's slot. |

### Regressions (changed files and the flows they touch)

None found. Checked:
- the landed row (`LandedTaskTile` gets the same `showDate`);
- a timed task of this day listed for a date-only deadline (its row shows only the clock time, which is correct);
- recurring occurrences (`displayDate` is the occurrence date);
- the line's absence on `timeline.normal`;
- that the line stays put while the hours scroll (it is outside both scroll views).

A polish note, not a regression: at 1x the new full-width line sits 13 dp above the 08:00 hour line, and both are the same grey. They read as two separate things because the hour line starts after the time gutter.
