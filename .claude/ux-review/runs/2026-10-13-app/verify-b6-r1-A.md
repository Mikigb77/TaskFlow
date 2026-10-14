## UX verify — run 2026-10-13-app, round 1, area A (P20, P34) — 2026-10-14

**Verdict:** Ship after fixes. All six findings land in code. One part of U9 is only partly done: the first-capture privacy note is the old four-sentence paragraph instead of "a small line". There are three new minor problems on the new Voz screen and the share toast.

Evidence: I read `git diff HEAD` for every listed file, the new files in full, and the render `App/build/capture-listening-es-2x.png` (10-14 10:28, newer than `voice_task_screen.dart` at 09:56). The Voz screen has no render, so I judged it from the widget code. I didn't run Flutter.

### Findings

| ID | Result | Evidence |
|---|---|---|
| UX-121 | fixed (needs a phone) | The widget description is now `Tap to say a task.` / `Toca para dictar una tarea.` / `Toca per dictar una tasca.` in `res/values*/strings.xml:4`. ES `capture_voice` reads `Dictar una tarea`, which pairs with `Escribir una tarea`. The widget label and preview use `@string/capture_voice` (`AndroidManifest.xml:59`, `layout/capture_widget.xml:4,7`). The sheet's stop control reads `Listo` in the render. |
| UX-119 | fixed (needs a phone) | `CaptureEntryBridge.kt:66,71,82` uses `R.string.share_too_long`, `share_queue_full` and `share_not_saved`. All three strings exist in EN, ES and CA with the agreed copy. There's no hard-coded text left. See R1A-4 for the empty-share case. |
| UX-125 | fixed (needs a phone) | `capture_shortcuts.xml:2,6` points at `capture_shortcut_voice` and `capture_shortcut_text`. These are valid 48 dp vectors: a Material mic glyph and an edit glyph in #167568 on a #E3F1EE circle (about 5:1 contrast). How the launcher masks a non-adaptive icon needs a phone. |
| UX-420 | fixed (needs an iOS build) | `Info.plist:8` and line 1 of all three `InfoPlist.strings` carry the new text. `NSLocalNetworkUsageDescription` is unchanged, as planned. |
| U9 | partly | Done: the capture code has no `holdTalk`, `_chooseKind`, `speechOptions`, `nativeSpeechHelp`, `guestTrialHelp` or `returnCaptureHelp` (grep of `App/lib`). The Voz row is in Otros ajustes (`other_settings_screen.dart:49-55`, subtitle is the language), and the Voz screen exists (`voice_settings_screen.dart`). The privacy note shows only on the first microphone use (`voice_task_screen.dart:702-712`, `:772`). Not done: the in-sheet note is the whole `capturePrivacy` paragraph (4 sentences, about 60 Spanish words), not "a small line under the words". In the 2× render it fills about a third of the words area, is cut off mid-line, and appears while the user is speaking. Fix in R1A-1. |
| UX-115 | fixed (on-device path; a Catalan speaker needs a phone) | `_load` builds `_speechLanguage` from the Voz choice or the app locale (`voice_task_screen.dart:438-446`) and passes it to `capability` and `start` (`:812-814`), so Kotlin's `Locale.getDefault()` fallback (`NativeSpeechBridge.kt:84,101`) never applies. The choice is stored in `RegionalPreferences.speechLanguage` and survives a restart (`regional_provider.dart` toJson/fromJson). The help line with the raw code is gone. The online-audio path is a separate gap: R1A-3. |

### Regressions (only in the changed files and their flows)

**R1A-1 · Severity 2 · The first-capture privacy note is a jargon paragraph that interrupts dictation**
- Where: `App/lib/screens/voice_task_screen.dart:1669-1681` (Flexible + SingleChildScrollView showing `l10n.capturePrivacy`) and `:1648` (`flex: 2` on the words). Copy: `app_es.arb:304` (`capturePrivacy`). Seen in `App/build/capture-listening-es-2x.png`.
- The moment: "I'm talking and a whole paragraph appears… 'envía tus palabras a Google', 'capturas pendientes'… Did I do something wrong? It's cut off — is there more?"
- What happens: on the first capture, 4 sentences of internal terms appear under the live words: reconocimiento local, extracción de tareas con IA, audio guardado, capturas pendientes. At 2× the note takes about a third of the words area, its last visible line is sliced in half, and it scrolls on its own. The words get less room (flex 2:1).
- Why it fails: no paragraphs on action screens (Nielsen 1997; Moran 2016). Internal terms on the default path (ISO 24495-1). It competes with the live words while the user speaks (Sweller 1988). The plan asked for "a small line".
- Fix: add a one-sentence key for the sheet and keep `capturePrivacy` for Voz only:
  - EN `TaskFlow sends your words online to turn them into tasks. More in Settings.`
  - ES `TaskFlow envía tus palabras por internet para convertirlas en tareas. Más en Ajustes.`
  - CA `TaskFlow envia les teves paraules per internet per convertir-les en tasques. Més a Configuració.`
  
  Then remove the note's Flexible/SingleChildScrollView wrapper (a plain `Text`, `bodySmall`, maxLines 2) and the `flex: 2` on the words.
- Verify: re-render `capture-listening-es-2x.png`. The note is one or two full lines and none is cut. The widget test still shows the note on the first capture only.
- Evidence: verified in code and in the current render.

**R1A-2 · Severity 2 · Voz shows capture-screen instructions and an unlabelled technical choice**
- Where: `App/lib/screens/voice_settings_screen.dart:133-167` and `:186-190`. Strings: `onDeviceTranscript`, `onlineAudio`, `onDeviceUnavailable`, `captureSetupRequested` (`app_es.arb:293,297,907`).
- The moment: "Two options with no title: 'Transcripción en directo en el dispositivo' or 'Audio guardado · transcripción en línea' — which one is for me? And it says 'Graba audio… o escribe', but where do I record or type here?"
- What happens: the second radio group has no heading, while the first has `Idioma de voz`. The option labels are technical. `onDeviceUnavailable` tells the user to "record audio … or type", which only makes sense on the capture sheet. After `Configurar la transcripción local`, the banner ends "Mientras tanto, puedes seguir escribiendo", but there's nothing to type on Voz. `captureSetupRequested` is still used by the capture sheet (`capture_messages.dart:33`), so it can't just be reworded.
- Why it fails: plain language and the user's own words (Nielsen heuristic 2; ISO 24495-1). Grouping with a visible label (Gestalt common region). Copy has to match the context it appears in.
- Fix: add a heading above the second group: EN `How speech becomes text` / ES `Cómo se pasa la voz a texto` / CA `Com es passa la veu a text`. Rename the options to the outcome: EN `On this phone, as you speak` / `Online, after you finish`; ES `En el teléfono, mientras hablas` / `En línea, al terminar`; CA `Al telèfon, mentre parles` / `En línia, en acabar`. Add Voz-only keys:
  - unavailable: EN `This phone can’t do this language by itself, so TaskFlow does it online.` / ES `Este teléfono no puede con este idioma por sí solo, así que TaskFlow lo hace en línea.` / CA `Aquest telèfon no pot amb aquest idioma tot sol, així que TaskFlow ho fa en línia.`
  - set-up requested: EN `Follow Android’s steps, then tap Check again.` / ES `Sigue los pasos de Android y luego pulsa Comprobar de nuevo.` / CA `Segueix els passos d’Android i després toca Torna a comprovar-ho.`
  
  Remove `onDeviceTranscript` and `onlineAudio` if nothing else uses them (only Voz does).
- Verify: widget test on Voz in ES. The heading text exists, and no Voz string contains `escribe` or `Graba`. 2× at 320 dp still fits.
- Evidence: verified in code; no render of Voz.

**R1A-3 · Severity 2 · The Voz language doesn't reach online transcription**
- Where: `App/lib/services/capture_processor.dart:151-160`: the `ai/drafts/` request sends no language. Voz shows `Idioma de voz` regardless of the chosen way (`voice_settings_screen.dart:106-131`).
- The moment: "I set Català, but it wrote my words in Spanish."
- What happens: whenever the online way is used, the speech-language choice is never sent. Online is used either because the user picked it, or because on-device speech is unavailable for the language, which `onDeviceUnavailable` suggests is common for Catalan. Which language the audio is transcribed in is then decided elsewhere.
- Why it fails: a setting that has no visible effect breaks the user's model of the app (Norman 2013, gulf of evaluation). Consistency.
- Fix: send the recognizer tag (`_speechLanguage`, e.g. `ca-ES`) with the capture and the audio, and have transcription use it. Cause likely server-side for the use. If that isn't possible, hide `Idioma de voz` while the online way is selected.
- Verify: unit test that the drafts request carries `language`. Device check: Catalan online audio comes back in Catalan.
- Evidence: verified in code that no language is sent; the transcription behaviour is inferred.

**R1A-4 · Severity 1 · An empty share says "Share a shorter text"**
- Where: `CaptureEntryBridge.kt:65-66`. One string, `share_too_long`, covers both `text.isEmpty()` and `> 4000`.
- What happens: a `text/plain` share that arrives with no text shows `TaskFlow admite hasta 4000 caracteres. Comparte un texto más corto.` The old copy, "between 1 and 4,000", covered both cases.
- Fix: add a separate `share_empty`, shown when the text is empty: EN `There’s no text to add. Share some text with TaskFlow.` / ES `No hay texto que añadir. Comparte un texto con TaskFlow.` / CA `No hi ha cap text per afegir. Comparteix un text amb TaskFlow.`
- Verify: `native_resources_test` checks for `share_empty` in all three languages, and that the bridge uses it in the `isEmpty` branch.
- Evidence: verified in code.

### Notes (not regressions)
- `captureSpeechLanguage` (`app_es.arb:898`) still says "Elige otro idioma". That choice now lives in Ajustes › Otros ajustes › Voz, and the message doesn't say so. This was already true at HEAD (P35 removed the menu), and the pre-check in `_load` makes the message rare.
- ES `capture_voice` was changed "to match the in-app button", but the in-app button is now `Añadir tarea` (U8). The shortcut and the widget still agree with each other, so this is fine.
