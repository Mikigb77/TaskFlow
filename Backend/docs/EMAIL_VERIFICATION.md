# Email verification

A password sign-up must confirm its email before it can sign in. TaskFlow emails a 6-digit code, valid for 30 minutes. Owner decision, 2026-10-18 (`.claude/ux-review/DECISIONS.md`).

Code: `core/email_verification.py` (codes, limits, the email), the views in `core/auth_views.py`, and `core/google_auth.py`. Tests: `core/test_email_verification.py`.

## Settings

Neither setting is in `config/settings.py` yet. The code reads them with `getattr` and a default.

| Setting | Default | Effect |
|---|---|---|
| `EMAIL_VERIFICATION_REQUIRED` | `True` | Off: sign-up and sign-in work exactly as before. `config/test_settings.py` turns it off for the older tests. |
| `STAGING_INVITE_ONLY` | `False` | Staging only. On: brings back the invited-testers gate, so only the allowlist or a live invitation can sign up. |

## API

All four endpoints use the `auth` rate limit (10 a minute).

**`POST /api/auth/register/`**: `{"email", "password", "first_name"?, "timezone"?, "language"?}`.
- `language` is `"es"`, `"ca"` or `"en"`, and picks the email's language. A region such as `"es-ES"` also works.
- New address: creates the account unconfirmed, emails a code, and answers `201 {"verification_required": true, "email": "<normalised email>"}`, with no tokens.
- Address of an account that was never confirmed: replaces it, because nobody could sign in to it. It gets the new password, name and time zone, any sessions end, and a new code is sent. Same `201` answer. The earlier sign-up's verify then answers `signup_replaced`.
  - Within the sending limits' wait, the same password again answers `201` and keeps the code already sent. A different password answers `429` and changes nothing.
- Confirmed account: `400 {"email": ["An account with this email already exists."]}`.
- No code can be sent (the outbox limits below): `429`, and nothing is created or changed.
- Verification off: `201` with `access`, `refresh` and `user`, as before.

**`POST /api/auth/login/`**: as before, except for the right password on an unconfirmed account.
- That answers `403 {"code": "email_unverified", "detail", "email"}` and emails a fresh code if the limits allow. Otherwise it skips the email quietly.
- A wrong password answers exactly as before, so sign-in never tells anyone whether an account exists.
- An optional `language` works as for register.

**`POST /api/auth/verify-email/`**: `{"email", "code", "password"}`. The app sends the password the person just typed, whether they came from sign-up or from sign-in's `email_unverified`.

It checks, in this order:
1. **Sign-in's lock**, when a password is sent. After five wrong passwords, at sign-in or here, it answers `429` for 15 minutes.
2. **The account.** An unknown address, or one already confirmed, answers `400 {"code": "code_expired", "detail"}`.
3. **The password**, checked as sign-in checks it. A wrong or missing password answers `400 {"code": "signup_replaced", "detail"}`: the address was signed up again with another password (see below).
   - It spends no code try and confirms nothing.
   - A wrong password counts toward sign-in's lock, as on the delete-account page; a missing one doesn't.
   - An unconfirmed account without a usable password, which only server code can make, skips this step.
4. **The code:**
   - right: the account is confirmed, and the answer is `200` with what sign-in returns (`access`, `refresh`, `user`);
   - wrong: `400 {"code": "code_invalid", "detail"}`, and one of the 5 tries is spent;
   - expired, or locked after 5 wrong tries: `400 {"code": "code_expired", "detail"}`, without saying which.

Spaces, hyphens and a code sent as a JSON number are accepted.

**`POST /api/auth/verify-email/resend/`**: `{"email", "language"?}`.
- `204` when a new code is on its way, and for any address with no unconfirmed account: an unknown address or a confirmed one gets `204` and nothing is sent.
- For an unconfirmed account past a limit (below), nothing is sent and the answer is `429 {"code": "resend_limited", "retry_after": <seconds>, "detail"}`, with a `Retry-After` header. The app then says how long to wait and keeps «Reenviar código» off, instead of claiming a code went out (D9, decided 2026-10-18).
  - This tells nothing new about who has signed up: registering the same address already answers `429` while a recent code for an unconfirmed sign-up stands.
- The new code replaces the last one.

## The code

- Six random digits (`secrets`), valid for 30 minutes, locked after 5 wrong tries.
- Only a salted HMAC-SHA256 digest is stored (`salted_hmac`, like invitation codes), bound to the account. It is compared in constant time.
- There's one `EmailVerification` row per unconfirmed account. A new code replaces the last one, and the row goes once the address is confirmed.
- The code is never logged.

**Sending limits per address:**
- at most 1 code a minute and 5 an hour, kept on the `EmailVerification` row;
- on top of those, the outbox's limits (`reserve_email`): 80 emails a day, 2,700 a month, and 8 a day to one recipient.

## The email

It goes through the outbox (`core/email_delivery.py`), like invitation and password-reset emails. It sends from `DEFAULT_FROM_EMAIL`, the noreply address, with Reply-To `EMAIL_SUPPORT_ADDRESS` once the outbox sets it for every email.

| Language | Subject | Body |
|---|---|---|
| es | Tu código de TaskFlow: 123456 | Tu código para confirmar tu correo en TaskFlow es 123456. Caduca en 30 minutos. Si no has creado una cuenta de TaskFlow, ignora este mensaje. |
| ca | El teu codi de TaskFlow: 123456 | El teu codi per confirmar el teu correu a TaskFlow és 123456. Caduca d’aquí a 30 minuts. Si no has creat cap compte de TaskFlow, ignora aquest missatge. |
| en | Your TaskFlow code: 123456 | Your code to confirm your email for TaskFlow is 123456. It expires in 30 minutes. If you didn't create a TaskFlow account, ignore this message. |

**Language:** the request's `language`; else the language of the sign-up, for codes sent by sign-in or resend; else English.

**Where the code's text lives:**
- Until the email is sent, the outbox holds its text, code included, like invitation and reset emails.
- After sending, the outbox clears the body, and this code replaces the subject with «TaskFlow email code».
- When a code is replaced or used, its email is cancelled if it's still unsent.
- Daily maintenance deletes expired outbox rows.

## Who counts as confirmed

`User.email_verified` records it. New accounts start unconfirmed (`False`), so any new way of creating accounts must say so explicitly.

These count as confirmed:
- every account that existed before this feature (data migration `0020_email_verification`);
- Google sign-in, whose token must say the email is verified;
- linking Google to an account with the same email;
- completing a password reset, because the reset email proves the address;
- the local test account (`seed_test_user`), which also confirms one that signed up in the app and never entered the code;
- `createsuperuser`;
- sign-ups while verification is off, so turning it on later never locks them out or lets anyone replace them.

**Google and an unconfirmed sign-up.** Google sign-in with the address of an unconfirmed password sign-up claims it:
- the account becomes the Google person's, confirmed and linked;
- it no longer has a usable password;
- a confirmed account still gets `409 google_link_required`, as before;
- with verification off, nothing is claimed.

## Why verify asks for the password

Someone could sign up an unconfirmed address again, with another password, while its owner is entering the code. The owner's mailbox then gets the new code. Without the password check, entering it would confirm an account whose password the other person chose, and they could then sign in to it.

With the check:
- the owner's verify answers `signup_replaced`, because their password is no longer the one in place;
- the app asks them to sign up again, which puts their password back and sends a new code to their mailbox;
- whoever signed up last can confirm only with their own password and a code from the mailbox.

Sign-in's lock stops verify becoming a way to guess the password.

## Known gaps

- The outbox's footer is in English, even on Spanish and Catalan emails.
