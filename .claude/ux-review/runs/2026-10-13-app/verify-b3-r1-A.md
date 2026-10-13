## UX verify — run 2026-10-13-app, round 1, area A (P19, P36, P37) — 2026-10-13

**Verdict:** Ship after fixes. P19 and P36 are fixed. P37 is only partly fixed: on Tareas the new row is highlighted but never scrolled into view. One new mis-tap risk can lose a result.
**Evidence used:** the code in the working tree (`git diff HEAD`), the four review previews re-rendered at 22:37 (current for this code), and ux-tester's results. Flutter was not run.

### Findings
| ID | Result | Evidence |
|---|---|---|
| UX-110 | fixed | `capture_review_editor.dart:158-209`: a question that offers times shows only the time chips plus `Sin hora`. `Sin hora` keeps the day and has no time. Neither `Cambiar este dato` nor a confirm shows there. Other questions show `Así está bien` (es), `That’s right` (en) and `Així està bé` (ca). The chips use the app clock (`05:00`), the same as every other time in the app. The tests pass. |
| UX-116 | fixed | `:338-361`: each collapsed card has ✕ (`removeCaptureItem`) and no pencil. `:545`: a title question shows on the collapsed card. Seen in review-batch-light/dark.png. |
| UX-117 | fixed | `voice_task_screen.dart:1756-1765`: with no drafts left, `save-drafts` is enabled and reads `Terminar` (`_finishEmpty`). The small link is gone. |
| UX-113 | fixed | `capture_processor.dart:16-38`: `noteTitle` takes the first sentence, or about 60 characters cut at a word. The full text stays in `notes`. The `reviewShortTitle` hint was removed along with its key. |
| UX-124 | fixed | `voice_task_screen.dart:1787-1797`: shows `Ver lo que dije` only for speech, and `Texto original` otherwise. `taskTitle` in English is now `Task title`. |
| UX-127 | fixed | `capture_review_editor.dart:313-317, 469-472`: the summary lists only priority above low and repeats, and is empty otherwise. review-direct-light.png shows `Más opciones` with no subtitle. |
| U4 | fixed (device walk pending) | `_review` now calls setState on `_result` instead of pushing a page. `review_tasks_screen.dart` is deleted. The processing status uses `captureUnderstanding`. The date line uses `titleLarge` plus the calendar icon. The date question sits right under it. `Bandeja personal` shows only when assignment needs review. Batch header, the 4 button labels, `Volver a decirlo` for speech only, and Deshacer reopening the sheet are all present. The renders show the sheet in light and dark. Still to check on a device: UX_REVIEW §7 task 1. |
| U5 | partly | Working: the Calendar landing (day, highlight, `Añadida al …` with Deshacer), the two-day batch, and the pending list returning to Calendar (`main_shell.dart` listener, `captures_screen.dart` `showCalendar`). Tareas (`home_screen.dart` `_land`/`_reveal`) clears the filter and highlights the row, but the row is never scrolled into view: ux-tester's test fails at `saved.hitTestable()`. `_reveal` drives `NestedScrollView.innerController` and `showOnScreen`, and neither brings the row up from under the header. |

### Regressions (caused by this change)
**R1A-1 · Severity 3 · `Volver a decirlo` discards the result, right under the primary button**
- Where: `voice_task_screen.dart:1776-1786` (TextButton directly under `save-drafts`, no gap) and `_sayAgain` at `:919-945` (it discards the previous capture at once).
- The moment: "I went to tap Añadir… now it's listening again and my task is gone."
- Why it fails: a destructive action sits flush against the primary action (thumb zone; Fitts). There is no undo, so the user loses input, edits included (Nielsen: user control; Raskin: prefer undo).
- Fix: don't discard the previous capture until new words have been understood. If the user taps `Cancelar` while listening again, return to the previous result. Also add at least 12 dp between the filled button and `Volver a decirlo`.
- Verify: a widget test: on the result, tap `Volver a decirlo`, then `Cancelar`, and the same result is back with its edits.

**R1A-2 · Severity 2 · The result has no visible way out**
- Where: `CaptureResult.build`, `voice_task_screen.dart:1666-1800`. The listening state has `Cancelar` (`:1305-1316`) and the deleted review page had a back arrow; the result has neither.
- The moment: "I don't want this. How do I close it without saving?" The only exits are a tap on the dimmed area, Back, or a swipe. All three are hidden to a newcomer, and each one silently leaves the capture in the pending list.
- Why it fails: user control and freedom, consistency within the same sheet (Nielsen). Gestures without a signifier (Norman & Nielsen 2010).
- Fix: put `Cancelar` / `Cancel` / `Cancel·la` in the same row as `Volver a decirlo`, matching the listening controls. This replaces nothing visible and stays clear of the filled button.
- Verify: a widget test: the result shows `Cancelar`. Tapping it closes the sheet, and the capture stays in the pending list.

**R1A-3 · Severity 1 · The date line doesn't say it's the date for TalkBack**
- Where: `capture_review_editor.dart:260-278`. The old row read `Fecha y hora` plus the value. The new line reads only `Hoy`, or `vie, 16 oct · 17:00`.
- Fix: `Semantics(label: '${l.reviewSchedule}: ${taskDayLine(...)}')` on the ListTile. This adds no visible text.

### Notes
- Seen in the renders: the batch cards in light and dark are readable, with ✕ at 48 dp and the pinned button above `Volver a decirlo` and `Ver lo que dije`.
- These are not regressions: the title shows twice on an expanded batch card, and `Borrador retirado` / `borradores` is jargon. Both were there before this change.
