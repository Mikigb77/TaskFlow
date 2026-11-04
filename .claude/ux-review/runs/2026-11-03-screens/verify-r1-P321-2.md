## UX verify — P321, round 1, check 2 — 2026-11-03
Worktree `.claude/worktrees/wf_b7a20ea0-e5f-2`. I read the package diff (waves.py), the changed code, the renders and the tests. Evidence comes from code, renders and the tester's widget/unit tests only. Nothing ran on a device.

**Verdict:** Ship. R1-P321-1 is fixed and no new regression was found. UX-2705, UX-2708 and UX-2718 stay fixed. UX-2710 stays partly fixed, because its server half is Backend and out of scope.

### What the fix changed since check 1
- `App/lib/l10n/meeting_copy.dart`: the new `meetingDate` writes the weekday in full.
  - ES and CA use `DateFormat('EEEE d MMM')`.
  - Other languages use the locale's `MMMEd` with `EEE` widened to `EEEE`.
  - All languages then add `, ` and the locale's `Hm` (24-hour).
  - It calls `initializeDateFormatting()` for a caller without Flutter's data. intl's initializer runs only while its data is still uninitialized, so it does nothing once Flutter has loaded its date data. If it runs first, Flutter's later `initializeDateFormattingCustom` adds to the same maps, which can be changed. Neither order fails or changes the output. I checked this in the intl 0.20.3 source.
- The `meetingNoteHeader` ARB description, a comment in `meeting_note.dart`, the P321 test (now exact lines in ES, CA and EN) and the preview fixture (`meeting_previews.dart`, with «Reunión del martes 3 nov, 10:15 · 52 min»).

### Regressions from check 1
**R1-P321-1 · fixed** («Reunión del mar» read as "meeting of the sea")
- Render `meetings/note.create-task.es.light.1x` (23:35, newer than every file under `lib/` and `assets/`): «Reunión del martes 3 nov, 10:15 · 52 min» opens «Tu nota».
- The test `meeting_screens_test.dart` "UX-2710: …" now expects these exact lines, and they pass:
  - «Reunión del martes 3 nov, 10:15 · 52 min»
  - «Reunió del dimarts 3 de nov., 10:15 · 52 min»
  - “Meeting on Tuesday, Nov 3, 10:15 · 52 min”
- Flutter's own date data has the same months and weekdays (`generated_date_localizations.dart`):
  - CA short months «de nov.» and «d’oct.», with `Hm` `H:mm`;
  - ES short months «nov» and «sept»;
  - EN `MMMEd` `EEE, MMM d`.
  So the app shows the same line that the tests check.
- Note: a Spanish meeting in March reads «del martes 3 mar». After a day number that is the usual short form of the month, so it is not a regression.

### Findings
**UX-2705 · fixed.** Unchanged since check 1.
- `meetingLength` and `meetingMinutes` are in meeting_copy.dart.
- `meetingElapsed` is used only by the recording screen's counter (`meeting_screen.dart:506`).
- Recording line: `meeting_banners.dart:241`. Stopped card `time`: :263. Waiting card's «Descartar» name: :309.
- Chapters read «Minutos a–b · …» while a part ends within the first hour, and lengths after that (`chapterRange`).
- Renders `meetings/notes-lines.*`: «Grabando una reunión · 12 min» and «se detuvo en 1 h 42 min».
- Those renders are a little older than the fix's changes to `meeting_copy.dart`. The fix touched only `meetingDate`, which the lines don't use, so they are still evidence.
- The tests cover the formatter in all three languages and check that no `\d:\d\d` appears in the lines' text or TalkBack names.

**UX-2708 · fixed.**
- `task_detail_screen.dart:445` puts a note's steps before the body, and :498 keeps a task's order.
- Render `note.create-task.es.light.1x`: title, «PASOS · 0/3» with three steps, then «TU NOTA», with no scrolling.
- `notes/note.with-steps.es.light.1x` shows the same order.
- At ES 2×, the first step is partly under the bottom bar. That is expected, since the acceptance check is at 1×.

**UX-2710 · partly fixed.**
- The app part is done.
  - The note opens with the meeting line, before «start missing» and the summary (`meeting_note.dart`, `meetingNote`).
  - The store passes `startedAt.toLocal()` and `recorded` (`meeting_store.dart:809-810`).
  - The line now reads naturally (R1-P321-1).
- Still open: the server's absolute «when», which is Backend. «Crear tarea» still carries only the title and the steps, so a to-do's «el viernes» has no anchor on the task. That needs the server part, so it is not counted against the package.

**UX-2718 · fixed.**
- The recording time has `semanticsLabel: meetingElapsedLabel(l, elapsed)` (`meeting_screen.dart:507`). It is not a live region and still shows «12:03».
- The ICU plurals are correct in ES, EN and CA.
- «Abrir» is named «Abrir la grabación» (`meeting_banners.dart:243-247`).
- AUDIT agrees on both labels.
- No real TalkBack was heard.

### New regressions
None. I checked:
- the note page's order and bottom bar (render);
- the line for other languages: `meetingLocalizations` falls back to English, and its locale guard keeps the date in that language;
- the 24-hour time in all three locales;
- that the date code cannot clash with Flutter's date data.

### Outside my lane, for the merge (unchanged from check 1)
- The diff still changes `App/analysis_options.yaml` (analyzer excludes) and `App/pubspec.lock` (intl 0.20.2 → 0.20.3 and others). Neither is in the package's file list, and the merge should decide whether to keep them.
- `meeting_copy.dart` now imports `package:intl/date_symbol_data_local.dart`, which bundles every locale's date data into the app.

### Memory notes
- A meeting note's first line is «Reunión del {weekday in full} {d MMM}, {H:mm} · {length}», from `meetingDate` in meeting_copy.dart. The weekday is always written in full: a short «mar» reads as "sea".
