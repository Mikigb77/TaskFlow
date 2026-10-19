# UX web loop: run 2026-10-18-site, batch b1, close (2026-10-19)

**Verdict:** 11 findings verified, each protected by a Playwright test. 5 more are fixed in code and by tests but still need a real device or a person (`device-check`). 9 stay open, but only for the parts owned by packages outside this batch (WP19, WP20, WP22, WP23, WP26 to WP28). WEB-2's bare-`/` redirect failed twice and goes to the owner. Round 3 left one new S1 regression, WEB-710, which is not planned yet.

## Verified (the reviewer said fixed, and no test for it failed)
| ID | Title | Package | Locked by |
|---|---|---|---|
| WEB-10 | The live demo sits 5.4 phone screens below the hero | WP14 | `tests/ux-web-home.spec.ts` |
| WEB-11 | The "at a glance" bar says nothing concrete | WP14 | `tests/ux-web-home.spec.ts` |
| WEB-17 | A whole section sells the website's dark mode | WP14 | `tests/ux-web-home.spec.ts` |
| WEB-114 | Sample dates are a month old | WP14 | `tests/ux-web-home.spec.ts` |
| WEB-101 | The site says TaskFlow works without an account | WP17, WP18 | `tests/ux-web-features.spec.ts` |
| WEB-106 | Reminders, the core loop's third step, are never told | WP17 | `tests/ux-web-features.spec.ts` |
| WEB-504 | Comparers never learn their phone calendar comes along | WP17 | `tests/ux-web-features.spec.ts` |
| WEB-308 | Keyboard focus vanishes on the closing card in light mode | WP18 | `tests/ux-web-features.spec.ts` |
| WEB-705 | Voice feature card is half empty (R1H-1, R1F-2) | WP35 | `tests/ux-web-features.spec.ts`, `tests/ux-web-home.spec.ts` |
| WEB-706 | Calendar drawing hard-codes days 21 to 27 (R1H-2, R1F-3) | WP35 | `tests/ux-web-features.spec.ts`, `tests/ux-web-home.spec.ts` |
| WEB-709 | Full-width offline card is two-thirds blank (R2F-1) | WP36 | `tests/ux-web-features.spec.ts` |

Note on WEB-114: WD4's hero images show the date they were rendered. Re-render them before publishing.

## Device check (fixed in code and by tests; a person or a real device still has to confirm)
| ID | Title | Test | Still to check |
|---|---|---|---|
| WEB-1 | The hero never says what TaskFlow is | `tests/ux-web-home.spec.ts` | A screen reader on the hero. A native Catalan read of «posa cada una el seu dia» (or «posa cadascuna al seu dia»). |
| WEB-5 | Hero screenshots show the old app | `tests/ux-web-home.spec.ts:62` | Can the task titles be read at arm's length on a real phone? |
| WEB-19 | Decorative hero text is read aloud | `tests/ux-web-home.spec.ts` | NVDA or TalkBack on the hero. |
| WEB-503 | Opening one FAQ answer closes the one you read | `tests/ux-web-features.spec.ts` | Safari on an iPhone: opening an answer doesn't make the page jump. |
| WEB-708 | Account answer reads as password-free sign-in (R1F-1) | `tests/ux-web-features.spec.ts` | A native Catalan read of the answer. |

## Still open (this batch's part is verified; the rest belongs to later packages)
- **WEB-3**: WP16's hero line and WP18's closing card are done. Left: the phone-menu row (WP20).
- **WEB-4**: WP16 to WP18 are done. Left: the header's "Explore the app" (WP20), the footer (WP23, held) and "Try the live demo" (WP26, held).
- **WEB-6**: WP14 removed the walkthrough (round 1, partly fixed). WP33 removed its last pointers in round 2: the footer link, the tries-used line and privacy §8. Left: WP26's static example (held).
- **WEB-16**: WP14 is done. Left: the intro orb (WP26) and the real button (WP27), both held.
- **WEB-311**: WP16 is done; the home loads one hero image of 25 to 27 KB. Left: the font (WP22, held).
- **WEB-105**: WP17's voice card is done. Left: the FAQ (WP19).
- **WEB-111**: WP17's headings are done. Left: the FAQ heading and its orphan "04 /" eyebrow (WP19).
- **WEB-104**: WP18 is done, including WD14's clause. Left: WP28 (held). Also, the demo's "3 free tries · no account" badge contradicts WD2's line (WP26).
- **WEB-707** (R1G-1): WP34 wrapped the demo in `lang="en"`; WP26 removes the wrapper later. Left: the FAQ half (WP19). Until WP19 lands, FAQ items 4 to 7 on /es/ and /ca/ are still English text inside `lang="es"` or `lang="ca"`.
- **WEB-710** (new, R3F-1) · S1 · F · Offline paragraph sits above its own heading · `src/styles/global.css:687`. This is a regression from round 3: WP36 aligned the paragraph to the top of the icon, so at desktop widths the body text starts above the heading. Proposed fix, CSS only: `.feature-offline p { grid-column: 2; grid-row: 2; margin-top: 18px; }`. Verify that at 1440 px in EN, ES and CA the tops of the paragraph and the heading are within 2 px. Not planned yet.
- The other open lines in the ledger are packages that weren't in this batch: WP19 to WP32.

## Escalations
- **WEB-2** (home only in English, no language switch; the bare-`/` part). It failed twice:
  - **Round 1 (WP15):** Next 16 overwrote `Vary` on the 200.
  - **Round 2 (WP34):** the relaxed cache checks now pass (`tests/ux-web-global.spec.ts:91-136`), but the briefed path-only redirect was never made. `src/proxy.ts:37` still builds the 307's Location from `request.url`. The implementer and the tester disagree on whether that comes out absolute.
  - **The risk:** behind Cloud Run, the edge worker rewrites a Location only when it starts with `env.ORIGIN` (`edge/worker.ts:78-83`). So after a deploy, Spanish and Catalan visitors could be sent to the run.app host or to a dead host. This is inferred, not seen, and probably server-side.
  - **Recommendation:** allow the one-line change at `src/proxy.ts:37`, `new NextResponse(null, { status: 307, headers: { Location: homePath(language) } })`, keeping lines 38 and 39. Then check it with curl locally and on taskflow.garbar.tech after a deploy.
  - **Done in b1:** the /es/ and /ca/ homes, canonical links, hreflang, and choosing the language by cookie or Accept-Language.
  - **Still planned:** WP20, WP22 to WP24 (held), WP28 and WP29 (held).

## Before committing (for the main session)
- **Commit `src/proxy.ts` and `src/app/[language]/` only together with WP20.** Nothing writes the `taskflow-lang` cookie yet. Until WP20's language switch does, a browser that prefers Spanish or Catalan can never reach the English home: every `/` answers 307 to /es/ or /ca/.
- **Held files.** Commit only this run's own lines there:
  - `src/components/Footer.tsx` and `src/components/VoiceDemo.tsx` hold another session's uncommitted changes.
  - `src/content/legal/en.ts`, `es.ts` and `ca.ts` are another session's untracked files. They can't be committed until that session commits them.

## Checks for a real device or a person
- **After a deploy:** `curl -sI -H 'Accept-Language: es' https://taskflow.garbar.tech/` must answer with `location` set to `https://taskflow.garbar.tech/es/` or `/es/` (WEB-2).
- **Screen reader on the hero:** NVDA or TalkBack (WEB-1, WEB-19).
- **Reading the demo on /es/:** TalkBack in Spanish should read the demo's English heading with English pronunciation. Also check VoiceOver on Safari with the `display: contents` wrapper (WEB-707).
- **A real phone at arm's length:** can the task titles in the hero screenshot be read? (WEB-5)
- **Safari on an iPhone:** opening an FAQ answer doesn't make the page jump (WEB-503). All the renders were Chromium, so the site's look in Safari is generally unchecked.
- **Native Catalan reads:**
  - the hero subheadline (WEB-1);
  - the account answer (WEB-708);
  - «Ja puc descarregar TaskFlow?»;
  - «Aquesta setmana»;
  - «dl dt dc dj dv ds dg»;
  - «Un bon començament» / «Repassa els plans de la setmana»;
  - «Una estona a l'aire lliure» / «El teu passeig preferit»;
  - the shortened sentence in privacy §8.
- **Owner action:** re-render WD4's hero images before publishing, because they show their render date (WEB-114).

## Files changed
**Website (TaskFlowWeb):**
- **Pages and content:**
  - `src/app/page.tsx`
  - `src/app/[language]/page.tsx`
  - `src/proxy.ts` (commit only with WP20)
  - `src/content/site/types.ts`, `index.ts`, `en.ts`, `es.ts`, `ca.ts`
- **Components:**
  - `src/components/HomePage.tsx`
  - `src/components/useSiteLanguage.ts`
  - `src/components/Header.tsx`
  - `src/components/Phone.tsx`
  - `src/components/ThemeProvider.tsx`
  - `src/components/Icon.tsx`
  - `src/components/TaskDemo.tsx` (deleted)
- **Styles and voice logic:**
  - `src/styles/global.css`
  - `src/lib/voice/policy.ts`, `src/lib/voice/security.ts`
- **Images deleted:** `public/images/tasks-light.png`, `tasks-dark.png`, `agenda-light.png`, `agenda-dark.png`, `calendar-light.png`, `calendar-dark.png`.
- **Tests:**
  - `tests/website.spec.ts`
  - `tests/voice.spec.ts`
  - `tests/ux-renders.spec.ts`
  - `tests/ux-web-home.spec.ts`
  - `tests/ux-web-features.spec.ts`
  - `tests/ux-web-global.spec.ts`
  - `tests/ux-web-frame.spec.ts`
  - `tests/ux-web-voice.spec.ts`
  - `tests/ux-web-legal.spec.ts`
  - `tests/support/ux-voice.ts`, `tests/support/ux-web.ts`, `tests/support/ux-web-copy.ts`
- **Held (another session's work):**
  - `src/components/Footer.tsx` (uncommitted changes)
  - `src/components/VoiceDemo.tsx` (uncommitted changes)
  - `src/content/legal/en.ts`, `es.ts`, `ca.ts` (untracked files)

**App repo (TaskFlow):**
- `.claude/ux-web/ISSUES.md`
- In `.claude/ux-web/runs/2026-10-18-site/`:
  - `plan.md`
  - `plan-b1-r2.json`, `plan-b1-r3.json`
  - `verify-b1-r1-H.md`, `verify-b1-r1-G.md`, `verify-b1-r1-F.md`
  - `verify-b1-r2-H.md`, `verify-b1-r2-G.md`, `verify-b1-r2-F.md`
  - `verify-b1-r3-F.md`
  - `report-b1.md` (the main session saves it)

## Rounds
| Round | Packages | Tests | Fixed | Not yet | Regressions |
|---|---|---|---|---|---|
| 1 (`plan.json`) | WP14 done, WP15 partial, WP16 to WP18 done | **failed**: the failing checks were WEB-2's Vary on the 200 and WEB-6's footer link | WEB-17, 11, 10, 16*, 114, 1, 3*, 4*, 5, 19, 311*, 101, 105*, 106, 504, 111*, 104*, 503, 308 | WEB-6, WEB-2 | R1H-1 and R1F-2 → WEB-705; R1H-2 and R1F-3 → WEB-706; R1G-1 → WEB-707; R1F-1 → WEB-708 |
| 2 (`plan-b1-r2.json`) | WP33, WP34, WP35 done | passed | WEB-6*, 707*, 708, 706, 705 | WEB-2 (escalated) | R2F-1 → WEB-709 |
| 3 (`plan-b1-r3.json`) | WP36 done | passed | WEB-709 | none | R3F-1 → WEB-710 (open) |

\* This batch's share is fixed; the rest of the finding waits on later packages (see "Still open").

## Ledger changes (`.claude/ux-web/ISSUES.md`)
- **To Verified:** WEB-10, 11, 17, 101, 106, 114, 308, 504, 705, 706, 709.
- **To Device check:** WEB-1, 5, 19, 503, 708.
- **Notes updated, still Open:** WEB-3, 4, 6, 16, 104, 105, 111, 311, 707.
- **Added as Open:** WEB-710.
- **Escalated note updated:** WEB-2.
- No line was deleted.