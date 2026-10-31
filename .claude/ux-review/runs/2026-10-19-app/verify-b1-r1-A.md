## UX verify — run 2026-10-19-app, round 1, area A (P166, P167, P168) — 2026-10-20

**Verdict:** 9 fixed, 1 partly (UX-1308: results made only of voice commands still arrive without an announcement). Two new severity-1 problems, both caused by this change.
**Evidence:** code (`git diff HEAD`), renders from 06:09–06:14 today (newer than `voice_task_screen.dart` 05:12, `capture_review_editor.dart` 04:15 and `app_es.arb` 05:02), AUDIT.md, and the tester's widget tests. No device or emulator evidence.

### Results

| ID | Result | Evidence |
|---|---|---|
| UX-107 | fixed | `voice_task_screen.dart` `_startRecording`: `_speech.permission()` is asked on both paths (the `_recorder!.hasPermission()` branch is gone), so a blocked microphone sets `_micBlocked` on the online path too. Tests: native_speech_test UX-107 / UX-1303 (online and on-device, Settings → resume → listens). Device: re-capture `permission-mic.blocked.ca`. |
| UX-1303 | fixed | `settingsFirst = waiting && _micBlocked`: one autofocus FilledButton `capture-open-settings`, with no «Empezar a hablar»; the banner is neutral, keeps the mic-off icon and is a live region. Renders `sheet.mic-blocked{,-online}.es.light.1x` and `.ca.light.2x`: neutral green banner, whole text, «Abrir Ajustes» / «Obre Configuració» full width. AUDIT: «Abrir Ajustes» [focused] comes right after the banner. Device: TalkBack's first focus. |
| UX-1305 | fixed | `_askingMic` puts `captureMicrophoneWhy` in place of Listo while the status read says the microphone isn't granted and the bridge hasn't answered (render `sheet.mic-asking.es.light.2x`). A refusal now sets `CaptureProblem.microphone` with a neutral banner and the mic-off icon (render `sheet.mic-denied.es.light.2x`), and «Empezar a hablar» and Escribir both show. The copy matches the brief in EN, ES and CA; «escribe abajo» is gone. Device: the line under Android's real dialog. See R1A-2. |
| UX-1306 | fixed | When the on-device run fails before it's ready (an error event, or `start` throwing anything other than a microphone problem), `_goOnline()` switches the sheet to online and remembers that for the session (`_speech.remember`), then `_startRecording` runs again with no message. If both fail, there's one line: `captureCantListen`. `captureSpeechLanguage` and `captureSpeechUnavailable` are gone from all three ARB files; `capture_messages.dart` maps both problems to `captureCantListen`. Device: an Android 12 phone in Catalan. |
| UX-1301 | fixed | `_nothingFound`: a filled «Volver a decirlo» (`_sayAgainAfterNothing` discards the capture, clears the words and listens, but with TalkBack on it waits for «Empezar a hablar»); «Guardar como tarea» is a TextButton; no «Reintentar». With no dictations left, Escribir is the filled button (`typeFirst`); typed words keep Listo. Renders `sheet.error-nothing-understood.es.light.1x` and `.ca.light.2x` show the new copy and buttons. The banner keeps the red error style, which the brief didn't ask to change (question below). |
| UX-1304 | fixed | Hint chain: `captureTimeLeft(60 - _seconds)` from 50 s, announced once at tick 50; online, `captureListeningOnline`; on the device's own speech, `captureNothingHeardYet` while no words have come, else `captureStillListening`. `_timeUp()` shows `captureNoSpeech` on the on-device path when nothing was heard, without announcing Listo. Renders `sheet.listening-quiet.es.light.2x` («Aún no he oído nada…») and `sheet.listening-time-left.es.light.2x` («Quedan 9 segundos» at 00:51). |
| UX-1322 | fixed | `_ring` draws the microphone only when `phase != processing`. Render `sheet.understanding.es.light.1x`: the spinner alone. |
| UX-1302 | fixed | `_reveal()` uses `Scrollable.ensureVisible(QuestionBox or card, alignment: 1)`, with `Duration.zero` when animations are off; it runs again after each answer (`_revealAfter`). «Ver lo que dije» is now the last item in the scroll, and the footer holds only the filled button and the exits. Renders `result.question.{es,ca}.light.2x`: 05:00, 17:00 and Sin hora are all above the footer. `commands/cards.mixed.es.light.2x`: the deletion card is in view. |
| UX-1312 | fixed | `capture_review_editor.dart`: `dense` and the compact density are removed, and the chevron shows on every card. Render `result.several.es.light.1x` shows a chevron on each day line. AUDIT `capture/result · several` lists no target under 48 dp (only 0 dp gaps, which are P171's). |
| UX-1308 | partly | `_announce()` after the first frame: one task → «title, date line» from `taskDayLine`; several tasks or new projects → `captureThingsToAdd`; with a question open, its text is added at the end. Tests pass. Still silent: a result made of a single change or delete card, or a mixed one (`adding` is false, so it returns without announcing). Those are the same "Listo… then silence" moment. Fix, with no new strings: for one command, announce the card's headline as shown (for example «Se eliminará: Dentista (dom, 25 de oct)»); for a mixed result, announce the filled button's label («Añadir, cambiar y eliminar»). |

### Regressions (caused by this change)

**R1A-1 · Severity 1 · «Ver lo que dije» looks like a second task option**
- Where: `voice_task_screen.dart`, CaptureResult cards (the ExpansionTile moved to the end of the scroll); render `capture/result.one-task.es.light.1x.png`.
- What happens: on a one-task result, «Ver lo que dije» now sits 1 dp under «Más opciones» (AUDIT `capture/result · one-task`). They are identical full-width expansion rows with a leading icon and a chevron. «Más opciones» belongs to the task; the words don't. A newcomer reads them as two options of the same task.
- Why: Gestalt proximity and similarity; lens D (two different actions never look alike side by side).
- Fix: P171 adds 8 dp above it. Also make it visibly secondary and outside the card: bodySmall in onSurfaceVariant, and 16 dp above it instead of 8, or a thin divider. Its label stays.
- Evidence: seen in a current render.

**R1A-2 · Severity 1 · Reason line can flash before the blocked banner**
- Where: `voice_task_screen.dart` `_startRecording` (`_microphoneGranted()` is read alongside `_speech.permission()`); `NativeSpeechBridge.kt:85-94` and `:348-358`.
- What happens: when the microphone is blocked, `requestPermissions` shows no dialog but still answers through the activity callback. The status read can win that race, so «Permite el micrófono para dictar tus tareas…» may show briefly in place of Listo — with no question on screen — before the blocked banner replaces it. This can happen each time the sheet opens by itself.
- Fix: set `_askingMic` only after a short grace period (for example 300 ms) with the request still unanswered, or only when `Permission.microphone.status` is denied and `shouldShowRequestRationale` is false... Simplest: delay showing the line by 300 ms; a real dialog stays up far longer than that.
- Evidence: inferred from code; needs an emulator check (`permission-mic.blocked`, watching the frames that come before it).

### Notes (not regressions)
- At 2× the reveal scrolls the result so the task title's first line is cut in half under the drag handle (`result.question.es.light.2x`: «Recoger el» is cut, «coche del taller» shows). That's the cost of bringing the answers into view. Acceptable, but a top-edge fade would make it read as "more above".
- The copy now names «Escribir» in three lines (`captureMicrophone`, `captureNothingHeardYet`, `captureCantListen`). Pro accounts still see an unlabelled keyboard icon (AUDIT: `button (no label) tooltip «Escribir»`). P171 / UX-1310 labels it; until then, those lines name a button the user can't see written.
- The «nothing found» banner keeps the red error style (`isError`). That isn't a regression, but it presents a normal miss as a fault (Budiu & Laubheimer 2018: uncertainty as a question, never as an error). It's a candidate for the neutral style, as with the microphone banners.

### Device checks still owed
`permission-mic.blocked.ca` / `dialog.es` (1.0 and 2.0) / `denied.es` re-captures; whether «Permisos › Micrófono › Permitir» matches App info on Android 13–15; Android 12 in Catalan going online; TalkBack: first focus on «Abrir Ajustes», the countdown spoken once, the result spoken once after Listo; the real model with «Hola, ¿me oyes?»; the largest font on a 360 dp phone.
