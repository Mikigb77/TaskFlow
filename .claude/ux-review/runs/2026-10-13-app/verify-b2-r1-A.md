## UX verify — 2026-10-13-app, b2 round 1, area A (P3, P35) — 2026-10-13

**Verdict:** All six findings are fixed on the app side. Two small regressions came with the sheet, plus one polish item. The device checks (recognition rate, real TalkBack speech) are still open.

Evidence levels: code read in full (`voice_task_screen.dart`, entry diffs, P3 diffs), the current render `App/build/capture-listening-es-2x.png` (19:42, newer than the code at 18:35), and ux-tester's passing tests. I didn't run Flutter.

### Results

- **U6 (app side): fixed.** Needs a phone for the recognition rate.
  - **Biasing on Android 13+ only.** `NativeSpeechBridge.kt:216` adds `EXTRA_BIASING_STRINGS` inside the `SDK_INT >= 33` branch of the inner `begin()`. Every attempt goes through it, restarts included. The list comes in through `start` at `:102`, and nothing is added below 33.
  - **The hint list.** `native_speech.dart:134` `speechHints()` holds:
    - the intl weekday, month and AM/PM symbols for the speech locale;
    - day and time words in es, ca and en;
    - active project names, then their people (name and voiceName);
    - at most 100 items of 40 characters or fewer.
  - **Sent while listening.** `voice_task_screen.dart:607` sends the list on every listening start.
  - **Speech or typed source.**
    - `capture_processor.dart:90` sends `speech` for audio, otherwise the stored source, otherwise `typed`.
    - The first words set the source: `voice_task_screen.dart:425-436` for the recognizer or the keyboard, `:617`/`:626` for recorded audio, and `capture_store.dart:100` for shares.
    - The source is stored in the JSON `data` and survives restore (`capture_store.dart:302`).
  - **The server accepts it.** `Backend/core/serializers.py:281` `DraftRequestSerializer` is a plain DRF Serializer, which ignores unknown fields, so no 400.
  - **Still open, server side.** The speech-only repair instruction in `Backend/core/ai.py` stays in the ledger.
- **U3: fixed.**
  - `showCaptureSheet` (`voice_task_screen.dart:35`) is the only entry. Every way in calls it:
    - `task_actions.dart` (the creation button);
    - `notes_screen.dart:154` (`kind: 'note'`);
    - `captures_screen.dart:58` (`startListening: false`);
    - `main.dart:175` (widget, shortcut and share).
  - The `/voiceTask` route is gone, and no `VoiceTaskScreen(` is constructed outside the sheet.
  - The mic is a non-tappable `ExcludeSemantics` ring (`:1157`). The controls are Cancelar, Listo and the keyboard icon (`:1188-1250`).
  - No headline, chips, speech options or privacy text remain.
- **U2: fixed.**
  - `Listo` → `_done` (`:846`) always stops and processes. It's disabled when `!_hasInput` (`:1037`).
  - Cancel, Back and a swipe down all go through `PopScope` → `_cancel` (`:864`, `:1090`, `_SheetFrame` `maybePop` at `:115`). With nothing said the sheet closes. Otherwise one dialog asks `¿Conservar lo que has dicho?`, with `Conservar` as the FilledButton and `Descartar` as an error-coloured TextButton (`:874-893`).
  - The scrim is held while listening, starting or processing (`:990`, `_CaptureSheetRoute.barrierDismissible`).
- **UX-105: fixed** (seen in the render).
  - At 360×740 and 2×, the render shows the status line, the newest words ending "…por la noche", the ring, the full-width `Listo`, `Cancelar` and the keyboard icon.
  - The words are `headlineSmall` (the largest text), in a `SingleChildScrollView(reverse: true)` (`:1108`).
- **UX-109: fixed in code.** Needs a phone for real TalkBack speech.
  - `_autoStart` is false under `accessibleNavigation` (`:326`). An autofocused `Empezar a hablar` FilledButton shows instead (`:1024-1029`).
  - `captureListening` is announced at `:516` and `done` at `:732`.
  - The old mic keys are gone from code and catalogs.
  - The creation button's Tooltip is removed (task_actions diff).
  - The keyboard button has one label, used for both tooltip and semantics (`:1201`).
- **UX-126: fixed.**
  - There is no discard button, and `discardCapture`, `discardCaptureQuestion` and `captureDiscardHelp` are gone from the code and the catalogs.
  - Discarding now lives only in Cancel's question, as the non-filled option.
  - grep finds no `Icons.notes_rounded` in `voice_task_screen.dart`.

Untested but present in code: the 5 s silence line (`:1005-1011`) and the `En pausa` + `Seguir` state (`:1002`, `:1017-1034`).

### Regressions

**R1A-1 · Severity 2 · "Seguir" shows on shared and resumed text that was never listening**
- **Where:** `voice_task_screen.dart:1017-1022`. `canContinue` uses `resting`, which includes `idle`, not just `paused`.
- **The moment:** a newcomer shares a WhatsApp message to TaskFlow, or taps a pending capture ("Toca para continuar"). They see their text, a grey mic, `Seguir` and `Listo`, with no status line, because `idle` maps to `null` at `:1003`. They think "Seguir means go on", tap it, and the mic starts ("Escuchando · 00:00") when they only wanted to proceed.
- **Why it fails:** in everyday Spanish, "Seguir" and "Listo" both mean "proceed". The pair breaks the "one meaning for finished" rule U2 set up (Norman's gulf of execution; Nielsen, match with the real world). The brief scoped `Seguir` to the paused state only.
- **Fix:** show `Seguir` only when `phase == paused`, or when the phase is idle and `_session?.source == 'speech'` (a resumed voice capture). Typed and shared text then shows only `Listo` and `Cancelar`, plus the keyboard.
- **Verify:** a widget test opens the sheet for a shared-text entry (`acceptEntry` with text, `startListening: false`) and expects no `Seguir`. A paused voice capture still shows it.

**R1A-2 · Severity 2 · TalkBack says "Listo" when the user cancels or types**
- **Where:** `voice_task_screen.dart:732`. `_stopRecording` announces `l10n.done` on every stop: Cancelar (`:872`), Escribir (`:858`), leaving the app and audio interruptions.
- **The moment:** a TalkBack user taps Cancelar and hears "Listo", the name of the button that sends. They think "did it just save?" Then the keep-or-discard question arrives.
- **Why it fails:** the announcement contradicts the action (Nielsen, visibility of system status). It is also the label of a different control.
- **Fix:**
  - Announce `done` only when `submit` is true.
  - For interrupted stops, announce `capturePaused` (EN `Paused` / ES `En pausa` / CA `En pausa`).
  - For Escribir, announce nothing, because focus moves to the field.
- **Verify:** extend the UX-109 widget test. Cancel with words should capture no `Listo` announcement, and `Listo` should capture one.

**R1A-3 · Severity 1 · English silence line truncates at 2×**
- **Where:** `voice_task_screen.dart:1125-1136`, which uses `maxLines: 2` with an ellipsis.
- **What happens:** I modelled Manrope at 28 px across 312 dp. EN `Still listening — tap Done when you’re finished.` needs 3 lines and is cut after "you’re". ES and CA fit in 2.
- **Fix:** shorten the EN copy to `Still listening. Tap Done when finished.`, or allow 3 lines.
- **Evidence:** text-width model only, not a render.

### Not regressions, noted
- Back or Cancel during "Preparando tu plan…" closes the sheet without asking. The page before this change behaved the same (it had no PopScope). The capture stays pending.
- The ⌨ keyboard button is icon-only and sits in the bottom-right corner. That matches the approved design in UX_REVIEW §3.1 (D3), so I'm not reporting it.
- After typing, the question still says "lo que has dicho" ("what you said"). That is the brief's exact copy. It is understandable, so I'm not reporting it.
