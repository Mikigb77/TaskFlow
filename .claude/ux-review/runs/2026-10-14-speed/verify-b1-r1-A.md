## UX verify — 2026-10-14-speed, round 1, area A (P101–P106) — 2026-10-14
**Verdict:** Ship after fixes. 15 of 16 findings are fixed in code. UX-609 is partly fixed: the Catalan line takes 3 lines at 2× on 320 dp. There is one new severity-2 regression in the parser (R1A-1) and one cosmetic one (R1A-2).
**Evidence used:** `git diff HEAD` of every changed file; ux-tester's results (all pass except UX-609 CA); renders `App/build/review-direct-{light,dark}.png`, `review-direct-no-notes-{light,dark}.png`, `review-batch-open-light.png` (16:43, newer than the code at 15:53–16:11). Flutter wasn't run.

### Results
| ID | Result | Evidence |
|---|---|---|
| UX-601 | fixed (device check) | `task_provider.dart` `showLocal()` reads the phone, sets state, then `unawaited(loadTasks())`. The `_shown` counter stops a read that started before the save from overwriting the list (pre-sync and post-sync reads are both guarded, and the loop re-runs). `voice_task_screen.dart` `_save` and Deshacer call `showLocal()`; every diagnostics `record` is unawaited, in this file and in `capture_processor.dart`. Four landing tests pass with a sync that never completes. |
| UX-610 | fixed (device check) | `_stopRecording` times `stop` → `_speechEnded`/4 s and records `recognizerFinish` unawaited; the 4 s cap is unchanged. The label is in all three ARB files. The p50/p95 need a phone. |
| UX-602 | fixed (device check) | `calendar_screen.dart` `_picked` is set by `onDaySelected` and Hoy. `_land` clears it only when the landing goes to another day. `TaskActions(day: _picked ? _selectedDay : null)`. The four D9 tests pass. |
| U5 | fixed (device check) | `CalendarFocus.undated`. `_land` sets `_landingInbox` when undated. The no-date row lights in the same build as the dated rows (`calendar_screen.dart:300-307`). `_landedRow` goes only on the dated row (`_inboxOnly`). The message adds `captureAlsoOn` / `captureAlsoOnDays` when `remaining == 0`. Residual, as planned (not a regression): with many dated rows, the lit no-date row can sit below the fold, and the message doesn't name it. Watch for this in §7 task 3. |
| UX-603 | fixed (device check) | `NativeSpeech.knownCapability` memoizes per language, and unanswered/timeout results aren't kept. Capability is forgotten on a failed start, on an error before ready, and after `prepareLanguage`. `TaskActions` warms it after the first frame. The time zone is a stored Future awaited only in `_ensureSession`. `cleanFinished` runs once, after listening or focus. In Kotlin, `emit(run,"listening")` fires after `startListening` when `feed != null`. Twelve tests pass. |
| UX-611 | fixed for this package's part (device check) | `VoiceTaskScreen.build` shows the spinner only when `freeVoiceLeftProvider == null`. At 0 left, typing opens at once and stays typing. The start-up and restore waits remain under UX-424 / P30. |
| UX-604 | fixed | Parser rules 1–4 (`_notMorning`, `_dayAfterTomorrow`, `_partOfDay`, `_settle`) and the unit and widget tests pass. See R1A-1 for a side effect. |
| UX-606 | fixed | The notes field shows only when `task.isNote` or `_notesOpen`. 'Añadir notas' is the first row in Más opciones and opens the field with focus. The render without notes has no Notas field. |
| UX-607 | fixed | Underline borders (outline / primary 2 dp / outlineVariant) on the title and notes. Visible under the title in light and dark. See R1A-2. |
| UX-608 | fixed | `applyDays: true` from `_schedule`. The chips call `_done()` when `moving != null \|\| applyDays`. TaskEditor is unchanged. |
| UX-613 | fixed | `compact && expanded` keeps only the ✕ IconButton, with its tooltip. `review-batch-open-light.png` shows the title once. |
| UX-605 | fixed (device check) | `_CaptureResultState` has `PopScope(canPop:false)` → `_leave()`, the shared `_askToKeep` (title only, Descartar / Conservar), `_discard()`, and `_finishEmpty` when no card is left. Save still pops. Back, the scrim, typing and listening tests pass. The back swipe and TalkBack need a phone. |
| UX-614 | fixed | `sayAgain = spoken && onSayAgain != null && ref.watch(voiceAvailableProvider)`. |
| UX-612 | fixed | ARB values are renamed in EN/ES/CA. `captureKeepHelp` and `captureReviewRetainedHelp` are removed. `captureDraftSummary(count)` has one argument. The catalog grep test passes. |
| UX-609 | partly | The copy is 7 words instead of 17, 'Ver Pro' and the live region are kept, and the field stays above a 300 dp keyboard. ES and EN take ≤2 lines at 2×/320 dp, but CA 'Fins al dia 1 de nov. no tens dictats gratuïts.' takes 3 lines (tester and implementer agree). This needs a copy or owner decision (see below). |

### Regressions
**R1A-1 · Severity 2 · Part-of-day times with no date word land in the past**
- Where: `App/lib/services/quick_schedule_parser.dart:123-124` (no date word → `today`), together with `settle()` (:163-174, :185-190, :203-212). Affects typed tasks and Guardar tal cual.
- The moment: at 10:00 the person types or says "Llamar a Juan a las 9 de la mañana" offline and taps Guardar tal cual. "I said nine in the morning — why is it already late?"
- What happens: before P104, 'mañana' read as tomorrow, and the bare 9 asked the hour question. Now 'de la mañana' settles 09:00 and no date word is left, so the task is dated today at 09:00, an hour in the past. With nothing asked, Guardar tal cual saves it at once, and no reminder will ever fire. The same happens with "a las 5 de la tarde" said after 17:00.
- Why it fails: error prevention (Nielsen). A silent wrong save is worse than the question it replaced.
- Fix: when there is no date word and no picked `day`, and the settled time is earlier than `reference`, use the next day (Thursday 09:00). Do this at least for times a part of the day settled. Ideally apply it to every no-date time, since "a las 17" at 18:00 already has this problem.
- Verify: unit tests with reference Wed 14 Oct, 10:00. "Llamar a Juan a las 9 de la mañana" → Thu 15 Oct 09:00, title "Llamar a Juan". "Llamar a Juan a las 5 de la tarde" → Wed 14 Oct 17:00.
- Evidence: verified in code; the behaviour is inferred (no test covers it).

**R1A-2 · Severity 1 · Two parallel lines under the notes**
- Where: `App/lib/widgets/capture_review_editor.dart` — the notes underline (UX-607) and `Divider(height: 1)` at :573, about 9 dp apart. Seen in review-direct-light.png and -dark.png (y≈1177 and 1195).
- Fix: show the Divider above Más opciones only when the notes field is hidden, because the field's underline already separates the two.
- Verify: re-render review-direct: one line between the notes and Más opciones.
- Evidence: seen in the current render.

### Question for the owner (UX-609, Catalan)
At 2× text on 320 dp, any Catalan sentence that keeps "dictats gratuïts" and the date "1 de nov." in mid-sentence (UX-503) takes 3 lines. The field still stays visible above the keyboard, which is the point of the check. The options are:
- (a) accept 3 lines in Catalan only;
- (b) a shorter Catalan line that drops "gratuïts", e.g. `Més dictats el dia {date}.`, which needs a native read;
- (c) keep the wording and relax the check to "the field stays visible".

The reviewer leans to (a) or (c).
