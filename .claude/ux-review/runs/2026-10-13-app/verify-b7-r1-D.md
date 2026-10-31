## UX verify — 2026-10-13-app, batch b7, round 1, area D — 2026-10-14
**Verdict:** Ship after fixes. All three findings are fixed in code. Three small regressions: sign-out lost its progress indicator, the billing copy still tells people to "refresh" with a button that's gone, and the Pro screen's new file-space line contradicts the editor's "64 MiB per account".
**Evidence level:** code plus ux-tester's widget tests (es/en/ca, 2x text at 320 dp). There are no current renders of Account, Pro or Export: `App/artifacts/design/account-*.png` dates from 2026-09-22, older than the code, so it isn't evidence. Nothing here was run on a device.

### Results
- **UX-408 — fixed.** `App/lib/screens/account_screen.dart`:
  - the card and its 40-word paragraph are replaced by one `ListTile` reading `accountSaved` (EN "Saved to your account" / ES "Guardado en tu cuenta" / CA "Desat al teu compte") at :217-226;
  - `Sincronizar ahora` is now a `TextButton.icon` that shows its own spinner (:233-241);
  - the spinner at the bottom of the list is gone;
  - Import shows only when `localTaskCount() > 0` (FutureBuilder at :243-261; `cloud_task_repository.dart:38-39`), and the `noLocalItems` dead end is removed;
  - a failed sync replaces the saved line, once (:227-232). `loadTasks` never throws (`task_provider.dart:52-57`), so the lower banner can't repeat it;
  - `Detalles de conexión` shows only when `widget.debug` (default `kDebugMode`, :15, :262). Staging reaches it at `other_settings_screen.dart:151`;
  - sign-out asks first with `signOutQuestion`, using Cancelar and Cerrar sesión (:97-120), and the copy matches the brief in all three languages.
  - Counts: Account buttons go 4 (Sincronizar, Importar, Detalles, Cerrar sesión) → 2 (Sincronizar, Cerrar sesión) for a typical account; words in the sync area go about 45 → 3.
- **UX-423 — fixed (one device check left).**
  - Export: `data_transfer_screen.dart:151` shows `exportImportIntro`, one sentence in EN/ES/CA, and "proyectos de pasos" is gone.
  - Pro: `billingOpenStore`, `billingRefresh`, `billingStoreOpenError` and `_openStore` are removed (screen and ARB). Kept: `Ver suscripción` (:164-179, only without Pro), `Restaurar compras` (:191-199) and `Gestionar suscripción` (:200-211, after a purchase).
  - The status refreshes when the screen opens (:19-24) and on resume (`main.dart:120-123`).
  - Pro buttons for a past buyer go 5 → 3.
  - Left for a device: come back from the store and the status updates without a button.
- **UX-501 — fixed.** `subscription_screen.dart:45-67,124-130`:
  - a free account (not complimentary, not Pro, not loading) sees `freeVoiceStatus` with an ICU plural in ES/CA (EN reads naturally without one) and the reset date via `context.shortDate`, plus `storageUsage`, inside the status card;
  - Pro and complimentary accounts see neither;
  - `billingTestMode` now says unlimited dictation and file space (EN/ES/CA);
  - `voiceProRequired` and `voiceAccessUnavailable` are gone from all three ARBs and from `lib/` outside generated code.

### Regressions (only in changed files and their flows)
**R1D-1 · Severity 2 · Sign-out shows no progress for up to 12 s**
- Where: `App/lib/screens/account_screen.dart:280-289`, Account › Cerrar sesión › confirm.
- The moment: "I said yes. Did it work? Nothing's moving."
- What happens: the old spinner at the bottom of the list was removed. Sync and Import got in-button spinners, but sign-out didn't: `_running == _Action.signOut` only greys the button out. `AuthNotifier.signOut` waits on `POST auth/logout/` (12 s timeout, `api_client.dart:451-455`) before the screen changes. The Google-link path's `auth.loading` also lost its spinner, although `_Action.google` has its own bar.
- Why it fails: visibility of system status (Nielsen); anything over about 1 s needs visible progress (Miller 1968; Nielsen 1993).
- Fix: make sign-out a `TextButton.icon` whose icon is the same 18 dp `progress` while `_running == _Action.signOut` (none otherwise), matching Sync and Import. No new copy.
- Verify: widget test with a sign-out that never completes → a progress indicator sits inside the Cerrar sesión button.
- Evidence: verified in code.

**R1D-2 · Severity 2 · Billing copy says "refresh", but the button is gone**
- Where: `App/lib/l10n/app_en.arb:1530-1531`, `app_es.arb:1094-1095` and the matching CA lines. Keys: `billingError` (accountUnavailable, network) and `billingResult` (awaitingEntitlement). Shown on the Pro screen (`subscription_screen.dart:155-162`) and in its snackbars.
- The moment: "It says 'actualiza el estado'. Where? There's no button for that."
- What happens: P44 removed `Actualizar estado`, but three messages still send people to it:
  - EN: "…link your subscription, then refresh." / "Check your connection and refresh." / "refresh or restore purchases shortly."
  - ES: "…y actualiza el estado." / "…actualiza o restaura las compras en unos momentos."
- Why it fails: an error must say how to fix it with something that exists (Nielsen 2001); no dead ends (lens A).
- Fix: point to what exists — leaving and coming back refreshes, and Restore is a button:
  - accountUnavailable: EN "Connect to the TaskFlow server to link your subscription." / ES "Conéctate al servidor de TaskFlow para vincular tu suscripción." / CA needs Catalan translation (drop the refresh clause).
  - network: EN "Could not check your subscription. Check your connection and open this screen again." / ES "No se pudo comprobar tu suscripción. Revisa tu conexión y vuelve a abrir esta pantalla." / CA "No s’ha pogut comprovar la subscripció. Revisa la connexió i torna a obrir aquesta pantalla."
  - awaitingEntitlement: EN "Purchase received. Pro will turn on in a few moments; if it doesn’t, tap Restore purchases." / ES "Compra recibida. Pro se activará en unos momentos; si no, pulsa Restaurar compras." / CA "Compra rebuda. Pro s’activarà d’aquí a uns moments; si no, toca Restaura les compres."
- Verify: grep the three ARBs for refresh/actualiza/actualitza inside billing keys → no hits.
- Evidence: verified in code.

**R1D-3 · Severity 2 · Pro screen says 100 MB; the task editor says 64 MiB per account**
- Where: `subscription_screen.dart:62-66` (new `storageUsage` line, "Archivos: 3 de 100 MB usados") vs `fileUploadHelp` at `app_en.arb:920` (and ES :550, CA), shown in `widgets/task_editor.dart:369,817`.
- The moment: "Pro says I have 100 MB, the task says 64. Which is it? And I'm Pro — why a limit at all?"
- What happens: the editor's help predates the free-tier decision. It states a 64 MiB per-account cap to everyone, Pro included, in MiB. The new Pro-screen line now shows a different number in MB.
- Why it fails: consistency (Nielsen); one concept, one name and one number (ISO 24495-1).
- Fix: cut the per-account cap from `fileUploadHelp` — the usage line and `storageFull` (P91) already say it when it matters. EN "New files upload to your account after saving, up to 6 MB each. Older local files stay on this device until you choose Upload in task details." / ES "Los archivos nuevos se suben a tu cuenta al guardar, hasta 6 MB cada uno. Los archivos locales anteriores permanecen aquí hasta que elijas Subir en los detalles de la tarea." / CA needs Catalan translation. Use MB everywhere, as `storageUsage` does.
- Verify: grep the ARBs for "64 MiB" → none.
- Evidence: verified in code. The old number predates this round; the contradiction is new with P92's line, so the organizer may file it as a new issue rather than a regression.

### Checked, no regression
- The sign-out dialog has no title, only the question: one sentence, which is fine.
- Sign-out sits 20 dp below Sync and is red, so the two text buttons don't read as the same action.
- The Import row appears after its count loads, a small one-time shift; it disappears after a successful import because the count refreshes.
- A successful "Sincronizar ahora" no longer shows "Tus tareas y notas están actualizadas"; the persistent saved line stands in, as the brief asks.
- The free lines hide while billing loads, so a Pro user never sees them flash.
