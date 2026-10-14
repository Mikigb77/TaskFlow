## UX verify — 2026-10-13-app, b5 round 1, area C (P13, P14, P15) — 2026-10-14

**Verdict:** Ship after fixes. Nine of the ten findings are fixed and one is partly fixed (the inviter's name needs a server change). But the new Share door on the project page opens a path where deleting or leaving lands the user on an empty "ghost" page of the project they just removed.

**Evidence level:** I read the code (`git diff HEAD`) and the tester's results. No preview covers sharing, invitations or Projects. The Calendar renders from 04:34 have no invitation fixture. I did not run Flutter.

**Walked:**
- Share from inside a project, as the owner: Compartir → Invitar a una persona → email (autofocused) → Enviar invitación → Hecho. That is 4 taps plus typing; before, there was no door from the project page at all. The invite dialog has about 13 words, down from 73.
- Invitee without the email link: Calendar card → Unirme dialog → paste the code → Unirme → project page with "Te has unido a …". That is 3 taps plus pasting.
- Invitee with the link: review → Aceptar invitación → project page. Or Ahora no → the Calendar card offers it again.
- Archive a project or group → message with Deshacer.
- Delete or leave from the Projects ⋮ menu and from the sharing screen.

Personas: newcomer, daily user, TalkBack user.

### Findings

| ID | Result | Evidence |
|---|---|---|
| UX-305 | fixed (needs a phone check) | `home_screen.dart:326-363`: the owner's personal project shows Compartir; once shared it reads `Miembros · {people.length}`. The server's `project_people` includes the owner (`Backend/core/list_access.py:43`). Invite dialog `list_sharing_screen.dart:121-180`: autofocused field, one sentence, Enviar invitación, role fixed to `editor`. Code dialog: `invitationSent` and `invitationCodeFallback`. Unsynced project: `connectToShare` (`:136-152`). ⋮ item `shareProject` with no `version > 0` gate (`task_lists_screen.dart:330-334`). |
| UX-318 | fixed | `list_sharing_screen.dart:319-355`: the rows have no `onTap`; a ⋮ menu offers Reenviar and Anular invitación (in the error colour). `replaceInvitationHelp` is removed. |
| UX-316 | fixed | `forTeam` reads All / Todas / Totes. `assignedToGroup` reads Todos / Tothom. The `people` heading and `sharingProblem` say Miembros. |
| UX-339 | fixed | `list_sharing_screen.dart:239-248`: `yourRole` and `sharingHelp` show only to non-owners. The pending heading shows only when there are invitations (`:317-318`). |
| UX-306 | fixed (needs a phone check) | Card: `calendar_screen.dart:588-599`, placed under the week strip and above the agenda heading, with `+N`. Pull-to-refresh refreshes it (`:228-231`), and on failure it stays silent. One join dialog: `invitation_cards.dart:83-149`. Decline asks first (`:150-174`). Decline sits away from Join: spaced apart on a wide row, and on top when stacked. |
| UX-307 | fixed | `showJoined` (`invitation_cards.dart:237-260`) pushes the project page (`HomeScreen` with `listId`) or `GroupScreen` and says "Te has unido a {name}". From a link it uses `pushReplacement(result: true)`, so Back returns to Calendar. |
| UX-326 | partly | Copy fixed (`invitationReviewHelp`, `signedInAs`, `invitationNotNow`). Ahora no keeps the link (`main.dart:233-239`), and the card pre-fills the code (`invitation_cards.dart:79-80`). Still missing: who sent it. Needs `invited_by_name` on the server (cause server-side). |
| UX-301 | fixed (needs a phone check) | Project: `projectArchivedNoReminders` with Deshacer → `store.update(list)` + `loadTasks` (`task_lists_screen.dart:60-84`). Group: `groupArchivedForEveryone` with Deshacer (`groups_screen.dart:620-644`). Mute: `updatesMuted` = "Silenciado: sin novedades ni recordatorios". A phone still has to confirm a reminder fires after Deshacer. |
| UX-317 | fixed | Projects ⋮ has Eliminar proyecto in red, or "…para todos" when shared, for an owner's personal synced project (`task_lists_screen.dart:340-355`). In all three screens, delete, leave, remove access and revoke use the error colour, and their confirm buttons are red (`groupConfirm(destructive:)`). |
| UX-340 | fixed | Has salido de {name} / Proyecto eliminado via `showFeedback` after pop (`list_sharing_screen.dart:107-111`, `groups_screen.dart:276-280`). Group delete was never in this finding (it is pre-existing, out of scope). |

### Regressions (caused by this round)

**R1C-1 · Severity 3 · Delete or leave lands on a ghost project page**
- Where: `list_sharing_screen.dart:107-111` (`Navigator.pop` once), with `home_screen.dart:264-268` and 450-463.
- The moment: "Pone 'Proyecto eliminado'… ¿y por qué sigo dentro, en una página 'Proyecto' que me pide añadir una tarea?"
- What happens: P13 gives every owned project a Compartir button on its own page. Delete from sharing, or Leave, pops one screen, back to `HomeScreen(listId)` of a project that no longer exists. The title falls back to "Proyecto". The empty state says "Añade una tarea a este proyecto. Tú eliges la fecha y el recordatorio." The success snackbar shows over it.
- Why: Norman, gulf of evaluation. Nielsen #1 and #5: the page contradicts the message, and it invites adding to a deleted project.
- Fix: on delete or leave, pop the project page too: `popUntil` the route below `HomeScreen(listId)`, i.e. back to Projects or Calendar. Alternatively, `HomeScreen` closes itself when its `listId` disappears from `taskListsProvider` after a load. Show the snackbar on the screen it lands on.
- Verify: widget test. Open sharing from the project page, delete; the project page is gone and Projects (or Calendar) shows Proyecto eliminado. Do the same for Leave.
- Evidence: verified in code; what a capture started on that page does needs a phone check.

**R1C-2 · Severity 2 · Unshared delete still warns "para todas las personas"**
- Where: `task_lists_screen.dart:97-104`, which uses `deleteListHelp` for every project.
- The moment: "¿Para todas las personas? Si no lo he compartido con nadie… ¿lo ve alguien?"
- What happens: the new ⋮ item correctly says "Eliminar proyecto" for an unshared project. The confirmation then says "¿Eliminar este proyecto y todas sus tareas, notas y archivos subidos para todas las personas?"
- Why: UX-317's own rule (say "for everyone" only when shared); plain language (ISO 24495-1); it frightens the newcomer.
- Fix: add a key for the unshared case and pick by `list.shared`.
  - EN: "Delete {name} with all its tasks, notes and files? This can’t be undone."
  - ES: "¿Eliminar «{name}» con todas sus tareas, notas y archivos? No se puede deshacer."
  - CA: "Vols suprimir «{name}» amb totes les tasques, notes i fitxers? No es pot desfer."
  - Use the same key on the sharing screen's delete when the project isn't shared.
- Verify: widget test. Deleting an unshared project shows no "para todas".
- Evidence: verified in code.

**R1C-3 · Severity 2 · Unirme: no progress, and a wrong code is lost**
- Where: `invitation_cards.dart:83-211`.
- The moment: "Le he dado a Unirme y no pasa nada… ¿lo vuelvo a pegar?"
- What happens:
  - The dialog closes as soon as Unirme is tapped. Then the request and a full `loadTasks()` run with nothing on screen until the project opens.
  - Tapping the card again does nothing (`_responding`).
  - A wrong or expired code shows only a snackbar after the dialog has gone, and the pasted code is lost.
  - For a group, the server's "Ask a group administrator…" maps to `sharingProblem.code`, so it reads "Pide al propietario del proyecto…".
  - This is the new Calendar entry, so it reaches the newcomer first.
- Why: Nielsen 1993 (progress beyond 1 s); Nielsen 2001 (keep the user's input; say how to fix it); Nielsen #1.
- Fix:
  - Keep the dialog open while it sends: Unirme shows a spinner, and the other buttons are disabled.
  - Show the error under the code field, keeping the code.
  - Close only on success, then land.
  - For a group code error, say "Pide a quien te invitó el código actual." / EN "Ask the person who invited you for the current code." / CA "Demana el codi actual a qui t’ha convidat."
- Verify: widget test with a delayed and a failing `respond`. A progress indicator is visible in the dialog, the error shows in the dialog, and the field still holds the code.
- Evidence: verified in code.

**R1C-4 · Severity 2 · Projects ⋮ says "Compartir" where you can't share**
- Where: `task_lists_screen.dart:330-334`, shown whenever an account exists.
- The moment: an editor of a shared project taps "Compartir" and finds only "Tu rol: Editor" and "Salir del proyecto". In a group project, a non-admin lands on the group page with no way to invite.
- What happens: the rename made a generic item into a promise only owners and admins can keep. Leaving the project is now hidden behind a "Compartir" label.
- Why: match between the app and the real world (Nielsen #2); one concept, one name (ISO 24495-1).
- Fix:
  - Label the item `shareProject` only when `list.groupId == null && list.role == 'owner'`, or for a group admin.
  - Otherwise use `people` ("Members" / "Miembros" / "Membres"), matching the project page's "Miembros · N".
- Verify: widget test. An editor's ⋮ reads Miembros; the owner's reads Compartir.
- Evidence: verified in code.

**R1C-5 · Severity 1 · Decline confirmation isn't red; "revoca" vs "Anular"**
- Where:
  - `invitation_cards.dart:164-168`: the confirm Rechazar is a plain `FilledButton`, while every other destructive confirm in this run is red.
  - `sharingProblem.memberLimit` still says "revoca una invitación" (EN "revoke", CA "revoca"), but the action is now "Anular invitación".
- Fix:
  - Use `groupConfirm(…, destructive: true)`, or the same error style, for the decline confirm.
  - Change the copy to "anula una invitación" / EN "cancel an invitation" / CA "anul·la una invitació". Groups' "Revocar invitación" is P27's.
- Evidence: verified in code.

### Observations (not regressions)
- After Ahora no, the stored link reopens the review on every later cold start until the user joins or declines. That is consistent with "not now", but worth watching on the phone walkthrough.
- On the review screen, an invitation that is unavailable (404) still offers "Ahora no" and "Intentar de nuevo"; this is pre-existing.
- Deleting an empty group still closes the group page without a message. That is outside UX-340's scope; candidate for the ledger.
- `sharingProblem` in ES and CA still uses feminine pronouns left from "lista" ("si ya no la necesitas", "Actualízala antes de eliminarla"). This is pre-existing and not caused by this round.

### Phone checks still needed
- "Share this list with your wife", starting inside a project.
- Second account: the card is on Calendar → paste the code → you land on the project.
- A reminder still fires after archiving and then Deshacer.
