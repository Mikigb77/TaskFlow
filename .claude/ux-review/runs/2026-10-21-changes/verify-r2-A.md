# Verify — run 2026-10-21-changes, round 2, area A (P229) — 2026-10-21

Scope: `App/lib/screens/voice_task_screen.dart`, `App/test/ux_previews/commands_previews.dart` (git diff HEAD). Renders: `App/build/ux/commands/cards.bulk-delete*.png`, `cards.bulk-ambiguous-project.*` rendered 2026-10-22 00:22, newer than the code (23:39), so current. Evidence level: code + widget-test renders; no device.

## UX-1717 · fixed
- `voice_task_screen.dart:4076-4080`: `count: view.bulk?.count ?? (command.bulk ? 2 : 1)` with the one-line comment. `command.bulk` (`capture_command.dart:414`) is true for update/delete/complete sets, so a set still asking «¿Qué proyecto?» (view.bulk == null) now selects the ICU `other` branch: ES «No se cambiarán / eliminarán / completarán», CA «No es canviaran / No se suprimiran / No es completaran» (`app_es.arb:1289-1290,1333`; `app_ca.arb:993-994,1037`). One-task cards still pass 1.
- `_removeCommand` doc comment (`:3334-3337`) updated to the three cases. Button count untouched.
- Tester's acceptance tests exist (`bulk_voice_commands_test.dart:3721-3823`); no failure reported.

## UX-1718 · fixed
- `_firstOpen` (`:2676-2702`): last loop no longer filters `view.bulk == null`; returns `(card, heading: view.bulk != null)` for the delete pick, heading false elsewhere. Pick order unchanged. Doc comment updated.
- `_reveal` (`:2743-2760`): `alignment: open.heading ? 0 : 1`; duration, curve and `Duration.zero` under disabled animations kept. `_announce` (`:2814`) adapted to `.card`.
- Render `cards.bulk-delete-mixed.es.light.2x` (new): sheet opens with «Eliminar 3 tareas» and its ✕ at the top, «Añadir y eliminar» below. Description is true to the render.
- Render `cards.bulk-delete.es.light.2x`: still opens at «Eliminar 3 tareas» and ✕ (UX-1704 still fixed). `cards.bulk-ambiguous-project` es 1×/2× unchanged: «Tareas de «mates»», «¿Qué proyecto?», two chips, button disabled.
- Observation, not a regression (the brief's stated trade-off): in the mixed render nothing on screen shows that the «Comprar pan» card sits above; only the button's «Añadir» hints at it.

## Regressions

### R2A-1 · Severity 2 · Answering a deletion set's project hides its heading
- Where: `voice_task_screen.dart:2753-2755` (`_reveal`), reached from `_changeCommand` → `_revealAfter(open)` (`:2963`).
- The moment: "I tapped «Matemáticas» and the red title and the ✕ jumped off the top — what is this going to delete?"
- What happens: a deletion set that asked «¿Qué proyecto?» keeps its QuestionBox after a chip is tapped (`capture_command_cards.dart:57` `asksProject => projectChoices.isNotEmpty`; `_Frame` puts the question right under the heading, `:525-529`). Once answered, the set is no longer blocking, so `_openCount` drops, `_revealAfter` runs `_reveal`, `_firstOpen` picks the set with `heading: true`, and `_reveal` scrolls `_questionIn(card) ?? card` — the QuestionBox, not the card — to `alignment: 0`. At large text (rows in the sheet's own scroll, `capture_command_cards.dart:2088-2090`) the card is taller than the view, so «Eliminar N tareas» and its ✕ scroll up out of view by the heading's height. Before this round nothing was revealed for a set, so the heading stayed in view. The brief asked for the heading to come to the top in exactly this case.
- Why it fails: visibility of system status (Nielsen 1994); the destructive scope and its way out must be visible before the delete button (P229 brief's own rationale).
- Fix: in `_reveal`, when `open.heading` is true, reveal the card itself, not its question: `Scrollable.ensureVisible(open.heading ? card : (_questionIn(card) ?? card), alignment: open.heading ? 0 : 1, …)`. Update the doc comment. No copy change.
- Verify: widget test, Spanish, 2×, 360 dp: a deletion set asking «¿Qué proyecto?» (Matemáticas / Matemáticas II); tap «Matemáticas», settle; the set's `command-headline` and its ✕ (tooltip «No eliminar ninguna») lie inside the visible scroll area.
- Evidence: verified in code; no preview covers the post-answer state.
