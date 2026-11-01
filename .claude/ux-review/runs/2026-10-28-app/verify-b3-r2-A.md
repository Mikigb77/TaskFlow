## UX verify — run 2026-10-28-app, round 2, area A (P308, P309) — 2026-11-01

**Verdict:** Ship after fixes. UX-2110, UX-2637 and UX-2636 are fixed at widget-test and render level (device checks for P308 still to do). Two small regressions from P308's new rule: the "empty" test misses a recording with no live words, and the form check absorbs into any empty form, whatever it was opened for.

Evidence levels: code read in the working tree on HEAD b14d9cc (`git diff HEAD` of main.dart, voice_task_screen.dart, edit_task_screen.dart, task_editor.dart, task_form_entry.dart, the three ARBs); renders `capture/result.as-written.{es.light.1x, es.light.2x, ca.light.2x}` (13:25, newer than the code and the ARBs); `App/build/ux/AUDIT.md` § capture/result · as-written; test groups named, not re-run. No device captures (`App/build/ux/device/` absent).

### Findings

**UX-2110 · fixed (widget level; device pending)**
- Forms: `NewTaskRoute` (`App/lib/screens/edit_task_screen.dart` ~:111-141), installed on push with `empty = true`, used by `/newTask` in `App/lib/main.dart` ~:565. TaskEditor keeps it current from the title (`App/lib/widgets/task_editor.dart` ~:317-336: `_title.addListener(_markEmpty)`, set again in `didChangeDependencies`), the same test D12's Back uses.
- The used-up notice counts as the form while it's being decided and while it shows (`_notices`, `App/lib/widgets/task_form_entry.dart` ~:43-72, :95-112, removed in `finally`).
- `_openEntries` (`main.dart` ~:189-213) acknowledges a non-share entry when `captureOpensForm(..., typing: !voice) && emptyTaskFormOnTop(navigator)`. `captureOpensForm` (`App/lib/screens/voice_task_screen.dart` ~:160-163) is now the one test `showCaptureSheet` uses too (~:92), so the two can't drift. Shares still open their own.
- Tests: `capture_free_dictations_test.dart` group 'P308 · one entry, one sheet or form' (:3843) covers two TEXT entries 300 ms apart, two already pending, «Pan» typed then a second form over it, 0 left with the notice seen and not seen; `capture_sheet_test.dart` 'P308 …' (:3835) the Pro sheet cases and shares; 'P292 · one sheet per double tap' still passes.
- Device: double-tap «Escribir una tarea» (free) → one form, Back → Calendar; double-tap the widget (Pro, and free with 0 left).

**UX-2637 · fixed (widget level; device pending)**
- `_CaptureSheetRoute` carries `_typing` next to `_empty` (set on push, `.._typing = typing`, ~:153; kept every build by `_markEmpty`, ~:2264-2270). `emptyCaptureSheetOnTop` returns `CaptureMode?` (~:205-221).
- `main.dart`: same mode → acknowledge; other mode → `navigator.pop()` then open what the entry asks for. A VOICE entry onto an empty typing sheet now leaves one sheet, listening.
- Tests: 'P308 …' in `capture_sheet_test.dart` (:3835-…): TEXT then VOICE → one sheet, no focused field, «Listo», `speech.starts == 1`, both entries acknowledged; Cancelar → Calendar with nothing under it; and VOICE then TEXT → one typing sheet.
- Device: Pro, «Escribir una tarea» from the shortcut, Home, widget mic → one sheet, listening.

**UX-2636 · fixed**
- `fromYourWords`: ES «Según tus palabras», CA «Segons les teves paraules», EN “From your words”; `keepAsTyped`: EN “Keep my words”, ES and CA unchanged; both @descriptions updated; generated files match (es :1313, ca :1306, en :1279). No other «escrito» left on the card; the only other use of the keys is `capture_review_editor.dart:361-365`.
- Render `capture/result.as-written.es.light.1x`: «Mañana», «Según tus palabras · Dejar como está». AUDIT TalkBack: 4 «Según tus palabras», 5 «Dejar como está»; no «escrito».
- `ca.light.2x`: «Segons les teves paraules» wraps to two lines and «· Deixa-ho com està» to a third, whole, nothing clipped. The dangling «·» at the line start is the existing Wrap layout (the old Catalan string was the same length), not this change.
- Tests: 'P309 · Según tus palabras' (:4051) for ES/EN/CA and the spoken card; U8 / UX-204 updated.

### Regressions

**R2A-1 · Severity 2 · A text tap closes a voice sheet holding a recording**
- Where: `App/lib/screens/voice_task_screen.dart` ~:2284 `_markEmpty(result == null && !_hasWords)` with `App/lib/main.dart` ~:212 `if (top != null) navigator.pop();`.
- The moment: (widget mic, the phone listens online, says «Te escucho. Al tocar Listo verás lo que he entendido.», they speak, a call comes, later they tap «Escribir una tarea») "I'd said it all — where did it go?"
- What happens: in online listening (`_goOnline`, :1357-1367; the phone's recognizer couldn't start) no live words show, so a sheet with a recording has `_hasWords` false and counts as empty. Leaving the app pauses it with its audio (`_restingPhase`, :1420-1424). A TEXT entry then pops it without the keep-or-discard question that its own Cancelar asks (`_cancel` uses `_hasInput`, which counts `audioPath`, :1854-1855, :2093). `dispose` keeps the recording in Capturas pendientes (`_release`, ~:2235-2252), so it isn't deleted, but it leaves the screen unasked, to a list the newcomer doesn't know. The same holds for a typing sheet kept from a recording (Escribir → keep). Before P308 a sheet opened over it, and the recording stayed in view.
- Why: the brief's own rule, "anything that holds words is never closed"; Nielsen #1 visibility of system status; I (nothing the user said is lost from view).
- Fix: mark the route empty only when nothing was said or typed: `_markEmpty(result == null && !_hasInput)` (one word). A sheet with a recording then gets the entry opened over it, as before. No copy.
- Verify: widget test, Pro: a VOICE entry, online listening (native recognizer unavailable), audio recorded and paused, no words; a TEXT entry → a typing sheet opens over it; Cancelar on it shows the paused voice sheet; the capture is not discarded.
- Evidence: verified in code; not tested.

**R2A-2 · Severity 2 · Outside tap lands in an empty form opened for something else**
- Where: `App/lib/main.dart` ~:203-208 (`captureOpensForm(...) && emptyTaskFormOnTop(navigator)`), `emptyNewTaskFormOnTop` (`edit_task_screen.dart` ~:138-141), which matches any empty `/newTask`, including ones `TaskActions` opened in the app (`App/lib/widgets/task_actions.dart:83-89`, with `day`, `projectId`, `person`).
- The moment: (free account, 0 dictations left, or a server that sends no count) "I pressed the microphone and it gives me the keyboard, with nothing saying why" / "I wanted a new task and it's set to that Friday, in the shared list."
- What happens:
  - a TEXT entry's form (`askedToSpeak: false`, main.dart:251) absorbs a later VOICE entry, so the widget's mic shows a form without the «no quedan dictados…» line (`_noMic`, task_editor.dart:912-914, ~:1278) that a VOICE entry's own form shows;
  - an empty form opened in the app on a picked day in Calendar (`calendar_screen.dart:1149`), or on a shared project's page with a person chip on (`home_screen.dart:928`), absorbs a widget or shortcut entry: the task the person then adds goes to that day, list and person, where before a fresh form (no list, landing on Calendar) opened.
- Why: Nielsen #1 and #4 (the same entry opens a different form depending on what was left behind); D7 (the person chip assigns the task); UX-2637's own lesson, the entry must do what its label says.
- Fix: absorb only into a form an entry would open itself: give `NewTaskRoute` the arguments it was pushed with and acknowledge only when the top form has no `day`, `projectId`, `person` or `words`, and, for a VOICE entry, `askedToSpeak`. Any other empty form: open the entry's own over it, as before (or, for an entry-opened empty form of the other kind, pop it first as rule (4) does for sheets: D12's Back closes an empty form with nothing to keep). No copy.
- Verify: free, 0 left: a TEXT entry, then a VOICE entry → one form that shows the used-up line; Back → Calendar. Free, 0 left: Calendar on a picked day → Nueva tarea, leave it empty, then a TEXT entry → a form with no day preset on top.
- Evidence: verified in code; not tested.

### Not regressions, noted
- Free account with dictations left: an empty form from a TEXT entry, then a VOICE entry → a voice sheet opens over the form, and Cancelar shows the empty form. As before P292/P308; rule (4) covers only capture sheets. Could join R2A-2's fix (pop the empty entry form first) if the organizer wants.
- Between a `/newTask` push and TaskEditor's first build the route counts as empty, so a TEXT entry queued right behind a share could be absorbed into the shared-words form. Narrow; the shared form shows either way.
- `capture/result.as-written` at es 2×: «Ver lo que dije» 41 dp tall and 0 dp gaps under the title and date: unchanged by P309.

### Memory notes
- Entry absorption pattern (P292/P308): `_CaptureSheetRoute._open` + `_empty`/`_typing`, `emptyCaptureSheetOnTop → CaptureMode?`; `NewTaskRoute._open` + `empty`; `emptyTaskFormOnTop` (form or used-up notice); `captureOpensForm` shared by `showCaptureSheet` and `_openEntries`.
- Recurring problem: "empty" measured with `_hasWords` misses online recordings (no live words); `_hasInput` is the sheet's own test for "holds something".
- D10's line is now «Según tus palabras» · «Dejar como está» (EN “From your words” · “Keep my words”), for typed and spoken words.
