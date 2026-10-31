## UX verify — run 2026-10-22-changes, plan 2, round 1, area C — 2026-10-23

Scope: P260 (UX-2029). Files: the three ARB catalogs (key `sharedDataHelp` only), App/test/sharing_ui_test.dart, App/test/ux_previews/sharing_previews.dart.

### UX-2029 · fixed
- `sharedDataHelp` now ends «Los recordatorios no se comparten: cada persona tiene los suyos.» (app_es.arb), “Reminders aren’t shared: each person has their own.” (app_en.arb), «Els recordatoris no es comparteixen: cada persona té els seus.» (app_ca.arb). The first two sentences are unchanged word for word (git diff HEAD).
- `@sharedDataHelp` added in app_en.arb with the brief's description; generated files match (app_localizations_es.dart:1932, _en.dart:1884, _ca.dart:1917, app_localizations.dart:3193).
- No catalog or Dart source keeps the old sentence (grep across App/lib: no match for «opciones de recordatorio se comparten», “reminder choices are shared”, «recordatoris es comparteixen»).
- The string is used once, App/lib/screens/list_sharing_screen.dart:484; layout untouched.
- Renders (2026-10-23 11:55, current): `build/ux/sharing/project-sharing.how-it-works.es.light.1x.png` shows all three paragraphs with the new sentence whole; `…ca.light.2x.png` shows the Catalan paragraph whole at 2×, nothing clipped. AUDIT's TalkBack list reads the paragraph as one text node (item 15) in a sensible order.
- Tests: four P260 tests in sharing_ui_test.dart pass (es/en/ca 1×, es/ca 2×, old sentence gone, description).
- Evidence: verified in code, seen in current renders, widget tests.

### Regressions
None caused by this change.

Notes, not regressions:
- The old sentence also told people “each phone must enable its own notifications”; that line is gone. Acceptable: notification permission is asked in context from the reminder flows, and the help panel was never where it's enabled.
- INDEX/AUDIT description for the `ca.light.2x` render repeats “At 1× the roles and leaving paragraphs show around it”, which is about the es 1× render only. Harmless test-side wording; the description stays true for the 1× render.
- The brief calls the panel «Cómo funciona compartir»; the Spanish catalog's existing title is «Cómo funciona el acceso compartido». Unchanged here, not this package's.
- The AUDIT's 1 dp gap between «Novedades del proyecto» and «Cómo funciona…» is pre-existing layout, not touched by P260.

### For the main session (contract)
Nothing for Backend/docs/REMINDER_PLANS.md: the help copy now matches «Every reminder is personal».
