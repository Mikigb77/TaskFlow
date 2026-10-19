# UX web loop: run 2026-10-18-site, batch b3, report (2026-10-19)

**Verdict:** 3 rounds. Every round's tests passed and nothing was escalated.
- **Verified:** 12 findings.
- **Fixed, waiting on a device or person check:** 9 findings.
- **Still open:** 7 findings. 6 are only partly done because their remaining parts belong to later packages (WP29, WP31). The 7th is WEB-720, a new severity-1 regression from round 3 that wasn't re-planned because round 3 was the batch's last.
- **Committing:** most of the work is in `VoiceDemo.tsx` and the legal files, which hold another session's uncommitted work. Only this run's own lines can be committed (see "Files changed").

## Verified (the reviewer said "fixed" and no test failed)
| ID | Title | Package |
|---|---|---|
| WEB-4 | Every call to action loops back to a sample form | WP26 (the last part) |
| WEB-7 | The live demo ends in a toy list | WP28 |
| WEB-16 | Four microphones look tappable; three do nothing | WP26, WP27 |
| WEB-18 | Without JavaScript, the live demo's button does nothing | WP26 |
| WEB-104 | Free plan and Pro missing; pricing answer outdated | WP28, plus WP26's badge |
| WEB-108 | Both demos show a review step the app lacks | WP28 |
| WEB-208 | Language switch: the current language shown by colour only | WP24 |
| WEB-402 | The demo's text box has no visible edge | WP27 |
| WEB-502 | The demo turns typed sentences into tasks; that's Pro | WP27 |
| WEB-703 | Logo, footer links and "Back to top" under 44 px | WP25 (the last part) |
| WEB-714 | Legal back arrow no longer grows with the text (R1L-1) | WP41 |
| WEB-717 | After a failed voice send, Done sits beside Tap to talk (R1H-2) | WP39 |

## Fixed in code and by tests, still needing a device or person (`device-check`)
| ID | Title | What still needs checking |
|---|---|---|
| WEB-14 | Microphone errors are raw English or dead ends | Deny the microphone prompt in Chrome on Android and in Safari on an iPhone |
| WEB-15 | The recording timer is announced every second | TalkBack while recording |
| WEB-309 | The frame's small print is 8–11 px, fixed in px | Android at its largest font size |
| WEB-313 | Dark first visit: a light toolbar and a greyed-out switch | A dark-mode phone on a slow network |
| WEB-702 | Taps on frame links give no visible feedback | A throttled Android phone: tap a footer link in light and dark (the browser's highlight may be faint on #121c18) |
| WEB-715 | At 200% text on phones, sticky header takes two rows (R1G-1) | Android Chrome at its largest font size |
| WEB-716 | Tries-used line clips the weekday: «el mar», «dt.» (R1H-1) | A native Catalan read of «Hi podràs tornar a provar avui a les {time}.» and «… {weekday} a la {time}.» |
| WEB-718 | 'Understanding…' stays in the panel after the answer (R1H-3) | TalkBack in Spanish after a result |
| WEB-719 | Tapping Try again swaps it for a disabled Done (R2H-1) | Real Turnstile, AI and microphone on a phone in Spanish; TalkBack announcing «Reintentar» as unavailable |

## Still open, and why
- **WEB-2**: the WP24 and WP28 parts are verified (the legal back link and language pill; dates and plurals in the page's language). **Left for WP29:** the demo's connecting fallback, waiting state and server messages are still English on /es/ and /ca/.
- **WEB-6**: WP26's static example is verified. **Left for WP29:** show the example when the live demo can't run.
- **WEB-8**: WP25 is verified (`global.css` is all rem; no text under 12 px on the home or 404 pages). **Left for WP29:** `voice.css`'s 14 px example label. The legal article's small text belongs to WEB-205 (WP30).
- **WEB-9**: WP27 and WP28 are verified. **Left for WP29:** Turnstile `interaction-only` (the "Success!" box still shows).
- **WEB-12**: WP26 and WP28 are verified. **Left for WP29:** the waiting state's 'Making a little clarity…' and 'Your drafts will appear right here', and the server's messages.
- **WEB-207**: WP26 is verified (the privacy link goes to `/privacy/#website` in each language). **Left for WP31:** privacy §8 still names 'Create drafts' (together with WEB-602).
- **WEB-720 (new, R3H-1, severity 1):**
  - **Problem:** while Try again waits on its resend, it is `aria-disabled` and drawn at `opacity: 0.55` (`src/styles/voice.css:358`). The opacity also fades its keyboard focus ring, to about 2.4:1 against the card in light (about 3.8:1 in dark).
  - **Severity:** WCAG AA exempts inactive controls, so this isn't a failure, but a keyboard user can't easily see where focus is.
  - **Why not fixed:** round 3 was the batch's last, so it wasn't re-planned.
  - **Fix:** give the held button a dimmed fill (`color-mix(in srgb, var(--green) 55%, var(--surface))`) with `opacity: 1`, and leave `:disabled` as it is.

**Not in the ledger (verifier observations from before this run, for WP29's planning):**
- Pressing Tap to talk disables the focused button while the microphone starts, so focus drops to the page (`verify-b3-r1-H.md`).
- For typed text, 'See what I said' would be more exact as «what I wrote». The owner can decide whether to change it.

## Escalations
None.

## Checks for a real device or a person
- Live voice demo with the real AI and a real microphone, on a phone in Spanish (WEB-9, WEB-719).
- Deny the microphone prompt in Chrome on Android and Safari on an iPhone (WEB-14).
- TalkBack: while recording (WEB-15), after a result in Spanish (WEB-718), and «Reintentar» announced as unavailable while it keeps focus (WEB-719).
- Android at its largest font size: the frame's small print (WEB-309), the sticky header (WEB-715), and the language switch (WEB-2).
- A dark-mode phone on a slow network: no light flash, and the theme switch appears once it works (WEB-313).
- A throttled Android phone: tap feedback on footer links in light and dark (WEB-702).
- Turnstile's real look on the deployed site (WEB-9).
- The 307's Location header after a deploy (WEB-2).
- A real phone at arm's length: text size (WEB-8).
- Native Catalan reads:
  - the tries-used sentences (WEB-716);
  - these demo strings, recorded under WEB-2: `Prova la demo en directe`, `Tanca la demo`, `{n} de 3 intents disponibles`, `Demo en directe`, `Esperant el micròfon…`, `Parla`, `Escriu el que has de fer`, `{n} / {max} caràcters`, `Canvia el text`, `Hi podràs tornar a provar més tard.`

## Files changed

### Website (TaskFlowWeb)
"Held" below follows `git -C ../TaskFlowWeb status --porcelain` and the fix run's base snapshot (`refs/ux-web/base`).

**Hold another session's uncommitted work.** Only this run's lines can be committed:
- `src/components/VoiceDemo.tsx`: the other session's privacy link (line 396 at the base) was left untouched.
- `src/app/sitemap.ts`: the run only added `/es/` and `/ca/` after `/`.

**The other session's untracked files.** Nothing can be committed until that session commits them:
- `src/components/LegalPage.tsx`
- `src/styles/legal.css`

**The run's own, but committable only with the held `VoiceDemo.tsx` changes:**
- `src/components/VoiceExample.tsx` (new; `VoiceDemo.tsx` mounts it)
- `src/styles/voice.css`: it wasn't dirty at the run's base, but its new selectors (`.voice-retry`, `button[aria-disabled]`) only serve the held changes.
- `src/content/site/types.ts`, `en.ts`, `es.ts` and `ca.ts`: the demo's copy.
- `tests/voice.spec.ts`, `tests/ux-web-voice.spec.ts` and `tests/support/ux-voice.ts`

**The run's own, but committable only with the other session's untracked legal files:**
- `tests/ux-web-legal.spec.ts`: it tests `LegalPage.tsx` and `legal.css`.

**The run's own and independent:**
- `src/styles/global.css`
- `src/components/Icon.tsx`: the `back` icon.
- `tests/ux-web-global.spec.ts`
- `tests/support/ux-web.ts`

### App repo (TaskFlow)
- `.claude/ux-web/ISSUES.md`: this batch's lines. The other lines were untouched.
- `.claude/ux-web/runs/2026-10-18-site/plan.md` (rounds 2 and 3 appended), `plan-b3-r2.json`, `plan-b3-r3.json`.
- `.claude/ux-web/runs/2026-10-18-site/verify-b3-r1-{L,G,H}.md`, `verify-b3-r2-{L,G,H}.md`, `verify-b3-r3-H.md`.
- `.claude/ux-web/runs/2026-10-18-site/report-b3.md`: this report, which the main session saves.
- The app repo's other uncommitted files (`App/`, `Backend/`, `.claude/ux-review/`) belong to another session and aren't part of this run.

## Verified findings locked by a test
| Test file | Findings |
|---|---|
| `tests/ux-web-voice.spec.ts` | WEB-4, WEB-7, WEB-16, WEB-18, WEB-104, WEB-108, WEB-402, WEB-502, WEB-717 |
| `tests/ux-web-legal.spec.ts` | WEB-208, WEB-714, WEB-703 |
| `tests/ux-web-global.spec.ts` | WEB-4, WEB-703 |
| `tests/ux-web-frame.spec.ts` | WEB-4, WEB-703 |
| `tests/ux-web-home.spec.ts` | WEB-4, WEB-16 |
| `tests/ux-web-features.spec.ts` | WEB-4, WEB-16, WEB-104 |

Fixed findings still waiting on a device are locked too:
- `tests/ux-web-voice.spec.ts`: WEB-14, WEB-15, WEB-716, WEB-718, WEB-719.
- `tests/ux-web-global.spec.ts`: WEB-309, WEB-313, WEB-702, WEB-715.
- `tests/ux-web-frame.spec.ts`: WEB-309, WEB-313.
- `tests/ux-web-legal.spec.ts`: WEB-309.

The parts already fixed in the open findings are locked as well: WEB-2, WEB-6, WEB-8, WEB-9, WEB-12 and WEB-207.

## Rounds

### Round 1 (`plan.json`): WP24–WP28. Tests passed.
- **WP24 (L):** the legal pages' back link and language pill, and the sitemap. WEB-2's share and WEB-208 fixed.
- **WP25 (G):** `global.css`: rem sizes, dark mode without JavaScript, tap feedback, a 48 px logo. WEB-8's share, WEB-309, WEB-313, WEB-702 and WEB-703 fixed.
- **WP26 (H):** the demo's intro, static example, `noscript`, privacy line and landing. WEB-6, WEB-12, WEB-18, WEB-207, WEB-16 and WEB-4 fixed.
- **WP27 (H):** the capture step: one tap, microphone errors, the status line, the text box, the Pro line. WEB-9, WEB-14, WEB-15, WEB-16, WEB-402 and WEB-502 fixed.
- **WP28 (H):** the result: the app's layout, the hand-over, the plans line, dates by language. WEB-7, WEB-108, WEB-104, WEB-9, WEB-2 and WEB-12 fixed.

**Regressions, re-planned for round 2:**

| Regression | Ledger ID | Problem |
|---|---|---|
| R1L-1 | WEB-714 | The legal back arrow no longer grows with the text |
| R1G-1 | WEB-715 | At 200% text on phones, the sticky header takes two rows |
| R1H-1 | WEB-716 | The tries-used line clips the weekday: «el mar», «dt.» |
| R1H-2 | WEB-717 | After a failed voice send, Done sits beside Tap to talk |
| R1H-3 | WEB-718 | 'Understanding…' stays in the panel after the answer |

### Round 2 (`plan-b3-r2.json`): WP39–WP41. Tests passed.
- **WP39 (H):** WEB-716, WEB-717 and WEB-718 fixed.
- **WP40 (G):** WEB-715 fixed.
- **WP41 (L):** WEB-714 fixed.
- **Regression:** R2H-1, recorded as WEB-719 (tapping Try again swapped it for a disabled Done).

### Round 3 (`plan-b3-r3.json`): WP42. Tests passed.
- **WP42 (H):** WEB-719 fixed (the WEB-2 test's clock is now pinned).
- **Regression:** R3H-1, recorded as WEB-720 (the held Try again's focus ring fades). It is open and needs a later round.
