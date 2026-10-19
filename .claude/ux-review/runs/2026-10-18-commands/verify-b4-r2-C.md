## UX verify — run 2026-10-18-commands, b4 round 2, area C (P164) — 2026-10-19

**Verdict:** both findings fixed; no regressions in the changed file or the flows it touches.
**Scope:** `App/lib/widgets/name_ask_sheet.dart` (untracked, P155 + P164, read in full), `App/test/name_ask_test.dart` (round-2 tests :372-606).
**Render:** `App/build/ux/sharing/project-sharing.name-ask.es.light.{1x,2x}.png`, 2026-10-19 09:40; `find App/lib App/assets -newer` that PNG lists nothing, so it is current. It shows the sheet at rest only; no preview covers the saving or error states, judged from code and the tester's widget tests.

### UX-1229 · fixed
- `name_ask_sheet.dart:185-189`: `errorText` is `requestProblemText(l, _error!, onSignIn: true)`, with the asked-for comment above it.
- `request_locale.dart:48-50`: with `onSignIn`, `network` and `other` no longer take the `…Kept` variant, so the line reads EN “No connection. Check Wi-Fi or mobile data and try again.” / ES «No hay conexión. Revisa el wifi o los datos móviles e inténtalo de nuevo.» / CA «No hi ha connexió. Revisa la wifi o les dades mòbils i torna-ho a provar.»; unknown failures read `other`. Staging, sharing and sync mapping are untouched; a 429 with a stated wait now says «Demasiados intentos. Espera N minutos…», which fits a name save too.
- No ARB change; `request_locale.dart` unchanged (no diff).
- Tests (pass, per ux-tester): es/en offline exact text and no «Tus tareas» / “Your tasks are still saved” (:375-411); unknown failure (:414-432); es and ca at 2× on 320×640 with the keyboard, whole and no overflow (:546-606); the updated UX-1112 offline test (:279-307).
- Evidence: verified in code + widget tests.

### UX-1230 · fixed
- `name_ask_sheet.dart:196-208`: while `_saving`, the FilledButton's child is a 20×20 `CircularProgressIndicator(strokeWidth: 2, semanticsLabel: l.save)`; `onPressed: _canSave ? _save : null` (off while saving). The button is stretched by the Column, so its size doesn't change (test :469 compares sizes).
- `:210-213`: «Ahora no» has `onPressed: _saving ? null : …`; `_save` (:123-140) resets `_saving` on failure, so both come back with the error under the field; on success it pops once (`mounted` check).
- Tests (pass): spinner, no «Guardar» text, same size, semantics «Guardar» + button + off, «Ahora no» off and tapping it leaves the sheet open (:453-491); failure restores both and shows the error (:494-528); success closes (:530-543).
- Evidence: verified in code + widget tests. Device check still owed: a password account on a slow connection, tap «Guardar», the spinner shows at once and «Ahora no» stays off until the answer.

### Regressions
None found. Considered and dismissed:
- Spinner colour on the disabled filled button: default `primary` on the disabled `onSurface` 12 % fill, the same pattern as the join dialog (`invitation_cards.dart`); readable in light; dark not rendered, inferred fine.
- TalkBack hears «Guardar, desactivado» while it waits, with no «saving» word: the brief asked for the label «Guardar»; before the change it also went off silently, so not a regression.
- Back, the scrim and a swipe still close the sheet while «Ahora no» is off: kept on purpose by the brief; the save still finishes and the name is applied (only `taskListsProvider` isn't refreshed in that case, as before P164).
