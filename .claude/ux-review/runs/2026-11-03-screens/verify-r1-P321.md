## UX verify — P321, round 1 — 2026-11-03
Worktree `.claude/worktrees/wf_b7a20ea0-e5f-2`. I read the diff (waves.py), the changed code, the renders (all newer than every file under `App/lib` and `App/assets`) and AUDIT.md. Evidence comes from code, renders and widget-level AUDIT only. Nothing ran on a device.

**Verdict:** Ship. Three findings are fixed and UX-2710 is partly fixed: the server's half is Backend and out of scope. There is one polish regression, in copy the brief itself gave.

### Findings
**UX-2705 · fixed**
- `meetingLength` and `meetingMinutes` are in `App/lib/l10n/meeting_copy.dart:63-76`. `meetingElapsed` (:93) is now used only by the recording screen's big counter (`meeting_screen.dart:506`). No other `meetingElapsed(` or `meetingClock` call is left in `lib/`.
- These lines now use lengths in words:
  - the recording line (`meeting_banners.dart:241`);
  - the stopped card's `time` (:263), the only change to that card;
  - the waiting card's «Descartar» name (:309).
- Render `meetings/notes-lines.recording.es.light.1x`: «Grabando una reunión · 12 min».
- Render `notes-lines.stopped-and-waiting.es.light.1x`: «Tu grabación se detuvo en 1 h 42 min.»
- Chapters (`meeting_note.dart:109-117`, `chapterRange` in meeting_copy.dart:20-22): a part that ends within the first hour reads «Minutos 0–30 · …», a later one «1 h 30 min – 2 h · …». AUDIT's TalkBack value for note · create-task reads «Minutos 0–30 · Presentaciones y alcance … Minutos 30–52 · Precio del piloto».

**UX-2708 · fixed**
- `task_detail_screen.dart:442-445` puts a note's steps before the body. Tasks keep notes → reminder → steps (:498).
- Render `meetings/note.create-task.es.light.1x`: title, then «PASOS · 0/3» with all three to-dos, then «TU NOTA», with no scrolling.
- Render `notes/note.with-steps.es.light.1x`: the same order. In TalkBack's order, «PASOS · 0/3» (item 5) comes before «Tu nota» (item 11).
- At ES 2× the first step is partly cut by the bottom bar. That is expected: the acceptance check is at 1×.

**UX-2710 · partly fixed**
- App part done: `meetingNote` opens the body with the meeting line (`meeting_note.dart:109-111`), before start-missing and the summary. The store passes `startedAt.toLocal()` and `recorded` (`meeting_store.dart:809-810`). Production always passes `meetingNoteLabels(language)` through `MeetingHooks.labels` (`meeting_uploader.dart:383`), so the line is always there.
- Render: «Reunión del mar, 3 nov, 10:15 · 52 min».
- Still open: «Crear tarea» copies only the title and the open steps into the new task (`note_task.dart:39-53`). The note body, which holds the date, goes only into the review's transcript. On the task itself, «Enviar el presupuesto · Miki · el viernes» still has no anchor. The fix for that is the server's absolute "when", which is Backend. The implementer rightly left it out, so this is not counted against the package.

**UX-2718 · fixed**
- The time has `semanticsLabel: meetingElapsedLabel(l, elapsed)` (`meeting_screen.dart:507`). It is not a live region, and the screen still shows «12:03».
- AUDIT recording · listening reads text «12 minutos y 3 segundos grabados».
- The plurals in `meetingRecorded*` are correct in ES, EN and CA, including the hour form «1 hora, 4 minutos y 5 segundos grabados».
- «Abrir» now goes through `_action` with «Abrir la grabación» (`meeting_banners.dart:243-247`); AUDIT notes-lines · recording reads button «Abrir la grabación».
- No real TalkBack was heard.

### Regressions
**R1-P321-1 · Severity 1 · «Reunión del mar» reads as "meeting of the sea"**
- Where: `App/lib/l10n/app_es.arb` `meetingNoteHeader` «Reunión del {date} · {length}» with `DateFormat.MMMEd` (`meeting_copy.dart:258`). Render: `meetings/note.create-task.es.light.1x`.
- The moment: «Reunión del mar, 3 nov» — "del mar"? «del sáb», «del mié» are also not how Spanish speaks; a person says «del martes 3 de noviembre».
- Cause: the copy came from the review's own fix (UX-2710) and the brief. The implementer followed it.
- Fix: write the weekday in full, keeping the short month: ES «Reunión del martes 3 nov, 10:15 · 52 min», CA «Reunió del dimarts 3 de nov., 10:15 · 52 min», EN “Meeting on Tuesday, Nov 3, 10:15 · 52 min”. Use the locale's EEEE plus d MMM, for example `DateFormat('EEEE d MMM', locale)`, or MMMMEEEEd if the long month fits. Keep the `meetingNoteHeader` key and update the tests' «Reunión del» … «nov» checks.
- Evidence: seen in a current render.

No other regression found:
- the recording line's «Abrir» keeps the same TextButton look and place (render);
- notes without steps are unchanged;
- a task's page is unchanged (test, and code at :498);
- the stopped card's text and buttons are untouched apart from `time` (P322's).

### Outside my lane, for the merge
These are not UX findings. The package diff also changes two files that are not in its file list:
- `App/analysis_options.yaml` (adds `analyzer: exclude:`);
- `App/pubspec.lock` (intl 0.20.2 → 0.20.3, matcher, meta, test_api, vector_math).

They look like changes from setting up the environment. The conventions put `pubspec.yaml` and environment changes out of scope, so the merge should decide whether to keep them.

### Memory notes
- On a note's page, its steps now come before «Tu nota»; a task keeps notes → reminder → steps (`task_detail_screen.dart` `_steps`).
- Meeting lengths in words, from `meetingLength` and `meetingMinutes` in meeting_copy.dart. The `m:ss` clock is only on the recording screen's counter, and TalkBack reads it as words (`meetingElapsedLabel`).
- A meeting note's body opens with «Reunión del {date} · {length}». Chapters read «Minutos a–b · título» within the first hour.
- Recurring problem 21 (copy written for one moment, read later) still holds for a task made from a note: «Crear tarea» carries the steps but not the date line.
