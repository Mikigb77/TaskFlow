## UX verify — run 2026-10-28-app, b1 round 1, area A (P266, P267, P273, P274) — 2026-11-01

**Verdict:** Ship after fixes. 16 of 17 findings hold, by code, current renders (02:34–02:36, newer than every file under App/lib) and the testers' passing tests. UX-2203 is half done: the message names the day, but at 360×800 the day heading still scrolls off. Two small regressions, both in P267 and P274.

Code read: P266, P267 and P273 are in the WIP commit b0de7c8 (`git diff 8064257 b0de7c8`); P274 is in the working tree (`git diff HEAD`).

### Findings

| ID | Result | Evidence |
|---|---|---|
| UX-2101 | fixed | `voice_task_screen.dart:2630-2642`: `showType: !_typing && !recordingWaits && !typeFirst` (`!recorded` removed). `_typeFromControls` (:1957-2013) stops the recorder. With only silence it drops the recording (`_onlySilence`, level −45 dBFS, :1236-1244); otherwise it asks `_askToKeep`, and dismissing returns with the sheet unchanged. It then opens typing or the form empty (`_words.clear()`, session null). Render `capture/sheet.listening-online.{es 1×, ca 2×}`: «Escribir» / «Escriu» shown; AUDIT 106×48 dp. `sheet.error-offline-recording.es 2×` shows «Escribir» after an offline failure. Device check still open (emulator `capture.listening.ca`). |
| UX-2106 | fixed | `:2622-2627`: the ring shows only when `!_typing && !resting`, and nothing replaces it. Renders: `sheet.paused` (es 2×), `sheet.mic-denied` (es 1×), `sheet.error-offline` (ca 2×), `sheet.error-unavailable` (es 2×) and `sheet.error-offline-recording` (es 2×) have no ring. `sheet.listening` and `sheet.understanding(-slow)` keep it. The phase starts at `starting` (:512), so the sheet doesn't jump when it opens. |
| UX-2107 | fixed (device check open) | `_screenReader` (:905). With TalkBack, «Escuchando» is announced before the microphone opens, then a 1 s wait while the sheet shows `starting` (:1116-1128). `_listening()` stays quiet (:1000). At 50 s a haptic pulse fires instead of the announcement (:1013-1021). «Listo» / «En pausa» are announced only after `recorder.stop` (:1380-1422). If the app is left during that 1 s, the `finally` block (:1265-1273) returns the sheet to idle («Empezar a hablar»), so it can't get stuck. What TalkBack says and the pulse itself need a phone. |
| UX-2111 | fixed | ES/EN/CA `capturePrivacyLine` match the brief (app_es.arb:306, app_en.arb:540, app_ca.arb:285). The screen names match `otherSettings` and `voiceSettings`. Render `sheet.listening-first-use.ca.light.2x`: 3 lines, whole, no ellipsis. |
| UX-2113 | fixed | `captureListeningOnline` ES/EN/CA as in the brief (app_es.arb:915, app_ca.arb:730, app_en.arb:1814). Render `sheet.listening-online.ca.light.2x`: 2 lines, whole. |
| UX-2201 | fixed | `capture_command_cards.dart:2379-2385`: the rows go straight into the sheet's own scroll; `_scroll`, the Scrollbar and the ConstrainedBox are gone. Render `cards.bulk-today-overdue.es.light.1x`: all 6 rows show, with the pinned «Marcar 6 tareas como hechas» below them. |
| UX-2204 | fixed | `_Choice` (:1232-1315): each match is an outlined (`outline`), full-width choice, at least 48 dp tall and 8 dp apart, in the question panel. AUDIT `cards.change-which` es 1×: 248×56 dp, 8 dp gap. Renders es 1×, es 2× and ca 2× confirm it. See R1A1-1. |
| UX-2209 | fixed | `commandChangeLine` / `commandChangeLineFrom` in all three catalogs. `named: true` is set only on the deadline and priority lines (:1634, :1642, :1650). Render `cards.change-details.es.light.1x`: «Prioridad: Media → Alta». `cards.change-deadline-only.es.light.2x`: «Fecha límite: sáb, 31 de oct →» [Mañana ▾], not clipped. TalkBack still reads «Prioridad: de Media a Alta» (AUDIT). |
| UX-2210 | fixed | `Icons.search_rounded` on changes and deletions that found nothing (:1402, :1814). In set cards, only removable (actionable) headers keep the action's icon (:2213). Render `cards.bulk-view-only.es.light.1x` shows the search icon. |
| UX-2102 | fixed | `_cancel` (:2026-2073): while understanding it asks `_askToKeep`. Conservar → pop (the result waits in «Sin guardar»). Descartar → `_attempts++` and `CaptureProcessor.cancel(attempt)`, then discard. Dismissed → stays. `_backToResult` (UX-461) runs first and is unchanged. |
| UX-2103 | fixed | `:2369-2372`: no filled button while processing. A TextButton sits under the slow line (:2614-2620). Render `sheet.understanding-slow.es.light.1x`: AUDIT measures it at 160×48 dp; there is no filled button, and «Escribir» is disabled. After a failure the button is filled (`sheet.error-unavailable`). |
| UX-2104 | fixed | `captureOffline`, `captureOfflineRecording` and `captureUnavailable` match the brief. They are chosen through `recording: recorded && !_hasWords` (`capture_messages.dart:24-31`, `voice_task_screen.dart:2504-2509`). Renders: `sheet.error-offline.ca.2x`, `sheet.error-offline-recording.es.2x` (names no missing button) and `sheet.error-unavailable.es.2x`. No «asistente» / “assistant” / «assistent» left in the catalogs. |
| UX-2109 | fixed | `:2530-2582`: the error and banners show at their natural height, capped by a LayoutBuilder, and only the words scroll (`Flexible`). Renders `sheet.error-offline.ca.light.2x` and `sheet.error-limit-typed.ca.light.2x`: the banner is whole, with its bottom edge and the field's top border visible. |
| UX-2105 | fixed | EN `captureFailed`, ES `recordingKept`, and ES/CA `capturesEmptyHelp` match the brief. Render `sheet.error-offline-recording` shows «Grabación conservada en este teléfono». |
| UX-2202 | fixed | `voice_task_screen.dart:4040-4096`: on a result that added nothing (`takesBackOnly`), Deshacer only undoes the changes; it reopens no sheet and calls no `undoSave`. A result that added tasks or projects still reopens. `commandDeletedTitle` is used for one deletion (:3963-3967). Renders `applied.delete-applied` («Eliminada: Ir a la peluquería · Deshacer») and `applied.delete-undone` (Calendar, no sheet). See R1A1-2. |
| UX-2203 | partly | Part 1 is fixed: `captureTasksAddedOn` is used when every dated task lands on one day (:3352-3368 and :3902-3929), and «· también …» is kept for several days. Part 2 holds at 393×852 (render `agenda.added.es.light.1x-393`: «Agenda de hoy» and both lit rows are above the message). At 360×800 it fails: render `agenda.added.es.light.1x` has no heading and no week strip. The message reads «3 tareas añadidas · también el vie, 6 de nov», so no line names the lit rows' day. This is the tester's failing test (`capture_landing_test.dart` ~:1859). Suggested fix, no new copy: when a save spans several days, start the message with the landing day's tasks, using `captureTasksAddedOn(n, landingDay)` (or `taskAddedOn` for one task), followed by «· también el …» — for example «2 tareas añadidas al dom, 1 de nov · también el vie, 6 de nov». Then the message names the day whether or not the heading fits. Otherwise the organizer must choose between changing the fixture and changing the layout. |
| UX-2213 | fixed | `reviewUndoSaved` is an ICU plural in all three catalogs (app_es.arb:12, app_en.arb:21, app_ca.arb:12). It is called with the restored count (:3457, :4124). |

### Regressions (only the changed files and their flows)

**R1A1-1 · Severity 1 · At 2×, «¿Cuál…?» opens with its ✕ cut off**
- Where: `voice_task_screen.dart:2915-2928` (`_reveal`) with `capture_command_cards.dart:1232-1315` (`_Choice`, now in a `_QuestionPanel`, not a `QuestionBox`); render `commands/cards.change-which.es.light.2x`.
- What happens: `_questionIn(card)` finds no `QuestionBox` in a `_Choice`, so `_reveal` aligns the whole card's bottom with the view's bottom (`alignment: 1`). The outlined choices make the card taller than the view at 2×, so it opens scrolled past its top. The card's top edge and the pencil are cut. AUDIT measures «No cambiar ninguna» at 48 × 32 dp; it was 48 × 48 dp at 1×.
- Fix: reveal a card whose open question is a `_Choice` at its top (`alignment: 0`, as set cards are revealed by their heading), or mark the `_Choice` panel so that `_questionIn` finds it. No copy.
- Verify: re-render `cards.change-which` es 2× and ca 2×: the ✕ is 48 × 48 dp and the card's top edge is in view.
- Evidence: seen in a current render with AUDIT; cause read in code.

**R1A1-2 · Severity 2 · Deshacer on a voice deletion can show nothing at all**
- Where: `voice_task_screen.dart:4040-4096` (`takesBackOnly`); renders `commands/applied.delete-applied.es.light.1x` → `applied.delete-undone.es.light.1x`.
- The moment: "I pressed Deshacer… did it come back? Nothing changed."
- What happens: «Borra lo de la peluquería» deletes a task dated sáb, 31 de oct. Calendar is on today. Deshacer brings the task back, but the screen is identical before and after («Agenda de hoy · 4 pendientes · 1 completada»): no row reappears and no message appears. A voice change («Cambia el dentista al viernes») behaves much the same way: its lit row disappears from the day Calendar landed on, and nothing says where it went. Before this change, the sheet reopened on the card. That was the problem UX-2202 fixed, but it was a visible effect.
- Why it fails: Norman's gulf of evaluation; Nielsen's visibility of system status; change blindness (Rensink et al. 1997). The person may say the command again, or think the undo failed.
- Fix, with no new copy: when the restored or moved-back tasks aren't on the day Calendar shows, set `calendarFocusProvider` to `CalendarFocus(firstRestoredDay, ids)`, as a save does. Calendar then lands on the task, lit. When they are on the shown day, the lighting is enough.
- Verify: a widget test. Delete a task dated on another day by voice, then tap Deshacer: Calendar shows that day with the task's row lit. Then «Cambia el dentista al viernes» → Deshacer: Calendar shows the dentist's original day, lit.
- Evidence: verified in code; seen in current renders.

Not regressions (noted only):
- The day-chip card «nothing to change» (with a day chip to pick another day) now shows the search icon (`:2313-2328`). That follows UX-2210's rule. It can still act after a new day is picked, which is a fine distinction and not worth a finding.
- `calendar_screen.dart:677-687` (clearing `_openOnDay` when another tab is shown) belongs to another package. I saw no effect on the landing flow.

### Device checks still open
- UX-2101: emulator `device/capture.listening.ca.light.{1.0,2.0}`: «Escriu» is shown, and tapping it after speaking asks the keep question.
- UX-2107: a phone with TalkBack: the words that come back contain neither «Escuchando» nor «Quedan», and a pulse is felt at 50 s.

### Memory notes
- `_Choice` («¿Cuál…?») now draws its matches as outlined, full-width choices in a `_QuestionPanel` (not a `QuestionBox`). The card's header is the question.
- Deshacer on a voice result that added nothing (changes, completions, deletions, sets) only takes the change back; it reopens no sheet. A result that added tasks or projects still reopens. One deletion is named «Eliminada: …».
- The capture sheet's ring shows only while starting, listening or understanding. «Escribir» shows on the online path too (a keep question when speech was heard). With TalkBack, «Escuchando» is announced 1 s before the microphone opens, and a pulse replaces the 50 s announcement.
- While understanding is slow, «Guardar como tarea» is a TextButton; it is filled only after a failure. Error banners show whole; only the words scroll.
- Kept words are «conservadas» / «conservades» / “kept”, never «guardadas».
- Several added tasks on one day: «N tareas añadidas al …» (`captureTasksAddedOn`).
