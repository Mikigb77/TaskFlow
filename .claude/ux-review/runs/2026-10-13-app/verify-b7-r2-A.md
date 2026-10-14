## UX verify — b7 round 2, area A (P94) — 2026-10-14
**Verdict:** Ship after one Catalan copy fix — UX-502 and UX-504 are done; UX-503 fixed the "el 1" wording but Catalan still shows a doubled full stop ("nov..").
**Evidence level:** code (`git diff HEAD`) plus ux-tester's widget/unit tests. No preview covers the used-up state; `App/build/capture-listening-es-2x.png` (re-rendered 2026-10-14 13:27) shows the listening state unchanged.

### UX-502 · fixed (device check pending)
- One rule for both places: `_freeVoice()` (`App/lib/screens/voice_task_screen.dart:1298-1319`) and `_recordingWaits()` (:1324-1325) = `waitsForMore && _previousResult == null`; `build` uses the same rule (:1558-1560).
- Primary is a single full-width `FilledButton` `capture-close` → `l10n.captureClose`, `Navigator.pop` at once (:1612-1617). Sits low and central, in the thumb zone.
- No typing field: `words = _typing && !recordingWaits ? TextField : …` (:1657-1658).
- No Cancelar: `showCancel: !recordingWaits` (:1819); `_controls` drops it and the empty second row (:1868-1928).
- Back / swipe: `_cancel` pops with no dialog when `_recordingWaits()` (:1358-1361). The pending store is untouched (same as the old `Conservar`).
- Kept-recording status line is hidden in that state so the used-up line (live region) is the only message (:1574-1575); the used-up refusal banner is suppressed (:1730-1731). One message, one button, Ver Pro as a text link.
- Untouched as required: words-kept-after-402 still shows the field, `Guardar tal cual` and Cancelar with its keep question (`refused` branch :1618-1629, test pass); after `Volver a decirlo` Cancel still returns to the result (`_previousResult` check first in `_cancel`).
- Tests pass: es 2×/360, ca 2×/320, en 2×/320 layout; Cerrar closes and capture stays listed; reopened from Capturas pendientes at 0 left; Back with no dialog.
- Needs a phone: real free account at 0 left, no keyboard rising on reopen.

### UX-503 · partly
- 'dia' is in place: `App/lib/l10n/app_ca.arb:875-878`. ES and EN unchanged (test pass).
- Still wrong: `DateFormat.MMMd('ca')` (`capture_messages.dart:14`, `region.dart:16` via `subscription_screen.dart:60`) yields `1 de nov.`, and two Catalan sentences end in `{date}.`, so the screen reads `…en tindràs més el dia 1 de nov..` (capture sheet) and `…Més el dia 1 de nov..` (Pro screen). `freeVoiceUsedUpRecording` is fine (`{date}, o ara amb Pro.`). Acceptance `freeVoiceStatus ends with 'Més el dia 1 de nov.'` fails.
- Pre-existing (the old templates also ended `{date}.`), not caused by P94, but the finding's acceptance is not met.
- Fix (Catalan only; can't just drop the stop, because `març`, `maig`, `juny` have no abbreviation dot): move the date out of the sentence end.
  - `freeVoiceUsedUp` CA → `Ja has fet servir els dictats gratuïts d’aquest mes. La pots escriure aquí; el dia {date} en tindràs més.`
  - `freeVoiceStatus` CA → keep the plural part as it is; change the end to `El dia {date} en tindràs més.`
  - Update the UX-503 test: `contains('el dia 1 de nov. en tindràs més')`, and keep the `isNot(contains('..'))` loop.

### UX-504 · fixed
- `=0` branches: `app_en.arb:1690` `No free dictations left this month`; `app_es.arb:1180` `Ya no te quedan dictados gratis este mes`; `app_ca.arb:874` `Ja no et queden dictats gratuïts aquest mes`. `=1`/`other` unchanged; the line's condition (`freeLeft <= 3`, voice_task_screen.dart:2406) unchanged. Test pass.

### captureClose
- `Close` / `Cerrar` / `Tanca` with the requested @-description (`app_en.arb:1717-1720`); test pass.

### Regressions
None found in the changed files or the flows they touch (recording-only refusal, reopen from Capturas pendientes, words-kept refusal, Volver a decirlo, listening).
