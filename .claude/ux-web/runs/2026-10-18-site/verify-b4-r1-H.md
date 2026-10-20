# Verify — 2026-10-18-site, b4, round 1, area H — WP29 — 2026-10-19

Scope: WP29 (WEB-13, WEB-401, WEB-403, WEB-12, WEB-8, WEB-2). Evidence: the run's diff (`ux-web.sh diff`) of `src/components/VoiceDemo.tsx`, `src/styles/voice.css`, `src/content/site/{types,en,es,ca}.ts`; renders made 2026-10-20 00:28–00:31, after the last source change (VoiceDemo.tsx 2026-10-19 22:16, voice.css 22:24), so they count as evidence; AUDIT.md §13; the tester's results. No npm or Playwright run by me.

## Results

| ID | Result | Evidence |
|---|---|---|
| WEB-13 | fixed | Heading `t.understanding` with no subline, and "Your drafts will appear…" deleted (VoiceDemo.tsx processing stage). 10 s timer sets `waitedLong` and announces `t.stillUnderstanding`; `Stop waiting` (`.voice-stop`) aborts through `AbortController`, keeps text/recording (`retry: true` → `retryPending`, same request id). Close demo is `disabled={recording \|\| loading}` and calls `stopWaiting("close")`. Page timeout `AbortSignal.timeout(40_000)`. Renders: `voice-waiting-10s.en.mobile.light.view.png` (line + Stop waiting), `voice-timeout.en.mobile.light.panel.png` (message, filled "Try again" button). AUDIT §13 rows voice-waiting-10s: status "Still understanding…", axe 0. Device: real wait times on a slow phone connection. |
| WEB-401 | fixed | `readJson` reads the body only when content type is JSON; `refresh` throws `Refused(code)`; submit's catch maps `TypeError` → `errors.offline`, anything else → `errors.notAnswering`; no `reason.message` is shown anywhere. Opening: "Let’s try that again." and "Try connecting again" removed; a `.button` "Try again" under the alert. Renders `voice-connect-offline`, `voice-connect-gateway`, `voice-offline` (`.en.mobile.light.panel.png`) show the mapped text and Try again. AUDIT §13:973-974. See R1H-1 for the opening copy. |
| WEB-403 | fixed | Turnstile rendered with `appearance: "interaction-only"`, `size` compact under 300 px, `retry: "never"`; `before/after-interactive-callback` drive the tap line; failures show `t.checkFailed` with a Try again (`retryCheck` → new `generation`; failed script element removed so a new one loads); the mic and Done are disabled by `checkBlocked`; `checkFailures >= 2` → stage `unverified` (example + hand-over); `verification` code → `checkRefused` with the same in-place Try again that resends; `aria-label` removed from `.voice-verification`; `min-height: 66px` removed. Renders `voice-check-pending` (tap line directly above disabled Done), `voice-check-unreachable` (message, Try again, mic dimmed), `voice-check-gave-up`. AUDIT §13 voice-check-* axe 0 (0). Device: the deployed site with a content blocker; Cloudflare's real interaction-only/compact behaviour (Turnstile is a stand-in in tests; Cloudflare's docs are outside the reviewer's allowed sources, so the option names are unverified by me). See R1H-3. |
| WEB-12 | fixed | `failureFor` maps every code in the brief to the brief's copy; the server's `error` string is never read. Strings in en/es/ca.ts match the brief word for word; `errors.empty` equals the app's `captureEmptyInput` in all three ARBs (app_en.arb:1530, app_es.arb:909, app_ca.arb:724). The waiting state's ‘Making a little clarity…’ is gone. The only English hard-coded text left is developer-only (VoiceDemo.tsx:932, :1030-1031). Tester's 22-code test and 61-scenario scan pass. This was the last part of WEB-12 (ledger: WP26, WP28 done). |
| WEB-8 | fixed | Every `font-size` in voice.css is rem now (no px left; smallest 0.75rem = developer tools); the error box 1rem (was 13 px); the waiting line 1rem. AUDIT §13: "Small or low-contrast text in the demos: 0". This was the last part of WEB-8 (ledger: WP25 done; legal small text is WEB-205's). Device: a real phone at arm's length. |
| WEB-2 | fixed | Every new demo string exists in en/es/ca with one shared type; "Try connecting again" / "Let’s try that again." / waiting copy / server messages no longer reach the page. Tester's /es/ and /ca/ scans (61 scenarios each) find no English. This was the last part of WEB-2 per the ledger. Device: a native Catalan read of the new strings (below). |

Catalan strings this package added, for a native read: `Encara ho estic entenent. Pot trigar fins a mig minut.`; `Deixa d’esperar`; `Toca la comprovació de seguretat de dalt per continuar.`; `La comprovació de seguretat no s’ha carregat. Revisa la connexió i toca Torna-ho a provar.`; the ten `errors.*` strings in `src/content/site/ca.ts`.

## Regressions (only in the changed files and the demo they draw)

**R1H-1 · Severity 2 · Opening offline says "What you said is kept"**
- Where: `src/components/VoiceDemo.tsx` `statusFailed` (non-`Refused` → `t.errors.offline`); `src/content/site/{en,es,ca}.ts` `voice.errors.offline`. Render `voice-connect-offline.en.mobile.light.panel.png`; AUDIT §13:973-974.
- The moment: "What I said? I haven't said anything yet."
- What happens: opening the demo with no connection shows the sending message, which promises a kept recording and a free retry before anything was said or tried.
- Fix (subtract): on opening, show only the first two sentences. Add `errors.offlineOpening`: EN `No connection. Check Wi-Fi or mobile data and try again.` / ES `No hay conexión. Revisa el wifi o los datos móviles e inténtalo de nuevo.` / CA `No hi ha connexió. Revisa la wifi o les dades mòbils i torna-ho a provar.`; use it in `statusFailed`; keep `errors.offline` for sending.
- Verify: voice-connect-offline's alert has no "kept" / «conserva» / «conserva»; voice-offline unchanged.
- Evidence: seen in a current render; verified in code.

**R1H-2 · Severity 2 · "3 of 3 tries left" when the demo can't be used**
- Where: the tries badge in the panel header (VoiceDemo.tsx, shown for every stage with a status); renders `voice-error-budget-pause.en.mobile.light.panel.png`, `voice-check-gave-up.en.mobile.light.panel.png` / `.view.png`.
- The moment: "It says I have 3 tries, but there's nothing to tap."
- What happens: the new `off` and `unverified` stages replace the form with the static example, but the badge still counts tries left.
- Fix: in stages `off` and `unverified`, show the `liveDemo` label (`Live demo` / `Demo en directo` / `Demo en directe`) the connecting state already uses, instead of the count.
- Verify: in voice-error-budget-pause and voice-check-gave-up, `#voice` text has no "tries left" / «intentos» / «intents» in the badge.
- Evidence: seen in current renders.

**R1H-3 · Severity 2 · Second security-check failure: the form vanishes, no reason**
- Where: VoiceDemo.tsx `stage === "unverified"` block; focus goes to the hand-over. Render `voice-check-gave-up.en.mobile.light.view.png`; AUDIT §13:988-989 (announcement "—").
- The moment: "I tapped Try again and the box disappeared. Did I break it?"
- What happens: after the second failure the alert and Try again disappear and an example appears in their place; nothing on screen or announced says why, and the example could be read as a result.
- Fix: mirror the `off` stage: under the example, the alert EN `The security check didn’t load, so the live demo can’t run here. The example above shows what TaskFlow does.` / ES `La comprobación de seguridad no se ha cargado, así que la demo en directo no puede funcionar aquí. El ejemplo de arriba muestra lo que hace TaskFlow.` / CA `La comprovació de seguretat no s’ha carregat, així que la demo en directe no pot funcionar aquí. L’exemple de dalt mostra què fa TaskFlow.` (needs a native Catalan read), taking focus as the off state's alert does; keep the hand-over under it.
- Verify: voice-check-gave-up shows and announces the alert; axe 0.
- Evidence: seen in a current render and AUDIT §13.

**R1H-4 · Severity 2 · Stop waiting: the badge drops, nothing says Try again is free**
- Where: VoiceDemo.tsx submit, `reason === "stop"` → `message: ""`; renders `voice-stop-waiting.en.mobile.light.view.png` (badge "2 of 3 tries left"; no message; Try again below the fold) vs `voice-waiting-10s.en.mobile.light.view.png` ("3 of 3"); AUDIT §13:1031-1032 (announcement "—").
- The moment: "I stopped it and it still took one of my tries."
- What happens: the try was counted when the server admitted the request, and the badge refresh after stopping shows it, at the moment the visitor cancelled. Unlike the timeout, no line says Try again won't use another; on a phone the Try again button is a scroll below; a screen reader hears only the capture heading.
- Fix (reuse an existing string): for `reason === "stop"`, show `t.errors.processing` (EN `Still understanding. Try again in a moment; it won’t use another try.` / ES `Sigo entendiendo. Vuelve a probar en un momento; no gastará otro intento.` / CA `Encara ho estic entenent. Torna-ho a provar d’aquí a un moment; no gastarà cap altre intent.`), which is true (the server keeps working) and takes focus as the alert.
- Verify: after Stop waiting, the alert shows that text; Try again resends with the same request id and the badge stays at 2 of 3.
- Evidence: seen in current renders; verified in code.

Checked, no regression: Close demo while waiting (aborts, closes, no message); timeout at 40 s with filled Try again; `verification` refusal resends after the in-place Try again; the off state's example sits directly above its message; voice.css font sizes; strings in all three languages match the brief.

Not regressions (outside this package): the hand-over's "Coming soon to Google Play" (WP28's string) vs the conventions' "Coming soon to Android"; the privacy line's "Google’s AI".
