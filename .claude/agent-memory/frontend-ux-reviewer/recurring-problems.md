---
name: recurring-problems
description: Twenty-four problem types the 2026-10-13 whole-app review found in several areas of TaskFlow (no landing, state last, undo bars that never leave, hidden actions, developer text, duplicates, lost input, large text, help copy outliving its state...), as a checklist to run first on any screen
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

Related: [[ui-patterns]], [[review-techniques]].
