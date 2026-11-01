## UX review — A1: Ways in and listening (whole-app run 2026-10-28-app) — 2026-10-31

**Verdict:** Ship after fixes. Every way in reaches the one capture sheet or the form, and the three-tap path holds. But on the online speech path nobody can type once listening starts, Cancelar during «Entendiendo…» parks the words without asking, and after 8 s a filled «Guardar como tarea» saves several tasks as one.

**Evidence used:**
- **Renders:** `App/build/ux/capture/` (2026-10-28 17:56–17:58), `calendar/` (17:59–18:04) and `settings/` (2026-10-29 08:56), all from 6281e3d, read with AUDIT.md. `find App/lib App/assets App/android/app/src/main -newer <png>` lists no file, so every render is current. These are widget-test evidence.
- **Device captures:** `App/build/ux/device/`, 2026-10-29 09:13–10:08, built at 30c8ce0 (the same app code), with their `a11y/*.xml` trees. These are emulator evidence: no real voice, Pixel Launcher, API 36.
- **Code:** everything else, as each finding says.
- **Guides:** `references/guidelines.md` was present and used.

**Walked:** the Newcomer (Spanish, 2× text, 360 dp, one hand), the Daily user (several in a row, noisy places) and the assistive user (TalkBack, tremor, low vision).
- **Calendar → a spoken task (Pro, on-device speech):** Añadir tarea → Android's dialog on first use → speak → Listo → «Entendiendo…» → result. 2 taps to the result, 3 to save.
- **The same on the online path** (Catalan on the emulator, Voz «En línea, al terminar», or phones without on-device speech): no live words, «Fet» active at once, and no «Escriu».
- **A free account:**
  - with dictations left: the same, plus «Escribir» → form;
  - at 0 left: «Nueva tarea» → the monthly notice → «Crear una tarea» → form (2 taps; 1 after the first time).
- **Ways in from outside the app:**
  - the widget, warm and cold (1 tap → listening);
  - the «Dictar una tarea» shortcut (long-press + tap → listening);
  - the «Escribir una tarea» shortcut (→ form, free);
  - sharing text (chooser → TaskFlow → form, free);
  - «Sin guardar · N» → the list → resume.
- **Microphone:**
  - first ask;
  - refused once → «Empezar a hablar»;
  - refused twice → «Abrir Ajustes» → App info → Permisos › Micrófono › Permitir → back, and it listens by itself.
- **Listening:**
  - the quiet hint at 5 s and «Sigo escuchando»;
  - the countdown at 50 s and the cap at 60 s, with and without words;
  - leaving the app → «En pausa» → Seguir.
- **Waiting and failing:**
  - «Entendiendo…»;
  - slow at 8 s;
  - offline (typed), 503 (spoken), the daily limit on a recording, nothing found.
- **Interrupted:**
  - Cancelar → keep or discard;
  - Back and swipe;
  - Cancelar during «Entendiendo…»;
  - the app killed → «Sin guardar».
- **TalkBack:** Añadir tarea → «Empezar a hablar» (focused) → listening → Listo.
- **Diagnóstico de captura** is a debug and staging screen (D13). Not reviewed for the newcomer.

**Numbers:**

| What | Now | After the fixes |
|---|---|---|
| Taps, Calendar → one dated spoken task | 3 (+1 Android dialog the first time) | 3 |
| Ways in that reach the sheet or the form | 7 | 7 |
| Online speech path: ways to type once listening has started | 0 | 1 |
| Cancelar during «Entendiendo…»: words kept without a choice | yes | no (the usual keep question) |
| Filled buttons at 8 s while the assistant still works | 1 (a one-task save, unseen) | 0 |
| Capture strings that call kept words «guardadas» or "saved" | 7 | 0 |
| Rendered sheet states (of 18) showing a microphone while it's off | 7 | 0 |
| TalkBack announcements spoken while the microphone records | 2 | 0 |
| Height of the two capture taps («Añadir tarea», «Listo») | 52 dp (8.3 mm) | 60 dp (9.5 mm) |
| Launcher shortcut glyph (emulator) | ≈ 5 × 7 dp | ≈ 16 dp |
| Listening sheet tap targets, on-device / online | 3 / 2 | 3 / 3 |

### Findings (most severe first)

**UX-2101 · Severity 3 · Online listening hides «Escribir»: typing is unreachable**
- **Where:**
  - `App/lib/screens/voice_task_screen.dart:2116` (`recorded`) and `:2473` (`showType: !_typing && !recorded && !typeFirst`).
  - On the online path, the recorder's first amplitude event, every 120 ms, turns the capture into a recording (`:832-850`, `:1203-1210`).
  - State: the capture sheet listening, paused or failed on the online path. That path covers:
    - Voz «En línea, al terminar»;
    - Android 11 and older (`NativeSpeechBridge.kt:71` needs API 31);
    - phones with no on-device recognizer, or without the language installed (Catalan on the emulator);
    - a capability probe that times out (`native_speech.dart`, `usable` false).
- **The moment:** "I'm in the waiting room, I can't talk out loud. Where do I type it?"
- **What happens:**
  - «Escribir» shows only for the instant before the recorder starts, then disappears. On the emulator, `device/capture.listening.ca.light.{1.0,2.0}.png` shows «S'està escoltant · 00:07», «Fet» and «Cancel·la», with no «Escriu».
  - Cancelar asks keep or discard, then closes. «Añadir tarea» starts listening again.
  - A free account with dictations left can't reach the form at all, and a Pro account can't reach typing.
  - Offline, the recording fails with «Sin conexión…» and only «Reintentar». Nothing can add the task now.
  - The only typing way left is the launcher's long-press shortcut «Escribir una tarea».
  - TalkBack users are spared: listening waits for «Empezar a hablar», with «Escribir» beside it.
- **Why it fails:**
  - VO-16 (Luger 2016; Android Permissions): typing is always one tap away, offline included.
  - UX_REVIEW §3.1 and U9: «⌨ Type instead» belongs in the listening sheet.
  - CO-8 (Budiu 2024): recognition over recall.
  - PL-8 and OL-3 (Kobayashi 2011): the only remaining way is a long-press.
- **Fix:**
  - Show «Escribir» on the online path in every state where the on-device path shows it.
  - Tapping it stops the recorder:
    - if nothing above the silence level was heard, drop the empty recording, as `_dropUnheardAudio` and `_dropSilent` already do;
    - otherwise, ask the existing keep question («¿Conservar lo que has dicho para más tarde?», Descartar / Conservar). Conservar leaves the recording in «Sin guardar».
  - Then open typing (Pro) or the form (free) with an empty field. Never hand the recording to the form.
  - No new copy.
- **Verify:**
  - Widget test on the online path (capability not usable), with amplitude events flowing:
    - «Escribir» (or `capture-fill-by-hand`) is present and enabled while listening, paused and failed;
    - with silent levels, a tap opens typing or the form and leaves no pending capture;
    - with speech-level amplitude, a tap asks the keep question; Conservar → «Sin guardar · 1», then typing.
  - Emulator lane: the Catalan listening capture shows «Escriu».
- **Evidence:** seen in an emulator capture (2026-10-29 10:00, 30c8ce0) and verified in code. How often real Spanish phones take the online path needs a phone check.

**UX-2102 · Severity 2 · Cancelar during «Entendiendo…» parks the words without asking**
- **Where:**
  - `voice_task_screen.dart:1927-1930`: `if (_phase == processing) { Navigator.pop(context); return; }`.
  - Back and the swipe go through the same `_cancel()`.
  - Locked in by `App/test/capture_result_exits_test.dart:362`.
  - State: the capture sheet while understanding, the 8 s slow state included.
- **The moment:** "It's taking ages, I'll cancel and say it again… why does it say «Sin guardar · 1» now?"
- **What happens:**
  - The sheet closes at once and the request keeps running.
  - The answer is stored, and «Sin guardar · 1» appears above «Añadir tarea». Nothing says why.
  - For a free account, the dictation counts.
  - When listening, typing, or on a result with something to add, the same Cancelar asks «¿Conservar lo que has dicho para más tarde?».
- **Why it fails:**
  - UX_REVIEW §6, U2's done-when: "No code path leaves words parked without the user choosing it."
  - Consistency (Nielsen 1994h): one button, two behaviours depending on the state.
  - SC-10 (Rensink 1997): a change outside the focus, with no signal.
- **Fix:**
  - During understanding, ask the same `_askToKeep(spoken: …)` question.
    - Conservar → close. Understanding finishes and the result waits in «Sin guardar». It counts, as the free-tier plan keeps it.
    - Descartar → `CaptureProcessor.cancel(attempt)`, the DELETE that Volver a decirlo already sends, then discard. No dictation is used, as DECISIONS 2026-10-13 says for cancelled dictations.
    - Dismissed → stay and keep waiting.
  - If the answer arrives while the question is open, the choice still applies to it.
  - No new copy.
- **Verify:**
  - Update `capture_result_exits_test.dart:362`.
  - First capture, Cancelar, Back and swipe during «Entendiendo…» each show the question.
  - Descartar → no pending capture, and the cancel is sent.
  - Conservar → pending once understood.
- **Evidence:** verified in code and tests.

**UX-2103 · Severity 2 · At 8 s, a filled «Guardar como tarea» saves several tasks as one**
- **Where:**
  - `voice_task_screen.dart:1459-1463` (the 8 s timer), `:2190-2191`, and `:2253-2262` (the only filled button).
  - `:1585-1619` → `CaptureProcessor.asWritten` → `App/lib/services/local_capture.dart:81-149`. `localDrafts` always returns one draft.
  - The draft saves at once (`saveAtOnce`, `voice_task_screen.dart:2646-2654`).
  - Renders `capture/sheet.understanding-slow.{es.light.1x,es.light.2x,ca.light.2x}`.
- **The moment:** "There's a big green button now — I'll press it." Then on Calendar there's one task: «Comprar pan y leche, llamar al médico y recoger a los niños del colegio…».
- **What happens:**
  - At 8 s, «Guardar como tarea» takes the primary slot, filled and full width.
  - One tap cancels the assistant, whose answer usually comes seconds later. On staging and production the free model gives way to the paid one after 10 s (UX-616, DECISIONS 2026-10-18 night).
  - It saves the phone's reading at once, without a look. That reading is always one task, because the parser can't split. The other words go into its title or notes.
  - The first-run example itself, «Mañana, llamar al dentista y comprar pan», becomes one task.
- **Why it fails:**
  - SC-4 (M3 Buttons): the filled button is for the action that completes the flow as intended. Here it's the fallback.
  - VO-12 (Stivers 2009; Sherwin 2014pr): after about 8–10 s, explain and offer a way on. It needn't take over.
  - VO-7 (Budiu 2018ia): several tasks, one row each. Several tasks in one dictation is a must (DECISIONS 2026-10-15).
- **Fix:**
  - While the assistant is still working, show «Guardar como tarea» as a TextButton under «Está tardando más de lo normal.». No filled button: nothing is ready to confirm.
  - After a failure, it stays filled, as now.
  - Copy unchanged. Whether it should then show its one task before saving is D-A1-1 below.
- **Verify:**
  - At 8 s, `find.widgetWithText(FilledButton, captureSaveAsWritten)` finds nothing, and the TextButton is there and at least 48 dp.
  - After a 503 it's filled again.
  - Re-render `capture/sheet.understanding-slow.*`.
- **Evidence:** seen in current renders; verified in code.

**UX-2104 · Severity 2 · The offline line says "wait", over a button that saves now**
- **Where:**
  - `App/lib/l10n/capture_messages.dart:28-29`.
  - `captureOffline`: `app_en.arb:1671`, `app_es.arb:890`, `app_ca.arb:705`.
  - `captureUnavailable`: `app_en.arb:1672`, `app_es.arb:891`, `app_ca.arb:706`.
  - Shown at `voice_task_screen.dart:2377-2387`.
  - Renders `capture/sheet.error-offline.{es.light.1x,es.light.2x,ca.light.2x}` and `capture/sheet.error-unavailable.*`.
- **The moment:** "No internet, it says try later… so I'll close it." The task never reaches the calendar.
- **What happens:**
  - ES «Sin conexión. Tus palabras están guardadas; inténtalo cuando tengas internet.» sits over «Reintentar» and a filled «Guardar como tarea», which works offline.
  - The line steers people to wait, and «guardadas» reads as "done" (see UX-2105).
  - «No he podido contactar con el asistente…» names an assistant the app never introduces. It's the only «asistente» on screen in the Spanish catalog.
  - Neither line says what to tap.
- **Why it fails:**
  - UN-7 (Neusesser 2023): say what happened and how to fix it.
  - OL-2 (Nielsen 2013): never imply fault.
  - Plain language: no internal names.
- **Fix:**
  - When there are words to save:
    - offline: EN "No internet. Tap Save as a task, or try again when you're online." ES «Sin conexión. Toca Guardar como tarea o reinténtalo cuando tengas internet.» CA «Sense connexió. Toca Desa-ho com a tasca o torna-ho a provar quan tinguis internet.»
    - unreachable: EN "I can't turn your words into tasks right now; they're kept." ES «Ahora no puedo convertir tus palabras en tareas; se conservan.» CA «Ara no puc convertir les teves paraules en tasques; es conserven.» This is the wording of `captureSignIn` and `captureForbidden`.
  - Offline, recording only: a variant that names no missing button, as `captureAllowanceRecording` does. EN "No internet. Your recording is kept; try again when you're online." ES «Sin conexión. La grabación se conserva; reinténtalo cuando tengas internet.» CA «Sense connexió. La gravació es conserva; torna-ho a provar quan tinguis internet.»
  - Choose the recording variant when `_session?.audioPath != null && !_hasWords`.
  - Modelled with Manrope in the banner's 250 dp text width at 2×: ES offline stays at 5 lines, CA offline goes from 6 to 5, ES unreachable stays at 5.
- **Verify:**
  - Catalog test in three languages: no capture string says «asistente», "assistant" or «assistent».
  - Renders: `error-offline` ES and CA at 2×, and `error-unavailable`.
  - Widget test: the recording-only offline banner names no «Guardar como tarea».
- **Evidence:** seen in current renders and verified in code. The line counts are modelled with Manrope; the model matches today's renders (5, 6 and 3 lines).

**UX-2106 · Severity 2 · A grey microphone shows while the microphone is off**
- **Where:**
  - `voice_task_screen.dart:2460-2463`: the ring shows whenever the sheet isn't typing.
  - `:2490-2520`: `_ring` draws a grey mic unless listening.
  - Renders: `capture/sheet.{paused,mic-denied,mic-blocked,mic-blocked-online,error-unavailable,error-limit-recording,error-nothing-understood}.*`.
  - Emulator: `device/permission-mic.denied.*` and `device/capture.listening-ended.*`.
- **The moment:** "There's the microphone — I'll tap it and talk again." Nothing happens; or they start talking to a sheet that isn't listening.
- **What happens:**
  - In 7 of the 18 rendered sheet states, the 72 dp mic in its ring sits mid-sheet while nothing listens.
  - It isn't a button: no tap, excluded from semantics.
  - It differs from listening only by colour, grey against teal. Most of those states have no status line saying that nothing is listening.
  - The control that actually does it sits under it: «Empezar a hablar», «Seguir» or «Volver a decirlo».
- **Why it fails:**
  - VO-1 (Yankelovich 1995; Harley 2018): listening is unmistakable, and the microphone shows only while it listens.
  - AC-5 (WCAG 2.2 1.4.1): never colour alone.
  - Norman 2013: a signifier with no function.
- **Fix:**
  - Show the ring only while starting («Un momento…»), listening and understanding. Remove it in the idle and paused states.
  - This removes an element. Those states get about 104 dp shorter, which gives the words and banners room at 2×.
- **Verify:**
  - The 7 renders show no ring; listening, starting and understanding are unchanged.
  - Widget test: `find.byIcon(Icons.mic_none_rounded)` inside the sheet only while the phase is starting or listening.
- **Evidence:** seen in current renders and emulator captures; verified in code.

**UX-2107 · Severity 2 · TalkBack's speech goes into the open microphone**
- **Where:**
  - `voice_task_screen.dart:982-987`: `_listening()` announces `captureListening` as the microphone opens. `NativeSpeechBridge.kt:228` emits `listening` as soon as the app's own AudioRecord starts, and the recorder path calls `_listening()` right after `recorder.start`.
  - `:1000`: `captureTimeLeft(10)` is announced at 50 s, mid-listening.
  - State: the capture sheet with TalkBack on.
- **The moment:** a TalkBack user hears the result read back as «Escuchando, comprar pan…». "I didn't say that."
- **What happens:**
  - With TalkBack on, the sheet waits for «Empezar a hablar» so the screen reader's speech isn't recorded (UX-109).
  - But the app then makes TalkBack say «Escuchando» as the microphone opens, and «Quedan 10 segundos» at 50 s. Both come out of the speaker while it records.
  - The `VOICE_RECOGNITION` source isn't guaranteed echo cancellation, so these words can land at the start and the end of the dictation.
- **Why it fails:**
  - VO-1 and AC-7: announce state changes, but not into the user's own input.
  - It undoes the reason UX-109 gave for not starting by itself.
- **Fix:** when `MediaQuery.accessibleNavigationOf` is true:
  - announce «Escuchando» first, and open the microphone about 1 s later, with «Un momento…» meanwhile;
  - announce nothing while recording. At 50 s, give a haptic pulse instead; the cap acts as Listo, so nothing is lost.
  - The sighted flow is unchanged.
- **Verify:**
  - Widget test with accessible navigation and an announcement spy: no announcement between `speech.start` or `recorder.start` and the stop; «Escuchando» comes before the start.
  - Phone with TalkBack: say «comprar pan» and wait past 50 s. The words contain neither «Escuchando» nor «Quedan».
- **Evidence:** inferred from code; needs a TalkBack phone check.

**UX-2108 · Severity 2 · The two capture taps are 52 dp tall**
- **Where:**
  - `App/lib/theme/app_theme.dart:95-97`: `FilledButton` `minimumSize: Size(48, 52)`.
  - Used by «Añadir tarea» (`App/lib/widgets/task_actions.dart:108-116`) and by the sheet's primary: «Listo», «Empezar a hablar», «Seguir» and «Guardar como tarea».
  - AUDIT flags «primary under 56 dp» on every capture render: «Listo» 312 × 52 dp (8.3 mm), «Añadir tarea» 320 × 52 dp.
- **The moment:** (hand tremor) "I pressed Listo and it asked me whether to keep it." The thumb landed on «Cancelar», 12 dp below.
- **What happens:**
  - The two taps every capture needs are 8.3 mm tall.
  - «Cancelar» and «Escribir» sit 12 dp under «Listo», and the tab bar sits under «Añadir tarea».
- **Why it fails:**
  - RE-2 and RE-3 (Parhi 2006: 9.2 mm for single one-handed taps, 9.6 mm for sequences; Kobayashi 2011; Franz 2019): primary and frequent controls should be clearly larger than 48 dp for older hands.
  - Three earlier reviews noted it as cross-slice (2026-10-19-app A:558, B:555, C:717), and it was never filed.
- **Fix:**
  - Raise the filled-button minimum height to 60 dp (about 9.5 mm) in `app_theme.dart:97`: one place, and the same look everywhere.
  - Keep the 12 dp gaps.
- **Verify:**
  - In AUDIT, «Añadir tarea» and the sheet's primary are at least 58 dp tall, and no `capture/*` render has a «primary under 56 dp» flag.
  - At 2×, the primary still shows without scrolling (UX-1302).
- **Evidence:** measured in AUDIT on current renders; verified in code.

**UX-2105 · Severity 1 · Kept words are «guardadas», but listed under «Sin guardar»**
- **Where:**
  - `recordingKept`: ES «Grabación guardada en este teléfono» (`app_es.arb:293`). EN says "kept", CA «conservada».
  - `capturesEmptyHelp`: ES «Aquí se guardan las grabaciones…» (`app_es.arb:932`) and CA «Aquí es guarden…» (`app_ca.arb:747`). This is the empty state of the screen titled «Sin guardar» / «Sense desar».
  - `captureFailed`: EN "Your words are saved here — try again." (`app_en.arb:1851`).
  - `captureOffline`: handled in UX-2104.
- **The moment:** "It says my recording is saved… but it's under «Sin guardar»? Is it saved or not?"
- **What happens:**
  - The same thing is "saved" in one line and "not saved" in the list's name.
  - Elsewhere, ES and CA already say «se conserva» / «es conserva» (`captureUnavailable`, `captureAllowanceRecording`, `freeVoiceUsedUpRecording`).
- **Why it fails:**
  - SC-9 (WCAG 2.2 3.2.4; COGA 2021): one name per concept.
  - Since U11 named the list «Sin guardar», «guardar» has to mean "add as a task".
- **Fix:**
  - EN `captureFailed`: "That didn't work. Your words are still here — try again."
  - ES `recordingKept`: «Grabación conservada en este teléfono».
  - ES `capturesEmptyHelp`: «Aquí se conservan las grabaciones y las tareas que dejes a medias.» CA: «Aquí es conserven les gravacions i les tasques que deixis a mig fer.»
  - The rule from now on: words waiting in «Sin guardar» are «conservadas» / «conservades» / "kept", never «guardadas» / «desades» / "saved".
- **Verify:** catalog test: these keys contain none of «guardad», «se guardan», «es guarden», «desad» or "saved".
- **Evidence:** verified in code (the ARB files).

**UX-2109 · Severity 1 · At 2×, an error banner and the typed words both get cut**
- **Where:**
  - `voice_task_screen.dart:2402-2429`: the error and the words are two `Flexible` scroll views sharing the space.
  - Render `capture/sheet.error-offline.ca.light.2x.png`.
- **The moment:** "The red box ends in the middle of a word… is there more?"
- **What happens:**
  - At CA 2×, the banner's last line, «internet.», is cut through, and its bottom edge is gone.
  - The field below loses its top border, so the two boxes run together.
  - AUDIT doesn't count it as cut text, because the text is inside a scroll view.
  - Longer lines with typed words, such as `captureAllowance` or `captureTooFast`, lose more.
- **Why it fails:** AC-3 and AC-4 (WCAG 2.2 1.4.4, 1.4.10). Recurring problem: key content falls off-screen at 2×.
- **Fix:**
  - The banner shows whole; when space runs out, only the words scroll. For example, put the banner and the words in one scroll view, banner first, or give the banner its natural height and the words what's left.
  - UX-2104's copy also takes CA offline from 6 lines to 5.
- **Verify:** re-render `error-offline.ca.light.2x`, and a typed `captureAllowance` state at CA 2×. The banner's last line and bottom edge are whole.
- **Evidence:** seen in a current render; line counts modelled with Manrope.

**UX-2110 · Severity 1 · Two quick taps on the widget open two sheets**
- **Where:**
  - `App/android/app/src/main/kotlin/com/example/agenda/CaptureWidget.kt:27-31`: each tap starts `CAPTURE_VOICE`.
  - `CaptureEntryBridge.kt:73-84`: each start is queued.
  - `App/lib/main.dart:170-228`: `_openEntries` pushes one sheet per queued entry, and doesn't check for an open one. Its own comment says "before replacing its route", but it pushes.
  - The launcher shortcuts work the same way.
- **The moment:** (double-taps out of habit) "I cancelled it and it's still there."
- **What happens:**
  - The second entry pushes a second sheet over the first. The first stays underneath, idle with «Empezar a hablar», or paused.
  - After a save, both close, because the landing pops back to Calendar.
  - After Cancelar, the first sheet shows again.
- **Why it fails:** OL-1 (Kane 2019): design for recovery. PL-7: one Back is one step.
- **Fix:** in `_openEntries`, a `voice` or `text` entry that arrives while an entry's capture sheet is still on top and has no words is acknowledged without opening another. Shares still open their own.
- **Verify:**
  - Widget test: two VOICE entries 300 ms apart → one sheet; Cancelar → Calendar.
  - Emulator lane: double-tap the widget.
- **Evidence:** inferred from code; needs a device check.

**UX-2111 · Severity 1 · The first-use privacy line doesn't say whose AI, or where in Ajustes**
- **Where:**
  - `capturePrivacyLine`: `app_en.arb:531`, `app_es.arb:308`, `app_ca.arb:287`.
  - Shown at `voice_task_screen.dart:2433-2445`.
  - Render `capture/sheet.listening-first-use.{es,ca}.light.2x`.
- **The moment:** "My words go online — to whom? «Más en Ajustes»… it isn't there."
- **What happens:**
  - The line reads «Tus palabras van por internet. Más en Ajustes.»
  - Voz and the privacy policy say the words go to Google's AI.
  - The Ajustes tab has no «Voz» row: it lives in Ajustes › Otros ajustes › Voz (`device/screen-settings.list.es.light.1.0.png`).
- **Why it fails:**
  - PR-1 (GDPR arts. 12–13; WP260 2018): at first use, say where the words go.
  - CO-3 (Cowan 2001): a pointer the person has to hunt for.
- **Fix:**
  - EN "Your words go to Google's AI. More in Other settings › Voice."
  - ES «Tus palabras van a la IA de Google. Más en Otros ajustes › Voz.»
  - CA «Les paraules van a la IA de Google. Més a Altres opcions › Veu.»
  - Modelled with Manrope at 2× on 360 dp: 3 lines each, inside the line's 3-line limit.
- **Verify:** catalog test; re-render `listening-first-use` ES and CA at 2×: whole, at most 3 lines, no ellipsis.
- **Evidence:** verified in code and render; fit modelled.

**UX-2112 · Severity 1 · Launcher shortcut icons show a 5 dp glyph**
- **Where:**
  - `App/android/app/src/main/res/drawable/capture_shortcut_{voice,text}.xml`: non-adaptive 48 dp vectors with their own 44 dp mint circle.
  - `CaptureShortcuts.kt:37`.
  - Emulator `device/launcher.shortcuts.*`.
- **The moment:** (low vision) "Two little dots — which one is the microphone?"
- **What happens:**
  - The Pixel Launcher wraps the non-adaptive icon in its own white disc.
  - The result is a 32 dp white disc, a 17 dp mint disc inside it, and a 5 × 7 dp glyph (measured: 14 × 19 px at 440 dpi).
  - The labels carry the meaning; at that size the icons add nothing.
- **Why it fails:** PL-9 (Android Shortcuts): shortcuts that read like the system's own. AC-2 (WCAG 2.2 1.4.11): a glyph that small can't be told apart.
- **Fix:**
  - Make both icons adaptive: an `<adaptive-icon>` with the mint `#E3F1EE` background and the teal glyph as foreground, about half the safe zone.
  - The launcher then fills its circle, and the glyph reads at about 16 dp.
- **Verify:** emulator lane, `launcher.shortcuts.es.light.{1.0,2.0}`: no white outer ring, and a glyph of at least 14 dp.
- **Evidence:** seen in an emulator capture (measured).

**UX-2113 · Severity 1 · The online listening hint promises words it never shows**
- **Where:**
  - `captureListeningOnline`: `app_en.arb:1734`, `app_es.arb:911`, `app_ca.arb:726`.
  - Shown at `voice_task_screen.dart:2168-2169`.
  - Emulator `device/capture.listening.ca.light.1.0.png`.
- **The moment:** "It said I'd see my words… where are they?" After Listo come «Entendiendo…» and then a task card.
- **What happens:**
  - The hint reads «Te escucho. Verás tus palabras al tocar Listo.»
  - On the online path, Listo leads to the result. The words appear only behind «Ver lo que dije».
- **Why it fails:** VO-1 and VO-5: say what comes next, accurately.
- **Fix:**
  - EN "I'm listening. Tap Done to see what I understood."
  - ES «Te escucho. Al tocar Listo verás lo que he entendido.»
  - CA «T'escolto. En tocar Fet veuràs el que he entès.»
  - Modelled at 2×: 2–3 lines. The line has no limit when there are no words.
- **Verify:** catalog test; the emulator's Catalan listening capture.
- **Evidence:** verified in code and an emulator capture.

### Keep
- **Every way in lands in the same place.** The button, the widget (warm and cold), both shortcuts, sharing and «Sin guardar» all reach the one sheet or the form, and the emulator confirms each.
- **On-device listening never ends on a pause.** «Sigo escuchando» and the 50 s countdown say what's happening, the cap acts as Listo, and leaving the app pauses with the words kept.
- **The microphone permission is handled well.**
  - The reason shows under Android's own dialog.
  - A refusal gets a neutral banner.
  - «Abrir Ajustes» names the steps, and listening resumes by itself on return.
- **Failures never lose the words or show server text,** and «Guardar como tarea» works offline.
- **With TalkBack, nothing listens until «Empezar a hablar»,** which has the focus.

### Progress against UX_REVIEW.md (U1–U14)
- **U1 — still open:** a device check. On the emulator, on-device listening ran its full time without stopping, but a real voice is unproven.
- **U2 — regressed:** Cancelar during «Entendiendo…» parks the words without a choice (UX-2102).
- **U3 — holds:** one sheet from every way in. In the idle states a grey microphone looks like a second one (UX-2106).
- **U6 — holds in code:** the recognizer hints on API 33+.
- **U7 — holds, with three problems:**
  - at 8 s the fallback takes the primary slot (UX-2103);
  - the offline line points away from it (UX-2104);
  - it saves without a look (D-A1-1).
- **U8 — holds:** one filled «Añadir tarea» / «Nueva tarea» on Calendar, Tareas, project pages and the timeline.
- **U9 — holds:** no options in the sheet. The first-use privacy line names neither the AI nor its place (UX-2111).
- **U11 — slipped:** «guardada(s)» / "saved" against «Sin guardar» (UX-2105).
- **U12 — holds for capture:** the example sits on Calendar, and the microphone is asked in context with a reason. UX-702 (area B) still cuts the line at 360 dp and 2×.
- **U4, U5, U10, U13, U14:** other areas.

### Questions for the owner
**D-A1-1 · Should «Guardar como tarea» show its one task for a tap before saving?**
- **Today:** «Guardar como tarea» saves the phone's reading at once, unseen, after the 8 s wait, after a failure, and on «No se encontraron tareas». UX_REVIEW §3.5 says "instantly", and D3 approved that section.
- **The conflict:** every other result keeps a confirming tap, which UX-615 kept until the §7 test with your father.
- **Why it matters:** this is the least reliable reading the app makes. It's always one task, so «Mañana, llamar al dentista y comprar pan» becomes one task.
- **Recommendation:** show it as a normal result card, with «Añadir al calendario». That's one more tap on a fallback path, and the person sees the day it read and that it's one task.
- **The other option:** keep it instant, for speed. UX-2103 alone already makes it less likely to be pressed by mistake.

### Ledger notes (device checks seen in the 2026-10-29 emulator captures)
- **UX-1305 — holds:** the reason line shows under Android's dialog in ES, EN and CA.
- **UX-1303:** «Abrir Ajustes» lands on «Información de la app». The banner's «Permisos › Micrófono › Permitir» matches Android 16's page names (`permission-mic.open-settings-landing`).
- **UX-109:** with TalkBack, the focus lands on «Empezar a hablar» when the sheet opens (`talkback.capture-sheet`). The speech itself still needs a phone; see UX-2107.
- **UX-1316, UX-1656, UX-1658:**
  - The shortcuts read whole at 2.0 on 360 dp («Dictar», «Escribir»).
  - The widget label is whole in ES, CA and EN.
  - The ES widget captures at 1.0 and 2.0 show swapped label sizes, while the CA ones are in the expected order. That's probably the launcher not yet re-drawing after the scale change: re-capture before reading anything into it.
- **UX-611, UX-424:** a cold widget tap reaches «Escuchando», in 18–24 s on the emulator. The phone timing check stands.
- **UX-1319:** the ES too-long share toast reads whole.
- **SEEN #14 — still reproduces:** `shortcut-text.intended-landing-launcher-flags` lands on Calendar, while real taps open the form. It stays a phone check.

### Cross-slice notes
- **B1:** UX-702 — at 360 dp and 2×, the first-run line is still cut under «Nueva tarea» (`calendar/agenda.first-use-free.es.light.2x.png`).
- **B1:** with «Sin guardar · 1» at 2× on 360 dp, the agenda shows less than one task: «Llamar al médico para p…» (`calendar/agenda.pending-captures.es.light.2x.png`).
- **D:** `homeCaptureInstructions`, shown when the launcher can't pin the widget, says in ES «widget de micrófono… desde el lanzador». It uses neither the widget's name «Dictar una tarea» nor «pantalla de inicio».
- **D:** Voz's privacy paragraph (`capturePrivacy`) runs to over 60 words of jargon («transcripción en directo», «reconocimiento local», «audio guardado»).
- **D and B2:** the reminder sheet's «A tu manera» Google-AI line, from the website review, should use the same words as UX-2111.
- **D (theme):** UX-2108's fix is `app_theme.dart:95-97`, shared by every filled button.
- **D (debug and staging only):** Diagnóstico de captura shows «Mediana 0.18 s» with a decimal point in Spanish.

### Memory notes
- **Two speech paths.** The capture sheet has two paths. On the online (recorder) path, the first amplitude tick, after 120 ms, makes the capture a recording, which hides «Escribir» and «Seguir» (UX-2101). Check every capture change on both paths; Catalan is the online path on the emulator lane.
- **New recurring type: the app speaks into its own input.** TalkBack announcements fire while the microphone is open: «Escuchando» at the start, the countdown at 50 s (UX-2107).
- **Cancelar during «Entendiendo…»** closes silently. A test locks it in: `capture_result_exits_test.dart:362` (UX-2102).
- **«Guardar como tarea» always makes one task** (`localDrafts`) and saves at once. That needs owner question D-A1-1.
- **Settings map (2026-10-29 device capture):**
  - the Ajustes tab: Recordatorios, Idioma, Apariencia, Cuenta, TaskFlow Pro, Otros ajustes;
  - Otros ajustes: Hora y región, Voz, Calendarios del teléfono, «Botón de dictar en la pantalla de inicio» (which pins the widget), Exportar e importar, Licencias, Privacidad, Términos, and the version (Diagnóstico de captura in debug builds).
- **Copy facts:**
  - the first-run line is «Prueba: toca Añadir tarea y di «Mañana, llamar al dentista y comprar pan».»;
  - an empty day says «No hay tareas para este día.»;
  - the English shortcuts are "Dictate a task" / "Type a new task" (UX-1658);
  - kept words are «conservar», saving as a task is «guardar» (UX-2105).
- **Measuring line fits:**
  - the `MessageBanner` text is 250 dp wide on a 360 dp phone (312 − 32 padding − 20 icon − 10 gap), in bodyMedium 14 sp;
  - the privacy line is bodySmall 12 sp, 312 dp wide;
  - the Manrope model matched the renders' line counts exactly.
- **Device-lane caveat:** the widget's label size can look swapped between the 1.0 and 2.0 captures. Compare languages before filing.
- **Filing:** AUDIT's «primary under 56 dp» flag sat in cross-slice notes for three runs; it's now filed as UX-2108. File in your own area when the control is yours.
- **Shortcut icons** are non-adaptive, so the launcher wraps them in a white disc (UX-2112).
