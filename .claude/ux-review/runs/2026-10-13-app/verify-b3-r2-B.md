## UX verify — 2026-10-13-app, round 2, area B (P61) — 2026-10-13

**Verdict:** All four findings fixed in code and proven by widget tests; UX-452 still needs the phone check (keyboard drop, TalkBack reading the live region). One small regression (severity 1).
**Evidence level:** code + tests. No preview renders the date sheet or the repeat sheet (`App/build/` has none); the `calendar-feedback-*` renders don't show either sheet.

### Findings

**UX-452 · fixed (needs device)**
- `App/lib/widgets/schedule_editor.dart:122-139`: when the period is missing, `_done` sets `_missingPeriod`, calls `FocusScope.of(context).unfocus()`, then post-frame `Scrollable.ensureVisible(_periodRow…, keepVisibleAtEnd)`; animation is skipped under `disableAnimationsOf` (:128, :135). `mounted` and null-context guards are present (:131).
- `:349-385`: the a. m./p. m. Wrap and the error share one `Column(key: _periodRow)`; the error Text is wrapped in `Semantics(liveRegion: true)` (:379-382). Copy unchanged (`chooseAmPm` ES `Elige a. m. o p. m.`).
- Test `schedule_editor_test.dart:348-416` (12 h, ES, 2×, 360×640, inset 300): focus drops, message is hit-testable inside the viewport and above the keyboard, liveRegion set.
- Still open on a phone: the real keyboard drops, and TalkBack reads the message.

**UX-453 · fixed**
- `schedule_editor.dart:235-243`: with `moving != null`, every day chip calls `_done()` at once; the comment matches the brief. Sin fecha stays hidden for one occurrence (:230).
- TaskEditor and the capture result keep select-only (they don't pass `moving`); test `schedule_editor_test.dart:418`.
- Undo path: `task_interactions.dart:76-93` shows `movedInbox` (ES `Movida a la bandeja de entrada`) with Deshacer → `undoSchedule` for the series / non-repeating case. Test `calendar_feedback_test.dart:763`.
- `appearance_test.dart` no longer taps `schedule-done` after No date.

**UX-454 · fixed**
- `seriesRescheduleHelp` now names the real chip: EN `app_en.arb:494` “No date stops the repeat.”, ES `app_es.arb:368` “«Sin fecha» detiene la repetición.”, CA `app_ca.arb:347` “«Sense data» atura la repetició.” Matches the brief exactly.
- grep for `Inbox stops`, `bandeja de entrada detiene`, `safata d’entrada atura` in `App/lib/l10n`: no hits. Test `calendar_feedback_test.dart:818`.

**UX-455 · fixed**
- `App/lib/widgets/repeat_rule_control.dart:180` now uses `context.l10n.done` (EN `Done` / ES `Listo` / CA `Fet`).
- `keepRepeat`: no hits in `App/lib` (generated files included) or `App/test`. Test `schedule_editor_test.dart:449`.

### Regressions

**R2B-1 · Severity 1 · Sin fecha needs a second tap after an empty hour**
- Where: `App/lib/widgets/schedule_editor.dart:111-122, 235-243`, the move sheet (“Cambiar fecha”), Añadir hora on with an empty or invalid hour.
- The moment: “I tapped Sin fecha and the sheet didn’t close. Did it work?”
- What happens: `_select(null)` sets `_hasTime = false` in a setState that hasn’t rebuilt yet, so `_done()` → `_form.currentState!.validate()` still runs the hour field’s validator. An empty hour fails, `_done` returns and the sheet stays open. The rebuild then removes the time row and its error, so there is no visible reason. A second tap on Sin fecha, or Listo, then works. Hoy and Mañana keep the time row, so their error at least shows; only Sin fecha is silent. Caused by this change: before it, Sin fecha only selected.
- Why it fails: the sheet gives no feedback here, and the same row of chips behaves differently (Norman, gulf of evaluation; Nielsen, consistency).
- Fix: in `_done`, skip form validation when the result has no time — `final valid = !_hasTime || _form.currentState!.validate();` — or validate only when `_day != null && _hasTime`. No new strings.
- Verify: widget test, move sheet of a dated task without a time → turn on Añadir hora (hour empty) → tap Sin fecha → the sheet closes and `Movida a la bandeja de entrada` shows.
- Evidence: verified in code (Form.validate runs on fields that are still registered before the rebuild). Rare path.

No other regressions in the changed files: the scope chips, Omitir/Restaurar, kept time on Hoy/Mañana, the empty-minutes rule and the `_pm == null` handling are unchanged from round 1.
