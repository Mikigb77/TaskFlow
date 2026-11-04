---
name: recurring-problems
description: Forty-six problem types the 2026-10-13 whole-app review found in several areas of TaskFlow (no landing, state last, undo bars that never leave, hidden actions, developer text, duplicates, lost input, large text, help copy outliving its state...), as a checklist to run first on any screen
metadata:
  type: project
---

Problem types the 2026-10-13 whole-app run (slices A–D) found in more than one place. The examples are only illustrations; the issues and their status are in `.claude/ux-review/ISSUES.md`.

**Why:** these are this codebase's habits, so new screens and fixes tend to repeat them.
**How to apply:**
- Check every screen in scope for each type before the rest of the method.
- When a fix lands, check it didn't re-create one — for example, a new undo bar without `persist: false`.

1. **Nothing shows where the item went.**
   - There's no landing after:
     - a voice save or a typed save;
     - a move;
     - a new note (the list is unsorted);
     - a new project (sorted alphabetically);
     - an accepted invitation.
   - For tasks, the root cause is that the Calendar's selected day can't be set from outside.
2. **The result or the real state comes last.**
   - Messages name the action, not the result: "Tarea añadida al calendario", "Programación actualizada", "Project archived. Contents kept."
   - Labels end with the truth: "Recordatorio: 10 minutos antes · desactivado en el dispositivo".
   - Activity rows put who did what after the task title.
3. **Defaults and empty things are shown as content.**
   - "Prioridad Baja", "No se repite", "Sin texto añadido.", "No hay archivos adjuntos".
   - "Bandeja · 0", "All projects" with no projects, a heading with nothing under it.
   - Controls that only matter later are shown from day one (U10).
4. **Undo bars never leave.**
   - Any snackbar with an action needs `persist: false` plus `FeedbackTimeout.forAction()`, and most lack it.
   - So stale "Deshacer" buttons follow the user onto other screens and sit over primary buttons.
5. **Irreversible actions are handled the wrong way round.**
   - Reversible actions get a confirmation dialog with the destructive button filled — for example, deleting a task.
   - Irreversible ones happen in one tap: moving a task into a shared project, declining an invitation, archiving a group.
   - Undo is missing almost everywhere except task completion.
   - Destructive controls sit beside frequent ones (✏ 🗑 🌙 on the task detail; Decline 8 dp from Accept) and look like normal teal buttons.
6. **Main actions hide behind unlabelled icons, ⋮ menus or top corners.**
   - A folder icon opens Projects; ⋮ holds sharing and reminder timing; ✏ edits a task or a note; ✓ opens completed tasks.
   - The bell means Activity in the header, but reminders everywhere else.
7. **Developer text appears on user screens.**
   - "Diagnóstico de captura" (P50/P95), "Detalles de conexión", raw time-zone IDs, "MiB".
   - "La dirección del servidor" in network errors; raw English server errors during capture.
   - The widget-picker description ("retained capture flow").
8. **Things are duplicated.**
   - **Controls:** the theme toggle ×23, language ×2, account ×2.
   - **Parallel versions:** two date sheets, two repeat editors, two task forms, 3–4 create buttons, and two project filters (a chip, and the Notes dropdown).
   - **Names:** the stop button has three (Parar / Detener la grabación / Parar y crear borrador); other people have four (Team / Everyone / Members / People); checklists have four in Spanish.
9. **Copy is borrowed from another context.**
   - Notes use task strings.
   - The group code dialog shows the inviter's text to the invitee, with a "Save" button.
   - Load failures say "could not be saved".
10. **Translation slips.**
    - The Lista → Proyecto rename produced "Proyecto de pasos" and feminine agreement ("Archivada").
    - Spanish "Mañana" reads as "tomorrow", not "morning". "Captura" reads as a screenshot.
    - Catalan mixes infinitive and imperative buttons.
    - ICU plurals are missing ("1 completadas").
    - Spanish said "Dictar" in the app but "Dicta" on the widget and shortcut (since aligned).
    - One Android string serving several surfaces (shortcut label, widget text, TalkBack name, picker name, help copy naming it) means changing it for one surface renames the others; fixing one half left EN "Say a task" vs "Dictate a new task" (UX-1656 → UX-1657). Give each surface its own string, then grep every surface and ARB line that names it.
11. **The app acts without the user, or silently.**
    - Capture records are written before any words.
    - Listening stops when the notification shade is pulled down.
    - Archiving or muting a project silently stops its reminders.
    - The view filter becomes where new tasks are saved.
    - Signing out cancels reminders.
    - The selected day stays on yesterday after midnight.
12. **Typed input is lost.**
    - Back in TaskEditor drops everything.
    - A failed group dialog loses the name or email.
    - Switching login mode clears the password.
    - Session expiry rebuilds the navigator.
13. **Key content falls off-screen at 1.3–2× text.**
    - Today's tasks; the live words while listening; the capture and sign-up error banners.
    - At 2× and 320 dp, labels break mid-word: the theme tiles, "Proyectos" next to "Grupos", the Catalan tab label.
    - Making a label bigger or bolder (P28: tab labels 11 → 12 sp, w800) broke Spanish "Calendario" at < 348 dp. Any size, weight or letter-spacing change to a fixed-width label needs a 320 dp, 1.3×/2×, es+ca width check.
    - Fixes for large text can cap it somewhere else: a MediaQuery clamp also capped the tab tooltips (R2D-1).
    - Fit-to-width fixes that measure in Flutter can land with ~1 dp spare; device text shaping may still wrap. Ask for a margin or a device capture.
14. **Colour or faint contrast carries meaning alone.**
    - An overdue deadline only turns red. The calendar dots differ only by colour. Unread shows only as a 16 px icon.
    - The disabled project chip is at about 38%.
    - Field borders (was 1.28:1) and tab state (was pill-only) were fixed on 2026-10-13; check new components don't reintroduce `outlineVariant` as the only boundary.
15. **Words get in the way where the user has to act.**
    - Slogans instead of mode names on the login screen.
    - Eyebrow labels ("TU PRÓXIMO PASO", "A TU GUSTO") and headlines that repeat the app bar.
    - Permanent help paragraphs: Notes, the timeline, "Más detalles", the 73-word invite dialog, about 135 words in Notificaciones.

16. **Text matching that rewrites pairs breaks search-as-you-type.**
    - P11 folded `l·l` → `ll`, so the half-typed `col·` matched nothing for one keystroke (UX-425).
    - Fold one character at a time and test every prefix. Watch for the same with apostrophes (`'`/`’`) and any future normalisation.
17. **Work hidden behind tabs runs on every change.**
    - IndexedStack keeps Tareas and Notas built; their filters re-run on every task change anywhere (UX-426).
    - Any new per-item cost in a root tab's build is paid on every save in the app.

18. **Background work is awaited in the tap path.**
    - Save waited for a full server sync; Listo waited for diagnostics writes; every capture open re-checked speech capability and swept old captures before the mic (UX-601/603/610, 2026-10-14).
    - On any tap → visible result, look for `await` on sync, logging, diagnostics, time-zone lookups or housekeeping; they should be `unawaited` or done once per session.
19. **A fix that removes a question creates silent wrong results.**
    - Making «de la mañana» settle 09:00 removed the hour question, so a past time saved today silently with no reminder (R1A-1 → UX-618).
    - When a fix removes a question, check the cases the question used to catch (past times, ambiguity), especially on "Guardar tal cual", where nothing is shown before saving.
20. **One-flag visual conditions miss in-between states.**
    - A divider hidden "when notes show" also vanished when other rows sat between the notes and Más opciones (R2A-1 → UX-620); it took three rounds.
    - For separators conditioned on a neighbour, enumerate every row the build can draw between the two, and have the flag derived from the same conditions the build uses.
21. **Copy written for the scheduled moment is read at a different moment.**
    - Relative alert text ("dentro de 10 minutos") was false on late delivery; then the snooze reused the original `· en 10 min` tail and was false again (UX-409, R1D-1 round).
    - For any text built ahead of display (notifications, widget, scheduled copy), ask what it says when shown late, snoozed, or after midnight. Prefer absolute times.
22. **"Show once" conditions derived from live data come back.**
    - The first-run instruction keyed on an empty task list returned after deleting the only task (U12 round 1).
    - One-time teaching needs a persisted, per-account flag; check delete-to-empty, restart, account switch and the loading state.
23. **Fixed timeouts outside the in-app snackbar path ignore accessibility settings.**
    - The notification Undo started at a fixed 10 s (R1D-1 → UX-631). Background isolates can't read the platform timeout, so it must be stored from the foreground.

24. **Instruction copy outlives the state it describes.**
    - On delete-account, «O confirma con Google…» stayed after Google had confirmed: an alternative to nothing, asking for an action already done (R1D-1 → UX-1232, b5).
    - For any help line that offers an alternative or asks for an action, check each state after the action succeeds, fails and is retried; derive the line's visibility from the same state as the control.

25. **Scroll-reveal targets drift between states of the same card.**
    - Skipping the reveal for set deletions hid a red card below a task card (R1A-2 → UX-1718); revealing the question box instead of the card then pushed the heading and ✕ off the top once the project was answered (R2A-1 → UX-1719). Three rounds.
    - For any `ensureVisible`, enumerate: lone card, mixed result, before/after a question is answered, card taller than the view at 2×. Name what must be visible (heading + way out), and reveal that.
26. **New plural copy fed a count that isn't known yet.**
    - ✕ on a set still asking «¿Qué proyecto?» fell back to count 1 and spoke in the singular (R1A-1 → UX-1717).
    - When a string takes a count, check every state where the count is null (asking, loading, not found) and pick the form for what the thing is, not 1.

27. **Scaling a decoration with text steals the label's room.**
    - Growing the chip ▾ with the text scale (UX-1722) took 5 dp more of the row at 2×, and the Catalan day chip lost its time «· 10:00» (R2A-1 → UX-1724).
    - When an icon, badge or mark grows with text, check the longest locale at 2× on 360 dp; reserve the old layout width and let the glyph overflow its box visually.
28. **A landing or remap rule keyed on a flag, not on before/after.**
    - Landing sent every overdue item to Today, even ones a −1 shift moved to yesterday (R1A-2 → UX-1723).
    - For any "where does the user land" rule, check it against items that moved and items changed in place; derive it from the item's day before vs after.

29. **A new model rule exposes an old row/label branch nobody reached before.**
    - Voice moves of deadline-only tasks stopped creating a planned day (UX-1715, correct), and every such landing row then printed the long-standing «Sin fecha» beside «Movida al …» (R1A-1 → UX-1725).
    - When a change makes a new data shape reachable (no date + deadline, done + dated, etc.), render where that item lands and read the row's first words against the confirmation next to it.

30. **A control's placement keyed on mutable state jumps away on the user's own change.**
    - The capture card's reminder moved from «Más opciones» to above it as soon as it was changed there (`setState(_reminderOpen = true)`, R1A-1 → UX-2016); the fix (place once, `late final`) then left no summary once closed (R2A-1 → UX-2018). Three rounds.
    - For any "show here if X, else there", check: does editing the control flip X? Decide placement once, and when you move or remove a summary, check what the closed state still says.

31. **Copy examples that collide across tiers.**
    - The Pro screen's example was Normal's free rhythm, which the free offer had just proposed (R1D-1 → UX-2017).
    - Any "Pro lets you…" example must be something no free option produces; grep the free strings for it.

32. **No-break spaces bound one word short.**
    - U+00A0 in «las 8» stopped the lone «8» but left «a» dangling (UX-2019 → UX-2020, open).
    - Bind the whole phrase («a las 8», «a les 8») and check es 1×/2× renders, not only the widest locale.

33. **A new line inserted between an element and its attached question.**
    - The needs-day line went "under the date", landing between the date line and its open «¿Qué día?» box, asking for the day twice (R1A-1 → UX-2023).
    - When adding a row next to a field, check the field's open-question/helper children first; new rows go after them.

34. **A new preview exposes an old narrow-label wrap.**
    - P253's far-date strength preview showed the strip's end label «dt., 22 de des.» wrapping its final «.» at ca 2× (`reminder_plan_sheet.dart` strip labels each `Expanded` half width); pre-existing, not filed.
    - Abbreviated Catalan dates end in «.»; check half-width date labels at ca 2× with far dates.

35. **A no-tap element keeps its control look or state.**
    - A reminder line made non-tappable kept the outlined chip box (R1B-1 → UX-2034), and the capture row kept `enabled: onTap != null`, so TalkBack would read «Recordatorio para Marta, desactivado» — "the reminder is off" (UX-2025).
    - When a control loses its tap, check both the look (outline, fill, chevron) and the semantics (button role, enabled state); tests asserting only `hasTapAction: false` miss the enabled state.

36. **Pinning a header removes the scroll cue.**
    - Fixing the reminder sheet's title + note above a list that opens scrolled to a plan hid that rows sat above (R1D-1 → UX-2035, fixed with a 1 dp edge).
    - When content moves out of a scroll view into a fixed header, check the "opens mid-list" state at 2×: there must be an edge, and check what sliver of a scrolled row peeks under it (it is still a tap target).

37. **"Empty" judged by one field lets an automatic action discard what the user set.**
    - Entry absorption counted a sheet empty by live words (missed online recordings, R2A-1 → UX-2641) and a form empty by its title (dropped a picked date/checklist/photo, R3A-1 → UX-2643).
    - Any rule that closes or reuses a screen without asking must use that screen's own "holds input" test (`_hasInput`, the editor's `_edited()` vs `_unchanged`), not a proxy. Absorbing (loses nothing) can be looser than closing.

38. **A rule checks the stack once, then changes it.**
    - Close-first popped a sheet, uncovering one the entry should have joined, but opened a second anyway (R3A-2 → UX-2644).
    - After any pop inside a decision, re-check what is now on top.

39. **Reusing whatever is open ignores why it was opened.**
    - An empty form opened for a picked day, shared project or person absorbed an outside entry, so the new task inherited that context (R2A-2 → UX-2642).
    - Reuse only routes whose arguments match what the entry would open itself.

40. **A sheet without `isScrollControlled` is capped at 9/16 of the screen.**
    - Adding a drag handle + heading pushed the project sheet's last row («Nuevo proyecto») half below the edge (R1C-1 → UX-2639).
    - Whenever a sheet gains a header row, check its last row in a render; prefer the shared 70%-cap picker shape.

41. **An action that leaves the screen turns a hesitant second tap into a tap on the screen below.**
    - Completar now closes the task page; a second tap landed on Calendar's «Añadir tarea» (R1B2-1).
    - Check what sits at the same spot on the screen underneath.

42. **Scaled icons in benefit/feature lists push the status off the fold at 2×.**
    - The Pro screen's check icons scaled to 40 dp and hid «Dictados gratis» (R1D-1 → UX-2640, fixed: fixed 20 dp icon in a first-line-height box, plan status first).
    - Keep list icons fixed size; put what the person came for (status, counts) before the pitch.

43. **One-tap rows replacing a compact control push the primary below the fold at 2×** (repeat sheet, R1B1-2), and a pinned primary then hides that content continues (R2B-1). See 36.

44. **Sync gates comparing the phone's row with the server's "now" fail when the other side changed first** (D9 reader reminders). Look for a persisted intent marker (`own_reminders_pending`).

45. **A wrapping label stretches to the full width, leaving its icon at the edge.**
    - Four times so far: UX-2608, UX-2630, the form's «Añadir al / calendario» (UX-2634), the CA reminder chip (UX-2635). Fix is always `textWidthBasis: longestLine` + centre (only if tappable).
    - Check every `.icon` button and icon chip whose label can wrap at 2× in ES/CA.

46. **A page opened from a list loses the list's context.**
    - The task page opened from Completadas stamped a new completion time, so the row jumped (UX-2646). Same family as 39.
    - When a list holds per-row state (a remembered time, a scope), check that the row's page and its actions receive it.

47. **A permission ask whose button can silently do nothing.**
    - On Android 13+ after notifications were turned off in Settings or refused twice (and on ≤12 when off), `requestPermission()` shows nothing and returns false; the meeting card's «Continuar» then did nothing (UX-2902).
    - Every ask must handle false/throw with the existing line «El teléfono no deja que TaskFlow te avise.» + «Permitir avisos» (opens settings).

48. **A one-time ask that a stray tap spends.** A dismissible dialog marked "asked" on any close, so a scrim tap used the only ask (UX-2904). One-time asks: `barrierDismissible: false`, Back still closes.

49. **One-sentence card copy that is only a purpose clause.** «Para pararla desde la notificación…» named neither the subject nor the request, and its pronoun had no antecedent (in CA the gender pointed at the wrong noun) (UX-2901). Name the noun; say what is asked.

50. **A page's main button decided by an async read flips after the first frame.** The meeting-note bar showed one filled «Editar nota», then «Crear tarea» appeared, on every open (UX-2903). Fix: keep-alive provider, pre-read in the shell, hold the place while unread.

51. **A new per-item mark leaves data saved by the previous build unmarked.** Meeting notes saved before D1's marks lost «Crear tarea» until a schema-23 step filled the marks from what can still be traced (UX-2905). When a release adds a mark, ask what older rows get.

52. **An added line with the same spacing and style as an open-ended example reads as its continuation** (Pro screen hours under the colon-completing example, UX-3001). Also: any copy with a count needs a whole-sentence ICU plural (UX-3002).

Related: [[ui-patterns]], [[review-techniques]].
