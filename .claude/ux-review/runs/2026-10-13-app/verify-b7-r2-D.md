## UX verify — 2026-10-13-app, b7 round 2, area D (P96) — 2026-10-14

**Verdict:** all three findings fixed in code; one small new inconsistency (R2D-1, S1).
**Evidence:** code and ux-tester widget/unit tests. No preview renders Account, the Pro screen or the task editor's file sheet (newest PNGs in App/build/ are calendar, review and capture), so there's no render evidence. Sign-out on a slow network still needs a phone.

### Results
- **UX-508 · fixed (device check pending).** `App/lib/screens/account_screen.dart:284-299`: Cerrar sesión is now `TextButton.icon`. While `_running == _Action.signOut` its icon is an 18 dp `CircularProgressIndicator(strokeWidth: 2, color: colors.error)`; otherwise it's `null`. In Flutter 3.44.5, `TextButton.icon` with `icon == null` sets `_addPadding = false` (text_button.dart:123), so the button at rest looks the same as before. The label keeps `colors.error`. `busy` turns `onPressed` off while sign-out runs. The confirm dialog, Sync, Import and the Google path are unchanged by P96. The indicator stays until `AuthNotifier.signOut` sets `AuthState()` and the screen becomes LoginScreen. If it fails, `_run` clears it and shows the banner. Tests pass in light and dark.
- **UX-509 · fixed.** The three branches match the plan copy exactly: app_en.arb:1530-1531, app_es.arb:1094-1095, app_ca.arb:788-789. The other branches are unchanged. 'network' now says to open the screen again, and that works: `SubscriptionScreen.initState` calls `refresh()` (subscription_screen.dart:21-23). 'awaitingEntitlement' names the button by its real label (`billingRestore`: Restore purchases / Restaurar compras / Restaura les compres). That button is on the same screen whenever the account isn't complimentary (subscription_screen.dart:191-199). The plan's literal grep can't pass, because the kept 'other' and 'updated' branches use actualizar and actualitzar to mean "update". Neither asks anyone to refresh, so this isn't a defect.
- **UX-510 · fixed.** `fileUploadHelp` reads "…up to 6 MB each." with no per-account cap in EN (app_en.arb:920), ES (app_es.arb:550) and CA (app_ca.arb:529). The generated getters match (app_localizations_es.dart:1878-1879). It no longer contradicts the Pro screen's "Archivos: N de 100 MB usados".

### Regressions
**R2D-1 · S1 · The file-size limit is "6 MB" in one place and "6 MiB" next door**
- Where: app_en.arb:921-922, app_es.arb:551-552, app_ca.arb:530-531 (`fileLocalHelp`, `fileLimit`), and the `fileLimit` branch of `requestError` (app_en.arb:43, app_es.arb:24, app_ca.arb:25).
- The moment: "It said 6 MB a moment ago. Now it says 6 MiB — is that a different limit?"
- What happens: task_editor.dart:367-369 and :816-817 show `fileLocalHelp` or `fileUploadHelp` in the same spot, depending on whether the files are local. One now says "6 MB" and the other "6 MiB". The too-big snackbar (`fileLimit`, task_editor.dart:351 and :410) also says "6 MiB". P96 changed only one of these sibling strings.
- Why it fails: one concept, one name (ISO 24495-1). Consistency (Nielsen #4). "MiB" is also jargon to the newcomer.
- Fix: in all three ARB files, change "6 MiB" to "6 MB" in `fileLocalHelp`, `fileLimit` and `requestError.fileLimit`. EN: `…Up to 6 MB per file.` / `Choose a non-empty file up to 6 MB. You can attach up to 20 files per task.` / `Choose a non-empty file up to 6 MB.` ES: `…Hasta 6 MB por archivo.` / `Elige un archivo no vacío de hasta 6 MB. Puedes adjuntar hasta 20 archivos por tarea.` / `Elige un archivo no vacío de hasta 6 MB.` CA: `…Fins a 6 MB per fitxer.` / `Tria un fitxer no buit de fins a 6 MB. Pots adjuntar fins a 20 fitxers per tasca.` / `Tria un fitxer no buit de fins a 6 MB.` Leave request_locale.dart:98 alone: its `'6 mib'` matches server text, not app copy.
- Verify: grep for "MiB" across App/lib/l10n/app_*.arb returns nothing.

### Not regressions (noted)
- The sign-out spinner has no `semanticsLabel`, so TalkBack only hears "Cerrar sesión, disabled". The Sync and Import spinners from P44 work the same way. This is no worse than before P96, so it's not counted here.
- 'accountUnavailable' still says "Connect to the TaskFlow server", which is technical wording. It's the copy the plan set, and the old text said the same.
