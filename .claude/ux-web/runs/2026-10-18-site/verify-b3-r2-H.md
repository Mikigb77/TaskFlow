# Verify — run 2026-10-18-site, batch b3, round 2, area H — 2026-10-19

Scope: WP39 (WEB-716, WEB-717, WEB-718). Files read: `src/components/VoiceDemo.tsx` (held), `src/styles/voice.css` (held), `src/content/site/{types,en,es,ca}.ts`, the tester's `tests/ux-web-voice.spec.ts`. Renders and AUDIT.md re-made 20:58–20:59, after the last code change (20:13): current evidence.

## Results

| ID | Result | Evidence |
|---|---|---|
| WEB-716 | fixed | `VoiceDemo.tsx:22` `weekday: "long"`; cards keep `day` with `weekday: "short"` (`:23-27`); comment `:18-19` updated. `:433-453` picks `today`/`todayAtOne`/`onDay`/`onDayAtOne` from `resetAt.toDateString() === new Date().toDateString()` and `formatToParts(...).hour === "1"`; `triesUsedLater` unchanged. `types.ts:163-169`, `en.ts:189-197`, `es.ts:189-199`, `ca.ts:197-207`: all four sentences match the brief's copy exactly, no ‘tomorrow’. Both uses (`.voice-again-later` `:728`, tries-used heading `:760`) read `triesUsedLine`. Render `voice-tries-used.en.mobile.light.view.png`: “You can try again on Tuesday at 1:58 AM.” AUDIT §13 voice-tries-used, voice-last-try: axe 0. Tester: Europe/Madrid fixed clocks, three cases × three languages, Spanish card «vie,». |
| WEB-717 | fixed | `submit` tracks `let retry` (`:332`, set `:351`, `:373`); `catch` clears `audio` in voice mode when not retryable (`:377`). Done block renders only when `mode === "text"` (`:644-655`), unchanged with its `pending` hint. Voice mode renders one `button voice-retry` labelled `t.tryAgain` when `retryPending && audio && !listening` (`:658-666`), `disabled={unavailable}`, `onClick={() => setPending(true)}`; `record()` clears both (`:280-282`). Strings `Try again` / `Reintentar` / `Torna-ho a provar` (app's words). Render `voice-error-audio-length.en.mobile.light.panel.png`: alert, then only the filled ‘Tap to talk’ circle, no Done. AUDIT §13 voice-error-audio-length, invalid-audio-1..5, too-large-1/2: axe 0. Tester: same X-Request-Id on resend, badge unchanged; typed invalid_draft keeps Done. One `voice.css` selector (`.voice-retry` beside `.voice-submit`, `:368-375`) gives it the same centring and min-width; harmless, the brief's “no style needed” is about colour/shape, which `.button` supplies. |
| WEB-718 | fixed | `finally` in `submit` calls `setAnnouncement("")` (`:383-385`). AUDIT §13 Announced column: “status: Understanding…” only on voice-waiting-* rows; voice-result, result-open/one/six, no-tasks, tries-used, last-try show “—”; error rows show only their alert. TalkBack in Spanish is a device check, not run. |

No visual evidence of the voice-mode Try again state: `voice-offline` and `voice-error-processing-*` are typed-mode renders (INDEX.md:90, :120). The tester's assertions cover it; a render `voice-offline-recording` would let the next reviewer see it.

## Regressions

**R2H-1 · Severity 1 · Tapping Try again swaps it for a disabled “Done”**
- Where: `src/components/VoiceDemo.tsx:428` (`listening = recording || (pending && mode === "voice")`), `:567-582`, `:658-666`; home `#voice`, voice mode, after an offline/503/timeout failure of a recording; every language, viewport and theme.
- The moment: “I tapped Try again — why does it now say Done, and where did my button go?”
- What happens: Try again sets `pending`, so `listening` becomes true. The `.voice-retry` button unmounts (`!listening`), focus falls to `<body>`, and the record circle turns into the filled `is-recording` button labelled `Done` / `Listo` / `Fet`, disabled, with “One moment…” under it, until the new security token arrives and the processing stage takes over. With the stand-in check this lasts one render; with Turnstile it lasts as long as the check, longer if it asks for interaction.
- Why it fails: feedback should confirm the action the visitor took, and the control they used should not vanish (Nielsen's visibility of system status; WCAG 2.4.3 focus order — focus lost to body). “Done” means “stop and send a recording”, which isn't what is happening.
- Fix: exclude a retry from `listening`: `const listening = recording || (pending && mode === "voice" && !retryPending);` and render the retry button on `retryPending && audio && !recording`. Then while the resend waits for its token, ‘Tap to talk’ stays a disabled circle, Try again stays in place, disabled (it already has `disabled={unavailable}`), focus stays on it, and the hint under the microphone reads `One moment…` / `Un momento…` / `Un moment…` (existing `t.starting`, shown because `pending`).
- Verify: Playwright in voice mode: fail the draft (offline), hold the Turnstile stand-in's token, click `.voice-retry`; expect `.voice-retry` still visible and disabled and focused, no button named Done, `.voice-hint` “One moment…”; release the token and expect one draft request with the same X-Request-Id.
- Evidence: inferred from code; no render shows this moment.

Checked and not regressions:
- After a voice offline/503 failure the panel has two filled controls (the ‘Tap to talk’ circle and Try again), as before with Done; the brief chose this. The alert text there (“Failed to fetch”, the English timeout sentence) is WP29's.
- `switchMode` clears `retryPending` but keeps `audio`; switching back to voice shows only ‘Tap to talk’. Correct.
- A retryable failure on the last try keeps the capture stage (`allowanceUsed && !retryPending`, `:182`), so Try again stays reachable instead of the tries-used stage. Correct.
- The capture stage's privacy line (`:632-637`) and the other session's link are untouched by this package.

## Catalan for a native read (reviewer's copy, as given)
- `Hi podràs tornar a provar avui a les {time}.`
- `Hi podràs tornar a provar {weekday} a la {time}.` / `… avui a la {time}.`
