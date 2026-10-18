## UX review — D · Sign-up and email confirmation (run 2026-10-18-commands) — 2026-10-18

**Verdict:** Ship after fixes. The happy path is short: six digits confirm by themselves, and a pasted code works. But:
- at large text, the answer to a wrong code hides under the keyboard;
- the screen is lost if Android kills the app during the trip to the email;
- a lost answer can leave a confirmed account stuck on «ha caducado»;
- on the real server, a wrong password still reads «Vuelve a iniciar sesión».

**How I looked:**
- **Code and tests only.** I didn't run Flutter (this is inside the UX loop).
- **No preview renders «Confirma tu correo».** `App/artifacts/auth/login-light.png` and `login-dark.png` (15:50 today, newer than the 12:53 code change) show plain sign-in only.
- **Scope** (`git diff refs/ux-review/last`):
  - `App/lib/screens/verify_email_screen.dart` (new, read in full);
  - `login_screen.dart`, `auth_provider.dart`, `api_client.dart`, `main.dart`;
  - the 12 `verifyEmail*` keys in EN, ES and CA;
  - `App/test/email_verification_test.dart`, for what it covers.
- **Server:** `Backend/docs/EMAIL_VERIFICATION.md`, `Backend/core/auth_views.py` and `email_verification.py`, read only for what people see.
- **Flutter behaviour, checked in the local SDK (3.44.5):**
  - `editable_text.dart`: a read-only field hides the keyboard, and the caret reveal stops there;
  - `AccessibilityBridge.java`: a route with no name is announced blank;
  - `media_query.dart`: text scaling follows Android 14's non-linear curve.
- **Widths:** measured with Pillow and Manrope at weight 800. «Sign in» at 30 sp measures 92.4 dp, against about 91 dp in `login-light.png`.

**Walked**, as the newcomer (Spanish, 1.3–2× text, one hand), the daily user, and a TalkBack, low-vision or tremor user:
1. **Sign up by email to Calendar.** Crear una cuenta → email → password → Crear cuenta → «Confirma tu correo» → fetch the code from the email → 6 digits → Calendar.
2. **Sign in to an unconfirmed account.** Iniciar sesión → 403 `email_unverified` → the same screen → Calendar.
3. **Every state of the confirm screen:**
   - arrival with the keyboard open, and the 60-second wait;
   - Reenviar código, then «Te hemos enviado un código nuevo»;
   - a short code; a wrong code, repeated through Confirmar and through the keyboard's ✓;
   - expired and locked codes; offline; a lost answer after a success; throttled;
   - `signup_replaced` (back to «Crea tu cuenta»);
   - «Usar otro correo» from both ways in; system Back;
   - opened without the password (no flow does this);
   - the trip to the email app, with the app alive, frozen or killed;
   - the hourly code cap.
4. **Size and theme:**
   - 2× (linear) on 320 and 360 dp, in ES and CA;
   - 1.3× and 1.5× on 360×780 with a numeric keyboard of about 290 dp;
   - dark mode, from the theme's colours.

**Numbers:**
- **Taps to a confirmed account by email:**
  - 4 taps on the form, plus typing an email and a password of 12+ characters;
  - 2–3 taps to fetch the code (the notification shade or Gmail, then back to TaskFlow);
  - 6 digits, and no further tap.
  - By Google: 1 tap plus Google's account sheet.
- **Confirm screen:**
  - 4 tap targets: the code field, Confirmar, Reenviar (off for 60 s) and Usar otro correo;
  - 1 decision;
  - about 25 Spanish words, 15 of them before the field.
- **Wrong-code budget:** 5 tries. Confirmar and the keyboard's ✓ both resend the same refused digits. Pressing ✓ after each attempt spends 2 tries per mistake, so the code locks after 2–3 mistakes instead of 5.
- **At 1.3× on 360×780**, with the keyboard top at about 490 dp:
  - the field ends at about 432 dp;
  - the 3-line offline message ends at about 502 dp, so its last line is hidden;
  - Confirmar sits at about 505–560 dp and Reenviar at about 565 dp, both under the keyboard.
  - At 1.5× and above, everything below the field is under the keyboard.
- **The heading at linear 2×:** «Confirma» measures 266 dp, against 224 dp available at 320 dp and 264 dp at 360 dp. At Android 14's 200% (about 38 dp) it measures about 169 dp and fits.
- **The countdown's contrast:** about 2.2:1 in light and 3.3:1 in dark. `onSurfaceVariant` would give 5.3:1 and about 8:1.

### Findings (most severe first)

10 new findings (UX-1201 to UX-1210), plus UX-402, reopened. UX-402 is counted in the totals because it needs fixing.

**UX-402 · Severity 3 · Real server's wrong password reads as an ended session** (existing ID, reopened: its phone check would fail)
- **Where:**
  - `App/lib/l10n/request_locale.dart:80-82`: `credentials` matches only simplejwt's wording ("no active account", "invalid credentials").
  - `request_locale.dart:95`: any other 401 becomes `session`.
  - `App/lib/screens/login_screen.dart:320-325`: `unknownAccount` needs `credentials`.
  - **The server's answer:** `Backend/core/auth_views.py:173` returns 401 `{"detail": "Email or password is incorrect."}` (asserted in `Backend/core/test_email_verification.py:122-124`).
  - **State:** sign-in with a wrong password, or with an address that has no account. This includes the owner of an unconfirmed account who mistypes on the way to the code.
- **The moment:** «Me he equivocado en la contraseña y me dice que vuelva a iniciar sesión… ¡es lo que estoy haciendo!»
- **What happens:**
  - Under the button: «Vuelve a iniciar sesión para continuar. Tus tareas locales se conservan.»
  - No «Crear una cuenta con este correo» button (UX-402) and no recovery button (UX-488).
  - The app's tests pass because they fake simplejwt's wording ("No active account found with the given credentials", `App/test/auth_gate_test.dart:277`, `:600`, `:727`).
- **Why it fails:**
  - error messages say what happened and how to fix it (Nielsen 2001);
  - no dead ends (lens A);
  - match with the real world (Nielsen 1994).
- **Fix:** classify by status and endpoint, not by English text.
  - A 401 from `auth/login/` means wrong credentials, whatever its wording. For example, `ApiClient.signIn` rethrows it with a code that `requestProblem` reads before its generic 401 → `session` rule.
  - The copy stays: «No encontramos esa cuenta o la contraseña no es correcta.»
  - Make the auth tests fake the server's real answer.
- **Verify:**
  - **Test:** `auth_gate_test.dart` with 401 `{"detail": "Email or password is incorrect."}` shows the credentials line and «Crear una cuenta con este correo»; the UX-488 sequence shows «¿Has olvidado tu contraseña?».
  - **Phone, on staging:** a wrong password shows the same.
- **Evidence:** verified in code, app and server. Not seen on a device.

**UX-1201 · Severity 3 · After six digits, the answer hides under the keyboard**
- **Where:**
  - `App/lib/screens/verify_email_screen.dart:312` (`readOnly: _confirming`) and `:308` (`autofocus`);
  - `:330` (the error) and `:333-348` (the «resent» line);
  - nothing brings an answer into view after `_confirm` or `_resend` (`:192-201`, `:222-228`). Sign-in does, with `_reveal()` (`login_screen.dart:133-158`, UX-403).
  - **Flutter, in the local SDK:**
    - a read-only field closes its input connection, which hides Android's keyboard, and reopens it once it's editable again (`packages/flutter/lib/src/widgets/editable_text.dart:2609-2610`, `:3447-3455`; `services/text_input.dart:2314-2329`);
    - when the keyboard returns, only the caret plus 20 dp is scrolled into view (`editable_text.dart:4463-4533`), not the message under the field.
  - The comment at `:309-311` ("the keyboard stays up") is therefore wrong on Android.
- **The moment:** «He escrito el código, el teclado ha bajado y ha vuelto a subir… ¿ya está? No pasa nada.»
- **What happens:**
  - On the 6th digit the field turns read-only, and the keyboard drops.
  - On a refusal, the keyboard comes back and covers the message.
  - At 1.3× on 360×780: a 1–2-line message fits, but «No hay conexión. Revisa el wifi…» (3 lines) loses its last line, and the Confirmar spinner is hidden.
  - At 1.5× and above, the field itself sits at the keyboard's edge, so every message is under it: «Ese código no es correcto», «ha caducado», «Te hemos enviado un código nuevo».
  - On arrival, the open keyboard also hides «Reenviar código» and «Usar otro correo». Those are the way out for someone with no code yet, and the first thing to do on this screen is to leave it to fetch the code.
- **Why it fails:**
  - visibility of system status (Nielsen 1994);
  - the gulf of evaluation (Norman 2013);
  - change blindness (Rensink et al. 1997);
  - consistency with sign-in's UX-403 fix.
- **Fix:**
  1. **Keep the keyboard still while confirming.** Don't make the field read-only. Ignore edits until the answer instead, for example with a formatter that keeps the old value while `_confirming`. Correct the comment.
  2. **Bring every answer into view.** After an error, «El código tiene 6 cifras» or «Te hemos enviado un código nuevo», scroll the field and its message above the keyboard, as sign-in's `_reveal()` does. No animation when reduced motion is on.
  3. **Open without the keyboard** (`autofocus: false`).
     - The help still says «Escríbelo aquí», right above the field.
     - One tap on «Código» brings the keyboard, and Gboard's chip with the copied code.
     - Sign-up happens once, so the speed bar doesn't apply.
     - The test at `App/test/email_verification_test.dart:361` changes with this.
- **Verify:**
  - **Widget test:** with a 300 dp keyboard (`tester.view.viewInsets`), at 1.3× and 2× on 360×740, in ES and CA:
    - after `code_invalid`, `code_expired`, offline and Reenviar, the message's bottom is at or above 440 dp;
    - `tester.testTextInput.isVisible` stays true from the 6th digit to the answer;
    - on arrival nothing is focused, and Reenviar and Usar otro correo are on screen at 1.3×.
  - **Phone:** Spanish at 1.3× and 2×, type a wrong code. The keyboard doesn't drop, and the message shows above it.
- **Evidence:** verified in code (the screen and the Flutter SDK source). Positions come from layout arithmetic and Manrope measurements. Needs a device check.

**UX-1202 · Severity 3 · Going to read the email can lose the screen**
- **Where:**
  - `verify_email_screen.dart:30-38`: the password lives only in memory;
  - `login_screen.dart:191-207`: the screen is a plain pushed route, and nothing about it is stored;
  - `App/lib/main.dart:427-431`: a cold start without a session opens a blank sign-in.
  - **Server:** a sign-in or a new sign-up more than a minute after the last code emails a new code, which replaces the one in the inbox (`Backend/core/email_verification.py:89-124`; `auth_views.py:178`).
  - **State:** interrupted. The person switches to Gmail and Android kills TaskFlow (a low-memory phone), or they tap «Cerrar todo» in the recent-apps screen, a common habit.
- **The moment:** «He ido a mirar el correo y al volver me pide otra vez todo. ¿Dónde pongo el código?»
- **What happens:**
  - A blank «Inicia sesión»; nothing says a code is waiting.
  - The 12-character password they invented a minute ago must be typed again from memory.
  - Signing in, or creating the account again, sends a new code. The code they just read then gets «Ese código no es correcto».
- **Why it fails:**
  - interruptions lose nothing, and there's always a next step (lens I);
  - recognition over recall (Nielsen 1994);
  - working memory: the password and the code are carried across a restart (Cowan 2001).
- **Fix:**
  - **Remember the pending address, not the password.** Keep it from the moment the screen opens until the address is confirmed, «Usar otro correo» is tapped, or 30 minutes pass (the code's life).
  - **On a cold start** with no session and a pending address, open «Confirma tu correo» for it straight away. Its own password field already exists for this case (`:354-383`, tested at `email_verification_test.dart:727`). So the code in the inbox still works, and no new email is sent.
  - **In that branch, a `signup_replaced` answer most likely means a mistyped password.** Say so under the password field, and stay on the screen. Today it would leave with «Alguien ha vuelto a crear una cuenta…», which is false for a typo.
    - ES: «Esa contraseña no es la de esta cuenta.»
    - EN: "That isn't this account's password."
    - CA: «Aquesta contrasenya no és la d'aquest compte.»
- **Verify:**
  - **Widget test:**
    - open the screen, then rebuild the app with the same storage: «Confirma tu correo» opens for that address, with the password field;
    - after 30 minutes, or after «Usar otro correo», sign-in opens instead;
    - `signup_replaced` in that branch shows the line under the password field and stays.
  - **Phone:** turn on Developer options › «No mantener actividades». Create an account, open Gmail and come back. «Confirma tu correo» is there, and the emailed code works with the password.
- **Evidence:** verified in code that nothing survives a restart. How often Android kills the app here is inferred, and depends on the phone; needs a device check.

**UX-1203 · Severity 3 · A confirmed account is told «expired», and resending never arrives**
- **Where:**
  - `verify_email_screen.dart:185-201`: `code_expired` is shown as it comes;
  - `:205-239`: Reenviar.
  - **Server:**
    - an unknown or already confirmed address answers `code_expired` (`auth_views.py:118-122`);
    - resend answers 204 and sends nothing to a confirmed address (`:151-158`).
  - **State:**
    - the right code was accepted, but the answer never arrived: the 12-second timeout, or a dropped connection;
    - or the address was confirmed elsewhere, such as Google sign-in with the same address.
- **The moment:** «Dice que ha caducado. Le doy a Reenviar, dice que me lo ha mandado, y no llega nada. Ya van tres veces.»
- **What happens:**
  1. «No hay conexión…»
  2. Confirmar again gives `code_expired`: «Ese código ha caducado. Pide uno nuevo.»
  3. Reenviar código gives «Te hemos enviado un código nuevo», and nothing ever arrives.
  - The only way out is «Usar otro correo» → Crear cuenta → «Ya existe una cuenta con este correo» → «Iniciar sesión con este correo» → Iniciar sesión. That route contradicts everything the screen said.
- **Why it fails:**
  - no dead ends (lens A);
  - feedback must be true (the gulf of evaluation, Norman 2013);
  - error recovery (Nielsen 1994).
- **Fix:** on `code_expired`, sign in with the address and the password the screen holds, before showing anything.
  - Signed in: the app opens, as after the right code.
  - `email_unverified`: the code really is spent. Go on to UX-1204's expired line. That sign-in has just emailed a fresh code, if the server's one-a-minute limit allowed it.
  - Any other answer: today's message.
  - Package this with UX-1204.
- **Verify:** widget tests.
  - Verify answers `code_expired` and login answers a session: Calendar opens, with no expired line.
  - Login answers 403 `email_unverified`: UX-1204's line shows.
- **Evidence:** verified in code, app and server. Rare: it needs a lost answer or a confirmation elsewhere.

**UX-1204 · Severity 2 · After a refused code, the screen points the wrong way**
- **Where:**
  - `verify_email_screen.dart:385-389`: Confirmar stays live with the refused digits;
  - `:327`: the keyboard's ✓ submits them too;
  - `:196-199`: the countdown is cancelled on `code_expired`.
  - **Copy:** ES `App/lib/l10n/app_es.arb:450-451`; EN `app_en.arb:741-747`; CA `app_ca.arb:429-430`.
  - **Server:**
    - every wrong try counts, and 5 lock the code, which is then reported as `code_expired` (`auth_views.py:137-145`);
    - one code a minute at most, and resend drops extra requests silently (`email_verification.py:22`, `:133-141`).
- **The moment:** «Ponía que no es correcto; le he vuelto a dar a Confirmar por si acaso… y ahora dice que ha caducado. ¡Si me acaba de llegar!»
- **What happens:**
  - Confirmar or ✓ on the same digits spends another try. After 5, a code that arrived a minute ago is «caducado».
  - «Pide uno nuevo» names an action the screen calls «Reenviar código»: one concept, two names.
  - On `code_expired`, Reenviar is enabled at once. Within a minute of the last code, the server sends nothing while the app says «Te hemos enviado un código nuevo».
  - «Ese código no es correcto» doesn't say what to do. And with several code emails (a resend, or signing in again as in UX-1202), only the newest works.
- **Why it fails:**
  - error prevention (Nielsen 1994);
  - error messages say how to fix it (Nielsen 2001);
  - one concept, one name (ISO 24495-1).
- **Fix:**
  1. **Don't resend refused digits.** Remember the last refused code. Confirmar or ✓ on the same digits sends nothing and leaves the message as it is. Changing a digit clears it, as today.
  2. **«No es correcto» says what to do:**
     - ES: «Ese código no es correcto. Mira el último correo que te hemos enviado.»
     - EN: "That code isn't right. Check the newest email we sent."
     - CA: «Aquest codi no és correcte. Mira l'últim correu que t'hem enviat.»
  3. **Expired or locked**, after UX-1203's sign-in check:
     - **At least 60 s since this screen's last code.** That sign-in has sent a new one. Empty and focus the field and restart the countdown, as after Reenviar.
       - ES: «Ese código ya no sirve. Te hemos enviado uno nuevo.»
       - EN: "That code no longer works. We've sent you a new one."
       - CA: «Aquest codi ja no serveix. T'hem enviat un codi nou.»
     - **Within the 60 s.** Keep the countdown; never cancel it.
       - ES: «Ese código ya no sirve. Pide otro cuando acabe la cuenta atrás.»
       - EN: "That code no longer works. Ask for another when the countdown ends."
       - CA: «Aquest codi ja no serveix. Demana'n un altre quan acabi el compte enrere.»
- **Verify:** widget tests.
  - After `code_invalid`, Confirmar and `TextInputAction.done` send no second request.
  - `code_expired` 61 s after the code: the new-code line, an empty field and a 60-second countdown.
  - `code_expired` 20 s after the code: the other line, and about 40 s left.
  - The copy in ES, EN and CA at 2× on 320 dp.
- **Evidence:** verified in code, app and server.

**UX-1205 · Severity 2 · Nothing helps the person whose email never comes**
- **Where:**
  - `verify_email_screen.dart:291-300`: the address sits inside a grey 14 sp sentence;
  - `:333-348`: the «resent» line;
  - `login_screen.dart:191-207`: `_mode(register: true)` focuses nothing after «Usar otro correo».
  - **Copy:** ES `app_es.arb:443`, `:449`.
  - **State:** the address has a typo (ana@gmial.com), or the code landed in Spam or Promotions.
- **The moment:** «No me ha llegado nada.» Reenviar, Reenviar… then they give up. The account wall means no app at all.
- **What happens:**
  - The only clue to a typo is the address, in grey, in the middle of a sentence.
  - After Reenviar, «Te hemos enviado un código nuevo» repeats the same promise.
  - «Usar otro correo» lands on «Crea tu cuenta» with nothing focused.
- **Why it fails:**
  - people scan, so the key word must stand out (Nielsen 1997);
  - recognition over recall (Nielsen 1994);
  - teach at the moment it's needed (Carroll & Rosson 1987).
- **Fix** (no new controls):
  1. **The address stands out.** Show it in bold, in `onSurface`, inside the same sentence: split the translated string at the address. The copy doesn't change.
  2. **The «resent» line gives the hint**, at the moment someone shows they didn't get the email:
     - ES: «Te hemos enviado un código nuevo. Si no lo ves, mira en Spam o en Promociones.»
     - EN: "We've sent you a new code. If you can't see it, check Spam or Promotions."
     - CA: «T'hem enviat un codi nou. Si no el veus, mira a Correu brossa o a Promocions.» These are Gmail's Catalan folder names; a native read would help.
  3. **«Usar otro correo» lands ready to fix the address:** the email field focused, with the cursor at the end.
- **Verify:**
  - **Widget test:**
    - the address is a bold span;
    - after Reenviar, the line reads the new copy in ES, EN and CA, at 2× on 320 dp, above the keyboard (UX-1201);
    - after «Usar otro correo», the email field has focus.
  - **Phone:** with a fresh Gmail account, check where the code lands: Primary, Updates or Spam.
- **Evidence:** verified in code. Where emails land is inferred; needs a device check.

**UX-1206 · Severity 2 · «New code sent» shows when nothing was sent** (cause likely server-side)
- **Where:**
  - `verify_email_screen.dart:215-228`: any 204 shows «Te hemos enviado un código nuevo».
  - **Server:** resend always answers 204 (`auth_views.py:151-158`).
    - It sends nothing past 5 codes an hour (`email_verification.py:23`, `:84-85`) or 8 emails a day to one address (`Backend/core/email_delivery.py:76`).
    - Codes sent by sign-in count too.
  - **State:** a person who didn't get the email and keeps asking. Sign-up (1), Reenviar three times, then a sign-in: the next request is the 6th in the hour.
- **The moment:** «Me dice que me ha mandado un código nuevo, pero no llega nada.»
- **What happens:**
  - The app says the code was sent; nothing comes.
  - Every minute the button invites another empty try, for the rest of the hour.
- **Why it fails:**
  - visibility of system status: the feedback must be true (Nielsen 1994);
  - the gulf of evaluation (Norman 2013).
- **Fix:**
  - **Server:** when this address's own limit blocks a code, the resend should say so: 429 with `Retry-After`, as sign-up already does.
  - **App:** show the wait, and keep Reenviar off until then. Use plural forms.
    - ES: «Has pedido muchos códigos. Espera {n} minutos para pedir otro.»
    - EN: "You've asked for a lot of codes. Wait {n} minutes to ask for another."
    - CA: «Has demanat molts codis. Espera {n} minuts per demanar-ne un altre.»
  - The trade-off is the owner's (see the questions).
- **Verify:**
  - **Server test:** the 6th code in an hour answers 429 with `Retry-After`.
  - **App test:** a resend answered 429 with `Retry-After: 1800` shows «Espera 30 minutos…», and Reenviar stays off.
- **Evidence:** verified in code, app and server. How often it happens is inferred.

**UX-1207 · Severity 2 · TalkBack hears no screen name on arrival**
- **Where:**
  - `verify_email_screen.dart:280-289`: the heading has `header: true` but no `namesRoute`, and there's no AppBar.
  - **Flutter's Android bridge:** a route with no name gets a blank title, which "focus[es] the first semantics node without pronouncing any word" (`engine/src/flutter/shell/platform/android/io/flutter/view/AccessibilityBridge.java:2167-2188`, local SDK). Here that first node is the «taskflow» brand.
  - `:397-404`: Confirmar's spinner has no label.
- **The moment (TalkBack):** after «Crear cuenta», silence. Swiping gives «taskflow», then the heading, then the help: three swipes before they learn there's a code to fetch.
- **Why it fails:**
  - name, role and value (WCAG 2.2, 4.1.2);
  - visibility of system status (Nielsen 1994).
- **Fix:**
  - **Name the screen:** `namesRoute: true` on the heading's `Semantics`, so TalkBack says «Confirma tu correo» as the screen opens. The same one-line change would serve sign-in's heading.
  - **Label the spinner**, as UX-513 did: «Confirmando» (ES), "Confirming" (EN), «S'està confirmant» (CA).
- **Verify:**
  - **Semantics test:** the heading node names the route, and the spinner has its label.
  - **Phone:** TalkBack says «Confirma tu correo» when the screen opens.
- **Evidence:** verified in code (the app and the Flutter engine source). What TalkBack says needs a device check.

**UX-1208 · Severity 1 · «Demasiadas solicitudes. Espera un poco» never says how long**
- **Where:**
  - `verify_email_screen.dart:119` uses `requestProblemText`'s `rateLimit` for any 429 (`request_locale.dart:97`; `app_es.arb:24`).
  - **The same line elsewhere:**
    - «Crea tu cuenta» after a new password within the minute: register answers 429 (`auth_views.py:92-98`);
    - sign-in's 15-minute lock ("Too many failed attempts. Try again in 15 minutes.", `auth_views.py:166-167`).
- **The moment:** «"Demasiadas solicitudes"… ¿qué solicitudes? ¿Cuánto es "un poco"?»
- **Why it fails:**
  - plain language: no "solicitudes" (ISO 24495-1);
  - error messages say what to do (Nielsen 2001);
  - consistency: UX-809 already fixed this on the delete page.
- **Fix:**
  - Use the wait in `ApiException.retryAfter` (rounded up, at least 1 minute) with the delete page's wording, moved to a shared key.
    - ES: «Demasiados intentos. Espera {n, plural, =1{un minuto} other{{n} minutos}} y vuelve a intentarlo.»
    - EN: "Too many tries. Wait {n, plural, =1{a minute} other{{n} minutes}} and try again."
    - CA: needs a Catalan translation, following `deleteAccountThrottledWait`.
  - Use it on the confirm screen, on «Crea tu cuenta» and on sign-in.
- **Verify:** tests.
  - Confirmar answered 429 with `Retry-After: 42` shows «…Espera un minuto…».
  - Sign-in's 429 with `Retry-After: 900` shows «…15 minutos…».
- **Evidence:** verified in code. Rare on this screen.

**UX-1209 · Severity 1 · At 2× text, the heading breaks «Confirma» mid-word**
- **Where:** `verify_email_screen.dart:283-288`: 30 sp, weight 800, scaled with the text size. Sign-in's headings share the style (`login_screen.dart:387-396`).
- **What happens:**
  - At linear 2× (60 sp), «Confirma» measures 266 dp. The card leaves 224 dp at 320 dp and 264 dp at 360 dp, so ES and CA show «Confirm/a». EN "Confirm" (233 dp) breaks at 320 dp.
  - Sign-in already breaks «contraseña» (328 dp) and «contrasenya» (361 dp) the same way.
  - Android 14 and later scale this heading to about 38 dp at 200%, where it fits. So the break shows only with linear scaling: Android 13 and older at an OEM's or adb's 2.0.
  - The 2× test checks `didExceedMaxLines`, not word breaks (`email_verification_test.dart:878-890`).
- **Why it fails:** text at 2× without loss (lens L); a broken word costs older readers the most (Nielsen 2013).
- **Fix:** scale the auth headings by at most 1.2× (`textScaler: MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.2)`).
  - That's 36 dp, still above body text at 2× (28 dp), and close to Android 14's own curve.
  - Every heading word then fits in 224 dp, including «contrasenya» (216 dp).
- **Verify:** at linear 2× on 320 dp, in ES, EN and CA, every heading line on the confirm screen and sign-in ends at a space.
- **Evidence:** measured (Pillow and Manrope at weight 800, matched to the render within about 1 dp).

**UX-1210 · Severity 1 · Resend countdown: faint, freezes in background, touches the exit**
- **Where:**
  - `verify_email_screen.dart:418-442`: two TextButtons with no gap between them, and the disabled style at 38% `onSurface`;
  - `:88-95`: `_wait--` once per tick.
- **The moment:** «No leo ese gris.» Or: «He vuelto del correo hace dos minutos y aún me hace esperar 47 segundos.»
- **What happens:**
  - **Faint:** «Reenviar código en 42 segundos» is about 2.2:1 on the white card and 3.3:1 in dark. WCAG exempts disabled controls, but this label carries the screen's only "when".
  - **Frozen:** Android freezes background apps, and a periodic Dart timer then fires once on return. So the countdown resumes where it stopped, long after the server's minute has passed.
  - **Touching:** «Reenviar código» and «Usar otro correo» are 48 dp each, with 0 dp between them. A slip on the disabled countdown can land on the button that leaves the screen.
- **Why it fails:**
  - contrast and older eyes (WCAG 2.2, 1.4.3; Nielsen 2013);
  - visibility of system status (Nielsen 1994);
  - target spacing (Material 3).
- **Fix:**
  - Show the countdown in `onSurfaceVariant` while waiting (`disabledForegroundColor`): 5.3:1 light, about 8:1 dark.
  - Compute the wait from the time the code was sent (60 − elapsed), not by counting ticks.
  - Put 8 dp between the two buttons.
- **Verify:**
  - **Test:**
    - the waiting label's colour is `onSurfaceVariant` in both themes;
    - with the clock moved 120 s ahead, the button reads «Reenviar código»;
    - the gap is at least 8 dp.
  - **Phone:** go to Gmail for 2 minutes and come back. Reenviar is ready.
- **Evidence:** verified in code; contrast computed. The freezing is inferred from Android's cached-apps freezer; needs a device check.

### Keep
- **Six digits confirm by themselves**, and a pasted «Tu código: 654 321» keeps only its digits. There's no Confirmar tap on the normal path.
- **The code is in the email's subject** («Tu código de TaskFlow: 123456»), so the phone's notification shows it without opening the email.
- **The password just typed goes with the code.** Nothing to type again, and nothing saved.
- **Answers stay under the field, with the digits kept.** `signup_replaced` returns to «Crea tu cuenta» with the email kept and the reason in view, read once.
- **One filled button, 4 targets and about 25 words.** And Google, first on the form, skips the code entirely.

### Progress against UX_REVIEW.md (U1–U14)
- **U14 holds.** Google stays first on sign-in and create, and Google accounts never see a code. The email path is now one screen and one trip to the inbox longer, by the owner's decision of 2026-10-18.
  - UX-402 (sign-in without an account) has never held against the real server; reopened above.
- **Unchanged:** no other U-item is touched by this slice. U10 and U13 remain decisions.

### Questions for the owner
1. **Should «Reenviar código» admit when no code was sent?** (UX-1206)
   - Today the server answers the same either way, so someone past 5 codes an hour is told «Te hemos enviado un código nuevo» each time.
   - A 429 with the wait lets the app say «Espera N minutos». But it tells anyone who keeps pressing resend that an unconfirmed sign-up exists for that address.
   - **Recommendation:** yes. The person on the screen typed that address, and the information is worth little to anyone else.
2. **An «Abrir el correo» button on the confirm screen?**
   - It would open the phone's email app, the step a newcomer is most likely to get lost on.
   - It adds a control, and Gmail's notification already shows the code in its subject.
   - **Recommendation:** not now. Watch for it in the §7 test, with an email sign-up rather than Google.

### Cross-slice notes
- **Server:** the code email's footer is in English in ES and CA. This is a known gap in `Backend/docs/EMAIL_VERIFICATION.md`.
- **UX-484 and UX-488:** their phone checks fail for UX-402's reason, because both depend on `credentials`.

### Memory notes
- **Flow map:**
  - Sign-up (register answers `verification_required`) or sign-in (login answers 403 `email_unverified`) pushes `VerifyEmailScreen`, a `MaterialPageRoute` with no AppBar.
  - The right code rebuilds the app (MaterialApp keyed by session) and lands on Calendar.
  - The screen pops `VerifyEmailReturn.otherAddress` or `.replaced` to «Crea tu cuenta», with the email kept. `.replaced` also clears the password and shows `verifyEmailReplaced`.
  - Its password-field branch exists, but no flow opens it.
- **Auth screen pattern:**
  - `AuthBrand`, an `authCardDecoration` card and a 30 sp heading at weight 800, with no AppBar, so no TalkBack route name;
  - errors sit under their fields;
  - sign-in's `_reveal()` scrolls answers into view (UX-403).
- **Recurring: error mapping keys on the server's English text** (`App/lib/l10n/request_locale.dart`).
  - The auth tests fake simplejwt's wording, while the real login says "Email or password is incorrect."
  - Check `Backend/core/auth_views.py`'s strings whenever `requestProblem` is involved.
- **Recurring: some endpoints answer 204 or 200 whatever happened** (verification resend, password reset). The app's «sent» lines can't be verified from the app.
- **Flutter facts** (local SDK 3.44.5):
  - `readOnly` on a focused field hides Android's keyboard, and reopens it afterwards;
  - the caret reveal covers only the caret plus 20 dp;
  - a route with no name is announced blank;
  - text scaling follows Android 14's non-linear curve (30 sp is about 38 dp at 200%).
- **Tools:** Pillow loads only without `python -I`, because it lives in the user site-packages. Manrope measurements at weight 800 match the renders within about 1 dp.
