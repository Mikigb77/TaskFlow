## UX web review — verify, run 2026-10-18-site, round 3, area H (WP42) — 2026-10-19

**Verdict:** Ship after fixes. WEB-719 is fixed; one severity-1 regression (the faded focus ring on the held Try again) is cosmetic and AA-exempt, but cheap to fix.

**Walked:** live voice demo, voice mode: record → send → request fails (offline / 503) → Try again → security check held → released → review. Keyboard and pointer; desktop 1440 × 1000 and mobile 390 × 664; light (renders), dark (CSS arithmetic + tester's axe run); EN renders, ES/CA via the tester's assertions.

**Evidence:** code (`src/components/VoiceDemo.tsx`, `src/styles/voice.css`), renders `artifacts/ux-web/voice-resend-waiting.en.{desktop,mobile}.light.{view,panel}.png` (21:37–21:38, newer than `VoiceDemo.tsx` at 21:10), `AUDIT.md` §13 rows 1390–1391, the tester's tests in `tests/ux-web-voice.spec.ts`.

### Findings judged

**WEB-719 (R2H-1) · fixed**
- `src/components/VoiceDemo.tsx:427-429`: `listening = recording || (pending && mode === "voice" && !retryPending)`, with the brief's comment. So while the resend waits, the record button stays the plain mic circle labelled by `#voice-record-label` (“Tap to talk”), `disabled={unavailable}` (`:579`, pending is in `unavailable` `:426`), no `is-recording` class, no “Done”.
- `:659`: the Try again block renders on `mode === "voice" && retryPending && audio && !recording`, so it no longer unmounts when `pending` turns true.
- `:662-668`: the implementer took the brief's aria-disabled route: `disabled={unavailable && !pending}`, `aria-disabled={pending || undefined}`, click is a no-op while pending. Focus stays on the button (AUDIT §13: focus on `button.voice-retry “Try again”`, desktop and mobile).
- `:593-601`: the hint reads `t.starting` (“One moment…”) because `pending`.
- `src/styles/voice.css:358-362`: `button[aria-disabled="true"]` gets the same 0.55 opacity and not-allowed cursor as `:disabled`, so it looks unavailable.
- Renders: desktop and mobile panel/view show the plain mic circle, “Tap to talk”, “One moment…”, the stand-in “Verifying…”, and the greyed “Try again” in place; no Done.
- `AUDIT.md` §13 `voice-resend-waiting` desktop/mobile light: 0 axe, 0 target, 0 text-contrast, 0 control fails, 0 unnamed. §4: no violations.
- Normal path unchanged: `record()` clears `retryPending` (`:280`), `finish` sets `pending` (`:255`) so the circle stays Done, disabled, with One moment… Typed mode block (`:645-656`) untouched. Tester proved both.
- WEB-2 clock pin: `tests/ux-web-voice.spec.ts:718` fixes Monday 19 Oct 2026 18:00 +02:00 and keeps the «viernes a las 17:00» expectation.
- Device-only (not faked, still open for the owner): real Turnstile + AI + microphone on a phone in Spanish; TalkBack announcing «Reintentar» as unavailable while focus stays on it.

### Regressions

**R3H-1 · Severity 1 · Held Try again's keyboard focus ring fades to 2.4:1**
- Where: `src/styles/voice.css:358-362` (`.voice-panel button[aria-disabled="true"] { opacity: 0.55 }`) with `src/styles/global.css:116-119` (`:focus-visible { outline: 3px solid var(--green) }`); live demo, Try again held, light theme, any viewport, any language.
- The moment: a keyboard user presses Enter on “Try again”; focus correctly stays on it, but the ring around it goes pale: “Is anything focused? Did it take my key press?”
- What happens: `opacity` applies to the whole box, outline included. This is the first focusable control in the demo drawn at 0.55 opacity (a `disabled` button can't hold focus, so the case never arose before WP42). Light: #176e59 at 55% over #ffffff ≈ #7fafa4, about 2.4:1 against the white card. Dark: #9ed5b3 at 55% over #1d2a23 ≈ 3.8:1, which passes.
- Why it fails: WCAG 1.4.11 asks 3:1 for focus indicators, but it exempts inactive controls, and an aria-disabled button counts as inactive. So this isn't an AA failure; it's a weak signifier at the moment the visitor most needs to see where they are (AX-2, CT-5). The renders don't show it because the state was reached by a mouse click, so `:focus-visible` didn't match.
- Fix: make the held button look unavailable without opacity, so the outline keeps its full colour. For example `.voice-panel .button[aria-disabled="true"] { opacity: 1; background: color-mix(in srgb, var(--green) 55%, var(--surface)); }` (with the label colour left as is), and keep `:disabled` as it is. Or `.voice-panel button[aria-disabled="true"]:focus-visible { opacity: 1; }`, accepting that the button looks enabled while focused, with “One moment…” carrying the state. The first option is better. No copy change.
- Verify: reach the held state with the keyboard (Tab to Try again, press Enter), then screenshot; measure the ring colour against the card at 3:1 or more in light and dark. A Playwright check: `getComputedStyle(retry).opacity === "1"` while `aria-disabled="true"`.
- Evidence: inferred from CSS and computed by hand; no render shows keyboard focus in this state.

Not regressions (already owned elsewhere): the “Failed to fetch” alert left in view during the hold (WP29's wording); a security-check error during the hold leaves Try again unavailable with no way out (pre-existing for Done too; WP29's “Stop waiting”).
