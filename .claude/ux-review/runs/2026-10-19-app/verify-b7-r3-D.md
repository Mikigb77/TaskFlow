## UX verify — run 2026-10-19-app, round 3, area D (P223) — 2026-10-21

**Verdict:** UX-1657 fixed in code; three emulator checks remain for the main session's lane. No regressions.

### UX-1657 · S1 · fixed (code + widget test; device checks pending)
- `App/android/app/src/main/res/values/strings.xml:10-12`: translator comment kept, then `capture_widget_label` “Dictate a task” (14 chars, limit 20), after `capture_text_short` (:9) and before `capture_widget_description` “Tap to dictate a task.” (:12).
- English voice entries now share one verb: `capture_voice` “Dictate a new task” (:3), `capture_voice_short` “Dictate” (:5), widget “Dictate a task” (:11). No English Android string contains “say a task” (grep over `android/`).
- Every widget surface uses `capture_widget_label`: `res/layout/capture_widget.xml:6` (contentDescription) and `:10` (text), `CaptureWidget.kt:25` / `:35`, `AndroidManifest.xml:58` (receiver label).
- `App/lib/l10n/app_en.arb:404` reads “…or add the Dictate a task widget from your launcher…”, with the new `@homeCaptureInstructions` description at :405-407; generated files carry the change (regenerated, `app_localizations_en.dart`). Used at `lib/screens/other_settings_screen.dart:75`.
- Spanish and Catalan untouched: `values-es` / `values-ca` show «Dictar una tarea» / «Dicta una tasca»; `app_es.arb:228`, `app_ca.arb:207` unchanged.
- Evidence: verified in code; ux-tester's resource tests and the English 2×/320 dp Settings › Other help-sheet widget test (`test/settings_screen_test.dart`, compares the shown name with the XML label). The preview suite renders `settings/other.*` in Spanish only, so no render shows the English sheet; the home-screen widget can't be rendered by a widget test.
- Needs device (emulator lane): label whole at Android text 1.0 and 2.0 on at most two lines; TalkBack name and picker entry “Dictate a task” / “Tap to dictate a task.”; Android 13+ per-app English on a Spanish phone; ES/CA widget unchanged at 2.0.

### Regressions
None. Checked the changed strings, the ARB entry, the generated output, every widget surface and the Settings › Other flow that shows `homeCaptureInstructions`.

Not regressions, noted for the ledger owner only (pre-existing, outside this package's brief):
- iOS `Info.plist:8` and `en.lproj/InfoPlist.strings:1` still say “so you can say a task”. Android-only app per the 2026-10-18 decisions; the acceptance check covered Android strings only.
- English row title `homeCapture` “Mic button on your home screen” and Spanish help «…el widget de micrófono…» (`app_es.arb:228`) describe the widget by its icon, not its label «Dictar una tarea»; the brief kept Spanish as is on purpose.
