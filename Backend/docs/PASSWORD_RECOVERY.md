# Password recovery

A person who forgot their password asks for a code, gets a 6-digit code by email in the app's language, valid for 30 minutes, and types it in the app with a new password. It works like the sign-up code (`docs/EMAIL_VERIFICATION.md`). Approved by the owner on 2026-10-20 (UX-1602, whole-app plan `2026-10-19-app`).

Code: `core/password_reset.py` (codes, limits, the email) and the two views in `core/auth_views.py`. Tests: `core/test_password_recovery.py`.

## API

**`POST /api/auth/password-reset/`**: `{"email", "language"?}`.
- `language` is `"es"`, `"ca"` or `"en"`, and picks the email's language. A region such as `"ca-ES"` also works. Anything else, or none, is English. The app sends its own language.
- The answer is always `200 {"detail": "If that account exists, a recovery email has been sent."}`, whether or not the account exists, and whether or not a code went out (the limits below). That keeps the answer from saying who has an account.
- An active account with that address is emailed a new code, which replaces its last one. An unknown or deactivated address is sent nothing.
- The `recovery` rate limit applies: 5 requests an hour per client.

**`POST /api/auth/password-reset/confirm/`**: `{"email", "code", "password"}`.
- `code` is the 6 digits from the email. Spaces and hyphens are accepted, and so is a code sent as a JSON number.
- An `email` that isn't an email address answers `400` with the field's error, as verification does.
- It checks, in this order:
  1. **The code's form.** Anything but 6 digits answers `400 {"code": "code_invalid", "detail"}`, and spends no try.
  2. **The account and its code.** An unknown address, an address that asked for no code, a missing `email`, an expired code, or one locked after 5 wrong tries all answer `400 {"code": "code_expired", "detail"}`, without saying which.
  3. **The code itself.** A wrong code answers `400 {"code": "code_invalid", "detail"}`, and one of the 5 tries is spent.
  4. **The password**, with the same rules as sign-up. A weak one answers `400 {"password": ["…"]}`. The code stays good and untried, so the person can choose another password and send the same code again.
- A right code with a good password answers `200 {"detail": "Password updated. Sign in with your new password."}`, and then:
  - the password changes;
  - the address counts as confirmed (`mark_verified`), because the email proved it;
  - every session of the account ends, on every device, as before;
  - the code is used up, and any unsent email for it is cancelled;
  - sign-in's lock from earlier wrong passwords (5 wrong, then 15 minutes) is lifted, so the person can sign in with the new password straight away.
- The `auth` rate limit applies: 10 requests a minute per client.

The `code_invalid` and `code_expired` answers are the same as email verification's. The app shows its own words for them: any `400` whose body has a `code` key is a recovery-code error.

**Old codes.** Emails sent before 6-digit codes held a link and a long `uid:token` code. That code still works, without `email`: `{"code": "<uid>:<token>", "password"}`.
- Older app builds and the old web page (`/reset-password/`, `templates/reset.html`) send it this way.
- It's checked by Django's token generator as before: single use, valid for 30 minutes (`PASSWORD_RESET_TIMEOUT`).
- A bad or used one now answers `400 {"code": "code_expired", "detail"}` instead of `{"code": "<message>"}`. Older builds show the same message for both.
- New emails don't show it. So an older app build, which sends no `email`, can't use a new 6-digit code. It answers `code_expired`, as for an unknown address. Updating the app fixes that.
- `PASSWORD_RESET_BASE_URL` is no longer used by the code.

## The code

- Six random digits (`secrets`), valid for 30 minutes, locked after 5 wrong tries.
- Only a salted HMAC-SHA256 digest is stored (`salted_hmac`), bound to the account and compared in constant time. Its salt differs from the sign-up code's, so neither code can stand in for the other.
- One `PasswordReset` row per account, a new table (migration `0022_password_reset`). A new code replaces the last one, and the row goes once the password is set, by either kind of code. `manage.py maintain_staging` deletes rows whose code expired over an hour ago.
- The code is never logged.

**Why a new table, not the sign-up codes' table.** `EmailVerification` holds the code of an account that isn't confirmed yet, and confirming deletes it. A confirmed account asking for a recovery code, or an unconfirmed one asking for both, would mix two codes with different purposes and lifetimes in one row. A separate table keeps each flow's code, tries and limits apart, with no change to email verification.

**Sending limits per address:**
- at most 1 code a minute and 5 an hour, kept on the `PasswordReset` row;
- on top of those, the outbox's limits (`reserve_email`): 80 emails a day, 2,700 a month, and 8 a day to one recipient.

Past a limit nothing is sent, the last code keeps working, and the answer is the same `200`.

## The email

It goes through the outbox (`core/email_delivery.py`), like every other email. It sends from `DEFAULT_FROM_EMAIL`, the noreply address, with Reply-To `EMAIL_SUPPORT_ADDRESS` once the outbox sets it for every email. It has no link: the code is typed in the app.

| Language | Subject | Body |
|---|---|---|
| es | Tu código de recuperación de TaskFlow: 123456 | Tu código de recuperación de TaskFlow es 123456. Escríbelo en la aplicación para elegir una contraseña nueva. Caduca en 30 minutos. Si no lo has pedido, ignora este mensaje y tu contraseña seguirá igual. |
| ca | El teu codi de recuperació de TaskFlow: 123456 | El teu codi de recuperació de TaskFlow és 123456. Escriu-lo a l’aplicació per triar una contrasenya nova. Caduca d’aquí a 30 minuts. Si no l’has demanat, ignora aquest missatge i la contrasenya no canviarà. |
| en | Your TaskFlow recovery code: 123456 | Your TaskFlow recovery code is 123456. Type it in the app to choose a new password. It expires in 30 minutes. If you didn't ask for it, ignore this message and your password stays as it is. |

The words follow the app: its field is «Código de recuperación», “Recovery code”, «Codi de recuperació».

**Where the code's text lives**, as for sign-up codes:
- Until the email is sent, the outbox holds its text, code included.
- After sending, the outbox clears the body, and the subject becomes «TaskFlow recovery code».
- When a code is replaced or used, its email is cancelled if it's still unsent.

## Trying it locally

Ask for a code in the app, or in the local browser page with your email and a new password in its fields and **Recover account**. Read the code in Mailpit (http://localhost:8026) and type it. `scripts/smoke_test.py` does the same against the local Docker API.

## Known gaps

- The outbox's footer is in English, even on Spanish and Catalan emails.
