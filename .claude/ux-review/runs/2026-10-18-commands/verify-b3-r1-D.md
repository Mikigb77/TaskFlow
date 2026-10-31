## UX verify — run 2026-10-18-commands, round 1, area D (P143, P144) — 2026-10-19

**Verdict:** all five findings fixed in code and in current renders; no regressions caused by the change.
**Evidence level:** code read (`git diff HEAD`), renders in `App/build/ux/auth/` and `App/build/ux/form/` (03:36–03:37 on 2026-10-19; `find App/lib App/assets -newer <png>` lists nothing, so they are current), and ux-tester's widget tests. No device.

### Results

| ID | Result | Evidence |
|---|---|---|
| UX-1205 | fixed | `verify_email_screen.dart:440-460` `_help()` splits `verifyEmailHelp(email)` at the address into a bold (w700) `onSurface` span; sentence unchanged, falls back to plain text if the address isn't found. `verifyEmailResent` new copy in all three ARBs (EN «We’ve sent you a new code. If you can’t see it, check Spam or Promotions.», ES «…Si no lo ves, mira en Spam o en Promociones.», CA «…Si no el veus, mira a Correu brossa o a Promocions.»). `login_screen.dart:239-245`: on `otherAddress`, cursor collapsed at the end and the email `FocusNode` focused after the frame. Renders: `verify-email.resent.es.light.2x.png` (bold address, whole hint line under the field), `verify-email.code-entry.es.light.1x.png`, `…ca.light.2x.png`. Phone + native: where Gmail files the code; read of «Correu brossa» / «Promocions». |
| UX-1207 | fixed | New `AuthHeading` (`login_screen.dart:878-896`): `Semantics(container, header, namesRoute)`; used by the confirm screen (`verify_email_screen.dart:501`) and sign-in's heading (`login_screen.dart:437`). Confirmar's spinner has `semanticsLabel: l.verifyEmailConfirming` (`verify_email_screen.dart:619-623`); key in all three ARBs with an @description. Phone: TalkBack's announcement on open. |
| UX-1209 | fixed | `AuthHeading` clamps the scaler to 1.2× (30 sp → 36 at 2×). Renders: «Confirma tu / correo» (ES 2×), «Confirma el teu / correu» (CA 2×), «Inicia sesión» (ES 2×), recovery heading ends «contraseña» whole — all break at spaces. Heading still larger and bolder than 2× body (28). |
| UX-1210 | fixed | `verify_email_screen.dart:645-650`: while waiting, `disabledForegroundColor: colors.onSurfaceVariant` (render: dark grey, readable). `_countDown` (`:145-156`) keeps `_readyAt` by the clock and takes `min(clock-left, seconds - timer.tick)`, so a frozen-then-resumed app catches up on the first tick and a clock set back can't lengthen the wait; `initState` (`:112-116`) still starts from `_sentAt`. `SizedBox(height: 8)` between Reenviar and Usar otro correo (`:659`); visible gap in `verify-email.code-entry.es.light.1x.png`. Phone: 2 minutes in Gmail, come back. |
| UX-1012 | fixed | `app_theme.dart:153` `chipTheme.side` → `scheme.outline`; nothing else changed. Renders: `form/new-task.long-title.es.light.2x.png` and `form/new-task.filled.es.dark.1x.png` show clear borders on Hoy / Mañana / Elegir día / Añadir hora. Phone: light and dark on a real screen. |

### Regressions
None found in the changed files or the flows they touch (sign-up → confirm → resend → use another address; sign-in / create / recover headings; every chip via the theme).

Checked and not raised:
- The Confirmar button's merged TalkBack label while confirming reads «Confirmando Confirmar» — slightly redundant, but it's what the brief asked for (same pattern as UX-513) and it's the only signal of progress for a TalkBack user.
- The theme border now also outlines selected chips (grey line around the tint); it did before with `outlineVariant`, only fainter. Cosmetic, consistent everywhere.
- Catalan address wraps mid-word at 2× («maria.lopez@exam / ple.com»); same wrapping as before the change, only now bold. An address has no spaces to break at.
- Sign-in's heading changes text across sign-in / create / recover inside one route; TalkBack won't re-announce on a mode switch. Not a regression (it had no route name before).
- «Correo elect…» truncated field labels at 2× in the sign-in renders are older than this change.

### Still for the owner's phone
TalkBack on opening «Confirma tu correo»; Reenviar ready after 2 min in Gmail; where Gmail files the code and a native read of the Catalan folder names; chip borders in light and dark.
