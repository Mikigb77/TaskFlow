## UX verify — run 2026-10-28-app, round 1, area A (P292, P299) — 2026-11-01

**Verdict:** Ship after fixes. UX-2612 is fixed; UX-2112 is right in the resources (device check pending); UX-2110 is fixed for the capture sheet but not where a free account's entry opens the task form. Two small regressions from the change.

Evidence levels: code read at the working tree on HEAD b14d9cc; renders `capture/result.as-written.*` (2026-11-01 12:05, after the code), `capture/result.one-task.es.light.1x`, `capture/sheet.typing.es.light.1x`; `App/build/ux/AUDIT.md` § capture/result · as-written. No device captures exist (`App/build/ux/device/` absent).

### Findings

**UX-2110 · partly fixed**
- Fixed for the capture sheet: `App/lib/main.dart:188-196` acknowledges a `voice`/`text` entry without opening anything when an entry's sheet is still open and `emptyCaptureSheetOnTop` (`App/lib/screens/voice_task_screen.dart:200-207`) says the top route is a `_CaptureSheetRoute` with no words and no result (`_markEmpty`, :2246-2249, set every build at :2263; `_words` rebuilds on every change, :662-664). Shares still open their own (`!shared`). Tests: `capture_sheet_test.dart` group 'P292 · one sheet per double tap' (:3457-3525), widget level.
- Not fixed where the entry opens the task form instead of the sheet: `showCaptureSheet` returns `openTaskForm` for a free account's text entry, and for the widget's voice entry once free dictations are used up (`voice_task_screen.dart:91-103`). `openTaskForm` pushes `/newTask` unawaited and returns at once (`App/lib/widgets/task_form_entry.dart:63-79`), so `_entrySheets` drops straight back to 0, and the top route isn't a `_CaptureSheetRoute` anyway. A double tap on «Escribir una tarea» (free) or on the widget (free, 0 left) still stacks two forms; Back on the top one shows the second: the same "I cancelled it and it's still there". Free accounts are the newcomer's default.
- Fix: in `_openEntries`, also acknowledge a `voice`/`text` entry while the route on top is an entry-opened `/newTask` form with nothing typed (track the form route the entry pushed, or let `openTaskForm` return the route's future so the count holds while it's open). Verify: two TEXT entries 300 ms apart on a free account → one TaskEditor; Back → Calendar.
- Device: emulator double-tap on the widget is still to do.

**UX-2112 · fixed (resources; launcher not seen)**
- `res/drawable-anydpi-v26/capture_shortcut_{voice,text}.xml` are `<adaptive-icon>`s, background `#E3F1EE`, foreground `@drawable/capture_shortcut_*_foreground`.
- The foregrounds are 108 dp vectors, the 24 dp glyph at 2× translated 30: the mic spans x 40-68, y 34-72; the pencil 36-72 both ways, centred on 54. At about 38/72 of the visible mask, in the 32 dp shortcut disc measured before, the glyph reads at about 17 dp (was 5 × 7 dp).
- API 24-25 vectors unchanged in `drawable/`. `CaptureShortcuts.kt:43` keeps `IconCompat.createWithResource`, which hands the launcher the resource, so the adaptive one applies on 8+.
- Not compiled (no SDK) and not rendered on the launcher: needs the emulator check `launcher.shortcuts.es.light.{1.0,2.0}` (no white ring, glyph ≥ 14 dp) and the debug build.

**UX-2612 · fixed**
- `_saveAtOnce`, `CaptureResult.saveAtOnce` and its `initState` branch are gone (no reference left in `App/lib` or `App/test`); `initState` now always `_reveal()`s and `_announce()`s (`voice_task_screen.dart` ~:2852-2858).
- `_saveAsWritten` (:1676-1706) and `_saveResultAsWritten` (:1715-1731) only `_review(written)`; `_attempts++` still ends the running understanding step. The card's key is `(result.id, result.commands.isEmpty)` (:2268-2269), so the command card gives way to the one-task card; `result-save-as-written` shows only on a command card (`asWritten`, :4576-4585), whose commands are non-empty, so the key always changes there.
- Render `capture/result.as-written.es.light.1x`: one card, «Llamar al dentista y comprar pan», «Mañana», «Más opciones», «Añadir al calendario», Cancelar, Volver a decirlo; nothing saved. ES 2× and CA 2× (`Afegeix al calendari`, `Demà`) whole, no clipping; AUDIT shows only the same 0 dp title/date gaps as every result card.
- Tests cover every acceptance line (group 'P299 · Guardar como tarea shows its card', `capture_sheet_test.dart:3529-…`; UX-901 / UX-919 in `voice_command_cards_test.dart` for the command path; UX-499 in `capture_free_dictations_test.dart`). Airplane-mode dictation and TalkBack remain device checks.

### Regressions

**R1A-1 · Severity 2 · Spoken words' card says «Según lo que has escrito»**
- Where: `App/lib/widgets/capture_review_editor.dart:506, :758, :353-369` (`fromYourWords`, `keepAsTyped`); every «Guardar como tarea» card now; render `capture/result.as-written.es.light.1x` (the same card shows «Ver lo que dije»); AUDIT TalkBack line 4 reads «Según lo que has escrito».
- The moment: "I didn't write anything, I spoke — did it hear me?"
- What happens: the phone's reading sets `asTyped`, so the D10 line for typed dates shows under the date. Before this change spoken words read as written were saved at once and this line was seen only when an hour was ambiguous; now it is on every spoken «Guardar como tarea» card, under the date, read by TalkBack. EN “Keep as typed” has the same problem.
- Why: Nielsen #2, match with the real world; PL plain language (one concept, one name).
- Fix: word the line for both: ES «Según tus palabras», CA «Segons les teves paraules», EN keeps “From your words”; EN `keepAsTyped` → “Keep my words”, ES «Dejar como está» and CA «Deixa-ho com està» unchanged. No new key. (Or, if the owner prefers, a spoken variant «Según lo que has dicho» / «Segons el que has dit», which adds strings.)
- Verify: re-render `capture/result.as-written` (es 1×, ca 2×); the AUDIT TalkBack list no longer says «escrito»; the typed-date test of UX-204 still passes with the new copy.
- Evidence: seen in a current render and AUDIT.

**R1A-2 · Severity 2 · A voice tap is swallowed by an empty typing sheet**
- Where: `App/lib/main.dart:188-196` with `emptyCaptureSheetOnTop` (`voice_task_screen.dart:200-207`); typing sheet `capture/sheet.typing.es.light.1x` (field, Listo, Cancelar; no mic: `waiting` needs `!_typing`, :2339).
- The moment: (Pro, opened «Escribir una tarea», got interrupted, later taps the widget's mic) "I pressed the microphone and it gives me the keyboard."
- What happens: the VOICE entry is acknowledged because the open entry sheet is empty; the typing sheet stays, and it has no way to start speaking. Before, a voice sheet opened over it.
- Why: gulf of execution (Norman 2013); the entry no longer does what its label says.
- Fix: acknowledge a VOICE entry only when the empty sheet on top is a voice sheet (not typing); a TEXT entry may still be absorbed by any empty sheet, since the voice sheet offers «Escribir». E.g. `emptyCaptureSheetOnTop(navigator, voice: true)` checks the route's typing state too.
- Verify: widget test, Pro: a TEXT entry opens the typing sheet, then a VOICE entry → a listening sheet (one sheet showing listening), not the keyboard.
- Evidence: verified in code; render of the typing sheet.

### Not regressions, noted
- A VOICE entry onto an empty voice sheet that is idle or paused leaves it showing «Empezar a hablar» rather than starting to listen: one more tap, and as the brief asked.
