# Verify — run 2026-10-19-app, batch b7 round 2, area D — 2026-10-21

Scope: P222 (UX-1656). Evidence: code and resource files (`git diff HEAD`), ux-tester's resource tests. No Flutter preview covers launcher shortcuts or the widget; the device captures in `App/build/ux/device/` (commit 6ea4ab0, 2026-10-21 01:32–02:23) predate this change (strings.xml modified 04:47), so they are not evidence for it.

## UX-1656 — fixed (needs the emulator lane)

- `App/android/app/src/main/res/values/strings.xml:3` `capture_voice` = “Dictate a new task” (18 chars); `:5` `capture_voice_short` “Dictate”; `:7` `capture_text` “Type a new task” (15); `:9` `capture_text_short` “Type”. The English pair now reads as one wording, and both long labels are at or above the 15 characters the emulator showed falling back to the short label at 2.0.
- `capture_widget_label` added after `capture_text_short` with the brief's translator comment in all three catalogs: EN “Say a task” (`values/strings.xml:11`), ES «Dictar una tarea» (`values-es/strings.xml:11`), CA «Dicta una tasca» (`values-ca/strings.xml:11`) — the widget's text is unchanged.
- Every widget surface points at it: `res/layout/capture_widget.xml:6` (contentDescription) and `:10` (text); `CaptureWidget.kt:25` (getString, TIRAMISU check and comment kept; `:35–36` set text and TalkBack name from it); `AndroidManifest.xml:58` (receiver label). The only remaining `capture_voice` reference is `CaptureShortcuts.kt:26`, unchanged (empty diff).
- ES/CA `capture_voice`/`capture_text` and short labels, `capture_widget_description`, `capture_widget_info.xml` and every ARB file: unchanged (empty diffs). Manifest line 15 is P195's icon change, not this package's.
- ux-tester: all UX-1656, UX-1316 and UX-121 resource tests pass; debug APK links.
- Still needs the emulator lane (not faked): EN launcher shortcuts at 2.0 «Dictate» / «Type», at 1.0 whole; the widget's label, TalkBack name and picker name in EN/ES/CA at 1.0 and 2.0; Android 13+ per-app English reads «Say a task» on an already placed widget.

## Regressions

**R2D-1 · Severity 1 · English widget and voice shortcut now differ**
- Where: `values/strings.xml:3` vs `:11`; launcher long-press menu vs home-screen widget, English only.
- The moment: “The widget says Say a task, the shortcut says Dictate a new task — are those two different things?”
- What happens: before this round both voice entries were named “Say a task”; now the voice shortcut reads “Dictate a new task” and the widget “Say a task”, while the in-app English copy uses “dictate” throughout (`app_en.arb:1663,1674,1680,1688`). Spanish and Catalan are unaffected (widget and shortcut both «Dictar una tarea» / «Dicta una tasca»). This was a known trade-off of the brief (keep the widget's text exactly), so it is polish, English only.
- Why: one concept, one name (ISO 24495-1; Nielsen heuristic 4, consistency).
- Fix (optional, polish): `capture_widget_label` EN “Dictate a task” (14 chars, fits the ~20-char cell), `capture_widget_description` EN “Tap to dictate a task.”, and `homeCaptureInstructions` EN “…or add the Dictate a task widget…”. ES/CA unchanged. Or accept the difference as is.
- Verify: resource test for the new EN values; emulator capture of the English widget at 2.0 (two lines, no cut).
- Evidence: verified in code.

No other regressions in the changed files.
