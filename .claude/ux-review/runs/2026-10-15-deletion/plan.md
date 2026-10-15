# UX loop 2026-10-15-deletion: plan

**Run:** what changed since the last UX review (`changes`, 96404f1 → e1df0a7), which is the new Delete my account flow. Review D (`review-D.md`) says ship after fixes. This is a scoped run, so the packages go straight to the implementers.

**Summary.** All 11 findings are fixes, in 5 packages (P120–P124). Together they give a forgotten password a way out, make saving a copy one honest tap, name the account and every heir plainly, and show the real waits. Four owner questions (UX-812 to UX-815) are recorded; none blocks this run.

## Questions for the owner (not blocking)

### UX-815 · Forgot password: recover on the page, or confirm with Google? (S2)
- **Findings:** UX-815 (review D's question 4), and what's left of UX-801 after P121.
- **Why it's yours:** P121 makes the wrong-password message say how to recover. The route is long, though: sign out, get the code by email, set a new password, sign in, then Ajustes › Cuenta › Eliminar cuenta again. Both ways to shorten it need a server change:
  - (a) let accounts with Google linked confirm with Google instead of the password;
  - (b) recovery inside the delete page (review D's full fix for UX-801). A reset ends every session, so the page must sign back in, and today the 15-minute lock outlives a reset (`Backend/core/auth_views.py:145-164` never clears it). The server would have to lift the lock on a reset first.
- **Recommendation:** (a) now, (b) not yet.
  - Google sign-in already opens a linked account (`Backend/core/google_auth.py:66-69`), so confirming with it is no weaker.
  - The page gains no control: a linked account sees «Confirmar con Google» instead of the field.
  - Password-only accounts keep P121's way out. Revisit (b) if testers get stuck there.

### UX-813 · Telling the heir (S2)
- **Findings:** UX-813 (review D's question 2).
- **Why it's yours:** nothing tells the person who receives a project or group. Telling them is server work, and a new kind of message.
- **Recommendation:** yes, later. The website says ownership is never transferred silently, and the heir is the other side of that promise. Decide how (an in-app notice, an email, or both) together with the confirmation-email step you already set for later. Nothing in the app changes now.

### UX-814 · Files in the copy (S2)
- **Findings:** UX-814 (review D's question 3).
- **Why it's yours:** «Guardar antes una copia» keeps only the names of the files, and after deleting the files are gone. P120 now says so («La copia no incluye los archivos.»). Carrying the files changes what the export holds.
- **Recommendation:** not for now.
  - It needs a new export format (a zip with the files) and an import that reads it back.
  - The file can be large: up to the 100 MB free total, more with Pro.
  - That's a feature, not a fix. P120's line keeps the promise honest; revisit if testers say they lost photos.

### UX-812 · Choosing the heir (S1)
- **Findings:** UX-812 (review D's question 1).
- **Why it's yours:** heirs are picked automatically (the earliest admin or editor) and named before the tap. Letting the person pick someone else adds a control to the delete page. Groups already have Transferir propiedad; projects have nothing like it.
- **Recommendation:** not now. Every heir is named before confirming, which keeps the website's promise, and a group can be handed to someone else first with Transferir propiedad. Revisit if a tester asks for it.

## Packages, in order

They run one at a time. All are in area D, on the delete page unless noted. Full briefs are in `plan.json`.

### P120 · S3 · M · Save a copy from the delete page itself, and say it leaves the files out
- **UX-802 (S3):** with files, one line under the link: «La copia no incluye los archivos.».
- **UX-807 (S2):** the link saves the export itself, so Android's save screen opens at once. «Copia guardada» then replaces the link, and the link shows only when there are tasks or notes. That's 4 taps → 2 and 2 screens → 1.

### P121 · S3 · M · Confirming and deleting: a way out, the real wait, Google heard, progress shown
- **UX-801 (S3):** a wrong password now says «… Si no la recuerdas, cierra sesión y toca «¿Has olvidado tu contraseña?».». This is the reviewer's minimum; staying on the page is UX-815.
- **UX-808 (S2):** while deleting, the button reads «Eliminando tu cuenta…» and the back arrow hides.
- **UX-809 (S2):** the lock reads «Demasiados intentos. Espera 15 minutos y vuelve a intentarlo.», using the wait the server's answer carries.
- **UX-810 (S2):** TalkBack hears «Confirmado con Google», and «Eliminar mi cuenta» scrolls into view.

### P122 · S2 · L · Say whose account goes, what goes, what stays for the others, and what changed
- **UX-803 (S2):** the email sits under the heading, and "TaskFlow" goes in the intro. The Google lines name the email and say «Tu cuenta de Google no se elimina.».
- **UX-804 (S2):** a second list, «Lo que se queda para los demás:». Each line starts with its count, files are included, and a group's line says its projects go with it.
- **UX-805 (S2):** after a 409, the banner lists each new or changed handover, and that line is bold in the list until the next tap.

### P123 · S2 · M · The Google Play line: true for whoever reads it
- **UX-806 (S2):**
  - complimentary Pro sees nothing;
  - everyone else reads «Si pagas TaskFlow Pro en Google Play, eliminar tu cuenta no cancela la suscripción.»;
  - «Gestionar suscripción» opens the subscription manager, or Google Play's subscriptions page, instead of a help article.

### P124 · S1 · S · Account: Eliminar cuenta apart from Cerrar sesión (`account_screen.dart`)
- **UX-811 (S1):** 24 dp and a divider between the two red buttons.

## Skipped
None of the 11 findings is skipped. These are not planned, and why:
- **Files without tasks (part of UX-804):** someone who added files, but no tasks, to shared projects sees no line for them, because the preview doesn't count those files. Cause server-side.
- **The lock and sign-in (part of UX-809):** the 15-minute lock also stops signing in, which is a server rule. Sign-in itself only says «Demasiadas solicitudes. Espera un poco antes de volver a intentarlo.» for it (`requestError`, `rateLimit`). Review D didn't cover sign-in, so it isn't planned here. Someone who follows P121's route after five wrong tries will meet that message.
- **The open questions:** choosing or telling heirs, files in the copy, and confirming with Google are UX-812 to UX-815 above.

## Notes for the main session
- **The "owner's brief" test.** `App/test/delete_account_test.dart:1359` calls today's Spanish copy "the owner's brief", but DECISIONS.md records no deletion copy.
  - Only «Tu cuenta se ha eliminado.» comes from ACCOUNT_DELETION.md, and no package changes it.
  - P122 changes the kept, handover and plan-changed lines, and renames that test.
  - If the owner did approve that Spanish wording, stop P122 and record it in DECISIONS.md first.
- **The wait text.** P121 reads the wait from DRF's English detail ('Expected available in N seconds.'). `Backend/core/test_account_deletion.py:348` pins `Retry-After: 900` but not that text. Confirming it is a main-session check in P121's deviceChecks.
- **Throwaway accounts.** Device checks that confirm a deletion need a throwaway account: deleting is real.
- **Evidence.** So far it is code and widget tests only. No preview renders the delete page or the «Tu cuenta se ha eliminado.» notice.

## Round 2 (b1)

Round 1 ran P120 to P124, and the round check passed. Ten of the eleven findings are fixed. UX-804 is partly fixed: its app part is in place, and the only gap left is server-side. The reviewer found two regressions, both severity 1 and inferred from code. They are now UX-816 and UX-817.
Round 2 has one package, P125 (S1). There are no new decisions, and nothing is escalated.

The briefs are in `plan-b1-r2.json`.

### Packages, in run order

#### P125 · Delete page: the title holds still while deleting, and the changed-plan banner is spoken once, without the bullet · D · S · after P121 and P122
- **UX-816** (S1; R1D-1 from P121; inferred from AppBar layout) While the account is deleting, hiding the back arrow dropped its 56 dp slot. «Eliminar cuenta» slid toward the start on the tap and back on an error. Now CustomAppBar keeps the slot empty (`leading: SizedBox.shrink()`) when `canGoBack` is false. Other screens are unchanged.
- **UX-817** (S1; R1D-2 from P122; needs TalkBack on a phone) After a 409, the detailed banner spoke «viñeta», and it could announce twice (once during the reload, then with the details). Now the banner is a live region only after the reload, and TalkBack hears a label made of the same lines without the bullet. The visible text is unchanged.

### Skipped
- **UX-804** (partly, failed once), not re-planned, cause server-side. Someone who added files, but no tasks, to shared projects sees no kept line. That's because `kept_in_shared` (`Backend/core/account_deletion.py:106`) counts only tasks. Round 1's plan had already set this part aside. Counting those files is a backend change, outside the UX loop.

### Escalated
None: no finding has failed twice.
