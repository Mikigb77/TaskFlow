## UX verify — 2026-10-19-app, b2 round 2, area A (P200) — 2026-10-20

**Verdict:** both findings fixed; no regressions from P200.

Evidence base: the code (`git diff HEAD`), ux-tester's passing tests, and the renders `App/build/ux/capture/sheet.error-limit-recording.{es.light.1x,es.light.2x,ca.light.2x}.png` (10:05). No file in App/lib or App/assets is newer than these renders, so they are current. AUDIT `capture/sheet · error-limit-recording` was also read. Everything here is widget-test or render level, not a device.

| ID | Result | Evidence |
|---|---|---|
| UX-1630 | fixed | (a) `voice_task_screen.dart:1773-1780`: `_limitWaits` is true when the sheet is resting, the capture is recorded, there are no words, the error is `allowance` and there's no previous result. `_recordingWaits()` (:1767-1768) and build's `recordingWaits` (:2080-2082) include it, so the primary is «Cerrar» (`capture-close`, :2158-2163), «Cancelar» is hidden (:2418), and `_cancel` (:1883) closes without the discard question. (b) :2103: no «Grabación guardada en este teléfono» in this state. (c) :2328-2330: the banner reads `captureAllowanceRecording`; the ARB copy matches the brief in EN, ES and CA (en:1519, es:894, ca:709), with an @description in en:1520-1522; `captureProblemText` is unchanged. (d) :620-622: a reopened capture clears a stored `allowance`, so it shows «Reintentar». (e) Typed words are unchanged (the capture_sheet_test UX-1630 case). Renders: ES 1×/2× and CA 2× show the banner whole above «Cerrar»/«Tanca», with nothing else to tap. AUDIT: 0 cut text, 0 layout errors; TalkBack reads the banner (live region), then «Cerrar». The ES 1× contrast line is the known anti-aliasing false positive (7.24:1). The 52 dp primary note is on every sheet and predates this round. Device check still owed: staging, an account at its daily limit with online speech, reopened the next day. |
| UX-1631 | fixed | `voice_task_screen.dart:3512-3519` in `_apply`: only an `ApiException` that `CaptureProblem.from` maps to `offline` reads `captureOffline`; every other error reads `captureSaveFailed` («No se ha podido añadir. Tus palabras siguen aquí; vuelve a intentarlo.»). The comment says so. The voice_command_cards tests for 503, timeout, unreachable, 403, 413, 422 and 429 (Retry-After 3600) pass, and so does the UX-1318 offline test. |

### Regressions
None from P200.

What I checked in the flows it touches:
- swipe down and Back go through `PopScope` → `_cancel` and close at once;
- the ring under the banner is an inert `ExcludeSemantics` mic, so nothing in the refused state can be tapped by mistake;
- the reopen clear also applies to typed captures, which then show «Reintentar» and «Guardar como tarea». That's harmless.
- In Capturas pendientes the refused recording reads «Grabación · Hoy, hh:mm». That's the existing subtitle, unchanged.

The rest of the `git diff HEAD` on `voice_task_screen.dart` belongs to other packages:
- the controls layout;
- the `captureYourWords` semantics;
- `actionsOverflowButtonSpacing`;
- the spacing on the result's «Cancelar»/«Volver a decirlo».

Those are judged in their own verifications.

### Notes (not regressions)
- «Inténtalo mañana» doesn't say where the recording waits tomorrow. The sheet has no line naming Capturas pendientes, so a newcomer may not find it again. The same gap exists for recordings that wait for free dictations. It's a candidate for one short clause, e.g. ES «…; mañana la encontrarás en Capturas pendientes.» Not raised as a regression: the copy is the reviewer's, as the brief asked.
