## UX verify — run 2026-10-13-app, round 2, area A (P81, P82, P84) — 2026-10-14

**Verdict:** Ship after fixes. The privacy paragraph has left the sheet, Voz now reads in plain words, the app sends the speech language, and an empty share has its own message. Two gaps remain:
- At 2× text in Spanish, the new privacy line ends in "…" before its point.
- One Voz message still tells the user to "use saved audio or type".

The Catalan transcription outcome needs the server half.

Evidence:
- I read `git diff HEAD` for every listed file, and `voice_settings_screen.dart` in full (it is untracked).
- I read the render `App/build/capture-listening-es-2x.png` (10-14 11:11). It is newer than `voice_task_screen.dart` (10:43).
- Voz has no render, so I judged it from the widget code.
- I didn't run Flutter.

### Findings

| ID | Result | Evidence |
|---|---|---|
| U9 | fixed (needs a phone) | **Sheet:** the line is a single `Text(l10n.capturePrivacyLine)` in `bodySmall`, `onSurfaceVariant`, maxLines 2, under the words (`voice_task_screen.dart:1674-1688`, key `capture-privacy`). `flex: 2` is gone from the words, which are a plain `Flexible` again (`:1655`). It still shows on the first microphone use only (`_showPrivacyOnce`, `:708-720`, called at `:780`). **Voz:** keeps the full `capturePrivacy` paragraph (`voice_settings_screen.dart:196-204`). The copy-length gap at 2× is tracked under UX-491. |
| UX-491 | partly | **Done:** in the render the note is two whole lines; nothing is sliced, and the newest words keep the full area. **Not done:** at 2× in Spanish, line 2 reads `palabras por internet para…`. The newcomer — Spanish at large text, the bar — never sees `convertirlas en tareas. Más en Ajustes.` That is the line's reason, and the only pointer to where the details live. The line shows once per device, so there is no second chance. TalkBack reads the full string, so this affects sighted users only. **Fix:** shorten the copy so it fits two lines at 2× on 360 dp: EN `Your words go online. More in Settings.` / ES `Tus palabras van por internet. Más en Ajustes.` / CA `Les paraules van per internet. Més a Configuració.` **Verify:** a widget test at 2× on 360×740 in ES and CA asserts that the line doesn't exceed its max lines. If CA still overflows, allow 3 lines instead of the ellipsis. |
| UX-492 | partly | **Done:** the heading `speechMethod` sits above the second group in the same style as `Idioma de voz` (`voice_settings_screen.dart:133-136`). The options read `En el teléfono, mientras hablas` / `En línea, al terminar`. `onDeviceUnavailable` is reworded. `voiceSetupRequested` replaces `captureSetupRequested` on Voz (`:77`), and `captureSetupRequested` is still used by `capture_messages.dart:33`. **Not done:** when Android can't open speech setup, Voz still shows `captureSetupUnavailable` (`:78`): ES `…no está disponible aquí. Usa audio guardado o escribe.` / EN `…Use saved audio or type.` / CA `…Utilitza àudio desat o escriu.` Voz has nothing to record or type, and the finding's check says no Voz text contains `escribe`. The test's fake `prepareLanguage` always returns true (`voice_settings_test.dart:790`), so this branch is never exercised. **Fix:** add a Voz-only key `voiceSetupUnavailable`, used at `:78`: EN `This phone can’t set this up, so TaskFlow does it online.` / ES `Este teléfono no puede configurarlo, así que TaskFlow lo hace en línea.` / CA `Aquest telèfon no ho pot configurar, així que TaskFlow ho fa en línia.` Leave `captureSetupUnavailable` for the capture sheet (`capture_messages.dart:34`). **Verify:** a widget test with `prepareLanguage` returning false shows the new copy, with no `escribe` and no `audio guardado`. |
| UX-493 | partly (app half done; server half open; needs a phone) | **App half:** `CaptureSession.language` is in the constructor, `copyWith`, `toJson` (only when non-null) and `fromJson` (`capture_session.dart:170-264`). `CaptureStore.create` takes `language`, and the update at `capture_store.dart:344` keeps it. The sheet passes `_spokenLanguage(...)` only for audio or `source == 'speech'` (`voice_task_screen.dart:550, :561-564`), and for the audio switch at `:843`. Typed captures and shares send none. `ai/drafts/` adds `language` when it is set (`capture_processor.dart:160`). **Server half:** `Backend/core/serializers.py` and `Backend/core/ai.py` transcribe don't use it yet, so a Català speaker on `En línia, en acabar` can still get Spanish words. Cause: server-side. |
| UX-494 | fixed (needs a phone) | `CaptureEntryBridge.kt:65-72`: an empty share shows `R.string.share_empty`, and only text over 4,000 characters shows `share_too_long`. Both return. `share_empty` carries the agreed copy in `values`, `values-es` and `values-ca` (`strings.xml:5`), with a typographic apostrophe, so no escape is needed. |

### Regressions (only in the changed files and their flows)

None caused by this round. Two notes that are not regressions:
- **The privacy line stays for the whole first capture.** It still shows in typing, processing and error states, and can stack with the 2-line hint under it. This is consistent with "for this capture", and minor.
- **`share_too_long` writes the number differently by language.** ES writes `4000` and CA writes `4.000`. Both are correct for their language (RAE doesn't group four-digit numbers), and this round didn't change it.

### Memory notes
- **Voz has two Voz-only copy keys.** `voiceSetupRequested`, plus `voiceSetupUnavailable` once UX-491/492 are finished. The `captureSetup*` keys belong to the sheet. Watch for capture-sheet copy that leaks onto settings screens.
- **Recurring:** ellipsised one-off notes at 2× drop the sentence's purpose. When a line is capped, check the copy fits at 2× ES and CA. Don't accept "…" on text that shows only once.
- **Recurring:** test fakes that always succeed (`prepareLanguage` → true) hide the failure branch's copy. Check both branches by reading the code.
