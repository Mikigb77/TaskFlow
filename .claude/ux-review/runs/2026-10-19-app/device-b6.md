# Run 2026-10-19-app: batch b6 on the review emulator (2026-10-21)

**Evidence level: emulator.** TaskFlow_Review: Android 16, Pixel 4 profile at about 393 dp. There's no real voice, and it isn't a physical phone.
- **The build:** batch b6's app code, from a clean worktree. The journey ran at c95c260 and the share at 267b77d.
- **The backend:** the local Docker API at cf39f6e.
- **The captures:** 87 in all, with nothing missing in the end, in `App/build/ux/device/`.

Two lane changes came first, for b6's own changes (both committed):
- **Sign-in:** the lane now goes through «Continuar con mi correo» (D2).
- **Sharing:** a share now counts as arrived by its title words, because D3 takes the day out of the title.

## Confirmed on the emulator
| Finding | What the capture shows | Capture |
|---|---|---|
| UX-1603 (D2, P193), the visible half | The first screen shows «Inicia sesión», the pitch, «Continuar con Google» as the one button-shaped control, «Continuar con mi correo» as a text link, then Privacy and Terms. «Ajustes de conexión» shows only in debug builds. «Continuar con mi correo» opens the email form in place. | `first-run.sign-in.es.*`, `first-run.sign-in-email.es.*` |
| UX-1623 (D3, P192) | Sharing «Comprar pan y leche el viernes» opens «Nueva tarea» titled «Comprar pan y leche», with «vie, 23 oct» chosen. Back saves it on Friday the 23rd. This fixes SEEN #7, which saved it undated with «el viernes» in the title. | `share.landing.es.*`, `share.after-back.es.light.1.0` |
| UX-1601 (D1, P190), one half | With a task saved for tomorrow, whose 9:00 reminder can still fire, the one-time question still comes after the save message. | `reminder-ask.sheet.es.*` |

## Still for a phone or staging
- **UX-1603:** Google sign-in from the folded screen (real Google), and Back folding the open form.
- **UX-1601:** a date-only task for today saved after 9:00 brings no question (the lane saves for tomorrow).
- **UX-1602:** the 6-digit code with the number pad and autofill, and the Spanish email on staging.
- **UX-1515:** a changed name saved to the account (staging).
- **UX-1654:** a shared capture resumed days later opens with no day (needs the clock moved forward).

## Noticed, for the next review
- At 2.0 on the opened sign-in form, «Continuar con Google» wraps to two lines. It's whole, and the lane now closes Gboard's font-size banner before that capture.
