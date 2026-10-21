## UX verify — run 2026-10-19-app, round 2, area D — 2026-10-21

Scope: P220 (UX-1655). Changed file: `App/lib/screens/account_screen.dart` (the P220 change is the one `trailing:` line; the rest of the diff against HEAD is P194's row from round 1, already verified).

### UX-1655 · S2 · Cuenta: the name row ends in a chevron — FIXED
- Code: `App/lib/screens/account_screen.dart:211` adds `trailing: const Icon(Icons.chevron_right_rounded),` to the `account-name` ListTile, identical to Settings' nav rows (`settings_screen.dart:105,115,124,131,137`, no colour/size override). Key, leading icon, title/subtitle, `onTap` with `busy` guard and the 16 / 12 dp spacing are unchanged (`:199-214`). The Google-linked row (`:216-220`) has no trailing, as required.
- Renders (03:46 today; `find App/lib App/assets -newer` = nothing, so current):
  - `settings/account.named.es.light.1x`: «Nombre / María» with the chevron at the right; now reads as a tappable row, distinct from «Guardado en tu cuenta».
  - `settings/account.google-linked.es.light.1x`: name row has the chevron; «Cuenta de Google vinculada» and «Guardado en tu cuenta» have none — the tappable/read-only contrast is now visible.
  - `settings/account.email.es.light.2x` / `.ca.light.2x`: «Añadir tu nombre» / «Afegeix el teu nom» wrap at a word boundary to two lines beside the chevron, nothing clipped.
- AUDIT: `· named` «Nombre María» button 312 × 72 dp; `· email` «Añadir tu nombre» button 312 × 56 dp; TalkBack line unchanged («Nombre María», button).
- Tests: `App/test/name_ask_test.dart:889-940` — three UX-1655 tests, reported passing by ux-tester.
- Evidence: verified in code + current renders + widget tests. No device check needed.

### Regressions
None. The chevron takes ~40 dp from the title width; at 2× the titles still wrap cleanly. The AUDIT entries the tester noted (contrast flag on «Añadir tu nombre», an anti-aliasing false positive at 13.54:1; «Cerrar sesión» 200 × 2 dp in `· named es.light.2x`, a button cut by the bottom of the 2× viewport in a scrolling view) are not caused by a trailing icon, which changes no heights.
