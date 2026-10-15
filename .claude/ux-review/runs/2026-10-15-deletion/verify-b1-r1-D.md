## UX verify — 2026-10-15-deletion, round 1, area D (P120–P124) — 2026-10-16

**Verdict:** Ship. All eleven findings are in place as planned. The one gap left is server-side: UX-804's files-only kept line. Two small regressions (severity 1), both inferred from code.

**Evidence level:** code (`git diff HEAD`) plus ux-tester's widget tests, which all pass (App/test/delete_account_test.dart:1604-2831). There are no renders of the delete page or of Account: no file in App/build/ or App/artifacts/ covers them. So no visual judgement rests on a PNG. TalkBack, Android's save screen, Play and the Customer Center still need a phone.

### Results
| ID | Result | Evidence |
|---|---|---|
| UX-807 | fixed | `_saveCopy` delete_account_screen.dart:323-338 runs `archiveStoreProvider.export()` and then `archiveFilesProvider.save()`, and never pushes `/dataTransfer` (grep finds nothing). `_copy` :589-656 shows the link, which is disabled while `_deleting \|\| _savingCopy`. Once saved, a check row (key `delete-account-copy-saved`) replaces it inside `Semantics(liveRegion)`. An error line appears in `colorScheme.error`, in a live region, using archiveDiagnostic or transferError. The link only shows when tasks>0 or notes>0 (:420). data_transfer_screen, archive_store and task_archive have no diff. Tests :1604-1767. |
| UX-802 | fixed | `deleteAccountCopyNoFiles` appears when `files > 0`, under the link or the check row, at the icon's inset, in onSurfaceVariant (:645-654). ES «La copia no incluye los archivos.» EN and CA read exactly as planned. Tests :1770, :1835, :1853. |
| UX-801 | fixed | The ES/EN/CA copy is exact. The quoted words match `forgotPassword` (es:432, en:680, ca:411), and the verb matches `signOut` (Cerrar sesión / Sign out / Tanca la sessió). `errorMaxLines: 10`. Tests :1920, :1946, and the Manrope 2× test :2805. |
| UX-808 | fixed | While deleting, the button reads `deleteAccountDeleting` («Eliminando tu cuenta…») after a spinner with no label (:466-483). `CustomAppBar.canGoBack` defaults to true (custom_app_bar.dart:10). Its only caller is delete_account_screen.dart:389. PopScope is kept. Test :1975. |
| UX-809 | fixed | `_waitMinutesFor` :181-189 rounds up, with a minimum of 1. `deleteAccountThrottledWait` shows in the outcome banner (:375-378). With no wait in the text, the unchanged `deleteAccountThrottled` shows. Tests :2056, :2081. Main session: check the server's 429 detail text. |
| UX-810 | fixed | The confirmed row is wrapped in `Semantics(liveRegion: true)` and keeps its key (:731-741). `_reveal(_confirmButton)` uses a KeyedSubtree around the FilledButton (:143-144, :452-454), and respects reduced motion (:302-304). Tests :2119, :2139. |
| UX-803 | fixed | The email shows 8 dp under the heading in onSurfaceVariant, then the intro 12 dp below (:402-411). The intro, GoogleHelp and OtherGoogle copy is exact, with `{email}`. Tests :2166, :2227, and the 34-character email at 2× :2264. |
| UX-804 | partly | Done as planned: two lists under titleMedium headings, using a shared `_bullet` whose bullet is hidden from TalkBack (:525-575). The kept line front-loads the count and names the files. The group line names its projects. No final full stops. Tests :2304-2425. Still missing: someone who added only files to shared projects sees no kept line. The preview doesn't count those files, so this is server-side, as the implementer said. |
| UX-805 | fixed | `_newOrChanged` compares kind, name and recipient (:277-291). The banner reads intro / • line / check (:432-441), and stays general during the reload or when nothing is new. A bold line is cleared when `_delete` starts (:208). The password is kept. Tests :2481-2561, and the Manrope 2× test :2831. |
| UX-806 | fixed | The block is hidden for `complimentaryPro` (:543). The line is in normal weight. `_manageLink` :556-570 opens the Customer Center when billing is ready and a purchase is known; otherwise it opens play.google.com/store/account/subscriptions, and shows `deleteAccountLinkError` when that fails. `deleteAccountSubscriptionHelp` and the help-article URL are gone from lib, the tests and the catalogs. subscription_screen.dart has no diff. Tests :2597-2685. |
| UX-811 | fixed | account_screen.dart:305-307 has 24 dp, a Divider (height 1), then 8 dp before «Eliminar cuenta», which stays last, red, keyed `account-delete`. Tests :2707, :2751. |

### Regressions (changed files only)
**R1D-1 · Severity 1 · Title jumps sideways while deleting**
- Where: custom_app_bar.dart:21 (`automaticallyImplyLeading: !isRoot && canGoBack`), used by delete_account_screen.dart:387-390.
- What happens: when the arrow is hidden, AppBar drops the 56 dp leading slot. «Eliminar cuenta» slides about 56 dp to the start at the moment of the tap, then slides back if there's an error. The page moves at its most anxious moment.
- Fix: keep the slot and hide only the arrow. When `!canGoBack`, pass `leading: const SizedBox.shrink()`; AppBar still reserves `leadingWidth`. No copy change.
- Evidence: inferred from AppBar/NavigationToolbar layout; no render.

**R1D-2 · Severity 1 · The changed-plan banner: TalkBack reads "bullet" and may speak twice**
- Where: delete_account_screen.dart:430-441.
- What happens: (1) the banner's handover line starts with a literal '• ', which TalkBack reads aloud («viñeta»), unlike the lists, where the bullet is hidden from it. (2) The live region shows `deleteAccountPlanChanged` during the reload and then changes to the detailed text, so TalkBack can announce two near-identical messages in a row.
- Fix: give the banner `liveRegion: !_reloading`, so it announces once, with the final text. Wrap the MessageBanner in `Semantics(label: <the same lines without '• '>, child: ExcludeSemantics(...))`, so the bullet stays visible and isn't spoken.
- Evidence: inferred from code; needs a TalkBack check on a device.

Not regressions (they were there before this run): the Google Play link and the save-a-copy link are two look-alike link buttons stacked together, as before with «Cómo cancelarla en Google Play». The link is disabled during a slow export with no progress shown; the plan chose no spinner.

### Device checks still open
P120: the save screen opens, the saved file imports again, TalkBack says «Copia guardada». P121: TalkBack hears «Confirmado con Google» and the deleting text once; the main session checks that the 429 detail ends with 'Expected available in 900 seconds.'. P122: Google's chooser lists the email shown. P123: a sandbox subscriber reaches cancel in 2 taps, and Play's subscriptions page opens.
