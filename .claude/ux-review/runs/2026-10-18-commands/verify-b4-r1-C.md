## UX verify — run 2026-10-18-commands, b4 round 1, area C (P155) — 2026-10-19

**Verdict:** both findings fixed in the app; two polish-level regressions in the new name sheet, neither blocking.

### UX-1112 · fixed (device check for TalkBack and the other member's sync)
- `App/lib/services/api_client.dart` `Account.fromJson` reads `first_name` ('' when missing or null); new `ApiClient.setFirstName` sends `PATCH auth/me/` with `{'first_name': …}` and persists the returned user into the session, guarded by `_generation`.
- `App/lib/providers/auth_provider.dart` `AuthNotifier.setFirstName` updates `state` only for the same account.
- `App/lib/widgets/name_ask_sheet.dart` (new): `askForNameOnce` asks only while `firstName` is blank, once per owner (`app_preferences` scope `nameAsked:<owner>`, marked as the sheet shows, plus an in-run guard). Sheet: header in a live region, body line, autofocused field (words capitalisation, maxLength 150, no counter, prefilled by `suggestedName`), FilledButton «Guardar» disabled when empty, TextButton «Ahora no»; failure shows `requestProblemText` under the field and keeps the name; save invalidates `taskListsProvider`. Scrolls and pads by the keyboard inset.
- Call sites: `list_sharing_screen.dart` `_applied` after «Invitación enviada» closes; `groups_screen.dart` after the group's code dialog closes; `invitation_cards.dart` `showJoined` (used by the join dialog and `invitation_review_screen.dart`) over the joined page.
- Copy matches the brief in EN / ES / CA (`app_en.arb:1078-1093`, `app_es.arb:575-578`, `app_ca.arb:554-557`).
- Renders (current: no app file newer than them): `App/build/ux/sharing/project-sharing.name-ask.es.light.{1x,2x}.png` — title, body, prefilled field, «Guardar», «Ahora no» whole at 2×; one primary. AUDIT: TalkBack reads heading «¿Cómo te llamas?» [live region] first after the route; targets 48–60 dp; «Guardar» 52 dp is the app-wide FilledButton theme (`minimumSize 48×52`), not new.
- Tester's 11 acceptance tests pass. Group-invite path has no test but mirrors the project path line for line.

### UX-1102 · fixed in the app (Google half on the server, 41c00f3: device check on staging)
- No app code shortens an email into a name: the only `split('@')` in `App/lib` is the sheet's own suggestion. Chips (`project_scope_control.dart:272-277` `member.name`), «Creada por» (`task_detail_screen.dart:148` `createdByName`), the picker (`task_assignment_picker.dart:154-155` `person.name`) and the row tag (`task_tile.dart` → `responsibilityLabel`, `task_assignment_picker.dart:17-26` `assigneeName`) all show the server's name. Tester's chip/«Creada por» test passes; picker and row tag verified in code only.

### Regressions (only in the changed files)
- **R1C-1 · S1 · Offline error under the name field talks about tasks.** `name_ask_sheet.dart` errorText → `requestProblemText(l, _error!)`, which for a network failure returns `networkKept`: «No hay conexión. Revisa el wifi o los datos móviles e inténtalo de nuevo. Tus tareas siguen guardadas en este teléfono.» The last sentence is about tasks, not the name the person just typed (G, plain and specific; Neusesser & Sunwall 2023: say what happened, keep the input). Fix: show the plain `network`/`other` reason here (no «Kept» suffix), e.g. call `requestProblemText(l, e, onSignIn: true)` or map the reason directly; the field already shows the name is kept.
- **R1C-2 · S1 · No progress while «Guardar» waits.** `_save` only greys the button (`_canSave` false while `_saving`); on a slow connection nothing moves for >1 s, and «Ahora no» stays live (B, Nielsen 1993 response-time limits). Fix: while saving, show a small `CircularProgressIndicator` in place of the «Guardar» label (keep the button size), as the join dialog does (`invitation_cards.dart:302`), and turn «Ahora no» off while it runs.

### Notes (not regressions)
- After «Guardar» the sheet just closes; the person never sees their own name anywhere (own row is not listed). Acceptable: the closing is the answer, and the brief adds no name row (accepted in the brief).
- The «Te has unido…» snackbar may time out under the sheet after a join; accepted in the brief; the joined page itself confirms.
