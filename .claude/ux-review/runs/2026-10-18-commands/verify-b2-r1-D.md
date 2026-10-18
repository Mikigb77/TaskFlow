## UX verify — run 2026-10-18-commands, round 1, area D (P133, P134) — 2026-10-18
**Verdict:** Ship after fixes. All four findings are fixed. The new cold-start path brings in one minor dead end (a forgotten password) and three polish points.
**Evidence level:** I read the code (`git diff HEAD`) and the names and scope of the ux-tester's tests. No preview covers «Confirma tu correo»: `artifacts/auth/` holds only login-light/dark, re-rendered 22:05, and the sign-in screen doesn't look any different. I didn't run Flutter.

### Results
- **UX-1201 · fixed.**
  - `App/lib/screens/verify_email_screen.dart:109-112`: the `_steady` formatter is the first formatter on the code field (:494) and the only one on the password field (:537). `readOnly` is gone from both.
  - `autofocus` is removed (:479-486).
  - `_reveal` (:183-203) runs `ensureVisible` with keepVisibleAtEnd and then keepVisibleAtStart, with `Duration.zero` when animations are off. `_show` calls it after every line: short code, refused, offline, spent, «Te hemos enviado un código nuevo», and the password lines.
  - Tests: the keyboard stays visible from the 6th digit through the answer, and at 1.3× and 2× in ES and CA each line ends at or above y=440.
  - Phone only: whether Android's real keyboard drops.
- **UX-1203 · fixed.**
  - `code_expired` goes to `_signInInstead` (:291-292, :310-337) while `_confirming` stays true. A session opens the app. `EmailVerificationRequired` goes to `_codeSpent`. Any other answer shows under the code field through `requestProblemText(onSignIn: true)`, and `clearError()` stops sign-in behind the screen from also showing it.
  - Tests: Calendar opens and no expired line ever shows; «too many tries» stays on this screen.
  - Staging only: the lost-answer case.
- **UX-1204 · fixed.**
  - `_refused` (:86, :238-249, :294) re-shows the refusal and sends nothing. Confirmar, the keyboard's done action and the same six digits all pass through `_confirm`. Changing a digit clears the line (:210-217).
  - The copy matches in all three catalogs (`app_es.arb:450-452`, `app_ca.arb:429-431`, `app_en.arb:749-757`).
  - `verifyEmailCodeExpired` is gone, and the countdown is never cancelled. `_codeSpent` (:353-376): from 60 s on, it empties and focuses the field and restarts at 60. Under 60 s, it keeps `min(_wait, 60 − elapsed)`.
  - Tests cover 61 s, 20 s (→ 40 s), and 2× at 320×640 in ES, EN and CA.
- **UX-1202 · fixed.**
  - `App/lib/services/pending_verification.dart` stores only `{email, saved}` under one secure-storage key. It drops entries 30 minutes or older, and an unreadable entry.
  - `remember` runs when the screen opens from sign-up or sign-in (`login_screen.dart:209-212`), after Reenviar, and after a spent code that sent a new one.
  - `forget` runs on «Usar otro correo» (:614-624) and on `signup_replaced` with a password. `confirmed` runs on any sign-in to that address (`main.dart:369-375`).
  - The cold start (`login_screen.dart:63-77`) is skipped when `signInAgain` is set. It sends nothing: it only pushes the screen with `password: null`.
  - `verifyEmailWrongPassword` shows under the password field, both for `signup_replaced` and for the sign-in check's `credentials` answer.
  - Tests cover all five acceptance checks. The «No mantener actividades» run needs a phone.

### Regressions (only in the changed flows)
**R1D-1 · Severity 2 · Forgotten password on the resumed screen: no way forward**
- Where: `verify_email_screen.dart:340-350` (`_showWrongPassword`) and the `verifyEmailWrongPassword` line, on the screen a cold start reopens.
- The moment: "I made this password up a minute ago and I can't remember it. What now?"
- What happens: the line says only «Esa contraseña no es la de esta cuenta.» The ways out are Back, which goes to plain sign-in (where the password is still unknown), and «Usar otro correo», which re-creates the account with this address kept, but its label says *another* email. Before P134, a cold start landed on sign-in, which offers password recovery, and `signup_replaced` went back to «Crea tu cuenta» on its own.
- Why it fails: an error message should say how to fix the problem (Neusesser & Sunwall 2023), and the screen should have no dead ends (lens A).
- Fix: after the same password has been refused twice, add a second sentence under the field that names the way out:
  - EN: “That isn’t this account’s password. Don’t remember it? Tap “Use another email” and create the account again.”
  - ES: «Esa contraseña no es la de esta cuenta. ¿No la recuerdas? Toca «Usar otro correo» y crea la cuenta de nuevo.»
  - CA: «Aquesta contrasenya no és la d’aquest compte. No la recordes? Toca «Utilitza un altre correu» i torna a crear el compte.»
  - Alternatively, organizer's choice: show this sentence from the first refusal.
- Verify: on the cold-start screen, a second `signup_replaced` shows the longer line, and «Usar otro correo» lands on «Crea tu cuenta» with the address kept.
- Evidence: verified in code.

**R1D-2 · Severity 1 · Resumed screen times the code from when it reopened**
- Where: `verify_email_screen.dart:101-104`: `_sentAt = _now()` and a 60 s countdown on every open, including the cold-start one. `pending_verification.dart` stores `saved` but doesn't pass it on.
- What happens: the code went out minutes ago, yet «Reenviar código» stays off for 60 s.
  - Worse, a code spent within that minute gets «Toca «Reenviar código» cuando acabe la cuenta atrás», even though the sign-in check has just emailed a new code: the last one was minutes ago.
  - The person then taps Reenviar, which replaces that new code, and two emails arrive.
- Fix: `resume()` returns the saved time with the address, and `VerifyEmailScreen` takes an optional `sentAt`. `_sentAt` starts from it, and the countdown starts at `max(0, 60 − elapsed)`.
- Verify: resume 5 minutes after the sign-up. «Reenviar código» is on at once, and a `code_expired` + 403 answer shows «Te hemos enviado uno nuevo».
- Evidence: verified in code; rare (it needs a spent code).

**R1D-3 · Severity 1 · Sign-in flashes, then slides away**
- Where: `login_screen.dart:63-77`. `_resumeConfirming` awaits secure storage after LoginScreen's first frame, then pushes a `MaterialPageRoute` with its transition.
- What happens: «Inicia sesión» shows briefly, then «Confirma tu correo» slides in over it. For a moment the person is on the wrong screen and may start typing.
- Fix: read `resume()` while the session is restoring (`SessionLoadingScreen`), or push the resumed route without a transition.
- Evidence: inferred from the code, needs a device check.

**R1D-4 · Severity 1 · An old pending address reopens after signing out**
- Where: `main.dart:369-375`. `confirmed()` clears the entry only when the signed-in address matches it. `resume()` runs once per process, on the first plain LoginScreen.
- What happens: someone creates account A and leaves «Confirma tu correo» with Back. They then sign in as B (Google or password) and sign out within 30 minutes. The first LoginScreen of that process then opens «Confirma tu correo» for A.
- Fix: forget the pending entry on any successful sign-in, whatever the account, since a signed-in person no longer waits for a code.
- Evidence: verified in code; rare.

Out of my scope: `main.dart:204-205`, `showCalendar: true` on capture entries, belongs to another area's package.
