## UX verify — run 2026-10-13-app, b6 round 3, area A (P87) — 2026-10-14

**Verdict:** UX-491 and UX-492 are both fixed. There is one small new regression (R3A-1, severity 1): after a failed set-up, Voz says almost the same sentence twice.
**Evidence used:** code (`git diff HEAD`, grep), the ux-tester's tests, and the render `App/build/capture-listening-es-2x.png`. The render (11:32) is newer than voice_task_screen.dart (11:18) and app_es.arb (11:17). I didn't run Flutter.

### UX-491 · fixed (on a phone: still needs checking)
- Copy: `capturePrivacyLine` now reads EN `Your words go online. More in Settings.`, ES `Tus palabras van por internet. Más en Ajustes.` and CA `Les paraules van per internet. Més a Configuració.`. Each ends with its catalog's `settings` word (ES `Ajustes` at app_es.arb:134, CA `Configuració` at app_ca.arb:113).
- Widget: `App/lib/screens/voice_task_screen.dart:1677-1689`. The note keeps its key `capture-privacy`, its bodySmall / onSurfaceVariant style and the ellipsis, and it still sits under the words. `maxLines` is 3, which the brief allows; the code comment says Catalan at 2× text needs three lines. When it shows (`_showPrivacyOnce`, :708-720) hasn't changed.
- Render: `capture-listening-es-2x.png` shows "Tus palabras van por / internet. Más en Ajustes." — two whole lines, no "…". The newest words ("…sábado por la noche") are visible above it, and Listo is still the dominant button. 10 words → 7 in Spanish.
- Tests: `App/test/voice_settings_test.dart:939-1012`. They measure with the real Manrope font: `didExceedMaxLines` is false in ES and CA. The earlier test that the newest words stay in view (:411) still passes.
- Still needs a phone: a fresh install in Spanish at large text.

### UX-492 · fixed
- `App/lib/screens/voice_settings_screen.dart:66-80`: when Android's set-up can't open (it returns false or throws), Voz now shows `voiceSetupUnavailable`. EN `This phone can’t set this up, so TaskFlow does it online.` uses the typographic apostrophe; ES and CA match the brief.
- `captureSetupUnavailable` is now used only at `App/lib/l10n/capture_messages.dart:34`. `capturePrivacy` is used only at voice_settings_screen.dart:199. Nothing on Voz tells the user to record or type any more.
- Tests: `App/test/voice_settings_test.dart:736-835` cover returns-false, throws, opens (`voiceSetupRequested` still shows) and Catalan at 2× text on 320×640 with no overflow.
- The word check skips the `capturePrivacy` paragraph, and that's justified. The paragraph says "El audio guardado se transcribe en línea" ("saved audio is transcribed online"), which describes how audio is handled; it doesn't tell the user to do anything. P87 left it untouched on purpose.

### Regressions
**R3A-1 · Severity 1 · After a failed set-up, Voz repeats itself**
- Where: `App/lib/screens/voice_settings_screen.dart:162-190`, Voz, when on-device speech exists but lacks the language (`onDevice && !usable`) and set-up fails.
- The moment: "It just told me that — did my tap do anything?"
- What happens: when `usable == false`, the grey line `onDeviceUnavailable` is already showing: "Este teléfono no puede con este idioma por sí solo, así que TaskFlow lo hace en línea." ("This phone can't handle this language by itself, so TaskFlow does it online."). Tapping `Configurar la transcripción local` then adds a banner two rows below it: "Este teléfono no puede configurarlo, así que TaskFlow lo hace en línea." ("This phone can't set it up, so TaskFlow does it online."). Both sentences end the same way. The `Configurar…` button stays live, so a second tap only repeats the banner.
- Why it fails: minimalist design and one message per fact (Nielsen's heuristics). Repeated notices stop being read (banner blindness, Benway & Lane 1998).
- Fix: once set-up has failed, hide the set-up row (`Configurar…` and `Comprobar de nuevo`) and the `onDeviceUnavailable` line, and keep only the banner. That removes 2 buttons and 1 sentence. Copy stays as it is.
- Verify: widget test. On Voz (ES), with `prepares = false`, tap Configurar. The text "TaskFlow lo hace en línea" should appear exactly once, and `Configurar la transcripción local` should no longer be found.
- Evidence: verified in code.
