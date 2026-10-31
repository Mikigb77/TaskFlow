## UX verify — 2026-10-13-app, b3 round 2, area A (P59, P60) — 2026-10-13

**Verdict:** Ship after fixes. Volver a decirlo is now safe, and the result has a visible way out. On Tareas the new row now comes into view, but with animations off it ends partly under the `Añadida…` message.

**Evidence used:** code (`git diff HEAD`), ux-tester's results, and the review previews rendered at 23:25 (newer than the code: home_screen 22:53, voice_task_screen 22:58, capture_review_editor 22:57). No preview covers the Tareas landing.

### Results

| ID | Result | Evidence |
|---|---|---|
| U5 (P59) | partly | `App/lib/screens/home_screen.dart:136-245`: `_reveal` / `_shortfall` / `_scrollBy` measure the row against the NestedScrollView's on-screen rect and move the outer controller first, then the inner one. The brief's steps 1–5 are all there (one correction after `endOfFrame`, the build-out loop kept, `jumpTo` when animations are off). The tester's checks pass: the main Tareas test, 2× text at 360×740, and nothing moves when the row already shows; Calendar landing is unchanged. **Fails with animations off:** the row ends at 427–550 and the message's top is at 503 (list area 64–650), so about 47 of its 123 px sit under `Añadida…`. Likely cause, inferred from the code: with animations off, the jump and its one correction both happen in the first frames. At that point `_messageTop()` (:181-200) reads the SnackBar's top while the message is still sliding in, or before it's laid out, and so falls back to the 88 px clearance. The final message is about 147 px tall. With animations on, the 300 ms animation outlasts the message's entry, so the correction sees its real top. Device check still open: UX_REVIEW §7 task 2. |
| UX-456 (P60) | fixed | `voice_task_screen.dart:938-958`: `_sayAgain` keeps `_previousResult` and no longer discards it. `:916-934`: `_review` discards the previous capture only when a different session is understood. `:988-991` with `:1039-1064`: `_cancel` goes `_backToResult`, which stops quietly, discards the new capture and restores the previous result with `_movedToReview = true`. `CaptureResult._sayAgain` (:1711-1720) awaits `_writes` and passes `_session`, so edits survive. Render `build/review-direct-light.png`: a gap of about 18 dp between `Añadir al calendario` and the `Cancelar · Volver a decirlo` row. The tester's 2× text checks (es, ca) report a gap of at least 12 dp and no overflow. Device check still open: a one-handed mis-tap on a phone. |
| UX-457 (P60) | fixed | `voice_task_screen.dart:1722-1750` `_exits`: `Cancelar` at the start, `Volver a decirlo` at the end; they stack at large text, and only Cancelar shows for typed text. Both are disabled while saving. Cancelar calls `Navigator.maybePop`, with no dialog. It's placed under `save-drafts` with `SizedBox(height: 12)` (:1876-1878), and the fold stays below it. Seen in `build/review-direct-light.png` and `build/review-batch-dark.png`. |
| UX-458 (P60) | fixed | `capture_review_editor.dart:261-290`: `Semantics(label: '${reviewSchedule}: $day', button: true, excludeSemantics: true, onTap: …)` wraps both the main line and the collapsed one. ARB: `Fecha y hora` / `Date and time` / `Data i hora`. The tester's semantics test passes. Device check still open: real TalkBack speech. |

### Regressions (only in the changed files and flows)

**R2A-1 · Severity 2 · With animations off, the new Tareas row hides under the message**
- Where: `App/lib/screens/home_screen.dart:136-200` (`_reveal`, `_shortfall`, `_messageTop`), Tareas after saving from capture, with animations off (Android "Remove animations").
- The moment: "It says Añadida — where? Something's half covered at the bottom."
- What happens: the row is lit but about 40% of it is under the snackbar (row bottom 550, message top 503).
- Why it fails: change blindness (Rensink et al. 1997). The landed row must be seen whole, and reduced-motion users are the assistive persona.
- Fix: base the clearance on the message's final place, not its current one. Use `visible.bottom - messageHeight - 8` from the SnackBar box's `size.height`, which is final even while it slides in. Or, when the message isn't laid out yet, do the single correction after the message's entry has finished: wait for the `ScaffoldMessenger`'s current snackbar to finish its entry, not for one frame. Keep it to one correction.
- Verify: the failing test `U5: with animations off…` in `App/test/capture_landing_test.dart` passes unchanged.
- Evidence: tester measurement; the cause is inferred from the code.

**R2A-2 · Severity 2 · Cancel during "Entendiendo…" after Volver a decirlo leaves two pending**
- Where: `App/lib/screens/voice_task_screen.dart:982-991`. The processing branch pops before the `_previousResult` check, and `_process` (:882-912) can still finish in the background.
- The moment: "I cancelled, so why are there two of the same thing in Pendientes?"
- What happens: before P60 the old capture was discarded when the user said it again. Now, if the user taps Cancelar or Back while the new words are being understood, the sheet closes, the previous result stays pending, and the new capture is processed and kept too. That's two near-duplicate pending items.
- Why it fails: user control and freedom, and consistency (Nielsen heuristics). Cancelar does something different here than in the listening phase just before, where it brings the result back.
- Fix: check `_previousResult` before the processing branch, so Cancelar returns to the previous result in this phase too. In `_process`, when `_result != null` or the sheet already went back (the session id no longer matches), discard the newly processed session instead of calling `_review`.
- Verify: widget test. On a spoken result, tap Volver a decirlo, say new words, tap Listo, then tap Cancelar while `Entendiendo…` shows. The previous result shows with its edits, and the pending list holds one capture.
- Evidence: verified in code; not tested.

**R2A-3 · Severity 1 · Date line doesn't announce when it's disabled**
- Where: `App/lib/widgets/capture_review_editor.dart:264-268`, while saving (`widget.enabled == false`).
- What happens: `excludeSemantics: true` hides the ListTile's own disabled state. The new node says "button" with no tap action and no `enabled: false`, so TalkBack doesn't say "disabled".
- Fix: add `enabled: widget.enabled` to the `Semantics`.
- Verify: a semantics test while saving: the node has `isEnabled` false.
- Evidence: verified in code.

### Keep
- `Cancelar` and `Volver a decirlo` are low and plain, below the filled primary action with a clear gap, and the fold is last.
- Volver a decirlo can be undone with Cancelar, which is better than an "Are you sure?" dialog (Raskin 2000).
- The landing measures what's on screen, not the inner viewport.
