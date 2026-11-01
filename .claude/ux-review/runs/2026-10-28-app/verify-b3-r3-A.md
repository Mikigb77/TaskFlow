## UX verify — 2026-10-28-app, b3 round 3, area A (P313) — 2026-11-01

**Verdict:** Ship after fixes — both findings are fixed at widget level; one minor and one polish regression in the new close-first rule.
**Evidence level:** code read (`git diff HEAD`) plus the tester's passing widget tests. No render covers entries from outside the app (INDEX.md has no entry-flow preview), so there's no visual evidence. Device checks are still for the main session.

### UX-2641 · fixed (widget level; device pending)
- `App/lib/screens/voice_task_screen.dart`: `_CaptureSheetRoute._recorded` is new. `_markEmpty` sets it on every build from `_session?.audioPath != null`, and `_markRecorded()` sets it inside `_keepAudio`'s `_writes`, right after the session gets its audio (≈:926). So the flag is true as soon as the audio is kept, with no rebuild needed. `emptyCaptureSheetOnTopRecorded` exposes it.
- `App/lib/main.dart:202-220`: same-mode absorbing still uses the loose test (`sheet == asked`), so a double VOICE tap in online listening stays one sheet. The other mode's empty sheet is popped only when `!recorded`; otherwise the entry opens over it.
- Tests (capture_sheet_test.dart, group P313, ≈:4151): a paused online recording plus a TEXT entry gives a typing sheet over it. Cancelar shows «Grabación conservada en este teléfono». The capture is not discarded and keeps its `audioPath`. Two VOICE taps leave one sheet, one recorder, still recording. P308's native-listening VOICE→TEXT case and P292's renamed test pass.

### UX-2642 · fixed (widget level; device pending)
- `App/lib/screens/edit_task_screen.dart`: `NewTaskArguments.blank` is new (≈:112), and `emptyEntryFormOnTop` (≈:151) returns the top empty form's `askedToSpeak` only when its arguments are blank.
- `App/lib/widgets/task_form_entry.dart`: `_Notice.fromEntry` is set from `arguments.blank`. Under `emptyTaskFormOnTop`, TEXT takes either form kind, VOICE takes only an `askedToSpeak` form, and a notice absorbs only when it came from an entry. A notice is never popped.
- `main.dart:219`: an empty entry form that doesn't absorb is popped first. Forms with a day, project, person, words or capture are never popped or absorbed.
- Tests (capture_free_dictations_test.dart P313, plus the share case in capture_sheet_test.dart P313) cover:
  - at 0 left, TEXT→VOICE gives one form with `free-voice-used-up`, and VOICE→TEXT gives one form;
  - a picked later day (0 left and 5 left) gives a second form with no day, and Back shows the picked day;
  - a shared project with Ana's chip gives a second blank form;
  - with dictations left, TEXT→VOICE gives the listening sheet, and Cancelar lands on Calendar;
  - share + TEXT gives two forms with the shared words kept;
  - P308's double-tap tests still pass.

### Regressions (only in the changed files and the flows they touch)

**R3A-1 · Severity 2 · An entry closes a titleless form holding a date or photo**
- Where: `App/lib/main.dart:219` (`form != null` → `navigator.pop()`), with emptiness from `App/lib/widgets/task_editor.dart:336` (`empty = title is empty`). Screen: the task form opened by the widget or shortcut (free account), and the blank in-app «Nueva tarea» (Calendar with no day picked, Home with no project or person, `TaskActions`). Both count as "entry forms".
- The moment: «Le puse la foto y el día, fui a mirar una cosa y toqué el micro del widget… ¿dónde está lo que había puesto?»
- What happens: P313 pops a blank form whose title is empty when the entry doesn't take it. That happens to a TEXT form with a VOICE entry, and to any blank form at 0 left. The pop ignores everything else in the form: a picked date or time, a reminder, a checklist, an attachment or photo, notes. Notes survive under «Sin guardar», out of view, because the dispose doesn't let go of them. The date, reminder, checklist and attachments are gone. Nothing asks, and nothing says the form closed. Before P313 an entry never popped a form. P308 only absorbed one, which lost nothing. The package's own rule is "an entry never closes what holds something".
- Why it fails: user control and the "never lose input" rule (Nielsen heuristics 3 and 5; Neusesser & Sunwall 2023). The user didn't choose to leave the way D12's Back is a choice. UX-2641's fix uses the sheet's own `_hasInput` test for the same reason. Rare: it needs a form left mid-edit with no title, then an outside tap.
- Fix: count an entry's form as empty for closing only when nothing in it changed. Use the editor's own comparison (`_edited().toMap()` against `_unchanged`) with no title, no notes, no checklist and no attachments, updated on each change. Absorbing can keep the title-only test, because absorbing loses nothing. Otherwise the entry opens its own form over it, as for in-app forms. No copy.
- Verify: a widget test with a free account and dictations left. A TEXT entry opens the form; pick a date (or add a checklist step), with no title. A VOICE entry then opens the listening sheet over the form, and Cancelar shows the form with the date still set.
- Evidence: verified in code; not covered by a test or a render.

**R3A-2 · Severity 1 · Voice, text, voice taps stack two voice sheets**
- Where: `App/lib/main.dart:204-219`. The checks run once, before the pop, so they never look at what the pop uncovers.
- The moment: «Toqué el micro otra vez y salió otra hoja; al cancelar había otra debajo».
- What happens (Pro, online listening):
  1. The widget mic records and pauses: a voice sheet that keeps a recording.
  2. A TEXT entry opens a typing sheet over it, as P313 means it to.
  3. A second widget-mic tap pops the empty typing sheet, and the paused voice sheet with the recording is on top again. It would take a VOICE entry (`sheet == asked`), but the entry still opens a second voice sheet, with a second recorder, over it.

  Nothing is lost: Cancelar on the new one shows the paused one. But two voice sheets stack, the UX-2110 pattern. The stack arises only because P313 opens over a recorded sheet.
- Why it fails: consistency with the UX-2110 rule (one tap, one sheet). Visibility of system status: the recording sits one level down, unseen.
- Fix: after the close-first pop, check again what's on top. If an empty sheet of the asked mode is now current, acknowledge the entry and open nothing. Otherwise open as today. No copy.
- Verify: a widget test in the P313 group with Pro, online listening. VOICE (audio kept, app paused), then TEXT, then VOICE gives exactly one capture sheet: the paused voice sheet, with «Grabación conservada…» showing and one recorder.
- Evidence: verified in code; inferred behaviour, no test.

### Checked, no regression
- Shares still always open their own (`if (!shared)`), and a share's form isn't blank, so it never absorbs or closes.
- Notices are never popped (the pop is gated on `sheet`/`form` only).
- `openTaskForm` still returns at once for its in-app callers: the push stays `unawaited`.
- The `_entrySheets` count resets on sign-out (`_navigator` compare). No copy, ARB or Kotlin change in this package.
- An in-app blank form (no day, project or person) now absorbs a TEXT entry like an entry's own. Its saved task lands on its `page` rather than Calendar, and it stays in view, so I'm not reporting it.

### Device checks still open (main session, TaskFlow_Review emulator)
The three in the package: shortcut then widget mic at 0 left; a picked day's form then the shortcut; Pro with online listening forced, mic then shortcut, then Cancelar.
