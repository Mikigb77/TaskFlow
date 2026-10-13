## UX verify — 2026-10-13-app, b2 round 2, area A (P54) — 2026-10-13

**Verdict:** All three findings fixed in code and proven by widget tests; no regressions found. TalkBack speech itself still needs a phone (UX-441).

Evidence level: code read (`git diff HEAD`, current file) plus ux-tester's passing tests. The only fresh capture render (`App/build/capture-listening-es-2x.png`, 20:20) shows the listening state, whose layout P54 did not change; no preview covers the paused, shared-text or silence-hint states.

### UX-440 · fixed
- `App/lib/screens/voice_task_screen.dart:1031-1037`: `canContinue` now needs `phase == paused` or `phase == idle && _session?.source == 'speech'`, and keeps `!_typing`, `!recorded`, `_nativeMode` and words not empty.
- Shared text is stored with source `typed` (`App/lib/services/capture_store.dart:100`), and typed text in the sheet gets `typed` from `_changedText` (`voice_task_screen.dart:424-428`). So it shows only `Listo`, `Cancelar` and the keyboard button.
- Tests pass: shared text opened with `startListening: false` shows no `Seguir`. Background interruption shows `En pausa` and `Seguir`, and so does a reopened voice capture.

### UX-441 · fixed (TalkBack wording needs a phone)
- `voice_task_screen.dart:726-742`: announces `done` only when `submit`; announces `capturePaused` only when not `quiet` and the phase landed on `paused`; otherwise nothing.
- `_typeInstead` (:868) and `_cancel` (:883) pass `quiet: true`. Cancel keeps `interrupted: true`, so it lands in `paused` as before.
- Interruptions without a user request (leaving the app :790, audio focus :717, recognizer `ended` :505, start-up races :613/:653/:658, `_interruptCapture` :950) all pass `interrupted: true`, so they announce `En pausa` when words or audio were kept.
- Tests pass with `tester.takeAnnouncements()`: Cancel gives none before the dialog, Listo gives exactly one, the keyboard button gives none, and going to the background gives `En pausa`.
- Device check still open: on a phone with TalkBack, Cancel with words is silent before the keep-or-discard question, and Listo says `Listo`.

### UX-444 · fixed
- `App/lib/l10n/app_en.arb:1183` now reads `Still listening. Tap Done when finished.`, and the generated EN file matches (`app_localizations_en.dart:2572`). ES and CA are unchanged. `maxLines: 2` is kept (`voice_task_screen.dart:1145`).
- Test passes: EN at 2× text on 360×740 with Manrope gives `didExceedMaxLines == false`.

### Regressions
None caused by P54.

Noted, not counted (both existed before P54):
- A recognizer **error** (terminal, kind not `ended`) stops as `idle` with no announcement. The error shows in a `MessageBanner` that isn't a live region, so TalkBack hears nothing. Before P54 it wrongly said `Listo`; at HEAD it said nothing. Worth a later look.
- If the 60 s cap fires in native mode with no words heard, the submit path announces `Listo`, and the sheet then returns to `Empezar a hablar`. This edge is rare.
