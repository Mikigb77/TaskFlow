## UX verify — 2026-10-13-app, b4 round 1, area A (P65, P66, P38, P39, P40) — 2026-10-14

**Verdict:** Ship after fixes. 13 of 14 findings are fixed. UX-103 is partly fixed: two of its new messages tell the user to tap `Seguir` when that button isn't on screen. One new single-button flow (typing without Pro) has small gaps: the time chips have no question above them, and the typing hint gives an example the phone can't split. There's also a landing gap from the day timeline.
**Evidence level:** I read the code with `git diff HEAD`, and ux-tester's widget and unit tests pass. I read the current renders: `build/calendar-es-1.3x-light.png` and `build/calendar-feedback-light.png`, both 10-14 01:54, newer than the code. I didn't run Flutter. No render covers typing mode, the slow or failed sheet, Tareas or the timeline, so those judgements come from the widget code.
**Numbers:** create controls on an empty Calendar day: 3 (4 with the timeline's `+`) → 1. Calendar bar: 2 buttons → 1, full width (render). Notes bar: 2 → 1. Ways in that dead-end without Pro: 5 (the bar, the widget, 2 shortcuts, share) → 0.

### Findings
- **U5 · fixed (device check open).** `App/lib/screens/home_screen.dart:202-219`: `_messageClearance` now reads the message's final `size.height + 8`, not its position while it animates in. `:192-194` uses `max(88, clearance)` from the list's bottom. `:140-145` grows the list's bottom padding (`_listEnd`, passed to `TaskList.bottomPadding`, `App/lib/widgets/task_list.dart:41`), so a last row can still scroll clear of the message. The animations-off test runs unskipped and unchanged; the 2×, already-visible and Calendar tests pass. Device: Android's "Remove animations".
- **UX-460 · fixed (device check open).** Same change and test as U5.
- **UX-464 · fixed.** `App/lib/screens/voice_task_screen.dart:958-961`: `unawaited(_process())`, so `_stopping` ends when listening ends. `understanding` keeps the `finally` from resetting the phase. `_process` skips its idle reset when `wentBack()` (:1080-1087) and returns early when `superseded()`. Tests cover `Volver a decirlo`, `Escribir` and `Cancelar` before the late answer, with and without TalkBack.
- **U8 · fixed (device check open).** `App/lib/widgets/task_actions.dart:47-62`: one full-width filled `Añadir tarea`, mic icon with Pro, add icon without. Calendar (`calendar_screen.dart:687`), Tareas and project pages (`home_screen.dart:475`) and the timeline (`day_timeline_screen.dart:250`) all use it. The empty-state button and `_create` are gone, and `calendarEmpty` reads `Nada previsto para este día.` The render confirms one button over the tab bar. `/createTask` and `CreateTaskScreen` are gone from `App/lib`. Device: a non-Pro account in Spanish, and whether the father's account has Pro.
- **UX-204 · fixed.** `App/lib/services/local_capture.dart:48-118` applies the parsed date, keeps `asTyped` and asks about an ambiguous hour. `capture_review_editor.dart:264-299` shows `Según lo que has escrito · Dejar como está` under the date line, and `_keepAsTyped` restores the words and the day they'd have had otherwise. A date picked by hand clears the line (:113-116). The Catalan day words are in the parser (tests). See R1A-1: the chips have no question.
- **UX-112 · fixed.** `voice_task_screen.dart:503-530` stores a later day on the session, never for notes or for today or earlier. `capture_processor.dart` `_laterDay` applies it to both the assistant's result and the phone's result. `CaptureStore.undoSave` keeps `day`. Tests cover Thursday versus today, both said and typed.
- **UX-118 · fixed.** `notes_screen.dart:255-268`: one filled `Añadir nota` (mic or add icon) opens the sheet as a note with `_saveTo`.
- **UX-102 · fixed (device check open).** The record is written on the first words (`_changedText`) or the first audio level (`_keepAudio`, :558-579). Before that, audio goes to a named file that `_dropUnheardAudio` deletes (:540-551). Erasing every word discards the record (:589-596). Widget and shortcut entries write nothing (`main.dart:149-192`). `pending()` drops empty stored records (`capture_store.dart:165-176`). Device: tap the widget, press Back, and no pending line appears.
- **UX-106 · fixed (device check open).** The Pro wall and `billingRefresh` are gone from capture: `VoiceTaskScreen` (:244-262) opens typing without Pro, and shows a spinner while `billingLoadingProvider` is true and Pro is unknown. The widget and the voice shortcut add `captureSpeakingIsPro` and `Ver Pro` (:1505-1519). Shared text shows no Pro line. R1A-6 is a small grammar slip in that line.
- **UX-114 · fixed (device check open).** Text entries open with `typing: true`, the field focused after load (:470-474), and no auto-listening (:421-425). `capture_text` reads `Type a task` / `Escribir una tarea` / `Escriu una tasca`. Device: does the keyboard come up from the launcher shortcut?
- **U7 · fixed (device check open).** An 8 s timer (:1021-1024) sets `_slow`. The hint reads `Está tardando más de lo normal.` and `Guardar tal cual` replaces `Listo` (:1442-1460). After a failure: `Reintentar` (tonal) and `Guardar tal cual` (filled). With saved audio and no words, only `Reintentar`. `_saveAsWritten` builds the result on the phone and saves it at once through the normal save, unless an AM/PM chip is open. `CaptureProcessor._written` makes a late answer or failure change nothing. Device: airplane mode, then `Guardar tal cual`, and the task is dated Friday. See R1A-3 and R1A-5.
- **UX-103 · partly.** Done: there's no raw fallback (`capture_messages.dart:35-36` → `captureFailed`); 400, 404 and other statuses map to `failed`, 422 to `noSpeech`, and the timeout and an unreachable server to `captureUnavailable` (`capture_problem.dart:64-83`). `captureKept` is no longer added. The error sits right under the status line (:1557-1565), and `MessageBanner` is a live region when `isError` (`app_components.dart:137-139`). `Listo` is disabled with no input. **Still wrong:** two of the new messages name a button that isn't on screen.
  - `captureNoSpeech` ("No te he entendido. Toca Seguir y vuelve a intentarlo.") comes from a 422 on saved audio. There, `Seguir` is hidden (`canContinue` needs `!recorded`, :1433-1439), and the only button is `Reintentar` (:1461-1465). It resends the same silent audio and gets the same 422.
  - `captureSpeechStopped` ("…Toca Seguir para continuar o escribe.") with no words yet shows `Empezar a hablar`, not `Seguir` (`waiting`, :1430).
  - Fix: name what's there. EN `I didn't catch that. Try again, or type it.` / ES `No te he entendido. Vuelve a intentarlo o escríbelo.` / CA `No t’he entès. Torna-ho a provar o escriu-ho.` For a 422 on audio with no words, drop that audio and show the waiting state (`Empezar a hablar` plus the keyboard) instead of `Reintentar`.
  - Verify: a widget test with a 422 on a recorded capture shows no `Seguir` in the message, and the next button records again. Native `speechStopped` with no words names no `Seguir`.
- **UX-451 · fixed (device check open).** The recognizer's errors go through the same `MessageBanner`, now `Semantics(liveRegion: true)`. Device: TalkBack reads the error aloud.

### Regressions

**R1A-1 · Severity 2 · Time chips appear with no question**
- Where: `App/lib/services/local_capture.dart:101-108` (`question: ''`) and `App/lib/widgets/capture_review_editor.dart:151-157`. The result card is built on the phone, from typed words or `Guardar tal cual`, with `a las 5`.
- The moment: "05:00, 17:00, Sin hora… what are these? And the button says 'Revisa los datos de arriba' and won't press."
- What happens: under `vie, 17 de oct` and `Según lo que has escrito · Dejar como está`, three chips sit with no prompt. The save button is disabled as `Revisa los datos de arriba` (`captureCheckDetails`). The assistant's AM/PM question on the same card has its question text (UX-110), so the two paths look different.
- Why it fails: gulf of execution (Norman 2013); consistency, and recognition rather than recall (Nielsen 1994).
- Fix: give the phone's question one short line. EN `What time?` / ES `¿A qué hora?` / CA `A quina hora?`. That is neutral for 9 versus 21, and avoids Spanish "mañana", which also means "tomorrow".
- Verify: extend the UX-204 `a las 5` widget test to find `¿A qué hora?` above the chips, in Spanish and English.
- Evidence: verified in code; the implementer and ux-tester both flagged it.

**R1A-2 · Severity 2 · From the timeline, a saved task lands out of sight**
- Where: `App/lib/screens/day_timeline_screen.dart:248-250`: `TaskActions(day: _day)` with no `page`. Landing: `voice_task_screen.dart:1884-1911`.
- The moment: "It says 'Guardada en Sin fecha'… but it's not here. Where did it go?"
- What happens: saving closes the sheet back onto the timeline. Landing sets `calendarFocusProvider` for the Calendar under the timeline, which the user can't see. The timeline doesn't highlight anything. A task with no date, from today's timeline (D9: today adds nothing), or one dated another day, isn't on the timeline at all. Before this change, the timeline's `+` filled in today or the timeline's day, so the new task showed on that same timeline.
- Why it fails: change blindness (Rensink et al. 1997). "Where did it go, and can they see it?" Lens B, and the peak–end rule (Kahneman et al. 1993).
- Fix: when a task is saved from the timeline and isn't on the timeline's day, return to Calendar as the pending list does (`showCalendar: true` → `popUntil(isFirst)`), where landing already selects the day and highlights the row. When it is on the timeline's day, stay, and scroll to and highlight its row. No new strings.
- Verify: a widget test from today's timeline types `comprar pan` and lands on Calendar's `Sin fecha` row, highlighted. Typing `comprar pan` on Thursday's timeline keeps the timeline and highlights the row there.
- Evidence: verified in code.

**R1A-3 · Severity 2 · TalkBack isn't told that saving as written is now possible**
- Where: `App/lib/screens/voice_task_screen.dart:1021-1024` and :1417-1419. `captureSlow` is a plain `Text` hint, and `_announce` (:620) isn't called.
- The moment, with TalkBack: "Entendiendo… still. Is it stuck?" `Guardar tal cual` appeared, but nothing said so.
- What happens: after 8 s the hint and a new button appear silently. `Entendiendo…` was the last thing spoken.
- Why it fails: WCAG 2.2 SC 4.1.3 (status messages); visibility of system status (Nielsen 1994).
- Fix: when `_slow` turns true, call `_announce(l10n.captureSlow)`, as listening and pausing already do. No new strings.
- Verify: a semantics test or a spied `SemanticsService` announcement at 8 s. Device: TalkBack says "Está tardando más de lo normal."
- Evidence: verified in code.

**R1A-4 · Severity 2 · Without Pro, the typing hint shows something the phone can't do**
- Where: `voice_task_screen.dart:1492` (`examplePlan` as the field's hint) with `local_capture.dart:111-116`.
- The moment: copies the example "Médico el viernes a las 17:00. Llevar mis resultados. También comprar café." and expects two tasks.
- What happens: without Pro, the phone builds one task, `Médico`, on Friday at 17:00. "Llevar mis resultados. También comprar café." goes into its notes, so the coffee task is never added on its own.
- Why it fails: the example sets a wrong model of the app (Norman 2013), and its failure is silent.
- Fix: without voice, use a one-task example. EN `Doctor Friday at 5 p.m.` / ES `Médico el viernes a las 17:00` / CA `Metge divendres a les 17 h`. Keep the longer one for Pro, where the assistant splits it.
- Verify: a widget test with hasPro false finds the short hint in the empty field.
- Evidence: verified in code.

**R1A-5 · Severity 1 · Two side-by-side buttons wrap at 1.0×**
- Where: `voice_task_screen.dart:1451-1460` with `_controls` (:1676-1699): two primary buttons share a row below 440 dp.
- What happens: at 360 dp each button is about 152 dp, leaving 104 dp for text. Measured in Manrope at 14 sp w700: `Guardar tal cual` is 117 and wraps; Catalan `Desa-ho tal com està` (151) and `Torna-ho a provar` (129) both wrap. From 1.3× they stack, so the newcomer isn't affected.
- Fix: stack the failed and slow pair full-width whenever both labels can't fit on one line.
- Verify: a Manrope-loaded preview at 360 dp in Catalan shows single-line labels.
- Evidence: measured from code and the font.

**R1A-6 · Severity 1 · The Pro line's pronoun has nothing to refer to**
- Where: `app_es.arb:1162`, `app_ca.arb:856` (`captureSpeakingIsPro`).
- What happens: "Dictar tareas es parte de TaskFlow Pro. Puedes escribir**la** aquí." — `la` refers to a singular task the sentence never names. The Catalan has the same slip.
- Fix: ES `Dictar una tarea es parte de TaskFlow Pro. Puedes escribirla aquí.` / CA `Dictar una tasca forma part de TaskFlow Pro. La pots escriure aquí.` English is fine.
- Evidence: verified in copy.

### Checked, no regression
- The TaskEditor still shows the same edit headings (`fineTunePlan` / `giveName` / `seriesEdits`). It just has no create branch.
- The calendar render at 1.3×: `Añadir tarea` is the one dominant button over the tab bar, and the `Deshacer` bar sits above it.
- Shared text with Pro opens typing with the words in place and sends them to the assistant. The voice shortcut without Pro types, with the Pro line.
- `CaptureProblem.from` maps every `ApiException` it doesn't know to `failed`, so no `field: message` text reaches the screen.
- `_listEnd` only grows. That leaves at most a few dp of extra space after the last row; I'm not reporting it.

### Memory notes
- A capture made without Pro is understood on the phone (`local_capture.dart`, `localDrafts`). Its AM/PM clarification has an empty question. `asTyped` holds the task as typed, for `Dejar como está`.
- TaskActions takes `day` (Calendar's selected day or the timeline's). Only a later day sticks, and it's stored on the session. The timeline has no `page`, so its saves land on the Calendar hidden under it.
- Error copy that names a button (`Seguir`, the mic) has to be checked against the `waiting` / `canContinue` / `failed` branches of `_VoiceTaskScreenState.build`.
