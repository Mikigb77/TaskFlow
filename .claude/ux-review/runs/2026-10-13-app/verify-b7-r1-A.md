## UX verify — run 2026-10-13-app, b7 round 1, area A (P89, P90, P93) — 2026-10-14

**Verdict:** All four findings are fixed in code: UX-496, UX-497, UX-498 and UX-499. There are three new regressions. One is severity 2: when only a recording is kept, the sheet has no next step except Cancelar, and Cancelar asks to keep something the sheet just said was kept. The other two are copy polish (severity 1).
**Evidence used:**
- the code (`git diff HEAD`, grep);
- the ux-tester's tests in `App/test/capture_free_dictations_test.dart` and `App/test/voice_settings_test.dart`;
- the render `App/build/capture-listening-es-2x.png` (12:51, newer than the code). It shows the Pro/listening path is unchanged: no banner, and Listo is still the dominant button.

No preview covers the used-up states, so I judged those from the widget code. I didn't run Flutter.

### UX-497 · fixed (still needs a phone)
- `App/lib/services/api_client.dart`, `FreeVoice` and `AccountStorage`:
  - `Account` parses `free_voice` and `storage`; both are nullable.
  - `rememberFreeVoice` writes a dictation's block into the saved session and emits `accountUpdated`.
  - `AuthNotifier` listens to that stream (`auth_provider.dart:45-55`).
- The count refreshes at start (`restore` → `refreshAccount`) and on resume (`main.dart:123` → `SubscriptionController.refresh` → `refreshAccount`).
- `App/lib/providers/subscription_provider.dart:59-82`: `voiceAvailableProvider` = hasPro, or `left > 0`. `FreeVoice.leftAt` counts a saved 0 as the full limit once `now ≥ resets_at`, and with no block it falls back to hasPro. It never waits on the network.
- The mic follows `voiceAvailable` in four places:
  - the sheet (`voice_task_screen.dart:246`);
  - the Añadir tarea icon (`task_actions.dart:57`);
  - Notas (`notes_screen.dart:262`);
  - "Volver a decirlo" (`voice_task_screen.dart:1268`).
- The widget and the voice shortcut open the same sheet, so they follow it too.
- Typed words go to the assistant only with Pro: `local: !hasPro && source != 'speech'` (`voice_task_screen.dart:1104`).
- `freeVoiceLeft` shows under a spoken result when 3 or fewer are left (`voice_task_screen.dart:2273`, `:2371`). It has ICU plurals in EN, ES and CA, and it says dictados/dictations/dictats.
- The speed bar holds: anyone with dictations left gets no new tap, dialog or wait.
- Needs a phone: dictate on a free account against the real server and watch the count on the Pro screen drop. Also check the widget and the voice shortcut.

### UX-499 · fixed
- `App/lib/services/capture_processor.dart`:
  - `:216`: `capture_id` is sent with every AI request.
  - `:87-108`: `_cancelRequest` fires `DELETE ai/drafts/<id>/` without waiting, swallows the 409, and renews the ID for any next attempt.
  - `:200`: words dropped before the request goes out are never sent.
- Callers:
  - "Guardar tal cual" calls `_cancelRequest`.
  - Cancel after "Volver a decirlo" calls `cancel()` (`voice_task_screen.dart:1373-1378`).
  - Closing the sheet while it's understanding just pops, so no cancel is sent and the dictation counts, as decided.
- Tests: all three UX-499 cases pass.

### UX-498 · fixed (still needs a phone)
- `App/lib/services/capture_problem.dart:83`: a 402 with `free_voice_used_up` maps to `freeVoiceUsedUp`; `pro_required` reads the same (`:68`).
- `App/lib/screens/voice_task_screen.dart:1527-1544`:
  - At 0 left the sheet opens in typing with `freeVoiceUsedUp` (local short date) and "Ver Pro", and creates no recorder.
  - After a 402, `_typing = true` (`:1146`): the words stay in the field with "Guardar tal cual", and nothing is sent again.
  - The error banner is suppressed so the line isn't said twice (`:1701`).
  - The line is a live region.
- A recording with no words shows `freeVoiceUsedUpRecording` in the sheet and in Capturas pendientes (`captures_screen.dart:25-40`).
- A 503 `billing_unavailable` keeps the try-again message.
- Needs a phone: open capture from the home-screen widget with 0 left.
- See R1A-1 for the recording-only state.

### UX-496 · fixed
- `App/lib/screens/voice_settings_screen.dart:96,158,172,193`: once set-up has failed, the `onDeviceUnavailable` line and the Configurar / Comprobar de nuevo row hide, and only the `voiceSetupUnavailable` banner remains.
- Before any attempt, the screen is unchanged. When set-up opens, `voiceSetupRequested` keeps Comprobar de nuevo.
- Tests: all four UX-496 cases pass.

### Regressions

**R1A-1 · Severity 2 · Kept recording: no next step, and Cancelar asks "keep?"**
- Where: `App/lib/screens/voice_task_screen.dart:1537` (`waitsForMore`), `:1589-1599` (the `refused` branch), `:1146` (`_typing = true`) and `:1316-1355` (`_cancel`). The sheet, after a 402 on a recording-only capture, or when such a capture is reopened from Capturas pendientes at 0 left.
- The moment: "It says my recording is kept. Now 'Cancelar' asks if I want to keep it — did I lose it?"
- What happens:
  - The `refused` branch has no primary button: nothing to continue, and "Guardar tal cual" needs words.
  - The sheet shows "Tu grabación se conserva. Se podrá entender a partir del 1 nov, o ahora con Pro.", then "Ver Pro" and an empty typing field with the hint "Médico el viernes a las 17:00". The only other control is "Cancelar".
  - Cancelar opens "¿Conservar lo que has dicho?" with Descartar / Conservar. The test (`capture_free_dictations_test.dart:543-549`) has to tap Conservar.
  - Typing in the empty field brings up "Guardar tal cual" for the typed text, and nothing says what happens to the recording.
- Why it fails:
  - No primary action: the user can't tell what to do next (Norman's gulf of execution).
  - The dialog asks about something the sheet already settled. Confirmations get clicked through without being read (Raskin 2000), and a red "Descartar" puts the kept recording at risk.
- Fix: subtract.
  - In the `waitsForMore` state, don't open the typing field.
  - Make the one button a FilledButton that closes the sheet at once with the capture kept, and skip the keep dialog. Copy: EN `Close`, ES `Cerrar`, CA `Tanca` (new key). It replaces "Cancelar" in that state.
  - Result: 1 control instead of 2, and 0 dialogs instead of 1.
- Verify: widget test on the 402 recording-only case. No `capture-words` field; one FilledButton `Cerrar`; tapping it pops with no AlertDialog; the session isn't discarded and is listed in Capturas pendientes.
- Evidence: verified in code and in the test's own steps.

**R1A-2 · Severity 1 · Catalan says "el 1 de nov." instead of "l’1"**
- Where: `App/lib/l10n/app_ca.arb:875` (`…en tindràs més el {date}`) and `:876` (`…a partir del {date}`).
- What happens:
  - `{date}` is `DateFormat.MMMd('ca')`, which gives "d MMM" with the month "de nov.".
  - The reset is the 1st of the month (UTC), so in Spain the date always reads "1 de nov.".
  - The text comes out as "el 1 de nov." and "a partir del 1 de nov.". Catalan needs "l’1" and "de l’1".
  - Elsewhere the day can be 30 or 31, where "el" is right, so a fixed elision doesn't work either.
- Why it fails: each language must read naturally (plain-language guidance, ISO 24495-1).
- Fix: put "dia" before the date in Catalan only, which reads correctly for any day:
  - `freeVoiceUsedUp`: `Ja has fet servir els dictats gratuïts d’aquest mes. La pots escriure aquí; en tindràs més el dia {date}.`
  - `freeVoiceUsedUpRecording`: `La gravació es conserva. Es podrà entendre a partir del dia {date}, o ara amb Pro.`
  - P92's `freeVoiceStatus` ("Més el {date}") has the same problem: `Més el dia {date}.`
- Verify: unit test that formats the CA strings with 1 Nov and checks for "el dia 1 de nov.".
- Evidence: verified in code and in intl 0.20.2's `ca` pattern and month symbols.

**R1A-3 · Severity 1 · After the last free dictation: "Te quedan 0 dictados"**
- Where: `App/lib/l10n/app_*.arb`, `freeVoiceLeft` (EN :1690, ES :1180, CA :874), shown at `voice_task_screen.dart:2371` whenever `freeLeft <= 3`, including 0.
- What happens: after the 10th dictation the result reads "Te quedan 0 dictados gratis este mes" / "0 free dictations left this month". That is grammatical, but stiff for the moment that matters most.
- Fix: add `=0` to each plural:
  - EN `No free dictations left this month`
  - ES `Ya no te quedan dictados gratis este mes`
  - CA `Ja no et queden dictats gratuïts aquest mes`
- Verify: the plural test also covers 0 in EN, ES and CA.
- Evidence: verified in code.

### Not regressions (checked)
- Listening and Pro paths: there's no banner without the used-up state, and the render is unchanged.
- `captureSpeakingIsPro` now shows only for an older server with no count. That's intended.
- After a failed set-up, Voz no longer offers Comprobar de nuevo. That's the reviewer's own fix (UX-496), and the banner already says TaskFlow does it online.
