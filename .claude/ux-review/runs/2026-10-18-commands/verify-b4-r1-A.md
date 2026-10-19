## UX verify — 2026-10-18-commands, b4 round 1, area A (P152, P153) — 2026-10-19

**Verdict:** all five findings fixed in code; no regressions found in the changed files or the flows they touch.
**Evidence level:** code read at the working tree, ux-tester's widget tests (all pass), and renders from 2026-10-19 06:54–06:55, which are newer than every file under App/lib and App/assets (`find -newer` lists nothing). No device.

### Results

**UX-917 · fixed** (D1)
- `App/lib/screens/voice_task_screen.dart` `_leave` (~:3333-3357): after the existing `!_worthKeeping()` → `_finishEmpty()` branch, `if (!_items.any((d) => d.pending)) { await _discard(); return; }`. `_items` is `List<CaptureDraft>` (:2260); `CaptureDraft.pending` is `savedTaskId == null && !removed` (`models/capture_session.dart:97`), so only tasks and notes still to add keep the question; changes, deletions, searches and new projects don't.
- `_discard` (:3359-3375) is the same path as «Descartar»: `_store.discard`, `pendingCapturesProvider` invalidated, sheet popped. Nothing applied, nothing left in «Sin guardar».
- Cancel, Back, scrim and swipe all route through `_leave` (Cancel is `Navigator.maybePop`). Comment over `_leave` updated.
- Tests (pass): Cancelar / Back / scrim on deletion-only; change-only; project-only; UX-903's two keep-question tests now carry a task beside the deletion.

**UX-919 · fixed** (D3)
- `captureSaveAsWritten`: EN “Save as a task” (`app_en.arb:1616`), ES «Guardar como tarea» (`app_es.arb:978`), CA «Desa-ho com a tasca» (`app_ca.arb:758`); `@captureSaveAsWritten` description added (:1617-1619); `@calendarTrySaying` description renamed (:314). No catalog value says «tal cual», “as written” or «tal com està» (grep).
- Comments renamed in voice_task_screen.dart, capture_processor.dart:53, subscription_provider.dart:85; preview description in commands_previews.dart:564.
- Renders: `capture/sheet.understanding-slow.es.light.2x.png` and `.ca.light.2x.png` show the filled button whole on one line («Guardar como tarea», «Desa-ho com a tasca»); `commands/cards.not-found.es.light.2x.png` shows «Guardar como tarea» above «Cerrar». AUDIT: no clipped text; the 4 dp gap to Cancelar at 2× and the 52 dp height are as before the rename.

**UX-920 · fixed (app)** (D4)
- `App/lib/services/task_matcher.dart`: `_when` replaces `_within` and returns when the task falls in the period (planned day, else deadline; a repeating task's first repetition in it via `occurrencesOn(day).firstOrNull.displayDate`); `_soonestFirst` sorts by day, untimed before timed, then time; ties `_newestFirst`; no period → newest first as before. `_ranked` keeps the order inside its title/notes groups, so title matches still lead.
- Doc comments updated (task_matcher.dart `find`; capture_command_cards.dart:42 and the `FindCommandCard` comment).
- Still open outside the app: `Backend/docs/VOICE_COMMANDS.md:100` says newest first — for the main session, as the brief says. Not counted against the app fix.

**UX-918 · fixed** (D2)
- `_fillByHand` (voice_task_screen.dart ~:1560-1606) passes `spoken = session.source == 'speech' || session.audioPath != null` and `heardAt = session.capturedAt.toLocal()` through `openTaskForm` (task_form_entry.dart) into `NewTaskArguments` (edit_task_screen.dart).
- `NewTaskScreen._start` parses only when `spoken`, with `day: later` and `keepAmbiguousHour: true`; builds title/notes/dueDate/hasTime/deadline/deadlineHasTime/reminderAnchor exactly as `localDrafts` does (local_capture.dart:73-123), including “words that are only a date stay the title”.
- `QuickScheduleParser.parse(keepAmbiguousHour)` (quick_schedule_parser.dart:270-279): with the flag a bare 1–12 hour sets no `ambiguousHour` and isn't cut from the title. With no date words and only a bare hour, `parse` returns null, so «Médico a las 5» alone opens as typed with no day (today isn't assumed).
- Shared text and typed captures reopened from «Sin guardar» go through `_typedWords` (voice_task_screen.dart:143-164, which excludes `source == 'speech'` and audio) and never set `spoken`: they stay as typed.
- Render: `form/new-task.from-dictation.es.light.1x/2x.png` — title «Médico», «vie, 23 de oct» selected, time chip «17:00».

**UX-1010 · fixed** (D6)
- `App/lib/widgets/task_editor.dart` `_add()` (~:561-640): the `back` flag is gone; message is `taskAddedOn(day)` / `taskAddedDue(deadline)` / `taskSavedInbox`, always with Deshacer; `CalendarFocus(day ?? due, …, undated: day == null && due == null)`, so a deadline-only task lands lit on its deadline's day as the capture sheet does.
- Editing a saved task keeps `changesSaved` (the edit branch of `_save` is untouched; `task_detail_test` UX-211 passes).

### Regressions (changed files and touched flows only)
None found. Checked: an unchanged edit path; empty-words `Escribir` (parse of '' → null); no-date dictations with a later day shown (still that day); deadline + bare hour (title keeps the hour, deadline has no time); `reminderAnchor` default is 'planned' (`models/task.dart:79`), so the form's explicit value changes nothing for dated tasks; search rows keep P137's look.

Seen but not new (pre-existing, not counted): form AUDIT reports «17:00» and «Quitar hora» overlapping (P139's time chip); slow-state render shows the transcript scrolled under «Entendiendo…».

### Device checks left for the owner
- Staging, real model, ES: «Borra la tarea del dentista» → Cancelar closes at once; «Sin guardar» shows nothing new.
- Airplane mode, ES: dictate «médico el viernes»; after the failure the filled «Guardar como tarea» saves it on Friday.
- Free account with dictations left, ES, real speech: «Médico el viernes a las 5 de la tarde» → Escribir → form on Friday 17:00; Añadir tarea lands on Friday.
